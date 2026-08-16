import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class CommunityGuidelinesPage extends StatelessWidget {
  const CommunityGuidelinesPage({super.key});

  static const String _appName = 'LinLive';
  static const String _supportEmail = 'help24imran@gmail.com';
  static const String _website = 'https://linlive.fr';
  static const String _deleteAccountUrl = 'https://linlive.fr/delete-account';
  static const String _childSafetyContact = 'help24imran@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          ('Community Guidelines').appTr,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _centerTitle(('$_appName COMMUNITY GUIDELINES').appTr),
              const SizedBox(height: 8),
              _centerSubTitle(('Last Updated: August 16, 2026').appTr),
              const SizedBox(height: 20),
              _paragraph(
                ('These Guidelines apply to live audio, live video, voice rooms, profiles, comments, posts, messages, gifts, virtual items, games, and all other community features. Before creating, broadcasting, posting, uploading, or sharing user-generated content, users must accept and follow our Terms of Service, Privacy Policy, and these Community Guidelines.').appTr,
              ),

              _paragraph(
                ('We apply zero tolerance to child sexual abuse and exploitation, child sexual abuse material, grooming, sextortion, trafficking, predatory behavior, and other content or conduct that endangers a child.').appTr,
              ),

              _sectionTitle(('1. Respect and Authenticity').appTr),
              _smallBullet(('Do not harass, bully, threaten, shame, stalk, or abuse another person.').appTr),
              _smallBullet(('Do not promote hate or discrimination based on protected characteristics.').appTr),
              _smallBullet(('Do not impersonate another person, host, company, moderator, or public authority.').appTr),
              _smallBullet(('Do not use fake verification, deceptive profiles, or coordinated fake engagement.').appTr),

              _sectionTitle(('2. Sexual, Exploitative, Child-Endangering, and Harmful Content').appTr),
              _smallBullet(('Nudity, pornography, sexually explicit activity, sexual services, exploitation, and non-consensual intimate content are prohibited.').appTr),
              _smallBullet(('Child Sexual Abuse and Exploitation (CSAE), Child Sexual Abuse Material (CSAM), grooming, sextortion, sexualization of minors, trafficking, and predatory interaction with children are strictly prohibited.').appTr),
              _smallBullet(('We remove confirmed CSAM or child-endangering content, restrict involved accounts, preserve relevant safety records where lawful, and report confirmed material to the appropriate regional authority where required by law.').appTr),
              _smallBullet(('Do not encourage self-harm, dangerous challenges, severe violence, or behavior likely to cause injury.').appTr),
              _smallBullet(('Do not use coercion, blackmail, threats, or non-consensual sharing of intimate or private content.').appTr),
              _smallBullet(('Child-safety concerns can be reported in the app or to $_childSafetyContact.').appTr),

              _sectionTitle(('3. Illegal, Fraudulent, and Unsafe Activity').appTr),
              _smallBullet(('Scams, phishing, fake recharge, money laundering, account theft, and unauthorized financial activity are prohibited.').appTr),
              _smallBullet(('Do not promote illegal goods, drugs, weapons, criminal services, or harmful activity.').appTr),
              _smallBullet(('Do not promote gambling, betting, lottery, cash games, cash prizes, or unlawful reward systems.').appTr),
              _smallBullet(('Do not expose another person’s private information without authorization.').appTr),
              _smallBullet(('Do not hack, exploit, reverse engineer, spam, or disrupt the app, servers, rooms, or other users.').appTr),

              _sectionTitle(('4. Live Rooms, Chat, and Messages').appTr),
              _smallBullet(('Hosts and users are responsible for content they broadcast, post, comment, or send.').appTr),
              _smallBullet(('Spam, repeated unwanted messages, abusive comments, and disruptive behavior are prohibited.').appTr),
              _smallBullet(('Hosts should stop unsafe or prohibited activity in their rooms when they become aware of it.').appTr),
              _smallBullet(('Public content and reported private content may be reviewed for safety and policy enforcement.').appTr),

              _sectionTitle(('5. Coins, Gifts, Purchases, and Promotions').appTr),
              _smallBullet(('Virtual coins, diamonds, gifts, badges, frames, and VIP features are platform features, not direct cash.').appTr),
              _smallBullet(('Do not sell, trade, exchange, or transfer accounts or virtual items outside official platform rules.').appTr),
              _smallBullet(('The Google Play version uses Google Play Billing for in-app digital purchases where required.').appTr),
              _smallBullet(('Manual recharge, reseller recharge, external payment links, QR codes, and unauthorized payment instructions are not allowed inside the Google Play version.').appTr),
              _smallBullet(('Games, lucky features, rankings, or events must not be used for real-money gambling, betting, cash prizes, or cash withdrawal.').appTr),

              _sectionTitle(('6. Reporting, Blocking, and Moderation').appTr),
              _paragraph(
                ('Users can report objectionable users, public or reported private content, live rooms, comments, messages, posts, or other content using available in-app reporting tools. Users can block unwanted users. Our moderation team reviews reports and takes action that is reasonable for the content, context, severity, and risk.').appTr,
              ),
              _smallBullet(('We may remove content, mute users, stop rooms, restrict features, suspend accounts, or permanently ban accounts.').appTr),
              _smallBullet(('Repeated or severe violations may result in action without prior warning.').appTr),
              _smallBullet(('Serious safety or legal violations may be reported to appropriate authorities.').appTr),
              _smallBullet(('Users may contact support for reports, appeals, or safety concerns.').appTr),

              _sectionTitle(('7. Account Safety and Deletion').appTr),
              _smallBullet(('Protect your login information and device.').appTr),
              _smallBullet(('Do not create replacement accounts to avoid restrictions or bans.').appTr),
              _smallBullet(('Account deletion requests can be submitted from Settings → Account Deletion or through the public deletion webpage at $_deleteAccountUrl.').appTr),
              _smallBullet(('Deletion may remove account access, profile information, social connections, and virtual items, while limited legal, safety, fraud, accounting, or dispute records may be retained.').appTr),

              _sectionTitle(('8. Privacy and Personal Information').appTr),
              _smallBullet(('Do not post passwords, payment security codes, government IDs, or home addresses publicly.').appTr),
              _smallBullet(('Data is collected and used according to our Privacy Policy and Google Play Data Safety disclosure.').appTr),
              _smallBullet(('Use reporting tools if another user shares your private information without permission.').appTr),

              _sectionTitle(('9. Enforcement and Appeals').appTr),
              _paragraph(
                ('Enforcement decisions consider the content, context, severity, repeated behavior, user safety, and applicable law. Users may contact support to appeal moderation or account actions. Submitting an appeal does not guarantee reversal.').appTr,
              ),

              _sectionTitle(('10. Contact Us').appTr),
              _contactRow('Support:', _supportEmail),
              _contactRow('Child safety:', _childSafetyContact),
              _contactRow('Website:', _website),
              _contactRow('Account deletion:', _deleteAccountUrl),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _centerTitle(String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
    ),
  );

  static Widget _centerSubTitle(String text) => Center(
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  static Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
    ),
  );

  static Widget _paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      textAlign: TextAlign.justify,
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontSize: 13.5,
        height: 1.65,
      ),
    ),
  );

  static Widget _smallBullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '• ',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.justify,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _contactRow(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontSize: 13.5,
          height: 1.5,
        ),
        children: <TextSpan>[
          TextSpan(
            text: '$title ',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
