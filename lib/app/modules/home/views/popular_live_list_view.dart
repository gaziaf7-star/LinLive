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

class PopularLiveListView extends StatefulWidget {
  const PopularLiveListView({super.key});

  @override
  State<PopularLiveListView> createState() => _PopularLiveListViewState();
}

class _PopularLiveListViewState extends State<PopularLiveListView> {
  late final HomeController controller;
  late final ScrollController _scrollController;
  Worker? _liveListWorker;

  bool _autoPagingVideo = false;

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

    /// যখন list update হবে, তখন যদি first page-এ video না থাকে
    /// তাহলে next page auto load করে video খুঁজবে।
    _liveListWorker = ever<List<dynamic>>(
      controller.showingLiveStreamList,
          (_) => _autoLoadVideoPages(),
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

      await _autoLoadVideoPages();
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

  /// ✅ Pagination video page fix:
  /// First page-এ যদি audio বেশি থাকে আর video later page-এ থাকে,
  /// তাহলে page 2,3,4... auto load হবে যতক্ষণ video না পাওয়া যায়।
  Future<void> _autoLoadVideoPages() async {
    if (_autoPagingVideo || !mounted) return;

    _autoPagingVideo = true;

    try {
      int guard = 0;

      while (mounted && guard < 10) {
        final videoCount = _prepareVideoLiveListWithPkMeta(
          List<dynamic>.from(controller.showingLiveStreamList),
        ).length;

        final bool needMoreVideo = videoCount == 0 || videoCount < 4;

        if (!needMoreVideo || !controller.canLoadMoreLive) break;
        if (controller.isLoading.value || controller.isLoadingMoreLive.value) {
          break;
        }

        guard++;
        await controller.loadMoreLivestreamList();

        /// UI update হওয়ার জন্য ছোট delay.
        await Future.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      _autoPagingVideo = false;
    }
  }

  Future<void> _refreshVideoLives() async {
    await controller.getLivestreamList(
      page: 1,
      perPage: controller.livePerPage.value,
      refresh: true,
    );
    await _autoLoadVideoPages();
  }

  /// ✅ Only video live filter
  /// Backend response-এ video live কখনো `stream_type: popular`,
  /// আবার caller-এর ভিতরে `call_type: video` / `video_on: true` থাকে।

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

  bool _isRealPkAgoraChannel(String value) {
    final channel = value.trim();
    // Real PK agora channel looks like pk_8211_8210_1782927658.
    // Do not accept pk_109 or numeric room channels like 101010/100550.
    return channel.startsWith('pk_') && channel.split('_').length >= 4;
  }

  String _pkChannelFrom(Map<String, dynamic> item) {
    final nested = _asMap(item['data']);
    final pkRoom = _asMap(item['pk_room'] ?? item['pk'] ?? item['current_pk']);
    final candidates = [
      item['pk_channel_name'],
      item['pk_channel'],
      item['agora_channel_name'],
      item['pk_agora_channel'],
      item['audience_join_agora_channel'],
      item['channel_name'],
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

  bool _isRealPkRoom(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final streamType =
        item['stream_type']?.toString().toLowerCase().trim() ?? '';
    final hasPair =
        item['sender_livestream'] != null ||
            item['receiver_livestream'] != null ||
            item['sender_livestream_id'] != null ||
            item['receiver_livestream_id'] != null;

    return streamType == 'pk' ||
        item['is_pk_room'] == true ||
        id.startsWith('pk_') ||
        (item['pk_id'] != null && hasPair);
  }

  List<dynamic> _prepareVideoLiveListWithPkMeta(List<dynamic> sourceList) {
    final Map<int, Map<String, dynamic>> pkByLiveId = {};

    for (final raw in sourceList) {
      final pk = _asMap(raw);
      if (pk.isEmpty || !_isRealPkRoom(pk)) continue;

      final pkChannel = _pkChannelFrom(pk);
      if (!_isRealPkAgoraChannel(pkChannel)) continue;

      final senderLive = _asMap(pk['sender_livestream']);
      final receiverLive = _asMap(pk['receiver_livestream']);
      final senderLiveId = _toInt(
        pk['sender_livestream_id'] ?? senderLive['id'],
      );
      final receiverLiveId = _toInt(
        pk['receiver_livestream_id'] ?? receiverLive['id'],
      );

      if (senderLiveId > 0) {
        pkByLiveId[senderLiveId] = {
          ...pk,
          '__pk_show_side': 'sender',
          '__pk_channel': pkChannel,
        };
      }
      if (receiverLiveId > 0) {
        pkByLiveId[receiverLiveId] = {
          ...pk,
          '__pk_show_side': 'receiver',
          '__pk_channel': pkChannel,
        };
      }
    }

    final List<dynamic> result = [];
    final Set<String> seen = {};

    for (final raw in sourceList) {
      if (!_isVideoLive(raw)) continue;

      final live = _asMap(raw);
      if (live.isEmpty) continue;

      final liveId = _toInt(
        live['id'] ?? live['livestream_id'] ?? live['stream_id'],
      );
      Map<String, dynamic> out = Map<String, dynamic>.from(live);

      final String pkStatus = (live['pk_status'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final bool isPkRunningNormalLive =
          pkStatus == 'running' ||
              live['is_pk_room'] == true ||
              live['is_real_pk_room'] == true ||
              live['is_pk'] == 1 ||
              live['is_pk'] == true;

      // ✅ PK running live video tab-e show korbo na.
      // PK tab theke join korle real pk_ channel jabe. Video tab theke join korle
      // normal 101010/100550 channel chole jay, tai camera blank/flicker hoy.
      if (isPkRunningNormalLive) continue;

      final pk = pkByLiveId[liveId];
      if (pk != null) {
        final pkChannel = pk['__pk_channel']?.toString().trim() ?? '';
        final side = pk['__pk_show_side']?.toString() ?? '';
        final senderLive = _asMap(pk['sender_livestream']);
        final receiverLive = _asMap(pk['receiver_livestream']);

        if (_isRealPkAgoraChannel(pkChannel)) {
          out = {
            ...out,
            'normal_room_id': out['room_id'],
            'normal_channel_name': out['channel_name'],
            'room_id': pkChannel,
            'channel_name': pkChannel,
            'agora_channel_name': pkChannel,
            'pk_channel': pkChannel,
            'pk_channel_name': pkChannel,
            'stream_type': 'popular',
            'is_pk': 1,
            'is_pk_room': true,
            'is_real_pk_room': true,
            'pk_id': pk['pk_id'] ?? pk['id'],
            'pk_show_side': side,
            'sender_livestream_id':
            pk['sender_livestream_id'] ?? senderLive['id'],
            'receiver_livestream_id':
            pk['receiver_livestream_id'] ?? receiverLive['id'],
            'pk_sender_livestream_id':
            pk['sender_livestream_id'] ?? senderLive['id'],
            'pk_receiver_livestream_id':
            pk['receiver_livestream_id'] ?? receiverLive['id'],
            'sender_host_id': pk['sender_host_id'],
            'receiver_host_id': pk['receiver_host_id'],
            'sender_score': pk['sender_score'] ?? 0,
            'receiver_score': pk['receiver_score'] ?? 0,
            'sender_score_percent': pk['sender_score_percent'] ?? 50,
            'receiver_score_percent': pk['receiver_score_percent'] ?? 50,
            'sender_host': pk['sender_host'],
            'receiver_host': pk['receiver_host'],
            'sender_livestream': senderLive,
            'receiver_livestream': receiverLive,
            'pk_room_data': pk,
          };
        }
      }

      final key =
          '${out['id'] ?? liveId}_${out['pk_id'] ?? ''}_${out['pk_show_side'] ?? ''}';
      if (seen.add(key)) result.add(out);
    }

    return result;
  }

  bool _isVideoLive(dynamic item) {
    if (item is! Map) return false;

    final Map<String, dynamic> live = Map<String, dynamic>.from(item);

    String clean(dynamic value) => value?.toString().toLowerCase().trim() ?? '';

    bool truthy(dynamic value) {
      final v = clean(value);
      return value == true ||
          value == 1 ||
          v == '1' ||
          v == 'true' ||
          v == 'yes' ||
          v == 'on';
    }

    final streamType = clean(live['stream_type']);
    final liveType = clean(live['live_type']);
    final type = clean(live['type']);
    final callType = clean(live['call_type']);

    /// তোমার API অনুযায়ী video live = stream_type popular.
    if (streamType == 'popular' ||
        streamType == 'video' ||
        streamType == 'video_live' ||
        streamType == 'videolive' ||
        liveType == 'video' ||
        liveType == 'video_live' ||
        liveType == 'videolive' ||
        type == 'video' ||
        type == 'video_live' ||
        type == 'videolive' ||
        callType == 'video' ||
        truthy(live['video_on']) ||
        truthy(live['is_video_on']) ||
        truthy(live['host_video_on']) ||
        truthy(live['is_video_live'])) {
      return true;
    }

    final callers = live['livestream_callers'];
    if (callers is List) {
      for (final caller in callers) {
        if (caller is! Map) continue;
        final c = Map<String, dynamic>.from(caller);

        if (clean(c['call_type']) == 'video' ||
            truthy(c['video_on']) ||
            truthy(c['is_video_on']) ||
            truthy(c['host_video_on']) ||
            truthy(c['is_video_live'])) {
          return true;
        }
      }
    }

    return false;
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
            _autoPagingVideo;

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
                    text: ('Searching Video Live...').appTr,
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
                    text: ('No Video Live Available').appTr,
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
          onRefresh: _refreshVideoLives,
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
                              child: Image.asset(
                                appLogo,
                                width: 40,
                                height: 40,
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
              final videoLiveList = _prepareVideoLiveListWithPkMeta(
                List<dynamic>.from(controller.showingLiveStreamList),
              );

              if (controller.isLoading.value &&
                  controller.showingLiveStreamList.isEmpty) {
                return _buildLoadingGrid();
              }

              if (videoLiveList.isEmpty) {
                return _buildEmptyOrSearching();
              }

              final bool showBottomLoader =
                  controller.isLoadingMoreLive.value || _autoPagingVideo;

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
                itemCount: videoLiveList.length + (showBottomLoader ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= videoLiveList.length) {
                    return const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.3),
                      ),
                    );
                  }

                  final item = videoLiveList[index];

                  return RepaintBoundary(
                    child: UserProfileCard(
                      key: ValueKey(
                        'video_live_${item['id'] ?? item['livestream_id'] ?? index}',
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
