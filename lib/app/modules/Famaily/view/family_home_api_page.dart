import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Controller/FamilyConroller.dart';
import '../Models/family_models.dart';
import '../Widgets/family_common_widgets.dart';
import '../Widgets/family_shimmer.dart';
import 'family_ranking_api_page.dart';
import 'family_requests_api_page.dart';
import 'find_family_api_page.dart';
import 'my_family_api_page.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class FamilyHomeApiPage extends StatefulWidget {
  const FamilyHomeApiPage({super.key});

  @override
  State<FamilyHomeApiPage> createState() => _FamilyHomeApiPageState();
}

class _FamilyHomeApiPageState extends State<FamilyHomeApiPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FamilyController controller = Get.put(Familyconroller(), permanent: true);

  late final AnimationController _bgController;

  static const Color _primary = Color(0xFF190522);
  static const Color _secondary = Color(0xFF3B072F);
  static const Color _accent = Color(0xFFFF3D8B);
  static const Color _gold1 = Color(0xFFFFC400);
  static const Color _gold2 = Color(0xFFFFF238);
  static const Color _pageBg = Color(0xFFFFFBFE);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF211625);
  static const Color _muted = Color(0xFF827484);

  double _s(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390.0).clamp(0.86, 1.18);
    return value * scale;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Starts an immediate foreground sync, then keeps the visible page fresh.
    // The controller deduplicates overlapping API calls automatically.
    controller.startRealtime(forceImmediate: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.resumeRealtime();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      controller.pauseRealtime();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgController.dispose();
    controller.stopRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          _animatedBackground(context),
          Obx(() {
            if (controller.homeStatus.value == FamilyPageStatus.loading) {
              return const SafeArea(child: FamilyHomeShimmer());
            }

            if (controller.homeStatus.value == FamilyPageStatus.error) {
              return _errorView(
                context,
                controller.errorMessage.value,
                controller.loadHome,
              );
            }

            final family = controller.myFamily.value;
            if (family == null) return _noFamilyView(context);

            return RefreshIndicator(
              color: _accent,
              backgroundColor: Colors.white,
              onRefresh: controller.refreshAll,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: _s(context, 28)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _animatedIn(
                      delay: 0,
                      child: _coverHero(context, family),
                    ),
                    SizedBox(height: _s(context, 2)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _s(context, 14)),
                      child: Column(
                        children: [
                          _animatedIn(
                            delay: 80,
                            child: _announcement(context, family),
                          ),
                          SizedBox(height: _s(context, 14)),
                          _animatedIn(
                            delay: 150,
                            child: _menu(context, family),
                          ),
                          SizedBox(height: _s(context, 14)),
                          _animatedIn(
                            delay: 220,
                            child: _contributors(context, family),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _animatedBackground(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final value = _bgController.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF6FC),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FamilyHomePatternPainter(
                    primary: _secondary,
                    accent: _accent,
                    progress: value,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -_s(context, 76) + (value * 22),
              right: -_s(context, 82),
              child: _softCircle(_s(context, 220), _accent.withOpacity(.12)),
            ),
            Positioned(
              top: _s(context, 310) - (value * 26),
              left: -_s(context, 120),
              child: _softCircle(_s(context, 235), _secondary.withOpacity(.08)),
            ),
            Positioned(
              bottom: -_s(context, 88),
              right: _s(context, 28) + (value * 20),
              child: _softCircle(_s(context, 185), _gold1.withOpacity(.08)),
            ),
          ],
        );
      },
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _animatedIn({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 430 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, widgetChild) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: widgetChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget _coverHero(BuildContext context, FamilyModel family) {
    final screenHeight = MediaQuery.of(context).size.height;
    final coverHeight = (screenHeight * 0.50).clamp(
      _s(context, 330),
      _s(context, 440),
    );

    return InkWell(
      onTap: () => Get.to(() => const MyFamilyApiPage()),
      child: SizedBox(
        height: coverHeight + _s(context, 48),
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: coverHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (family.coverUrl.isNotEmpty)
                    Image.network(
                      family.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const CustomPaint(
                        painter: FamilyPurpleHeaderPainter(),
                      ),
                    )
                  else
                    const CustomPaint(painter: FamilyPurpleHeaderPainter()),

                  /// Image ta top side e clear thakbe, bottom side page color er
                  /// sathe smooth vabe mix/blend hobe.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(.12),
                          _primary.withOpacity(.05),
                          _secondary.withOpacity(.28),
                          _pageBg.withOpacity(.98),
                        ],
                        stops: const [0.0, .36, .72, 1.0],
                      ),
                    ),
                  ),

                  /// side glow and premium rings
                  AnimatedBuilder(
                    animation: _bgController,
                    builder: (context, child) {
                      final v = _bgController.value;
                      return Stack(
                        children: [
                          Positioned(
                            right: -_s(context, 58) + (v * 12),
                            top: _s(context, 86),
                            child: _heroGlow(_s(context, 160), _accent.withOpacity(.16)),
                          ),
                          Positioned(
                            left: -_s(context, 70),
                            bottom: _s(context, 42) + (v * 10),
                            child: _heroGlow(_s(context, 178), _primary.withOpacity(.16)),
                          ),
                          Positioned(
                            right: _s(context, 18),
                            bottom: _s(context, 86),
                            child: _premiumRing(context, _s(context, 120)),
                          ),
                        ],
                      );
                    },
                  ),

                  /// Floating top controls - appbar er moto upore thakbe.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          _s(context, 14),
                          _s(context, 6),
                          _s(context, 14),
                          0,
                        ),
                        child: Row(
                          children: [
                            _floatingIconButton(
                              context,
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: Get.back,
                            ),
                            const Spacer(),
                            _floatingIconButton(
                              context,
                              icon: Icons.search_rounded,
                              onTap: () => Get.to(() => const FindFamilyApiPage()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: _s(context, 20),
                    right: _s(context, 20),
                    top: coverHeight * .30,
                    child: _familyIdentity(context, family),
                  ),
                ],
              ),
            ),
            Positioned(
              left: _s(context, 14),
              right: _s(context, 14),
              bottom: _s(context, 8),
              child: _stats(context, family),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _floatingIconButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_s(context, 16)),
      child: Container(
        width: _s(context, 42),
        height: _s(context, 42),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.22),
          borderRadius: BorderRadius.circular(_s(context, 16)),
          border: Border.all(color: Colors.white.withOpacity(.42)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: _s(context, 19)),
      ),
    );
  }

  Widget _familyIdentity(BuildContext context, FamilyModel family) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(_s(context, 5)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_gold1, _accent, _secondary]),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(.32),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(_s(context, 3)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.92),
            ),
            child: FamilyNetworkImage(
              url: family.logoUrl,
              size: _s(context, 86),
              radius: 43,
            ),
          ),
        ),
        SizedBox(height: _s(context, 13)),
        Text(
          family.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _s(context, 24),
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: .3,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(.38),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        SizedBox(height: _s(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _heroBadge(
              context,
              icon: Icons.workspace_premium_rounded,
              text: ('Lv.${family.levelNo}').appTr,
              isGold: true,
            ),
            SizedBox(width: _s(context, 8)),
            _heroBadge(
              context,
              icon: Icons.tag_rounded,
              text: ('ID ${family.familyCode}').appTr,
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroBadge(
      BuildContext context, {
        required IconData icon,
        required String text,
        bool isGold = false,
      }) {
    return Container(
      constraints: BoxConstraints(maxWidth: _s(context, 150)),
      padding: EdgeInsets.symmetric(
        horizontal: _s(context, 11),
        vertical: _s(context, 7),
      ),
      decoration: BoxDecoration(
        gradient: isGold ? const LinearGradient(colors: [_gold1, _gold2]) : null,
        color: isGold ? null : Colors.white.withOpacity(.20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isGold ? Colors.white.withOpacity(.55) : Colors.white.withOpacity(.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isGold ? _textDark : Colors.white, size: _s(context, 14)),
          SizedBox(width: _s(context, 5)),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _s(context, 11.6),
                fontWeight: FontWeight.w900,
                color: isGold ? _textDark : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumRing(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(.10),
          width: _s(context, 16),
        ),
      ),
    );
  }

  Widget _stats(BuildContext context, FamilyModel family) {
    return Container(
      padding: EdgeInsets.all(_s(context, 8)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(_s(context, 24)),
        border: Border.all(color: Colors.white.withOpacity(.88)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.14),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          _stat(context, FamilyUi.compact(family.points), ('Points').appTr, Icons.star_rounded),
          _stat(context, family.memberText, ('Members').appTr, Icons.groups_rounded),
          _stat(context, FamilyUi.compact(family.coins), ('Coins').appTr, Icons.monetization_on_rounded),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String title, IconData icon) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _s(context, 3)),
        padding: EdgeInsets.symmetric(vertical: _s(context, 11)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4FB), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(_s(context, 18)),
          border: Border.all(color: const Color(0xFFF3E3F4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _accent, size: _s(context, 19)),
            SizedBox(height: _s(context, 5)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _s(context, 14.5),
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            SizedBox(height: _s(context, 3)),
            Text(
              title,
              style: TextStyle(
                fontSize: _s(context, 10.8),
                color: _muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Widget child,
        Widget? trailing,
      }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_s(context, 14)),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(.94),
        borderRadius: BorderRadius.circular(_s(context, 24)),
        border: Border.all(color: Colors.white.withOpacity(.88)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _s(context, 36),
                height: _s(context, 36),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
                  borderRadius: BorderRadius.circular(_s(context, 14)),
                ),
                child: Icon(icon, color: Colors.white, size: _s(context, 19)),
              ),
              SizedBox(width: _s(context, 10)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: _s(context, 15.2),
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: _s(context, 13)),
          child,
        ],
      ),
    );
  }

  Widget _announcement(BuildContext context, FamilyModel family) {
    final msg = controller.announcements.isNotEmpty
        ? controller.announcements.first.message
        : (family.notice.isEmpty
        ? 'Welcome to our family. Be active and enjoy!'
        : family.notice);

    return _premiumCard(
      context,
      title: ('Announcement').appTr,
      icon: Icons.campaign_rounded,
      trailing: Text(
        ('View All').appTr,
        style: TextStyle(
          fontSize: _s(context, 11.5),
          color: _accent,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(_s(context, 12)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFFF2FA), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(_s(context, 16)),
          border: Border.all(color: const Color(0xFFF3E1F4)),
        ),
        child: Text(
          msg,
          style: TextStyle(
            fontSize: _s(context, 12.8),
            color: _muted,
            fontWeight: FontWeight.w700,
            height: 1.38,
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, FamilyModel family) {
    final items = <_FamilyMenuItem>[
      _FamilyMenuItem(
        ('Members').appTr,
        Icons.group_rounded,
        const [Color(0xFF7C3AED), Color(0xFF3B0764)],
            () => Get.to(() => const MyFamilyApiPage()),
      ),
      _FamilyMenuItem(
        ('Ranking').appTr,
        Icons.emoji_events_rounded,
        const [Color(0xFFFFC400), Color(0xFFFF7A00)],
            () => Get.to(() => const FamilyRankingApiPage()),
      ),
      _FamilyMenuItem(
        ('Request').appTr,
        Icons.assignment_rounded,
        const [Color(0xFFFF3D8B), Color(0xFFBE185D)],
            () {
          if (controller.canManageRequests) {
            Get.to(() => const FamilyRequestsApiPage());
          } else {

          }
        },
      ),
    ];

    return _premiumCard(
      context,
      title: ('Family Menu').appTr,
      icon: Icons.grid_view_rounded,
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : _s(context, 10),
              ),
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(_s(context, 18)),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: _s(context, 13)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8FD),
                    borderRadius: BorderRadius.circular(_s(context, 18)),
                    border: Border.all(color: const Color(0xFFF2E2F3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: _s(context, 46),
                        height: _s(context, 46),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: item.colors),
                          borderRadius: BorderRadius.circular(_s(context, 17)),
                          boxShadow: [
                            BoxShadow(
                              color: item.colors.last.withOpacity(.20),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(item.icon, size: _s(context, 23), color: Colors.white),
                      ),
                      SizedBox(height: _s(context, 8)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: _s(context, 11.2),
                            color: _textDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _contributors(BuildContext context, FamilyModel family) {
    final list = family.topContributors.isNotEmpty
        ? family.topContributors
        : family.members.take(5).toList();

    return _premiumCard(
      context,
      title: ("Today's Contribution").appTr,
      icon: Icons.leaderboard_rounded,
      child: list.isEmpty
          ? Padding(
        padding: EdgeInsets.symmetric(vertical: _s(context, 10)),
        child: Text(
          ('No contribution found').appTr,
          style: TextStyle(
            fontSize: _s(context, 13),
            color: _muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      )
          : Column(
        children: List.generate(list.length, (i) {
          final item = list[i];
          final bool top = i < 3;
          return Container(
            margin: EdgeInsets.only(bottom: _s(context, 10)),
            padding: EdgeInsets.all(_s(context, 10)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: top
                    ? const [Color(0xFFFFF2FA), Color(0xFFFFFFFF)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFFF8FD)],
              ),
              borderRadius: BorderRadius.circular(_s(context, 16)),
              border: Border.all(color: const Color(0xFFF2E2F3)),
            ),
            child: Row(
              children: [
                Container(
                  width: _s(context, 27),
                  height: _s(context, 27),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: top
                        ? const LinearGradient(colors: [_gold1, _gold2])
                        : LinearGradient(
                      colors: [
                        _secondary.withOpacity(.08),
                        _accent.withOpacity(.08),
                      ],
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: _s(context, 12),
                      fontWeight: FontWeight.w900,
                      color: top ? _textDark : _secondary,
                    ),
                  ),
                ),
                SizedBox(width: _s(context, 9)),
                FamilyNetworkImage(
                  url: item.avatarUrl,
                  size: _s(context, 34),
                  radius: 17,
                  placeholderIcon: Icons.person,
                ),
                SizedBox(width: _s(context, 10)),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _s(context, 13.2),
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _s(context, 9),
                    vertical: _s(context, 6),
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(.09),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        FamilyUi.compact(item.coins),
                        style: TextStyle(
                          fontSize: _s(context, 12.2),
                          fontWeight: FontWeight.w900,
                          color: _secondary,
                        ),
                      ),
                      SizedBox(width: _s(context, 4)),
                      Icon(
                        Icons.monetization_on_rounded,
                        size: _s(context, 16),
                        color: _gold1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _noFamilyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_s(context, 20)),
        child: _animatedIn(
          delay: 0,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(_s(context, 22)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.94),
              borderRadius: BorderRadius.circular(_s(context, 28)),
              border: Border.all(color: Colors.white.withOpacity(.88)),
              boxShadow: [
                BoxShadow(
                  color: _secondary.withOpacity(.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _s(context, 92),
                  height: _s(context, 92),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(.22),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.groups_2_rounded,
                    size: _s(context, 46),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: _s(context, 16)),
                Text(
                  ('No Family Yet').appTr,
                  style: TextStyle(
                    fontSize: _s(context, 22),
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                SizedBox(height: _s(context, 8)),
                Text(
                  ('Create a family or join an existing family to start collecting points together.').appTr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    fontSize: _s(context, 13),
                  ),
                ),
                SizedBox(height: _s(context, 20)),
                InkWell(
                  onTap: () => Get.to(() => const FindFamilyApiPage()),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: _s(context, 54),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      ('Find Family').appTr,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: _s(context, 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(
      BuildContext context,
      String error,
      Future<void> Function() retry,
      ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_s(context, 20)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(_s(context, 20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_s(context, 24)),
            boxShadow: [
              BoxShadow(
                color: _secondary.withOpacity(.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: _accent, size: _s(context, 48)),
              SizedBox(height: _s(context, 12)),
              Text(
                error.isEmpty ? ('Failed to load family').appTr: error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  fontSize: _s(context, 13.5),
                ),
              ),
              SizedBox(height: _s(context, 14)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_s(context, 14)),
                  ),
                ),
                onPressed: retry,
                child:  Text(('Try Again').appTr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyMenuItem {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _FamilyMenuItem(this.title, this.icon, this.colors, this.onTap);
}

class _FamilyHomePatternPainter extends CustomPainter {
  final Color primary;
  final Color accent;
  final double progress;

  const _FamilyHomePatternPainter({
    required this.primary,
    required this.accent,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = primary.withOpacity(.030)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = accent.withOpacity(.042)
      ..style = PaintingStyle.fill;

    final shift = progress * 14;

    for (double y = 110 + shift; y < size.height + 90; y += 118) {
      final row = (y / 118).floor();
      for (double x = -36; x < size.width + 90; x += 126) {
        final dx = row.isEven ? x : x + 62;
        _drawFamilyMark(canvas, Offset(dx, y), linePaint);
        canvas.drawCircle(Offset(dx + 78, y + 22), 2.7, dotPaint);
        canvas.drawCircle(Offset(dx + 96, y + 64), 2.0, dotPaint);
      }
    }

    final wavePaint = Paint()
      ..color = accent.withOpacity(.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final wave = Path()
      ..moveTo(0, size.height * .56)
      ..quadraticBezierTo(
        size.width * .24,
        size.height * .48,
        size.width * .50,
        size.height * .56,
      )
      ..quadraticBezierTo(
        size.width * .74,
        size.height * .64,
        size.width,
        size.height * .52,
      );

    canvas.drawPath(wave, wavePaint);
  }

  void _drawFamilyMark(Canvas canvas, Offset origin, Paint paint) {
    final center = origin + const Offset(32, 22);

    canvas.drawCircle(center, 8.4, paint);
    canvas.drawCircle(origin + const Offset(16, 27), 6.5, paint);
    canvas.drawCircle(origin + const Offset(49, 27), 6.5, paint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin + const Offset(32, 48),
          width: 34,
          height: 27,
        ),
        const Radius.circular(16),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin + const Offset(13, 50),
          width: 24,
          height: 21,
        ),
        const Radius.circular(14),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin + const Offset(52, 50),
          width: 24,
          height: 21,
        ),
        const Radius.circular(14),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FamilyHomePatternPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.accent != accent ||
        oldDelegate.progress != progress;
  }
}
