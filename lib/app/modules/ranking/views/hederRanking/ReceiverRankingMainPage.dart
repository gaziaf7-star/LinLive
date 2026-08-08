import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';

import '../../../../../constants/spinkit.dart';
import '../../controllers/ranking_controller.dart';
import 'receiver_rankingList.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Receiverrankingmainpage extends StatefulWidget {
  const Receiverrankingmainpage({super.key});

  @override
  State<Receiverrankingmainpage> createState() => _ReceiverrankingmainpageState();
}

class _ReceiverrankingmainpageState extends State<Receiverrankingmainpage>
    with SingleTickerProviderStateMixin {
  late final RankingController controller;
  late final TabController _periodTabController;

  static const Color _cyan = Color(0xFF64E8FF);
  static const Color _blue = Color(0xFF2B7CFF);
  static const Color _purple = Color(0xFF7C4DFF);
  static const Color _deepBlue = Color(0xFF071C3A);

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
        final period = controller.selectedRankingPeriod.value;
        return LoadingOverlay(
          isLoading: controller.isLoading.value &&
              controller.receiverRankingFor(period).isEmpty,
          progressIndicator: kLoadingIndicator(),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ReceiverSoftPatternPainter()),
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
                        RankingReciverList(period: 'daily'),
                        RankingReciverList(period: 'weekly'),
                        RankingReciverList(period: 'monthly'),
                        RankingReciverList(period: 'overall'),
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
              color: Colors.black.withOpacity(.30),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _cyan.withOpacity(.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.26),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: _cyan.withOpacity(.16),
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
                    Color(0xFFE9FAFF),
                    Color(0xFF6AE6FF),
                    Color(0xFF2B7CFF),
                  ],
                ),
                border: Border.all(color: Colors.white70, width: 1.1),
                boxShadow: const [
                  BoxShadow(color: Color(0x884BD9FF), blurRadius: 10, offset: Offset(0, 4)),
                  BoxShadow(color: Color(0x66FFFFFF), blurRadius: 4, offset: Offset(0, -1)),
                ],
              ),
              labelColor: _deepBlue,
              unselectedLabelColor: Colors.white.withOpacity(.76),
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
        Icon(Icons.auto_awesome_rounded, size: _rf(context, 13), color: _cyan.withOpacity(.90)),
        SizedBox(width: _rw(context, 5)),
        Text(
          ('Data is refreshed every 1 minute').appTr,
          style: GoogleFonts.poppins(
            fontSize: _rf(context, 12.5),
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(.74),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _ReceiverSoftPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFF64E8FF).withOpacity(.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final Paint dotPaint = Paint()
      ..color = const Color(0xFF7C4DFF).withOpacity(.050)
      ..style = PaintingStyle.fill;

    for (double y = 10; y < size.height; y += 76) {
      for (double x = -26; x < size.width + 44; x += 76) {
        final path = Path()
          ..moveTo(x + 38, y + 10)
          ..quadraticBezierTo(x + 62, y + 38, x + 38, y + 66)
          ..quadraticBezierTo(x + 14, y + 38, x + 38, y + 10);
        canvas.drawPath(path, linePaint);
        canvas.drawCircle(Offset(x + 38, y + 38), 5.5, linePaint);
        canvas.drawCircle(Offset(x + 60, y + 60), 2.4, dotPaint);
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
