import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/cp_data_controller.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class AnniversaryPage extends StatefulWidget {
  const AnniversaryPage({super.key});

  @override
  State<AnniversaryPage> createState() => _AnniversaryPageState();
}

class _AnniversaryPageState extends State<AnniversaryPage>
    with SingleTickerProviderStateMixin {
  final CpDataController cpController = Get.put(CpDataController());

  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    cpController.fetchCpData(showLoader: false);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cp = cpController.acceptedCp;

      if (cpController.isLoading.value && cp == null) {
        return  CpLoadingPage(title: ('Anniversary').appTr);
      }

      if (cp == null) {
        return CpNoAcceptedView(
          title: ('Anniversary').appTr,
          onRefresh: () => cpController.fetchCpData(),
        );
      }

      return _buildAnniversary(context, cp);
    });
  }

  Widget _buildAnniversary(BuildContext context, CpRequestModel cp) {
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
                  animation: _animation,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: _AnniversaryBgPainter(_animation.value),
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
                      30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _topBar(context),
                        const SizedBox(height: 24),
                        _mainAnniversaryCard(cp),
                        const SizedBox(height: 24),
                        _sectionTitle(('Upcoming').appTr),
                        const SizedBox(height: 12),
                        _upcomingCard(cp),
                        const SizedBox(height: 25),
                        _sectionTitle(('Memories').appTr),
                        const SizedBox(height: 12),
                        _memoriesRow(cp),
                        const SizedBox(height: 20),
                        Center(child: _viewAllButton()),
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
      height: 34,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(40),
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
            child: Center(
              child: Text(
                ('Anniversary').appTr,
                style: TextStyle(
                  color: Color(0xff1f1c25),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _mainAnniversaryCard(CpRequestModel cp) {
    return Container(
      width: double.infinity,
      height: 176,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffffd7ea),
            Color(0xffffe7f2),
            Color(0xffffc4df),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff8fbd).withOpacity(.16),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PinkHeartCardPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text(
                  ('Our Anniversary').appTr,
                  style: TextStyle(
                    color: Color(0xff24212c),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _calendarIcon(),
                const SizedBox(height: 13),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cp.anniversaryShort,
                      style: const TextStyle(
                        color: Color(0xff24212c),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xffff5d96),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarIcon() {
    return Container(
      width: 84,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffff73a9), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff6aa5).withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xffff9ac3),
                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
              ),
            ),
          ),
          Positioned(top: -7, left: 20, child: _calendarRing()),
          Positioned(top: -7, right: 20, child: _calendarRing()),
          Positioned(
            top: 29,
            child: Container(
              width: 42,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xff2d324c),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffff5d96).withOpacity(.20),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xffff5d96),
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarRing() {
    return Container(
      width: 9,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffff5d96), width: 2),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xff201d27),
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _upcomingCard(CpRequestModel cp) {
    return Container(
      width: double.infinity,
      height: 116,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xfffff0f6),
            Color(0xfffff7fa),
            Color(0xffffeef5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                  ('Next Anniversary').appTr,
                  style: TextStyle(
                    color: Color(0xff5c4a58),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cp.nextAnniversaryText,
                  style: const TextStyle(
                    color: Color(0xff1f1c25),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  ('${cp.daysLeftForAnniversary} Days Left').appTr,
                  style: const TextStyle(
                    color: Color(0xff1f1c25),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            height: 95,
            child: CustomPaint(painter: _BalloonPainter()),
          ),
        ],
      ),
    );
  }

  Widget _memoriesRow(CpRequestModel cp) {
    final items = [
      cp.me.profileImage,
      cp.partner.profileImage,
      '',
    ];

    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 9),
            child: _memoryItem(items[index], index),
          ),
        );
      }),
    );
  }

  Widget _memoryItem(String image, int index) {
    return AspectRatio(
      aspectRatio: 1.07,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: image.isNotEmpty
              ? CpImage(imageUrl: image, size: 160, iconSize: 38)
              : _memoryPlaceholder(index),
        ),
      ),
    );
  }

  Widget _memoryPlaceholder(int index) {
    final gradients = [
      const [Color(0xff1d2446), Color(0xffffb1c9)],
      const [Color(0xff3c496b), Color(0xffffd7e4)],
      const [Color(0xff202c44), Color(0xffffa8c8)],
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradients[index],
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: 14, bottom: 12, child: _miniAvatar(const Color(0xff22283f))),
          Positioned(right: 14, bottom: 12, child: _miniAvatar(const Color(0xffff8eb7))),
          Positioned(
            right: 10,
            top: 10,
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white.withOpacity(.75),
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAvatar(Color color) {
    return Column(
      children: [
        Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4),
          ),
        ),
        Container(
          width: 28,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(.88),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(15),
              bottom: Radius.circular(5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewAllButton() {
    return Container(
      width: 96,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: const LinearGradient(
          colors: [
            Color(0xffff7cab),
            Color(0xffff4f8f),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff5d96).withOpacity(.30),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: () {},
          child:  Center(
            child: Text(
              ('View All').appTr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnniversaryBgPainter extends CustomPainter {
  _AnniversaryBgPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xfffff8fb),
          Color(0xffffffff),
          Color(0xfffff6fa),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bg);

    final random = math.Random(12);
    for (int i = 0; i < 22; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * .72;
      final floatY = math.sin((progress + i * .08) * math.pi * 2) * 5;
      final s = 8 + random.nextDouble() * 14;

      _drawHeart(
        canvas,
        Offset(x, y + floatY),
        s,
        const Color(0xffff8fbd).withOpacity(i % 3 == 0 ? .20 : .11),
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
  bool shouldRepaint(covariant _AnniversaryBgPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _PinkHeartCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(33);

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final s = 5 + random.nextDouble() * 10;

      _drawHeart(
        canvas,
        Offset(x, y),
        s,
        const Color(0xffff6fa7).withOpacity(.12),
      );
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(.25),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .5, size.height * .5),
          radius: size.width * .45,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * .5, size.height * .5),
      size.width * .45,
      glowPaint,
    );
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

class _BalloonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xffff8eb8).withOpacity(.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * .58, size.height * .46),
      Offset(size.width * .50, size.height * .96),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * .34, size.height * .60),
      Offset(size.width * .46, size.height * .98),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * .76, size.height * .72),
      Offset(size.width * .54, size.height * .98),
      linePaint,
    );

    _drawHeartBalloon(
      canvas,
      Offset(size.width * .62, size.height * .25),
      32,
      const Color(0xffff4f77),
      const Color(0xffff9ab3),
    );

    _drawHeartBalloon(
      canvas,
      Offset(size.width * .36, size.height * .52),
      25,
      const Color(0xffffb3cb),
      const Color(0xffffe6ef),
    );

    _drawHeartBalloon(
      canvas,
      Offset(size.width * .78, size.height * .66),
      15,
      const Color(0xffff5d96),
      const Color(0xffffa7c5),
    );
  }

  void _drawHeartBalloon(
      Canvas canvas,
      Offset center,
      double size,
      Color color1,
      Color color2,
      ) {
    final rect = Rect.fromCircle(center: center, radius: size);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color2, color1],
      ).createShader(rect);

    final path = Path();
    final x = center.dx;
    final y = center.dy;
    final s = size / 18;

    path.moveTo(x, y + 6 * s);
    path.cubicTo(x - 20 * s, y - 5 * s, x - 10 * s, y - 21 * s, x, y - 10 * s);
    path.cubicTo(x + 10 * s, y - 21 * s, x + 20 * s, y - 5 * s, x, y + 6 * s);
    path.close();

    canvas.drawPath(path, paint);

    final shine = Paint()..color = Colors.white.withOpacity(.35);
    canvas.drawCircle(
      Offset(center.dx - size * .22, center.dy - size * .22),
      size * .13,
      shine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}