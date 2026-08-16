import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String _appName = 'LinLive';
  static const String _operator = 'Lin Live Team';
  static const String _supportEmail = 'help24imran@gmail.com';
  static const String _website = 'https://linlive.fr';
  static const String _childSafetyContact = 'help24imran@gmail.com';

  // IMPORTANT: This exact URL must be live, publicly accessible, and allow
  // users to submit an account-deletion request without reinstalling the app.
  // Create the page on your website before submitting the Play Store build.
  static const String _accountDeletionUrl =
      'https://linlive.fr/delete-account';

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
          'Privacy Policy'.appTr,
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
            children: [
              _centerTitle('PRIVACY POLICY – $_appName'.appTr),
              const SizedBox(height: 8),
              _centerSubTitle('Last Updated: August 16, 2026'.appTr),
              const SizedBox(height: 20),

              _paragraph(
                '$_operator ("we", "us" or "our") respects your privacy. This Privacy Policy explains what information we access, collect, use, share, protect and retain when you use the $_appName mobile application, website and related services.'.appTr,
              ),
              _paragraph(
                'This policy applies to account registration, profiles, live audio and video rooms, background live audio, messaging, user-generated content, virtual coins, gifts, VIP features, Google Play purchases, safety tools, customer support and other $_appName features.'.appTr,
              ),

              _importantNotice(
                title: 'Important Google Play Purchase Notice'.appTr,
                body:
                'Coins and other purchased digital items are virtual products for use only inside $_appName. They are not money, a bank deposit, cryptocurrency, stored cash, or a cash wallet. Purchased virtual items cannot be redeemed for cash, withdrawn to a bank or mobile wallet, or transferred outside $_appName.'.appTr,
                icon: Icons.verified_user_rounded,
              ),

              _sectionTitle('1. Information We Collect'.appTr),
              _bullet(
                'Account Information:'.appTr,
                'Name, username, phone number, email address, profile photo, gender, date of birth or age information where provided, user ID, login method, country, language and account status.'.appTr,
              ),
              _bullet(
                'Profile and Community Data:'.appTr,
                'Profile details, live room information, live titles, comments, messages, followers, following, blocked users, reports, levels, badges, gifts, virtual items and other community activity.'.appTr,
              ),
              _bullet(
                'Live Audio and Video:'.appTr,
                'When you host, speak, join or participate in live audio, live video, audio rooms, calls or similar features, the app accesses microphone and camera data as needed to provide the feature.'.appTr,
              ),
              _bullet(
                'Background Live Audio:'.appTr,
                'If you keep an active live room running while $_appName is in the background, microphone access and live audio transmission may continue until you mute yourself, leave the room, end the live session or stop the service. Android displays a persistent service notification while this feature is active.'.appTr,
              ),
              _bullet(
                'Photos, Media and Files:'.appTr,
                'When you choose to upload or update profile photos, posts, room images or related media, the app may access the selected photos, videos or files with your permission.'.appTr,
              ),
              _bullet(
                'Device and Technical Data:'.appTr,
                'Device model, operating system, app version, IP address, app instance or device identifiers where permitted, language, network information, crash logs, diagnostics, security signals and performance information.'.appTr,
              ),
              _bullet(
                'Purchase and Transaction Data:'.appTr,
                'Product ID, purchase token, order ID, transaction time, purchase status, acknowledgement or consumption status, verification result, refund or chargeback status, coin balance changes and related support records. Google Play processes the payment method. We do not receive or store your full card or bank account number.'.appTr,
              ),
              _bullet(
                'General Location:'.appTr,
                'Approximate location such as country, region or city may be inferred from IP address or selected by the user for language, safety, fraud prevention, ranking, content relevance and account protection.'.appTr,
              ),
              _bullet(
                'Safety and Moderation Data:'.appTr,
                'Reports, block records, moderation decisions, policy violations, suspicious activity signals, room actions and support communications may be processed to protect users and enforce our rules.'.appTr,
              ),

              _sectionTitle('2. How We Use Information'.appTr),
              _smallBullet('To create, verify, operate and secure user accounts.'.appTr),
              _smallBullet('To provide live audio, live video, calls, chat, messaging, profiles, gifts, virtual items and other app features.'.appTr),
              _smallBullet('To process, verify, acknowledge and fulfil Google Play purchases and prevent duplicate coin crediting.'.appTr),
              _smallBullet('To maintain virtual coin balances and transaction history and handle refunds, chargebacks and purchase support.'.appTr),
              _smallBullet('To provide customer support, account help, privacy responses and safety assistance.'.appTr),
              _smallBullet('To detect, prevent and respond to spam, fraud, abuse, scams, fake recharge offers, account theft, policy violations and illegal activity.'.appTr),
              _smallBullet('To review reports, moderate content, restrict abusive accounts and protect the community.'.appTr),
              _smallBullet('To send service notifications, security alerts, live room updates, purchase confirmations and account messages.'.appTr),
              _smallBullet('To improve app performance, stability, security, user experience and feature quality.'.appTr),

              _sectionTitle(
                '3. Camera, Microphone, Background Audio, Notifications and Media Permissions'.appTr,
              ),
              _importantNotice(
                title: 'Background Microphone Disclosure'.appTr,
                body:
                'When you deliberately keep an active live audio room running in the background, $_appName continues to access and transmit microphone audio so other room participants can hear you. You remain in control: mute, leave the room or end the live session to stop transmission.'.appTr,
                icon: Icons.mic_rounded,
              ),
              _paragraph(
                'Camera and microphone permissions are used only for live video, live audio, calls, room hosting, speaking and related communication features. Media permissions are used when you choose to upload or select media. Notification permission is used for account, message, live room, purchase, call, safety and service updates. You can manage permissions from device settings, but some features may stop working if permissions are disabled.'.appTr,
              ),
              _paragraph(
                'Where required, $_appName shows an in-app disclosure before requesting sensitive permissions or starting background microphone access. Permission or consent is not treated as granted merely because you leave or dismiss a screen.'.appTr,
              ),

              _sectionTitle('4. User-Generated Content and Public Visibility'.appTr),
              _paragraph(
                '$_appName includes public and semi-public user-generated content features. Content you stream, post, comment, upload or share may be visible to other users depending on the feature and privacy setting you use.'.appTr,
              ),
              _paragraph(
                'Before creating or uploading content, users must follow our Terms of Service and Community Guidelines. Objectionable, abusive, sexually explicit, exploitative, fraudulent, hateful, threatening or illegal content is prohibited.'.appTr,
              ),
              _paragraph(
                'Public live rooms, comments, profiles, messages reported by users and other community content may be reviewed by automated tools or authorised moderators for safety, abuse prevention and policy enforcement.'.appTr,
              ),

              _sectionTitle('5. Reporting, Blocking and Moderation'.appTr),
              _paragraph(
                'Users can report objectionable content, live rooms, comments, messages or accounts and can block unwanted users. We may remove content, mute or remove users from rooms, restrict features, stop live sessions, suspend accounts or permanently ban accounts when reasonably necessary to enforce our rules or applicable law.'.appTr,
              ),
              _paragraph(
                'Reports should be reviewed within a reasonable period based on seriousness. Serious safety reports may be retained and may be disclosed to competent authorities where legally required or necessary to protect users or the public.'.appTr,
              ),

              _sectionTitle('6. Google Play Billing, Virtual Coins and Digital Items'.appTr),
              _importantNotice(
                title: 'Virtual Coin Rules'.appTr,
                body:
                'The balance shown in the app is a virtual coin balance, not a cash balance. Purchased coins are usable only for eligible digital features inside $_appName. They have no guaranteed real-world value, do not earn interest and cannot be exchanged outside the service.'.appTr,
                icon: Icons.monetization_on_rounded,
              ),
              _paragraph(
                'In the Google Play version of $_appName, purchases of coins, VIP access, digital gifts, frames, badges and other digital items use Google Play Billing where required. The Play Store version must not direct users to manual recharge, reseller recharge, bank transfer, mobile-wallet payment, an external checkout page or another payment method for the same digital items.'.appTr,
              ),
              _paragraph(
                'Google Play may collect and process payment information under Google’s own terms and privacy practices. $_appName receives limited purchase information needed to verify and fulfil the transaction, prevent fraud and provide support.'.appTr,
              ),
              _paragraph(
                'Purchase fulfilment may be delayed while a transaction is pending or being verified. Duplicate, cancelled, refunded, charged-back, fraudulent or invalid purchases may not be credited, or previously credited virtual items may be reversed where permitted by law and platform rules.'.appTr,
              ),
              _paragraph(
                'Refund requests for Google Play purchases are handled according to Google Play policies, applicable law and the status of the digital item. Nothing in this policy limits any mandatory consumer rights.'.appTr,
              ),
              _paragraph(
                'Entertainment games, lucky features, rewards and events must not be used for real-money gambling, betting, lottery, cash prizes, cash withdrawal, real-world prize redemption or illegal transactions. Randomised virtual-item features, if offered, should clearly disclose applicable odds before purchase.'.appTr,
              ),

              _sectionTitle('7. Data Sharing'.appTr),
              _paragraph(
                'We do not sell personal information. We may disclose limited information only in the following situations:'.appTr,
              ),
              _bullet(
                'Service Providers:'.appTr,
                'To trusted providers that support cloud hosting, storage, live streaming, content delivery, analytics, crash reporting, security, customer support, notifications and payment verification.'.appTr,
              ),
              _bullet(
                'Google Play and Platform Providers:'.appTr,
                'To Google Play or related platform services when necessary to process, verify, acknowledge, consume, refund or investigate purchases and prevent fraud.'.appTr,
              ),
              _bullet(
                'Safety and Legal Reasons:'.appTr,
                'When required by law or reasonably necessary to protect users, the public, our rights or services, or to prevent fraud, abuse, security incidents or illegal activity.'.appTr,
              ),
              _bullet(
                'Business Transfer:'.appTr,
                'If the service is involved in a merger, acquisition, reorganisation or sale of assets, information may be transferred subject to appropriate safeguards.'.appTr,
              ),

              _sectionTitle('8. Third-Party Services'.appTr),
              _paragraph(
                '$_appName may use third-party services for live audio and video, login, analytics, crash reporting, notifications, cloud hosting, content delivery, customer support and Google Play Billing. These providers may process limited data according to their own privacy policies and our instructions where applicable.'.appTr,
              ),
              _paragraph(
                'Our Google Play Data Safety declaration is intended to cover data collected or shared by both $_appName and third-party SDKs included in the distributed app. We periodically review SDK data practices and update our disclosures when app behaviour changes.'.appTr,
              ),

              _sectionTitle('9. Data Security'.appTr),
              _paragraph(
                'We use reasonable technical and organisational safeguards, including access controls, secure transport where supported, server-side purchase verification, logging, anti-fraud controls and restricted administrative access. No internet, mobile or live-streaming service can be guaranteed completely secure.'.appTr,
              ),

              _sectionTitle('10. Data Retention'.appTr),
              _paragraph(
                'We retain information only as long as reasonably necessary to provide the service, fulfil purchases, comply with legal obligations, resolve disputes, prevent fraud and abuse, protect users, maintain security and enforce our policies.'.appTr,
              ),
              _bullet(
                'Purchase Records:'.appTr,
                'Purchase tokens, order records, verification results, refund and chargeback records may be retained for accounting, support, fraud prevention and legal compliance, even after an account deletion request where retention is legally permitted or required.'.appTr,
              ),
              _bullet(
                'Safety Records:'.appTr,
                'Reports, moderation actions and abuse-prevention records may be retained for a reasonable period to protect users and prevent repeated violations.'.appTr,
              ),
              _bullet(
                'Deleted Content and Backups:'.appTr,
                'Deleted data may remain temporarily in secure backups or logs until the normal backup cycle completes, unless a longer period is required for lawful security, fraud-prevention or compliance reasons.'.appTr,
              ),

              _sectionTitle('11. Account and Data Deletion'.appTr),
              _importantNotice(
                title: 'Account Deletion'.appTr,
                body:
                'Users can initiate account deletion from the in-app account settings and through the external deletion page: $_accountDeletionUrl. The external page must remain functional and must not require the user to reinstall the app.'.appTr,
                icon: Icons.delete_forever_rounded,
              ),
              _paragraph(
                'When a valid account deletion request is completed, we delete or anonymise account data associated with that account, except information that we must or may retain for security, fraud prevention, dispute resolution, chargebacks, financial records, legal compliance or public-safety reasons.'.appTr,
              ),
              _paragraph(
                'Temporary account deactivation, suspension or freezing is not treated as account deletion. Users may contact $_supportEmail if they cannot access the in-app or web deletion process.'.appTr,
              ),

              _sectionTitle('12. Your Choices and Controls'.appTr),
              _smallBullet('Update eligible profile information from account or profile settings.'.appTr),
              _smallBullet('Mute your microphone, leave a room or stop a live session to end live audio transmission.'.appTr),
              _smallBullet('Block users and report objectionable content using in-app safety tools.'.appTr),
              _smallBullet('Manage camera, microphone, notification and media permissions from device settings.'.appTr),
              _smallBullet('Request account deletion or other privacy assistance using the in-app option, deletion webpage or support email.'.appTr),

              _sectionTitle('13. Child Safety Standards'.appTr),
              _paragraph(
                '$_appName has zero tolerance for Child Sexual Abuse and Exploitation (CSAE), Child Sexual Abuse Material (CSAM), grooming, sextortion, sexualization of minors, trafficking, predatory interaction, and any other content or conduct that endangers a child.'.appTr,
              ),
              _paragraph(
                'Users can submit child-safety reports through available in-app reporting tools or contact $_childSafetyContact. When we obtain actual knowledge of confirmed CSAM or related child-endangering content, we remove or restrict the material and accounts and report confirmed material to the appropriate authority where required by law.'.appTr,
              ),

              _sectionTitle('14. Children’s Privacy and Age Requirement'.appTr),
              _paragraph(
                '$_appName is intended only for users aged 18 and above. Users must provide truthful age information where age screening is provided. We do not knowingly allow children to create accounts or use age-restricted live and social features. If we learn that a minor created an account, we may restrict or delete the account and associated data, subject to lawful retention requirements.'.appTr,
              ),

              _sectionTitle('15. International Processing'.appTr),
              _paragraph(
                'Information may be processed on servers or by service providers located outside your country. Where required, we use appropriate safeguards and process data according to this Privacy Policy and applicable law.'.appTr,
              ),

              _sectionTitle('16. Policy Changes'.appTr),
              _paragraph(
                'We may update this Privacy Policy when our app, SDKs, legal obligations or data practices change. Updates will be posted in the app or on our website with a revised “Last Updated” date. Where required, we will provide additional notice or obtain consent.'.appTr,
              ),

              _sectionTitle('17. Contact Us'.appTr),
              _paragraph(
                'For privacy questions, account deletion, purchase support, data requests, safety reports or other support, contact us:'.appTr,
              ),
              _contactRow('Email:', _supportEmail),
              _contactRow('Website:', _website),
              _contactRow('Account deletion:', _accountDeletionUrl),
              _contactRow('Child safety:', _childSafetyContact),
              _contactRow('Operator:', _operator),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _importantNotice({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffff8e8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffffd98a)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xffffe7ad),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xff8a5700),
              size: 20,
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
                    color: const Color(0xff5d3b00),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff664b1d),
                    fontSize: 12.6,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      children: [
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
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
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
      children: [
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
              fontWeight: FontWeight.w400,
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
        children: [
          TextSpan(
            text: '$title ',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
