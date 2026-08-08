import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../informationcollection/views/informationcollection_view.dart';
import '../../verified/controllers/verified_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Createagency extends StatelessWidget {
  const Createagency({super.key});

  @override
  Widget build(BuildContext context) {
    VerifiedController verifiedController = Get.put(VerifiedController());
    verifiedController.showNewAgenctList();
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Creator Center').appTr,
      ),
      body: Column(
        children: [
          Center(
            child: InkWell(
              onTap: () {
                Get.to(InformationcollectionView(),
                    transition: Transition.rightToLeft);

                // Get.to(AgencyView());
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: kHeight * 0.02,
                ),
                margin: EdgeInsets.symmetric(
                    vertical: kHeight * 0.03, horizontal: kWeight * 0.04),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      kAppColor2,
                      kAppColor1
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            Color(0xff2c0375),
                            Color(0xff41026e),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          appLogo,
                          width: kHeight * 0.07,
                          height: kHeight * 0.07,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 6,
                    ),
                    Castontext(
                        fontWeight: FontWeight.w600,
                        fontSize: kHeight * 0.017,
                        textColor: Colors.white,
                        text: (' Apply for Creator Center').appTr),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
