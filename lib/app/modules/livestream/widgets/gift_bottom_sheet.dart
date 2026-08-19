import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/home/views/widgets/tabbarshemmer.dart'
    hide kAppColor2, kAppColor1;

import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';
import 'vip_required_prompt.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

/// Play Store safe mode.
/// true = Lucky gift / cashback / recharge text hidden.
/// false = internal/private build-e old lucky/recharge UI show korte parben.
const bool kPlayStoreSafeMode = false;

class gift_bottom_sheet extends StatefulWidget {
  final dynamic isbrodcaster;
  final String liveType;

  const gift_bottom_sheet({
    super.key,
    required this.isbrodcaster,
    required this.liveType,
  });

  @override
  State<gift_bottom_sheet> createState() => _gift_bottom_sheetState();
}

class _gift_bottom_sheetState extends State<gift_bottom_sheet> {
  /// ✅ Pixel-sampled directly from the reference screenshot (see chat) —
  /// NOT the same as the app's existing `kAppColor1`/`kAppColor2` brand
  /// constants, because we don't know if those already equal these values
  /// in this project's color_constants.dart. Every "match the image
  /// exactly" accent below uses these hardcoded hex values instead of
  /// kAppColor1/kAppColor2, so the result is guaranteed to match the
  /// screenshot regardless of what the app's brand teal actually is.
  static const Color _kRefTeal = Color(0xff00e6e6); // bright cyan accent
  static const Color _kRefTealDeep = Color(0xff00b8c9); // darker teal (gradients)
  static const Color _kRefNavy = Color(0xff1c1c40); // selected-card top navy
  static const Color _kRefBg = Color(0xff1a1d26); // sheet background (flat)
  static const Color _kRefPurpleTop = Color(0xffb04bff);
  static const Color _kRefPurpleBottom = Color(0xff8f05f7);
  static const Color _kRefGold = Color(0xffffc94d);

  final LivestreamController livestreamController = Get.find();
  final WebsocketController websocketController = Get.find();
  final AuthController authController = Get.find();

  final RxList<int> selectedLocalReceiverIds = <int>[].obs;
  final Rxn<Map<String, dynamic>> selectedGift = Rxn<Map<String, dynamic>>();

  /// ✅ FIX (first send of any gift takes 8-10s, repeat sends are instant):
  /// SVGAEasyPlayer's useCache genuinely caches an SVGA after it has been
  /// loaded once — confirmed by the second send of the same gift always
  /// being instant — but nothing ever loaded a gift's SVGA before the user
  /// actually tapped send. _precacheGiftImages() explicitly skips SVGA URLs
  /// (see `_isSvga(image)` below), so every gift's animated version paid
  /// its full first-time network fetch + decode cost right at send time,
  /// with the gift-display safety-timer's ~8s floor covering that wait.
  /// These two fields drive an invisible, zero-size SVGAEasyPlayer per
  /// not-yet-cached gift (see _svgaPreloadLayer/_preloadGiftSvgaAnimations)
  /// so the same caching that already works for a second send happens
  /// quietly in the background as soon as the gift icon/panel is reachable,
  /// well before the user ever taps send.
  final Set<String> _preloadedGiftSvgaUrls = <String>{};
  final List<String> _activeSvgaPreloadUrls = <String>[];

  /// Send amount / quantity UI value.
  /// Custom এ user number দিলে Send button এর left পাশে show হবে।
  final RxString selectedSendAmount = ''.obs;
  final TextEditingController customAmountController = TextEditingController();

  /// ✅ New (screenshot-matched): quick x1/x5/x10 quantity picker shown as a
  /// "▲ x5" dropdown pill in the bottom bar. Purely a UI selection value —
  /// same as the pre-existing `selectedSendAmount` custom chip, it is not
  /// wired into `_sendSelectedGift`/`tryToSendGift` because that controller
  /// method has no quantity/multiplier parameter in this codebase. Wiring
  /// real repeat-send behaviour would need that API to accept a count.
  final RxInt quickSendMultiplier = 1.obs;

  bool get isSmallScreen => Get.width < 370;
  bool get isTinyScreen => Get.width < 340;

  double get sheetHeight {
    /// Professional bottom sheet height:
    /// small mobile 76%, normal mobile 72%, large screen 68%.
    if (Get.height < 680) return Get.height * .76;
    if (Get.height < 760) return Get.height * .72;
    return Get.height * .68;
  }

  double get avatarSize => isTinyScreen ? 36 : (isSmallScreen ? 42 : 48);
  double get avatarBoxWidth => isTinyScreen ? 46 : (isSmallScreen ? 52 : 58);

  /// Avatar circle + overlapping bottom number-badge height (used by the
  /// receiver strip's SizedBox so the badge isn't clipped). Mirrors the
  /// `badgeH * .55` overlap math used inside `_avatar`.
  double get avatarRowHeight =>
      avatarSize + (isTinyScreen ? 15 : (isSmallScreen ? 16 : 18)) * .55;
  double get tabFontSize => isTinyScreen ? 12.5 : (isSmallScreen ? 14 : 16);
  double get giftNameFontSize =>
      isTinyScreen ? 9.5 : (isSmallScreen ? 10.5 : 12.2);
  double get coinFontSize => isTinyScreen ? 10.5 : (isSmallScreen ? 11.5 : 13.2);
  double get giftImageSize => isSmallScreen ? 56 : 70;

