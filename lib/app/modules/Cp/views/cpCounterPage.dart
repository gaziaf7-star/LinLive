import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/cp_data_controller.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class LoveCounterPage extends StatefulWidget {
  const LoveCounterPage({super.key});

  @override
  State<LoveCounterPage> createState() => _LoveCounterPageState();
}

class _LoveCounterPageState extends State<LoveCounterPage>
    with SingleTickerProviderStateMixin {
  final CpDataController cpController = Get.put(CpDataController());

  late final AnimationController _bgAnim;

  @override
  void initState() {
    super.initState();

    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    cpController.fetchCpData(showLoader: false);
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cp = cpController.acceptedCp;

      if (cpController.isLoading.value && cp == null) {
        return  CpLoadingPage(title: ('Love Counter').appTr);
      }

      if (cp == null) {
        return CpNoAcceptedView(
          title: ('Love Counter').appTr,
          onRefresh: () => cpController.fetchCpData(),
        );
      }

      return _buildCounter(context, cp);
    });
  }

  Widget _buildCounter(BuildContext context, CpRequestModel cp) {
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = screen.width > 520 ? 520.0 : screen.width;

    return Scaffold(
      backgroundColor: const Color(0xfffff8fb),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgAnim,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: _LoveBgPainter(_bgAnim.value),
                    );
                  },
                ),
              ),
              SafeArea(
                child: RefreshIndicator(
                  onRefresh: () => cpController.fetchCpData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      maxWidth * .055,
                      8,
                      maxWidth * .055,
                      28,
                    ),
                    child: Column(
                      children: [
                        _topBar(context),
                        const SizedBox(height: 18),
                        _circleCounter(cp),
                        const SizedBox(height: 28),
                        _statCards(cp),
                        const SizedBox(height: 30),
                        _sectionHeader(),
                        const SizedBox(height: 14),
                        _cpWidgets(cp),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(50),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 22,
                color: Color(0xff1f1c25),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:  [
                Icon(
                  Icons.favorite_rounded,
                  color: Color(0xffff5d96),
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  ('Love Counter').appTr,
                  style: TextStyle(
                    color: Color(0xff1f1c25),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.more_vert_rounded,
              size: 24,
              color: Color(0xff1f1c25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleCounter(CpRequestModel cp) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: .82),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 230,
          height: 230,
          child: CustomPaint(
            painter: _CircleProgressPainter(progress: value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    ('Together For').appTr,
                    style: TextStyle(
                      color: Color(0xff6a5b66),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${cp.daysTogether}',
                    style: const TextStyle(
                      color: Color(0xffff5d96),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: .95,
                    ),
                  ),
                  const SizedBox(height: 6),
                   Text(
                    ('Days').appTr,
                    style: TextStyle(
                      color: Color(0xff2a2630),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    cp.sinceFullDate,
                    style: const TextStyle(
                      color: Color(0xff2a2630),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statCards(CpRequestModel cp) {
    final items = [
      _StatItem('${cp.monthsTogether}', ('Months').appTr, const Color(0xffff5d96)),
      _StatItem('${cp.daysTogether}', ('Days').appTr, const Color(0xff1f1c25)),
      _StatItem(cpCompactNumber(cp.hoursTogether), ('Hours').appTr, const Color(0xff26376b)),
      _StatItem(cpCompactNumber(cp.minutesTogether), ('Minutes').appTr, const Color(0xffff5d96)),
    ];

    return Row(
      children: List.generate(items.length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 10),
            child: _statCard(items[index]),
          ),
        );
      }),
    );
  }

  Widget _statCard(_StatItem item) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: item.color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            style: TextStyle(
              color: const Color(0xff27242d).withOpacity(.72),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
         Text(
          ('CP Widget').appTr,
          style: TextStyle(
            color: Color(0xff1f1c25),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child:  Padding(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: Row(
              children: [
                Text(
                  ('See All').appTr,
                  style: TextStyle(
                    color: Color(0xff8b7d89),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 3),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Color(0xff8b7d89),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cpWidgets(CpRequestModel cp) {
    return Row(
      children: [
        Expanded(child: _darkCpCard(cp)),
        const SizedBox(width: 14),
        Expanded(child: _pinkCpCard(cp)),
      ],
    );
  }

  Widget _darkCpCard(CpRequestModel cp) {
    return AspectRatio(
      aspectRatio: .74,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff0f102a),
              Color(0xff24114b),
              Color(0xff4b155f),
              Color(0xffed4f9b),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff5d96).withOpacity(.22),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GalaxyPainter())),
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '${cp.me.name.isEmpty ? 'You' : cp.me.name} & ${cp.partner.name.isEmpty ? 'CP' : cp.partner.name} ❤',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cp.daysTogether}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 39,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                     Text(
                      ('Days Together').appTr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xffff5d96).withOpacity(.75),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinkCpCard(CpRequestModel cp) {
    return AspectRatio(
      aspectRatio: .74,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfffff5fb),
              Color(0xffffe6f1),
              Color(0xffffc7df),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(.12),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _PinkWidgetPainter())),
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  ('You & Me ❤').appTr,
                  style: const TextStyle(
                    color: Color(0xff2b2530),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    '${cp.daysTogether}',
                    style: const TextStyle(
                      color: Color(0xffff5d96),
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                   Text(
                    ('Days Together').appTr,
                    style: TextStyle(
                      color: Color(0xffff5d96),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 105),
                painter: _CouplePainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String value;
  final String label;
  final Color color;

  _StatItem(this.value, this.label, this.color);
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;

  _CircleProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .40;
    final stroke = 12.0;

    final bgPaint = Paint()
      ..color = const Color(0xffffd8e8)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi * .78,
        endAngle: math.pi * 2.25,
        colors: [
          Color(0xffff4d8c),
          Color(0xffff7eb1),
          Color(0xffff4d8c),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startAngle = math.pi * .78;
    final sweepAngle = math.pi * 1.45;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );

    final dotPaint = Paint()..color = const Color(0xffff5d96);
    canvas.drawCircle(Offset(center.dx, center.dy - radius), 7, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _LoveBgPainter extends CustomPainter {
  final double progress;

  _LoveBgPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xfffff8fb),
          Color(0xffffffff),
          Color(0xfffff6fa),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bgPaint);

    final random = math.Random(17);
    for (int i = 0; i < 28; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * .55;
      final move = math.sin((progress + i * .07) * math.pi * 2) * 5;
      final heartSize = 5 + random.nextDouble() * 12;

      _drawHeart(
        canvas,
        Offset(x, y + move),
        heartSize,
        const Color(0xffff95bd).withOpacity(i % 2 == 0 ? .14 : .08),
      );
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    final x = center.dx;
    final y = center.dy;
    final s = size / 18;

    path.moveTo(x, y + 5 * s);
    path.cubicTo(x - 18 * s, y - 6 * s, x - 9 * s, y - 18 * s, x, y - 8 * s);
    path.cubicTo(x + 9 * s, y - 18 * s, x + 18 * s, y - 6 * s, x, y + 5 * s);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LoveBgPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _GalaxyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(22);
    final paint = Paint();

    for (int i = 0; i < 80; i++) {
      paint.color = Colors.white.withOpacity(.12 + random.nextDouble() * .45);
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        .6 + random.nextDouble() * 1.3,
        paint,
      );
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffff5d96).withOpacity(.40),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .5, size.height * .76),
          radius: size.width * .55,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * .5, size.height * .76),
      size.width * .55,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PinkWidgetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(44);

    for (int i = 0; i < 35; i++) {
      _drawHeart(
        canvas,
        Offset(
          random.nextDouble() * size.width,
          size.height * (.28 + random.nextDouble() * .40),
        ),
        5 + random.nextDouble() * 10,
        const Color(0xffff6aa3).withOpacity(.14),
      );
    }

    final hillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xffffb8d5),
          Color(0xffff8ebe),
        ],
      ).createShader(
        Offset(0, size.height * .62) & Size(size.width, size.height * .38),
      );

    final path = Path()
      ..moveTo(0, size.height * .72)
      ..quadraticBezierTo(
        size.width * .30,
        size.height * .62,
        size.width * .55,
        size.height * .72,
      )
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .80,
        size.width,
        size.height * .68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, hillPaint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();
    final x = center.dx;
    final y = center.dy;
    final s = size / 18;

    path.moveTo(x, y + 5 * s);
    path.cubicTo(x - 18 * s, y - 6 * s, x - 9 * s, y - 18 * s, x, y - 8 * s);
    path.cubicTo(x + 9 * s, y - 18 * s, x + 18 * s, y - 6 * s, x, y + 5 * s);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CouplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xff1e243a);
    final baseY = size.height * .76;

    canvas.drawCircle(Offset(size.width * .42, baseY - 43), 15, dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * .42, baseY - 17),
          width: 26,
          height: 48,
        ),
        const Radius.circular(14),
      ),
      dark,
    );

    canvas.drawCircle(Offset(size.width * .60, baseY - 43), 15, dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * .60, baseY - 17),
          width: 26,
          height: 48,
        ),
        const Radius.circular(14),
      ),
      dark,
    );

    final armPaint = Paint()
      ..color = const Color(0xff1e243a)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * .46, baseY - 15),
      Offset(size.width * .55, baseY - 15),
      armPaint,
    );

    final groundPaint = Paint()..color = const Color(0xff1e243a).withOpacity(.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .20, baseY + 8, size.width * .62, 10),
        const Radius.circular(20),
      ),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}