import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';


import '../../store/views/store_tabber_view/FollowingList.dart';
import 'friend_giftSent.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class GiftSentFriend extends StatelessWidget {
  const GiftSentFriend({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,

          flexibleSpace: Container(
            decoration:  BoxDecoration(
              gradient: LinearGradient(
                colors: [
                kAppColor1,
                  kAppColor2
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.lato(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs:  [
              Tab(text: ('Follower').appTr),
              Tab(text: ('Following').appTr),
            ],
          ),

          leading: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
            ),
          ),

          title: Text(
            ('Select gift object').appTr,
            style: GoogleFonts.lato(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  // Popular Section

                  // Party Section
                  GiftFollowerList(),
                  GiftFollowinglist(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