  @override
  void dispose() {
    customAmountController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (livestreamController.giftList.isEmpty) {
      livestreamController.fetchGiftList();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncDefaultReceiver();
      livestreamController.selectedGiftCategoryIndex.value = -1;
      _precacheGiftImages();
      _preloadGiftSvgaAnimations();
    });
  }

  void _precacheGiftImages() {
    final gifts = _allGiftList().take(24).toList();

    for (final gift in gifts) {
      final image = _giftImage(gift);
      if (image.isEmpty || _isSvga(image)) continue;
      precacheImage(CachedNetworkImageProvider(image), context);
    }
  }

  /// ✅ FIX: companion to _precacheGiftImages, for the SVGA gifts that
  /// function explicitly skips. Warms SVGAEasyPlayer's own cache for the
  /// most likely-to-be-sent gifts (first 10, matching typical "popular
  /// gifts first" catalog ordering) by quietly mounting an invisible,
  /// zero-size player for each one. Capped at 10 concurrent so this does
  /// not itself create a burst of simultaneous network fetches. Already-
  /// preloaded URLs are skipped so reopening the panel doesn't re-trigger
  /// finished downloads.
  void _preloadGiftSvgaAnimations() {
    final gifts = _allGiftList().take(10).toList();
    final List<String> toPreload = [];

    for (final gift in gifts) {
      final image = _giftImage(gift);
      if (image.isEmpty || !_isSvga(image)) continue;
      if (_preloadedGiftSvgaUrls.contains(image)) continue;
      toPreload.add(image);
    }

    if (toPreload.isEmpty || !mounted) return;

    setState(() {
      _activeSvgaPreloadUrls
        ..clear()
        ..addAll(toPreload);
    });
  }

  /// Called by each invisible preload player once its SVGA has actually
  /// finished loading and playing through once — at that point
  /// SVGAEasyPlayer's own cache already holds the decoded file, so it is
  /// safe to unmount this warm-up instance.
  void _onGiftSvgaPreloaded(String url) {
    _preloadedGiftSvgaUrls.add(url);
    if (!mounted) return;
    setState(() {
      _activeSvgaPreloadUrls.remove(url);
    });
  }

  /// Zero-size, non-interactive SVGA players whose only purpose is to
  /// trigger SVGAEasyPlayer's own network fetch + decode + cache for gifts
  /// the user has not sent yet, so the first real send is as fast as a
  /// repeat send already is today.
  Widget _svgaPreloadLayer() {
    if (_activeSvgaPreloadUrls.isEmpty) return const SizedBox.shrink();

    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: Stack(
          children: _activeSvgaPreloadUrls
              .map(
                (url) => SVGAEasyPlayer(
              key: ValueKey('gift_svga_preload_$url'),
              resUrl: url,
              loops: 0,
              useCache: true,
              onFinished: () => _onGiftSvgaPreloaded(url),
            ),
          )
              .toList(growable: false),
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _hostUser() {
    final map = _asMap(widget.isbrodcaster);

    if (map['user'] is Map) {
      return _asMap(map['user']);
    }

    return map;
  }

  String _safeImage(dynamic value) {
    final raw = value?.toString().trim() ?? '';

    if (raw.isEmpty || raw == 'null' || raw == 'file:///') return '';

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return ImageHelper.getImageUrl(raw);
  }

  bool _isSvga(dynamic value) {
    return value?.toString().toLowerCase().endsWith('.svga') == true;
  }

  num _safeNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString().trim()) ?? 0;
  }

  num _currentUserCoins() {
    final user = authController.userProfile.value.user;
    return _safeNum(user?.levelCoins);
  }

  /// Lucky gift/category only 0 coin er beshi thakle show hobe.
  /// coins 0/null/empty hole Lucky option hide thakbe.
  bool get _canShowLuckyGift => _currentUserCoins() > 0;

  String _giftImage(Map<String, dynamic> gift) {
    return _safeImage(
      gift['show_image'] ??
          gift['gift_image'] ??
          gift['image'] ??
          gift['icon'] ??
          gift['thumbnail'],
    );
  }

  String _categoryName(Map<String, dynamic> gift) {
    return (gift['category'] ??
        gift['gift_category'] ??
        gift['type'] ??
        gift['gift_type'] ??
        'Gifts')
        .toString()
        .trim();
  }

  bool _isLuckyGift(Map<String, dynamic> gift) {
    final category = _categoryName(gift).toLowerCase();
    final pretty = _prettyCategory(_categoryName(gift)).toLowerCase();

    final backCoin = gift['back_coin'];
    final luckyRatio = gift['lucky_ratio'];
    final luckyCoin = gift['lucky_coin'];
    final isLucky = gift['is_lucky'];

    return category.contains('lucky') ||
        pretty.contains('lucky') ||
        (backCoin != null &&
            backCoin.toString() != 'null' &&
            backCoin.toString() != '0') ||
        (luckyRatio != null && luckyRatio.toString() != 'null') ||
        (luckyCoin != null && luckyCoin.toString() != 'null') ||
        isLucky == true ||
        isLucky.toString() == '1';
  }

  bool _isVipGift(Map<String, dynamic> gift) {
    final category = _categoryName(gift).toLowerCase();
    final raw = gift['is_vip'] ?? gift['vip_only'] ?? gift['requires_vip'];
    return category.contains('vip') ||
        raw == true ||
        raw == 1 ||
        raw?.toString().toLowerCase() == 'true' ||
        raw?.toString() == '1';
  }

  bool get _canUseVipGifts => livestreamController.currentVipPrivileges.vipGift;

  bool _shouldShowGift(Map<String, dynamic> gift) {
    final bool isLucky = _isLuckyGift(gift);

    /// Play Store safe mode: hide lucky/cashback style gifts.
    if (kPlayStoreSafeMode && isLucky) return false;

    /// Normal/private build: Lucky gift only user coin 0 er beshi hole show hobe.
    if (isLucky && !_canShowLuckyGift) return false;

    return true;
  }

  String _prettyCategory(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('robot')) return 'Robot';
    if (lower.contains('vip')) return ('VIP').appTr;
    if (lower.contains('animal')) return 'Animal';
    if (lower.contains('face')) return 'Face';
    if (lower.contains('love')) return 'Love';
    if (lower.contains('funny')) return 'Funny';

    /// Play Store safe mode-e Lucky category public UI te ashbe na.
    if (lower.contains('lucky')) return 'Lucky';

    if (lower.contains('custom')) return ('Custom').appTr;
    if (lower.contains('country')) return ('Country').appTr;
    if (lower.contains('cp')) return ('CP').appTr;
    if (lower.contains('gift')) return 'Gifts';

    return name.isEmpty ? 'Gifts' : name;
  }

  List<String> _giftCategories() {
    final set = <String>{};

    for (final item in livestreamController.giftList) {
      final gift = Map<String, dynamic>.from(item);

      if (!_shouldShowGift(gift)) continue;

      final category = _prettyCategory(_categoryName(gift));

      if (kPlayStoreSafeMode && category.toLowerCase().contains('lucky')) {
        continue;
      }

      if (category.isNotEmpty) {
        set.add(category);
      }
    }

    final list = set.toList();

    final order = [
      'Gifts',
      'Robot',
      ('VIP').appTr,
      'Animal',
      'Face',
      'Love',
      'Funny',
      if (!kPlayStoreSafeMode && _canShowLuckyGift) 'Lucky',
      ('Custom').appTr,
      ('CP').appTr,
      ('Country').appTr,
    ];

    list.sort((a, b) {
      final ai = order.indexOf(a);
      final bi = order.indexOf(b);

      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;

      return a.compareTo(b);
    });

    return list;
  }

  List<Map<String, dynamic>> _allGiftList() {
    return livestreamController.giftList
        .map((e) => Map<String, dynamic>.from(e))
        .where(_shouldShowGift)
        .toList();
  }

  List<Map<String, dynamic>> _giftListBySelectedCategory() {
    final selectedIndex = livestreamController.selectedGiftCategoryIndex.value;

    if (selectedIndex == -1) {
      return _allGiftList();
    }

    final categories = _giftCategories();

    if (categories.isEmpty) {
      return _allGiftList();
    }

    final safeIndex = selectedIndex < 0
        ? 0
        : selectedIndex >= categories.length
        ? categories.length - 1
        : selectedIndex;

    final selectedCategory = categories[safeIndex].toLowerCase();

    return livestreamController.giftList
        .map((e) => Map<String, dynamic>.from(e))
        .where(_shouldShowGift)
        .where(
          (gift) =>
      _prettyCategory(_categoryName(gift)).toLowerCase() ==
          selectedCategory,
    )
        .toList();
  }

  List<Map<String, dynamic>> _receiverList() {
    final receivers = <Map<String, dynamic>>[];
    final added = <String>{};

    void addUser(Map<String, dynamic> user, {dynamic seatNo}) {
      final id = int.tryParse('${user['id'] ?? 0}') ?? 0;

      if (id == 0) return;
      if (added.contains(id.toString())) return;

      added.add(id.toString());

      receivers.add({...user, 'id': id, 'seat_no': seatNo});
    }

    final host = _hostUser();
    addUser(host, seatNo: host['seat_no'] ?? 1);

    for (final item in websocketController.liveCallList) {
      if (item is! Map) continue;

      final call = Map<String, dynamic>.from(item);
      final String status =
      (call['call_status'] ?? call['status'] ?? 'accepted')
          .toString()
          .toLowerCase();

      final int seatNo = int.tryParse('${call['seat_no'] ?? 0}') ?? 0;

      if (seatNo <= 0 ||
          !const <String>{
            'accepted',
            'joined',
            'active',
            'live',
            'on_seat',
          }.contains(status)) {
        continue;
      }

      final user = call['user'] is Map
          ? Map<String, dynamic>.from(call['user'])
          : <String, dynamic>{
        'id': call['caller_id'] ?? call['user_id'] ?? call['id'],
        'name': call['caller_name'] ?? call['name'] ?? ('User').appTr,
        'profile_image': call['profile_image'],
      };

      addUser(user, seatNo: call['seat_no']);
    }

    /*
    |--------------------------------------------------------------------------
    | Gift receivers are host + active seated users only
    |--------------------------------------------------------------------------
    | Do not append the current audience user automatically. That made the gift
    | receiver count different from the real seat/receiver count.
    |--------------------------------------------------------------------------
    */
    return receivers;
  }

  List<int> _allReceiverIds(List<Map<String, dynamic>> receivers) {
    return receivers
        .map((e) => int.tryParse('${e['id'] ?? 0}') ?? 0)
        .where((id) => id != 0)
        .toList();
  }

  String _formatCoins(dynamic value) {
    final num coin = num.tryParse(value?.toString() ?? '0') ?? 0;

    if (coin >= 1000000) {
      final v = coin / 1000000;
      return v % 1 == 0 ? '${v.toInt()}m' : '${v.toStringAsFixed(1)}m';
    }

    if (coin >= 1000) {
      final v = coin / 1000;
      return v % 1 == 0 ? '${v.toInt()}k' : '${v.toStringAsFixed(1)}k';
    }

    return coin.toInt().toString();
  }

  Future<void> _sendSelectedGift() async {
    final gift = selectedGift.value;

    if (gift == null) {
      Fluttertoast.showToast(msg: ('Please select gift').appTr);
      return;
    }

    if (_isVipGift(gift) && !_canUseVipGifts) {
      await showVipRequired(('VIP Gift').appTr);
      return;
    }

    if (_isLuckyGift(gift) && (kPlayStoreSafeMode || !_canShowLuckyGift)) {
      Fluttertoast.showToast(
        msg: ('This gift is not available right now').appTr,
      );
      selectedGift.value = null;
      return;
    }

    final giftId = int.tryParse('${gift['id'] ?? 0}') ?? 0;
    final giftPrice =
        int.tryParse('${gift['coin'] ?? gift['price'] ?? 0}') ?? 0;

    if (giftId == 0) {
      Fluttertoast.showToast(msg: ('Gift not found').appTr);
      return;
    }

    if (selectedLocalReceiverIds.isEmpty) {
      Fluttertoast.showToast(msg: ('Please select receiver').appTr);
      return;
    }

    final me = authController.userProfile.value.user;
    final myCoins = int.tryParse(me?.coins.toString() ?? '0') ?? 0;

    if (giftPrice > 0 && myCoins < giftPrice) {
      Fluttertoast.showToast(
        msg: kPlayStoreSafeMode
            ? ('Insufficient balance').appTr
            : ('Insufficient balance. Please recharge!').appTr,
        backgroundColor: Colors.white,
        textColor: Colors.red,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final receivers = selectedLocalReceiverIds.toList(growable: false);
    final optimisticGift = Map<String, dynamic>.from(gift);

    livestreamController.selectedReceiverIds
      ..clear()
      ..addAll(receivers);

    /// Calling the async method here executes its optimistic/local animation
    /// synchronously until the first network await. Therefore the gift is
    /// already queued before the bottom sheet closing animation starts.
    final Future<Map<String, dynamic>?> sendFuture = livestreamController
        .tryToSendGift(
      receiverId: receivers.first,
      giftId: giftId,
      giftPrice: giftPrice,
      localGift: optimisticGift,
    );

    selectedGift.value = null;

    if (Get.isBottomSheetOpen == true && mounted) {
      Navigator.pop(context);
    }

    unawaited(
      sendFuture.then((Map<String, dynamic>? result) {
        if (result == null) return;

        livestreamController.showQuickGiftButton(
          receiverId: receivers.first,
          giftId: giftId,
          giftPrice: giftPrice,
          gift: optimisticGift,
        );
      }),
    );
  }

  void _syncDefaultReceiver() {
    final receivers = _receiverList();
    final ids = _allReceiverIds(receivers);

    selectedLocalReceiverIds.removeWhere((id) => !ids.contains(id));

    if (selectedLocalReceiverIds.isEmpty && ids.isNotEmpty) {
      selectedLocalReceiverIds.add(ids.first);
    }

    livestreamController.selectedReceiverIds
      ..clear()
      ..addAll(selectedLocalReceiverIds);
  }

  BoxDecoration _premiumSheetDecoration() {
    return BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      // ✅ Re-confirmed by frequency analysis of the reference screenshot:
      // #1a1d26 alone covers the vast majority of the background pixels —
      // it's essentially FLAT, not a gradient. Using the exact sampled
      // color as a near-flat fill instead of guessing a darker navy blend.
      color: _kRefBg,
      boxShadow: [
        BoxShadow(
          color: const Color(0xff020814).withOpacity(.72),
          blurRadius: 34,
          offset: const Offset(0, -10),
        ),
      ],
    );
  }

  Widget _avatar(Map<String, dynamic> user) {
    final id = int.tryParse('${user['id'] ?? 0}') ?? 0;
    final image = _safeImage(user['profile_image']);
    final seatNo = user['seat_no'];

    /// ✅ Re-fixed to match the reference image exactly: the seat/receiver
    /// number sits as a small pill OVERLAPPING the bottom of the avatar
    /// ring (not below it) — unselected pill is a dark, near-invisible tag
    /// with soft grey-blue text; selected pill turns bright cyan matching
    /// the selected ring. Same tap/select logic as before, visuals only.
    final double badgeH = isTinyScreen ? 15 : (isSmallScreen ? 16 : 18);

    return Obx(() {
      final selected = selectedLocalReceiverIds.contains(id);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (id == 0) return;

          if (selected) {
            selectedLocalReceiverIds.remove(id);
          } else {
            selectedLocalReceiverIds.add(id);
          }

          livestreamController.selectedReceiverIds
            ..clear()
            ..addAll(selectedLocalReceiverIds);
        },
        child: SizedBox(
          width: avatarBoxWidth,
          height: avatarSize + badgeH * .55,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: avatarSize,
                width: avatarSize,
                padding: EdgeInsets.all(selected ? 2.2 : 1.3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kRefTeal, _kRefTealDeep],
                  )
                      : null,
                  border: selected
                      ? null
                      : Border.all(
                    color: Colors.white.withOpacity(.24),
                    width: 1.2,
                  ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: _kRefTeal.withOpacity(.50),
                        blurRadius: 14,
                        spreadRadius: .5,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xff07122a),
                  ),
                  child: ClipOval(
                    child: image.isEmpty
                        ? Container(
                      color: Colors.white12,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: isTinyScreen ? 18 : (isSmallScreen ? 20 : 22),
                      ),
                    )
                        : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white12,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: isTinyScreen ? 18 : (isSmallScreen ? 20 : 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: badgeH,
                  constraints: BoxConstraints(minWidth: badgeH),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: selected
                        ? const LinearGradient(colors: [_kRefTeal, _kRefTealDeep])
                        : null,
                    color: selected ? null : const Color(0xcc0a1830),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withOpacity(.55)
                          : Colors.white.withOpacity(.16),
                      width: 1,
                    ),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: _kRefTeal.withOpacity(.45),
                          blurRadius: 8,
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      seatNo == null ? '' : '$seatNo',
                      style: GoogleFonts.poppins(
                        color: selected
                            ? Colors.white
                            : const Color(0xffb9c6e6),
                        fontSize:
                        isTinyScreen ? 8.5 : (isSmallScreen ? 9 : 10),
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// ✅ Re-fixed to match the reference image: a single horizontal toggle
  /// chip — a white pill labelled "All" that slides inside a dark track,
  /// instead of a text-label-above-switch layout. Same select-all/clear-all
  /// behaviour is passed in via [onTap] from `_topReceiverPanel`.
  Widget _allToggle({
    required bool allSelected,
    required VoidCallback onTap,
  }) {
    final double trackH = isTinyScreen ? 24 : (isSmallScreen ? 26 : 28);
    final double trackW = isTinyScreen ? 52 : (isSmallScreen ? 58 : 64);
    final double thumbW = trackW * .62;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: trackH,
        width: trackW,
        padding: const EdgeInsets.all(2.4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: allSelected
              ? _kRefTeal.withOpacity(.16)
              : Colors.white.withOpacity(.08),
          border: Border.all(
            color: allSelected
                ? _kRefTeal.withOpacity(.65)
                : Colors.white.withOpacity(.22),
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: allSelected ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbW,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: allSelected
                  ? const LinearGradient(colors: [_kRefTeal, _kRefTealDeep])
                  : null,
              color: allSelected ? null : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.30),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                ('All').appTr,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  color: allSelected ? Colors.white : Colors.black87,
                  fontSize: isTinyScreen ? 9.5 : (isSmallScreen ? 10 : 11),
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _premiumPill({
    required IconData icon,
    required String text,
    required bool active,
    required VoidCallback onTap,
    double? width,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        padding: EdgeInsets.symmetric(
          horizontal: kWeight * 0.02,
          vertical: kHeight * 0.005,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: active
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kAppColor2, kAppColor1],
          )
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(.22),
              Colors.white.withOpacity(.10),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(.25), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: active
                  ? kAppColor2.withOpacity(.35)
                  : Colors.black.withOpacity(.28),
              blurRadius: active ? 14 : 10,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(.08),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: kHeight * 0.02),
            SizedBox(width: kWeight * 0.005),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight * .016,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topReceiverPanel(List<Map<String, dynamic>> receivers) {
    final ids = _allReceiverIds(receivers);

    return Padding(
      padding: EdgeInsetsGeometry.symmetric(
        horizontal: kWeight * 0.02,
        vertical: isTinyScreen ? 4 : 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            ('To:').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: isTinyScreen ? 11 : (isSmallScreen ? 12 : 13.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 9),
          Expanded(
            child: receivers.isEmpty
                ? Text(
              ('No receiver').appTr,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
                : SizedBox(
              height: avatarRowHeight,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: receivers.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: isSmallScreen ? 8 : 12),
                itemBuilder: (_, index) => _avatar(receivers[index]),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 13),
          Obx(() {
            final allSelected =
                ids.isNotEmpty &&
                    selectedLocalReceiverIds.length == ids.length &&
                    ids.every((id) => selectedLocalReceiverIds.contains(id));

            return _allToggle(
              allSelected: allSelected,
              onTap: () {
                if (ids.isEmpty) return;
                if (allSelected) {
                  selectedLocalReceiverIds.clear();
                } else {
                  selectedLocalReceiverIds
                    ..clear()
                    ..addAll(ids);
                }
                livestreamController.selectedReceiverIds
                  ..clear()
                  ..addAll(selectedLocalReceiverIds);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryTabs() {
    return Obx(() {
      final categories = _giftCategories();
      final selectedIndex =
          livestreamController.selectedGiftCategoryIndex.value;

      if (categories.isEmpty) return const SizedBox.shrink();

      return Container(
        height: isTinyScreen ? 52 : (isSmallScreen ? 58 : 64),
        padding: EdgeInsets.fromLTRB(
          isTinyScreen ? 8 : (isSmallScreen ? 10 : 15),
          isSmallScreen ? 5 : 7,
          isTinyScreen ? 8 : (isSmallScreen ? 10 : 15),
          0,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
        ),
        child: Row(
          children: [
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final selected = selectedIndex == index;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      livestreamController.selectedGiftCategoryIndex.value =
                          index;
                      selectedGift.value = null;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(right: isSmallScreen ? 17 : 26),
                      padding: const EdgeInsets.only(top: 7),
                      child: Center(
                        // ✅ Re-fixed to match the reference image: plain
                        // bold-white (selected) vs translucent-grey
                        // (unselected) text, no teal color/glow, no
                        // underline indicator bar.
                        child: Text(
                          categories[index],
                          style: GoogleFonts.roboto(
                            color: selected
                                ? Colors.white
                                : Colors.white.withOpacity(.55),
                            fontSize: kHeight * 0.018,
                            fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: isTinyScreen ? 6 : 9),
            // ✅ New (decorative only, screenshot-matched): backpack/bag
            // icon at the trailing end of the category tab row. No gift
            // "inventory" feature exists in this codebase yet, so this is
            // purely visual and intentionally not wired to any action.
            _giftBackpackIcon(),
          ],
        ),
      );
    });
  }

  /// Purely decorative bag icon shown at the end of the category tabs row
  /// (matches the reference design — a plain outline icon, no background
  /// bubble). No onTap handler on purpose.
  Widget _giftBackpackIcon() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Icon(
        Icons.backpack_rounded,
        color: Colors.white.withOpacity(.70),
        size: isTinyScreen ? 21 : (isSmallScreen ? 23 : 26),
      ),
    );
  }

  /// ✅ New (screenshot-matched): ribbon-style "Lucky" banner tag for the
  /// top-left corner of a gift card, replacing the old small icon badge.
  /// Purely presentational — the caller still gates it on the same
  /// _isLuckyGift/_canShowLuckyGift/kPlayStoreSafeMode conditions.
  Widget _luckyRibbon() {
    // ✅ Re-fixed to match the reference image: a small flag-style tag
    // hanging off the top-left corner (not a rotated diagonal ribbon) —
    // icon + "Lucky" text on a purple-to-blue gradient chip.
    final double fontSize = isTinyScreen ? 7.5 : (isSmallScreen ? 8 : 8.8);

    return Positioned(
      top: isTinyScreen ? -4 : -5,
      left: isTinyScreen ? -4 : -5,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 6 : 8,
          vertical: isSmallScreen ? 2.4 : 3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
            bottomLeft: Radius.circular(2),
          ),
          // ✅ Pixel-sampled ribbon purple (was an eyeballed guess before).
          gradient: const LinearGradient(
            colors: [_kRefPurpleTop, _kRefPurpleBottom],
          ),
          boxShadow: [
            BoxShadow(
              color: _kRefPurpleBottom.withOpacity(.45),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: fontSize + 2),
            const SizedBox(width: 2),
            Text(
              ('Lucky').appTr,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBadge({
    required IconData icon,
    required Color color,
    required double top,
    required double right,
  }) {
    return Positioned(
      top: top,
      right: right,
      child: Container(
        height: isSmallScreen ? 16 : 18,
        width: isSmallScreen ? 16 : 18,
        decoration: BoxDecoration(
          // ✅ Re-fixed to match the reference image: small rounded SQUARE
          // (not a circle) for the "hot"/flame badge.
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            colors: [color.withOpacity(.95), color.withOpacity(.62)],
          ),
          border: Border.all(color: Colors.white.withOpacity(.55), width: 1),
          boxShadow: [BoxShadow(color: color.withOpacity(.40), blurRadius: 10)],
        ),
        child: Icon(icon, color: Colors.white, size: isSmallScreen ? 9 : 10),
      ),
    );
  }

  Widget _imageShimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: .35, end: 1),
      duration: const Duration(milliseconds: 650),
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(.05 + (.06 * value)),
                Colors.white.withOpacity(.13 + (.08 * value)),
                Colors.white.withOpacity(.05 + (.06 * value)),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white.withOpacity(.20 + (.18 * value)),
              size: isSmallScreen ? 32 : 38,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _giftImageBox(String image) {
    // ✅ Gift image bigger + fully clear.
    // ✅ White shadow / glow / fade / shader mask remove.
    // ✅ Image side clear থাকবে, crop হবে না।

    final double boxSize = isSmallScreen ? kHeight * 0.066 : kHeight * 0.074;
    final double iconSize = isSmallScreen ? 34 : 38;

    Widget fallbackIcon() {
      return Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          color: Colors.white.withOpacity(.95),
          size: iconSize,
        ),
      );
    }

    Widget buildRawImage() {
      if (image.isEmpty) return fallbackIcon();

      if (_isSvga(image)) {
        return SVGAEasyPlayer(
          resUrl: image,
          fit: BoxFit.contain,
          loops: 0,
          isMute: true,
          useCache: true,
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: image,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          memCacheWidth: 280,
          memCacheHeight: 280,

          // ✅ Loading time eo white shadow/fade ashbe na.
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => fallbackIcon(),
        ),
      );
    }

    return Center(
      child: SizedBox(
        height: boxSize,
        width: boxSize,
        child: RepaintBoundary(child: buildRawImage()),
      ),
    );
  }

  Widget _giftCard(Map<String, dynamic> gift) {
    final giftId = int.tryParse('${gift['id'] ?? 0}') ?? 0;
    final image = _giftImage(gift);
    final name = (gift['name'] ?? ('Gift').appTr).toString();
    final coin = _formatCoins(gift['coin'] ?? gift['price'] ?? 0);
    final isLucky = _isLuckyGift(gift);
    return Obx(() {
      livestreamController.currentVipRevision.value;
      final isVipLocked = _isVipGift(gift) && !_canUseVipGifts;
      final selectedId = int.tryParse('${selectedGift.value?['id'] ?? 0}') ?? 0;
      final selected = selectedId == giftId;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isVipLocked) {
            showVipRequired(('VIP Gift').appTr);
            return;
          }
          if (isLucky && (kPlayStoreSafeMode || !_canShowLuckyGift)) {
            Fluttertoast.showToast(
              msg: ('This gift is not available right now').appTr,
            );
            return;
          }
          // Freeze the complete selected object. The send flow now uses this
          // exact map for the first optimistic animation instead of performing
          // a second list lookup that can briefly return an image-less fallback.
          selectedGift.value = Map<String, dynamic>.from(gift);
        },
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          scale: selected ? .97 : 1,
          // ✅ Re-fixed per feedback (3rd pass): "selected" now means the
          // SAME card treatment the reference image shows on its first
          // card (Cactus fruit) — a rounded card box with a dark
          // navy-to-bright-teal vertical gradient — instead of no styling
          // at all. Unselected cards stay fully transparent, exactly like
          // every other card in the reference.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(isSmallScreen ? 6 : 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kRefNavy,
                  _kRefNavy,
                  _kRefTeal,
                ],
                stops: [0.0, 0.55, 1.0],
              )
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _giftImageBox(image)),
                    SizedBox(height: isSmallScreen ? 7 : 9),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: giftNameFontSize,
                        fontWeight: FontWeight.w500,
                        height: 1.05,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(.55),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: isSmallScreen ? 16 : 18,
                          width: isSmallScreen ? 16 : 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xfffff15f), Color(0xffff9d00)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xffffb400,
                                ).withOpacity(.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          // ✅ Screenshot-matched: gold star token instead
                          // of a coin icon (visual only, same price data).
                          child: Icon(
                            Icons.star_rounded,
                            color: const Color(0xff8b4a00),
                            size: isSmallScreen ? 12 : 13,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 5 : 7),
                        Flexible(
                          child: Text(
                            coin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              // ✅ Re-fixed to match the reference image:
                              // white price text (not gold/yellow).
                              color: Colors.white.withOpacity(.95),
                              fontSize: coinFontSize,
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // ✅ Screenshot-matched: ribbon-style "Lucky" tag in the
                // top-left corner instead of a small icon badge. Same
                // _isLuckyGift/_canShowLuckyGift condition as before.
                if (!kPlayStoreSafeMode && _canShowLuckyGift && isLucky)
                  _luckyRibbon(),
                if (isVipLocked)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xDD251645),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFFFD76A),
                        size: 14,
                      ),
                    ),
                  ),
                // ✅ Screenshot-matched: "hot" flame badge in the top-right
                // corner (freed up now that Lucky moved to a top-left
                // ribbon). Same back_coin condition/data as before, only
                // the icon/color/position changed.
                if (!kPlayStoreSafeMode &&
                    _canShowLuckyGift &&
                    gift['back_coin'] != null &&
                    gift['back_coin'].toString() != 'null' &&
                    !isVipLocked)
                  _smallBadge(
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xffff5b3d),
                    top: 7,
                    right: 7,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _selectedCustomAmountChip() {
    return Obx(() {
      final value = selectedSendAmount.value.trim();

      if (value.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: EdgeInsets.only(right: isSmallScreen ? 6 : 8),
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * 0.026,
          vertical: kHeight * 0.006,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: kAppColor2,
          border: Border.all(color: Colors.white.withOpacity(.32), width: 1),
          boxShadow: [
            BoxShadow(
              color: kAppColor2.withOpacity(.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: isSmallScreen ? 11.5 : 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    });
  }

  void _openCustomAmountDialog() {
    customAmountController.text = selectedSendAmount.value.trim();

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: kWeight * 0.08),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff07142d), Color(0xff061126)],
            ),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kAppColor2.withOpacity(.18),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ('Custom Amount').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Get.back(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextField(
                controller: customAmountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                cursorColor: kAppColor2,
                decoration: InputDecoration(
                  hintText: ('Enter number').appTr,
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(.18),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kAppColor2, width: 1.4),
                  ),
                ),
                onSubmitted: (_) => _saveCustomAmount(),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        selectedSendAmount.value = '';
                        customAmountController.clear();
                        Get.back();
                      },
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(.18),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            ('Clear').appTr,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _saveCustomAmount,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: kAppColor2,
                          boxShadow: [
                            BoxShadow(
                              color: kAppColor2.withOpacity(.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            ('Done').appTr,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black.withOpacity(.35),
    );
  }

  void _saveCustomAmount() {
    final value = customAmountController.text.trim();
    final amount = int.tryParse(value) ?? 0;

    if (amount <= 0) {
      Fluttertoast.showToast(msg: ('Please enter valid number').appTr);
      return;
    }

    selectedSendAmount.value = amount.toString();
    Get.back();
  }

  /// ✅ New (screenshot-matched): "▲ x{n}" dropdown pill offering quick
  /// x1/x5/x10 quantity presets plus the existing "Custom" flow. Selecting
  /// x1/x5/x10 only updates the local `quickSendMultiplier` display value;
  /// selecting Custom calls the original `_openCustomAmountDialog()` so
  /// that flow's behaviour is completely unchanged.
  /// ✅ Re-fixed to match the reference image: the quantity dropdown and
  /// the Send button are ONE seamless stadium-shaped control (teal border
  /// wraps both halves, no gap/seam between them, solid teal fill only on
  /// the Send half) instead of two separate pills with a gap. Same
  /// onSelected/_openCustomAmountDialog quantity logic and the same
  /// `_sendSelectedGift` tap target as before — visual merge only.
  Widget _quantityAndSendControl() {
    final double controlHeight = isSmallScreen ? 32 : 36;

    return Obx(() {
      final qty = quickSendMultiplier.value;
      final gift = selectedGift.value;
      final giftId = int.tryParse('${gift?['id'] ?? 0}') ?? 0;
      final enabled = giftId != 0;

      return Container(
        height: controlHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _kRefTeal.withOpacity(enabled ? .9 : .5),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              color: const Color(0xff0c1c3a),
              surfaceTintColor: Colors.transparent,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(.14)),
              ),
              offset: const Offset(0, -8),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'custom') {
                  _openCustomAmountDialog();
                  return;
                }
                quickSendMultiplier.value = int.tryParse(value) ?? 1;
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                for (final n in const [1, 5, 10])
                  PopupMenuItem<String>(
                    value: '$n',
                    height: isSmallScreen ? 34 : 38,
                    child: Text(
                      'x$n',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'custom',
                  height: isSmallScreen ? 34 : 38,
                  child: Text(
                    ('Custom').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.022),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_drop_up_rounded,
                      color: _kRefTeal,
                      size: kHeight * 0.02,
                    ),
                    Text(
                      'x$qty',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: kHeight * 0.014,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 1, color: _kRefTeal.withOpacity(.5)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _sendSelectedGift,
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.03),
                decoration: BoxDecoration(
                  // ✅ Screenshot-matched: flat pixel-sampled teal, not a
                  // two-tone gradient (Send button in the reference is a
                  // solid fill, essentially one color end to end).
                  color: enabled
                      ? _kRefTeal
                      : _kRefTeal.withOpacity(.45),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: kHeight * 0.015,
                    ),
                    SizedBox(width: isSmallScreen ? 5 : 7),
                    Text(
                      ('Send').appTr,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: kHeight * 0.015,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * 0.015,
          vertical: kHeight * 0.008,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xff07122a).withOpacity(.10),
              const Color(0xff061126).withOpacity(.92),
            ],
          ),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
        ),
        child: Row(
          children: [
            // ✅ Screenshot-matched: compact balance pill (star icon +
            // balance + circular "+" button) instead of the old
            // icon/text/"Recharge>" link row. Same recharge tap target and
            // same coin-balance source, visual only.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 9 : 11,
                    vertical: isSmallScreen ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    // ✅ Re-fixed to match the reference image: rounded
                    // rectangle (not a full stadium pill) with a gold/amber
                    // outline on a dark fill.
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(.25),
                    border: Border.all(
                      color: _kRefGold.withOpacity(.85),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: isSmallScreen ? 18 : 20,
                        width: isSmallScreen ? 18 : 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xfffff15f), Color(0xffff9d00)],
                          ),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: const Color(0xff8b4a00),
                          size: isSmallScreen ? 12 : 13,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Flexible(
                        child: Obx(() {
                          final coins =
                              authController.userProfile.value.user?.coins ??
                                  0;

                          return Text(
                            _formatCoins(coins),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 13 : 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        }),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      // ✅ Re-fixed to match the reference image: a plain
                      // "+" glyph (no circular teal button background).
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // Recharge page route থাকলে এখানে দিন
                          // Get.to(() => RechargeView());
                        },
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 17 : 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Custom/selected number will show left side of Send.
                    _selectedCustomAmountChip(),

                    // ✅ New (screenshot-matched): merged "▲ x5 | Send"
                    // stadium control (x1/x5/x10 + Custom dropdown seamlessly
                    // joined to the Send button, no gap between them).
                    _quantityAndSendControl(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSheet() {
    _syncDefaultReceiver();

    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          // ✅ Responsiveness fix: use the tiered `sheetHeight` getter
          // (small mobile 76%, normal 72%, large screen 68%) instead of a
          // single fixed fraction, so the sheet scales sensibly from small
          // phones up to tablets/large screens.
          height: sheetHeight,
          width: Get.width,
          clipBehavior: Clip.antiAlias,
          decoration: _premiumSheetDecoration(),
          child: Obx(() {
            final gifts = _giftListBySelectedCategory();
            final receivers = _receiverList();

            if (livestreamController.giftList.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xff17ff62)),
              );
            }

            return Column(
              children: [
                _topReceiverPanel(receivers),
                _categoryTabs(),
                Expanded(
                  child: gifts.isEmpty
                      ? Center(
                    child: Text(
                      ('No gift found').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                      : GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isSmallScreen ? 9 : 15,
                      isSmallScreen ? 7 : 9,
                      isSmallScreen ? 9 : 15,
                      isSmallScreen ? 6 : 8,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: gifts.length,
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: .3,
                      crossAxisSpacing: .5,
                      childAspectRatio: .75,
                    ),
                    itemBuilder: (_, index) => _giftCard(gifts[index]),
                  ),
                ),
                _bottomBar(),
              ],
            );
          }),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      elevation: 0,
      enableDrag: true,
      isDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kHeight * 0.06,
      width: kHeight * 0.06,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () async {
              if (livestreamController.giftList.isEmpty) {
                await livestreamController.fetchGiftList();
              }

              selectedGift.value = null;
              _syncDefaultReceiver();
              _precacheGiftImages();
              _preloadGiftSvgaAnimations();
              _openSheet();
            },
            child: SVGAEasyPlayer(
              assetsName: 'assets/newaudio/gift_icon.svga',
              fit: BoxFit.cover,
            ),
          ),
          // ✅ FIX: see _preloadGiftSvgaAnimations. Invisible, takes no
          // layout space, only warms SVGAEasyPlayer's cache in the
          // background.
          _svgaPreloadLayer(),
        ],
      ),
    );
  }
}