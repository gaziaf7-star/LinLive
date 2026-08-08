import 'package:get/get.dart';

import '../controllers/coinshop_controller.dart';

class CoinshopBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CoinshopController>(
      () => CoinshopController(),
    );
  }
}
