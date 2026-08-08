import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AccountSafetyPage extends StatelessWidget {
  const AccountSafetyPage({
    super.key,
    this.onOpenAccountDeletion,
  });

  final VoidCallback? onOpenAccountDeletion;

  static const String supportEmail = 'help24imran@gmail.com';
  static const String deletionUrl = 'https://linlive.fr/delete-account';
  static const String childSafetyContact = 'help24imran@gmail.com';

  void _toast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(message);
  }

  Future<void> _copyEmail() =>
      _copyText(supportEmail, ('Support email copied').appTr);

  Future<void> _copyDeletionUrl() =>
      _copyText(deletionUrl, ('Account deletion link copied').appTr);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffaf7ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          ('Account & Safety').appTr,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          children: [
            _heroCard(),

            const SizedBox(height: 16),

            _sectionCard(
              title: ('Protect Your Account').appTr,
              children:  [
                _SafetyItem(
                  icon: Icons.lock_rounded,
                  title: ('Keep login details private').appTr,
                  text:
                  ('Never share your password, OTP, verification code, or account access with anyone.').appTr,
                ),
                _SafetyItem(
                  icon: Icons.phone_android_rounded,
                  title: ('Use your own device').appTr,
                  text:
                  ('Avoid logging in from unknown devices. Log out if you use a shared phone.').appTr,
                ),
                _SafetyItem(
                  icon: Icons.verified_user_rounded,
                  title: ('Verify your information').appTr,
                  text:
                  ('Use accurate profile and contact information to keep your account trusted.').appTr,
                ),
              ],
            ),

            const SizedBox(height: 14),

            _sectionCard(
              title: ('Community Safety').appTr,
              children:  [
                _SafetyItem(
                  icon: Icons.report_rounded,
                  title: ('Report unsafe behavior').appTr,
                  text:
                  ('Report users, live rooms, messages, or comments that violate our community rules.').appTr,
                ),
                _SafetyItem(
                  icon: Icons.block_rounded,
                  title: ('Block unwanted users').appTr,
                  text:
                  ('Use the block feature to stop unwanted interaction from another user.').appTr,
                ),
                _SafetyItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: ('Moderation review').appTr,
                  text:
                  ('Reported content may be reviewed and action may be taken against violating accounts.').appTr,
                ),
              ],
            ),

            const SizedBox(height: 14),

            _sectionCard(
              title: ('Account Deletion & Data').appTr,
              children: [
                _SafetyItem(
                  icon: Icons.delete_outline_rounded,
                  title: ('Request account deletion').appTr,
                  text:
                  ('Use Settings → Account Deletion for an authenticated request. If you cannot access the app, use the public deletion page.').appTr,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onOpenAccountDeletion ?? _copyDeletionUrl,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: Text(
                      (onOpenAccountDeletion != null
                          ? 'Open Account Deletion'
                          : 'Copy Account Deletion Link')
                          .appTr,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffd9365c),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  deletionUrl,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff3658b5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _copyEmail,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff8A4CF7).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xff8A4CF7).withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_rounded,
                          color: Color(0xff8A4CF7),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            supportEmail,
                            style: GoogleFonts.poppins(
                              color: const Color(0xff8A4CF7),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          ('Copy').appTr,
                          style: GoogleFonts.poppins(
                            color: const Color(0xff8A4CF7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _sectionCard(
              title: ('Child Safety').appTr,
              children: [
                _SafetyItem(
                  icon: Icons.child_care_rounded,
                  title: ('Zero tolerance for child exploitation').appTr,
                  text:
                  ('Child Sexual Abuse and Exploitation, child sexual abuse material, grooming, sextortion, trafficking, predatory behavior, and any content that endangers a child are prohibited.').appTr,
                ),
                _SafetyItem(
                  icon: Icons.health_and_safety_rounded,
                  title: ('Report child-safety concerns').appTr,
                  text:
                  ('Use the in-app report tools or contact $childSafetyContact. Confirmed prohibited material is removed and reported to the appropriate authority where required by law.').appTr,
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xff8A4CF7),
            Color(0xffB460F0),
            Color(0xff15bccd),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xff8A4CF7).withOpacity(0.24),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 66,
            width: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
              ),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            ('Your safety matters').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ('Use these safety tips and tools to protect your account and community experience.').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.88),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xff8A4CF7).withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xff2d2340),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SafetyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _SafetyItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xff8A4CF7).withOpacity(0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xff8A4CF7),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff2d2340),
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff6f657d),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}