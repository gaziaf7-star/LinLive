import 'package:get/get.dart';

import '../controllers/registersteps_controller.dart';

class RegisterstepsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RegisterstepsController>(
      () => RegisterstepsController(),
    );
  }
}
