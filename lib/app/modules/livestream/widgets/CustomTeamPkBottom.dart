import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/audience_join_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CustomTeamPkBottom extends StatelessWidget {
  const CustomTeamPkBottom({super.key});

  @override
  Widget build(BuildContext context) {
    AudienceJoinController timeController = Get.put(AudienceJoinController());

    return DefaultTabController(
      length: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: Get.height * 0.5,
            decoration: BoxDecoration(
              border: const Border(
                top: BorderSide(
                  color: CupertinoColors.systemYellow,
                  width: 2,
                ),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xff141E30), // deep navy
                  Color(0xff243B55), // bluish dark
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  offset: Offset(0, -6),
                )
              ],
            ),
            child: Column(
              children: [
                /// Premium TabBar
                Padding(
                  padding: const EdgeInsets.only(top: 55, left: 20, right: 20),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white24, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xfff7971e), Color(0xffffd200)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.yellowAccent,
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: Offset(0, 3),
                          )
                        ],
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: GoogleFonts.unlock(
                        fontWeight: FontWeight.bold,
                        fontSize: Get.height * 0.022,
                      ),
                      tabs:  [
                        Tab(text: ("🔥 Team PK").appTr),
                        Tab(text: ("🏆 Room PK").appTr),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 18),

                /// Premium Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Stack(
                      //   children: [
                      //     Positioned(
                      //       top: Get.height * 0.001,
                      //       left: 0,
                      //       right: 0,
                      //       child: Column(
                      //         crossAxisAlignment: CrossAxisAlignment.center,
                      //         children: [
                      //           Text(
                      //             'Please select your team side',
                      //             style: GoogleFonts.roboto(
                      //                 color: Colors.white,
                      //                 fontSize: Get.height * 0.018,
                      //                 shadows: [
                      //                   Shadow(
                      //                       color: Colors.yellow,
                      //                       offset: Offset(5, 3),
                      //                       blurRadius: 8)
                      //                 ]),
                      //           ),
                      //           SizedBox(
                      //             height: Get.height * 0.015,
                      //           ),
                      //           Padding(
                      //             padding: const EdgeInsets.all(15.0),
                      //             child: SingleChildScrollView(
                      //               scrollDirection: Axis.horizontal,
                      //               child: Row(
                      //                 children: [
                      //                   Container(
                      //                     decoration: BoxDecoration(
                      //                         borderRadius:
                      //                             BorderRadius.circular(5),
                      //                         gradient: LinearGradient(
                      //                             begin: Alignment.topCenter,
                      //                             end: Alignment.bottomCenter,
                      //                             colors: [
                      //                               Color(0xffc3d9fa),
                      //                               Color(0xff0857cc),
                      //                             ])),
                      //                     child: Padding(
                      //                       padding: const EdgeInsets.all(1.0),
                      //                       child: Container(
                      //                         width: Get.width * 0.35,
                      //                         height: Get.height * 0.12,
                      //                         decoration: BoxDecoration(
                      //                             borderRadius:
                      //                                 BorderRadius.circular(5),
                      //                             gradient: LinearGradient(
                      //                                 begin:
                      //                                     Alignment.topCenter,
                      //                                 end: Alignment
                      //                                     .bottomCenter,
                      //                                 colors: [
                      //                                   Color(0xff294D8C),
                      //                                   Color(0xff281E56),
                      //                                 ])),
                      //                         child: Padding(
                      //                           padding:
                      //                               const EdgeInsets.all(5.0),
                      //                           child: Stack(
                      //                             children: [
                      //                               Positioned(
                      //                                 left: 22,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 top: 20,
                      //                                 left: 0,
                      //                                 right: 0,
                      //                                 child: Image.asset(
                      //                                   'assets/audio_live/download-7.png',
                      //                                   height:
                      //                                       Get.height * 0.05,
                      //                                 ),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 22,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                   bottom: 5,
                      //                                   right: 40,
                      //                                   child: Text(
                      //                                     '1 VS 1',
                      //                                     style: GoogleFonts
                      //                                         .unlock(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.026,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .white),
                      //                                   ))
                      //                             ],
                      //                           ),
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   ),
                      //                   SizedBox(
                      //                     width: Get.width * 0.03,
                      //                   ),
                      //                   Container(
                      //                     decoration: BoxDecoration(
                      //                         borderRadius:
                      //                             BorderRadius.circular(5),
                      //                         gradient: LinearGradient(
                      //                             begin: Alignment.topCenter,
                      //                             end: Alignment.bottomCenter,
                      //                             colors: [
                      //                               Color(0xffc3d9fa),
                      //                               Color(0xff0857cc),
                      //                             ])),
                      //                     child: Padding(
                      //                       padding: const EdgeInsets.all(1.0),
                      //                       child: Container(
                      //                         width: Get.width * 0.35,
                      //                         height: Get.height * 0.12,
                      //                         decoration: BoxDecoration(
                      //                             borderRadius:
                      //                                 BorderRadius.circular(5),
                      //                             gradient: LinearGradient(
                      //                                 begin:
                      //                                     Alignment.topCenter,
                      //                                 end: Alignment
                      //                                     .bottomCenter,
                      //                                 colors: [
                      //                                   Color(0xff294D8C),
                      //                                   Color(0xff281E56),
                      //                                 ])),
                      //                         child: Padding(
                      //                           padding:
                      //                               const EdgeInsets.all(5.0),
                      //                           child: Stack(
                      //                             children: [
                      //                               Positioned(
                      //                                 left: 5,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 left: 28,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 top: 20,
                      //                                 left: 0,
                      //                                 right: 0,
                      //                                 child: Image.asset(
                      //                                   'assets/audio_live/vsImage.png',
                      //                                   height:
                      //                                       Get.height * 0.05,
                      //                                 ),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 28,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 5,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                   bottom: 5,
                      //                                   right: 40,
                      //                                   child: Text(
                      //                                     '2 VS 2',
                      //                                     style: GoogleFonts
                      //                                         .unlock(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.026,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .white),
                      //                                   ))
                      //                             ],
                      //                           ),
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   ),
                      //                   SizedBox(
                      //                     width: Get.width * 0.03,
                      //                   ),
                      //                   Container(
                      //                     decoration: BoxDecoration(
                      //                         borderRadius:
                      //                             BorderRadius.circular(5),
                      //                         gradient: LinearGradient(
                      //                             begin: Alignment.topCenter,
                      //                             end: Alignment.bottomCenter,
                      //                             colors: [
                      //                               Color(0xff0857cc),
                      //                               Color(0xff0857cc),
                      //                             ])),
                      //                     child: Padding(
                      //                       padding: const EdgeInsets.all(1.0),
                      //                       child: Container(
                      //                         width: Get.width * 0.35,
                      //                         height: Get.height * 0.12,
                      //                         decoration: BoxDecoration(
                      //                             borderRadius:
                      //                                 BorderRadius.circular(5),
                      //                             gradient: LinearGradient(
                      //                                 begin:
                      //                                     Alignment.topCenter,
                      //                                 end: Alignment
                      //                                     .bottomCenter,
                      //                                 colors: [
                      //                                   Color(0xff294D8C),
                      //                                   Color(0xff281E56),
                      //                                 ])),
                      //                         child: Padding(
                      //                           padding:
                      //                               const EdgeInsets.all(5.0),
                      //                           child: Stack(
                      //                             children: [
                      //                               Positioned(
                      //                                 left: 5,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 left: 28,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 left: 18,
                      //                                 top: 8,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 top: 20,
                      //                                 left: 0,
                      //                                 right: 0,
                      //                                 child: Image.asset(
                      //                                   'assets/audio_live/vsImage.png',
                      //                                   height:
                      //                                       Get.height * 0.05,
                      //                                 ),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 28,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 5,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                   bottom: 5,
                      //                                   right: 40,
                      //                                   child: Text(
                      //                                     '3 VS 3',
                      //                                     style: GoogleFonts
                      //                                         .unlock(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.026,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .white),
                      //                                   )),
                      //                               Positioned(
                      //                                 right: 18,
                      //                                 top: 8,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                             ],
                      //                           ),
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   ),
                      //                   SizedBox(
                      //                     width: Get.width * 0.03,
                      //                   ),
                      //                   Container(
                      //                     decoration: BoxDecoration(
                      //                         borderRadius:
                      //                             BorderRadius.circular(5),
                      //                         gradient: LinearGradient(
                      //                             begin: Alignment.topCenter,
                      //                             end: Alignment.bottomCenter,
                      //                             colors: [
                      //                               Color(0xff0857cc),
                      //                               Color(0xff0857cc),
                      //                             ])),
                      //                     child: Padding(
                      //                       padding: const EdgeInsets.all(1.0),
                      //                       child: Container(
                      //                         width: Get.width * 0.35,
                      //                         height: Get.height * 0.12,
                      //                         decoration: BoxDecoration(
                      //                             borderRadius:
                      //                                 BorderRadius.circular(5),
                      //                             gradient: LinearGradient(
                      //                                 begin:
                      //                                     Alignment.topCenter,
                      //                                 end: Alignment
                      //                                     .bottomCenter,
                      //                                 colors: [
                      //                                   Color(0xff294D8C),
                      //                                   Color(0xff281E56),
                      //                                 ])),
                      //                         child: Padding(
                      //                           padding:
                      //                               const EdgeInsets.all(5.0),
                      //                           child: Stack(
                      //                             children: [
                      //                               Positioned(
                      //                                 left: 2,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 left: 17,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 left: 32,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 left: 18,
                      //                                 top: 8,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 top: 20,
                      //                                 left: 0,
                      //                                 right: 0,
                      //                                 child: Image.asset(
                      //                                   'assets/audio_live/vsImage.png',
                      //                                   height:
                      //                                       Get.height * 0.05,
                      //                                 ),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 2,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 17,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 32,
                      //                                 top: 30,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                 right: 18,
                      //                                 top: 8,
                      //                                 child:
                      //                                     CustomProfileImage(),
                      //                               ),
                      //                               Positioned(
                      //                                   bottom: 5,
                      //                                   right: 40,
                      //                                   child: Text(
                      //                                     '4 VS 4',
                      //                                     style: GoogleFonts
                      //                                         .unlock(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.026,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .white),
                      //                                   )),
                      //                             ],
                      //                           ),
                      //                         ),
                      //                       ),
                      //                     ),
                      //                   ),
                      //                 ],
                      //               ),
                      //             ),
                      //           ),
                      //           SizedBox(
                      //             height: Get.height * 0.015,
                      //           ),
                      //           Padding(
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 15, vertical: 5),
                      //             child: Container(
                      //               decoration: BoxDecoration(
                      //                 borderRadius: BorderRadius.circular(15),
                      //                 color: Colors.blueGrey.withOpacity(0.4),
                      //               ),
                      //               child: Padding(
                      //                 padding: const EdgeInsets.symmetric(
                      //                     horizontal: 15, vertical: 8),
                      //                 child: Row(
                      //                   mainAxisAlignment:
                      //                       MainAxisAlignment.spaceBetween,
                      //                   crossAxisAlignment:
                      //                       CrossAxisAlignment.center,
                      //                   children: [
                      //                     Text(
                      //                       ('Time').appTr,
                      //                       style: GoogleFonts.roboto(
                      //                         fontWeight: FontWeight.w500,
                      //                         fontSize: Get.height * 0.02,
                      //                         color: Colors.white,
                      //                       ),
                      //                     ),
                      //                     DropdownButton<int>(
                      //                       dropdownColor: Colors.blueGrey,
                      //                       // value: timeController
                      //                       //     .selectedTeamPkTime.value,
                      //                       icon: const Icon(
                      //                           Icons.arrow_drop_down,
                      //                           color: Colors.white),
                      //                       underline: const SizedBox(),
                      //                       style: GoogleFonts.roboto(
                      //                         color: Colors.white,
                      //                         fontSize: Get.height * 0.018,
                      //                       ),
                      //                       items: const [
                      //                         DropdownMenuItem(
                      //                             value: 5,
                      //                             child: Text("5 mins")),
                      //                         DropdownMenuItem(
                      //                             value: 10,
                      //                             child: Text("10 mins")),
                      //                         DropdownMenuItem(
                      //                             value: 20,
                      //                             child: Text("20 mins")),
                      //                         DropdownMenuItem(
                      //                             value: 30,
                      //                             child: Text("30 mins")),
                      //                         DropdownMenuItem(
                      //                             value: 45,
                      //                             child: Text("45 mins")),
                      //                         DropdownMenuItem(
                      //                             value: 60,
                      //                             child: Text("60 mins")),
                      //                       ],
                      //                       onChanged: (value) {
                      //                         if (value != null) {
                      //                           // timeController
                      //                           //     .selectedTeamPkTime
                      //                           //     .value = value;
                      //                         }
                      //                       },
                      //                     )
                      //                   ],
                      //                 ),
                      //               ),
                      //             ),
                      //           ),
                      //           SizedBox(
                      //             height: Get.height * 0.015,
                      //           ),
                      //           Padding(
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 15, vertical: 5),
                      //             child: InkWell(
                      //               onTap: () {
                      //                 // Get.back();
                      //                 // timeController.showPk();
                      //                 Get.bottomSheet(
                      //                   Container(
                      //                     height: Get.height * 0.35,
                      //                     decoration: BoxDecoration(
                      //                       borderRadius: BorderRadius.only(
                      //                         topRight: Radius.circular(20),
                      //                         topLeft: Radius.circular(20),
                      //                       ),
                      //                       color: Color(0xff191D20),
                      //                     ),
                      //                     child: Padding(
                      //                       padding: const EdgeInsets.all(15.0),
                      //                       child: Column(
                      //                         children: [
                      //                           RichText(
                      //                             text: TextSpan(
                      //                               text: ('A').appTr,
                      //                               style: GoogleFonts.poppins(
                      //                                 fontSize:
                      //                                     Get.height * 0.022,
                      //                                 fontWeight:
                      //                                     FontWeight.w600,
                      //                                 color: Colors.blue,
                      //                               ),
                      //                               children: <TextSpan>[
                      //                                 TextSpan(
                      //                                     text: ' or ',
                      //                                     style: GoogleFonts
                      //                                         .poppins(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.022,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .white)),
                      //                                 TextSpan(
                      //                                     text: 'B,',
                      //                                     style: GoogleFonts
                      //                                         .poppins(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.022,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .pink)),
                      //                                 TextSpan(
                      //                                     text:
                      //                                         ' Pick your team! ',
                      //                                     style: GoogleFonts
                      //                                         .poppins(
                      //                                             fontSize:
                      //                                                 Get.height *
                      //                                                     0.022,
                      //                                             fontWeight:
                      //                                                 FontWeight
                      //                                                     .w600,
                      //                                             color: Colors
                      //                                                 .white)),
                      //                               ],
                      //                             ),
                      //                           ),
                      //                           SizedBox(
                      //                               height: Get.height * 0.05),
                      //                           Row(
                      //                             mainAxisAlignment:
                      //                                 MainAxisAlignment
                      //                                     .spaceAround,
                      //                             children: [
                      //                               // === A Team ===
                      //                               Stack(
                      //                                 children: [
                      //                                   Container(
                      //                                     width:
                      //                                         Get.width * 0.3,
                      //                                     decoration:
                      //                                         BoxDecoration(
                      //                                       borderRadius:
                      //                                           BorderRadius
                      //                                               .circular(
                      //                                                   5),
                      //                                       gradient:
                      //                                           LinearGradient(
                      //                                         begin: Alignment
                      //                                             .topCenter,
                      //                                         end: Alignment
                      //                                             .bottomCenter,
                      //                                         colors: [
                      //                                           Color(
                      //                                               0xff0B68B9),
                      //                                           Color(
                      //                                               0xff3D23B4),
                      //                                         ],
                      //                                       ),
                      //                                     ),
                      //                                     child: Padding(
                      //                                       padding:
                      //                                           const EdgeInsets
                      //                                               .all(8.0),
                      //                                       child: Column(
                      //                                         children: [
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.01),
                      //                                           Container(
                      //                                             decoration:
                      //                                                 BoxDecoration(
                      //                                               borderRadius:
                      //                                                   BorderRadius.circular(
                      //                                                       40),
                      //                                               color: Color(
                      //                                                   0xff5584BA),
                      //                                             ),
                      //                                             child:
                      //                                                 Padding(
                      //                                               padding:
                      //                                                   const EdgeInsets
                      //                                                       .all(
                      //                                                       12.0),
                      //                                               child: Icon(
                      //                                                 Icons.add,
                      //                                                 color: Colors
                      //                                                     .white,
                      //                                                 size: 50,
                      //                                               ),
                      //                                             ),
                      //                                           ),
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.01),
                      //                                           Row(
                      //                                             mainAxisAlignment:
                      //                                                 MainAxisAlignment
                      //                                                     .center,
                      //                                             children: [
                      //                                               CustomProfileImage(),
                      //                                               CustomProfileImage(),
                      //                                             ],
                      //                                           ),
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.03),
                      //                                           Container(
                      //                                             decoration:
                      //                                                 BoxDecoration(
                      //                                               color: Colors
                      //                                                   .white,
                      //                                               borderRadius:
                      //                                                   BorderRadius
                      //                                                       .circular(2),
                      //                                             ),
                      //                                             child:
                      //                                                 Padding(
                      //                                               padding: const EdgeInsets
                      //                                                   .symmetric(
                      //                                                   horizontal:
                      //                                                       30,
                      //                                                   vertical:
                      //                                                       5),
                      //                                               child: Text(
                      //                                                 ('Join').appTr,
                      //                                                 style: GoogleFonts
                      //                                                     .roboto(
                      //                                                   fontWeight:
                      //                                                       FontWeight.w600,
                      //                                                   fontSize:
                      //                                                       Get.height *
                      //                                                           0.018,
                      //                                                   color: Colors
                      //                                                       .blue,
                      //                                                 ),
                      //                                               ),
                      //                                             ),
                      //                                           ),
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.01),
                      //                                         ],
                      //                                       ),
                      //                                     ),
                      //                                   ),
                      //                                   Text(
                      //                                     ('A').appTr,
                      //                                     style: GoogleFonts
                      //                                         .unlock(
                      //                                       color: Colors.white
                      //                                           .withOpacity(
                      //                                               0.5),
                      //                                       fontSize:
                      //                                           Get.height *
                      //                                               0.05,
                      //                                     ),
                      //                                   )
                      //                                 ],
                      //                               ),
                      //
                      //                               Text(
                      //                                 ('PK').appTr,
                      //                                 style: GoogleFonts.unlock(
                      //                                   color: Colors.white,
                      //                                   fontSize:
                      //                                       Get.height * 0.040,
                      //                                   fontWeight:
                      //                                       FontWeight.w600,
                      //                                 ),
                      //                               ),
                      //
                      //                               // === B Team ===
                      //                               Stack(
                      //                                 children: [
                      //                                   Container(
                      //                                     width:
                      //                                         Get.width * 0.3,
                      //                                     decoration:
                      //                                         BoxDecoration(
                      //                                       borderRadius:
                      //                                           BorderRadius
                      //                                               .circular(
                      //                                                   5),
                      //                                       gradient:
                      //                                           LinearGradient(
                      //                                         begin: Alignment
                      //                                             .topCenter,
                      //                                         end: Alignment
                      //                                             .bottomCenter,
                      //                                         colors: [
                      //                                           Color(
                      //                                               0xffE91E63),
                      //                                           Color(
                      //                                               0xff8d0433),
                      //                                         ],
                      //                                       ),
                      //                                     ),
                      //                                     child: Padding(
                      //                                       padding:
                      //                                           const EdgeInsets
                      //                                               .all(8.0),
                      //                                       child: Column(
                      //                                         children: [
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.01),
                      //                                           Container(
                      //                                             decoration:
                      //                                                 BoxDecoration(
                      //                                               borderRadius:
                      //                                                   BorderRadius.circular(
                      //                                                       40),
                      //                                               color: Color(
                      //                                                   0xff5584BA),
                      //                                             ),
                      //                                             child:
                      //                                                 Padding(
                      //                                               padding:
                      //                                                   const EdgeInsets
                      //                                                       .all(
                      //                                                       12.0),
                      //                                               child: Icon(
                      //                                                 Icons.add,
                      //                                                 color: Colors
                      //                                                     .white,
                      //                                                 size: 50,
                      //                                               ),
                      //                                             ),
                      //                                           ),
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.01),
                      //                                           Row(
                      //                                             mainAxisAlignment:
                      //                                                 MainAxisAlignment
                      //                                                     .center,
                      //                                             children: [
                      //                                               CustomProfileImage(),
                      //                                               CustomProfileImage(),
                      //                                             ],
                      //                                           ),
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.03),
                      //                                           Container(
                      //                                             decoration:
                      //                                                 BoxDecoration(
                      //                                               color: Colors
                      //                                                   .white,
                      //                                               borderRadius:
                      //                                                   BorderRadius
                      //                                                       .circular(2),
                      //                                             ),
                      //                                             child:
                      //                                                 Padding(
                      //                                               padding: const EdgeInsets
                      //                                                   .symmetric(
                      //                                                   horizontal:
                      //                                                       30,
                      //                                                   vertical:
                      //                                                       5),
                      //                                               child: Text(
                      //                                                 ('Join').appTr,
                      //                                                 style: GoogleFonts
                      //                                                     .roboto(
                      //                                                   fontWeight:
                      //                                                       FontWeight.w600,
                      //                                                   fontSize:
                      //                                                       Get.height *
                      //                                                           0.018,
                      //                                                   color: Colors
                      //                                                       .pink,
                      //                                                 ),
                      //                                               ),
                      //                                             ),
                      //                                           ),
                      //                                           SizedBox(
                      //                                               height: Get
                      //                                                       .height *
                      //                                                   0.01),
                      //                                         ],
                      //                                       ),
                      //                                     ),
                      //                                   ),
                      //                                   Text(
                      //                                     ('B').appTr,
                      //                                     style: GoogleFonts
                      //                                         .unlock(
                      //                                       color: Colors.white
                      //                                           .withOpacity(
                      //                                               0.5),
                      //                                       fontSize:
                      //                                           Get.height *
                      //                                               0.05,
                      //                                     ),
                      //                                   )
                      //                                 ],
                      //                               ),
                      //                             ],
                      //                           ),
                      //                         ],
                      //                       ),
                      //                     ),
                      //                   ),
                      //                 );
                      //
                      //                 // === Auto Close after 2 seconds ===
                      //                 Future.delayed(Duration(seconds: 2), () {
                      //                   if (Get.isBottomSheetOpen ?? false) {
                      //                     Get.back();
                      //                   }
                      //                 });
                      //               },
                      //               child: Container(
                      //                 decoration: BoxDecoration(
                      //                   borderRadius: BorderRadius.circular(30),
                      //                   color: Colors.purple,
                      //                 ),
                      //                 child: Padding(
                      //                   padding: const EdgeInsets.symmetric(
                      //                       horizontal: 15, vertical: 15),
                      //                   child: Row(
                      //                     mainAxisAlignment:
                      //                         MainAxisAlignment.center,
                      //                     children: [
                      //                       Icon(Icons.done,
                      //                           color: Colors.white, size: 28),
                      //                       SizedBox(width: Get.width * 0.02),
                      //                       Text(
                      //                         'Start PK',
                      //                         style: GoogleFonts.roboto(
                      //                           fontWeight: FontWeight.w500,
                      //                           fontSize: Get.height * 0.02,
                      //                           color: Colors.white,
                      //                         ),
                      //                       ),
                      //                     ],
                      //                   ),
                      //                 ),
                      //               ),
                      //             ),
                      //           )
                      //         ],
                      //       ),
                      //     )
                      //   ],
                      // ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xff540930),
                              Color(0xff6D1E2A),
                              Color(0xff540930),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: Get.height * 0.03),
                            Text(
                              ('Select a mode and PK to win rewards').appTr,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: Get.height * 0.016,
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(
                                    color: Colors.yellow,
                                    offset: Offset(3, 3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: Get.height * 0.03),

                            /// Premium Card (=/= shape)
                            InkWell(
                              onTap: () {
                                Get.back();
                                // timeController.showPkRoomBar();
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xfff7971e), // orange
                                      Color(0xffffd200), // yellow
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    /// diagonal shape effect (=/=)
                                    Positioned.fill(
                                      child: ClipPath(
                                        clipper: _DiagonalClipper(),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.black.withOpacity(0.2),
                                                Colors.transparent,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// Row content
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        /// Texts
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ('Quick Match').appTr,
                                                style: GoogleFonts.unlock(
                                                  color: Colors.white,
                                                  fontSize: Get.height * 0.025,
                                                  fontWeight: FontWeight.w600,
                                                  shadows: const [
                                                    Shadow(
                                                      color: Colors.black54,
                                                      offset: Offset(1, 1),
                                                      blurRadius: 2,
                                                    )
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                ('PK against a random room').appTr,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: Get.height * 0.018,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        /// Image
                                        Image.asset(
                                          'assets/audio_live/powerImage.png',
                                          height: Get.height * 0.06,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: Get.height * 0.012),
                            InkWell(
                              onTap: () {
                                Get.bottomSheet(Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xff3a4044), // orange
                                        Color(0xff030608), // yellow
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 10,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      /// --- Search Bar ---
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: TextField(
                                          style: const TextStyle(
                                              color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: ("Search friends").appTr,
                                            hintStyle: TextStyle(
                                                color: Colors.white54),
                                            prefixIcon: const Icon(Icons.search,
                                                color: Colors.white),
                                            filled: true,
                                            fillColor: const Color(0xff2A2A3A),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            // এখন কোনো filtering নেই, শুধু UI
                                          },
                                        ),
                                      ),

                                      /// --- ListView.builder ---
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: 10, // Number of items
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          itemBuilder: (context, index) {
                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff1F1D2B),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  /// Profile Image
                                                  CircleAvatar(
                                                    radius: 25,
                                                    backgroundImage: NetworkImage(
                                                        'https://randomuser.me/api/portraits/men/$index.jpg'),
                                                  ),
                                                  const SizedBox(width: 12),

                                                  /// Name + subtitles
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          ('Friend $index').appTr,
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              ('Subtitle 1').appTr,
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Text(
                                                              ('Subtitle 2').appTr,
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  /// Invite Button
                                                  ElevatedButton(
                                                    onPressed: () {},
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.purple,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8),
                                                    ),
                                                    child: Text(
                                                      ('Invite').appTr,
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ));
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xfff7971e), // orange
                                      Color(0xffffd200), // yellow
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    /// diagonal shape effect (=/=)
                                    Positioned.fill(
                                      child: ClipPath(
                                        clipper: _DiagonalClipper(),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.black.withOpacity(0.2),
                                                Colors.transparent,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    /// Row content
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        /// Texts
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ('Invite Room').appTr,
                                                style: GoogleFonts.unlock(
                                                  color: Colors.white,
                                                  fontSize: Get.height * 0.025,
                                                  fontWeight: FontWeight.w600,
                                                  shadows: const [
                                                    Shadow(
                                                      color: Colors.black54,
                                                      offset: Offset(1, 1),
                                                      blurRadius: 2,
                                                    )
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                ('Invite your friend\'s room to PK ').appTr,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: Get.height * 0.018,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        /// Image
                                        Image.asset(
                                          'assets/audio_live/arrowRightImage.png',
                                          height: Get.height * 0.06,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// PK Title with Glow
          Positioned(
            top: -28,
            right: Get.width * 0.46,
            child: Text(
              ('PK').appTr,
              style: GoogleFonts.unlock(
                color: Colors.white,
                fontSize: Get.height * 0.045,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(
                    color: Colors.amber,
                    offset: Offset(0, 0),
                    blurRadius: 25,
                  )
                ],
              ),
            ),
          ),

          /// Glass Close Button
          Positioned(
            right: 12,
            top: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width - 40, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class CustomProfileImage extends StatelessWidget {
  const CustomProfileImage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Color(0xff98c7e3)),
          color: Colors.blue),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Image.asset(
            'assets/audio_live/user (3).png',
            height: Get.height * 0.017,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
