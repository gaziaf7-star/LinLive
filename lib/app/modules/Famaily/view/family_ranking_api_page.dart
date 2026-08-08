import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import '../Controller/FamilyConroller.dart';
import '../Models/family_models.dart';
import '../Widgets/family_common_widgets.dart';
import '../Widgets/family_shimmer.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class FamilyRankingApiPage extends StatefulWidget {
  const FamilyRankingApiPage({super.key});

  @override
  State<FamilyRankingApiPage> createState() => _FamilyRankingApiPageState();
}

class _FamilyRankingApiPageState extends State<FamilyRankingApiPage> {
  final FamilyController controller = Get.put(
    Familyconroller(),
    permanent: true,
  );

  static const String _top1FrameAsset =
      'assets/svga/Level/Top1_gold9999999_days1 (1) (3).svga';
  static const String _top2FrameAsset =
      'assets/svga/Level/Top2_gold99999999_days1 (1) (1).svga';
  static const String _top3FrameAsset =
      'assets/svga/Level/Top3_gold999999_days1 (1) (1).svga';

  static const Color _primary = Color(0xFF190522);
  static const Color _secondary = Color(0xFF3B072F);
  static const Color _accent = Color(0xFFFF3D8B);
  static const Color _gold = Color(0xFFFFD45A);
  static const Color _silver = Color(0xFFBFD2FF);
  static const Color _bronze = Color(0xFFFFB36C);
  static const Color _pageBg = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF211625);
  static const Color _muted = Color(0xFF827484);

  @override
  void initState() {
    super.initState();
    controller.loadRanking();
    controller.startRealtime();
  }

  @override
  void dispose() {
    controller.stopRealtime();
    super.dispose();
  }

  String _ownerName(FamilyModel family) {
    return family.ownerName.trim().isEmpty ? 'Family Owner' : family.ownerName;
  }

  String _ownerImage(FamilyModel family) {
    if (family.ownerProfileImageUrl.trim().isNotEmpty) {
      return family.ownerProfileImageUrl;
    }
    return family.logoUrl;
  }

  String _frameAssetForRank(int rank) {
    if (rank == 1) return _top1FrameAsset;
    if (rank == 2) return _top2FrameAsset;
    return _top3FrameAsset;
  }

  double _s(BuildContext context, double value) => FamilyUi.r(context, value);

  @override
  Widget build(BuildContext context) {
    final r = FamilyUi.r;

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          _cleanWhiteBackground(context),
          SafeArea(
            child: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: Obx(() {
                    if (controller.rankingStatus.value ==
                        FamilyPageStatus.loading) {
                      return const FamilyListShimmer();
                    }

                    if (controller.rankingStatus.value ==
                        FamilyPageStatus.error) {
                      return _empty(
                        controller.errorMessage.value,
                        retry: controller.loadRanking,
                      );
                    }

                    if (controller.rankingList.isEmpty) {
                      return _empty(('No ranking found').appTr);
                    }

                    final top = controller.rankingList.take(3).toList();
                    final rest = controller.rankingList.skip(3).toList();

                    return RefreshIndicator(
                      color: _accent,
                      backgroundColor: Colors.white,
                      onRefresh: controller.loadRanking,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(bottom: r(context, 26)),
                        child: Column(
                          children: [
                            SizedBox(height: r(context, 12)),
                            _topCards(context, top),
                            SizedBox(height: r(context, 22)),
                            if (rest.isNotEmpty) _rankingList(context, rest),
                            if (rest.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: r(context, 16),
                                ),
                                child: _singleInfoCard(context),
                              ),
                            SizedBox(height: r(context, 18)),
                            _realtimePill(context),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cleanWhiteBackground(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFFBFE),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _FamilyRankingPatternPainter(
                primary: _secondary,
                accent: _accent,
              ),
            ),
          ),
        ),
        Positioned(
          top: -_s(context, 82),
          right: -_s(context, 95),
          child: _blurCircle(_s(context, 230), _accent.withOpacity(.095)),
        ),
        Positioned(
          top: _s(context, 220),
          left: -_s(context, 120),
          child: _blurCircle(_s(context, 245), _secondary.withOpacity(.055)),
        ),
        Positioned(
          bottom: -_s(context, 92),
          right: _s(context, 18),
          child: _blurCircle(_s(context, 180), _gold.withOpacity(.075)),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _topBar(BuildContext context) {
    final r = FamilyUi.r;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r(context, 14),
        r(context, 8),
        r(context, 14),
        r(context, 6),
      ),
      child: Container(
        height: r(context, 58),
        padding: EdgeInsets.symmetric(horizontal: r(context, 10)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.92),
          borderRadius: BorderRadius.circular(r(context, 22)),
          border: Border.all(color: const Color(0xFFF6E8F1)),
          boxShadow: [
            BoxShadow(
              color: _secondary.withOpacity(.075),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            InkWell(
              onTap: Get.back,
              borderRadius: BorderRadius.circular(r(context, 15)),
              child: Container(
                width: r(context, 40),
                height: r(context, 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _secondary, _accent],
                  ),
                  borderRadius: BorderRadius.circular(r(context, 15)),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(.17),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: r(context, 18),
                ),
              ),
            ),
            SizedBox(width: r(context, 12)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ('Family Ranking').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r(context, 18),
                      color: _textDark,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: r(context, 4)),
                  Text(
                    ('Top family leaderboard').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r(context, 11.5),
                      color: _muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: r(context, 41),
              height: r(context, 41),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_gold, Color(0xFFFFF238)]),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withOpacity(.24),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: _textDark,
                size: r(context, 23),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCards(BuildContext context, List<FamilyModel> top) {
    FamilyModel f(int i) {
      return top.length > i ? top[i] : const FamilyModel(name: 'FAMILY');
    }

    final r = FamilyUi.r;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double sideW = (constraints.maxWidth * .285)
            .clamp(r(context, 96), r(context, 112))
            .toDouble();
        final double centerW = (constraints.maxWidth * .355)
            .clamp(r(context, 126), r(context, 142))
            .toDouble();
        final double gap = r(context, 7);

        final double centerLeft = (constraints.maxWidth - centerW) / 2;
        final double leftCardX = (centerLeft - sideW - gap)
            .clamp(r(context, 6), constraints.maxWidth)
            .toDouble();

        return SizedBox(
          height: r(context, 278),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: leftCardX,
                bottom: r(context, 3),
                child: _animatedPodium(
                  context,
                  delay: 120,
                  child: _podium(
                    context,
                    family: f(1),
                    rank: 2,
                    width: sideW,
                    height: r(context, 190),
                    mainColor: const Color(0xFF244EDB),
                    secondColor: const Color(0xFF6AA8FF),
                    accentColor: _silver,
                    nameColor: const Color(0xFFFFFFFF),
                    ownerColor: const Color(0xFFEAF0FF),
                  ),
                ),
              ),
              Positioned(
                right: leftCardX,
                bottom: r(context, 3),
                child: _animatedPodium(
                  context,
                  delay: 180,
                  child: _podium(
                    context,
                    family: f(2),
                    rank: 3,
                    width: sideW,
                    height: r(context, 190),
                    mainColor: const Color(0xFFFF7B2C),
                    secondColor: const Color(0xFFFF3D8B),
                    accentColor: _bronze,
                    nameColor: const Color(0xFFFFFFFF),
                    ownerColor: const Color(0xFFFFF2E9),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: _animatedPodium(
                  context,
                  delay: 40,
                  child: _podium(
                    context,
                    family: f(0),
                    rank: 1,
                    width: centerW,
                    height: r(context, 218),
                    mainColor: _primary,
                    secondColor: _accent,
                    accentColor: _gold,
                    nameColor: const Color(0xFFFFFFFF),
                    ownerColor: const Color(0xFFFFE8F5),
                    first: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _animatedPodium(
      BuildContext context, {
        required int delay,
        required Widget child,
      }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
    );
  }

  Widget _podium(
      BuildContext context, {
        required FamilyModel family,
        required int rank,
        required double width,
        required double height,
        required Color mainColor,
        required Color secondColor,
        required Color accentColor,
        required Color nameColor,
        required Color ownerColor,
        bool first = false,
      }) {
    final r = FamilyUi.r;
    final isEmptyFake = family.id == 0 && family.name == 'FAMILY';
    final avatarSize = first ? r(context, 58) : r(context, 49);
    final frameSize = first ? r(context, 90) : r(context, 78);

    return SizedBox(
      width: width,
      height: height + r(context, 34),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          _rankBadge(context, rank, first),
          Positioned(
            top: r(context, 28),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r(context, 22)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    mainColor,
                    secondColor.withOpacity(.94),
                    const Color(0xFF13051C),
                  ],
                  stops: const [0.0, .58, 1.0],
                ),
                border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: secondColor.withOpacity(.25),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    top: -r(context, 40),
                    right: -r(context, 36),
                    child: _glow(
                      context,
                      r(context, 96),
                      accentColor.withOpacity(first ? .22 : .18),
                    ),
                  ),
                  Positioned(
                    bottom: -r(context, 52),
                    left: -r(context, 48),
                    child: _glow(context, r(context, 104), Colors.white.withOpacity(.08)),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        r(context, 7),
                        first ? r(context, 13) : r(context, 11),
                        r(context, 7),
                        r(context, 10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: _svgaProfileFrame(
                              context,
                              imageUrl: isEmptyFake ? '' : _ownerImage(family),
                              avatarSize: avatarSize,
                              frameSize: frameSize,
                              frameAsset: _frameAssetForRank(rank),
                              glowColor: accentColor,
                            ),
                          ),
                          SizedBox(height: first ? r(context, 3) : r(context, 1)),
                          Text(
                            isEmptyFake ? ('FAMILY').appTr: family.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: first ? r(context, 12) : r(context, 10.7),
                              fontWeight: FontWeight.w900,
                              color: nameColor,
                              height: 1.05,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(.20),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: r(context, 5)),
                          Text(
                            isEmptyFake ? ('Owner').appTr: _ownerName(family),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: first ? r(context, 10.8) : r(context, 9.8),
                              fontWeight: FontWeight.w800,
                              color: ownerColor.withOpacity(.92),
                              height: 1,
                            ),
                          ),
                          SizedBox(height: r(context, 7)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r(context, 7),
                              vertical: r(context, 3.5),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.16),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: Colors.white.withOpacity(.14)),
                            ),
                            child: Text(
                              isEmptyFake ? ('0/0 Members').appTr: family.memberText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: r(context, 9.2),
                                fontWeight: FontWeight.w900,
                                color: Colors.white.withOpacity(.90),
                                height: 1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r(context, 8),
                              vertical: r(context, 4),
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withOpacity(.26),
                                  Colors.white.withOpacity(.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: accentColor.withOpacity(.28)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  color: accentColor,
                                  size: r(context, 15),
                                ),
                                SizedBox(width: r(context, 3)),
                                Text(
                                  isEmptyFake ? '0' : FamilyUi.compact(family.coins),
                                  style: TextStyle(
                                    fontSize: first ? r(context, 13.2) : r(context, 12.2),
                                    fontWeight: FontWeight.w900,
                                    color: accentColor,
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _glow(BuildContext context, double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _svgaProfileFrame(
      BuildContext context, {
        required String imageUrl,
        required double avatarSize,
        required double frameSize,
        required String frameAsset,
        required Color glowColor,
      }) {
    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: avatarSize + _s(context, 8),
            height: avatarSize + _s(context, 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(.92),
                  glowColor.withOpacity(.55),
                  _gold.withOpacity(.62),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
          FamilyNetworkImage(
            url: imageUrl,
            size: avatarSize,
            radius: avatarSize / 2,
            placeholderIcon: Icons.person,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: SVGAEasyPlayer(
                assetsName: frameAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(BuildContext context, int rank, bool first) {
    final r = FamilyUi.r;

    final Color bgColor = rank == 1
        ? _gold
        : rank == 2
        ? _silver
        : _bronze;

    final Color textColor = rank == 1
        ? const Color(0xff8A5900)
        : rank == 2
        ? const Color(0xff4052A8)
        : const Color(0xff8B5200);

    return SizedBox(
      width: r(context, 54),
      height: r(context, 44),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: r(context, 8),
            child: Container(
              width: r(context, 35),
              height: r(context, 35),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.70), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(.45),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: r(context, 15),
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          ),
          if (first)
            Positioned(
              top: 0,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: r(context, 19),
                color: const Color(0xffFFF4B2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rankingList(BuildContext context, List<FamilyModel> list) {
    final r = FamilyUi.r;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r(context, 14)),
      padding: EdgeInsets.symmetric(vertical: r(context, 8)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(r(context, 22)),
        border: Border.all(color: const Color(0xFFF6E8F1)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.060),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: List.generate(
          list.length,
              (i) {
            return Column(
              children: [
                _rankRow(context, i + 4, list[i]),
                if (i != list.length - 1)
                  Padding(
                    padding: EdgeInsets.only(left: r(context, 74), right: r(context, 14)),
                    child: Container(height: 1, color: const Color(0xFFF4E7F0)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _rankRow(BuildContext context, int rank, FamilyModel item) {
    final r = FamilyUi.r;

    return SizedBox(
      height: r(context, 78),
      child: Row(
        children: [
          SizedBox(
            width: r(context, 40),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: r(context, 14),
                  fontWeight: FontWeight.w900,
                  color: _secondary,
                ),
              ),
            ),
          ),
          Container(
            width: r(context, 46),
            height: r(context, 46),
            padding: EdgeInsets.all(r(context, 2)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_secondary.withOpacity(.20), _accent.withOpacity(.18)],
              ),
            ),
            child: FamilyNetworkImage(
              url: _ownerImage(item),
              size: r(context, 42),
              radius: 21,
              placeholderIcon: Icons.person,
            ),
          ),
          SizedBox(width: r(context, 11)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r(context, 13.8),
                    fontWeight: FontWeight.w900,
                    color: _textDark,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: r(context, 6)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _ownerName(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: r(context, 11.4),
                          fontWeight: FontWeight.w800,
                          color: _muted,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: r(context, 7)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r(context, 7),
                        vertical: r(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F8),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFF5D6E8)),
                      ),
                      child: Text(
                        item.memberText,
                        style: TextStyle(
                          fontSize: r(context, 9.4),
                          fontWeight: FontWeight.w900,
                          color: _accent,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: r(context, 8)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monetization_on_rounded,
                    size: r(context, 15),
                    color: _gold,
                  ),
                  SizedBox(width: r(context, 3)),
                  Text(
                    FamilyUi.compact(item.coins),
                    style: TextStyle(
                      fontSize: r(context, 13.2),
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r(context, 5)),
              Text(
                ('${FamilyUi.compact(item.points)} pts').appTr,
                style: TextStyle(
                  fontSize: r(context, 10.4),
                  fontWeight: FontWeight.w800,
                  color: _muted,
                ),
              ),
            ],
          ),
          SizedBox(width: r(context, 12)),
        ],
      ),
    );
  }

  Widget _singleInfoCard(BuildContext context) {
    final r = FamilyUi.r;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r(context, 15)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(r(context, 20)),
        border: Border.all(color: const Color(0xFFF6E8F1)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.060),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        ('More families will appear here when they join the ranking.').appTr,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: r(context, 12.6),
          fontWeight: FontWeight.w800,
          color: _muted,
        ),
      ),
    );
  }

  Widget _realtimePill(BuildContext context) {
    final r = FamilyUi.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r(context, 13), vertical: r(context, 8)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.90),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFF2DDEB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r(context, 8),
            height: r(context, 8),
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          ),
          SizedBox(width: r(context, 7)),
          Text(
            ('Ranking updates in real time').appTr,
            style: TextStyle(
              fontSize: r(context, 12.2),
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text, {Future<void> Function()? retry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF6E8F1)),
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
              const Icon(Icons.emoji_events_rounded, color: _accent, size: 48),
              const SizedBox(height: 12),
              Text(
                text.isEmpty ? ('No ranking found').appTr: text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              if (retry != null) ...[
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: retry,
                  child:  Text(('Try Again').appTr),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyRankingPatternPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  const _FamilyRankingPatternPainter({
    required this.primary,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = primary.withOpacity(.026)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;

    final softPaint = Paint()
      ..color = accent.withOpacity(.020)
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = accent.withOpacity(.035)
      ..style = PaintingStyle.fill;

    for (double y = 36; y < size.height + 100; y += 125) {
      final row = (y / 125).floor();
      for (double x = -40; x < size.width + 90; x += 130) {
        final dx = row.isEven ? x : x + 62;
        _drawFamilyMark(canvas, Offset(dx, y), linePaint, softPaint);
        canvas.drawCircle(Offset(dx + 78, y + 18), 2.8, dotPaint);
        canvas.drawCircle(Offset(dx + 96, y + 62), 2.0, dotPaint);
      }
    }

    final wavePaint = Paint()
      ..color = primary.withOpacity(.020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final wave = Path()
      ..moveTo(0, size.height * .20)
      ..quadraticBezierTo(
        size.width * .22,
        size.height * .12,
        size.width * .48,
        size.height * .20,
      )
      ..quadraticBezierTo(
        size.width * .74,
        size.height * .28,
        size.width,
        size.height * .17,
      );

    canvas.drawPath(wave, wavePaint);
  }

  void _drawFamilyMark(
      Canvas canvas,
      Offset origin,
      Paint linePaint,
      Paint softPaint,
      ) {
    final center = origin + const Offset(32, 22);

    canvas.drawCircle(center, 8.5, linePaint);
    canvas.drawCircle(origin + const Offset(15, 26), 6.4, linePaint);
    canvas.drawCircle(origin + const Offset(49, 26), 6.4, linePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin + const Offset(32, 48),
          width: 34,
          height: 27,
        ),
        const Radius.circular(16),
      ),
      linePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin + const Offset(12, 50),
          width: 23,
          height: 21,
        ),
        const Radius.circular(14),
      ),
      linePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: origin + const Offset(52, 50),
          width: 23,
          height: 21,
        ),
        const Radius.circular(14),
      ),
      linePaint,
    );

    final heart = Path()
      ..moveTo(origin.dx + 32, origin.dy + 74)
      ..cubicTo(
        origin.dx + 20,
        origin.dy + 64,
        origin.dx + 13,
        origin.dy + 80,
        origin.dx + 32,
        origin.dy + 91,
      )
      ..cubicTo(
        origin.dx + 51,
        origin.dy + 80,
        origin.dx + 44,
        origin.dy + 64,
        origin.dx + 32,
        origin.dy + 74,
      )
      ..close();

    canvas.drawPath(heart, softPaint);
  }

  @override
  bool shouldRepaint(covariant _FamilyRankingPatternPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.accent != accent;
  }
}
