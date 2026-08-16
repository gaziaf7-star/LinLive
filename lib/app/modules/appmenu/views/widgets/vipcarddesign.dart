import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/modules/accountInfornation/views/CoinTopup.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

const Color kAppColor1 = Color(0xFFAC0422);
const Color kAppColor2 = Color(0xFFF81889);
const Color kAppbarColor = Color(0xFFF82897);
const Color kAppbarColor1 = Color(0xFFF33558);

const String _kSvipAsset = 'assets/audio_live/svip.png';
const String _kVipAsset = 'assets/audio_live/vip.png';
const String _kRechargeAsset = 'assets/audio_live/ress.png';

Widget premiumVipValidityCard({
  required double kHeight,
  required double kWeight,
  String? title,
  String? validity,
  String imagePath =
  'assets/svip_exclusive_image/17775972733301774478312058vip3.webp',
  BoxFit imageFit = BoxFit.contain,
  VoidCallback? onTapSvip,
  VoidCallback? onTapVip,
}) {
  // Kept backward-compatible with the previous widget signature.
  // The section itself follows the reference UI: one wide SVIP card on top,
  // then two equal VIP / Recharge cards below it.
  final double topCardHeight = (kHeight * .105).clamp(82.0, 98.0).toDouble();
  final double bottomCardHeight =
  (kHeight * .112).clamp(88.0, 104.0).toDouble();
  final double verticalGap = (kHeight * .010).clamp(8.0, 11.0).toDouble();

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: kWeight * .032),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: topCardHeight,
          width: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapSvip,
            child: _buildTopSvipCard(
              kHeight: kHeight,
              kWeight: kWeight,
            ),
          ),
        ),
        SizedBox(height: kHeight*0.017),
        SizedBox(
          height: bottomCardHeight,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Get.to(
                      CoinTopUp(),
                      transition: Transition.rightToLeft,
                    );
                  },
                  child: _buildSmallCard(
                    kHeight: kHeight,
                    kWeight: kWeight,
                    title: 'Recharge'.appTr,
                    subtitle: 'Top up'.appTr,
                    assetPath: _kRechargeAsset,
                    gradient: const [
                      Color(0xFFFFF0A8),
                      Color(0xFFFFE8C8),
                      Color(0xFFFFD8E8),
                    ],
                    imageScale: 1.18,
                  ),
                ),
              ),
              SizedBox(width: (kWeight * .018).clamp(10.0, 14.0).toDouble()),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTapVip,
                  child: _buildSmallCard(
                    kHeight: kHeight,
                    kWeight: kWeight,
                    title: 'VIP'.appTr,
                    subtitle: 'check now'.appTr,
                    assetPath: _kVipAsset,
                    gradient: const [
                      Color(0xFFFFF4BC),
                      Color(0xFFFFF1CF),
                      Color(0xFFFFDCE4),
                    ],
                    imageScale: 1.13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildTopSvipCard({
  required double kHeight,
  required double kWeight,
}) {
  final double radius = (kHeight * .0165).clamp(13.0, 17.0).toDouble();
  final double logoWidth = (kWeight * .205).clamp(94.0, 122.0).toDouble();
  final double titleSize = (kHeight * .026).clamp(20.0, 25.0).toDouble();
  final double subtitleSize = (kHeight * .014).clamp(11.0, 13.5).toDouble();

  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFFFF6C9),
          Color(0xFFFFF0B6),
          Color(0xFFFFE7A8),
        ],
        stops: [0.0, .50, 1.0],
      ),
      border: Border.all(
        color: const Color(0xFFF4D98E).withOpacity(.72),
        width: .8,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFB58B28).withOpacity(.10),
          blurRadius: 7,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Very soft sparkle treatment like the reference card.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: .34,
                child: CustomPaint(
                  painter: const _VipSparklePainter(),
                ),
              ),
            ),
          ),
          Positioned(
            left: -(kWeight * .004),
            top: -(kHeight * .016),
            bottom: -(kHeight * .016),
            width: logoWidth,
            child: Image.asset(
              _kSvipAsset,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned.fill(
            left: logoWidth - (kWeight * .004),
            child: Padding(
              padding: EdgeInsets.only(
                left: (kWeight * .013).clamp(6.0, 10.0).toDouble(),
                right: (kWeight * .024).clamp(10.0, 18.0).toDouble(),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SVIP Center'.appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFF6A4313),
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: (kHeight * .008).clamp(5.0, 7.0).toDouble()),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Get SVIP and enjoy various privileges'.appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8B672B),
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                      ),
                      SizedBox(width: (kWeight * .006).clamp(2.0, 5.0).toDouble()),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFF8E6425),
                        size: (kHeight * .022).clamp(17.0, 20.0).toDouble(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSmallCard({
  required double kHeight,
  required double kWeight,
  required String title,
  required String subtitle,
  required String assetPath,
  required List<Color> gradient,
  double imageScale = 1.0,
}) {
  final double radius = (kHeight * .015).clamp(12.0, 16.0).toDouble();
  final double titleSize = (kHeight * .023).clamp(18.0, 22.0).toDouble();
  final double subtitleSize = (kHeight * .014).clamp(11.0, 13.0).toDouble();
  final double imageWidth = (kWeight * .152).clamp(66.0, 88.0).toDouble();
  final double imageTop = (kHeight * .006).clamp(3.0, 6.0).toDouble();
  final double imageRight = (kWeight * .010).clamp(4.0, 8.0).toDouble();

  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: gradient,
            stops: const [0.0, .54, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFF0DDA8).withOpacity(.55),
            width: .7,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  left: (kWeight * .026).clamp(12.0, 18.0).toDouble(),
                  right: imageWidth * .92,
                  top: (kHeight * .006).clamp(3.0, 6.0).toDouble(),
                  bottom: (kHeight * .006).clamp(3.0, 6.0).toDouble(),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        color: const Color(0xFF704817),
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: (kHeight * .010).clamp(6.0, 8.0).toDouble()),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF976E32),
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                            ),
                          ),
                        ),
                        SizedBox(width: (kWeight * .009).clamp(4.0, 7.0).toDouble()),
                        Container(
                          width: (kHeight * .022).clamp(17.0, 20.0).toDouble(),
                          height: (kHeight * .022).clamp(17.0, 20.0).toDouble(),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF815824),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: (kHeight * .016).clamp(12.0, 15.0).toDouble(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: imageRight,
              top: imageTop,
              width: imageWidth,
              child: Transform.scale(
                scale: imageScale * .92,
                alignment: Alignment.topRight,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(
                    (kWeight * .088).clamp(34.0, 48.0).toDouble(),
                    (kHeight * .040).clamp(22.0, 30.0).toDouble(),
                  ),
                  painter: const _TopRightCurvedCornerPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TopRightCurvedCornerPainter extends CustomPainter {
  const _TopRightCurvedCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path fillPath = Path()
      ..moveTo(size.width * .24, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .74)
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .16,
        size.width * .24,
        0,
      )
      ..close();

    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x30FFFFFF),
          Color(0x12FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);

    final Paint stroke = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x44FFFFFF),
          Color(0x10FFFFFF),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    canvas.drawPath(fillPath, fill);

    final Path curve = Path()
      ..moveTo(size.width * .24, 0)
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .16,
        size.width,
        size.height * .74,
      );
    canvas.drawPath(curve, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VipSparklePainter extends CustomPainter {
  const _VipSparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()..color = Colors.white.withOpacity(.72);
    final Paint starPaint = Paint()
      ..color = Colors.white.withOpacity(.88)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final List<Offset> dots = <Offset>[
      Offset(size.width * .74, size.height * .25),
      Offset(size.width * .82, size.height * .63),
      Offset(size.width * .91, size.height * .34),
      Offset(size.width * .95, size.height * .74),
      Offset(size.width * .69, size.height * .78),
      Offset(size.width * .55, size.height * .18),
    ];

    for (final Offset p in dots) {
      canvas.drawCircle(p, 1.2, dotPaint);
    }

    final List<Offset> stars = <Offset>[
      Offset(size.width * .80, size.height * .20),
      Offset(size.width * .93, size.height * .58),
      Offset(size.width * .64, size.height * .70),
    ];

    for (final Offset p in stars) {
      const double r = 4.0;
      canvas.drawLine(Offset(p.dx - r, p.dy), Offset(p.dx + r, p.dy), starPaint);
      canvas.drawLine(Offset(p.dx, p.dy - r), Offset(p.dx, p.dy + r), starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}