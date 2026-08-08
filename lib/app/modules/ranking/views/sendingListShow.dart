import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/ranking_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Sendinglistshow extends StatefulWidget {
  final String period;

  const Sendinglistshow({super.key, this.period = 'daily'});

  @override
  State<Sendinglistshow> createState() => _SendinglistshowState();
}

class _SendinglistshowState extends State<Sendinglistshow>
    with SingleTickerProviderStateMixin {
  late final RankingController controller;
  late final AnimationController _nameGradientController;
  bool _localLoading = true;

  static const String _top1Frame = 'assets/svga/Level/Top1_gold9999999_days1 (1) (3).svga';
  static const String _top2Frame = 'assets/svga/Level/Top2_gold99999999_days1 (1) (1).svga';
  static const String _top3Frame = 'assets/svga/Level/Top3_gold999999_days1 (1) (1).svga';

  static const Color _gold = Color(0xFFFFE36F);
  static const Color _deepBrown = Color(0xFF3B1305);
  static const Color _brown = Color(0xFF5A210C);
  static const Color _orange = Color(0xFFFF8B2B);
  static const Color _blue = Color(0xFF42B9FF);
  static const Color _pink = Color(0xFFFF4FA2);

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<RankingController>()
        ? Get.find<RankingController>()
        : Get.put(RankingController(), permanent: true);

    _nameGradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadData();
    });
  }

  @override
  void dispose() {
    _nameGradientController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Sendinglistshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _loadData();
    }
  }

  Future<void> _loadData({bool force = false}) async {
    final currentList = controller.senderRankingFor(widget.period);
    if (mounted && currentList.isEmpty) {
      setState(() => _localLoading = true);
    }

    await controller.showRankingList(period: widget.period, force: force);

    if (mounted) {
      setState(() => _localLoading = false);
    }
  }

  Future<void> _refresh() async {
    await controller.refreshRankingPeriod(widget.period);
  }

  String _periodTitle() {
    switch (widget.period.toLowerCase()) {
      case 'weekly':
        return ('Weekly').appTr;
      case 'monthly':
        return ('Monthly').appTr;
      case 'overall':
        return ('Over all').appTr;
      case 'daily':
      default:
        return ('Daily').appTr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = List<dynamic>.from(controller.senderRankingFor(widget.period).toList());
      list.sort((a, b) => _totalCoin(b).compareTo(_totalCoin(a)));

      final bool showFirstLoading = _localLoading && list.isEmpty;
      if (showFirstLoading) {
        return _rankingShimmer(context);
      }

      if (list.isEmpty) {
        return RefreshIndicator(
          color: _gold,
          backgroundColor: _deepBrown,
          onRefresh: _refresh,
          child: ListView(

            padding: EdgeInsets.fromLTRB(
              _rw(context, 16),
              _rh(context, 34),
              _rw(context, 16),
              _rh(context, 34),
            ),
            children: [
              _emptyCard(context),
            ],
          ),
        );
      }

      final top = list.take(3).toList();
      final rest = list.length > 3 ? list.sublist(3) : <dynamic>[];

      return RefreshIndicator(
        color: _gold,
        backgroundColor: _deepBrown,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _palaceTopArea(context, top)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index < rest.length) {
                    return _rankTile(context, item: rest[index], rank: index + 4);
                  }
                  return _myRankBottomCard(context, list.length + 1);
                },
                childCount: rest.length + 1,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: _rh(context, 26))),
          ],
        ),
      );
    });
  }

  Widget _rankingShimmer(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      padding: EdgeInsets.fromLTRB(_rw(context, 16), _rh(context, 20), _rw(context, 16), _rh(context, 25)),
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: _rh(context, 12)),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.10),
            highlightColor: Colors.white.withOpacity(0.30),
            child: Container(
              height: index == 0 ? _rh(context, 310) : _rh(context, 76),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(index == 0 ? 26 : 18),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _palaceTopArea(BuildContext context, List<dynamic> top) {
    final first = top.isNotEmpty ? top[0] : null;
    final second = top.length > 1 ? top[1] : null;
    final third = top.length > 2 ? top[2] : null;

    return Container(
      height: _rh(context, 326),
      margin: EdgeInsets.fromLTRB(_rw(context, 0), _rh(context, 0), _rw(context, 0), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _palaceBackground(context)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.18),
                    Colors.black.withOpacity(.03),
                    const Color(0xFF4B1B08).withOpacity(.92),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: _rh(context, 10),
            left: 0,
            right: 0,
            child: _topUser(
              context,
              item: first,
              rank: 1,
              frameAsset: _top1Frame,
              avatarSize: _rw(context, 86),
              frameSize: _rw(context, 202),
              nameSize: _rf(context, 18.2),
              coinSize: _rf(context, 21.5),
              center: true,
            ),
          ),
          Positioned(
            top: _rh(context, 134),
            left: _rw(context, 2),
            child: _topUser(
              context,
              item: second,
              rank: 2,
              frameAsset: _top2Frame,
              avatarSize: _rw(context, 48),
              frameSize: _rw(context, 126),
              nameSize: _rf(context, 12.2),
              coinSize: _rf(context, 15.8),
            ),
          ),
          Positioned(
            top: _rh(context, 146),
            right: _rw(context, 2),
            child: _topUser(
              context,
              item: third,
              rank: 3,
              frameAsset: _top3Frame,
              avatarSize: _rw(context, 45),
              frameSize: _rw(context, 118),
              nameSize: _rf(context, 12.0),
              coinSize: _rf(context, 15.5),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _listTopCurve(context),
          ),
        ],
      ),
    );
  }

  Widget _palaceBackground(BuildContext context) {
    // Background image comes from Allrank parent.
    // This layer only adds smooth royal glow so Sending / Receiving / Agency images stay visible.
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(.03),
                Colors.black.withOpacity(.00),
                const Color(0xFF4B1B08).withOpacity(.42),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _PalaceGlowPainter()),
        ),
      ],
    );
  }

  Widget _periodBadge(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: _rw(context, 16), vertical: _rh(context, 7)),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.30),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withOpacity(.40)),
            ),
            child: Text(
              ('${_periodTitle()} Wealth Ranking').appTr,
              style: GoogleFonts.poppins(
                color: _gold,
                fontSize: _rf(context, 13),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topUser(
      BuildContext context, {
        required dynamic item,
        required int rank,
        required String frameAsset,
        required double avatarSize,
        required double frameSize,
        required double nameSize,
        required double coinSize,
        bool center = false,
      }) {
    final user = _userData(item);
    final name = _userName(item);
    final image = _profileImage(user);
    final coin = _formatCoin(_totalCoin(item));
    final level = _safeText(user['level'], fallback: '0');

    final width = center
        ? _rw(context, 255)
        : rank == 2
        ? _rw(context, 138)
        : _rw(context, 132);

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: frameSize * .70,
            width: frameSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(
                    0,
                    center ? -frameSize * .030 : -frameSize * .020,
                  ),
                  child: _circleAvatarWithFallback(
                    context,
                    imageUrl: image,
                    name: name,
                    size: avatarSize,
                  ),
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
          ),
          SizedBox(height: center ? _rh(context, 0) : _rh(context, 0)),
          _animatedGradientName(
            context,
            name,
            fontSize: nameSize,
            rank: rank,
          ),
          SizedBox(height: _rh(context, 5)),
          _levelAndBadgeRow(context, rank: rank, level: level),
          SizedBox(height: _rh(context, 4)),
          Text(
            rank == 1 ? ('NO.1').appTr: coin,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: _gold,
              fontSize: coinSize,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
          if (rank == 1)
            Text(
              coin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(.86),
                fontSize: _rf(context, 12),
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _animatedGradientName(
      BuildContext context,
      String name, {
        required double fontSize,
        required int rank,
      }) {
    final List<Color> colors = rank == 1
        ? const [
      Color(0xFFFFF7B4),
      Color(0xFFFFC400),
      Color(0xFFFFFFFF),
      Color(0xFFFF8B19),
    ]
        : rank == 2
        ? const [
      Color(0xFFEFF8FF),
      Color(0xFF42B9FF),
      Color(0xFFFFFFFF),
      Color(0xFFBEEBFF),
    ]
        : const [
      Color(0xFFFFF0D9),
      Color(0xFFFFA24A),
      Color(0xFFFFFFFF),
      Color(0xFFFFD1A3),
    ];

    return AnimatedBuilder(
      animation: _nameGradientController,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            final double slide = bounds.width * (2 * _nameGradientController.value - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
              stops: const [0.0, .34, .58, 1.0],
            ).createShader(
              Rect.fromLTWH(slide, 0, bounds.width, bounds.height),
            );
          },
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1.05,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _levelAndBadgeRow(BuildContext context, {required int rank, required String level}) {
    final Color badgeColor = rank == 1
        ? const Color(0xFFE7A650)
        : rank == 2
        ? _blue
        : const Color(0xFF47D775);
    final Color secondColor = rank == 1
        ? const Color(0xFF855DFF)
        : rank == 2
        ? _pink
        : _blue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniRankPill(context, color: badgeColor, text: level, icon: Icons.hexagon_rounded),
        SizedBox(width: _rw(context, 5)),
        _miniRankPill(context, color: secondColor, text: '${math.max(1, int.tryParse(level) ?? 0)}', icon: Icons.star_rounded),
      ],
    );
  }

  Widget _miniRankPill(BuildContext context, {required Color color, required String text, required IconData icon}) {
    return Container(
      height: _rh(context, 22),
      padding: EdgeInsets.symmetric(horizontal: _rw(context, 7)),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(.95), color.withOpacity(.62)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(.22), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: _rf(context, 12)),
          SizedBox(width: _rw(context, 3)),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: _rf(context, 10.5),
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listTopCurve(BuildContext context) {
    return Container(
      height: _rh(context, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF7A350F).withOpacity(.90),
            const Color(0xFF4B1B08).withOpacity(.98),
            const Color(0xFF3B1305).withOpacity(.99),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.elliptical(
            MediaQuery.of(context).size.width,
            _rh(context, 52),
          ),
        ),
        border: Border(
          top: BorderSide(color: _gold.withOpacity(.92), width: 1.7),
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(.24),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: EdgeInsets.only(top: _rh(context, 5)),
          width: _rw(context, 82),
          height: _rh(context, 3.5),
          decoration: BoxDecoration(
            color: _gold.withOpacity(.50),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }

  Widget _rankTile(BuildContext context, {required dynamic item, required int rank}) {
    final user = _userData(item);
    final name = _userName(item);
    final image = _profileImage(user);
    final userId = _senderId(item, user);
    final coin = _formatCoin(_totalCoin(item));
    final level = _safeText(user['level'], fallback: '0');
    final frame = _userFrame(user);

    return Container(
      color: const Color(0xFF3B1305).withOpacity(.98),
      padding: EdgeInsets.fromLTRB(
        _rw(context, 12),
        _rh(context, 3),
        _rw(context, 12),
        _rh(context, 6),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + ((rank - 4) * 22).clamp(0, 180).toInt()),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_rw(context, 20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                _rw(context, 10),
                _rh(context, 7),
                _rw(context, 10),
                _rh(context, 7),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: rank % 2 == 0
                      ? [
                    const Color(0xFF6A2A0B).withOpacity(.72),
                    const Color(0xFF3B1305).withOpacity(.88),
                  ]
                      : [
                    const Color(0xFF4E1B08).withOpacity(.76),
                    const Color(0xFF2A0C03).withOpacity(.88),
                  ],
                ),
                borderRadius: BorderRadius.circular(_rw(context, 20)),
                border: Border.all(color: _gold.withOpacity(.13), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.18),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: _rw(context, 36),
                    child: Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: _rf(context, 20),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: _rw(context, 6)),
                  _normalAvatar(
                    context,
                    imageUrl: image,
                    name: name,
                    size: _rw(context, 62),
                    framePath: frame,
                  ),
                  SizedBox(width: _rw(context, 10)),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: _rf(context, 14.8),
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: _rh(context, 6)),
                        Row(
                          children: [
                            _miniRankPill(
                              context,
                              color: const Color(0xFF557DFF),
                              text: level,
                              icon: Icons.hexagon_rounded,
                            ),
                            SizedBox(width: _rw(context, 6)),
                            _miniRankPill(
                              context,
                              color: _pink,
                              text: '${math.max(0, int.tryParse(level) ?? 0)}',
                              icon: Icons.favorite_rounded,
                            ),
                          ],
                        ),
                        SizedBox(height: _rh(context, 5)),
                        Text(
                          ('ID:$userId').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(.62),
                            fontSize: _rf(context, 11.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: _rw(context, 8)),
                  Container(
                    constraints: BoxConstraints(maxWidth: _rw(context, 82)),
                    padding: EdgeInsets.symmetric(
                      horizontal: _rw(context, 8),
                      vertical: _rh(context, 6),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.18),
                      borderRadius: BorderRadius.circular(_rw(context, 14)),
                      border: Border.all(color: _gold.withOpacity(.13)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          coin,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: _gold,
                            fontSize: _rf(context, 17.4),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: _rh(context, 2)),
                        Text(
                          ('Wealth').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(.58),
                            fontSize: _rf(context, 12.2),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _myRankBottomCard(BuildContext context, int rank) {
    return Container(
      color: const Color(0xFF3B1305).withOpacity(.98),
      padding: EdgeInsets.fromLTRB(_rw(context, 10), _rh(context, 6), _rw(context, 10), _rh(context, 14)),
      child: Container(
        padding: EdgeInsets.fromLTRB(_rw(context, 16), _rh(context, 13), _rw(context, 16), _rh(context, 13)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFC95B).withOpacity(.45),
              const Color(0xFF9A4A13).withOpacity(.76),
              const Color(0xFF3B1305).withOpacity(.92),
            ],
          ),
          borderRadius: BorderRadius.circular(_rw(context, 24)),
          border: Border.all(color: _gold.withOpacity(.78), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: _gold.withOpacity(.16),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '100+',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: _rf(context, 22),
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: _rw(context, 14)),
            Container(
              width: _rw(context, 62),
              height: _rw(context, 62),
              decoration: BoxDecoration(
                color: const Color(0xFFE9E9E9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.60), width: 1.2),
              ),
              child: Icon(Icons.person_rounded, color: Colors.grey, size: _rw(context, 38)),
            ),
            SizedBox(width: _rw(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ('vip lo').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: _rf(context, 16),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: _rh(context, 4)),
                  Row(
                    children: [
                      _miniRankPill(context, color: const Color(0xFFB8C5DF), text: '0', icon: Icons.hexagon_rounded),
                      SizedBox(width: _rw(context, 6)),
                      _miniRankPill(context, color: const Color(0xFF97A8D7), text: '0', icon: Icons.star_rounded),
                    ],
                  ),
                  SizedBox(height: _rh(context, 3)),
                  Text(
                    ('ID:11766592').appTr,
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(.64), fontSize: _rf(context, 12), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('0', style: GoogleFonts.poppins(color: _gold, fontSize: _rf(context, 21), fontWeight: FontWeight.w900)),
                Text(('Wealth').appTr, style: GoogleFonts.poppins(color: Colors.white.withOpacity(.64), fontSize: _rf(context, 13), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleAvatarWithFallback(BuildContext context, {required String imageUrl, required String name, required double size}) {
    final first = name.trim().isEmpty ? 'U': name.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEFEFEF),
        border: Border.all(color: _gold.withOpacity(.70), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Center(child: Text(first, style: GoogleFonts.poppins(color: _deepBrown, fontWeight: FontWeight.w900)))
          : CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => Center(child: Text(first, style: GoogleFonts.poppins(color: _deepBrown, fontWeight: FontWeight.w900))),
        errorWidget: (_, __, ___) => Center(child: Text(first, style: GoogleFonts.poppins(color: _deepBrown, fontWeight: FontWeight.w900))),
      ),
    );
  }

  Widget _normalAvatar(BuildContext context, {required String imageUrl, required String name, required double size, required String framePath}) {
    return SizedBox(
      width: size + _rw(context, 18),
      height: size + _rw(context, 18),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _circleAvatarWithFallback(context, imageUrl: imageUrl, name: name, size: size),
          if (framePath.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: _assetOrNetworkFrame(framePath, BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }

  Widget _assetOrNetworkFrame(String path, BoxFit fit) {
    final fixed = path.trim();
    if (fixed.isEmpty) return const SizedBox.shrink();
    final lower = fixed.toLowerCase();
    final isNetwork = lower.startsWith('http://') || lower.startsWith('https://');
    final url = isNetwork ? fixed : _safeImageUrl(fixed);

    if (lower.endsWith('.svga')) {
      if (isNetwork) {
        return SVGAEasyPlayer(resUrl: url, fit: fit);
      }
      return SVGAEasyPlayer(assetsName: fixed, fit: fit);
    }

    if (isNetwork || url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Image.asset(
      fixed,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(_rw(context, 22)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(_rw(context, 24)),
        border: Border.all(color: _gold.withOpacity(.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_rounded, color: _gold, size: _rw(context, 54)),
          SizedBox(height: _rh(context, 10)),
          Text(
            ('No ${_periodTitle()} ranking found').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: _rf(context, 15), fontWeight: FontWeight.w900),
          ),
          SizedBox(height: _rh(context, 5)),
          Text(
            ('Pull down to refresh ranking data').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(.62), fontSize: _rf(context, 12), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _userData(dynamic item) {
    try {
      if (item is Map) {
        final sender = item['sender'];
        if (sender is Map) return sender.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
        return item.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  int _totalCoin(dynamic item) {
    dynamic value;
    if (item is Map) {
      value = item['total_coin'] ?? item['wealth'] ?? item['coins'] ?? item['gifts_coins'] ?? 0;
    } else {
      value = 0;
    }
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  String _userName(dynamic item) {
    final user = _userData(item);
    return _safeText(user['name'], fallback: ('Unknown').appTr);
  }

  String _senderId(dynamic item, Map<String, dynamic> user) {
    if (item is Map) {
      final id = item['sender_id'] ?? user['user_id'] ?? user['id'];
      return _safeText(id, fallback: '0');
    }
    return _safeText(user['user_id'] ?? user['id'], fallback: '0');
  }

  String _profileImage(Map<String, dynamic> user) {
    return _safeImageUrl(user['profile_image']);
  }

  String _userFrame(Map<String, dynamic> user) {
    try {
      final assetPurchase = user['asset_purchase_history2'];
      if (assetPurchase is Map) {
        final assetBox = assetPurchase['asset'];
        if (assetBox is Map) {
          final asset = _safeText(assetBox['asset']);
          final type = _safeText(assetBox['type']).toLowerCase();
          if (asset.isNotEmpty && (type.contains('frame') || asset.toLowerCase().endsWith('.svga') || asset.toLowerCase().endsWith('.webp') || asset.toLowerCase().endsWith('.gif'))) {
            return asset;
          }
        }
      }

      final vip = user['vip_purchase_history'];
      if (vip is Map) {
        final package = vip['package'];
        if (package is Map) {
          final vipVvip = package['vip_vvip'];
          if (vipVvip is Map) {
            final frame = _safeText(vipVvip['frame']);
            if (frame.isNotEmpty) return frame;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  String _safeImageUrl(dynamic path) {
    final p = _safeText(path);
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    try {
      final url = ImageHelper.getImageUrl(p);
      if (url.trim().isEmpty || url == 'null') return '';
      return url;
    } catch (_) {
      return '';
    }
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String _formatCoin(int value) {
    if (value >= 1000000000000) return '${_trimCompact(value / 1000000000000)}T';
    if (value >= 1000000000) return '${_trimCompact(value / 1000000000)}B';
    if (value >= 1000000) return '${_trimCompact(value / 1000000)}M';
    if (value >= 1000) return '${_trimCompact(value / 1000)}K';
    return value.toString();
  }

  String _trimCompact(double value) {
    final String fixed = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return fixed.replaceAll(RegExp(r'\.0$'), '');
  }
}

class _PalaceGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFFE36F).withOpacity(.09);

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(size.width * .50, size.height * .50), size.width * (.26 + i * .08), linePaint);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(.055);
    canvas.drawCircle(Offset(size.width * .50, size.height * .17), size.width * .18, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double _rw(BuildContext context, double value) {
  final width = MediaQuery.of(context).size.width;
  return value * (width / 390).clamp(.84, 1.12);
}

double _rh(BuildContext context, double value) {
  final height = MediaQuery.of(context).size.height;
  return value * (height / 844).clamp(.82, 1.12);
}

double _rf(BuildContext context, double value) {
  final width = MediaQuery.of(context).size.width;
  return value * (width / 390).clamp(.84, 1.06);
}
