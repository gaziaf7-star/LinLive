import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../auth/views/user_agreement_page.dart';
import '../../registersteps/controllers/registersteps_controller.dart';

class GoogleRegistrationCompleteView extends StatelessWidget {
  const GoogleRegistrationCompleteView({super.key});

  @override
  Widget build(BuildContext context) {
    final RegisterstepsController controller =
    Get.find<RegisterstepsController>();

    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.width < 360 || size.height < 680;
    final double horizontal = compact ? 22 : 28;
    final double contentWidth = size.width > 560 ? 500 : size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xffFCFCFD),
          body: SafeArea(
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                        vertical: compact ? 18 : 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              (compact ? 36 : 48),
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const _StepProgress(
                                currentStep: 3,
                                totalSteps: 3,
                              ),

                              const Spacer(),

                              Container(
                                width: compact ? 64 : 70,
                                height: compact ? 64 : 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [kAppColor, kPostIconColor],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                      kPostIconColor.withOpacity(.17),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: compact ? 36 : 40,
                                ),
                              ),

                              SizedBox(height: compact ? 24 : 28),

                              Text(
                                'Registration completed',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: compact ? 19 : 21,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xff25262A),
                                  letterSpacing: -0.25,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Your LIN LIVE profile is ready.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: compact ? 11.5 : 12.3,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xff8A8D96),
                                ),
                              ),

                              SizedBox(height: compact ? 20 : 24),

                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 15 : 18,
                                  vertical: compact ? 14 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xffEFEFF2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(.035),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'By entering LIN LIVE, you confirm that you have read and agree to our terms.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: compact ? 10.8 : 11.5,
                                        height: 1.55,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xff676A72),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      onTap: () {
                                        Get.to(
                                              () => const UserAgreementPage(),
                                          transition:
                                          Transition.rightToLeft,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          'User Agreement',
                                          style: GoogleFonts.poppins(
                                            fontSize:
                                            compact ? 11.3 : 12,
                                            fontWeight: FontWeight.w700,
                                            color: kPostIconColor,
                                            decoration:
                                            TextDecoration.underline,
                                            decorationColor:
                                            kPostIconColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: compact ? 26 : 32),

                              Obx(() {
                                final bool loading =
                                    controller.googleEnteringApp.value;

                                return SizedBox(
                                  width: compact ? 200 : 225,
                                  height: compact ? 45 : 48,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: loading
                                          ? const LinearGradient(
                                        colors: [
                                          Color(0xffC9C7C4),
                                          Color(0xffD8D5D1),
                                        ],
                                      )
                                          : const LinearGradient(
                                        colors: [
                                          kAppColor,
                                          kPostIconColor,
                                        ],
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(24),
                                      boxShadow: loading
                                          ? const []
                                          : [
                                        BoxShadow(
                                          color: kPostIconColor
                                              .withOpacity(.16),
                                          blurRadius: 14,
                                          offset:
                                          const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius:
                                        BorderRadius.circular(24),
                                        onTap: loading
                                            ? null
                                            : controller
                                            .enterAppAfterGoogleOnboarding,
                                        child: Center(
                                          child: loading
                                              ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                              : Text(
                                            'Enter LIN LIVE',
                                            style:
                                            GoogleFonts.poppins(
                                              fontSize: compact
                                                  ? 13.8
                                                  : 14.5,
                                              fontWeight:
                                              FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              const Spacer(flex: 2),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalSteps, (index) {
          final bool active = index < currentStep;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 24 : 8,
            height: 5,
            margin: const EdgeInsets.only(left: 5),
            decoration: BoxDecoration(
              color: active ? kAppColor : const Color(0xffE1E2E6),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }),
      ),
    );
  }
}
