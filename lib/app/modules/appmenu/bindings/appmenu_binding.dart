import 'package:get/get.dart';

import '../controllers/appmenu_controller.dart';

class AppmenuBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppmenuController>(
      () => AppmenuController(),
    );
  }
}
