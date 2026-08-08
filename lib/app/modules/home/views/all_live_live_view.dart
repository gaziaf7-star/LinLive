import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/safe_network_image.dart';
import '../../livestream/controllers/agoraTokenController.dart';
import '../../livestream/controllers/audience_join_controller.dart';
import '../../livestream/controllers/livestream_controller.dart';
import '../controllers/home_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

/// Keeps only the tapped card protected from double-tap.
/// No global loading UI is shown, so the whole list stays smooth while joining.
final RxString _joiningLiveCardKey = ''.obs;
final RxString _joiningLiveMessage = 'Joining live...'.obs;

String _liveCardStableKey(dynamic raw) {
  if (raw is Map) {
    final id = raw['id'] ?? raw['livestream_id'] ?? raw['stream_id'];
    if (id != null && id.toString().trim().isNotEmpty) {
      return id.toString();
    }
    final userId = raw['user_id'] ?? raw['room_id'];
    if (userId != null && userId.toString().trim().isNotEmpty) {
      return 'user_${userId.toString()}';
    }
  }
  return raw.hashCode.toString();
}

class AllLiveListView extends GetView<HomeController> {
  const AllLiveListView({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());
    Get.put(LivestreamController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3B072F).withOpacity(.22),
              Color(0xFF3B072F).withOpacity(.96),
            ],
          ),
        ),
        child: CustomRefreshIndicator(
          onRefresh: () async => controller.refreshLivestreamList(),
          builder:
              (
              BuildContext context,
              Widget child,
              IndicatorController refreshController,
              ) {
            return Stack(
              children: [
                child,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: refreshController,
                    builder: (context, _) {
                      return SizedBox(
                        height: refreshController.value * 76,
                        child: Center(
                          child: refreshController.isIdle
                              ? const SizedBox.shrink()
                              : Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.22),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(
                                color: Colors.white.withOpacity(.25),
                              ),
                            ),
                            child: Transform.scale(
                              scale: refreshController.value.clamp(
                                0.0,
                                1.0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  50,
                                ),
                                child: Image.asset(
                                  appLogo,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
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
          child: Obx(() {
            final users = controller.showingLiveStreamList;

            /// Important:
            /// Do not replace the whole grid with shimmer while already showing data.
            /// This prevents all cards from loading when user taps a live.
            if (controller.isLoading.value && users.isEmpty) {
              return _LoadingMasonrySkeleton();
            }

            if (users.isEmpty) {
              return _EmptyLiveList();
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 420) {
                  controller.loadMoreLivestreamList();
                }
                return false;
              },
              child: CustomScrollView(
                physics: ScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      kWeight * .025,
                      kHeight * .010,
                      kWeight * .025,
                      kHeight * .010,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _TopMasonrySection(users: users),
                    ),
                  ),
                  if (users.length > 3)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        kWeight * .025,
                        0,
                        kWeight * .025,
                        kHeight * .018,
                      ),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = users[index + 3];
                          return UserProfileCard(
                            key: ValueKey('live_${_liveCardStableKey(item)}'),
                            data: item,
                            index: index + 3,
                            // নিচের ২-column card বড় ও পরিষ্কার থাকবে।
                            compact: false,
                          );
                        }, childCount: users.length - 3),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          // নিচের live card এখন প্রতি row-তে ২টি করে দেখাবে।
                          // উপরের featured ৩টি card-এর layout অপরিবর্তিত থাকবে।
                          crossAxisCount: 2,
                          mainAxisSpacing: kWeight * .022,
                          crossAxisSpacing: kWeight * .022,
                          childAspectRatio: .92,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Obx(() {
                      if (controller.isLoadingMoreLive.value) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: CupertinoActivityIndicator(radius: 12),
                          ),
                        );
                      }

                      if (!controller.liveHasMore.value) {
                        return const SizedBox(height: 18);
                      }

                      return const SizedBox(height: 24);
                    }),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TopMasonrySection extends StatelessWidget {
  final List<dynamic> users;

  const _TopMasonrySection({required this.users});

  @override
  Widget build(BuildContext context) {
    final double gap = kWeight * .018;
    final double heroHeight = kHeight * .285;

    if (users.length == 1) {
      return SizedBox(
        height: heroHeight,
        child: UserProfileCard(
          key: ValueKey('live_${_liveCardStableKey(users.first)}'),
          data: users.first,
          index: 0,
          featured: true,
        ),
      );
    }

    return SizedBox(
      height: heroHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: UserProfileCard(
              key: ValueKey('live_${_liveCardStableKey(users[0])}'),
              data: users[0],
              index: 0,
              featured: true,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: UserProfileCard(
                    key: ValueKey('live_${_liveCardStableKey(users[1])}'),
                    data: users[1],
                    index: 1,
                    compact: true,
                  ),
                ),
                if (users.length > 2) ...[
                  SizedBox(height: gap),
                  Expanded(
                    child: UserProfileCard(
                      key: ValueKey('live_${_liveCardStableKey(users[2])}'),
                      data: users[2],
                      index: 2,
                      compact: true,
                    ),
                  ),
                ] else ...[
                  SizedBox(height: gap),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingMasonrySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(kWeight * .025),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(.16),
        highlightColor: Colors.white.withOpacity(.32),
        child: Column(
          children: [
            SizedBox(
              height: kHeight * .285,
              child: Row(
                children: [
                  Expanded(flex: 2, child: _skeletonBox()),
                  SizedBox(width: kWeight * .018),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _skeletonBox()),
                        SizedBox(height: kWeight * .018),
                        Expanded(child: _skeletonBox()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: kWeight * .018),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: kWeight * .022,
                  crossAxisSpacing: kWeight * .022,
                  childAspectRatio: .92,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => _skeletonBox(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _EmptyLiveList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: kHeight * .18),
        Center(
          child: Column(
            children: [
              Lottie.asset(
                'assets/flaticons/nYuPvdjcOD.json',
                height: kHeight * 0.14,
                width: kHeight * 0.14,
                fit: BoxFit.cover,
              ),
              SizedBox(height: kHeight * 0.01),
              Castontext(
                fontWeight: FontWeight.w500,
                textColor: Colors.white.withOpacity(.78),
                fontSize: kHeight * 0.012,
                text: ('No Stream Available').appTr,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UserProfileCard extends StatelessWidget {
  final dynamic data;
  final int index;
  final bool featured;
  final bool compact;

  const UserProfileCard({
    Key? key,
    required this.data,
    required this.index,
    this.featured = false,
    this.compact = false,
  }) : super(key: key);

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _safeText(dynamic value) => value?.toString().trim() ?? '';

  /// Returns the correct emoji flag from either an ISO country code or a
  /// country name. No extra package/asset is required.
  String _countryFlag(Map<String, dynamic> user, Map<String, dynamic> item) {
    final List<dynamic> candidates = <dynamic>[
      user['country_code'],
      user['countryCode'],
      user['country_iso'],
      user['iso2'],
      user['country'],
      item['country_code'],
      item['countryCode'],
      item['country_iso'],
      item['iso2'],
      item['country'],
      item['host_country'],
    ];

    for (final dynamic value in candidates) {
      final String flag = _flagFromCountryValue(value);
      if (flag.isNotEmpty) return flag;
    }

    return '';
  }

  String _flagFromCountryValue(dynamic value) {
    final String clean = _cleanText(value);
    if (clean.isEmpty) return '';

    // Country text already contains a flag emoji.
    final List<int> regionalIndicators = clean.runes
        .where((int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF)
        .take(2)
        .toList();
    if (regionalIndicators.length == 2) {
      return String.fromCharCodes(regionalIndicators);
    }

    final String directCode = clean.toUpperCase();
    final String directFlag = _flagFromIsoCode(directCode);
    if (directFlag.isNotEmpty) return directFlag;

    final String normalized = clean
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const Map<String, String> countryCodes = <String, String>{
      'bangladesh': 'BD',
      'india': 'IN',
      'pakistan': 'PK',
      'nepal': 'NP',
      'sri lanka': 'LK',
      'bhutan': 'BT',
      'maldives': 'MV',
      'afghanistan': 'AF',
      'indonesia': 'ID',
      'malaysia': 'MY',
      'singapore': 'SG',
      'thailand': 'TH',
      'philippines': 'PH',
      'vietnam': 'VN',
      'myanmar': 'MM',
      'china': 'CN',
      'japan': 'JP',
      'south korea': 'KR',
      'korea': 'KR',
      'united arab emirates': 'AE',
      'uae': 'AE',
      'saudi arabia': 'SA',
      'qatar': 'QA',
      'kuwait': 'KW',
      'oman': 'OM',
      'bahrain': 'BH',
      'iraq': 'IQ',
      'iran': 'IR',
      'turkey': 'TR',
      'egypt': 'EG',
      'algeria': 'DZ',
      'morocco': 'MA',
      'tunisia': 'TN',
      'libya': 'LY',
      'sudan': 'SD',
      'south africa': 'ZA',
      'nigeria': 'NG',
      'kenya': 'KE',
      'ghana': 'GH',
      'uganda': 'UG',
      'tanzania': 'TZ',
      'ethiopia': 'ET',
      'united kingdom': 'GB',
      'great britain': 'GB',
      'england': 'GB',
      'scotland': 'GB',
      'wales': 'GB',
      'uk': 'GB',
      'united states': 'US',
      'united states of america': 'US',
      'usa': 'US',
      'canada': 'CA',
      'australia': 'AU',
      'new zealand': 'NZ',
      'brazil': 'BR',
      'argentina': 'AR',
      'mexico': 'MX',
      'france': 'FR',
      'germany': 'DE',
      'italy': 'IT',
      'spain': 'ES',
      'portugal': 'PT',
      'netherlands': 'NL',
      'belgium': 'BE',
      'sweden': 'SE',
      'norway': 'NO',
      'denmark': 'DK',
      'finland': 'FI',
      'russia': 'RU',
      'ukraine': 'UA',
    };

    final String? exactCode = countryCodes[normalized];
    if (exactCode != null) return _flagFromIsoCode(exactCode);

    // Handles values such as "United Kingdom (UK)" or "Bangladesh 🇧🇩".
    for (final MapEntry<String, String> entry in countryCodes.entries) {
      if (normalized.contains(entry.key)) {
        return _flagFromIsoCode(entry.value);
      }
    }

    return '';
  }

  String _flagFromIsoCode(String code) {
    final String iso = code.trim().toUpperCase();
    if (iso.length != 2) return '';

    final List<int> units = iso.codeUnits;
    final bool valid = units.every((int unit) => unit >= 65 && unit <= 90);
    if (!valid) return '';

    return String.fromCharCodes(units.map((int unit) => 0x1F1E6 + unit - 65));
  }

  String _liveKey(Map<String, dynamic> item) {
    return _safeText(item['id'] ?? item['livestream_id'] ?? item['stream_id']);
  }

  Map<String, dynamic> _displayUser(Map<String, dynamic> item) {
    final callers = item['livestream_callers'];

    if (callers is List && callers.isNotEmpty) {
      final broadcaster = callers.firstWhereOrNull((caller) {
        if (caller is! Map) return false;
        return caller['is_broadcaster'] == true ||
            caller['is_broadcaster'] == 1 ||
            caller['caller_id']?.toString() == item['user_id']?.toString();
      });

      final first = broadcaster ?? callers.first;
      if (first is Map && first['user'] is Map) {
        return _asMap(first['user']);
      }
      if (first is Map && first['User'] is Map) {
        return _asMap(first['User']);
      }
    }

    if (item['user'] is Map) return _asMap(item['user']);
    if (item['User'] is Map) return _asMap(item['User']);
    if (item['sender_host'] is Map) return _asMap(item['sender_host']);
    if (item['receiver_host'] is Map) return _asMap(item['receiver_host']);

    // Realtime live_create event sometimes arrives with no nested user object.
    // Build a safe display user from the stream itself until API refresh gives full data.
    final String fallbackName = _cleanText(
      item['name'] ??
          item['stream_bte'] ??
          item['title'] ??
          item['username'] ??
          ('User').appTr,
    );

    return <String, dynamic>{
      'id': item['user_id'] ?? item['room_id'] ?? item['host_id'],
      'user_id': item['user_id'] ?? item['room_id'] ?? item['host_id'],
      'name': fallbackName.isNotEmpty ? fallbackName : ('User').appTr,
      'username': item['username'],
      'profile_image':
      item['profile_image'] ?? item['image'] ?? item['stream_image'],
      'image': item['profile_image'] ?? item['image'] ?? item['stream_image'],
      'country': item['country'] ?? item['host_country'],
      'country_code':
      item['country_code'] ?? item['country_iso'] ?? item['iso2'],
    };
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  bool _isBadFallbackImage(dynamic value) {
    final url = _cleanText(value).toLowerCase();
    return url.isEmpty ||
        url.contains('photosbulk.com') ||
        url.contains('hijab-girl-pic_108.webp');
  }

  String _imageUrlFromRaw(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return '';
    if (_isBadFallbackImage(raw)) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  String _coverImageUrl(Map<String, dynamic> item, Map<String, dynamic> user) {
    final candidates = <dynamic>[
      // 1) Room/stream cover image first.
      item['stream_image'],
      item['stream_img'],
      item['image'],
      item['cover_image'],
      item['thumbnail'],
      item['live_image'],

      // 2) If stream image missing, show host/user profile image.
      user['profile_image'],
      user['image'],
      item['profile_image'],
      item['avatar'],
      item['user'] is Map ? item['user']['profile_image'] : null,
      item['user'] is Map ? item['user']['image'] : null,
      item['User'] is Map ? item['User']['profile_image'] : null,
      item['User'] is Map ? item['User']['image'] : null,
    ];

    for (final rawValue in candidates) {
      final url = _imageUrlFromRaw(rawValue);
      if (url.isNotEmpty) return url;
    }

    return '';
  }

  String _avatarUrl(Map<String, dynamic> user) {
    final raw =
        (user['profile_image'] ?? user['image'])?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null' || _isBadFallbackImage(raw)) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  bool _isPkRunning(Map<String, dynamic> item) {
    final int pkId = _toInt(item['pk_id'] ?? item['current_pk_id']);
    final String pkStatus = item['pk_status']?.toString().toLowerCase() ?? '';
    final String streamType =
        item['stream_type']?.toString().toLowerCase() ?? '';

    return pkId > 0 ||
        item['is_pk']?.toString() == '1' ||
        item['is_pk_room'] == true ||
        pkStatus == 'running' ||
        streamType == 'pk';
  }

  bool _isRealPkAgoraChannel(String value) {
    final String channel = value.trim();
    return channel.startsWith('pk_') && channel.split('_').length >= 4;
  }

  String _firstRealPkChannel(Map<String, dynamic> item) {
    final candidates = [
      item['pk_channel'],
      item['pk_channel_name'],
      item['agora_channel_name'],
      item['audience_join_agora_channel'],
      item['channel_name'],
      item['pk_room_data'] is Map ? item['pk_room_data']['channel_name'] : null,
      item['pk_room_data'] is Map
          ? item['pk_room_data']['pk_channel_name']
          : null,
      item['pk_room_data'] is Map ? item['pk_room_data']['pk_channel'] : null,
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (_isRealPkAgoraChannel(value)) return value;
    }
    try {
      final c = Get.find<LivestreamController>();
      final String active = c.pkChannelName.value.trim();
      final int itemPkId = _toInt(item['pk_id'] ?? item['current_pk_id']);
      if (_isRealPkAgoraChannel(active) &&
          (itemPkId <= 0 ||
              c.currentPkId.value == 0 ||
              c.currentPkId.value == itemPkId)) {
        return active;
      }
    } catch (_) {}
    return '';
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is double) return value.toInt() == 1;

    final String text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on' ||
        text == 'locked';
  }

  bool _isRoomLockedForJoin(Map<String, dynamic> item) {
    return _truthy(
      item['room_lock'] ??
          item['is_room_locked'] ??
          item['room_locked'] ??
          item['has_room_password'],
    );
  }

  Future<bool> _checkRoomPasswordBeforeJoin(Map<String, dynamic> item) async {
    final bool locked = _isRoomLockedForJoin(item);

    if (!locked) {
      return true;
    }

    final int streamId = _toInt(
      item['id'] ?? item['livestream_id'] ?? item['stream_id'],
    );
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (streamId <= 0 || userId <= 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return false;
    }

    final HomeController homeController = Get.find<HomeController>();
    final String? password = await homeController.showRoomPasswordDialog();

    if (password == null || password.trim().isEmpty) {
      return false;
    }

    final bool verified = await homeController.verifyRoomPassword(
      userId: userId,
      streamId: streamId,
      password: password.trim(),
    );

    return verified;
  }

  Future<void> _joinLive(
      BuildContext context,
      Map<String, dynamic> item,
      ) async {
    if (kDebugMode) {
      debugPrint('join_tap=${DateTime.now().microsecondsSinceEpoch}');
    }
    final AudienceJoinController liveController =
    Get.isRegistered<AudienceJoinController>()
        ? Get.find<AudienceJoinController>()
        : Get.put(AudienceJoinController());

    final String liveKey = _liveKey(item);
    if (liveKey.isEmpty || _joiningLiveCardKey.value == liveKey) return;

    _joiningLiveCardKey.value = liveKey;
    _joiningLiveMessage.value = 'Preparing live room...';
    liveController.joinProgressMessage.value = 'Preparing live room...';

    try {
      final Map<String, dynamic> liveData = Map<String, dynamic>.from(item);
      final String backgroundUrl = _roomBackgroundUrl(liveData);
      if (backgroundUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(backgroundUrl, cacheKey: backgroundUrl),
          context,
        ).ignore();
      }

      final bool canJoin = await _checkRoomPasswordBeforeJoin(liveData);
      if (!canJoin) {
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'join_validation_done=${DateTime.now().microsecondsSinceEpoch}',
        );
      }

      final String normalChannel =
          '${liveData['normal_room_id'] ?? liveData['room_id'] ?? liveData['normal_channel_name'] ?? liveData['channel_name'] ?? liveData['user_id'] ?? ''}';
      final String pkChannel = _firstRealPkChannel(liveData);
      final int pkId = _toInt(liveData['pk_id'] ?? liveData['current_pk_id']);
      final bool isPkRunning = _isPkRunning(liveData);

      if (isPkRunning && !_isRealPkAgoraChannel(pkChannel)) {
        Fluttertoast.showToast(
          msg: ('PK room is syncing. Please refresh and try again.').appTr,
        );
        return;
      }

      final String joinChannel = isPkRunning ? pkChannel : normalChannel;

      if (joinChannel.trim().isEmpty || joinChannel == 'null') {
        Fluttertoast.showToast(msg: ('Live channel not found').appTr);
        return;
      }

      await liveController.joinAsAudience(
        channelName: joinChannel,
        data: {
          ...liveData,
          'audience_join_agora_channel': joinChannel,
          'is_pk': isPkRunning ? 1 : 0,
          'pk_id': pkId,
          'pk_channel': pkChannel,
          'pk_channel_name': pkChannel,
        },
      );
    } finally {
      if (_joiningLiveCardKey.value == liveKey) {
        _joiningLiveCardKey.value = '';
      }
      _joiningLiveMessage.value = 'Joining live...';
    }
  }

  String _roomBackgroundUrl(Map<String, dynamic> item) {
    final Map<String, dynamic> live = _asMap(item['livestreamdata']);
    for (final dynamic raw in <dynamic>[
      item['room_background_image'],
      item['background_image'],
      live['room_background_image'],
      live['background_image'],
      item['stream_image'],
    ]) {
      final String url = _imageUrlFromRaw(raw);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> item = _asMap(data);
    final Map<String, dynamic> displayUser = _displayUser(item);

    final String displayName = (displayUser['name'] ?? ('User').appTr)
        .toString();
    final String imageUrl = _coverImageUrl(item, displayUser);
    final String avatarUrl = _avatarUrl(displayUser);
    final String streamType =
        item['stream_type']?.toString().toLowerCase() ?? '';
    final bool isAudio = streamType == 'audio';
    final bool isPk = _isPkRunning(item);
    final int viewerCount = _toInt(
      item['livestream_viewers_count'] ?? item['viewer_count'],
    );
    final String displayId =
    displayUser['user_id']?.toString().trim().isNotEmpty == true
        ? displayUser['user_id'].toString()
        : (displayUser['id'] ?? item['user_id'] ?? '').toString();
    final String countryFlag = _countryFlag(displayUser, item);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _joinLive(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(featured ? 16 : 12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeNetworkImage(
              key: ValueKey<String>('live-cover-$imageUrl'),
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: featured ? 720 : 360,
              memCacheHeight: featured ? 850 : 480,
              maxWidthDiskCache: featured ? 900 : 480,
              maxHeightDiskCache: featured ? 1100 : 640,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.06),
                    Colors.black.withOpacity(.14),
                    Colors.black.withOpacity(.70),
                  ],
                ),
              ),
            ),
            if (isPk)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xffffcf4d).withOpacity(.85),
                      width: featured ? 1.4 : 1,
                    ),
                    borderRadius: BorderRadius.circular(featured ? 16 : 12),
                  ),
                ),
              ),
            Positioned(
              top: featured ? 10 : 6,
              left: featured ? 10 : 6,
              child: _typeBadge(isPk: isPk, isAudio: isAudio),
            ),
            Positioned(
              top: featured ? 10 : 6,
              right: featured ? 10 : 6,
              child: _viewerBadge(viewerCount),
            ),
            Positioned(
              left: featured ? 10 : 6,
              right: featured ? 10 : 6,
              bottom: featured ? 10 : 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _avatar(avatarUrl, size: featured ? 25 : 18),
                      SizedBox(width: featured ? 7 : 5),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: featured
                                ? kHeight * .0145
                                : kHeight * .0108,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (featured || !compact) ...[
                    SizedBox(height: featured ? 7 : 4),
                    _idChip(
                      displayId,
                      countryFlag: countryFlag,
                      featured: featured,
                    ),
                  ] else ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (countryFlag.isNotEmpty) ...[
                          Text(
                            countryFlag,
                            style: TextStyle(
                              fontSize: kHeight * .0125,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            ('ID: $displayId').appTr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(.88),
                              fontSize: kHeight * .0092,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Obx(() {
              final bool joining = _joiningLiveCardKey.value == _liveKey(item);
              if (!joining) return const SizedBox.shrink();

              return Positioned.fill(child: _joinLoadingOverlay(''));
            }),
          ],
        ),
      ),
    );
  }

  Widget _joinLoadingOverlay(String message) {
    // Home/live-list e only small center loader show hobe.
    // Kono text/message show korbo na, jate UI clean and fast feel kore.
    final double loaderSize = featured ? 44 : 36;
    final double progressSize = featured ? 24 : 19;

    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: Container(
          width: loaderSize,
          height: loaderSize,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.58),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(.24), width: .8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff23d7b0).withOpacity(.22),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: SizedBox(
              height: progressSize,
              width: progressSize,
              child: const CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String url, {required double size}) {
    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.75), width: .8),
        color: Colors.white.withOpacity(.18),
      ),
      child: ClipOval(
        child: SafeNetworkImage(
          key: ValueKey<String>('live-avatar-$url'),
          imageUrl: url,
          fit: BoxFit.contain,
          width: size,
          height: size,
          memCacheWidth: 96,
          memCacheHeight: 96,
          maxWidthDiskCache: 160,
          maxHeightDiskCache: 160,
        ),
      ),
    );
  }

  Widget _viewerBadge(int viewerCount) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(.36),
        border: Border.all(color: Colors.white.withOpacity(.18), width: .6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_2_fill,
            color: Colors.white,
            size: compact ? 11 : 14,
          ),
          const SizedBox(width: 3),
          Text(
            _formatCount(viewerCount),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: compact ? kHeight * .0088 : kHeight * .0105,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _idChip(
      String id, {
        required String countryFlag,
        required bool featured,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: featured ? 8 : 6,
        vertical: featured ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.35), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (countryFlag.isNotEmpty) ...[
            Text(
              countryFlag,
              style: TextStyle(
                fontSize: featured ? kHeight * .0135 : kHeight * .0115,
                height: 1,
              ),
            ),
            SizedBox(width: featured ? 5 : 3),
          ],
          Text(
            ('ID: $id').appTr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: featured ? kHeight * .0105 : kHeight * .009,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge({required bool isPk, required bool isAudio}) {
    final String label = isPk ? 'PK' : (isAudio ? 'Audio' : 'Live');
    final IconData icon = isPk
        ? Icons.sports_mma_rounded
        : (isAudio ? Icons.mic_rounded : Icons.wifi_tethering_rounded);

    final List<Color> colors = isPk
        ? const [Color(0xffff7a00), Color(0xffff2d55)]
        : isAudio
        ? const [Color(0xff23d7b0), Color(0xff667eea)]
        : const [Color(0xffff2768), Color(0xffff7b34)];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? kHeight * .0084 : kHeight * .0103,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }
}

class CastomminContainer extends StatelessWidget {
  final String image;

  const CastomminContainer({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Image(image: AssetImage(image), height: 30),
      ),
    );
  }
}
