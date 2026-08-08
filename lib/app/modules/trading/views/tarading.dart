import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../controllers/trading_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Tarading extends StatefulWidget {
  const Tarading({super.key});

  @override
  State<Tarading> createState() => _TaradingState();
}

class _TaradingState extends State<Tarading> {
  Map<String, dynamic>? selectedUser;

  void searchUser(String uid) {
    if (uid.isEmpty) {
      setState(() => selectedUser = null);
      return;
    }

    try {
      final user = homeController.allUserData.firstWhere(
        (u) => u['user_id'].toString() == uid,
      );

      setState(() {
        selectedUser = user;
      });


    } catch (e) {
      setState(() => selectedUser = null);

    }
  }

  @override
  Widget build(BuildContext context) {
    double cardHeight = selectedUser != null ? 140 : 0;
    TradingController tradingController = Get.put(TradingController());
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: kHeight * 0.03),

            /// You Have + Diamond
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {},
                    child: Castontext(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      text: ('You Have').appTr,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Image(
                      image: AssetImage('assets/audio_live/diamond.png'),
                      height: kHeight * 0.014,
                    ),
                  ),
                  SizedBox(width: 8),
                  InkWell(
                    onTap: () {},
                    child: Castontext(
                      textColor: Color(0xff8A4CF7),
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      text:
                          '${authController.userProfile.value.user!.earnedCoins}',
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: kHeight * 0.02),

            /// Search Box
            Container(
              width: kWeight * 0.8,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                readOnly: false,
                controller: tradingController.searchController,
                onChanged: (value) {
                  searchUser(value.trim());
                },
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey[600]),
                  hintText: ('Enter UID').appTr,
                  border: InputBorder.none,
                ),
              ),
            ),

            SizedBox(height: kHeight * 0.01),

            /// Animated Profile Card
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: cardHeight,
              width: kWeight * 0.8,
              child: selectedUser != null
                  ? selectedUser == null
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey[300],
                            ),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 10),
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 150,
                                      height: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 100,
                                      height: 12,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.grey[100],
                          ),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 10),
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CachedNetworkImage(
                                imageUrl:
                                    "$kMainUrl/${selectedUser!['profile_image']}",
                                imageBuilder: (context, imageProvider) =>
                                    Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                placeholder: (context, url) =>
                                    Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: Image.network(
                                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTD8qrkPg5tffSPQIqlxXcW-czht693ZlfJnHGej1zZUVvStsw638N4108&s',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Castontext(
                                    fontSize: Get.height * 0.016,
                                    fontWeight: FontWeight.w600,
                                    textColor: Colors.black.withOpacity(.6),
                                    text: ('UID: ${selectedUser!['user_id']}').appTr,
                                  ),
                                  const SizedBox(height: 8),
                                  Castontext(
                                    fontSize: Get.height * 0.015,
                                    fontWeight: FontWeight.w400,
                                    textColor: Colors.black.withOpacity(.6),
                                    text:
                                        ('Name: ${selectedUser!['name'] ?? 'N/A'}').appTr,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ("Level: ${selectedUser!['level'] ?? 'N/A'}").appTr,
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                  : SizedBox(),
            ),

            /// Coin amount field
            Obx(() {
              return Center(
                child: Container(
                  width: kWeight * 0.8,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  margin: EdgeInsets.only(top: selectedUser != null ? 20 : 0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: tradingController.amount,
                    onChanged: (value) {
                      // এখানে শুধু method call করুন
                      tradingController.calculatePercentage(value);
                    },
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.only(right: 10),
                      suffixStyle: TextStyle(
                        color: Colors.purple[700],
                        fontSize: kHeight * 0.014,
                        fontWeight: FontWeight.bold,
                      ),
                      suffixText:
                          tradingController.calculatedAmount.value.isNotEmpty
                              ? tradingController.calculatedAmount.value
                              : null,
                      icon:
                          Icon(Icons.currency_bitcoin, color: Colors.grey[600]),
                      hintText: ('Enter Coin amount').appTr,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              );
            }),

            SizedBox(height: kHeight * 0.02),

            /// Submit Button
            /// Submit Button
            SizedBox(
              width: kWeight * 0.7,
              height: kHeight * 0.055,
              child: ElevatedButton(
                onPressed: () {
                  // // Validation: Check if user is selected
                  // if (selectedUser == null) {
                  //   Fluttertoast.showToast(
                  //     msg: "Please search and select a user first",
                  //     backgroundColor: Colors.orange,
                  //     textColor: Colors.white,
                  //   );
                  //   return;
                  // }
                  //
                  // // Validation: Check if amount is entered
                  // if (tradingController.amount.text.trim().isEmpty) {
                  //   Fluttertoast.showToast(
                  //     msg: "Please enter coin amount",
                  //     backgroundColor: Colors.orange,
                  //     textColor: Colors.white,
                  //   );
                  //   return;
                  // }

                  // Pass the SELECTED USER's ID (not authenticated user's ID)
                  tradingController.coinTrading(
                    userid: '${selectedUser!['id']}',
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xffade8f0),  const Color(0xffcdaafc),

                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    child: Text(
                      ('Submit').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: kHeight*0.018,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
