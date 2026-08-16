import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_language_page.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/app/modules/auth/views/community_guidelines_page.dart';
import 'package:meetlivepro/app/modules/auth/views/privacy_policy_page.dart';
import 'package:meetlivepro/app/modules/auth/views/user_agreement_page.dart';
import 'package:meetlivepro/app/modules/setting/views/widgets/about_page.dart';
import 'package:meetlivepro/app/modules/setting/views/widgets/account_dettection_page.dart';
import 'package:meetlivepro/app/modules/setting/views/widgets/account_safety_page.dart';

import '../../../../constants/name_constants.dart';

import '../../notification/views/notification_view.dart';
import '../../registersteps/controllers/registersteps_controller.dart';
import 'LoginPassword.dart';
import 'blockList.dart';

class SettingController extends GetxController {}

class SettingView extends GetView<SettingController> {
  const SettingView({Key? key}) : super(key: key);

  static const Color _pageBg = Color(0xffF5F5F5);
  static const Color _dividerColor = Color(0xffEEEEEE);
  static const Color _arrowColor = Color(0xffC7C9CE);
  static const Color _textColor = Color(0xff252525);
  static const Color _yellowStart = Color(0xffFFEE2E);
  static const Color _yellowEnd = Color(0xffFFBD13);

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_yellowStart, _yellowEnd],
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xff2F2F2F),
                  size: 29,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ('Log out?').appTr,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ('Are you sure you want to log out from your account?').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  height: 1.45,
                  color: const Color(0xff777777),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textColor,
                        side: const BorderSide(color: Color(0xffDDDDDD)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        ('Cancel').appTr,
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [_yellowStart, _yellowEnd],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          Get.find<RegisterstepsController>().tryToSignOut();
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: _textColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          ('Log out').appTr,
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w800,
                          ),
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
      backgroundColor: _pageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 66,
        leadingWidth: 70,
        leading: IconButton(
          onPressed: () => Get.back(),
          splashRadius: 24,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textColor,
            size: 30,
          ),
        ),
        title: Text(
          ('Settings').appTr,
          style: GoogleFonts.lato(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xff152019),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: _dividerColor,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ACCOUNT GROUP
            _whiteGroup(
              children: [
                _settingRow(
                  icon: Icons.block_rounded,
                  title: ('Block List').appTr,
                  onTap: () {
                    Get.to(
                      BlockListPage(),
                      transition: Transition.fade,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.password_rounded,
                  title: ('Change Password').appTr,
                  onTap: () {
                    Get.to(
                      const LoginPassword(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.notifications_rounded,
                  title: ('Notification').appTr,
                  onTap: () {
                    Get.to(
                      NotificationView(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.security_rounded,
                  title: ('Account & Safety').appTr,
                  onTap: () {
                    Get.to(
                      AccountSafetyPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
              ],
            ),

            _sectionGap(),

            // LEGAL GROUP
            _whiteGroup(
              children: [
                _settingRow(
                  icon: Icons.privacy_tip_rounded,
                  title: ('Privacy Policy').appTr,
                  onTap: () {
                    Get.to(
                      const PrivacyPolicyPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.description_rounded,
                  title: ('User Agreement').appTr,
                  onTap: () {
                    Get.to(
                      const UserAgreementPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.verified_user_rounded,
                  title: ('Community Guidelines').appTr,
                  onTap: () {
                    Get.to(
                      const CommunityGuidelinesPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
              ],
            ),

            _sectionGap(),

            // APP / INFO GROUP
            _whiteGroup(
              children: [
                _settingRow(
                  icon: Icons.info_outline_rounded,
                  title: ('About Us').appTr,
                  onTap: () {
                    Get.to(
                      const AboutUsPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.language_rounded,
                  title: ('Language').appTr,
                  trailingText:
                  AppLanguageController.to.currentLanguageSubtitle,
                  onTap: () {
                    Get.to(
                          () => const AppLanguagePage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _settingRow(
                  icon: Icons.cleaning_services_rounded,
                  title: ('Clean Cache').appTr,
                  trailingText: '100Mb',
                  onTap: _cleanCache,
                ),
                _settingRow(
                  icon: Icons.delete_outline_rounded,
                  title: ('Account Deletion Request').appTr,
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

            const SizedBox(height: 38),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: _logoutButton(),
            ),

            const SizedBox(height: 22),

            Center(
              child: Text(
                '_Version:$kAppVersion',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xffA7A7A7),
                ),
              ),
            ),

            const SizedBox(height: 54),
          ],
        ),
      ),
    );
  }

  Widget _whiteGroup({
    required List<Widget> children,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 0,
                endIndent: 0,
                color: _dividerColor,
              ),
          ],
        ],
      ),
    );
  }

  Widget _sectionGap() {
    return const SizedBox(height: 14);
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailingText,
    bool danger = false,
  }) {
    final Color rowColor =
    danger ? const Color(0xffD94B4B) : const Color(0xff353535);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      icon,
                      size: 25,
                      color: rowColor,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: rowColor,
                    ),
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 115),
                    child: Text(
                      trailingText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff9B9B9B),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 19,
                  color: _arrowColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return InkWell(
      onTap: _showLogoutDialog,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: double.infinity,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            colors: [_yellowStart, _yellowEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Text(
          ('Logout').appTr,
          style: GoogleFonts.lato(
            color: const Color(0xff3A3A3A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
