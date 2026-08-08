import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../apis/api_endpoints.dart';
import '../../models/user_profile.dart';
import '../modules/auth/controllers/auth_controller.dart';
import '../modules/bottomnav/views/bottomnav_view.dart';
import '../modules/home/controllers/home_controller.dart';
import '../modules/livestream/controllers/websocket_controller.dart';
import '../modules/messanger/views/messages/components/firestore_service.dart';
import '../modules/registersteps/controllers/registersteps_controller.dart';
import 'account_block_service.dart';
import 'device_identity_service.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>['email', 'profile'],
  );

  static final firebase_auth.FirebaseAuth _auth =
      firebase_auth.FirebaseAuth.instance;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  /// Google Sign-In + backend login.
  ///
  /// The configured Dio interceptor automatically sends the stable device
  /// headers and centrally handles account/device block responses.
  static Future<void> signInWithGoogle() async {
    if (!Get.isRegistered<RegisterstepsController>() ||
        !Get.isRegistered<AuthController>()) {
      _showError(('Login service is not ready. Please reopen the app.').appTr);
      return;
    }

    final RegisterstepsController registerController =
    Get.find<RegisterstepsController>();
    final AuthController authController = Get.find<AuthController>();

    if (registerController.isLoading.value ||
        registerController.googleLoading.value) {
      return;
    }

    registerController.isLoading.value = true;
    registerController.googleLoading.value = true;

    try {
      // Adds X-Device-Id/device metadata and account/device block interceptors.
      authController.configureProtectedDio(_dio);

      // Force an account chooser instead of silently reusing a stale account.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the Google account chooser.
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final firebase_auth.OAuthCredential credential =
      firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final firebase_auth.UserCredential credentialResult =
      await _auth.signInWithCredential(credential);
      final firebase_auth.User? firebaseUser = credentialResult.user;

      if (firebaseUser == null) {
        _showError(('Google authentication failed.').appTr);
        return;
      }

      final String email =
      (firebaseUser.email ?? googleUser.email).trim();
      final String googleId = firebaseUser.uid.trim();
      final String googleToken =
      (googleAuth.accessToken ?? googleAuth.idToken ?? '').trim();

      if (email.isEmpty) {
        _showError(('Google email is unavailable.').appTr);
        return;
      }
      if (googleId.isEmpty) {
        _showError(('Google ID is unavailable.').appTr);
        return;
      }
      if (googleToken.isEmpty) {
        _showError(
          ('Google token is unavailable. Please try again.').appTr,
        );
        return;
      }

      final Map<String, dynamic> requestData = <String, dynamic>{
        'name': _firstNonEmpty(<String?>[
          firebaseUser.displayName,
          googleUser.displayName,
          'User',
        ]),
        'email': email,
        'profile_image_url': _cleanPhotoUrl(
          firebaseUser.photoURL ?? googleUser.photoUrl,
        ),
        'google_id': googleId,
        'google_token': googleToken,
      };

      // Never print google_token/access token in Logcat.
      debugPrint(
        '🔐 Google backend login => email=$email google_id=$googleId',
      );

      final Map<String, String> deviceHeaders =
      Get.isRegistered<DeviceIdentityService>()
          ? await DeviceIdentityService.to.headers()
          : <String, String>{'Accept': 'application/json'};

      final Response<dynamic> response = await _dio.post(
        kLoginGoogle,
        data: requestData,
        options: Options(
          headers: <String, dynamic>{
            ...deviceHeaders,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _showError(
          _serverMessage(response.data, ('Google login failed.').appTr),
        );
        return;
      }

      final Map<String, dynamic> responseData = _asMap(response.data);
      if (responseData.isEmpty) {
        _showError(('Invalid response from server.').appTr);
        return;
      }

      if (responseData['success'] == false) {
        _showError(
          _serverMessage(responseData, ('Google login failed.').appTr),
        );
        return;
      }

      final UserProfile profile = UserProfile.fromJson(responseData);
      final int databaseUserId = profile.user?.id?.toInt() ?? 0;
      final String token = profile.token?.toString().trim() ?? '';

      if (databaseUserId <= 0 || token.isEmpty) {
        _showError(
          _serverMessage(
            responseData,
            ('Google login response is incomplete.').appTr,
          ),
        );
        return;
      }

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

      await _saveProfileResponse(
        authController: authController,
        responseData: responseData,
      );

      // Save/update FCM token using the same protected device-aware Dio flow.
      await authController.saveFcmTokenToBackend(force: true);

      // Starts account block + device block authenticated realtime session.
      await authController.startAccountBlockSession();

      if (Get.isRegistered<WebsocketController>()) {
        final WebsocketController websocket =
        Get.find<WebsocketController>();

        await websocket.ensureRechargeRealtimeSubscription();
        await websocket.ensureAccountBlockRealtimeSubscription();
        await websocket.ensureDeviceBlockRealtimeSubscription();
      }

      if (!Get.isRegistered<FirestoreService>()) {
        Get.put(FirestoreService());
      }

      if (Get.isRegistered<HomeController>()) {
        try {
          Get.find<HomeController>().showActiveFrame();
        } catch (error) {
          debugPrint('⚠️ Active frame refresh skipped safely: $error');
        }
      }

      Fluttertoast.showToast(
        msg: ('Google Sign-In successful!').appTr,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Get.offAll(
            () => const BottomnavView(),
        transition: Transition.rightToLeft,
      );
    } on DioException catch (error) {
      // The global interceptor already navigates and shows the backend message
      // for account_blocked/device_blocked responses.
      if (Get.isRegistered<AccountBlockService>() &&
          AccountBlockService.to.handlingForceLogout) {
        return;
      }

      final int? statusCode = error.response?.statusCode;
      final Map<String, dynamic> body = _asMap(error.response?.data);
      final String action =
      (body['action_type'] ?? '').toString().trim().toLowerCase();

      String fallback = ('Google login failed. Please try again.').appTr;

      if (statusCode == 422 && action == 'device_id_required') {
        fallback =
            ('Device ID is required. Please restart the app and try again.')
                .appTr;
      } else if (statusCode == 422) {
        fallback = ('Validation error. Please check your data.').appTr;
      } else if (statusCode == 423 || action == 'device_blocked') {
        fallback =
            ('This device has been blocked by the administrator.').appTr;
      } else if (statusCode == 401 || statusCode == 403) {
        fallback = ('Authentication failed. Please try again.').appTr;
      } else if (statusCode != null && statusCode >= 500) {
        fallback = ('Server error. Please try again later.').appTr;
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        fallback =
            ('Connection timeout. Please check your internet connection.')
                .appTr;
      } else if (error.type == DioExceptionType.connectionError) {
        fallback =
            ('Network error. Please check your internet connection.').appTr;
      }

      _showError(_serverMessage(error.response?.data, fallback));
    } on firebase_auth.FirebaseAuthException catch (error) {
      final String message = switch (error.code) {
        'account-exists-with-different-credential' =>
        ('An account already exists with a different sign-in method.').appTr,
        'network-request-failed' =>
        ('Network error. Please check your internet connection.').appTr,
        'user-disabled' => ('This Google account is disabled.').appTr,
        _ => ('Google Sign-In failed. Please try again.').appTr,
      };
      _showError(message);
    } catch (error, stack) {
      debugPrint('❌ Google Sign-In error => $error');
      debugPrint('$stack');
      _showError(('Something went wrong during Google login.').appTr);
    } finally {
      registerController.isLoading.value = false;
      registerController.googleLoading.value = false;
    }
  }

  static Future<void> _saveProfileResponse({
    required AuthController authController,
    required Map<String, dynamic> responseData,
  }) async {
    final String encoded = jsonEncode(responseData);

    try {
      await authController.preferences.setString('profile', encoded);
      return;
    } catch (error) {
      debugPrint(
        '⚠️ StreamingSharedPreferences profile save fallback => $error',
      );
    }

    final SharedPreferences preferences =
    await SharedPreferences.getInstance();
    await preferences.setString('profile', encoded);
  }

  static String? _cleanPhotoUrl(String? raw) {
    String value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    value = value
        .replaceAll('`', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();

    final Uri? uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return null;
    }

    return value;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final String? raw in values) {
      final String value = raw?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'User';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      try {
        final dynamic decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static String _serverMessage(dynamic raw, String fallback) {
    final Map<String, dynamic> root = _asMap(raw);
    final Map<String, dynamic> data = _asMap(root['data']);

    final String message = <dynamic>[
      root['message'],
      root['error'],
      data['message'],
      data['error'],
    ]
        .map((dynamic value) => value?.toString().trim() ?? '')
        .firstWhere(
          (String value) =>
      value.isNotEmpty && value.toLowerCase() != 'null',
      orElse: () => '',
    );

    return message.isEmpty ? fallback : message;
  }

  static void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  /// Google/Firebase sign-out only.
  ///
  /// Application logout should continue using AccountBlockService.logoutManually
  /// so backend device login session, Sanctum token and private channels are
  /// cleaned correctly.
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('⚠️ Google sign-out skipped safely: $error');
    }

    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint('⚠️ Firebase sign-out skipped safely: $error');
    }
  }

  static Future<GoogleSignInAccount?> getCurrentUser() async {
    final firebase_auth.User? firebaseUser = _auth.currentUser;
    final GoogleSignInAccount? googleUser =
    await _googleSignIn.signInSilently();

    if (firebaseUser != null && googleUser != null) {
      return googleUser;
    }

    return null;
  }

  static Future<bool> isSignedIn() async {
    final bool googleSignedIn = await _googleSignIn.isSignedIn();
    return googleSignedIn && _auth.currentUser != null;
  }
}
