import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/trading/views/tarading.dart';
import 'package:meetlivepro/app/modules/trading/views/tradingsend.dart';

import '../../../../widgets/after/castom appbar.dart';
import '../controllers/trading_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class TradingView extends GetView<TradingController> {
  const TradingView({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomAppBar(
          title: ('Earning Coin').appTr,
        ),
        body: Column(
          children: [
            Container(
              // width: Get.width * 0.5,
              decoration: BoxDecoration(color: Color(0xffffffff)),
              child: TabBar(
                indicatorColor: Color(0xff050303),
                labelColor: Color(0xff050303),
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    text: ('Trading').appTr,
                  ),
                  Tab(
                    text: ('History').appTr,
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Popular Section
                  Tarading(),
                  // Party Section
                  Tradingsend(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
