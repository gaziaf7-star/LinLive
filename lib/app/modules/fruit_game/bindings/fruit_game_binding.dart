import 'package:get/get.dart';

import '../controllers/fruit_game_controller.dart';

class FruitGameBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FruitGameController>(
      () => FruitGameController(),
    );
  }
}
