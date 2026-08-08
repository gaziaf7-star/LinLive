import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import '../controllers/livestream_controller.dart';
import 'AnimatedProgressBar.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class towVsTowPk extends StatelessWidget {
  const towVsTowPk({
    super.key,
    required this.animatedProgressBarController,
    required this.livestreamController,
  });

  final AnimatedProgressBarController animatedProgressBarController;
  final LivestreamController livestreamController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            // 🔵 Left Container
            Container(
              width: Get.width * 0.5,
              height: Get.height * 0.5,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.only(topLeft: Radius.circular(15)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff0B68B9), Color(0xff3D23B4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    SizedBox(height: Get.height * 0.15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.blueAccent, width: 2),
                                borderRadius: BorderRadius.circular(100),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff5584BA),
                                    Color(0xff2196F3)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(300),
                                child: CachedNetworkImage(
                                  imageUrl:
                                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                  height: Get.height * 0.07,
                                  width: Get.height * 0.07,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(height: Get.height * 0.01),
                            Text(
                              ('Md Abdul').appTr,
                              style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SizedBox(width: Get.width * 0.05),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(150),
                            color: Colors.white24,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 🔴 Right Container
            Container(
              width: Get.width * 0.5,
              height: Get.height * 0.5,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.only(topRight: Radius.circular(15)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffE91E63), Color(0xff8d0433)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    SizedBox(height: Get.height * 0.15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(150),
                                color: Colors.white24,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              ),
                            ),
                            SizedBox(height: Get.height * 0.01),
                          ],
                        ),
                        SizedBox(width: Get.width * 0.05),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(150),
                            color: Colors.white24,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Background VS letters
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ('A').appTr,
                style: GoogleFonts.unlock(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: Get.height * 0.1,
                ),
              ),
              Text(
                ('B').appTr,
                style: GoogleFonts.unlock(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: Get.height * 0.1,
                ),
              )
            ],
          ),
        ),

        // Bottom gradient bar
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
                    height: Get.height * 0.01,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _roundIcon(Icons.person, size: 28),
                      SizedBox(width: Get.width * 0.02),
                      _roundIcon(Icons.person, size: 28),
                      SizedBox(width: Get.width * 0.02),
                      _roundIcon(Icons.person, size: 28),
                    ],
                  ),
                  SizedBox(
                    height: Get.height * 0.03,
                  ),
                  Container(
                    width: Get.width * 0.7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Center(
                        child: Text(
                          ('Start').appTr,
                          style: GoogleFonts.roboto(
                              fontWeight: FontWeight.w600,
                              fontSize: Get.height * 0.02,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: Get.height * 0.02,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Positioned LinearPercentIndicator

        // Positioned(
        //   bottom: 200,
        //   left: 15,
        //   right: 15,
        //   child: AnimatedProgressBar(
        //     controller: animatedProgressBarController,
        //   ),
        // ),

        // Top-right PK timer + exit
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(width: Get.width * 0.1),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white30,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ('PK').appTr,
                      style: GoogleFonts.unlock(color: Colors.yellow),
                    ),
                    SizedBox(width: Get.width * 0.02),
                    Text(
                      '05:00',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600),
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
                    Get.back(); // Dialog close
                    livestreamController.hidePk(); // PK View hide
                  },
                );
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
            )
          ],
        ),
      ],
    );
  }
}

Widget _roundIcon(IconData icon, {double size = 28}) {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [
          Color(0xff6A11CB), // Purple
          Color(0xff2575FC), // Blue
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    padding: const EdgeInsets.all(12),
    child: Icon(
      icon,
      color: Colors.white,
      size: size,
    ),
  );
}
