import 'package:get/get.dart';

import '../controllers/memberincome_controller.dart';

class MemberincomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MemberincomeController>(
      () => MemberincomeController(),
    );
  }
}
