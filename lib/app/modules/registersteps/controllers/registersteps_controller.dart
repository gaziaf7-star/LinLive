import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../models/user_profile.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../services/account_block_service.dart';
import '../../../services/device_identity_service.dart';
import '../../auth/views/welcome_view.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../messanger/views/messages/components/firestore_service.dart';
import '../../livestream/controllers/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

enum InviteCodeValidationState { idle, checking, valid, invalid }

class RegisterstepsController extends GetxController {
  final isLoading = false.obs;

  final AuthController authController = Get.find<AuthController>();
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // Register controllers
  final nickNameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();
  final inviteCodeController = TextEditingController();

  final inviteCodeState = InviteCodeValidationState.idle.obs;
  final inviteCodeMessage = ''.obs;
  final inviteCodeError = RxnString();
  final inviterName = ''.obs;
  final inviterProfileImageUrl = ''.obs;
  final googleLoading = false.obs;

  Timer? _inviteValidationDebounce;
  CancelToken? _inviteValidationCancelToken;
  String _lastValidatedInviteCode = '';
  bool _registrationInProgress = false;

  // Register state
  final selectedGender = ''.obs;
  final dataOfBirth = ''.obs;
  final selected_language = ''.obs;
  final profile_image = ''.obs;
  final obscurePassword = true.obs;

  @override
  void onInit() {
    super.onInit();

    authController.configureProtectedDio(dio);

    Future<void>.microtask(_loadInitialInviteCode);
  }

  String get cleanInviteCode => inviteCodeController.text.trim();

  bool get hasInviteCode => cleanInviteCode.isNotEmpty;

  void onInviteCodeChanged(String value) {
    _inviteValidationDebounce?.cancel();
    _inviteValidationCancelToken?.cancel('Invite code changed');

    inviteCodeError.value = null;
    inviterName.value = '';
    inviterProfileImageUrl.value = '';
    _lastValidatedInviteCode = '';

    final code = value.trim();
    if (code.isEmpty) {
      inviteCodeState.value = InviteCodeValidationState.idle;
      inviteCodeMessage.value = '';
      _savePendingInviteCode('');
      return;
    }

    inviteCodeState.value = InviteCodeValidationState.idle;
    inviteCodeMessage.value = ('Checking invite code...').appTr;
    _savePendingInviteCode(code);

    _inviteValidationDebounce = Timer(
      const Duration(milliseconds: 450),
          () => validateInviteCode(silent: true),
    );
  }

  Future<bool?> validateInviteCode({bool silent = false}) async {
    final code = cleanInviteCode;
    if (code.isEmpty) {
      inviteCodeState.value = InviteCodeValidationState.idle;
      inviteCodeMessage.value = '';
      inviteCodeError.value = null;
      return true;
    }

    _inviteValidationCancelToken?.cancel('Starting another validation');
    final cancelToken = CancelToken();
    _inviteValidationCancelToken = cancelToken;

    inviteCodeState.value = InviteCodeValidationState.checking;
    inviteCodeError.value = null;
    inviteCodeMessage.value = ('Checking invite code...').appTr;

    try {
      final response = await dio.get(
        '$_inviteValidationBaseUrl/${Uri.encodeComponent(code)}',
        options: Options(headers: const {'Accept': 'application/json'}),
        cancelToken: cancelToken,
      );

      final body = _asMap(response.data);
      final data = _asMap(body['data']);
      final valid = _truthy(
        data['valid'] ?? body['valid'] ?? body['success'],
      );

      if (!valid) {
        final message = _apiMessage(body, ('Invalid invite code.').appTr);
        _setInviteInvalid(message, code: code);
        if (!silent) _showError(message);
        return false;
      }

      final inviter = _asMap(data['inviter']);
      inviterName.value = inviter['name']?.toString().trim() ?? '';
      inviterProfileImageUrl.value =
          inviter['profile_image_url']?.toString().trim() ??
              inviter['profile_image']?.toString().trim() ??
              '';
      _lastValidatedInviteCode = code;
      inviteCodeState.value = InviteCodeValidationState.valid;
      inviteCodeError.value = null;
      inviteCodeMessage.value = inviterName.value.isEmpty
          ? ('Invite code is valid.').appTr
          : '${('Invited by').appTr} ${inviterName.value}';
      await _savePendingInviteCode(code);
      return true;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;

      if (e.response?.statusCode == 422 || e.response?.statusCode == 404) {
        final body = _asMap(e.response?.data);
        final message = _firstError(body, const [
          'invite_code',
          'code',
          'reffer_by',
          'referral_code',
        ]) ??
            _apiMessage(body, ('Invalid invite code.').appTr);
        _setInviteInvalid(message, code: code);
        if (!silent) _showError(message);
        return false;
      }

      inviteCodeState.value = InviteCodeValidationState.idle;
      inviteCodeError.value = null;
      inviteCodeMessage.value =
          ('Could not validate now. Registration will verify the code securely.')
              .appTr;
      return null;
    } catch (_) {
      inviteCodeState.value = InviteCodeValidationState.idle;
      inviteCodeError.value = null;
      inviteCodeMessage.value =
          ('Could not validate now. Registration will verify the code securely.')
              .appTr;
      return null;
    }
  }

