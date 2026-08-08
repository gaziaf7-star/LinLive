import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../../apis/api_endpoints.dart';
import '../../../../../constants/color_constants.dart';
import '../../../../../constants/image_const/image_conost.dart';
import '../../../../../constants/layout_constant.dart';
import '../varify_page_5.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class HostCertificationPage extends StatelessWidget {
  final dynamic verificationData;
  const HostCertificationPage({Key? key, required this.verificationData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = verificationData;
    final status = data['status']?.toString().toLowerCase() ?? 'pending';

    print('host data $data');

    // Accepted হলে সরাসরি VarifyPage5 এ যান
    if (status == 'accepted' || status == 'approved') {
      return VarifyPage5(verificationData: verificationData);
    }

    // Accepted না হলে review page দেখান
    final statusInfo = _getStatusInfo(status);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          ('Host certification').appTr,
          style: GoogleFonts.roboto(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 60),
          // Dynamic Icon with circular background
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: statusInfo['color'],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  '${statusInfo['icon']}',
                  height: kHeight * 0.09,
                  width: kHeight * 0.09,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          // Dynamic Title
          Text(
            statusInfo['title'],
            style: GoogleFonts.roboto(
              fontSize: 24,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Dynamic Descriptions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: (statusInfo['descriptions'] as List<String>)
                  .map((desc) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 40),
          // Contact Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Profile Image
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${kDomainUrl}/${data['agency']['profile_image']}',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.person, size: 30),
                          );
                        },
                      )),
                  const SizedBox(width: 12),
                  // Name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['agency']['name'] ?? ('Tom').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ('ID:${data['agency']['agency_id'] ?? '791'}').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  // Contact Button
                  OutlinedButton(
                    onPressed: () async {
                      final phone = data['agency']['phone'];
                      if (phone != null && phone.isNotEmpty) {
                        // WhatsApp URL তৈরি করুন
                        String whatsappUrl = "https://wa.me/$phone";

                        // যদি phone number + দিয়ে শুরু না হয় তাহলে add করুন
                        if (!phone.startsWith('+')) {
                          whatsappUrl =
                              "https://wa.me/+88$phone"; // Bangladesh code +88
                        }

                        final Uri url = Uri.parse(whatsappUrl);

                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        } else {
                          // Error message দেখান
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(('Could not open WhatsApp').appTr),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(('Phone number not available').appTr),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      ('Contact\npresident').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get status info based on verification status
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'canceled':
      case 'cancelled':
      case 'rejected':
        return {
          'icon': appLogo,
          'color': Colors.red,
          'title': 'Canceled',
          'descriptions': [
            '❌ Your request has been canceled.',
            'Please check your details and try again.',
          ],
        };
      default: // pending, reviewing
        return {
          'icon': appLogo,
          'color': Colors.orange.shade300,
          'title': 'Reviewing',
          'descriptions': [
            '⏳ Your application is currently under review.',
            'This process usually takes 1-3 work days.',
            'Please be patient, you\'ll be notified soon.',
          ],
        };
    }
  }
}
