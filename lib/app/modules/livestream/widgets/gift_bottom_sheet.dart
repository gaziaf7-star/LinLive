import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/home/views/widgets/tabbarshemmer.dart' hide kAppColor2, kAppColor1;

import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/websocket_controller.dart';

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
  final LivestreamController livestreamController = Get.find();
  final WebsocketController websocketController = Get.find();
  final AuthController authController = Get.find();

  final RxList<int> selectedLocalReceiverIds = <int>[].obs;
  final Rxn<Map<String, dynamic>> selectedGift = Rxn<Map<String, dynamic>>();

  /// Send amount / quantity UI value.
  /// Custom এ user number দিলে Send button এর left পাশে show হবে।
  final RxString selectedSendAmount = ''.obs;
  final TextEditingController customAmountController = TextEditingController();

  bool get isSmallScreen => Get.width < 370;
  bool get isTinyScreen => Get.width < 340;

  double get sheetHeight {
    /// Professional bottom sheet height:
    /// small mobile 76%, normal mobile 72%, large screen 68%.
    if (Get.height < 680) return Get.height * .76;
    if (Get.height < 760) return Get.height * .72;
    return Get.height * .68;
  }

  double get avatarSize => isSmallScreen ? 42 : 48;
  double get avatarBoxWidth => isSmallScreen ? 52 : 58;
  double get tabFontSize => isSmallScreen ? 14 : 16;
  double get giftNameFontSize => isSmallScreen ? 10.5 : 12.2;
  double get coinFontSize => isSmallScreen ? 11.5 : 13.2;
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
        (backCoin != null && backCoin.toString() != 'null' && backCoin.toString() != '0') ||
        (luckyRatio != null && luckyRatio.toString() != 'null') ||
        (luckyCoin != null && luckyCoin.toString() != 'null') ||
        isLucky == true ||
        isLucky.toString() == '1';
  }

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
      if (!kPlayStoreSafeMode && _canShowLuckyGift)
        'Lucky',
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

      receivers.add({
        ...user,
        'id': id,
        'seat_no': seatNo,
      });
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

      final int seatNo =
          int.tryParse('${call['seat_no'] ?? 0}') ?? 0;

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

    if (_isLuckyGift(gift) && (kPlayStoreSafeMode || !_canShowLuckyGift)) {
      Fluttertoast.showToast(msg: ('This gift is not available right now').appTr);
      selectedGift.value = null;
      return;
    }

    final giftId = int.tryParse('${gift['id'] ?? 0}') ?? 0;
    final giftPrice = int.tryParse('${gift['coin'] ?? gift['price'] ?? 0}') ?? 0;

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
            ? ('Insufficient balance').appTr: ('Insufficient balance. Please recharge!').appTr,
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
    final Future<Map<String, dynamic>?> sendFuture =
    livestreamController.tryToSendGift(
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
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xff07142d),
          Color(0xff07122a),
          Color(0xff061126),
        ],
      ),
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
          height: avatarSize + 12,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: avatarSize,
                width: avatarSize,
                padding: const EdgeInsets.all(2.4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kAppColor2, kAppColor1],
                  )
                      : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(.22),
                      Colors.white.withOpacity(.06),
                    ],
                  ),
                  boxShadow: [
                    if (selected)
                      BoxShadow(
                        color: kAppColor2.withOpacity(.52),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(.42),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
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
                        size: isSmallScreen ? 22 : 24,
                      ),
                    )
                        : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white12,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: isSmallScreen ? 22 : 24,
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
                  height: isSmallScreen ? 17 : 19,
                  constraints: BoxConstraints(minWidth: isSmallScreen ? 17 : 19),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    shape: seatNo == null ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: seatNo == null ? null : BorderRadius.circular(30),
                    gradient: selected
                        ? const LinearGradient(colors: [kAppColor2, kAppColor1])
                        : const LinearGradient(colors: [Color(0xff2ddcff), Color(0xff5c7cff)]),
                    border: Border.all(color: Colors.white.withOpacity(.55), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: (selected ? kAppColor2 : const Color(0xff3aa8ff)).withOpacity(.40),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      seatNo == null ? '✓' : '$seatNo',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight: FontWeight.w900,
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


        padding: EdgeInsets.symmetric(horizontal: kWeight*0.02,vertical: kHeight*0.005),
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
            Icon(icon, color: Colors.white, size: kHeight*0.02),
            SizedBox(width:kWeight*0.005),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight*.016,
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
      padding: EdgeInsetsGeometry.symmetric(horizontal: kWeight*0.02),
      child: Row(
        children: [
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
              height: avatarSize + 12,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: receivers.length,
                separatorBuilder: (_, __) => SizedBox(width: isSmallScreen ? 7 : 10),
                itemBuilder: (_, index) => _avatar(receivers[index]),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 13),
          Obx(() {
            final allSelected = ids.isNotEmpty &&
                selectedLocalReceiverIds.length == ids.length &&
                ids.every((id) => selectedLocalReceiverIds.contains(id));

            return _premiumPill(
              icon: Icons.mic_rounded,
              text: ('All Mic').appTr,
              active: allSelected,
              width: isSmallScreen ? 104 : 126,
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
      final selectedIndex = livestreamController.selectedGiftCategoryIndex.value;

      if (categories.isEmpty) return const SizedBox.shrink();

      return Container(
        height: isSmallScreen ? 58 : 64,
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 10 : 15,
          isSmallScreen ? 5 : 7,
          isSmallScreen ? 10 : 15,
          0,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(.08)),
          ),
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
                      livestreamController.selectedGiftCategoryIndex.value = index;
                      selectedGift.value = null;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(right: isSmallScreen ? 17 : 26),
                      padding: const EdgeInsets.only(top: 7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            categories[index],
                            style: GoogleFonts.roboto(
                              color: selected ? kAppColor2 : Colors.white.withOpacity(.68),
                              fontSize: kHeight*0.018,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              shadows: selected
                                  ? [
                                Shadow(
                                  color: kAppColor2.withOpacity(.40),
                                  blurRadius: 12,
                                ),
                              ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 7),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 4,
                            width: selected ? 24 : 0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              gradient: const LinearGradient(colors: [kAppColor2, kAppColor1]),
                              boxShadow: [
                                if (selected)
                                  BoxShadow(
                                    color: kAppColor2.withOpacity(.45),
                                    blurRadius: 10,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          ],
        ),
      );
    });
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
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [color.withOpacity(.95), color.withOpacity(.62)]),
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
        child: RepaintBoundary(
          child: buildRawImage(),
        ),
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
      final selectedId = int.tryParse('${selectedGift.value?['id'] ?? 0}') ?? 0;
      final selected = selectedId == giftId;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isLucky && (kPlayStoreSafeMode || !_canShowLuckyGift)) {
            Fluttertoast.showToast(msg: ('This gift is not available right now').appTr);
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(selected ? 1 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: selected
                  ? const LinearGradient(
                colors: [kAppColor2, kAppColor1, kAppColor2],
              )
                  : null,

              // ✅ Selected gift card glow shadow remove.
              // Image er upor halka white/blur effect ashbe na.
              boxShadow: const [],
            ),
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 4 : 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: selected ? const Color(0xff091834) : Colors.transparent,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _giftImageBox(image),
                      ),
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
                            height: isSmallScreen ? 17 : 19,
                            width: isSmallScreen ? 17 : 19,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xfffff15f),
                                  Color(0xffff9d00),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xffffb400).withOpacity(.35),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xff8b4a00),
                              size: 14,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 5 : 7),
                          Flexible(
                            child: Text(
                              coin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xffffd34d),
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
                  if (!kPlayStoreSafeMode && _canShowLuckyGift && isLucky)
                    _smallBadge(
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xff9b55ff),
                      top: 7,
                      right: 7,
                    ),
                  if (!kPlayStoreSafeMode &&
                      _canShowLuckyGift &&
                      gift['back_coin'] != null &&
                      gift['back_coin'].toString() != 'null')
                    _smallBadge(
                      icon: Icons.local_offer_rounded,
                      color: const Color(0xff19d3af),
                      top: isSmallScreen ? 31 : 34,
                      right: 7,
                    ),
                ],
              ),
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
          border: Border.all(
            color: Colors.white.withOpacity(.32),
            width: 1,
          ),
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
              colors: [
                Color(0xff07142d),
                Color(0xff061126),
              ],
            ),
            border: Border.all(
              color: Colors.white24,
              width: 1,
            ),
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
                    borderSide: const BorderSide(
                      color: kAppColor2,
                      width: 1.4,
                    ),
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
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(.08)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/diamond-removebg-preview.png',
                    height: isSmallScreen ? 21 : 24,
                    width: isSmallScreen ? 21 : 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.monetization_on,
                      color: const Color(0xffffd447),
                      size: isSmallScreen ? 21 : 24,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Obx(() {
                      final coins =
                          authController.userProfile.value.user?.coins ?? 0;

                      return Text(
                        _formatCoins(coins),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 13.5 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Recharge page route থাকলে এখানে দিন
                      // Get.to(() => RechargeView());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 5,
                      ),
                      child: Text(
                        ('Recharge>').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xff22e4c0),
                          fontSize: isSmallScreen ? 9 : 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openCustomAmountDialog,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: kWeight * 0.02,
                          vertical: kHeight * 0.005,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(.14),
                              Colors.white.withOpacity(.05),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(.26),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: kHeight * 0.014,
                            ),
                            SizedBox(width: isSmallScreen ? 5 : 7),
                            Text(
                              ('Custom').appTr,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: kHeight * 0.014,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: isSmallScreen ? 8 : 10),
                    /// Custom/selected number will show left side of Send.
                    _selectedCustomAmountChip(),

                    Obx(() {
                      final gift = selectedGift.value;
                      final giftId =
                          int.tryParse('${gift?['id'] ?? 0}') ?? 0;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _sendSelectedGift,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: kWeight * 0.02,
                            vertical: kHeight * 0.007,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: giftId == 0
                                  ? [
                                kAppColor1.withOpacity(.64),
                                kAppColor2.withOpacity(.64),
                              ]
                                  : [
                                kAppColor2,
                                kAppColor1,
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(.25),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kAppColor2.withOpacity(
                                  giftId == 0 ? .18 : .42,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
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
                      );
                    }),
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
          height: kHeight*0.49,
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
      child: InkWell(
        onTap: () async {
          if (livestreamController.giftList.isEmpty) {
            await livestreamController.fetchGiftList();
          }

          selectedGift.value = null;
          _syncDefaultReceiver();
          _precacheGiftImages();
          _openSheet();
        },
        child: SVGAEasyPlayer(
          assetsName: 'assets/newaudio/gift_icon.svga',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}