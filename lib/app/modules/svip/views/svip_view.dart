import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/svip/views/vipModel.dart';
import 'Widgets/svip_settings_page.dart';
import 'package:meetlivepro/constants/layout_constant.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../controllers/svip_controller.dart';
import 'Widgets/vipMEdiaView.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class SvipView extends StatelessWidget {
  final VipSectionMode mode;
  late final SvipController svipController;

  SvipView({super.key, this.mode = VipSectionMode.vip}) {
    final String tag = mode.name;
    svipController = Get.isRegistered<SvipController>(tag: tag)
        ? Get.find<SvipController>(tag: tag)
        : Get.put(SvipController(mode: mode), tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff080402),
      body: Stack(
        children: [
          Obx(() {
            if (svipController.isLoading.value && svipController.vipLevels.isEmpty) {
              return const _VipLoadingPage();
            }

            if (svipController.vipLevels.isEmpty) {
              return _VipEmptyPage(onRefresh: svipController.refreshVipSystem);
            }

            final level = svipController.selectedLevel ?? svipController.vipLevels.first;
            final int selectedIndex = svipController.selectedTab.value;

            return _VipLevelBody(
              level: level,
              controller: svipController,
              style: _VipStyle.byIndex(selectedIndex, mode: svipController.mode),
            );
          }),
          _TopBar(controller: svipController),
          _VipTabBar(controller: svipController),


          Obx(() {
            final level = svipController.selectedLevel;
            if (level == null) return const SizedBox.shrink();

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              left: 12,
              right: 12,
              bottom: svipController.showBottomCard.value ? 18 : -150,
              child: _BottomBuyCard(
                level: level,
                controller: svipController,
                style: _VipStyle.byIndex(
                  svipController.selectedTab.value,
                  mode: svipController.mode,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _VipStyle {
  final Color bgDark;
  final Color bgDeep;
  final Color primary;
  final Color secondary;
  final Color cardTop;
  final Color cardBottom;
  final String bgAsset;

  const _VipStyle({
    required this.bgDark,
    required this.bgDeep,
    required this.primary,
    required this.secondary,
    required this.cardTop,
    required this.cardBottom,
    required this.bgAsset,
  });

  static _VipStyle byIndex(int index, {VipSectionMode mode = VipSectionMode.vip}) {
    final List<_VipStyle> styles = [
      const _VipStyle(
        bgDark: Color(0xff0c0700),
        bgDeep: Color(0xff241404),
        primary: Color(0xffffdf87),
        secondary: Color(0xffb97921),
        cardTop: Color(0xff3a2814),
        cardBottom: Color(0xff201407),
        bgAsset: 'assets/Svip/bg.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff14001c),
        bgDeep: Color(0xff31003d),
        primary: Color(0xffffdf87),
        secondary: Color(0xffbb5cff),
        cardTop: Color(0xff42044d),
        cardBottom: Color(0xff24002c),
        bgAsset: 'assets/Svip/Svip3.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff130606),
        bgDeep: Color(0xff381010),
        primary: Color(0xffffdf87),
        secondary: Color(0xffff7d35),
        cardTop: Color(0xff3a1212),
        cardBottom: Color(0xff200e0e),
        bgAsset: 'assets/Svip/bg.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff110414),
        bgDeep: Color(0xff4a111f),
        primary: Color(0xffffdf87),
        secondary: Color(0xffff4274),
        cardTop: Color(0xff381010),
        cardBottom: Color(0xff200e0e),
        bgAsset: 'assets/Svip/Svip3.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff071607),
        bgDeep: Color(0xff4b2a02),
        primary: Color(0xffffdf87),
        secondary: Color(0xff50c845),
        cardTop: Color(0xff2f2407),
        cardBottom: Color(0xff141205),
        bgAsset: 'assets/Svip/Svip4.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff0c0619),
        bgDeep: Color(0xff3a064c),
        primary: Color(0xffffdf87),
        secondary: Color(0xffff43bd),
        cardTop: Color(0xff391049),
        cardBottom: Color(0xff18081d),
        bgAsset: 'assets/Svip/bg.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff160606),
        bgDeep: Color(0xff681414),
        primary: Color(0xffffdf87),
        secondary: Color(0xffff5746),
        cardTop: Color(0xff421111),
        cardBottom: Color(0xff1b0808),
        bgAsset: 'assets/Svip/Svip5.png',
      ),
      const _VipStyle(
        bgDark: Color(0xff160606),
        bgDeep: Color(0xff681414),
        primary: Color(0xffffdf87),
        secondary: Color(0xffff5746),
        cardTop: Color(0xff421111),
        cardBottom: Color(0xff1b0808),
        bgAsset: 'assets/Svip/Svip8bg.png',
      ),
    ];

    if (mode == VipSectionMode.svip) {
      // The SVIP tier reuses the same palette but starts from its deepest,
      // richest tones (the look originally reserved for the 8th/top tier)
      // instead of restarting at VIP1's bronze look, so the SVIP page still
      // reads as a distinct, more premium space than the VIP page.
      const svipStyleOrder = [7, 5, 3, 6, 1, 4, 2, 0];
      final safeIndex = index < 0 ? 0 : index;
      return styles[svipStyleOrder[safeIndex % svipStyleOrder.length]];
    }

    if (index < 0 || index >= styles.length) return styles.first;
    return styles[index];
  }
}

class _TopBar extends StatelessWidget {
  final SvipController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final double h = Get.height;
    final double w = Get.width;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: h * .072,
            child: Row(
              children: [
                SizedBox(width: w * .010),
                _PremiumCircleIcon(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: Get.back,
                  size: h * .044,
                  iconSize: h * .021,
                ),
                const Spacer(),
                _PremiumTopTitle(
                  title: controller.sectionLabel.appTr,
                  selected: true,
                  color: _VipStyle.byIndex(
                    controller.selectedTab.value,
                    mode: controller.mode,
                  ).primary,
                ),
                SizedBox(width: w * .105),
                _PremiumTopTitle(
                  title: ('Daily Bonus').appTr,
                  selected: false,
                  color: Colors.white,
                  italic: true,
                ),
                const Spacer(),
                _PremiumCircleIcon(
                  icon: CupertinoIcons.question_circle,
                  onTap: controller.fetchMyVipHistory,
                  size: h * .044,
                  iconSize: h * .025,
                ),
                SizedBox(width: w * .010),
                Obx(() {
                  final current = controller.currentVip.value;
                  final canOpen = current != null && current.isActive;
                  return Opacity(
                    opacity: canOpen ? 1 : .38,
                    child: _PremiumCircleIcon(
                      icon: Icons.settings_outlined,
                      onTap: () async {
                        if (!canOpen) {
                          controller.showMessage(
                            ('No active VIP found').appTr,
                            color: Colors.red,
                          );
                          return;
                        }
                        await controller.reloadCurrentUserVip(silent: true);
                        Get.to(
                              () => SvipSettingsPage(
                            level: controller.selectedLevel,
                            levels: controller.vipLevels.toList(),
                            controller: controller,
                          ),
                          transition: Transition.rightToLeft,
                          duration: const Duration(milliseconds: 260),
                        );
                      },
                      size: h * .044,
                      iconSize: h * .025,
                    ),
                  );
                }),
                SizedBox(width: w * .018),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumTopTitle extends StatelessWidget {
  final String title;
  final bool selected;
  final Color color;
  final bool italic;

  const _PremiumTopTitle({
    required this.title,
    required this.selected,
    required this.color,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    final double h = Get.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            color: selected ? color : Colors.white.withOpacity(.94),
            fontSize: h * .02,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: selected ? .8 : .2,
            shadows: [
              Shadow(
                color: selected ? color.withOpacity(.60) : Colors.black.withOpacity(.40),
                blurRadius: selected ? 14 : 8,
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: selected ? 4 : 0,
          width: selected ? h * .040 : 0,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: LinearGradient(
              colors: [color.withOpacity(.25), color, color.withOpacity(.25)],
            ),
            boxShadow: [BoxShadow(color: color.withOpacity(.42), blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class _PremiumCircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _PremiumCircleIcon({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(.10),
          border: Border.all(color: Colors.white.withOpacity(.16)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(.92), size: iconSize),
      ),
    );
  }
}

class _VipTabBar extends StatelessWidget {
  final SvipController controller;
  const _VipTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: Get.height * .098,
      left: 0,
      right: 0,
      child: Obx(() {
        final levels = controller.vipLevels;
        if (levels.isEmpty) return const SizedBox.shrink();
        final style = _VipStyle.byIndex(
          controller.selectedTab.value,
          mode: controller.mode,
        );

        return Container(
          height: Get.height * .065,
          margin: EdgeInsets.symmetric(horizontal: Get.width * .016),

          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: Get.width * .024),
            child: Row(
              children: List.generate(levels.length, (index) {
                final level = levels[index];
                final selected = controller.selectedTab.value == index;

                return GestureDetector(
                  onTap: () => controller.changeTab(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(right: Get.width * .045),
                    padding: EdgeInsets.symmetric(horizontal: selected ? 5 : 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              Text(
                                '❧',
                                style: TextStyle(
                                  color: style.primary,
                                  fontSize: Get.height * .020,
                                  shadows: [Shadow(color: style.primary.withOpacity(.55), blurRadius: 8)],
                                ),
                              ),
                            if (selected) const SizedBox(width: 4),
                            Text(
                              level.displayTitle.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                fontSize: selected ? Get.height * .02 : Get.height * .018,
                                color: selected ? style.primary : Colors.white.withOpacity(.50),
                                letterSpacing: selected ? .5 : .2,
                                shadows: selected
                                    ? [Shadow(color: style.primary.withOpacity(.55), blurRadius: 10)]
                                    : [],
                              ),
                            ),
                            if (selected) const SizedBox(width: 4),
                            if (selected)
                              Text(
                                '❧',
                                style: TextStyle(
                                  color: style.primary,
                                  fontSize: Get.height * .020,
                                  shadows: [Shadow(color: style.primary.withOpacity(.55), blurRadius: 8)],
                                ),
                              ),
                          ],
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: selected ? 3 : 0,
                          width: selected ? Get.width * .12 : 0,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [style.primary.withOpacity(.05), style.primary, style.primary.withOpacity(.05)],
                            ),
                            boxShadow: [BoxShadow(color: style.primary.withOpacity(.35), blurRadius: 8)],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      }),
    );
  }
}

class _VipLevelBody extends StatelessWidget {
  final VipLevel level;
  final SvipController controller;
  final _VipStyle style;

  const _VipLevelBody({
    required this.level,
    required this.controller,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final current = controller.isCurrentVipLevel(level);

    return RefreshIndicator(
      color: style.primary,
      backgroundColor: style.bgDeep,
      onRefresh: controller.refreshVipSystem,
      child: SingleChildScrollView(
        controller: controller.scrollController,
        child: Container(
          color: style.bgDark,
          child: Column(
            children: [
              _PremiumHeroArea(
                level: level,
                controller: controller,
                style: style,
                isCurrent: current,
              ),
              SizedBox(height: kHeight*0.01,),
              _WaveDivider(style: style),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [style.bgDark, style.bgDeep, style.bgDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: Get.height * .028),
                    _GoldTitle(title: ('VIP Identity').appTr, style: style),
                    SizedBox(height: Get.height * .014),
                    _VipIdentityGrid(level: level, style: style),
                    SizedBox(height: Get.height * .025),
                    if (_vipHasActivePrivilege(level)) ...[
                      _GoldTitle(title: ('Exclusive privileges').appTr, style: style),
                      SizedBox(height: Get.height * .014),
                      _PrivilegeGrid(level: level, style: style),
                    ],
                    if (level.allAssets.isNotEmpty) ...[
                      SizedBox(height: Get.height * .026),
                      _GoldTitle(title: ('VIP Assets').appTr, style: style),
                      SizedBox(height: Get.height * .014),
                      _AssetGrid(level: level, style: style),
                    ],
                    SizedBox(height: Get.height * .026),
                    _GoldTitle(title: ('VIP Packages').appTr, style: style),
                    SizedBox(height: Get.height * .014),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _PackageList(level: level, controller: controller, style: style),
                    ),
                    SizedBox(height: Get.height * .17),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumHeroArea extends StatelessWidget {
  final VipLevel level;
  final SvipController controller;
  final _VipStyle style;
  final bool isCurrent;

  const _PremiumHeroArea({
    required this.level,
    required this.controller,
    required this.style,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * .505,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            style.bgAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [style.bgDeep, style.bgDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(.04),
                  style.bgDeep.withOpacity(.10),
                  style.bgDark.withOpacity(.82),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -Get.height * .03,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: Get.height * .22,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: .72,
                    colors: [
                      style.primary.withOpacity(.45),
                      style.primary.withOpacity(.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: Get.height * .155,
            left: 0,
            right: 0,
            child: _HeroVipPreview(level: level, isCurrent: isCurrent, style: style),
          ),
        ],
      ),
    );
  }
}

class _HeroVipPreview extends StatelessWidget {
  final VipLevel level;
  final bool isCurrent;
  final _VipStyle style;

  const _HeroVipPreview({
    required this.level,
    required this.isCurrent,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final double h = Get.height;
    final double w = Get.width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: h * .01),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: -h * .012,
              child: Container(
                height: h * .034,
                width: w * .58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: RadialGradient(
                    colors: [
                      style.primary.withOpacity(.30),
                      style.secondary.withOpacity(.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Container(
              height: h * .235,
              width: h * .235,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    style.primary.withOpacity(.32),
                    style.secondary.withOpacity(.16),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [BoxShadow(color: style.primary.withOpacity(.22), blurRadius: 55, spreadRadius: 4)],
              ),
            ),
            SizedBox(
              height: h * .215,
              width: h * .215,
              child: _VipStaticPreview(
                url: _vipLevelMainShowImageUrl(level),
                icon: Icons.workspace_premium_rounded,
                style: style,
                fit: BoxFit.contain,
                iconSize: h * .105,
              ),
            ),
            if (isCurrent)
              Positioned(
                top: kHeight*0.21,
                right: -w * .04,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xff209447), Color(0xff126b32)]),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white.withOpacity(.18)),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(.22), blurRadius: 12)],
                  ),
                  child: Text(
                    ('ACTIVE').appTr,
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: h * .0105, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
        Text(
          level.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            color: style.primary,
            fontSize: h * .030,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
            shadows: [Shadow(color: style.secondary.withOpacity(.55), blurRadius: 13)],
          ),
        ),
        SizedBox(height: h * .004),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * .13),
          child: Text(
            level.description.isEmpty ? ('Unlock premium identity and livestream privileges').appTr: level.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              color: Colors.white.withOpacity(.72),
              fontSize: h * .0135,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentVipStrip extends StatelessWidget {
  final SvipController controller;
  final _VipStyle style;
  const _CurrentVipStrip({required this.controller, required this.style});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.currentVip.value;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withOpacity(.28),
          border: Border.all(color: Colors.white.withOpacity(.14)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 12)],
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [style.primary, style.secondary]),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.black87),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current == null ? ('My VIP').appTr: (current.vipLevel?.displayTitle ?? current.vipType.toUpperCase()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.remainingText(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12.2, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (controller.isMyVipLoading.value)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: style.primary))
            else
              IconButton(
                onPressed: () => controller.fetchMyCurrentVip(
                  userId: int.parse(authController.userProfile.value.user!.id.toString()),
                ),
                icon: Icon(Icons.sync_rounded, color: style.primary),
              ),
          ],
        ),
      );
    });
  }
}

class _WaveDivider extends StatelessWidget {
  final _VipStyle style;
  const _WaveDivider({required this.style});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -1),
      child: SizedBox(
        height: Get.height * .044,
        width: double.infinity,
        child: CustomPaint(
          painter: _VipWavePainter(style: style),
        ),
      ),
    );
  }
}

class _VipWavePainter extends CustomPainter {
  final _VipStyle style;
  _VipWavePainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * .46);
    path.quadraticBezierTo(size.width * .50, -size.height * .18, size.width, size.height * .46);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [style.bgDeep, style.bgDark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = style.primary.withOpacity(.38);
    final linePath = Path();
    linePath.moveTo(0, size.height * .46);
    linePath.quadraticBezierTo(size.width * .50, -size.height * .18, size.width, size.height * .46);
    canvas.drawPath(linePath, glow);
  }

  @override
  bool shouldRepaint(covariant _VipWavePainter oldDelegate) => oldDelegate.style != style;
}

class _GoldTitle extends StatelessWidget {
  final String title;
  final _VipStyle style;
  const _GoldTitle({required this.title, required this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('༺༒', style: TextStyle(color: style.primary, fontSize: Get.height * .018)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.roboto(
            color: style.primary,
            fontSize: Get.height * .019,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Text('༒༻', style: TextStyle(color: style.primary, fontSize: Get.height * .018)),
      ],
    );
  }
}

class _VipIdentityGrid extends StatelessWidget {
  final VipLevel level;
  final _VipStyle style;
  const _VipIdentityGrid({required this.level, required this.style});

  @override
  Widget build(BuildContext context) {
    final items = [
      _VipCardItem(
        'VIP Frame',
        _vipFrameShowImageUrl(level),
        Icons.crop_square_rounded,
        mediaUrl: _vipFramePlayUrl(level),
      ),
      _VipCardItem(
        'VIP Title',
        _vipTitleShowImageUrl(level),
        Icons.military_tech_rounded,
        mediaUrl: _vipTitlePlayUrl(level),
      ),
      _VipCardItem(
        'VIP Name',
        _vipNameShowImageUrl(level),
        Icons.text_fields_rounded,
        mediaUrl: _vipNamePlayUrl(level),
      ),
      _VipCardItem(
        'VIP Badge',
        _vipBadgeShowImageUrl(level),
        Icons.verified_rounded,
        mediaUrl: _vipBadgePlayUrl(level),
      ),
      _VipCardItem(
        'Entry Banner',
        _vipEntryBannerShowImageUrl(level),
        Icons.rocket_launch_rounded,
        mediaUrl: _vipEntryBannerPlayUrl(level),
      ),
      _VipCardItem(
        'Profile Card',
        _vipProfileCardShowImageUrl(level),
        Icons.contact_page_rounded,
        mediaUrl: _vipProfileCardPlayUrl(level),
      ),
      _VipCardItem(
        'Chat Bubble',
        _vipChatBubbleShowImageUrl(level),
        Icons.chat_bubble_outline_rounded,
        mediaUrl: _vipChatBubblePlayUrl(level),
      ),
      _VipCardItem('Chat Color', '', Icons.chat_bubble_rounded, colorText: level.chatBubbleColor),
    ];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: .74,
      ),
      itemBuilder: (_, index) => _LuxuryGridCard(
        item: items[index],
        style: style,
        onTap: () => _showVipItemDialog(Get.context!, items[index], style),
      ),
    );
  }
}

class _VipCardItem {
  final String title;
  final String url;
  final String mediaUrl;
  final IconData icon;
  final String? colorText;

  const _VipCardItem(
      this.title,
      this.url,
      this.icon, {
        this.mediaUrl = '',
        this.colorText,
      });

  String get previewUrl => url;
  String get playUrl => mediaUrl.trim().isNotEmpty ? mediaUrl.trim() : url.trim();
}


class _VipStaticPreview extends StatelessWidget {
  final String url;
  final IconData icon;
  final _VipStyle style;
  final Color? color;
  final BoxFit fit;
  final double? iconSize;

  const _VipStaticPreview({
    required this.url,
    required this.icon,
    required this.style,
    this.color,
    this.fit = BoxFit.contain,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final Color displayColor = color ?? style.primary;
    final String staticUrl = _vipStaticPreviewOnly(url);

    if (staticUrl.isEmpty) {
      return Center(
        child: Container(
          width: Get.width * .12,
          height: Get.width * .12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: displayColor.withOpacity(.17),
            border: Border.all(color: displayColor.withOpacity(.80)),
          ),
          child: Icon(icon, color: displayColor, size: iconSize ?? Get.height * .033),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _VipSmartNetworkImage(
        key: ValueKey(staticUrl),
        url: staticUrl,
        fit: fit,
        borderRadius: 14,
        shimmerBaseColor: displayColor.withOpacity(.18),
        shimmerHighlightColor: Colors.white.withOpacity(.24),
        fallback: Center(
          child: Container(
            width: Get.width * .12,
            height: Get.width * .12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: displayColor.withOpacity(.17),
              border: Border.all(color: displayColor.withOpacity(.80)),
            ),
            child: Icon(icon, color: displayColor, size: iconSize ?? Get.height * .033),
          ),
        ),
      ),
    );
  }
}

class _VipSmartNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double borderRadius;
  final Color shimmerBaseColor;
  final Color shimmerHighlightColor;
  final Widget fallback;

  const _VipSmartNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    required this.borderRadius,
    required this.shimmerBaseColor,
    required this.shimmerHighlightColor,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        filterQuality: FilterQuality.high,
        // The package's own cross-fade is disabled here because imageBuilder
        // below reproduces the exact same scale + fade entrance the design
        // already used with Image.network's frameBuilder. Two fades stacked
        // on top of each other would look like a double-flicker.
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        imageBuilder: (context, imageProvider) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Image(
              image: imageProvider,
              fit: fit,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
            builder: (context, value, builtChild) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: value,
                  child: builtChild,
                ),
              );
            },
          );
        },
        progressIndicatorBuilder: (context, url, downloadProgress) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _VipShimmerBox(
                borderRadius: borderRadius,
                baseColor: shimmerBaseColor,
                highlightColor: shimmerHighlightColor,
              ),
              Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(.14),
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    valueColor: AlwaysStoppedAnimation<Color>(shimmerHighlightColor),
                    value: downloadProgress.progress,
                  ),
                ),
              ),
            ],
          );
        },
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}

