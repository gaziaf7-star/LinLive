import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/views/welcome_view.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../messanger/views/messages/components/firestore_service.dart';
import '../../registersteps/controllers/registersteps_controller.dart';

class SplashController extends GetxController {
  bool _startupStarted = false;
  bool _navigationDone = false;

  AuthController get _authController => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ SplashController onInit');
  }

  @override
  void onReady() {
    super.onReady();
    debugPrint('✅ SplashController onReady');

    if (_startupStarted) return;
    _startupStarted = true;
    unawaited(_resolveStartupRoute());
  }

  Future<void> _resolveStartupRoute() async {
    final DateTime splashStartedAt = DateTime.now();
    bool authenticated = false;

    try {
      // Wait for SharedPreferences/profile restore instead of guessing that
      // every phone will finish it within a fixed 3-second delay.
      await _authController.initialize().timeout(
        const Duration(seconds: 8),
      );

      authenticated =
      await _authController.validateStoredSessionForStartup();
    } on TimeoutException catch (error) {
      debugPrint('⚠️ Splash startup timeout => $error');
      authenticated = false;
    } catch (error, stackTrace) {
      debugPrint('❌ Splash startup failed => $error');
      debugPrint('$stackTrace');
      authenticated = false;
    }

    _authController.markStartupGateFinished();

    // Keep the logo visible briefly, but never use this delay as auth logic.
    final Duration elapsed = DateTime.now().difference(splashStartedAt);
    const Duration minimumSplashTime = Duration(milliseconds: 1200);
    if (elapsed < minimumSplashTime) {
      await Future<void>.delayed(minimumSplashTime - elapsed);
    }

    if (_navigationDone) return;
    _navigationDone = true;

    try {
      if (authenticated && _authController.hasUsableToken) {
        if (!Get.isRegistered<FirestoreService>()) {
          Get.lazyPut<FirestoreService>(
                () => FirestoreService(),
            fenix: true,
          );
        }

        if (!Get.isRegistered<RegisterstepsController>()) {
          Get.lazyPut<RegisterstepsController>(
                () => RegisterstepsController(),
            fenix: true,
          );
        }

        debugPrint('✅ Splash route => BottomnavView');
        Get.offAll(
              () => BottomnavView(),
          transition: Transition.fadeIn,
        );
        return;
      }

      debugPrint('🔐 Splash route => WelcomeView');
      Get.offAll(
            () => const WelcomeView(),
        transition: Transition.fadeIn,
      );
    } catch (error, stackTrace) {
      debugPrint('❌ Splash navigation error => $error');
      debugPrint('$stackTrace');

      // A dependency/navigation exception must not leave the app stuck on logo.
      await _authController.clearStoredAuthSession();
      Get.offAll(
            () => const WelcomeView(),
        transition: Transition.fadeIn,
      );
    }
  }
}
