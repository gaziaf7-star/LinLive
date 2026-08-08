import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:meetlivepro/constants/image_const/image_conost.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../record/controllers/record_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AccountInformationView extends StatelessWidget {
  const AccountInformationView({super.key});

  Widget glassCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * 0.04,
              vertical: kHeight * 0.025,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.22),
                  Colors.white.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(-4, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.017,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget glassBox(String title, String value, {IconData? icon}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.26),
                    Colors.white.withOpacity(0.09),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.30),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kPostIconColor,
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      size: kHeight * 0.018,
                      color: Colors.amberAccent,
                    ),
                  if (icon != null) const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: kHeight * 0.013,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: kHeight * 0.012,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget backgroundImage() {
    return Positioned.fill(
      child: Image.asset(
        profileImage,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget darkOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAppColor2.withOpacity(0.55),
             kAppColor1.withOpacity(0.45),
              kAppColor2.withOpacity(0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordController = Get.put(RecordController());
    final record = recordController.sessionWiseLiveRecord;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(title: ('Earning').appTr),
      body: Stack(
        children: [
          backgroundImage(),
          darkOverlay(),

          SafeArea(
            child: Obx(() {
              return LoadingOverlay(
                isLoading: recordController.isLoading.value,
                progressIndicator: SpinKitChasingDots(
                  size: 30,
                  color: kPrimaryColor,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  child: Column(
                    children: [
                      glassCard("Today", [
                        Row(
                          children: [
                            glassBox(
                              ("Live Duration").appTr,
                              ("${record['today']?['totalLiveTime'] ?? 0} min").appTr,
                            ),
                            glassBox(
                              ("Coin Income").appTr,
                              "${record['today']?['totalGiftAmount'] ?? 0}",
                              icon: Icons.monetization_on,
                            ),
                          ],
                        ),
                      ]),

                      glassCard("1st to 15th Days", [
                        Row(
                          children: [
                            glassBox(
                              ("Live Duration").appTr,
                              ("${record['firstTO7Days']?['totalLiveTime'] ?? 0} min").appTr,
                            ),
                            glassBox(
                              ("Coin Income").appTr,
                              "${record['firstTO7Days']?['totalGiftAmount'] ?? 0}",
                              icon: Icons.monetization_on,
                            ),
                          ],
                        ),
                      ]),

                      glassCard("16th to 30th Days", [
                        Row(
                          children: [
                            glassBox(
                              ("Live Duration").appTr,
                              ("${record['sixteenthT21Days']?['totalLiveTime'] ?? 0} min").appTr,
                            ),
                            glassBox(
                              ("Coin Income").appTr,
                              "${record['sixteenthT21Days']?['totalGiftAmount'] ?? 0}",
                              icon: Icons.monetization_on,
                            ),
                          ],
                        ),
                      ]),

                      glassCard("Monthly Total", [
                        Row(
                          children: [
                            glassBox(
                              ("Total Live Time").appTr,
                              ("${record['totalMontly']?['totalMontlyTime'] ?? 0} min").appTr,
                            ),
                            glassBox(
                              ("Total Coins").appTr,
                              "${record['totalMontly']?['totalMontlyAmount'] ?? 0}",
                              icon: Icons.monetization_on,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            glassBox(
                              ("Total Time + Gift").appTr,
                              "${record['totalMontly']?['totalTimeAndGiftAmount'] ?? 0}",
                            ),
                          ],
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}