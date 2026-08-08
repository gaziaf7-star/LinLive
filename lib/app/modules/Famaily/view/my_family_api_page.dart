import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Controller/FamilyConroller.dart';
import '../Models/family_models.dart';
import '../Widgets/family_common_widgets.dart';
import '../Widgets/family_shimmer.dart';
import 'edit_family_api_page.dart';
import 'family_requests_api_page.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MyFamilyApiPage extends StatefulWidget {
  final int? familyId;
  final bool readOnly;

  const MyFamilyApiPage({
    super.key,
    this.familyId,
    this.readOnly = false,
  });

  @override
  State<MyFamilyApiPage> createState() => _MyFamilyApiPageState();
}

class _MyFamilyApiPageState extends State<MyFamilyApiPage>
    with TickerProviderStateMixin {
  final FamilyController controller = Get.put(Familyconroller(), permanent: true);
  late final TabController tabController;
  late final AnimationController _bgController;

  bool _logsLoaded = false;

  bool get _isDetailMode => widget.familyId != null && widget.familyId! > 0;

  static const Color _primary = Color(0xFF190522);
  static const Color _secondary = Color(0xFF3B072F);
  static const Color _accent = Color(0xFFFF3D8B);
  static const Color _gold1 = Color(0xFFFFC400);
  static const Color _gold2 = Color(0xFFFFF238);
  static const Color _pageBg = Color(0xFFFFF7FD);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF211625);
  static const Color _muted = Color(0xFF827484);

  double _r(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390.0).clamp(0.86, 1.18);
    return value * scale;
  }

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 3, vsync: this);
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isDetailMode) {
        controller.selectedFamily.value = null;
        controller.loadFamilyDetail(widget.familyId!);
      } else {
        controller.loadHome(silent: controller.myFamily.value != null);
      }
    });

    tabController.addListener(() {
      if (!mounted) return;
      if (!tabController.indexIsChanging && tabController.index == 2) {
        _loadCoinLogsOnce();
      }
    });
  }

  void _loadCoinLogsOnce() {
    if (_logsLoaded) return;
    _logsLoaded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.loadCoinLogs();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          _animatedBackground(context),
          SafeArea(
            child: Obx(() {
              final status = _isDetailMode
                  ? controller.detailStatus.value
                  : controller.homeStatus.value;
              final family = _isDetailMode
                  ? controller.selectedFamily.value
                  : controller.myFamily.value;

              if (status == FamilyPageStatus.loading && family == null) {
                return const FamilyHomeShimmer();
              }

              if (family == null) {
                return _noFamilyFound(context);
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    color: _accent,
                    onRefresh: () => _isDetailMode
                        ? controller.loadFamilyDetail(widget.familyId!)
                        : controller.loadHome(),
                    child: SingleChildScrollView(

                      padding: EdgeInsets.only(bottom: _r(context, 102)),
                      child: Column(
                        children: [
                          _header(context, family),
                          Transform.translate(
                            offset: Offset(0, -_r(context, 12)),
                            child: Column(
                              children: [
                                _tabs(context),
                                SizedBox(
                                  height: _r(context, 430),
                                  child: TabBarView(
                                    controller: tabController,
                                    physics: const BouncingScrollPhysics(),
                                    children: [
                                      _memberList(context, family),
                                      _requestHint(context, family),
                                      _logList(context),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.readOnly) _bottomActionButton(context, family),
                ],
              );
            }),
          ),
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
                    Color(0xFFFFEFF8),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF7FD),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -_r(context, 90) + (value * 22),
              right: -_r(context, 85),
              child: _glowCircle(_r(context, 225), _accent.withOpacity(.17)),
            ),
            Positioned(
              top: _r(context, 210) - (value * 28),
              left: -_r(context, 120),
              child: _glowCircle(_r(context, 245), _secondary.withOpacity(.13)),
            ),
            Positioned(
              bottom: -_r(context, 100) + (value * 16),
              right: _r(context, 34),
              child: _glowCircle(_r(context, 185), _gold1.withOpacity(.11)),
            ),
          ],
        );
      },
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        _r(context, 12),
        _r(context, 8),
        _r(context, 12),
        _r(context, 8),
      ),
      padding: EdgeInsets.fromLTRB(
        _r(context, 10),
        _r(context, 10),
        _r(context, 10),
        _r(context, 10),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary, _accent],
        ),
        borderRadius: BorderRadius.circular(_r(context, 25)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _topIconButton(
            context,
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: Get.back,
          ),
          SizedBox(width: _r(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('My Family').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _r(context, 20),
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: _r(context, 5)),
                Text(
                  ('Premium family dashboard').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.72),
                    fontSize: _r(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            final family = _isDetailMode
                ? controller.selectedFamily.value
                : controller.myFamily.value;
            return _topIconButton(
              context,
              icon: Icons.settings_rounded,
              onTap: (family == null || widget.readOnly)
                  ? null
                  : () => _openFamilySettings(context, family),
              gold: true,
            );
          }),
        ],
      ),
    );
  }

  Widget _topIconButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback? onTap,
        bool gold = false,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_r(context, 16)),
      child: Container(
        width: _r(context, 42),
        height: _r(context, 42),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gold ? const LinearGradient(colors: [_gold1, _gold2]) : null,
          color: gold ? null : Colors.white.withOpacity(.14),
          borderRadius: BorderRadius.circular(_r(context, 16)),
          border: Border.all(color: Colors.white.withOpacity(.16)),
          boxShadow: gold
              ? [
            BoxShadow(
              color: _gold1.withOpacity(.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ]
              : [],
        ),
        child: Icon(
          icon,
          color: gold ? _textDark : Colors.white,
          size: _r(context, 19),
        ),
      ),
    );
  }

  Widget _noFamilyFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_r(context, 22)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(_r(context, 22)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(_r(context, 24)),
            border: Border.all(color: Colors.white.withOpacity(.85)),
            boxShadow: [
              BoxShadow(
                color: _secondary.withOpacity(.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _r(context, 72),
                height: _r(context, 72),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_primary, _secondary, _accent]),
                ),
                child: Icon(Icons.groups_2_rounded, color: Colors.white, size: _r(context, 34)),
              ),
              SizedBox(height: _r(context, 14)),
              Text(
                ('No family found').appTr,
                style: TextStyle(
                  fontSize: _r(context, 18),
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              SizedBox(height: _r(context, 6)),
              Text(
                ('Create or join a family to see your premium dashboard.').appTr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _r(context, 13),
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, FamilyModel family) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 22 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: SizedBox(
        height: _r(context,402),
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _coverArea(context, family),
            Positioned(
              left: _r(context, 12),
              right: _r(context, 12),
              bottom: _r(context, 16),
              child: _stats(context, family),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverArea(BuildContext context, FamilyModel family) {
    return Container(
      height: _r(context, 318),
      width: double.infinity,
      // margin: EdgeInsets.fromLTRB(
      //   _r(context, 10),
      //   _r(context, 6),
      //   _r(context, 10),
      //   0,
      // ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // borderRadius: BorderRadius.circular(_r(context, 34)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary, _accent],
        ),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (family.coverUrl.isNotEmpty)
            Image.network(
              family.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          /// Cover + page color blend overlay.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.06),
                    _primary.withOpacity(.16),
                    _secondary.withOpacity(.38),
                    _pageBg.withOpacity(.18),
                  ],
                  stops: const [0.0, .38, .76, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _MyFamilyCoverPatternPainter(
                primary: Colors.white,
                accent: _gold1,
              ),
            ),
          ),
          Positioned(
            right: -_r(context, 48),
            top: -_r(context, 44),
            child: _ring(context, _r(context, 170)),
          ),
          Positioned(
            left: -_r(context, 60),
            bottom: -_r(context, 70),
            child: _ring(context, _r(context, 190)),
          ),

          /// Top floating controls like an appbar, but no real appbar.
          Positioned(
            left: _r(context, 14),
            top: _r(context, 14),
            child: _coverIconButton(
              context,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: Get.back,
            ),
          ),
          if (!widget.readOnly)
            Positioned(
              right: _r(context, 14),
              top: _r(context, 14),
              child: _coverIconButton(
                context,
                icon: Icons.settings_rounded,
                onTap: () => _openFamilySettings(context, family),
                gold: true,
              ),
            ),

          /// Center profile information.
          Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _r(context, 22),
                _r(context, 30),
                _r(context, 22),
                _r(context, 34),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _r(context, 106),
                    height: _r(context, 106),
                    padding: EdgeInsets.all(_r(context, 5)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(.30),
                          blurRadius: 26,
                          offset: const Offset(0, 11),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: EdgeInsets.all(_r(context, 3)),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_gold1, _accent, _secondary]),
                      ),
                      child: FamilyNetworkImage(
                        url: family.logoUrl,
                        size: _r(context, 90),
                        radius: _r(context, 45),
                        placeholderIcon: Icons.groups_2_rounded,
                      ),
                    ),
                  ),
                  SizedBox(height: _r(context, 12)),
                  Text(
                    family.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _r(context, 22),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(.28),
                          blurRadius: 9,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: _r(context, 11)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _coverInfoPill(
                          context,
                          icon: Icons.workspace_premium_rounded,
                          text: ('Lv. ${family.levelNo}').appTr,
                          gold: true,
                        ),
                      ),
                      SizedBox(width: _r(context, 8)),
                      Flexible(
                        child: _coverInfoPill(
                          context,
                          icon: Icons.tag_rounded,
                          text: ('ID: ${family.familyCode}').appTr,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _r(context, 8)),
                  _coverInfoPill(
                    context,
                    icon: Icons.groups_rounded,
                    text: family.memberText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverIconButton(
      BuildContext context, {
        required IconData icon,
        required VoidCallback? onTap,
        bool gold = false,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_r(context, 17)),
      child: Container(
        width: _r(context, 43),
        height: _r(context, 43),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gold ? const LinearGradient(colors: [_gold1, _gold2]) : null,
          color: gold ? null : Colors.black.withOpacity(.20),
          borderRadius: BorderRadius.circular(_r(context, 17)),
          border: Border.all(
            color: gold ? Colors.white.withOpacity(.85) : Colors.white.withOpacity(.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: gold ? _textDark : Colors.white,
          size: _r(context, 19),
        ),
      ),
    );
  }

  Widget _coverInfoPill(
      BuildContext context, {
        required IconData icon,
        required String text,
        bool gold = false,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _r(context, 10),
        vertical: _r(context, 7),
      ),
      decoration: BoxDecoration(
        gradient: gold ? const LinearGradient(colors: [_gold1, _gold2]) : null,
        color: gold ? null : Colors.white.withOpacity(.17),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(gold ? 0 : .20)),
        boxShadow: gold
            ? [
          BoxShadow(
            color: _gold1.withOpacity(.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: gold ? _textDark : Colors.white,
            size: _r(context, 14),
          ),
          SizedBox(width: _r(context, 5)),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: gold ? _textDark : Colors.white,
                fontSize: _r(context, 11.5),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.10), width: _r(context, 18)),
      ),
    );
  }

  Widget _headerPill(
      BuildContext context, {
        required IconData icon,
        required String text,
        bool gold = false,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _r(context, 10), vertical: _r(context, 7)),
      decoration: BoxDecoration(
        gradient: gold ? const LinearGradient(colors: [_gold1, _gold2]) : null,
        color: gold ? null : Colors.white.withOpacity(.86),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: gold ? _textDark : _secondary, size: _r(context, 15)),
          SizedBox(width: _r(context, 5)),
          Text(
            text,
            style: TextStyle(
              color: gold ? _textDark : _secondary,
              fontSize: _r(context, 11.4),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyInfo(BuildContext context, FamilyModel family) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _r(context, 18),
        _r(context, 52),
        _r(context, 18),
        _r(context, 14),
      ),
      child: Column(
        children: [
          Text(
            family.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _r(context, 20),
              fontWeight: FontWeight.w900,
              color: _textDark,
              height: 1.05,
            ),
          ),
          SizedBox(height: _r(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _miniInfoPill(
                  context,
                  icon: Icons.tag_rounded,
                  text: ('ID: ${family.familyCode}').appTr,
                ),
              ),
              SizedBox(width: _r(context, 8)),
              Flexible(
                child: _miniInfoPill(
                  context,
                  icon: Icons.groups_rounded,
                  text: family.memberText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfoPill(BuildContext context, {required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _r(context, 10), vertical: _r(context, 7)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FD),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFF1E4F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _secondary.withOpacity(.76), size: _r(context, 14)),
          SizedBox(width: _r(context, 5)),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _secondary.withOpacity(.76),
                fontSize: _r(context, 11.6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context, FamilyModel family) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _r(context, 14)),
      child: Row(
        children: [
          _statCard(
            context,
            icon: Icons.auto_awesome_rounded,
            value: FamilyUi.compact(family.points),
            title: ('Points').appTr,
          ),
          SizedBox(width: _r(context, 10)),
          _statCard(
            context,
            icon: Icons.groups_rounded,
            value: family.memberText,
            title: ('Members').appTr,
          ),
          SizedBox(width: _r(context, 10)),
          _statCard(
            context,
            icon: Icons.monetization_on_rounded,
            value: FamilyUi.compact(family.coins),
            title: ('Coins').appTr,
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String title,
      }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: _r(context, 12), horizontal: _r(context, 8)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primary, _secondary, _accent],
          ),
          borderRadius: BorderRadius.circular(_r(context, 18)),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _r(context, 34),
              height: _r(context, 34),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.14),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: Icon(icon, color: _gold1, size: _r(context, 18)),
            ),
            SizedBox(height: _r(context, 8)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _r(context, 14.3),
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            SizedBox(height: _r(context, 4)),
            Text(
              title,
              style: TextStyle(
                fontSize: _r(context, 10.8),
                fontWeight: FontWeight.w800,
                color: Colors.white.withOpacity(.76),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    return Container(
      height: _r(context, 56),
      margin: EdgeInsets.fromLTRB(_r(context, 12), 0, _r(context, 12), _r(context, 12)),
      padding: EdgeInsets.all(_r(context, 6)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(_r(context, 20)),
        border: Border.all(color: Colors.white.withOpacity(.86)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
          borderRadius: BorderRadius.circular(_r(context, 16)),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _muted,
        labelStyle: TextStyle(fontSize: _r(context, 12.2), fontWeight: FontWeight.w900),
        unselectedLabelStyle: TextStyle(fontSize: _r(context, 12), fontWeight: FontWeight.w800),
        tabs:  [
          Tab(text: ('Members').appTr),
          Tab(text: ('Request').appTr),
          Tab(text: ('Log').appTr),
        ],
      ),
    );
  }

  Widget _memberList(BuildContext context, FamilyModel family) {
    final members = family.members;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: _r(context, 12)),
      decoration: _premiumCardDecoration(context),
      child: members.isEmpty
          ? _emptyCard(context, ('No member found').appTr, Icons.person_off_rounded)
          : ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(_r(context, 13)),
        itemCount: members.length,
        separatorBuilder: (_, __) => SizedBox(height: _r(context, 12)),
        itemBuilder: (_, index) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 340 + (index * 45).clamp(0, 240)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(14 * (1 - value), 0),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _memberRow(context, members[index]),
          );
        },
      ),
    );
  }

  BoxDecoration _premiumCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white.withOpacity(.94),
      borderRadius: BorderRadius.circular(_r(context, 24)),
      border: Border.all(color: Colors.white.withOpacity(.86)),
      boxShadow: [
        BoxShadow(
          color: _secondary.withOpacity(.065),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _memberRow(BuildContext context, FamilyMemberModel member) {
    final role = member.role.trim().toLowerCase();
    final roleIcon = role == 'owner'
        ? Icons.workspace_premium_rounded
        : role == 'admin'
        ? Icons.admin_panel_settings_rounded
        : Icons.person_rounded;

    final roleColor = role == 'owner'
        ? _gold1
        : role == 'admin'
        ? _accent
        : _secondary.withOpacity(.68);

    return Container(
      padding: EdgeInsets.all(_r(context, 12)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFF7FD), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(_r(context, 18)),
        border: Border.all(color: const Color(0xFFF1E4F2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(_r(context, 2)),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_gold1, _accent, _secondary]),
            ),
            child: FamilyNetworkImage(
              url: member.avatarUrl,
              size: _r(context, 46),
              radius: _r(context, 23),
              placeholderIcon: Icons.person,
            ),
          ),
          SizedBox(width: _r(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _r(context, 14.2),
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                  ),
                ),
                SizedBox(height: _r(context, 6)),
                Row(
                  children: [
                    Icon(roleIcon, color: roleColor, size: _r(context, 15)),
                    SizedBox(width: _r(context, 4)),
                    Flexible(
                      child: Text(
                        member.role.capitalizeFirst ?? member.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _r(context, 11.6),
                          fontWeight: FontWeight.w900,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: _r(context, 8)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: _r(context, 9), vertical: _r(context, 7)),
            decoration: BoxDecoration(
              color: _secondary.withOpacity(.07),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              FamilyUi.compact(member.coins),
              style: TextStyle(
                fontSize: _r(context, 11.6),
                fontWeight: FontWeight.w900,
                color: _secondary,
              ),
            ),
          ),
          SizedBox(width: _r(context, 5)),
          if (_canShowMemberMenu(member))
            PopupMenuButton<String>(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_r(context, 15))),
              icon: Icon(Icons.more_horiz_rounded, size: _r(context, 22), color: _secondary),
              onSelected: (value) => _handleMemberAction(member, value),
              itemBuilder: (_) => _memberMenuItems(member),
            )
          else
            Icon(Icons.more_horiz_rounded, size: _r(context, 22), color: _muted),
        ],
      ),
    );
  }

  bool _canShowMemberMenu(FamilyMemberModel member) {
    return controller.canManageMember(member);
  }

  List<PopupMenuEntry<String>> _memberMenuItems(FamilyMemberModel member) {
    final items = <PopupMenuEntry<String>>[];
    final role = member.role.trim().toLowerCase();

    if (controller.canChangeRoles) {
      if (role == 'admin') {
        items.add( PopupMenuItem(value: 'member', child: Text(('Make Member').appTr)));
      } else {
        items.add( PopupMenuItem(value: 'admin', child: Text(('Make Admin').appTr)));
      }
    }

    if (controller.canKickFamilyMember(member)) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add( PopupMenuItem(value: 'kick', child: Text(('Kick Member').appTr)));
    }

    if (items.isEmpty) {
      items.add( PopupMenuItem(value: 'none', enabled: false, child: Text(('No action').appTr)));
    }

    return items;
  }

  Future<void> _handleMemberAction(FamilyMemberModel member, String action) async {
    if (action == 'none') return;

    if (action == 'kick') {
      final ok = await _confirmDialog(
        title: ('Kick Member?').appTr,
        message: ('Remove ${member.name} from this family?').appTr,
        confirmText: ('Kick').appTr,
        color: const Color(0xffEF4444),
      );
      if (ok) await controller.kickMember(member.id);
      return;
    }

    if (action == 'admin' || action == 'member') {
      final roleName = action == 'admin' ? ('Admin').appTr : ('Member').appTr;
      final ok = await _confirmDialog(
        title: ('Change Role?').appTr,
        message: ('Make ${member.name} $roleName?').appTr,
        confirmText: ('Update').appTr,
        color: _accent,
      );
      if (ok) await controller.changeRole(member.id, action);
    }
  }

  Widget _requestHint(BuildContext context, FamilyModel family) {
    if (!controller.canManageRequests) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: _r(context, 12)),
        decoration: _premiumCardDecoration(context),
        child: _emptyCard(context, 'Only owner/admin can view requests', Icons.lock_rounded),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: _r(context, 12)),
      padding: EdgeInsets.all(_r(context, 18)),
      decoration: _premiumCardDecoration(context),
      child: Center(
        child: InkWell(
          onTap: () => Get.to(() => const FamilyRequestsApiPage()),
          borderRadius: BorderRadius.circular(_r(context, 18)),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(_r(context, 16)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
              borderRadius: BorderRadius.circular(_r(context, 18)),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: _r(context, 46),
                  height: _r(context, 46),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.15),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: _gold1, size: _r(context, 24)),
                ),
                SizedBox(width: _r(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ('View Pending Requests').appTr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _r(context, 15),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: _r(context, 4)),
                      Text(
                        ('Accept or reject family join requests').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.73),
                          fontSize: _r(context, 12),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: _r(context, 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logList(BuildContext context) {
    _loadCoinLogsOnce();

    return Obx(() {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: _r(context, 12)),
        decoration: _premiumCardDecoration(context),
        child: controller.coinLogs.isEmpty
            ? _emptyCard(context, 'No Log Found', Icons.receipt_long_rounded)
            : ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(_r(context, 13)),
          itemCount: controller.coinLogs.length,
          separatorBuilder: (_, __) => SizedBox(height: _r(context, 12)),
          itemBuilder: (_, i) {
            final log = controller.coinLogs[i];
            return Container(
              padding: EdgeInsets.all(_r(context, 12)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8FD),
                borderRadius: BorderRadius.circular(_r(context, 17)),
                border: Border.all(color: const Color(0xFFF1E4F2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: _r(context, 38),
                    height: _r(context, 38),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_primary, _secondary, _accent]),
                    ),
                    child: Icon(Icons.auto_graph_rounded, color: _gold1, size: _r(context, 19)),
                  ),
                  SizedBox(width: _r(context, 11)),
                  Expanded(
                    child: Text(
                      log.note.isEmpty ? log.actionType : log.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                        fontSize: _r(context, 13.2),
                      ),
                    ),
                  ),
                  SizedBox(width: _r(context, 8)),
                  Text(
                    '+${FamilyUi.compact(log.points)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _accent,
                      fontSize: _r(context, 13),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  Widget _emptyCard(BuildContext context, String text, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_r(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _r(context, 62),
              height: _r(context, 62),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_primary, _secondary, _accent]),
              ),
              child: Icon(icon, color: Colors.white, size: _r(context, 28)),
            ),
            SizedBox(height: _r(context, 12)),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _muted,
                fontSize: _r(context, 13.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActionButton(BuildContext context, FamilyModel family) {
    final isManager = controller.canManageRequests;

    return Positioned(
      left: _r(context, 18),
      right: _r(context, 18),
      bottom: _r(context, 16),
      child: InkWell(
        onTap: () async {
          if (isManager) {
            Get.to(() => const FamilyRequestsApiPage());
            return;
          }

          final ok = await _confirmDialog(
            title: ('Leave Family?').appTr,
            message: ('Are you sure you want to leave this family?').appTr,
            confirmText: ('Leave').appTr,
            color: const Color(0xffEF4444),
          );
          if (ok) await controller.leaveFamily();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: _r(context, 56),
          decoration: BoxDecoration(
            gradient: isManager
                ? const LinearGradient(colors: [_primary, _secondary, _accent])
                : const LinearGradient(colors: [Color(0xffFF5F6D), Color(0xffEF4444)]),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(.18)),
            boxShadow: [
              BoxShadow(
                color: (isManager ? _accent : const Color(0xffEF4444)).withOpacity(.28),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isManager ? Icons.manage_accounts_rounded : Icons.logout_rounded,
                color: isManager ? _gold1 : Colors.white,
                size: _r(context, 20),
              ),
              SizedBox(width: _r(context, 9)),
              Text(
                isManager ? ('Manage Requests').appTr: ('Leave Family').appTr,
                style: TextStyle(
                  fontSize: _r(context, 14.5),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFamilySettings(BuildContext context, FamilyModel family) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            _r(context, 16),
            _r(context, 12),
            _r(context, 16),
            _r(context, 16),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_r(context, 28))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: _r(context, 46),
                  height: _r(context, 5),
                  decoration: BoxDecoration(
                    color: const Color(0xffEADDE9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              SizedBox(height: _r(context, 16)),
              Row(
                children: [
                  Container(
                    width: _r(context, 42),
                    height: _r(context, 42),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_primary, _secondary, _accent]),
                    ),
                    child: Icon(Icons.settings_rounded, color: _gold1, size: _r(context, 22)),
                  ),
                  SizedBox(width: _r(context, 12)),
                  Text(
                    ('Family Settings').appTr,
                    style: TextStyle(fontSize: _r(context, 17), fontWeight: FontWeight.w900, color: _textDark),
                  ),
                ],
              ),
              SizedBox(height: _r(context, 14)),
              if (controller.canEditFamily)
                _sheetItem(
                  context,
                  icon: Icons.edit_rounded,
                  color: _accent,
                  title: ('Edit Family').appTr,
                  subTitle: 'Update name, notice, description and join type',
                  onTap: () {
                    Get.back();
                    Get.to(() => EditFamilyApiPage(family: family));
                  },
                ),
              if (controller.canManageRequests)
                _sheetItem(
                  context,
                  icon: Icons.person_add_alt_1_rounded,
                  color: const Color(0xff22C55E),
                  title: ('Manage Requests').appTr,
                  subTitle: 'Accept or reject pending join requests',
                  onTap: () {
                    Get.back();
                    Get.to(() => const FamilyRequestsApiPage());
                  },
                ),
              _sheetItem(
                context,
                icon: Icons.refresh_rounded,
                color: const Color(0xff315BD8),
                title: ('Refresh Family').appTr,
                subTitle: 'Reload latest family data',
                onTap: () {
                  Get.back();
                  if (_isDetailMode) {
                    controller.loadFamilyDetail(widget.familyId!);
                  } else {
                    controller.loadHome();
                  }
                },
              ),
              if (!controller.isOwner)
                _sheetItem(
                  context,
                  icon: Icons.logout_rounded,
                  color: const Color(0xffEF4444),
                  title: ('Leave Family').appTr,
                  subTitle: 'Exit from this family',
                  onTap: () async {
                    Get.back();
                    final ok = await _confirmDialog(
                      title: ('Leave Family?').appTr,
                      message: ('Are you sure you want to leave this family?').appTr,
                      confirmText: ('Leave').appTr,
                      color: const Color(0xffEF4444),
                    );
                    if (ok) await controller.leaveFamily();
                  },
                )
              else
                _disabledSheetItem(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: ('Owner cannot leave').appTr,
                  subTitle: 'Transfer ownership or manage family from admin panel.',
                ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _sheetItem(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required String subTitle,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_r(context, 16)),
      child: Container(
        margin: EdgeInsets.only(bottom: _r(context, 10)),
        padding: EdgeInsets.all(_r(context, 12)),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8FD),
          borderRadius: BorderRadius.circular(_r(context, 16)),
          border: Border.all(color: const Color(0xFFF1E4F2)),
        ),
        child: Row(
          children: [
            Container(
              width: _r(context, 42),
              height: _r(context, 42),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(_r(context, 14)),
              ),
              child: Icon(icon, color: color, size: _r(context, 22)),
            ),
            SizedBox(width: _r(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: _r(context, 13.7), fontWeight: FontWeight.w900, color: _textDark),
                  ),
                  SizedBox(height: _r(context, 3)),
                  Text(
                    subTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: _r(context, 11.5), fontWeight: FontWeight.w700, color: _muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: _r(context, 14), color: const Color(0xffB6B6BC)),
          ],
        ),
      ),
    );
  }

  Widget _disabledSheetItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subTitle,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: _r(context, 10)),
      padding: EdgeInsets.all(_r(context, 12)),
      decoration: BoxDecoration(
        color: const Color(0xffF5F2F6),
        borderRadius: BorderRadius.circular(_r(context, 16)),
        border: Border.all(color: const Color(0xFFE9E1EA)),
      ),
      child: Row(
        children: [
          Container(
            width: _r(context, 42),
            height: _r(context, 42),
            decoration: BoxDecoration(
              color: const Color(0xffEDE8EF),
              borderRadius: BorderRadius.circular(_r(context, 14)),
            ),
            child: Icon(icon, color: const Color(0xff9999A4), size: _r(context, 22)),
          ),
          SizedBox(width: _r(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: _r(context, 13.7), fontWeight: FontWeight.w900, color: const Color(0xff777782)),
                ),
                SizedBox(height: _r(context, 3)),
                Text(
                  subTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _r(context, 11.5), fontWeight: FontWeight.w700, color: const Color(0xff9999A4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color color,
  }) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_r(context, 20))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child:  Text(('No').appTr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Get.back(result: true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }
}


class _MyFamilyCoverPatternPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  const _MyFamilyCoverPatternPainter({
    required this.primary,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = primary.withOpacity(.060)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = accent.withOpacity(.085)
      ..style = PaintingStyle.fill;

    for (double y = 34; y < size.height + 60; y += 92) {
      final row = (y / 92).floor();
      for (double x = -26; x < size.width + 80; x += 108) {
        final dx = row.isEven ? x : x + 52;
        _familyIcon(canvas, Offset(dx, y), linePaint);
        canvas.drawCircle(Offset(dx + 76, y + 18), 2.7, dotPaint);
        canvas.drawCircle(Offset(dx + 92, y + 54), 1.9, dotPaint);
      }
    }

    final wavePaint = Paint()
      ..color = primary.withOpacity(.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final wave = Path()
      ..moveTo(0, size.height * .72)
      ..quadraticBezierTo(size.width * .22, size.height * .64, size.width * .48, size.height * .72)
      ..quadraticBezierTo(size.width * .75, size.height * .82, size.width, size.height * .68);

    canvas.drawPath(wave, wavePaint);
  }

  void _familyIcon(Canvas canvas, Offset origin, Paint paint) {
    canvas.drawCircle(origin + const Offset(31, 17), 7.5, paint);
    canvas.drawCircle(origin + const Offset(16, 22), 5.5, paint);
    canvas.drawCircle(origin + const Offset(47, 22), 5.5, paint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: origin + const Offset(31, 41), width: 31, height: 24),
        const Radius.circular(14),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: origin + const Offset(13, 43), width: 21, height: 18),
        const Radius.circular(12),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: origin + const Offset(50, 43), width: 21, height: 18),
        const Radius.circular(12),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MyFamilyCoverPatternPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.accent != accent;
  }
}
