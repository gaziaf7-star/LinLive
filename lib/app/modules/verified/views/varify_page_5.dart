import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../../../widgets/setheight.dart';
import '../../../../widgets/small_text_widgets.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class VarifyPage5 extends StatelessWidget {
  final dynamic verificationData;

  const VarifyPage5({super.key, required this.verificationData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          title: ('Host Verify').appTr,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: kHeight * 0.095,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height: Get.height * 0.24,
                    decoration: BoxDecoration(
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
                  Positioned(
                    top: 70,
                    left: kWeight * 0.05,
                    child: Container(
                      width: Get.width * 0.9,
                      height: Get.height * 0.3,
                      decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                                color: kAppColor1.withOpacity(0.2),
                                offset: Offset(1, 1),
                                blurRadius: 1)
                          ],
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          SetHeight(heightSet: 0.17),
                          Row(
                            children: [
                              Expanded(
                                child: SmallTextStyle(
                                    color: Colors.black,
                                    text: ('Rank of Agency \n 0').appTr,
                                    fontSize: 15),
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: SmallTextStyle(
                                    color: Colors.black,
                                    text: ('My Rank \n 0').appTr,
                                    fontSize: 15),
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: SmallTextStyle(
                                    color: Colors.black,
                                    text: ('Active Days \n 0').appTr,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: kWeight * 0.35,
                    top: 15,
                    child: Column(
                      children: [
                        Container(
                          height: Get.height * 0.13,
                          width: Get.width * 0.28,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(150),
                            child: CachedNetworkImage(
                              imageUrl:
                                  '$kDomainUrl/${verificationData['agency']['profile_image']}',
                              height: Get.height * 0.15,
                              width: Get.width * 0.35,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SetHeight(heightSet: 0.001),
                        SmallTextStyle(
                          color: Colors.black,
                          text: verificationData['agency']['name'],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        SmallTextStyle(
                            color: Colors.black,
                            text:
                                ('ID: ${verificationData['agency']['agency_id']}').appTr,
                            fontSize: 12),
                      ],
                    ),
                  ),
                ],
              ),
              SetHeight(heightSet: 0.15),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.05),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14.0, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                InkWell(
                                  onTap: () {
                                    // Get.to(ProfileView(),
                                    //     transition: Transition.rightToLeft);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.06,
                                      width:
                                          MediaQuery.of(context).size.height *
                                              0.06,
                                      fit: BoxFit.cover,
                                      imageUrl:
                                          '$kDomainUrl/${verificationData['agency']['profile_image']}',
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -10,
                                  child: Container(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Colors.black,
                                        border: Border.all(
                                            color: Color(0xfff64008),
                                            width: 1.3)),
                                    child: Castontext(
                                      text: ('Agent').appTr,
                                      textColor: Color(0xfff64008),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                                width:
                                    MediaQuery.of(context).size.width * 0.03),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Castontext(
                                  text: verificationData['agency']['name'],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                Castontext(
                                  text:
                                      ('ID : ${verificationData['agency']['agency_id']}').appTr,
                                  fontSize: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 17,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              SetHeight(heightSet: 0.01),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.05),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Card(
                    color: Colors.white,
                    elevation:
                        0, // Card এর elevation বন্ধ করে Container এ shadow
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(17.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Castontext(
                            text: ('Your Host type').appTr,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          Castontext(
                            text: ('Commission').appTr,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ));
  }
}
