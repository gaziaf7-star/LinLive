import 'package:get/get.dart';

import '../controllers/account_infornation_controller.dart';

class AccountInfornationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountInfornationController>(
      () => AccountInfornationController(),
    );
  }
}
