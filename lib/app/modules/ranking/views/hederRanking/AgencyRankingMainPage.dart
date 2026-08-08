import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';

import '../../../../../constants/spinkit.dart';
import '../../controllers/ranking_controller.dart';
import 'agency_rankinList.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Agencyrankingmainpage extends StatefulWidget {
  const Agencyrankingmainpage({super.key});

  @override
  State<Agencyrankingmainpage> createState() => _AgencyrankingmainpageState();
}

class _AgencyrankingmainpageState extends State<Agencyrankingmainpage>
    with SingleTickerProviderStateMixin {
  late final RankingController controller;
  late final TabController _periodTabController;

  static const Color _emerald = Color(0xFF5DFFB5);
  static const Color _deepGreen = Color(0xFF062719);

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
              controller
                  .agencyRankingFor(controller.selectedRankingPeriod.value)
                  .isEmpty,
          progressIndicator: kLoadingIndicator(),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _AgencyRoyalPatternPainter()),
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
                        AgencyRankingList(period: 'daily'),
                        AgencyRankingList(period: 'weekly'),
                        AgencyRankingList(period: 'monthly'),
                        AgencyRankingList(period: 'overall'),
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
              color: Colors.black.withOpacity(.28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.26),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: _emerald.withOpacity(.13),
                  blurRadius: 18,
                  spreadRadius: 1,
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
                    Color(0xFFE9FFF4),
                    Color(0xFF62F7B8),
                    Color(0xFF00B878),
                  ],
                ),
                border:
                Border.all(color: Colors.white.withOpacity(.46), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x8037FFB0),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color(0x80FFFFFF),
                    blurRadius: 4,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              labelColor: _deepGreen,
              unselectedLabelColor: Colors.white.withOpacity(.78),
              labelStyle: GoogleFonts.poppins(
                fontSize: _rf(context, 13),
                fontWeight: FontWeight.w900,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: _rf(context, 13),
                fontWeight: FontWeight.w800,
              ),
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
        Icon(
          Icons.access_time_filled_rounded,
          size: _rf(context, 13),
          color: _emerald.withOpacity(.94),
        ),
        SizedBox(width: _rw(context, 5)),
        Text(
          ('Data is refreshed every 1 minute').appTr,
          style: GoogleFonts.poppins(
            fontSize: _rf(context, 12.5),
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(.78),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _AgencyRoyalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final emeraldPaint = Paint()
      ..color = const Color(0xFF5DFFB5).withOpacity(.038)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = 12; y < size.height; y += 86) {
      for (double x = -26; x < size.width + 40; x += 86) {
        final path = Path()
          ..moveTo(x + 43, y + 6)
          ..quadraticBezierTo(x + 76, y + 43, x + 43, y + 80)
          ..quadraticBezierTo(x + 10, y + 43, x + 43, y + 6);
        canvas.drawPath(path, emeraldPaint);
        canvas.drawCircle(Offset(x + 43, y + 43), 6, emeraldPaint);
      }
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF84FFD0).withOpacity(.05);

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * .50, size.height * .42),
        size.width * (.16 + i * .08),
        glowPaint,
      );
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
