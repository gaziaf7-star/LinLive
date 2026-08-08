import 'package:get/get.dart';

import '../controllers/svip_controller.dart';

class SvipBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SvipController>(
      () => SvipController(),
    );
  }
}
