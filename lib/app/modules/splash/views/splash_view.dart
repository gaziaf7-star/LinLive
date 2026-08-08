import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/image_const/image_conost.dart';
import '../controllers/splash_controller.dart';

/// SplashController must be registered explicitly.
/// Extending GetView<SplashController> alone does not create the controller.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<SplashController>()) {
      Get.put<SplashController>(SplashController());
      debugPrint('✅ SplashController registered from SplashView');
    } else {
      // Touch the existing controller so the route uses the registered instance.
      Get.find<SplashController>();
      debugPrint('ℹ️ SplashController already registered');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              appLogo,
              height: Get.height * 0.12,
              width: Get.height * 0.12,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('❌ Splash logo load error => $error');
                return const SizedBox(
                  width: 72,
                  height: 72,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
