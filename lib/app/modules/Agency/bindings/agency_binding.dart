import 'package:get/get.dart';

import '../controllers/agency_controller.dart';

class AgencyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AgencyController>(
      () => AgencyController(),
    );
  }
}
