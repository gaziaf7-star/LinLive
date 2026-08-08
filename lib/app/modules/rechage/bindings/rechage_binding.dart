import 'package:get/get.dart';

import '../controllers/rechage_controller.dart';

class RechageBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RechageController>(
      () => RechageController(),
    );
  }
}
