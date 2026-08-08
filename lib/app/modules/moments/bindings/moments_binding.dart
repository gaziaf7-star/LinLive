import 'package:get/get.dart';

import '../controllers/moments_controller.dart';

class MomentsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MomentsController>(
      () => MomentsController(),
    );
  }
}
