import 'package:get/get.dart';

import '../controllers/store1_controller.dart';

class Store1Binding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<Store1Controller>(
      () => Store1Controller(),
    );
  }
}
