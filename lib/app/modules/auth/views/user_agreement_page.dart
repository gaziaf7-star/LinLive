import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({super.key});

  static const String _appName = 'LinLive';
  static const String _operator = 'Lin Live Team';
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
          ('User Agreement').appTr,
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
              _centerTitle(('$_appName – TERMS OF SERVICE').appTr),
              const SizedBox(height: 8),
              _centerSubTitle(('Last Updated: August 16, 2026').appTr),
              const SizedBox(height: 20),
              _paragraph(
                ('These Terms of Service ("Terms") govern access to and use of the $_appName mobile application, website, and related services provided by $_operator. By creating an account or using the service, you agree to these Terms, our Privacy Policy, and our Community Guidelines.').appTr,
              ),

              _sectionTitle(('1. Eligibility and Accounts').appTr),
              _bullet(
                ('Age Requirement:').appTr,
                ('You must be at least 18 years old to create or use an account.').appTr,
              ),
              _bullet(
                ('Accurate Information:').appTr,
                ('You must provide accurate and current registration and profile information.').appTr,
              ),
              _bullet(
                ('Account Security:').appTr,
                ('You are responsible for protecting your credentials and for activity performed through your account.').appTr,
              ),
              _bullet(
                ('Misuse:').appTr,
                ('Fake accounts, impersonation, deceptive identity information, ban evasion, unauthorized access, and account trading are prohibited.').appTr,
              ),

              _sectionTitle(('2. User-Generated Content').appTr),
              _paragraph(
                ('Users may create live audio, live video, room titles, profiles, images, posts, comments, messages, and other content. Before creating or uploading user-generated content, you must accept and follow these Terms and our Community Guidelines. You remain responsible for content you create, upload, broadcast, or share.').appTr,
              ),
              _smallBullet(('No nudity, pornography, sexually explicit services, exploitation, or harmful sexual content.').appTr),
              _smallBullet(('No harassment, threats, hate speech, bullying, graphic violence, or dangerous behavior.').appTr),
              _smallBullet(('No Child Sexual Abuse and Exploitation (CSAE), Child Sexual Abuse Material (CSAM), grooming, sextortion, sexualization of minors, trafficking, predatory interaction, or other content or conduct that endangers a child.').appTr),
              _smallBullet(('No scams, phishing, fake recharge, money laundering, illegal goods, or unauthorized financial activity.').appTr),
              _smallBullet(('No gambling, betting, lottery, cash games, cash-prize schemes, or unlawful reward systems.').appTr),
              _smallBullet(('No infringement of copyright, privacy, trademark, or other rights.').appTr),

              _sectionTitle(('3. Reporting, Blocking, and Moderation').appTr),
              _paragraph(
                ('Users can report objectionable content, live rooms, messages, posts, comments, or users through available in-app reporting tools and can block unwanted users. We may investigate reports and take action including warnings, content removal, live-room termination, mute, feature restrictions, account suspension, or permanent termination. When we obtain actual knowledge of confirmed CSAM or other child-endangering content, we take appropriate action and report it to the appropriate authority where required by law. Child-safety concerns may also be sent to $_childSafetyContact.').appTr,
              ),

              _sectionTitle(('4. Virtual Items and Google Play Purchases').appTr),
              _bullet(
                ('Virtual Items:').appTr,
                ('Coins, diamonds, gifts, badges, levels, frames, VIP features, and similar items are digital features used inside $_appName. A Coin Wallet or Coin Balance displays virtual items, not cash or a financial account.').appTr,
              ),
              _bullet(
                ('Google Play Billing:').appTr,
                ('When purchases are available in a Play Store-distributed version, in-app digital items are purchased through Google Play Billing where required.').appTr,
              ),
              _bullet(
                ('Verification:').appTr,
                ('A purchase may be credited only after server-side verification. Pending, canceled, duplicated, refunded, reversed, or unverifiable purchases may be rejected or corrected.').appTr,
              ),
              _bullet(
                ('No Off-Platform Recharge:').appTr,
                ('Manual recharge, reseller recharge, Stripe, QR codes, bank transfer, external payment links, and off-platform payment instructions are not offered inside the Google Play version for purchasing in-app digital items.').appTr,
              ),
              _bullet(
                ('No Direct Cash Value:').appTr,
                ('Purchased virtual items are not directly redeemable or withdrawable as cash and may not be used for gambling, betting, lottery, cash games, or illegal transactions.').appTr,
              ),
              _bullet(
                ('Refunds:').appTr,
                ('Refunds and cancellations are handled according to Google Play rules, applicable law, and our official support process. Refunded or charged-back virtual items may be removed or the balance corrected.').appTr,
              ),

              _sectionTitle(('5. Hosts, Creators, Agencies, and Earnings').appTr),
              _paragraph(
                ('Hosts, creators, agencies, managers, moderators, or similar roles must follow all platform rules and any separate written program terms. Any creator or host earnings program is separate from purchased virtual coins and may require identity, eligibility, fraud, and payout verification. Unauthorized selling, fake recharge, cash trading, or misleading earning claims are prohibited.').appTr,
              ),

              _sectionTitle(('6. Games, Lucky Features, and Promotions').appTr),
              _paragraph(
                ('Entertainment games, lucky features, rankings, promotions, and reward events must not be used for real-money gambling, betting, lottery, cash prizes, cash withdrawal, or real-world prize schemes. We may restrict or remove such features where necessary for law, safety, or platform policy.').appTr,
              ),

              _sectionTitle(('7. Privacy and Account Deletion').appTr),
              _paragraph(
                ('Our Privacy Policy explains how information is collected, used, shared, retained, and protected. Users can submit an authenticated deletion request from Settings → Account Deletion. The request may be canceled during the displayed cancellation period. Users without app access can request deletion at $_deleteAccountUrl, subject to identity verification.').appTr,
              ),
              _paragraph(
                ('After completion, account access, profile information, social connections, and virtual items may be permanently removed. Certain legal, financial, fraud-prevention, chargeback, dispute, and safety records may be retained as permitted or required.').appTr,
              ),

              _sectionTitle(('8. Intellectual Property').appTr),
              _paragraph(
                ('The app, software, brand, graphics, systems, and platform-provided content are owned by or licensed to $_operator. By uploading or broadcasting content, you grant us a limited license to host, display, process, moderate, and distribute that content as needed to operate and protect the service.').appTr,
              ),

              _sectionTitle(('9. Suspension and Termination').appTr),
              _paragraph(
                ('We may remove content, restrict features, suspend, or terminate an account for violations of these Terms, the Community Guidelines, applicable law, Google Play policy, or conduct that creates risk for users or the service.').appTr,
              ),

              _sectionTitle(('10. Service Availability and Changes').appTr),
              _paragraph(
                ('We may add, change, suspend, or discontinue features, virtual items, events, or services for legal, safety, technical, operational, or business reasons.').appTr,
              ),

              _sectionTitle(('11. Disclaimer and Liability').appTr),
              _paragraph(
                ('$_appName is provided on an "AS IS" and "AS AVAILABLE" basis. To the maximum extent permitted by law, we do not guarantee uninterrupted or error-free operation and are not liable for indirect, incidental, special, consequential, or punitive damages.').appTr,
              ),

              _sectionTitle(('12. Changes to These Terms').appTr),
              _paragraph(
                ('We may update these Terms. The updated version will be published in the app or on our website with a revised date. Continued use after an update constitutes acceptance where permitted by law.').appTr,
              ),

              _sectionTitle(('13. Contact Us').appTr),
              _contactRow('Email:', _supportEmail),
              _contactRow('Website:', _website),
              _contactRow('Account deletion:', _deleteAccountUrl),
              _contactRow('Child safety:', _childSafetyContact),
              _contactRow('Operator:', _operator),
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
        fontWeight: FontWeight.w400,
        height: 1.65,
      ),
    ),
  );

  static Widget _bullet(String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '• ',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        Expanded(
          child: RichText(
            textAlign: TextAlign.justify,
            text: TextSpan(
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 13.5,
                height: 1.6,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: '$title ',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _smallBullet(String text) => Padding(
    padding: const EdgeInsets.only(left: 14, bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '– ',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 14,
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
