import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';
import '../../appmenu/views/widgets/imageColor.dart';
import '../../bottomnav/views/bottomnav_view.dart' hide kAppColor1, kAppColor2, kAppbarColor;

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AgencySuccessView extends StatelessWidget {
  const AgencySuccessView({
    super.key,
    required this.agencyName,
    required this.creatorId,
  });

  final String agencyName;
  final String creatorId;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF5F7),
        body: Stack(
          children: [
            const Positioned.fill(child: _SuccessBackground()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: kWeight * 0.06,
                    vertical: kHeight * 0.035,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: kWeight * 0.055,
                          vertical: kHeight * 0.045,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: kAppColor2.withOpacity(0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kAppColor2.withOpacity(0.15),
                              blurRadius: 35,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: kHeight * 0.135,
                              width: kHeight * 0.135,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [kAppColor2, kAppColor1],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kAppColor1.withOpacity(0.28),
                                    blurRadius: 26,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: kHeight * 0.072,
                              ),
                            ),
                            SizedBox(height: kHeight * 0.028),
                            Text(
                              ('Application Submitted!').appTr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1C1C1E),
                                fontSize: kHeight * 0.026,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: kHeight * 0.01),
                            Text(
                              ('Your creator agency application was submitted successfully. Our team will review the information and update your account status.').appTr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: kHeight * 0.014,
                                fontWeight: FontWeight.w500,
                                height: 1.55,
                              ),
                            ),
                            SizedBox(height: kHeight * 0.026),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(kHeight * 0.018),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: kAppColor2.withOpacity(0.16),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _InfoRow(
                                    icon: Icons.apartment_rounded,
                                    label: ('Agency Name').appTr,
                                    value: agencyName,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: kHeight * 0.012,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: Colors.black.withOpacity(0.07),
                                    ),
                                  ),
                                  _InfoRow(
                                    icon: Icons.badge_rounded,
                                    label: ('Creator ID').appTr,
                                    value: creatorId,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: kHeight * 0.012,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: Colors.black.withOpacity(0.07),
                                    ),
                                  ),
                                   _InfoRow(
                                    icon: Icons.hourglass_top_rounded,
                                    label: ('Current Status').appTr,
                                    value: 'Under Review',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: kHeight * 0.03),
                            SizedBox(
                              width: double.infinity,
                              height: kHeight * 0.062,
                              child: ElevatedButton(
                                onPressed: () {
                                  Get.offAll(
                                        () => BottomnavView(),
                                    transition: Transition.rightToLeft,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [kAppColor2, kAppColor1],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          ('Go to Home').appTr,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: kHeight * 0.016,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: kWeight * 0.02),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: kHeight * 0.046,
          width: kHeight * 0.046,
          decoration: BoxDecoration(
            color: kAppColor2.withOpacity(0.11),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: kAppbarColor, size: kHeight * 0.023),
        ),
        SizedBox(width: kWeight * 0.035),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.black45,
                  fontSize: kHeight * 0.0115,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: kHeight * 0.002),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF252525),
                  fontSize: kHeight * 0.0145,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessBackground extends StatelessWidget {
  const _SuccessBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFFD8E0),
            Color(0xFFFFF4F7),
            Color(0xFFFFE8ED),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: _GlowCircle(size: 220, opacity: 0.13),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _GlowCircle(size: 260, opacity: 0.10),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAppColor1.withOpacity(opacity),
      ),
    );
  }
}
