import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/app/modules/rechage/views/rechage_view.dart';

import '../../../../constants/layout_constant.dart';
import 'RechargeList.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Reselar extends StatelessWidget {
  const Reselar({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              gradient: LinearGradient(
                colors: [
          kAppColor1,
                  kAppColor2
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          title: Text(
            ('Recharge').appTr,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white, // text color change for visibility
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              // width: Get.width * 0.5,
              decoration: BoxDecoration(color: Color(0xffffffff)),
              child: TabBar(
                isScrollable: true,
                indicatorColor: kAppColor1,
                labelColor: kAppColor1,
                unselectedLabelColor: Color(0xff0b0a0b),
                labelStyle: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    text: ('Reseller List').appTr,
                  ),
                  Tab(
                    text: ('Recharge Offer').appTr,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: kHeight * 0.01,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Popular Section
                  Rechargelist(),
                  // Party Section
                  RechageView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
