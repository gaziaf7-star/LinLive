import 'dart:ui';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';
import '../controllers/ranking_controller.dart';
import 'AppRank.dart';
import 'hederRanking/AgencyRankingMainPage.dart';
import 'hederRanking/ReceiverRankingMainPage.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Allrank extends StatefulWidget {
  const Allrank({super.key});

  @override
  State<Allrank> createState() => _AllrankState();
}

class _AllrankState extends State<Allrank> with SingleTickerProviderStateMixin {
  late final RankingController controller;
  late final TabController _mainTabController;

  final List<String> _backgroundImages = const [
    'assets/audio_live/snd.png', // Sending background
    'assets/audio_live/reciviBg.png', // Receiving background
    'assets/audio_live/agency.png', // Agency background
  ];

  final List<String> _titles = const [
    'Sending Ranking',
    'Receiving Ranking',
    'Agency Ranking',
  ];

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<RankingController>()
        ? Get.find<RankingController>()
        : Get.put(RankingController(), permanent: true);

    _mainTabController = TabController(length: 3, vsync: this);
    _mainTabController.addListener(_onMainTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.setMainRankingTab(0);
      controller.showRankingList(
        period: controller.selectedRankingPeriod.value,
        force: false,
      );
    });
  }

  void _onMainTabChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_mainTabController.indexIsChanging) {
      controller.setMainRankingTab(_mainTabController.index);
      controller.showRankingList(
        period: controller.selectedRankingPeriod.value,
        force: false,
      );
    }
  }

  @override
  void dispose() {
    _mainTabController.removeListener(_onMainTabChanged);
    _mainTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _mainTabController.index.clamp(0, _backgroundImages.length - 1);
    final bg = _backgroundImages[currentIndex];

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.025, end: 1).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                bg,
                key: ValueKey(bg),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackBackground(currentIndex),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.16),
                      Colors.black.withOpacity(.04),
                      Colors.black.withOpacity(.28),
                      Colors.black.withOpacity(.58),
                    ],
                    stops: const [0.0, .28, .58, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _AllRankRoyalGlowPainter()),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: kHeight*0.03,
                ),
                _topBar(context, currentIndex),
                _mainTabs(context),
                Expanded(
                  child: TabBarView(
                    controller: _mainTabController,
                    physics: const BouncingScrollPhysics(),
                    children: const [
                      Apprank(),
                      Receiverrankingmainpage(),
                      Agencyrankingmainpage(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackBackground(int index) {
    final colors = index == 1
        ? const [Color(0xFF051B2E), Color(0xFF173B54), Color(0xFF06111E)]
        : index == 2
        ? const [Color(0xFF21120A), Color(0xFF744012), Color(0xFF2B1204)]
        : const [Color(0xFF201006), Color(0xFF643211), Color(0xFF240D03)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, int currentIndex) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Get.width * .025, 6, Get.width * .035, 2),
      child: SizedBox(
        height: kHeight * .050,
        child: Row(
          children: [
            _circleIcon(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: Get.back,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _titles[currentIndex],
                  key: ValueKey(_titles[currentIndex]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.024,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                      Shadow(color: Color(0x99FFD15D), blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
            Obx(
                  () => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: InkWell(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        onSelect: (Country country) {
                          controller.selectedCountry.value = country;
                          controller.refreshRankingPeriod(controller.selectedRankingPeriod.value);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: kHeight * .042,
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(.28)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.16),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.selectedCountry.value.flagEmoji,
                            style: TextStyle(fontSize: kHeight * 0.018),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIcon({required IconData icon, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: kHeight * .044,
            height: kHeight * .044,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.10),
              border: Border.all(color: Colors.white.withOpacity(.28)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: kHeight * .021),
          ),
        ),
      ),
    );
  }

  Widget _mainTabs(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 54,
          width: Get.width * 0.88,
          padding: const EdgeInsets.all(3),
          margin: const EdgeInsets.only(top: 7, bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: const Color(0xffffdf95).withOpacity(.76), width: 1.2),
            color: Colors.white.withOpacity(.08),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 5)),
              BoxShadow(color: const Color(0xffffd47a).withOpacity(0.13), blurRadius: 16, spreadRadius: 1),
            ],
          ),
          child: TabBar(
            controller: _mainTabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xfffff0b7), Color(0xffffcf70), Color(0xffff9f2f)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x80ffcc5c), blurRadius: 10, offset: Offset(0, 3)),
                BoxShadow(color: Color(0x66ffffff), blurRadius: 4, offset: Offset(0, -1)),
              ],
            ),
            dividerColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            labelColor: const Color(0xff34200e),
            unselectedLabelColor: Colors.white.withOpacity(.82),
            labelStyle: GoogleFonts.poppins(fontSize: Get.width * 0.036, fontWeight: FontWeight.w800),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: Get.width * 0.036, fontWeight: FontWeight.w700),
            labelPadding: EdgeInsets.zero,
            tabs:  [
              Tab(text: ('Sending').appTr),
              Tab(text: ('Receiving').appTr),
              Tab(text: ('Agency').appTr),
            ],
          ),
        ),
      ),
    );
  }

}

class _AllRankRoyalGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFFD15D).withOpacity(.08);

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * .50, size.height * .38),
        size.width * (.18 + (i * .09)),
        paint,
      );
    }

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.055);

    for (double y = size.height * .18; y < size.height; y += 130) {
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(size.width * .25, y - 22, size.width * .50, y)
        ..quadraticBezierTo(size.width * .75, y + 22, size.width, y - 4);
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
