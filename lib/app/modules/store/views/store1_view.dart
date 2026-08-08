import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../backpack/controllers/store_controller.dart';
import '../../backpack/views/BackPack.dart';
import '../../coinshop/views/giftsent_friend.dart';
import '../controllers/store1_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Store1View extends GetView<Store1Controller> {
  const Store1View({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PremiumStoreBody();
  }
}

class _PremiumStoreBody extends StatefulWidget {
  const _PremiumStoreBody();

  @override
  State<_PremiumStoreBody> createState() => _PremiumStoreBodyState();
}

class _PremiumStoreBodyState extends State<_PremiumStoreBody>
    with TickerProviderStateMixin {
  late final StoreController storeController;
  late final AnimationController bgController;
  late Future<dynamic> assetFuture;

  int mainTabIndex = 1; // 0 = Svip, 1 = Mall
  int mallTabIndex = 0;

  /// User jokhon kono Frame / Entry / VIP item select korbe,
  /// oi item-er amount bottom bar-er right side-e show hobe.
  Map<String, dynamic>? selectedItem;

  final List<_StoreCategory> mallTabs =  [
    _StoreCategory(title: ('Frame').appTr, apiType: 'Frame'),
    _StoreCategory(title: ('Entry').appTr, apiType: 'Entry Care'),
    _StoreCategory(title: ('Banner').appTr, apiType: 'Banner Frame'),
    _StoreCategory(title: ('Lucky ID').appTr, apiType: 'Lucky Id'),
  ];

  @override
  void initState() {
    super.initState();
    Get.put(Store1Controller());
    storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());
    assetFuture = storeController.getAssetList();
    bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    bgController.dispose();
    super.dispose();
  }

  Future<void> refreshAssets() async {
    final future = storeController.getAssetList();
    setState(() => assetFuture = future);
    await future;
  }

  Color get appColor1 => kAppColor1;
  Color get appColor2 => kAppColor2;

  String get activeApiType {
    if (mainTabIndex == 0) return 'Vip';
    return mallTabs[mallTabIndex].apiType;
  }

  String get activeEmptyText {
    if (mainTabIndex == 0) return 'No SVIP assets found';
    return 'No ${mallTabs[mallTabIndex].title} assets found';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final topHeight = mainTabIndex == 0
        ? math.min(h * .36, 286.0)
        : math.min(h * .34, 272.0);

    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      body: Stack(
        children: [
          _TopBlueBackground(
            height: topHeight,
            animation: bgController,
            appColor1: appColor1,
            appColor2: appColor2,
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(w),
                Expanded(
                  child: FutureBuilder(
                    future: assetFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildMainShell(
                          context: context,
                          child: _buildShimmerGrid(),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildMainShell(
                          context: context,
                          child: _StoreStateMessage(
                            title: ('Something went wrong').appTr,
                            subtitle: '${snapshot.error}',
                            buttonText: ('Try Again').appTr,
                            onTap: refreshAssets,
                            appColor: appColor2,
                          ),
                        );
                      }

                      final List<Map<String, dynamic>> list = storeController
                          .assetList
                          .where((item) => item['type'] == activeApiType)
                          .map((e) => Map<String, dynamic>.from(e as Map))
                          .toList();

                      return _buildMainShell(
                        context: context,
                        child: RefreshIndicator(
                          color: appColor2,
                          backgroundColor: Colors.white,
                          onRefresh: refreshAssets,
                          child: list.isEmpty
                              ? SingleChildScrollView(
                            physics:
                            const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: h * .45,
                              child: _StoreStateMessage(
                                title: activeEmptyText,
                                subtitle:
                                ('New premium items will appear here.').appTr,
                                buttonText: ('Refresh').appTr,
                                onTap: refreshAssets,
                                appColor: appColor2,
                              ),
                            ),
                          )
                              : _buildProductGrid(list),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBalanceBar(context),
    );
  }

  Widget _buildTopBar(double w) {
    final double topBarHeight = mainTabIndex == 0 ? 120 : 108;

    return SizedBox(
      height: topBarHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: Get.back,
                  child: Container(
                    height: 42,
                    width: 42,
                    color: Colors.transparent,
                    alignment: Alignment.centerLeft,
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _topMainTab(
                        title: ('Svip').appTr,
                        selected: mainTabIndex == 0,
                        onTap: () => setState(() {
                          mainTabIndex = 0;
                          selectedItem = null;
                        }),
                      ),
                      SizedBox(width: w * .12),
                      _topMainTab(
                        title: ('Mall').appTr,
                        selected: mainTabIndex == 1,
                        onTap: () => setState(() {
                          mainTabIndex = 1;
                          selectedItem = null;
                        }),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.to(
                    Backpack(),
                    transition: Transition.rightToLeft,
                  ),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.13),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(.08)),
                    ),
                    child: Text(
                      ('My dress-up').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: mainTabIndex == 0 ? 17 : 24),
            if (mainTabIndex == 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Text(
                      ('Filter').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(.86),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(.23)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            ('All').appTr,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.unfold_more_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
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

  Widget _topMainTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: selected ? 1 : .42,
        duration: const Duration(milliseconds: 220),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: -.5,
              ),
              child: Text(title),
            ),
            const SizedBox(height: 1),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: selected ? 9 : 0,
              width: selected ? 26 : 0,
              child: CustomPaint(
                painter: _WaveUnderlinePainter(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainShell({
    required BuildContext context,
    required Widget child,
  }) {
    final h = MediaQuery.of(context).size.height;

    // Mall screen: profile circle er center line-er sathe white container start hobe.
    // Tai profile half top background-e, half white container-e image-er moto thakbe.
    final double avatarTop = -18;
    const double avatarSize = 84;
    final double mallWhiteTop = avatarTop + (avatarSize / 2);
    final double mallContentTop = avatarTop + avatarSize + 22;

    final double whiteTop = mainTabIndex == 0 ? 10 : mallWhiteTop;
    final double contentTop = mainTabIndex == 0 ? 18 : mallContentTop;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: whiteTop,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
          ),
        ),
        Positioned.fill(
          top: contentTop,
          child: Column(
            children: [
              if (mainTabIndex == 1) _buildMallCategoryTabs(),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(mainTabIndex == 0 ? 26 : 0),
                    topRight: Radius.circular(mainTabIndex == 0 ? 26 : 0),
                  ),
                  child: Container(
                    constraints: BoxConstraints(minHeight: h * .5),
                    color: Colors.white,
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (mainTabIndex == 1) _buildProfileAvatar(top: avatarTop, size: avatarSize),
      ],
    );
  }

  Widget _buildProfileAvatar({
    required double top,
    required double size,
  }) {
    final image = _profileImage();
    final initial = _profileInitial();

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: bgController,
          builder: (context, child) {
            final v = math.sin(bgController.value * math.pi * 2) * 1.4;
            return Transform.translate(offset: Offset(0, v), child: child);
          },
          child: Container(
            height: size,
            width: size,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff7C929C),
                image: image == null
                    ? null
                    : DecorationImage(
                  image: CachedNetworkImageProvider(image),
                  fit: BoxFit.cover,
                ),
              ),
              alignment: Alignment.center,
              child: image != null
                  ? const SizedBox.shrink()
                  : Text(
                initial,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMallCategoryTabs() {
    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(mallTabs.length, (index) {
            final selected = mallTabIndex == index;
            return Padding(
              padding: EdgeInsets.only(right: index == mallTabs.length - 1 ? 0 : 18),
              child: GestureDetector(
                onTap: () => setState(() {
                  mallTabIndex = index;
                  selectedItem = null;
                }),
                behavior: HitTestBehavior.opaque,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: selected ? 1 : .46,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        style: GoogleFonts.poppins(
                          color: selected ? const Color(0xff07142B) : Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                          letterSpacing: -.2,
                        ),
                        child: Text(mallTabs[index].title),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: selected ? 8 : 0,
                        width: selected ? 23 : 0,
                        child: CustomPaint(
                          painter: _WaveUnderlinePainter(color: appColor2),
                        ),
                      ),
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

  Widget _buildProductGrid(List<Map<String, dynamic>> list) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 850
            ? 5
            : width >= 650
            ? 4
            : 3;
        final ratio = width < 360 ? .61 : .64;

        return GridView.builder(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: width < 360 ? 10 : 15,
            mainAxisSpacing: width < 360 ? 13 : 18,
            childAspectRatio: ratio,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 250 + (index % 12) * 35),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _StoreProductCard(
                item: list[index],
                appColor1: appColor1,
                appColor2: appColor2,
                selected: selectedItem?['id']?.toString() ==
                    list[index]['id']?.toString(),
                onTap: () {
                  setState(() {
                    selectedItem = list[index];
                  });
                  _openItemDialog(list[index]);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 18,
        mainAxisSpacing: 22,
        childAspectRatio: .61,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade100,
          highlightColor: Colors.grey.shade50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBalanceBar(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final myCoins = _formatCoins(authController.userProfile.value.user?.coins);
    final selectedAmount = selectedItem == null
        ? '0'
        : _formatCoins(selectedItem?['price']);

    return Container(
      height: 76 + bottom,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 22,
            offset: const Offset(0, -7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _balancePill(
              title: ('My Coins').appTr,
              icon: 'assets/images/coin.png',
              value: myCoins,
              active: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _balancePill(
              title: ('Selected Amount').appTr,
              icon: 'assets/images/coin.png',
              value: selectedAmount,
              active: selectedItem != null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _balancePill({
    required String title,
    required String icon,
    required String value,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? appColor2.withOpacity(.075) : const Color(0xffF8F8FA),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: active ? appColor2.withOpacity(.22) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Image.asset(icon, height: 23, width: 23),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff1A1A1A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: active ? appColor2 : Colors.grey.shade500,
            size: 13.5,
          ),
        ],
      ),
    );
  }

  void _openItemDialog(Map<String, dynamic> item) {
    storeController.selectId.value = item['id'].toString();

    if (selectedItem?['id']?.toString() != item['id']?.toString()) {
      setState(() {
        selectedItem = item;
      });
    }

    Get.bottomSheet(
      _StoreItemBottomSheet(
        item: item,
        appColor1: appColor1,
        appColor2: appColor2,
        onPurchase: () async {
          await storeController.purchaseAsset(purchaseId: item['id'].toString());
          await refreshAssets();
        },
        onSend: () {
          Get.back();
          Get.to(
            GiftSentFriend(),
            transition: Transition.rightToLeft,
          );
        },
        onBackpack: () {
          Get.back();
          Get.to(
            Backpack(),
            transition: Transition.rightToLeft,
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.42),
      isDismissible: true,
      enableDrag: true,
    );
  }

  String _profileInitial() {
    final name = _profileName();
    if (name.trim().isEmpty) return ('R').appTr;
    return name.trim().substring(0, 1).toUpperCase();
  }

  String _profileName() {
    final dynamic user = authController.userProfile.value.user;
    try {
      final dynamic v = user?.name;
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    } catch (_) {}
    try {
      final dynamic v = user?.fullName;
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    } catch (_) {}
    try {
      final dynamic v = user?.username;
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    } catch (_) {}
    return ('R').appTr;
  }

  String? _profileImage() {
    final dynamic user = authController.userProfile.value.user;
    String? raw;
    try {
      final dynamic v = user?.profileImageUrl;
      if (v != null && v.toString().trim().isNotEmpty) raw = v.toString();
    } catch (_) {}
    try {
      final dynamic v = user?.profileImage;
      if (raw == null && v != null && v.toString().trim().isNotEmpty) {
        raw = v.toString();
      }
    } catch (_) {}
    try {
      final dynamic v = user?.image;
      if (raw == null && v != null && v.toString().trim().isNotEmpty) {
        raw = v.toString();
      }
    } catch (_) {}
    try {
      final dynamic v = user?.avatar;
      if (raw == null && v != null && v.toString().trim().isNotEmpty) {
        raw = v.toString();
      }
    } catch (_) {}

    if (raw == null || raw!.trim().isEmpty) return null;
    raw = raw!.trim();
    if (raw!.startsWith('http')) return raw;
    return '$kDomainUrl/$raw';
  }
}

class _StoreCategory {
  final String title;
  final String apiType;

  const _StoreCategory({required this.title, required this.apiType});
}

class _StoreProductCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color appColor1;
  final Color appColor2;
  final bool selected;
  final VoidCallback onTap;

  const _StoreProductCard({
    required this.item,
    required this.appColor1,
    required this.appColor2,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Gifts';
    final type = item['type']?.toString() ?? '';
    final label = _typeLabel(type);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: const Color(0xffFAFAFA),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? appColor2.withOpacity(.55) : Colors.transparent,
            width: selected ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? appColor2.withOpacity(.12)
                  : Colors.black.withOpacity(.022),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 7),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: _StoreAssetImage(
                              item: item,
                              preferShowImage: true,
                            ),
                          ),
                          Container(
                            height: 30,
                            width: 30,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.38),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/coin.png', height: 14, width: 14),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _formatCoins(item['price']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xff242424),
                            fontSize: 12.6,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: -1,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _typeColors(type)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff3A2321),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 7,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_filled_rounded,
                      color: Colors.grey.shade300, size: 10.5),
                  const SizedBox(width: 1.5),
                  Text(
                    ('${item['duration_days'] ?? 0}d').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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

  String _typeLabel(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'entry care') return 'ENTRY';
    if (t == 'lucky id') return 'LUCKY';
    if (t == 'banner frame') return 'BANNER';
    if (t == 'frame') return 'FRAME';
    if (t == 'vip') return ('VIP').appTr;
    return type.isEmpty ? 'ITEM' : type.toUpperCase();
  }

  List<Color> _typeColors(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'entry care') return const [Color(0xffD8F3FF), Color(0xff8FD5FF)];
    if (t == 'frame') return const [Color(0xffFFE0C7), Color(0xffD7A17E)];
    if (t == 'vip') return const [Color(0xffF9D7BD), Color(0xffC99A7A)];
    if (t == 'lucky id') return const [Color(0xffFFF1A6), Color(0xffFFC84E)];
    if (t == 'banner frame') return const [Color(0xffE6D8FF), Color(0xffB99AFF)];
    return const [Color(0xffE8E8E8), Color(0xffCFCFCF)];
  }
}

class _StoreAssetImage extends StatelessWidget {
  final Map<String, dynamic> item;
  final BoxFit fit;

  /// true  => card/list thumbnail-e show_image first show hobe.
  /// false => bottom preview-e real asset first show hobe, tai SVGA play hobe.
  final bool preferShowImage;

  const _StoreAssetImage({
    required this.item,
    this.fit = BoxFit.contain,
    this.preferShowImage = true,
  });

  @override
  Widget build(BuildContext context) {
    final String rawPath = _resolveAssetPath(item, preferShowImage: preferShowImage);

    if (rawPath.isEmpty) {
      return Icon(
        Icons.image_not_supported_rounded,
        color: Colors.grey.shade300,
        size: 30,
      );
    }

    final String url = _toFullAssetUrl(rawPath);

    if (rawPath.toLowerCase().endsWith('.svga')) {
      return RepaintBoundary(
        child: SVGAEasyPlayer(
          key: ValueKey(url),
          resUrl: url,
          fit: fit,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: 420,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey.shade100,
        highlightColor: Colors.grey.shade50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Icon(
        Icons.image_not_supported_rounded,
        color: Colors.grey.shade300,
        size: 30,
      ),
    );
  }

  String _resolveAssetPath(
      Map<String, dynamic> item, {
        required bool preferShowImage,
      }) {
    final String showImage = _cleanPath(item['show_image']);
    final String asset = _cleanPath(item['asset']);

    if (preferShowImage) {
      if (showImage.isNotEmpty) return showImage;
      return asset;
    }

    /// Bottom sheet preview: asset first, so Entry/Frame SVGA can play.
    if (asset.isNotEmpty) return asset;
    return showImage;
  }

  String _cleanPath(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _toFullAssetUrl(String rawPath) {
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      return rawPath;
    }

    final String base = kDomainUrl.endsWith('/')
        ? kDomainUrl.substring(0, kDomainUrl.length - 1)
        : kDomainUrl;
    final String path = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    return '$base/$path';
  }
}

class _StoreItemBottomSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color appColor1;
  final Color appColor2;
  final VoidCallback onPurchase;
  final VoidCallback onSend;
  final VoidCallback onBackpack;

  const _StoreItemBottomSheet({
    required this.item,
    required this.appColor1,
    required this.appColor2,
    required this.onPurchase,
    required this.onSend,
    required this.onBackpack,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final purchased = item['purchased']?.toString().toLowerCase() == 'yes';
    final type = item['type']?.toString() ?? ('Item').appTr;
    final label = _typeLabel(type);

    return SafeArea(
      top: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 28 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.fromLTRB(18, 10, 18, 14 + bottom),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                appColor1.withOpacity(.18),
                appColor2.withOpacity(.12),
                Colors.white,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.18),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 42,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 92,
                        width: 92,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.04),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _StoreAssetImage(
                          item: item,
                          preferShowImage: false,
                        ),
                      ),
                      Positioned(
                        left: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _typeColors(type)),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.poppins(
                              color: const Color(0xff3A2321),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name']?.toString() ?? ('Item').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xff171717),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ('${item['duration_days'] ?? 0} days validity').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Image.asset('assets/images/coin.png', height: 18, width: 18),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _formatCoins(item['price']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xff202020),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
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
              const SizedBox(height: 14),
              _sheetOption(
                title: ('${_formatCoins(item['price'])} Noble points purchase').appTr,
                onTap: onPurchase,
              ),
              _sheetOption(
                title: ('${_formatCoins(item['price'])} Gold coin purchase').appTr,
                onTap: onPurchase,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sheetButton(
                      title: purchased ? ('Backpack').appTr: ('Purchase').appTr,
                      icon: purchased ? Icons.backpack_rounded : Icons.shopping_bag_rounded,
                      onTap: purchased ? onBackpack : onPurchase,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sheetButton(
                      title: ('Send').appTr,
                      icon: Icons.send_rounded,
                      onTap: onSend,
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

  Widget _sheetOption({required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.76),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(.045)),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: const Color(0xff242424),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _sheetButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [appColor1, appColor2]),
            boxShadow: [
              BoxShadow(
                color: appColor2.withOpacity(.20),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'entry care') return 'ENTRY';
    if (t == 'lucky id') return 'LUCKY';
    if (t == 'banner frame') return 'BANNER';
    if (t == 'frame') return 'FRAME';
    if (t == 'vip') return ('VIP').appTr;
    return type.isEmpty ? 'ITEM' : type.toUpperCase();
  }

  List<Color> _typeColors(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'entry care') return const [Color(0xffD8F3FF), Color(0xff8FD5FF)];
    if (t == 'frame') return const [Color(0xffFFE0C7), Color(0xffD7A17E)];
    if (t == 'vip') return const [Color(0xffF9D7BD), Color(0xffC99A7A)];
    if (t == 'lucky id') return const [Color(0xffFFF1A6), Color(0xffFFC84E)];
    if (t == 'banner frame') return const [Color(0xffE6D8FF), Color(0xffB99AFF)];
    return const [Color(0xffE8E8E8), Color(0xffCFCFCF)];
  }
}

class _TopBlueBackground extends StatelessWidget {
  final double height;
  final Animation<double> animation;
  final Color appColor1;
  final Color appColor2;

  const _TopBlueBackground({
    required this.height,
    required this.animation,
    required this.appColor1,
    required this.appColor2,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value;
        return Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [appColor1, appColor2, appColor2.withOpacity(.95)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80 + math.sin(v * math.pi * 2) * 16,
                left: -80,
                child: _lightCircle(180, Colors.white.withOpacity(.15)),
              ),
              Positioned(
                top: 54 + math.cos(v * math.pi * 2) * 18,
                right: -70,
                child: _lightCircle(170, Colors.white.withOpacity(.10)),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _SoftSparkPainter(value: v),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _lightCircle(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _WaveUnderlinePainter extends CustomPainter {
  final Color color;

  _WaveUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(2, size.height * .55);
    path.quadraticBezierTo(size.width * .25, size.height, size.width * .5,
        size.height * .55);
    path.quadraticBezierTo(size.width * .75, 0, size.width - 2,
        size.height * .55);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveUnderlinePainter oldDelegate) => false;
}

class _SoftSparkPainter extends CustomPainter {
  final double value;

  _SoftSparkPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(.10);
    for (int i = 0; i < 18; i++) {
      final dx = (size.width / 18) * i;
      final p = (value + i * .06) % 1;
      final dy = size.height * p;
      final r = 1.2 + math.sin((p + i) * math.pi * 2).abs() * 1.1;
      canvas.drawCircle(Offset(dx + math.sin(p * math.pi * 2) * 18, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoftSparkPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _StoreStateMessage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;
  final Color appColor;

  const _StoreStateMessage({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
    required this.appColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: appColor.withOpacity(.9), size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xff151515),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: appColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCoins(dynamic value) {
  final raw = value?.toString().replaceAll(',', '').trim() ?? '0';
  final number = double.tryParse(raw) ?? 0;

  if (number >= 1000000000) return '${_cleanNumber(number / 1000000000)}B';
  if (number >= 1000000) return '${_cleanNumber(number / 1000000)}M';
  if (number >= 1000) return '${_cleanNumber(number / 1000)}K';
  return number.toStringAsFixed(0);
}

String _cleanNumber(double value) {
  if (value >= 100) return value.toStringAsFixed(0);
  if (value >= 10) return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
}
