import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/Flower.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/FlowingList.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/base_medal_view.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/game_test.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/managerDashbord.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/menuiconPage.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/secoundCard.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/vipcarddesign.dart'
    hide kAppColor2;


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../Cp/views/cp_view.dart';

import '../../InvitePage/view/invite_view.dart';

import '../../backpack/views/BackPack.dart';

import '../../home/views/widgets/unicId2.dart';

import '../../livestream/widgets/audioText.dart';
import '../../myprofile/views/myprofile_view.dart';

import '../../record/views/record_view.dart';
import '../../registersteps/controllers/registersteps_controller.dart';
import '../../reseller/views/reselerView.dart';
import '../../setting/views/setting_view.dart';
import '../../setting/views/widgets/about_page.dart';

import '../../svip/views/svip_view.dart';
import '../../svip/controllers/svip_controller.dart';

import '../../verified/controllers/verified_controller.dart';
import '../../withdraw/views/lanelpage.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

const bool kPlayStoreSafeMode = true;

num _safeUserCoins() {
  final dynamic rawCoins = authController.userProfile.value.user?.levelCoins;

  if (rawCoins == null) {
    return 0;
  }

  if (rawCoins is num) {
    return rawCoins;
  }

  return num.tryParse(rawCoins.toString().trim()) ?? 0;
}

bool _canShowRechargeInviteByCoins() {
  return _safeUserCoins() >= 10;
}

// data.vip_level.title_image_url => card image
// ===============================================================

const String _kDefaultVipMenuImage =
    'assets/frame/17775973319631774478394818vip6.webp';

// ✅ VIP WORK: current auth user id safe int convert
int _currentAuthUserId() {
  final dynamic rawId = authController.userProfile.value.user?.id;

  if (rawId is num) {
    return rawId.toInt();
  }

  return int.tryParse(rawId?.toString().trim() ?? '') ?? 0;
}

