import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassTriangleWidget extends StatelessWidget {
  final double width;
  final double height;
  final List<Color> gradientColors;
  final Color borderColor;
  final double borderWidth;
  final String text;

  const GlassTriangleWidget({
    super.key,
    required this.width,
    required this.height,
    required this.gradientColors,
    required this.borderColor,
    this.borderWidth = 2,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TriangleClipper(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: CustomPaint(
          size: Size(width, height),
          painter: TrianglePainter(
            gradientColors: gradientColors,
            borderColor: borderColor,
            borderWidth: borderWidth,
            text: text,
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final List<Color> gradientColors;
  final Color borderColor;
  final double borderWidth;
  final String text;

  TrianglePainter({
    required this.gradientColors,
    required this.borderColor,
    this.borderWidth = 2,
    required this.text,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    // Background gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // Glass highlight
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.35),
          Colors.white.withOpacity(0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, highlightPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);

    // Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.bold,
          fontSize: 16,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );

    final textX = (size.width - textPainter.width) / 2;
    final textY =
        (size.height - textPainter.height) / 2 + size.height * 0.08;

    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(covariant TrianglePainter oldDelegate) {
    return oldDelegate.gradientColors != gradientColors ||
        oldDelegate.text != text ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}