import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../apis/api_endpoints.dart';
import '../../../../../constants/constants.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../backpack/controllers/store_controller.dart';
import '../../../backpack/views/BackPack.dart';
import '../../../coinshop/views/giftsent_friend.dart';
import '../../controllers/store1_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Rideview extends GetView<StoreController> {
  const Rideview({super.key});

  @override
  Widget build(BuildContext context) {
    Store1Controller store1controller = Get.put(Store1Controller());
    Get.put(StoreController());

    String formatCoins(int coins) {
      if (coins >= 1000000) {
        double m = coins / 1000000;
        return m % 1 == 0 ? "${m.toInt()}M" : "${m.toStringAsFixed(1)}M";
      } else if (coins >= 1000) {
        double k = coins / 1000;
        return k % 1 == 0 ? "${k.toInt()}k" : "${k.toStringAsFixed(1)}k";
      } else {
        return coins.toString();
      }
    }

    controller.getAssetList();

    return Scaffold(
      backgroundColor: Color(0xffF4F5F9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: controller.getAssetList(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // 🔹 Loading → Shimmer Grid
                    return GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: 6, // placeholder count
                      itemBuilder: (context, index) {
                        return Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                height: 12,
                                width: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 6),
                              Container(
                                height: 12,
                                width: 40,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text(("Error: ${snapshot.error}").appTr));
                  }

                  // 🔥 FIX: Filter kore shudhu 'Entry Care' type er items nibo
                  final filteredList = controller.assetList
                      .where((item) => item['type'] == 'Entry Care')
                      .toList();

                  if (filteredList.isEmpty) {
                    return Center(child: Text(("No Entry Care assets found").appTr));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filteredList.length, // 🔥 Filtered list length
                    itemBuilder: (context, index) {
                      final item =
                          filteredList[index]; // 🔥 Filtered item use korbo

                      return Column(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Frame image
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),

                                Positioned(
                                  bottom: 13,
                                  right: 4,
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xff2fb599),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 4,
                                                horizontal: kWeight * 0.05),
                                            minimumSize: Size(0, 28),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            textStyle: TextStyle(fontSize: 14),
                                          ),
                                          onPressed: () {
                                            controller.selectId.value =
                                                item['id'].toString();

                                            Get.bottomSheet(Container(
                                              height: kHeight * 0.5,
                                              padding: EdgeInsets.symmetric(
                                                  vertical: kHeight * 0.02,
                                                  horizontal: kWeight * 0.04),
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(20),
                                                      topRight:
                                                          Radius.circular(20)),
                                                  color: Colors.white),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(height: 20,),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 10,
                                                        horizontal: 10),
                                                    decoration: BoxDecoration(

                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                    ),
                                                    child: item['asset']
                                                            .toString()
                                                            .endsWith('.svga')
                                                        ? SizedBox(
                                                            height:
                                                                kHeight * 0.08,
                                                            width: kHeight * 0.08,
                                                            child: SVGAEasyPlayer(
                                                              resUrl:
                                                                  "$kDomainUrl/${item['asset']}",
                                                              fit: BoxFit.cover,
                                                            ),
                                                          )
                                                        : CachedNetworkImage(
                                                            imageUrl:
                                                                '$kDomainUrl/${item['asset']}',
                                                            height:
                                                                kHeight * 0.08,
                                                            fit: BoxFit.cover,
                                                          ),
                                                  ),
                                                  Divider(color: Colors.black),
                                                  Text(
                                                    ('Price : ${item['price']}').appTr,
                                                    style: GoogleFonts.lato(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  SizedBox(
                                                      height: kHeight * 0.015),
                                                  Text(
                                                    ('Select gift object').appTr,
                                                    style: GoogleFonts.lato(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  SizedBox(
                                                      height: kHeight * 0.015),
                                                  GestureDetector(
                                                    onTap: () {
                                                      Get.to(GiftSentFriend(),
                                                          transition: Transition
                                                              .rightToLeft);
                                                    },
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 7,
                                                              horizontal: 10),
                                                      decoration: BoxDecoration(
                                                          color: kAppColor1
                                                              .withOpacity(0.6),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(3),
                                                          border: Border.all(
                                                            color: kAppColor2
                                                                .withOpacity(0.6),
                                                          )),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          GestureDetector(
                                                            onTap: () {
                                                              controller.onTap();
                                                            },
                                                            child: Text(
                                                              ('Send').appTr,
                                                              style: GoogleFonts.lato(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600),
                                                            ),
                                                          ),
                                                          Text(('Choose').appTr,
                                                              style: GoogleFonts.lato(
                                                                  color: Color(
                                                                      0xff1d5bf4),
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      height: kHeight * 0.012),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Image.asset(
                                                            'assets/images/coin.png',
                                                            width: 20,
                                                            height: 20,
                                                          ),
                                                          Text(
                                                            ' ${authController.userProfile.value.user!.coins}',
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: Color(
                                                                  0xff793be6),
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              fontSize: 20,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  vertical: 2,
                                                                  horizontal: 15),
                                                          minimumSize:
                                                              Size(0, 25),
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          backgroundColor:
                                                              kAppColor1,
                                                        ),
                                                        onPressed: () {},
                                                        child: Text(
                                                          ('Send').appTr,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: kHeight * 0.06)
                                                ],
                                              ),
                                            ));
                                          },
                                          child: Text(
                                            ('Sending').appTr,
                                            style: GoogleFonts.lato(
                                              fontWeight: FontWeight.w600,
                                              fontSize: kHeight * 0.01,
                                              color: Color(0xffffffff),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: kWeight * 0.02),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xff4700f5),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 4,
                                                horizontal: kWeight * 0.05),
                                            minimumSize: Size(0, 28),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                            textStyle: TextStyle(fontSize: 14),
                                          ),
                                          onPressed: () {
                                            item['purchased'] == 'yes'
                                                ? Get.to(Backpack(),
                                                    transition:
                                                        Transition.rightToLeft)
                                                : Get.bottomSheet(Container(
                                                    height: kHeight * 0.3,
                                                    padding: EdgeInsets.symmetric(
                                                        vertical: kHeight * 0.02,
                                                        horizontal:
                                                            kWeight * 0.04),
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.only(
                                                                topLeft: Radius
                                                                    .circular(20),
                                                                topRight: Radius
                                                                    .circular(
                                                                        20)),
                                                        color: Colors.white),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 10,
                                                                  horizontal: 10),
                                                          decoration:
                                                              BoxDecoration(
                                                          gradient: LinearGradient(colors: [
                                                          kAppColor1,
                                                            kAppColor2
                                                          ]),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(5),
                                                          ),
                                                          child: item['asset']
                                                                  .toString()
                                                                  .endsWith(
                                                                      '.svga')
                                                              ? SizedBox(
                                                                  height:
                                                                      kHeight *
                                                                          0.08,
                                                                  width: kHeight *
                                                                      0.08,
                                                                  child:
                                                                      SVGAEasyPlayer(
                                                                    resUrl:
                                                                        "$kDomainUrl/${item['asset']}",
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  ),
                                                                )
                                                              : CachedNetworkImage(
                                                                  imageUrl:
                                                                      '$kDomainUrl/${item['asset']}',
                                                                  height:
                                                                      kHeight *
                                                                          0.08,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                        ),
                                                        Divider(
                                                            color: Colors.black),
                                                        Text(
                                                          ('Amount : ${item['price']}').appTr,
                                                          style: GoogleFonts.lato(
                                                              fontSize: 17,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600),
                                                        ),
                                                        SizedBox(
                                                            height:
                                                                kHeight * 0.012),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Image.asset(
                                                                  'assets/images/coin.png',
                                                                  width: 20,
                                                                  height: 20,
                                                                ),
                                                                Text(
                                                                  '  ${authController.userProfile.value.user!.coins}',
                                                                  style:
                                                                      GoogleFonts
                                                                          .poppins(
                                                                    color: Color(
                                                                        0xff793be6),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize: 20,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            ElevatedButton(
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        vertical:
                                                                            2,
                                                                        horizontal:
                                                                            15),
                                                                minimumSize:
                                                                    Size(0, 25),
                                                                tapTargetSize:
                                                                    MaterialTapTargetSize
                                                                        .shrinkWrap,
                                                                backgroundColor:
                                                                    kAppColor1,
                                                              ),
                                                              onPressed: () {
                                                                controller.purchaseAsset(
                                                                    purchaseId: item[
                                                                            'id']
                                                                        .toString());
                                                              },
                                                              child: Text(
                                                                ('Purchase').appTr,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        kHeight *
                                                                            0.01,
                                                                    color: Colors
                                                                        .white),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(
                                                            height:
                                                                kHeight * 0.06)
                                                      ],
                                                    ),
                                                  ));
                                          },
                                          child: Text(
                                            item['purchased'] == 'yes'
                                                ? ('BackPack').appTr: ('Purchase').appTr,
                                            style: GoogleFonts.lato(
                                              fontWeight: FontWeight.w600,
                                              fontSize: kHeight * 0.01,
                                              color: Color(0xffffffff),
                                            ),
                                          ),
                                        ),
                                      ]),
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 10),
                                  decoration: BoxDecoration(
                                    // gradient: LinearGradient(colors: [
                                    //   kAppColor1,
                                    //   kAppColor2
                                    // ]),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child:
                                      item['asset'].toString().endsWith('.svga')
                                          ? SizedBox(
                                              height: kHeight * 0.08,
                                              width: kHeight * 0.08,
                                              child: SVGAEasyPlayer(
                                                resUrl:
                                                    "$kDomainUrl/${item['asset']}",
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : CachedNetworkImage(
                                              imageUrl:
                                                  '$kDomainUrl/${item['asset']}',
                                              height: kHeight * 0.08,
                                              fit: BoxFit.cover,
                                            ),
                                ),

                                // Level indicator
                                Positioned(
                                  top: 2,
                                  right: 5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kAppColor2,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      ('${item['duration_days']} Days').appTr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          // Price tag
                          InkWell(
                            onTap: () {
                              controller.onTap();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                     kAppColor2,
                                      kAppColor1
                                      ])),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/coin.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                  Text(
                                    '${item['price']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
