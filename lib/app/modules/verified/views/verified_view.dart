import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/modules/verified/views/verify_page_2.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../accountInfornation/views/widget/CastomBtton.dart';
import '../controllers/verified_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class VerifiedView extends GetView<VerifiedController> {
  const VerifiedView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Account Verify').appTr,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Image(
                image: AssetImage(
                    'assets/audio_live/f86d41f1-a917-479e-bcdd-eb8bbaf96538-removebg-preview.png'),
                height: kHeight * 0.18,
              ),
            ),
            SizedBox(
              height: kHeight * 0.02,
            ),
            CastomAppButton(onPressed: () {
              Get.to(VerifyPage2(),transition: Transition.leftToRight);

              // homeController.showHostStatusList();
            }, buttonText: ('Apply Naw').appTr)
          ],
        ),
      ),
    );
  }
}
