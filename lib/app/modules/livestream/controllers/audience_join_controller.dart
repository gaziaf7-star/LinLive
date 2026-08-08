import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../constants/constants.dart';
import '../../home/controllers/home_controller.dart';
import '../../../services/agora_service.dart';
import '../../messanger/views/audio_call_view.dart';
import '../../messanger/views/video_call_view.dart';
import '../views/audio_live_view.dart';
import '../views/multi_live_view.dart';
import '../views/popular_live_view.dart';
import 'agoraTokenController.dart';
import 'livestream_controller.dart';
import 'websocket_controller.dart';
import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class AudienceJoinController extends GetxController {
  final isLoading = false.obs;
  final joinProgressMessage = 'Joining live...'.obs;

  final HomeController controller = Get.isRegistered<HomeController>()
      ? Get.find<HomeController>()
      : Get.put(HomeController());
  final LivestreamController livestreamController = Get.find();
  final AgoraTokenController agoraTokenController = Get.find();
  WebsocketController get websocketController =>
      Get.find<WebsocketController>();
  final Set<int> _joiningLivestreamIds = <int>{};
  int _joinGeneration = 0;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text == 'null') return '';
    return text;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  void _setJoinProgress(String message) {
    joinProgressMessage.value = message;
  }

  void _warmAudioEngineForFastJoin() {
    Future.microtask(() async {
      try {
        await AgoraService().initializeAudioEngine();
      } catch (e) {
        liveLog('⚠️ Agora audio warmup skipped safely => $e');
      }
    });
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _safeText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  int _firstInt(List<dynamic> values) {
    for (final value in values) {
      final id = _toInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  bool _isPkLive(Map<String, dynamic> data) {
    final int pkId = _firstInt([
      data['pk_id'],
      data['current_pk_id'],
      data['pk'] is Map ? data['pk']['id'] : null,
      data['current_pk'] is Map ? data['current_pk']['id'] : null,
    ]);

    final String pkStatus = _firstText([
      data['pk_status'],
      data['pk'] is Map ? data['pk']['status'] : null,
      data['current_pk'] is Map ? data['current_pk']['status'] : null,
    ]).toLowerCase();

    final String pkChannel = _firstText([
      data['pk_channel'],
      data['pk_channel_name'],
      data['agora_pk_channel'],
      data['pk'] is Map ? data['pk']['pk_channel'] : null,
      data['pk'] is Map ? data['pk']['channel_name'] : null,
      data['current_pk'] is Map ? data['current_pk']['pk_channel'] : null,
      data['current_pk'] is Map ? data['current_pk']['channel_name'] : null,
    ]);

    final String isPk = _safeText(data['is_pk']).toLowerCase();

    return pkId > 0 ||
        pkChannel.isNotEmpty ||
        isPk == '1' ||
        isPk == 'true' ||
        pkStatus == 'running' ||
        pkStatus == 'started' ||
        pkStatus == 'active';
  }

  int _pkId(Map<String, dynamic> data) {
    return _firstInt([
      data['pk_id'],
      data['current_pk_id'],
      data['pk'] is Map ? data['pk']['id'] : null,
      data['current_pk'] is Map ? data['current_pk']['id'] : null,
    ]);
  }

  String _normalChannel(Map<String, dynamic> data) {
    // Permanent rooms use the owner/room_id as the stable normal channel.
    // Never prefer a temporary live_<id> value over room_id, otherwise the
    // host and audience can join different Agora channels.
    final user = _asMap(data['user'] ?? data['User']);
    return _firstText([
      data['room_id'],
      data['channel_name'],
      data['owner_user_id'],
      data['user_id'],
      user['id'],
      data['agora_channel_name'],
      data['agora_channel'],
      data['channel'],
    ]);
  }

  String _pkChannel(Map<String, dynamic> data) {
    return _firstText([
      data['pk_channel'],
      data['pk_channel_name'],
      data['agora_pk_channel'],
      data['pk_agora_channel'],
      data['pk_room_channel'],
      data['audience_join_agora_channel'],
      data['agora_channel_name'],
      data['channel_name'],
      data['pk'] is Map ? data['pk']['pk_channel'] : null,
      data['pk'] is Map ? data['pk']['pk_channel_name'] : null,
      data['pk'] is Map ? data['pk']['channel_name'] : null,
      data['current_pk'] is Map ? data['current_pk']['pk_channel'] : null,
      data['current_pk'] is Map ? data['current_pk']['pk_channel_name'] : null,
      data['current_pk'] is Map ? data['current_pk']['channel_name'] : null,
    ]);
  }

  bool _isRealPkAgoraChannel(String value) {
    final String channel = value.trim();
    return channel.startsWith('pk_') && channel.split('_').length >= 4;
  }

  String _controllerPkChannelFallback(int pkId) {
    try {
      final String active = livestreamController.pkChannelName.value.trim();
      final int activePkId = livestreamController.currentPkId.value;
      if (_isRealPkAgoraChannel(active) &&
          (pkId <= 0 || activePkId == 0 || activePkId == pkId)) {
        return active;
      }

      final Map<String, dynamic> current = Map<String, dynamic>.from(
        livestreamController.currentPkData,
      );
      final int currentPkId = _firstInt([
        current['pk_id'],
        current['id'],
        current['data'] is Map ? current['data']['pk_id'] : null,
        current['data'] is Map ? current['data']['id'] : null,
      ]);
      if (pkId > 0 && currentPkId > 0 && currentPkId != pkId) return '';

      final String fromData = _firstText([
        current['pk_channel_name'],
        current['pk_channel'],
        current['agora_channel_name'],
        current['channel_name'],
        current['data'] is Map ? current['data']['pk_channel_name'] : null,
        current['data'] is Map ? current['data']['pk_channel'] : null,
        current['data'] is Map ? current['data']['channel_name'] : null,
      ]);
      if (_isRealPkAgoraChannel(fromData)) return fromData;
    } catch (_) {}
    return '';
  }

  String _resolvePkJoinChannel({
    required Map<String, dynamic> data,
    required int pkId,
    required String explicitChannel,
  }) {
    final String direct = _pkChannel(data).trim();
    if (_isRealPkAgoraChannel(direct)) return direct;

    final String explicit = explicitChannel.trim();
    if (_isRealPkAgoraChannel(explicit)) return explicit;

    final String fallback = _controllerPkChannelFallback(pkId);
    if (_isRealPkAgoraChannel(fallback)) return fallback;

    return '';
  }

  int _livestreamId(Map<String, dynamic> data) {
    /// Lucky Bag packet has its own packet id in `id` and real room id in
    /// `livestream_id`. Prefer livestream_id for packet-like payloads.
    final bool looksLikeRedPacket =
        data['red_packet_id'] != null ||
        data['packet_type'] != null ||
        data['amount'] != null ||
        data['remaining_quantity'] != null ||
        data['sender_id'] != null;

    if (looksLikeRedPacket) {
      final liveId = _firstInt([
        data['livestream_id'],
        data['stream_id'],
        data['live_stream_id'],
      ]);
      if (liveId > 0) return liveId;
    }

    return _firstInt([
      data['livestream_id'],
      data['stream_id'],
      data['live_stream_id'],
      data['id'],
    ]);
  }

  int _ownerUserId(Map<String, dynamic> data) {
    final user = _asMap(data['user'] ?? data['User']);
    final broadcaster = _asMap(data['broadcaster'] ?? data['host']);
    return _firstInt([
      data['owner_user_id'],
      data['user_id'],
      data['host_id'],
      data['broadcaster_id'],
      user['id'],
      user['user_id'],
      broadcaster['id'],
      broadcaster['user_id'],
    ]);
  }

  bool _isSupportedAudioSeatCount(int count) {
    return count == 9 || count == 12 || count == 15 || count == 20;
  }

  int _normalizeAudioSeatCount(dynamic value, {int fallback = 9}) {
    final parsed = _toInt(value);
    if (_isSupportedAudioSeatCount(parsed)) return parsed;

    final safeFallback = _toInt(fallback);
    if (_isSupportedAudioSeatCount(safeFallback)) return safeFallback;

    return 9;
  }

  Map<String, dynamic> _findCachedLiveRoomData(int livestreamId) {
    if (livestreamId <= 0) return <String, dynamic>{};

    bool sameRoom(Map<String, dynamic> item) {
      final nestedLive = _asMap(item['livestream']);
      final nestedLiveData = _asMap(item['livestreamdata']);
      final id = _firstInt([
        item['livestream_id'],
        item['stream_id'],
        item['live_stream_id'],
        item['id'],
        nestedLive['livestream_id'],
        nestedLive['stream_id'],
        nestedLive['id'],
        nestedLiveData['livestream_id'],
        nestedLiveData['stream_id'],
        nestedLiveData['id'],
      ]);
      return id == livestreamId;
    }

    try {
      for (final raw in controller.showingLiveStreamList) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        if (sameRoom(item)) return item;
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Map<String, dynamic> _mergeCachedRoomDataForRoute({
    required int livestreamId,
    required Map<String, dynamic> liveData,
    Map<String, dynamic>? availableSeats,
  }) {
    final cached = _findCachedLiveRoomData(livestreamId);
    final cachedLiveData = _asMap(cached['livestreamdata']).isNotEmpty
        ? _asMap(cached['livestreamdata'])
        : _asMap(cached['livestream']).isNotEmpty
        ? _asMap(cached['livestream'])
        : <String, dynamic>{};

    final incomingLiveData = _asMap(liveData['livestreamdata']).isNotEmpty
        ? _asMap(liveData['livestreamdata'])
        : _asMap(liveData['livestream']).isNotEmpty
        ? _asMap(liveData['livestream'])
        : <String, dynamic>{};

    final mergedLiveData = <String, dynamic>{
      ...cachedLiveData,
      ...incomingLiveData,
      ...liveData,
    };

    final available = availableSeats ?? <String, dynamic>{};
    final int seatCount = _normalizeAudioSeatCount(
      liveData['seat_count'] ??
          liveData['total_seats'] ??
          incomingLiveData['seat_count'] ??
          incomingLiveData['total_seats'] ??
          cachedLiveData['seat_count'] ??
          cachedLiveData['total_seats'] ??
          cached['seat_count'] ??
          cached['total_seats'] ??
          available['total_seats'] ??
          available['seat_count'],
      fallback: 9,
    );

    final route = <String, dynamic>{
      ...cached,
      ...cachedLiveData,
      ...liveData,
      ...mergedLiveData,
      'id': livestreamId,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'seat_count': seatCount,
      'total_seats': seatCount,
      'livestreamdata': mergedLiveData,
      if (cached['livestream_callers'] != null)
        'livestream_callers': cached['livestream_callers'],
      if (cachedLiveData['livestream_callers'] != null)
        'livestream_callers': cachedLiveData['livestream_callers'],
    };

    /// Preserve Lucky Bag packet separately. Do not let packet fields like
    /// amount/quantity/id behave like livestream room metadata.
    if (liveData['amount'] != null ||
        liveData['packet_type'] != null ||
        liveData['red_packet_id'] != null) {
      route['global_lucky_bag_packet'] = Map<String, dynamic>.from(liveData);
    }

    return route;
  }

  int _pkSenderLivestreamId(
    Map<String, dynamic> data,
    int originalLivestreamId,
  ) {
    return _firstInt([
      data['pk_sender_livestream_id'],
      data['sender_livestream_id'],
      data['from_livestream_id'],
      data['pk'] is Map ? data['pk']['sender_livestream_id'] : null,
      data['pk'] is Map ? data['pk']['from_livestream_id'] : null,
      data['current_pk'] is Map
          ? data['current_pk']['sender_livestream_id']
          : null,
      data['current_pk'] is Map
          ? data['current_pk']['from_livestream_id']
          : null,
      originalLivestreamId,
    ]);
  }

  int _pkReceiverLivestreamId(Map<String, dynamic> data) {
    return _firstInt([
      data['pk_receiver_livestream_id'],
      data['receiver_livestream_id'],
      data['opponent_livestream_id'],
      data['to_livestream_id'],
      data['pk'] is Map ? data['pk']['receiver_livestream_id'] : null,
      data['pk'] is Map ? data['pk']['opponent_livestream_id'] : null,
      data['pk'] is Map ? data['pk']['to_livestream_id'] : null,
      data['current_pk'] is Map
          ? data['current_pk']['receiver_livestream_id']
          : null,
      data['current_pk'] is Map
          ? data['current_pk']['opponent_livestream_id']
          : null,
      data['current_pk'] is Map ? data['current_pk']['to_livestream_id'] : null,
    ]);
  }

  int _pkSenderHostId(Map<String, dynamic> data) {
    return _firstInt([
      data['pk_sender_host_id'],
      data['sender_host_id'],
      data['host_id'],
      data['user_id'],
      data['user'] is Map ? data['user']['id'] : null,
      data['pk'] is Map ? data['pk']['sender_host_id'] : null,
      data['current_pk'] is Map ? data['current_pk']['sender_host_id'] : null,
    ]);
  }

  int _pkReceiverHostId(Map<String, dynamic> data) {
    return _firstInt([
      data['pk_receiver_host_id'],
      data['receiver_host_id'],
      data['opponent_host_id'],
      data['opponent_user_id'],
      data['opponent'] is Map ? data['opponent']['id'] : null,
      data['opponent'] is Map ? data['opponent']['user_id'] : null,
      data['opponent_livestream'] is Map
          ? data['opponent_livestream']['user_id']
          : null,
      data['opponent_livestream'] is Map &&
              data['opponent_livestream']['user'] is Map
          ? data['opponent_livestream']['user']['id']
          : null,
      data['pk'] is Map ? data['pk']['receiver_host_id'] : null,
      data['current_pk'] is Map ? data['current_pk']['receiver_host_id'] : null,
    ]);
  }

  void _syncAudiencePkState({
    required Map<String, dynamic> data,
    required int originalLivestreamId,
    required int pkId,
    required String pkChannel,
  }) {
    final int senderStreamId = _pkSenderLivestreamId(
      data,
      originalLivestreamId,
    );
    final int receiverStreamId = _pkReceiverLivestreamId(data);
    final int senderHostId = _pkSenderHostId(data);
    final int receiverHostId = _pkReceiverHostId(data);

    livestreamController.pkModeActive.value = true;
    livestreamController.currentPkId.value = pkId;
    livestreamController.pkChannelName.value = pkChannel;

    if (senderStreamId > 0) {
      livestreamController.pkSenderLivestreamId.value = senderStreamId;
    }

    if (receiverStreamId > 0) {
      livestreamController.pkReceiverLivestreamId.value = receiverStreamId;
    }

    if (senderHostId > 0) {
      livestreamController.pkSenderHostId.value = senderHostId;
    }

    if (receiverHostId > 0) {
      livestreamController.pkReceiverHostId.value = receiverHostId;
    }

    livestreamController.currentPkData.assignAll({
      ...data,
      'is_pk': 1,
      'pk_id': pkId,
      'pk_channel': pkChannel,
      'pk_channel_name': pkChannel,
      'audience_join_livestream_id': originalLivestreamId,
      'audience_join_agora_channel': pkChannel,
      'sender_livestream_id': senderStreamId,
      'receiver_livestream_id': receiverStreamId,
      'opponent_livestream_id': originalLivestreamId == senderStreamId
          ? receiverStreamId
          : senderStreamId,
    });

    liveLog('✅ Audience PK state synced');
    liveLog('✅ pkId => $pkId');
    liveLog('✅ pkChannel => $pkChannel');
    liveLog('✅ senderStreamId => $senderStreamId');
    liveLog('✅ receiverStreamId => $receiverStreamId');
    liveLog('✅ senderHostId => $senderHostId');
    liveLog('✅ receiverHostId => $receiverHostId');
  }

  void _clearAudiencePkStateIfNormal() {
    // Normal live join er shomoy old PK state pore thakle comment/viewer filter problem kore.
    livestreamController.pkModeActive.value = false;
    livestreamController.currentPkId.value = 0;
    livestreamController.pkChannelName.value = '';
    livestreamController.pkSenderLivestreamId.value = 0;
    livestreamController.pkReceiverLivestreamId.value = 0;
    livestreamController.pkSenderHostId.value = 0;
    livestreamController.pkReceiverHostId.value = 0;
    livestreamController.currentPkData.clear();

    liveLog('✅ Audience normal live join: old PK state cleared');
  }

  Future<void> joinAsAudience({
    required String channelName,
    required dynamic data,
  }) async {
    final Map<String, dynamic> initialLiveData = _asMap(data);
    final int requestedLivestreamId = _livestreamId(initialLiveData);
    if (requestedLivestreamId <= 0 ||
        _joiningLivestreamIds.contains(requestedLivestreamId)) {
      return;
    }

    _joiningLivestreamIds.add(requestedLivestreamId);
    final int generation = ++_joinGeneration;
    final Stopwatch joinStopwatch = Stopwatch()..start();
    void timing(String label) {
      if (kDebugMode) {
        debugPrint('$label=${joinStopwatch.elapsedMilliseconds}ms');
      }
    }

    bool isCurrentJoin() =>
        generation == _joinGeneration &&
        _joiningLivestreamIds.contains(requestedLivestreamId) &&
        !isClosed;

    isLoading.value = true;
    _setJoinProgress('Preparing live room...');
    timing('join_validation_done');
    _warmAudioEngineForFastJoin();

    try {
      final Map<String, dynamic> liveData = _asMap(data);

      final int userId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;

      final int originalLivestreamId = _livestreamId(liveData);
      final bool isPkRunning = _isPkLive(liveData);
      final int pkId = _pkId(liveData);

      final String normalChannel = _normalChannel(liveData).isNotEmpty
          ? _normalChannel(liveData)
          : channelName;

      final String pkJoinChannel = _resolvePkJoinChannel(
        data: liveData,
        pkId: pkId,
        explicitChannel: channelName,
      );

      // Viewer/check/addviewer always original livestream id.
      // Agora channel PK running hole ONLY real pk_ channel use hobe.
      // Missing PK channel hole normal 101010/100550 te join korbo na, otherwise
      // Channel mismatch / blank camera / auto removeviewer hobe.
      if (isPkRunning && !_isRealPkAgoraChannel(pkJoinChannel)) {
        Get.snackbar(
          ('PK room syncing').appTr,
          ('Please refresh PK list and try again.').appTr,
          snackPosition: SnackPosition.BOTTOM,
        );
        liveLog(
          '⛔ PK audience join blocked: real pk channel missing => stream=$originalLivestreamId pk=$pkId normal=$normalChannel',
        );
        return;
      }

      final String finalAgoraChannel = isPkRunning
          ? pkJoinChannel
          : normalChannel;

      liveLog('================ AUDIENCE JOIN START ================');
      liveLog(
        '👀 join => user=$userId stream=$originalLivestreamId '
        'pk=$isPkRunning channel=$finalAgoraChannel',
      );

      if (userId == 0 ||
          originalLivestreamId == 0 ||
          finalAgoraChannel.isEmpty) {
        Get.snackbar(
          ('Error').appTr,
          ('Live join data missing. Please refresh and try again.').appTr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // The room owner must rejoin as broadcaster, never as a normal viewer.
      if (_ownerUserId(liveData) == userId) {
        livestreamController.streamId.value = originalLivestreamId;
        websocketController.streamID.value = originalLivestreamId;
        await livestreamController.rejoinPermanentRoom(
          livestreamId: originalLivestreamId,
          fallbackLiveData: liveData,
        );
        return;
      }

      _setJoinProgress('Checking room access...');
      timing('join_api_start');
      final result = await livestreamController.checkCanJoinLivestream(
        originalLivestreamId,
        userId,
      );
      timing('join_api_done');
      if (!isCurrentJoin()) return;

      if (result['can_join'] != true) {
        _showKickedDialog(
          result['message'] ?? 'You cannot join this livestream',
        );
        return;
      }

      final String requestedStreamType = _safeText(
        liveData['stream_type'],
      ).toLowerCase();
      if (requestedStreamType == 'popular' || requestedStreamType == 'video') {
        websocketController.resetAudioRoomStateForStream(
          newStreamId: originalLivestreamId,
          force: true,
        );
      }

      // Original live state set first. PK id kokhono streamId e boshbe na.
      livestreamController.streamId.value = originalLivestreamId;
      websocketController.streamID.value = originalLivestreamId;

      if (isPkRunning) {
        _syncAudiencePkState(
          data: liveData,
          originalLivestreamId: originalLivestreamId,
          pkId: pkId,
          pkChannel: finalAgoraChannel,
        );
      } else {
        _clearAudiencePkStateIfNormal();
      }

      // Fast join path:
      // - Do not block room opening with full caller/viewer list APIs.
      // - Register viewer and generate Agora token in parallel.
      // - Heavy room snapshot/list sync runs after navigation in background.
      _setJoinProgress('Entering live room...');
      final viewerAddFuture = livestreamController.tryToAddViewer(
        streamId: originalLivestreamId,
        viewerId: userId,
        syncState: false,
      );

      final tokenFuture = agoraTokenController.tryToGenerateBroadcasterToken(
        isBroadcaster: false,
        userId: userId,
        channelName: finalAgoraChannel,
        streamId: '$originalLivestreamId',
        pkId: isPkRunning ? pkId : null,
      );

      _setJoinProgress('Connecting audio...');
      final bool tokenReady = await tokenFuture;
      if (!isCurrentJoin()) {
        final viewerAddResponse = await viewerAddFuture;
        if (viewerAddResponse != null) {
          await livestreamController.tryToRemoveViewer(
            streamId: originalLivestreamId,
            viewerId: userId,
          );
        }
        return;
      }

      if (!tokenReady ||
          agoraTokenController.agoraToken.isEmpty ||
          agoraTokenController.getTokenString().isEmpty) {
        viewerAddFuture.then((viewerAddResponse) {
          if (viewerAddResponse != null) {
            livestreamController.tryToRemoveViewer(
              streamId: originalLivestreamId,
              viewerId: userId,
            );
          }
        });
        Get.snackbar(
          ('Error').appTr,
          ('Failed to generate token. Please try again later.').appTr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      /// ✅ FAST AUDIO ROOM OPEN:
      /// Do not block navigation with caller/viewer/seat APIs.
      /// The room opens first; the latest state is synced after navigation below.
      final Map<String, dynamic> availableSeatsData = <String, dynamic>{};

      final Map<String, dynamic> routeArguments = _mergeCachedRoomDataForRoute(
        livestreamId: originalLivestreamId,
        liveData: liveData,
        availableSeats: availableSeatsData,
      );

      routeArguments.addAll({
        'id': originalLivestreamId,
        'livestream_id': originalLivestreamId,
        'stream_id': originalLivestreamId,
        'room_id': normalChannel,
        'channel_name': normalChannel,
        'agora_channel': finalAgoraChannel,
        'agora_channel_name': finalAgoraChannel,
        'audience_join_livestream_id': originalLivestreamId,
        'audience_join_agora_channel': finalAgoraChannel,
        'audience_viewer_added': true,
        'audience_viewer_add_pending': true,
        'is_pk': isPkRunning ? 1 : 0,
        if (isPkRunning) 'pk_id': pkId,
        if (isPkRunning) 'pk_channel': finalAgoraChannel,
        if (isPkRunning) 'pk_channel_name': finalAgoraChannel,
      });

      final int safeRouteSeatCount = _normalizeAudioSeatCount(
        routeArguments['seat_count'] ?? routeArguments['total_seats'],
        fallback: 9,
      );
      routeArguments['seat_count'] = safeRouteSeatCount;
      routeArguments['total_seats'] = safeRouteSeatCount;
      final liveArg = _asMap(routeArguments['livestreamdata']);
      if (liveArg.isNotEmpty) {
        routeArguments['livestreamdata'] = {
          ...liveArg,
          'seat_count': safeRouteSeatCount,
          'total_seats': safeRouteSeatCount,
        };
      }

      final String rawStreamType = _safeText(
        routeArguments['stream_type'] ?? liveData['stream_type'],
      ).toLowerCase();
      final String streamType = rawStreamType.isEmpty ? 'audio' : rawStreamType;
      routeArguments['stream_type'] = streamType;

      liveLog(
        '✅ Audience route hydrated => stream=$originalLivestreamId '
        'seat=$safeRouteSeatCount bg=${routeArguments['room_background']} '
        'theme=${routeArguments['room_theme']}',
      );

      _setJoinProgress('Opening room...');
      timing('join_navigation');

      if (streamType == 'audio') {
        Get.to(
          () => AudioLiveView(
            channelName: finalAgoraChannel,
            isBroadcaster: false,
            token: agoraTokenController.getTokenString(),
            seatCount: safeRouteSeatCount,
          ),
          arguments: routeArguments,
        );
      } else if (streamType == 'multi') {
        livestreamController.seatCount.value = safeRouteSeatCount;

        Get.to(
          () => MultiLiveView(
            channelName: finalAgoraChannel,
            isBroadcaster: false,
            token: agoraTokenController.getTokenString(),
            seatCount: safeRouteSeatCount,
          ),
          arguments: routeArguments,
        );
      } else {
        Get.to(
          () => PopularLiveView(
            channelName: finalAgoraChannel,
            isBroadcaster: false,
            token: agoraTokenController.getTokenString(),
          ),
          arguments: routeArguments,
        );
      }

      /// Extra refresh after navigation, jate viewer/list/gift state latest thake.
      Future.microtask(() {
        if (!isCurrentJoin()) return;
        livestreamController.warmLiveRoomStateFast(
          streamId: originalLivestreamId,
          source: 'audience_join_after_navigation_refresh',
        );
      });
      viewerAddFuture.then((viewerAddResponse) {
        if (isClosed ||
            generation != _joinGeneration ||
            livestreamController.streamId.value != originalLivestreamId ||
            viewerAddResponse == null) {
          return;
        }
        livestreamController.warmLiveRoomStateFast(
          streamId: originalLivestreamId,
          source: 'audience_presence_ready',
        );
      });
      timing('join_first_ready');

      liveLog('================ AUDIENCE JOIN END ==================');
    } catch (e, stack) {
      liveLog('❌ Audience join error => $e');
      liveLog(stack);

      Get.snackbar(
        ('Error').appTr,
        ('Something went wrong while joining live.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _joiningLivestreamIds.remove(requestedLivestreamId);
      if (generation == _joinGeneration && !isClosed) {
        isLoading.value = false;
        _setJoinProgress('Joining live...');
      }
    }
  }

  // Show dialog when user is kicked and cannot join
  void _showKickedDialog(String message) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text(
              ("Access Denied").appTr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              ("OK").appTr,
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> joinAsCallReceiver({
    required String channelName,
    required dynamic data,
  }) async {
    await livestreamController.tryToGenerateToken(
      roleId: 1,
      userId: authController.userProfile.value.user!.id!.toInt(),
      channelName: channelName,
    );

    livestreamController.getTokens.isNotEmpty
        ? data['peeredUserCallType'] == 'audio'
              ? Get.to(
                  () => AudioCallView(
                    channelName: channelName,
                    isBroadcaster: false,
                    token: livestreamController.getTokens['token'],
                    profile: null,
                  ),
                  arguments: data,
                )
              : Get.to(
                  () => VideoCallView(
                    channelName: channelName,
                    isBroadcaster: false,
                    token: livestreamController.getTokens['token'],
                    profile: null,
                  ),
                  arguments: data,
                )
        : Get.snackbar(
            ('Error').appTr,
            ('Failed to generate token. Please try again later.').appTr,
            snackPosition: SnackPosition.BOTTOM,
          );

    isLoading.value = false;
  }
}
