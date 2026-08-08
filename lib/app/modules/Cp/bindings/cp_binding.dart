import 'package:get/get.dart';

import '../controllers/cp_controller.dart';

class CpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CpController>(
      () => CpController(),
    );
  }
}
