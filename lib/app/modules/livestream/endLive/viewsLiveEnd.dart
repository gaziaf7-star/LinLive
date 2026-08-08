import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castom appbar.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class Viewsliveend extends StatefulWidget {
  Viewsliveend({super.key});

  @override
  State<Viewsliveend> createState() => _ViewsliveendState();
}

class _ViewsliveendState extends State<Viewsliveend> {
  bool iColor = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: ('End Live').appTr,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
              Color(0xffb5a7fe),
              Color(0xffffffff),
            ], begin: Alignment.topRight, end: Alignment.bottomRight)),
          ),
          Column(
            children: [
              SizedBox(
                height: kHeight * 0.04,
              ),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background Gradient Container with content
                    Container(
                      width: kWeight * 0.9,
                      padding: EdgeInsets.symmetric(vertical: kHeight * 0.05),
                      margin: EdgeInsets.symmetric(
                          vertical: 10, horizontal: kWeight * 0.03),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xff8A4CF7),
                            Color(0xffB460F0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: Offset(0, 6),
                            blurRadius: 12,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                              height: 15), // Space for avatar overlap
                          Castontext(
                            textColor: Colors.white,
                            text: 'kamal',
                            fontSize: 20,
                          ),
                          SizedBox(height: kHeight * 0.02),
                          InkWell(
                            onTap: () {
                              setState(() {
                                iColor = !iColor;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 7, horizontal: kHeight * 0.03),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: Color(0xff6e05b6)),
                              child: Castontext(
                                  textColor: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  text:
                                      iColor == true ? 'Following' : 'Follow'),
                            ),
                          ),
                          SizedBox(height: kHeight * 0.03),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                          //   children: [
                          //     CastomLivecatagory(
                          //       text: 'Receive Coin',
                          //       text1: '0',
                          //       image: 'assets/images/dollar.png',
                          //     ),
                          //     CastomLivecatagory(
                          //       text: 'New follower',
                          //       text1: '0',
                          //       image: 'assets/flaticons/user.png',
                          //     ),
                          //   ],
                          // ),
                        ],
                      ),
                    ),

                    // Positioned Circular Image with border
                    Positioned(
                      top: -40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xff8A4CF7),
                                Color(0xffB460F0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: CircleAvatar(
                              radius: kHeight * 0.045,
                              backgroundColor: Colors.white,
                              child: CachedNetworkImage(
                                imageUrl:
                                    'https://media.gettyimages.com/id/1317804578/photo/one-businesswoman-headshot-smiling-at-the-camera.jpg?s=612x612&w=gi&k=20&c=tFkDOWmEyqXQmUHNxkuR5TsmRVLi5VZXYm3mVsjee0E=',
                                height: kHeight * 0.09,
                                width: kHeight * 0.09,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: kHeight * 0.12,
              ),
              // SizedBox(
              //   width: kWeight * 0.85,
              //   height: kHeight * 0.06,
              //   child: ElevatedButton(
              //     onPressed: () {},
              //     style: ElevatedButton.styleFrom(
              //       padding: EdgeInsets.zero,
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(50),
              //       ),
              //       backgroundColor: Colors.transparent,
              //       shadowColor: Colors.transparent,
              //     ),
              //     child: Ink(
              //       decoration: BoxDecoration(
              //         gradient: LinearGradient(
              //           colors: [
              //             Color(0xff8A4CF7),
              //             Color(0xffB460F0),
              //           ],
              //           begin: Alignment.topCenter,
              //           end: Alignment.bottomCenter,
              //         ),
              //         borderRadius: BorderRadius.circular(10),
              //       ),
              //       child: Container(
              //         alignment: Alignment.center,
              //         padding:
              //             EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              //         child: Text(
              //           'Conform',
              //           style: GoogleFonts.lato(
              //             color: Colors.white,
              //             fontSize: 22,
              //             fontWeight: FontWeight.w600,
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
