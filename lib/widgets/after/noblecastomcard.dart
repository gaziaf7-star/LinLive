import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/layout_constant.dart';
import 'CastomText.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class NobelCustomCard extends StatefulWidget {
  final String diayloText;
  final String image;

  const NobelCustomCard({
    super.key,
    required this.diayloText,
    required this.image,
  });

  @override
  State<NobelCustomCard> createState() => _NobelCustomCardState();
}

class _NobelCustomCardState extends State<NobelCustomCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double kHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        Get.dialog(
          Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xff8A4CF7),
                        Color(0xffB460F0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/audio_live/crown.png',
                        height: kHeight * 0.03,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(
                        height: kHeight * 0.01,
                      ),
                      Castontext(
                        textColor: Color(0xfff5f3ff), // Bright off-white
                        fontWeight: FontWeight.w700,
                        fontSize: kHeight * 0.02,
                        text: widget.diayloText,
                      ),
                      SizedBox(
                        height: kHeight * 0.01,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset(
                  'assets/audio_live/luxury-car-speeds-by-modern-building-dusk-generative-ai.jpg',
                  height: kHeight * 0.12,
                  width: kWeight * 0.6,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: kWeight * 0.5, // 🔥 Full-width button
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors
                          .transparent, // Must be transparent for gradient
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xffa259f7), Color(0xff8206e6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: kHeight * 0.014),
                        alignment: Alignment.center,
                        child: Castontext(
                          textColor: Colors.white,
                          fontSize: kHeight * 0.014,
                          text: ('Understood').appTr,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: kHeight * 0.03,
                )
              ],
            ),
          ),
        );
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isPressed
                    ? [Color(0xff7b0cd6), Color(0xff520f9d)] // Dark on press
                    : [Color(0xffe4d8fa), Color(0xfff4f2f6)], // Default
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Image.asset(
              widget.image,
              height: kHeight * 0.018,
            ),
          ),
          SizedBox(height: kHeight * 0.007),
          Text(
            widget.diayloText,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              color: Color(0xff7b0cd6),
              fontWeight: FontWeight.w600,
              fontSize: kHeight * 0.009,
            ),
          ),
        ],
      ),
    );
  }
}