int _safeAuthProfileCount(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

int _authTotalFollowers() {
  final dynamic user = authController.userProfile.value.user;
  if (user == null) return 0;

  try {
    final value = user.totalFollowers;
    final count = _safeAuthProfileCount(value);
    if (count >= 0) return count;
  } catch (_) {}

  try {
    final value = user.followersCount;
    final count = _safeAuthProfileCount(value);
    if (count >= 0) return count;
  } catch (_) {}

  return 0;
}

int _authTotalFollowing() {
  final dynamic user = authController.userProfile.value.user;
  if (user == null) return 0;

  final values = <dynamic>[];

  try {
    values.add(user.totalFollowing);
  } catch (_) {}
  try {
    values.add(user.totalFollowings);
  } catch (_) {}
  try {
    values.add(user.followingCount);
  } catch (_) {}
  try {
    values.add(user.total_following);
  } catch (_) {}

  for (final value in values) {
    final count = _safeAuthProfileCount(value);
    if (count > 0) return count;
  }

  return 0;
}


int _authTotalVisitors() {
  final dynamic user = authController.userProfile.value.user;
  if (user == null) return 0;

  final values = <dynamic>[];

  try {
    values.add(user.totalVisitors);
  } catch (_) {}
  try {
    values.add(user.visitorCount);
  } catch (_) {}
  try {
    values.add(user.totalVisitor);
  } catch (_) {}
  try {
    values.add(user.profileVisitors);
  } catch (_) {}

  for (final value in values) {
    final count = _safeAuthProfileCount(value);
    if (count > 0) return count;
  }

  return 0;
}

// ✅ VIP WORK: any dynamic value ke safe int bananor helper
int _safeVipMenuInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

// ✅ VIP WORK: current VIP data logged-in user-er kina check
bool _vipDataBelongsToUser(dynamic vipData, int userId) {
  if (userId <= 0 || vipData is! Map) return false;

  final map = Map<String, dynamic>.from(vipData);
  return _safeVipMenuInt(map['user_id']) == userId;
}

// ✅ VIP WORK: API date parse helper
DateTime? _parseVipMenuDate(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;

  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

// ✅ VIP WORK: VIP active kina check
bool _isVipActiveForMenu(dynamic value) {
  if (value is! Map) return false;

  final map = Map<String, dynamic>.from(value);
  final String status = (map['status'] ?? '').toString().trim().toLowerCase();
  final dynamic rawActive = map['is_active'];

  final bool isActive =
      rawActive == true ||
          rawActive == 1 ||
          rawActive?.toString().trim().toLowerCase() == 'true' ||
          status == 'active';

  if (!isActive || map['vip_level'] is! Map) {
    return false;
  }

  final DateTime? expiresAt = _parseVipMenuDate(map['expires_at']);
  if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
    return false;
  }

  return true;
}

// ✅ VIP WORK: vip_level map safe way te get
Map<String, dynamic> _vipLevelForMenu(dynamic vipData) {
  if (!_isVipActiveForMenu(vipData)) return <String, dynamic>{};

  final dynamic level = (vipData as Map)['vip_level'];
  if (level is Map<String, dynamic>) return level;
  if (level is Map) return Map<String, dynamic>.from(level);

  return <String, dynamic>{};
}

// ✅ VIP WORK: network/asset/backend relative path clean kore final image path return
String _cleanVipMenuImage(dynamic value) {
  final String path = value?.toString().trim() ?? '';

  if (path.isEmpty || path.toLowerCase() == 'null') {
    return _kDefaultVipMenuImage;
  }

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  if (path.startsWith('assets/')) {
    return path;
  }

  return ImageHelper.getImageUrl(path);
}

// ✅ VIP WORK: card title dynamic
// Priority: vip_level.title > vip_level.name > vip_type > VIP
String _vipMenuTitle(dynamic vipData) {
  if (!_isVipActiveForMenu(vipData)) return 'VIP'.appTr;

  final Map<String, dynamic> level = _vipLevelForMenu(vipData);
  final String title =
  (level['title'] ??
      level['name'] ??
      (vipData as Map)['vip_type'] ??
      'VIP'.appTr)
      .toString()
      .trim();

  if (title.isEmpty || title.toLowerCase() == 'null') return 'VIP'.appTr;
  return title.appTr;
}

// ✅ VIP WORK: card validity dynamic
// Main: API er "day" show korbe. Example: day: 7 => 7 Days
// Fallback: remaining_days
String _vipMenuValidity(Map<String, dynamic>? vipData, {bool loading = false}) {
  if (loading && vipData == null) {
    return 'Loading...'.appTr;
  }

  if (vipData == null || vipData.isEmpty || !_isVipActiveForMenu(vipData)) {
    return 'No Active VIP'.appTr;
  }

  final int totalDays = _safeVipMenuInt(vipData['day']);
  if (totalDays > 0) {
    return '$totalDays ${totalDays == 1 ? 'Day'.appTr : 'Days'.appTr}';
  }

  final int remainingDays = _safeVipMenuInt(vipData['remaining_days']);
  if (remainingDays > 0) {
    return '$remainingDays ${remainingDays == 1 ? 'Day'.appTr : 'Days'.appTr}';
  }

  return 'Active'.appTr;
}

// ✅ VIP WORK: card image dynamic
// Priority: title_image_url > title_image > badge_image_url > badge_image > default asset
String _vipMenuTitleImage(dynamic vipData) {
  if (!_isVipActiveForMenu(vipData)) {
    return _kDefaultVipMenuImage;
  }

  final Map<String, dynamic> level = _vipLevelForMenu(vipData);

  return _cleanVipMenuImage(
    level['badge_image'] ??
        level['badge_image'] ??
        level['badge_image_url'] ??
        level['badge_image'] ??
        _kDefaultVipMenuImage,
  );
}

// Active VIP na thakle profile row-te kono fake/default VIP image show korbe na.
String _activeVipProfileTitleImage(dynamic vipData) {
  if (!_isVipActiveForMenu(vipData)) return '';

  final Map<String, dynamic> level = _vipLevelForMenu(vipData);

  final String rawPath =
  (level['title_image_url'] ??
      level['title_image'] ??
      level['badge_image_url'] ??
      level['badge_image'] ??
      '')
      .toString()
      .trim();

  if (rawPath.isEmpty || rawPath.toLowerCase() == 'null') return '';

  return _cleanVipMenuImage(rawPath);
}

Widget _currentVipTitleImageBadge() {
  return Obx(() {
    final int userId = _currentAuthUserId();

    final Map<String, dynamic>? cachedVip = userId > 0
        ? homeController.currentVipForUser(userId)
        : null;

    final Map<String, dynamic>? currentVip =
        homeController.vipCurrentData.value;

    final Map<String, dynamic>? vipData =
        cachedVip ??
            (_vipDataBelongsToUser(currentVip, userId) ? currentVip : null);

    final String imagePath = _activeVipProfileTitleImage(vipData);

    if (imagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    final double badgeHeight = kHeight * 0.039;
    final double badgeWidth = kWeight * 0.23;

    Widget imageWidget;

    if (imagePath.toLowerCase().endsWith('.svga')) {
      imageWidget = SVGAEasyPlayer(resUrl: imagePath, fit: BoxFit.contain);
    } else if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        memCacheWidth: 260,
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      );
    } else {
      imageWidget = Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    }

    return Container(
      height: badgeHeight,
      width: badgeWidth,
      alignment: Alignment.center,
      margin: EdgeInsets.only(left: kWeight * 0.010),
      child: RepaintBoundary(child: imageWidget),
    );
  });
}

