import 'package:get/get.dart';

import '../controllers/verified_controller.dart';

class VerifiedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VerifiedController>(
      () => VerifiedController(),
    );
  }
}
