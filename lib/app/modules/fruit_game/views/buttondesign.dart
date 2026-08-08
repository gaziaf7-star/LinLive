import 'package:flutter/material.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final Color color;

  const NeonButton({
    super.key,
    required this.text,
    required this.color,
    this.width = 130,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _NeonPainter(color),
          ),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: height * 0.42,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final Color color;

  _NeonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPath(size, 10);

    /// Gradient (main color based)
    final gradient = LinearGradient(
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.4),
      ],
    );

    final paintFill = Paint()
      ..shader = gradient.createShader(Offset.zero & size);

    canvas.drawPath(path, paintFill);

    /// Glow
    final glowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, glowPaint);

    /// Border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, borderPaint);
  }

  Path _createPath(Size size, double cut) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}