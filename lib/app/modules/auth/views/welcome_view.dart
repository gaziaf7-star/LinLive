import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/auth/views/community_guidelines_page.dart';
import 'package:meetlivepro/app/modules/auth/views/privacy_policy_page.dart';
import 'package:meetlivepro/app/modules/auth/views/user_agreement_page.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CustomButtons.dart';
import '../../../../widgets/setheight.dart';
import '../../../../widgets/small_text_widgets.dart';
import '../../../services/google_auth_service.dart';
import '../../registersteps/controllers/registersteps_controller.dart';
import '../../registersteps/views/set_nickname.dart';
import 'login_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  bool _agreed = false;

  void _showAgreementToast() {
    Fluttertoast.showToast(
      msg: ('Please agree to the User Agreement, Privacy Policy and Community Guidelines to continue.').appTr,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  Future<void> _continueWithGoogle(RegisterstepsController controller) async {
    if (!_agreed) {
      _showAgreementToast();
      return;
    }

    if (controller.isLoading.value) return;
    await GoogleAuthService.signInWithGoogle();
  }

  void _continueWithPhone() {
    if (!_agreed) {
      _showAgreementToast();
      return;
    }

    Get.to(
      const LoginView(),
      transition: Transition.leftToRight,
    );
  }

  void _createAccount() {
    if (!_agreed) {
      _showAgreementToast();
      return;
    }

    Get.to(
      const SetNickname(),
      transition: Transition.rightToLeft,
    );
  }

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RegisterstepsController registerstepsController =
    Get.put(RegisterstepsController());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(profileImage, fit: BoxFit.cover),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  children: [
                    SizedBox(height: kHeight * 0.16),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        appLogo,
                        width: kHeight * 0.12,
                        height: kHeight * 0.12,
                        fit: BoxFit.cover,
                      ),
                    ),


                    SizedBox(height: kHeight * 0.02),

                    Text(
                      ('Welcome to LinLive').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: kHeight * 0.032,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: kHeight * 0.008),

                    Text(
                      ('Choose your login method').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: kHeight * 0.016,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    SetHeight(heightSet: 0.035),

                    Obx(
                          () => CustomButtons(
                        text: registerstepsController.isLoading.value
                            ? 'Loading...'
                            : 'Continue with Google',

                        // দুই বাটনের ভেতরের একই ডার্ক কালার
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xff26004f),
                            Color(0xff120043),
                            Color(0xff08083c),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),

                        // দুই বাটনের একই Neon Border
                        borderGradient: const LinearGradient(
                          colors: [
                            Color(0xffff4fce),
                            Color(0xffb840ff),
                            Color(0xff6158ff),
                            Color(0xff3aaeff),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),

                        image: 'assets/audio_live/google.png',
                        isLoading: registerstepsController.isLoading.value,
                        showArrow: true,
                        borderWidth: 3,
                        height: 64,

                        onTap: () async {
                          await _continueWithGoogle(registerstepsController);
                        },
                      ),
                    ),

                    SetHeight(heightSet: 0.012),

                    CustomButtons(
                      text: 'Continue with Phone',

                      // Google button-এর মতো একই ভেতরের কালার
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xff26004f),
                          Color(0xff120043),
                          Color(0xff08083c),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),

                      // Google button-এর মতো একই Neon Border
                      borderGradient: const LinearGradient(
                        colors: [
                          Color(0xffff4fce),
                          Color(0xffb840ff),
                          Color(0xff6158ff),
                          Color(0xff3aaeff),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),

                      image:
                      'assets/audio_live/phone-call.png',
                      showArrow: true,
                      borderWidth: 3,
                      height: 64,
                      onTap: _continueWithPhone,
                    ),

                    SetHeight(heightSet: 0.02),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.white.withOpacity(0.45)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SmallTextStyle(
                            color: Colors.white,
                            text: ('or').appTr,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.white.withOpacity(0.45)),
                        ),
                      ],
                    ),


                    SetHeight(heightSet: 0.012),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _agreed = value ?? false;
                              });
                            },
                            activeColor: kPrimaryColor,
                            checkColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text.rich(
                                TextSpan(
                                  text: ('By continuing, I agree to the ').appTr,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white.withOpacity(0.88),
                                    fontWeight: FontWeight.w400,
                                    height: 1.55,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ('User Agreement').appTr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => _openPage(
                                          const UserAgreementPage(),
                                        ),
                                    ),
                                    const TextSpan(text: ', '),
                                    TextSpan(
                                      text: ('Privacy Policy').appTr,
                                      style: const TextStyle(
                                        color: Color(0xff7fd7ff),
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xff7fd7ff),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => _openPage(
                                          const PrivacyPolicyPage(),
                                        ),
                                    ),
                                    TextSpan(text: (' and ').appTr),
                                    TextSpan(
                                      text: ('Community Guidelines').appTr,
                                      style: const TextStyle(
                                        color: Color(0xffffd36a),
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xffffd36a),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => _openPage(
                                          const CommunityGuidelinesPage(),
                                        ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SetHeight(heightSet: 0.02),

                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _createAccount,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                          ),
                        ),
                        child: Text(
                          ('Create Account').appTr,
                          style: GoogleFonts.lato(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: kHeight * 0.16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}