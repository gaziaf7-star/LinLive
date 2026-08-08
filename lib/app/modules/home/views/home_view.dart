import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/modules/Famaily/Controller/FamilyConroller.dart';

import 'package:meetlivepro/app/modules/home/views/pk_live_list_view.dart';
import 'package:meetlivepro/app/modules/home/views/popular_live_list_view.dart';
import 'package:meetlivepro/app/modules/home/views/widgets/animatedAppnameText.dart';
import 'package:meetlivepro/app/modules/home/views/widgets/livesearchView.dart';
import 'package:meetlivepro/app/modules/home/views/widgets/tabbarshemmer.dart'
    hide kAppColor1, kAppColor2;
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../Famaily/view/family_ranking_api_page.dart';
import '../../livestream/controllers/livestream_controller.dart';
import '../../ranking/controllers/ranking_controller.dart';
import '../../ranking/views/allrank.dart';
import '../controllers/home_controller.dart';
import 'all_live_live_view.dart';
import 'audio_live_stream_list_view.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
// 🔹 Connectivity Controller
class ConnectivityController extends GetxController {
  var isOnline = true.obs;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;

  @override
  void onInit() {
    super.onInit();
    checkInitialConnectivity();
    startMonitoring();
  }

  Future<void> checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    updateConnectionStatus(connectivityResult);
  }

  void startMonitoring() {
    connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      updateConnectionStatus(result);
    });
  }

  void updateConnectionStatus(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      isOnline.value = false;
      showOfflineDialog();
    } else {
      isOnline.value = true;
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }
  }

  void showOfflineDialog() {
    if (Get.isDialogOpen ?? false) return;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ('You are offline').appTr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ('We are unable to reach server. Please check your network settings and try again.').appTr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    AppSettings.openAppSettings(type: AppSettingsType.wifi);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAppbarColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:  Text(
                    ('RETRY').appTr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:  Text(
                    ('CLOSE').appTr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  @override
  void onClose() {
    connectivitySubscription.cancel();
    super.onClose();
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  Map<String, dynamic>? selectedUser;
  bool _quickLiveCreating = false;

  num _safeNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString().trim()) ?? 0;
  }

  num _currentUserCoins() {
    return _safeNum(authController.userProfile.value.user?.levelCoins);
  }

  bool get _canOpenBannerWhatsApp => _currentUserCoins() > 0;


  final PageController _bannerPageController = PageController(viewportFraction: 1.0);
  Timer? _bannerAutoTimer;
  Future<void>? _bannerFuture;
  int _bannerCurrentIndex = 0;

  // Ranking shortcut card: show 3 real ranking profiles per page.
  final PageController _rankingPageController = PageController();
  Timer? _rankingAutoTimer;
  int _rankingCurrentPage = 0;

  // Family shortcut: 5 profiles per page, smooth vertical auto slider.
  late final FamilyController _familyController;
  final PageController _familyPageController = PageController();
  Timer? _familyAutoTimer;
  int _familyCurrentPage = 0;

  // CP shortcut: real active couples, one couple per vertical slider page.
  final PageController _cpPageController = PageController();
  Timer? _cpAutoTimer;
  int _cpCurrentPage = 0;

  @override
  void initState() {
    super.initState();

    _familyController = Get.isRegistered<FamilyController>()
        ? Get.find<FamilyController>()
        : (Get.isRegistered<Familyconroller>()
        ? Get.find<Familyconroller>()
        : Get.put<FamilyController>(
      Familyconroller(),
      permanent: true,
    ));

    _bannerFuture = homeController.showBannerList();
    _startBannerAutoSlide();
    _startRankingAutoSlide();
    _startFamilyAutoSlide();
    _startCpAutoSlide();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Home Ranking card -> Daily Sending ranking.
      final RankingController rankingController =
      Get.isRegistered<RankingController>()
          ? Get.find<RankingController>()
          : Get.put(RankingController());
      rankingController.showRankingList(period: 'daily', force: false);

      // Family card -> same family ranking source used by Family Ranking page.
      if (_familyController.rankingList.isEmpty) {
        _familyController.loadRanking(silent: true);
      }

      // CP card -> real active couples from /api/cp-active-couples.
      homeController.loadCpActiveCouples(silent: true);
    });
  }

  @override
  void dispose() {
    _bannerAutoTimer?.cancel();
    _rankingAutoTimer?.cancel();
    _familyAutoTimer?.cancel();
    _cpAutoTimer?.cancel();
    _bannerPageController.dispose();
    _rankingPageController.dispose();
    _familyPageController.dispose();
    _cpPageController.dispose();
    super.dispose();
  }

  void _startBannerAutoSlide() {
    _bannerAutoTimer?.cancel();
    _bannerAutoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerPageController.hasClients) return;

      final int length = homeController.bannerLstData.length;
      if (length <= 1) return;

      final int nextPage = (_bannerCurrentIndex + 1) % length;
      _bannerPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startRankingAutoSlide() {
    _rankingAutoTimer?.cancel();
    _rankingAutoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          !_rankingPageController.hasClients ||
          !Get.isRegistered<RankingController>()) {
        return;
      }

      final RankingController controller = Get.find<RankingController>();
      final List<dynamic> list =
      List<dynamic>.from(controller.senderRankingFor('daily').toList());

      list.sort(
            (a, b) => _rankingTotalCoin(b).compareTo(_rankingTotalCoin(a)),
      );

      final int pageCount = (list.length / 3).ceil();
      if (pageCount <= 1) return;

      final int nextPage = (_rankingCurrentPage + 1) % pageCount;
      _rankingPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _startFamilyAutoSlide() {
    _familyAutoTimer?.cancel();
    _familyAutoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_familyPageController.hasClients) return;

      final int familyCount = _familyController.rankingList.length;
      final int pageCount = (familyCount / 5).ceil();

      if (pageCount <= 1) return;

      // Always move to the NEXT virtual page.
      // This keeps the animation continuously bottom -> top.
      final int nextPage = _familyCurrentPage + 1;

      _familyPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    });
  }


  void _startCpAutoSlide() {
    _cpAutoTimer?.cancel();

    _cpAutoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_cpPageController.hasClients) return;

      final int coupleCount = homeController.cpActiveCouples.length;
      if (coupleCount <= 1) return;

      // Virtual pages always increase, therefore the animation always moves
      // bottom -> top, exactly like the Family shortcut slider.
      final int nextPage = _cpCurrentPage + 1;

      _cpPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  String _bannerString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _bannerImage(dynamic banner) {
    if (banner is! Map) return '';
    final String image = _bannerString(banner['image']);
    if (image.isEmpty || image.startsWith('file:///')) return '';
    return image.startsWith('http') ? image : ImageHelper.getImageUrl(image);
  }

  Future<void> _refreshBannerList() async {
    await homeController.showBannerList();
    if (!mounted) return;
    final int length = homeController.bannerLstData.length;
    if (length == 0) {
      setState(() => _bannerCurrentIndex = 0);
      return;
    }
    if (_bannerCurrentIndex >= length) {
      setState(() => _bannerCurrentIndex = length - 1);
    }
  }

  Future<void> _openSafeBannerWebView({
    required String link,
    String? title,
  }) async {
    final String cleanLink = _bannerString(link);
    if (cleanLink.isEmpty) return;

    final Uri? uri = Uri.tryParse(cleanLink);
    if (uri == null || (!uri.hasScheme && !cleanLink.startsWith('www.'))) {
      Fluttertoast.showToast(
        msg: ('Invalid link').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final String normalizedLink = uri.hasScheme
        ? cleanLink
        : 'https://$cleanLink';

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SafeBannerWebViewPage(
          initialUrl: normalizedLink,
          title: _bannerString(title).isNotEmpty
              ? _bannerString(title)
              : ('Details').appTr,
        ),
      ),
    );
  }

  String _findCpBannerLink() {
    try {
      for (final dynamic raw in homeController.bannerLstData) {
        if (raw is! Map) continue;

        final String title =
        _bannerString(raw['title']).toLowerCase();
        final String link = _bannerString(raw['link']);
        final String linkLower = link.toLowerCase();

        if (link.isNotEmpty &&
            (title == 'cp' ||
                title.contains('cp ranking') ||
                linkLower.contains('/cp_ranking'))) {
          return link;
        }
      }
    } catch (e) {
      debugPrint('CP banner link search error: $e');
    }

    return '';
  }

  Future<void> _openCpRankingFromCard() async {
    String cpLink = _findCpBannerLink();

    // If the banner API is still loading, refresh once and try again so
    // the CP card always uses the exact same link configured for the CP banner.
    if (cpLink.isEmpty) {
      try {
        await homeController.showBannerList();
      } catch (e) {
        debugPrint('CP banner refresh error: $e');
      }
      cpLink = _findCpBannerLink();
    }

    if (cpLink.isEmpty) {
      Fluttertoast.showToast(
        msg: ('CP ranking link not found').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 12.0,
      );
      return;
    }

    await _openSafeBannerWebView(
      link: cpLink,
      title: ('CP Ranking').appTr,
    );
  }

  Future<void> _handleBannerTap(dynamic banner) async {
    if (banner is! Map) return;

    final String link = _bannerString(banner['link']);
    final String phone = _bannerString(banner['phone']);
    final String title = _bannerString(banner['title']);

    if (link.isNotEmpty) {
      await _openSafeBannerWebView(
        link: link,
        title: title,
      );
      return;
    }

    if (phone.isNotEmpty) {
      if (!_canOpenBannerWhatsApp) return;
      await homeController.openWhatsApp(phone);
      return;
    }

    Fluttertoast.showToast(
      msg: ('No link or WhatsApp number found').appTr,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  Widget _bannerShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: Get.width * 0.025),
          width: Get.width * 0.95,
          height: Get.height * 0.12,
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bannerDot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 6,
      width: active ? 18 : 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        boxShadow: active
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
    );
  }

  Widget _buildBannerPager() {
    return FutureBuilder<void>(
      future: _bannerFuture,
      builder: (context, snapshot) {
        final bool firstLoading = snapshot.connectionState == ConnectionState.waiting &&
            homeController.bannerLstData.isEmpty;

        if (firstLoading) return _bannerShimmer();

        return Obx(() {
          final banners = homeController.bannerLstData;
          if (banners.isEmpty) return const SizedBox();

          final int safeIndex = _bannerCurrentIndex.clamp(0, banners.length - 1).toInt();

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshBannerList,
                  color: kAppbarColor,
                  child: PageView.builder(
                    controller: _bannerPageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: banners.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() => _bannerCurrentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      final String imageUrl = _bannerImage(banner);
                      final bool hasImage = imageUrl.isNotEmpty;
                      final bool hasLink = banner is Map && _bannerString(banner['link']).isNotEmpty;
                      final bool hasPhone = banner is Map && _bannerString(banner['phone']).isNotEmpty;

                      return AnimatedPadding(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: Get.width * 0.025,
                          vertical: 0,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _handleBannerTap(banner),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: Colors.grey[300]),
                                  if (hasImage)
                                    CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      fadeInDuration: const Duration(milliseconds: 220),
                                      placeholder: (context, url) => Shimmer.fromColors(
                                        baseColor: Colors.grey[300]!,
                                        highlightColor: Colors.grey[100]!,
                                        child: Container(color: Colors.white),
                                      ),
                                      errorWidget: (context, url, error) => Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey[600],
                                          size: 40,
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey[600],
                                        size: 40,
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.10),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasLink || hasPhone)
                                    Positioned(
                                      right: 10,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.35),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.22),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              hasLink ? Icons.open_in_new_rounded : Icons.call_rounded,
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              hasLink ? ('Open').appTr: ('WhatsApp').appTr,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
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
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                      (index) => _bannerDot(active: index == safeIndex),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildHomeShortcutCards() {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final double screenWidth = outerConstraints.maxWidth;

        final double horizontalPadding =
        (screenWidth * 0.030).clamp(8.0, 14.0).toDouble();
        final double gap =
        (screenWidth * 0.020).clamp(6.0, 10.0).toDouble();

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            (screenWidth * 0.015).clamp(5.0, 8.0).toDouble(),
            horizontalPadding,
            (screenWidth * 0.012).clamp(4.0, 7.0).toDouble(),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth =
                  (constraints.maxWidth - (gap * 2)) / 3;

              // Reference card ratio stays stable on small + large phones.
              final double cardHeight =
              (cardWidth * 0.72).clamp(74.0, 112.0).toDouble();

              return Row(
                children: [
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _homeShortcutCard(
                      title: ('Ranking').appTr,
                      colors: const [
                        Color(0xFFFFB915),
                        Color(0xFFFFCA35),
                      ],
                      onTap: () {
                        Get.to(
                              () => Allrank(),
                          transition: Transition.rightToLeft,
                        );
                      },
                      child: _rankingCardArtwork(cardWidth),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _homeShortcutCard(
                      title: 'CP',
                      colors: const [
                        Color(0xFFFF5FA2),
                        Color(0xFFE944B5),
                      ],
                      onTap: () {
                        unawaited(_openCpRankingFromCard());
                      },
                      child: _cpCardArtwork(cardWidth),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _homeShortcutCard(
                      title: ('Family').appTr,
                      colors: const [
                        Color(0xFF23D9E7),
                        Color(0xFF169DEB),
                      ],
                      onTap: () {
                        Get.to(
                              () => const FamilyRankingApiPage(),
                          transition: Transition.rightToLeft,
                        );
                      },
                      child: _familyCardArtwork(cardWidth),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _homeShortcutCard({
    required String title,
    required List<Color> colors,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final card = LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double radius = (w * .12).clamp(11.0, 16.0).toDouble();
        final double titleSize = (w * .14).clamp(13.0, 17.0).toDouble();
        final double topPad = (h * .085).clamp(5.0, 8.0).toDouble();
        final double sidePad = (w * .055).clamp(4.0, 7.0).toDouble();

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: (w * .06).clamp(5.0, 8.0).toDouble(),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                Positioned(
                  right: -w * .14,
                  top: -h * .26,
                  child: Container(
                    width: w * .62,
                    height: w * .62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                ),
                Positioned(
                  left: -w * .18,
                  bottom: -h * .42,
                  child: Container(
                    width: w * .72,
                    height: w * .72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    sidePad,
                    topPad,
                    sidePad,
                    (h * .045).clamp(3.0, 5.0).toDouble(),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: (h * .21).clamp(15.0, 22.0).toDouble(),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: (h * .035).clamp(2.0, 4.0).toDouble(),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _profileBubble({
    required double size,
    IconData icon = Icons.person_rounded,
    Color iconColor = Colors.white,
    Color? backgroundColor,
    String? badge,
    Color badgeColor = Colors.white,
  }) {
    return SizedBox(
      width: size,
      height: size + (badge == null ? 0 : 7),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor ?? Colors.black.withOpacity(0.22),
              border: Border.all(
                color: Colors.white.withOpacity(0.92),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.54),
          ),
          if (badge != null)
            Positioned(
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _rankingUserData(dynamic item) {
    try {
      if (item is Map) {
        final dynamic sender = item['sender'];
        if (sender is Map) {
          return sender.map<String, dynamic>(
                (key, value) => MapEntry(key.toString(), value),
          );
        }
        return item.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  int _rankingTotalCoin(dynamic item) {
    dynamic value = 0;
    if (item is Map) {
      value = item['total_coin'] ??
          item['wealth'] ??
          item['coins'] ??
          item['gifts_coins'] ??
          0;
    }

    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
      value.toString().replaceAll(',', '').trim(),
    ) ??
        0;
  }

  String _rankingSafeText(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _rankingProfileImage(dynamic item) {
    final Map<String, dynamic> user = _rankingUserData(item);
    final String path = _rankingSafeText(user['profile_image']);

    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    try {
      final String url = ImageHelper.getImageUrl(path);
      if (url.trim().isEmpty || url.toLowerCase() == 'null') return '';
      return url;
    } catch (_) {
      return '';
    }
  }

  String _rankingUserName(dynamic item) {
    final Map<String, dynamic> user = _rankingUserData(item);
    final String name = _rankingSafeText(user['name']);
    return name.isEmpty ? 'User' : name;
  }

  Widget _rankingRealProfileBubble({
    required dynamic item,
    required int rank,
    required double size,
    required Color badgeColor,
  }) {
    final String imageUrl = _rankingProfileImage(item);
    final String name = _rankingUserName(item);
    final String firstLetter =
    name.trim().isEmpty ? 'U' : name.trim().substring(0, 1).toUpperCase();

    return SizedBox(
      width: size,
      height: size + 5,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.94),
              border: Border.all(
                color: Colors.white,
                width: rank == 1 ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isEmpty
                ? Center(
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: const Color(0xFF784400),
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
                : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => Container(
                color: Colors.white.withOpacity(0.90),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    color: const Color(0xFF784400),
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingPage({
    required List<dynamic> pageItems,
    required int pageStart,
    required double cardWidth,
  }) {
    final double normalSize =
    (cardWidth * 0.265).clamp(25.0, 34.0).toDouble();
    final double topOneSize =
    (cardWidth * 0.315).clamp(30.0, 41.0).toDouble();

    // First page keeps the reference Ranking-card look:
    // rank 2 on the left, rank 1 bigger in the center, rank 3 on the right.
    if (pageStart == 0 && pageItems.length >= 3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _rankingRealProfileBubble(
            item: pageItems[1],
            rank: 2,
            size: normalSize,
            badgeColor: const Color(0xFF9CAEC4),
          ),
          const SizedBox(width: 2),
          _rankingRealProfileBubble(
            item: pageItems[0],
            rank: 1,
            size: topOneSize,
            badgeColor: const Color(0xFFFFC400),
          ),
          const SizedBox(width: 2),
          _rankingRealProfileBubble(
            item: pageItems[2],
            rank: 3,
            size: normalSize,
            badgeColor: const Color(0xFFC77B4A),
          ),
        ],
      );
    }

    // Every next slider page shows the next 3 ranking users.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(pageItems.length, (localIndex) {
        final int rank = pageStart + localIndex + 1;
        final Color badgeColor = rank == 1
            ? const Color(0xFFFFC400)
            : rank == 2
            ? const Color(0xFF9CAEC4)
            : rank == 3
            ? const Color(0xFFC77B4A)
            : const Color(0xFF8A5A22);

        return Padding(
          padding: EdgeInsets.only(
            right: localIndex == pageItems.length - 1 ? 0 : 3,
          ),
          child: _rankingRealProfileBubble(
            item: pageItems[localIndex],
            rank: rank,
            size: normalSize,
            badgeColor: badgeColor,
          ),
        );
      }),
    );
  }

  Widget _rankingLoadingArtwork(double cardWidth) {
    final double size = (cardWidth * 0.26).clamp(25.0, 34.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        3,
            (index) => Padding(
          padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.38),
            highlightColor: Colors.white.withOpacity(0.78),
            child: Container(
              width: index == 1 ? size * 1.15 : size,
              height: index == 1 ? size * 1.15 : size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rankingCardArtwork(double cardWidth) {
    final RankingController controller =
    Get.isRegistered<RankingController>()
        ? Get.find<RankingController>()
        : Get.put(RankingController());

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: -3,
          left: 0,
          right: 0,
          child: Icon(
            Icons.workspace_premium_rounded,
            size: (cardWidth * 0.76).clamp(70.0, 96.0).toDouble(),
            color: Colors.white.withOpacity(0.20),
          ),
        ),
        Positioned.fill(
          child: Obx(() {
            final List<dynamic> list = List<dynamic>.from(
              controller.senderRankingFor('daily').toList(),
            );

            list.sort(
                  (a, b) => _rankingTotalCoin(b).compareTo(_rankingTotalCoin(a)),
            );

            if (controller.isLoading.value && list.isEmpty) {
              return Transform.translate(
                offset: const Offset(0, -6),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _rankingLoadingArtwork(cardWidth),
                ),
              );
            }

            if (list.isEmpty) {
              return Transform.translate(
                offset: const Offset(0, -6),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _profileBubble(
                        size: (cardWidth * 0.25).clamp(24.0, 34.0).toDouble(),
                        badge: '2',
                        badgeColor: const Color(0xFFB8C4D4),
                      ),
                      const SizedBox(width: 2),
                      _profileBubble(
                        size: (cardWidth * 0.31).clamp(29.0, 42.0).toDouble(),
                        badge: '1',
                        badgeColor: const Color(0xFFFFD43B),
                      ),
                      const SizedBox(width: 2),
                      _profileBubble(
                        size: (cardWidth * 0.25).clamp(24.0, 34.0).toDouble(),
                        badge: '3',
                        badgeColor: const Color(0xFFD98C62),
                      ),
                    ],
                  ),
                ),
              );
            }

            final int pageCount = (list.length / 3).ceil();

            if (_rankingCurrentPage >= pageCount) {
              _rankingCurrentPage = 0;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_rankingPageController.hasClients) return;
                _rankingPageController.jumpToPage(0);
              });
            }

            return Transform.translate(
              offset: const Offset(0, -6),
              child: PageView.builder(
                controller: _rankingPageController,
                physics: pageCount > 1
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: pageCount,
                onPageChanged: (page) {
                  _rankingCurrentPage = page;
                },
                itemBuilder: (context, pageIndex) {
                  final int start = pageIndex * 3;
                  final int end =
                  (start + 3) > list.length ? list.length : (start + 3);
                  final List<dynamic> pageItems = list.sublist(start, end);

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: _rankingPage(
                      pageItems: pageItems,
                      pageStart: start,
                      cardWidth: cardWidth,
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Map<String, dynamic> _safePreviewMap(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
            (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }

  String _previewProfileImageFromMap(Map<String, dynamic> user) {
    final String direct = _rankingSafeText(
      user['profile_image_url'] ??
          user['avatar_url'] ??
          user['image_url'] ??
          user['photo_url'],
    );

    if (direct.isNotEmpty) {
      if (direct.startsWith('http://') || direct.startsWith('https://')) {
        return direct;
      }
      return ImageHelper.getImageUrl(direct);
    }

    final String path = _rankingSafeText(
      user['profile_image'] ??
          user['avatar'] ??
          user['image'] ??
          user['photo'],
    );

    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return ImageHelper.getImageUrl(path);
  }

  String _previewUserName(Map<String, dynamic> user) {
    final String name = _rankingSafeText(
      user['name'] ??
          user['username'] ??
          user['full_name'] ??
          user['display_name'],
    );
    return name.isEmpty ? 'User' : name;
  }

  Widget _compactNetworkAvatar({
    required String imageUrl,
    required String name,
    required double size,
    required Color ringColor,
  }) {
    final String firstLetter =
    name.trim().isEmpty ? 'U' : name.trim().substring(0, 1).toUpperCase();

    // CP card profile: no outer white border/ring.
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Container(
          color: Colors.white.withOpacity(.18),
          alignment: Alignment.center,
          child: Text(
            firstLetter,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * .38,
            ),
          ),
        )
            : CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, __) => Container(
            color: Colors.white.withOpacity(.16),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.white.withOpacity(.18),
            alignment: Alignment.center,
            child: Text(
              firstLetter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * .38,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _cpActiveUser(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _cpActiveProfileImage(Map<String, dynamic> user) {
    final String raw = _rankingSafeText(
      user['profile_image'] ??
          user['profile_image_url'] ??
          user['avatar'] ??
          user['image'],
    );

    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    try {
      return ImageHelper.getImageUrl(raw);
    } catch (_) {
      return '';
    }
  }

  String _cpActiveName(Map<String, dynamic> user) {
    final String name = _rankingSafeText(
      user['name'] ??
          user['username'] ??
          user['full_name'] ??
          user['display_name'],
    );
    return name.isEmpty ? 'User' : name;
  }

  Widget _cpCouplePage({
    required dynamic rawCouple,
    required double cardWidth,
  }) {
    final Map<String, dynamic> couple = _safePreviewMap(rawCouple);
    final Map<String, dynamic> userOne = _cpActiveUser(couple['user_1']);
    final Map<String, dynamic> userTwo = _cpActiveUser(couple['user_2']);

    final String imageOne = _cpActiveProfileImage(userOne);
    final String imageTwo = _cpActiveProfileImage(userTwo);
    final String nameOne = _cpActiveName(userOne);
    final String nameTwo = _cpActiveName(userTwo);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double base = w < h ? w : h;

        // Bigger CP couple profiles.
        final double avatarSize =
        (base * .64).clamp(33.0, 47.0).toDouble();

        // Same CP SVGA used on the Profile page.
        final double cpSvgaSize =
        (base * .46).clamp(24.0, 34.0).toDouble();

        final double gap =
        (w * .006).clamp(0.5, 1.5).toDouble();

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -w * .04,
              bottom: -h * .28,
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white.withOpacity(.09),
                size: base * 1.08,
              ),
            ),
            Positioned(
              right: w * .01,
              top: -h * .05,
              child: Transform.rotate(
                angle: .22,
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.white.withOpacity(.07),
                  size: base * .50,
                ),
              ),
            ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _compactNetworkAvatar(
                      imageUrl: imageOne,
                      name: nameOne,
                      size: avatarSize,
                      ringColor: Colors.white.withOpacity(.98),
                    ),
                    // SizedBox(width: gap),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        width: kHeight*0.05,
                        height: kHeight*0.05,
                        child: SVGAEasyPlayer(
                          assetsName: 'assets/svga/Level/cp_info_bg (1).svga',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // SizedBox(width: gap),
                    _compactNetworkAvatar(
                      imageUrl: imageTwo,
                      name: nameTwo,
                      size: avatarSize,
                      ringColor: Colors.white.withOpacity(.98),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cpLoadingArtwork(double cardWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double base = w < h ? w : h;
        final double avatar =
        (base * .64).clamp(33.0, 47.0).toDouble();
        final double cpSvgaSize =
        (base * .46).clamp(24.0, 34.0).toDouble();

        Widget bubble() {
          return Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(.26),
            highlightColor: Colors.white.withOpacity(.72),
            child: Container(
              width: avatar,
              height: avatar,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          );
        }

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble(),
              const SizedBox(width: 5),
              SizedBox(
                width: cpSvgaSize,
                height: cpSvgaSize,
                child: SVGAEasyPlayer(
                  assetsName: 'assets/svga/Level/cp_info_bg (1).svga',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 5),
              bubble(),
            ],
          ),
        );
      },
    );
  }

  Widget _cpEmptyArtwork(double cardWidth) {
    return Center(
      child: Icon(
        Icons.favorite_border_rounded,
        color: Colors.white.withOpacity(.78),
        size: (cardWidth * .30).clamp(28.0, 40.0).toDouble(),
      ),
    );
  }

  Widget _cpCardArtwork(double cardWidth) {
    return Obx(() {
      final List<dynamic> couples =
      List<dynamic>.from(homeController.cpActiveCouples);

      if (homeController.cpActiveCouplesLoading.value && couples.isEmpty) {
        return _cpLoadingArtwork(cardWidth);
      }

      if (couples.isEmpty) {
        return _cpEmptyArtwork(cardWidth);
      }

      final int coupleCount = couples.length;

      return PageView.builder(
        controller: _cpPageController,
        scrollDirection: Axis.vertical,
        physics: coupleCount > 1
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),

        // A large virtual page count keeps the slider looping forever while
        // preserving the same bottom -> top direction on every transition.
        itemCount: coupleCount > 1 ? 1000000 : 1,

        onPageChanged: (virtualPage) {
          _cpCurrentPage = virtualPage;
        },
        itemBuilder: (context, virtualPage) {
          final int logicalIndex =
          coupleCount <= 1 ? 0 : virtualPage % coupleCount;

          return _cpCouplePage(
            rawCouple: couples[logicalIndex],
            cardWidth: cardWidth,
          );
        },
      );
    });
  }

  String _familyPreviewOwnerImage(dynamic family) {
    try {
      final String owner = _rankingSafeText(family.ownerProfileImageUrl);
      if (owner.isNotEmpty) return owner;

      final String logo = _rankingSafeText(family.logoUrl);
      if (logo.isNotEmpty) return logo;
    } catch (_) {}
    return '';
  }

  String _familyPreviewLogo(dynamic family) {
    try {
      final String logo = _rankingSafeText(family.logoUrl);
      if (logo.isNotEmpty) return logo;

      final String owner = _rankingSafeText(family.ownerProfileImageUrl);
      if (owner.isNotEmpty) return owner;
    } catch (_) {}
    return '';
  }

  String _familyPreviewName(dynamic family) {
    try {
      final String owner = _rankingSafeText(family.ownerName);
      if (owner.isNotEmpty) return owner;

      final String name = _rankingSafeText(family.name);
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return 'Family';
  }

  // Reference image-er moto LEFT side-e family logo/emblem.
  // Important: eta circle crop kora hocche na, jate family logo full shape-e dekha jay.
  Widget _familyReferenceMainLogo({
    required dynamic family,
    required double size,
    required int rank,
  }) {
    final String imageUrl = _familyPreviewLogo(family);
    final String name = _familyPreviewName(family);
    final String firstLetter =
    name.trim().isEmpty ? 'F' : name.trim().substring(0, 1).toUpperCase();

    return SizedBox(
      width: size * 1.12,
      height: size * 1.12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: imageUrl.isEmpty
                ? Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * .20),
                color: Colors.white.withOpacity(.16),
              ),
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * .42,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
                : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => Shimmer.fromColors(
                baseColor: Colors.white.withOpacity(.18),
                highlightColor: Colors.white.withOpacity(.60),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(size * .20),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * .20),
                  color: Colors.white.withOpacity(.16),
                ),
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * .42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),

          // Small ranking badge like the reference family emblem.
          Positioned(
            top: -size * .06,
            left: size * .02,
            child: Container(
              constraints: BoxConstraints(
                minWidth: (size * .32).clamp(14.0, 19.0).toDouble(),
              ),
              height: (size * .30).clamp(14.0, 18.0).toDouble(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEAF1FF),
                    Color(0xFF8DB7FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.white.withOpacity(.95),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$rank',
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFF4052A8),
                  fontSize: (size * .15).clamp(7.0, 9.0).toDouble(),
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reference image-er right side-er small round profile.
  Widget _familyReferenceAvatar({
    required String imageUrl,
    required String name,
    required double size,
  }) {
    final String firstLetter =
    name.trim().isEmpty ? 'F' : name.trim().substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.15),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.13),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Container(
          color: Colors.white.withOpacity(.20),
          alignment: Alignment.center,
          child: Text(
            firstLetter,
            style: TextStyle(
              color: const Color(0xFF1575B8),
              fontWeight: FontWeight.w900,
              fontSize: size * .37,
            ),
          ),
        )
            : CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 100),
          placeholder: (_, __) => Container(
            color: Colors.white.withOpacity(.18),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.white.withOpacity(.20),
            alignment: Alignment.center,
            child: Text(
              firstLetter,
              style: TextStyle(
                color: const Color(0xFF1575B8),
                fontWeight: FontWeight.w900,
                fontSize: size * .37,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Exactly 5 profile photos on the right:
  // top row = 3, bottom row = 2 — reference screenshot-er moto.
  Widget _familyFiveProfileCluster({
    required List<dynamic> pageFamilies,
    required double avatarSize,
    required double horizontalGap,
    required double verticalGap,
  }) {
    Widget profileAt(int index) {
      if (index >= pageFamilies.length) {
        return SizedBox(
          width: avatarSize,
          height: avatarSize,
        );
      }

      final dynamic family = pageFamilies[index];

      return _familyReferenceAvatar(
        imageUrl: _familyPreviewOwnerImage(family),
        name: _familyPreviewName(family),
        size: avatarSize,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            profileAt(0),
            SizedBox(width: horizontalGap),
            profileAt(1),
            SizedBox(width: horizontalGap),
            profileAt(2),
          ],
        ),
        SizedBox(height: verticalGap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            profileAt(3),
            SizedBox(width: horizontalGap),
            profileAt(4),
          ],
        ),
      ],
    );
  }

  Widget _familyReferencePage({
    required List<dynamic> pageFamilies,
    required double cardWidth,
    required double logoSize,
    required double avatarSize,
    required double horizontalGap,
    required double verticalGap,
    required int pageStart,
  }) {
    if (pageFamilies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (cardWidth * .01).clamp(1.0, 3.0).toDouble(),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 39,
            child: Align(
              alignment: Alignment.center,
              child: _familyReferenceMainLogo(
                family: pageFamilies.first,
                size: logoSize,
                rank: pageStart + 1,
              ),
            ),
          ),
          Expanded(
            flex: 61,
            child: Align(
              alignment: Alignment.center,
              child: _familyFiveProfileCluster(
                pageFamilies: pageFamilies,
                avatarSize: avatarSize,
                horizontalGap: horizontalGap,
                verticalGap: verticalGap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _familyLoadingReference(double cardWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double base = w < h ? w : h;

        final double logo =
        (base * .69).clamp(32.0, 46.0).toDouble();
        final double avatar =
        (base * .31).clamp(16.0, 21.0).toDouble();
        final double hGap =
        (base * .045).clamp(2.0, 3.5).toDouble();
        final double vGap =
        (base * .045).clamp(2.0, 3.5).toDouble();

        Widget circle() {
          return Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(.28),
            highlightColor: Colors.white.withOpacity(.72),
            child: Container(
              width: avatar,
              height: avatar,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 39,
              child: Center(
                child: Shimmer.fromColors(
                  baseColor: Colors.white.withOpacity(.26),
                  highlightColor: Colors.white.withOpacity(.70),
                  child: Container(
                    width: logo,
                    height: logo,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 61,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        circle(),
                        SizedBox(width: hGap),
                        circle(),
                        SizedBox(width: hGap),
                        circle(),
                      ],
                    ),
                    SizedBox(height: vGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        circle(),
                        SizedBox(width: hGap),
                        circle(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _familyCardArtwork(double cardWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double base = w < h ? w : h;

        // Tuned for the reference card:
        // large family emblem on left + 5 small profiles (3 + 2) on right.
        final double logoSize =
        (base * .69).clamp(32.0, 46.0).toDouble();
        final double avatarSize =
        (base * .31).clamp(16.0, 21.0).toDouble();
        final double horizontalGap =
        (base * .045).clamp(2.0, 3.5).toDouble();
        final double verticalGap =
        (base * .045).clamp(2.0, 3.5).toDouble();

        return Stack(
          children: [
            // Soft background decoration only.
            Positioned(
              right: -w * .10,
              bottom: -h * .28,
              child: Icon(
                Icons.groups_rounded,
                size: base * 1.25,
                color: Colors.white.withOpacity(.065),
              ),
            ),
            Positioned.fill(
              child: Obx(() {
                final List<dynamic> families =
                List<dynamic>.from(_familyController.rankingList);

                if (families.isEmpty) {
                  return _familyLoadingReference(cardWidth);
                }

                // 5 ranking profiles per logical page.
                final int pageCount = (families.length / 5).ceil();

                return PageView.builder(
                  controller: _familyPageController,
                  scrollDirection: Axis.vertical,
                  physics: pageCount > 1
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),

                  // Large virtual page count makes the logical pages loop
                  // continuously while always moving bottom -> top.
                  itemCount: pageCount > 1 ? 1000000 : 1,

                  onPageChanged: (virtualPage) {
                    _familyCurrentPage = virtualPage;
                  },
                  itemBuilder: (context, virtualPage) {
                    final int logicalPage =
                    pageCount <= 1 ? 0 : virtualPage % pageCount;

                    final int start = logicalPage * 5;
                    final int end =
                    (start + 5) > families.length
                        ? families.length
                        : start + 5;

                    final List<dynamic> pageFamilies =
                    families.sublist(start, end);

                    return _familyReferencePage(
                      pageFamilies: pageFamilies,
                      cardWidth: cardWidth,
                      logoSize: logoSize,
                      avatarSize: avatarSize,
                      horizontalGap: horizontalGap,
                      verticalGap: verticalGap,
                      pageStart: start,
                    );
                  },
                );
              }),
            ),
          ],
        );
      },
    );
  }


  Future<bool> _ensureMicrophonePermissionBeforeQuickLive() async {
    try {
      PermissionStatus status = await Permission.microphone.status;

      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        // Slow phones need a tiny delay after permission before Agora join/publish.
        await Future.delayed(const Duration(milliseconds: 250));
        return true;
      }

      Fluttertoast.showToast(
        msg: ('Please allow microphone permission for audio live').appTr,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 12.0,
      );

      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Microphone permission check failed: $e');
      return true;
    }
  }

  Future<void> createDefaultNineSeatBackgroundLive() async {
    if (_quickLiveCreating) return;

    final bool micReady = await _ensureMicrophonePermissionBeforeQuickLive();
    if (!micReady) return;

    final user = authController.userProfile.value.user;
    final int userId = user?.id?.toInt() ?? 0;

    if (userId <= 0) {
      Fluttertoast.showToast(
        msg: ('Please login first').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 12.0,
      );
      return;
    }

    final LivestreamController liveController =
    Get.isRegistered<LivestreamController>()
        ? Get.find<LivestreamController>()
        : Get.put(LivestreamController());

    try {
      _quickLiveCreating = true;

      // Very important: Home theke direct live create korle old mute state reset.
      liveController.mute.value = false;

      if (liveController.backgroundList.isEmpty) {
        await liveController.showBackground();
      }

      int backgroundId = -1;
      if (liveController.backgroundList.isNotEmpty) {
        final firstBg = liveController.backgroundList.first;
        if (firstBg is Map && firstBg['id'] != null) {
          backgroundId = int.tryParse(firstBg['id'].toString()) ?? -1;
        }
      }

      final String title = (user?.name?.toString().trim().isNotEmpty == true)
          ? user!.name.toString().trim()
          : 'Live Room';

      liveController.seatCount.value = 9;

      // Slow devices: allow audio permission/session to settle before create/join.
      await Future.delayed(const Duration(milliseconds: 250));

      await liveController.tryToCreateLivestream(
        streamTitle: title,
        streamType: 'audio',
        userId: userId,
        seatCountValue: 9,
        roomLayout: 0,
        roomTheme: 0,
        roomBackground: backgroundId,
      );
    } catch (e) {
      debugPrint('❌ Quick 9-seat live create failed: $e');
      Fluttertoast.showToast(
        msg: ('Live create failed').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 12.0,
      );
    } finally {
      _quickLiveCreating = false;
    }
  }

  void searchUser(String uid) {
    if (uid.isEmpty) {
      setState(() => selectedUser = null);
      return;
    }

    try {
      final user = homeController.allUserData.firstWhere(
            (u) => u['user_id'].toString() == uid,
      );

      setState(() {
        selectedUser = user;
      });
    } catch (e) {
      setState(() => selectedUser = null);
    }
  }
  @override
  Widget build(BuildContext context) {
    final HomeController hController = Get.put(HomeController());
    final RankingController controller = Get.put(RankingController());

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(Get.height * 0.06),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF190522),
                  Color(0xFF3B072F),

                ],
              ),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Column(
                children: [
                  Container(
                    width: Get.width * 0.6,
                    height: kHeight * 0.04,

                    child: Row(
                      children: [
                        Image.asset('assets/logo/linLigo-removebg-preview.png'),
                        SizedBox(width: kWeight*0.01,),
                        AnimatedGradientText(
                          text: ('LIN LIVE').appTr,
                          style: TextStyle(
                            fontSize: kHeight*0.025,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: InkWell(
                    onTap: () {
                      Get.to(
                            () => const LiveSearchView(),
                        transition: Transition.rightToLeft,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: kHeight*0.01,horizontal: kHeight*0.01),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(colors: [
                            Color(0xff9113fa),
                            Color(0xffe208fa),
                          ])
                      ),
                      child: Image.asset(
                        'assets/new/search (1).png',
                        height: Get.height * 0.025,
                        color: Colors.white,
                      ),
                    ),

                  ),
                ),
                SizedBox(width: kWeight * 0.02),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: createDefaultNineSeatBackgroundLive,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/newaudio/live Creae manu Icon-min.png',
                      height: kHeight * 0.07,
                    ),
                  ),
                ),
                SizedBox(width: kWeight * 0.01),
              ],
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF3B072F),
                Color(0xFF3B072F)
              ],
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 10,),
              SizedBox(
                height: Get.height * 0.145,
                child: _buildBannerPager(),
              ),
              _buildHomeShortcutCards(),
              GlowingTabBarBox(kHeight: kHeight),
              Expanded(
                child: TabBarView(
                  children: [
                    AllLiveListView(),
                    PopularLiveListView(),
                    AudioLiveListView(),
                    PkLiveListView(),
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


class _SafeBannerWebViewPage extends StatefulWidget {
  const _SafeBannerWebViewPage({
    required this.initialUrl,
    required this.title,
  });

  final String initialUrl;
  final String title;

  @override
  State<_SafeBannerWebViewPage> createState() =>
      _SafeBannerWebViewPageState();
}

class _SafeBannerWebViewPageState extends State<_SafeBannerWebViewPage> {
  late final WebViewController _controller;

  int _progress = 0;
  bool _loading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _errorText = null;
              _progress = 0;
            });
          },
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress.clamp(0, 100);
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _loading = false;
              _errorText = error.description.trim().isNotEmpty
                  ? error.description
                  : ('Unable to load page').appTr;
            });
          },
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _handleBack() async {
    // This in-app WebView is a single app route.
    // Back should always close it and return to Home instead of getting stuck
    // inside the website's own navigation history.
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorText = null;
      _progress = 0;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final String safeTitle =
    widget.title.trim().isEmpty ? ('Details').appTr : widget.title.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF3B072F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: ('Back').appTr,
          onPressed: _handleBack,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          safeTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: ('Reload').appTr,
            onPressed: _reload,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_loading ? 3 : 0),
          child: _loading
              ? LinearProgressIndicator(
            minHeight: 3,
            value: _progress <= 0 ? null : _progress / 100,
            backgroundColor: Colors.white.withOpacity(.18),
            valueColor:
            const AlwaysStoppedAnimation<Color>(Color(0xFFFF4BB2)),
          )
              : const SizedBox.shrink(),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            if (_errorText != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            color: Color(0xFF3B072F),
                            size: 48,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            ('Unable to load page').appTr,
                            style: const TextStyle(
                              color: Color(0xFF24252A),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF7A7D85),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _reload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B072F),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(('Reload').appTr),
                          ),
                        ],
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
}


Widget shimmerWidget() {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[300],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 14, color: Colors.white),
              const SizedBox(height: 8),
              Container(width: 150, height: 12, color: Colors.white),
              const SizedBox(height: 8),
              Container(width: 100, height: 12, color: Colors.white),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget profileCard(dynamic user) {
  return Container(
    key: ValueKey(user['id']),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white,
          Colors.grey.shade50,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -5,
        ),
      ],
      border: Border.all(
        color: Colors.grey.withOpacity(0.1),
        width: 1,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          homeController.visitProfile(userId: '${user['id']}');
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: kWeight * 0.04,
            vertical: kHeight * 0.015,
          ),
          child: Row(
            children: [
              Hero(
                tag: 'profile_${user['id']}',
                child: _buildProfileWithFrame(user),
              ),
              SizedBox(width: kWeight * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['name'] ?? ('Unknown').appTr,
                            style: TextStyle(
                              fontSize: kWeight * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: kWeight * 0.04,
                            color: Colors.blue,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ('ID: ${user['user_id'] ?? '---'}').appTr,
                      style: TextStyle(
                        fontSize: kWeight * 0.032,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: kWeight * 0.04,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildProfileWithFrame(dynamic user) {
  return SizedBox(
    height: kHeight * 0.08,
    width: kHeight * 0.08,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: kHeight * 0.028,
            backgroundColor: Colors.grey.shade200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: CachedNetworkImage(
                imageUrl: ImageHelper.getImageUrl(
                  user['profile_image'] ?? 'default.png',
                ),
                fit: BoxFit.cover,
                height: kHeight * 0.056,
                width: kHeight * 0.056,
                placeholder: (context, url) => CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.purple.shade300),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.person,
                  size: kHeight * 0.03,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
        if (user['active_frame'] != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: '$kDomainUrl/${user['active_frame']['asset']}',
              fit: BoxFit.contain,
              placeholder: (context, url) => const SizedBox(),
              errorWidget: (context, url, error) => const SizedBox(),
            ),
          ),
      ],
    ),
  );
}