// ===============================================================
// ✅ VIP MENU CARD DYNAMIC SYSTEM - END
// ===============================================================

class AppmenuView extends StatefulWidget {
  const AppmenuView({super.key});

  @override
  State<AppmenuView> createState() => _AppmenuViewState();
}

class _AppmenuViewState extends State<AppmenuView>
    with AutomaticKeepAliveClientMixin<AppmenuView> {
  bool _initialDataRequested = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<VerifiedController>()) {
      Get.put(VerifiedController());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialDataRequested) return;
      _initialDataRequested = true;
      _loadInitialPageData();
    });
  }

  Future<void> _loadInitialPageData() async {
    try {
      await homeController.baseList();
    } catch (_) {}

    final int userId = _currentAuthUserId();
    if (userId <= 0) return;

    try {
      await homeController.fetchUserCurrentVip(
        userId: userId,
        force: false,
        silent: true,
      );
    } catch (_) {}
  }

  Future<void> _refreshPage() async {
    await Future.wait<dynamic>([
      registerstepsController.refreshAuthUserData(),
      homeController.baseList(),
    ]);

    final int userId = _currentAuthUserId();
    if (userId <= 0) return;

    await homeController.fetchUserCurrentVip(
      userId: userId,
      force: true,
      silent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (kDebugMode) {
      final String token =
          authController.userProfile.value.token?.toString().trim() ?? '';
      debugPrint(
        'App menu auth: token_present=${token.isNotEmpty} '
            'token_length=${token}',
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomRefreshIndicator(
        onRefresh: _refreshPage,
        builder:
            (
            BuildContext context,
            Widget child,
            IndicatorController refreshController,
            ) {
          return Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: refreshController,
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.asset(
                        appLogo,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                  builder: (context, child) {
                    if (refreshController.isIdle) {
                      return const SizedBox.shrink();
                    }

                    final double value = refreshController.value.clamp(
                      0.0,
                      1.0,
                    );

                    return SizedBox(
                      height: value * 80,
                      child: Center(
                        child: Transform.scale(
                          scale: value,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: kAppColor,
                              shape: BoxShape.circle,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Existing app background image remains visible at the top.
            // Lower area softly fades into the warm white reference background.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.00, 0.18, 0.31, 0.43, 0.58, 1.00],
                      colors: [
                        Colors.transparent,
                        Color(0x18FFFFFF),
                        Color(0x76FFFDF8),
                        Color(0xE8FFFDF8),
                        Color(0xFFFFFDF8),
                        Color(0xFFFFFDF8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: const _FastAppMenuScrollBehavior(),
                child: ListView.custom(
                  key: const PageStorageKey<String>('app_menu_scroll_position'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  cacheExtent: MediaQuery.sizeOf(context).height * .85,
                  childrenDelegate: SliverChildBuilderDelegate(
                    _buildPageSection,
                    childCount: 6,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageSection(BuildContext context, int index) {
    switch (index) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: kHeight * .060),
            RepaintBoundary(child: Obx(_profileInfoHeaderCard)),
            SizedBox(height: kHeight * .006),
          ],
        );

      case 1:
        return RepaintBoundary(
          child: Obx(
                () => Padding(
              padding: EdgeInsets.symmetric(horizontal: kWeight * .045),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Get.to(FollowinfList()),
                      child: _statTile(
                        '${_authTotalFollowing()}',
                        'Follow'.appTr,
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Get.to(Follower(), transition: Transition.rightToLeft);
                      },
                      child: _statTile(
                        '${_authTotalFollowers()}',
                        'Fans'.appTr,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _statTile(
                      '${_authTotalVisitors()}',
                      'Visitor'.appTr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case 2:
        return Padding(
          padding: EdgeInsets.only(top: kHeight * .022),
          child: RepaintBoundary(
            child: Obx(() {
              final int userId = _currentAuthUserId();

              final Map<String, dynamic>? cachedVip = userId > 0
                  ? homeController.currentVipForUser(userId)
                  : null;

              final Map<String, dynamic>? currentVip =
                  homeController.vipCurrentData.value;

              final Map<String, dynamic>? vipData =
                  cachedVip ??
                      (_vipDataBelongsToUser(currentVip, userId)
                          ? currentVip
                          : null);

              final bool isLoading =
                  userId > 0 &&
                      (homeController.userCurrentVipLoadingIds.contains(userId) ||
                          homeController.vipCurrentLoading.value);

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Get.to(SvipView(), transition: Transition.rightToLeft);
                },
                child: premiumVipValidityCard(
                  kHeight: kHeight,
                  kWeight: kWeight,
                  title: _vipMenuTitle(vipData),
                  validity: _vipMenuValidity(vipData, loading: isLoading),
                  imagePath: _vipMenuTitleImage(vipData),
                  onTapVip: () {
                    Get.to(
                      SvipView(mode: VipSectionMode.vip),
                      transition: Transition.rightToLeft,
                    );
                  },
                  onTapSvip: () {
                    Get.to(
                      SvipView(mode: VipSectionMode.svip),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
              );
            }),
          ),
        );

      case 3:
        return Padding(
          padding: EdgeInsets.fromLTRB(
            kWeight * .03,
            kHeight * .018,
            kWeight * .03,
            0,
          ),
          child: RepaintBoundary(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.97),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.020),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General Tools'.appTr,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26272B),
                      fontSize: (kHeight * .020).clamp(16.0, 19.0).toDouble(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: kHeight * .016),
                  premiumShortcutMenu(
                    kHeight: kHeight,
                    kWeight: kWeight,
                  ),
                  SizedBox(height: kHeight * .006),
                  secoundPremiumShortcutMenu(
                    kHeight: kHeight,
                    kWeight: kWeight,
                  ),
                ],
              ),
            ),
          ),
        );

      case 4:
        return Padding(
          padding: EdgeInsets.fromLTRB(
            kWeight * .03,
            kHeight * .018,
            kWeight * .03,
            0,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * .018,
              vertical: kHeight * .006,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.98),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.018),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Obx(() {
                  final bool isReseller =
                      authController.userProfile.value.user?.reselerType
                          ?.toString()
                          .toLowerCase() ==
                          'reseller';

                  if (!isReseller) {
                    return const SizedBox.shrink();
                  }

                  return _referenceMenuRow(
                    text: 'Coin Seller'.appTr,
                    image: 'assets/newaudio/coinSeller.png',
                    onTap: () {
                      Get.to(
                        Reselerview(),
                        transition: Transition.rightToLeft,
                      );
                    },
                  );
                }),
                // _referenceMenuRow(
                //   text: 'Earnings'.appTr,
                //   image: 'assets/images/earnings.png',
                //   onTap: homeController.showEarningData,
                // ),
                _referenceMenuRow(
                  text: 'Record'.appTr,
                  image: 'assets/newaudio/record.png',
                  onTap: () {
                    Get.to(
                      RecordView(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _referenceMenuRow(
                  text: 'My Item'.appTr,
                  image: 'assets/newaudio/myIteam.png',
                  onTap: () {
                    Get.to(
                      Backpack(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _referenceMenuRow(
                  text: 'Verified'.appTr,
                  image: 'assets/newaudio/hostt.png',
                  onTap: homeController.showHostStatusList,
                ),
                Obx(() {
                  if (!_canShowRechargeInviteByCoins()) {
                    return const SizedBox.shrink();
                  }

                  return _referenceMenuRow(
                    text: 'Invite'.appTr,
                    image: 'assets/newaudio/inv.png',
                    onTap: () {
                      Get.to(
                        InviteEarnPage(),
                        transition: Transition.rightToLeft,
                      );
                    },
                  );
                }),
                _referenceMenuRow(
                  text: 'My Level'.appTr,
                  image: 'assets/images/lv.png',
                  onTap: () {
                    Get.to(
                      MyLevelPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _referenceMenuRow(
                  text: 'About Us'.appTr,
                  image: 'assets/newaudio/about.png',
                  onTap: () {
                    Get.to(
                      AboutUsPage(),
                      transition: Transition.rightToLeft,
                    );
                  },
                ),
                _referenceMenuRow(
                  text: 'Settings'.appTr,
                  image: 'assets/newaudio/seettings.png',
                  onTap: () {
                    Get.to(
                      SettingView(),
                      transition: Transition.rightToLeft,
                    );
                  },
                  showDivider: false,
                ),
              ],
            ),
          ),
        );

      default:
        return SizedBox(height: kHeight * .07);
    }
  }

  Widget _referenceMenuRow({
    required String text,
    required String image,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: (kHeight * .060).clamp(49.0, 58.0).toDouble(),
              child: Row(
                children: [
                  SizedBox(width: kWeight * .022),
                  SizedBox(
                    width: kHeight * .030,
                    height: kHeight * .030,
                    child: Image.asset(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.circle_outlined,
                        color: Color(0xFF55575C),
                      ),
                    ),
                  ),
                  SizedBox(width: kWeight * .021),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF2B2C30),
                        fontSize:
                        (kHeight * .0162).clamp(13.0, 15.5).toDouble(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFFA2A4A8),
                    size: kHeight * .020,
                  ),
                  SizedBox(width: kWeight * .024),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: .55,
            indent: kWeight * .078,
            endIndent: kWeight * .018,
            color: const Color(0xFFF1F1F1),
          ),
      ],
    );
  }

  Widget _statTile(String value, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .018,
        vertical: kHeight * .008,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: (Get.height * .020).clamp(16.0, 20.0).toDouble(),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B4D23),
            ),
          ),
          SizedBox(height: kHeight * .002),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: (Get.height * .0155).clamp(12.0, 15.0).toDouble(),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B4936),
            ),
          ),
        ],
      ),
    );
  }
}

class _FastAppMenuScrollBehavior extends MaterialScrollBehavior {
  const _FastAppMenuScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}

Widget premiumGlassCard({required Widget child, double radius = 28}) {
  return RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.34),
            const Color(0xffB460F0).withOpacity(0.22),
            const Color(0xff6A4CFF).withOpacity(0.20),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff8A4CF7).withOpacity(0.24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    ),
  );
}

bool _isRegionalIndicator(int rune) {
  return rune >= 0x1F1E6 && rune <= 0x1F1FF;
}

String _flagFromCode(String code) {
  final cleanCode = code.trim().toUpperCase();

  if (!RegExp(r'^[A-Z]{2}$').hasMatch(cleanCode)) {
    return '🌐';
  }

  return String.fromCharCodes(cleanCode.codeUnits.map((unit) => unit + 127397));
}

String _extractEmojiFlag(String raw) {
  final runes = raw.runes.toList();

  for (int i = 0; i < runes.length - 1; i++) {
    if (_isRegionalIndicator(runes[i]) && _isRegionalIndicator(runes[i + 1])) {
      return String.fromCharCodes([runes[i], runes[i + 1]]);
    }
  }

  return '';
}

String _removeEmojiFlag(String raw) {
  final buffer = StringBuffer();

  for (final rune in raw.runes) {
    if (!_isRegionalIndicator(rune)) {
      buffer.write(String.fromCharCode(rune));
    }
  }

  return buffer.toString();
}

String cleanCountryName(String? country) {
  final raw = country?.trim() ?? '';

  if (raw.isEmpty ||
      raw.toLowerCase() == 'null' ||
      raw.toLowerCase() == 'add country') {
    return '';
  }

  String cleaned = raw;

  // Backend jodi "🇧🇩 Bangladesh" save kore, emoji flag remove hobe.
  cleaned = _removeEmojiFlag(cleaned);

  // Remove code in brackets: Bangladesh (BD)
  cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');

  // Remove prefix code: BD - Bangladesh / BD, Bangladesh
  cleaned = cleaned.replaceFirst(RegExp(r'^[A-Za-z]{2}\s*[-,]\s*'), '');

  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (RegExp(r'^[A-Za-z]{2}$').hasMatch(cleaned)) {
    return cleaned.toUpperCase();
  }

  return cleaned;
}

String getCountryFlag(String? country) {
  final raw = country?.trim() ?? '';
  final value = raw.toLowerCase();

  if (value.isEmpty || value == 'add country' || value == 'null') {
    return '🌐';
  }

  // Backend direct emoji flag save korle: 🇧🇩 or 🇧🇩 Bangladesh
  final emojiFlag = _extractEmojiFlag(raw);
  if (emojiFlag.isNotEmpty) {
    return emojiFlag;
  }

  // Backend country code save korle: BD, US, GB
  final onlyCode = raw.trim().toUpperCase();
  if (RegExp(r'^[A-Z]{2}$').hasMatch(onlyCode)) {
    return _flagFromCode(onlyCode);
  }

  final normalized = cleanCountryName(raw)
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final Map<String, String> countryMap = {
    'afghanistan': 'AF',
    'aland islands': 'AX',
    'albania': 'AL',
    'algeria': 'DZ',
    'american samoa': 'AS',
    'andorra': 'AD',
    'angola': 'AO',
    'anguilla': 'AI',
    'antarctica': 'AQ',
    'antigua and barbuda': 'AG',
    'argentina': 'AR',
    'armenia': 'AM',
    'aruba': 'AW',
    'australia': 'AU',
    'austria': 'AT',
    'azerbaijan': 'AZ',
    'bahamas': 'BS',
    'bahrain': 'BH',
    'bangladesh': 'BD',
    'bd': 'BD',
    'barbados': 'BB',
    'belarus': 'BY',
    'belgium': 'BE',
    'belize': 'BZ',
    'benin': 'BJ',
    'bermuda': 'BM',
    'bhutan': 'BT',
    'bolivia': 'BO',
    'bosnia and herzegovina': 'BA',
    'botswana': 'BW',
    'brazil': 'BR',
    'british indian ocean territory': 'IO',
    'brunei': 'BN',
    'bulgaria': 'BG',
    'burkina faso': 'BF',
    'burundi': 'BI',
    'cambodia': 'KH',
    'cameroon': 'CM',
    'canada': 'CA',
    'cape verde': 'CV',
    'cayman islands': 'KY',
    'central african republic': 'CF',
    'chad': 'TD',
    'chile': 'CL',
    'china': 'CN',
    'christmas island': 'CX',
    'cocos islands': 'CC',
    'colombia': 'CO',
    'comoros': 'KM',
    'congo': 'CG',
    'democratic republic of the congo': 'CD',
    'cook islands': 'CK',
    'costa rica': 'CR',
    'cote d ivoire': 'CI',
    'ivory coast': 'CI',
    'croatia': 'HR',
    'cuba': 'CU',
    'cyprus': 'CY',
    'czech republic': 'CZ',
    'czechia': 'CZ',
    'denmark': 'DK',
    'djibouti': 'DJ',
    'dominica': 'DM',
    'dominican republic': 'DO',
    'ecuador': 'EC',
    'egypt': 'EG',
    'el salvador': 'SV',
    'equatorial guinea': 'GQ',
    'eritrea': 'ER',
    'estonia': 'EE',
    'ethiopia': 'ET',
    'falkland islands': 'FK',
    'faroe islands': 'FO',
    'fiji': 'FJ',
    'finland': 'FI',
    'france': 'FR',
    'french guiana': 'GF',
    'french polynesia': 'PF',
    'gabon': 'GA',
    'gambia': 'GM',
    'georgia': 'GE',
    'germany': 'DE',
    'ghana': 'GH',
    'gibraltar': 'GI',
    'greece': 'GR',
    'greenland': 'GL',
    'grenada': 'GD',
    'guadeloupe': 'GP',
    'guam': 'GU',
    'guatemala': 'GT',
    'guernsey': 'GG',
    'guinea': 'GN',
    'guinea bissau': 'GW',
    'guyana': 'GY',
    'haiti': 'HT',
    'honduras': 'HN',
    'hong kong': 'HK',
    'hungary': 'HU',
    'iceland': 'IS',
    'india': 'IN',
    'in': 'IN',
    'indonesia': 'ID',
    'iran': 'IR',
    'iraq': 'IQ',
    'ireland': 'IE',
    'isle of man': 'IM',
    'israel': 'IL',
    'italy': 'IT',
    'jamaica': 'JM',
    'japan': 'JP',
    'jersey': 'JE',
    'jordan': 'JO',
    'kazakhstan': 'KZ',
    'kenya': 'KE',
    'kiribati': 'KI',
    'kuwait': 'KW',
    'kyrgyzstan': 'KG',
    'laos': 'LA',
    'latvia': 'LV',
    'lebanon': 'LB',
    'lesotho': 'LS',
    'liberia': 'LR',
    'libya': 'LY',
    'liechtenstein': 'LI',
    'lithuania': 'LT',
    'luxembourg': 'LU',
    'macau': 'MO',
    'madagascar': 'MG',
    'malawi': 'MW',
    'malaysia': 'MY',
    'maldives': 'MV',
    'mali': 'ML',
    'malta': 'MT',
    'marshall islands': 'MH',
    'martinique': 'MQ',
    'mauritania': 'MR',
    'mauritius': 'MU',
    'mayotte': 'YT',
    'mexico': 'MX',
    'micronesia': 'FM',
    'moldova': 'MD',
    'monaco': 'MC',
    'mongolia': 'MN',
    'montenegro': 'ME',
    'montserrat': 'MS',
    'morocco': 'MA',
    'mozambique': 'MZ',
    'myanmar': 'MM',
    'namibia': 'NA',
    'nauru': 'NR',
    'nepal': 'NP',
    'netherlands': 'NL',
    'new caledonia': 'NC',
    'new zealand': 'NZ',
    'nicaragua': 'NI',
    'niger': 'NE',
    'nigeria': 'NG',
    'niue': 'NU',
    'north korea': 'KP',
    'north macedonia': 'MK',
    'norway': 'NO',
    'oman': 'OM',
    'pakistan': 'PK',
    'palau': 'PW',
    'palestine': 'PS',
    'panama': 'PA',
    'papua new guinea': 'PG',
    'paraguay': 'PY',
    'peru': 'PE',
    'philippines': 'PH',
    'poland': 'PL',
    'portugal': 'PT',
    'puerto rico': 'PR',
    'qatar': 'QA',
    'romania': 'RO',
    'russia': 'RU',
    'rwanda': 'RW',
    'saint kitts and nevis': 'KN',
    'saint lucia': 'LC',
    'saint vincent and the grenadines': 'VC',
    'samoa': 'WS',
    'san marino': 'SM',
    'sao tome and principe': 'ST',
    'saudi arabia': 'SA',
    'saudi': 'SA',
    'senegal': 'SN',
    'serbia': 'RS',
    'seychelles': 'SC',
    'sierra leone': 'SL',
    'singapore': 'SG',
    'slovakia': 'SK',
    'slovenia': 'SI',
    'solomon islands': 'SB',
    'somalia': 'SO',
    'south africa': 'ZA',
    'south korea': 'KR',
    'korea': 'KR',
    'spain': 'ES',
    'sri lanka': 'LK',
    'sudan': 'SD',
    'suriname': 'SR',
    'sweden': 'SE',
    'switzerland': 'CH',
    'syria': 'SY',
    'taiwan': 'TW',
    'tajikistan': 'TJ',
    'tanzania': 'TZ',
    'thailand': 'TH',
    'timor leste': 'TL',
    'togo': 'TG',
    'tonga': 'TO',
    'trinidad and tobago': 'TT',
    'tunisia': 'TN',
    'turkey': 'TR',
    'turkiye': 'TR',
    'turkmenistan': 'TM',
    'tuvalu': 'TV',
    'uganda': 'UG',
    'ukraine': 'UA',
    'united arab emirates': 'AE',
    'uae': 'AE',
    'united kingdom': 'GB',
    'uk': 'GB',
    'england': 'GB',
    'united states': 'US',
    'united states of america': 'US',
    'usa': 'US',
    'us': 'US',
    'uruguay': 'UY',
    'uzbekistan': 'UZ',
    'vanuatu': 'VU',
    'vatican city': 'VA',
    'venezuela': 'VE',
    'vietnam': 'VN',
    'yemen': 'YE',
    'zambia': 'ZM',
    'zimbabwe': 'ZW',
  };

  final code = countryMap[normalized];

  if (code == null || code.length != 2) {
    return '🌐';
  }

  return _flagFromCode(code);
}

Widget _countryFlagNameChip(String? country) {
  final flag = getCountryFlag(country);
  final name = cleanCountryName(country);

  if (name.isEmpty) {
    return Text(flag, style: TextStyle(fontSize: kHeight * 0.023));
  }

  return Container(
    constraints: BoxConstraints(maxWidth: kWeight * 0.30),
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.014,
      vertical: kHeight * 0.0028,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.58),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0x33A77B4E), width: .7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(flag, style: TextStyle(fontSize: kHeight * 0.0185)),
        SizedBox(width: kWeight * 0.008),
      ],
    ),
  );
}

