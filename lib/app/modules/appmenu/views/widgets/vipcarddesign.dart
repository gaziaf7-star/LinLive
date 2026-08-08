import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
const Color kAppColor1 = Color(0xFFAC0422);
const Color kAppColor2 = Color(0xFFF81889);
const Color kAppbarColor = Color(0xFFF82897);
const Color kAppbarColor1 = Color(0xFFF33558);

Widget premiumVipValidityCard({
  required double kHeight,
  required double kWeight,
  String? title,
  String? validity,
  String imagePath =
  'assets/svip_exclusive_image/17775972733301774478312058vip3.webp',
  BoxFit imageFit = BoxFit.contain,
}) {
  final String displayTitle = (title ?? 'VIP').appTr;
  final String displayValidity = validity ?? '6 Days'.appTr;

  return Container(
    margin: EdgeInsets.symmetric(
      horizontal: kWeight * 0.03,
      vertical: kHeight * 0.002,
    ),
    height: kHeight * 0.12,
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          kAppColor1,
          kAppbarColor1.withOpacity(0.45),
          kAppColor1,
        ],
      ),
      border: Border.all(
        color: kAppColor2.withOpacity(0.75),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: kAppColor1.withOpacity(0.35),
          blurRadius: 26,
          spreadRadius: 1,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: kAppColor2.withOpacity(0.22),
          blurRadius: 18,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _VipCardLinePainter(),
            ),
          ),

          Positioned(
            right: -45,
            top: -20,
            child: Container(
              width: kWeight * 0.8,
              height: kHeight * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kAppColor2.withOpacity(0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: -35,
            bottom: -45,
            child: Container(
              width: kWeight * 0.35,
              height: kHeight * 0.16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kAppColor1.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * 0.045,
              vertical: kHeight * 0.01,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayTitle,
                            style: GoogleFonts.poppins(
                              fontSize: kHeight * 0.037,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: kAppColor2.withOpacity(0.9),
                                  blurRadius: 14,
                                ),
                                Shadow(
                                  color: kAppColor1.withOpacity(0.7),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: kWeight * 0.018),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: kHeight * 0.024,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: kAppColor2.withOpacity(0.9),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: kHeight * 0.01),

                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Remaining Validity: '.appTr,
                              style: GoogleFonts.poppins(
                                fontSize: kHeight * 0.016,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            TextSpan(
                              text: displayValidity,
                              style: GoogleFonts.poppins(
                                fontSize: kHeight * 0.017,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: kAppColor2.withOpacity(0.8),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: kWeight * 0.02),

                SizedBox(
                  height: kHeight * 0.095,
                  width: kHeight * 0.095,
                  child: _vipBadgeImage(
                    imagePath: imagePath,
                    kHeight: kHeight,
                    fit: imageFit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _vipBadgeImage({
  required String imagePath,
  required double kHeight,
  BoxFit fit = BoxFit.contain,
}) {
  final path = imagePath.trim();
  final lowerPath = path.toLowerCase();

  if (path.isEmpty) {
    return _vipImageFallback(kHeight);
  }

  final bool isNetworkImage =
      lowerPath.startsWith('http://') || lowerPath.startsWith('https://');

  final bool isSvga = lowerPath.endsWith('.svga');

  if (isSvga && isNetworkImage) {
    return SVGAEasyPlayer(
      resUrl: path,
      fit: fit,
    );
  }

  if (isSvga && !isNetworkImage) {
    return SVGAEasyPlayer(
      assetsName: path,
      fit: fit,
    );
  }

  if (isNetworkImage) {
    return CachedNetworkImage(
      imageUrl: path,
      fit: fit,

      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (c, u) => const SizedBox.shrink(),
      errorWidget: (c, u, e) => _vipImageFallback(kHeight),
    );
  }

  return Image.asset(
    path,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return _vipImageFallback(kHeight);
    },
  );
}

Widget _vipImageFallback(double kHeight) {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(0.16),
      border: Border.all(
        color: Colors.white.withOpacity(0.35),
        width: 1,
      ),
    ),
    child: Icon(
      Icons.workspace_premium_rounded,
      color: Colors.white,
      size: kHeight * 0.038,
    ),
  );
}

class _VipCardLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1;

    final paint2 = Paint()
      ..color = kAppColor2.withOpacity(0.10)
      ..strokeWidth = 1.2;

    for (double i = -size.height; i < size.width; i += 12) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint1,
      );
    }

    final path = Path();
    path.moveTo(0, size.height * 0.82);
    path.quadraticBezierTo(
      size.width * 0.32,
      size.height * 0.55,
      size.width * 0.62,
      size.height * 0.72,
    );
    path.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.84,
      size.width,
      size.height * 0.58,
    );
    canvas.drawPath(path, paint2);

    final topPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          kAppColor2.withOpacity(0.55),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1.4),
      topPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}