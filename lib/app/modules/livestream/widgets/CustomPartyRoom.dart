import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/livestream_controller.dart';
import 'AnimatedProgressBar.dart';
import 'CustomProfilePkRoom.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CustomPartyRoom extends StatelessWidget {
  const CustomPartyRoom({
    super.key,
    required this.livestreamController,
    required this.animatedProgressBarController,
  });

  final LivestreamController livestreamController;
  final AnimatedProgressBarController animatedProgressBarController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              gradient: LinearGradient(colors: [
                Color(0xed3c16e7),
                Color(0xef49021b),
              ])),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/audio_live/gift-box.png',
                      height: Get.height * 0.03,
                    ),
                    Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ('PK').appTr,
                              style: GoogleFonts.unlock(color: Colors.yellow),
                            ),
                            SizedBox(
                              width: Get.width * 0.02,
                            ),
                            Text(
                              '05:00',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Get.defaultDialog(
                          title: ("Exit").appTr,
                          middleText: ("Are you sure you want to exit?").appTr,
                          textCancel: ("No").appTr,
                          textConfirm: ("Yes").appTr,
                          confirmTextColor: Colors.white,
                          onConfirm: () {
                            // Get.back();
                            // audienceJoinController.hidePkRoomBar();
                          },
                        );
                      },
                      icon: Icon(Icons.exit_to_app, color: Colors.white),
                    )
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ('Pk Punishment').appTr,
                    style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: Get.height * 0.018),
                  ),
                  SizedBox(
                    width: Get.width * 0.01,
                  ),
                  Text(
                    ('Selection (50s) >').appTr,
                    style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        color: Colors.yellow,
                        fontSize: Get.height * 0.018),
                  ),
                ],
              ),
              SizedBox(
                height: Get.height * 0.01,
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.only(topLeft: Radius.circular(15)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xff0B68B9),
                            Color(0xff3D23B4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(10),
                                color: Color(0xff5584BA),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                  height: Get.height * 0.04,
                                  width: Get.height * 0.06,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: Get.width * 0.02,
                            ),
                            Expanded(
                                child: Column(
                              children: [
                                Text(
                                  overflow: TextOverflow.ellipsis,
                                  ('Md Abdul Abdul Abdul').appTr,
                                  style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: Get.height * 0.015),
                                ),
                                SizedBox(
                                  height: Get.height * 0.001,
                                ),
                                Row(children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 6), // dynamic width
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xffe8661a),
                                          Color(0xff6C3F25)
                                        ], // subtle orange gradient
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize
                                          .min, // width depends on content
                                      children: [
                                        Image.asset(
                                          'assets/audio_live/preview-removebg-preview.png',
                                          height: Get.height * 0.014,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          ('ID: 203555').appTr,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: Get.height * 0.010,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ])
                              ],
                            ))
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(15),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xffE91E63),
                            Color(0xff8d0433),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                                child: Column(
                              children: [
                                Text(
                                  overflow: TextOverflow.ellipsis,
                                  ('Md Abdul Abdul Abdul').appTr,
                                  style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: Get.height * 0.015),
                                ),
                                SizedBox(
                                  height: Get.height * 0.001,
                                ),
                                Row(children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 6), // dynamic width
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xffe8661a),
                                          Color(0xff6C3F25)
                                        ], // subtle orange gradient
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize
                                          .min, // width depends on content
                                      children: [
                                        Image.asset(
                                          'assets/audio_live/preview-removebg-preview.png',
                                          height: Get.height * 0.014,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          ('ID: 203555').appTr,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: Get.height * 0.010,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ])
                              ],
                            )),
                            SizedBox(
                              width: Get.width * 0.02,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(10),
                                color: Color(0xff5584BA),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                  height: Get.height * 0.04,
                                  width: Get.height * 0.06,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.only(bottomLeft: Radius.circular(15)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xff0B68B9),
                            Color(0xff3D23B4),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  CustomProfilePkRoom(),
                                  CustomProfilePkRoom(),
                                ]),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(15),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xffE91E63),
                            Color(0xff8d0433),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  CustomProfilePkRoom(),
                                  CustomProfilePkRoom(),
                                ]),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                            SizedBox(height: Get.height * 0.02),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                                CustomProfilePkRoom(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff3D23B4),
                        Color(0xff5c3ee8),
                        Color(0xffE91E63),
                        Color(0xff8d0433),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: Get.height * 0.02,
                        ),
                        AnimatedProgressBar(
                          controller: animatedProgressBarController,
                        ),
                        SizedBox(
                          height: Get.height * 0.03,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Positioned LinearPercentIndicator
            ],
          ),
        ),
      ],
    );
  }
}
