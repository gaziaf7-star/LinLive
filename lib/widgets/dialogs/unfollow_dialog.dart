import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class UnfollowDialog {
  static void show({
    required int userId,
    required Function(int) onUnfollow,
    required Function() onUpdateFollowStatus,
  }) {
    Get.defaultDialog(
      title: '',
      contentPadding: EdgeInsets.all(20),
      backgroundColor: Colors.white,
      radius: 0,
      content: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 50,
          ),
          SizedBox(height: 15),
          Text(
            ('Unfollow').appTr,
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            ('Are you sure you want to unfollow?').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  padding: EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Get.back(),
                child: Text(
                  ('Cancel').appTr,
                  style: GoogleFonts.lato(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Unfollow Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: null,
                  elevation: 0,
                ).copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith(
                    (states) => null,
                  ),
                ),
                onPressed: () {
                  onUnfollow(userId);
                  onUpdateFollowStatus();
                  Get.back();
                },
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xff8A4CF7),
                        Color(0xffB460F0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 12,
                    ),
                    child: Text(
                      ('Unfollow').appTr,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}