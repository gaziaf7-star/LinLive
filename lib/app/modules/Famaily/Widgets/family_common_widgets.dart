import 'package:flutter/material.dart';

class FamilyUi {
  const FamilyUi._();

  static double r(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    return (width / 390 * value).clamp(value * .88, value * 1.22).toDouble();
  }

  static String compact(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 2)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }
}

class FamilyNetworkImage extends StatelessWidget {
  const FamilyNetworkImage({super.key, required this.url, required this.size, this.radius = 12, this.placeholderIcon = Icons.workspace_premium_rounded});
  final String url;
  final double size;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(colors: [Color(0xff321276), Color(0xff10051F)]),
      ),
      child: Icon(placeholderIcon, color: const Color(0xffFFD35A), size: size * .55),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

class FamilyTopBar extends StatelessWidget {
  const FamilyTopBar({super.key, required this.title, this.onBack, this.trailing});
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = FamilyUi.r;
    return SizedBox(
      height: r(context, 48),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r(context, 10)),
        child: Row(
          children: [
            InkWell(
              onTap: onBack ?? () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: EdgeInsets.all(r(context, 7)),
                child: Icon(Icons.arrow_back_rounded, size: r(context, 24), color: Colors.black),
              ),
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontSize: r(context, 17.5), fontWeight: FontWeight.w900, color: Colors.black)),
            const Spacer(),
            SizedBox(width: r(context, 38), child: Center(child: trailing ?? Icon(Icons.settings_outlined, size: r(context, 22), color: Colors.black))),
          ],
        ),
      ),
    );
  }
}

class FamilyPurpleHeaderPainter extends CustomPainter {
  const FamilyPurpleHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff090323), Color(0xff28105F), Color(0xff12062E)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final glow = Paint()
      ..color = const Color(0xff8D4DFF).withOpacity(0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.32), size.width * 0.22, glow);

    final bottomGlow = Paint()
      ..color = const Color(0xff6D32E8).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.92), size.width * 0.45, bottomGlow);

    final ring = Paint()
      ..color = const Color(0xffB56AFF).withOpacity(0.36)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (int i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.76), width: size.width * (0.38 + i * 0.14), height: size.height * (0.12 + i * 0.055)),
        ring,
      );
    }

    final wave = Paint()
      ..color = const Color(0xffA64FFF).withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final path = Path()
      ..moveTo(-20, size.height * 0.55)
      ..cubicTo(size.width * 0.20, size.height * 0.34, size.width * 0.28, size.height * 0.78, size.width * 0.48, size.height * 0.54)
      ..cubicTo(size.width * 0.66, size.height * 0.30, size.width * 0.76, size.height * 0.58, size.width + 25, size.height * 0.36);
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
