import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/app/modules/verified/views/verify_page_3.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../controllers/verified_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
/// Play Store safe mode.
/// true  = risky earning/withdraw wording and risky flows hidden/safe.
/// false = full internal/original business flow can be used later.
const bool kPlayStoreSafeMode = true;

class VerifyPage2 extends StatelessWidget {
  const VerifyPage2({super.key});

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

  bool _isValidPhone(String number) {
    final clean = number.trim();
    if (clean.length < 8 || clean.length > 16) return false;
    return RegExp(r'^[0-9+]+$').hasMatch(clean);
  }

  @override
  Widget build(BuildContext context) {
    final VerifiedController controller = Get.put(VerifiedController());
    final dynamic agencydata = Get.arguments;

    final String agencyName = agencydata?['name']?.toString() ?? ('Agency').appTr;
    final dynamic agencyId = agencydata?['agency_id'];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kAppColor1,
                kAppColor2,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
        ),
        title: Text(
          ('Host Verify').appTr,
          style: GoogleFonts.lato(
            fontSize: kHeight * 0.022,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  Get.to(
                     VerifyPage3(),
                    transition: Transition.rightToLeft,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        agencyName,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.01),

              Divider(
                color: Colors.grey.withOpacity(0.5),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.01),

              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.01,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller.whatsappNumber,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: kHeight * 0.01,
                      vertical: 16,
                    ),
                    hintText: ('Enter WhatsApp number').appTr,
                    prefixIcon: const Icon(
                      Icons.phone_rounded,
                      color: Colors.deepPurple,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.01),

              Castontext(
                fontSize: kHeight * 0.016,
                text: ('Host type').appTr,
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.012),

              SizedBox(
                height: MediaQuery.of(context).size.height * 0.13,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _chatBox(context, 'Chat', controller),
                          _chatBox(context, 'Stream', controller),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _chatBox(context, 'Sing', controller),
                          _chatBox(context, 'Dance', controller),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _chatBox(context, ('Beauty').appTr, controller),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.02),

              Castontext(
                fontSize: kHeight * 0.017,
                fontWeight: FontWeight.w500,
                text: ('Description').appTr,
              ),

              SizedBox(height: MediaQuery.of(context).size.height * 0.012),

              _safeDescriptionText(
                '* Please provide real contact information so our team or selected agency can contact you if needed.',
              ),
              _safeDescriptionText(
                '* After submitting your host verification request, please wait for review. You cannot submit another request while your current request is pending.',
              ),
              _safeDescriptionText(
                '* Host verification helps us maintain a safe and trusted live streaming community.',
              ),
              _safeDescriptionText(
                '* Verified hosts must follow our User Agreement, Privacy Policy and Community Guidelines.',
              ),
              _safeDescriptionText(
                '* Any abusive, illegal, adult, hateful, fraudulent or unsafe activity may result in rejection, suspension or account termination.',
              ),

              if (!kPlayStoreSafeMode) ...[
                _safeDescriptionText(
                  '* Internal note: agency settlement and reward-related matters are handled according to platform rules and separate agreements.',
                ),
              ],

              SizedBox(height: MediaQuery.of(context).size.height * 0.05),

              Obx(
                    () => Center(
                  child: SizedBox(
                    width: kWeight * 0.7,
                    height: kHeight * 0.055,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () {
                        final String number =
                        controller.whatsappNumber.text.trim();
                        final String hostType =
                        controller.selectedHostType.value.trim();

                        if (agencyId == null ||
                            agencyId.toString().isEmpty) {
                          _showToast(('Please select an agency first.').appTr);
                          return;
                        }

                        if (!_isValidPhone(number)) {
                          _showToast(
                            ('Please enter a valid WhatsApp number.').appTr,
                          );
                          return;
                        }

                        if (hostType.isEmpty) {
                          _showToast(('Please select a host type.').appTr);
                          return;
                        }

                        controller.hostVerifyPost(
                          agencyId: agencyId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kHeight * 0.1),
                        ),
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: controller.isLoading.value
                                ? [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.3),
                            ]
                                : [
                              const Color(0xff8A4CF7),
                              const Color(0xffB460F0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(kHeight * 0.1),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: controller.isLoading.value
                              ? SizedBox(
                            height: kHeight * 0.022,
                            width: kHeight * 0.022,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            ('Submit now').appTr,
                            style: GoogleFonts.lato(
                              color: Colors.white,
                              fontSize: kHeight * 0.017,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: kHeight * 0.03),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _safeDescriptionText(String text) {
  return Padding(
    padding: EdgeInsets.only(bottom: kHeight * 0.01),
    child: Castontext(
      fontSize: kHeight * 0.0105,
      fontWeight: FontWeight.w500,
      textColor: Colors.black,
      text: text,
    ),
  );
}

Widget _chatBox(
    BuildContext context,
    String text,
    VerifiedController controller,
    ) {
  return Obx(() {
    final bool isSelected = controller.selectedHostType.value == text;

    return InkWell(
      onTap: () => controller.selectHostType(text),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.01,
          horizontal: MediaQuery.of(context).size.width * 0.08,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.grey.withOpacity(.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Castontext(
          fontSize: kHeight * 0.015,
          text: text,
          textColor: isSelected ? Colors.white : Colors.black,
        ),
      ),
    );
  });
}