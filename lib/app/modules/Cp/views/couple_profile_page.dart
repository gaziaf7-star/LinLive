import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../controllers/cp_data_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CoupleProfilePage extends StatefulWidget {
  const CoupleProfilePage({
    super.key,
    this.boyImage,
    this.girlImage,
  });

  final String? boyImage;
  final String? girlImage;

  @override
  State<CoupleProfilePage> createState() => _CoupleProfilePageState();
}

class _CoupleProfilePageState extends State<CoupleProfilePage>
    with SingleTickerProviderStateMixin {
  final CpDataController cpController = Get.isRegistered<CpDataController>()
      ? Get.find<CpDataController>()
      : Get.put(CpDataController());

  late final AnimationController _heartAnim;

  @override
  void initState() {
    super.initState();

    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    Future.microtask(() => _refreshProfile(showLoader: false));
  }

  @override
  void dispose() {
    _heartAnim.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile({bool showLoader = true}) async {
    await Future.wait([
      cpController.fetchCpData(showLoader: showLoader),
      cpController.fetchCpLevelData(showLoader: showLoader),
      cpController.fetchCpProfileAssets(showLoader: showLoader),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cp = cpController.acceptedCp;
      final isLoading = cpController.isLoading.value && cp == null;

      if (isLoading) {
        return  CpLoadingPage(title: ('Our CP Profile').appTr);
      }

      if (cp == null) {
        return CpNoAcceptedView(
          title: ('Our CP Profile').appTr,
          onRefresh: () => _refreshProfile(showLoader: true),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xffffedf7),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: RefreshIndicator(
              color: const Color(0xffff4f91),
              onRefresh: () => _refreshProfile(showLoader: true),
              child: CustomScrollView(
                // physics: const AlwaysScrollableScrollPhysics(
                //   parent: BouncingScrollPhysics(),
                // ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _profileHeader(context, cp),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 26),
                        decoration: const BoxDecoration(
                          color: Color(0xffffedf7),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 23),
                            _topStats(cp),
                            const SizedBox(height: 14),
                            _badgesSection(),
                            const SizedBox(height: 14),
                            _themesSection(),
                            const SizedBox(height: 14),
                            _coupleStatusCard(cp),
                            const SizedBox(height: 14),
                            _doneTogetherCard(cp),
                            const SizedBox(height: 14),
                            _memoryButton(),
                          ],
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
    });
  }

  Widget _profileHeader(BuildContext context, CpRequestModel cp) {
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 520.0).toDouble();
    final headerHeight = (width * .80).clamp(388.0, 430.0).toDouble();
    final current = cpController.cpCurrentLevel.value;
    final firstBadge = cpController.cpBadges.isEmpty ? null : cpController.cpBadges.first;
    final headerImage = firstBadge?.bestBackgroundUrl ?? '';

    return SizedBox(
      height: headerHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: _headerBackground(headerImage),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _heartAnim,
              builder: (_, __) {
                return CustomPaint(
                  painter: _CpProfileSkyPainter(progress: _heartAnim.value),
                );
              },
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                width <= 360 ? 12 : 14,
                8,
                width <= 360 ? 12 : 14,
                0,
              ),
              child: Column(
                children: [
                  _topBar(),
                  SizedBox(height: width <= 360 ? 14 : 18),
                  _avatarPair(width, cp),
                  SizedBox(height: width <= 360 ? 6 : 8),
                  _nameRow(cp),
                  SizedBox(height: width <= 360 ? 8 : 10),
                  _togetherBigCard(cp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBackground(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xff1a0d35),
                Color(0xff5f2a82),
                Color(0xffff83b6),
                Color(0xffffd3e8),
              ],
            ),
          ),
        ),
        if (url.isNotEmpty)
          Opacity(
            opacity: .30,
            child: Image.network(
              _fixedUrl(url),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xff160c2f).withOpacity(.40),
                const Color(0xff4b1f72).withOpacity(.10),
                const Color(0xffffedf7).withOpacity(.05),
                const Color(0xffffedf7),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        _glassIcon(Icons.arrow_back_ios_new_rounded, () => Navigator.maybePop(context)),
         Expanded(
          child: Center(
            child: Text(
              ('Our CP Profile').appTr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        _glassIcon(Icons.more_vert_rounded, () {}),
      ],
    );
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(.16)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _avatarPair(double width, CpRequestModel cp) {
    final boxWidth = width.clamp(300.0, 400.0).toDouble();
    final avatarSize = (boxWidth * .29).clamp(88.0, 116.0).toDouble();

    return SizedBox(
      width: boxWidth,
      height: avatarSize + 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: boxWidth * .13,
            top: 4,
            child: _avatar(
              size: avatarSize,
              image: cp.me.profileImage.isNotEmpty ? cp.me.profileImage : widget.boyImage,
              isBoy: true,
              useNetwork: cp.me.profileImage.isNotEmpty,
            ),
          ),
          Positioned(
            right: boxWidth * .13,
            top: 4,
            child: _avatar(
              size: avatarSize,
              image: cp.partner.profileImage.isNotEmpty
                  ? cp.partner.profileImage
                  : widget.girlImage,
              isBoy: false,
              useNetwork: cp.partner.profileImage.isNotEmpty,
            ),
          ),
          Positioned(
            top: avatarSize * .34,
            child: Container(
              width: (avatarSize * .42).clamp(42.0, 50.0).toDouble(),
              height: (avatarSize * .42).clamp(42.0, 50.0).toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.35),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffff69a7).withOpacity(.75),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: (avatarSize * .32).clamp(32.0, 38.0).toDouble(),
                  height: (avatarSize * .32).clamp(32.0, 38.0).toDouble(),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xffffb8d2), Color(0xffff4f91)],
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar({
    required double size,
    required String? image,
    required bool isBoy,
    required bool useNetwork,
  }) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xffffc8df)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: image == null || image.isEmpty
            ? _avatarFallback(size, isBoy)
            : useNetwork
            ? CpImage(imageUrl: image, size: size, iconSize: size * .48)
            : Image.asset(image, fit: BoxFit.cover),
      ),
    );
  }

  Widget _avatarFallback(double size, bool isBoy) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBoy
              ? const [Color(0xff20274d), Color(0xff7354ac)]
              : const [Color(0xffffb6ce), Color(0xff9c4b82)],
        ),
      ),
      child: Icon(
        isBoy ? Icons.person_rounded : Icons.person_2_rounded,
        color: Colors.white,
        size: size * .50,
      ),
    );
  }

  Widget _nameRow(CpRequestModel cp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: _nameText(
            cp.me.name.isEmpty ? 'You': cp.me.name,
            Icons.male_rounded,
            const Color(0xff7fd0ff),
          ),
        ),
        const SizedBox(width: 62),
        Flexible(
          child: _nameText(
            cp.partner.name.isEmpty ? 'Partner': cp.partner.name,
            Icons.female_rounded,
            const Color(0xffff9aca),
          ),
        ),
      ],
    );
  }

  Widget _nameText(String name, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(icon, color: color, size: 14),
      ],
    );
  }

  Widget _togetherBigCard(CpRequestModel cp) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 36),
      padding:EdgeInsets.symmetric(vertical: kHeight*0.01),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(.13),
        border: Border.all(color: Colors.white.withOpacity(.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            ('Together For').appTr,
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${cp.daysTogether}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.0,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            ('Days').appTr,
            style: TextStyle(
              color: Colors.white.withOpacity(.82),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xffff5d96), size: 12),
                const SizedBox(width: 5),
                Text(
                  ('Since ${cp.sinceFullDate}').appTr,
                  style: const TextStyle(
                    color: Color(0xff5c3254),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelBadgeLine(CpCurrentLevelModel? current) {
    final level = current?.currentLevelNo ?? 0;
    final coins = current?.coins ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _miniGlassPill(Icons.favorite_rounded, ('Love Level').appTr, 'Lv. $level'),
        const SizedBox(width: 10),
        _miniGlassPill(Icons.diamond_rounded, ('Love Points').appTr, cpCompactNumber(coins)),
      ],
    );
  }

  Widget _miniGlassPill(IconData icon, String title, String value) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(.17),
        border: Border.all(color: Colors.white.withOpacity(.13)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.70),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topStats(CpRequestModel cp) {
    final current = cpController.cpCurrentLevel.value;
    final level = current?.currentLevelNo ?? 0;
    final coins = current?.coins ?? 0;

    return Row(
      children: [
        Expanded(
          child: _smallStatCard(
            icon: Icons.favorite_rounded,
            iconGradient: const [Color(0xffffb4cf), Color(0xffff4f91)],
            title: ('Love Level').appTr,
            value: 'Lv. $level',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallStatCard(
            icon: Icons.diamond_rounded,
            iconGradient: const [Color(0xffa6ecff), Color(0xff28b6ff)],
            title: ('Love Points').appTr,
            value: cpCompactNumber(coins),
          ),
        ),
      ],
    );
  }

  Widget _smallStatCard({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String value,
  }) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(.96),
            const Color(0xffffd9ec),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: iconGradient),
              boxShadow: [
                BoxShadow(
                  color: iconGradient.last.withOpacity(.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xff3b3143).withOpacity(.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff33243c),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgesSection() {
    final badges = cpController.cpBadges;
    final loading = cpController.isProfileAssetsLoading.value && badges.isEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width.clamp(320.0, 520.0).toDouble();
    final badgeWidth = (screenWidth * .27).clamp(104.0, 132.0).toDouble();
    final badgeHeight = (badgeWidth * 1.38).clamp(140.0, 172.0).toDouble();

    return _sectionCard(
      title: ('Our Badges').appTr,
      trailing: badges.isEmpty ? null : '${badges.length} Items',
      child: loading
          ? _badgeLoadingRow()
          : badges.isEmpty
          ? _emptyAssetBox(
        icon: Icons.workspace_premium_rounded,
        title: ('No CP Badge Found').appTr,
        subTitle: 'Admin panel theke badge add korle ekhane show hobe.',
      )
          : SizedBox(
        height: badgeHeight,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: badges.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return _badgeItem(
              badges[index],
              width: badgeWidth,
              height: badgeHeight,
            );
          },
        ),
      ),
    );
  }

  Widget _badgeLoadingRow() {
    final screenWidth = MediaQuery.sizeOf(context).width.clamp(320.0, 520.0).toDouble();
    final badgeWidth = (screenWidth * .27).clamp(104.0, 132.0).toDouble();
    final badgeHeight = (badgeWidth * 1.38).clamp(140.0, 172.0).toDouble();

    return SizedBox(
      height: badgeHeight,
      child: Row(
        children: [
          CpShimmerBox(width: badgeWidth, height: badgeHeight, radius: 24),
          const SizedBox(width: 12),
          CpShimmerBox(width: badgeWidth, height: badgeHeight, radius: 24),
          const SizedBox(width: 12),
          CpShimmerBox(width: badgeWidth, height: badgeHeight, radius: 24),
        ],
      ),
    );
  }

  Widget _badgeItem(
      CpBadgeModel badge, {
        required double width,
        required double height,
      }) {
    final primary = _hexColor(badge.primaryColor, const Color(0xffff5d96));
    final secondary = _hexColor(badge.secondaryColor, const Color(0xff7c4dff));
    final imageSize = (width * .50).clamp(48.0, 66.0).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => _showBadgeDetails(badge),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(2.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withOpacity(.95),
              const Color(0xffffd6e8),
              secondary.withOpacity(.88),
              primary.withOpacity(.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                primary.withOpacity(.055),
                secondary.withOpacity(.075),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LoveFramePainter(
                    primary: primary,
                    secondary: secondary,
                  ),
                ),
              ),
              Positioned(
                top: 3,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(.11),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primary.withOpacity(.18)),
                  ),
                  child: Text(
                    badge.levelText.isEmpty ? ('CP').appTr: badge.levelText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [primary, secondary]),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withOpacity(.28),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: badge.bestImageUrl.isEmpty
                          ? const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 28,
                      )
                          : Image.network(
                        _fixedUrl(badge.bestImageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      badge.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff2e2537),
                        fontSize: 10.3,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: [
                            primary.withOpacity(.13),
                            secondary.withOpacity(.12),
                          ],
                        ),
                        border: Border.all(color: primary.withOpacity(.14)),
                      ),
                      child: Text(
                        badge.priceText.isEmpty ? badge.durationText : badge.priceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xff2e2537).withOpacity(.70),
                          fontSize: 8.4,
                          fontWeight: FontWeight.w900,
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
    );
  }

  Widget _themesSection() {
    final themes = cpController.cpThemes;
    final loading = cpController.isProfileAssetsLoading.value && themes.isEmpty;
    final screenWidth = MediaQuery.sizeOf(context).width.clamp(320.0, 520.0).toDouble();
    final themeWidth = (screenWidth * .43).clamp(150.0, 188.0).toDouble();
    final themeHeight = (themeWidth * .72).clamp(108.0, 132.0).toDouble();

    return _sectionCard(
      title: ('CP Themes').appTr,
      trailing: themes.isEmpty ? null : '${themes.length} Items',
      child: loading
          ? CpShimmerBox(width: double.infinity, height: themeHeight, radius: 20)
          : themes.isEmpty
          ? _emptyAssetBox(
        icon: Icons.palette_rounded,
        title: ('No Theme Available').appTr,
        subTitle: 'CP theme list empty ache. Theme add korle ekhane show hobe.',
      )
          : SizedBox(
        height: themeHeight,
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemCount: themes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) => _themeItem(
            themes[index],
            width: themeWidth,
            height: themeHeight,
          ),
        ),
      ),
    );
  }

  Widget _themeItem(
      CpThemeModel theme, {
        required double width,
        required double height,
      }) {
    final primary = _hexColor(theme.primaryColor, const Color(0xffff5d96));
    final secondary = _hexColor(theme.secondaryColor, const Color(0xff7c4dff));

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: [primary, secondary, const Color(0xffffd6e8)]),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, secondary]),
                ),
              ),
            ),
            if (theme.bestImageUrl.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: .72,
                  child: Image.network(
                    _fixedUrl(theme.bestImageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(.40)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white.withOpacity(.72),
                size: 17,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    theme.priceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.84),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    String? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xff2d2535),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    color: const Color(0xff2d2535).withOpacity(.45),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyAssetBox({
    required IconData icon,
    required String title,
    required String subTitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xfffff3fa),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffffd9ec)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xffffacd0), Color(0xffff5d96)]),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff30263b),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subTitle,
                  style: TextStyle(
                    color: const Color(0xff30263b).withOpacity(.55),
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coupleStatusCard(CpRequestModel cp) {
    final message = cp.message.isEmpty
        ? 'I may not be your first date, kiss or love... but I want to be your last everything.'
        : cp.message;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children:  [
              Text(
                ('Couple Status').appTr,
                style: TextStyle(
                  color: Color(0xff2d2535),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              Icon(Icons.favorite_rounded, color: Color(0xffff5d96), size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xff2d2535).withOpacity(.66),
              fontSize: 12,
              height: 1.48,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Icon(Icons.favorite_rounded, color: Color(0xffff5d96), size: 15),
        ],
      ),
    );
  }

  Widget _doneTogetherCard(CpRequestModel cp) {
    final current = cpController.cpCurrentLevel.value;
    final level = current?.currentLevelNo ?? 0;
    final coins = current?.coins ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            ("What We've Done Together").appTr,
            style: TextStyle(
              color: Color(0xff2d2535),
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _doneStat('${cp.daysTogether}', ('Days Together').appTr),
              _doneStat('${cp.monthsTogether}', ('Months').appTr),
              _doneStat('$level', ('CP Level').appTr),
              _doneStat(cpCompactNumber(coins), 'Love Coins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _doneStat(String value, String title) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xffff4f91),
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xff2d2535).withOpacity(.54),
              fontSize: 9.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memoryButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        Get.snackbar(
          ('Coming Soon').appTr,
          ('Create New Memory system pore connect korben.').appTr,
          backgroundColor: Colors.white,
          colorText: const Color(0xff2d2535),
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: const LinearGradient(
            colors: [Color(0xffff7daf), Color(0xffff4f91)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff4f91).withOpacity(.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:  [
            Icon(Icons.add_circle_rounded, color: Colors.white, size: 17),
            SizedBox(width: 8),
            Text(
              ('Create New Memory').appTr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.075),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.13)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xff2d2535).withOpacity(.46),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff2d2535),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetails(CpBadgeModel badge) {
    final primary = _hexColor(badge.primaryColor, const Color(0xffff5d96));
    final secondary = _hexColor(badge.secondaryColor, const Color(0xff7c4dff));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth.clamp(300.0, 430.0).toDouble();

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CP Badge Details',
      barrierColor: Colors.black.withOpacity(.46),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .82,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withOpacity(.95),
                    const Color(0xffffd6e8),
                    secondary.withOpacity(.92),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.22),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 170,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [primary, secondary],
                                      ),
                                    ),
                                  ),
                                ),
                                if (badge.bestBackgroundUrl.isNotEmpty)
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: .50,
                                      child: Image.network(
                                        _fixedUrl(badge.bestBackgroundUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _LoveFramePainter(
                                      primary: Colors.white.withOpacity(.85),
                                      secondary: const Color(0xffffd6e8),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(40),
                                    onTap: () => Navigator.of(dialogContext).maybePop(),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(.22),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 94,
                                    height: 94,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Colors.white, Color(0xffffd6e8)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(.18),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: badge.bestImageUrl.isEmpty
                                          ? Icon(
                                        Icons.workspace_premium_rounded,
                                        color: primary,
                                        size: 48,
                                      )
                                          : Image.network(
                                        _fixedUrl(badge.bestImageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.workspace_premium_rounded,
                                          color: primary,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  badge.displayName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xff2d2535),
                                    fontSize: 20,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: LinearGradient(
                                      colors: [
                                        primary.withOpacity(.12),
                                        secondary.withOpacity(.12),
                                      ],
                                    ),
                                    border: Border.all(color: primary.withOpacity(.14)),
                                  ),
                                  child: Text(
                                    ('${badge.levelText} • ${badge.durationText}'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dialogInfoCard(
                                        icon: Icons.favorite_rounded,
                                        title: ('Level').appTr,
                                        value: badge.levelText,
                                        color: primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _dialogInfoCard(
                                        icon: Icons.diamond_rounded,
                                        title: ('Price').appTr,
                                        value: badge.priceText,
                                        color: secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _dialogInfoCard(
                                        icon: Icons.timer_rounded,
                                        title: ('Duration').appTr,
                                        value: badge.durationText,
                                        color: primary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (badge.description.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfffff3fa),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: const Color(0xffffd6e8)),
                                    ),
                                    child: Text(
                                      badge.description,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xff2d2535).withOpacity(.64),
                                        fontSize: 12,
                                        height: 1.45,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Color _hexColor(String hex, Color fallback) {
    var clean = hex.trim();
    if (clean.isEmpty) return fallback;
    clean = clean.replaceAll('#', '');
    if (clean.length == 6) clean = 'ff$clean';
    if (clean.length != 8) return fallback;
    return Color(int.tryParse(clean, radix: 16) ?? fallback.value);
  }

  String _fixedUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return clean;
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    if (clean.startsWith('/')) return 'https://linlive.fr$clean';
    return 'https://linlive.fr/$clean';
  }
}


class _LoveFramePainter extends CustomPainter {
  _LoveFramePainter({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withOpacity(.50),
          secondary.withOpacity(.42),
          primary.withOpacity(.50),
        ],
      ).createShader(rect);

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(4),
      const Radius.circular(22),
    );
    canvas.drawRRect(rrect, borderPaint);

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = primary.withOpacity(.62);

    const double gap = 13;
    final double right = size.width - 10;
    final double bottom = size.height - 10;

    canvas.drawLine(const Offset(11, gap), const Offset(11, 28), cornerPaint);
    canvas.drawLine(const Offset(gap, 11), const Offset(30, 11), cornerPaint);

    canvas.drawLine(Offset(right, gap), Offset(right, 28), cornerPaint);
    canvas.drawLine(Offset(size.width - gap, 11), Offset(size.width - 30, 11), cornerPaint);

    canvas.drawLine(Offset(11, bottom - 18), Offset(11, bottom), cornerPaint);
    canvas.drawLine(Offset(gap, bottom), Offset(30, bottom), cornerPaint);

    canvas.drawLine(Offset(right, bottom - 18), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(size.width - gap, bottom), Offset(size.width - 30, bottom), cornerPaint);

    final glowPaint = Paint()
      ..color = secondary.withOpacity(.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * .16, size.height * .20), 13, glowPaint);
    canvas.drawCircle(Offset(size.width * .84, size.height * .78), 15, glowPaint);

    final heartPaint = Paint()..color = primary.withOpacity(.20);
    _drawMiniHeart(canvas, Offset(size.width * .17, size.height * .82), 10, heartPaint);
    _drawMiniHeart(canvas, Offset(size.width * .84, size.height * .18), 9, heartPaint);
  }

  void _drawMiniHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final x = center.dx;
    final y = center.dy;
    final s = size / 18;

    path.moveTo(x, y + 5 * s);
    path.cubicTo(x - 18 * s, y - 6 * s, x - 9 * s, y - 18 * s, x, y - 8 * s);
    path.cubicTo(x + 9 * s, y - 18 * s, x + 18 * s, y - 6 * s, x, y + 5 * s);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LoveFramePainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.secondary != secondary;
  }
}