class _VipShimmerBox extends StatefulWidget {
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const _VipShimmerBox({
    required this.borderRadius,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_VipShimmerBox> createState() => _VipShimmerBoxState();
}

class _VipShimmerBoxState extends State<_VipShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth <= 0 ? Get.width * .2 : constraints.maxWidth;
          final shimmerWidth = width * .48;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = (width + shimmerWidth) * _controller.value - shimmerWidth;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.baseColor,
                    ),
                  ),
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: shimmerWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            widget.highlightColor.withOpacity(.00),
                            widget.highlightColor.withOpacity(.16),
                            widget.highlightColor.withOpacity(.45),
                            widget.highlightColor.withOpacity(.16),
                            widget.highlightColor.withOpacity(.00),
                          ],
                          stops: const [0.0, 0.22, 0.50, 0.78, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LuxuryGridCard extends StatelessWidget {
  final _VipCardItem item;
  final _VipStyle style;
  final VoidCallback? onTap;

  const _LuxuryGridCard({required this.item, required this.style, this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayColor = _parseColor(item.colorText ?? '#FFD76A');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [style.cardTop, style.cardBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: style.primary.withOpacity(.18), width: .7),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.20), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(.05), Colors.black.withOpacity(.04)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: _VipStaticPreview(
                  url: item.previewUrl,
                  icon: item.icon,
                  style: style,
                  color: displayColor,
                  fit: BoxFit.contain,
                  iconSize: Get.height * .028,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [style.bgDeep.withOpacity(.35), Colors.black.withOpacity(.28)]),
                  border: Border(top: BorderSide(color: style.primary.withOpacity(.10))),
                ),
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: style.primary,
                    fontSize: Get.height * .013,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showVipItemDialog(BuildContext context, _VipCardItem item, _VipStyle style) {
  final Color displayColor = _parseColor(item.colorText ?? '#FFD76A');

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: Get.width * .045, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: Get.height * .70),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [style.cardTop, style.cardBottom, style.bgDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: style.primary.withOpacity(.38), width: 1.1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.58), blurRadius: 34, offset: const Offset(0, 18)),
            BoxShadow(color: style.primary.withOpacity(.16), blurRadius: 26),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: .95,
                      colors: [
                        style.primary.withOpacity(.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: style.primary,
                            fontSize: Get.height * .022,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: Get.back,
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          height: 34,
                          width: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(.22),
                            border: Border.all(color: Colors.white.withOpacity(.14)),
                          ),
                          child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(.88), size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      height: Get.height * .38,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.black.withOpacity(.20),
                        border: Border.all(color: style.primary.withOpacity(.20)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: item.playUrl.isEmpty
                            ? Icon(item.icon, key: const ValueKey('vip-dialog-icon'), color: displayColor, size: 88)
                            : VipMediaView(
                          key: ValueKey(item.playUrl),
                          url: item.playUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ('Preview').appTr,
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(.74),
                      fontSize: Get.height * .014,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: Get.back,
                    child: Container(
                      width: Get.width * .50,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        gradient: LinearGradient(colors: [style.primary, style.secondary]),
                        boxShadow: [BoxShadow(color: style.primary.withOpacity(.22), blurRadius: 16)],
                      ),
                      child: Text(
                        ('OK').appTr,
                        style: GoogleFonts.roboto(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    barrierColor: Colors.black.withOpacity(.72),
  );
}

class _PrivilegeGrid extends StatelessWidget {
  final VipLevel level;
  final _VipStyle style;
  const _PrivilegeGrid({required this.level, required this.style});

  @override
  Widget build(BuildContext context) {
    final allItems = <Map<String, dynamic>>[
      {'key': 'anti_comment_mute', 'title': 'Anti-comment Mute', 'icon': Icons.volume_off_rounded},
      {'key': 'anti_kick_ban', 'title': 'Anti-kick Ban', 'icon': Icons.shield_rounded},
      {'key': 'anti_block', 'title': 'Anti-block', 'icon': Icons.block_rounded},
      {'key': 'invisible', 'title': 'Invisible', 'icon': Icons.visibility_off_rounded},
      {'key': 'vip_gift', 'title': 'VIP Gift', 'icon': Icons.card_giftcard_rounded},
      {'key': 'vip_emoji', 'title': 'VIP Emoji', 'icon': Icons.emoji_emotions_rounded},
      {'key': 'gif_profile_pic', 'title': 'GIF Profile', 'icon': Icons.gif_box_rounded},
      {'key': 'vip_set', 'title': 'VIP Set', 'icon': Icons.diamond_rounded},
      {'key': 'entry_banner', 'title': 'Entry Banner', 'icon': Icons.rocket_launch_rounded},
      {'key': 'colorful_chat', 'title': 'Colorful Chat', 'icon': Icons.chat_rounded},
      {'key': 'colorful_profile', 'title': 'Color Profile', 'icon': Icons.palette_rounded},
      {'key': 'vip_badge', 'title': 'VIP Badge', 'icon': Icons.verified_rounded},
    ];

    final items = allItems.where((item) => level.privilegeEnabled(item['key'])).toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: .78,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return _PrivilegeLuxuryCard(
          title: item['title'],
          icon: item['icon'],
          enabled: true,
          style: style,
        );
      },
    );
  }
}

class _PrivilegeLuxuryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final _VipStyle style;

  const _PrivilegeLuxuryCard({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: enabled ? [style.cardTop, style.cardBottom] : [const Color(0xff161616), const Color(0xff0d0d0d)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: enabled ? style.primary.withOpacity(.18) : Colors.white10, width: .7),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Center(
              child: Container(
                height: Get.height * .052,
                width: Get.height * .052,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? style.primary.withOpacity(.14) : Colors.white.withOpacity(.05),
                  border: Border.all(color: enabled ? style.primary.withOpacity(.50) : Colors.white12),
                ),
                child: Icon(icon, color: enabled ? style.primary : Colors.white30, size: Get.height * .028),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.16),
                border: Border(top: BorderSide(color: style.primary.withOpacity(.10))),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  color: enabled ? Colors.white : Colors.white38,
                  fontSize: Get.height * .0125,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetGrid extends StatelessWidget {
  final VipLevel level;
  final _VipStyle style;
  const _AssetGrid({required this.level, required this.style});

  @override
  Widget build(BuildContext context) {
    final assets = level.allAssets;
    return SizedBox(
      height: Get.height * .18,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: assets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final asset = assets[index];
          final item = _VipCardItem(
            _vipAssetName(asset),
            _vipAssetShowImageUrl(asset),
            Icons.auto_awesome_rounded,
            mediaUrl: _vipAssetMediaUrl(asset),
          );

          return SizedBox(
            width: Get.width * .30,
            child: _LuxuryGridCard(
              item: item,
              style: style,
              onTap: () => _showVipItemDialog(
                Get.context!,
                item,
                style,
              ),
            ),
          );
        },
      ),
    );
  }
}

int _vipPkgId(dynamic pkg) {
  if (pkg == null) return 0;
  if (pkg is Map) return int.tryParse('${pkg['id'] ?? 0}') ?? 0;
  try {
    return int.tryParse('${pkg.id}') ?? 0;
  } catch (_) {
    return 0;
  }
}

int _vipPkgDay(dynamic pkg) {
  if (pkg == null) return 0;
  if (pkg is Map) return int.tryParse('${pkg['day'] ?? 0}') ?? 0;
  try {
    return int.tryParse('${pkg.day}') ?? 0;
  } catch (_) {
    return 0;
  }
}

String _vipPkgPriceText(dynamic pkg) {
  if (pkg == null) return '0';
  if (pkg is Map) {
    final value = pkg['price_text'] ?? pkg['priceText'] ?? pkg['price'] ?? 0;
    return value.toString();
  }
  try {
    return pkg.priceText.toString();
  } catch (_) {}
  try {
    return pkg.price.toString();
  } catch (_) {}
  return '0';
}

class _PackageList extends StatelessWidget {
  final VipLevel level;
  final SvipController controller;
  final _VipStyle style;

  const _PackageList({
    required this.level,
    required this.controller,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<dynamic> packages = List<dynamic>.from(controller.packagesForLevel(level.id));

      if (controller.isPackageLoading.value && packages.isEmpty) {
        return Center(child: CircularProgressIndicator(color: style.primary));
      }

      if (packages.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(('No package found for this VIP.').appTr, style: GoogleFonts.roboto(color: Colors.white70)),
        );
      }

      final dynamic selected = controller.selectedPackageForLevel(level.id);
      final int selectedId = _vipPkgId(selected);

      return Row(
        children: packages.map<Widget>((dynamic pkg) {
          final int packageId = _vipPkgId(pkg);
          final int day = _vipPkgDay(pkg);
          final String priceText = _vipPkgPriceText(pkg);
          final bool active = selectedId > 0 && selectedId == packageId;

          return Expanded(
            child: GestureDetector(
              onTap: packageId <= 0
                  ? null
                  : () => controller.selectPackage(vipId: level.id, packageId: packageId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: Get.height * .105,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: active
                      ? LinearGradient(colors: [style.primary, style.secondary])
                      : LinearGradient(colors: [style.cardTop, style.cardBottom]),
                  border: Border.all(
                    color: active ? Colors.white.withOpacity(.55) : style.primary.withOpacity(.18),
                  ),
                  boxShadow: active ? [BoxShadow(color: style.primary.withOpacity(.22), blurRadius: 16)] : [],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Center(
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: active ? Colors.black87 : style.primary,
                          size: Get.height * .034,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: active ? Colors.white.withOpacity(.12) : Colors.black.withOpacity(.18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              ('$day Days').appTr,
                              style: GoogleFonts.roboto(
                                color: active ? Colors.black87 : Colors.white,
                                fontSize: Get.height * .0125,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '💰 $priceText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: active ? Colors.black87 : style.primary,
                                fontSize: Get.height * .0105,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _BottomBuyCard extends StatelessWidget {
  final VipLevel level;
  final SvipController controller;
  final _VipStyle style;

  const _BottomBuyCard({
    required this.level,
    required this.controller,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dynamic pkg = controller.selectedPackageForLevel(level.id);
      final int packageId = _vipPkgId(pkg);
      final int day = _vipPkgDay(pkg);
      final String priceText = _vipPkgPriceText(pkg);
      final bool isCurrent = controller.isCurrentVipLevel(level);

      final dynamic user = authController.userProfile.value.user;
      final double userCoins = _numFromVipValue(user?.coins);
      final double packagePrice = _numFromVipText(priceText);
      final double targetPoints = packagePrice <= 0 ? 1 : packagePrice;
      final double progress = packagePrice <= 0
          ? 1
          : (userCoins / targetPoints).clamp(0.0, 1.0).toDouble();
      final bool hasEnoughCoins =
          packageId > 0 && userCoins >= packagePrice;
      final String profileImageUrl = ImageHelper.getImageUrl(
        user?.profileImage?.toString() ?? '',
      ).trim();
      final String userPointsText = _formatVipNumber(userCoins);
      final String actionText = isCurrent
          ? (hasEnoughCoins ? 'Extend' : 'Recharge')
          : (hasEnoughCoins ? 'Activate' : 'Recharge');

      Future<void> handleAction() async {
        if (controller.isPurchaseLoading.value || packageId <= 0) return;

        if (!hasEnoughCoins) {
          controller.showMessage(
            ('Insufficient coins. Please recharge first.').appTr,
            color: Colors.red,
          );
          return;
        }

        await controller.purchaseSelectedPackage();
      }

      return SafeArea(
        child: Container(
          height: Get.height * .168,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                style.cardTop.withOpacity(.92),
                style.bgDeep.withOpacity(.90),
                style.cardBottom.withOpacity(.94),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: style.primary.withOpacity(.58),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.52),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: style.primary.withOpacity(.18),
                blurRadius: 24,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -Get.width * .05,
                bottom: -Get.height * .055,
                child: Opacity(
                  opacity: .16,
                  child: SizedBox(
                    height: Get.height * .20,
                    width: Get.height * .20,
                    child: _VipStaticPreview(
                      url: _vipLevelMainShowImageUrl(level),
                      icon: Icons.workspace_premium_rounded,
                      style: style,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(.10),
                        Colors.transparent,
                        Colors.black.withOpacity(.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Get.width * .035,
                  vertical: Get.height * .014,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: Get.height * .050,
                                width: Get.height * .050,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      style.primary,
                                      style.secondary,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.55),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: style.primary.withOpacity(.24),
                                      blurRadius: 13,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: profileImageUrl.isEmpty
                                      ? _VipProfileFallback(style: style)
                                      : CachedNetworkImage(
                                    imageUrl: profileImageUrl,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    fadeInDuration: const Duration(milliseconds: 180),
                                    placeholder: (context, url) =>
                                        _VipProfileFallback(
                                          style: style,
                                          loading: true,
                                        ),
                                    errorWidget: (context, url, error) =>
                                        _VipProfileFallback(style: style),
                                  ),
                                ),
                              ),
                              SizedBox(width: Get.width * .025),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCurrent
                                          ? ('${level.displayTitle} Active')
                                          .appTr
                                          : ("You don't have ${level.displayTitle}")
                                          .appTr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontSize: Get.height * .018,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: Get.height * .004),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            day <= 0
                                                ? ('Select package first').appTr
                                                : ('$day days package').appTr,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.roboto(
                                              color: Colors.white.withOpacity(.72),
                                              fontSize: Get.height * .012,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (packageId > 0) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              ('• $priceText coins').appTr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.roboto(
                                                color: style.primary,
                                                fontSize: Get.height * .012,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Get.height * .009),
                          Row(
                            children: [
                              Text(
                                ('This Month points').appTr,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: Get.height * .014,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: Get.width * .015),
                              Container(
                                height: Get.height * .018,
                                width: Get.height * .018,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xffffe36e),
                                      Color(0xffffa800),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: style.primary.withOpacity(.22),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.monetization_on,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  userPointsText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: Get.height * .016,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Get.height * .003),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: LinearProgressIndicator(
                                    minHeight: 5,
                                    value: progress,
                                    color: hasEnoughCoins
                                        ? const Color(0xff49d273)
                                        : style.primary,
                                    backgroundColor:
                                    Colors.white.withOpacity(.28),
                                  ),
                                ),
                              ),
                              SizedBox(width: Get.width * .025),
                              SizedBox(
                                height: Get.height * .030,
                                width: Get.width * .17,
                                child: _VipStaticPreview(
                                  url: _vipBadgeShowImageUrl(level).isEmpty
                                      ? _vipLevelMainShowImageUrl(level)
                                      : _vipBadgeShowImageUrl(level),
                                  icon: Icons.verified_rounded,
                                  style: style,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Get.height * .006),
                          Row(
                            children: [
                              Text(
                                ('$userPointsText points').appTr,
                                style: GoogleFonts.roboto(
                                  color: Colors.white.withOpacity(.76),
                                  fontSize: Get.height * .012,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                packageId <= 0
                                    ? level.displayTitle
                                    : ('$priceText points').appTr,
                                style: GoogleFonts.roboto(
                                  color: Colors.white.withOpacity(.76),
                                  fontSize: Get.height * .012,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: Get.width * .030),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: controller.fetchMyVipHistory,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ('Record').appTr,
                                  style: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(.78),
                                    fontSize: Get.height * .016,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withOpacity(.78),
                                  size: Get.height * .022,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: controller.isPurchaseLoading.value ||
                              packageId <= 0
                              ? null
                              : handleAction,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: Get.height * .050,
                            padding: EdgeInsets.symmetric(
                              horizontal: Get.width * .043,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              gradient: hasEnoughCoins
                                  ? const LinearGradient(
                                colors: [
                                  Color(0xff55e985),
                                  Color(0xffc7ffd8),
                                  Color(0xff2fbd63),
                                ],
                              )
                                  : LinearGradient(
                                colors: [
                                  style.primary,
                                  const Color(0xfffff2bd),
                                  style.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (hasEnoughCoins
                                      ? const Color(0xff49d273)
                                      : style.primary)
                                      .withOpacity(.32),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: controller.isPurchaseLoading.value
                                ? SizedBox(
                              width: Get.height * .018,
                              height: Get.height * .018,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black87,
                              ),
                            )
                                : Text(
                              actionText.appTr,
                              style: GoogleFonts.roboto(
                                color: const Color(0xff22320f),
                                fontSize: Get.height * .017,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _VipProfileFallback extends StatelessWidget {
  final _VipStyle style;
  final bool loading;

  const _VipProfileFallback({
    required this.style,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            style.cardTop,
            style.cardBottom,
          ],
        ),
      ),
      child: loading
          ? SizedBox(
        width: Get.height * .017,
        height: Get.height * .017,
        child: CircularProgressIndicator(
          strokeWidth: 1.7,
          color: style.primary,
        ),
      )
          : Icon(
        Icons.person_rounded,
        color: style.primary,
        size: Get.height * .028,
      ),
    );
  }
}

double _numFromVipText(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.trim().isEmpty) return 0;
  return double.tryParse(cleaned) ?? 0;
}


double _numFromVipValue(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final cleaned = value.toString().replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 0;
}

String _formatVipNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '');
}

class _VipLoadingPage extends StatelessWidget {
  const _VipLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff080402),
      child: const Center(child: CircularProgressIndicator(color: Color(0xffffdc72))),
    );
  }
}

class _VipEmptyPage extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _VipEmptyPage({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff080402),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_outlined, color: Color(0xffffdc72), size: 64),
              const SizedBox(height: 14),
              Text(
                ('No VIP data found').appTr,
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                ('Please check VIP API and try again.').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onRefresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffffdc72),
                  foregroundColor: Colors.black87,
                ),
                child:  Text(('Retry').appTr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


bool _vipHasActivePrivilege(VipLevel level) {
  const keys = [
    'anti_comment_mute',
    'anti_kick_ban',
    'anti_block',
    'invisible',
    'vip_gift',
    'vip_emoji',
    'gif_profile_pic',
    'vip_set',
    'entry_banner',
    'colorful_chat',
    'colorful_profile',
    'vip_badge',
  ];

  for (final key in keys) {
    if (level.privilegeEnabled(key)) return true;
  }

  return false;
}

bool _vipIsSvgaUrl(String value) {
  final clean = value.trim().toLowerCase().split('?').first;
  return clean.endsWith('.svga');
}

String _vipStaticPreviewOnly(String value) {
  final clean = _cleanVipUrl(value);
  if (clean.isEmpty) return '';
  if (_vipIsSvgaUrl(clean)) return '';
  return clean;
}

String _vipFirstStatic(List<String> values) {
  for (final value in values) {
    final clean = _vipStaticPreviewOnly(value);
    if (clean.isNotEmpty) return clean;
  }
  return '';
}

String _vipBadgeHeroImageUrl(VipLevel level) {
  final badgeOriginal = _vipStaticPreviewOnly(_vipBadgePlayUrl(level));
  if (badgeOriginal.isNotEmpty) return badgeOriginal;
  return _vipBadgeShowImageUrl(level);
}

String _vipLevelMainShowImageUrl(VipLevel level) {
  return _vipFirstStatic([
    _vipBadgeHeroImageUrl(level),
    _vipProfileCardShowImageUrl(level),
    _vipFrameShowImageUrl(level),
    _vipTitleShowImageUrl(level),
    _vipEntryBannerShowImageUrl(level),
  ]);
}

String _cleanVipUrl(String value) {
  final v = value.trim();
  if (v.isEmpty || v.toLowerCase() == 'null') return '';
  return v;
}

String _vipStringFromMap(Map data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final clean = _cleanVipUrl(value.toString());
    if (clean.isNotEmpty) return clean;
  }
  return '';
}


String _vipFirstClean(List<String> values) {
  for (final value in values) {
    final clean = _cleanVipUrl(value);
    if (clean.isNotEmpty) return clean;
  }
  return '';
}

String _vipDynamicString(dynamic item, List<String> getterNames) {
  // Dart dynamic property cannot be accessed by string. These try blocks keep this
  // view compatible with both old and new VipLevel/VipAsset models.
  for (final name in getterNames) {
    try {
      if (name == 'frameUrl') {
        final v = _cleanVipUrl(item.frameUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'frame') {
        final v = _cleanVipUrl(item.frame?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'badgeImageUrl') {
        final v = _cleanVipUrl(item.badgeImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'badgeImage') {
        final v = _cleanVipUrl(item.badgeImage?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'titleImageUrl') {
        final v = _cleanVipUrl(item.titleImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'titleImage') {
        final v = _cleanVipUrl(item.titleImage?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'entryBannerImageUrl') {
        final v = _cleanVipUrl(item.entryBannerImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'entryBannerImage') {
        final v = _cleanVipUrl(item.entryBannerImage?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'profileCardImageUrl') {
        final v = _cleanVipUrl(item.profileCardImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'profileCardImage') {
        final v = _cleanVipUrl(item.profileCardImage?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'frameShowImageUrl') {
        final v = _cleanVipUrl(item.frameShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'badgeImageShowImageUrl') {
        final v = _cleanVipUrl(item.badgeImageShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'titleImageShowImageUrl') {
        final v = _cleanVipUrl(item.titleImageShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'entryBannerImageShowImageUrl') {
        final v = _cleanVipUrl(item.entryBannerImageShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'profileCardImageShowImageUrl') {
        final v = _cleanVipUrl(item.profileCardImageShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'nameImageUrl') {
        final v = _cleanVipUrl(item.nameImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'nameImageShowImageUrl') {
        final v = _cleanVipUrl(item.nameImageShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'chatBubbleImageUrl') {
        final v = _cleanVipUrl(item.chatBubbleImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      } else if (name == 'chatBubbleImageShowImageUrl') {
        final v = _cleanVipUrl(item.chatBubbleImageShowImageUrl?.toString() ?? '');
        if (v.isNotEmpty) return v;
      }
    } catch (_) {}
  }
  return '';
}


Map? _vipRawMap(dynamic source) {
  if (source is Map) return source;

  try {
    final raw = source.raw;
    if (raw is Map) return raw;
  } catch (_) {}

  try {
    final raw = source.data;
    if (raw is Map) return raw;
  } catch (_) {}

  try {
    final raw = source.json;
    if (raw is Map) return raw;
  } catch (_) {}

  try {
    final raw = source.toJson();
    if (raw is Map) return raw;
  } catch (_) {}

  return null;
}


String _vipRawOrModelUrl(
    VipLevel level, {
      required List<String> rawKeys,
      required List<String> modelGetters,
    }) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, modelGetters);
  if (modelValue.isNotEmpty) return modelValue;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final rawValue = _vipStringFromMap(raw, rawKeys);
    if (rawValue.isNotEmpty) return rawValue;
  }

  return '';
}

String _vipFramePlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['frame_url', 'frameUrl', 'frame'],
    modelGetters: ['frameUrl', 'frame'],
  );
}

String _vipBadgePlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['badge_image_url', 'badgeImageUrl', 'badge_image', 'badgeImage'],
    modelGetters: ['badgeImageUrl', 'badgeImage'],
  );
}

String _vipTitlePlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['title_image_url', 'titleImageUrl', 'title_image', 'titleImage'],
    modelGetters: ['titleImageUrl', 'titleImage'],
  );
}

String _vipEntryBannerPlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['entry_banner_image_url', 'entryBannerImageUrl', 'entry_banner_image', 'entryBannerImage'],
    modelGetters: ['entryBannerImageUrl', 'entryBannerImage'],
  );
}

String _vipProfileCardPlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['profile_card_image_url', 'profileCardImageUrl', 'profile_card_image', 'profileCardImage'],
    modelGetters: ['profileCardImageUrl', 'profileCardImage'],
  );
}

String _vipNamePlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['name_image_url', 'nameImageUrl', 'name_image', 'nameImage'],
    modelGetters: ['nameImageUrl', 'nameImage'],
  );
}

String _vipChatBubblePlayUrl(VipLevel level) {
  return _vipRawOrModelUrl(
    level,
    rawKeys: ['chat_bubble_image_url', 'chatBubbleImageUrl', 'chat_bubble_image', 'chatBubbleImage'],
    modelGetters: ['chatBubbleImageUrl', 'chatBubbleImage'],
  );
}

String _vipFrameShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['frameShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['frame_show_image_url', 'frameShowImageUrl', 'frame_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipFramePlayUrl(level));
}

String _vipBadgeShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['badgeImageShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['badge_image_show_image_url', 'badgeImageShowImageUrl', 'badge_image_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipBadgePlayUrl(level));
}

String _vipTitleShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['titleImageShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['title_image_show_image_url', 'titleImageShowImageUrl', 'title_image_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipTitlePlayUrl(level));
}

String _vipEntryBannerShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['entryBannerImageShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['entry_banner_image_show_image_url', 'entryBannerImageShowImageUrl', 'entry_banner_image_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipEntryBannerPlayUrl(level));
}

String _vipProfileCardShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['profileCardImageShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['profile_card_image_show_image_url', 'profileCardImageShowImageUrl', 'profile_card_image_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipProfileCardPlayUrl(level));
}

String _vipNameShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['nameImageShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['name_image_show_image_url', 'nameImageShowImageUrl', 'name_image_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipNamePlayUrl(level));
}

String _vipChatBubbleShowImageUrl(VipLevel level) {
  final dynamic item = level;

  final modelValue = _vipDynamicString(item, ['chatBubbleImageShowImageUrl']);
  final modelStatic = _vipStaticPreviewOnly(modelValue);
  if (modelStatic.isNotEmpty) return modelStatic;

  final raw = _vipRawMap(item);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['chat_bubble_image_show_image_url', 'chatBubbleImageShowImageUrl', 'chat_bubble_image_show_image']);
    final staticValue = _vipStaticPreviewOnly(v);
    if (staticValue.isNotEmpty) return staticValue;
  }

  return _vipStaticPreviewOnly(_vipChatBubblePlayUrl(level));
}

String _vipAssetName(dynamic asset) {
  try {
    final v = asset.name?.toString() ?? '';
    if (v.trim().isNotEmpty) return v.trim();
  } catch (_) {}

  final raw = _vipRawMap(asset);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['name', 'title']);
    if (v.isNotEmpty) return v;
  }

  return 'VIP Asset';
}

String _vipAssetMediaUrl(dynamic asset) {
  try {
    final v = _cleanVipUrl(asset.assetUrl?.toString() ?? '');
    if (v.isNotEmpty) return v;
  } catch (_) {}

  try {
    final v = _cleanVipUrl(asset.asset_url?.toString() ?? '');
    if (v.isNotEmpty) return v;
  } catch (_) {}

  final raw = _vipRawMap(asset);
  if (raw != null) {
    final v = _vipStringFromMap(raw, ['asset_url', 'assetUrl', 'asset']);
    if (v.isNotEmpty) return v;
  }

  try {
    return _cleanVipUrl(asset.previewUrl?.toString() ?? '');
  } catch (_) {}

  return '';
}

String _vipAssetShowImageUrl(dynamic asset) {
  String assetMedia = '';

  try {
    final v = _cleanVipUrl(asset.showImageUrl?.toString() ?? '');
    if (_vipStaticPreviewOnly(v).isNotEmpty) return _vipStaticPreviewOnly(v);
  } catch (_) {}

  try {
    final v = _cleanVipUrl(asset.show_image_url?.toString() ?? '');
    if (_vipStaticPreviewOnly(v).isNotEmpty) return _vipStaticPreviewOnly(v);
  } catch (_) {}

  final raw = _vipRawMap(asset);
  if (raw != null) {
    assetMedia = _vipStringFromMap(raw, ['asset_url', 'assetUrl', 'asset']);
    final v = _vipStringFromMap(raw, ['show_image_url', 'showImageUrl', 'show_image']);
    final staticShow = _vipStaticPreviewOnly(v);
    if (staticShow.isNotEmpty) return staticShow;
  }

  if (assetMedia.isEmpty) {
    assetMedia = _vipAssetMediaUrl(asset);
  }

  final staticMedia = _vipStaticPreviewOnly(assetMedia);
  if (staticMedia.isNotEmpty) return staticMedia;

  try {
    final v = _cleanVipUrl(asset.previewUrl?.toString() ?? '');
    final staticPreview = _vipStaticPreviewOnly(v);
    if (staticPreview.isNotEmpty) return staticPreview;
  } catch (_) {}

  return '';
}


Color _parseColor(String value) {
  var hex = value.trim().replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.tryParse(hex, radix: 16) ?? 0xffffd76a);
}