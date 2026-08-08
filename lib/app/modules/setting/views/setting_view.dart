import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_language_page.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/app/modules/auth/views/community_guidelines_page.dart';
import 'package:meetlivepro/app/modules/auth/views/privacy_policy_page.dart';
import 'package:meetlivepro/app/modules/auth/views/user_agreement_page.dart';
import 'package:meetlivepro/app/modules/setting/views/widgets/about_page.dart';

import 'package:meetlivepro/app/modules/setting/views/widgets/account_dettection_page.dart';
import 'package:meetlivepro/app/modules/setting/views/widgets/account_safety_page.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../constants/name_constants.dart';

import '../../notification/views/notification_view.dart';
import '../../registersteps/controllers/registersteps_controller.dart';
import 'LoginPassword.dart';
import 'blockList.dart';

class SettingController extends GetxController {}

class SettingView extends GetView<SettingController> {
  const SettingView({Key? key}) : super(key: key);

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  void _showLogoutDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff8A4CF7),
                      Color(0xffB460F0),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                ('Log out?').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff2d2340),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ('Are you sure you want to log out from your account?').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff6f657d),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        ('Cancel').appTr,
                        style: GoogleFonts.poppins(
                          color: const Color(0xff6f657d),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.find<RegisterstepsController>().tryToSignOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff8A4CF7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        ('Log out').appTr,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
  }

  void _cleanCache() {
    _showToast(('Cache cleaned').appTr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffaf7ff),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kAppColor2,
                kAppColor1,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
        ),
        title: Text(
          ('Settings').appTr,
          style: GoogleFonts.lato(
            fontSize: kHeight * 0.022,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: kHeight * 0.20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kAppColor2,
                  kAppColor1,
                  const Color(0xfffaf7ff),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: kWeight * 0.04,
                vertical: kHeight * 0.018,
              ),
              children: [
                _profileHeaderCard(),

                SizedBox(height: kHeight * 0.018),

                _sectionCard(
                  title: ('Account').appTr,
                  children: [
                    _settingTile(
                      icon: Icons.block_rounded,
                      title: ('Block List').appTr,
                      subtitle: ('Manage blocked users').appTr,
                      onTap: () {
                        Get.to(
                          BlockListPage(),
                          transition: Transition.fade,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.password_rounded,
                      title: ('Change Password').appTr,
                      subtitle: ('Update your account password').appTr,
                      onTap: () {
                        Get.to(
                          const LoginPassword(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.notifications_active_rounded,
                      title: ('Notification').appTr,
                      subtitle: ('View your notifications').appTr,
                      onTap: () {
                        Get.to(
                          NotificationView(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.security_rounded,
                      title: ('Account & Safety').appTr,
                      subtitle: ('Safety, login and account protection').appTr,
                      onTap: () {
                        Get.to(
                          AccountSafetyPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                  ],
                ),

                SizedBox(height: kHeight * 0.014),

                _sectionCard(
                  title: ('Legal & Safety').appTr,
                  children: [
                    _settingTile(
                      icon: Icons.privacy_tip_rounded,
                      title: ('Privacy Policy').appTr,
                      subtitle: ('How we collect and protect data').appTr,
                      onTap: () {
                        Get.to(
                          const PrivacyPolicyPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.description_rounded,
                      title: ('User Agreement').appTr,
                      subtitle: ('Terms of using LinLive').appTr,
                      onTap: () {
                        Get.to(
                          const UserAgreementPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.verified_user_rounded,
                      title: ('Community Guidelines').appTr,
                      subtitle: ('Rules for live, chat and messages').appTr,
                      onTap: () {
                        Get.to(
                          const CommunityGuidelinesPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.info_rounded,
                      title: ('About Us').appTr,
                      subtitle: ('Learn more about LinLive').appTr,
                      onTap: () {
                        Get.to(
                          const AboutUsPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                  ],
                ),

                SizedBox(height: kHeight * 0.014),

                _sectionCard(
                  title: ('App').appTr,
                  children: [
                    _settingTile(
                      icon: Icons.language_rounded,
                      title: 'Language'.appTr,
                      subtitle: AppLanguageController.to.currentLanguageSubtitle,
                      onTap: () {
                        Get.to(
                              () => const AppLanguagePage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                    _settingTile(
                      icon: Icons.cleaning_services_rounded,
                      title: ('Clean Cache').appTr,
                      subtitle: ('Clear temporary app data').appTr,
                      trailingText: '100Mb',
                      onTap: _cleanCache,
                    ),
                    _settingTile(
                      icon: Icons.system_update_alt_rounded,
                      title: ('Version').appTr,
                      subtitle: ('Current app version').appTr,
                      trailingText: kAppVersion,
                      onTap: () {},
                    ),
                    _settingTile(
                      icon: Icons.delete_outline_rounded,
                      title: ('Account Deletion Request').appTr,
                      subtitle: ('Request account and data deletion').appTr,
                      danger: true,
                      onTap: () {
                        Get.to(
                          const AccountDeletionPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                    ),
                  ],
                ),

                SizedBox(height: kHeight * 0.032),

                _logoutButton(),

                SizedBox(height: kHeight * 0.05),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.96),
            const Color(0xfff7edff),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff8A4CF7).withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.75),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xff8A4CF7),
                  Color(0xffB460F0),
                ],
              ),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('App Settings').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff2d2340),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ('Manage privacy, safety and app preferences').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff6f657d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff8A4CF7).withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xff8A4CF7),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingText,
    bool danger = false,
  }) {
    final Color mainColor =
    danger ? const Color(0xffff5f7e) : const Color(0xff8A4CF7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: mainColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: mainColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.2,
                      fontWeight: FontWeight.w700,
                      color: danger
                          ? const Color(0xffff5f7e)
                          : const Color(0xff2d2340),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.8,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff8a8198),
                    ),
                  ),
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff8a8198),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.withOpacity(0.65),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return InkWell(
      onTap: _showLogoutDialog,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        height: kHeight * 0.057,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              Color(0xff8A4CF7),
              Color(0xffB460F0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff8A4CF7).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          ('Log out').appTr,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}