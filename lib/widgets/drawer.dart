import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/color_constants.dart';
import 'button_with_icon.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
Drawer CustomDrawr() {
  return Drawer(
    child: Center(
      // Center widget added here
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundImage: AssetImage('assets/images/profile-picture.png'),
            ),
            const SizedBox(height: 20),
             Text(
              ('নামঃ সাগর হোসেন').appTr,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
             Text(
              ('ফোনঃ ০১৯৯৪১২১৫৪৫১').appTr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
             Text(
              ('ইমেইলঃ example@email.com').appTr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
             Text(
              ('ঠিকানাঃ ঢাকা, বাংলাদেশ').appTr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 15),
            ButtonWithIcon(
              height: Get.height * 0.07,
              width: Get.width * 0.8,
              backgroundColor: Colors.white,
              borderColor: kPrimaryColor,
              textColor: Colors.black,
              buttonText: ('এড্রেস বুক').appTr,
              onPressed: () {},
              iconColor: Colors.black,
              icone: Icons.book_online,
            ),
            const SizedBox(height: 15),
            ButtonWithIcon(
              height: Get.height * 0.07,
              width: Get.width * 0.8,
              backgroundColor: Colors.white,
              borderColor: kPrimaryColor,
              textColor: Colors.black,
              buttonText: ('প্রোফাইল আপডেট').appTr,
              onPressed: () {
                // Get.to(const ProfileUpdateView());
              },
              iconColor: Colors.black,
              icone: Icons.person_remove_alt_1_outlined,
            ),
            const SizedBox(height: 15),
            ButtonWithIcon(
              height: Get.height * 0.07,
              width: Get.width * 0.8,
              backgroundColor: Colors.white,
              borderColor: kPrimaryColor,
              textColor: Colors.black,
              buttonText: ('পাসওয়ার্ড পরিবর্তন').appTr,
              onPressed: () {
                // Get.to(const PasswordChangeView());
              },
              iconColor: Colors.black,
              icone: Icons.book_online,
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () {
                // Handle logout button press
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label:  Text(('লগ আউট করুন').appTr,
                  style: TextStyle(fontSize: 18, color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
                side: const BorderSide(color: Colors.redAccent, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
