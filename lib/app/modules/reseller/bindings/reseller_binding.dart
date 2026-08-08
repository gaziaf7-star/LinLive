import 'package:get/get.dart';

import '../controllers/reseller_controller.dart';

class ResellerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ResellerController>(
      () => ResellerController(),
    );
  }
}
