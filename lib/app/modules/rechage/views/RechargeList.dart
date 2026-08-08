import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/layout_constant.dart';
import '../controllers/rechage_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Rechargelist extends GetView<RechageController> {
  const Rechargelist({super.key});

  @override
  Widget build(BuildContext context) {
    RechageController rechageController = Get.put(RechageController());
    return Scaffold(
      body: FutureBuilder(
        future: rechageController.showResellerList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 🔹 Shimmer Loading UI
            return ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(
                    horizontal: kWeight * 0.03, vertical: kHeight * 0.003),
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.grey.shade300),
                  child: Padding(
                    padding: EdgeInsets.all(5.0),
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                        ),
                        title: Container(
                          height: 16,
                          width: 100,
                          color: Colors.white,
                        ),
                        subtitle: Container(
                          height: 14,
                          width: 60,
                          margin: EdgeInsets.only(top: 5),
                          color: Colors.white,
                        ),
                        trailing: Container(
                          height: 30,
                          width: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text(("Error loading data").appTr));
          } else {
            return ListView.builder(
              itemCount: rechageController.resellerListData.length,
              itemBuilder: (context, index) {

                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: kWeight * 0.035,
                    vertical: kHeight * 0.008,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFE8A3),
                          Color(0xFFFFC947),
                          Color(0xFFB87900),
                          Color(0xFFFFD66B),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFC947).withOpacity(.35),
                          blurRadius: 22,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(.35),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: kWeight * 0.035,
                        vertical: kHeight * 0.014,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(23),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF080808),
                            Color(0xFF17130B),
                            Color(0xFF251A08),
                            Color(0xFF0A0A0A),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -35,
                            top: -35,
                            child: Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFC947).withOpacity(.12),
                              ),
                            ),
                          ),

                          Positioned(
                            left: 55,
                            bottom: -45,
                            child: Container(
                              width: 150,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                color: const Color(0xFFFFB800).withOpacity(.08),
                              ),
                            ),
                          ),

                          Row(
                            children: [
                              Container(
                                width: kHeight * 0.075,
                                height: kHeight * 0.075,
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFF2B8),
                                      Color(0xFFFFC947),
                                      Color(0xFFB87900),
                                      Color(0xFFFFE08A),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFC947).withOpacity(.55),
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF111111),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: CachedNetworkImage(
                                      imageUrl:
                                      '$kDomainUrl/${rechageController.resellerListData[index]['profile_image']}',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => CircleAvatar(
                                        backgroundColor: const Color(0xFF1C1C1C),
                                        child: Icon(
                                          Icons.person,
                                          color: const Color(0xFFFFD66B),
                                          size: kHeight * 0.032,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => CircleAvatar(
                                        backgroundColor: const Color(0xFF1C1C1C),
                                        child: Icon(
                                          Icons.person,
                                          color: const Color(0xFFFFD66B),
                                          size: kHeight * 0.032,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: kWeight * 0.035),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${rechageController.resellerListData[index]['name']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.playfairDisplay(
                                        fontWeight: FontWeight.w800,
                                        fontSize: kHeight * 0.021,
                                        color: const Color(0xFFFFE9A6),
                                        shadows: [
                                          Shadow(
                                            color: const Color(0xFFFFB800).withOpacity(.55),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: kHeight * 0.006),

                                    Row(
                                      children: [
                                        Container(
                                          width: kWeight * 0.13,
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFFFFD66B).withOpacity(.0),
                                                const Color(0xFFFFD66B),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Icon(
                                            Icons.diamond_rounded,
                                            size: kHeight * 0.014,
                                            color: const Color(0xFFFFD66B),
                                          ),
                                        ),
                                        Container(
                                          width: kWeight * 0.13,
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFFFFD66B),
                                                const Color(0xFFFFD66B).withOpacity(.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: kHeight * 0.006),

                                    Text(
                                      ('ID : ${rechageController.resellerListData[index]['id']}').appTr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: kHeight * 0.0145,
                                        color: const Color(0xFFFFF1C1),
                                        letterSpacing: .4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(width: kWeight * 0.02),

                              InkWell(
                                borderRadius: BorderRadius.circular(100),
                                onTap: () async {
                                  try {
                                    final phoneNumber = rechageController
                                        .resellerListData[index]['whatsapp_number'];

                                    final cleanNumber = phoneNumber
                                        .toString()
                                        .replaceAll(RegExp(r'[^\d]'), '');

                                    String formattedNumber = cleanNumber;

                                    if (cleanNumber.startsWith('01')) {
                                      formattedNumber = '88$cleanNumber';
                                    } else if (cleanNumber.startsWith('8801')) {
                                      formattedNumber = cleanNumber;
                                    }

                                    final whatsappUrl = "https://wa.me/$formattedNumber";
                                    print("Opening WhatsApp URL: $whatsappUrl");

                                    await launchUrl(
                                      Uri.parse(whatsappUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (e) {
                                    print("WhatsApp Error: $e");

                                    try {
                                      final phoneNumber =
                                      rechageController.resellerListData[index]['phone'];

                                      final cleanNumber = phoneNumber
                                          .toString()
                                          .replaceAll(RegExp(r'[^\d]'), '');

                                      String formattedNumber =
                                      cleanNumber.startsWith('01')
                                          ? '88$cleanNumber'
                                          : cleanNumber;

                                      await launchUrl(
                                        Uri.parse(
                                          "https://web.whatsapp.com/send?phone=$formattedNumber",
                                        ),
                                        mode: LaunchMode.inAppWebView,
                                      );
                                    } catch (e2) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(
                                          content: Text(('Could not open WhatsApp').appTr),
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  width: kHeight * 0.056,
                                  height: kHeight * 0.056,
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFF2B8),
                                        Color(0xFFFFC947),
                                        Color(0xFFB87900),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFC947).withOpacity(.55),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(kHeight * 0.009),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF1A1A1A),
                                          Color(0xFF050505),
                                        ],
                                      ),
                                    ),
                                    child: Image.asset(
                                      'assets/frame/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
