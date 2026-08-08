import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/spinkit.dart';
import '../../informationcollection/controllers/informationcollection_controller.dart';
import '../controllers/ranking_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
const Color _rankPrimary = Color(0xff6D39FF);
const Color _rankPink = Color(0xffF73A8D);
const Color _rankCyan = Color(0xff19C8FF);
const Color _rankBg = Color(0xffF6F7FF);
const Color _rankDark = Color(0xff101936);
const Color _rankMuted = Color(0xff747B92);

class RankingView extends StatefulWidget {
  const RankingView({super.key});

  @override
  State<RankingView> createState() => _RankingViewState();
}

class _RankingViewState extends State<RankingView>
    with TickerProviderStateMixin {
  late final RankingController rankingController;
  late final InformationcollectionController infoController;

  late final AnimationController _floatController;
  late final AnimationController _entryController;

  int _loadedAgencyId = 0;

  @override
  void initState() {
    super.initState();

    rankingController = Get.isRegistered<RankingController>()
        ? Get.find<RankingController>()
        : Get.put(RankingController());

    infoController = Get.isRegistered<InformationcollectionController>()
        ? Get.find<InformationcollectionController>()
        : Get.put(InformationcollectionController());

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRanking();
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _agencyData {
    try {
      final raw = verifiedController.agencySingleData;

      if (raw is RxMap) {
        return raw.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
        );
      }

      if (raw is Map) {
        return raw.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  void _loadRanking() {
    final data = _agencyData;
    final agencyId = _toInt(data['agency_id']);

    if (agencyId <= 0) return;
    if (_loadedAgencyId == agencyId) return;

    _loadedAgencyId = agencyId;

    try {
      infoController.showAgencyHostList(agencyId: agencyId);
    } catch (_) {}
  }

  Future<void> _refreshRanking() async {
    final data = _agencyData;
    final agencyId = _toInt(data['agency_id']);

    if (agencyId <= 0) return;

    try {
      infoController.showAgencyHostList(agencyId: agencyId);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 450));
  }

  double _sp(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390).clamp(.82, 1.0);
    return (value * scale).clamp(value * .78, value).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme,
          ),
        ),
        child: Scaffold(
          backgroundColor: _rankBg,
          body: Obx(() {
            return LoadingOverlay(
              isLoading: rankingController.isLoading.value,
              progressIndicator: kLoadingIndicator(),
              child: NestedScrollView(
                physics: const BouncingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      pinned: true,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      expandedHeight: 205,
                      backgroundColor: _rankPrimary,
                      flexibleSpace: FlexibleSpaceBar(
                        background: AnimatedBuilder(
                          animation: _floatController,
                          builder: (_, __) {
                            return CustomPaint(
                              painter: _RankHeaderPainter(
                                _floatController.value,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xff5728FF),
                                      Color(0xff8C42FF),
                                      Color(0xffF63E9B),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      12,
                                      18,
                                      22,
                                    ),
                                    child: Column(
                                      children: [
                                        _RankTopBar(sp: _sp),
                                        const Spacer(),

                                        _HeaderInfoCard(sp: _sp),
                                        SizedBox(height: kHeight*0.06,)
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(72),
                        child: Container(

                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: _rankBg,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 13),
                            child: _PremiumTabBar(sp: _sp),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: AnimatedBuilder(
                  animation: _entryController,
                  builder: (context, child) {
                    final value =
                    Curves.easeOutCubic.transform(_entryController.value);

                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: TabBarView(
                    children: [
                      Obx(() {
                        final list = _sortedUsers(
                          infoController.newAgencyhostList,
                          'daily_earned_coins',
                        );

                        return RefreshIndicator(
                          onRefresh: _refreshRanking,
                          child: _ProfessionalRankList(
                            users: list,
                            coinKey: 'daily_earned_coins',
                            title: ('Daily Ranking').appTr,
                            subtitle: ('Today agency diamond performance').appTr,
                            emptyText: ('No daily ranking found').appTr,
                            accent: _rankCyan,
                            sp: _sp,
                          ),
                        );
                      }),
                      Obx(() {
                        final list = _sortedUsers(
                          infoController.newAgencyManthly,
                          'monthly_earned_coins',
                        );

                        return RefreshIndicator(
                          onRefresh: _refreshRanking,
                          child: _ProfessionalRankList(
                            users: list,
                            coinKey: 'monthly_earned_coins',
                            title: ('Monthly Ranking').appTr,
                            subtitle: ('This month agency diamond performance').appTr,
                            emptyText: ('No monthly ranking found').appTr,
                            accent: _rankPink,
                            sp: _sp,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortedUsers(dynamic rawList, String coinKey) {
    final List<Map<String, dynamic>> list = [];

    try {
      if (rawList is Iterable) {
        for (final item in rawList) {
          if (item is Map) {
            list.add(
              item.map<String, dynamic>(
                    (key, value) => MapEntry(key.toString(), value),
              ),
            );
          }
        }
      }
    } catch (_) {}

    list.sort((a, b) {
      final bCoin = _coinValue(b, coinKey);
      final aCoin = _coinValue(a, coinKey);
      return bCoin.compareTo(aCoin);
    });

    return list;
  }
}

class _RankTopBar extends StatelessWidget {
  final double Function(BuildContext, double) sp;

  const _RankTopBar({required this.sp});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () => Get.back(),
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(.20),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          Text(
            ('Agency Rank').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: sp(context, 20),
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoCard extends StatelessWidget {
  final double Function(BuildContext, double) sp;

  const _HeaderInfoCard({required this.sp});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ('Top Agency Members').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: sp(context, 15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ('Daily & Monthly rank update from API data').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(.78),
                        fontSize: sp(context, 10.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.auto_graph_rounded,
                color: Colors.white,
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTabBar extends StatelessWidget {
  final double Function(BuildContext, double) sp;

  const _PremiumTabBar({required this.sp});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _rankPrimary.withOpacity(.10),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            colors: [
              Color(0xff6D39FF),
              Color(0xffF73A8D),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _rankPink.withOpacity(.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _rankMuted,
        labelStyle: GoogleFonts.poppins(
          fontSize: sp(context, 12.5),
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: sp(context, 12.5),
          fontWeight: FontWeight.w700,
        ),
        tabs:  [
          Tab(text: ('Daily').appTr),
          Tab(text: ('Monthly').appTr),
        ],
      ),
    );
  }
}

class _ProfessionalRankList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String coinKey;
  final String title;
  final String subtitle;
  final String emptyText;
  final Color accent;
  final double Function(BuildContext, double) sp;

  const _ProfessionalRankList({
    required this.users,
    required this.coinKey,
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.accent,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 30),
        children: [
          _EmptyRankCard(
            text: emptyText,
            sp: sp,
          ),
        ],
      );
    }

    final topUsers = users.take(3).toList();
    final restUsers =
    users.length > 3 ? users.sublist(3) : <Map<String, dynamic>>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        _SectionTitle(
          title: title,
          subtitle: subtitle,
          accent: accent,
          sp: sp,
        ),
        const SizedBox(height: 14),
        _PodiumSection(
          users: topUsers,
          coinKey: coinKey,
          sp: sp,
        ),
        const SizedBox(height: 18),
        if (restUsers.isNotEmpty)
          ...List.generate(restUsers.length, (index) {
            final realRank = index + 4;
            return _RankUserTile(
              user: restUsers[index],
              rank: realRank,
              coinKey: coinKey,
              sp: sp,
            );
          }),
        if (restUsers.isEmpty)
          _OnlyTopRankCard(
            text: ('Only top ${topUsers.length} member found').appTr,
            sp: sp,
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final double Function(BuildContext, double) sp;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 39,
          width: 39,
          decoration: BoxDecoration(
            color: accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.leaderboard_rounded,
            color: accent,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: _rankDark,
                  fontSize: sp(context, 16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: _rankMuted,
                  fontSize: sp(context, 10.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PodiumSection extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String coinKey;
  final double Function(BuildContext, double) sp;

  const _PodiumSection({
    required this.users,
    required this.coinKey,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    final first = users.isNotEmpty ? users[0] : null;
    final second = users.length > 1 ? users[1] : null;
    final third = users.length > 2 ? users[2] : null;

    final width = MediaQuery.of(context).size.width;

    final sectionHeight = (width * .63).clamp(222.0, 252.0);
    final firstHeight = (sectionHeight * .90).clamp(198.0, 226.0);
    final secondHeight = (firstHeight - 24).clamp(174.0, 202.0);
    final thirdHeight = (firstHeight - 38).clamp(160.0, 188.0);

    return SizedBox(
      height: sectionHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second == null
                ? const SizedBox.shrink()
                : _TopRankCard(
              user: second,
              rank: 2,
              coinKey: coinKey,
              height: secondHeight,
              avatarSize: (width * .125).clamp(44.0, 52.0),
              topCapHeight: 30,
              colors: const [
                Color(0xff61DFFF),
                Color(0xff2A73FF),
              ],
              accent: const Color(0xffBFEFFF),
              sp: sp,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: first == null
                ? const SizedBox.shrink()
                : _TopRankCard(
              user: first,
              rank: 1,
              coinKey: coinKey,
              height: firstHeight,
              avatarSize: (width * .155).clamp(56.0, 64.0),
              topCapHeight: 34,
              colors: const [
                Color(0xffFFE06A),
                Color(0xffFF9D2E),
                Color(0xffFF6C2C),
              ],
              accent: const Color(0xffFFF3BC),
              sp: sp,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: third == null
                ? const SizedBox.shrink()
                : _TopRankCard(
              user: third,
              rank: 3,
              coinKey: coinKey,
              height: thirdHeight,
              avatarSize: (width * .115).clamp(40.0, 48.0),
              topCapHeight: 28,
              colors: const [
                Color(0xffFF86C5),
                Color(0xffCB51FF),
              ],
              accent: const Color(0xffFFD2EA),
              sp: sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRankCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int rank;
  final String coinKey;
  final double height;
  final double avatarSize;
  final double topCapHeight;
  final List<Color> colors;
  final Color accent;
  final double Function(BuildContext, double) sp;

  const _TopRankCard({
    required this.user,
    required this.rank,
    required this.coinKey,
    required this.height,
    required this.avatarSize,
    required this.topCapHeight,
    required this.colors,
    required this.accent,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    final name = _safeText(user['name'], fallback: ('User').appTr);
    final profile = _imageUrl(user['profile_image']);
    final coin = _formatCoin(_coinValue(user, coinKey));

    final bool isFirst = rank == 1;
    final double radius = isFirst ? 25 : 23;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(isFirst ? .24 : .18),
            blurRadius: isFirst ? 24 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: _SmoothFourCornerHouseClipper(
          radius: radius,
          topCapHeight: topCapHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HouseCardPatternPainter(
                    rank: rank,
                    accent: accent,
                  ),
                ),
              ),

              Positioned(
                top: 8,
                left: 8,
                right: 8,
                height: topCapHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(.17),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Icon(
                  isFirst
                      ? Icons.workspace_premium_rounded
                      : Icons.military_tech_rounded,
                  color: Colors.white,
                  size: isFirst ? 30 : 25,
                ),
              ),

              Positioned.fill(
                top: topCapHeight + 13,
                left: 8,
                right: 8,
                bottom: 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: isFirst ? 26 : 23,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.22),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(.30),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: sp(context, isFirst ? 12.5 : 11),
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),

                    SizedBox(height: isFirst ? 9 : 7),

                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: avatarSize + 14,
                          width: avatarSize + 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.17),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.30),
                              width: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          height: avatarSize + 6,
                          width: avatarSize + 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.24),
                            shape: BoxShape.circle,
                          ),
                        ),
                        _RankAvatar(
                          imageUrl: profile,
                          name: name,
                          size: avatarSize,
                          frameData: user['asset_purchase_history'],
                        ),
                      ],
                    ),

                    SizedBox(height: isFirst ? 8 : 6),

                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: sp(context, isFirst ? 12.2 : 10.8),
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Container(
                      constraints: const BoxConstraints(maxWidth: 88),
                      padding: EdgeInsets.symmetric(
                        horizontal: isFirst ? 8 : 7,
                        vertical: isFirst ? 5 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.18),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withOpacity(.14),
                        ),
                      ),
                      child: Text(
                        ('$coin Diamonds').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(.95),
                          fontSize: sp(context, isFirst ? 9 : 8),
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),

                    const Spacer(),

                    Container(
                      height: isFirst ? 6 : 5,
                      width: isFirst ? 48 : 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.26),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
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

class _RankUserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final int rank;
  final String coinKey;
  final double Function(BuildContext, double) sp;

  const _RankUserTile({
    required this.user,
    required this.rank,
    required this.coinKey,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    final name = _safeText(user['name'], fallback: ('User').appTr);
    final country = _safeText(user['country'], fallback: ('Unknown').appTr);
    final profile = _imageUrl(user['profile_image']);
    final coin = _formatCoin(_coinValue(user, coinKey));
    final userType = _safeText(user['user_type'], fallback: 'member');

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _rankPrimary.withOpacity(.065),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _rankPrimary.withOpacity(.14),
                      _rankPink.withOpacity(.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$rank',
                  style: GoogleFonts.poppins(
                    color: _rankPrimary,
                    fontSize: sp(context, 12.5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              _RankAvatar(
                imageUrl: profile,
                name: name,
                size: 46,
                frameData: user['asset_purchase_history'],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _rankDark,
                        fontSize: sp(context, 13.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: _rankMuted,
                              fontSize: sp(context, 9.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffF5F2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            userType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: _rankPrimary,
                              fontSize: sp(context, 8.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    coin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _rankPink,
                      fontSize: sp(context, 12.5),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ('Diamonds').appTr,
                    style: GoogleFonts.poppins(
                      color: _rankMuted,
                      fontSize: sp(context, 8.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double size;
  final dynamic frameData;

  const _RankAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
    required this.frameData,
  });

  @override
  Widget build(BuildContext context) {
    final frameUrl = _frameUrl(frameData);
    final firstLetter =
    name.trim().isEmpty ? 'U': name.trim().substring(0, 1).toUpperCase();

    return SizedBox(
      height: size + 8,
      width: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: size + 7,
            width: size + 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xff6D39FF),
                  Color(0xffF73A8D),
                ],
              ),
            ),
          ),
          Container(
            height: size,
            width: size,
            decoration: const BoxDecoration(
              color: Color(0xffEEF1FA),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: Text(
                    firstLetter,
                    style: GoogleFonts.poppins(
                      color: _rankPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Text(
                    firstLetter,
                    style: GoogleFonts.poppins(
                      color: _rankPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                fadeInDuration: Duration.zero,
              ),
            ),
          ),
          if (frameUrl != null)
            CachedNetworkImage(
              imageUrl: frameUrl,
              height: size + 8,
              width: size + 8,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
              fadeInDuration: Duration.zero,
            ),
        ],
      ),
    );
  }
}

class _EmptyRankCard extends StatelessWidget {
  final String text;
  final double Function(BuildContext, double) sp;

  const _EmptyRankCard({
    required this.text,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 245,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _rankPrimary.withOpacity(.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: const Color(0xffF2EEFF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.leaderboard_outlined,
              color: _rankPrimary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _rankDark,
              fontSize: sp(context, 15),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ('Pull down to refresh ranking data').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _rankMuted,
              fontSize: sp(context, 10.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlyTopRankCard extends StatelessWidget {
  final String text;
  final double Function(BuildContext, double) sp;

  const _OnlyTopRankCard({
    required this.text,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: _rankMuted,
          fontSize: sp(context, 11.5),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RankHeaderPainter extends CustomPainter {
  final double t;

  _RankHeaderPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(.17)
      ..style = PaintingStyle.fill;

    final shift = math.sin(t * math.pi) * 7;

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        canvas.drawCircle(
          Offset(size.width * .73 + col * 14, size.height * .24 + row * 14),
          1.9,
          dotPaint,
        );
      }
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withOpacity(.09);

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * .96, -8 + shift),
        42 + (i * 17),
        ringPaint,
      );
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(.065);

    canvas.drawCircle(
      Offset(size.width * .08, size.height * .30 + shift),
      38,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RankHeaderPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _HouseCardPatternPainter extends CustomPainter {
  final int rank;
  final Color accent;

  _HouseCardPatternPainter({
    required this.rank,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.13);

    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * .93, size.height * .13),
        24 + (i * 14),
        ringPaint,
      );
    }

    final shinePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(.09);

    canvas.drawCircle(
      Offset(size.width * .14, size.height * .23),
      16,
      shinePaint,
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(.15);

    final path = Path()
      ..moveTo(size.width * .14, size.height * .80)
      ..quadraticBezierTo(
        size.width * .45,
        size.height * .72,
        size.width * .86,
        size.height * .79,
      );

    canvas.drawPath(path, linePaint);

    final diamondPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withOpacity(.18);

    final cx = size.width * .17;
    final cy = size.height * .12;
    final r = rank == 1 ? 8.0 : 6.5;

    final diamond = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    canvas.drawPath(diamond, diamondPaint);
  }

  @override
  bool shouldRepaint(covariant _HouseCardPatternPainter oldDelegate) {
    return oldDelegate.rank != rank || oldDelegate.accent != accent;
  }
}

class _SmoothFourCornerHouseClipper extends CustomClipper<Path> {
  final double radius;
  final double topCapHeight;

  _SmoothFourCornerHouseClipper({
    required this.radius,
    required this.topCapHeight,
  });

  @override
  Path getClip(Size size) {
    final r = radius.clamp(18.0, 30.0);
    final topSoft = topCapHeight.clamp(24.0, size.height * .24);

    final path = Path();

    path.moveTo(r, 0);

    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(
      size.width,
      0,
      size.width,
      r,
    );

    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - r,
      size.height,
    );

    path.lineTo(r, size.height);
    path.quadraticBezierTo(
      0,
      size.height,
      0,
      size.height - r,
    );

    path.lineTo(0, r);
    path.quadraticBezierTo(
      0,
      0,
      r,
      0,
    );

    path.close();

    final roofPath = Path()
      ..moveTo(r + 8, topSoft)
      ..quadraticBezierTo(
        size.width * .50,
        topSoft - 10,
        size.width - r - 8,
        topSoft,
      );

    return Path.combine(
      PathOperation.union,
      path,
      roofPath,
    );
  }

  @override
  bool shouldReclip(covariant _SmoothFourCornerHouseClipper oldClipper) {
    return oldClipper.radius != radius ||
        oldClipper.topCapHeight != topCapHeight;
  }
}

int _coinValue(Map<String, dynamic> user, String coinKey) {
  final value = user[coinKey] ??
      user['earned_coins'] ??
      user['gifts_coins'] ??
      user['coins'] ??
      0;

  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
}

String _safeText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

String _formatCoin(int value) {
  if (value >= 1000000000000) {
    return '${(value / 1000000000000).toStringAsFixed(1)}T';
  }

  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }

  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }

  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }

  return value.toString();
}

String _imageUrl(dynamic path) {
  try {
    return ImageHelper.getImageUrl(path?.toString() ?? '');
  } catch (_) {
    return '';
  }
}

String? _frameUrl(dynamic frameData) {
  try {
    if (frameData is! Map) return null;

    final assetBox = frameData['asset'];
    if (assetBox is! Map) return null;

    final asset = assetBox['asset'];
    if (asset == null) return null;

    final url = ImageHelper.getImageUrl(asset.toString());
    if (url.trim().isEmpty || url == 'null') return null;

    return url;
  } catch (_) {
    return null;
  }
}