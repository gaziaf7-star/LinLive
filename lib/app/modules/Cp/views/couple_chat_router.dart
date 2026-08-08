import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../messanger/views/chatpage_view.dart';
import '../controllers/cp_data_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CoupleChatRouter extends StatelessWidget {
  const CoupleChatRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final CpDataController cpController = Get.isRegistered<CpDataController>()
        ? Get.find<CpDataController>()
        : Get.put(CpDataController());

    Future.microtask(() {
      cpController.fetchCpData(showLoader: false);
    });

    return Obx(() {
      final cp = cpController.acceptedCp;

      if (cpController.isLoading.value && cp == null) {
        return  CpLoadingPage(title: ('Couple Chat').appTr);
      }

      if (cp == null) {
        return CpNoAcceptedView(
          title: ('Couple Chat').appTr,
          onRefresh: () => cpController.fetchCpData(),
        );
      }

      final partner = cp.partner;
      final me = cp.me;

      return ChatPage(
        receiverId: '${partner.userId}',
        receiverName: partner.name.isEmpty ? 'CP Partner' : partner.name,
        receiverImage: partner.profileImage,
        isCoupleChat: true,
        cpMyImage: me.profileImage,
        cpPartnerImage: partner.profileImage,
        cpSinceText: cp.sinceFullDate,
        cpDays: cp.daysTogether,
      );
    });
  }
}
