import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const String _appName = 'LinLive';
  static const String _operator = 'Lin Live Team';
  static const String _website = 'https://linlive.fr';
  static const String _supportEmail = 'help24imran@gmail.com';
  static const String _deleteAccountUrl = 'https://linlive.fr/delete-account';
  static const String _childSafetyContact = 'help24imran@gmail.com';

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
          ('About Us').appTr,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCard(),

              const SizedBox(height: 18),

              _sectionCard(
                title: ('Who We Are').appTr,
                children: [
                  _paragraph(
                    ('$_appName is a live streaming and social communication platform where users can connect through live audio, live video, chat, messages, profiles, virtual items and community features.').appTr,
                  ),
                  _paragraph(
                    ('Our goal is to create a safe, friendly and enjoyable space where people can discover communities, communicate respectfully and share positive moments.').appTr,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: ('Our Community Values').appTr,
                children: [
                  _smallBullet(('Respect other users and communicate politely.').appTr),
                  _smallBullet(('Use live, chat and message features responsibly.').appTr),
                  _smallBullet(('Do not share harmful, adult, hateful, illegal, misleading or abusive content.').appTr),
                  _smallBullet(('Report or block users when you see unsafe, abusive or objectionable behavior.').appTr),
                ],
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: ('Safety and Moderation').appTr,
                children: [
                  _paragraph(
                    ('We provide safety tools such as reporting, blocking and moderation review to help protect users and maintain community standards.').appTr,
                  ),
                  _paragraph(
                    ('Content or accounts that violate our User Agreement, Privacy Policy or Community Guidelines may be removed, restricted, suspended or terminated.').appTr,
                  ),
                  _paragraph(
                    ('Public live rooms, comments, profiles and community content may be reviewed for safety, abuse prevention, fraud prevention and policy enforcement.').appTr,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: ('Child Safety Standards').appTr,
                children: [
                  _paragraph(
                    ('$_appName has zero tolerance for Child Sexual Abuse and Exploitation (CSAE), Child Sexual Abuse Material (CSAM), grooming, sextortion, sexualization of minors, trafficking, predatory behavior, or any conduct that endangers a child.').appTr,
                  ),
                  _paragraph(
                    ('Users can submit reports inside the app. We remove confirmed prohibited material, take action against involved accounts, and report confirmed CSAM to the appropriate authority where required by law. Child-safety concerns may also be sent to $_childSafetyContact.').appTr,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: ('Virtual Items and Payments').appTr,
                children: [
                  _paragraph(
                    ('Some features may include virtual items used only for in-app entertainment, profile expression and community interaction. Virtual items do not represent real-world cash value and must not be used for gambling, betting, cash games, cash withdrawal, illegal transactions or unauthorized trading.').appTr,
                  ),
                  _paragraph(
                    ('In the Google Play version of $_appName, digital item purchases must use approved Google Play Billing where required. Manual recharge, reseller recharge, off-platform payment links or external payment instructions are not allowed inside the Play Store version of the app.').appTr,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: ('Privacy and Account Control').appTr,
                children: [
                  _paragraph(
                    ('We respect user privacy and explain our data practices in our Privacy Policy and Google Play Data Safety disclosure.').appTr,
                  ),
                  _paragraph(
                    ('Users can submit an authenticated deletion request from Settings → Account Deletion. Users without app access can use the public deletion page at $_deleteAccountUrl.').appTr,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionCard(
                title: ('Contact Us').appTr,
                children: [
                  _paragraph(
                    ('For support, safety reports, privacy questions, account deletion requests or account help, please contact us through our official support channels.').appTr,
                  ),
                  _contactRow('Website:', _website),
                  _contactRow('Email:', _supportEmail),
                  _contactRow('Account deletion:', _deleteAccountUrl),
                  _contactRow('Child safety:', _childSafetyContact),
                  _contactRow('Operator:', _operator),
                ],
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  ('Last Updated: August 10, 2026').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff7b7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
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
            color: const Color(0xff8A4CF7).withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 74,
            width: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
              ),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            ('Welcome to $_appName').appTr,
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
            ('Live streaming, chat and community interaction in one place.').appTr,
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
          _sectionTitle(title),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: const Color(0xff2d2340),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.4,
      ),
    );
  }

  static Widget _paragraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: GoogleFonts.poppins(
          color: const Color(0xff4b4458),
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          height: 1.65,
        ),
      ),
    );
  }

  static Widget _smallBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7),
            height: 6,
            width: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xff8A4CF7),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.poppins(
                color: const Color(0xff4b4458),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _contactRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            color: const Color(0xff4b4458),
            fontSize: 13.5,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$title ',
              style: GoogleFonts.poppins(
                color: const Color(0xff2d2340),
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}