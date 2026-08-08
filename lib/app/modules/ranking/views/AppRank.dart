import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';

import '../../../../constants/spinkit.dart';
import '../controllers/ranking_controller.dart';
import 'sendingListShow.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Apprank extends StatefulWidget {
  const Apprank({super.key});

  @override
  State<Apprank> createState() => _ApprankState();
}

class _ApprankState extends State<Apprank> with SingleTickerProviderStateMixin {
  late final RankingController controller;
  late final TabController _periodTabController;

  static const Color _gold = Color(0xFFFFD15D);
  static const Color _deepBrown = Color(0xFF3B1305);

  final List<String> _periods = const ['daily', 'weekly', 'monthly', 'overall'];

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<RankingController>()
        ? Get.find<RankingController>()
        : Get.put(RankingController(), permanent: true);

    _periodTabController = TabController(length: 4, vsync: this);
    _periodTabController.addListener(_onPeriodChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.showRankingList(period: 'daily', force: false);
    });
  }

  void _onPeriodChanged() {
    if (!_periodTabController.indexIsChanging) {
      final period = _periods[_periodTabController.index];
      controller.showRankingList(period: period, force: false);
    }
  }

  @override
  void dispose() {
    _periodTabController.removeListener(_onPeriodChanged);
    _periodTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(() {
        return LoadingOverlay(
          isLoading: controller.isLoading.value &&
              controller.senderRankingFor(controller.selectedRankingPeriod.value).isEmpty,
          progressIndicator: kLoadingIndicator(),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _RoyalSoftPatternPainter()),
                ),
              ),
              Column(
                children: [
                  SizedBox(height: _rh(context, 8)),
                  _timeTabs(context),
                  SizedBox(height: _rh(context, 8)),
                  _refreshText(context),
                  Expanded(
                    child: TabBarView(
                      controller: _periodTabController,
                      physics: const BouncingScrollPhysics(),
                      children: const [
                        Sendinglistshow(period: 'daily'),
                        Sendinglistshow(period: 'weekly'),
                        Sendinglistshow(period: 'monthly'),
                        Sendinglistshow(period: 'overall'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _timeTabs(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _rw(context, 20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: _rh(context, 50),
            padding: EdgeInsets.all(_rw(context, 4)),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.36),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.28),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: TabBar(
              controller: _periodTabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.zero,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF7B4),
                    Color(0xFFFFC95B),
                    Color(0xFFFF8B19),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(.45), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FFB736), blurRadius: 10, offset: Offset(0, 4)),
                  BoxShadow(color: Color(0x80FFFFFF), blurRadius: 4, offset: Offset(0, -1)),
                ],
              ),
              labelColor: _deepBrown,
              unselectedLabelColor: Colors.white.withOpacity(.72),
              labelStyle: GoogleFonts.poppins(fontSize: _rf(context, 13), fontWeight: FontWeight.w900),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: _rf(context, 13), fontWeight: FontWeight.w800),
              tabs:  [
                Tab(text: ('Daily').appTr),
                Tab(text: ('Weekly').appTr),
                Tab(text: ('Monthly').appTr),
                Tab(text: ('Over all').appTr),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _refreshText(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.access_time_filled_rounded, size: _rf(context, 13), color: _gold.withOpacity(.88)),
        SizedBox(width: _rw(context, 5)),
        Text(
          ('Data is refreshed every 1 minute').appTr,
          style: GoogleFonts.poppins(
            fontSize: _rf(context, 12.5),
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(.72),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _RoyalSoftPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFFD15D).withOpacity(.040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = 8; y < size.height; y += 76) {
      for (double x = -22; x < size.width + 40; x += 76) {
        final path = Path()
          ..moveTo(x + 18, y + 38)
          ..quadraticBezierTo(x + 38, y + 8, x + 58, y + 38)
          ..quadraticBezierTo(x + 38, y + 68, x + 18, y + 38);
        canvas.drawPath(path, goldPaint);
        canvas.drawCircle(Offset(x + 38, y + 38), 6, goldPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double _rw(BuildContext context, double value) {
  final width = MediaQuery.of(context).size.width;
  return value * (width / 390).clamp(.86, 1.18);
}

double _rh(BuildContext context, double value) {
  final height = MediaQuery.of(context).size.height;
  return value * (height / 844).clamp(.84, 1.14);
}

double _rf(BuildContext context, double value) {
  final width = MediaQuery.of(context).size.width;
  return value * (width / 390).clamp(.84, 1.08);
}