  Future<void> setPendingInviteCode(String? rawValue) async {
    final code = _extractInviteCode(rawValue);
    if (code.isEmpty) return;

    inviteCodeController.text = code;
    inviteCodeController.selection = TextSelection.collapsed(
      offset: inviteCodeController.text.length,
    );
    await _savePendingInviteCode(code);
    onInviteCodeChanged(code);
  }

  void selectGender(String gender) {
    selectedGender.value = gender;
  }

  bool isGenderSelected(String gender) {
    return selectedGender.value == gender;
  }

  void togglePassword() {
    obscurePassword.value = !obscurePassword.value;
  }

  void setDateOfBirth(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    dataOfBirth.value = '$year-$month-$day';
  }

  Future<void> singleFilePicker() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      profile_image.value = result.files.single.path!;
    } catch (e) {
      Fluttertoast.showToast(
        msg: ("Image select failed").appTr,

      );
    }
  }

  bool _isValidEmail(String email) {
    return GetUtils.isEmail(email.trim());
  }

  Future<void> tryToSignUp() async {
    if (_registrationInProgress || isLoading.value) return;
    _registrationInProgress = true;

    try {
      final name = nickNameController.text.trim();
      final email = emailController.text.trim();
      final phone = phoneNumberController.text.trim();
      final password = passwordController.text;
      final inviteCode = cleanInviteCode;

      inviteCodeError.value = null;

      if (profile_image.value.isEmpty) {
        _showError(('Please select profile image').appTr);
        return;
      }

      if (selected_language.value.isEmpty) {
        _showError(('Please select country').appTr);
        return;
      }

      if (name.isEmpty) {
        _showError(('Please enter nickname').appTr);
        return;
      }

      if (selectedGender.value.isEmpty) {
        _showError(('Please select gender').appTr);
        return;
      }

      if (dataOfBirth.value.isEmpty) {
        _showError(('Please select date of birth').appTr);
        return;
      }

      if (phone.isEmpty) {
        _showError(('Please enter phone number').appTr);
        return;
      }

      if (email.isEmpty || !_isValidEmail(email)) {
        _showError(('Please enter valid email').appTr);
        return;
      }

      if (password.length < 6) {
        _showError(('Password must be at least 6 characters').appTr);
        return;
      }

      if (inviteCode.isNotEmpty) {
        final alreadyInvalid =
            inviteCodeState.value == InviteCodeValidationState.invalid &&
                _lastValidatedInviteCode == inviteCode;
        if (alreadyInvalid) {
          _showError(
            inviteCodeError.value ?? ('Invalid invite code.').appTr,
          );
          return;
        }

        final alreadyValid =
            inviteCodeState.value == InviteCodeValidationState.valid &&
                _lastValidatedInviteCode == inviteCode;
        if (!alreadyValid) {
          final validation = await validateInviteCode(silent: true);
          if (validation == false) {
            _showError(
              inviteCodeError.value ?? ('Invalid invite code.').appTr,
            );
            return;
          }
        }
      }

      isLoading.value = true;

      final formMap = <String, dynamic>{
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'gender': selectedGender.value,
        'dateofbirth': dataOfBirth.value,
        'country': selected_language.value,
        if (addressController.text.trim().isNotEmpty)
          'address': addressController.text.trim(),
        if (inviteCode.isNotEmpty) 'invite_code': inviteCode,
        'profile_image': await MultipartFile.fromFile(
          profile_image.value,
          filename: profile_image.value.split(RegExp(r'[/\\]')).last,
        ),
      };

      final Map<String, String> deviceHeaders =
      Get.isRegistered<DeviceIdentityService>()
          ? await DeviceIdentityService.to.headers()
          : <String, String>{'Accept': 'application/json'};

      final response = await dio.post(
        kRegisterUrl,
        data: FormData.fromMap(formMap),
        options: Options(headers: deviceHeaders),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _showError(('Register failed').appTr);
        return;
      }

      final responseData = _asMap(response.data);
      authController.userProfile.value = UserProfile.fromJson(responseData);
      authController.userProfile.refresh();

      final bool deviceSessionAccepted =
      await authController.syncDeviceSessionFromResponse(responseData);
      if (!deviceSessionAccepted) {
        if (!Get.isRegistered<AccountBlockService>() ||
            !AccountBlockService.to.handlingForceLogout) {
          _showError(
            authController.deviceSessionError.value.isEmpty
                ? ('Device verification failed.').appTr
                : authController.deviceSessionError.value,
          );
        }
        return;
      }

      await authController.preferences.setString(
        'profile',
        jsonEncode(authController.userProfile.value.toJson()),
      );
      await _clearPendingInviteCode();

      createDeviceToken();
      await _startAuthenticatedRealtimeAfterAuth();
      _ensureRechargeRealtimeAfterAuth();

      Fluttertoast.showToast(
        msg: _registrationSuccessMessage(responseData),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Get.offAll(
            () => const BottomnavView(),
        transition: Transition.rightToLeft,
      );
    } on DioException catch (e) {
      _handleRegistrationDioError(e);
    } catch (e) {
      debugPrint('Registration error: $e');
      _showError(('Something went wrong').appTr);
    } finally {
      isLoading.value = false;
      _registrationInProgress = false;
    }
  }

  //---------------------------------- login ---------------

  final loginPhone = TextEditingController();
  final loginPassword = TextEditingController();

  final loginPhoneText = ''.obs;
  final loginPasswordText = ''.obs;

  final loginPhoneError = RxnString();
  final loginPasswordError = RxnString();
  final loginObscurePassword = true.obs;

  void toggleLoginPassword() {
    loginObscurePassword.value = !loginObscurePassword.value;
  }

  void onPhoneChanged(String value) {
    loginPhoneText.value = value;
    loginPhoneError.value = null;
  }

  void onPasswordChanged(String value) {
    loginPasswordText.value = value;
    loginPasswordError.value = null;
  }

  void tryToSignIn() async {
    isLoading.value = true;

    final phone = loginPhone.text.trim();
    final password = loginPassword.text.trim();

    loginPhoneError.value = null;
    loginPasswordError.value = null;

    if (phone.isEmpty) {
      loginPhoneError.value = "Please enter phone number";
      isLoading.value = false;
      return;
    }

    if (password.isEmpty) {
      loginPasswordError.value = "Please enter password";
      isLoading.value = false;
      return;
    }

    try {
      final data = {
        'phone': phone,
        'password': password,
      };

      final Map<String, String> deviceHeaders =
      Get.isRegistered<DeviceIdentityService>()
          ? await DeviceIdentityService.to.headers()
          : <String, String>{'Accept': 'application/json'};

      final response = await dio.post(
        kLoginUrl,
        data: data,
        options: Options(
          headers: <String, dynamic>{
            ...deviceHeaders,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data is String
            ? jsonDecode(response.data)
            : response.data;

        final profile = UserProfile.fromJson(responseData);

        authController.userProfile.value = profile;
        authController.userProfile.refresh();

        final bool deviceSessionAccepted =
        await authController.syncDeviceSessionFromResponse(responseData);
        if (!deviceSessionAccepted) {
          if (!Get.isRegistered<AccountBlockService>() ||
              !AccountBlockService.to.handlingForceLogout) {
            _showError(
              authController.deviceSessionError.value.isEmpty
                  ? ('Device verification failed.').appTr
                  : authController.deviceSessionError.value,
            );
          }
          return;
        }

        await authController.preferences.setString(
          'profile',
          jsonEncode(authController.userProfile.value.toJson()),
        );

        createDeviceToken();
        await _startAuthenticatedRealtimeAfterAuth();
        _ensureRechargeRealtimeAfterAuth();

        Get.offAll(
              () => const BottomnavView(),
          transition: Transition.rightToLeft,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Invalid credentials").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      if (Get.isRegistered<AccountBlockService>() &&
          AccountBlockService.to.handlingForceLogout) {
        return;
      }

      final Map<String, dynamic> body = _asMap(e.response?.data);
      _showError(
        _apiMessage(
          body,
          e.response?.statusCode == 422
              ? ('Device ID is required for login.').appTr
              : ('Invalid credentials').appTr,
        ),
      );
    } catch (e) {
      if (Get.isRegistered<AccountBlockService>() &&
          AccountBlockService.to.handlingForceLogout) {
        return;
      }

      _showError(('Something went wrong').appTr);
    } finally {
      isLoading.value = false;
    }
  }

  void createDeviceToken() async {
    try {
      final deviceToken = await FirebaseMessaging.instance.getToken();

      final userId = authController.userProfile.value.user?.id;
      if (deviceToken == null || userId == null) return;

      final response = await dio.get(
        getAndUpdateDeviceToken(
          userId: userId.toInt(),
          deviceToken: deviceToken,
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('Device token created');
      } else {
        debugPrint('Device token creation failed');
      }
    } catch (e) {
      debugPrint('Device token error: $e');
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<void> googleSign({String? inviteCode}) async {
    if (googleLoading.value || isLoading.value) return;
    googleLoading.value = true;

    try {
      final code = (inviteCode ?? cleanInviteCode).trim();

      if (code.isNotEmpty) {
        final alreadyValid =
            inviteCodeState.value == InviteCodeValidationState.valid &&
                _lastValidatedInviteCode == code;
        if (!alreadyValid && code == cleanInviteCode) {
          final validation = await validateInviteCode(silent: true);
          if (validation == false) {
            _showError(
              inviteCodeError.value ?? ('Invalid invite code.').appTr,
            );
            return;
          }
        }
      }

      await _googleSignIn.signOut();
      final GoogleSignInAccount? result = await _googleSignIn.signIn();
      if (result == null) return;

      final GoogleSignInAuthentication googleAuth =
      await result.authentication;
      final String googleToken =
      (googleAuth.accessToken ?? googleAuth.idToken ?? '').trim();

      if (googleToken.isEmpty) {
        _showError(('Google token is unavailable. Please try again.').appTr);
        return;
      }

      final data = <String, dynamic>{
        'name': result.displayName ?? 'User',
        'email': result.email,
        'profile_image_url': result.photoUrl,
        'google_id': result.id,
        'google_token': googleToken,
        if (code.isNotEmpty) 'invite_code': code,
      };

      final Map<String, String> deviceHeaders =
      Get.isRegistered<DeviceIdentityService>()
          ? await DeviceIdentityService.to.headers()
          : <String, String>{'Accept': 'application/json'};

      final response = await dio.post(
        kLoginGoogle,
        data: data,
        options: Options(
          headers: <String, dynamic>{
            ...deviceHeaders,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _showError(('Google login failed.').appTr);
        return;
      }

      final responseData = _asMap(response.data);
      authController.userProfile.value = UserProfile.fromJson(responseData);
      authController.userProfile.refresh();

      final bool deviceSessionAccepted =
      await authController.syncDeviceSessionFromResponse(responseData);
      if (!deviceSessionAccepted) {
        if (!Get.isRegistered<AccountBlockService>() ||
            !AccountBlockService.to.handlingForceLogout) {
          _showError(
            authController.deviceSessionError.value.isEmpty
                ? ('Device verification failed.').appTr
                : authController.deviceSessionError.value,
          );
        }
        return;
      }

      await authController.preferences.setString(
        'profile',
        jsonEncode(authController.userProfile.value.toJson()),
      );
      await _clearPendingInviteCode();

      createDeviceToken();
      await _startAuthenticatedRealtimeAfterAuth();
      _ensureRechargeRealtimeAfterAuth();
      if (!Get.isRegistered<FirestoreService>()) {
        Get.put(FirestoreService());
      }

      Fluttertoast.showToast(
        msg: _registrationSuccessMessage(responseData),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Get.offAll(
            () => const BottomnavView(),
        transition: Transition.rightToLeft,
      );
    } on DioException catch (e) {
      _handleRegistrationDioError(e);
    } catch (error) {
      debugPrint('Google sign-in error: $error');
      _showError(('Something went wrong during Google login.').appTr);
    } finally {
      googleLoading.value = false;
    }
  }

  Future<void> _startAuthenticatedRealtimeAfterAuth() async {
    final int databaseUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (databaseUserId <= 0 ||
        !Get.isRegistered<AccountBlockService>()) {
      return;
    }

    await AccountBlockService.to.startAuthenticatedSession(
      databaseUserId: databaseUserId,
    );
  }

  void _ensureRechargeRealtimeAfterAuth() {
    void subscribePrivateChannels() {
      if (!Get.isRegistered<WebsocketController>()) return;
      final WebsocketController websocket =
      Get.find<WebsocketController>();
      websocket.ensureRechargeRealtimeSubscription();
      websocket.ensureAccountBlockRealtimeSubscription();
      websocket.ensureDeviceBlockRealtimeSubscription();
    }

    Future<void>.delayed(
      const Duration(milliseconds: 250),
      subscribePrivateChannels,
    );

    /// Bottom navigation/bindings may finish mounting just after navigation.
    /// This is a local retry only; it does not create a second socket.
    Future<void>.delayed(
      const Duration(seconds: 2),
      subscribePrivateChannels,
    );
  }

  void tryToSignOut() async {
    if (Get.isRegistered<AccountBlockService>()) {
      await AccountBlockService.to.logoutManually();
      return;
    }

    if (Get.isRegistered<WebsocketController>()) {
      final WebsocketController websocket =
      Get.find<WebsocketController>();
      await websocket.disconnectDeviceBlockRealtime();
      await websocket.disconnectAccountBlockRealtime();
      await websocket.disconnectRechargeRealtime();
    }

    await authController.preferences.clear();
    if (Get.isRegistered<DeviceIdentityService>()) {
      await DeviceIdentityService.to.clearDeviceSession();
    }
    authController.userProfile.value = UserProfile();
    authController.userProfile.refresh();

    Get.offAll(
          () => WelcomeView(),
      transition: Transition.leftToRightWithFade,
    );
  }

  String get _inviteValidationBaseUrl {
    final domain = kDomainUrl.toString().trim().replaceAll(RegExp(r'/+$'), '');
    return '$domain/api/invite/validate-code';
  }

  Future<void> _loadInitialInviteCode() async {
    String code = _extractInviteCode(Get.arguments);

    if (code.isEmpty) {
      final parameters = Map<String, dynamic>.from(Get.parameters);
      code = _extractInviteCode(parameters);
    }

    if (code.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      code = prefs.getString('pending_invite_code')?.trim() ?? '';
    }

    if (code.isNotEmpty) {
      inviteCodeController.text = code;
      inviteCodeController.selection = TextSelection.collapsed(
        offset: code.length,
      );
      onInviteCodeChanged(code);
    }
  }

  String _extractInviteCode(dynamic source) {
    if (source == null) return '';

    if (source is Map) {
      for (final key in const [
        'invite_code',
        'referral_code',
        'reffer_by',
        'code',
        'inviteLink',
        'invite_link',
        'uri',
        'url',
      ]) {
        final value = source[key];
        final parsed = _extractInviteCode(value);
        if (parsed.isNotEmpty) return parsed;
      }
      return '';
    }

    final raw = source.toString().trim();
    if (raw.isEmpty || raw == 'null') return '';

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      for (final key in const [
        'invite_code',
        'referral_code',
        'reffer_by',
        'code',
      ]) {
        final value = uri.queryParameters[key]?.trim() ?? '';
        if (value.isNotEmpty) return value;
      }

      final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).toList();
      final inviteIndex = segments.indexWhere(
            (segment) => segment.toLowerCase() == 'invite',
      );
      if (inviteIndex >= 0 && inviteIndex + 1 < segments.length) {
        return Uri.decodeComponent(segments[inviteIndex + 1]).trim();
      }

      if ((uri.hasScheme || raw.contains('/')) && segments.isNotEmpty) {
        final last = Uri.decodeComponent(segments.last).trim();
        if (last.isNotEmpty && last.toLowerCase() != 'invite') return last;
      }
    }

    if (!raw.contains('/') && !raw.contains('?') && !raw.contains('=')) {
      return raw;
    }

    return '';
  }

  Future<void> _savePendingInviteCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = code.trim();
    if (clean.isEmpty) {
      await prefs.remove('pending_invite_code');
    } else {
      await prefs.setString('pending_invite_code', clean);
    }
  }

  Future<void> _clearPendingInviteCode() async {
    _inviteValidationDebounce?.cancel();
    _inviteValidationCancelToken?.cancel('Registration completed');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_invite_code');
  }

  void _setInviteInvalid(String message, {required String code}) {
    _lastValidatedInviteCode = code;
    inviteCodeState.value = InviteCodeValidationState.invalid;
    inviteCodeError.value = message;
    inviteCodeMessage.value = '';
    inviterName.value = '';
    inviterProfileImageUrl.value = '';
  }

  void _handleRegistrationDioError(DioException error) {
    final body = _asMap(error.response?.data);
    final inviteError = _firstError(body, const [
      'invite_code',
      'referral_code',
      'reffer_by',
    ]);

    if (error.response?.statusCode == 422 && inviteError != null) {
      _setInviteInvalid(inviteError, code: cleanInviteCode);
      _showError(inviteError);
      return;
    }

    final message = _firstError(body, const []) ??
        _apiMessage(body, ('Something went wrong').appTr);
    _showError(message);
  }

  String? _firstError(
      Map<String, dynamic> body,
      List<String> preferredKeys,
      ) {
    final errors = body['errors'];
    if (errors is! Map) return null;

    for (final key in preferredKeys) {
      final message = _errorValueToString(errors[key]);
      if (message != null) return message;
    }

    for (final value in errors.values) {
      final message = _errorValueToString(value);
      if (message != null) return message;
    }
    return null;
  }

  String? _errorValueToString(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final message = value.first?.toString().trim() ?? '';
      return message.isEmpty ? null : message;
    }
    final message = value?.toString().trim() ?? '';
    return message.isEmpty ? null : message;
  }

  String _apiMessage(Map<String, dynamic> body, String fallback) {
    final message = body['message'] ?? body['error'];
    final clean = message?.toString().trim() ?? '';
    return clean.isEmpty ? fallback : clean;
  }

  String _registrationSuccessMessage(Map<String, dynamic> responseData) {
    final inviteApplied = _truthy(responseData['invite_applied']);
    final reward = _toInt(responseData['invite_reward_coins']);

    if (inviteApplied && reward > 0) {
      return '${('Register successful. Invite applied.').appTr} '
          '${('Inviter received').appTr} $reward ${('coins').appTr}.';
    }
    if (inviteApplied) {
      return ('Register successful. Invite code applied.').appTr;
    }

    return _apiMessage(responseData, ('Register Success').appTr);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final clean = value?.toString().trim().toLowerCase() ?? '';
    return clean == '1' || clean == 'true' || clean == 'yes' || clean == 'success';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  bool _authRefreshInProgress = false;
  DateTime? _lastAuthRefreshAt;

  /// Refreshes the logged-in user's latest server data without creating
  /// duplicate requests. Existing callers can still use refreshAuthUserData()
  /// without any arguments.
  Future<bool> refreshAuthUserData({
    bool force = false,
    Duration minInterval = const Duration(seconds: 5),
    bool persist = true,
  }) async {
    final String token =
        authController.userProfile.value.token?.toString().trim() ?? '';

    if (token.isEmpty || _authRefreshInProgress) {
      return false;
    }

    final now = DateTime.now();
    final lastRefresh = _lastAuthRefreshAt;

    if (!force &&
        lastRefresh != null &&
        now.difference(lastRefresh) < minInterval) {
      return true;
    }

    _authRefreshInProgress = true;

    try {
      final response = await dio.get(
        kAuthUser,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
        ),
      );

      final dynamic responseData = response.data;
      if (response.statusCode != 200 ||
          responseData is! Map ||
          responseData['success'] != true ||
          responseData['user'] is! Map) {
        return false;
      }

      final currentProfile = authController.userProfile.value;
      final userJson = Map<String, dynamic>.from(responseData['user'] as Map);
      final updatedUser = User.fromJson(userJson);

      final assetHistories = userJson['asset_histories'] != null
          ? AssetHistories.fromJson(userJson['asset_histories'])
          : currentProfile.assetHistories;

      final entryHistories = userJson['entry_histories'] != null
          ? EntryHistories.fromJson(userJson['entry_histories'])
          : currentProfile.entryHistories;

      final vipHistories = userJson['vip_histories'] != null
          ? VipHistories.fromJson(userJson['vip_histories'])
          : currentProfile.vipHistories;

      authController.userProfile.value = UserProfile(
        success: currentProfile.success,
        message: currentProfile.message,
        token: currentProfile.token,
        user: updatedUser,
        totalFollowers:
        userJson['total_followers'] ?? currentProfile.totalFollowers,
        totalFollowing:
        userJson['total_following'] ?? currentProfile.totalFollowing,
        assetHistories: assetHistories,
        entryHistories: entryHistories,
        vipHistories: vipHistories,
        deviceSession: currentProfile.deviceSession,
      );

      authController.userProfile.refresh();
      _lastAuthRefreshAt = DateTime.now();

      // Periodic live balance checks can skip disk writes. Normal refreshes
      // still persist the latest profile by default.
      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'profile',
          jsonEncode(authController.userProfile.value.toJson()),
        );
      }

      return true;
    } on DioException catch (e) {
      debugPrint(
        'Auth refresh failed: ${e.response?.statusCode ?? e.type}',
      );
      return false;
    } catch (e) {
      debugPrint('Error refreshing auth user data: $e');
      return false;
    } finally {
      _authRefreshInProgress = false;
    }
  }

  @override
  void onClose() {
    nickNameController.dispose();
    phoneNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    addressController.dispose();
    inviteCodeController.dispose();
    _inviteValidationDebounce?.cancel();
    _inviteValidationCancelToken?.cancel('Controller closed');

    loginPhone.dispose();
    loginPassword.dispose();

    super.onClose();
  }
}