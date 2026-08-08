import 'package:get/get.dart';

import '../controllers/informationcollection_controller.dart';

class InformationcollectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InformationcollectionController>(
      () => InformationcollectionController(),
    );
  }
}
