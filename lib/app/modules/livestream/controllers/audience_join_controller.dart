import 'dart:async';

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
import 'roket_controller.dart';
import '../socket/websocket_controller.dart';
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
  final Map<int, Map<String, dynamic>> _pendingRoutePresentations = {};
  final Map<int, Map<String, dynamic>> _pendingSelfViewerResponses = {};
  final Map<int, Map<String, dynamic>> _pendingTargetRouteData = {};
  int _readyRouteStreamId = 0;
  int _readyRouteGeneration = 0;

  bool get isJoinInProgress => _joiningLivestreamIds.isNotEmpty;

  bool _hasCanonicalRoomIdentity(Map<String, dynamic> room, int targetId) {
    return _livestreamId(room) == targetId &&
        _ownerUserId(room) > 0 &&
        _normalChannel(room).isNotEmpty;
  }

  Future<Map<String, dynamic>> _canonicalBannerTargetData(
      Map<String, dynamic> bannerData,
      ) async {
    if (!_isGlobalBannerNavigation(bannerData)) return bannerData;
    final int targetId = _livestreamId(bannerData);
    final stopwatch = Stopwatch()..start();
    String source = 'cached';
    debugPrint('BANNER_TARGET_LOOKUP_START target=$targetId source=$source');
    Map<String, dynamic> canonical = _findCachedLiveRoomData(targetId);
    if (!_hasCanonicalRoomIdentity(canonical, targetId)) {
      source = 'paged_list';
      debugPrint('BANNER_TARGET_LOOKUP_START target=$targetId source=$source');
      try {
        canonical =
            await controller.findActiveLivestreamById(targetId) ??
                <String, dynamic>{};
      } catch (_) {
        debugPrint(
          'BANNER_TARGET_LOOKUP_FAILED target=$targetId reason=network',
        );
        rethrow;
      }
    }
    if (!_hasCanonicalRoomIdentity(canonical, targetId)) {
      final reason = canonical.isEmpty ? 'not_found' : 'invalid_data';
      debugPrint('BANNER_TARGET_LOOKUP_FAILED target=$targetId reason=$reason');
      throw StateError('Canonical livestream data unavailable for $targetId');
    }
    final result = <String, dynamic>{
      ...canonical,
      'id': targetId,
      'livestream_id': targetId,
      'stream_id': targetId,
      'global_banner_type': bannerData['global_banner_type'],
      if (_asMap(bannerData['global_lucky_event']).isNotEmpty)
        'global_lucky_event': _asMap(bannerData['global_lucky_event']),
      if (_asMap(bannerData['global_lucky_bag_packet']).isNotEmpty)
        'global_lucky_bag_packet': _asMap(
          bannerData['global_lucky_bag_packet'],
        ),
    };
    debugPrint(
      'BANNER_TARGET_LOOKUP_DONE target=$targetId source=$source '
          'elapsed=${stopwatch.elapsedMilliseconds}ms host=${_ownerUserId(result)} '
          'channel=${_normalChannel(result)}',
    );
    return result;
  }

  Map<String, dynamic> _sanitizeGlobalBannerRoomData(Map<String, dynamic> raw) {
    if (!_isGlobalBannerNavigation(raw)) return raw;
    final clean = Map<String, dynamic>.from(raw);
    for (final key in const <String>[
      'livestream_callers',
      'callers',
      'accepted_callers',
      'pending_call',
      'pending_calls',
      'available_seats',
      'viewer_list',
      'viewers',
      'muted_users',
      'audio_muted_users',
      'locked_seats',
      'guardian_list',
      'guardians',
      'room_admins',
      'cp_connections',
    ]) {
      clean.remove(key);
    }
    final nested = _asMap(clean['livestreamdata']);
    if (nested.isNotEmpty) {
      clean['livestreamdata'] =
      _sanitizeGlobalBannerRoomData({
        ...nested,
        'global_lucky_event': clean['global_lucky_event'],
        'global_lucky_bag_packet': clean['global_lucky_bag_packet'],
      })
        ..remove('global_lucky_event')
        ..remove('global_lucky_bag_packet');
    }
    return clean;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  bool _currentRoomIsPermanent() {
    final candidates = <Map<String, dynamic>>[
      _asMap(livestreamController.createStreamData),
      _asMap(livestreamController.createData),
      _asMap(Get.arguments),
    ];
    for (final item in candidates) {
      if (_truthy(item['is_permanent']) ||
          _truthy(item['permanent_room']) ||
          _safeText(item['stream_type']).toLowerCase() == 'audio') {
        return true;
      }
    }
    return false;
  }

  ({int generation, Future<void> cleanup}) _prepareFreshAudienceSession({
    required int targetStreamId,
    required bool isBannerNavigation,
  }) {
    final int oldStreamId = <int>[
      livestreamController.streamId.value,
      websocketController.streamID.value,
      websocketController.activeAudioStreamId.value,
    ].firstWhere((value) => value > 0, orElse: () => 0);
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    final bool wasBroadcaster =
        livestreamController.isBroadcaster.value ||
            livestreamController.isHost.value;
    final int roomGeneration = livestreamController.beginRoomTransition(
      targetStreamId: targetStreamId,
    );
    _pendingRoutePresentations.removeWhere(
          (generation, _) => generation != roomGeneration,
    );
    _pendingSelfViewerResponses.removeWhere(
          (generation, _) => generation != roomGeneration,
    );
    _pendingTargetRouteData.removeWhere(
          (generation, _) => generation != roomGeneration,
    );

    final cleanup = websocketController.liveCleanupService.leaveBeforeJoining(
      oldStreamId: oldStreamId,
      targetStreamId: targetStreamId,
      userId: userId,
      generation: roomGeneration,
      wasBroadcaster: wasBroadcaster,
      wasPermanentRoom: _currentRoomIsPermanent(),
      isBannerNavigation: isBannerNavigation,
    );
    return (generation: roomGeneration, cleanup: cleanup);
  }

  void _restoreTargetBannerEvent(Map<String, dynamic> liveData) {
    final targetStreamId = _livestreamId(liveData);
    if (targetStreamId <= 0 ||
        livestreamController.streamId.value != targetStreamId) {
      return;
    }
    final packet = _asMap(liveData['global_lucky_bag_packet']);
    if (packet.isNotEmpty) {
      final packetStreamId = _livestreamId(packet);
      if (packetStreamId > 0 && packetStreamId != targetStreamId) return;
      websocketController.currentRedPacket.value = packet;
      websocketController.redPacketVisible.value = true;
      websocketController.currentRedPacket.refresh();
    }

    final luckyEvent = _asMap(liveData['global_lucky_event']);
    if (luckyEvent.isNotEmpty) {
      final type = _safeText(liveData['global_banner_type']).toLowerCase();
      if (type == 'rocket') {
        final rocket = Get.isRegistered<RocketController>()
            ? Get.find<RocketController>()
            : Get.put(RocketController(), permanent: true);
        rocket.restoreRoomLaunchPresentation(
          livestreamId: _livestreamId(liveData),
          payload: luckyEvent,
        );
      } else {
        livestreamController.showLuckyGiftResult(luckyEvent);
      }
    }
  }

  void markTargetRouteReady({required int streamId}) {
    final generation = livestreamController.roomSessionGeneration;
    if (!livestreamController.isRoomSessionCurrent(
      streamId: streamId,
      generation: generation,
    )) {
      return;
    }
    _readyRouteStreamId = streamId;
    _readyRouteGeneration = generation;
    debugPrint('TARGET_ROUTE_READY stream=$streamId generation=$generation');

    final viewerResponse = _pendingSelfViewerResponses.remove(generation);
    if (viewerResponse != null) {
      websocketController.reconcileSelfViewerJoinFromApi(
        livestreamId: streamId,
        viewerId: authController.userProfile.value.user?.id?.toInt() ?? 0,
        response: viewerResponse,
      );
      debugPrint('ENTRY_PRESENTATION_SHOWN stream=$streamId');
    }

    final presentation = _pendingRoutePresentations.remove(generation);
    final routeData = _pendingTargetRouteData.remove(generation);
    if (routeData != null) {
      final int userId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      bool isSelf(dynamic raw) {
        if (raw is! Map) return false;
        final map = Map<String, dynamic>.from(raw);
        final user = _asMap(map['user']);
        return _toInt(
          map['viewer_id'] ??
              map['user_id'] ??
              map['caller_id'] ??
              user['id'],
        ) ==
            userId;
      }

      final selfCalls = websocketController.liveCallList.where(isSelf).toList();
      final selfSeatNo = selfCalls.fold<int>(0, (seat, raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return seat > 0 ? seat : _toInt(map['seat_no'] ?? map['seat_number']);
      });
      final viewerSelfCount = livestreamController.liveViewerList
          .where(isSelf)
          .length;
      final int canonicalStreamId = _livestreamId(routeData);
      debugPrint(
        'TARGET_UI_PARITY streamId=${livestreamController.streamId.value} '
            'canonicalStreamId=$canonicalStreamId routeStreamId=$streamId '
            'hostId=${_ownerUserId(routeData)} '
            'displayedHostId=${livestreamController.broadcasterId.value} '
            'selfUserId=$userId '
            'displayedOwnerSeatUserId=${livestreamController.broadcasterId.value} '
            'streamTitle=${_safeText(routeData['stream_title'] ?? routeData['title'])} '
            'viewerCount=${livestreamController.liveViewerList.length} '
            'viewerListCount=${livestreamController.liveViewerList.length} '
            'viewerContainsSelf=${viewerSelfCount > 0} '
            'viewerSelfCount=$viewerSelfCount selfSeatNo=$selfSeatNo '
            'callListCount=${websocketController.liveCallList.length}',
      );
    }
    if (presentation != null) {
      final type = _safeText(presentation['global_banner_type']);
      debugPrint(
        'BANNER_PRESENTATION_RESTORE type=$type stream=$streamId '
            'generation=$generation',
      );
      _restoreTargetBannerEvent(presentation);
      debugPrint('BANNER_PRESENTATION_SHOWN type=$type stream=$streamId');
    }
  }

  bool _isGlobalBannerNavigation(Map<String, dynamic> liveData) =>
      _asMap(liveData['global_lucky_bag_packet']).isNotEmpty ||
          _asMap(liveData['global_lucky_event']).isNotEmpty;

  void _logJoinParity({
    required Map<String, dynamic> liveData,
    required int streamId,
    required int generation,
    required int userId,
  }) {
    bool isSelf(dynamic raw) {
      if (raw is! Map) return false;
      final map = Map<String, dynamic>.from(raw);
      final user = _asMap(map['user']);
      return _toInt(
        map['viewer_id'] ??
            map['user_id'] ??
            map['caller_id'] ??
            user['id'],
      ) ==
          userId;
    }

    final selfCalls = websocketController.liveCallList.where(isSelf).toList();
    final pendingSelf = websocketController.pendingCall.where(isSelf).length;
    final selfSeat = selfCalls.fold<int>(0, (seat, raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return seat > 0 ? seat : _toInt(map['seat_no'] ?? map['seat_number']);
    });
    final viewerSelfCount = livestreamController.liveViewerList
        .where(isSelf)
        .length;
    final sourceType = _safeText(liveData['global_banner_type']).isNotEmpty
        ? _safeText(liveData['global_banner_type'])
        : _isGlobalBannerNavigation(liveData)
        ? 'lucky'
        : 'list';
    debugPrint(
      'JOIN_PARITY sourceType=$sourceType streamId=$streamId '
          'sessionGeneration=$generation userId=$userId '
          'isHost=${livestreamController.isHost.value} '
          'isBroadcaster=${livestreamController.isBroadcaster.value} '
          'viewerContainsSelf=${viewerSelfCount > 0} '
          'viewerSelfCount=$viewerSelfCount selfSeatNo=$selfSeat '
          'selfAcceptedCallCount=${selfCalls.length} '
          'pendingSelfCallCount=$pendingSelf '
          'guardian=${livestreamController.isMyGuardian.value} '
          'muted=${websocketController.audioMutedUserMap[userId] == true} '
          'agoraRole=audience callListCount=${websocketController.liveCallList.length}',
    );
  }

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
    final Map<String, dynamic> initialLiveData = _sanitizeGlobalBannerRoomData(
      _asMap(data),
    );
    final int requestedLivestreamId = _livestreamId(initialLiveData);
    if (requestedLivestreamId <= 0 ||
        _joiningLivestreamIds.contains(requestedLivestreamId)) {
      return;
    }

    final int currentStreamId = <int>[
      livestreamController.streamId.value,
      websocketController.streamID.value,
      websocketController.activeAudioStreamId.value,
    ].firstWhere((value) => value > 0, orElse: () => 0);
    if (currentStreamId == requestedLivestreamId &&
        (_isGlobalBannerNavigation(initialLiveData) ||
            AgoraService().isJoinedChannel)) {
      _restoreTargetBannerEvent(initialLiveData);
      return;
    }

    _joiningLivestreamIds.add(requestedLivestreamId);
    final int generation = ++_joinGeneration;
    final Stopwatch joinStopwatch = Stopwatch()..start();
    void timing(String label) {
      if (kDebugMode) {
        debugPrint('[LIVE_JOIN] $label ${joinStopwatch.elapsedMilliseconds}ms');
      }
    }

    bool isCurrentJoin() =>
        generation == _joinGeneration &&
            _joiningLivestreamIds.contains(requestedLivestreamId) &&
            !isClosed;

    // ✅ FIX: see abortRoomTransition/abortRoomSession. beginRoomTransition
    // (called inside _prepareFreshAudienceSession below) locks out realtime
    // events for every stream until a matching activate call lands. This
    // pair of variables lets the finally block detect "we opened a
    // transition but this join returned/threw before ever activating it"
    // and safely roll it back, instead of leaving every future join/seat/
    // entry update silently dropped.
    int? startedRoomGeneration;
    bool transitionActivated = false;

    isLoading.value = true;
    timing('join_tap');
    _setJoinProgress('Preparing live room...');
    timing('controller_ready');
    final bool isBannerNavigation = _isGlobalBannerNavigation(initialLiveData);
    if (!isBannerNavigation) _warmAudioEngineForFastJoin();

    try {
      Map<String, dynamic> liveData = initialLiveData;

      final int userId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;

      final int originalLivestreamId = _livestreamId(liveData);
      if (userId == 0 || originalLivestreamId == 0) {
        Get.snackbar(
          ('Error').appTr,
          ('Live join data missing. Please refresh and try again.').appTr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final transition = _prepareFreshAudienceSession(
        targetStreamId: requestedLivestreamId,
        isBannerNavigation: isBannerNavigation,
      );
      final int roomGeneration = transition.generation;
      startedRoomGeneration = roomGeneration;

      late Future<Map<String, dynamic>> resultFuture;
      if (isBannerNavigation) {
        await transition.cleanup;
        if (!isCurrentJoin()) return;

        final bool sourceStateCleared =
            livestreamController.streamId.value == 0 &&
                websocketController.streamID.value == 0 &&
                websocketController.activeAudioStreamId.value == 0 &&
                !livestreamController.isHost.value &&
                !livestreamController.isBroadcaster.value &&
                websocketController.liveCallList.isEmpty &&
                websocketController.pendingCall.isEmpty;
        assert(requestedLivestreamId != currentStreamId);
        assert(sourceStateCleared);
        if (!sourceStateCleared) {
          debugPrint(
            'TARGET_JOIN_BLOCKED source=$currentStreamId target=$requestedLivestreamId '
                'stream=${livestreamController.streamId.value} '
                'ws=${websocketController.streamID.value} '
                'audio=${websocketController.activeAudioStreamId.value} '
                'host=${livestreamController.isHost.value} '
                'broadcaster=${livestreamController.isBroadcaster.value} '
                'calls=${websocketController.liveCallList.length} '
                'pending=${websocketController.pendingCall.length}',
          );
          return;
        }

        // Remove the inactive Room A surface before any Room B work starts.
        // The legacy Multi view explicitly ignores shared-state disposal while
        // this authoritative transition is in progress.
        if (currentStreamId > 0 && Get.key.currentState?.canPop() == true) {
          Get.back(closeOverlays: false);
          await WidgetsBinding.instance.endOfFrame;
          if (!isCurrentJoin()) return;
        }

        liveData = await _canonicalBannerTargetData(initialLiveData);
        if (!isCurrentJoin()) return;
        _warmAudioEngineForFastJoin();
        debugPrint(
          'TARGET_JOIN_START source=$currentStreamId target=$requestedLivestreamId '
              'generation=$roomGeneration',
        );
        _setJoinProgress('Checking room access...');
        timing('join_api_start');
        if (kDebugMode) debugPrint('[LIVE_JOIN] access_start');
        resultFuture = livestreamController.checkCanJoinLivestream(
          requestedLivestreamId,
          userId,
        );
      } else {
        final canonicalFuture = _canonicalBannerTargetData(initialLiveData);
        _setJoinProgress('Checking room access...');
        timing('join_api_start');
        if (kDebugMode) debugPrint('[LIVE_JOIN] access_start');
        resultFuture = livestreamController.checkCanJoinLivestream(
          requestedLivestreamId,
          userId,
        );
        liveData = await canonicalFuture;
      }
      if (!isCurrentJoin()) return;
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

      if (finalAgoraChannel.isEmpty) {
        Get.snackbar(
          ('Error').appTr,
          ('Live join data missing. Please refresh and try again.').appTr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // A global banner is an audience navigation intent. In particular, Lucky
      // receiver data must never turn this into a permanent-room host rejoin.
      if (!_isGlobalBannerNavigation(liveData) &&
          _ownerUserId(liveData) == userId) {
        await transition.cleanup;
        if (!isCurrentJoin()) return;
        livestreamController.streamId.value = originalLivestreamId;
        websocketController.streamID.value = originalLivestreamId;
        await livestreamController.rejoinPermanentRoom(
          livestreamId: originalLivestreamId,
          fallbackLiveData: liveData,
        );
        return;
      }

      // Access and fallback RTC-token generation are independent once the
      // canonical channel/uid are known. Run them concurrently so two slow
      // backend calls do not add their latencies together. Access remains the
      // authority: a rejection below discards this token result.
      final Stopwatch tokenStopwatch = Stopwatch()..start();
      final Future<bool> parallelFallbackTokenFuture = agoraTokenController
          .tryToGenerateBroadcasterToken(
        isBroadcaster: false,
        userId: userId,
        channelName: finalAgoraChannel,
        streamId: '$originalLivestreamId',
        pkId: isPkRunning ? pkId : null,
      );

      final result = await resultFuture;
      timing('join_api_done');
      if (kDebugMode) {
        debugPrint(
          '[LIVE_JOIN] access_done duration_ms=${joinStopwatch.elapsedMilliseconds}',
        );
      }
      if (!isCurrentJoin()) return;

      final bool tokenFromJoinResponse = agoraTokenController
          .adoptTokenResponseIfValid(
        response: result,
        isBroadcaster: false,
        userId: userId,
        channelName: finalAgoraChannel,
        streamId: '$originalLivestreamId',
        pkId: isPkRunning ? pkId : null,
      );
      if (kDebugMode) {
        debugPrint(
          '[LIVE_JOIN][ACCESS_RESPONSE] '
              'duration_ms=${joinStopwatch.elapsedMilliseconds} '
              'has_rtc_token=$tokenFromJoinResponse '
              'token_source=${tokenFromJoinResponse ? 'join_response' : 'parallel_token_api'}',
        );
      }

      if (!isBannerNavigation) await transition.cleanup;
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
      // The unified listener is idempotent and normally already connected.
      // Prepare it and clear stale leave guards before add-viewer so realtime
      // events cannot be missed in the join/snapshot gap.
      unawaited(websocketController.tryToConnectToUnifiedLiveStreamEventWs());
      websocketController.prepareViewerRejoin(
        livestreamId: originalLivestreamId,
        viewerId: userId,
      );
      timing('socket_ready');
      final viewerAddFuture = livestreamController.tryToAddViewer(
        streamId: originalLivestreamId,
        viewerId: userId,
        syncState: false,
        activateRoom: false,
      );
      if (isBannerNavigation) {
        viewerAddFuture.then((_) {
          debugPrint('TARGET_ADD_VIEWER_DONE target=$originalLivestreamId');
        });
      }

      final Future<bool> tokenFuture = tokenFromJoinResponse
          ? Future<bool>.value(true)
          : parallelFallbackTokenFuture;

      _setJoinProgress('Connecting audio...');
      final bool tokenReady = await tokenFuture;
      tokenStopwatch.stop();
      timing('agora_token');
      if (kDebugMode) {
        debugPrint(
          '[LIVE_JOIN][TOKEN_READY] room=$originalLivestreamId '
              'duration_ms=${tokenStopwatch.elapsedMilliseconds} '
              'source=${tokenFromJoinResponse ? 'join_response' : 'token_api'}',
        );
      }
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

      livestreamController.activateRoomSession(
        streamId: originalLivestreamId,
        generation: roomGeneration,
      );
      if (isBannerNavigation) {
        debugPrint(
          'TARGET_SESSION_ACTIVATED target=$originalLivestreamId '
              'generation=$roomGeneration',
        );
      }
      websocketController.activateRoomTransition(
        generation: roomGeneration,
        streamId: originalLivestreamId,
      );
      transitionActivated = true;
      livestreamController.streamId.value = originalLivestreamId;

      // ✅ FIX (rejoin shows stale "muted"): a previous full-exit's cleanup
      // (see clearSpecificUserStreamData's shouldDemoteCurrentUserMedia
      // branch) intentionally sets mute/isMuted/isAudioEnabled and
      // audioMutedUserMap[myId] to "muted" as a safety measure — it
      // prevents this device from silently republishing its mic if a
      // background/resume recovery ran after leaving a seat. That flag has
      // no expiry of its own, so it was still "muted" the next time this
      // user rejoined, even as a fresh plain viewer who never touched mute
      // this session. A confirmed successful join always starts from a
      // clean, unmuted local state.
      livestreamController.mute.value = false;
      livestreamController.isMuted.value = false;
      livestreamController.isAudioEnabled.value = true;
      if (websocketController.audioMutedUserMap.containsKey(userId)) {
        websocketController.audioMutedUserMap.remove(userId);
        websocketController.audioMutedUserMap.refresh();
      }
      // Admin state is persistent but ancillary to opening/audio. Restore it
      // asynchronously; room-scoped mutation guards reject a late old-room
      // response, while the UI updates immediately when the result arrives.
      unawaited(
        livestreamController.syncGuardianStateForRoom(
          streamId: originalLivestreamId,
          userId: userId,
        ),
      );

      livestreamController.startLivePresenceHeartbeat(
        livestreamId: originalLivestreamId,
        role: 'viewer',
        isOnSeat: false,
      );

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

      // Publish one complete target-room display snapshot before constructing
      // the route. Membership responses remain separate and must not replace
      // canonical host/title/image identity.
      livestreamController.createStreamData.value = Map<String, dynamic>.from(
        routeArguments,
      );
      livestreamController.createStreamData.refresh();
      livestreamController.broadcasterId.value = _ownerUserId(routeArguments);

      liveLog(
        '✅ Audience route hydrated => stream=$originalLivestreamId '
            'seat=$safeRouteSeatCount bg=${routeArguments['room_background']} '
            'theme=${routeArguments['room_theme']}',
      );

      debugPrint(
        'BANNER_TARGET_ROUTE_DATA stream=$originalLivestreamId '
            'host=${_ownerUserId(routeArguments)} '
            'title=${_safeText(routeArguments['stream_title'] ?? routeArguments['title'])} '
            'bannerType=${_safeText(routeArguments['global_banner_type'])}',
      );
      _readyRouteStreamId = 0;
      _readyRouteGeneration = 0;
      if (_isGlobalBannerNavigation(routeArguments)) {
        _pendingRoutePresentations[roomGeneration] = routeArguments;
      }
      _pendingTargetRouteData[roomGeneration] = routeArguments;

      _setJoinProgress('Opening room...');
      timing('join_navigation');
      if (kDebugMode) {
        debugPrint(
          '[LIVE_JOIN][NAVIGATION] room=$originalLivestreamId '
              'elapsed_ms=${joinStopwatch.elapsedMilliseconds} '
              'token_source=${tokenFromJoinResponse ? 'join_response' : 'token_api'}',
        );
      }
      if (isBannerNavigation) {
        debugPrint('TARGET_NAVIGATION target=$originalLivestreamId');
      }

      if (streamType == 'audio') {
        Get.to(
              () => AudioLiveView(
            key: ValueKey('audio_live_$originalLivestreamId'),
            channelName: finalAgoraChannel,
            isBroadcaster: false,
            token: agoraTokenController.getTokenString(),
            seatCount: safeRouteSeatCount,
            roomData: routeArguments,
          ),
          arguments: routeArguments,
        );
      } else if (streamType == 'multi') {
        livestreamController.seatCount.value = safeRouteSeatCount;

        Get.to(
              () => MultiLiveView(
            key: ValueKey('multi_live_$originalLivestreamId'),
            channelName: finalAgoraChannel,
            isBroadcaster: false,
            token: agoraTokenController.getTokenString(),
            seatCount: safeRouteSeatCount,
            roomData: routeArguments,
          ),
          arguments: routeArguments,
        );
      } else {
        Get.to(
              () => PopularLiveView(
            key: ValueKey('popular_live_$originalLivestreamId'),
            channelName: finalAgoraChannel,
            isBroadcaster: false,
            token: agoraTokenController.getTokenString(),
            roomData: routeArguments,
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
        if (_readyRouteStreamId == originalLivestreamId &&
            _readyRouteGeneration == roomGeneration) {
          websocketController.reconcileSelfViewerJoinFromApi(
            livestreamId: originalLivestreamId,
            viewerId: userId,
            response: viewerAddResponse,
          );
          debugPrint('ENTRY_PRESENTATION_SHOWN stream=$originalLivestreamId');
        } else {
          _pendingSelfViewerResponses[roomGeneration] = viewerAddResponse;
          debugPrint(
            'ENTRY_PRESENTATION_QUEUED stream=$originalLivestreamId '
                'generation=$roomGeneration',
          );
        }
        _logJoinParity(
          liveData: liveData,
          streamId: originalLivestreamId,
          generation: roomGeneration,
          userId: userId,
        );
        livestreamController.warmLiveRoomStateFast(
          streamId: originalLivestreamId,
          source: 'audience_presence_ready',
        );
      });
      timing('first_room_ui');

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

      // ✅ FIX: this is the actual bug behind "second join into a room shows
      // nothing" — see abortRoomTransition/abortRoomSession for the full
      // explanation. Whatever caused this join to exit early (a guard
      // returning, or the catch block above), if a room transition was
      // opened for this join and never activated, clear it now so the next
      // join/seat/entry event is not silently dropped forever.
      if (startedRoomGeneration != null && !transitionActivated) {
        liveLog(
          '⚠️ Rolling back stuck room transition => '
              'generation=$startedRoomGeneration stream=$requestedLivestreamId',
        );
        websocketController.abortRoomTransition(
          generation: startedRoomGeneration!,
        );
        livestreamController.abortRoomSession(
          generation: startedRoomGeneration!,
        );
      }

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