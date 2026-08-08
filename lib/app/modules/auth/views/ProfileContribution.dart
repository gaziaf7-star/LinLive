import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../constants/spinkit.dart';
import '../../../../widgets/after/customRankingcode.dart';
import '../../ranking/controllers/ranking_controller.dart';
import '../../ranking/views/ListVeiw.dart';
import '../../ranking/views/ranking_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Profilecontribution extends StatelessWidget {
  const Profilecontribution({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(RankingController());
    RankingController controller = Get.put(RankingController());
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff8A4CF7),
                  Color(0xffB460F0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Get.back(),
              ),
              centerTitle: true,
              title: Text(
                ('Contribution').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        body: Obx(() {
          return LoadingOverlay(
            isLoading: controller.isLoading.value,
            progressIndicator: kLoadingIndicator(),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xffb5a7fe), Color(0xffffffff)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Column(
                  children: [
                    // ---------------------Tabbar design --------------------
                    Container(
                      width: kWeight * 0.8,
                      margin: EdgeInsets.symmetric(
                          vertical: 10, horizontal: kWeight * 0.07),
                      // width: Get.width * 0.5,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Color(0xff8A4CF7)),
                      child: TabBar(
                        indicatorPadding:
                            const EdgeInsets.symmetric(horizontal: -34),
                        labelPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        indicator: BoxDecoration(
                          color: Colors.white, // Active tab background color
                          borderRadius: BorderRadius.circular(
                              20), // Optional: rounded tabs
                        ),
                        indicatorColor: Color(0xFF5cc87d),
                        labelColor: Color(0xff8A4CF7),
                        dividerColor: Color(0xFF5cc87d),
                        unselectedLabelColor: Colors.white,
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: [
                          Tab(text: ('Daily Ranking').appTr),
                          Tab(text: (' Over all Ranking').appTr),
                        ],
                      ),
                    ),
                    Text(
                      ('Countdown : 00 D 22 H 30 M 49 S ').appTr,
                      style: GoogleFonts.lato(
                          color: Color(0xff8A4CF7),
                          fontWeight: FontWeight.w500,
                          fontSize: 15),
                    ),
                    //-----------------------card design ---------------------
                    SizedBox(
                      height: 40,
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 18.0, vertical: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          //-------------------fast card ----------------------
                          Column(
                            children: [
                              CastonRankingcard(
                                coin: '',
                                profileImage: '',
                                pwidth: Get.width * 0.077,
                                fastColor: Color(0xFFe3dce3),
                                secondColor: Color(0xff8A4CF7),
                                height: Get.height * 0.13,
                                width: Get.width * 0.23,
                                bottomColor: Color(0xff8A4CF7),
                                rankText: '2',
                                name: '', backgroundImage: 'assets/new/rank2.png',
                              ),
                              SizedBox(
                                height: kHeight * 0.032,
                              ),
                              Obx(
                                () => InkWell(
                                  onTap: () {
                                    controller.isFollow.value =
                                        !controller.isFollow.value;
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: kWeight * 0.03),
                                    decoration: BoxDecoration(
                                        color: Color(0xff8A4CF7),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                            color: Color(0xff8A4CF7))),
                                    child: Text(
                                      controller.isFollow.value == true
                                          ? ('+ Follow ').appTr: ('Following').appTr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                          //-------------------2nd card ----------------------
                          Column(
                            children: [
                              CastonRankingcard(
                                coin: '',
                                profileImage: '',
                                pwidth: Get.width * 0.1,
                                fastColor: Color(0xff8A4CF7),
                                secondColor: Color(0xFFfec42a),
                                height: Get.height * 0.17,
                                width: Get.width * 0.29,
                                bottomColor: Color(0xFFfec42a),
                                rankText: '1',
                                name: '', backgroundImage: 'assets/new/rank1-removebg-preview.png',
                              ),
                              SizedBox(
                                height: kHeight * 0.032,
                              ),
                              Obx(
                                () => InkWell(
                                  onTap: () {
                                    controller.isFollow.value =
                                        !controller.isFollow.value;
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: kWeight * 0.03),
                                    decoration: BoxDecoration(
                                        color: Color(0xff8A4CF7),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                            color: Color(0xff8A4CF7))),
                                    child: Text(
                                      controller.isFollow.value == true
                                          ? ('+ Follow ').appTr: ('Following').appTr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),

                          //------------------3rd card ----------------

                          Column(
                            children: [
                              CastonRankingcard(
                                coin: '',
                                profileImage: '',
                                pwidth: Get.width * 0.076,
                                fastColor: Color(0xFFfdbca0),
                                secondColor: Color(0xFFff847d),
                                height: Get.height * 0.13,
                                width: Get.width * 0.23,
                                bottomColor: Color(0xFFff847d),
                                rankText: '3',
                                name: '', backgroundImage: 'assets/new/rankfastcard.png',
                              ),
                              SizedBox(
                                height: kHeight * 0.032,
                              ),
                              Obx(
                                () => InkWell(
                                  onTap: () {
                                    controller.isFollow.value =
                                        !controller.isFollow.value;
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: kWeight * 0.03),
                                    decoration: BoxDecoration(
                                        color: Color(0xff8A4CF7),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                            color: Color(0xff8A4CF7))),
                                    child: Text(
                                      controller.isFollow.value == true
                                          ? ('+ Follow ').appTr: ('Following').appTr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Popular Section
                          RankingList(),
                          // Party Section
                          RankingList(),

                          // Live Section

                          // Explore Section
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
