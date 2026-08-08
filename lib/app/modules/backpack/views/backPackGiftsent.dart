import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'backPackFoloweingList.dart';
import 'backPackFolowingList.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Backpackgiftsent extends StatelessWidget {
  const Backpackgiftsent({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            indicatorColor: Color(0xff050303),
            labelColor: Color(0xff050303),
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.lato(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              Tab(
                text: ('Follower').appTr,
              ),
              Tab(
                text: ('Following').appTr,
              ),
            ],
          ),
          leading: IconButton(
              onPressed: () {
                Get.back();
              },
              icon: Icon(Icons.arrow_back_ios_rounded)),
          centerTitle: true,
          title: Text(
            ('BackPack gift object').appTr,
            style: GoogleFonts.lato(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  // Popular Section

                  // Party Section
                  Backpackfolowrlist(),
                  Backpackfolowinglist(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
