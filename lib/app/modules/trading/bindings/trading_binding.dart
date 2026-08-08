import 'package:get/get.dart';

import '../controllers/trading_controller.dart';

class TradingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TradingController>(
      () => TradingController(),
    );
  }
}
