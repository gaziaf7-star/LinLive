import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import 'medialinksdocs.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Messangerprofile extends StatelessWidget {
  const Messangerprofile({super.key});

  // Dummy actions for each option
  void _openMedia() {
    Get.snackbar(('Media').appTr, ('Open media, links & docs').appTr,
        backgroundColor: Colors.deepPurple, colorText: Colors.white);
  }

  void _toggleFavorite() {
    Get.snackbar(('Favorite').appTr, ('Added to favorites').appTr,
        backgroundColor: Colors.deepPurple, colorText: Colors.white);
  }

  void _blockUser() {
    Get.defaultDialog(
      title: ('Block User').appTr,
      titleStyle: GoogleFonts.poppins(fontSize: Get.height  * 0.022,fontWeight: FontWeight.w600),
      middleText: ('Are you sure you want to block this user?').appTr,
      textConfirm: ('Yes').appTr,
      textCancel: ('No').appTr,
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back();
        Get.snackbar(('Blocked').appTr, ('User has been blocked').appTr,
            backgroundColor: Colors.red, colorText: Colors.white);
      },
    );
  }

  void _reportUser() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading:  Icon(Icons.report, color: Colors.red),
              title:  Text(('Spam').appTr,style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: Get.height * 0.018),),
              onTap: () {
                Get.back();
                Get.snackbar(('Reported').appTr, ('User reported for Spam').appTr,
                    backgroundColor: Colors.red, colorText: Colors.white);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title:  Text(('Harassment').appTr,style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: Get.height * 0.018),),
              onTap: () {
                Get.back();
                Get.snackbar(('Reported').appTr, ('User reported for Harassment').appTr,
                    backgroundColor: Colors.red, colorText: Colors.white);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title:  Text(('Other').appTr,style: GoogleFonts.poppins(fontWeight: FontWeight.w500,fontSize: Get.height * 0.018),),
              onTap: () {
                Get.back();
                Get.snackbar(('Reported').appTr, ('User reported').appTr,
                    backgroundColor: Colors.red, colorText: Colors.white);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteChat() {
    Get.defaultDialog(
      title: ('Delete Chat').appTr,
      middleText: ('Are you sure you want to delete this chat?').appTr,
      titleStyle: GoogleFonts.poppins(fontSize: Get.height  * 0.022,fontWeight: FontWeight.w600),
      textConfirm: ('Yes').appTr,
      textCancel: ('No').appTr,
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back();
        Get.snackbar(('Deleted').appTr, ('Chat deleted').appTr,
            backgroundColor: Colors.redAccent, colorText: Colors.white);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4B0082), // app purple color
      appBar: AppBar(
        backgroundColor: const Color(0xFF4B0082),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),

      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile picture
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/profile/default_avatar.png'),
            ),
            const SizedBox(height: 12),
            // Name
            Text(
              ("John Doe").appTr,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // ID/Number
            Text(
              "+1 234 567 890",
              style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 20),

            // Media, links & docs
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: Text(("Media, links & docs").appTr,
                  style: GoogleFonts.poppins(color: Colors.white)),
              trailing:
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              onTap: (){Get.to(MediaLinksDocsView(),transition: Transition.leftToRight);},
            ),
            Divider(color: Colors.white24, thickness: 1),

            // Mute notifications
            ListTile(
              leading: const Icon(Icons.notifications_off, color: Colors.white),
              title: Text(("Mute notifications").appTr,
                  style: GoogleFonts.poppins(color: Colors.white)),
              trailing: Switch(
                value: true,
                activeColor: Colors.amber,
                onChanged: (val) {
                  Get.snackbar(('Notifications').appTr, val ? ('Muted').appTr: ('Unmuted').appTr,
                      backgroundColor: Colors.deepPurple, colorText: Colors.white);
                },
              ),
            ),
            Divider(color: Colors.white24, thickness: 1),

            // Add to favorites
            ListTile(
              leading: const Icon(Icons.star_border, color: Colors.white),
              title: Text(("Add to favorites").appTr,
                  style: GoogleFonts.poppins(color: Colors.white)),
              trailing:
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              onTap: _toggleFavorite,
            ),
            Divider(color: Colors.white24, thickness: 1),

            // Block
            ListTile(
              leading: const Icon(Icons.block, color: Colors.white),
              title: Text(("Block").appTr,
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: _blockUser,
            ),
            Divider(color: Colors.white24, thickness: 1),

            // Report
            ListTile(
              leading: const Icon(Icons.report, color: Colors.white),
              title: Text(("Report").appTr,
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: _reportUser,
            ),
            Divider(color: Colors.white24, thickness: 1),

            // Delete chat
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: Text(("Delete chat").appTr,
                  style: GoogleFonts.poppins(color: Colors.redAccent)),
              onTap: _deleteChat,
            ),
          ],
        ),
      ),
    );
  }
}


