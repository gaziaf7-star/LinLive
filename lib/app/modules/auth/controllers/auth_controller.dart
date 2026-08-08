import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:streaming_shared_preferences/streaming_shared_preferences.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/name_constants.dart';
import '../../../../models/user_profile.dart';
import '../../../services/account_block_service.dart';
import '../../../services/device_identity_service.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class AuthController extends GetxController {
  final isLoading = false.obs;

  final forgotPasswordSendingOtp = false.obs;
  final forgotPasswordVerifyingOtp = false.obs;
  final forgotPasswordResetting = false.obs;

  final registerName = TextEditingController();
  final registerEmail = TextEditingController();
  final registerPhone = TextEditingController();
  final registerAddress = TextEditingController();
  final registerPassword = TextEditingController();
  final registerProfile_Image = TextEditingController();

  final Dio _dio = Dio();

  final userProfile = UserProfile().obs;
  late StreamingSharedPreferences preferences;

  final needsForceUpdate = false.obs;
  final forceUpdateUrl = ''.obs;
  final serverVersion = ''.obs;

  bool _fcmSaving = false;
  String _lastSavedFcmToken = '';
  bool _profileRestoreRunning = false;
  final RxString deviceSessionError = ''.obs;

  /// Forgot password page-এর email field auto-fill করার জন্য current
  /// account email। Logged-in/restored profile-এর email প্রথম priority,
  /// register email fallback হিসেবে ব্যবহার হবে।
  String get currentAccountEmail {
    final dynamic currentUser = userProfile.value.user;
    final String profileEmail =
        currentUser?.email?.toString().trim().toLowerCase() ?? '';

    if (profileEmail.isNotEmpty && profileEmail != 'null') {
      return profileEmail;
    }

    final String fallbackEmail = registerEmail.text.trim().toLowerCase();
    return fallbackEmail == 'null' ? '' : fallbackEmail;
  }

  Future<void>? _initializeFuture;
  StreamSubscription<String>? _profileSubscription;
  String _lastProfileValue = '';
  bool _startupGateFinished = false;

  bool get hasUsableToken {
    final String token =
        userProfile.value.token?.toString().trim() ?? '';
    final String normalized = token.toLowerCase();

    return token.isNotEmpty &&
        normalized != 'null' &&
        normalized != 'undefined' &&
        normalized != '0';
  }

  void markStartupGateFinished() {
    _startupGateFinished = true;
  }

  @override
  void onInit() {
    super.onInit();

    if (Get.isRegistered<AccountBlockService>()) {
      AccountBlockService.to.configureDio(
        _dio,
        tokenProvider: () =>
            userProfile.value.token?.toString().trim(),
      );
    } else if (Get.isRegistered<DeviceIdentityService>()) {
      DeviceIdentityService.to.configureDio(
        _dio,
        tokenProvider: () =>
            userProfile.value.token?.toString().trim(),
      );
    }

    // SplashController এই একই Future await করবে। তাই startup restore একবারই চলবে।
    unawaited(initialize());

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 FCM token refreshed');
      if (Get.isRegistered<DeviceIdentityService>()) {
        unawaited(DeviceIdentityService.to.refreshFcmToken());
      }
      unawaited(saveFcmTokenToBackend(force: true));
    });
  }

  @override
  void onClose() {
    unawaited(_profileSubscription?.cancel());
    registerName.dispose();
    registerEmail.dispose();
    registerPhone.dispose();
    registerAddress.dispose();
    registerPassword.dispose();
    registerProfile_Image.dispose();
    super.onClose();
  }

  /// Restores the saved profile exactly once and can safely be awaited by splash.
  Future<void> initialize() {
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      if (Get.isRegistered<DeviceIdentityService>()) {
        await DeviceIdentityService.to.initialize();
      }

      preferences = await StreamingSharedPreferences.instance;
      final profilePreference =
      preferences.getString('profile', defaultValue: '');

      String initialValue = '';
      try {
        initialValue = await profilePreference.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => '',
        );
      } catch (error) {
        debugPrint('⚠️ Initial profile read failed => $error');
      }

      _lastProfileValue = initialValue;
      await _restoreProfileFromStorage(
        initialValue,
        startAuthenticatedServices: false,
      );

      await _profileSubscription?.cancel();
      _profileSubscription = profilePreference.listen((String value) {
        if (value == _lastProfileValue) return;

        _lastProfileValue = value;
        unawaited(
          _restoreProfileFromStorage(
            value,
            startAuthenticatedServices: _startupGateFinished,
          ),
        );
      });
    } catch (error, stackTrace) {
      debugPrint('❌ Auth initialize error => $error');
      debugPrint('$stackTrace');
      userProfile.value = UserProfile();
      userProfile.refresh();
    }
  }

  Future<void> _restoreProfileFromStorage(
      String rawValue, {
        required bool startAuthenticatedServices,
      }) async {
    final String value = rawValue.trim();

    if (value.isEmpty || value.toLowerCase() == 'null') {
      userProfile.value = UserProfile();
      userProfile.refresh();
      return;
    }

    if (_profileRestoreRunning) return;
    _profileRestoreRunning = true;

    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw const FormatException('Saved profile is not a JSON object');
      }

      userProfile.value = UserProfile.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      userProfile.refresh();

      if (Get.isRegistered<DeviceIdentityService>()) {
        final DeviceSession? savedSession =
            userProfile.value.deviceSession;
        if (savedSession != null) {
          await DeviceIdentityService.to.saveDeviceSession(
            savedSession.toJson(),
          );
        }
      }

      try {
        registerstepsController.refreshAuthUserData();
      } catch (error) {
        debugPrint('⚠️ refreshAuthUserData skipped => $error');
      }

      if (startAuthenticatedServices && hasUsableToken) {
        _startAuthenticatedServices();
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Profile restore error => $error');
      debugPrint('$stackTrace');
      await clearStoredAuthSession();
    } finally {
      _profileRestoreRunning = false;
    }
  }

  /// Splash uses this method before opening BottomnavView.
  ///
  /// 200 = valid token/session.
  /// 401/403/419 or an explicit token error = clear local login and go Welcome.
  /// Network/server timeout = do not enter BottomnavView. The saved profile is
  /// kept, but this launch goes to WelcomeView because the token was not verified.
  Future<bool> validateStoredSessionForStartup() async {
    await initialize();

    try {
      final int userId = userProfile.value.user?.id?.toInt() ?? 0;
      if (!hasUsableToken || userId <= 0) {
        await clearStoredAuthSession();
        return false;
      }

      if (!Get.isRegistered<DeviceIdentityService>()) {
        debugPrint(
          '⚠️ Startup token validation deferred: '
              'DeviceIdentityService unavailable',
        );
        return false;
      }

      final String token =
      userProfile.value.token!.toString().trim();
      final Dio startupDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      final Response<dynamic> response = await startupDio.get<dynamic>(
        kDeviceStatusUrl,
        options: Options(
          headers: await DeviceIdentityService.to.headers(token: token),
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      final int statusCode = response.statusCode ?? 0;

      if (statusCode == 200) {
        final Map<String, dynamic> session =
        await DeviceIdentityService.to.requireValidAuthDeviceSession(
          response.data,
        );

        userProfile.value.deviceSession = DeviceSession.fromJson(session);
        userProfile.refresh();

        final String encoded = jsonEncode(userProfile.value.toJson());
        _lastProfileValue = encoded;
        await preferences.setString('profile', encoded);

        _startAuthenticatedServices();
        debugPrint('✅ Splash auth check: valid session');
        return true;
      }

      if (_isInvalidAuthStatus(statusCode) ||
          _payloadIndicatesInvalidToken(response.data)) {
        debugPrint(
          '🔐 Splash auth check: invalid/expired token '
              '(HTTP $statusCode)',
        );
        await clearStoredAuthSession();
        return false;
      }

      // Unknown server responses must not open the authenticated home page.
      // Keep the saved profile so a later launch can validate it again.
      debugPrint(
        '⚠️ Splash auth check not verified (HTTP $statusCode); '
            'routing to WelcomeView',
      );
      return false;
    } on DeviceBlockedLoginException catch (error) {
      userProfile.value = UserProfile();
      userProfile.refresh();

      if (Get.isRegistered<AccountBlockService>()) {
        await AccountBlockService.to.forceLogoutFromPayload(
          error.payload,
          assumeDeviceBlocked: true,
        );
      } else {
        await clearStoredAuthSession();
      }
      return false;
    } on DeviceSessionValidationException catch (error) {
      debugPrint('❌ Startup device session invalid => ${error.message}');
      await clearStoredAuthSession();
      return false;
    } on DioException catch (error) {
      final int statusCode = error.response?.statusCode ?? 0;
      if (_isInvalidAuthStatus(statusCode) ||
          _payloadIndicatesInvalidToken(error.response?.data)) {
        await clearStoredAuthSession();
        return false;
      }

      debugPrint(
        '⚠️ Splash auth network check deferred => '
            '${error.type} / HTTP $statusCode',
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint('⚠️ Splash auth check failed safely => $error');
      debugPrint('$stackTrace');
      return false;
    } finally {
      // After the splash decision, future profile updates are login/logout
      // changes and may start the authenticated services normally.
      _startupGateFinished = true;
    }
  }

  bool _isInvalidAuthStatus(int statusCode) {
    return statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 419;
  }

  bool _payloadIndicatesInvalidToken(dynamic payload) {
    final String text = payload?.toString().toLowerCase() ?? '';
    return text.contains('unauthenticated') ||
        text.contains('token expired') ||
        text.contains('token has expired') ||
        text.contains('expired token') ||
        text.contains('invalid token');
  }

  void _startAuthenticatedServices() {
    if (!hasUsableToken) return;

    unawaited(saveFcmTokenToBackend());

    final int databaseUserId =
        userProfile.value.user?.id?.toInt() ?? 0;
    if (databaseUserId > 0 &&
        Get.isRegistered<AccountBlockService>()) {
      unawaited(
        AccountBlockService.to.startAuthenticatedSession(
          databaseUserId: databaseUserId,
        ),
      );
    }
  }

  Future<void> clearStoredAuthSession() async {
    try {
      // initialize() may already be running; normally this field is ready here.
      preferences = await StreamingSharedPreferences.instance;
      _lastProfileValue = '';
      await preferences.setString('profile', '');
    } catch (error) {
      debugPrint('⚠️ Saved profile clear skipped => $error');
    }

    if (Get.isRegistered<DeviceIdentityService>()) {
      try {
        await DeviceIdentityService.to.clearDeviceSession();
      } catch (error) {
        debugPrint('⚠️ Device session clear skipped => $error');
      }
    }

    userProfile.value = UserProfile();
    userProfile.refresh();
  }

  Future<void> tryRegister() async {
    final data = {
      'name': registerName.text.trim(),
      'email': registerEmail.text.trim(),
      'phone': registerPhone.text.trim(),
      'address': registerAddress.text.trim(),
      'password': registerPassword.text.trim(),
      'profile_image': registerProfile_Image.text.trim(),
    };

    try {
      isLoading.value = true;

      final Map<String, String> headers =
      Get.isRegistered<DeviceIdentityService>()
          ? await DeviceIdentityService.to.headers()
          : <String, String>{'Accept': 'application/json'};

      final response = await _dio.post(
        kRegisterUrl,
        data: data,
        options: Options(
          headers: <String, dynamic>{
            ...headers,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Register success: ${response.data}');
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print('❌ Register error: $e');


    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ এই function receiver user এর FCM token backend এ save করবে
  /// Backend API:
  /// /api/getandupatedevicetoken/{userId}/{deviceToken}
  Future<void> saveFcmTokenToBackend({bool force = false}) async {
    if (_fcmSaving) {
      print('⚠️ FCM token save skipped: already running');
      return;
    }

    try {
      _fcmSaving = true;

      final int userId = userProfile.value.user?.id?.toInt() ?? 0;

      if (userId == 0) {
        print('❌ FCM token save skipped: userId empty');
        return;
      }

      final String? token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.trim().isEmpty) {
        print('❌ FCM token empty');
        return;
      }

      if (!force && _lastSavedFcmToken == token) {
        print('ℹ️ FCM token already saved, skipped');
        return;
      }


      final response = await _dio.get(
        getAndUpdateDeviceToken(
          userId: userId,
          deviceToken: token,
        ),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (userProfile.value.token != null &&
                userProfile.value.token.toString().isNotEmpty)
              'Authorization': 'Bearer ${userProfile.value.token}',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastSavedFcmToken = token;

      } else {
        print('⚠️ FCM token save failed: ${response.statusCode}');
      }
    } catch (e, s) {
      print('❌ FCM token save error: $e');
      print('$s');
    } finally {
      _fcmSaving = false;
    }
  }

  /// Installs the global account-block fallback on an existing Dio client.
  void configureProtectedDio(Dio dio) {
    final DeviceTokenProvider tokenProvider = () =>
        userProfile.value.token?.toString().trim();

    if (Get.isRegistered<AccountBlockService>()) {
      AccountBlockService.to.configureDio(
        dio,
        tokenProvider: tokenProvider,
      );
      return;
    }

    if (Get.isRegistered<DeviceIdentityService>()) {
      DeviceIdentityService.to.configureDio(
        dio,
        tokenProvider: tokenProvider,
      );
    }
  }

  /// Called by the shared Reverb socket when `.account.blocked` arrives.
  Future<void> handleAccountBlockedPayload(
      Map<String, dynamic> payload,
      ) async {
    if (!Get.isRegistered<AccountBlockService>()) return;
    await AccountBlockService.to.forceLogoutFromPayload(payload);
  }

  Future<void> handleDeviceBlockedPayload(
      Map<String, dynamic> payload,
      ) async {
    if (!Get.isRegistered<AccountBlockService>()) return;
    await AccountBlockService.to.forceLogoutFromPayload(payload);
  }

  Future<bool> syncDeviceSessionFromResponse(
      dynamic responseData,
      ) async {
    deviceSessionError.value = '';

    if (!Get.isRegistered<DeviceIdentityService>()) {
      deviceSessionError.value =
      'Device verification service is unavailable. Please restart the app.';
      return false;
    }

    try {
      final Map<String, dynamic> session =
      await DeviceIdentityService.to.requireValidAuthDeviceSession(
        responseData,
      );

      userProfile.value.deviceSession = DeviceSession.fromJson(session);
      userProfile.refresh();
      return true;
    } on DeviceBlockedLoginException catch (error) {
      userProfile.value = UserProfile();
      userProfile.refresh();

      if (Get.isRegistered<AccountBlockService>()) {
        await AccountBlockService.to.forceLogoutFromPayload(
          error.payload,
          assumeDeviceBlocked: true,
        );
      }
      return false;
    } on DeviceSessionValidationException catch (error) {
      deviceSessionError.value = error.message;
      userProfile.value = UserProfile();
      userProfile.refresh();
      return false;
    } catch (error) {
      deviceSessionError.value =
      'Device verification failed. Please restart the app and try again.';
      userProfile.value = UserProfile();
      userProfile.refresh();
      debugPrint('❌ Device session validation failed => $error');
      return false;
    }
  }

  Future<void> startAccountBlockSession() async {
    final int databaseUserId = userProfile.value.user?.id?.toInt() ?? 0;
    if (databaseUserId <= 0 ||
        !Get.isRegistered<AccountBlockService>()) {
      return;
    }
    await AccountBlockService.to.startAuthenticatedSession(
      databaseUserId: databaseUserId,
    );
  }

  Future<ForgotPasswordResult> sendForgotPasswordOtp({
    required String email,
  }) async {
    return _runForgotPasswordRequest(
      url: kForgetPasswordSendOtp,
      data: <String, dynamic>{
        'email': email.trim().toLowerCase(),
      },
      loading: forgotPasswordSendingOtp,
      fallbackSuccessMessage:
      'A verification code has been sent to your email.',
      fallbackErrorMessage:
      'We could not send the verification code. Please try again.',
    );
  }

  Future<ForgotPasswordResult> verifyForgotPasswordOtp({
    required String email,
    required String otp,
  }) async {
    return _runForgotPasswordRequest(
      url: kForgetPasswordVerifyOtp,
      data: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      },
      loading: forgotPasswordVerifyingOtp,
      fallbackSuccessMessage: 'Verification code confirmed successfully.',
      fallbackErrorMessage:
      'The verification code is invalid or has expired.',
    );
  }

  Future<ForgotPasswordResult> resetForgotPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    return _runForgotPasswordRequest(
      url: kForgetPasswordReset,
      data: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      loading: forgotPasswordResetting,
      fallbackSuccessMessage:
      'Your password has been reset successfully. You can now log in.',
      fallbackErrorMessage:
      'We could not reset your password. Please try again.',
    );
  }

  Future<ForgotPasswordResult> _runForgotPasswordRequest({
    required String url,
    required Map<String, dynamic> data,
    required RxBool loading,
    required String fallbackSuccessMessage,
    required String fallbackErrorMessage,
  }) async {
    if (loading.value) {
      return const ForgotPasswordResult(
        success: false,
        message: 'Please wait for the current request to finish.',
      );
    }

    try {
      loading.value = true;

      final Response<dynamic> response = await _dio.post<dynamic>(
        url,
        data: data,
        options: Options(
          headers: const <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      final int statusCode = response.statusCode ?? 0;
      final bool httpSuccess = statusCode >= 200 && statusCode < 300;
      final bool explicitlyFailed = _forgotPasswordPayloadFailed(response.data);
      final bool success = httpSuccess && !explicitlyFailed;

      return ForgotPasswordResult(
        success: success,
        message: _forgotPasswordMessage(
          response.data,
          fallback: success
              ? fallbackSuccessMessage
              : fallbackErrorMessage,
        ),
      );
    } on DioException catch (error) {
      final String message = _forgotPasswordMessage(
        error.response?.data,
        fallback: _dioForgotPasswordFallback(error),
      );

      return ForgotPasswordResult(success: false, message: message);
    } catch (error) {
      debugPrint('Forgot password request failed: $error');
      return ForgotPasswordResult(
        success: false,
        message: fallbackErrorMessage,
      );
    } finally {
      loading.value = false;
    }
  }

  bool _forgotPasswordPayloadFailed(dynamic payload) {
    if (payload is! Map) return false;

    final Map<String, dynamic> map = Map<String, dynamic>.from(payload);
    final dynamic success = map['success'];
    final dynamic status = map['status'];

    if (success == false || success == 0 || success?.toString() == '0') {
      return true;
    }

    if (status == false || status == 0 || status?.toString() == '0') {
      return true;
    }

    return false;
  }

  String _forgotPasswordMessage(
      dynamic payload, {
        required String fallback,
      }) {
    if (payload is String && payload.trim().isNotEmpty) {
      return payload.trim();
    }

    if (payload is! Map) return fallback;

    final Map<String, dynamic> map = Map<String, dynamic>.from(payload);

    for (final String key in <String>['message', 'error', 'detail']) {
      final String text = map[key]?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }

    final dynamic errors = map['errors'];
    if (errors is Map) {
      for (final dynamic value in errors.values) {
        if (value is List && value.isNotEmpty) {
          final String text = value.first?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
        }

        final String text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    }

    final dynamic nestedData = map['data'];
    if (nestedData is Map) {
      final String nestedMessage =
          nestedData['message']?.toString().trim() ?? '';
      if (nestedMessage.isNotEmpty) return nestedMessage;
    }

    return fallback;
  }

  String _dioForgotPasswordFallback(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network and try again.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

}