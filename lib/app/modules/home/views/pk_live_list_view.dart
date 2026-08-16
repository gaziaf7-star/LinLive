import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../livestream/controllers/livestream_controller.dart';
import '../controllers/home_controller.dart';
import 'all_live_live_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class PkLiveListView extends StatefulWidget {
  const PkLiveListView({super.key});

  @override
  State<PkLiveListView> createState() => _PkLiveListViewState();
}

class _PkLiveListViewState extends State<PkLiveListView> {
  late final HomeController controller;
  late final ScrollController _scrollController;
  Worker? _liveListWorker;

  bool _autoPagingPk = false;

  @override
  void initState() {
    super.initState();

    controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    if (!Get.isRegistered<LivestreamController>()) {
      Get.put(LivestreamController());
    }

    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollLoadMore);

    /// List update hole, first page-e PK kom/na thakle next page auto load korbe.
    _liveListWorker = ever<List<dynamic>>(
      controller.showingLiveStreamList,
          (_) => _autoLoadPkPages(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (controller.showingLiveStreamList.isEmpty &&
          !controller.isLoading.value) {
        await controller.getLivestreamList(
          page: 1,
          perPage: controller.livePerPage.value,
          refresh: true,
        );
      }

      await _autoLoadPkPages();
    });
  }

  @override
  void dispose() {
    _liveListWorker?.dispose();
    _scrollController.removeListener(_onScrollLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollLoadMore() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final bool nearBottom = position.pixels >= position.maxScrollExtent - 280;

    if (nearBottom && controller.canLoadMoreLive) {
      controller.loadMoreLivestreamList();
    }
  }

  Future<void> _refreshPkLives() async {
    await controller.getLivestreamList(
      page: 1,
      perPage: controller.livePerPage.value,
      refresh: true,
    );
    await _autoLoadPkPages();
  }

  /// ✅ Pagination PK page fix:
  /// First page-e PK na thakle page 2,3,4... auto load kore PK khujbe.
  Future<void> _autoLoadPkPages() async {
    if (_autoPagingPk || !mounted) return;

    _autoPagingPk = true;

    try {
      int guard = 0;

      while (mounted && guard < 10) {
        final pkCount = _preparePkList(
          List<dynamic>.from(controller.showingLiveStreamList),
        ).length;

        final bool needMorePk = pkCount == 0 || pkCount < 4;

        if (!needMorePk || !controller.canLoadMoreLive) break;
        if (controller.isLoading.value || controller.isLoadingMoreLive.value) {
          break;
        }

        guard++;
        await controller.loadMoreLivestreamList();

        /// UI update hobar jonno small delay.
        await Future.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      _autoPagingPk = false;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _clean(dynamic value) => value?.toString().toLowerCase().trim() ?? '';

  bool _truthy(dynamic value) {
    final String v = _clean(value);
    return value == true ||
        value == 1 ||
        v == '1' ||
        v == 'true' ||
        v == 'yes' ||
        v == 'on';
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();

    final String cleanValue = value.toString().trim().replaceAll(
      RegExp(r'[^0-9-]'),
      '',
    );

    if (cleanValue.isEmpty || cleanValue == '-') return fallback;
    return int.tryParse(cleanValue) ?? fallback;
  }

  bool _isRealPkAgoraChannel(String value) {
    final channel = value.trim();
    // Real PK agora channel looks like pk_8211_8210_1782930208.
    // Numeric room ids like 101010/100550 are NOT PK channels.
    return channel.startsWith('pk_') && channel.split('_').length >= 4;
  }

  String _firstRealPkChannelFromMap(Map<String, dynamic> map) {
    final nested = _asMap(map['data']);
    final pkRoom = _asMap(map['pk_room'] ?? map['pk'] ?? map['current_pk']);
    final candidates = [
      map['pk_channel_name'],
      map['pk_channel'],
      map['pk_agora_channel'],
      map['pk_room_channel'],
      map['agora_channel_name'],
      map['audience_join_agora_channel'],
      map['channel_name'],
      map['room_id'],
      nested['pk_channel_name'],
      nested['pk_channel'],
      nested['channel_name'],
      pkRoom['pk_channel_name'],
      pkRoom['pk_channel'],
      pkRoom['channel_name'],
    ];
    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (_isRealPkAgoraChannel(value)) return value;
    }
    return '';
  }

  String _controllerPkChannelFallback(dynamic pkIdRaw) {
    final int pkId = _toInt(pkIdRaw);
    try {
      final live = Get.find<LivestreamController>();
      final active = live.pkChannelName.value.trim();
      if (_isRealPkAgoraChannel(active) &&
          (pkId <= 0 ||
              live.currentPkId.value == 0 ||
              live.currentPkId.value == pkId)) {
        return active;
      }
      final current = Map<String, dynamic>.from(live.currentPkData);
      final currentPkId = _toInt(
        current['pk_id'] ??
            current['id'] ??
            (current['data'] is Map ? current['data']['pk_id'] : null),
      );
      if (pkId > 0 && currentPkId > 0 && currentPkId != pkId) return '';
      final fromData = _firstRealPkChannelFromMap(current);
      if (_isRealPkAgoraChannel(fromData)) return fromData;
    } catch (_) {}
    return '';
  }

  String _resolveRealPkChannel(Map<String, dynamic> pkData) {
    final direct = _firstRealPkChannelFromMap(pkData);
    if (_isRealPkAgoraChannel(direct)) return direct;
    return _controllerPkChannelFallback(pkData['pk_id'] ?? pkData['id']);
  }

  /// ✅ Only real PK room detect.
  /// Normal live room-er pk_status running hole duplicate card hote pare,
  /// tai seta direct PK card dhora hocche na.
  bool _isRealPkRoom(dynamic item) {
    final Map<String, dynamic> map = _asMap(item);
    if (map.isEmpty) return false;

    final String id = map['id']?.toString() ?? '';
    final String streamType = _clean(map['stream_type']);

    final bool hasPkPair =
        map['sender_livestream'] != null ||
            map['receiver_livestream'] != null ||
            map['sender_livestream_id'] != null ||
            map['receiver_livestream_id'] != null;

    return streamType == 'pk' ||
        _truthy(map['is_pk_room']) ||
        id.startsWith('pk_') ||
        (map['pk_id'] != null && hasPkPair);
  }

  /// ✅ Old UserProfileCard support + PK data support.
  /// one PK object-er vitore sender_livestream + receiver_livestream thake.
  /// showSide = sender hole sender card, receiver hole receiver card.
  Map<String, dynamic> _makePkRoomCardData(
      dynamic item, {
        required String showSide,
      }) {
    final Map<String, dynamic> pkData = _asMap(item);
    final Map<String, dynamic> senderLive = _asMap(pkData['sender_livestream']);
    final Map<String, dynamic> receiverLive = _asMap(
      pkData['receiver_livestream'],
    );
    final Map<String, dynamic> senderHost = _asMap(pkData['sender_host']);
    final Map<String, dynamic> receiverHost = _asMap(pkData['receiver_host']);

    final bool isReceiverSide = showSide.toLowerCase().trim() == 'receiver';

    final Map<String, dynamic> mainLive = isReceiverSide
        ? receiverLive
        : senderLive;
    final Map<String, dynamic> opponentLive = isReceiverSide
        ? senderLive
        : receiverLive;
    final Map<String, dynamic> mainHost = isReceiverSide
        ? receiverHost
        : senderHost;
    final Map<String, dynamic> opponentHost = isReceiverSide
        ? senderHost
        : receiverHost;

    final dynamic pkId = pkData['pk_id'] ?? pkData['id'];
    final dynamic senderLiveId =
        pkData['sender_livestream_id'] ?? senderLive['id'];
    final dynamic receiverLiveId =
        pkData['receiver_livestream_id'] ?? receiverLive['id'];
    final dynamic mainLiveId = isReceiverSide ? receiverLiveId : senderLiveId;
    final dynamic opponentLiveId = isReceiverSide
        ? senderLiveId
        : receiverLiveId;

    final Map<String, dynamic> mainUser = _asMap(mainLive['user']);
    final Map<String, dynamic> opponentUser = _asMap(opponentLive['user']);

    final String mainName =
    (mainHost['name'] ??
        mainLive['stream_bte'] ??
        mainUser['name'] ??
        (isReceiverSide ? 'Opponent' : 'PK Host'))
        .toString();
    final String opponentName =
    (opponentHost['name'] ??
        opponentLive['stream_bte'] ??
        opponentUser['name'] ??
        (isReceiverSide ? 'PK Host' : 'Opponent'))
        .toString();

    final dynamic currentScore = isReceiverSide
        ? (pkData['receiver_score'] ?? 0)
        : (pkData['sender_score'] ?? 0);
    final dynamic opponentScore = isReceiverSide
        ? (pkData['sender_score'] ?? 0)
        : (pkData['receiver_score'] ?? 0);

    final String pkAgoraChannel = _resolveRealPkChannel(pkData);

    final String normalRoomId =
    (mainLive['room_id'] ??
        mainLive['channel_name'] ??
        mainLive['user_id'] ??
        '')
        .toString()
        .trim();

    final bool pkChannelReady = _isRealPkAgoraChannel(pkAgoraChannel);
    if (!pkChannelReady) {
      debugPrint(
        '⚠️ PK card shown but channel pending side=$showSide normal=$normalRoomId pk=${pkData['pk_id'] ?? pkData['id']}',
      );
    }

    return {
      ...mainLive,

      /// Old live card support.
      'id': mainLiveId ?? pkData['id'],

      /// ✅ VERY IMPORTANT:
      /// PK card tap must join real PK Agora channel, not normal room_id
      /// like 101010/100550. Keep normal_room_id separately for display/fallback.
      'room_id': pkChannelReady ? pkAgoraChannel : normalRoomId,
      'normal_room_id': normalRoomId,
      'user_id':
      mainLive['user_id'] ??
          (isReceiverSide
              ? pkData['receiver_host_id']
              : pkData['sender_host_id']),
      'stream_bte': 'PK: $mainName VS $opponentName',
      'stream_type': 'pk',
      'live_status': pkData['live_status'] ?? 'active',
      'pk_status': pkData['pk_status'] ?? 'running',
      'is_pk': 1,
      'is_pk_room': true,
      'is_real_pk_room': true,
      'pk_show_side': isReceiverSide ? 'receiver' : 'sender',
      'pk_card_key': '${pkId}_${isReceiverSide ? 'receiver' : 'sender'}',

      /// PK identity/channel.
      'pk_id': pkId,
      'pk_room_id': pkData['id'],
      'channel_name': pkChannelReady ? pkAgoraChannel : '',
      'pk_channel': pkChannelReady ? pkAgoraChannel : '',
      'pk_channel_name': pkChannelReady ? pkAgoraChannel : '',
      'agora_channel_name': pkChannelReady ? pkAgoraChannel : '',
      'pk_channel_pending': !pkChannelReady,
      'pk_start_time': pkData['pk_start_time'],
      'duration_seconds': pkData['duration_seconds'],
      'remaining_seconds': pkData['remaining_seconds'],
      'remaining_time': pkData['remaining_time'],

      /// PK live ids.
      'sender_livestream_id': senderLiveId,
      'receiver_livestream_id': receiverLiveId,
      'pk_sender_livestream_id': senderLiveId,
      'pk_receiver_livestream_id': receiverLiveId,
      'current_pk_livestream_id': mainLiveId,
      'opponent_pk_livestream_id': opponentLiveId,
      'sender_host_id': pkData['sender_host_id'],
      'receiver_host_id': pkData['receiver_host_id'],
      'current_pk_host_id': isReceiverSide
          ? pkData['receiver_host_id']
          : pkData['sender_host_id'],
      'opponent_pk_host_id': isReceiverSide
          ? pkData['sender_host_id']
          : pkData['receiver_host_id'],

      /// PK scores.
      'sender_score': pkData['sender_score'] ?? 0,
      'receiver_score': pkData['receiver_score'] ?? 0,
      'current_score': currentScore,
      'opponent_score': opponentScore,
      'total_score': pkData['total_score'] ?? 0,
      'sender_score_percent': pkData['sender_score_percent'] ?? 50,
      'receiver_score_percent': pkData['receiver_score_percent'] ?? 50,
      'winner_host_id': pkData['winner_host_id'],
      'is_draw': pkData['is_draw'],

      /// Both side data.
      'sender_host': pkData['sender_host'],
      'receiver_host': pkData['receiver_host'],
      'sender_livestream': senderLive,
      'receiver_livestream': receiverLive,
      'current_pk_livestream': mainLive,
      'opponent_pk_livestream': opponentLive,
      'current_pk_host': mainHost,
      'opponent_pk_host': opponentHost,

      /// Image fallback support for old card.
      'host_profile_image':
      mainLive['host_profile_image'] ??
          mainHost['profile_image'] ??
          pkData['host_profile_image'],
      'host_image':
      mainLive['host_image'] ??
          mainHost['profile_image'] ??
          pkData['host_image'],
      'broadcaster_profile_image':
      mainLive['broadcaster_profile_image'] ??
          mainHost['profile_image'] ??
          pkData['broadcaster_profile_image'],
      'display_profile_image':
      mainLive['display_profile_image'] ??
          mainHost['profile_image'] ??
          pkData['display_profile_image'],
      'display_image':
      mainLive['display_image'] ??
          mainHost['profile_image'] ??
          pkData['display_image'],
      'thumbnail_image':
      mainLive['thumbnail_image'] ??
          mainLive['stream_image'] ??
          mainHost['profile_image'] ??
          pkData['thumbnail_image'],
      'stream_image': mainLive['stream_image'] ?? pkData['stream_image'],
      'user': mainLive['user'] ?? mainHost,
      'host_user': mainLive['host_user'] ?? mainHost,
      'broadcaster': mainLive['broadcaster'] ?? mainHost,

      /// Call/view support.
      'livestream_callers':
      mainLive['livestream_callers'] ?? pkData['livestream_callers'] ?? [],
      'viewer_count':
      mainLive['viewer_count'] ??
          pkData['viewer_count'] ??
          opponentLive['viewer_count'] ??
          0,
      'livestream_viewers_count': pkData['livestream_viewers_count'] ?? 0,

      /// Full original PK object.
      'pk_room_data': pkData,
    };
  }

  List<dynamic> _preparePkList(List<dynamic> sourceList) {
    final List<dynamic> list = [];
    final Set<String> seenCardKeys = {};

    for (final raw in sourceList) {
      final Map<String, dynamic> item = _asMap(raw);
      if (item.isEmpty) continue;
      if (!_isRealPkRoom(item)) continue;

      final String pkKey = (item['pk_id'] ?? item['id'] ?? '').toString();
      if (pkKey.isEmpty || pkKey == 'null') continue;

      final Map<String, dynamic> senderLive = _asMap(item['sender_livestream']);
      final Map<String, dynamic> receiverLive = _asMap(
        item['receiver_livestream'],
      );

      /// ✅ One PK object = 2 cards:
      /// 1) sender_livestream card
      /// 2) receiver_livestream card
      /// Normal pk_status running room direct add kora hocche na,
      /// tai duplicate/gap hobe na.
      if (senderLive.isNotEmpty || item['sender_livestream_id'] != null) {
        final String senderKey = '${pkKey}_sender';
        if (!seenCardKeys.contains(senderKey)) {
          final card = _makePkRoomCardData(item, showSide: 'sender');
          if (card.isNotEmpty) {
            seenCardKeys.add(senderKey);
            list.add(card);
          }
        }
      }

      if (receiverLive.isNotEmpty || item['receiver_livestream_id'] != null) {
        final String receiverKey = '${pkKey}_receiver';
        if (!seenCardKeys.contains(receiverKey)) {
          final card = _makePkRoomCardData(item, showSide: 'receiver');
          if (card.isNotEmpty) {
            seenCardKeys.add(receiverKey);
            list.add(card);
          }
        }
      }
    }

    return list;
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(4),
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrSearching() {
    final bool searching =
        controller.liveHasMore.value ||
            controller.isLoadingMoreLive.value ||
            _autoPagingPk;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: kHeight * 0.18),
        Center(
          child: Padding(
            padding: EdgeInsets.all(kHeight * 0.04),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (searching) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  SizedBox(height: kHeight * 0.02),
                  Castontext(
                    fontWeight: FontWeight.w500,
                    textColor: Colors.black.withOpacity(.65),
                    fontSize: kHeight * 0.013,
                    text: ('Searching PK Live...').appTr,
                  ),
                ] else ...[
                  Lottie.asset(
                    'assets/flaticons/nYuPvdjcOD.json',
                    height: kHeight * 0.14,
                    width: kHeight * 0.14,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(height: kHeight * 0.01),
                  Castontext(
                    fontWeight: FontWeight.w500,
                    textColor: Colors.black.withOpacity(.6),
                    fontSize: kHeight * 0.012,
                    text: ('No PK Live Available').appTr,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: Colors.transparent,
        child: CustomRefreshIndicator(
          onRefresh: _refreshPkLives,
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
                        height: refreshController.value * 80,
                        child: Center(
                          child: refreshController.isIdle
                              ? const SizedBox()
                              : Container(
                            decoration: BoxDecoration(
                              color: kAppColor,
                              borderRadius: BorderRadius.circular(50),
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Obx(() {
              final List<dynamic> pkLiveList = _preparePkList(
                List<dynamic>.from(controller.showingLiveStreamList),
              );

              if (controller.isLoading.value &&
                  controller.showingLiveStreamList.isEmpty) {
                return _buildLoadingGrid();
              }

              if (pkLiveList.isEmpty) {
                return _buildEmptyOrSearching();
              }

              final bool showBottomLoader =
                  controller.isLoadingMoreLive.value || _autoPagingPk;

              return GridView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(8.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemCount: pkLiveList.length + (showBottomLoader ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= pkLiveList.length) {
                    return const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.3),
                      ),
                    );
                  }

                  final item = pkLiveList[index];

                  return RepaintBoundary(
                    child: UserProfileCard(
                      key: ValueKey(
                        'pk_live_${item['id'] ?? item['livestream_id'] ?? item['pk_id'] ?? index}',
                      ),
                      data: item,
                      index: index,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}