Widget _profileBaseBadgesRow() {
  return Obx(() {
    final bases = homeController.profileBaseList;

    if (bases.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: kHeight * 0.050,
      width: double.infinity,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: bases.length,
        itemBuilder: (context, index) {
          final item = bases[index];
          return _baseBadgeItem(item);
        },
      ),
    );
  });
}

Widget _baseBadgeItem(dynamic item) {
  String imageUrl = '';

  if (item is Map) {
    imageUrl = item['image_url']?.toString() ?? '';

    if (imageUrl.isEmpty) {
      final imagePath = item['image']?.toString() ?? '';
      if (imagePath.isNotEmpty) {
        final cleanDomain = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
        final cleanPath = imagePath.replaceAll(RegExp(r'^/+'), '');
        imageUrl = '$cleanDomain/$cleanPath';
      }
    }
  }

  if (imageUrl.isEmpty) {
    return const SizedBox.shrink();
  }

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Get.to(
              () => const BaseMedalView(),
          transition: Transition.rightToLeft,
          duration: const Duration(milliseconds: 220),
        );
      },
      child: Container(
        width: kWeight * 0.325,
        height: kHeight * 0.050,
        alignment: Alignment.center,
        child: RepaintBoundary(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: kWeight * 0.315,
            height: kHeight * 0.085,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            memCacheWidth: 300,
            placeholder: (context, url) => const SizedBox.shrink(),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

Widget _profileInfoHeaderCard() {
  final userProfile = authController.userProfile.value;
  final user = userProfile.user;
  final profileImage = user?.profileImage ?? '';
  final framePath = userProfile.assetHistories?.asset?.asset?.toString() ?? '';

  final bool hasUserFrame =
      userProfile.assetHistories != null &&
          framePath.isNotEmpty &&
          userProfile.assetHistories?.asset?.type == 'Frame';

  final baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
  final frameUrl = '$baseUrl/$framePath';

  final name = user?.name ?? 'User'.appTr;
  final shortName = name.length > 16 ? '${name.substring(0, 16)}..' : name;

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => Get.to(MyProfileView()),
    child: Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: kHeight * .135),
      padding: EdgeInsets.fromLTRB(
        kWeight * .045,
        kHeight * .006,
        kWeight * .035,
        kHeight * .006,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: kHeight * .125,
            width: kHeight * .125,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: kHeight * .086,
                  width: kHeight * .086,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.96),
                    border: Border.all(
                      color: Colors.white.withOpacity(.95),
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(profileImage),
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholderFadeInDuration: Duration.zero,
                    memCacheWidth: 180,
                    memCacheHeight: 180,
                    placeholder: (c, u) => const SizedBox.shrink(),
                    errorWidget: (c, u, e) => const Icon(
                      Icons.person,
                      size: 36,
                      color: Color(0xFFB7B7B7),
                    ),
                  ),
                ),
                if (hasUserFrame)
                  SizedBox(
                    height: kHeight * .145,
                    width: kHeight * .145,
                    child: framePath.toLowerCase().endsWith('.svga')
                        ? SVGAEasyPlayer(
                      resUrl: frameUrl,
                      fit: BoxFit.cover,
                    )
                        : CachedNetworkImage(
                      imageUrl: frameUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholderFadeInDuration: Duration.zero,
                      memCacheWidth: 320,
                      memCacheHeight: 320,
                      placeholder: (c, u) => const SizedBox.shrink(),
                      errorWidget: (c, u, e) =>
                      const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: kWeight * .018),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF27282C),
                          fontSize: (kHeight * .0215).clamp(17.0, 21.0).toDouble(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: kWeight * .012),
                    Container(
                      width: kHeight * .024,
                      height: kHeight * .024,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user?.gender?.toString().toLowerCase() == 'female'
                            ? const Color(0xFFFF75B8)
                            : const Color(0xFF62B8FF),
                      ),
                      child: Icon(
                        user?.gender?.toString().toLowerCase() == 'female'
                            ? Icons.female
                            : Icons.male,
                        color: Colors.white,
                        size: kHeight * .0155,
                      ),
                    ),
                    SizedBox(width: kWeight * .010),
                    _countryFlagNameChip(user?.country?.toString()),
                  ],
                ),
                SizedBox(height: kHeight * .006),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: kWeight * .010,
                        vertical: kHeight * .0015,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3A452),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID'.appTr,
                        style: GoogleFonts.poppins(
                          fontSize: (kHeight * .0115).clamp(9.0, 11.0).toDouble(),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: kWeight * .010),
                    Flexible(
                      child: Text(
                        '${user?.uniqueId ?? user?.userId ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize:
                          (kHeight * .014).clamp(11.0, 13.5).toDouble(),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFFEA02),
                        ),
                      ),
                    ),
                    SizedBox(width: kWeight * .008),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                            '${authController.userProfile.value.user?.userId ?? ''}',
                          ),
                        );
                        Fluttertoast.showToast(
                          msg: ('ID copied').appTr,
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.black87,
                          textColor: Colors.white,
                          fontSize: 13,
                        );
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        size: kHeight * .016,
                        color: const Color(0xFFFFEA02),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: kHeight * .005),
                Row(
                  children: [
                    SizedBox(width: kWeight * .047),
                    LevelFrame(
                      level: '${authController.userProfile.value.user!.level}',
                    ),
                    SizedBox(width: kWeight * .014),
                    Flexible(child: _currentVipTitleImageBadge()),
                  ],
                ),
                SizedBox(height: kHeight * .003),
                _profileBaseBadgesRow(),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: const Color(0xFFFFEA02),
            size: kHeight * .026,
          ),
        ],
      ),
    ),
  );
}