class _CpProfileSkyPainter extends CustomPainter {
  _CpProfileSkyPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(18);
    final starPaint = Paint();

    for (int i = 0; i < 44; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * .62;
      final twinkle = (.18 + math.sin((progress + i * .07) * math.pi * 2).abs() * .35);
      starPaint.color = Colors.white.withOpacity(twinkle);
      canvas.drawCircle(Offset(x, y), .7 + random.nextDouble() * 1.3, starPaint);
    }

    final heartPaint = Paint();
    for (int i = 0; i < 18; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = 40 + random.nextDouble() * size.height * .55;
      final y = baseY + math.sin((progress + i * .08) * math.pi * 2) * 6;
      final s = 5 + random.nextDouble() * 11;
      heartPaint.color = const Color(0xffffa6c9).withOpacity(i % 3 == 0 ? .36 : .20);
      _drawHeart(canvas, Offset(x, y), s, heartPaint);
    }

    final moonPaint = Paint()..color = Colors.white.withOpacity(.85);
    canvas.drawCircle(Offset(size.width * .86, 80), 12, moonPaint);
    moonPaint.color = const Color(0xff6a3981).withOpacity(.85);
    canvas.drawCircle(Offset(size.width * .875, 75), 12, moonPaint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final x = center.dx;
    final y = center.dy;
    final s = size / 18;

    path.moveTo(x, y + 5 * s);
    path.cubicTo(x - 18 * s, y - 6 * s, x - 9 * s, y - 18 * s, x, y - 8 * s);
    path.cubicTo(x + 9 * s, y - 18 * s, x + 18 * s, y - 6 * s, x, y + 5 * s);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CpProfileSkyPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
