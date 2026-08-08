import 'package:get/get.dart';

import '../controllers/messanger_controller.dart';

class MessangerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MessangerController>(
      () => MessangerController(),
    );
  }
}
