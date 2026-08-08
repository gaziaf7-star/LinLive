
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/roket_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../widgets/call_request_popup.dart';
import '../../../services/agora_service.dart';
import '../../../services/live_cleanup_service.dart';
import '../../../services/device_identity_service.dart';
import '../../coinshop/views/recharge_coin_popup.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../home/controllers/home_controller.dart';
import '../utils/LiveTestingLogger.dart';
import 'livestream_controller.dart';

import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class WebsocketController extends GetxController {
  @override
  void onInit() {
    /// ✅ Backend now sends everything through one event:
    /// App\\Events\\LiveStreamEvent / LiveStreamEvent
    /// and payload contains action_type.
    ///
    /// Old separate websocket connect functions are kept below as backup,
    /// but we do not call them here anymore.
    authController.configureProtectedDio(dio);
    LiveTestingLogger.installDio(dio, owner: 'WebsocketController');
    _startLiveTestingMonitor();
    LiveTestingLogger.printBlock('LIVE TEST WEBSOCKET CONTROLLER INIT', {
      'time': DateTime.now().toIso8601String(),
      'ws_url': kWsUrl,
      'channel': liveStreamEventChannelName,
      'current_user_id': _currentUserIdInt(),
    });
    tryToConnectToUnifiedLiveStreamEventWs();

    super.onInit();
  }

  // Home controller instance
  HomeController get homeController => Get.find<HomeController>();
  LivestreamController get livestreamController =>
      Get.find<LivestreamController>();
  AuthController get authController => Get.find<AuthController>();
  // websocket staff
  WebSocketChannel? channel;
  StreamSubscription<dynamic>? _liveListSubscription;
  WebSocketChannel? _viewersChannel;
  StreamSubscription<dynamic>? _viewersSubscription;
  WebSocketChannel? _commentsChannel;
  StreamSubscription<dynamic>? _commentsSubscription;
  WebSocketChannel? _callListChannel;
  StreamSubscription<dynamic>? _callListSubscription;
  WebSocketChannel? _moderationChannel;
  StreamSubscription<dynamic>? _moderationSubscription;
  final Map<String, int> _socketGenerations = <String, int>{};
  final Set<String> _connectingSockets = <String>{};
  bool _socketLifecycleClosed = false;
  bool _realtimeLiveRefreshScheduled = false;
  Timer? _realtimeLiveRefreshTimer;

  int _nextSocketGeneration(String purpose) {
    final int generation = (_socketGenerations[purpose] ?? 0) + 1;
    _socketGenerations[purpose] = generation;
    return generation;
  }

  bool _isCurrentSocket(String purpose, int generation) =>
      !_socketLifecycleClosed && _socketGenerations[purpose] == generation;

  Future<void> _cancelSocketSubscription(
      StreamSubscription<dynamic>? subscription,
      String purpose,
      ) async {
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (error, stackTrace) {
      liveLog(
        'WebSocket $purpose listener cancellation failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _closeSocketChannel(
      WebSocketChannel? socket,
      String purpose,
      ) async {
    if (socket == null) return;
    try {
      await socket.sink.close();
    } catch (error, stackTrace) {
      liveLog('WebSocket $purpose close failed: $error\n$stackTrace');
    }
  }

  /// General room state remains ordered on this queue.
  Future<void> _unifiedEventQueue = Future<void>.value();

  /// Normal gift frames use a separate ordered fast lane. A slow seat/profile/
  /// room-state handler must never hold a visible gift behind it for 5-6 seconds.
  /// Gift order is still FIFO inside this queue.
  Future<void> _normalGiftRealtimeEventQueue = Future<void>.value();

  final streamID = 0.obs;
  final activeAudioStreamId = 0.obs;
  final newViewersJoinded = false.obs;
  final newJoinedUserData = {}.obs;

  /// viewer_join / viewer_left animation status
  final newViewerAction = 'join'.obs;

  final dio = Dio();

  Timer? _liveTestingMonitorTimer;
  int _lastTestingWsFrameAtMs = 0;
  int _testingWsFrameCount = 0;
  int _testingPusherPingCount = 0;
  int _testingPusherPongCount = 0;

  /// ===================== LIVE ROOM UI REFRESH THROTTLE =====================

  Timer? _liveCallRefreshTimer;
  Timer? _commentsRefreshTimer;
  Timer? _giftMessagesRefreshTimer;
  Timer? _giftTotalsRefreshTimer;

  // RxList.add() notifies immediately. During rapid Lucky gifts that rebuilt
  // the complete comment/gift timeline once per tap. Keep incoming rows in
  // plain queues and publish one batched Rx update every short frame window.
  final Queue<Map<String, dynamic>> _pendingGiftMessageRows =
  Queue<Map<String, dynamic>>();
  final Queue<Map<String, dynamic>> _pendingGiftCommentRows =
  Queue<Map<String, dynamic>>();

  static const int _maxLiveCommentsForRoom = 120;
  static const int _maxGiftMessagesForRoom = 80;

  void _trimListToMax(RxList list, int maxLength) {
    if (maxLength <= 0) return;
    final extra = list.length - maxLength;
    if (extra > 0) {
      list.removeRange(0, extra);
    }
  }

  void _refreshLiveCallListSmooth() {
    _liveCallRefreshTimer?.cancel();
    _liveCallRefreshTimer = Timer(const Duration(milliseconds: 120), () {
      liveCallList.refresh();
    });
  }

  void _refreshCommentsListSmooth() {
    _trimListToMax(commentsList, _maxLiveCommentsForRoom);
    _commentsRefreshTimer?.cancel();
    _commentsRefreshTimer = Timer(const Duration(milliseconds: 120), () {
      commentsList.refresh();
    });
  }

  void _refreshGiftMessagesListSmooth() {
    _trimListToMax(giftMessagesList, _maxGiftMessagesForRoom);
    _giftMessagesRefreshTimer?.cancel();
    _giftMessagesRefreshTimer = Timer(const Duration(milliseconds: 120), () {
      giftMessagesList.refresh();
    });
  }

  void _queueGiftTimelineRow(
      Map<String, dynamic> row, {
        bool alsoAddToComments = false,
      }) {
    _pendingGiftMessageRows.addLast(Map<String, dynamic>.from(row));
    if (alsoAddToComments) {
      _pendingGiftCommentRows.addLast(Map<String, dynamic>.from(row));
    }

    // One timer for a burst. Do not cancel/restart forever while auto tapping.
    if (_giftMessagesRefreshTimer?.isActive == true) return;
    _giftMessagesRefreshTimer = Timer(const Duration(milliseconds: 140), () {
      if (_pendingGiftMessageRows.isNotEmpty) {
        final rows = _pendingGiftMessageRows.toList(growable: false);
        _pendingGiftMessageRows.clear();
        giftMessagesList.value.addAll(rows);
        _trimListToMax(giftMessagesList, _maxGiftMessagesForRoom);
        giftMessagesList.refresh();
      }

      if (_pendingGiftCommentRows.isNotEmpty) {
        final rows = _pendingGiftCommentRows.toList(growable: false);
        _pendingGiftCommentRows.clear();
        commentsList.value.addAll(rows);
        _trimListToMax(commentsList, _maxLiveCommentsForRoom);
        commentsList.refresh();
      }
      _giftMessagesRefreshTimer = null;
    });
  }

  void _scheduleGiftTotalsRefresh() {
    // At most one history/total refresh per burst. The realtime payload already
    // updates the visible coins instantly; these APIs are only reconciliation.
    if (_giftTotalsRefreshTimer?.isActive == true) return;
    _giftTotalsRefreshTimer = Timer(const Duration(milliseconds: 1600), () {
      _giftTotalsRefreshTimer = null;
      try {
        final live = Get.find<LivestreamController>();
        live.fetchGiftHistory();
        live.fetchTotalGiftCoins();
      } catch (e) {
        liveLog('⚠️ gift total refresh skipped: $e');
      }
    });
  }

  /// ===================== DEBUG PRINT HELPERS =====================
  /// Comment / join / left raw data pretty print korar jonno.
  /// Logcat/console e boro JSON kete na jawar jonno chunk kore print kore.
  dynamic _debugJsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, val) {
        map[key.toString()] = _debugJsonSafe(val);
      });
      return map;
    }

    if (value is Iterable) {
      return value.map(_debugJsonSafe).toList();
    }

    return value.toString();
  }

  void _debugPrintLong(String text) {
    const int chunkSize = 800;

    if (text.length <= chunkSize) {
      liveLog(text, wrapWidth: 1024);
      return;
    }

    for (int i = 0; i < text.length; i += chunkSize) {
      final int end = (i + chunkSize < text.length)
          ? i + chunkSize
          : text.length;
      liveLog(text.substring(i, end), wrapWidth: 1024);
    }
  }

  void _printFullLiveDebug(String title, dynamic data) {
    try {
      final prettyJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(_debugJsonSafe(data));

      _debugPrintLong('\n================ $title ================');
      _debugPrintLong(prettyJson);
      _debugPrintLong('================ END $title ================\n');
    } catch (e) {
      liveLog('❌ DEBUG PRINT ERROR [$title] => $e');
      liveLog(data.toString(), wrapWidth: 1024);
    }
  }

  /// Gift payload dumps are intentionally disabled in production.
  /// Printing several hundred KB of JSON for every tap blocks the UI thread
  /// and can make the live room lag or crash during rapid Lucky gifts.
  void _forceGiftPrint(String title, dynamic data) {
    // no-op
  }

  /// One-line seat diagnostics only. No name, image, token or full user payload.
  /// Row format: userId:seatNo:status
  List<String> _compactSeatRows([Iterable<dynamic>? rows]) {
    final Iterable<dynamic> source = rows ?? liveCallList;
    final List<String> result = <String>[];
    int total = 0;

    for (final dynamic raw in source) {
      if (raw is! Map) continue;
      total++;
      if (result.length >= 20) continue;

      final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
      final int userId = _callUserId(row);
      final int seatNo = _callSeatNo(row);
      final String status =
      (row['call_status'] ?? row['status'] ?? 'unknown')
          .toString()
          .toLowerCase()
          .trim();
      result.add('$userId:$seatNo:${status.isEmpty ? 'unknown' : status}');
    }

    if (total > result.length) result.add('+${total - result.length}');
    return result;
  }

  void printSeatTrace(
      String stage, {
        int? streamId,
        int? userId,
        int? seatNo,
        String? status,
        String? reason,
        int? beforeCount,
        int? afterCount,
        Object? error,
        String? note,
      }) {
    final List<String> parts = <String>['stage=$stage'];
    if (streamId != null) parts.add('stream=$streamId');
    if (userId != null) parts.add('user=$userId');
    if (seatNo != null) parts.add('seat=$seatNo');
    if (status != null && status.trim().isNotEmpty) {
      parts.add('status=${status.trim()}');
    }
    if (reason != null && reason.trim().isNotEmpty) {
      parts.add('reason=${reason.trim()}');
    }
    if (beforeCount != null || afterCount != null) {
      parts.add('count=${beforeCount ?? liveCallList.length}->${afterCount ?? liveCallList.length}');
    }
    if (note != null && note.trim().isNotEmpty) parts.add('note=${note.trim()}');
    if (error != null) parts.add('error=$error');
    parts.add('rows=[${_compactSeatRows().join(',')}]');
    LiveTestingLogger.line('🪑 SEAT TRACE | ${parts.join(' | ')}');
  }


  void _startLiveTestingMonitor() {
    _liveTestingMonitorTimer?.cancel();
    _liveTestingMonitorTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _printLiveTestingSnapshot(source: 'periodic_30s'),
    );

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!_socketLifecycleClosed) {
        _printLiveTestingSnapshot(source: 'initial_3s');
      }
    });
  }

  Map<String, dynamic>? _testingSelfCallRow() {
    final int uid = _currentUserIdInt();
    if (uid <= 0) return null;
    for (final dynamic raw in liveCallList) {
      if (raw is! Map) continue;
      final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
      if (_callUserId(row) == uid) return row;
    }
    return null;
  }

  void _printLiveTestingSnapshot({required String source}) {
    try {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic>? selfCall = _testingSelfCallRow();
      final dynamic lastPingAt = LiveTestingLogger.findFirstByKeys(
        selfCall,
        const <String>[
          'last_ping_at',
          'last_ping',
          'ping_at',
          'last_seen_at',
        ],
      );

      LiveTestingLogger.printBlock('LIVE TEST ROOM SNAPSHOT [$source]', {
        'time': DateTime.now().toIso8601String(),
        'current_user_id': _currentUserIdInt(),
        'stream_ids': {
          'websocket_stream_id': streamID.value,
          'active_audio_stream_id': activeAudioStreamId.value,
          'controller_stream_id': livestreamController.streamId.value,
          'room_update_stream_id': liveRoomUpdateStreamId.value,
        },
        'websocket': {
          'open': liveStreamEventChannel != null &&
              liveStreamEventChannel!.closeCode == null,
          'close_code': liveStreamEventChannel?.closeCode,
          'socket_id': _rechargeSocketId,
          'generation': _unifiedSocketGeneration,
          'connecting': _isConnectingUnifiedWs,
          'reconnect_attempt': _unifiedWsReconnectAttempt,
          'background_paused': _unifiedWsReconnectPausedByBackground,
          'frames_received': _testingWsFrameCount,
          'last_frame_age_seconds': _lastTestingWsFrameAtMs > 0
              ? ((nowMs - _lastTestingWsFrameAtMs) / 1000).round()
              : null,
          'pusher_ping_count': _testingPusherPingCount,
          'pusher_pong_count': _testingPusherPongCount,
        },
        'presence': livestreamController.livePresenceDebugSnapshot,
        'legacy_websocket_heartbeat_timer_active':
        heartbeatTimer?.isActive == true,
        'last_activity_time': lastActivityTime.value.toIso8601String(),
        'last_activity_age_seconds':
        DateTime.now().difference(lastActivityTime.value).inSeconds,
        'self_call_row': selfCall,
        'self_last_ping_at': lastPingAt,
        'self_last_ping_age_seconds': LiveTestingLogger.ageSeconds(lastPingAt),
        'lists': {
          'accepted_calls': liveCallList.length,
          'accepted_seats': _compactSeatRows(),
          'pending_calls': pendingCall.length,
          'viewers': livestreamController.liveViewerList.length,
          'comments': commentsList.length,
          'gift_messages': giftMessagesList.length,
          'locked_seats': lockedSeatMap.keys.toList(),
          'muted_users': audioMutedUserMap,
        },
      });
    } catch (error, stackTrace) {
      LiveTestingLogger.printBlock('LIVE TEST SNAPSHOT ERROR', {
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
      });
    }
  }

  // Red packet properties
  final redPacketVisible = false.obs;
  final currentRedPacket = <String, dynamic>{}.obs;
  Timer? redPacketTimer;

  // Gift tracking to prevent duplicates
  final Set<String> processedGiftIds = <String>{};
  final Set<String> processedImogiIds = <String>{};
  final liveImogiAnimations = <Map<String, dynamic>>[].obs;

  /// Keeps last known mic state for every user (host + seat callers).
  /// This prevents host mute icon from being reset by unrelated seat join/leave events.
  /// true = muted, false = unmuted.
  final audioMutedUserMap = <int, bool>{}.obs;

  /// Last good hydrated user profile by user id.
  /// Caller-left / seat-remove events often arrive with partial user data.
  /// We use this cache so viewer list never becomes name/level/frame null.
  final Map<int, Map<String, dynamic>> _liveUserProfileCache =
  <int, Map<String, dynamic>>{};

  // Global red packet properties (for all live streams)
  final globalRedPacketVisible = false.obs;
  final globalCurrentRedPacket = <String, dynamic>{}.obs;
  Timer? globalRedPacketTimer;

  // Emoji animation properties
  final emojiAnimations = <Map<String, dynamic>>[].obs;
  final showEmojiAnimation = false.obs;
  Function(Map<String, dynamic> redPacketData)? onRedPacketReceived;

  // Heartbeat and cleanup properties
  Timer? heartbeatTimer;
  Timer? inactivityTimer;
  final isUserActive = true.obs;
  final lastActivityTime = DateTime.now().obs;
  final heartbeatInterval = 30; // seconds
  final inactivityTimeout = 120; // seconds (2 minutes)

  //comments on live stream
  // LivestreamController livestreamController = Get.find();
  final AgoraService _agoraService = AgoraService();

  late final LiveCleanupService liveCleanupService = LiveCleanupService(
    websocketController: this,
    livestreamController: livestreamController,
    engineProvider: () => _agoraService.engine,
  );
  // for live stream end
  final liveCallList = [].obs; // Stores accepted calls
  final pendingCall = [].obs; // Stores pending calls
  final commentsList = [].obs;

  /// ✅ Seat protection guard.
  /// Backend sometimes broadcasts caller_left with reason=heartbeat_timeout even
  /// while the current user is still inside the room and still publishing audio.
  /// In that case we must not remove the current user's seat/profile locally.
  /// The heartbeat sender must also send role=caller and is_on_seat=true; this
  /// guard protects the UI from wrong/reordered websocket snapshots.
  final Map<int, int> _heartbeatTimeoutSeatGuardUntilMs = <int, int>{};
  int _lastKnownSelfSeatNo = 0;

  /// Gift tab data.
  /// All tab = commentsList + giftMessagesList
  /// Message tab = only normal comments
  /// Gift tab = only gift data
  final giftMessagesList = [].obs;

  /// Live music status for audience UI.
  final liveMusicStatus = 'stopped'.obs;
  final liveMusicName = ''.obs;
  final liveMusicHostId = 0.obs;
  final liveMusicPositionMs = 0.obs;
  final liveMusicDurationMs = 0.obs;
  final liveMusicVolume = 65.obs;

  /// Live YouTube status for all audience UI.
  final liveYoutubeStatus = 'stopped'.obs;
  final liveYoutubeUrl = ''.obs;
  final liveYoutubeVideoId = ''.obs;
  final liveYoutubeHostId = 0.obs;

  /// Live room realtime edit state.
  /// 0 means no override yet; AudioLiveView will use initial Get.arguments values.
  final liveRoomUpdateStreamId = 0.obs;
  final liveRoomSeatCount = 0.obs;
  final liveRoomLayout = 0.obs;
  final liveRoomTheme = 0.obs;
  final liveRoomBackground = (-1).obs;
  final liveRoomTitle = ''.obs;
  final liveRoomAnnouncement = ''.obs;
  final liveRoomStreamImage = ''.obs;
  final liveRoomPassword = ''.obs;

  void clearLiveRoomSettingsForStream({int newStreamId = 0}) {
    liveRoomUpdateStreamId.value = newStreamId;
    liveRoomSeatCount.value = 0;
    liveRoomLayout.value = 0;
    liveRoomTheme.value = 0;
    liveRoomBackground.value = -1;
    liveRoomTitle.value = '';
    liveRoomAnnouncement.value = '';
    liveRoomStreamImage.value = '';
    liveRoomPassword.value = '';
  }

  void updateLiveRoomSettings({
    required int livestreamId,
    required int seatCount,
    required int roomLayout,
    required int roomTheme,
    required int roomBackground,
    String? streamTitle,
    String? streamAnnouncement,
    String? streamImage,
    String? streamPassword,
  }) {
    final int oldStreamId = liveRoomUpdateStreamId.value;

    /// HARD ROOM ISOLATION:
    /// If user moves from one live room to another, never keep the previous
    /// room's title/announcement/profile image/password as fallback.
    /// Before this guard, opening room B after editing room A could show room A
    /// information until the new API snapshot arrived.
    if (oldStreamId != 0 && oldStreamId != livestreamId) {
      clearLiveRoomSettingsForStream(newStreamId: livestreamId);
      liveLog(
        '🧹 Live room edit cache cleared => old:$oldStreamId new:$livestreamId',
      );
    } else {
      liveRoomUpdateStreamId.value = livestreamId;
    }

    liveRoomSeatCount.value = seatCount;
    liveRoomLayout.value = roomLayout;
    liveRoomTheme.value = roomTheme;
    liveRoomBackground.value = roomBackground;

    /// Null means "this snapshot did not send this field". Empty string means
    /// "current room really has empty value". Because the cache is cleared on
    /// room switch, both cases are now safe.
    if (streamTitle != null) liveRoomTitle.value = streamTitle.trim();
    if (streamAnnouncement != null)
      liveRoomAnnouncement.value = streamAnnouncement.trim();
    if (streamImage != null) liveRoomStreamImage.value = streamImage.trim();
    if (streamPassword != null) liveRoomPassword.value = streamPassword.trim();

    liveLog(
      '🎨 Live room settings updated => stream:$livestreamId seats:$seatCount layout:$roomLayout theme:$roomTheme bg:$roomBackground title:${liveRoomTitle.value} announcement:${liveRoomAnnouncement.value} image:${liveRoomStreamImage.value} password:${liveRoomPassword.value.isEmpty ? 'empty' : 'set'}',
    );
  }

  /// seatNo => locked true/false.
  ///
  /// IMPORTANT:
  /// This is the single source of truth for UI seat lock state.
  /// Viewer join / live refresh / available seat response must NOT clear this map
  /// unless backend sends an explicit unlock event or host manual unlock succeeds.
  final RxMap<int, bool> lockedSeatMap = <int, bool>{}.obs;

  /// Audio live CP adjacent seat connection state.
  /// Backend can send cp_connections/cp_connection/cp_partner_seat_no from
  /// room snapshots or seat events. AudioLiveView reads this list and draws a
  /// love symbol exactly between the two CP seats.
  final RxList<Map<String, dynamic>> cpSeatConnections =
      <Map<String, dynamic>>[].obs;

  bool _seatTruthy(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    return v == '1' ||
        v == 'true' ||
        v == 'yes' ||
        v == 'y' ||
        v == 'locked' ||
        v == 'lock';
  }

  bool _seatFalsey(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    return v == '0' ||
        v == 'false' ||
        v == 'no' ||
        v == 'n' ||
        v == 'unlocked' ||
        v == 'unlock';
  }

  int? _seatToInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  bool isSeatLocked(dynamic seatNoRaw) {
    final seatNo = _seatToInt(seatNoRaw);
    if (seatNo == null) return false;
    return lockedSeatMap[seatNo] == true;
  }

  /// Full room snapshot sync for late audience join/resume.
  /// Host live create korar por lock/mute/gift change hoye gele new audience
  /// realtime old events pabe na. Tai room open/viewer add/resume time-e API/list
  /// response theke current state local controller-e apply korte hobe.
  bool _asMuted(dynamic audioOn, dynamic mutedRaw) {
    final a = audioOn?.toString().toLowerCase().trim() ?? '';
    final m = mutedRaw?.toString().toLowerCase().trim() ?? '';

    /// ✅ FIX: audio_on is the strongest state for room snapshots.
    /// Backend/API snapshots sometimes keep stale is_muted=1 while audio_on=1.
    /// That made host/new seat user show muted even though the mic was actually on.
    if (a == '0' || a == 'false' || a == 'off' || a == 'mute' || a == 'muted')
      return true;
    if (a == '1' || a == 'true' || a == 'on' || a == 'unmute' || a == 'unmuted')
      return false;

    /// Only use muted fields when audio_on/is_audio_on is missing.
    if (m == '1' ||
        m == 'true' ||
        m == 'yes' ||
        m == 'y' ||
        m == 'muted' ||
        m == 'mute')
      return true;
    if (m == '0' ||
        m == 'false' ||
        m == 'no' ||
        m == 'n' ||
        m == 'unmuted' ||
        m == 'unmute')
      return false;

    return false;
  }

  int _extractUserIdFromAny(Map<String, dynamic> item) {
    final user = item['user'];
    final profile = item['profile'];
    final broadcaster = item['broadcaster'];
    final host = item['host'];

    final bool looksLikeStreamRoot =
        item.containsKey('livestream_id') ||
            item.containsKey('stream_id') ||
            item.containsKey('seat_count') ||
            item.containsKey('room_layout') ||
            item.containsKey('livestream_callers');

    final bool looksLikeUserObject =
        item.containsKey('name') ||
            item.containsKey('profile_image') ||
            item.containsKey('avatar') ||
            item.containsKey('level') ||
            item.containsKey('gender') ||
            item.containsKey('email');

    final raw =
        item['user_id'] ??
            item['host_id'] ??
            item['broadcaster_id'] ??
            item['caller_id'] ??
            item['viewer_id'] ??
            (user is Map ? user['id'] : null) ??
            (profile is Map ? profile['id'] : null) ??
            (broadcaster is Map ? broadcaster['id'] : null) ??
            (host is Map ? host['id'] : null) ??
            (looksLikeStreamRoot && !looksLikeUserObject ? null : item['id']);

    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  void _syncMuteStateFromUserLikeMap(
      Map<String, dynamic> item, {
        String source = 'snapshot',
      }) {
    final uid = _extractUserIdFromAny(item);
    if (uid <= 0) return;

    final user = item['user'];
    final profile = item['profile'];
    final broadcaster = item['broadcaster'];
    final host = item['host'];

    dynamic nestedAudio;
    dynamic nestedMuted;
    if (user is Map) {
      nestedAudio = user['audio_on'] ?? user['is_audio_on'] ?? user['mic_on'];
      nestedMuted =
          user['is_muted'] ?? user['muted'] ?? user['is_muted_by_host'];
    } else if (profile is Map) {
      nestedAudio =
          profile['audio_on'] ?? profile['is_audio_on'] ?? profile['mic_on'];
      nestedMuted =
          profile['is_muted'] ??
              profile['muted'] ??
              profile['is_muted_by_host'];
    } else if (broadcaster is Map) {
      nestedAudio =
          broadcaster['audio_on'] ??
              broadcaster['is_audio_on'] ??
              broadcaster['mic_on'];
      nestedMuted =
          broadcaster['is_muted'] ??
              broadcaster['muted'] ??
              broadcaster['is_muted_by_host'];
    } else if (host is Map) {
      nestedAudio = host['audio_on'] ?? host['is_audio_on'] ?? host['mic_on'];
      nestedMuted =
          host['is_muted'] ?? host['muted'] ?? host['is_muted_by_host'];
    }

    final audioOn =
        item['audio_on'] ??
            item['is_audio_on'] ??
            item['mic_on'] ??
            item['is_mic_on'] ??
            nestedAudio;

    final mutedRaw =
        item['is_muted'] ??
            item['muted'] ??
            item['is_muted_by_host'] ??
            item['mute'] ??
            item['mic_muted'] ??
            nestedMuted;

    if (audioOn == null && mutedRaw == null) return;

    final muted = _asMuted(audioOn, mutedRaw);
    audioMutedUserMap[uid] = muted;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  int _currentUserIdInt() {
    return authController.userProfile.value.user?.id?.toInt() ?? 0;
  }

  int _callUserId(Map call) {
    return _toInt(
      call['caller_id'] ??
          call['user_id'] ??
          call['viewer_id'] ??
          (call['user'] is Map ? call['user']['id'] : null) ??
          (call['caller'] is Map ? call['caller']['id'] : null),
    );
  }

  int _callSeatNo(Map call) {
    return _toInt(
      call['seat_no'] ??
          call['seatNo'] ??
          call['seat'] ??
          call['seat_number'] ??
          (call['user'] is Map ? call['user']['seat_no'] : null),
    );
  }

  bool _isAcceptedSeatCall(Map call) {
    final status = (call['call_status'] ?? call['status'] ?? 'accepted')
        .toString()
        .toLowerCase();
    return status.isEmpty ||
        status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'on_seat';
  }

  int _selfSeatNoFromLiveCallList() {
    final currentUserId = _currentUserIdInt();
    if (currentUserId <= 0) return _lastKnownSelfSeatNo;

    for (final raw in liveCallList) {
      if (raw is! Map) continue;
      final call = Map<String, dynamic>.from(raw);
      if (_callUserId(call) != currentUserId) continue;
      if (!_isAcceptedSeatCall(call)) continue;
      final seatNo = _callSeatNo(call);
      if (seatNo > 0) {
        _lastKnownSelfSeatNo = seatNo;
        return seatNo;
      }
    }
    return _lastKnownSelfSeatNo;
  }

  bool _selfIsStillOnSeatLocally() {
    final currentUserId = _currentUserIdInt();
    if (currentUserId <= 0) return false;

    for (final raw in liveCallList) {
      if (raw is! Map) continue;
      final call = Map<String, dynamic>.from(raw);
      if (_callUserId(call) != currentUserId) continue;
      if (!_isAcceptedSeatCall(call)) continue;
      final seatNo = _callSeatNo(call);
      if (seatNo > 0) {
        _lastKnownSelfSeatNo = seatNo;
        return true;
      }
    }
    return false;
  }

  void _markSelfHeartbeatSeatGuard({required int userId, required int seatNo}) {
    if (userId <= 0) return;
    if (seatNo > 0) _lastKnownSelfSeatNo = seatNo;

    /// Keep this longer than one heartbeat interval so the immediately-following
    /// livestream_state_updated snapshot cannot erase the local seat.
    _heartbeatTimeoutSeatGuardUntilMs[userId] = _nowMs() + 95000;
    liveLog(
      '🛡️ Self heartbeat seat guard enabled => user:$userId seat:$seatNo',
    );
  }

  bool _hasSelfHeartbeatSeatGuard(int userId) {
    if (userId <= 0) return false;
    final until = _heartbeatTimeoutSeatGuardUntilMs[userId] ?? 0;
    if (until <= _nowMs()) {
      _heartbeatTimeoutSeatGuardUntilMs.remove(userId);
      return false;
    }
    return true;
  }

  void syncRoomSnapshotForLateJoin(
      Map<String, dynamic>? payload, {
        String source = 'late_join_snapshot',
      }) {
    if (payload == null || payload.isEmpty) return;

    try {
      final root = Map<String, dynamic>.from(payload);
      Map<String, dynamic> data = Map<String, dynamic>.from(root);

      for (final key in [
        'data',
        'livestreamdata',
        'livestream',
        'live_stream',
        'stream',
      ]) {
        if (root[key] is Map) {
          data = {...data, ...Map<String, dynamic>.from(root[key])};
        }
      }

      /// Gift total must be available for late audience immediately.
      syncGiftCoinsFromPayload(data, source: source);
      try {
        livestreamController.syncLiveGiftCoinsFromPayload(data, source: source);
      } catch (_) {}

      /// Locked seats from current room snapshot.
      /// If backend sends explicit locked_seats, that list is the source of truth.
      final bool hasExplicitLockedSeatList =
          data['locked_seats'] is List ||
              data['lockedSeats'] is List ||
              data['locked_seat_numbers'] is List ||
              data['lockedSeatNumbers'] is List ||
              data['locks'] is List;

      if (_shouldIgnoreSeatLocksFromSource(source)) {
        liveLog(
          '🔐 locked_seats ignored from non-authority snapshot => source:$source',
        );
      } else if (_isSeatLockAuthoritativeSource(source)) {
        syncSeatLocksFromAnyPayload(data, allowUnlock: true, source: source);
      } else {
        liveLog('🔐 locked_seats skipped from weak snapshot => source:$source');
      }

      /// Host/broadcaster mute state.
      _syncMuteStateFromUserLikeMap(data, source: '$source/root');
      for (final key in [
        'user',
        'host',
        'broadcaster',
        'livestream_user',
        'owner',
      ]) {
        if (data[key] is Map) {
          _syncMuteStateFromUserLikeMap(
            Map<String, dynamic>.from(data[key]),
            source: '$source/$key',
          );
        }
      }

      /// Guardian/admin state can come with room snapshot. Keep it in the
      /// persistent roomGuardianMap so an admin who left/rejoined still keeps
      /// permissions until the host removes admin from backend.
      void syncGuardianFromAny(
          Map<String, dynamic> item, {
            Map<String, dynamic>? caller,
          }) {
        final Map<String, dynamic> user = item['user'] is Map
            ? Map<String, dynamic>.from(item['user'])
            : <String, dynamic>{};
        final int uid = _toInt(
          item['user_id'] ??
              item['caller_id'] ??
              item['target_user_id'] ??
              user['id'] ??
              user['user_id'],
        );
        if (uid <= 0) return;

        final bool hasGuardianKey =
            item.containsKey('is_guardian') ||
                item.containsKey('guardian') ||
                item.containsKey('is_admin') ||
                item.containsKey('room_admin') ||
                item.containsKey('admin') ||
                user.containsKey('is_guardian') ||
                user.containsKey('guardian') ||
                user.containsKey('is_admin') ||
                user.containsKey('room_admin') ||
                user.containsKey('admin');
        if (!hasGuardianKey) return;

        final bool isGuardian = _truthy(
          item['is_guardian'] ??
              item['guardian'] ??
              item['room_admin'] ??
              item['is_admin'] ??
              item['admin'] ??
              user['is_guardian'] ??
              user['guardian'] ??
              user['room_admin'] ??
              user['is_admin'] ??
              user['admin'],
        );

        livestreamController.applyGuardianLocalStatus(
          userId: uid,
          isGuardian: isGuardian,
          caller: caller ?? item,
        );
      }

      for (final key in [
        'guardians',
        'guardian_list',
        'room_admins',
        'admins',
      ]) {
        final list = data[key];
        if (list is List) {
          for (final raw in list) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            item['is_guardian'] ??= 1;
            syncGuardianFromAny(item);
          }
        }
      }

      /// Seat callers mute + coin + lock state.
      final callers =
          data['livestream_callers'] ??
              data['callers'] ??
              data['seats'] ??
              data['seat_users'];
      if (callers is List) {
        for (final raw in callers) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          _syncMuteStateFromUserLikeMap(item, source: '$source/caller');

          final seatNo = _seatToInt(
            item['seat_no'] ??
                item['seatNo'] ??
                item['seat'] ??
                item['seat_number'],
          );
          final rawLocked =
              item['is_locked'] ??
                  item['locked'] ??
                  item['seat_locked'] ??
                  item['lock_status'];

          /// Do not let stale livestream_callers.is_locked=yes override explicit
          /// locked_seats from backend. This was making unlocked seats appear
          /// locked again in popular/video/audio views.
          if (!hasExplicitLockedSeatList &&
              seatNo != null &&
              _seatTruthy(rawLocked)) {
            updateSeatLockStatus(
              seatNo: seatNo,
              isLocked: true,
              source: '$source/caller_lock',
            );
          }

          syncGuardianFromAny(item, caller: item);
        }
      }

      audioMutedUserMap.refresh();
      lockedSeatMap.refresh();
      _refreshLiveCallListSmooth();
      syncCpSeatConnectionsFromAnyPayload(
        data,
        source: 'room_snapshot_$source',
      );
      livestreamController.update();
      liveLog(
        '✅ Room snapshot synced for late join => source:$source locks:${lockedSeatMap.keys.toList()} muted:$audioMutedUserMap coins:$totalGiftCoins',
      );
    } catch (e, st) {
      liveLog(
        '❌ syncRoomSnapshotForLateJoin error => $e\n$st payload=$payload',
      );
    }
  }

  void updateSeatLockStatus({
    required int seatNo,
    required bool isLocked,
    String source = 'unknown',
  }) {
    if (seatNo <= 0) return;

    if (isLocked) {
      lockedSeatMap[seatNo] = true;
    } else {
      lockedSeatMap.remove(seatNo);
    }

    /// Do not mutate liveCallList['is_locked'] here.
    /// Backend call object can contain is_locked=yes for an occupied call/seat,
    /// but real room lock state must live only in lockedSeatMap.
    lockedSeatMap.refresh();
    liveLog(
      '🔒 Seat lock status updated => seat:$seatNo locked:$isLocked source:$source locks:${lockedSeatMap.keys.toList()}',
    );
  }

  /// Sync lock state from any live details / available seats / room payload.
  /// allowUnlock=false keeps previously locked seats safe during viewer join/resume.
  /// Only explicit unlock event/API success should call with allowUnlock=true or updateSeatLockStatus(false).
  void syncSeatLocksFromAnyPayload(
      Map<String, dynamic> payload, {
        bool allowUnlock = false,
        String source = 'payload',
      }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      void lockSeat(dynamic value, {String src = 'locked_list'}) {
        final seatNo = _seatToInt(value);
        if (seatNo != null && seatNo > 0) {
          updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: true,
            source: '$source/$src',
          );
        }
      }

      void parseLockedList(dynamic list, {String src = 'locked_list'}) {
        if (list is! List) return;
        for (final item in list) {
          if (item is Map) {
            final seatNo =
                item['seat_no'] ??
                    item['seatNo'] ??
                    item['seat'] ??
                    item['seat_number'] ??
                    item['no'] ??
                    item['number'];
            final rawLocked =
                item['is_locked'] ??
                    item['locked'] ??
                    item['seat_locked'] ??
                    item['lock_status'] ??
                    item['status'];
            if (seatNo != null &&
                (rawLocked == null || _seatTruthy(rawLocked))) {
              lockSeat(seatNo, src: src);
            } else if (allowUnlock &&
                seatNo != null &&
                _seatFalsey(rawLocked)) {
              final parsedSeat = _seatToInt(seatNo);
              if (parsedSeat != null) {
                updateSeatLockStatus(
                  seatNo: parsedSeat,
                  isLocked: false,
                  source: '$source/$src-explicit-unlock',
                );
              }
            }
          } else {
            lockSeat(item, src: src);
          }
        }
      }

      final bool hasExplicitLockedSeatList =
          data['locked_seats'] is List ||
              data['lockedSeats'] is List ||
              data['locked_seat_numbers'] is List ||
              data['lockedSeatNumbers'] is List ||
              data['locks'] is List;

      if (_shouldIgnoreSeatLocksFromSource(source)) {
        liveLog(
          '🔐 syncSeatLocks ignored from non-authority source => $source',
        );
        return;
      }

      parseLockedList(data['locked_seats'], src: 'locked_seats');
      parseLockedList(data['lockedSeats'], src: 'lockedSeats');
      parseLockedList(data['locked_seat_numbers'], src: 'locked_seat_numbers');
      parseLockedList(data['lockedSeatNumbers'], src: 'lockedSeatNumbers');
      parseLockedList(data['locks'], src: 'locks');

      /// ✅ If authoritative payload explicitly says no locked seats, clear
      /// stale visual locks. Do this only when allowUnlock=true; late viewer
      /// snapshots with partial data must not wipe real host locks.
      if (allowUnlock && hasExplicitLockedSeatList) {
        final bool allExplicitListsEmpty =
            (data['locked_seats'] is! List ||
                (data['locked_seats'] as List).isEmpty) &&
                (data['lockedSeats'] is! List ||
                    (data['lockedSeats'] as List).isEmpty) &&
                (data['locked_seat_numbers'] is! List ||
                    (data['locked_seat_numbers'] as List).isEmpty) &&
                (data['lockedSeatNumbers'] is! List ||
                    (data['lockedSeatNumbers'] as List).isEmpty) &&
                (data['locks'] is! List || (data['locks'] as List).isEmpty);
        if (allExplicitListsEmpty && lockedSeatMap.isNotEmpty) {
          lockedSeatMap.clear();
          lockedSeatMap.refresh();
          liveLog(
            '🔓 Cleared stale locks from explicit empty locked_seats => source:$source',
          );
        }
      }

      final dynamic callersRaw =
          data['livestream_callers'] ?? data['callers'] ?? data['seats'];
      if (!hasExplicitLockedSeatList && callersRaw is List) {
        for (final item in callersRaw) {
          if (item is! Map) continue;
          final seatNo = _seatToInt(
            item['seat_no'] ??
                item['seatNo'] ??
                item['seat'] ??
                item['seat_number'],
          );
          if (seatNo == null || seatNo <= 0) continue;

          final lockValue =
              item['is_locked'] ??
                  item['locked'] ??
                  item['seat_locked'] ??
                  item['lock_status'];

          if (_seatTruthy(lockValue)) {
            updateSeatLockStatus(
              seatNo: seatNo,
              isLocked: true,
              source: '$source/caller_lock',
            );
          } else if (allowUnlock && _seatFalsey(lockValue)) {
            updateSeatLockStatus(
              seatNo: seatNo,
              isLocked: false,
              source: '$source/caller_unlock',
            );
          }
        }
      }

      /// Intentionally never unlock from available_seats only.
      /// Some backend responses send available_seats without locked_seats and
      /// that used to make locked seats visually unlock for late viewers.
    } catch (e) {
      liveLog('⚠️ syncSeatLocksFromAnyPayload error => $e payload=$payload');
    }
  }

  final isPkRunning = false.obs;

  Function(Map<String, dynamic> collectionData)? onRedPacketCollected;

  void tryToConnectToLiveListWs() async {
    const purpose = 'live-list';
    if (channel != null && channel!.closeCode == null) return;
    if (_socketLifecycleClosed || !_connectingSockets.add(purpose)) return;
    final int generation = _nextSocketGeneration(purpose);
    await _cancelSocketSubscription(_liveListSubscription, purpose);
    _liveListSubscription = null;
    liveLog('⚡ Trying to connect to Live List WS...');
    if (channel != null) {
      try {
        await _closeSocketChannel(channel, purpose);
      } catch (error, stackTrace) {
        liveLog('WebSocket $purpose replacement failed: $error\n$stackTrace');
      }
    }
    if (kWsUrl.isEmpty) {
      liveLog('❌ WebSocket URL is empty.');
      return;
    }
    try {
      channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      final localChannel = channel!;
      await localChannel.ready;
      if (!_isCurrentSocket(purpose, generation) || channel != localChannel) {
        await _closeSocketChannel(localChannel, '$purpose stale connect');
        return;
      }
      _connectingSockets.remove(purpose);
      liveLog('✅ Connected to WebSocket');
    } catch (e) {
      liveLog('❌ Connection failed: $e');
      channel = null;
      return;
    }
    final localChannel = channel!;
    _liveListSubscription = localChannel.stream.listen((message) {
      if (!_isCurrentSocket(purpose, generation) || channel != localChannel)
        return;
      try {
        final decoded1 = json.decode(message);
        // handle ping - check in decoded JSON, not raw string
        if (decoded1 is Map && decoded1["event"] == "pusher:ping") {
          localChannel.sink.add(json.encode({"event": "pusher:pong"}));
          return;
        }
        final eventName = decoded1["event"];
        dynamic streamData;

        // 🔹 decode deeply until we reach Map
        dynamic inner = decoded1["data"];
        int safeLimit = 5; // just in case infinite nested
        while (inner is String && safeLimit > 0) {
          inner = json.decode(inner);
          safeLimit--;
        }

        // 🔹 handle nested data
        if (inner is Map) {
          if (inner["data"] is Map && inner["data"]["data"] != null) {
            streamData = inner["data"]["data"];
          } else if (inner["data"] != null) {
            streamData = inner["data"];
          } else {
            streamData = inner;
          }
        }

        if (eventName == "App\\Events\\LiveStreamCreated" ||
            eventName == "live-stream-created") {
          if (streamData != null) {
            final userId = streamData["user_id"];

            // Remove any existing stream from the same user
            homeController.showingLiveStreamList.removeWhere(
                  (s) => s["user_id"] == userId,
            );

            // Add the new stream
            homeController.showingLiveStreamList.add(streamData);
            homeController.sortLiveStreamList(); // Auto sort after adding
            homeController.showingLiveStreamList.refresh();
          } else {
            liveLog('❌ streamData is NULL after decode.');
          }
        } else if (eventName == "App\\Events\\LiveStreamEnded" ||
            eventName == "live-stream-ended") {
          if (streamData != null) {
            final streamId = streamData["id"];
            homeController.showingLiveStreamList.removeWhere(
                  (s) => s["id"] == streamId,
            );
            homeController.sortLiveStreamList(); // Auto sort after removing
            homeController.showingLiveStreamList.refresh();
            liveLog('🔚 Live Stream Ended: ${streamData["stream_bte"]}');
          }
        } else {
          liveLog('ℹ️ Other event: $eventName');
        }
      } catch (e, st) {
        liveLog("⚠️ Error decoding message: $e\n$st");
      }
    });

    // subscribe
    try {
      final subscribeData = {
        "event": "pusher:subscribe",
        "data": {"channel": "live-stream-list"},
      };
      localChannel.sink.add(json.encode(subscribeData));
      liveLog('📡 Subscribed to "live-stream-list" channel');
    } catch (e) {
      liveLog('❌ Subscription error: $e');
    }
  }

  // Method to manually refresh live stream list
  Future<void> refreshLiveStreamList() async {
    try {
      liveLog("========== REFRESH LIVE STREAM LIST START ==========");
      liveLog("API URL: $getLiveStreamList");

      final response = await dio.get(
        getLiveStreamList,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      liveLog("========== REFRESH LIVE STREAM LIST RESPONSE ==========");
      liveLog("Status Code: ${response.statusCode}");
      liveLog("Status Message: ${response.statusMessage}");
      liveLog("Response Data: ${response.data}");
      liveLog("Response Runtime Type: ${response.data.runtimeType}");

      if (response.statusCode == 200) {
        final dynamic body = response.data;

        List<dynamic> liveList = [];

        if (body is Map<String, dynamic>) {
          if (body['data'] is List) {
            liveList = List<dynamic>.from(body['data']);
          } else {
            liveList = [];
            liveLog("⚠️ body['data'] is not List");
          }
        } else if (body is List) {
          liveList = List<dynamic>.from(body);
        } else {
          liveList = [];
          liveLog("⚠️ Response body is not Map or List");
        }

        homeController.showingLiveStreamList.assignAll(liveList);
        homeController.sortLiveStreamList();

        liveLog("✅ Live stream list refreshed successfully");
        liveLog(
          "Updated List Length: ${homeController.showingLiveStreamList.length}",
        );
        liveLog("Updated List: ${homeController.showingLiveStreamList}");
      } else {
        liveLog("⚠️ Failed to refresh live stream list");
        liveLog("Status Code: ${response.statusCode}");
        liveLog("Response Data: ${response.data}");
      }
    } on DioException catch (e, stackTrace) {
      liveLog("========== DIO ERROR REFRESH LIVE STREAM LIST ==========");
      liveLog("Dio Error Type: ${e.type}");
      liveLog("Dio Error Message: ${e.message}");
      liveLog("Request URL: ${e.requestOptions.uri}");
      liveLog("Response Status Code: ${e.response?.statusCode}");
      liveLog("Response Data: ${e.response?.data}");
      liveLog("StackTrace: $stackTrace");
    } catch (e, stackTrace) {
      liveLog("========== UNKNOWN ERROR REFRESH LIVE STREAM LIST ==========");
      liveLog("Error: $e");
      liveLog("Error Runtime Type: ${e.runtimeType}");
      liveLog("StackTrace: $stackTrace");
    } finally {
      liveLog("========== REFRESH LIVE STREAM LIST END ==========");
    }
  }

  // Method to sync livestream_callers with current liveCallList
  void syncLivestreamCallers() {
    final streamIndex = homeController.showingLiveStreamList.indexWhere(
          (stream) => stream['id'] == streamID.value,
    );

    if (streamIndex != -1) {
      final stream = homeController.showingLiveStreamList[streamIndex];
      if (stream['livestream_callers'] != null) {
        // Update livestream_callers to match current liveCallList
        stream['livestream_callers'] = liveCallList.toList();
        homeController.sortLiveStreamList(); // Auto sort after sync
        homeController.showingLiveStreamList.refresh();
        liveLog('🔄 Synced livestream_callers with liveCallList');
      }
    }
  }

  //------------------------

  bool getUserAudioStatus(int userId) {
    try {
      /// ✅ Last websocket/API state wins.
      /// This stops old liveCallList rows from toggling the wrong direction.
      if (audioMutedUserMap.containsKey(userId)) {
        return audioMutedUserMap[userId] != true;
      }

      final user = liveCallList.firstWhere((viewer) {
        final callerId = viewer['caller_id'];
        final profileId = viewer['user']?['id'];
        final userIdField = viewer['user_id'];
        return callerId.toString() == userId.toString() ||
            profileId.toString() == userId.toString() ||
            userIdField.toString() == userId.toString();
      }, orElse: () => null);

      if (user != null) {
        final int normalized = _normalizeAudioOn(
          Map<String, dynamic>.from(user),
        );
        if (normalized != -1) return normalized == 1;

        final audioOnValue = user['audio_on'];
        return audioOnValue == 1 || audioOnValue.toString() == '1';
      } else {
        liveLog('User $userId not found in liveCallList');
        return true;
      }
    } catch (e) {
      liveLog('Error getting user audio status for $userId: $e');
      return true;
    }
  }

  bool getUserVideoStatus(int userId) {
    try {
      final user = liveCallList.firstWhere(
            (viewer) {
          if (viewer is! Map) return false;
          final nestedUserId = viewer['user'] is Map
              ? viewer['user']['id']
              : null;
          return viewer['caller_id'].toString() == userId.toString() ||
              viewer['user_id'].toString() == userId.toString() ||
              nestedUserId.toString() == userId.toString();
        },
        orElse: () => null,
      );

      if (user != null) {
        final videoOnValue = user['video_on'] ?? user['is_video_on'];
        final bool isVideoEnabled;
        if (videoOnValue == null) {
          final type = (user['call_type'] ?? user['type'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          isVideoEnabled = type == 'video' || type == 'popular';
        } else if (videoOnValue is bool) {
          isVideoEnabled = videoOnValue;
        } else if (videoOnValue is num) {
          isVideoEnabled = videoOnValue.toInt() != 0;
        } else {
          final text = videoOnValue.toString().trim().toLowerCase();
          isVideoEnabled = text == '1' ||
              text == 'true' ||
              text == 'yes' ||
              text == 'on' ||
              text == 'enabled';
        }
        liveLog(
          'User $userId video status: ${isVideoEnabled ? "enabled" : "disabled"} (value: $videoOnValue)',
        );
        return isVideoEnabled;
      } else {
        liveLog('User $userId not found in liveCallList');
        return true; // Default to true if user not found
      }
    } catch (e) {
      liveLog('Error getting user video status for $userId: $e');
      return true; // Default to true on error
    }
  }

  bool getUserIsOnCall(int userId) {
    try {
      final user = liveCallList.firstWhere(
            (viewer) => viewer['caller_id'].toString() == userId.toString(),
        orElse: () => null,
      );

      if (user != null) {
        liveLog('User $userId is currently on call');
        return true;
      } else {
        liveLog('User $userId is not on call');
        return false; // User not found in liveCallList
      }
    } catch (e) {
      liveLog('Error checking if user $userId is on call: $e');
      return false; // Default to false on error
    }
  }

  Future<void> tryToConnectToViewersListWs() async {
    const purpose = 'viewers';
    if (_viewersChannel != null && _viewersChannel!.closeCode == null) return;
    if (_socketLifecycleClosed || !_connectingSockets.add(purpose)) return;
    final int generation = _nextSocketGeneration(purpose);
    await _cancelSocketSubscription(_viewersSubscription, purpose);
    _viewersSubscription = null;
    await _closeSocketChannel(_viewersChannel, purpose);
    _viewersChannel = null;
    liveLog('⚡ Trying to connect to Viewer List WS...');
    try {
      if (kWsUrl.isEmpty) {
        liveLog('❌ WebSocket URL is empty, cannot connect to viewers list');
        return;
      }

      final channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _viewersChannel = channel;
      await channel.ready;
      if (!_isCurrentSocket(purpose, generation) ||
          _viewersChannel != channel) {
        await _closeSocketChannel(channel, '$purpose stale connect');
        return;
      }
      _connectingSockets.remove(purpose);

      _viewersSubscription = channel.stream.listen((message) {
        if (!_isCurrentSocket(purpose, generation) ||
            _viewersChannel != channel)
          return;
        if (message.toString().contains('ping')) {
          try {
            if (channel.closeCode == null) {
              channel.sink.add(json.encode({"event": "pusher:pong"}));
            }
          } catch (e) {
            liveLog('Error sending pong in viewers WS: $e');
          }
          return;
        }
        try {
          final decodedMessage = json.decode(message);
          if (decodedMessage["event"] == "App\\Events\\LiveSteamViewer") {
            // Decode the nested JSON string in the "data" field
            final dataString = decodedMessage["data"];
            final dataMap = json.decode(dataString); // Convert string to Map

            final viewerData = dataMap["data"];

            if (viewerData != null) {
              final action = viewerData["action"];
              final viewerInfo = viewerData["viewer_data"];

              _printFullLiveDebug(
                'OLD VIEWER CHANNEL RAW DATA | action: $action',
                viewerData,
              );

              if (action == "viewer_add") {
                _printFullLiveDebug('OLD VIEWER JOIN USER FULL DATA', {
                  'action': action,
                  'viewer_info_full_data': viewerInfo,
                  'raw_viewer_data': viewerData,
                });
                // Check if user already exists in the list
                bool userExists = livestreamController.liveViewerList.any(
                      (v) => v["id"] == viewerInfo["id"],
                );

                // Add user only if not already in the list
                if (streamID.value.toString() ==
                    viewerData['viewer_data']['livestream_id'].toString()) {
                  showEntryAnimationForViewer(
                    entryData: Map<String, dynamic>.from(viewerInfo),
                    userId:
                    viewerInfo['viewer_id'] ??
                        viewerInfo['user_id'] ??
                        viewerInfo['id'],
                  );
                  if (!userExists) {
                    livestreamController.addOrUpdateViewerLocal(
                      Map<String, dynamic>.from(viewerInfo),
                      force: true,
                    );
                  }
                }

                // Always show entry animation regardless of whether user was added or already exists
              } else if (action == "viewer_remove") {
                livestreamController.liveViewerList.removeWhere(
                      (v) => v["id"] == viewerInfo["id"],
                );
              }
            }
          }
        } catch (e) {
          liveLog("❌ Error parsing WebSocket message: $e");
        }
      });

      // Subscribe to the live stream viewer channel
      try {
        if (channel.closeCode == null) {
          channel.sink.add(
            json.encode({
              "event": "pusher:subscribe",
              "data": {"channel": "live-stream-viewer"},
            }),
          );
        }
      } catch (e) {
        liveLog('Error subscribing to live-stream-viewer: $e');
      }
    } catch (e) {
      liveLog('❌ Error connecting to viewers list WebSocket: $e');
    }
  }

  void tryToConnectToCommentsListWs() async {
    _connectingSockets.remove('viewers');
    const purpose = 'comments';
    if (_commentsChannel != null && _commentsChannel!.closeCode == null) return;
    if (_socketLifecycleClosed || !_connectingSockets.add(purpose)) return;
    final int generation = _nextSocketGeneration(purpose);
    await _cancelSocketSubscription(_commentsSubscription, purpose);
    _commentsSubscription = null;
    await _closeSocketChannel(_commentsChannel, purpose);
    _commentsChannel = null;
    try {
      if (kWsUrl.isEmpty) {
        liveLog('❌ WebSocket URL is empty, cannot connect to comments list');
        return;
      }

      final channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _commentsChannel = channel;
      await channel.ready;
      if (!_isCurrentSocket(purpose, generation) ||
          _commentsChannel != channel) {
        await _closeSocketChannel(channel, '$purpose stale connect');
        return;
      }
      _connectingSockets.remove(purpose);
      _commentsSubscription = channel.stream.listen((message) {
        if (!_isCurrentSocket(purpose, generation) ||
            _commentsChannel != channel)
          return;
        try {
          final decodedMessage = json.decode(message);
          if (decodedMessage['event'] == 'App\\Events\\LiveComment') {
            final data = json.decode(decodedMessage['data']);
            final commentData = {
              'livestream_id': data['data']['livestream_id'],
              'user': data['data']['user'],
              'comment': data['data']['comment'],
              'timestamp': data['data']['timestamp'],
            };

            _printFullLiveDebug('OLD COMMENT CHANNEL USER FULL DATA', {
              'livestream_id': commentData['livestream_id'],
              'comment_text': commentData['comment'],
              'user_full_data': commentData['user'],
              'comment_item': commentData,
              'raw_data': data,
            });

            // Add the comment to the observable list

            if (streamID.value.toString() ==
                commentData['livestream_id'].toString()) {
              commentsList.add(commentData);
              _refreshCommentsListSmooth();

              _printFullLiveDebug(
                'OLD COMMENT LIST AFTER NEW COMMENT | total: ${commentsList.length}',
                commentsList.toList(),
              );
            }

            liveLog('comment List ${commentsList}');
          }

          // Handle emoji sent event
          if (decodedMessage['event'] == 'App\\Events\\EmojiSent') {
            final data = json.decode(decodedMessage['data']);
            final emojiData = {
              'stream_id': data['stream_id'],
              'emoji': data['emoji'],
              'user': data['user'],
              'timestamp': data['timestamp'],
            };

            // Show emoji animation
            handleEmojiAnimation(emojiData);

            liveLog('Emoji received: ${emojiData}');
          }
        } catch (e) {
          liveLog('Error decoding message: $e');
        }

        // Handle ping messages
        if (message.toString().contains('ping')) {
          try {
            if (channel.closeCode == null) {
              channel.sink.add(json.encode({"event": "pusher:pong"}));
              liveLog('pong');
            }
          } catch (e) {
            liveLog('Error sending pong to comments channel: $e');
          }
        }
      });

      // Subscribe to the live-comment channel
      try {
        if (channel.closeCode == null) {
          channel.sink.add(
            json.encode({
              "event": "pusher:subscribe",
              "data": {"channel": "live-comment"},
            }),
          );
        }
      } catch (e) {
        liveLog('Error subscribing to live-comment channel: $e');
      }
    } catch (e) {
      liveLog('❌ Error connecting to comments list WebSocket: $e');
    }
  }

  void tryToConnectToCallListWs() async {
    _connectingSockets.remove('comments');
    const purpose = 'call-list';
    if (_callListChannel != null && _callListChannel!.closeCode == null) return;
    if (_socketLifecycleClosed || !_connectingSockets.add(purpose)) return;
    final int generation = _nextSocketGeneration(purpose);
    await _cancelSocketSubscription(_callListSubscription, purpose);
    _callListSubscription = null;
    await _closeSocketChannel(_callListChannel, purpose);
    _callListChannel = null;
    try {
      if (kWsUrl.isEmpty) {
        liveLog('❌ WebSocket URL is empty, cannot connect to call list');
        return;
      }

      final channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _callListChannel = channel;
      await channel.ready;
      if (!_isCurrentSocket(purpose, generation) ||
          _callListChannel != channel) {
        await _closeSocketChannel(channel, '$purpose stale connect');
        return;
      }
      _connectingSockets.remove(purpose);

      _callListSubscription = channel.stream.listen((message) async {
        if (!_isCurrentSocket(purpose, generation) ||
            _callListChannel != channel)
          return;
        try {
          final decodedMessage = json.decode(message);
          if (decodedMessage['event'] == 'App\\Events\\LiveSteamCall') {
            final data = json.decode(decodedMessage['data']);
            final callData = data['data'];

            if (streamID.value == callData['livestream_id']) {
              final int callerId = callData['caller_id'];
              final String callStatus = callData['call_status'];

              if (callStatus == 'accepted') {
                //pk call management
                if (callData['call_type'] == "pk") {
                  liveLog('I am from pk');
                  isPkRunning.value = true;
                  //for video audio call
                  pendingCall.removeWhere(
                        (call) => call['caller_id'] == callerId,
                  );
                  // ✅ Prevent duplicate addition
                  if (!liveCallList.any(
                        (call) => call['caller_id'] == callerId,
                  )) {
                    liveCallList.add(callData);
                  }
                  if (authController.userProfile.value.user!.id == callerId) {
                    if (callData['call_type'] == "pk") {
                      await _agoraService.engine!.enableVideo();
                    }
                    await _agoraService.engine!.enableAudio();
                  }

                  // ✅ Also update showingLiveStreamList
                  final streamIndex = homeController.showingLiveStreamList
                      .indexWhere((stream) => stream['id'] == streamID.value);

                  if (streamIndex != -1) {
                    final stream =
                    homeController.showingLiveStreamList[streamIndex];
                    if (stream['livestream_callers'] != null) {
                      final existingCallerIndex =
                      (stream['livestream_callers'] as List).indexWhere(
                            (caller) => caller['caller_id'] == callerId,
                      );

                      if (existingCallerIndex == -1) {
                        (stream['livestream_callers'] as List).add(callData);
                        homeController
                            .sortLiveStreamList(); // Auto sort after caller added
                        homeController.showingLiveStreamList.refresh();
                      }
                    }
                  }
                } else {
                  //for video audio call
                  pendingCall.removeWhere(
                        (call) => call['caller_id'] == callerId,
                  );
                  // ✅ Prevent duplicate addition
                  if (!liveCallList.any(
                        (call) => call['caller_id'] == callerId,
                  )) {
                    liveCallList.add(callData);
                  }
                  if (authController.userProfile.value.user!.id == callerId) {
                    if (callData['call_type'] == "video") {
                      await _agoraService.engine!.enableVideo();
                    }
                    await _agoraService.engine!.enableAudio();
                  }

                  // ✅ Also update showingLiveStreamList
                  final streamIndex = homeController.showingLiveStreamList
                      .indexWhere((stream) => stream['id'] == streamID.value);

                  if (streamIndex != -1) {
                    final stream =
                    homeController.showingLiveStreamList[streamIndex];
                    if (stream['livestream_callers'] != null) {
                      final existingCallerIndex =
                      (stream['livestream_callers'] as List).indexWhere(
                            (caller) => caller['caller_id'] == callerId,
                      );

                      if (existingCallerIndex == -1) {
                        (stream['livestream_callers'] as List).add(callData);
                        homeController
                            .sortLiveStreamList(); // Auto sort after caller added
                        homeController.showingLiveStreamList.refresh();
                      }
                    }
                  }
                }
              } else if (callStatus == 'pending') {
                /// Legacy LiveSteamCall channel can deliver delayed/stale
                /// pending frames after an audio-seat user leaves. Audio live
                /// never uses host Accept/Reject, so discard these completely.
                final bool legacyAudioRoom = _isCurrentAudioOnlyRoom(
                  livestreamId: callData['livestream_id'],
                ) ||
                    _truthy(callData['is_audio_seat_join']) ||
                    (_truthy(callData['auto_accepted']) &&
                        !_truthy(callData['requires_host_acceptance']));

                if (legacyAudioRoom) {
                  pendingCall.removeWhere((raw) {
                    return raw is Map &&
                        _callUserId(Map<String, dynamic>.from(raw)) == callerId;
                  });
                  pendingCall.refresh();
                  liveLog(
                    '🚫 LEGACY_AUDIO_PENDING_CALL_IGNORED => '
                        'stream:${callData['livestream_id']} caller:$callerId',
                  );
                } else if (callData['call_type'] == "pk") {
                  _upsertPendingCall(Map<String, dynamic>.from(callData));
                  if (authController.userProfile.value.user!.id == callerId) {
                    _showCallRequestPopup(callData, rtcEngine: null);
                  }
                } else {
                  // Pending popup is VIDEO/POPULAR flow only.
                  _upsertPendingCall(Map<String, dynamic>.from(callData));
                  if (livestreamController.isBroadcaster.value) {
                    _showCallRequestPopup(callData, rtcEngine: null);
                  }
                }
              } else if (callStatus == 'canceled' || callStatus == 'rejected') {
                // Stop audio/video for the removed caller

                pendingCall.removeWhere(
                      (call) => call['caller_id'] == callerId,
                );
                liveCallList.removeWhere(
                      (call) => call['caller_id'] == callerId,
                );

                if (isPkRunning.value && callData['call_type'] == "pk") {
                  isPkRunning.value = false;
                }
                if (authController.userProfile.value.user!.id == callerId) {
                  await _agoraService.engine!.setClientRole(
                    role: ClientRoleType.clientRoleAudience,
                  );
                  await _agoraService.engine!.muteLocalAudioStream(true);
                  await _agoraService.engine!.muteLocalVideoStream(true);
                }

                // Also remove from showingLiveStreamList's livestream_callers
                final streamIndex = homeController.showingLiveStreamList
                    .indexWhere((stream) => stream['id'] == streamID.value);
                if (streamIndex != -1) {
                  final stream =
                  homeController.showingLiveStreamList[streamIndex];
                  if (stream['livestream_callers'] != null) {
                    (stream['livestream_callers'] as List).removeWhere(
                          (caller) => caller['caller_id'] == callerId,
                    );
                    homeController
                        .sortLiveStreamList(); // Auto sort after caller removed
                    homeController.showingLiveStreamList.refresh();
                    liveLog(
                      '🗑️ Removed caller $callerId from showingLiveStreamList',
                    );
                  }
                }
              }

              _refreshLiveCallListSmooth(); // Ensure UI updates
              pendingCall.refresh(); // Ensure UI updates
            }
          }
        } catch (e) {
          liveLog('Error decoding message: $e');
        }

        // Handle ping messages
        if (message.toString().contains('ping')) {
          try {
            channel.sink.add(json.encode({"event": "pusher:pong"}));
            liveLog('pong');
          } catch (e) {
            liveLog('Error sending pong to call list channel: $e');
          }
        }
      });

      // Subscribe to the live-stream-call channel
      try {
        channel.sink.add(
          json.encode({
            "event": "pusher:subscribe",
            "data": {"channel": "live-stream-call"},
          }),
        );
      } catch (e) {
        liveLog('Error subscribing to live-stream-call channel: $e');
      }
    } catch (e) {
      liveLog('❌ Error connecting to call list WebSocket: $e');
    }
  }

  /// Show call request popup for broadcasters
  void _showCallRequestPopup(
      Map<String, dynamic> callData, {
        required RtcEngine? rtcEngine,
        String? popupKey,
      }) {
    /// Old channel/new unified channel duita thekei popup ashte pare.
    /// Tai popup show-er age user data safe normalize.
    _normalizeUnifiedCallUser(callData, callData);

    if (Get.context == null) {
      if (popupKey != null) _activeCallPopupKeys.remove(popupKey);
      liveLog('⚠️ No context available for showing call request sheet');
      return;
    }

    try {
      final LivestreamController liveController =
      Get.find<LivestreamController>();

      final callerUser = callData['user'] is Map
          ? Map<String, dynamic>.from(callData['user'])
          : <String, dynamic>{};
      final callerName =
      (callerUser['name'] ??
          callData['name'] ??
          callData['caller_name'] ??
          callData['username'] ??
          'User')
          .toString();
      final callerId =
          callData['caller_id'] ?? callData['user_id'] ?? callerUser['id'];
      final streamId =
          callData['livestream_id'] ?? callData['stream_id'] ?? streamID.value;

      if (!_normalizeCallTypeForCurrentRoom(
        callData,
        callData,
        livestreamId: streamId,
      )) {
        return;
      }

      final int callerIdInt = _toInt(callerId);
      final int streamIdInt = _toInt(streamId);

      /// AUDIO LIVE HAS NO HOST ACCEPT/REJECT CALL REQUEST UI.
      /// This is the final defense layer: even if a stale legacy/unified frame
      /// accidentally reaches this method after room leave, it can never open
      /// the Incoming Call Request bottom sheet in an audio room.
      final bool audioPopupForbidden =
          _isCurrentAudioOnlyRoom(livestreamId: streamIdInt) ||
              _truthy(callData['is_audio_seat_join']) ||
              (_truthy(callData['auto_accepted']) &&
                  !_truthy(callData['requires_host_acceptance']));

      if (audioPopupForbidden) {
        if (popupKey != null) _activeCallPopupKeys.remove(popupKey);
        pendingCall.removeWhere((raw) {
          return raw is Map &&
              _callUserId(Map<String, dynamic>.from(raw)) == callerIdInt;
        });
        pendingCall.refresh();
        liveLog(
          '🚫 AUDIO_CALL_REQUEST_POPUP_HARD_BLOCKED => '
              'stream:$streamIdInt caller:$callerIdInt',
        );
        return;
      }

      final effectivePopupKey =
          popupKey ??
              _callPopupKey(
                streamId: streamIdInt,
                callerId: callerIdInt,
                callType: callData['call_type'] ?? 'audio',
              );
      if (callerIdInt <= 0 ||
          streamIdInt <= 0 ||
          _activeCallPopupKeys.contains(effectivePopupKey) ||
          _handledCallPopupKeys.contains(effectivePopupKey)) {
        return;
      }
      _activeCallPopupKeys.add(effectivePopupKey);

      Get.bottomSheet<void>(
        Obx(() {
          final current = pendingCall.firstWhereOrNull((raw) {
            return raw is Map &&
                _callUserId(Map<String, dynamic>.from(raw)) == callerIdInt;
          });
          return CallRequestPopup(
            key: ValueKey<String>('call-request-$effectivePopupKey'),
            callData: current is Map
                ? Map<String, dynamic>.from(current)
                : callData,
            onAccept: () async {
              final accepted = await liveController.tryToAcceptCall(
                streamId: streamIdInt,
                userId: callerIdInt,
              );
              if (!accepted) {
                Fluttertoast.showToast(
                  msg: ('Call could not be accepted').appTr,
                );
                return;
              }
              _activeCallPopupKeys.remove(effectivePopupKey);
              _handledCallPopupKeys.add(effectivePopupKey);
              if (Get.isBottomSheetOpen == true) Get.back<void>();

              /// Accept korar sathe sathe call list refresh. Event late ashleo
              /// broadcaster side-e video/audio card show hobe.
              try {
                _refreshLiveCallListSmooth();
                pendingCall.refresh();
                refreshCpSeatConnectionsFromCurrentCallList(
                  source: 'live_call_after_accept',
                );
                syncLivestreamCallers();
              } catch (e) {
                liveLog('❌ Refresh after accept failed: $e');
              }

              Fluttertoast.showToast(
                msg: ('$callerName has been added to the live stream').appTr,
                backgroundColor: Colors.green,
                textColor: Colors.white,
              );
            },
            onReject: () async {
              final rejected = await liveController.tryToRejectCall(
                streamId: streamIdInt,
                userId: callerIdInt,
              );
              if (!rejected) {
                Fluttertoast.showToast(
                  msg: ('Call could not be rejected').appTr,
                );
                return;
              }
              _activeCallPopupKeys.remove(effectivePopupKey);
              _handledCallPopupKeys.add(effectivePopupKey);
              if (Get.isBottomSheetOpen == true) Get.back<void>();

              Fluttertoast.showToast(
                msg: ('$callerName was not added to the live stream').appTr,
                backgroundColor: Colors.red,
                textColor: Colors.white,
              );
            },
          );
        }),
        isScrollControlled: true,
        backgroundColor: Colors.white,
        barrierColor: Colors.black54,
        isDismissible: false,
        enableDrag: false,
      ).whenComplete(() => _activeCallPopupKeys.remove(effectivePopupKey));

      liveLog('✅ Call request popup shown for caller: $callerId');
    } catch (e) {
      if (popupKey != null) _activeCallPopupKeys.remove(popupKey);
      liveLog('❌ Error showing call request popup: $e');
      liveLog('📝 Call request added to pending list without popup');
    }
  }

  //action handled here
  // Monitor livestream moderation events (kick out,audio toggle, Video Toggle etc.)
  void tryToConnectToModerationWs() async {
    _connectingSockets.remove('call-list');
    const purpose = 'moderation';
    if (_moderationChannel != null && _moderationChannel!.closeCode == null)
      return;
    if (_socketLifecycleClosed || !_connectingSockets.add(purpose)) return;
    final int generation = _nextSocketGeneration(purpose);
    await _cancelSocketSubscription(_moderationSubscription, purpose);
    _moderationSubscription = null;
    await _closeSocketChannel(_moderationChannel, purpose);
    _moderationChannel = null;
    try {
      if (kWsUrl.isEmpty) {
        liveLog('❌ WebSocket URL is empty, cannot connect to moderation');
        return;
      }

      final channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _moderationChannel = channel;
      await channel.ready;
      if (!_isCurrentSocket(purpose, generation) ||
          _moderationChannel != channel) {
        await _closeSocketChannel(channel, '$purpose stale connect');
        return;
      }
      _connectingSockets.remove(purpose);

      _moderationSubscription = channel.stream.listen((message) {
        if (!_isCurrentSocket(purpose, generation) ||
            _moderationChannel != channel)
          return;
        try {
          final decodedMessage = json.decode(message);

          // Handle kick out event
          if (decodedMessage['event'] == 'App\\Events\\LiveSteamModeration') {
            liveLog('🔔 LiveSteamModeration event received');
            final data = json.decode(decodedMessage['data']);
            final moderationData = data['data'] ?? data;

            liveLog('🔔 Moderation action: ${moderationData['action']}');
            liveLog('🔔 Full moderation data: $moderationData');

            switch (moderationData['action']) {
              case 'kickout':
                liveLog('🚫 Processing kickout action...');
                _handleKickOut(moderationData);
                break;

              case 'audio_toggle':
                _handleAudioToggle(moderationData);
                break;
              case 'video_toggle':
                _handleVideoToggle(moderationData);
                break;

              case 'live_stream_ended':
                liveLog(
                  '🛑 Live stream ended for ID: ${moderationData['livestream_id']}',
                );

                homeController.showingLiveStreamList.removeWhere(
                      (stream) => stream['id'] == moderationData['livestream_id'],
                );

                homeController
                    .sortLiveStreamList(); // Auto sort after stream removed
                homeController.showingLiveStreamList
                    .refresh(); // ✅ force UI update
                _handleLiveStreamEnded(moderationData);
                break;

              default:
                liveLog(
                  'Unknown moderation action: ${moderationData['action']}',
                );
                break;
            }
          }
        } catch (e) {
          liveLog('Error decoding moderation message: $e');
        }

        // Handle ping messages
        if (message.toString().contains('ping')) {
          channel.sink.add(json.encode({"event": "pusher:pong"}));
          liveLog('pong');
        }
      });

      // Subscribe to moderation channel
      channel.sink.add(
        json.encode({
          "event": "pusher:subscribe",
          "data": {"channel": "live-stream-moderation"},
        }),
      );
    } catch (e) {
      liveLog('❌ Error in moderation WebSocket: $e');
    }
  }

  //end action handled here

  // Method to fetch initial gift total from backend
  Future<void> fetchInitialGiftTotal({dynamic streamId}) async {
    try {
      final int sid =
          int.tryParse((streamId ?? streamID.value).toString()) ?? 0;

      if (sid <= 0) {
        liveLog('Skipping gift total fetch - invalid stream ID: $sid');
        return;
      }

      final response = await dio.get(kGetTotalGiftCoins(sid));
      if (response.statusCode == 200) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        final dynamic coinRaw =
            data['total_gift_coins'] ??
                data['total_coins'] ??
                data['gifts_coins'] ??
                data['gift_amount'] ??
                data['stream_coins'];

        final int coins = _toInt(coinRaw);

        /// Do not let a partial/empty response reset a live that already has coins.
        if (coins > 0 || totalGiftCoins.value <= 0) {
          totalGiftCoins.value = coins;
        }

        // Load user gift counts if available
        if (data['user_gift_counts'] != null) {
          userGiftCounts.value = Map<String, Map<String, dynamic>>.from(
            data['user_gift_counts'].map(
                  (key, value) =>
                  MapEntry(key.toString(), Map<String, dynamic>.from(value)),
            ),
          );
        }

        liveLog('Initial gift total loaded: ${totalGiftCoins.value}');
        liveLog('Initial user gift counts loaded: $userGiftCounts');
      }
    } catch (e) {
      if (e.toString().contains('404')) {
        liveLog('Livestream not found for ID: ${streamId ?? streamID.value}');
      } else {
        liveLog('Error fetching initial gift total: $e');
      }
    }
  }

  bool _looksLikeViewerOnlyPayloadForCoin(
      Map<String, dynamic> payload,
      Map<String, dynamic> data,
      ) {
    /// viewer/user join payload may contain user.balance/coins/gifts_coins = 0.
    /// That is NOT the live received gift total, so never sync live total from it.
    final action = (payload['action_type'] ?? payload['action'] ?? '')
        .toString()
        .toLowerCase();

    if (action.contains('viewer') ||
        action.contains('join_live') ||
        action.contains('user_joined')) {
      return true;
    }

    if ((payload.containsKey('viewer') || payload.containsKey('viewer_data')) &&
        !payload.containsKey('livestream') &&
        !payload.containsKey('live_stream')) {
      return true;
    }

    if ((data.containsKey('viewer_id') || data.containsKey('is_active')) &&
        !data.containsKey('total_gift_coins') &&
        !data.containsKey('gift_amount') &&
        !data.containsKey('stream_coins')) {
      return true;
    }

    return false;
  }

  void syncGiftCoinsFromPayload(
      Map<String, dynamic> payload, {
        String source = 'payload',
      }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : payload['live_stream'] is Map
          ? Map<String, dynamic>.from(payload['live_stream'])
          : Map<String, dynamic>.from(payload);

      if (_looksLikeViewerOnlyPayloadForCoin(payload, data)) {
        liveLog('🪙 Gift coin sync skipped viewer-only payload from $source');
        return;
      }

      final bool hasLiveCoinKey =
          data.containsKey('total_gift_coins') ||
              data.containsKey('total_coins') ||
              data.containsKey('gift_amount') ||
              data.containsKey('stream_coins') ||
              data.containsKey('received_coins');

      /// Do NOT treat data['gifts_coins'] alone as live total when it comes
      /// from viewer/user object. User.gifts_coins is often 0 for late viewers.
      final bool hasOnlyUserGiftCoins =
          data.containsKey('gifts_coins') &&
              !hasLiveCoinKey &&
              (data.containsKey('id') ||
                  data.containsKey('user_id') ||
                  data.containsKey('profile_image'));

      if (!hasLiveCoinKey && hasOnlyUserGiftCoins) {
        liveLog('🪙 Gift coin sync skipped user.gifts_coins from $source');
        return;
      }

      final dynamic coinRaw =
          data['total_gift_coins'] ??
              data['total_coins'] ??
              data['gift_amount'] ??
              data['stream_coins'] ??
              data['received_coins'] ??
              data['gifts_coins'];

      if (coinRaw == null) return;

      final int coins = _toInt(coinRaw);
      final int payloadStreamId = _toInt(
        payload['livestream_id'] ??
            payload['stream_id'] ??
            data['livestream_id'] ??
            data['stream_id'] ??
            data['id'],
      );
      final int currentStreamId = _toInt(streamID.value);

      /// IMPORTANT FIX:
      /// Global live_stream_created/list events from another room must never reset
      /// the current room gift total. Example: current=6810, event=6931.
      if (currentStreamId > 0 &&
          payloadStreamId > 0 &&
          payloadStreamId != currentStreamId) {
        liveLog(
          '⛔ Gift coins ignored from other stream '
              '=> event=$payloadStreamId current=$currentStreamId source=$source keep=${totalGiftCoins.value}',
        );
        return;
      }

      /// Partial/late response must not reset old total to 0.
      if (coins == 0 && totalGiftCoins.value > 0) {
        liveLog(
          '🪙 Gift coins zero reset ignored from $source, keep=${totalGiftCoins.value}',
        );
        return;
      }

      if (coins > 0 || totalGiftCoins.value <= 0) {
        totalGiftCoins.value = coins;
      }
    } catch (e) {
      liveLog('⚠️ syncGiftCoinsFromPayload error => $e');
    }
  }

  final isGiftAnimationShowing = false.obs;

  final giftsData = {}.obs; // Observable to store received gifts

  // Gift tracking variables
  final totalGiftCoins = 0.obs; // Total coins from all gifts
  final userGiftCounts =
      <String, Map<String, dynamic>>{}.obs; // Individual user gift counts

  /// ✅ Realtime per-user received gift coins for seat UI.
  ///
  /// IMPORTANT:
  /// The key is room-scoped: "livestreamId:userId".
  /// Using only userId allowed coins from room A to appear when the same user
  /// entered room B. Seat UI must show only coins received inside the currently
  /// open broadcast, never the user's lifetime earned_coins/gifts_coins.
  final RxMap<String, int> liveUserGiftCoins = <String, int>{}.obs;

  int _giftCoinRoomId({int? livestreamId}) {
    final int requested = _toInt(livestreamId);
    if (requested > 0) return requested;

    final int websocketStream = _toInt(streamID.value);
    if (websocketStream > 0) return websocketStream;

    final int activeStream = _toInt(activeAudioStreamId.value);
    if (activeStream > 0) return activeStream;

    try {
      final int controllerStream = _toInt(livestreamController.streamId.value);
      if (controllerStream > 0) return controllerStream;
    } catch (_) {}

    return 0;
  }

  String _liveUserGiftCoinKey({
    required int userId,
    int? livestreamId,
  }) {
    final int roomId = _giftCoinRoomId(livestreamId: livestreamId);
    return '$roomId:$userId';
  }

  int _rowLivestreamId(Map<String, dynamic> row) {
    final Map<String, dynamic> livestream = row['livestream'] is Map
        ? Map<String, dynamic>.from(row['livestream'])
        : <String, dynamic>{};
    final Map<String, dynamic> livestreamData = row['livestreamdata'] is Map
        ? Map<String, dynamic>.from(row['livestreamdata'])
        : <String, dynamic>{};

    return _toInt(
      row['livestream_id'] ??
          row['stream_id'] ??
          row['live_stream_id'] ??
          row['live_id'] ??
          livestream['livestream_id'] ??
          livestream['stream_id'] ??
          livestream['id'] ??
          livestreamData['livestream_id'] ??
          livestreamData['stream_id'] ??
          livestreamData['id'],
    );
  }

  bool _rowBelongsToGiftRoom(
      Map<String, dynamic> row,
      int roomId,
      ) {
    if (roomId <= 0) return true;
    final int rowRoomId = _rowLivestreamId(row);

    // Call-list rows from the current room can omit livestream_id. They are safe
    // because the whole call list is cleared whenever the room changes.
    return rowRoomId <= 0 || rowRoomId == roomId;
  }

  int? _explicitCurrentLiveGiftCoins(Map<String, dynamic> row) {
    final Map<String, dynamic> user = row['user'] is Map
        ? Map<String, dynamic>.from(row['user'])
        : <String, dynamic>{};
    final Map<String, dynamic> caller = row['caller'] is Map
        ? Map<String, dynamic>.from(row['caller'])
        : <String, dynamic>{};

    final List<dynamic> values = <dynamic>[
      row['current_gift_coins'],
      row['current_live_gift_coins'],
      row['live_gift_coins'],
      row['stream_gift_coins'],
      row['livestream_gift_coins'],
      row['room_gift_coins'],
      user['current_gift_coins'],
      user['current_live_gift_coins'],
      user['live_gift_coins'],
      user['stream_gift_coins'],
      user['livestream_gift_coins'],
      user['room_gift_coins'],
      caller['current_gift_coins'],
      caller['current_live_gift_coins'],
      caller['live_gift_coins'],
      caller['stream_gift_coins'],
      caller['livestream_gift_coins'],
      caller['room_gift_coins'],
    ];

    for (final dynamic value in values) {
      if (value == null) continue;
      return _toInt(value);
    }

    return null;
  }

  /// Public room-scoped reader used by every seat, including the owner seat.
  /// Generic account fields (earned_coins, earn_coins, gifts_coins,
  /// received_coins) are intentionally ignored because they may be lifetime
  /// wallet totals and were the reason a wrong value appeared in another room.
  int currentLiveGiftCoinsForUser({
    required int userId,
    int? livestreamId,
  }) {
    if (userId <= 0) return 0;

    final int roomId = _giftCoinRoomId(livestreamId: livestreamId);
    final String key = _liveUserGiftCoinKey(
      userId: userId,
      livestreamId: roomId,
    );

    if (liveUserGiftCoins.containsKey(key)) {
      return _toInt(liveUserGiftCoins[key]);
    }

    for (final dynamic raw in liveCallList) {
      if (raw is! Map) continue;
      final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
      if (!_rowBelongsToGiftRoom(call, roomId)) continue;

      final Map<String, dynamic> user = call['user'] is Map
          ? Map<String, dynamic>.from(call['user'])
          : <String, dynamic>{};
      final Map<String, dynamic> caller = call['caller'] is Map
          ? Map<String, dynamic>.from(call['caller'])
          : <String, dynamic>{};
      final int callUserId = _toInt(
        call['caller_id'] ??
            call['user_id'] ??
            call['viewer_id'] ??
            user['id'] ??
            user['user_id'] ??
            caller['id'] ??
            caller['user_id'],
      );
      if (callUserId != userId) continue;

      return _explicitCurrentLiveGiftCoins(call) ?? 0;
    }

    return 0;
  }

  int _currentGiftCoinsForUser(int userId) {
    return currentLiveGiftCoinsForUser(userId: userId);
  }

  Map<int, int> giftCoinSnapshotForUsers(Iterable<int> userIds) {
    final Map<int, int> snapshot = <int, int>{};
    for (final int rawId in userIds) {
      final int id = _toInt(rawId);
      if (id <= 0 || snapshot.containsKey(id)) continue;
      snapshot[id] = _currentGiftCoinsForUser(id);
    }
    return snapshot;
  }

  /// Sender-side API reconciliation for one physical tap.
  ///
  /// The old containsKey fallback stopped working after the first gift because
  /// the receiver key remained in liveUserGiftCoins forever. This method uses
  /// the value captured before that tap and guarantees at least +giftPrice,
  /// while still avoiding a double increment when WebSocket already applied it.
  void ensureSenderGiftCoinsAtLeast({
    required List<int> receiverIds,
    required Map<int, int> baselineCoins,
    required int coinValue,
  }) {
    if (coinValue <= 0 || receiverIds.isEmpty) return;

    final Map<int, int> missingDelta = <int, int>{};
    for (final int rawId in receiverIds) {
      final int id = _toInt(rawId);
      if (id <= 0) continue;

      final int expected = (baselineCoins[id] ?? 0) + coinValue;
      final int current = _currentGiftCoinsForUser(id);
      if (current < expected) {
        missingDelta[id] = expected - current;
      }
    }

    if (missingDelta.isEmpty) return;
    _applyReceiverGiftCoinDeltas(missingDelta);
  }

  /// Entry animation duplicate/safety guard.
  /// viewer_joined + live_comment + rebuild একসাথে আসলে একই user এর entry বারবার
  /// restart/print হবে না। SVGA onFinished না এলেও fallback hide হবে।
  Timer? _entryAnimationSafetyTimer;
  final Map<int, int> _recentEntryShownUntilMs = <int, int>{};

  // Broadcaster status monitoring
  final isBroadcasterOnline = true.obs;
  final isStreamEnded = false.obs;
  final streamEndReason = ''.obs;
  // show animation when user joined the stream

  /// Entry animation show korbe only.
  /// Hide/clear hobe EntryAnimation widget er SVGA onFinished callback theke.
  /// Tai ekhane kono fixed 3 seconds timer rakha jabe na.
  void showEntryAnimation() {
    newViewersJoinded.value = true;
  }

  /// Entry/SVGA full play sesh hole widget theke eta call korben.
  void hideEntryAnimation({bool clearData = true}) {
    _entryAnimationSafetyTimer?.cancel();
    _entryAnimationSafetyTimer = null;
    newViewersJoinded.value = false;
    if (clearData) {
      newJoinedUserData.value = {};
    }
    newViewerAction.value = 'join';
  }

  int _entryUserIdFromData(dynamic data) {
    try {
      final root = data is Map<String, dynamic>
          ? data
          : data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};

      final user = root['user'] is Map<String, dynamic>
          ? root['user']
          : root['user'] is Map
          ? Map<String, dynamic>.from(root['user'])
          : <String, dynamic>{};

      final viewerData = root['viewer_data'] is Map<String, dynamic>
          ? root['viewer_data']
          : root['viewer_data'] is Map
          ? Map<String, dynamic>.from(root['viewer_data'])
          : <String, dynamic>{};

      final viewerUser = viewerData['user'] is Map<String, dynamic>
          ? viewerData['user']
          : viewerData['user'] is Map
          ? Map<String, dynamic>.from(viewerData['user'])
          : <String, dynamic>{};

      return _toInt(
        user['id'] ??
            viewerUser['id'] ??
            root['viewer_id'] ??
            root['user_id'] ??
            root['id'],
      );
    } catch (_) {
      return 0;
    }
  }

  bool _isSameEntryAlreadyShowing(dynamic userId) {
    final incomingUserId = _toInt(userId);
    if (incomingUserId <= 0) return false;
    if (newViewersJoinded.value != true) return false;
    return _entryUserIdFromData(newJoinedUserData.value) == incomingUserId;
  }

  Map<String, dynamic> _safeAuthUserForSystemComment(dynamic fallbackUserId) {
    final int uid = _toInt(fallbackUserId);
    final dynamic profileUser = authController.userProfile.value.user;

    dynamic safeRead(dynamic Function() getter) {
      try {
        return getter();
      } catch (_) {
        return null;
      }
    }

    String safeText(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty || text.toLowerCase() == 'null') return '';
      return text;
    }

    final dynamic profileId = safeRead(() => profileUser?.id);
    final String name = safeText(safeRead(() => profileUser?.name));
    final String username = safeText(safeRead(() => profileUser?.username));
    final dynamic profileImage =
        safeRead(() => profileUser?.profileImage) ??
            safeRead(() => profileUser?.image);

    return {
      'id': uid > 0 ? uid : profileId,
      'user_id': uid > 0 ? uid : profileId,
      'name': name.isNotEmpty ? name : (username.isNotEmpty ? username : 'You'),
      'username': username,
      'level': safeRead(() => profileUser?.level) ?? 0,
      'profile_image': profileImage,
      'image': safeRead(() => profileUser?.image) ?? profileImage,
      'frame': safeRead(() => profileUser?.frame),
      'gender': safeRead(() => profileUser?.gender),
      'is_online': true,
    };
  }

  void _addSelfJoinCommentFromEntry({
    required Map<String, dynamic> entryData,
    required dynamic userId,
  }) {
    try {
      final int incomingUserId = _toInt(userId);
      final int currentUserId = _toInt(
        authController.userProfile.value.user?.id,
      );
      if (incomingUserId <= 0 ||
          currentUserId <= 0 ||
          incomingUserId != currentUserId)
        return;

      int sid = _toInt(
        entryData['livestream_id'] ??
            entryData['stream_id'] ??
            entryData['live_stream_id'],
      );
      if (sid <= 0) sid = _toInt(streamID.value);
      if (sid <= 0) sid = _toInt(activeAudioStreamId.value);
      if (sid <= 0) sid = _toInt(liveRoomUpdateStreamId.value);
      if (sid <= 0 || !_isCurrentStream(sid)) return;

      Map<String, dynamic> userMap = entryData['user'] is Map
          ? Map<String, dynamic>.from(entryData['user'])
          : <String, dynamic>{};

      final fallback = _safeAuthUserForSystemComment(incomingUserId);
      userMap = {
        ...fallback,
        ...userMap,
        'id': userMap['id'] ?? fallback['id'],
        'user_id': userMap['user_id'] ?? userMap['id'] ?? fallback['user_id'],
        'name': (userMap['name']?.toString().trim().isNotEmpty ?? false)
            ? userMap['name']
            : fallback['name'],
      };

      _addSystemViewerComment(
        livestreamId: sid,
        user: userMap,
        comment: 'has joined the stream',
        systemType: 'viewer_join',
      );
      liveLog(
        '✅ Self join timeline item added => stream:$sid user:$incomingUserId',
      );
    } catch (e) {
      liveLog('⚠️ Self join timeline add skipped => $e');
    }
  }

  void showEntryAnimationForViewer({
    required Map<String, dynamic> entryData,
    required dynamic userId,
  }) {
    final incomingUserId = _toInt(userId);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    /// ✅ Backend onek somoy nijer device-e viewer_joined echo kore na,
    /// abar duplicate cooldown er jonno animation skip holeo self timeline miss hoto.
    /// Tai duplicate guard-er age self join comment add korte hobe.
    _addSelfJoinCommentFromEntry(entryData: entryData, userId: incomingUserId);

    // Same viewer er viewer_joined + live_comment duplicate ashle running
    // SVGA restart/replace korbe na. Tai full animation cut hobe na.
    if (_isSameEntryAlreadyShowing(incomingUserId)) {
      liveLog(
        'ℹ️ Duplicate entry ignored while running => user:$incomingUserId',
      );
      return;
    }

    final int blockedUntil = _recentEntryShownUntilMs[incomingUserId] ?? 0;
    if (incomingUserId > 0 && blockedUntil > nowMs) {
      liveLog('ℹ️ Duplicate entry ignored by cooldown => user:$incomingUserId');
      return;
    }

    if (incomingUserId > 0) {
      _recentEntryShownUntilMs[incomingUserId] = nowMs + 8000;
    }

    newJoinedUserData.value = entryData;
    newViewerAction.value = 'join';
    showEntryAnimation();

    _entryAnimationSafetyTimer?.cancel();
    _entryAnimationSafetyTimer = Timer(const Duration(seconds: 8), () {
      try {
        if (_entryUserIdFromData(newJoinedUserData.value) == incomingUserId) {
          hideEntryAnimation();
        }
      } catch (_) {
        hideEntryAnimation();
      }
    });
  }

  void showGiftsAnimation() {
    _giftAnimationHideTimer?.cancel();
    if (giftsData.isNotEmpty) {
      isGiftAnimationShowing.value = true;
    } else {
      _showNextQueuedGiftAnimation();
    }
  }

  bool _isLuckyAnimationMap(Map<String, dynamic> data) {
    final Map<String, dynamic> gift = data['gift'] is Map
        ? Map<String, dynamic>.from(data['gift'])
        : <String, dynamic>{};
    final String category =
    (data['gift_category'] ??
        data['gift_type'] ??
        data['type'] ??
        gift['category'] ??
        gift['gift_category'] ??
        gift['gift_type'] ??
        gift['type'] ??
        gift['name'] ??
        '')
        .toString()
        .toLowerCase();
    return data['is_lucky_gift'] == true ||
        data['is_lucky_gift'].toString() == '1' ||
        gift['is_lucky_gift'] == true ||
        gift['is_lucky_gift'].toString() == '1' ||
        category.contains('lucky');
  }

  void _mountLuckyQueueItemWithoutClosingCard(Map<String, dynamic> next) {
    _luckyCardHideTimer?.cancel();
    _luckyCurrentFlightComplete = false;
    giftsData.value = Map<String, dynamic>.from(next);
    giftsData.refresh();
    isGiftAnimationShowing.value = true;
    isGiftAnimationShowing.refresh();
  }

  /// Normal gifts close after each animation.
  /// Lucky gifts keep one horizontal card mounted for 7 seconds. Every fast
  /// Combo tap only changes the values inside that same card and starts the next
  /// queued flight, so the card never flashes or recreates.
  void hideGiftAnimation({bool clearData = true}) {
    _giftAnimationHideTimer?.cancel();

    final Map<String, dynamic> current = giftsData.isNotEmpty
        ? Map<String, dynamic>.from(giftsData)
        : <String, dynamic>{};

    if (_isLuckyAnimationMap(current)) {
      _luckyCurrentFlightComplete = true;

      if (_giftAnimationQueue.isNotEmpty) {
        final Map<String, dynamic> next = Map<String, dynamic>.from(
          _giftAnimationQueue.removeFirst(),
        );
        // Mount synchronously. A microtask gap allowed a new rapid tap to
        // overtake this queued item and could overwrite/reorder animations.
        _mountLuckyQueueItemWithoutClosingCard(next);
        return;
      }

      _luckyCardHideTimer?.cancel();
      _luckyCardHideTimer = Timer(const Duration(seconds: 7), () {
        if (_giftAnimationQueue.isNotEmpty) {
          final Map<String, dynamic> next = Map<String, dynamic>.from(
            _giftAnimationQueue.removeFirst(),
          );
          _mountLuckyQueueItemWithoutClosingCard(next);
          return;
        }

        _luckyCurrentFlightComplete = false;
        isGiftAnimationShowing.value = false;
        giftsData.value = <String, dynamic>{};
      });
      return;
    }

    isGiftAnimationShowing.value = false;
    if (clearData) {
      giftsData.value = <String, dynamic>{};
    }

    if (_giftAnimationQueue.isNotEmpty) {
      Future.microtask(_showNextQueuedGiftAnimation);
    }
  }

  // Show gift animation
  void showGiftAnimation(Map<String, dynamic> giftData) {
    try {
      _handleUnifiedGift({...giftData, 'force_show': true});
    } catch (e) {
      liveLog("❌ Error showing gift animation: $e");
    }
  }

  // Red Packet Methods
  void hideRedPacket() {
    redPacketVisible.value = false;
    currentRedPacket.value = {};
    _cancelRedPacketTimer();
  }

  // Global Red Packet Methods
  void hideGlobalRedPacket() {
    globalRedPacketVisible.value = false;
    globalCurrentRedPacket.value = {};
    _cancelGlobalRedPacketTimer();
  }

  void _startRedPacketTimer(String redPacketId, int durationMinutes) {
    // Cancel any existing timer
    _cancelRedPacketTimer();

    // Start timer for auto-refund using dynamic duration
    redPacketTimer = Timer(Duration(minutes: durationMinutes), () {
      _autoRefundRedPacket(redPacketId);
    });
  }

  void _cancelRedPacketTimer() {
    redPacketTimer?.cancel();
    redPacketTimer = null;
  }

  void _startGlobalRedPacketTimer(String redPacketId, int durationMinutes) {
    // Cancel any existing global timer
    _cancelGlobalRedPacketTimer();

    // Start timer for auto-hide using dynamic duration
    globalRedPacketTimer = Timer(Duration(minutes: durationMinutes), () {
      hideGlobalRedPacket();
      liveLog(
        '🧧 Global Red Packet auto-hidden after $durationMinutes minutes',
      );
    });
  }

  void _cancelGlobalRedPacketTimer() {
    globalRedPacketTimer?.cancel();
    globalRedPacketTimer = null;
  }

  Future<void> _autoRefundRedPacket(String redPacketId) async {
    try {
      final dio = Dio();
      LiveTestingLogger.installDio(
        dio,
        owner: 'WebsocketController.redPacketRefund',
      );
      final authController = Get.find<AuthController>();

      final response = await dio.post(
        '$kDomainUrl/api/red-packets/refund/$redPacketId',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer ${authController.userProfile.value.token}",
          },
        ),
      );

      if (response.statusCode == 200) {
        liveLog("✅ Red packet auto-refunded successfully");
        hideRedPacket();

        // Show refund notification
        Get.snackbar(
          ("🧧 Red Packet Expired").appTr,
          ("Red packet has been refunded to sender").appTr,
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      liveLog("❌ Error auto-refunding red packet: $e");
    }
  }

  void setRedPacketCallbacks({
    Function(Map<String, dynamic>)? onReceived,
    Function(Map<String, dynamic>)? onCollected,
  }) {
    onRedPacketReceived = onReceived;
    onRedPacketCollected = onCollected;
  }

  // Global Red Packet Collection Method
  Future<bool> collectGlobalRedPacket() async {
    try {
      if (globalCurrentRedPacket.value.isEmpty) {
        liveLog("❌ No global red packet available to collect");
        return false;
      }

      final redPacketId = globalCurrentRedPacket.value['id'].toString();
      final dio = Dio();
      LiveTestingLogger.installDio(
        dio,
        owner: 'WebsocketController.redPacketCollect',
      );
      final authController = Get.find<AuthController>();

      final response = await dio.post(
        '$kDomainUrl/api/red-packets/collect/$redPacketId',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        hideGlobalRedPacket();

        // Show success message
        Get.snackbar(
          ("🧧 Red Packet Collected!").appTr,
          ("You have successfully collected the red packet").appTr,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );

        return true;
      } else {
        liveLog(
          "⚠️ Failed to collect global red packet: ${response.statusCode}",
        );
        return false;
      }
    } catch (e) {
      liveLog("❌ Error collecting global red packet: $e");

      // Show error message
      Get.snackbar(
        ("❌ Collection Failed").appTr,
        ("Failed to collect red packet. Please try again.").appTr,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );

      return false;
    }
  }

  void clearRedPacketCallbacks() {
    onRedPacketReceived = null;

    onRedPacketCollected = null;
    _cancelRedPacketTimer();
  }

  // Emoji Animation Methods
  void handleEmojiAnimation(Map<String, dynamic> emojiData) {
    try {
      // Add emoji to animation list
      emojiAnimations.add({
        'emoji': emojiData['emoji'],
        'user': emojiData['user'],
        'timestamp': emojiData['timestamp'],
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // Show animation
      showEmojiAnimation.value = true;

      // Remove emoji after 5 seconds
      Timer(Duration(seconds: 5), () {
        if (emojiAnimations.isNotEmpty) {
          emojiAnimations.removeAt(0);
        }
        if (emojiAnimations.isEmpty) {
          showEmojiAnimation.value = false;
        }
      });

      liveLog('✅ Emoji animation started: ${emojiData['emoji']}');
    } catch (e) {
      liveLog('❌ Error showing emoji animation: $e');
    }
  }

  /// New audio room open hole old room-er comments/entry/gift/seat data clear.
  /// Same stream/minimize return hole clear korbe na.
  Future<void> leaveVideoRoomState({required int livestreamId}) async {
    for (final purpose in <String>[
      'viewers',
      'comments',
      'call-list',
      'moderation',
    ]) {
      _nextSocketGeneration(purpose);
    }
    await Future.wait<void>(<Future<void>>[
      _cancelSocketSubscription(_viewersSubscription, 'video-room viewers'),
      _cancelSocketSubscription(_commentsSubscription, 'video-room comments'),
      _cancelSocketSubscription(_callListSubscription, 'video-room call-list'),
      _cancelSocketSubscription(
        _moderationSubscription,
        'video-room moderation',
      ),
      _closeSocketChannel(_viewersChannel, 'video-room viewers'),
      _closeSocketChannel(_commentsChannel, 'video-room comments'),
      _closeSocketChannel(_callListChannel, 'video-room call-list'),
      _closeSocketChannel(_moderationChannel, 'video-room moderation'),
    ]);
    _viewersSubscription = null;
    _commentsSubscription = null;
    _callListSubscription = null;
    _moderationSubscription = null;
    _viewersChannel = null;
    _commentsChannel = null;
    _callListChannel = null;
    _moderationChannel = null;

    commentsList.clear();
    giftMessagesList.clear();
    liveCallList.clear();
    pendingCall.clear();
    newViewersJoinded.value = false;
    newJoinedUserData.clear();
    audioMutedUserMap.clear();
    lockedSeatMap.clear();
    processedGiftIds.clear();
    processedImogiIds.clear();
    liveImogiAnimations.clear();
    _giftAnimationHideTimer?.cancel();
    _giftAnimationQueue.clear();
    _giftAnimationQueueMounting = false;
    giftsData.clear();
    isGiftAnimationShowing.value = false;
    liveUserGiftCoins.clear();

    if (streamID.value == livestreamId) streamID.value = 0;
    if (activeAudioStreamId.value == livestreamId) {
      activeAudioStreamId.value = 0;
    }
  }

  void resetAudioRoomStateForStream({
    required int newStreamId,
    bool force = false,
    bool clearSeatsForSameStream = false,
  }) {
    if (newStreamId == 0) return;

    if (!force && activeAudioStreamId.value == newStreamId) {
      /*
      |--------------------------------------------------------------------------
      | Never clear the whole seat list for the same active room
      |--------------------------------------------------------------------------
      | Route rebuild/minimize/resume can call this method while many callers are
      | still seated. Clearing liveCallList made every seat disappear until the
      | next API snapshot arrived.
      |--------------------------------------------------------------------------
      */
      liveLog(
        'ℹ️ Same audio stream preserved; no full seat reset '
            '=> stream:$newStreamId requestedClear:$clearSeatsForSameStream',
      );
      return;
    }

    liveLog(
      '🧹 Reset audio room state => old:${activeAudioStreamId.value} new:$newStreamId',
    );

    /// Hard room isolation: one broadcaster/viewer/coin/PK state must never
    /// leak into another broadcaster's room.
    try {
      livestreamController.resetLocalLiveStateForNewStream(
        newStreamId: newStreamId,
        source: 'websocket_reset_audio_room',
        force: true,
      );
      // Also clear room-scoped admin permission when switching rooms.
      // New room permissions will be filled again by its own API/websocket payload.
      livestreamController.roomGuardianMap.clear();
      livestreamController.guardianListData.clear();
      livestreamController.isMyGuardian.value = false;
      livestreamController.resetPkState(clearResult: true);
      livestreamController.clearPkAgoraSession();
    } catch (e) {
      liveLog('⚠️ Livestream local reset skipped safely: $e');
    }

    activeAudioStreamId.value = newStreamId;
    streamID.value = newStreamId;

    /// Current room changed: title/announcement/profile image/password must be
    /// loaded only from the new room, not from the previously edited room.
    clearLiveRoomSettingsForStream(newStreamId: newStreamId);

    newViewersJoinded.value = false;
    newJoinedUserData.value = {};
    newViewerAction.value = 'join';

    commentsList.clear();
    giftMessagesList.clear();
    processedGiftIds.clear();
    processedImogiIds.clear();
    liveImogiAnimations.clear();
    audioMutedUserMap.clear();

    /// Per-seat gift coins belong to one broadcast only.
    /// Clear before the new room renders so room A can never leak into room B.
    liveUserGiftCoins.clear();

    /// ✅ New live/new room must always start with mic ON locally.
    /// Old room mute state was leaking here and showing fake mute icon on create/join.
    try {
      livestreamController.mute.value = false;
      livestreamController.isMuted.value = false;
      livestreamController.isAudioEnabled.value = true;
    } catch (e) {
      liveLog('⚠️ Local mic reset skipped safely: $e');
    }

    _giftAnimationHideTimer?.cancel();
    _giftAnimationQueue.clear();
    _giftAnimationQueueMounting = false;
    _luckyCardHideTimer?.cancel();
    _luckyCardHideTimer = null;
    _luckyCurrentFlightComplete = false;
    _optimisticGiftAnimationUntilMs.clear();
    _optimisticGiftEchoCredits.clear();
    _optimisticClientEventUntilMs.clear();
    giftsData.value = {};
    isGiftAnimationShowing.value = false;

    liveCallList.clear();
    pendingCall.clear();

    lockedSeatMap.clear();

    liveMusicStatus.value = 'stopped';
    liveMusicName.value = '';
    liveMusicHostId.value = 0;

    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';
    liveYoutubeHostId.value = 0;

    try {
      livestreamController.liveViewerList.clear();
    } catch (_) {}

    _refreshCommentsListSmooth();
    _refreshGiftMessagesListSmooth();
    _refreshLiveCallListSmooth();
    pendingCall.refresh();
    lockedSeatMap.refresh();
    audioMutedUserMap.refresh();
  }

  /// clear user data after remove/out from the stream.
  /// This clears UI only. Seat lock map is NOT changed here.
  Future<void> clearSpecificUserStreamData({
    dynamic rawUserId,
    String? userId,
    bool rejectCallIfInCallList = true,
    bool removeAcceptedCall = true,
    bool closePopupIfOpen = false,
    bool removeViewer = true,
    String reason = '',
  }) async {
    final resolvedUserId = (userId ?? rawUserId ?? '').toString();

    if (resolvedUserId.isEmpty || resolvedUserId == 'null') {
      liveLog(
        '⚠️ clearSpecificUserStreamData skipped: empty userId reason=$reason',
      );
      return;
    }

    final userIdText = resolvedUserId;
    final userIdInt = int.tryParse(userIdText) ?? 0;

    liveLog(
      '🧹 clearSpecificUserStreamData userId=$userIdText '
          'rejectCallIfInCallList=$rejectCallIfInCallList '
          'removeAcceptedCall=$removeAcceptedCall '
          'closePopupIfOpen=$closePopupIfOpen '
          'removeViewer=$removeViewer reason=$reason',
    );

    bool sameCall(dynamic call) {
      if (call is! Map) return false;

      final callerId = call['caller_id'];
      final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
      final userIdField = call['user_id'];
      final directId = call['id'];
      final bool hasRealCallerId =
          callerId != null || nestedUserId != null || userIdField != null;

      return callerId.toString() == userIdText ||
          nestedUserId.toString() == userIdText ||
          userIdField.toString() == userIdText ||
          (!hasRealCallerId && directId.toString() == userIdText) ||
          callerId == userIdInt ||
          nestedUserId == userIdInt ||
          userIdField == userIdInt ||
          (!hasRealCallerId && directId == userIdInt);
    }

    bool sameViewer(dynamic viewer) {
      if (viewer is! Map) return false;

      final nestedUserId = viewer['user'] is Map ? viewer['user']['id'] : null;
      final viewerId = viewer['viewer_id'];
      final directId = viewer['id'];
      final userIdField = viewer['user_id'];

      return nestedUserId.toString() == userIdText ||
          viewerId.toString() == userIdText ||
          userIdField.toString() == userIdText ||
          directId.toString() == userIdText ||
          nestedUserId == userIdInt ||
          viewerId == userIdInt ||
          userIdField == userIdInt ||
          directId == userIdInt;
    }

    final leavingCalls = liveCallList.where(sameCall).whereType<Map>().toList();
    final userWasInCallList = leavingCalls.isNotEmpty;

    /// Do NOT clear lockedSeatMap here.
    /// Seat lock should only change from explicit lock/unlock events.

    if (removeViewer) {
      try {
        livestreamController.removeViewerLocal(userIdInt);
      } catch (_) {}

      livestreamController.liveViewerList.removeWhere(sameViewer);
      livestreamController.liveViewerList.refresh();
      newViewersJoinded.value = false;
      newJoinedUserData.value = {};
    }

    final bool shouldDemoteCurrentUserMedia =
        removeAcceptedCall ||
            reason.contains('kick') ||
            reason.contains('reject') ||
            reason.contains('leave_seat') ||
            reason.contains('live_end') ||
            reason.contains('live_ended') ||
            reason.contains('room_exit') ||
            reason.contains('full_exit') ||
            reason.contains('close');

    if (authController.userProfile.value.user?.id == userIdInt &&
        shouldDemoteCurrentUserMedia) {
      try {
        final agoraService = AgoraService();

        /// Removing the current user from a seat must leave the app muted.
        /// Previously this branch set mute=false, so a later background/resume
        /// recovery could publish the microphone again even though the user was
        /// already a normal viewer.
        livestreamController.mute.value = true;
        livestreamController.isMuted.value = true;
        livestreamController.isAudioEnabled.value = false;
        audioMutedUserMap[userIdInt] = true;
        audioMutedUserMap.refresh();

        if (agoraService.engine != null) {
          await agoraService.engine!.enableAudio();
          await agoraService.engine!.enableLocalAudio(true);
          try {
            await agoraService.engine!.adjustRecordingSignalVolume(0);
          } catch (_) {}
          await agoraService.engine!.muteLocalAudioStream(true);
          await agoraService.engine!.muteLocalVideoStream(true);

          try {
            await agoraService.engine!.updateChannelMediaOptions(
              const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleAudience,
                publishMicrophoneTrack: false,
                autoSubscribeAudio: true,
              ),
            );
          } catch (e) {
            liveLog(
              '⚠️ media option update skipped while clearing current user: $e',
            );
          }

          await agoraService.engine!.setClientRole(
            role: ClientRoleType.clientRoleAudience,
          );

          liveLog(
            '🔇 Current user cleared from seat; local media auto-muted: $userIdInt',
          );
        }
      } catch (e) {
        liveLog('⚠️ Error muting local media for user $userIdInt: $e');
      }
    }

    if (removeAcceptedCall) {
      liveCallList.removeWhere(sameCall);
    } else {
      liveCallList.removeWhere((call) {
        if (call is! Map) return false;
        if (!sameCall(call)) return false;

        final status = (call['call_status'] ?? call['status'] ?? '')
            .toString()
            .toLowerCase();

        /// If removeAcceptedCall=false, keep every active seat/call row.
        /// Backend uses several equivalent active statuses across old/unified
        /// channels. Dropping `live`/`on_seat` here made the host lose a caller
        /// card even though that caller was still connected and publishing.
        return status != 'accepted' &&
            status != 'joined' &&
            status != 'active' &&
            status != 'live' &&
            status != 'on_seat';
      });
    }
    _refreshLiveCallListSmooth();

    pendingCall.removeWhere(sameCall);
    pendingCall.refresh();

    if (closePopupIfOpen) {
      try {
        if (Get.isDialogOpen == true) {
          Get.back();
        }
      } catch (e) {
        liveLog('⚠️ closePopupIfOpen ignored: $e');
      }
    }

    if (rejectCallIfInCallList && userWasInCallList && streamID.value != 0) {
      try {
        await livestreamController.tryToRejectCall(
          streamId: streamID.value,
          userId: userIdInt,
        );
      } catch (e) {
        liveLog('⚠️ Reject call skipped/failed: $e');
      }
    }
  }

  // Handle kick out moderation action
  void _handleKickOut(Map<String, dynamic> moderationData) {
    try {
      final kickedUserId = moderationData['user_id'];
      final livestreamId = moderationData['livestream_id'];
      final remainingMinutes = moderationData['remaining_minutes'] ?? 15;

      // Check if current user is the one being kicked
      final currentUserId = Get.find<AuthController>()
          .userProfile
          .value
          .user
          ?.id
          .toString();

      if (currentUserId == kickedUserId &&
          streamID.value.toString() == livestreamId) {
        // Current user is being kicked outda

        Get.offAll(BottomnavView());

        // Show kick out dialog
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 8),
                Text(('Kicked Out').appTr),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(('You have been removed from this live stream.').appTr),
                SizedBox(height: 8),
                Text(
                  ('You cannot rejoin for $remainingMinutes minutes.').appTr,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(); // Close dialog
                },
                child: Text(
                  ('OK').appTr,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          barrierDismissible: false,
        );
        clearSpecificUserStreamData(userId: kickedUserId);
      } else {
        // Another user is being kicked out, remove from lists
        liveLog(
          '🚫 User $kickedUserId kicked out from livestream $livestreamId',
        );
        clearSpecificUserStreamData(userId: kickedUserId);
      }
    } catch (e) {
      liveLog('❌ Error handling kick out: $e');
    }
  }

  // Handle audio toggle moderation action
  bool _audioOffValue(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    return v == '0' ||
        v == 'false' ||
        v == 'no' ||
        v == 'off' ||
        v == 'mute' ||
        v == 'muted';
  }

  bool _audioOnValue(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    return v == '1' ||
        v == 'true' ||
        v == 'yes' ||
        v == 'on' ||
        v == 'unmute' ||
        v == 'unmuted';
  }

  int _normalizeAudioOn(Map<String, dynamic> data) {
    final mutedRaw =
        data['is_muted'] ??
            data['muted'] ??
            data['is_muted_by_host'] ??
            data['mute_status'];
    final audioRaw =
        data['audio_on'] ??
            data['is_audio_on'] ??
            data['mic_on'] ??
            data['microphone_on'] ??
            data['status'] ??
            data['action'];

    /// ✅ FIX:
    /// audio_on/is_audio_on is authoritative when present. Some backend rows send
    /// audio_on=1 with stale is_muted=1, which caused fake mute icons.
    if (_audioOffValue(audioRaw)) return 0;
    if (_audioOnValue(audioRaw)) return 1;

    /// mutedRaw means: true/1/muted => mic off, false/0/unmuted => mic on.
    /// Use it only when audio_on/is_audio_on is missing.
    if (mutedRaw != null) {
      if (mutedRaw == true || mutedRaw == 1 || _audioOffValue(mutedRaw)) {
        return 0;
      }
      if (mutedRaw == false || mutedRaw == 0 || _audioOnValue(mutedRaw)) {
        return 1;
      }
    }

    /// If no audio state exists in event, keep old state instead of forcing unmute.
    return -1;
  }

  Future<void> _handleAudioToggle(Map<String, dynamic> moderationData) async {
    try {
      final data = moderationData['data'] is Map
          ? Map<String, dynamic>.from(moderationData['data'])
          : Map<String, dynamic>.from(moderationData);

      final userId =
          int.tryParse(
            (data['user_id'] ??
                data['caller_id'] ??
                data['id'] ??
                data['uid'] ??
                '')
                .toString(),
          ) ??
              0;

      if (userId == 0) {
        liveLog('⚠️ audio toggle user id missing: $moderationData');
        return;
      }

      final int normalizedAudioOn = _normalizeAudioOn(data);

      final callIndex = liveCallList.indexWhere((call) {
        if (call is! Map) return false;
        final callerId = call['caller_id'];
        final profileId = call['user'] is Map ? call['user']['id'] : null;
        final userIdField = call['user_id'];
        return callerId.toString() == userId.toString() ||
            profileId.toString() == userId.toString() ||
            userIdField.toString() == userId.toString();
      });

      if (callIndex != -1) {
        final old = liveCallList[callIndex] is Map
            ? Map<String, dynamic>.from(liveCallList[callIndex])
            : <String, dynamic>{};

        final int oldAudioOn = _normalizeAudioOn(old) == -1
            ? (old['audio_on']?.toString() == '0' ? 0 : 1)
            : _normalizeAudioOn(old);

        final int audioOn = normalizedAudioOn == -1
            ? oldAudioOn
            : normalizedAudioOn;

        old['audio_on'] = audioOn;
        old['is_audio_on'] = audioOn;
        old['is_muted'] = audioOn == 1 ? 0 : 1;
        old['is_muted_by_host'] = audioOn == 1 ? 0 : 1;

        liveCallList[callIndex] = old;
        _refreshLiveCallListSmooth();

        liveLog(
          '✅ Unified audio toggle updated => user:$userId audio_on:$audioOn',
        );

        final currentUserId =
            authController.userProfile.value.user?.id?.toInt() ?? 0;

        audioMutedUserMap[userId] = audioOn == 0;
        audioMutedUserMap.refresh();

        if (userId == currentUserId && _agoraService.engine != null) {
          final engine = _agoraService.engine!;
          livestreamController.mute.value = audioOn == 0;
          await engine.enableAudio();
          await engine.enableLocalAudio(true);
          if (audioOn == 1) {
            await engine.setClientRole(
              role: ClientRoleType.clientRoleBroadcaster,
            );
            try {
              await engine.updateChannelMediaOptions(
                const ChannelMediaOptions(
                  clientRoleType: ClientRoleType.clientRoleBroadcaster,
                  publishMicrophoneTrack: true,
                  autoSubscribeAudio: true,
                ),
              );
            } catch (_) {}
          }
          await engine.muteLocalAudioStream(audioOn == 0);
          try {
            await engine.adjustRecordingSignalVolume(audioOn == 1 ? 100 : 0);
          } catch (_) {}
          liveLog('🎙️ Local mic ${audioOn == 1 ? "unmuted" : "muted"}');
        }
      } else {
        /// Late audience may receive audio state before seat list is hydrated.
        /// If the event has no explicit audio value, do not create a fake unmuted row.
        if (normalizedAudioOn == -1) {
          liveLog(
            'ℹ️ Audio toggle ignored for missing row because audio state is partial => user:$userId',
          );
          return;
        }

        final int audioOn = normalizedAudioOn;
        liveCallList.add({
          'caller_id': userId,
          'user_id': userId,
          'audio_on': audioOn,
          'is_audio_on': audioOn,
          'is_muted': audioOn == 1 ? 0 : 1,
          'is_muted_by_host': audioOn == 1 ? 0 : 1,
          'call_status': 'accepted',
          'user': data['user'] is Map
              ? Map<String, dynamic>.from(data['user'])
              : {
            'id': userId,
            'user_id': userId,
            'name': data['name'] ?? data['user_name'] ?? 'User $userId',
            'profile_image': data['profile_image'] ?? '',
            'level': data['level'] ?? 0,
          },
        });
        _refreshLiveCallListSmooth();
        liveLog(
          'ℹ️ Audio toggle inserted missing call row => user:$userId audio_on:$audioOn',
        );
      }
    } catch (e) {
      liveLog('❌ Error handling audio toggle: $e');
    }
  }

  // Handle video toggle moderation action
  Future<void> _handleVideoToggle(Map<String, dynamic> moderationData) async {
    try {
      final int userId = _toInt(
        moderationData['user_id'] ??
            moderationData['caller_id'] ??
            moderationData['target_user_id'],
      );
      if (userId <= 0) {
        liveLog('⚠️ Video toggle ignored: user id missing => $moderationData');
        return;
      }

      final dynamic videoOnRaw =
          moderationData['video_on'] ?? moderationData['is_video_on'];
      final bool hasExplicitVideoState =
          moderationData.containsKey('video_on') ||
              moderationData.containsKey('is_video_on');
      final bool isVideoOn = hasExplicitVideoState
          ? _truthy(videoOnRaw)
          : !getUserVideoStatus(userId);
      final int videoOnValue = isVideoOn ? 1 : 0;

      final callIndex = liveCallList.indexWhere((call) {
        if (call is! Map) return false;
        final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
        return call['caller_id'].toString() == userId.toString() ||
            call['user_id'].toString() == userId.toString() ||
            nestedUserId.toString() == userId.toString();
      });

      if (callIndex != -1) {
        final row = Map<String, dynamic>.from(liveCallList[callIndex]);
        row['video_on'] = videoOnValue;
        row['is_video_on'] = videoOnValue;
        if (row['user'] is Map) {
          final user = Map<String, dynamic>.from(row['user']);
          user['video_on'] = videoOnValue;
          user['is_video_on'] = videoOnValue;
          row['user'] = user;
        }
        liveCallList[callIndex] = row;
        _refreshLiveCallListSmooth();
      } else {
        liveLog('⚠️ User $userId not found in live call list');
      }

      final currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (userId == currentUserId && _agoraService.engine != null) {
        final engine = _agoraService.engine!;
        livestreamController.isVideoEnabled.value = isVideoOn;

        /// Camera off must not demote the caller from the call/seat. Keep the
        /// broadcaster role and microphone publishing; only camera capture and
        /// camera track publishing are toggled.
        await engine.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        );
        await engine.enableVideo();
        await engine.enableLocalVideo(isVideoOn);
        await engine.muteLocalVideoStream(!isVideoOn);
        try {
          await engine.updateChannelMediaOptions(
            ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishCameraTrack: isVideoOn,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
        } catch (e) {
          liveLog('⚠️ Camera publish option update skipped safely: $e');
        }
        liveLog(
          '📹 Local Agora video ${isVideoOn ? "enabled" : "disabled"} '
              '=> user:$userId',
        );
      }

      livestreamController.update();
      liveLog(
        '✅ Video toggle applied => user:$userId video_on:$videoOnValue',
      );
    } catch (e) {
      liveLog('❌ Error handling video toggle: $e');
    }
  }

  // Handle live stream ended moderation action
  void _handleLiveStreamEnded(Map<String, dynamic> moderationData) {
    try {
      final livestreamId =
          moderationData['livestream_id'] ??
              moderationData['stream_id'] ??
              moderationData['id'];
      final message = moderationData['message'] ?? 'Live stream has ended';
      final int livestreamIdInt = _toInt(livestreamId);

      if (livestreamIdInt <= 0) {
        liveLog(
          '⚠️ _handleLiveStreamEnded missing livestream_id => $moderationData',
        );
        return;
      }

      /// The same owner's REST close flow will open Endlive with full summary
      /// data. Do not send this device to Bottomnav from the earlier socket event.
      if (_isLocalOwnerCloseInProgress(moderationData)) {
        isStreamEnded.value = true;
        isBroadcasterOnline.value = false;
        _locallyLeftStreamIds.add(livestreamIdInt);
        liveLog(
          '✅ Local owner close socket acknowledged; '
              'Bottomnav redirect skipped => stream:$livestreamIdInt',
        );
        return;
      }

      // If this live is currently in any local room state, force cleanup.
      // Do NOT depend on joined_users because backend sometimes sends host only.
      final bool isCorrectStream =
          _isLiveRoomCurrentlyOpen(livestreamIdInt) ||
              streamID.value == livestreamIdInt ||
              activeAudioStreamId.value == livestreamIdInt ||
              livestreamController.streamId.value == livestreamIdInt;

      if (!isCorrectStream) {
        // Still remove from list, but do not route if the room is not open here.
        liveLog(
          'ℹ️ Live end list removed only, room not open here => $livestreamIdInt',
        );
        return;
      }

      isStreamEnded.value = true;
      isBroadcasterOnline.value = false;
      _locallyLeftStreamIds.add(livestreamIdInt);

      liveLog(
        '✅ Live end force cleanup => stream:$livestreamIdInt msg:$message',
      );
      liveCleanupService.forceExitLiveRoom(
        streamId: livestreamIdInt,
        reason: moderationData['reason']?.toString() ?? 'live_end',
        goBottomNav: true,
      );
    } catch (e, st) {
      liveLog('❌ Error handling live stream ended: $e\n$st');
      liveCleanupService.forceExitLiveRoom(
        streamId: streamID.value,
        reason: 'live_end_error',
      );
    }
  }

  // Redirect to bottom navigation (home page)
  void _redirectToBottomNav() {
    try {
      _safeCloseOpenDialogOrSheet();

      streamID.value = 0;
      activeAudioStreamId.value = 0;
      try {
        livestreamController.streamId.value = 0;
      } catch (_) {}

      livestreamController.clearViewerLocal();
      liveCallList.clear();
      pendingCall.clear();
      _refreshLiveCallListSmooth();
      pendingCall.refresh();

      Future.microtask(() {
        try {
          Get.offAll(
                () => BottomnavView(),
            transition: Transition.cupertino,
            duration: const Duration(milliseconds: 300),
          );
        } catch (e) {
          liveLog('❌ Get.offAll bottom nav failed => $e');
        }
      });
    } catch (e, st) {
      liveLog('❌ Error redirecting to bottom nav: $e\n$st');
    }
  }

  // brodecaster controller
  final broadcasterWebsocket = WebSocketChannel.connect(Uri.parse(kWsUrl));
  void tryToConnectToBroadcasterWs() async {
    try {
      if (kWsUrl.isEmpty) {
        liveLog('❌ WebSocket URL is empty, cannot connect to comments list');
        return;
      }

      await broadcasterWebsocket.ready;

      // Subscribe to the live-comment channel
      try {
        if (broadcasterWebsocket.closeCode == null) {
          broadcasterWebsocket.sink.add(
            json.encode({
              "event": "pusher:subscribe",
              "data": {"channel": "livestream-$streamID"},
            }),
          );

          // ✅ Print after successful subscription attempt
          liveLog(
            '✅ Connected and subscribed to livestream-$streamID WebSocket channel',
          );
        }
      } catch (e) {
        liveLog('❌ Error subscribing to live-comment channel: $e');
      }
    } catch (e) {
      liveLog('❌ Error connecting to comments list WebSocket: $e');
    }
  }

  // ========================================================================
  // ✅ NEW SINGLE EVENT WEBSOCKET SYSTEM
  // Backend event: LiveStreamEvent
  // Payload key: action_type
  // ========================================================================

  WebSocketChannel? liveStreamEventChannel;
  StreamSubscription<dynamic>? _unifiedSubscription;
  Timer? _unifiedReconnectTimer;
  bool _isConnectingUnifiedWs = false;
  int _unifiedSocketGeneration = 0;
  int? _unifiedReconnectScheduledForGeneration;
  bool _unifiedDisconnectIntentional = false;

  // ========================================================================
  // RECHARGE COIN REALTIME
  // One existing websocket connection + one private user channel.
  // No fast polling and no extra websocket connection.
  // ========================================================================
  static const String _rechargeEventName = 'recharge.coin.updated';
  static const String _rechargeActionType = 'recharge_coin_updated';

  static const String _accountBlockedEventName = 'account.blocked';
  static const String _accountBlockedActionType = 'account_blocked';
  static const String _deviceBlockedEventName = 'device.blocked';
  static const String _deviceBlockedActionType = 'device_blocked';

  String _rechargeSocketId = '';
  String _rechargePrivateChannelName = '';
  String _rechargePendingChannelName = '';
  int _rechargeSubscribedUserId = 0;
  bool _isAuthorizingRechargeChannel = false;

  String _accountBlockPrivateChannelName = '';
  String _accountBlockPendingChannelName = '';
  int _accountBlockSubscribedUserId = 0;
  bool _isAuthorizingAccountBlockChannel = false;

  String _deviceBlockPrivateChannelName = '';
  String _deviceBlockPendingChannelName = '';
  int _deviceBlockSubscribedDeviceId = 0;
  bool _isAuthorizingDeviceBlockChannel = false;

  bool _rechargeUiPaused = false;
  bool _rechargePopupShowing = false;
  Timer? _rechargePopupRetryTimer;

  final Set<String> _processedRechargeEventIds = <String>{};
  final Set<String> _claimedRechargeEventIds = <String>{};
  final List<Map<String, dynamic>> _rechargePopupQueue =
  <Map<String, dynamic>>[];

  /// Prevent duplicate call popup for same caller/stream/call type.
  /// Pending event duplicate ashle accept korar por abar popup show hobe na.
  final Set<String> _activeCallPopupKeys = <String>{};
  final Set<String> _handledCallPopupKeys = <String>{};
  final Map<String, Future<void>> _callProfileHydrationFutures =
  <String, Future<void>>{};
  final Map<int, Future<void>> _callerMediaTransitionFutures =
  <int, Future<void>>{};
  bool _localVideoPreviewActive = false;
  int _localPublishingCallerId = 0;

  /// Local leave + viewer join memory for video live.
  /// Keeps stale pending call/live-ended events from affecting a user after they left.
  final Set<int> _locallyLeftStreamIds = <int>{};
  final Map<int, int> _viewerJoinedAtMs = <int, int>{};

  /// Room-exit guard by stream+user.
  /// When a viewer fully leaves the room, delayed call_canceled/caller_left
  /// events can arrive a few seconds later and wrongly re-add the user as viewer.
  /// This guard blocks only those stale seat-left re-adds. A real viewer_joined
  /// event clears the guard and allows the user to appear again.
  final Map<String, int> _recentRoomExitUserUntilMs = <String, int>{};

  String _roomExitGuardKey(dynamic streamId, dynamic userId) =>
      '${_toInt(streamId)}_${_toInt(userId)}';

  void _markRecentRoomExit({
    required dynamic streamId,
    required dynamic userId,
    int milliseconds = 60000,
  }) {
    final int sid = _toInt(streamId);
    final int uid = _toInt(userId);
    if (sid <= 0 || uid <= 0) return;

    _recentRoomExitUserUntilMs[_roomExitGuardKey(sid, uid)] =
        DateTime.now().millisecondsSinceEpoch + milliseconds;
  }

  bool _hasRecentRoomExit({
    required dynamic streamId,
    required dynamic userId,
  }) {
    final int sid = _toInt(streamId);
    final int uid = _toInt(userId);
    if (sid <= 0 || uid <= 0) return false;

    final key = _roomExitGuardKey(sid, uid);
    final until = _recentRoomExitUserUntilMs[key] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (until <= now) {
      _recentRoomExitUserUntilMs.remove(key);
      return false;
    }
    return true;
  }

  void _clearRecentRoomExit({
    required dynamic streamId,
    required dynamic userId,
  }) {
    final int sid = _toInt(streamId);
    final int uid = _toInt(userId);
    if (sid <= 0 || uid <= 0) return;
    _recentRoomExitUserUntilMs.remove(_roomExitGuardKey(sid, uid));
  }

  void prepareViewerRejoin({required int livestreamId, required int viewerId}) {
    if (livestreamId <= 0 || viewerId <= 0) return;
    _locallyLeftStreamIds.remove(livestreamId);
    _clearRecentRoomExit(streamId: livestreamId, userId: viewerId);
    _viewerJoinedAtMs.remove(viewerId);
    _recentEntryShownUntilMs.remove(viewerId);
    if (_entryUserIdFromData(newJoinedUserData.value) == viewerId) {
      hideEntryAnimation();
    }
    streamID.value = livestreamId;
  }

  String _callPopupKey({
    required dynamic streamId,
    required dynamic callerId,
    required dynamic callType,
  }) {
    return '${streamId ?? streamID.value}_${callerId}_$callType';
  }

  String _normalizedCallType(dynamic value) =>
      (value ?? '').toString().trim().toLowerCase();

  bool _isVideoCallType(dynamic value) {
    final type = _normalizedCallType(value);
    return type == 'video' || type == 'popular';
  }

  /// AudioLiveView keeps activeAudioStreamId equal to the currently opened
  /// audio room. Cached room data is used as a fallback for restore/rejoin.
  bool _isCurrentAudioOnlyRoom({dynamic livestreamId}) {
    final int eventStreamId = _toInt(livestreamId ?? streamID.value);
    final int activeAudioId = _toInt(activeAudioStreamId.value);

    if (activeAudioId > 0 &&
        (eventStreamId <= 0 || eventStreamId == activeAudioId)) {
      return true;
    }

    final List<Map<String, dynamic>> candidates = <Map<String, dynamic>>[];
    try {
      final root = livestreamController.createStreamData;
      if (root is Map) {
        candidates.add(Map<String, dynamic>.from(root));
        for (final key in const ['livestreamdata', 'livestream', 'data']) {
          final nested = root[key];
          if (nested is Map) {
            candidates.add(Map<String, dynamic>.from(nested));
          }
        }
      }
    } catch (_) {}

    try {
      for (final raw in homeController.showingLiveStreamList) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final int id = _toInt(
          map['id'] ?? map['livestream_id'] ?? map['stream_id'],
        );
        if (eventStreamId > 0 && id > 0 && id != eventStreamId) continue;
        candidates.add(map);
        if (eventStreamId > 0 && id == eventStreamId) break;
      }
    } catch (_) {}

    for (final map in candidates) {
      final int id = _toInt(
        map['id'] ?? map['livestream_id'] ?? map['stream_id'],
      );
      if (eventStreamId > 0 && id > 0 && id != eventStreamId) continue;

      final type = _normalizedCallType(
        map['stream_type'] ?? map['live_type'] ?? map['room_type'],
      );
      if (type == 'audio' || type == 'audio_live') return true;
      if (type == 'video' ||
          type == 'popular' ||
          type == 'multi' ||
          type == 'pk') {
        return false;
      }
    }

    return false;
  }

  /// Returns false only for an explicit video/popular request inside an audio
  /// room. Missing call_type is normalized to audio because the pending event
  /// may omit it even though the accept API returns call_type=audio.
  bool _normalizeCallTypeForCurrentRoom(
      Map<String, dynamic> callData,
      Map<String, dynamic> payload, {
        dynamic livestreamId,
      }) {
    final nestedCallData = payload['call_data'];
    final rawType =
        callData['call_type'] ??
            callData['type'] ??
            payload['call_type'] ??
            (nestedCallData is Map ? nestedCallData['call_type'] : null);
    final type = _normalizedCallType(rawType);
    final bool audioRoom = _isCurrentAudioOnlyRoom(
      livestreamId: livestreamId,
    );

    if (audioRoom && _isVideoCallType(type)) {
      final int callerId = _toInt(
        callData['caller_id'] ??
            callData['user_id'] ??
            callData['user']?['id'] ??
            payload['caller_id'] ??
            payload['user_id'],
      );
      final int sid = _toInt(livestreamId ?? streamID.value);

      pendingCall.removeWhere((raw) {
        if (raw is! Map) return false;
        return _callUserId(Map<String, dynamic>.from(raw)) == callerId;
      });
      pendingCall.refresh();

      final key = _callPopupKey(
        streamId: sid,
        callerId: callerId,
        callType: type,
      );
      _activeCallPopupKeys.remove(key);
      _handledCallPopupKeys.add(key);

      liveLog(
        '⛔ VIDEO_CALL_BLOCKED_IN_AUDIO_ROOM => '
            'stream:$sid caller:$callerId type:$type',
      );
      return false;
    }

    if (audioRoom && (type.isEmpty || type == 'voice')) {
      callData['call_type'] = 'audio';
    } else if (type.isEmpty) {
      // Safe generic fallback: never turn an absent call_type into video UI.
      callData['call_type'] = 'audio';
    } else {
      callData['call_type'] = type;
    }

    return true;
  }

  int _eventTimeMs(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value > 9999999999 ? value : value * 1000;
    final s = value.toString().trim();
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt > 9999999999 ? asInt : asInt * 1000;
    try {
      return DateTime.parse(s).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  void markUserDisconnectedFromLivestream({
    required dynamic streamId,
    required dynamic userId,
    String reason = 'left_live',
  }) {
    final int sid = _toInt(streamId);
    final int uid = _toInt(userId);

    if (sid > 0) {
      _locallyLeftStreamIds.add(sid);
      if (streamID.value == sid) {
        streamID.value = 0;
      }
    }

    if (uid > 0) {
      _markRecentRoomExit(streamId: sid, userId: uid, milliseconds: 60000);
      _viewerJoinedAtMs.remove(uid);
      _clearStaleCallStateForUser(
        callerId: uid,
        streamId: sid > 0 ? sid : null,
        removeAcceptedCall: true,
        closePopupIfOpen: true,
        reason: reason,
      );
      audioMutedUserMap.remove(uid);
      audioMutedUserMap.refresh();
    }

    pendingCall.refresh();
    _refreshLiveCallListSmooth();
    liveLog(
      '🚪 Marked user disconnected from livestream => stream:$sid user:$uid reason:$reason',
    );
  }

  bool _isUserInCurrentViewerList(dynamic userId) {
    final uid = userId?.toString();
    if (uid == null || uid == 'null' || uid.isEmpty || uid == '0') return false;

    for (final item in livestreamController.liveViewerList) {
      if (item is! Map) continue;
      final nestedUserId = item['user'] is Map ? item['user']['id'] : null;
      final viewerId = item['viewer_id'];
      final directId = item['id'];
      final userIdField = item['user_id'];

      if (nestedUserId?.toString() == uid ||
          viewerId?.toString() == uid ||
          directId?.toString() == uid ||
          userIdField?.toString() == uid) {
        return true;
      }
    }

    return false;
  }

  void _ensureViewerRowFromCall(Map<String, dynamic> callData) {
    final user = callData['user'];
    final int uid = _toInt(
      callData['caller_id'] ?? (user is Map ? user['id'] : null),
    );
    if (uid <= 0 || user is! Map) return;

    _cacheLiveUserProfile(user);
    final exists = _isUserInCurrentViewerList(uid);
    if (exists) return;

    final stream =
        callData['livestream_id'] ?? callData['stream_id'] ?? streamID.value;
    livestreamController.addOrUpdateViewerLocal({
      'id': uid,
      'viewer_id': uid,
      'user_id': uid,
      'livestream_id': stream,
      'user': _mergeWithCachedLiveUserProfile(userId: uid, rawUser: user),
      'is_active': 1,
    }, force: true);
    liveLog('✅ Viewer row hydrated from call payload => user:$uid');
  }

  /// When host removes a user from seat, backend sends caller_left.
  /// That must remove only mic/seat row, not live room viewer identity.
  /// Some backend payloads do not send a separate viewer_joined after this,
  /// so hydrate the viewer row from caller_left.user/caller payload.
  void _ensureViewerRowAfterSeatLeft(Map<String, dynamic> payload) {
    try {
      final dynamic rawUser = payload['user'] is Map
          ? payload['user']
          : payload['caller'] is Map
          ? payload['caller']
          : null;

      if (rawUser is! Map) return;

      final int uid = _toInt(
        payload['user_id'] ??
            payload['caller_id'] ??
            rawUser['id'] ??
            rawUser['user_id'],
      );

      if (uid <= 0) return;

      final stream =
          payload['livestream_id'] ?? payload['stream_id'] ?? streamID.value;
      final reason = (payload['reason'] ?? payload['leave_reason'] ?? '')
          .toString()
          .toLowerCase();
      final action = (payload['action'] ?? payload['action_type'] ?? '')
          .toString()
          .toLowerCase();
      final status = (payload['call_status'] ?? payload['status'] ?? '')
          .toString()
          .toLowerCase();
      final bool fullRoomExit =
          reason == 'room_exit' ||
              reason == 'full_exit' ||
              reason.contains('room_exit') ||
              reason.contains('full_exit') ||
              payload['remove_viewer'] == true ||
              payload['viewer_removed'] == true ||
              action == 'viewer_left' ||
              action == 'viewer_remove' ||
              action == 'viewer_removed';

      if (fullRoomExit || _hasRecentRoomExit(streamId: stream, userId: uid)) {
        liveLog(
          '🚫 Viewer row NOT re-added after full room exit/stale seat event => user:$uid reason:$reason action:$action status:$status',
        );
        return;
      }

      _cacheLiveUserProfile(rawUser);
      final hydratedUser = _mergeWithCachedLiveUserProfile(
        userId: uid,
        rawUser: rawUser,
      );
      final exists = _isUserInCurrentViewerList(uid);

      final viewerInfo = <String, dynamic>{
        'id': uid,
        'viewer_id': uid,
        'user_id': uid,
        'livestream_id': stream,
        'is_active': true,
        'user': hydratedUser,
      };

      livestreamController.addOrUpdateViewerLocal(viewerInfo, force: true);
      if (exists) {
        liveLog('✅ Viewer row kept after seat left => user:$uid');
      } else {
        liveLog('✅ Viewer row re-added after seat left => user:$uid');
      }
    } catch (e) {
      liveLog('⚠️ ensure viewer after seat left skipped => $e');
    }
  }

  /// Clears stale call request/cache for a viewer/caller.
  ///
  /// Video live problem fix:
  /// If a viewer leaves the broadcast while a call request is pending, the host
  /// could keep seeing the old "call request" popup after that viewer enters the
  /// live again. We clear only that caller's stale call rows/keys without touching
  /// PK state or other callers.
  void _clearStaleCallStateForUser({
    required dynamic callerId,
    dynamic streamId,
    bool removeAcceptedCall = false,
    bool closePopupIfOpen = false,
    String reason = 'unknown',
  }) {
    final int cid = _toInt(callerId);
    if (cid == 0) return;

    bool sameCaller(dynamic call) {
      if (call is! Map) return false;
      final dynamic id =
          call['caller_id'] ??
              call['user_id'] ??
              (call['user'] is Map ? call['user']['id'] : null) ??
              (call['caller_data'] is Map
                  ? call['caller_data']['caller_id']
                  : null) ??
              (call['caller_data'] is Map && call['caller_data']['user'] is Map
                  ? call['caller_data']['user']['id']
                  : null);
      return id != null && id.toString() == cid.toString();
    }

    final int beforePending = pendingCall.length;
    final int beforeLive = liveCallList.length;

    pendingCall.removeWhere(sameCaller);

    if (removeAcceptedCall) {
      liveCallList.removeWhere(sameCaller);
    }

    bool keyBelongsToCaller(String key) {
      final sid = streamId ?? streamID.value;
      final containsCaller = key.contains('_${cid}_');
      if (!containsCaller) return false;
      if (sid == null || sid.toString().isEmpty || sid.toString() == '0') {
        return true;
      }
      return key.startsWith('${sid}_');
    }

    final bool hadActivePopup = _activeCallPopupKeys.any(keyBelongsToCaller);
    _activeCallPopupKeys.removeWhere(keyBelongsToCaller);

    /// Do not keep handled keys forever. Otherwise the same viewer cannot call
    /// again after leaving/re-entering the broadcast.
    _handledCallPopupKeys.removeWhere(keyBelongsToCaller);

    if (closePopupIfOpen && hadActivePopup && Get.isDialogOpen == true) {
      try {
        Get.back();
      } catch (_) {}
    }

    pendingCall.refresh();
    _refreshLiveCallListSmooth();
  }

  int _authRechargeUserId() {
    final dynamic rawId = authController.userProfile.value.user?.id;
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId?.toString() ?? '') ?? 0;
  }

  String _authRechargeToken() {
    return authController.userProfile.value.token?.toString().trim() ?? '';
  }

  Map<String, dynamic> _decodePusherData(dynamic raw) {
    dynamic value = raw;

    for (int i = 0; i < 5; i++) {
      if (value is String) {
        try {
          value = json.decode(value);
        } catch (_) {
          break;
        }
      } else {
        break;
      }
    }

    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> ensureRechargeRealtimeSubscription() async {
    final int userId = _authRechargeUserId();
    final String token = _authRechargeToken();

    if (userId <= 0 || token.isEmpty) {
      liveLog('ℹ️ Recharge realtime waiting for authenticated user');
      return;
    }

    final String expectedChannel = 'private-user-recharge.$userId';
    final bool alreadySubscribed =
        _rechargeSubscribedUserId == userId &&
            _rechargePrivateChannelName == expectedChannel;
    final bool subscriptionPending =
        _rechargePendingChannelName == expectedChannel;

    if ((alreadySubscribed || subscriptionPending) &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      return;
    }

    if (liveStreamEventChannel == null ||
        liveStreamEventChannel!.closeCode != null) {
      await tryToConnectToUnifiedLiveStreamEventWs(force: false);
      return;
    }

    if (_rechargeSocketId.isEmpty) {
      liveLog('ℹ️ Recharge realtime waiting for websocket socket_id');
      return;
    }

    await _authorizeAndSubscribeRechargeChannel(
      socketId: _rechargeSocketId,
      userId: userId,
      token: token,
    );
  }

  Future<void> _authorizeAndSubscribeRechargeChannel({
    required String socketId,
    required int userId,
    required String token,
  }) async {
    if (_isAuthorizingRechargeChannel) return;
    if (socketId.isEmpty || userId <= 0 || token.isEmpty) return;
    if (liveStreamEventChannel == null ||
        liveStreamEventChannel!.closeCode != null) {
      return;
    }

    final String channelName = 'private-user-recharge.$userId';

    if ((_rechargeSubscribedUserId == userId &&
        _rechargePrivateChannelName == channelName) ||
        _rechargePendingChannelName == channelName) {
      return;
    }

    _isAuthorizingRechargeChannel = true;

    try {
      final response = await dio.post(
        '$kDomainUrl/broadcasting/auth',
        data: <String, dynamic>{
          'socket_id': socketId,
          'channel_name': channelName,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        liveLog(
          '⚠️ Recharge private channel auth failed '
              '=> status:${response.statusCode} data:${response.data}',
        );
        return;
      }

      final Map<String, dynamic> authData = _decodePusherData(response.data);
      final String auth = authData['auth']?.toString().trim() ?? '';

      if (auth.isEmpty) {
        liveLog('⚠️ Recharge private channel auth response missing auth token');
        return;
      }

      final Map<String, dynamic> subscribeData = <String, dynamic>{
        'channel': channelName,
        'auth': auth,
      };

      final dynamic channelData = authData['channel_data'];
      if (channelData != null && channelData.toString().trim().isNotEmpty) {
        subscribeData['channel_data'] = channelData;
      }

      final dynamic sharedSecret = authData['shared_secret'];
      if (sharedSecret != null && sharedSecret.toString().trim().isNotEmpty) {
        subscribeData['shared_secret'] = sharedSecret;
      }

      liveStreamEventChannel!.sink.add(
        json.encode(<String, dynamic>{
          'event': 'pusher:subscribe',
          'data': subscribeData,
        }),
      );

      _rechargePendingChannelName = channelName;
      liveLog('🪙 Recharge private subscription requested => $channelName');
    } on DioException catch (e) {
      liveLog(
        '❌ Recharge private channel auth error '
            '=> ${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    } catch (e, st) {
      liveLog('❌ Recharge private channel subscribe error => $e\n$st');
    } finally {
      _isAuthorizingRechargeChannel = false;
    }
  }

  Future<void> ensureAccountBlockRealtimeSubscription() async {
    final int userId = _authRechargeUserId();
    final String token = _authRechargeToken();

    if (userId <= 0 || token.isEmpty) {
      liveLog('ℹ️ Account block realtime waiting for authenticated user');
      return;
    }

    final String expectedChannel = 'private-user-account.$userId';
    final bool alreadySubscribed =
        _accountBlockSubscribedUserId == userId &&
            _accountBlockPrivateChannelName == expectedChannel;
    final bool subscriptionPending =
        _accountBlockPendingChannelName == expectedChannel;

    if ((alreadySubscribed || subscriptionPending) &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      return;
    }

    if (liveStreamEventChannel == null ||
        liveStreamEventChannel!.closeCode != null) {
      await tryToConnectToUnifiedLiveStreamEventWs(force: false);
      return;
    }

    if (_rechargeSocketId.isEmpty) {
      liveLog('ℹ️ Account block realtime waiting for websocket socket_id');
      return;
    }

    await _authorizeAndSubscribeAccountBlockChannel(
      socketId: _rechargeSocketId,
      userId: userId,
      token: token,
    );
  }

  Future<void> _authorizeAndSubscribeAccountBlockChannel({
    required String socketId,
    required int userId,
    required String token,
  }) async {
    if (_isAuthorizingAccountBlockChannel) return;
    if (socketId.isEmpty || userId <= 0 || token.isEmpty) return;
    if (liveStreamEventChannel == null ||
        liveStreamEventChannel!.closeCode != null) {
      return;
    }

    final String channelName = 'private-user-account.$userId';

    if ((_accountBlockSubscribedUserId == userId &&
        _accountBlockPrivateChannelName == channelName) ||
        _accountBlockPendingChannelName == channelName) {
      return;
    }

    _isAuthorizingAccountBlockChannel = true;

    try {
      final response = await dio.post(
        '$kDomainUrl/broadcasting/auth',
        data: <String, dynamic>{
          'socket_id': socketId,
          'channel_name': channelName,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        liveLog(
          '⚠️ Account block private channel auth failed '
              '=> status:${response.statusCode} data:${response.data}',
        );
        return;
      }

      final Map<String, dynamic> authData = _decodePusherData(response.data);
      final String auth = authData['auth']?.toString().trim() ?? '';

      if (auth.isEmpty) {
        liveLog(
          '⚠️ Account block private channel auth response missing auth token',
        );
        return;
      }

      final Map<String, dynamic> subscribeData = <String, dynamic>{
        'channel': channelName,
        'auth': auth,
      };

      final dynamic channelData = authData['channel_data'];
      if (channelData != null && channelData.toString().trim().isNotEmpty) {
        subscribeData['channel_data'] = channelData;
      }

      final dynamic sharedSecret = authData['shared_secret'];
      if (sharedSecret != null && sharedSecret.toString().trim().isNotEmpty) {
        subscribeData['shared_secret'] = sharedSecret;
      }

      liveStreamEventChannel!.sink.add(
        json.encode(<String, dynamic>{
          'event': 'pusher:subscribe',
          'data': subscribeData,
        }),
      );

      _accountBlockPendingChannelName = channelName;
      liveLog(
        '🔐 Account block private subscription requested => $channelName',
      );
    } on DioException catch (e) {
      liveLog(
        '❌ Account block private channel auth error '
            '=> ${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    } catch (e, st) {
      liveLog('❌ Account block private channel subscribe error => $e\n$st');
    } finally {
      _isAuthorizingAccountBlockChannel = false;
    }
  }

  Future<void> ensureDeviceBlockRealtimeSubscription() async {
    if (!Get.isRegistered<DeviceIdentityService>()) {
      liveLog('ℹ️ Device block realtime waiting for device identity');
      return;
    }

    final DeviceIdentityService device = DeviceIdentityService.to;
    final String token = _authRechargeToken();
    final int deviceId = device.deviceDatabaseId;
    final String channelName = device.privateRealtimeChannel;

    if (token.isEmpty || deviceId <= 0 || channelName.isEmpty) {
      liveLog('ℹ️ Device block realtime waiting for device_session');
      return;
    }

    final bool alreadySubscribed =
        _deviceBlockSubscribedDeviceId == deviceId &&
            _deviceBlockPrivateChannelName == channelName;
    final bool subscriptionPending =
        _deviceBlockPendingChannelName == channelName;

    if ((alreadySubscribed || subscriptionPending) &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      return;
    }

    if (liveStreamEventChannel == null ||
        liveStreamEventChannel!.closeCode != null) {
      await tryToConnectToUnifiedLiveStreamEventWs(force: false);
      return;
    }

    if (_rechargeSocketId.isEmpty) {
      liveLog('ℹ️ Device block realtime waiting for websocket socket_id');
      return;
    }

    await _authorizeAndSubscribeDeviceBlockChannel(
      socketId: _rechargeSocketId,
      channelName: channelName,
      deviceId: deviceId,
      token: token,
    );
  }

  Future<void> _authorizeAndSubscribeDeviceBlockChannel({
    required String socketId,
    required String channelName,
    required int deviceId,
    required String token,
  }) async {
    if (_isAuthorizingDeviceBlockChannel) return;
    if (socketId.isEmpty ||
        channelName.isEmpty ||
        deviceId <= 0 ||
        token.isEmpty) {
      return;
    }
    if (liveStreamEventChannel == null ||
        liveStreamEventChannel!.closeCode != null) {
      return;
    }

    if ((_deviceBlockSubscribedDeviceId == deviceId &&
        _deviceBlockPrivateChannelName == channelName) ||
        _deviceBlockPendingChannelName == channelName) {
      return;
    }

    _isAuthorizingDeviceBlockChannel = true;

    try {
      final response = await dio.post(
        '$kDomainUrl/broadcasting/auth',
        data: <String, dynamic>{
          'socket_id': socketId,
          'channel_name': channelName,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        liveLog(
          '⚠️ Device block private channel auth failed '
              '=> status:${response.statusCode} data:${response.data}',
        );
        return;
      }

      final Map<String, dynamic> authData = _decodePusherData(response.data);
      final String auth = authData['auth']?.toString().trim() ?? '';

      if (auth.isEmpty) {
        liveLog(
          '⚠️ Device block private channel auth response missing auth token',
        );
        return;
      }

      final Map<String, dynamic> subscribeData = <String, dynamic>{
        'channel': channelName,
        'auth': auth,
      };

      final dynamic channelData = authData['channel_data'];
      if (channelData != null && channelData.toString().trim().isNotEmpty) {
        subscribeData['channel_data'] = channelData;
      }

      final dynamic sharedSecret = authData['shared_secret'];
      if (sharedSecret != null && sharedSecret.toString().trim().isNotEmpty) {
        subscribeData['shared_secret'] = sharedSecret;
      }

      liveStreamEventChannel!.sink.add(
        json.encode(<String, dynamic>{
          'event': 'pusher:subscribe',
          'data': subscribeData,
        }),
      );

      _deviceBlockPendingChannelName = channelName;
      liveLog('📱 Device block private subscription requested => $channelName');
    } on DioException catch (e) {
      liveLog(
        '❌ Device block private channel auth error '
            '=> ${e.response?.statusCode} ${e.response?.data ?? e.message}',
      );
    } catch (e, st) {
      liveLog('❌ Device block private channel subscribe error => $e\n$st');
    } finally {
      _isAuthorizingDeviceBlockChannel = false;
    }
  }

  Future<void> disconnectDeviceBlockRealtime() async {
    final String channelName = _deviceBlockPrivateChannelName.isNotEmpty
        ? _deviceBlockPrivateChannelName
        : _deviceBlockPendingChannelName;

    if (channelName.isNotEmpty &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      try {
        liveStreamEventChannel!.sink.add(
          json.encode(<String, dynamic>{
            'event': 'pusher:unsubscribe',
            'data': <String, dynamic>{'channel': channelName},
          }),
        );
      } catch (_) {}
    }

    _deviceBlockPrivateChannelName = '';
    _deviceBlockPendingChannelName = '';
    _deviceBlockSubscribedDeviceId = 0;
    _isAuthorizingDeviceBlockChannel = false;
  }

  bool _isDeviceBlockedEvent(String eventName, Map<String, dynamic> payload) {
    final String normalizedEvent = eventName.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );

    final String action =
    (payload['action_type'] ?? payload['action'] ?? payload['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return normalizedEvent == _deviceBlockedEventName ||
        action == _deviceBlockedActionType;
  }

  Future<void> disconnectAccountBlockRealtime() async {
    final String channelName = _accountBlockPrivateChannelName.isNotEmpty
        ? _accountBlockPrivateChannelName
        : _accountBlockPendingChannelName;

    if (channelName.isNotEmpty &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      try {
        liveStreamEventChannel!.sink.add(
          json.encode(<String, dynamic>{
            'event': 'pusher:unsubscribe',
            'data': <String, dynamic>{'channel': channelName},
          }),
        );
      } catch (_) {}
    }

    _accountBlockPrivateChannelName = '';
    _accountBlockPendingChannelName = '';
    _accountBlockSubscribedUserId = 0;
    _isAuthorizingAccountBlockChannel = false;
  }

  bool _isAccountBlockedEvent(String eventName, Map<String, dynamic> payload) {
    final String normalizedEvent = eventName.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );

    final String action =
    (payload['action_type'] ?? payload['action'] ?? payload['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final dynamic forceRaw = payload['force_logout'];
    final bool forceLogout =
        forceRaw == true ||
            forceRaw == 1 ||
            forceRaw?.toString().toLowerCase() == 'true' ||
            forceRaw?.toString() == '1';

    return normalizedEvent == _accountBlockedEventName ||
        action == _accountBlockedActionType ||
        forceLogout;
  }

  Future<void> shutdownAuthenticatedRealtimeForLogout() async {
    _unifiedDisconnectIntentional = true;
    _unifiedSocketGeneration++;
    _unifiedWsReconnectPausedByBackground = true;
    _unifiedReconnectTimer?.cancel();
    _unifiedReconnectTimer = null;

    heartbeatTimer?.cancel();
    heartbeatTimer = null;
    inactivityTimer?.cancel();
    inactivityTimer = null;

    _liveTestingMonitorTimer?.cancel();
    _liveTestingMonitorTimer = null;
    _printLiveTestingSnapshot(source: 'controller_on_close');
    _liveCallRefreshTimer?.cancel();
    _commentsRefreshTimer?.cancel();
    _giftMessagesRefreshTimer?.cancel();
    _giftTotalsRefreshTimer?.cancel();

    _cancelRedPacketTimer();
    _cancelGlobalRedPacketTimer();

    await disconnectDeviceBlockRealtime();
    await disconnectAccountBlockRealtime();
    await disconnectRechargeRealtime();

    await _cancelSocketSubscription(_unifiedSubscription, 'unified logout');
    _unifiedSubscription = null;
    await _closeSocketChannel(liveStreamEventChannel, 'unified logout');

    liveStreamEventChannel = null;
    _rechargeSocketId = '';
    streamID.value = 0;
    activeAudioStreamId.value = 0;
  }

  Future<void> disconnectRechargeRealtime() async {
    _rechargePopupRetryTimer?.cancel();
    _rechargePopupRetryTimer = null;
    _rechargePopupQueue.clear();
    _rechargePopupShowing = false;
    _processedRechargeEventIds.clear();
    _claimedRechargeEventIds.clear();

    final String channelName = _rechargePrivateChannelName;

    if (channelName.isNotEmpty &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      try {
        liveStreamEventChannel!.sink.add(
          json.encode(<String, dynamic>{
            'event': 'pusher:unsubscribe',
            'data': <String, dynamic>{'channel': channelName},
          }),
        );
      } catch (_) {}
    }

    _rechargePrivateChannelName = '';
    _rechargePendingChannelName = '';
    _rechargeSubscribedUserId = 0;
    _isAuthorizingRechargeChannel = false;
  }

  bool _isRechargeCoinEvent(String eventName, Map<String, dynamic> payload) {
    final String normalizedEvent = eventName.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );

    final String action =
    (payload['action_type'] ?? payload['action'] ?? payload['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return normalizedEvent == _rechargeEventName ||
        action == _rechargeActionType;
  }

  Future<void> _handleRechargeCoinUpdated(Map<String, dynamic> payload) async {
    final String wallet = (payload['wallet'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // Only real "coins" recharge is accepted.
    // earned_coins and every other wallet/event are intentionally ignored.
    if (wallet != 'coins') return;

    final int currentUserId = _authRechargeUserId();
    final int eventUserId = _toInt(payload['user_id']);

    if (currentUserId <= 0 ||
        eventUserId <= 0 ||
        currentUserId != eventUserId) {
      return;
    }

    final int addedCoins = _toInt(payload['added_coins']);
    final int oldCoins = _toInt(payload['old_coins']);
    final int newCoins = _toInt(payload['new_coins']);

    if (addedCoins <= 0 || newCoins < oldCoins) return;

    String eventId = payload['event_id']?.toString().trim() ?? '';
    if (eventId.isEmpty) {
      eventId =
      '${eventUserId}_${payload['source']}_${payload['created_at']}_'
          '${addedCoins}_$newCoins';
    }

    if (_processedRechargeEventIds.contains(eventId)) {
      liveLog('ℹ️ Duplicate recharge event ignored => $eventId');
      return;
    }

    _processedRechargeEventIds.add(eventId);

    // Keep memory bounded even after a very long app session.
    if (_processedRechargeEventIds.length > 120) {
      final List<String> oldest = _processedRechargeEventIds.take(40).toList();
      _processedRechargeEventIds.removeAll(oldest);
    }

    // Backend already credited the recharge safely. Flutter keeps this event
    // pending until the user taps Claim, then only the local auth coin UI/cache
    // is activated. earnedCoins and all other wallets remain untouched.
    _rechargePopupQueue.add(<String, dynamic>{
      ...payload,
      'event_id': eventId,
      'added_coins': addedCoins,
      'new_coins': newCoins,
    });

    liveLog(
      '🪙 Recharge coin received; waiting for Claim '
          '=> +$addedCoins balance:$newCoins source:${payload['source']}',
    );

    _drainRechargePopupQueue();
  }

  Future<void> _applyClaimedRechargeCoin(Map<String, dynamic> event) async {
    final String eventId = event['event_id']?.toString().trim() ?? '';

    if (eventId.isNotEmpty && _claimedRechargeEventIds.contains(eventId)) {
      liveLog('ℹ️ Recharge Claim already applied => $eventId');
      return;
    }

    final user = authController.userProfile.value.user;
    if (user == null) {
      throw StateError('Authenticated user is unavailable.');
    }

    final int addedCoins = _toInt(event['added_coins']);
    final int newCoins = _toInt(event['new_coins']);
    final int currentLocalCoins = _toInt(user.coins);

    if (addedCoins <= 0 || newCoins < 0) {
      throw StateError('Invalid recharge coin payload.');
    }

    // Never reduce a newer balance if multiple recharge events were received
    // or auth refresh already loaded a later server balance.
    final int safeBalance = newCoins > currentLocalCoins
        ? newCoins
        : currentLocalCoins;

    // Only the normal coins wallet is updated here.
    // earnedCoins and every other user balance remain unchanged.
    user.coins = safeBalance.toString();
    authController.userProfile.refresh();

    try {
      await authController.preferences.setString(
        'profile',
        jsonEncode(authController.userProfile.value.toJson()),
      );
    } catch (e) {
      // The in-memory UI update is already successful. A cache write problem
      // must not make the user press Claim twice or lose the recharge popup.
      liveLog('⚠️ Claimed recharge profile persistence skipped => $e');
    }

    if (eventId.isNotEmpty) {
      _claimedRechargeEventIds.add(eventId);

      if (_claimedRechargeEventIds.length > 120) {
        final List<String> oldest = _claimedRechargeEventIds.take(40).toList();
        _claimedRechargeEventIds.removeAll(oldest);
      }
    }

    liveLog(
      '✅ Recharge coin activated after Claim '
          '=> +$addedCoins balance:$safeBalance source:${event['source']}',
    );
  }

  void pauseRechargePopupForBackground() {
    _rechargeUiPaused = true;
    _rechargePopupRetryTimer?.cancel();
    _rechargePopupRetryTimer = null;
  }

  void resumeRechargePopupAfterForeground() {
    _rechargeUiPaused = false;
    ensureRechargeRealtimeSubscription();
    _drainRechargePopupQueue();
  }

  void _scheduleRechargePopupRetry() {
    if (_rechargePopupRetryTimer?.isActive == true) return;

    _rechargePopupRetryTimer = Timer(
      const Duration(milliseconds: 700),
      _drainRechargePopupQueue,
    );
  }

  Future<void> _drainRechargePopupQueue() async {
    if (_rechargePopupShowing ||
        _rechargeUiPaused ||
        _rechargePopupQueue.isEmpty) {
      return;
    }

    if (Get.context == null || Get.isDialogOpen == true) {
      _scheduleRechargePopupRetry();
      return;
    }

    final Map<String, dynamic> event = Map<String, dynamic>.from(
      _rechargePopupQueue.removeAt(0),
    );

    _rechargePopupShowing = true;

    try {
      await Get.generalDialog(
        barrierDismissible: false,
        barrierLabel: 'Recharge Coin',
        barrierColor: Colors.black.withValues(alpha: .58),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) {
          return RechargeCoinPopup(
            addedCoins: _toInt(event['added_coins']),
            newCoins: _toInt(event['new_coins']),
            source: event['source']?.toString() ?? '',
            onClaim: () => _applyClaimedRechargeCoin(event),
          );
        },
        transitionBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
    } catch (e) {
      liveLog('⚠️ Recharge popup show skipped => $e');
    } finally {
      _rechargePopupShowing = false;

      if (_rechargePopupQueue.isNotEmpty) {
        Future<void>.delayed(
          const Duration(milliseconds: 260),
          _drainRechargePopupQueue,
        );
      }
    }
  }

  /// Backend channel name. If backend developer uses a different channel,
  /// only change this string.
  final String liveStreamEventChannelName = 'live-stream-event';

  /// BIGO-style background rule:
  /// App minimize/background hole websocket reconnect spam korbe na.
  /// Live room/Agora/heartbeat keep thakbe; foreground e fire back korle
  /// ekbar safe reconnect korbe.
  bool _unifiedWsReconnectPausedByBackground = false;
  int _unifiedWsReconnectAttempt = 0;

  void pauseUnifiedLiveStreamReconnectForBackground() {
    _unifiedWsReconnectPausedByBackground = true;
    pauseRechargePopupForBackground();
    _unifiedReconnectTimer?.cancel();
    _unifiedReconnectTimer = null;
    _cancelRedPacketTimer();
    _cancelGlobalRedPacketTimer();
    liveLog(
      '⏸️ Unified LiveStreamEvent reconnect paused: app background/minimized',
    );
  }

  void resumeUnifiedLiveStreamReconnectAfterForeground() {
    final wasPaused = _unifiedWsReconnectPausedByBackground;
    _unifiedWsReconnectPausedByBackground = false;
    _unifiedWsReconnectAttempt = 0;
    liveLog('▶️ Unified LiveStreamEvent reconnect resumed: foreground');

    if (wasPaused) {
      tryToConnectToUnifiedLiveStreamEventWs(force: false);
    }

    resumeRechargePopupAfterForeground();
  }

  bool _isSeatLockAuthoritativeSource(String source) {
    final s = source.toLowerCase();

    /// Only real seat-lock/live-state endpoints/events may mutate lock map.
    /// viewer_join/comment/gift/old init snapshots often contain stale locked_seats.
    return s.contains('seat_lock') ||
        s.contains('seat_unlock') ||
        s.contains('available_seats') ||
        s.contains('livestream_state_updated') ||
        s.contains('live_state_updated') ||
        s.contains('room_state_updated');
  }

  bool _shouldIgnoreSeatLocksFromSource(String source) {
    final s = source.toLowerCase();

    return s.contains('viewer_add') ||
        s.contains('viewer_join') ||
        s.contains('live_comment') ||
        s.contains('gift') ||
        s.contains('audio_init_args') ||
        s.contains('audio_stream_info') ||
        s.contains('audio_broadcaster_data') ||
        s.contains('livestream_controller_apply_state');
  }

  Future<void> tryToConnectToUnifiedLiveStreamEventWs({
    bool force = false,
  }) async {
    if (_socketLifecycleClosed || _unifiedDisconnectIntentional) return;
    if (_unifiedWsReconnectPausedByBackground) {
      liveLog(
        '⏸️ Unified LiveStreamEvent connect skipped: app background/minimized',
      );
      return;
    }

    if (_isConnectingUnifiedWs) {
      liveLog('ℹ️ Unified LiveStreamEvent WS already connecting...');
      return;
    }

    if (!force &&
        liveStreamEventChannel != null &&
        liveStreamEventChannel!.closeCode == null) {
      liveLog('ℹ️ Unified LiveStreamEvent WS already connected/open');
      return;
    }

    liveLog(
      '⚡ Trying to connect to unified LiveStreamEvent WS... force=$force url=$kWsUrl',
    );
    LiveTestingLogger.printBlock('LIVE TEST WS CONNECT START', {
      'time': DateTime.now().toIso8601String(),
      'force': force,
      'url': kWsUrl,
      'channel': liveStreamEventChannelName,
      'generation_next': _unifiedSocketGeneration + 1,
      'current_stream_id': streamID.value,
      'active_audio_stream_id': activeAudioStreamId.value,
    });

    if (kWsUrl.isEmpty) {
      liveLog('❌ WebSocket URL is empty, cannot connect to LiveStreamEvent');
      return;
    }

    _isConnectingUnifiedWs = true;
    final int generation = ++_unifiedSocketGeneration;
    _unifiedReconnectTimer?.cancel();
    _unifiedReconnectTimer = null;
    _unifiedReconnectScheduledForGeneration = null;
    _cancelRedPacketTimer();
    _cancelGlobalRedPacketTimer();

    _rechargeSocketId = '';
    _rechargePrivateChannelName = '';
    _rechargePendingChannelName = '';
    _rechargeSubscribedUserId = 0;
    _isAuthorizingRechargeChannel = false;

    _accountBlockPrivateChannelName = '';
    _accountBlockPendingChannelName = '';
    _accountBlockSubscribedUserId = 0;
    _isAuthorizingAccountBlockChannel = false;

    await _cancelSocketSubscription(_unifiedSubscription, 'unified');
    _unifiedSubscription = null;
    final WebSocketChannel? previousChannel = liveStreamEventChannel;
    liveStreamEventChannel = null;
    await _closeSocketChannel(previousChannel, 'unified replacement');

    late final WebSocketChannel localChannel;
    try {
      localChannel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      liveStreamEventChannel = localChannel;
      await localChannel.ready;
      if (_socketLifecycleClosed ||
          _unifiedDisconnectIntentional ||
          generation != _unifiedSocketGeneration ||
          liveStreamEventChannel != localChannel) {
        await _closeSocketChannel(localChannel, 'stale unified connect');
        return;
      }

      _unifiedWsReconnectAttempt = 0;
      liveLog('✅ Connected to unified LiveStreamEvent WebSocket');
      LiveTestingLogger.printBlock('LIVE TEST WS CONNECTED', {
        'time': DateTime.now().toIso8601String(),
        'url': kWsUrl,
        'generation': generation,
        'channel': liveStreamEventChannelName,
      });

      _unifiedSubscription = localChannel.stream.listen(
            (message) {
          if (generation != _unifiedSocketGeneration ||
              liveStreamEventChannel != localChannel ||
              _socketLifecycleClosed) {
            return;
          }
          _queueUnifiedSocketFrame(message);
        },
        onError: (error) {
          liveLog('❌ Unified LiveStreamEvent WS error: $error');
          LiveTestingLogger.printBlock('LIVE TEST WS ERROR', {
            'time': DateTime.now().toIso8601String(),
            'generation': generation,
            'error': error.toString(),
            'close_code': localChannel.closeCode,
            'frames_received': _testingWsFrameCount,
          });
          _scheduleUnifiedWsReconnect(
            reason: 'onError',
            generation: generation,
          );
        },
        onDone: () {
          liveLog('⚠️ Unified LiveStreamEvent WS closed');
          LiveTestingLogger.printBlock('LIVE TEST WS CLOSED', {
            'time': DateTime.now().toIso8601String(),
            'generation': generation,
            'close_code': localChannel.closeCode,
            'close_reason': localChannel.closeReason,
            'frames_received': _testingWsFrameCount,
          });
          _scheduleUnifiedWsReconnect(reason: 'onDone', generation: generation);
        },
        cancelOnError: true,
      );

      localChannel.sink.add(
        json.encode({
          "event": "pusher:subscribe",
          "data": {"channel": liveStreamEventChannelName},
        }),
      );

      liveLog('📡 Subscribed to "$liveStreamEventChannelName" channel');
    } catch (e, st) {
      liveLog('❌ Unified LiveStreamEvent connection failed: $e');
      LiveTestingLogger.printBlock('LIVE TEST WS CONNECT FAILED', {
        'time': DateTime.now().toIso8601String(),
        'generation': generation,
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
      if (generation == _unifiedSocketGeneration) {
        liveStreamEventChannel = null;
        _scheduleUnifiedWsReconnect(reason: 'catch', generation: generation);
      }
    } finally {
      if (generation == _unifiedSocketGeneration) {
        _isConnectingUnifiedWs = false;
      }
    }
  }

  bool _isNormalGiftFastLaneFrame(dynamic message) {
    final String compact = message
        .toString()
        .toLowerCase()
    // Pusher often wraps event data as an escaped JSON string. Remove the
    // escape slashes so Lucky markers are detected before choosing a queue.
    // This keeps the already-working Lucky gift/result order untouched.
        .replaceAll('\\', '')
        .replaceAll(RegExp(r'\s+'), '');

    final bool isGiftAction =
        compact.contains('gift_sent') ||
            compact.contains('gift-sent') ||
            compact.contains('giftsent') ||
            compact.contains('pk_gift_received') ||
            compact.contains('pk_gift_score_updated');

    if (!isGiftAction) return false;

    // Keep the already-working Lucky result/card path on the original queue.
    final bool isLucky =
        compact.contains('lucky_gift_result') ||
            compact.contains('"action_type":"lucky') ||
            compact.contains('"is_lucky_gift":true') ||
            compact.contains('"is_lucky_gift":1') ||
            compact.contains('"is_lucky":true') ||
            compact.contains('"is_lucky":1') ||
            compact.contains('"category":"lucky"') ||
            compact.contains('"gift_category":"lucky"') ||
            compact.contains('"lucky_ratio"') ||
            compact.contains('"lucky_coin"') ||
            compact.contains('"back_coin"');

    return !isLucky;
  }

  void _queueUnifiedSocketFrame(dynamic message) {
    if (_isNormalGiftFastLaneFrame(message)) {
      _normalGiftRealtimeEventQueue = _normalGiftRealtimeEventQueue
          .then((_) => _handleUnifiedLiveStreamMessage(message))
          .catchError((Object error, StackTrace stackTrace) {
        liveLog(
          '❌ Normal gift realtime fast-lane error: $error\n$stackTrace',
        );
      });
      return;
    }

    _unifiedEventQueue = _unifiedEventQueue
        .then((_) => _handleUnifiedLiveStreamMessage(message))
        .catchError((Object error, StackTrace stackTrace) {
      liveLog('❌ Unified event queue error: $error\n$stackTrace');
    });
  }

  void _scheduleUnifiedWsReconnect({
    required String reason,
    required int generation,
  }) {
    if (_socketLifecycleClosed ||
        _unifiedDisconnectIntentional ||
        generation != _unifiedSocketGeneration ||
        _unifiedReconnectScheduledForGeneration == generation) {
      return;
    }
    if (_unifiedWsReconnectPausedByBackground) {
      liveLog(
        '⏸️ Unified LiveStreamEvent reconnect skipped after $reason: background/minimized',
      );
      return;
    }

    _unifiedReconnectTimer?.cancel();
    _unifiedReconnectScheduledForGeneration = generation;

    _unifiedWsReconnectAttempt++;
    final delaySeconds = (_unifiedWsReconnectAttempt * 3).clamp(3, 30);

    _unifiedReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _unifiedReconnectTimer = null;
      _unifiedReconnectScheduledForGeneration = null;
      if (_socketLifecycleClosed ||
          _unifiedDisconnectIntentional ||
          generation != _unifiedSocketGeneration ||
          _unifiedWsReconnectPausedByBackground) {
        liveLog(
          '⏸️ Unified LiveStreamEvent reconnect timer ignored: background/minimized',
        );
        return;
      }

      liveLog(
        '🔄 Reconnecting unified LiveStreamEvent WS after $reason... attempt=$_unifiedWsReconnectAttempt delay=${delaySeconds}s',
      );
      tryToConnectToUnifiedLiveStreamEventWs(force: true);
    });
  }

  Future<void> _handleUnifiedLiveStreamMessage(dynamic message) async {
    final int eventSequence = LiveTestingLogger.nextEventSequence();
    final Stopwatch eventStopwatch = Stopwatch()..start();
    _testingWsFrameCount++;
    _lastTestingWsFrameAtMs = DateTime.now().millisecondsSinceEpoch;
    lastActivityTime.value = DateTime.now();
    isUserActive.value = true;

    try {
      final String rawMessageText = message.toString();
      final String rawMessageLower = rawMessageText.toLowerCase();

      if (rawMessageLower.contains('gift') ||
          rawMessageLower.contains('lucky') ||
          rawMessageLower.contains('multiplier') ||
          rawMessageLower.contains('win_amount') ||
          rawMessageLower.contains('back_coin') ||
          rawMessageLower.contains('gift_id')) {
        _forceGiftPrint('GIFT WEBSOCKET RAW MESSAGE BEFORE JSON DECODE', {
          'runtime_type': message.runtimeType.toString(),
          'raw_message': rawMessageText,
        });
      }

      final decodedMessage = _safeJsonDecode(message);

      if (decodedMessage is! Map) {
        liveLog('⚠️ Unified message is not Map: $decodedMessage');
        return;
      }

      final eventName = decodedMessage['event']?.toString() ?? '';

      if (eventName.startsWith('pusher') && eventName != 'pusher:ping') {
        LiveTestingLogger.printBlock(
          'LIVE TEST WS SYSTEM EVENT #$eventSequence [$eventName]',
          {
            'time': DateTime.now().toIso8601String(),
            'event': eventName,
            'channel': decodedMessage['channel'],
            'data': decodedMessage['data'],
          },
        );
      }

      /// Pusher system events. These are normal, not app events.
      if (eventName == "pusher:ping") {
        _testingPusherPingCount++;
        LiveTestingLogger.printBlock('LIVE TEST WS PUSHER PING #$eventSequence', {
          'time': DateTime.now().toIso8601String(),
          'event': eventName,
          'frame_count': _testingWsFrameCount,
          'raw': decodedMessage,
        });
        _sendUnifiedPong();
        return;
      }

      if (eventName == "pusher:connection_established") {
        final Map<String, dynamic> connectionData = _decodePusherData(
          decodedMessage['data'],
        );
        _rechargeSocketId =
            connectionData['socket_id']?.toString().trim() ?? '';
        LiveTestingLogger.printBlock(
          'LIVE TEST WS CONNECTION ESTABLISHED #$eventSequence',
          {
            'time': DateTime.now().toIso8601String(),
            'event': eventName,
            'connection_data': connectionData,
            'socket_id': _rechargeSocketId,
          },
        );

        if (_rechargeSocketId.isNotEmpty) {
          await ensureRechargeRealtimeSubscription();
          await ensureAccountBlockRealtimeSubscription();
          await ensureDeviceBlockRealtimeSubscription();
        }
        return;
      }

      if (eventName == "pusher_internal:subscription_succeeded") {
        final String channelName =
            decodedMessage['channel']?.toString().trim() ?? '';

        if (channelName.isNotEmpty &&
            (channelName == _rechargePendingChannelName ||
                channelName.startsWith('private-user-recharge.'))) {
          _rechargePrivateChannelName = channelName;
          _rechargePendingChannelName = '';
          _rechargeSubscribedUserId = _authRechargeUserId();
          liveLog('✅ Recharge realtime subscribed => $channelName');
          return;
        }

        if (channelName.isNotEmpty &&
            (channelName == _accountBlockPendingChannelName ||
                channelName.startsWith('private-user-account.'))) {
          _accountBlockPrivateChannelName = channelName;
          _accountBlockPendingChannelName = '';
          _accountBlockSubscribedUserId = _authRechargeUserId();
          liveLog('✅ Account block realtime subscribed => $channelName');
          return;
        }

        if (channelName.isNotEmpty &&
            (channelName == _deviceBlockPendingChannelName ||
                channelName.startsWith('private-user-device.'))) {
          _deviceBlockPrivateChannelName = channelName;
          _deviceBlockPendingChannelName = '';
          _deviceBlockSubscribedDeviceId =
          Get.isRegistered<DeviceIdentityService>()
              ? DeviceIdentityService.to.deviceDatabaseId
              : 0;
          liveLog('✅ Device block realtime subscribed => $channelName');
        }
        return;
      }

      if (eventName == 'pusher:subscription_error' ||
          eventName == 'pusher:error') {
        final Map<String, dynamic> errorData = _decodePusherData(
          decodedMessage['data'],
        );
        final String channelName =
        (decodedMessage['channel'] ?? errorData['channel'] ?? '')
            .toString()
            .trim();

        final bool rechargeError =
            channelName.isEmpty ||
                channelName == _rechargePendingChannelName ||
                channelName.startsWith('private-user-recharge.');
        final bool accountError =
            channelName.isEmpty ||
                channelName == _accountBlockPendingChannelName ||
                channelName.startsWith('private-user-account.');
        final bool deviceError =
            channelName.isEmpty ||
                channelName == _deviceBlockPendingChannelName ||
                channelName.startsWith('private-user-device.');

        if (rechargeError) {
          _rechargePendingChannelName = '';
          _rechargePrivateChannelName = '';
          _rechargeSubscribedUserId = 0;
          liveLog(
            '⚠️ Recharge private subscription rejected '
                '=> channel:$channelName data:$errorData',
          );
        }

        if (accountError) {
          _accountBlockPendingChannelName = '';
          _accountBlockPrivateChannelName = '';
          _accountBlockSubscribedUserId = 0;
          liveLog(
            '⚠️ Account block private subscription rejected '
                '=> channel:$channelName data:$errorData',
          );
        }

        if (deviceError) {
          _deviceBlockPendingChannelName = '';
          _deviceBlockPrivateChannelName = '';
          _deviceBlockSubscribedDeviceId = 0;
          liveLog(
            '⚠️ Device block private subscription rejected '
                '=> channel:$channelName data:$errorData',
          );
        }
        return;
      }

      if (eventName.startsWith("pusher_internal:")) {
        return;
      }

      final payload = _extractUnifiedPayload(decodedMessage);

      // DEBUG V2: Capture raw frames even when action_type is missing or uses
      // a backend-specific name. This guarantees Lucky data is not skipped.
      final String rawGiftTraceText = decodedMessage.toString().toLowerCase();
      if (rawGiftTraceText.contains('gift') ||
          rawGiftTraceText.contains('lucky') ||
          rawGiftTraceText.contains('multiplier') ||
          rawGiftTraceText.contains('win_amount') ||
          rawGiftTraceText.contains('back_coin')) {
        _forceGiftPrint('🎁 ALL GIFT WEBSOCKET FRAME RAW BEFORE PARSE', {
          'event_name': eventName,
          'decoded_message': decodedMessage,
          'extracted_payload': payload,
        });
      }

      if (payload.isEmpty) {
        liveLog(
          '⚠️ Unified payload empty. event=$eventName message=$decodedMessage',
        );
        return;
      }

      if (_isDeviceBlockedEvent(eventName, payload)) {
        if (!Get.isRegistered<DeviceIdentityService>() ||
            DeviceIdentityService.to.payloadTargetsCurrentDevice(payload)) {
          await authController.handleDeviceBlockedPayload(payload);
        }
        return;
      }

      if (_isAccountBlockedEvent(eventName, payload)) {
        await authController.handleAccountBlockedPayload(payload);
        return;
      }

      if (_isRechargeCoinEvent(eventName, payload)) {
        await _handleRechargeCoinUpdated(payload);
        return;
      }

      String actionType =
      (payload['action_type'] ??
          payload['action_type'.toString()] ??
          payload['action'] ??
          payload['type'] ??
          '')
          .toString()
          .trim();

      /// Some backend events come with event name only, without action_type in data.
      /// Example: event="live-stream-updated" or "App\\Events\\LiveStreamUpdated".
      /// In that case map eventName to our unified action_type.
      if (actionType.isEmpty) {
        actionType = _actionTypeFromEventName(eventName);
      }

      if (actionType.isEmpty) {
        liveLog(
          'ℹ️ Non LiveStreamEvent ignored. event=$eventName payload=$payload',
        );
        return;
      }

      /// Put inferred action_type back into payload so handlers can debug/parse same way.
      payload['action_type'] ??= actionType;

      actionType = actionType.toLowerCase().trim();
      payload['action_type'] = actionType;

      liveLog('✅ LiveStreamEvent action_type: $actionType');

      final dynamic eventLastPingAt = LiveTestingLogger.findFirstByKeys(
        payload,
        const <String>[
          'last_ping_at',
          'last_ping',
          'ping_at',
          'last_seen_at',
        ],
      );
      final bool isGiftLikeForTesting = actionType.contains('gift') ||
          actionType.contains('lucky') ||
          payload.containsKey('gift') ||
          payload.containsKey('gift_data') ||
          payload.containsKey('lucky_result');
      final Map<String, dynamic> testingNestedData = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};
      final Map<String, dynamic> testingGiftData = payload['gift'] is Map
          ? Map<String, dynamic>.from(payload['gift'])
          : <String, dynamic>{};
      LiveTestingLogger.printBlock(
        'LIVE TEST EVENT RECEIVED #$eventSequence [$actionType]',
        {
          'time': DateTime.now().toIso8601String(),
          'event_name': eventName,
          'action_type': actionType,
          'stream_id': payload['livestream_id'] ??
              payload['stream_id'] ??
              payload['live_id'] ??
              testingNestedData['livestream_id'],
          'user_id': payload['user_id'] ??
              payload['caller_id'] ??
              payload['viewer_id'] ??
              testingNestedData['user_id'],
          'call_status': payload['call_status'] ??
              payload['status'] ??
              testingNestedData['call_status'],
          'last_ping_at': eventLastPingAt,
          'last_ping_age_seconds':
          LiveTestingLogger.ageSeconds(eventLastPingAt),
          'payload_keys': payload.keys.toList(),
          'payload': isGiftLikeForTesting
              ? {
            'summary_only_for_performance': true,
            'gift_id': payload['gift_id'] ?? testingGiftData['id'],
            'sender_id': payload['sender_id'] ?? payload['user_id'],
            'receiver_id': payload['receiver_id'] ??
                payload['target_user_id'],
            'quantity': payload['quantity'] ?? payload['count'],
            'coin': payload['coin'] ?? payload['gift_coin'],
            'keys': payload.keys.toList(),
          }
              : payload,
        },
        maxChars: isGiftLikeForTesting ? 7000 : 16000,
      );

      final bool debugGiftLikeEvent =
          actionType.contains('gift') ||
              actionType.contains('lucky') ||
              payload.containsKey('gift') ||
              payload.containsKey('gift_data') ||
              payload.containsKey('gift_info') ||
              payload.containsKey('lucky_result') ||
              payload.containsKey('lucky_results') ||
              payload.containsKey('multiplier') ||
              payload.containsKey('win_amount') ||
              payload.containsKey('back_coin');

      if (debugGiftLikeEvent) {
        _forceGiftPrint('🎁 ALL GIFT UNIFIED EVENT PARSED', {
          'event_name': eventName,
          'action_type': actionType,
          'decoded_message': decodedMessage,
          'payload': payload,
          'payload_keys': payload.keys.toList(),
          'current_stream_id': streamID.value,
          'active_audio_stream_id': activeAudioStreamId.value,
          'livestream_controller_stream_id':
          livestreamController.streamId.value,
        });
      }

      if (actionType == 'lucky_gift_result' ||
          actionType == 'lucky_gift_back_coin' ||
          actionType.contains('lucky')) {
        _forceGiftPrint('🍀 LUCKY UNIFIED WEBSOCKET EVENT FULL DATA', {
          'event_name': eventName,
          'action_type': actionType,
          'decoded_message': decodedMessage,
          'extracted_payload': payload,
          'current_stream_id': streamID.value,
          'active_audio_stream_id': activeAudioStreamId.value,
          'livestream_controller_stream_id':
          livestreamController.streamId.value,
        });
      }

      /// ✅ IMPORTANT: Global Lucky Bag must be handled BEFORE the cross-room guard.
      /// When user is on Home/BottomNav, current stream is 0, so the old guard ignored
      /// red_packet_sent events from other rooms and the app-wide banner never showed.
      if (actionType == 'red_packet_sent') {
        try {
          final Map<String, dynamic> preGuardPacket = _normalizeRedPacket(
            payload,
          );
          final bool isGlobalLuckyBag =
              preGuardPacket.isNotEmpty &&
                  _redPacketTruthy(preGuardPacket['is_global']);

          liveLog(
            '🧧 Global Lucky Bag pre-guard => '
                'global:$isGlobalLuckyBag id:${preGuardPacket['id']} '
                'stream:${preGuardPacket['livestream_id']}',
          );

          if (isGlobalLuckyBag) {
            livestreamController.redPacketController
                .handleRedPacketSentForGlobalBanner(payload);
          }
        } catch (e) {
          liveLog('⚠️ Global Lucky Bag pre-guard handler failed => $e');
        }
      }

      /// 50x+ Lucky banner is app-wide and must be handled before the
      /// cross-room guard. Backend can place the result in lucky_gift_result,
      /// gift_sent.big_win_events, gift_sent.lucky_results or direct fields.
      final bool globalLuckyCandidate =
          actionType.contains('gift') ||
              actionType.contains('lucky') ||
              payload['lucky_result'] is Map ||
              (payload['lucky_results'] is List &&
                  (payload['lucky_results'] as List).isNotEmpty) ||
              (payload['big_win_events'] is List &&
                  (payload['big_win_events'] as List).isNotEmpty) ||
              payload['multiplier'] != null ||
              payload['win_amount'] != null ||
              payload['back_coin'] != null;
      if (globalLuckyCandidate) {
        try {
          livestreamController.showGlobalLuckyWinBannerFromPayload(payload);
        } catch (e) {
          liveLog('⚠️ Global Lucky win pre-guard failed => $e');
        }
      }

      /// Cross-room guard:
      /// Onno broadcaster-er event current audio room-e apply hobe na.
      /// Missing livestream_id thakle existing handler-specific fallback cholbe,
      /// but explicit wrong id thakle ekhanei drop.
      final int eventStreamId = _eventLivestreamId(payload);
      final bool allowGlobalAction =
          actionType == 'live_stream_created' ||
              actionType == 'permanent_room_rejoined' ||
              actionType == 'live_stream_list';
      if (eventStreamId > 0 &&
          !allowGlobalAction &&
          !_isCurrentStream(eventStreamId)) {
        liveLog(
          '⛔ LiveStreamEvent ignored: other stream event=$eventStreamId current=$streamID/${activeAudioStreamId.value}/${livestreamController.streamId.value} action=$actionType',
        );
        return;
      }

      await _dispatchLiveStreamAction(actionType, payload);
    } catch (e, st) {
      liveLog('❌ Error handling unified LiveStreamEvent: $e\n$st');
      LiveTestingLogger.printBlock(
        'LIVE TEST EVENT ERROR #$eventSequence',
        {
          'elapsed_ms': eventStopwatch.elapsedMilliseconds,
          'error': e.toString(),
          'stack_trace': st.toString(),
          'raw_message': message.toString(),
        },
      );
    } finally {
      eventStopwatch.stop();
      LiveTestingLogger.line(
        '🧪 EVENT COMPLETE #$eventSequence => ${eventStopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  String _actionTypeFromEventName(String eventName) {
    final e = eventName.toLowerCase().replaceAll('\\\\', '\\');

    if (e.contains('livestreamupdated') ||
        e.contains('live_stream_updated') ||
        e.contains('live-stream-updated') ||
        e.contains('livestream-updated')) {
      return 'live_stream_updated';
    }

    if (e.contains('livestreamcreated') ||
        e.contains('live_stream_created') ||
        e.contains('live-stream-created')) {
      return 'live_stream_created';
    }

    if (e.contains('livestreamended') ||
        e.contains('live_stream_ended') ||
        e.contains('live-stream-ended')) {
      return 'live_stream_ended';
    }

    if (e.contains('roomsettingsupdated') ||
        e.contains('room_settings_updated') ||
        e.contains('room-settings-updated')) {
      return 'room_settings_updated';
    }

    if (e.contains('livecommentlockupdated') ||
        e.contains('live_comment_lock_updated') ||
        e.contains('comment_lock_updated')) {
      return 'live_comment_lock_updated';
    }

    if (e.contains('livehiddenroomupdated') ||
        e.contains('live_hidden_room_updated') ||
        e.contains('hidden_room_updated')) {
      return 'live_hidden_room_updated';
    }

    if (e.contains('livescreensettingupdated') ||
        e.contains('live_screen_setting_updated') ||
        e.contains('screen_setting_updated')) {
      return 'live_screen_setting_updated';
    }

    if (e.contains('clearlivecomments') ||
        e.contains('clear_live_comments') ||
        e.contains('live_comments_cleared')) {
      return 'clear_live_comments';
    }

    if (e.contains('livemusic') || e.contains('live_music')) {
      return 'live_music';
    }

    if (e.contains('liveyoutube') || e.contains('live_youtube')) {
      return 'live_youtube';
    }

    if (e.contains('seatlock') || e.contains('seat_lock_toggle')) {
      return 'seat_lock_toggle';
    }

    if (e.contains('seatswitched') ||
        e.contains('seat_switched') ||
        e.contains('seat-switched')) {
      return 'seat_switched';
    }

    return '';
  }

  void _sendUnifiedPong() {
    try {
      if (liveStreamEventChannel != null &&
          liveStreamEventChannel!.closeCode == null) {
        liveStreamEventChannel!.sink.add(json.encode({"event": "pusher:pong"}));
        _testingPusherPongCount++;
        LiveTestingLogger.line(
          '🏓 LIVE TEST WS PONG SENT => count=$_testingPusherPongCount time=${DateTime.now().toIso8601String()}',
        );
      }
    } catch (e) {
      liveLog('❌ Unified pong error: $e');
    }
  }

  dynamic _safeJsonDecode(dynamic value) {
    dynamic result = value;

    for (int i = 0; i < 6; i++) {
      if (result is String) {
        result = json.decode(result);
      } else {
        break;
      }
    }

    return result;
  }

  Map<String, dynamic> _extractUnifiedPayload(Map decodedMessage) {
    dynamic rawData = decodedMessage['data'];
    dynamic data = _tryDecodeDeep(rawData);

    /// New flat backend format after broadcastWith() returns $this->data:
    /// {"action_type":"live_stream_updated", "data": {...}}
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);

      if (dataMap['action_type'] != null ||
          dataMap['action'] != null ||
          dataMap['type'] != null) {
        return dataMap;
      }

      /// Old Laravel LiveStreamEvent format:
      /// {"data": {"action_type":"moderation", ...}}
      if (dataMap['data'] is Map) {
        final inner = Map<String, dynamic>.from(dataMap['data']);

        if (inner['action_type'] != null ||
            inner['action'] != null ||
            inner['type'] != null) {
          liveLog('🧪 EXTRACT returned inner with action_type => $inner');
          return inner;
        }

        if (inner['data'] is Map) {
          final deep = Map<String, dynamic>.from(inner['data']);

          if (deep['action_type'] != null ||
              deep['action'] != null ||
              deep['type'] != null) {
            liveLog('🧪 EXTRACT returned deep with action_type => $deep');
            return deep;
          }

          liveLog('🧪 EXTRACT returned deep data without action_type => $deep');
          return deep;
        }

        liveLog('🧪 EXTRACT returned inner without action_type => $inner');
        return inner;
      }

      liveLog('🧪 EXTRACT returned dataMap without action_type => $dataMap');
      return dataMap;
    }

    /// Rare case: action_type is directly on decodedMessage.
    if (decodedMessage['action_type'] != null ||
        decodedMessage['action'] != null ||
        decodedMessage['type'] != null) {
      final direct = Map<String, dynamic>.from(decodedMessage);
      liveLog('🧪 EXTRACT returned decodedMessage direct => $direct');
      return direct;
    }

    liveLog('⚠️ EXTRACT failed, no payload map found. rawData=$rawData');
    return {};
  }

  dynamic _tryDecodeDeep(dynamic value) {
    dynamic result = value;

    for (int i = 0; i < 6; i++) {
      if (result is String) {
        try {
          result = json.decode(result);
        } catch (_) {
          break;
        }
      } else {
        break;
      }
    }

    return result;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _hasUsefulProfileValue(dynamic value) {
    if (value == null) return false;
    final v = value.toString().trim();
    return v.isNotEmpty && v.toLowerCase() != 'null' && v != '0';
  }

  int _profileIdFromMap(Map user) {
    return _toInt(
      user['id'] ?? user['user_id'] ?? user['viewer_id'] ?? user['caller_id'],
    );
  }

  void _cacheLiveUserProfile(dynamic rawUser) {
    if (rawUser is! Map) return;
    final int uid = _profileIdFromMap(rawUser);
    if (uid <= 0) return;

    final incoming = Map<String, dynamic>.from(rawUser);
    final old = _liveUserProfileCache[uid] ?? <String, dynamic>{};
    final merged = Map<String, dynamic>.from(old);

    incoming.forEach((key, value) {
      if (_hasUsefulProfileValue(value) || value is Map || value is List) {
        merged[key.toString()] = value;
      }
    });

    merged['id'] = uid;
    merged['user_id'] = merged['user_id'] ?? uid;

    final hasFrameData =
        merged['asset_purchase_history'] is Map ||
            merged['asset_purchase_history'] is List ||
            merged['asset_purchase_histories'] is Map ||
            merged['asset_purchase_histories'] is List ||
            merged['profile_frame_history'] is Map ||
            merged['profile_frame_history'] is List ||
            merged['profile_frame'] != null ||
            merged['profileFrame'] != null ||
            merged['active_frame'] != null ||
            merged['avatar_frame'] != null ||
            merged['frame'] != null;

    if (_hasUsefulProfileValue(merged['name']) ||
        _hasUsefulProfileValue(merged['profile_image']) ||
        _hasUsefulProfileValue(merged['level']) ||
        hasFrameData) {
      _liveUserProfileCache[uid] = merged;
    }
  }

  Map<String, dynamic> _mergeWithCachedLiveUserProfile({
    required int userId,
    dynamic rawUser,
  }) {
    final cached = _liveUserProfileCache[userId] ?? <String, dynamic>{};
    final incoming = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    final merged = Map<String, dynamic>.from(cached);

    incoming.forEach((key, value) {
      if (_hasUsefulProfileValue(value) || value is Map || value is List) {
        merged[key.toString()] = value;
      }
    });

    merged['id'] = userId;
    merged['user_id'] = merged['user_id'] ?? userId;
    merged['name'] = _hasUsefulProfileValue(merged['name'])
        ? merged['name']
        : 'User';
    merged['level'] = _hasUsefulProfileValue(merged['level'])
        ? merged['level']
        : 0;
    merged['profile_image'] = _hasUsefulProfileValue(merged['profile_image'])
        ? merged['profile_image']
        : '';

    _cacheLiveUserProfile(merged);
    return merged;
  }

  /// Merge accepted mic/seat callers without losing profile frame/name/id.
  /// Backend resume/addViewer snapshots sometimes return only caller_id/seat_no.
  /// If we assignAll() that partial list, seated audience frame/name disappears.
  /// This method keeps previous complete `user` data and only updates real fields.
  void mergeLiveCallListPreservingProfiles(
      List<Map<String, dynamic>> incoming, {
        String source = 'unknown',
        bool clearWhenExplicitEmpty = false,
      }) {
    try {
      if (incoming.isEmpty) {
        if (clearWhenExplicitEmpty) {
          final int beforeCount = liveCallList.length;
          liveCallList.clear();
          pendingCall.clear();
          _refreshLiveCallListSmooth();
          pendingCall.refresh();
          printSeatTrace(
            'snapshot_explicit_clear',
            beforeCount: beforeCount,
            afterCount: liveCallList.length,
            reason: source,
          );
        } else {
          liveLog(
            'ℹ️ Empty call list ignored to preserve active seats => source:$source old=${liveCallList.length}',
          );
        }
        return;
      }

      final Map<String, Map<String, dynamic>> oldByUser = {};
      final Map<String, Map<String, dynamic>> oldBySeat = {};
      for (final raw in liveCallList) {
        if (raw is! Map) continue;
        final old = Map<String, dynamic>.from(raw);
        final uid = _toInt(
          old['caller_id'] ??
              old['user_id'] ??
              (old['user'] is Map ? old['user']['id'] : null),
        );
        final seat = _toInt(
          old['seat_no'] ?? old['seatNo'] ?? old['seat'] ?? old['seat_number'],
        );
        if (uid > 0) oldByUser[uid.toString()] = old;
        if (seat > 0) oldBySeat[seat.toString()] = old;
      }

      final List<Map<String, dynamic>> mergedList = [];
      final Set<String> usedUsers = {};

      for (final rawIncoming in incoming) {
        final incomingMap = Map<String, dynamic>.from(rawIncoming);
        final int uid = _toInt(
          incomingMap['caller_id'] ??
              incomingMap['user_id'] ??
              incomingMap['viewer_id'] ??
              (incomingMap['user'] is Map ? incomingMap['user']['id'] : null),
        );
        final int seat = _toInt(
          incomingMap['seat_no'] ??
              incomingMap['seatNo'] ??
              incomingMap['seat'] ??
              incomingMap['seat_number'],
        );

        final old = uid > 0
            ? oldByUser[uid.toString()]
            : (seat > 0 ? oldBySeat[seat.toString()] : null);

        final merged = <String, dynamic>{
          if (old != null) ...old,
          ...incomingMap,
        };

        final int resolvedUid = uid > 0
            ? uid
            : _toInt(
          old?['caller_id'] ??
              old?['user_id'] ??
              (old?['user'] is Map ? old!['user']['id'] : null),
        );

        final oldUser = old?['user'] is Map
            ? Map<String, dynamic>.from(old!['user'])
            : <String, dynamic>{};
        final newUser = incomingMap['user'] is Map
            ? Map<String, dynamic>.from(incomingMap['user'])
            : <String, dynamic>{};

        if (resolvedUid > 0) {
          if (oldUser.isNotEmpty) _cacheLiveUserProfile(oldUser);
          if (newUser.isNotEmpty) _cacheLiveUserProfile(newUser);
          merged['user'] = _mergeWithCachedLiveUserProfile(
            userId: resolvedUid,
            rawUser: {...oldUser, ...newUser},
          );
          merged['caller_id'] = merged['caller_id'] ?? resolvedUid;
          usedUsers.add(resolvedUid.toString());
        } else if (oldUser.isNotEmpty || newUser.isNotEmpty) {
          merged['user'] = {...oldUser, ...newUser};
        }

        // Preserve seat/frame/audio fields if backend sends partial/null snapshot.
        merged['seat_no'] =
            incomingMap['seat_no'] ??
                old?['seat_no'] ??
                old?['seatNo'] ??
                old?['seat'];
        merged['call_status'] =
            incomingMap['call_status'] ??
                incomingMap['status'] ??
                old?['call_status'] ??
                old?['status'] ??
                'accepted';
        merged['audio_on'] =
            incomingMap['audio_on'] ??
                incomingMap['is_audio_on'] ??
                old?['audio_on'] ??
                old?['is_audio_on'] ??
                1;
        merged['is_audio_on'] = merged['audio_on'];
        merged['video_on'] = incomingMap['video_on'] ?? old?['video_on'];
        merged['is_speaking'] =
            old?['is_speaking'] ?? incomingMap['is_speaking'] ?? false;

        final int oldEarn = _toInt(
          old?['earn_coins'] ?? old?['gift_coins'] ?? old?['received_coins'],
        );
        final int newEarn = _toInt(
          incomingMap['earn_coins'] ??
              incomingMap['gift_coins'] ??
              incomingMap['received_coins'],
        );
        if (newEarn == 0 && oldEarn > 0) merged['earn_coins'] = oldEarn;

        mergedList.add(merged);
      }

      // Keep old accepted rows briefly when snapshot is partial and omits someone.
      // This prevents flicker/disappear after minimize/foreground before full API catches up.
      for (final raw in liveCallList) {
        if (raw is! Map) continue;
        final old = Map<String, dynamic>.from(raw);
        final oldUid = _toInt(
          old['caller_id'] ??
              old['user_id'] ??
              (old['user'] is Map ? old['user']['id'] : null),
        );
        if (oldUid > 0 && !usedUsers.contains(oldUid.toString())) {
          final status = (old['call_status'] ?? old['status'] ?? 'accepted')
              .toString()
              .toLowerCase();
          if (status == 'accepted' ||
              status == 'joined' ||
              status == 'active' ||
              status == 'live' ||
              status == 'on_seat') {
            mergedList.add(old);
          }
        }
      }

      // Final dedupe: one active row per user and per seat.
      final Map<int, Map<String, dynamic>> byUser =
      <int, Map<String, dynamic>>{};
      final Map<int, int> seatOwner = <int, int>{};
      final List<Map<String, dynamic>> withoutUserId = <Map<String, dynamic>>[];

      for (final item in mergedList) {
        final int uid = _toInt(
          item['caller_id'] ??
              item['user_id'] ??
              (item['user'] is Map ? item['user']['id'] : null),
        );
        final int seat = _toInt(
          item['seat_no'] ??
              item['seatNo'] ??
              item['seat'] ??
              item['seat_number'],
        );

        if (uid <= 0) {
          withoutUserId.add(item);
          continue;
        }

        // A newer row for the same user replaces the older row.
        byUser[uid] = item;

        if (seat > 0) {
          final previousOwner = seatOwner[seat];
          if (previousOwner != null && previousOwner != uid) {
            byUser.remove(previousOwner);
          }
          seatOwner[seat] = uid;
        }
      }

      final stableList = <Map<String, dynamic>>[
        ...byUser.values,
        ...withoutUserId,
      ];

      stableList.sort((a, b) {
        final aSeat = _toInt(a['seat_no'] ?? a['seatNo'] ?? a['seat']);
        final bSeat = _toInt(b['seat_no'] ?? b['seatNo'] ?? b['seat']);
        return aSeat.compareTo(bSeat);
      });

      final int beforeCount = liveCallList.length;
      liveCallList.assignAll(stableList);
      _refreshLiveCallListSmooth();
      printSeatTrace(
        'snapshot_merge',
        beforeCount: beforeCount,
        afterCount: liveCallList.length,
        reason: source,
        note: 'incoming=${incoming.length}',
      );
      refreshCpSeatConnectionsFromCurrentCallList(
        source: 'merge_call_list_$source',
      );
    } catch (e, st) {
      liveLog(
        '⚠️ mergeLiveCallListPreservingProfiles failed safely '
            '=> $e\n$st source:$source',
      );

      // Never replace the full active-seat list with a partial snapshot after
      // an exception. Upsert only valid incoming users and keep old seats.
      for (final incomingItem in incoming) {
        final int uid = _toInt(
          incomingItem['caller_id'] ??
              incomingItem['user_id'] ??
              (incomingItem['user'] is Map ? incomingItem['user']['id'] : null),
        );

        if (uid <= 0) continue;

        final index = liveCallList.indexWhere((raw) {
          if (raw is! Map) return false;
          return _callUserId(raw) == uid;
        });

        if (index >= 0) {
          final old = Map<String, dynamic>.from(liveCallList[index]);
          liveCallList[index] = <String, dynamic>{...old, ...incomingItem};
        } else {
          liveCallList.add(incomingItem);
        }
      }

      _refreshLiveCallListSmooth();
      refreshCpSeatConnectionsFromCurrentCallList(
        source: 'merge_call_list_exception_$source',
      );
    }
  }

  void _cacheLiveUserProfileFromPayload(Map<String, dynamic> payload) {
    final candidates = [
      payload['user'],
      payload['caller'],
      payload['viewer'],
      payload['viewer_data'] is Map ? payload['viewer_data']['user'] : null,
      payload['data'] is Map ? payload['data']['user'] : null,
      payload['data'] is Map ? payload['data']['caller'] : null,
    ];
    for (final item in candidates) {
      _cacheLiveUserProfile(item);
    }
  }

  bool _isCurrentStream(dynamic livestreamId) {
    final int incomingId = _toInt(livestreamId);
    if (incomingId <= 0) return false;

    // Audio live-e stream id sometimes 3 jaygay thake:
    // 1) websocket streamID, 2) activeAudioStreamId, 3) LivestreamController.streamId.
    // Sudhu streamID check korle viewer_left/live_end ignore hoye stale viewer thake.
    final int wsStreamId = streamID.value;
    final int audioStreamId = activeAudioStreamId.value;
    final int liveControllerStreamId = livestreamController.streamId.value;

    return wsStreamId == incomingId ||
        audioStreamId == incomingId ||
        liveControllerStreamId == incomingId;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is double) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on' ||
        text == 'success' ||
        text == 'locked' ||
        text == 'hidden' ||
        text == 'blocked' ||
        text == 'enabled';
  }

  Map<String, dynamic> _cpSafeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _cpIntFromKeys(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final int value = _toInt(map[key]);
      if (value > 0) return value;
    }
    return 0;
  }

  List<int> _cpSeatListFromAny(dynamic value) {
    final seats = <int>[];

    void addSeat(dynamic raw) {
      final int seat = _toInt(raw);
      if (seat > 0 && !seats.contains(seat)) seats.add(seat);
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          addSeat(
            map['seat_no'] ??
                map['seat'] ??
                map['seat_number'] ??
                map['seatNo'],
          );
        } else {
          addSeat(item);
        }
        if (seats.length >= 2) break;
      }
    } else if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      addSeat(
        map['seat_no'] ?? map['seat'] ?? map['seat_number'] ?? map['seatNo'],
      );
      addSeat(
        map['partner_seat_no'] ??
            map['cp_partner_seat_no'] ??
            map['other_seat_no'] ??
            map['to_seat_no'],
      );
    } else {
      addSeat(value);
    }

    return seats.take(2).toList();
  }

  List<int> _cpPairFromMap(Map<String, dynamic> raw) {
    final map = <String, dynamic>{...raw};

    for (final nestedKey in ['cp_connection', 'connection', 'cp_data']) {
      final nested = _cpSafeMap(raw[nestedKey]);
      if (nested.isNotEmpty) {
        map.addAll(nested);
      }
    }

    for (final listKey in [
      'cp_connection_pair',
      'cp_connected_seats',
      'connected_seats',
      'seat_pair',
      'pair',
      'seats',
    ]) {
      final pair = _cpSeatListFromAny(map[listKey]);
      if (pair.length >= 2) {
        pair.sort();
        return pair;
      }
    }

    final int seatOne = _cpIntFromKeys(map, [
      'seat_no',
      'seat',
      'seat_number',
      'seatNo',
      'my_seat_no',
      'current_user_seat_no',
      'user_seat_no',
      'sender_seat_no',
      'from_seat_no',
      'caller_seat_no',
    ]);

    final int seatTwo = _cpIntFromKeys(map, [
      'cp_partner_seat_no',
      'partner_seat_no',
      'partner_seat',
      'other_seat_no',
      'to_seat_no',
      'receiver_seat_no',
      'target_seat_no',
    ]);

    if (seatOne > 0 && seatTwo > 0 && seatOne != seatTwo) {
      final pair = [seatOne, seatTwo]..sort();
      return pair;
    }

    return <int>[];
  }

  int _cpUserIdFromMap(Map<String, dynamic> map) {
    final user = _cpSafeMap(map['user']);
    final caller = _cpSafeMap(map['caller']);
    final viewer = _cpSafeMap(map['viewer']);

    return _toInt(
      map['user_id'] ??
          map['caller_id'] ??
          map['viewer_id'] ??
          map['sender_id'] ??
          user['id'] ??
          user['user_id'] ??
          caller['id'] ??
          caller['user_id'] ??
          viewer['id'] ??
          viewer['user_id'],
    );
  }

  int _cpPartnerIdFromMap(Map<String, dynamic> map) {
    final partner = _cpSafeMap(map['cp_partner']);
    final receiver = _cpSafeMap(map['receiver']);

    return _toInt(
      map['cp_partner_id'] ??
          map['partner_id'] ??
          map['partner_user_id'] ??
          map['receiver_id'] ??
          map['to_user_id'] ??
          partner['id'] ??
          partner['user_id'] ??
          receiver['id'] ??
          receiver['user_id'],
    );
  }

  String _cpCleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _cpFirstTextFromKeys(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = _cpCleanText(map[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _cpLooksLikeImagePath(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;

    final lower = text.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('images/') ||
        lower.startsWith('/images/') ||
        lower.contains('/cp') ||
        lower.contains('/base') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.svga');
  }

  String _cpBaseImageFromMap(Map<String, dynamic> raw, {int depth = 0}) {
    if (raw.isEmpty || depth > 3) return '';

    final map = <String, dynamic>{...raw};

    final direct = _cpFirstTextFromKeys(map, const [
      'cp_base_image_url',
      'cp_base_image',
      'cpBaseImageUrl',
      'cpBaseImage',
      'cp_image_url',
      'cp_image',
      'cpImageUrl',
      'cpImage',
      'base_image_url',
      'base_image',
      'baseImageUrl',
      'baseImage',
      'connection_image_url',
      'connection_image',
      'connectionImageUrl',
      'connectionImage',
      'love_image_url',
      'love_image',
      'badge_image_url',
      'badge_image',
      'asset_url',
      'asset_path',
      'asset_image',
    ]);

    if (direct.isNotEmpty && _cpLooksLikeImagePath(direct)) {
      return direct;
    }

    for (final entry in map.entries) {
      final key = entry.key.toString().toLowerCase();
      if (!(key.contains('cp') ||
          key.contains('base') ||
          key.contains('connection'))) {
        continue;
      }
      if (!(key.contains('image') ||
          key.contains('url') ||
          key.contains('asset') ||
          key.contains('icon'))) {
        continue;
      }

      final value = _cpCleanText(entry.value);
      if (value.isNotEmpty && _cpLooksLikeImagePath(value)) {
        return value;
      }
    }

    for (final nestedKey in const [
      'cp_connection',
      'connection',
      'cp_data',
      'cp_base',
      'base',
      'cp',
      'asset',
      'badge',
      'image_data',
    ]) {
      final nested = _cpSafeMap(map[nestedKey]);
      if (nested.isEmpty) continue;
      final value = _cpBaseImageFromMap(nested, depth: depth + 1);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  bool _cpPayloadExplicitlyClearsConnection(
      Map<String, dynamic> data, {
        String source = 'unknown',
      }) {
    final action = (data['action_type'] ?? data['action'] ?? source)
        .toString()
        .toLowerCase()
        .trim();

    if (action == 'cp_base_removed' ||
        action == 'cp_removed' ||
        action == 'cp_disconnected' ||
        action == 'cp_connection_removed' ||
        action == 'cp_connection_broken' ||
        action == 'cp_break' ||
        action == 'breakup_cp' ||
        action == 'cp_breakup') {
      return true;
    }

    bool hasExplicitFalse(dynamic value) {
      if (value == null) return false;
      final text = value.toString().trim().toLowerCase();
      return text == '0' ||
          text == 'false' ||
          text == 'no' ||
          text == 'disconnected';
    }

    final bool mentionsCp =
        data.containsKey('has_cp_connection') ||
            data.containsKey('is_cp_connected') ||
            data.containsKey('cp_connected') ||
            data.containsKey('cp_connection') ||
            data.containsKey('cp_partner_id') ||
            data.containsKey('cp_partner_seat_no');

    if (!mentionsCp) return false;

    final bool saysConnected =
        _truthy(data['has_cp_connection']) ||
            _truthy(data['is_cp_connected']) ||
            _truthy(data['cp_connected']);

    if (saysConnected) return false;

    return hasExplicitFalse(data['has_cp_connection']) ||
        hasExplicitFalse(data['is_cp_connected']) ||
        hasExplicitFalse(data['cp_connected']) ||
        (data.containsKey('cp_connection') && data['cp_connection'] == null);
  }

  Map<String, dynamic>? _normalizeCpConnection(
      dynamic raw, {
        String source = 'unknown',
      }) {
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    final bool hasConnectionFlag =
        _truthy(map['has_cp_connection']) ||
            _truthy(map['is_cp_connected']) ||
            _truthy(map['cp_connected']) ||
            map['cp_connection'] is Map ||
            map['cp_connection_pair'] is Iterable ||
            map['cp_connected_seats'] is Iterable ||
            map['cp_partner_seat_no'] != null ||
            map['partner_seat_no'] != null;

    if (!hasConnectionFlag) return null;

    final pair = _cpPairFromMap(map);
    if (pair.length < 2) return null;

    final int seatOne = pair[0];
    final int seatTwo = pair[1];

    /// User requested only পাশের seat connection. So non-adjacent CP seats are
    /// ignored even if backend sends CP relation data.
    if ((seatOne - seatTwo).abs() != 1) return null;

    final String cpBaseImage = _cpBaseImageFromMap(map);

    return <String, dynamic>{
      'seat_one': seatOne,
      'seat_two': seatTwo,
      'user_id': _cpUserIdFromMap(map),
      'partner_id': _cpPartnerIdFromMap(map),
      'cp_base_image': cpBaseImage,
      'cp_base_image_url': cpBaseImage,
      'source': source,
      'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
      'raw': map,
    };
  }

  void _collectCpConnectionsFromDynamic(
      dynamic value,
      List<Map<String, dynamic>> output, {
        String source = 'unknown',
      }) {
    if (value == null) return;

    if (value is Iterable) {
      for (final item in value) {
        _collectCpConnectionsFromDynamic(item, output, source: source);
      }
      return;
    }

    if (value is! Map) return;

    final map = Map<String, dynamic>.from(value);
    final direct = _normalizeCpConnection(map, source: source);
    if (direct != null) output.add(direct);

    for (final key in [
      'cp_connections',
      'cp_seat_connections',
      'connections',
      'cp_connection_list',
    ]) {
      final nested = map[key];
      if (nested is Iterable || nested is Map) {
        _collectCpConnectionsFromDynamic(
          nested,
          output,
          source: '$source/$key',
        );
      }
    }
  }

  bool _sameCpConnectionList(
      List<Map<String, dynamic>> oldList,
      List<Map<String, dynamic>> newList,
      ) {
    if (oldList.length != newList.length) return false;

    String keyOf(Map<String, dynamic> item) {
      return '${_toInt(item['seat_one'])}-${_toInt(item['seat_two'])}-${_toInt(item['user_id'])}-${_toInt(item['partner_id'])}-${_cpCleanText(item['cp_base_image'] ?? item['cp_base_image_url'])}';
    }

    final oldKeys = oldList.map(keyOf).toList()..sort();
    final newKeys = newList.map(keyOf).toList()..sort();

    for (int i = 0; i < oldKeys.length; i++) {
      if (oldKeys[i] != newKeys[i]) return false;
    }

    return true;
  }

  void _applyCpSeatConnections(
      List<Map<String, dynamic>> connections, {
        String source = 'unknown',
        bool allowClear = false,
      }) {
    final Map<String, Map<String, dynamic>> unique =
    <String, Map<String, dynamic>>{};

    final Map<String, Map<String, dynamic>> oldByPair =
    <String, Map<String, dynamic>>{};
    for (final old in cpSeatConnections) {
      final int oldA = _toInt(old['seat_one']);
      final int oldB = _toInt(old['seat_two']);
      if (oldA <= 0 || oldB <= 0) continue;
      final int a = oldA < oldB ? oldA : oldB;
      final int b = oldA < oldB ? oldB : oldA;
      oldByPair['$a-$b'] = Map<String, dynamic>.from(old);
    }

    for (final item in connections) {
      final int a = _toInt(item['seat_one']);
      final int b = _toInt(item['seat_two']);
      if (a <= 0 || b <= 0 || a == b || (a - b).abs() != 1) continue;
      final int seatOne = a < b ? a : b;
      final int seatTwo = a < b ? b : a;
      final key = '$seatOne-$seatTwo';
      final old = oldByPair[key] ?? <String, dynamic>{};
      final String image = _cpCleanText(
        item['cp_base_image'] ??
            item['cp_base_image_url'] ??
            old['cp_base_image'] ??
            old['cp_base_image_url'],
      );

      unique[key] = <String, dynamic>{
        ...old,
        ...item,
        'seat_one': seatOne,
        'seat_two': seatTwo,
        if (image.isNotEmpty) 'cp_base_image': image,
        if (image.isNotEmpty) 'cp_base_image_url': image,
      };
    }

    final next = unique.values.toList()
      ..sort((a, b) => _toInt(a['seat_one']).compareTo(_toInt(b['seat_one'])));

    if (next.isEmpty && cpSeatConnections.isNotEmpty && !allowClear) {
      cpSeatConnections.refresh();
      liveLog(
        '🛡️ Empty CP snapshot ignored => keep:${cpSeatConnections.length} source:$source',
      );
      return;
    }

    if (_sameCpConnectionList(cpSeatConnections.toList(), next)) {
      cpSeatConnections.refresh();
      return;
    }

    cpSeatConnections.assignAll(next);
    cpSeatConnections.refresh();

    liveLog(
      '💞 CP adjacent seat connections synced => source:$source '
          'pairs:${next.map((e) => "${e['seat_one']}-${e['seat_two']} image:${_cpCleanText(e['cp_base_image']).isNotEmpty}").toList()}',
    );
  }

  void refreshCpSeatConnectionsFromCurrentCallList({
    String source = 'call_list',
  }) {
    final connections = <Map<String, dynamic>>[];

    for (final raw in liveCallList) {
      if (raw is Map) {
        _collectCpConnectionsFromDynamic(
          Map<String, dynamic>.from(raw),
          connections,
          source: '$source/liveCallList',
        );
      }
    }

    _applyCpSeatConnections(connections, source: source);
  }

  void syncCpSeatConnectionsFromAnyPayload(
      Map<String, dynamic> payload, {
        String source = 'unknown',
      }) {
    try {
      final Map<String, dynamic> data = <String, dynamic>{...payload};

      for (final key in [
        'data',
        'livestream',
        'livestreamdata',
        'live_stream',
        'stream',
      ]) {
        final nested = _cpSafeMap(payload[key]);
        if (nested.isNotEmpty) data.addAll(nested);
      }

      final dynamic livestreamId =
          data['livestream_id'] ??
              data['stream_id'] ??
              data['live_id'] ??
              data['id'];
      if (livestreamId != null &&
          _toInt(livestreamId) > 0 &&
          !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ CP connection ignored: not current stream => $livestreamId source:$source',
        );
        return;
      }

      final connections = <Map<String, dynamic>>[];
      _collectCpConnectionsFromDynamic(data, connections, source: source);

      for (final callersKey in [
        'livestream_callers',
        'callers',
        'accepted_callers',
        'live_callers',
      ]) {
        final callers = data[callersKey];
        if (callers is Iterable) {
          _collectCpConnectionsFromDynamic(
            callers,
            connections,
            source: '$source/$callersKey',
          );
        }
      }

      /// Local accepted seat list is the final UI state, so merge it too.
      for (final raw in liveCallList) {
        if (raw is Map) {
          _collectCpConnectionsFromDynamic(
            Map<String, dynamic>.from(raw),
            connections,
            source: '$source/liveCallList',
          );
        }
      }

      final bool allowClear = _cpPayloadExplicitlyClearsConnection(
        data,
        source: source,
      );

      _applyCpSeatConnections(
        connections,
        source: source,
        allowClear: allowClear,
      );
    } catch (e, st) {
      liveLog('❌ syncCpSeatConnectionsFromAnyPayload error => $e\n$st');
    }
  }

  void clearLiveCommentsLocal({int? livestreamId, String source = 'unknown'}) {
    try {
      if (livestreamId != null &&
          livestreamId > 0 &&
          !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ CLEAR LIVE COMMENTS ignored: not current stream => $livestreamId',
        );
        return;
      }

      final int beforeComments = commentsList.length;
      final int beforeGifts = giftMessagesList.length;

      commentsList.clear();
      giftMessagesList.clear();
      _refreshCommentsListSmooth();
      _refreshGiftMessagesListSmooth();

      liveLog(
        '🧹 LIVE COMMENTS LOCAL CLEARED => stream:${livestreamId ?? streamID.value} '
            'source:$source comments:$beforeComments->${commentsList.length} '
            'gifts:$beforeGifts->${giftMessagesList.length}',
      );
    } catch (e, st) {
      liveLog('❌ clearLiveCommentsLocal error => $e\n$st');
    }
  }

  void _handleUnifiedClearLiveComments(Map<String, dynamic> payload) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : payload;

      final dynamic rawStreamId =
          data['livestream_id'] ??
              data['liveSteamId'] ??
              data['stream_id'] ??
              data['live_stream_id'] ??
              payload['livestream_id'] ??
              payload['liveSteamId'] ??
              payload['stream_id'] ??
              payload['live_stream_id'];

      final int livestreamId = _toInt(rawStreamId);

      if (livestreamId > 0 && !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ CLEAR LIVE COMMENTS ignored: not current stream => $livestreamId',
        );
        return;
      }

      final dynamic rawClearValue =
          data['clear_comments'] ??
              data['comments_cleared'] ??
              payload['clear_comments'] ??
              payload['comments_cleared'];

      final bool shouldClear = rawClearValue == null
          ? true
          : _truthy(rawClearValue);

      if (!shouldClear) {
        liveLog('ℹ️ CLEAR LIVE COMMENTS event ignored: clear_comments=false');
        return;
      }

      liveLog(
        '🧹 CLEAR LIVE COMMENTS EVENT RECEIVED => stream:$livestreamId payload:$payload',
      );

      clearLiveCommentsLocal(
        livestreamId: livestreamId > 0 ? livestreamId : null,
        source: 'websocket_clear_live_comments',
      );
    } catch (e, st) {
      liveLog('❌ CLEAR LIVE COMMENTS EVENT ERROR => $e\n$st');
    }
  }

  void _handleUnifiedRoomSettingsUpdated(
      Map<String, dynamic> payload, {
        String source = 'room_settings_updated',
      }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};

      final Map<String, dynamic> liveData = payload['livestreamdata'] is Map
          ? Map<String, dynamic>.from(payload['livestreamdata'])
          : payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : payload['live_stream'] is Map
          ? Map<String, dynamic>.from(payload['live_stream'])
          : payload['stream'] is Map
          ? Map<String, dynamic>.from(payload['stream'])
          : payload['room'] is Map
          ? Map<String, dynamic>.from(payload['room'])
          : <String, dynamic>{};

      final Map<String, dynamic> nestedLiveData = data['livestreamdata'] is Map
          ? Map<String, dynamic>.from(data['livestreamdata'])
          : data['livestream'] is Map
          ? Map<String, dynamic>.from(data['livestream'])
          : data['live_stream'] is Map
          ? Map<String, dynamic>.from(data['live_stream'])
          : data['stream'] is Map
          ? Map<String, dynamic>.from(data['stream'])
          : data['room'] is Map
          ? Map<String, dynamic>.from(data['room'])
          : <String, dynamic>{};

      /// IMPORTANT:
      /// Backend sometimes broadcasts room edit with action_type:
      /// room_settings_updated instead of live_stream_updated.
      /// Old code only applied safety flags here, so audience did not see
      /// seat/theme/background/title change instantly. This merged room map is
      /// now used for both safety + full room UI sync.
      final Map<String, dynamic> room = {
        ...payload,
        ...data,
        ...liveData,
        ...nestedLiveData,
      };

      final dynamic rawStreamId =
          room['livestream_id'] ??
              room['liveSteamId'] ??
              room['stream_id'] ??
              room['live_stream_id'] ??
              room['id'];

      final int livestreamId = _toInt(rawStreamId);

      if (livestreamId > 0 && !_isCurrentStream(livestreamId)) {
        liveLog('⛔ ROOM SETTINGS ignored: not current stream => $livestreamId');
        return;
      }

      final int effectiveStreamId = livestreamId > 0
          ? livestreamId
          : streamID.value > 0
          ? streamID.value
          : activeAudioStreamId.value > 0
          ? activeAudioStreamId.value
          : livestreamController.streamId.value;

      livestreamController.applyRoomSafetySettingsFromPayload(
        room,
        source: 'websocket_$source',
      );

      bool hasRoomField(List<String> keys) {
        for (final key in keys) {
          if (room.containsKey(key) && room[key] != null) return true;
        }
        return false;
      }

      String? firstString(List<String> keys) {
        for (final key in keys) {
          if (room.containsKey(key) && room[key] != null) {
            return room[key].toString().trim();
          }
        }
        return null;
      }

      final bool hasRealtimeRoomUpdate =
          hasRoomField(['seat_count', 'total_seats']) ||
              hasRoomField(['room_layout', 'layout']) ||
              hasRoomField(['room_theme', 'theme']) ||
              hasRoomField(['room_background', 'background']) ||
              hasRoomField([
                'stream_bte',
                'title',
                'stream_title',
                'announcement',
                'anousment',
              ]) ||
              hasRoomField(['stream_image', 'image', 'cover_image', 'thumbnail']) ||
              hasRoomField(['room_password', 'stream_password', 'password']);

      if (effectiveStreamId > 0 && hasRealtimeRoomUpdate) {
        final int seatCount = _toInt(room['seat_count'] ?? room['total_seats']);
        final int roomLayout = _toInt(room['room_layout'] ?? room['layout']);
        final int roomTheme = _toInt(room['room_theme'] ?? room['theme']);
        final int roomBackground =
        room.containsKey('room_background') ||
            room.containsKey('background')
            ? _toInt(room['room_background'] ?? room['background'])
            : liveRoomBackground.value;

        updateLiveRoomSettings(
          livestreamId: effectiveStreamId,
          seatCount: seatCount > 0 ? seatCount : liveRoomSeatCount.value,
          roomLayout:
          room.containsKey('room_layout') || room.containsKey('layout')
              ? roomLayout
              : liveRoomLayout.value,
          roomTheme: room.containsKey('room_theme') || room.containsKey('theme')
              ? roomTheme
              : liveRoomTheme.value,
          roomBackground: roomBackground,
          streamTitle: firstString(['stream_bte', 'title']),
          streamAnnouncement: firstString([
            'announcement',
            'anousment',
            'stream_title',
          ]),
          streamImage: firstString([
            'stream_image',
            'image',
            'cover_image',
            'thumbnail',
          ]),
          streamPassword: firstString([
            'room_password',
            'stream_password',
            'password',
          ]),
        );

        try {
          syncRoomSnapshotForLateJoin(room, source: source);
        } catch (e) {
          liveLog('⚠️ room_settings snapshot sync skipped => $e');
        }

        try {
          livestreamController.syncLiveGiftCoinsFromPayload(
            room,
            source: source,
          );
        } catch (_) {}

        liveLog(
          '✅ ROOM SETTINGS FULL UI SYNCED => source:$source stream:$effectiveStreamId '
              'seats:${seatCount > 0 ? seatCount : liveRoomSeatCount.value} '
              'layout:${liveRoomLayout.value} theme:${liveRoomTheme.value} '
              'bg:${liveRoomBackground.value}',
        );
      } else {
        liveLog(
          'ℹ️ ROOM SETTINGS only safety fields received => source:$source stream:$effectiveStreamId',
        );
      }

      liveLog(
        '✅ ROOM SETTINGS EVENT APPLIED => source:$source stream:$livestreamId',
      );
    } catch (e, st) {
      liveLog('❌ ROOM SETTINGS EVENT ERROR => $e\n$st');
    }
  }

  int _eventLivestreamId(Map<String, dynamic> payload) {
    dynamic read(Map map, String key) => map[key];

    final candidates = <dynamic>[
      payload['livestream_id'],
      payload['stream_id'],
      payload['live_id'],
      payload['room_id'],
      payload['audio_stream_id'],
    ];

    for (final key in [
      'data',
      'livestream',
      'livestreamdata',
      'live_stream',
      'stream',
      'room',
    ]) {
      final nested = payload[key];
      if (nested is Map) {
        candidates.add(read(nested, 'livestream_id'));
        candidates.add(read(nested, 'stream_id'));
        candidates.add(read(nested, 'live_id'));
        candidates.add(read(nested, 'id'));
      }
    }

    for (final item in candidates) {
      final id = _toInt(item);
      if (id > 0) return id;
    }
    return 0;
  }

  bool _isLiveRoomCurrentlyOpen(dynamic livestreamId) {
    final int incomingId = _toInt(livestreamId);
    if (incomingId <= 0) return false;
    return _isCurrentStream(incomingId);
  }

  void _safeCloseOpenDialogOrSheet() {
    try {
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        final ctx = Get.overlayContext;
        if (ctx != null && Navigator.of(ctx, rootNavigator: true).canPop()) {
          Navigator.of(ctx, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      liveLog('⚠️ safe close overlay skipped => $e');
    }
  }

  /// ===================== SEAT SWITCH REALTIME =====================
  /// Used by both local API response and websocket action_type: seat_switched.
  void applySeatSwitch({
    required int userId,
    required int fromSeatNo,
    required int toSeatNo,
    required Map<String, dynamic> callData,
  }) {
    try {
      final index = liveCallList.indexWhere((call) {
        final callerId = call['caller_id'];
        final callUserId = call['user']?['id'] ?? call['User']?['id'];
        return callerId.toString() == userId.toString() ||
            callUserId.toString() == userId.toString();
      });

      final Map<String, dynamic> cpConnection = _cpSafeMap(
        callData['cp_connection'] ??
            callData['connection'] ??
            (callData['data'] is Map
                ? callData['data']['cp_connection']
                : null),
      );

      final normalizedCall = <String, dynamic>{
        ...callData,
        if (cpConnection.isNotEmpty) 'cp_connection': cpConnection,
        'caller_id': callData['caller_id'] ?? callData['user_id'] ?? userId,
        'user_id': callData['user_id'] ?? callData['caller_id'] ?? userId,
        'seat_no': toSeatNo,
        'my_seat_no': toSeatNo,
        'call_status':
        callData['call_status'] ?? callData['status'] ?? 'accepted',
      };

      if (index != -1) {
        final old = liveCallList[index];
        if (old is Map) {
          normalizedCall['user'] ??= old['user'];
          normalizedCall['audio_on'] ??= old['audio_on'];
          normalizedCall['video_on'] ??= old['video_on'];
          normalizedCall['is_muted'] ??= old['is_muted'];
          normalizedCall['is_muted_by_host'] ??= old['is_muted_by_host'];
        }
        liveCallList[index] = normalizedCall;
      } else {
        liveCallList.add(normalizedCall);
      }

      final seen = <String>{};
      liveCallList.removeWhere((call) {
        final seatNo = call['seat_no']?.toString() ?? '';
        final callerId =
            call['caller_id']?.toString() ??
                call['user']?['id']?.toString() ??
                '';
        final key = '$seatNo-$callerId';

        if (seen.contains(key)) return true;
        seen.add(key);
        return false;
      });

      _refreshLiveCallListSmooth();
      refreshCpSeatConnectionsFromCurrentCallList(
        source: 'apply_seat_switch_call_list',
      );
      syncCpSeatConnectionsFromAnyPayload(
        normalizedCall,
        source: 'apply_seat_switch',
      );
      livestreamController.update();

      final currentUserId = _currentUserIdInt();

      if (currentUserId == userId) {
        _lastKnownSelfSeatNo = toSeatNo;
        _heartbeatTimeoutSeatGuardUntilMs.remove(userId);

        try {
          livestreamController.updateLivePresenceRole(
            role: 'caller',
            isOnSeat: true,
            seatNo: toSeatNo,
          );
        } catch (e) {
          liveLog('⚠️ Self seat-switch presence repair skipped: $e');
        }
      }

      liveLog(
        '✅ Seat switched applied => user:$userId from:$fromSeatNo to:$toSeatNo',
      );
    } catch (e) {
      liveLog('❌ applySeatSwitch error: $e');
    }
  }

  void _handleUnifiedSeatSwitched(Map<String, dynamic> payload) {
    final Map<String, dynamic> data = payload['data'] is Map
        ? {
      ...Map<String, dynamic>.from(payload),
      ...Map<String, dynamic>.from(payload['data']),
    }
        : Map<String, dynamic>.from(payload);

    final livestreamId =
        data['livestream_id'] ?? data['stream_id'] ?? data['live_id'];
    if (livestreamId != null &&
        _toInt(livestreamId) > 0 &&
        !_isCurrentStream(livestreamId)) {
      liveLog(
        '⛔ seat_switched ignored: not current stream => $livestreamId current=${streamID.value}/${activeAudioStreamId.value}/${livestreamController.streamId.value}',
      );
      return;
    }

    final userId =
        int.tryParse(
          (data['user_id'] ?? data['caller_id'] ?? data['sender_id'] ?? 0)
              .toString(),
        ) ??
            0;
    final fromSeatNo =
        int.tryParse(
          (data['from_seat_no'] ?? data['old_seat_no'] ?? 0).toString(),
        ) ??
            0;
    final toSeatNo =
        int.tryParse(
          (data['to_seat_no'] ?? data['seat_no'] ?? data['my_seat_no'] ?? 0)
              .toString(),
        ) ??
            0;

    final callDataRaw =
        data['call_data'] ??
            data['caller'] ??
            data['call'] ??
            data['seat_user'];
    final callData = callDataRaw is Map
        ? <String, dynamic>{...data, ...Map<String, dynamic>.from(callDataRaw)}
        : <String, dynamic>{
      ...data,
      'livestream_id': data['livestream_id'],
      'caller_id': userId,
      'user_id': userId,
      'seat_no': toSeatNo,
      'call_status': 'accepted',
    };

    if (userId == 0 || toSeatNo == 0) {
      liveLog('⚠️ seat_switched ignored: invalid payload => $payload');
      return;
    }

    applySeatSwitch(
      userId: userId,
      fromSeatNo: fromSeatNo,
      toSeatNo: toSeatNo,
      callData: callData,
    );

    /// CP connection/base image can be sent at root level, not inside call_data.
    /// Sync it immediately so every viewer sees the base without waiting for an API refresh.
    syncCpSeatConnectionsFromAnyPayload(data, source: 'seat_switched');
  }

  void _handleUnifiedSeatLockToggle(Map<String, dynamic> payload) {
    final Map<String, dynamic> data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload['seat'] is Map
        ? Map<String, dynamic>.from(payload['seat'])
        : Map<String, dynamic>.from(payload);

    final livestreamId =
        payload['livestream_id'] ??
            payload['stream_id'] ??
            data['livestream_id'] ??
            data['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      return;
    }

    /// Sync full locked_seats list first. Important: allowUnlock=false keeps
    /// already locked seats safe during viewer join / resume / partial refresh.
    try {
      syncSeatLocksFromAnyPayload(
        {...payload, ...data},
        allowUnlock: false,
        source: 'seat_lock_toggle_payload',
      );
    } catch (e) {
      liveLog('⚠️ seat lock list sync failed => $e');
    }

    final int seatNo =
        _seatToInt(
          data['seat_no'] ??
              data['seatNo'] ??
              data['seat'] ??
              data['seat_number'] ??
              payload['seat_no'] ??
              payload['seatNo'] ??
              payload['seat_number'],
        ) ??
            0;

    if (seatNo == 0) {
      liveLog('⚠️ seat_lock_toggle missing seat_no: $payload');
      return;
    }

    final rawLocked =
        data['is_locked'] ??
            data['locked'] ??
            data['lock'] ??
            data['seat_locked'] ??
            data['lock_status'] ??
            data['status'] ??
            data['action'] ??
            payload['is_locked'] ??
            payload['locked'] ??
            payload['status'] ??
            payload['action'];

    final text = rawLocked?.toString().toLowerCase().trim() ?? '';

    final bool explicitUnlock =
        _seatFalsey(rawLocked) || text.contains('unlock');
    final bool explicitLock =
        _seatTruthy(rawLocked) ||
            (text.contains('lock') && !text.contains('unlock'));

    if (explicitUnlock) {
      updateSeatLockStatus(
        seatNo: seatNo,
        isLocked: false,
        source: 'seat_lock_toggle_unlock',
      );
    } else if (explicitLock) {
      updateSeatLockStatus(
        seatNo: seatNo,
        isLocked: true,
        source: 'seat_lock_toggle_lock',
      );
    } else {
      /// Do not unlock on empty/partial seat payload.
      /// Viewer join/live refresh sometimes sends seat data without lock keys,
      /// and that must not clear a previously locked seat.
      liveLog(
        'ℹ️ seat_lock_toggle ignored: no explicit lock/unlock value => seat:$seatNo raw:$rawLocked',
      );
      return;
    }

    liveLog(
      '✅ Unified seat lock toggle handled => seat:$seatNo locked:${isSeatLocked(seatNo)} raw:$rawLocked',
    );
  }

  Future<void> _dispatchLiveStreamAction(
      String actionType,
      Map<String, dynamic> payload,
      ) async {
    final Stopwatch dispatchStopwatch = Stopwatch()..start();
    LiveTestingLogger.line(
      '🧪 EVENT DISPATCH START => action=$actionType stream=${payload['livestream_id'] ?? payload['stream_id'] ?? payload['live_id']}',
    );
    try {
      if (actionType.contains('gift') ||
          actionType.contains('lucky') ||
          payload.containsKey('gift') ||
          payload.containsKey('lucky_result') ||
          payload.containsKey('lucky_results')) {
        _forceGiftPrint('🎁 ALL GIFT DISPATCH INPUT', {
          'action_type': actionType,
          'payload': payload,
        });
      }

      switch (actionType) {
        case 'live_stream_created':
        case 'permanent_room_rejoined':
          _handleUnifiedLiveStreamCreated(payload);
          try {
            livestreamController.syncLiveGiftCoinsFromPayload(
              payload,
              source: 'live_stream_created',
            );
          } catch (_) {}
          break;

        case 'live_stream_ended':
        case 'live_ended':
          _handleUnifiedLiveStreamEnded(payload);
          break;

        case 'broadcaster_disconnected':
        case 'host_left_room':
        case 'host_left':
        case 'host_disconnected':
        case 'host_reconnecting':
        case 'broadcaster_reconnecting':
          liveLog(
            'ℹ️ Host temporarily left/disconnected, keeping live room open',
          );
          break;

        case 'live_stream_list':
          _handleUnifiedLiveStreamList(payload);
          try {
            livestreamController.syncLiveGiftCoinsFromPayload(
              payload,
              source: 'live_stream_list',
            );
          } catch (_) {}
          break;

        case 'viewer_add':
        case 'viewer_added':
        case 'viewer_joined':
        case 'user_joined':
        case 'join_live':
        case 'live_joined':
        case 'viewer_remove':
        case 'viewer_removed':
        case 'viewer_left':
        case 'user_left':
        case 'user_leave':
        case 'leave_live':
          _handleUnifiedViewer(payload, actionType);
          break;

        case 'live_comment':
        case 'multi_live_comment':
        case 'pk_comment':
        case 'pk_live_comment':
          _handleUnifiedComment(payload);
          break;

        case 'rocket_progress_updated':
        case 'rocket_launched':
        case 'rocket_session_expired':
        case 'rocket_session_reset':
          try {
            final RocketController rocketController =
            Get.isRegistered<RocketController>()
                ? Get.find<RocketController>()
                : Get.put(RocketController(), permanent: true);
            rocketController.handleRealtime(actionType, payload);
          } catch (e) {
            liveLog('⚠️ Rocket realtime handle failed => $e');
          }
          break;

        case 'gift_sent':
        case 'multi_live_gift_sent':
        case 'pk_gift_sent':
        case 'pk_gift_received':
        case 'pk_score_updated':
        case 'pk_score_update':
        case 'pk_gift_score_updated':
          _handleUnifiedGift(payload);
          syncGiftCoinsFromPayload(payload, source: 'dispatch_gift_$actionType');
          try {
            livestreamController.syncLiveGiftCoinsFromPayload(
              payload,
              source: 'dispatch_gift_$actionType',
            );
          } catch (e) {
            liveLog('⚠️ controller gift coin sync failed => $e');
          }
          try {
            final bool isPkGift =
                actionType.contains('pk_gift') ||
                    payload['is_pk'] == true ||
                    payload['is_pk'] == 1 ||
                    payload['is_pk']?.toString() == '1' ||
                    _toInt(payload['pk_id']) > 0 ||
                    (payload['pk_channel'] ?? payload['pk_channel_name'] ?? '')
                        .toString()
                        .isNotEmpty;
            if (isPkGift) {
              livestreamController.handlePkScoreUpdated(payload);
            }
          } catch (_) {}
          break;

        case 'lucky_gift_result':
        case 'lucky_gift_back_coin':
          _forceGiftPrint('🍀 LUCKY ACTION DISPATCH INPUT', {
            'action_type': actionType,
            'payload': payload,
          });
          _handleLuckyGiftResult(payload);
          try {
            livestreamController.syncLiveGiftCoinsFromPayload(
              payload,
              source: 'lucky_gift_result',
            );
          } catch (_) {}
          break;

        case 'imogi_sent':
        case 'emoji_sent':
          _handleUnifiedImogiSent(payload);
          break;

        case 'live_stream_call':
        case 'multi_live_seat_joined':
        case 'multi_live_seat_left':
          await _handleUnifiedLiveCall(payload);
          break;

        case 'caller_reconnecting':
          {
            final int userId = _toInt(payload['caller_id'] ?? payload['user_id']);
            final int seatNo = _toInt(payload['seat_no']);

            if (userId == _currentUserIdInt() && seatNo > 0) {
              _markSelfHeartbeatSeatGuard(userId: userId, seatNo: seatNo);

              try {
                livestreamController.updateLivePresenceRole(
                  role: 'caller',
                  isOnSeat: true,
                  seatNo: seatNo,
                );
              } catch (_) {}
            }

            liveLog(
              '🛡️ Caller reconnecting; seat kept => user:$userId seat:$seatNo',
            );
            break;
          }

        case 'caller_left':
        case 'multi_live_caller_left':
        case 'seat_left':
        case 'live_seat_left':
          await _handleUnifiedCallerLeft(payload);
          break;

        case 'moderation':
          await _handleUnifiedModeration(payload);
          break;

        case 'multi_live_audio_toggle':
        case 'audio_toggle':
        case 'mute_toggle':
        case 'mic_toggle':
        case 'microphone_toggle':
          await _handleUnifiedAudioToggle(payload);
          break;

        case 'multi_live_video_toggle':
        case 'video_toggle':
          await _handleUnifiedVideoToggle(payload);
          break;

        case 'seat_lock_toggle':
        case 'seat_locked':
        case 'seat_unlocked':
          _handleUnifiedSeatLockToggle(payload);
          break;

        case 'seat_switched':
          _handleUnifiedSeatSwitched(payload);
          break;

        case 'live_music':
          _handleUnifiedLiveMusic(payload);
          break;

        case 'live_youtube':
          _handleUnifiedLiveYoutube(payload);
          break;

        case 'room_settings_updated':
        case 'live_comment_lock_updated':
        case 'live_hidden_room_updated':
        case 'live_screen_setting_updated':
          _handleUnifiedRoomSettingsUpdated(payload, source: actionType);
          break;

        case 'clear_live_comments':
        case 'live_comments_cleared':
        case 'comments_cleared':
          _handleUnifiedClearLiveComments(payload);
          break;

        case 'live_stream_updated':
          _handleUnifiedLiveStreamUpdated(payload);
          try {
            livestreamController.syncLiveGiftCoinsFromPayload(
              payload,
              source: 'live_stream_updated',
            );
          } catch (_) {}
          break;

        case 'live_gift_state_updated':
        case 'gift_state_updated':
          syncGiftCoinsFromPayload(payload, source: actionType);
          try {
            livestreamController.syncLiveGiftCoinsFromPayload(
              payload,
              source: actionType,
            );
          } catch (_) {}
          break;

        case 'multi_live_speaking':
          _handleUnifiedSpeaking(payload);
          break;

        case 'red_packet_sent':
          _handleUnifiedRedPacketSent(payload);
          break;

        case 'red_packet_collected':
          _handleUnifiedRedPacketCollected(payload);
          break;

        case 'red_packet_refunded':
        case 'red_packet_expired':
        case 'red_packet_closed':
          _handleUnifiedRedPacketClosed(payload, source: actionType);
          break;

        case 'greedy_winner_announced':
        case 'greedy_game_timer':
        case 'greedy_game_started':
        case 'greedy_game_ended':
        case 'greedy_bet_placed':
        case 'fruit_game_winner':
        case 'fruit_game_user_left':
        case 'fruit_game_user_joined':
        case 'fruit_game_timer':
        case 'fruit_game_bet_total':

        /// Game event system removed for audio live. Ignore old backend game events
        /// so they cannot update UI/state or affect normal live room.
          liveLog('🎮 Game action ignored in audio live => $actionType');
          break;

        case 'pk_request_received':
        case 'pk_invite_received':
          _handlePkRequestReceived(payload);
          break;

        case 'pk_request_sent':
        case 'pk_invite_sent':
          livestreamController.handlePkRequestSent(payload);
          _showPkWaitingToast(payload);
          break;

        case 'pk_started':
        case 'pk_accepted':
        case 'pk_request_accepted':
          livestreamController.handlePkStarted(payload);
          break;

        case 'pk_score_updated':
          livestreamController.handlePkScoreUpdated(payload);
          break;

        case 'pk_result_preview':
          livestreamController.handlePkResultPreview(payload);
          break;

        case 'livestream_state_updated':
        case 'live_state_updated':
        case 'stream_state_updated':
          _handleUnifiedLiveStreamStateUpdated(payload);
          break;

        case 'pk_rejected':
        case 'pk_request_rejected':
          livestreamController.handlePkRejected(payload);
          break;

        case 'pk_ended':
        case 'pk_cancelled':
        case 'pk_canceled':
          livestreamController.handlePkEnded(payload);
          break;

        default:
          liveLog('ℹ️ Unknown LiveStreamEvent action_type: $actionType');
          liveLog('Payload: $payload');
          break;
      }
    } catch (error, stackTrace) {
      LiveTestingLogger.printBlock('LIVE TEST EVENT DISPATCH ERROR [$actionType]', {
        'elapsed_ms': dispatchStopwatch.elapsedMilliseconds,
        'error': error.toString(),
        'stack_trace': stackTrace.toString(),
        'payload': payload,
      });
      rethrow;
    } finally {
      dispatchStopwatch.stop();
      LiveTestingLogger.line(
        '🧪 EVENT DISPATCH END => action=$actionType elapsed=${dispatchStopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  bool _isUserStillVisibleAsViewer(int userId) {
    if (userId <= 0) return false;
    try {
      for (final raw in livestreamController.liveViewerList) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final dynamic rowId =
            item['user_id'] ??
                item['viewer_id'] ??
                item['id'] ??
                (item['user'] is Map ? item['user']['id'] : null) ??
                (item['viewer'] is Map ? item['viewer']['id'] : null);
        if (rowId != null && rowId.toString() == userId.toString()) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _handleUnifiedCallerLeft(Map<String, dynamic> payload) async {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? {
        ...Map<String, dynamic>.from(payload),
        ...Map<String, dynamic>.from(payload['data']),
      }
          : Map<String, dynamic>.from(payload);

      _cacheLiveUserProfileFromPayload(data);

      final livestreamId =
          data['livestream_id'] ?? data['stream_id'] ?? data['id'];
      if (livestreamId != null && !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ caller_left ignored: not current stream => $livestreamId current=${streamID.value}/${activeAudioStreamId.value}/${livestreamController.streamId.value}',
        );
        return;
      }

      final userId =
          data['caller_id'] ??
              data['user_id'] ??
              data['viewer_id'] ??
              (data['user'] is Map ? data['user']['id'] : null) ??
              (data['caller'] is Map ? data['caller']['id'] : null);

      if (userId == null) {
        printSeatTrace(
          'caller_left_missing_user',
          streamId: _toInt(livestreamId),
          status: 'left',
          error: 'user_id_missing',
        );
        return;
      }

      final String uid = userId.toString();

      /// ✅ Do not remove current user's own seat/profile for heartbeat timeout.
      /// Log shows backend sends caller_left reason=heartbeat_timeout, but the
      /// next heartbeat still succeeds as viewer. That means client heartbeat
      /// role/state became wrong, not a real manual leave.
      final String reason = (data['reason'] ?? data['leave_reason'] ?? '')
          .toString()
          .toLowerCase();
      final int uidInt = _toInt(userId);
      final int currentUserId = _currentUserIdInt();
      final int seatNo =
      _toInt(data['seat_no'] ?? data['seat'] ?? data['seat_number']) > 0
          ? _toInt(data['seat_no'] ?? data['seat'] ?? data['seat_number'])
          : _selfSeatNoFromLiveCallList();
      final bool callerStillAccepted = _isUserAcceptedSeatLocally(userId);
      final bool videoMediaStillActive =
      _isVideoCallerMediaStillActive(uidInt);

      printSeatTrace(
        'caller_left_event',
        streamId: _toInt(livestreamId),
        userId: uidInt,
        seatNo: seatNo,
        status: 'left',
        reason: reason.isEmpty ? 'unknown' : reason,
        note: 'accepted=$callerStillAccepted media=$videoMediaStillActive',
      );

      /// A heartbeat timeout is a weak transport/presence signal. If the local
      /// accepted row OR the real Agora video media is still alive, keep the
      /// caller card/seat. The old code checked only the row, so a reordered
      /// timeout event could hide the card while both users still saw/heard
      /// each other through Agora.
      if (_isWeakCallerTimeoutReason(reason) &&
          (callerStillAccepted || videoMediaStillActive)) {
        if (currentUserId > 0 && uidInt == currentUserId) {
          _markSelfHeartbeatSeatGuard(userId: currentUserId, seatNo: seatNo);

          if (videoMediaStillActive) {
            final int sid = _toInt(livestreamId);
            if (sid > 0) {
              livestreamController.startLivePresenceHeartbeat(
                livestreamId: sid,
                role: 'caller',
                isOnSeat: true,
                seatNo: seatNo > 0 ? seatNo : null,
                backgroundMode: false,
              );
            } else {
              livestreamController.updateLivePresenceRole(
                role: 'caller',
                isOnSeat: true,
                seatNo: seatNo > 0 ? seatNo : null,
              );
            }
          } else {
            /// Audio-live privacy behavior stays unchanged: if there is no
            /// confirmed video media lease, mute while the weak timeout is
            /// verified so background speech cannot leak.
            await _autoMuteCurrentUserAfterSeatSignal(
              userId: currentUserId,
              reason: 'caller_left_heartbeat_timeout_guarded',
              confirmedSeatExit: false,
            );
            livestreamController.updateLivePresenceRole(
              role: 'caller',
              isOnSeat: true,
              seatNo: seatNo > 0 ? seatNo : null,
            );
          }
        }
        for (final raw in liveCallList) {
          if (raw is! Map) continue;
          final call = Map<String, dynamic>.from(raw);
          if (_callUserId(call) != uidInt) continue;
          _ensureViewerRowFromCall(call);
          break;
        }
        _refreshLiveCallListSmooth();
        livestreamController.liveViewerList.refresh();
        livestreamController.update();
        printSeatTrace(
          'caller_left_preserved',
          streamId: _toInt(livestreamId),
          userId: uidInt,
          seatNo: seatNo,
          status: 'accepted',
          reason: reason,
          note: 'viewerCount=${livestreamController.liveViewerList.length}',
        );
        return;
      }

      final int beforeCallRemoveCount = liveCallList.length;
      liveCallList.removeWhere((call) {
        if (call is! Map) return false;
        final callerId = call['caller_id'];
        final userIdField = call['user_id'];
        final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
        return callerId.toString() == uid ||
            userIdField.toString() == uid ||
            nestedUserId.toString() == uid;
      });
      _refreshLiveCallListSmooth();
      refreshCpSeatConnectionsFromCurrentCallList(source: 'caller_left');

      pendingCall.removeWhere((call) {
        if (call is! Map) return false;
        final callerId = call['caller_id'];
        final userIdField = call['user_id'];
        final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
        return callerId.toString() == uid ||
            userIdField.toString() == uid ||
            nestedUserId.toString() == uid;
      });
      pendingCall.refresh();

      if (currentUserId > 0 && uidInt == currentUserId) {
        await _autoMuteCurrentUserAfterSeatSignal(
          userId: currentUserId,
          reason: reason.isEmpty ? 'caller_left' : 'caller_left_$reason',
          confirmedSeatExit: true,
        );
      } else {
        await _muteRemoteCallerAfterConfirmedSeatExit(
          userId: uidInt,
          reason: reason.isEmpty ? 'caller_left' : 'caller_left_$reason',
        );
      }

      // Seat leave only: keep/re-add the user as normal viewer.
      _ensureViewerRowAfterSeatLeft(data);

      _viewerJoinedAtMs.remove(_toInt(userId));
      // Seat theke namale mute state remove korbo na.
      // User muted thakle viewer/next seat UI teo muted state preserve hobe
      // until host explicitly unmute kore.
      audioMutedUserMap.refresh();

      /// Caller/user seat chere dile oi seat automatic empty hobe.
      /// Host manually lock na korle stale lock icon dekhano jabe na.
      if (seatNo > 0) {
        updateSeatLockStatus(
          seatNo: seatNo,
          isLocked: false,
          source: 'caller_left_force_unlock_empty_seat',
        );
      }

      syncSeatLocksFromAnyPayload(
        data,
        allowUnlock: true,
        source: 'caller_left',
      );

      // caller_left mane seat theke namse. Viewer list theke remove korbo na,
      // karon user live room-e viewer hisebe thakte pare. viewer_left event ashle viewer remove hobe.
      livestreamController.update();
      printSeatTrace(
        'caller_left_applied',
        streamId: _toInt(livestreamId),
        userId: uidInt,
        seatNo: seatNo,
        status: 'removed',
        reason: reason.isEmpty ? 'caller_left' : reason,
        beforeCount: beforeCallRemoveCount,
        afterCount: liveCallList.length,
        note: 'viewerCount=${livestreamController.liveViewerList.length}',
      );
    } catch (e, st) {
      liveLog('❌ _handleUnifiedCallerLeft error => $e\n$st');
    }
  }

  void _handleUnifiedLiveStreamStateUpdated(Map<String, dynamic> payload) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? {
        ...Map<String, dynamic>.from(payload),
        ...Map<String, dynamic>.from(payload['data']),
      }
          : Map<String, dynamic>.from(payload);

      final livestreamId =
          data['livestream_id'] ??
              data['stream_id'] ??
              data['id'] ??
              payload['livestream_id'];

      if (livestreamId != null && !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ livestream_state_updated ignored: not current stream => $livestreamId',
        );
        return;
      }

      final int viewerCount = _toInt(
        data['viewer_count'] ?? data['viewers_count'],
      );
      final int callerCount = _toInt(
        data['caller_count'] ?? data['callers_count'],
      );

      printSeatTrace(
        'live_state_event',
        streamId: _toInt(livestreamId),
        status: 'snapshot',
        note: 'serverViewers=$viewerCount serverCallers=$callerCount occupied=${data['occupied_seats']}',
      );

      /// Seat lock source of truth. Here allowUnlock=true because this event is
      /// backend authoritative state after join/left/lock/unlock.
      syncSeatLocksFromAnyPayload(
        data,
        allowUnlock: true,
        source: 'livestream_state_updated',
      );

      /// If backend explicitly says locked_seats: [], clear old visual locks.
      if ((data['locked_seats'] is List &&
          (data['locked_seats'] as List).isEmpty) ||
          (data['lockedSeats'] is List &&
              (data['lockedSeats'] as List).isEmpty)) {
        lockedSeatMap.clear();
        lockedSeatMap.refresh();
      }

      /// If backend says no viewer, host UI must not keep stale viewer avatars.
      /// If viewerCount > 0 but no viewer objects are provided, only count/log is applied;
      /// never create fake list rows from count-only payload.
      livestreamController.viewerState.applyState(data);
      if (viewerCount == 0) {
        newViewersJoinded.value = false;
        newJoinedUserData.value = {};
      }

      /// If no caller/seat user except host, clear stale non-host call rows.
      /// Seat 1 host row should stay because audio room broadcaster is seeded there.
      if (callerCount <= 1 && data['occupied_seats'] is List) {
        final occupied = (data['occupied_seats'] as List)
            .map((e) => _seatToInt(e))
            .whereType<int>()
            .toSet();

        bool currentUserRemovedByAuthoritativeState = false;
        final Set<int> removedRemoteUserIds = <int>{};
        final int beforeStateRemoveCount = liveCallList.length;

        liveCallList.removeWhere((call) {
          if (call is! Map) return false;
          final callMap = Map<String, dynamic>.from(call);
          final seat = _seatToInt(
            callMap['seat_no'] ?? callMap['seat'] ?? callMap['seat_number'],
          );
          if (seat == null) return false;

          final int callUserId = _callUserId(callMap);
          final int currentUserId = _currentUserIdInt();
          if (currentUserId > 0 &&
              callUserId == currentUserId &&
              _hasSelfHeartbeatSeatGuard(currentUserId)) {
            liveLog(
              '🛡️ live_state_update kept current user seat during heartbeat guard => user:$currentUserId seat:$seat',
            );
            return false;
          }

          final bool shouldRemove = !occupied.contains(seat);
          if (shouldRemove && callUserId > 0) {
            if (currentUserId > 0 && callUserId == currentUserId) {
              currentUserRemovedByAuthoritativeState = true;
            } else {
              removedRemoteUserIds.add(callUserId);
            }
          }
          return shouldRemove;
        });
        _refreshLiveCallListSmooth();
        if (beforeStateRemoveCount != liveCallList.length) {
          printSeatTrace(
            'live_state_removed_missing_seat',
            streamId: _toInt(livestreamId),
            beforeCount: beforeStateRemoveCount,
            afterCount: liveCallList.length,
            reason: 'occupied_seats_authoritative',
            note: 'occupied=$occupied removedRemote=${removedRemoteUserIds.join(',')} selfRemoved=$currentUserRemovedByAuthoritativeState',
          );
        }

        if (currentUserRemovedByAuthoritativeState) {
          unawaited(
            _autoMuteCurrentUserAfterSeatSignal(
              userId: _currentUserIdInt(),
              reason: 'authoritative_live_state_seat_missing',
              confirmedSeatExit: true,
            ),
          );
        }

        for (final int removedUserId in removedRemoteUserIds) {
          unawaited(
            _muteRemoteCallerAfterConfirmedSeatExit(
              userId: removedUserId,
              reason: 'authoritative_live_state_seat_missing',
            ),
          );
        }
      }

      audioMutedUserMap.refresh();
      syncCpSeatConnectionsFromAnyPayload(
        data,
        source: 'livestream_state_updated',
      );
      livestreamController.update();

      liveLog(
        '✅ Live state applied => viewers:$viewerCount callers:$callerCount locks:${lockedSeatMap.keys.toList()}',
      );
    } catch (e, st) {
      liveLog('❌ _handleUnifiedLiveStreamStateUpdated error => $e\n$st');
    }
  }

  void _handleUnifiedLiveStreamUpdated(Map<String, dynamic> payload) {
    Map<String, dynamic> room = Map<String, dynamic>.from(payload);

    if (payload['data'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['data'])};
    }

    if (payload['livestreamdata'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['livestreamdata'])};
    }

    if (payload['livestream'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['livestream'])};
    }

    if (payload['live_stream'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['live_stream'])};
    }

    final livestreamId =
        payload['livestream_id'] ??
            payload['stream_id'] ??
            room['livestream_id'] ??
            room['stream_id'] ??
            room['id'];

    if (livestreamId == null) {
      liveLog('⚠️ live_stream_updated missing livestream id. payload=$payload');
      return;
    }

    if (!_isCurrentStream(livestreamId)) {
      liveLog(
        '⛔ live_stream_updated ignored: not current stream => $livestreamId current=${streamID.value}',
      );
      return;
    }

    final int streamId =
        int.tryParse(livestreamId.toString()) ?? streamID.value;

    final int seatCount =
        int.tryParse(
          (room['seat_count'] ??
              payload['seat_count'] ??
              liveRoomSeatCount.value)
              .toString(),
        ) ??
            liveRoomSeatCount.value;

    final int roomLayout =
        int.tryParse(
          (room['room_layout'] ??
              payload['room_layout'] ??
              liveRoomLayout.value)
              .toString(),
        ) ??
            liveRoomLayout.value;

    final int roomTheme =
        int.tryParse(
          (room['room_theme'] ?? payload['room_theme'] ?? liveRoomTheme.value)
              .toString(),
        ) ??
            liveRoomTheme.value;

    final int roomBackground =
        int.tryParse(
          (room['room_background'] ??
              payload['room_background'] ??
              liveRoomBackground.value)
              .toString(),
        ) ??
            liveRoomBackground.value;

    final String streamTitle =
    (room['stream_bte'] ??
        room['title'] ??
        payload['stream_bte'] ??
        payload['title'] ??
        liveRoomTitle.value)
        .toString()
        .trim();

    final String streamAnnouncement =
    (room['announcement'] ??
        room['anousment'] ??
        room['stream_title'] ??
        payload['announcement'] ??
        payload['anousment'] ??
        payload['stream_title'] ??
        liveRoomAnnouncement.value)
        .toString()
        .trim();

    final String streamImage =
    (room['stream_image'] ??
        room['image'] ??
        room['cover_image'] ??
        room['thumbnail'] ??
        payload['stream_image'] ??
        payload['image'] ??
        liveRoomStreamImage.value)
        .toString()
        .trim();

    final String streamPassword =
    (room['room_password'] ??
        room['stream_password'] ??
        room['password'] ??
        payload['room_password'] ??
        payload['stream_password'] ??
        payload['password'] ??
        liveRoomPassword.value)
        .toString()
        .trim();

    updateLiveRoomSettings(
      livestreamId: streamId,
      seatCount: seatCount,
      roomLayout: roomLayout,
      roomTheme: roomTheme,
      roomBackground: roomBackground,
      streamTitle: streamTitle,
      streamAnnouncement: streamAnnouncement,
      streamImage: streamImage,
      streamPassword: streamPassword,
    );

    try {
      livestreamController.applyRoomSafetySettingsFromPayload(
        room,
        source: 'websocket_live_stream_updated',
      );
    } catch (e) {
      liveLog('⚠️ live_stream_updated room safety sync skipped => $e');
    }

    syncRoomSnapshotForLateJoin(room, source: 'live_stream_updated');
    syncCpSeatConnectionsFromAnyPayload(room, source: 'live_stream_updated');
  }

  void _handleUnifiedLiveMusic(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload;

    final livestreamId = data['livestream_id'] ?? payload['livestream_id'];
    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ live_music ignored: not current stream => $livestreamId');
      return;
    }

    final status = (data['music_status'] ?? data['status'] ?? 'stopped')
        .toString()
        .toLowerCase();
    final name = (data['music_name'] ?? data['name'] ?? '').toString();
    final hostId = int.tryParse((data['host_id'] ?? 0).toString()) ?? 0;

    liveMusicStatus.value = status;
    liveMusicName.value = status == 'stopped' ? '' : name;
    liveMusicHostId.value = hostId;
    liveMusicPositionMs.value =
        int.tryParse(
          (data['music_position'] ?? data['position'] ?? 0).toString(),
        ) ??
            0;
    liveMusicDurationMs.value =
        int.tryParse(
          (data['music_duration'] ?? data['duration'] ?? 0).toString(),
        ) ??
            0;
    liveMusicVolume.value =
        int.tryParse(
          (data['music_volume'] ?? data['volume'] ?? 65).toString(),
        ) ??
            65;

    if (status == 'stopped') {
      liveMusicPositionMs.value = 0;
      liveMusicDurationMs.value = 0;
    }

    liveLog('✅ Live music updated => status:$status name:$name host:$hostId');
  }

  void _handleUnifiedLiveYoutube(Map<String, dynamic> payload) {
    liveLog('▶️ LIVE YOUTUBE RAW PAYLOAD => $payload');

    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload;

    final livestreamId = data['livestream_id'] ?? payload['livestream_id'];
    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ live_youtube ignored: not current stream => $livestreamId');
      return;
    }

    final status = (data['youtube_status'] ?? data['status'] ?? 'stopped')
        .toString()
        .toLowerCase();
    final url = (data['youtube_url'] ?? data['url'] ?? '').toString();
    final videoId = (data['youtube_video_id'] ?? _extractYoutubeVideoId(url))
        .toString();
    final hostId = int.tryParse((data['host_id'] ?? 0).toString()) ?? 0;

    if (status == 'stopped' || videoId.isEmpty) {
      liveYoutubeStatus.value = 'stopped';
      liveYoutubeUrl.value = '';
      liveYoutubeVideoId.value = '';
      liveYoutubeHostId.value = hostId;
    } else {
      liveYoutubeStatus.value = status;
      liveYoutubeUrl.value = url;
      liveYoutubeVideoId.value = videoId;
      liveYoutubeHostId.value = hostId;
    }

    liveLog(
      '✅ Live YouTube updated => status:$status video:${liveYoutubeVideoId.value} host:$hostId',
    );
  }

  String _extractYoutubeVideoId(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';

    final patterns = <RegExp>[
      RegExp(r'(?:v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match != null) return match.group(1) ?? '';
    }

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) return raw;
    return '';
  }

  dynamic _safeReadLiveUser(dynamic Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String _cleanLiveText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  bool _missingLiveText(dynamic value) => _cleanLiveText(value).isEmpty;

  bool _looksLikeBadFallbackImage(dynamic value) {
    final url = _cleanLiveText(value).toLowerCase();
    return url.isEmpty ||
        url == 'null' ||
        url.contains('photosbulk.com') ||
        url.contains('hijab-girl-pic_108.webp');
  }

  Map<String, dynamic> _safeCurrentUserMapForLiveCard() {
    final dynamic currentUser = authController.userProfile.value.user;
    final dynamic id = _safeReadLiveUser(() => currentUser?.id);
    final String userId = _cleanLiveText(
      _safeReadLiveUser(() => currentUser?.userId),
    );
    final String name = _cleanLiveText(
      _safeReadLiveUser(() => currentUser?.name),
    );
    final String username = _cleanLiveText(
      _safeReadLiveUser(() => currentUser?.username),
    );
    final dynamic profileImage =
        _safeReadLiveUser(() => currentUser?.profileImage) ??
            _safeReadLiveUser(() => currentUser?.image);

    return <String, dynamic>{
      'id': id,
      'user_id': userId.isNotEmpty ? userId : id,
      'name': name.isNotEmpty
          ? name
          : (username.isNotEmpty ? username : ('User').appTr),
      'username': username,
      'profile_image': profileImage,
      'image': profileImage,
      'level': _safeReadLiveUser(() => currentUser?.level) ?? 0,
      'coins': _safeReadLiveUser(() => currentUser?.coins),
      'earned_coins': _safeReadLiveUser(() => currentUser?.earnedCoins),
      'is_online': true,
    };
  }

  bool _hasRealUserMap(dynamic value) {
    if (value is! Map) return false;
    final user = Map<String, dynamic>.from(value);
    return _cleanLiveText(user['name']).isNotEmpty ||
        _cleanLiveText(user['username']).isNotEmpty ||
        _cleanLiveText(user['profile_image']).isNotEmpty ||
        _cleanLiveText(user['image']).isNotEmpty;
  }

  bool _sameLiveCardIdentity(Map<String, dynamic> a, Map<String, dynamic> b) {
    final String aId = _cleanLiveText(
      a['id'] ?? a['livestream_id'] ?? a['stream_id'],
    );
    final String bId = _cleanLiveText(
      b['id'] ?? b['livestream_id'] ?? b['stream_id'],
    );
    if (aId.isNotEmpty && bId.isNotEmpty && aId == bId) return true;

    final String aUser = _cleanLiveText(
      a['user_id'] ?? a['room_id'] ?? a['host_id'],
    );
    final String bUser = _cleanLiveText(
      b['user_id'] ?? b['room_id'] ?? b['host_id'],
    );
    return aUser.isNotEmpty && bUser.isNotEmpty && aUser == bUser;
  }

  Map<String, dynamic> _mergeLiveCardKeepingRichData(
      Map<String, dynamic> oldData,
      Map<String, dynamic> newData,
      ) {
    final merged = <String, dynamic>{...oldData, ...newData};

    if (!_hasRealUserMap(newData['user']) && _hasRealUserMap(oldData['user'])) {
      merged['user'] = oldData['user'];
    }
    if (!_hasRealUserMap(newData['User']) && _hasRealUserMap(oldData['User'])) {
      merged['User'] = oldData['User'];
    }

    for (final key in ['stream_bte', 'name', 'title']) {
      if (_missingLiveText(merged[key]) && !_missingLiveText(oldData[key])) {
        merged[key] = oldData[key];
      }
    }

    for (final key in [
      'stream_image',
      'stream_img',
      'image',
      'cover_image',
      'profile_image',
    ]) {
      if (_looksLikeBadFallbackImage(merged[key]) &&
          !_looksLikeBadFallbackImage(oldData[key])) {
        merged[key] = oldData[key];
      }
    }

    return merged;
  }

  Map<String, dynamic> _hydrateLiveCardForList(Map<String, dynamic> rawData) {
    Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    for (final oldRaw in homeController.showingLiveStreamList) {
      if (oldRaw is! Map) continue;
      final oldData = Map<String, dynamic>.from(oldRaw);
      if (_sameLiveCardIdentity(oldData, data)) {
        data = _mergeLiveCardKeepingRichData(oldData, data);
        break;
      }
    }

    final Map<String, dynamic> currentUserMap =
    _safeCurrentUserMapForLiveCard();
    final int myId = _toInt(currentUserMap['id']);
    final int dataHostId = _toInt(
      data['user_id'] ??
          data['room_id'] ??
          data['host_id'] ??
          data['broadcaster_id'] ??
          (data['user'] is Map ? data['user']['id'] : null) ??
          (data['User'] is Map ? data['User']['id'] : null),
    );

    if (myId > 0 && dataHostId == myId) {
      data['user'] = _hasRealUserMap(data['user'])
          ? _mergeLiveCardKeepingRichData(
        {'user': currentUserMap},
        {'user': data['user']},
      )['user']
          : currentUserMap;
      data['User'] = data['user'];

      if (_missingLiveText(data['stream_bte']) ||
          data['stream_bte'].toString().toLowerCase() == 'user') {
        data['stream_bte'] = currentUserMap['name'];
      }
      data['name'] = _missingLiveText(data['name'])
          ? currentUserMap['name']
          : data['name'];
      data['profile_image'] = _looksLikeBadFallbackImage(data['profile_image'])
          ? currentUserMap['profile_image']
          : data['profile_image'];

      // Realtime create event often comes before API returns stream_image.
      // Use host profile image temporarily so the live card never shows random fallback.
      if (_looksLikeBadFallbackImage(data['stream_image']) &&
          !_looksLikeBadFallbackImage(currentUserMap['profile_image'])) {
        data['stream_image'] = currentUserMap['profile_image'];
      }
      if (_looksLikeBadFallbackImage(data['image']) &&
          !_looksLikeBadFallbackImage(currentUserMap['profile_image'])) {
        data['image'] = currentUserMap['profile_image'];
      }

      liveLog(
        '✅ Own live card hydrated from auth profile => ${data['id'] ?? data['livestream_id']} name=${currentUserMap['name']}',
      );
    }

    return data;
  }

  void _scheduleRealtimeLiveListRefresh() {
    if (_realtimeLiveRefreshScheduled) return;
    _realtimeLiveRefreshScheduled = true;

    _realtimeLiveRefreshTimer?.cancel();
    _realtimeLiveRefreshTimer = Timer(
      const Duration(milliseconds: 900),
          () async {
        if (_socketLifecycleClosed) {
          _realtimeLiveRefreshScheduled = false;
          return;
        }
        try {
          await homeController.getLivestreamList(
            page: 1,
            perPage: homeController.livePerPage.value,
            refresh: true,
          );
          liveLog('✅ Live list auto refreshed after realtime create/update');
        } catch (e) {
          liveLog('⚠️ Live list auto refresh skipped => $e');
        } finally {
          _realtimeLiveRefreshScheduled = false;
          _realtimeLiveRefreshTimer = null;
        }
      },
    );
  }

  void _handleUnifiedLiveStreamCreated(Map<String, dynamic> payload) {
    final streamDataRaw =
        payload['livestream'] ??
            payload['live_stream'] ??
            payload['stream'] ??
            payload['data'] ??
            payload;

    if (streamDataRaw is! Map) {
      liveLog('⚠️ live_stream_created invalid payload: $payload');
      return;
    }

    final streamData = _hydrateLiveCardForList(
      Map<String, dynamic>.from(streamDataRaw),
    );

    final streamId = streamData['id'] ?? streamData['livestream_id'];
    final userId = streamData['user_id'] ?? streamData['room_id'];

    if (streamId == null && userId == null) {
      liveLog('⚠️ live_stream_created missing stream id/user id: $payload');
      return;
    }

    homeController.showingLiveStreamList.removeWhere((stream) {
      final oldId = stream['id'] ?? stream['livestream_id'];
      final oldUserId = stream['user_id'] ?? stream['room_id'];
      return (streamId != null && oldId.toString() == streamId.toString()) ||
          (userId != null && oldUserId.toString() == userId.toString());
    });

    homeController.showingLiveStreamList.insert(0, streamData);
    homeController.sortLiveStreamList();
    homeController.showingLiveStreamList.refresh();
    _scheduleRealtimeLiveListRefresh();

    final int createdStreamId = _toInt(
      streamData['id'] ??
          streamData['livestream_id'] ??
          streamData['stream_id'],
    );
    final int currentStreamId = _toInt(streamID.value);

    /// IMPORTANT:
    /// অন্য host নতুন live create করলে current room এর seat/call/gift/comment state clear করা যাবে না।
    /// Example: current=6810, event=6931. Only live list update হবে, room state untouched থাকবে।
    if (currentStreamId > 0 &&
        createdStreamId > 0 &&
        createdStreamId != currentStreamId) {
      liveLog(
        '⛔ Other live_stream_created ignored for room state => event:$createdStreamId current:$currentStreamId',
      );
      return;
    }

    _activeCallPopupKeys.clear();
    _handledCallPopupKeys.clear();
    _locallyLeftStreamIds.clear();
    _viewerJoinedAtMs.clear();
    _recentRoomExitUserUntilMs.clear();
    pendingCall.clear();
    liveCallList.clear();
    pendingCall.refresh();
    _refreshLiveCallListSmooth();
    refreshCpSeatConnectionsFromCurrentCallList(
      source: 'live_stream_created_clear',
    );

    syncSeatLocksFromAnyPayload(
      streamData,
      allowUnlock: false,
      source: 'live_stream_created',
    );
    syncGiftCoinsFromPayload(streamData, source: 'live_stream_created');
    try {
      livestreamController.syncLiveGiftCoinsFromPayload(
        streamData,
        source: 'live_stream_created',
      );
    } catch (_) {}

    if (createdStreamId > 0) {
      fetchInitialGiftTotal(streamId: createdStreamId);
    }

    liveLog('✅ Unified live stream created/list updated: ${streamData['id']}');
  }

  bool _isLocalOwnerCloseInProgress(Map<String, dynamic> payload) {
    final String reason =
    (payload['reason'] ?? payload['end_reason'] ?? payload['message'] ?? '')
        .toString()
        .toLowerCase();

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    final int actorId = _toInt(
      payload['host_id'] ??
          payload['owner_user_id'] ??
          payload['actor_id'] ??
          payload['user_id'],
    );

    final bool ownerCloseReason =
        reason.contains('owner_closed_room') ||
            reason.contains('closed by owner') ||
            reason.contains('owner close');

    return livestreamController.isOwnerClosingPermanentRoom.value &&
        ownerCloseReason &&
        currentUserId > 0 &&
        (actorId <= 0 || actorId == currentUserId);
  }

  bool _isExplicitLiveEndPayload(Map<String, dynamic> payload) {
    final String reason =
    (payload['reason'] ??
        payload['end_reason'] ??
        payload['type'] ??
        payload['action'] ??
        '')
        .toString()
        .toLowerCase();

    final String message = (payload['message'] ?? '').toString().toLowerCase();

    /// These are temporary host/app lifecycle events.
    /// Backend can still send them as live_ended sometimes, but the REST list
    /// later shows the room again. So do not remove the card for these cases.
    final String joined = '$reason $message';
    if (joined.contains('new_live_created') ||
        joined.contains('host_left') ||
        joined.contains('host leave') ||
        joined.contains('host_disconnected') ||
        joined.contains('broadcaster_disconnected') ||
        joined.contains('reconnecting') ||
        joined.contains('background') ||
        joined.contains('minimize') ||
        joined.contains('temporary')) {
      return false;
    }

    /// Explicit end reasons should remove the room and force audience out.
    if (joined.contains('host_ended') ||
        joined.contains('ended_by_host') ||
        joined.contains('end_live') ||
        joined.contains('manual') ||
        joined.contains('admin') ||
        joined.contains('expired') ||
        joined.contains('force_end')) {
      return true;
    }

    /// If no soft reason is present, keep old behaviour for real live_ended events.
    return true;
  }

  void _handleUnifiedLiveStreamEnded(Map<String, dynamic> payload) {
    final livestreamId =
        payload['livestream_id'] ?? payload['stream_id'] ?? payload['id'];
    final userId = payload['user_id'] ?? payload['room_id'];

    if (livestreamId == null && userId == null) {
      liveLog('⚠️ live_stream_ended missing livestream_id/user_id: $payload');
      return;
    }

    final bool explicitEnd = _isExplicitLiveEndPayload(payload);

    if (!explicitEnd) {
      /// Do not remove the list item for temporary host leave/disconnect events.
      /// This fixes the glitch where the card disappears, then comes back after refresh.
      liveLog(
        'ℹ️ Soft live_end ignored, keeping live card => $livestreamId payload=$payload',
      );
      return;
    }

    homeController.showingLiveStreamList.removeWhere((stream) {
      final oldId = stream['id'] ?? stream['livestream_id'];
      final oldUserId = stream['user_id'] ?? stream['room_id'];

      return (livestreamId != null &&
          oldId.toString() == livestreamId.toString()) ||
          (userId != null && oldUserId.toString() == userId.toString());
    });

    homeController.sortLiveStreamList();
    homeController.showingLiveStreamList.refresh();

    final int endedStreamId = _toInt(livestreamId);

    if (endedStreamId > 0) {
      _locallyLeftStreamIds.add(endedStreamId);
    }

    /// For the owner who pressed Close Room, REST response is responsible
    /// for opening Endlive with complete arguments. Audience/guardian devices
    /// still follow the normal force-exit path below.
    if (_isLocalOwnerCloseInProgress(payload)) {
      isStreamEnded.value = true;
      isBroadcasterOnline.value = false;
      liveLog(
        '✅ Owner close live_ended received; waiting for REST Endlive navigation '
            '=> stream:$endedStreamId',
      );
      return;
    }

    final bool shouldForceExit =
        livestreamId != null && _isLiveRoomCurrentlyOpen(livestreamId);

    if (shouldForceExit) {
      _handleLiveStreamEnded({
        ...payload,
        'livestream_id': livestreamId,
        'joined_users': payload['joined_users'] ?? [],
        'message': payload['message'] ?? 'Live stream has ended',
      });
    } else {
      liveLog(
        'ℹ️ Live end list removed only, room not open here => $livestreamId',
      );
    }

    liveLog('✅ Unified live stream ended/list removed: $livestreamId');
  }

  void _handleUnifiedLiveStreamList(Map<String, dynamic> payload) {
    final list =
        payload['data'] ??
            payload['streams'] ??
            payload['live_streams'] ??
            payload['livestreams'];

    if (list is List) {
      /// Avoid UI flicker: sometimes websocket sends an empty/partial snapshot,
      /// then REST refresh brings the cards back. Keep the existing list in that case.
      if (list.isEmpty && homeController.showingLiveStreamList.isNotEmpty) {
        liveLog('ℹ️ Empty live_stream_list ignored to prevent list flicker');
        return;
      }

      homeController.showingLiveStreamList.assignAll(list);
      homeController.sortLiveStreamList();
      homeController.showingLiveStreamList.refresh();
      liveLog('✅ Unified live stream list updated: ${list.length}');
    } else {
      liveLog('⚠️ live_stream_list does not contain list: $payload');
    }
  }

  void _addSystemViewerComment({
    required dynamic livestreamId,
    required Map<String, dynamic> user,
    required String comment,
    required String systemType,
  }) {
    final userId = user['id'] ?? user['user_id'] ?? user['viewer_id'];

    if (userId == null ||
        user['name'] == null ||
        user['name'].toString().trim().isEmpty ||
        user['name'].toString().toLowerCase() == 'null') {
      liveLog('⚠️ System viewer comment skipped, bad user => $user');
      return;
    }

    /// duplicate stop: same user + same stream + same join/left comment already recent thakle add korbo na.
    /// Age only user/comment check chilo, tai self join ba room switch-e wrong skip hote parto.
    final int incomingStreamId = _toInt(livestreamId);
    final String incomingSystemType = systemType.toString();
    final exists = commentsList.reversed.take(25).any((item) {
      if (item is! Map) return false;

      final itemUser = item['user'];
      final itemUserId = itemUser is Map
          ? (itemUser['id'] ?? itemUser['user_id'] ?? itemUser['viewer_id'])
          : null;

      final int itemStreamId = _toInt(
        item['livestream_id'] ??
            item['stream_id'] ??
            item['live_stream_id'] ??
            item['room_id'],
      );
      final String itemSystemType = (item['system_type'] ?? item['type'] ?? '')
          .toString();

      return item['comment'].toString() == comment &&
          itemUserId.toString() == userId.toString() &&
          itemStreamId == incomingStreamId &&
          itemSystemType == incomingSystemType;
    });

    if (exists) {
      liveLog(
        'ℹ️ Duplicate system viewer comment skipped: $comment user=$userId',
      );
      return;
    }

    final systemComment = {
      'type': systemType,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'user': user,
      'comment': comment,
      'timestamp': DateTime.now().toIso8601String(),
      'system_type': systemType,
      'comment_key': '${systemType}_${livestreamId}_$userId',
      'is_local_self_activity':
      userId.toString() ==
          authController.userProfile.value.user?.id?.toString(),
    };

    commentsList.add(systemComment);
    _refreshCommentsListSmooth();
  }

  bool _isUserAcceptedSeatLocally(dynamic userId) {
    final int uid = _toInt(userId);
    if (uid <= 0) return false;

    for (final raw in liveCallList) {
      if (raw is! Map) continue;

      final user = raw['user'] is Map
          ? Map<String, dynamic>.from(raw['user'])
          : <String, dynamic>{};

      final int rowId = _toInt(
        raw['caller_id'] ??
            raw['user_id'] ??
            raw['viewer_id'] ??
            user['id'] ??
            user['user_id'],
      );

      final String status = (raw['call_status'] ?? raw['status'] ?? 'accepted')
          .toString()
          .toLowerCase()
          .trim();

      final bool accepted =
          status == 'accepted' ||
              status == 'joined' ||
              status == 'active' ||
              status == 'live' ||
              status == 'on_seat';

      if (rowId == uid && accepted) return true;
    }

    return false;
  }

  bool _isWeakCallerTimeoutReason(String reason) {
    final String value = reason.toLowerCase().trim();
    if (value.isEmpty) return false;
    return value == 'heartbeat_timeout' ||
        value == 'heartbeat_delayed' ||
        value == 'presence_timeout' ||
        value == 'inactivity_timeout' ||
        value == 'ping_timeout' ||
        value == 'connection_lost' ||
        value == 'network_timeout' ||
        value == 'transport_timeout';
  }

  bool _isVideoCallerMediaStillActive(int userId) {
    if (userId <= 0) return false;

    final int currentUserId = _currentUserIdInt();
    if (userId == currentUserId && _localPublishingCallerId == userId) {
      return true;
    }

    final int mappedUid =
        livestreamController.videoCallerAgoraUidMap[userId] ?? 0;
    if (mappedUid <= 0) return false;

    // The caller->Agora mapping is created only for accepted video/popular
    // calls. Requiring that mapping prevents a stale remote UID from an old
    // video room from affecting audio-live seat cleanup.
    return livestreamController.videoLiveRemoteUids.any(
          (uid) =>
      uid == mappedUid ||
          uid == userId ||
          uid == userId + 100000 ||
          (userId >= 100000 && uid == userId - 100000),
    );
  }

  bool _viewerLeftIsRealRoomExit(String reason) {
    final String r = reason.toLowerCase().trim();

    return r.contains('kick') ||
        r.contains('ban') ||
        r.contains('live_end') ||
        r.contains('live_ended') ||
        r.contains('room_exit') ||
        r.contains('full_exit') ||
        r.contains('close') ||
        r.contains('owner_close') ||
        r.contains('leave_room');
  }

  void _handleUnifiedViewer(Map<String, dynamic> payload, String actionType) {
    final viewerInfoRaw =
        payload['viewer_data'] ??
            payload['viewer'] ??
            payload['user'] ??
            payload['data'] ??
            payload;

    if (viewerInfoRaw is! Map) {
      liveLog('⚠️ viewer payload invalid: $payload');
      return;
    }

    final viewerInfo = Map<String, dynamic>.from(viewerInfoRaw);

    // Viewer rows have their own database id (for example 15357) and the real
    // user id in viewer_id/user_id/user.id (for example 100558). Always prefer
    // the full user payload, otherwise viewer_left can clear the wrong id and
    // stale seat/profile rows remain in the room.
    final Map<String, dynamic> userMap = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'])
        : payload['viewer'] is Map
        ? Map<String, dynamic>.from(payload['viewer'])
        : viewerInfo['user'] is Map
        ? Map<String, dynamic>.from(viewerInfo['user'])
        : <String, dynamic>{};

    final livestreamId =
        payload['livestream_id'] ??
            payload['stream_id'] ??
            viewerInfo['livestream_id'] ??
            viewerInfo['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ VIEWER ignored: not current stream => $livestreamId');
      return;
    }

    final userId =
        userMap['id'] ??
            userMap['user_id'] ??
            payload['user_id'] ??
            payload['viewer_id'] ??
            viewerInfo['viewer_id'] ??
            viewerInfo['user_id'];

    if (userId == null) {
      liveLog('⚠️ viewer user id missing: $payload');
      return;
    }

    final currentUserId = authController.userProfile.value.user?.id?.toString();
    final action =
    (payload['action'] ??
        payload['viewer_action'] ??
        payload['action_type'] ??
        actionType)
        .toString()
        .toLowerCase();

    /// Backend can send action_type=viewer_add with action=viewer_remove.
    final isLeft =
        action.contains('remove') ||
            action.contains('left') ||
            action.contains('leave') ||
            action == 'viewer_out';

    final isSelf = currentUserId != null && userId.toString() == currentUserId;

    final int sidForGuard = _toInt(livestreamId);
    final int uidForGuard = _toInt(userId);
    final String leaveReason =
    (payload['reason'] ??
        payload['leave_reason'] ??
        payload['system_type'] ??
        payload['message'] ??
        '')
        .toString()
        .toLowerCase();

    /// ✅ Permanent audio seat fix:
    /// Sometimes backend sends viewer_left for current user while the user is still
    /// accepted on an audio seat. That event must NOT demote caller -> viewer,
    /// must NOT call rejectCall, and must NOT remove the user from viewer list.
    final bool selfSeatProtectedViewerLeft =
        isLeft &&
            isSelf &&
            sidForGuard > 0 &&
            uidForGuard > 0 &&
            !_locallyLeftStreamIds.contains(sidForGuard) &&
            (_selfIsStillOnSeatLocally() || _selfSeatNoFromLiveCallList() > 0) &&
            !leaveReason.contains('kick') &&
            !leaveReason.contains('ban') &&
            !leaveReason.contains('live_end') &&
            !leaveReason.contains('room_exit') &&
            !leaveReason.contains('full_exit');

    if (selfSeatProtectedViewerLeft) {
      final int protectedSeat = _selfSeatNoFromLiveCallList();
      _markSelfHeartbeatSeatGuard(userId: uidForGuard, seatNo: protectedSeat);
      if (userMap.isNotEmpty) {
        livestreamController.addOrUpdateViewerLocal({
          'id': uidForGuard,
          'viewer_id': uidForGuard,
          'user_id': uidForGuard,
          'livestream_id': livestreamId,
          'is_active': true,
          'user': userMap,
        }, force: true);
      }
      livestreamController.updateLivePresenceRole(
        role: 'caller',
        isOnSeat: true,
        seatNo: protectedSeat > 0 ? protectedSeat : null,
      );
      liveLog(
        '🛡️ Protected self viewer_left while still on seat => user:$userId seat:$protectedSeat',
      );
      return;
    }

    final bool viewerLeftUserStillOnSeat =
        isLeft && _isUserAcceptedSeatLocally(userId);
    final bool removeViewer =
        payload['remove_viewer'] == true || payload['viewer_removed'] == true;
    final bool forcedRoomExit =
        removeViewer || _viewerLeftIsRealRoomExit(leaveReason);
    final bool preserveViewer =
        !forcedRoomExit &&
            (payload['remove_viewer'] == false ||
                payload['viewer_removed'] == false ||
                leaveReason.contains('reject') ||
                leaveReason.contains('cancel') ||
                leaveReason.contains('seat_leave') ||
                leaveReason.contains('leave_seat') ||
                leaveReason.contains('call_end') ||
                leaveReason.contains('call_timeout'));
    final bool explicitViewerLeaveAction =
        action == 'viewer_left' ||
            action == 'viewer_leave' ||
            action == 'viewer_remove' ||
            action == 'viewer_removed' ||
            action == 'viewer_out';
    final bool viewerLeftRealRoomExit =
        isLeft &&
            !preserveViewer &&
            (forcedRoomExit ||
                (explicitViewerLeaveAction && !viewerLeftUserStillOnSeat));

    _cacheLiveUserProfile(userMap);

    /// ✅ Video live stale call popup fix + audio seat protection:
    /// viewer_left is a weak presence event. It must not remove an accepted
    /// audio seat. Seat removal happens only on explicit leave/reject/kick/end.
    if (isLeft) {
      if (viewerLeftRealRoomExit) {
        _markRecentRoomExit(
          streamId: livestreamId,
          userId: userId,
          milliseconds: 60000,
        );
      }

      if (isSelf && viewerLeftRealRoomExit) {
        final sid = _toInt(livestreamId);
        if (sid > 0) {
          _locallyLeftStreamIds.add(sid);
          if (streamID.value == sid) streamID.value = 0;
        }
      }

      if (viewerLeftRealRoomExit) {
        _viewerJoinedAtMs.remove(_toInt(userId));
      }

      _clearStaleCallStateForUser(
        callerId: userId,
        streamId: livestreamId,
        // Explicit room_exit/full_exit is authoritative. The local seat row can
        // still be present for a few milliseconds because caller_left/viewer_left
        // are separate realtime frames. Never let that stale row keep the user
        // visible on the host seat after they have left the room.
        removeAcceptedCall: viewerLeftRealRoomExit,
        closePopupIfOpen: viewerLeftRealRoomExit,
        reason: 'viewer_left_safe',
      );
      if (!viewerLeftRealRoomExit) {
        debugPrint(
          'VIEWER_PRESENCE_PRESERVED => user=$userId reason=$leaveReason '
              'removeViewer=${payload['remove_viewer']} viewerRemoved=${payload['viewer_removed']}',
        );
        if (viewerLeftUserStillOnSeat) {
          for (final raw in liveCallList) {
            if (raw is! Map) continue;
            final call = Map<String, dynamic>.from(raw);
            if (_callUserId(call) != _toInt(userId)) continue;
            _ensureViewerRowFromCall(call);
            break;
          }
        } else {
          _ensureViewerRowAfterSeatLeft({
            ...payload,
            if (userMap.isNotEmpty) 'user': userMap,
          });
        }
      }

      /// Only reject backend call for a real room/seat exit. Random viewer_left
      /// from presence/websocket must not kick audience out of seat.
      final int sid = _toInt(livestreamId);
      final int uid = _toInt(userId);
      if (viewerLeftRealRoomExit &&
          !viewerLeftUserStillOnSeat &&
          sid > 0 &&
          uid > 0) {
        Future.microtask(() async {
          try {
            await livestreamController.tryToRejectCall(
              streamId: sid,
              userId: uid,
            );
          } catch (e) {
            liveLog('⚠️ reject stale call on real viewer_left skipped => $e');
          }
        });
      } else {}
    } else {
      final sid = _toInt(livestreamId);
      _clearRecentRoomExit(streamId: sid, userId: userId);
      if (isSelf && sid > 0) {
        _locallyLeftStreamIds.remove(sid);
        streamID.value = sid;
      }

      _viewerJoinedAtMs[_toInt(userId)] = DateTime.now().millisecondsSinceEpoch;

      _clearStaleCallStateForUser(
        callerId: userId,
        streamId: livestreamId,
        removeAcceptedCall: false,
        closePopupIfOpen: false,
        reason: 'viewer_join_reset_old_pending',
      );
    }

    bool sameViewer(dynamic viewer) {
      if (viewer is! Map) return false;
      final nestedUserId = viewer['user'] is Map ? viewer['user']['id'] : null;
      final viewerId = viewer['viewer_id'];
      final userIdField = viewer['user_id'];
      final directId = viewer['id'];

      // viewer['id'] can be the livestream_viewers table row id, not the user id.
      // Only use it as a last fallback when no real viewer/user id is present.
      final bool hasRealViewerId =
          viewerId != null || userIdField != null || nestedUserId != null;

      return nestedUserId.toString() == userId.toString() ||
          viewerId.toString() == userId.toString() ||
          userIdField.toString() == userId.toString() ||
          (!hasRealViewerId && directId.toString() == userId.toString());
    }

    if (!isLeft) {
      // Viewer join payload jodi current room snapshot niye ase, late audience/host side
      // immediately lock/mute/gift coin current state sync kore nebo.
      syncRoomSnapshotForLateJoin(payload, source: 'viewer_add_payload');

      final exists = livestreamController.liveViewerList.any(sameViewer);

      if (!exists) {
        livestreamController.addOrUpdateViewerLocal(
          Map<String, dynamic>.from(viewerInfo),
          force: true,
        );
      }

      // Everybody should see their own entry animation after joining another live.
      // Only duplicate websocket/live_comment events are ignored by showEntryAnimationForViewer().
      if (!exists || isSelf) {
        showEntryAnimationForViewer(
          entryData: Map<String, dynamic>.from({
            ...viewerInfo,
            'user': userMap.isNotEmpty ? userMap : viewerInfo['user'],
            'viewer_id': userId,
            'livestream_id': livestreamId,
          }),
          userId: userId,
        );
      }

      if (!exists || isSelf) {
        final safeUser = userMap.isNotEmpty
            ? userMap
            : _safeAuthUserForSystemComment(userId);
        _addSystemViewerComment(
          livestreamId: livestreamId,
          user: safeUser,
          comment: 'has joined the stream',
          systemType: 'viewer_join',
        );
      }

      liveLog('✅ Unified viewer added: $userId exists=$exists');
    } else {
      // viewer_left is often a weak presence event. For normal viewer leave, remove
      // only that viewer row; never clear accepted seat/call/broadcaster state unless
      // it is an explicit room/seat exit.
      clearSpecificUserStreamData(
        userId: userId.toString(),
        rejectCallIfInCallList: false,
        // A confirmed full room exit must clear the seat/call immediately,
        // even if the previous accepted row is still present locally.
        removeAcceptedCall: viewerLeftRealRoomExit,
        closePopupIfOpen: viewerLeftRealRoomExit,
        removeViewer: viewerLeftRealRoomExit,
        reason: viewerLeftRealRoomExit
            ? 'viewer_left_safe_final'
            : 'viewer_left_presence_only',
      );

      if (!viewerLeftRealRoomExit) {
        _refreshLiveCallListSmooth();
        livestreamController.liveViewerList.refresh();
      }

      if (viewerLeftRealRoomExit) {
        final safeUser = userMap.isNotEmpty
            ? userMap
            : _safeAuthUserForSystemComment(userId);
        _addSystemViewerComment(
          livestreamId: livestreamId,
          user: safeUser,
          comment: 'left the room',
          systemType: 'viewer_left',
        );
      }
    }
  }

  void _handleUnifiedComment(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload;

    final livestreamId =
        data['livestream_id'] ??
            data['stream_id'] ??
            payload['livestream_id'] ??
            payload['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ COMMENT ignored: not current stream => $livestreamId');
      return;
    }

    final user = data['user'] ?? payload['user'];

    final commentData = {
      'type': 'message',
      'livestream_id': livestreamId,
      'user': user,
      'comment':
      data['comment'] ??
          data['message'] ??
          payload['comment'] ??
          payload['message'] ??
          '',
      'timestamp':
      data['timestamp'] ??
          payload['timestamp'] ??
          DateTime.now().toIso8601String(),
    };

    commentsList.add(commentData);
    _refreshCommentsListSmooth();

    _handleViewerSystemCommentFromLiveComment(commentData, payload);
  }

  void _handleViewerSystemCommentFromLiveComment(
      Map<String, dynamic> commentData,
      Map<String, dynamic> originalPayload,
      ) {
    try {
      final systemType =
      (originalPayload['system_type'] ??
          originalPayload['type'] ??
          commentData['system_type'] ??
          '')
          .toString()
          .toLowerCase();

      final commentText = (commentData['comment'] ?? '')
          .toString()
          .toLowerCase();

      final bool isJoin =
          systemType == 'viewer_join' ||
              systemType == 'viewer_joined' ||
              commentText.contains('has joined');
      final bool isLeft =
          systemType == 'viewer_left' ||
              systemType == 'viewer_leave' ||
              systemType == 'viewer_removed' ||
              commentText.contains('left the');

      if (!isJoin && !isLeft) return;

      final dynamic livestreamId =
          commentData['livestream_id'] ??
              originalPayload['livestream_id'] ??
              originalPayload['stream_id'];

      if (livestreamId != null && !_isCurrentStream(livestreamId)) return;

      final rawUser =
          commentData['user'] ??
              originalPayload['user'] ??
              originalPayload['viewer'];
      if (rawUser is! Map) return;

      final user = Map<String, dynamic>.from(rawUser);
      final dynamic userId =
          user['id'] ??
              originalPayload['user_id'] ??
              originalPayload['viewer_id'];
      if (userId == null) return;

      final currentUserId = authController.userProfile.value.user?.id
          ?.toString();
      final bool isSelf =
          currentUserId != null && userId.toString() == currentUserId;

      bool sameViewer(dynamic viewer) {
        if (viewer is! Map) return false;
        final nestedUserId = viewer['user'] is Map
            ? viewer['user']['id']
            : null;
        return nestedUserId.toString() == userId.toString() ||
            viewer['viewer_id'].toString() == userId.toString() ||
            viewer['user_id'].toString() == userId.toString() ||
            viewer['id'].toString() == userId.toString();
      }

      if (isLeft) {
        final int sidForGuard = _toInt(livestreamId);
        final int uidForGuard = _toInt(userId);

        /// A live_comment `viewer_left` row is informational and can arrive
        /// late/out of order after a caller was accepted. Never let that weak
        /// comment remove an active caller from the host viewer list. Explicit
        /// viewer/kick/live-end events remain the authority for room removal.
        if (_isUserAcceptedSeatLocally(userId)) {
          livestreamController.addOrUpdateViewerLocal({
            'id': uidForGuard,
            'viewer_id': uidForGuard,
            'user_id': uidForGuard,
            'livestream_id': livestreamId,
            'is_active': true,
            'user': user,
          }, force: true);
          _refreshLiveCallListSmooth();
          livestreamController.liveViewerList.refresh();
          liveLog(
            '🛡️ Ignored weak viewer_left comment for accepted caller '
                '=> user:$userId stream:$livestreamId',
          );
          return;
        }

        /// ✅ Same protection for live_comment system_type=viewer_left.
        /// A system comment can arrive after seat change/reconnect and should not
        /// remove the current user's viewer row while he is still seated.
        if (isSelf &&
            sidForGuard > 0 &&
            uidForGuard > 0 &&
            !_locallyLeftStreamIds.contains(sidForGuard) &&
            (_selfIsStillOnSeatLocally() ||
                _selfSeatNoFromLiveCallList() > 0)) {
          final int protectedSeat = _selfSeatNoFromLiveCallList();
          _markSelfHeartbeatSeatGuard(
            userId: uidForGuard,
            seatNo: protectedSeat,
          );
          livestreamController.addOrUpdateViewerLocal({
            'id': uidForGuard,
            'viewer_id': uidForGuard,
            'user_id': uidForGuard,
            'livestream_id': livestreamId,
            'is_active': true,
            'user': user,
          }, force: true);
          livestreamController.updateLivePresenceRole(
            role: 'caller',
            isOnSeat: true,
            seatNo: protectedSeat > 0 ? protectedSeat : null,
          );
          liveLog(
            '🛡️ Protected self viewer_left comment while still on seat => user:$userId seat:$protectedSeat',
          );
          return;
        }

        _markRecentRoomExit(
          streamId: livestreamId,
          userId: userId,
          milliseconds: 60000,
        );
        livestreamController.removeViewerLocal(userId);
        _viewerJoinedAtMs.remove(_toInt(userId));
        liveLog('✅ Viewer removed from live_comment system event => $userId');
        return;
      }

      /// Re-join entry fix:
      /// Backend sometimes sends only live_comment/system_type=viewer_join on 2nd join.
      /// Use manager so duplicate/stale rows are merged safely.
      if (_hasRecentRoomExit(streamId: livestreamId, userId: userId)) {
        liveLog(
          '🚫 Stale viewer_join live_comment ignored after recent room exit => user:$userId',
        );
        return;
      }

      _clearRecentRoomExit(streamId: livestreamId, userId: userId);

      final viewerInfo = <String, dynamic>{
        ...user,
        'id': userId,
        'viewer_id': originalPayload['viewer_id'] ?? userId,
        'livestream_id': livestreamId,
        'user': user,
      };

      livestreamController.addOrUpdateViewerLocal(viewerInfo, force: true);
      _viewerJoinedAtMs[_toInt(userId)] = DateTime.now().millisecondsSinceEpoch;

      // Self viewer should also see entry animation when joining another live.
      showEntryAnimationForViewer(
        entryData: Map<String, dynamic>.from(viewerInfo),
        userId: userId,
      );

      liveLog('✅ Viewer join synced from live_comment system event => $userId');
    } catch (e) {
      liveLog('⚠️ viewer system comment sync skipped => $e');
    }
  }

  void handleLocalImogiSent(Map<String, dynamic> payload) {
    _handleUnifiedImogiSent(payload, isLocal: true);
  }

  /// Public helper for local preview if needed.
  /// Existing backend websocket event still controls realtime display for everyone.
  void showLocalImogiAnimation(Map<String, dynamic> payload) {
    _handleUnifiedImogiSent(payload, isLocal: true);
  }

  void _handleUnifiedImogiSent(
      Map<String, dynamic> payload, {
        bool isLocal = false,
      }) {
    liveLog('🤖 IMOGI RAW PAYLOAD => $payload');

    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : Map<String, dynamic>.from(payload);

    final livestreamId =
        data['livestream_id'] ??
            data['stream_id'] ??
            data['streamId'] ??
            payload['livestream_id'] ??
            payload['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ IMOGI ignored: not current stream => $livestreamId');
      return;
    }

    final imogi = data['imogi'] is Map
        ? Map<String, dynamic>.from(data['imogi'])
        : data['emoji'] is Map
        ? Map<String, dynamic>.from(data['emoji'])
        : data['imogi_data'] is Map
        ? Map<String, dynamic>.from(data['imogi_data'])
        : <String, dynamic>{
      'id': data['imogi_id'] ?? data['emoji_id'],
      'name': data['imogi_name'] ?? data['emoji_name'] ?? 'Imogi',
      'image':
      data['imogi_image'] ?? data['emoji_image'] ?? data['image'],
      'category': data['category'],
    };

    final sender = data['sender'] is Map
        ? Map<String, dynamic>.from(data['sender'])
        : data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : <String, dynamic>{
      'id': data['sender_id'] ?? data['user_id'],
      'name': data['sender_name'] ?? data['user_name'] ?? 'User',
      'level': data['sender_level'] ?? data['level'] ?? 0,
      'profile_image':
      data['sender_profile_image'] ??
          data['profile_image'] ??
          data['avatar'],
    };

    final senderId = sender['id'] ?? data['sender_id'] ?? data['user_id'] ?? '';
    final imogiId = imogi['id'] ?? data['imogi_id'] ?? data['emoji_id'] ?? '';
    final eventId =
    (data['id'] ??
        data['event_id'] ??
        '${livestreamId}_${senderId}_${imogiId}_${data['timestamp'] ?? data['created_at'] ?? DateTime.now().millisecondsSinceEpoch}')
        .toString();

    if (!isLocal && processedImogiIds.contains(eventId)) {
      liveLog('ℹ️ Duplicate imogi ignored => $eventId');
      return;
    }

    processedImogiIds.add(eventId);
    if (processedImogiIds.length > 120) {
      processedImogiIds.remove(processedImogiIds.first);
    }

    final animationData = <String, dynamic>{
      'event_id': eventId,
      'livestream_id': livestreamId,
      'sender': sender,
      'imogi': imogi,
      'image': imogi['image'],
      'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
    };

    liveImogiAnimations.add(animationData);
    liveImogiAnimations.refresh();

    liveLog('✅ Imogi animation shown => sender:$senderId imogi:$imogiId');

    Timer(const Duration(milliseconds: 3600), () {
      liveImogiAnimations.removeWhere((item) {
        return item is Map && item['event_id'].toString() == eventId;
      });
      liveImogiAnimations.refresh();
    });
  }

  void _handleLuckyGiftResult(Map<String, dynamic> payload) {
    try {
      _forceGiftPrint('🍀 LUCKY GIFT RESULT RAW PAYLOAD', payload);

      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final livestreamId =
          data['livestream_id'] ??
              data['stream_id'] ??
              payload['livestream_id'] ??
              payload['stream_id'];

      _forceGiftPrint('🍀 LUCKY GIFT RESULT ROOT PARSED', {
        'resolved_livestream_id': livestreamId,
        'is_current_stream': livestreamId == null
            ? true
            : _isCurrentStream(livestreamId),
        'root_payload': payload,
        'parsed_data': data,
      });

      if (livestreamId != null && !_isCurrentStream(livestreamId)) {
        liveLog('⛔ Lucky gift ignored: not current stream => $livestreamId');
        return;
      }

      int luckyInt(dynamic value, {int fallback = 0}) {
        if (value == null) return fallback;
        if (value is int) return value;
        if (value is double) return value.toInt();
        return int.tryParse(value.toString()) ?? fallback;
      }

      double luckyDouble(dynamic value, {double fallback = 0}) {
        if (value == null) return fallback;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        return double.tryParse(value.toString()) ?? fallback;
      }

      bool truthy(dynamic value) {
        final v = value?.toString().toLowerCase().trim() ?? '';
        return value == true ||
            v == '1' ||
            v == 'true' ||
            v == 'yes' ||
            v == 'win';
      }

      Map<String, dynamic> toMap(dynamic value) {
        if (value is Map<String, dynamic>) return value;
        if (value is Map) return Map<String, dynamic>.from(value);
        return <String, dynamic>{};
      }

      final sender = data['sender'] is Map
          ? toMap(data['sender'])
          : data['user'] is Map
          ? toMap(data['user'])
          : data['sender_user'] is Map
          ? toMap(data['sender_user'])
          : <String, dynamic>{
        'id': data['sender_id'] ?? data['user_id'],
        'name': data['sender_name'] ?? data['name'] ?? 'User',
        'profile_image':
        data['sender_profile_image'] ?? data['profile_image'],
        'level': data['sender_level'] ?? data['level'] ?? 0,
      };

      final gift = data['gift'] is Map
          ? toMap(data['gift'])
          : data['gift_data'] is Map
          ? toMap(data['gift_data'])
          : <String, dynamic>{
        'id': data['gift_id'],
        'name': data['gift_name'] ?? 'Lucky Gift',
        'coin': data['gift_coin'] ?? data['coin'] ?? data['coins'],
        'image': data['gift_image'] ?? data['image'],
        'gift_image': data['gift_image'] ?? data['image'],
        'show_image': data['show_image'],
        'category': 'Lucky',
      };

      // Always mark the gift object itself, so GiftAnimationWidget can
      // reliably render Lucky gifts at 100x100 instead of full screen.
      gift['is_lucky_gift'] = true;
      gift['category'] ??= 'Lucky';

      final List luckyResults = <dynamic>[];
      void addLuckyResultList(dynamic value) {
        if (value is List) luckyResults.addAll(value);
      }

      addLuckyResultList(data['big_win_events'] ?? payload['big_win_events']);
      addLuckyResultList(data['lucky_results'] ?? payload['lucky_results']);
      addLuckyResultList(data['result'] ?? payload['result']);

      final Map<String, dynamic> luckyResult = data['lucky_result'] is Map
          ? toMap(data['lucky_result'])
          : payload['lucky_result'] is Map
          ? toMap(payload['lucky_result'])
          : <String, dynamic>{};

      _forceGiftPrint('🍀 LUCKY SENDER GIFT RESULT PARTS', {
        'sender': sender,
        'receiver': data['receiver'],
        'gift': gift,
        'lucky_results': luckyResults,
        'big_win_events': data['big_win_events'] ?? payload['big_win_events'],
        'lucky_result': luckyResult,
        'direct_multiplier': data['multiplier'],
        'direct_win_amount': data['win_amount'],
        'direct_back_coin': data['back_coin'],
        'direct_win_coin': data['win_coin'],
        'direct_is_win': data['is_win'],
      });

      final bool hasActualLuckyResult =
          luckyResults.isNotEmpty ||
              luckyResult.isNotEmpty ||
              data['multiplier'] != null ||
              data['win_amount'] != null ||
              data['back_coin'] != null ||
              data['win_coin'] != null;

      if (!hasActualLuckyResult) {
        liveLog(
          '🍀 Lucky result skipped: no multiplier/win_amount/lucky_results found',
        );
        return;
      }

      /// Keep the running Lucky gift animation alive.
      /// Result data will be merged into the same GiftAnimationWidget below,
      /// so the image never restarts/cuts when lucky_gift_result arrives.
      try {
        final current = giftsData.isNotEmpty
            ? Map<String, dynamic>.from(giftsData)
            : <String, dynamic>{};
        final currentGift = _mapFrom(current['gift']);

        giftsData.value = {
          ...current,
          'sender': current['sender'] is Map ? current['sender'] : sender,
          'receiver': current['receiver'] is Map
              ? current['receiver']
              : (data['receiver'] is Map
              ? toMap(data['receiver'])
              : <String, dynamic>{}),
          'gift': {
            ...gift,
            ...currentGift,
            'is_lucky_gift': true,
            'category': 'Lucky',
          },
          'is_lucky_gift': true,
        };
        giftsData.refresh();
        if (!isGiftAnimationShowing.value) {
          isGiftAnimationShowing.value = true;
        }
      } catch (e) {
        liveLog('⚠️ Lucky normal gift animation merge failed => $e');
      }

      final List<Map<String, dynamic>> normalizedResults = [];

      if (luckyResults.isNotEmpty) {
        for (final item in luckyResults) {
          if (item is Map) {
            normalizedResults.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (luckyResult.isNotEmpty) {
        normalizedResults.add(luckyResult);
      } else {
        normalizedResults.add(<String, dynamic>{
          'is_win':
          data['is_win'] ??
              data['is_win_lucky'] ??
              (luckyInt(
                data['win_amount'] ?? data['back_coin'] ?? data['win_coin'],
              ) >
                  0),
          'win_type': data['win_type'],
          'win_amount':
          data['win_amount'] ??
              data['back_coin'] ??
              data['win_coin'] ??
              data['bonus_coin'],
          'back_coin': data['back_coin'] ?? data['win_coin'],
          'win_coin': data['win_coin'] ?? data['back_coin'],
          'multiplier':
          data['multiplier'] ??
              data['multiple'] ??
              data['x'] ??
              data['gun'],
          'gift_coin': data['gift_coin'] ?? gift['coin'],
        });
      }

      _forceGiftPrint('🍀 LUCKY NORMALIZED RESULTS BEFORE TARGET RESOLVE', {
        'normalized_results': normalizedResults,
        'current_gifts_data_before_result': giftsData,
        'is_gift_animation_showing': isGiftAnimationShowing.value,
      });

      /// Audience-side lucky gift target fix:
      /// Lucky result websocket can arrive without the original selected
      /// receiver list. Sender device already has selected receiver ids, but
      /// audience devices may only get lucky_results. Normalize receiver ids and
      /// seat numbers here so GiftAnimationWidget can send particles to every
      /// selected receiver seat on every device.
      List<int> _luckyTargetsFromAny(dynamic value, {bool seat = false}) {
        final result = <int>[];
        final seen = <int>{};

        void addOne(dynamic raw) {
          if (raw == null) return;

          if (raw is Iterable) {
            for (final item in raw) addOne(item);
            return;
          }

          if (raw is Map) {
            final map = Map<String, dynamic>.from(raw);
            final keys = seat
                ? <String>[
              'seat_no',
              'seat',
              'seat_number',
              'receiver_seat_no',
              'receiver_seat',
              'receiver_seat_number',
              'to_seat_no',
              'target_seat_no',
            ]
                : <String>[
              'receiver_id',
              'receiver_user_id',
              'to_user_id',
              'target_user_id',
              'winner_user_id',
              'user_id',
              'id',
            ];
            for (final key in keys) addOne(map[key]);
            addOne(map['receiver']);
            addOne(map['receiver_user']);
            addOne(map['to_user']);
            addOne(map['target_user']);
            addOne(map['winner']);
            return;
          }

          final text = raw.toString().trim();
          if (text.isEmpty || text.toLowerCase() == 'null') return;
          if (text.contains(',')) {
            for (final part in text.split(',')) addOne(part);
            return;
          }
          final id = _toInt(text);
          if (id > 0 && seen.add(id)) result.add(id);
        }

        addOne(value);
        return result;
      }

      final List<int> luckyAnimationReceiverIds = <int>[];
      void _addLuckyReceiverIds(dynamic value, {dynamic single}) {
        final extracted = _giftReceiverIdsFromPayload(
          value is Map<String, dynamic>
              ? value
              : value is Map
              ? Map<String, dynamic>.from(value)
              : <String, dynamic>{},
          single,
          allowReceiverList: true,
        );
        for (final id in extracted) {
          if (id > 0 && !luckyAnimationReceiverIds.contains(id)) {
            luckyAnimationReceiverIds.add(id);
          }
        }
        for (final id in _luckyTargetsFromAny(value)) {
          if (id > 0 && !luckyAnimationReceiverIds.contains(id)) {
            luckyAnimationReceiverIds.add(id);
          }
        }
      }

      _addLuckyReceiverIds(
        data,
        single: data['receiver_id'] ?? data['to_user_id'],
      );
      _addLuckyReceiverIds(
        payload,
        single: payload['receiver_id'] ?? payload['to_user_id'],
      );
      _addLuckyReceiverIds(
        luckyResult,
        single: luckyResult['receiver_id'] ?? luckyResult['to_user_id'],
      );
      for (final item in luckyResults) {
        _addLuckyReceiverIds(
          item,
          single: item is Map
              ? (item['receiver_id'] ?? item['to_user_id'] ?? item['user_id'])
              : null,
        );
      }

      try {
        final current = giftsData.isNotEmpty
            ? Map<String, dynamic>.from(giftsData)
            : <String, dynamic>{};
        _addLuckyReceiverIds(
          current,
          single: current['receiver_id'] ?? current['to_user_id'],
        );
        final existingIds =
            current['animation_receiver_ids'] ??
                current['receiver_ids_for_animation'] ??
                current['all_receiver_ids'];
        for (final id in _luckyTargetsFromAny(existingIds)) {
          if (id > 0 && !luckyAnimationReceiverIds.contains(id)) {
            luckyAnimationReceiverIds.add(id);
          }
        }
      } catch (_) {}

      final List<int> luckyAnimationSeatNos = <int>[];
      void _addLuckySeatNos(dynamic value) {
        for (final seat in _luckyTargetsFromAny(value, seat: true)) {
          if (seat > 0 && !luckyAnimationSeatNos.contains(seat)) {
            luckyAnimationSeatNos.add(seat);
          }
        }
      }

      _addLuckySeatNos(data['animation_receiver_seat_nos']);
      _addLuckySeatNos(data['receiver_seats_for_animation']);
      _addLuckySeatNos(data['receiver_seat_nos']);
      _addLuckySeatNos(data['receiver_seats']);
      _addLuckySeatNos(data['receiver_seat_no']);
      _addLuckySeatNos(data['seat_no']);
      _addLuckySeatNos(payload['animation_receiver_seat_nos']);
      _addLuckySeatNos(payload['receiver_seats_for_animation']);
      _addLuckySeatNos(payload['receiver_seat_nos']);
      _addLuckySeatNos(payload['receiver_seat_no']);
      _addLuckySeatNos(luckyResult);
      for (final item in luckyResults) _addLuckySeatNos(item);

      for (final int rid in luckyAnimationReceiverIds) {
        final seatNo = _giftSeatNoForUser(rid, data);
        if (seatNo > 0 && !luckyAnimationSeatNos.contains(seatNo)) {
          luckyAnimationSeatNos.add(seatNo);
        }
      }

      _forceGiftPrint('🍀 LUCKY ANIMATION TARGETS RESOLVED', {
        'receiver_ids': luckyAnimationReceiverIds,
        'receiver_seat_nos': luckyAnimationSeatNos,
        'current_live_call_list': liveCallList.toList(),
        'current_gifts_data': giftsData,
      });

      final String baseEventId =
      (data['event_id'] ??
          data['lucky_event_id'] ??
          '${data['action_type'] ?? 'lucky'}_${livestreamId}_${sender['id']}_${gift['id']}_${data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}')
          .toString();

      /// Prefix with action type so gift_sent and lucky_gift_result do not block each other.
      final String eventId =
          'lucky_${data['action_type'] ?? 'result'}_$baseEventId';

      if (processedGiftIds.contains(eventId)) {
        liveLog('ℹ️ Duplicate lucky gift result skipped: $eventId');
        return;
      }

      processedGiftIds.add(eventId);
      if (processedGiftIds.length > 120) {
        processedGiftIds.remove(processedGiftIds.first);
      }

      final List<Map<String, dynamic>> commentsToAdd = [];
      Map<String, dynamic>? bestResult;

      for (final result in normalizedResults) {
        final int parsedWinAmount = luckyInt(
          result['win_amount'] ??
              result['back_coin'] ??
              result['win_coin'] ??
              data['win_amount'] ??
              data['back_coin'] ??
              data['win_coin'],
        );

        final double multiplier = luckyDouble(
          result['multiplier'] ??
              result['multiple'] ??
              result['x'] ??
              data['multiplier'] ??
              data['multiple'] ??
              data['x'],
        );

        final bool isWin =
            truthy(result['is_win']) ||
                truthy(data['is_win']) ||
                parsedWinAmount > 0 ||
                multiplier > 0;

        final String winType =
        (result['win_type'] ??
            data['win_type'] ??
            (multiplier >= 100 || parsedWinAmount >= 10000
                ? 'jackpot'
                : isWin
                ? 'small_win'
                : 'loss'))
            .toString()
            .toLowerCase();

        final bool isBigWin =
            winType.contains('big') ||
                winType.contains('jackpot') ||
                multiplier >= 100 ||
                parsedWinAmount >= 10000 ||
                data['is_big_win'] == true ||
                data['is_jackpot'] == true;

        final String senderName = (sender['name'] ?? 'User').toString();

        final String multiplierText = multiplier <= 0
            ? ''
            : multiplier % 1 == 0
            ? '${multiplier.toInt()} Times'
            : '${multiplier.toStringAsFixed(1)} Times';

        final String comment = isWin
            ? '$senderName won ${multiplierText.isEmpty ? '' : '$multiplierText '}+$parsedWinAmount coins 🎉'
            : '$senderName tried Lucky Gift. Better luck next time';

        final normalized = <String, dynamic>{
          ...data,
          ...result,
          'type': 'lucky_gift_card',
          'event_id': '${eventId}_${commentsToAdd.length}',
          'livestream_id': livestreamId,
          'user': sender,
          'sender': sender,
          'gift': gift,
          'comment': comment,
          'is_lucky_gift': true,
          'is_win': isWin,
          'win_amount': parsedWinAmount,
          'back_coin': parsedWinAmount,
          'win_coin': parsedWinAmount,
          'multiplier': multiplier,
          'win_type': winType,
          'is_big_win': isBigWin,
          'animation_receiver_ids': luckyAnimationReceiverIds,
          'receiver_ids_for_animation': luckyAnimationReceiverIds,
          'all_receiver_ids': luckyAnimationReceiverIds,
          'animation_receiver_seat_nos': luckyAnimationSeatNos,
          'receiver_seats_for_animation': luckyAnimationSeatNos,
          'multi_receiver_gift':
          luckyAnimationReceiverIds.length > 1 ||
              luckyAnimationSeatNos.length > 1,
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };

        _forceGiftPrint(
          '🍀 LUCKY SINGLE RESULT NORMALIZED #${commentsToAdd.length + 1}',
          {
            'source_result': result,
            'parsed_win_amount': parsedWinAmount,
            'parsed_multiplier': multiplier,
            'parsed_is_win': isWin,
            'parsed_win_type': winType,
            'parsed_is_big_win': isBigWin,
            'normalized_result': normalized,
          },
        );

        // Lucky loss/try rows must not enter live comments. A timeline card
        // is created only when the backend confirms an actual coin win.
        final bool shouldShowLuckyWinCard = isWin && parsedWinAmount > 0;
        if (shouldShowLuckyWinCard) {
          commentsToAdd.add(normalized);

          if (bestResult == null) {
            bestResult = normalized;
          } else {
            final oldAmount = luckyInt(bestResult['win_amount']);
            final oldMultiplier = luckyDouble(bestResult['multiplier']);

            if (isBigWin ||
                parsedWinAmount > oldAmount ||
                multiplier > oldMultiplier) {
              bestResult = normalized;
            }
          }
        }
      }

      _forceGiftPrint('🍀 LUCKY FINAL RESULT COLLECTION', {
        'all_normalized_results': commentsToAdd,
        'best_result': bestResult,
        'result_count': commentsToAdd.length,
      });

      // One Lucky result event creates at most one comment card. Even if the
      // payload contains several result representations, show only the best
      // confirmed win and never duplicate it across the timeline.
      if (bestResult != null) {
        _queueGiftTimelineRow(
          Map<String, dynamic>.from(bestResult),
          alsoAddToComments: true,
        );
      }

      if (bestResult != null) {
        try {
          final current = giftsData.isNotEmpty
              ? Map<String, dynamic>.from(giftsData)
              : <String, dynamic>{};
          final currentGift = _mapFrom(current['gift']);
          final resultGift = _mapFrom(bestResult['gift']);
          final int resultSerial = DateTime.now().microsecondsSinceEpoch;

          giftsData.value = {
            ...current,
            'sender': current['sender'] is Map
                ? current['sender']
                : bestResult['sender'],
            'receiver': current['receiver'] is Map
                ? current['receiver']
                : bestResult['receiver'],
            'gift': {
              ...resultGift,
              ...currentGift,
              'is_lucky_gift': true,
              'category': 'Lucky',
            },
            'is_lucky_gift': true,
            'is_win': bestResult['is_win'],
            'win_amount': bestResult['win_amount'],
            'back_coin': bestResult['back_coin'],
            'win_coin': bestResult['win_coin'],
            'multiplier': bestResult['multiplier'],
            'win_type': bestResult['win_type'],
            'is_big_win': bestResult['is_big_win'],
            'lucky_result': Map<String, dynamic>.from(bestResult),
            'animation_receiver_ids': luckyAnimationReceiverIds,
            'receiver_ids_for_animation': luckyAnimationReceiverIds,
            'all_receiver_ids': luckyAnimationReceiverIds,
            'animation_receiver_seat_nos': luckyAnimationSeatNos,
            'receiver_seats_for_animation': luckyAnimationSeatNos,
            'multi_receiver_gift':
            luckyAnimationReceiverIds.length > 1 ||
                luckyAnimationSeatNos.length > 1,
            'lucky_result_serial': resultSerial,
            'result_event_id': bestResult['event_id'],
          };
          giftsData.refresh();
          _forceGiftPrint('🍀 LUCKY FINAL GIFTS DATA BOUND TO ANIMATION', {
            'gifts_data': giftsData,
            'best_result': bestResult,
            'animation_receiver_ids': luckyAnimationReceiverIds,
            'animation_receiver_seat_nos': luckyAnimationSeatNos,
            'result_serial': resultSerial,
            'is_gift_animation_showing': isGiftAnimationShowing.value,
          });
          liveLog(
            '🍀 Lucky HUD bind => ${bestResult['multiplier']} Times coin:${bestResult['win_amount']} serial:$resultSerial',
          );

          if (!isGiftAnimationShowing.value) {
            isGiftAnimationShowing.value = true;
          }
        } catch (e) {
          liveLog('⚠️ Lucky badge/counter merge failed => $e');
        }

        try {
          final dynamic live = Get.find<LivestreamController>();

          try {
            live.showLuckyGiftVideoStyleResult(bestResult);
          } catch (_) {
            try {
              live.showLuckyGiftResult(bestResult);
            } catch (_) {}
          }
        } catch (e) {
          liveLog('⚠️ Lucky result controller show skipped => $e');
        }

        liveLog(
          '✅ Lucky gift result shown => win:${bestResult['is_win']} amount:${bestResult['win_amount']} multiplier:${bestResult['multiplier']} type:${bestResult['win_type']}',
        );
      }
    } catch (e, st) {
      liveLog('❌ _handleLuckyGiftResult error => $e\n$st\npayload=$payload');
    }
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _giftValueOk(dynamic value) {
    if (value == null) return false;
    final v = value.toString().trim();
    return v.isNotEmpty && v.toLowerCase() != 'null' && v != '0';
  }

  dynamic _pickGiftValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (_giftValueOk(value) || value is Map || value is List) return value;
    }
    return null;
  }

  Map<String, dynamic> _mergeGiftUserMaps(List<Map<String, dynamic>> maps) {
    final merged = <String, dynamic>{};
    for (final map in maps) {
      map.forEach((key, value) {
        if (_giftValueOk(value) || value is Map || value is List) {
          merged[key.toString()] = value;
        }
      });
    }
    return merged;
  }

  Map<String, dynamic> _findGiftUserById(dynamic userId) {
    final uid = _toInt(userId);
    if (uid <= 0) return <String, dynamic>{};

    final cached = _liveUserProfileCache[uid];
    if (cached != null && cached.isNotEmpty)
      return Map<String, dynamic>.from(cached);

    try {
      final currentUser = authController.userProfile.value.user;
      if (currentUser != null && _toInt(currentUser.id) == uid) {
        return {
          'id': currentUser.id,
          'user_id': currentUser.userId,
          'name': currentUser.name,
          'level': currentUser.level,
          'profile_image': currentUser.profileImage,
          // 'asset_purchase_history': currentUser.assetPurchaseHistory,
        };
      }
    } catch (_) {}

    for (final raw in liveCallList) {
      final item = _mapFrom(raw);
      final user = _mapFrom(item['user'] ?? item['caller'] ?? item['viewer']);
      final itemId = _toInt(
        user['id'] ??
            user['user_id'] ??
            item['caller_id'] ??
            item['user_id'] ??
            item['viewer_id'] ??
            item['id'],
      );
      if (itemId == uid) return _mergeGiftUserMaps([item, user]);
    }

    try {
      for (final raw in livestreamController.liveViewerList) {
        final item = _mapFrom(raw);
        final user = _mapFrom(
          item['user'] ?? item['viewer'] ?? item['viewer_data'],
        );
        final itemId = _toInt(
          user['id'] ??
              user['user_id'] ??
              item['viewer_id'] ??
              item['user_id'] ??
              item['caller_id'] ??
              item['id'],
        );
        if (itemId == uid) return _mergeGiftUserMaps([item, user]);
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Map<String, dynamic> _normalizeGiftUser({
    required Map<String, dynamic> data,
    required String role,
    required dynamic fallbackId,
  }) {
    final direct = _mapFrom(
      _pickGiftValue(
        data,
        role == 'sender'
            ? ['sender', 'gifter', 'from_user', 'user']
            : [
          'receiver',
          'receiver_user',
          'to_user',
          'host',
          'broadcaster',
          'livestream_user',
        ],
      ),
    );

    final id =
        direct['id'] ??
            direct['user_id'] ??
            fallbackId ??
            _pickGiftValue(
              data,
              role == 'sender'
                  ? ['sender_id', 'gifter_id', 'user_id']
                  : ['receiver_id', 'to_user_id', 'host_id', 'broadcaster_id'],
            );

    final cached = _findGiftUserById(id);

    return _mergeGiftUserMaps([
      cached,
      direct,
      {
        'id': id,
        'user_id': direct['user_id'] ?? id,
        'name': _pickGiftValue(
          data,
          role == 'sender'
              ? ['sender_name', 'gifter_name', 'user_name', 'name']
              : [
            'receiver_name',
            'to_user_name',
            'host_name',
            'broadcaster_name',
          ],
        ),
        'level': _pickGiftValue(
          data,
          role == 'sender'
              ? ['sender_level', 'gifter_level', 'level']
              : [
            'receiver_level',
            'to_user_level',
            'host_level',
            'broadcaster_level',
          ],
        ),
        'profile_image': _pickGiftValue(
          data,
          role == 'sender'
              ? [
            'sender_profile_image',
            'gifter_profile_image',
            'profile_image',
            'avatar',
          ]
              : [
            'receiver_profile_image',
            'to_user_profile_image',
            'host_profile_image',
            'broadcaster_profile_image',
          ],
        ),
      },
    ]);
  }

  Map<String, dynamic> _normalizeGiftAsset(Map<String, dynamic> data) {
    final direct = _mapFrom(
      _pickGiftValue(data, ['gift', 'gift_data', 'gift_info', 'asset']),
    );
    return _mergeGiftUserMaps([
      direct,
      {
        'id':
        direct['id'] ?? _pickGiftValue(data, ['gift_id', 'asset_id', 'id']),
        'name':
        direct['name'] ??
            _pickGiftValue(data, ['gift_name', 'asset_name', 'name']),
        'image':
        direct['image'] ??
            direct['gift_image'] ??
            direct['show_image'] ??
            _pickGiftValue(data, [
              'gift_image',
              'image',
              'show_image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'gift_image':
        direct['gift_image'] ??
            direct['image'] ??
            _pickGiftValue(data, [
              'gift_image',
              'image',
              'show_image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'show_image':
        direct['show_image'] ??
            direct['image'] ??
            _pickGiftValue(data, [
              'show_image',
              'gift_image',
              'image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'coin':
        direct['coin'] ??
            direct['coins'] ??
            _pickGiftValue(data, ['gift_coin', 'coin', 'coins', 'total_coins']),
        'audio':
        direct['audio'] ??
            direct['gift_audio'] ??
            direct['sound'] ??
            direct['audio_url'] ??
            _pickGiftValue(data, [
              'audio',
              'gift_audio',
              'sound',
              'sound_url',
              'audio_url',
              'gift_sound',
            ]),
        'gift_audio':
        direct['gift_audio'] ??
            direct['audio'] ??
            direct['sound'] ??
            direct['audio_url'] ??
            _pickGiftValue(data, [
              'gift_audio',
              'audio',
              'sound',
              'sound_url',
              'audio_url',
              'gift_sound',
            ]),
        'sound':
        direct['sound'] ??
            direct['audio'] ??
            direct['gift_audio'] ??
            _pickGiftValue(data, [
              'sound',
              'audio',
              'gift_audio',
              'sound_url',
              'audio_url',
              'gift_sound',
            ]),
        'category':
        direct['category'] ??
            direct['gift_category'] ??
            direct['gift_type'] ??
            _pickGiftValue(data, [
              'category',
              'gift_category',
              'gift_type',
              'type',
            ]),
        'gift_category':
        direct['gift_category'] ??
            direct['category'] ??
            _pickGiftValue(data, ['gift_category', 'category']),
        'gift_type':
        direct['gift_type'] ??
            direct['type'] ??
            _pickGiftValue(data, ['gift_type', 'type']),
        'is_lucky': direct['is_lucky'] ?? _pickGiftValue(data, ['is_lucky']),
        'is_lucky_gift':
        direct['is_lucky_gift'] ?? _pickGiftValue(data, ['is_lucky_gift']),
        'lucky': direct['lucky'] ?? _pickGiftValue(data, ['lucky']),
        'lucky_ratio':
        direct['lucky_ratio'] ?? _pickGiftValue(data, ['lucky_ratio']),
        'lucky_coin':
        direct['lucky_coin'] ?? _pickGiftValue(data, ['lucky_coin']),
        'back_coin': direct['back_coin'] ?? _pickGiftValue(data, ['back_coin']),
      },
    ]);
  }

  String _normalGiftMediaPath(Map<String, dynamic> gift) {
    final String path =
    (gift['gift_image'] ??
        gift['image'] ??
        gift['show_image'] ??
        gift['svga'] ??
        gift['animation'] ??
        gift['animation_url'] ??
        '')
        .toString()
        .trim();

    if (path.isEmpty || path.toLowerCase() == 'null' || path == 'file:///') {
      return '';
    }
    return path;
  }

  bool _normalGiftHasPlayableMedia(Map<String, dynamic> gift) {
    return _normalGiftMediaPath(gift).isNotEmpty;
  }

  bool _mountedNormalGiftIsInvalid() {
    if (!isGiftAnimationShowing.value || giftsData.isEmpty) return false;

    final Map<String, dynamic> current = Map<String, dynamic>.from(giftsData);
    if (_isLuckyAnimationMap(current)) return false;

    final Map<String, dynamic> currentGift = _normalizeGiftAsset(current);
    return !_normalGiftHasPlayableMedia(currentGift);
  }

  Timer? _giftAnimationHideTimer;

  final Map<String, int> _recentGiftEventMs = {};

  /// Sender-side instant animation is shown before the API/WebSocket finishes.
  /// The timestamp map is kept as a safety timeout; echo credits are counted so
  /// five fast Combo taps can suppress five confirmed echoes, not only the first.
  final Map<String, int> _optimisticGiftAnimationUntilMs = {};
  final Map<String, int> _optimisticGiftEchoCredits = <String, int>{};

  /// Exact sender request identity echoed by the optimized backend.
  /// Keeping it alive for the whole response window suppresses every
  /// multi-receiver echo belonging to the same physical tap.
  final Map<String, int> _optimisticClientEventUntilMs = <String, int>{};

  /// One RxMap cannot represent several fast taps: assigning the second event
  /// used to overwrite/cut the first widget. Every event is now stored here and
  /// mounted only after the previous GiftAnimationWidget calls hideGiftAnimation.
  final Queue<Map<String, dynamic>> _giftAnimationQueue =
  Queue<Map<String, dynamic>>();
  bool _giftAnimationQueueMounting = false;

  /// Lucky reference-video card stays mounted while its individual gift flights
  /// are consumed one by one.
  Timer? _luckyCardHideTimer;
  bool _luckyCurrentFlightComplete = false;

  int _giftAnimationSerial = 0;

  void _enqueueGiftAnimation(Map<String, dynamic> rawData) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    final bool incomingLucky = _isLuckyAnimationMap(data);
    final Map<String, dynamic> incomingGift = _normalizeGiftAsset(data);

    /// Never put an image-less normal gift into FIFO. The previous first-tap
    /// delay happened because a temporary fallback gift (`Gift`, no image URL)
    /// occupied the active slot until the long safety timer fired.
    if (!incomingLucky && !_normalGiftHasPlayableMedia(incomingGift)) {
      liveLog(
        '⚡ Empty normal gift animation skipped immediately '
            '=> giftId=${incomingGift['id'] ?? data['gift_id']}',
      );
      return;
    }

    /// Repair an old/stale invisible item immediately before mounting the new
    /// valid gift. Do not wait 8-20 seconds for a safety timeout.
    if (_mountedNormalGiftIsInvalid()) {
      liveLog('⚡ Stale empty normal gift cleared before next animation');
      isGiftAnimationShowing.value = false;
      giftsData.value = <String, dynamic>{};
      giftsData.refresh();
    }

    final int serial = ++_giftAnimationSerial;

    // Preserve the sender-side physical tap serial. The queue serial is only
    // an internal ordering number; replacing the physical serial made the same
    // tap look new again when local/API/WebSocket copies reached this queue.
    final dynamic physicalSerial =
        data['gift_animation_serial'] ??
            data['animation_serial'] ??
            data['client_combo_serial'] ??
            data['combo_serial'] ??
            data['tap_serial'] ??
            data['send_serial'];
    data['gift_animation_serial'] ??= physicalSerial ?? serial;
    data['animation_serial'] ??= data['gift_animation_serial'];
    data['timestamp'] ??= DateTime.now().toIso8601String();
    data['animation_queue_serial'] = serial;

    final bool currentLucky =
        giftsData.isNotEmpty &&
            _isLuckyAnimationMap(Map<String, dynamic>.from(giftsData));

    /// Card is still visible but the previous Lucky flight has already ended:
    /// put the new tap directly into the same mounted widget.
    if (incomingLucky &&
        currentLucky &&
        isGiftAnimationShowing.value &&
        _luckyCurrentFlightComplete) {
      _mountLuckyQueueItemWithoutClosingCard(data);
      return;
    }

    // Keep the exact first 200 rapid taps. Beyond that, replace the oldest
    // not-yet-mounted item instead of allowing unbounded Map/list growth to
    // terminate low-memory devices. Normal use (including 100 taps) is exact.
    if (_giftAnimationQueue.length >= 200) {
      _giftAnimationQueue.removeFirst();
    }
    _giftAnimationQueue.addLast(data);

    _forceGiftPrint('GIFT ANIMATION QUEUE ITEM ADDED', {
      'queue_serial': serial,
      'incoming_is_lucky': incomingLucky,
      'current_is_lucky': currentLucky,
      'queue_length_after_add': _giftAnimationQueue.length,
      'is_animation_showing': isGiftAnimationShowing.value,
      'queued_data': data,
    });

    // Never drop a physical Combo tap. Queue.removeFirst() keeps processing O(1)
    // even when many taps are waiting, so exact tap count is preserved smoothly.

    if (!isGiftAnimationShowing.value && !_giftAnimationQueueMounting) {
      _showNextQueuedGiftAnimation();
    }
  }

  void _showNextQueuedGiftAnimation() {
    if (_giftAnimationQueueMounting || isGiftAnimationShowing.value) return;
    if (_giftAnimationQueue.isEmpty) return;

    _giftAnimationQueueMounting = true;
    try {
      Map<String, dynamic>? next;

      /// Old queued fallback rows may already exist from an earlier tap. Skip
      /// every invalid normal row in the same microtask so the first real SVGA
      /// mounts without a safety-timer delay.
      while (_giftAnimationQueue.isNotEmpty) {
        final Map<String, dynamic> candidate = Map<String, dynamic>.from(
          _giftAnimationQueue.removeFirst(),
        );
        final bool lucky = _isLuckyAnimationMap(candidate);
        final Map<String, dynamic> candidateGift = _normalizeGiftAsset(
          candidate,
        );

        if (lucky || _normalGiftHasPlayableMedia(candidateGift)) {
          next = candidate;
          break;
        }

        liveLog(
          '⚡ Invalid queued normal gift discarded '
              '=> giftId=${candidateGift['id'] ?? candidate['gift_id']}',
        );
      }

      if (next == null) return;

      _luckyCardHideTimer?.cancel();
      _luckyCurrentFlightComplete = false;
      giftsData.value = next;
      giftsData.refresh();

      _forceGiftPrint('GIFT ANIMATION MOUNTED FINAL DATA', {
        'mounted_gifts_data': next,
        'remaining_queue_length': _giftAnimationQueue.length,
        'gift_animation_serial': next['gift_animation_serial'],
        'animation_serial': next['animation_serial'],
      });

      isGiftAnimationShowing.value = true;
      isGiftAnimationShowing.refresh();
    } finally {
      _giftAnimationQueueMounting = false;
    }
  }

  int _giftInt(dynamic value) => _toInt(value);

  bool _payloadHasAuthoritativeGiftTotal(Map<String, dynamic> payload) {
    try {
      final List<Map<String, dynamic>> maps = <Map<String, dynamic>>[payload];

      for (final key in [
        'data',
        'livestream',
        'livestreamdata',
        'live_stream',
      ]) {
        final dynamic value = payload[key];
        if (value is Map<String, dynamic>) {
          maps.add(value);
        } else if (value is Map) {
          maps.add(Map<String, dynamic>.from(value));
        }
      }

      for (final map in maps) {
        if (map.containsKey('total_gift_coins') ||
            map.containsKey('total_coins') ||
            map.containsKey('gift_amount') ||
            map.containsKey('stream_coins') ||
            map.containsKey('received_coins')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  List<int> _giftReceiverIdsFromPayload(
      Map<String, dynamic> data,
      dynamic singleReceiverId, {
        bool allowReceiverList = false,
      }) {
    final ids = <int>[];

    void addOne(dynamic value) {
      final id = _giftInt(value);
      if (id > 0 && !ids.contains(id)) ids.add(id);
    }

    /// ✅ Important multi-receiver rule:
    /// - Local optimistic sender-side payload can use receiver_ids so every
    ///   selected user gets instant animation.
    /// - Backend/websocket echo must normally use only receiver_id, otherwise
    ///   every single receiver event adds the gift price to all selected users
    ///   again and seat coin becomes multiplied.
    if (allowReceiverList) {
      final rawList =
          data['animation_receiver_ids'] ??
              data['receiver_ids_for_animation'] ??
              data['lucky_receiver_ids'] ??
              data['all_receiver_ids'] ??
              data['receiver_ids'] ??
              data['receiverIds'] ??
              data['to_user_ids'] ??
              data['receiver_id_list'];

      if (rawList is List) {
        for (final id in rawList) {
          addOne(id);
        }
      }
    }

    addOne(singleReceiverId);
    return ids;
  }

  Map<String, dynamic> _findLiveUserForGift(dynamic rawUserId) {
    final idText = rawUserId?.toString() ?? '';
    if (idText.isEmpty || idText == 'null') return <String, dynamic>{};

    Map<String, dynamic> userFromMap(Map item) {
      final user = item['user'];
      final caller = item['caller'];
      final viewer = item['viewer'];
      final sender = item['sender'];
      final receiver = item['receiver'];

      final nested = user is Map
          ? Map<String, dynamic>.from(user)
          : caller is Map
          ? Map<String, dynamic>.from(caller)
          : viewer is Map
          ? Map<String, dynamic>.from(viewer)
          : sender is Map
          ? Map<String, dynamic>.from(sender)
          : receiver is Map
          ? Map<String, dynamic>.from(receiver)
          : <String, dynamic>{};

      final ids = [
        item['id'],
        item['user_id'],
        item['caller_id'],
        item['viewer_id'],
        nested['id'],
        nested['user_id'],
      ];

      final matched = ids.any((v) => v?.toString() == idText);
      if (!matched) return <String, dynamic>{};

      if (nested.isNotEmpty) return nested;
      return Map<String, dynamic>.from(item);
    }

    for (final list in [
      liveCallList,
      pendingCall,
      commentsList,
      giftMessagesList,
    ]) {
      for (final raw in list) {
        if (raw is! Map) continue;
        final found = userFromMap(Map<String, dynamic>.from(raw));
        if (found.isNotEmpty) return found;
      }
    }

    final currentUser = authController.userProfile.value.user;
    final currentUserId = currentUser?.id?.toInt() ?? 0;
    if (currentUserId.toString() == idText) {
      return {
        'id': currentUserId,
        'user_id': currentUserId,
        'name': currentUser?.name ?? 'You',
        'profile_image': currentUser?.profileImage ?? '',
        'level': currentUser?.level ?? 0,
        'coins': currentUser?.coins,
        'earned_coins': currentUser?.earnedCoins,
      };
    }

    return {'id': _giftInt(rawUserId), 'user_id': _giftInt(rawUserId)};
  }

  /// Sender side fallback: backend sometimes sends bulk receiver_ids but
  /// websocket broadcasts only the first receiver_id. This method updates
  /// only receivers that did not arrive through websocket within fallback delay.
  void applySenderGiftCoinFallback({
    required List<int> receiverIds,
    required int coinValue,
  }) {
    final missing = <int>[];

    for (final id in receiverIds) {
      if (id <= 0) continue;
      final key = _liveUserGiftCoinKey(userId: id);

      /// If websocket already updated this receiver in THIS room, don't add
      /// again. A key from another room can never suppress the current room.
      if (liveUserGiftCoins.containsKey(key)) continue;

      missing.add(id);
    }

    if (missing.isEmpty) {
      return;
    }

    _addReceiverGiftCoins(receiverIds: missing, coinValue: coinValue);
  }

  void _applyReceiverGiftCoinDeltas(Map<int, int> deltas) {
    if (deltas.isEmpty) return;

    final List<dynamic> rows = liveCallList.value;

    for (final MapEntry<int, int> entry in deltas.entries) {
      final int receiverId = entry.key;
      final int delta = entry.value;
      if (receiverId <= 0 || delta <= 0) continue;

      final String key = _liveUserGiftCoinKey(userId: receiverId);
      final int oldValue = _currentGiftCoinsForUser(receiverId);
      final int nextRoomCoins = oldValue + delta;
      liveUserGiftCoins.value[key] = nextRoomCoins;

      for (int index = 0; index < rows.length; index++) {
        final dynamic raw = rows[index];
        if (raw is! Map) continue;

        final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
        final Map<String, dynamic> oldUser = call['user'] is Map
            ? Map<String, dynamic>.from(call['user'])
            : <String, dynamic>{};

        final int callUserId = _toInt(
          call['caller_id'] ??
              call['user_id'] ??
              call['viewer_id'] ??
              oldUser['id'] ??
              oldUser['user_id'],
        );
        if (callUserId != receiverId) continue;

        /// Update only room-scoped coin fields. Never overwrite
        /// earned_coins/earn_coins/gifts_coins/received_coins here because those
        /// can be lifetime wallet totals from the user profile.
        call['current_gift_coins'] = nextRoomCoins;
        call['current_live_gift_coins'] = nextRoomCoins;
        call['live_gift_coins'] = nextRoomCoins;
        call['stream_gift_coins'] = nextRoomCoins;

        if (oldUser.isNotEmpty) {
          oldUser['current_gift_coins'] = nextRoomCoins.toString();
          oldUser['current_live_gift_coins'] = nextRoomCoins.toString();
          oldUser['live_gift_coins'] = nextRoomCoins.toString();
          oldUser['stream_gift_coins'] = nextRoomCoins.toString();
          call['user'] = oldUser;
        }

        // Mutate the RxList's underlying value and notify once after every
        // receiver is processed. liveCallList[index] = ... emitted one rebuild
        // per receiver and became expensive for 8/20/100 receiver gifts.
        rows[index] = call;
        break;
      }
    }

    liveUserGiftCoins.refresh();
    _refreshLiveCallListSmooth();
  }

  void _addReceiverGiftCoins({
    required List<int> receiverIds,
    required int coinValue,
  }) {
    if (coinValue <= 0 || receiverIds.isEmpty) return;

    final Map<int, int> deltas = <int, int>{};
    for (final int rawId in receiverIds) {
      final int receiverId = _toInt(rawId);
      if (receiverId <= 0) continue;
      deltas[receiverId] = (deltas[receiverId] ?? 0) + coinValue;
    }

    _applyReceiverGiftCoinDeltas(deltas);
  }

  int _giftSeatNoForUser(dynamic rawUserId, Map<String, dynamic> payload) {
    final int userId = _toInt(rawUserId);
    if (userId <= 0) return 0;

    final Map<String, dynamic> sender = _mapFrom(
      payload['sender'] ?? payload['gifter'] ?? payload['from_user'],
    );
    final Map<String, dynamic> receiver = _mapFrom(
      payload['receiver'] ?? payload['receiver_user'] ?? payload['to_user'],
    );

    final int senderId = _toInt(sender['id'] ?? sender['user_id']);
    final int receiverId = _toInt(receiver['id'] ?? receiver['user_id']);

    if (senderId == userId) {
      final int senderSeat = _toInt(
        payload['sender_seat_no'] ??
            payload['sender_seat'] ??
            sender['seat_no'] ??
            sender['seat'] ??
            sender['seat_number'],
      );
      if (senderSeat > 0) return senderSeat;
    }

    if (receiverId == userId) {
      final int receiverSeat = _toInt(
        payload['receiver_seat_no'] ??
            payload['receiver_seat'] ??
            payload['seat_no'] ??
            receiver['seat_no'] ??
            receiver['seat'] ??
            receiver['seat_number'],
      );
      if (receiverSeat > 0) return receiverSeat;
    }

    for (final raw in liveCallList) {
      if (raw is! Map) continue;

      final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
      final Map<String, dynamic> user = _mapFrom(
        call['user'] ?? call['caller'] ?? call['viewer'],
      );

      final int callUserId = _toInt(
        call['caller_id'] ??
            call['user_id'] ??
            call['viewer_id'] ??
            user['id'] ??
            user['user_id'],
      );

      if (callUserId != userId) continue;

      return _toInt(
        call['seat_no'] ??
            call['seat'] ??
            call['seat_number'] ??
            user['seat_no'] ??
            user['seat'] ??
            user['seat_number'],
      );
    }

    return 0;
  }

  int _giftQuantityFromPayload(
      Map<String, dynamic> giftData,
      Map<String, dynamic> gift,
      ) {
    final int quantity = _toInt(
      giftData['quantity'] ??
          giftData['qty'] ??
          giftData['count'] ??
          giftData['gift_count'] ??
          giftData['gift_quantity'] ??
          giftData['total_gift'] ??
          giftData['total_quantity'] ??
          giftData['combo_count'] ??
          giftData['combo'] ??
          gift['quantity'] ??
          gift['qty'] ??
          gift['count'] ??
          gift['gift_count'],
    );

    return quantity > 0 ? quantity : 1;
  }

  void _printGiftOnlyLog({
    required Map<String, dynamic> giftData,
    required Map<String, dynamic> sender,
    required Map<String, dynamic> receiver,
    required Map<String, dynamic> gift,
  }) {
    final int senderId = _toInt(sender['id'] ?? sender['user_id']);
    final int receiverId = _toInt(receiver['id'] ?? receiver['user_id']);
    final int senderSeat = _giftSeatNoForUser(senderId, {
      ...giftData,
      'sender': sender,
    });
    final int receiverSeat = _giftSeatNoForUser(receiverId, {
      ...giftData,
      'receiver': receiver,
    });
    final int quantity = _giftQuantityFromPayload(giftData, gift);

    final String senderName =
    (sender['name'] ?? sender['username'] ?? ('User').appTr).toString();
    final String receiverName =
    (receiver['name'] ?? receiver['username'] ?? ('User').appTr).toString();
    final String giftName =
    (gift['name'] ?? gift['gift_name'] ?? ('Gift').appTr).toString();

    final String senderSeatText = senderSeat > 0 ? '$senderSeat' : 'none';
    final String receiverSeatText = receiverSeat > 0 ? '$receiverSeat' : 'none';

    liveLog(
      '🎁 GIFT => $senderName(ID:$senderId, seat:$senderSeatText) '
          '→ $receiverName(ID:$receiverId, seat:$receiverSeatText) '
          '| gift:$giftName | quantity:$quantity',
    );
  }

  /// Public entry for sender-side instant animation only.
  /// Coins, history and final totals still come from the confirmed WebSocket event.
  void handleOptimisticGift(Map<String, dynamic> payload) {
    _forceGiftPrint('GIFT OPTIMISTIC HANDLER INPUT ALL DATA', {
      'payload': payload,
      'current_stream_id': streamID.value,
      'active_audio_stream_id': activeAudioStreamId.value,
      'queue_length_before': _giftAnimationQueue.length,
      'current_gifts_data_before': giftsData,
    });

    _handleUnifiedGift({
      ...payload,
      'client_optimistic': true,
      'optimistic_local': true,
      'source': 'local_send',
      'force_show': true,
      'animation_only': true,
    });
  }

  void cancelOptimisticGiftAnimation({String? clientEventId}) {
    try {
      final String target = clientEventId?.trim() ?? '';

      if (target.isNotEmpty) {
        _optimisticClientEventUntilMs.remove(target);
        _giftAnimationQueue.removeWhere((Map<String, dynamic> item) {
          final String itemId =
          (item['client_event_id'] ?? item['client_request_id'] ?? '')
              .toString()
              .trim();
          return itemId == target && item['optimistic_local'] == true;
        });

        final String currentId =
        (giftsData['client_event_id'] ??
            giftsData['client_request_id'] ??
            '')
            .toString()
            .trim();

        if (currentId == target && giftsData['optimistic_local'] == true) {
          hideGiftAnimation();
        }
        return;
      }

      if (giftsData['optimistic_local'] == true) {
        hideGiftAnimation();
      }
    } catch (_) {}
  }

  void _handleUnifiedGift(Map<String, dynamic> payload) {
    _forceGiftPrint('🎁 HANDLE UNIFIED GIFT RAW PAYLOAD', payload);

    final giftData = <String, dynamic>{
      ...payload,
      ..._mapFrom(payload['data']),
      ..._mapFrom(payload['gift_data']),
      ..._mapFrom(payload['gift_info']),
    };

    _forceGiftPrint('🎁 HANDLE UNIFIED GIFT MERGED DATA', {
      'raw_payload': payload,
      'merged_gift_data': giftData,
      'raw_data': payload['data'],
      'raw_gift': payload['gift'],
      'raw_gift_data': payload['gift_data'],
      'raw_gift_info': payload['gift_info'],
      'raw_lucky_result': payload['lucky_result'],
      'raw_lucky_results': payload['lucky_results'],
    });

    final livestreamId =
        giftData['livestream_id'] ??
            giftData['stream_id'] ??
            payload['livestream_id'] ??
            payload['stream_id'];

    /// ✅ PK gift guard:
    /// During PK, gift can be sent to opponent livestream id. That is not the
    /// current stream id, but it still belongs to current PK battle and must
    /// update PK progress bar / animation. Normal single-live behavior remains
    /// unchanged.
    bool isPkGiftForCurrentBattle = false;
    try {
      final bool looksPkGift =
          payload['is_pk'] == true ||
              payload['is_pk'] == 1 ||
              payload['is_pk']?.toString() == '1' ||
              giftData['is_pk'] == true ||
              giftData['is_pk'] == 1 ||
              giftData['is_pk']?.toString() == '1' ||
              _toInt(payload['pk_id'] ?? giftData['pk_id']) > 0 ||
              (payload['pk_channel'] ??
                  payload['pk_channel_name'] ??
                  giftData['pk_channel'] ??
                  giftData['pk_channel_name'] ??
                  '')
                  .toString()
                  .trim()
                  .isNotEmpty;

      if (looksPkGift) {
        final int eventStreamId = _toInt(livestreamId);
        final int eventPkId = _toInt(payload['pk_id'] ?? giftData['pk_id']);
        final String eventChannel =
        (payload['pk_channel_name'] ??
            payload['pk_channel'] ??
            giftData['pk_channel_name'] ??
            giftData['pk_channel'] ??
            '')
            .toString()
            .trim();

        final int currentPkId = livestreamController.currentPkId.value;
        final bool pkIdMatch =
            eventPkId > 0 && currentPkId > 0 && eventPkId == currentPkId;
        final bool pkChannelMatch =
            eventChannel.isNotEmpty &&
                livestreamController.pkChannelName.value.trim().isNotEmpty &&
                eventChannel == livestreamController.pkChannelName.value.trim();
        final bool pkStreamMatch =
            eventStreamId > 0 &&
                (eventStreamId == livestreamController.pkSenderLivestreamId.value ||
                    eventStreamId ==
                        livestreamController.pkReceiverLivestreamId.value);

        isPkGiftForCurrentBattle = pkIdMatch || pkChannelMatch || pkStreamMatch;
      }
    } catch (e) {
      liveLog('⚠️ PK gift guard check skipped => $e');
    }

    if (livestreamId != null &&
        !_isCurrentStream(livestreamId) &&
        !isPkGiftForCurrentBattle) {
      liveLog('⛔ GIFT ignored: not current stream => $livestreamId');
      return;
    }

    final Map<String, dynamic> giftForLuckyCheck = _mapFrom(
      giftData['gift'] ??
          giftData['gift_data'] ??
          giftData['gift_info'] ??
          giftData['asset'],
    );

    String luckyText(dynamic value) =>
        value?.toString().trim().toLowerCase() ?? '';

    bool luckyTrue(dynamic value) {
      final text = luckyText(value);
      return value == true ||
          text == '1' ||
          text == 'true' ||
          text == 'yes' ||
          text == 'lucky';
    }

    final String luckyCategory = luckyText(
      giftForLuckyCheck['category'] ??
          giftForLuckyCheck['gift_category'] ??
          giftForLuckyCheck['gift_type'] ??
          giftForLuckyCheck['type'] ??
          giftData['category'] ??
          giftData['gift_category'] ??
          giftData['gift_type'],
    );

    final bool isLuckyGiftPayload =
        luckyText(payload['action_type']).contains('lucky') ||
            luckyText(giftData['action_type']).contains('lucky') ||
            luckyCategory.contains('lucky') ||
            luckyText(giftForLuckyCheck['name']).contains('lucky') ||
            luckyTrue(payload['is_lucky_gift']) ||
            luckyTrue(giftData['is_lucky_gift']) ||
            luckyTrue(giftForLuckyCheck['is_lucky_gift']) ||
            luckyTrue(giftForLuckyCheck['is_lucky']) ||
            luckyTrue(giftForLuckyCheck['lucky']) ||
            giftForLuckyCheck['lucky_ratio'] != null ||
            giftForLuckyCheck['lucky_coin'] != null ||
            giftForLuckyCheck['back_coin'] != null ||
            payload['lucky_results'] is List ||
            giftData['lucky_results'] is List ||
            payload['big_win_events'] is List ||
            giftData['big_win_events'] is List ||
            payload['lucky_result'] is Map ||
            giftData['lucky_result'] is Map;

    if (isLuckyGiftPayload) {
      _forceGiftPrint('🍀 LUCKY GIFT_SENT / UNIFIED GIFT FULL DATA', {
        'raw_payload': payload,
        'merged_gift_data': giftData,
        'gift_for_lucky_check': giftForLuckyCheck,
        'resolved_livestream_id': livestreamId,
        'is_pk_gift_for_current_battle': isPkGiftForCurrentBattle,
        'lucky_category': luckyCategory,
        'detected_is_lucky_gift': isLuckyGiftPayload,
        'current_gifts_data_before_handle': giftsData,
        'gift_animation_queue_length': _giftAnimationQueue.length,
      });
    }

    final bool hasLuckyResultData =
        payload['lucky_result'] is Map ||
            giftData['lucky_result'] is Map ||
            (payload['lucky_results'] is List &&
                (payload['lucky_results'] as List).isNotEmpty) ||
            (giftData['lucky_results'] is List &&
                (giftData['lucky_results'] as List).isNotEmpty) ||
            (payload['big_win_events'] is List &&
                (payload['big_win_events'] as List).isNotEmpty) ||
            (giftData['big_win_events'] is List &&
                (giftData['big_win_events'] as List).isNotEmpty) ||
            payload['multiplier'] != null ||
            giftData['multiplier'] != null ||
            payload['win_amount'] != null ||
            giftData['win_amount'] != null ||
            payload['back_coin'] != null ||
            giftData['back_coin'] != null ||
            payload['win_coin'] != null ||
            giftData['win_coin'] != null;

    if (isLuckyGiftPayload) {
      _forceGiftPrint('🍀 LUCKY GIFT DETECTION DECISION', {
        'is_lucky_gift_payload': isLuckyGiftPayload,
        'has_lucky_result_data': hasLuckyResultData,
        'action_type': payload['action_type'] ?? giftData['action_type'],
        'lucky_result': payload['lucky_result'] ?? giftData['lucky_result'],
        'lucky_results': payload['lucky_results'] ?? giftData['lucky_results'],
        'big_win_events':
        payload['big_win_events'] ?? giftData['big_win_events'],
        'multiplier': payload['multiplier'] ?? giftData['multiplier'],
        'win_amount': payload['win_amount'] ?? giftData['win_amount'],
        'back_coin': payload['back_coin'] ?? giftData['back_coin'],
        'win_coin': payload['win_coin'] ?? giftData['win_coin'],
      });
    }

    if (isLuckyGiftPayload && hasLuckyResultData) {
      try {
        _handleLuckyGiftResult({...payload, ...giftData});
      } catch (e) {
        liveLog('⚠️ lucky result from gift payload failed => $e');
      }
    } else if (isLuckyGiftPayload) {
      liveLog(
        '🍀 Lucky normal gift event received. Waiting for lucky_gift_result event...',
      );
    }

    final String unifiedAction =
    (giftData['action_type'] ??
        payload['action_type'] ??
        giftData['type'] ??
        '')
        .toString()
        .trim()
        .toLowerCase();
    final bool luckyResultOnlyAction =
        unifiedAction == 'lucky_gift_result' ||
            unifiedAction == 'lucky_gift_back_coin' ||
            unifiedAction == 'lucky_gift_card' ||
            unifiedAction.contains('lucky_result');

    // Result frames update WIN/times/coin only. They are not another physical
    // send and must never enter the visual queue.
    if (isLuckyGiftPayload && luckyResultOnlyAction) {
      return;
    }

    final senderId =
        _pickGiftValue(giftData, ['sender_id', 'gifter_id', 'user_id']) ??
            _mapFrom(
              giftData['sender'] ?? giftData['gifter'] ?? giftData['user'],
            )['id'] ??
            '';

    final receiverId =
        _pickGiftValue(giftData, [
          'receiver_id',
          'to_user_id',
          'host_id',
          'broadcaster_id',
        ]) ??
            _mapFrom(
              giftData['receiver'] ??
                  giftData['receiver_user'] ??
                  giftData['to_user'] ??
                  giftData['host'] ??
                  giftData['broadcaster'],
            )['id'] ??
            '';

    final giftId =
        _pickGiftValue(giftData, ['gift_id', 'asset_id']) ??
            _mapFrom(
              giftData['gift'] ??
                  giftData['gift_data'] ??
                  giftData['gift_info'] ??
                  giftData['asset'],
            )['id'] ??
            '';

    /// ✅ Multi receiver fix:
    /// Only sender-side optimistic payload may expand receiver_ids.
    /// Backend/websocket echo may contain receiver_ids too, but it can also
    /// send one event per receiver. If we expand that again, 300 gift x 3
    /// receivers becomes 900 on each seat.
    final bool isClientOptimisticGift =
        giftData['client_optimistic'] == true ||
            giftData['optimistic_local'] == true ||
            giftData['is_optimistic'] == true ||
            giftData['source']?.toString() == 'local_send';
    final bool alreadyExpanded = giftData['__expanded_receiver'] == true;

    /// ✅ Multi receiver robust fix:
    /// 1) If backend sends one event per receiver, use receiver_id only.
    /// 2) If backend sends one confirmed event with only receiver_ids, expand it once.
    /// 3) Local optimistic payload is normally disabled now, but kept supported.
    final bool hasConcreteSingleReceiver = _toInt(receiverId) > 0;
    final bool mayExpandReceiverList =
        !alreadyExpanded &&
            (isClientOptimisticGift || !hasConcreteSingleReceiver);

    final List<int> expandedReceiverIds = _giftReceiverIdsFromPayload(
      giftData,
      receiverId,
      allowReceiverList: mayExpandReceiverList,
    );
    // Lucky gift rule: one physical tap creates one sender-to-center image.
    // Do NOT recursively create one animation event per receiver. The single
    // Lucky request carries every receiver target and fans out in the widget.
    // Normal gifts keep the existing receiver-wise expansion behavior.
    if (!isLuckyGiftPayload &&
        !alreadyExpanded &&
        expandedReceiverIds.length > 1) {
      for (final rid in expandedReceiverIds) {
        final receiverUser = _findLiveUserForGift(rid);
        _handleUnifiedGift({
          ...giftData,
          'receiver_id': rid,
          'receiver': receiverUser,
          'receiver_user': receiverUser,
          'animation_receiver_ids': expandedReceiverIds,
          'receiver_ids_for_animation': expandedReceiverIds,
          'all_receiver_ids': expandedReceiverIds,
          'multi_receiver_gift': expandedReceiverIds.length > 1,
          '__expanded_receiver': true,
          'event_id':
          '${giftData['event_id'] ?? 'gift'}_${rid}_${DateTime.now().microsecondsSinceEpoch}',
        });
      }
      return;
    }

    /// ✅ Backend/WebSocket sometimes sends same gift event twice very fast.
    /// 800ms er moddhe same stream + sender + receiver + gift duplicate hole ignore.
    /// But user abar button click kore same gift send korle 800ms er por allow hobe.
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String clientEventId =
    (giftData['client_event_id'] ??
        giftData['client_request_id'] ??
        giftData['request_uuid'] ??
        '')
        .toString()
        .trim();

    _optimisticClientEventUntilMs.removeWhere(
          (String _, int until) => until <= nowMs,
    );

    final String shortDuplicateKey =
        '${livestreamId}_${senderId}_${receiverId}_${giftId}';
    final String luckySenderGiftKey =
        'lucky_${livestreamId}_${senderId}_${giftId}';

    final bool animationOnly = giftData['animation_only'] == true;
    final int optimisticUntil =
        _optimisticGiftAnimationUntilMs[shortDuplicateKey] ?? 0;
    final int optimisticCredits =
        _optimisticGiftEchoCredits[shortDuplicateKey] ?? 0;

    // A Lucky multi-receiver send can be echoed once per receiver. On the
    // sender device the visual already started optimistically, therefore every
    // matching confirmed echo must update data/coins only and never enqueue a
    // second image. The group key intentionally excludes receiver_id.
    final int luckyOptimisticUntil =
        _optimisticGiftAnimationUntilMs[luckySenderGiftKey] ?? 0;
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final bool senderIsCurrentUser =
        currentUserId > 0 && _toInt(senderId) == currentUserId;
    final bool suppressLuckySenderEcho =
        isLuckyGiftPayload &&
            !animationOnly &&
            senderIsCurrentUser &&
            luckyOptimisticUntil > nowMs;

    final bool suppressExactClientEcho =
        !animationOnly &&
            senderIsCurrentUser &&
            clientEventId.isNotEmpty &&
            (_optimisticClientEventUntilMs[clientEventId] ?? 0) > nowMs;

    final bool suppressConfirmedEchoAnimation =
        suppressLuckySenderEcho ||
            suppressExactClientEcho ||
            (!animationOnly && optimisticUntil > nowMs && optimisticCredits > 0);

    if (suppressConfirmedEchoAnimation && !suppressLuckySenderEcho) {
      if (optimisticCredits <= 1) {
        _optimisticGiftEchoCredits.remove(shortDuplicateKey);
        _optimisticGiftAnimationUntilMs.remove(shortDuplicateKey);
      } else {
        _optimisticGiftEchoCredits[shortDuplicateKey] = optimisticCredits - 1;
      }
    }

    final String rawServerEventId =
    (giftData['event_id'] ??
        giftData['gift_event_id'] ??
        giftData['transaction_id'] ??
        giftData['gift_history_id'] ??
        giftData['request_id'] ??
        giftData['client_event_id'] ??
        giftData['client_request_id'] ??
        giftData['timestamp'] ??
        '')
        .toString()
        .trim();
    final String duplicateEventKey =
    rawServerEventId.isNotEmpty && rawServerEventId != 'null'
        ? '${shortDuplicateKey}_$rawServerEventId'
        : shortDuplicateKey;
    final int lastMs = _recentGiftEventMs[duplicateEventKey] ?? 0;

    final bool forceShowGift =
        giftData['force_show'] == true || giftData['client_optimistic'] == true;

    /// Distinct server event ids are always accepted. When an old backend does
    /// not send an id, only a tiny 120ms duplicate window is used; the previous
    /// 800ms guard incorrectly deleted legitimate rapid Combo gifts.
    if (!animationOnly && !forceShowGift && nowMs - lastMs < 120) {
      liveLog('ℹ️ Exact fast duplicate gift ignored => $duplicateEventKey');
      return;
    }

    if (!animationOnly) {
      _recentGiftEventMs[duplicateEventKey] = nowMs;

      if (_recentGiftEventMs.length > 80) {
        _recentGiftEventMs.remove(_recentGiftEventMs.keys.first);
      }
    }

    if (_optimisticGiftAnimationUntilMs.length > 80) {
      _optimisticGiftAnimationUntilMs.remove(
        _optimisticGiftAnimationUntilMs.keys.first,
      );
    }

    /// ✅ Unique event id, so same gift repeatedly can still show.
    final String eventId =
        '${shortDuplicateKey}_${DateTime.now().microsecondsSinceEpoch}';

    processedGiftIds.add(eventId);

    if (processedGiftIds.length > 100) {
      processedGiftIds.remove(processedGiftIds.first);
    }

    final sender = _normalizeGiftUser(
      data: giftData,
      role: 'sender',
      fallbackId: senderId,
    );

    var receiver = _normalizeGiftUser(
      data: giftData,
      role: 'receiver',
      fallbackId: receiverId,
    );

    if ((_toInt(receiver['id'] ?? receiver['user_id']) <= 0 ||
        !_giftValueOk(receiver['profile_image'])) &&
        _toInt(receiverId) > 0 &&
        _toInt(receiverId) == _toInt(sender['id'] ?? sender['user_id'])) {
      receiver = Map<String, dynamic>.from(sender);
    }

    if (_toInt(receiver['id'] ?? receiver['user_id']) <= 0 ||
        !_giftValueOk(receiver['name']) ||
        !_giftValueOk(receiver['profile_image'])) {
      receiver = _mergeGiftUserMaps([
        _findLiveUserForGift(receiverId),
        receiver,
        {'id': receiverId, 'user_id': receiverId},
      ]);
    }

    final gift = _normalizeGiftAsset(giftData);

    if (isLuckyGiftPayload) {
      gift['is_lucky_gift'] = true;
      gift['category'] ??= 'Lucky';
    }

    final bool animationAssetReady =
        isLuckyGiftPayload || _normalGiftHasPlayableMedia(gift);

    /// Lucky animation target fix:
    /// For multi receiver gifts, backend may dispatch/confirm one event per receiver.
    /// We still keep the original selected receiver list only for animation targeting,
    /// so small gift particles can split into every selected receiver profile,
    /// including self-gift/profile.
    final List<int> animationReceiverIds = _giftReceiverIdsFromPayload(
      giftData,
      receiverId,
      allowReceiverList: true,
    );
    final List<int> animationReceiverSeatNos = <int>[];
    for (final int rid in animationReceiverIds) {
      final int seat = _giftSeatNoForUser(rid, giftData);
      if (seat > 0 && !animationReceiverSeatNos.contains(seat)) {
        animationReceiverSeatNos.add(seat);
      }
    }

    final Map<String, dynamic> normalizedAnimationData = {
      "sender": sender,
      "receiver": receiver,
      "gift": gift,
      "is_lucky_gift": isLuckyGiftPayload,
      "event_id": eventId,
      "optimistic_local": animationOnly,
      "animation_receiver_ids": animationReceiverIds,
      "receiver_ids_for_animation": animationReceiverIds,
      "all_receiver_ids": animationReceiverIds,
      "animation_receiver_seat_nos": animationReceiverSeatNos,
      "receiver_seats_for_animation": animationReceiverSeatNos,
      "multi_receiver_gift": animationReceiverIds.length > 1,
      "action_type": giftData['action_type'] ?? giftData['type'],
      "client_optimistic": giftData['client_optimistic'] == true,
      "optimistic_local": giftData['optimistic_local'] == true,
      "client_event_id": clientEventId,
      "client_request_id": giftData['client_request_id'] ?? clientEventId,
      "client_combo_serial": giftData['client_combo_serial'],
      "combo_serial": giftData['combo_serial'],
      "combo_count": giftData['combo_count'],
      "tap_serial": giftData['tap_serial'],
      "send_serial": giftData['send_serial'],
      "gift_animation_serial":
      giftData['gift_animation_serial'] ??
          giftData['animation_serial'] ??
          giftData['client_combo_serial'] ??
          giftData['combo_serial'],
      "source_event_id": rawServerEventId,
    };

    if (animationOnly) {
      /// Do not reserve/suppress the later confirmed WebSocket echo when the
      /// local optimistic object has no animation URL. The confirmed event can
      /// then play normally instead of being hidden behind an invisible item.
      if (!animationAssetReady) {
        liveLog(
          '⚡ Optimistic normal gift skipped: media not ready '
              '=> giftId=${gift['id'] ?? giftId}',
        );
        return;
      }

      _optimisticGiftAnimationUntilMs[shortDuplicateKey] = nowMs + 30000;
      if (clientEventId.isNotEmpty) {
        _optimisticClientEventUntilMs[clientEventId] = nowMs + 30000;
      }
      if (isLuckyGiftPayload) {
        _optimisticGiftAnimationUntilMs[luckySenderGiftKey] = nowMs + 30000;
      }
      _optimisticGiftEchoCredits[shortDuplicateKey] =
          (_optimisticGiftEchoCredits[shortDuplicateKey] ?? 0) + 1;

      normalizedAnimationData['timestamp'] = DateTime.now().toIso8601String();
      normalizedAnimationData['quantity'] = _toInt(
        giftData['quantity'] ?? giftData['gift_quantity'] ?? 1,
      ).clamp(1, 100);

      _enqueueGiftAnimation(normalizedAnimationData);
      return;
    }

    /// If the sender already started this exact animation locally, keep it
    /// running. The confirmed WebSocket event may still update data/coins below,
    /// but it must not restart or cut the SVGA.
    if (!suppressConfirmedEchoAnimation && animationAssetReady) {
      normalizedAnimationData['timestamp'] = DateTime.now().toIso8601String();
      normalizedAnimationData['quantity'] = _toInt(
        giftData['quantity'] ?? giftData['gift_quantity'] ?? 1,
      ).clamp(1, 100);
      _enqueueGiftAnimation(normalizedAnimationData);
    } else if (!suppressConfirmedEchoAnimation && !animationAssetReady) {
      liveLog(
        '⚡ Confirmed normal gift had no playable media; '
            'timeline/coins kept, animation skipped',
      );
    }

    _printGiftOnlyLog(
      giftData: giftData,
      sender: sender,
      receiver: receiver,
      gift: gift,
    );

    final giftMessage = {
      'type': 'gift',
      'livestream_id': livestreamId,
      'event_id': eventId,
      'user': sender,
      'sender': sender,
      'receiver': receiver,
      'gift': gift,
      'comment':
      '${sender['name'] ?? 'User'} sent ${gift['name'] ?? 'Gift'} to ${receiver['name'] ?? 'User'}',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Normal gifts always appear in the live Gift/All timeline. Lucky gifts
    // are intentionally hidden here; only a confirmed WIN result is allowed
    // to create one timeline card inside _handleLuckyGiftResult(). This avoids
    // 50 rapid Lucky taps rebuilding and auto-scrolling the comment list.
    if (!isLuckyGiftPayload) {
      _queueGiftTimelineRow(Map<String, dynamic>.from(giftMessage));
    }

    final Map<String, dynamic> luckyResultForCoin = _mapFrom(
      giftData['lucky_result'],
    );
    final coinValue = _toInt(
      gift['coin'] ??
          gift['coins'] ??
          giftData['gift_coin'] ??
          giftData['gift_price'] ??
          giftData['coin'] ??
          giftData['coins'] ??
          luckyResultForCoin['gift_coin'] ??
          luckyResultForCoin['gift_cost'],
    );

    if (coinValue > 0) {
      final bool hasAuthoritativeTotal = _payloadHasAuthoritativeGiftTotal(
        giftData,
      );

      /// If backend already sends stream_coins/total_gift_coins/received_coins,
      /// do NOT add locally first. Otherwise UI jumps 22560 -> 14520.
      if (!hasAuthoritativeTotal) {
        totalGiftCoins.value += coinValue;
      } else {}

      /// ✅ Coin update must be receiver-wise, not multiplied by selected count.
      /// After optimistic expansion each recursive item has one receiver_id,
      /// so every seat receives exactly gift price once.
      final bool optimizedLuckyBatch =
          isLuckyGiftPayload &&
              (giftData['optimized_lucky_batch'] == true ||
                  giftData['optimized_lucky_batch']?.toString() == '1' ||
                  giftData['animate_once'] == true);

      final List<int> receiverIdsForCoin = _giftReceiverIdsFromPayload(
        giftData,
        receiverId,
        allowReceiverList: optimizedLuckyBatch,
      );
      _addReceiverGiftCoins(
        receiverIds: receiverIdsForCoin.isNotEmpty
            ? receiverIdsForCoin
            : [_toInt(receiverId)],
        coinValue: coinValue,
      );

      try {
        final currentUser = authController.userProfile.value.user;
        final currentUserId = currentUser?.id?.toInt() ?? 0;
        final int receiverInt = _toInt(receiverId);

        if (currentUser != null &&
            currentUserId > 0 &&
            (receiverInt == currentUserId ||
                livestreamController.isBroadcaster.value)) {
          final oldEarned = _toInt(currentUser.earnedCoins);

          /// ✅ copyWith nai, tai direct user model update
          currentUser.earnedCoins = (oldEarned + coinValue).toString();

          authController.userProfile.refresh();
        }
      } catch (e) {
        liveLog('⚠️ Local earned coin update skipped => $e');
      }
    }

    syncGiftCoinsFromPayload(giftData, source: 'gift_event');

    try {
      livestreamController.syncLiveGiftCoinsFromPayload(
        giftData,
        source: 'gift_event',
      );
    } catch (_) {}

    /// Slow network refresh must not delay the animation/seat coin UI.
    /// Refresh later only for backend-confirmed final totals.
    _scheduleGiftTotalsRefresh();

    /// ✅ Smooth animation control.
    /// Duplicate backend event ignored above, so animation cut/cut hobe na.
    /// Fixed 5 seconds timer removed.
    /// GiftAnimationWidget er SVGA onFinished callback theke hideGiftAnimation() call hobe.
    if (suppressConfirmedEchoAnimation) {
      return;
    }

    /// Non-suppressed animations were already queued above. The current
    /// GiftAnimationWidget will mount the next item after its own completion.
  }

  Map<String, dynamic>? _extractCallerUserFromPayload(
      Map<String, dynamic> payload,
      Map<String, dynamic> callData,
      ) {
    bool looksLikeUser(Map data) {
      return data['name'] != null ||
          data['profile_image'] != null ||
          data['level'] != null ||
          data['user_id'] != null;
    }

    Map<String, dynamic>? asUser(dynamic value) {
      if (value is! Map) return null;

      final map = Map<String, dynamic>.from(value);

      if (map['user'] is Map) {
        return Map<String, dynamic>.from(map['user']);
      }

      if (map['caller_user'] is Map) {
        return Map<String, dynamic>.from(map['caller_user']);
      }

      if (map['caller_info'] is Map) {
        return Map<String, dynamic>.from(map['caller_info']);
      }

      if (map['sender'] is Map) {
        return Map<String, dynamic>.from(map['sender']);
      }

      if (map['from_user'] is Map) {
        return Map<String, dynamic>.from(map['from_user']);
      }

      if (looksLikeUser(map)) {
        return map;
      }

      return null;
    }

    final candidates = [
      callData['user'],
      callData['caller_user'],
      callData['caller_info'],
      callData['caller'],
      callData['caller_data'],
      payload['user'],
      payload['caller_user'],
      payload['caller_info'],
      payload['caller'],
      payload['caller_data'],
      payload['sender'],
      payload['from_user'],
      payload['data'],
      payload['call_data'],
      payload['livestream_call'],
      payload['live_call'],
      payload['call'],
    ];

    for (final candidate in candidates) {
      final user = asUser(candidate);
      if (user != null) return user;
    }

    return null;
  }

  void _normalizeUnifiedCallUser(
      Map<String, dynamic> payload,
      Map<String, dynamic> callData,
      ) {
    final user = _extractCallerUserFromPayload(payload, callData);

    if (user != null) {
      callData['user'] = user;

      /// caller_id missing hole user id diye fill.
      callData['caller_id'] =
          callData['caller_id'] ?? callData['user_id'] ?? user['id'];

      /// User-er id missing hole caller_id diye fill.
      if (callData['user'] is Map && callData['user']['id'] == null) {
        callData['user']['id'] = callData['caller_id'];
      }
    } else {
      /// Backend jodi user object na pathay, at least popup e Unknown/null
      /// na dekhiye caller id show korbe.
      final fallbackId =
          callData['caller_id'] ??
              callData['user_id'] ??
              payload['caller_id'] ??
              payload['user_id'];

      callData['user'] = {
        'id': fallbackId,
        'user_id': fallbackId,
        'name': fallbackId == null ? 'Unknown User' : 'User $fallbackId',
        'level': 0,
        'profile_image': '',
      };
    }
  }

  bool _hasRealCallerUser(Map<String, dynamic> callData) {
    final user = callData['user'];
    if (user is! Map) return false;

    final name = user['name']?.toString() ?? '';
    final image = user['profile_image']?.toString() ?? '';

    /// fallback User 100363 ke real user dhora jabe na.
    return name.isNotEmpty &&
        !name.startsWith('User ') &&
        name != 'Unknown User' &&
        (user['level'] != null || image.isNotEmpty);
  }

  Future<void> _hydrateCallDataFromServer(
      Map<String, dynamic> callData,
      dynamic livestreamId,
      dynamic callerId,
      ) async {
    try {
      if (_hasRealCallerUser(callData)) return;
      if (livestreamId == null || callerId == null) return;

      /// API theke latest call list niye caller-er full user data merge korbo.
      /// streamId sometimes String ashe, API function int expect kore.
      final int? sid = int.tryParse(livestreamId.toString());
      await livestreamController.tryToGetCallList(
        streamId: sid ?? livestreamId,
      );

      Map? matched;

      for (final call in pendingCall) {
        if (call is Map &&
            call['caller_id'].toString() == callerId.toString()) {
          matched = call;
          break;
        }
      }

      matched ??= liveCallList.firstWhereOrNull((call) {
        return call is Map &&
            call['caller_id'].toString() == callerId.toString();
      });

      if (matched != null) {
        final full = Map<String, dynamic>.from(matched);
        callData.addAll(full);

        if (full['user'] is Map) {
          callData['user'] = Map<String, dynamic>.from(full['user']);
        }

        liveLog('✅ Caller user data hydrated from API for caller: $callerId');
      } else {
        liveLog('⚠️ Caller not found in call list while hydrating: $callerId');
      }
    } catch (e) {
      liveLog('❌ Caller user hydrate failed: $e');
    }
  }

  void _upsertPendingCall(Map<String, dynamic> incoming) {
    final int callerId = _callUserId(incoming);
    if (callerId <= 0) return;

    final index = pendingCall.indexWhere((raw) {
      return raw is Map &&
          _callUserId(Map<String, dynamic>.from(raw)) == callerId;
    });
    if (index == -1) {
      pendingCall.add(incoming);
    } else {
      final old = pendingCall[index] is Map
          ? Map<String, dynamic>.from(pendingCall[index])
          : <String, dynamic>{};
      final oldUser = old['user'] is Map
          ? Map<String, dynamic>.from(old['user'])
          : <String, dynamic>{};
      final newUser = incoming['user'] is Map
          ? Map<String, dynamic>.from(incoming['user'])
          : <String, dynamic>{};
      pendingCall[index] = <String, dynamic>{
        ...old,
        ...incoming,
        'user': <String, dynamic>{...oldUser, ...newUser},
      };
    }
    pendingCall.refresh();
  }

  void _hydrateCallDataOnce(
      Map<String, dynamic> callData,
      dynamic livestreamId,
      int callerId,
      ) {
    if (_hasRealCallerUser(callData)) return;
    final key = '${livestreamId ?? streamID.value}:$callerId';
    if (_callProfileHydrationFutures.containsKey(key)) return;

    final future = () async {
      await _hydrateCallDataFromServer(callData, livestreamId, callerId);
      _normalizeUnifiedCallUser(callData, callData);

      /// Hydration is profile enrichment only. It must NEVER create a new
      /// pending call row. Previously every accepted audio-seat caller was
      /// unconditionally re-added to pendingCall after the async API returned.
      /// If that response completed after room leave, broadcaster saw a stale
      /// Accept Call popup for a user who had already left.
      final int sid = _toInt(livestreamId ?? streamID.value);
      if (_hasRecentRoomExit(streamId: sid, userId: callerId)) {
        liveLog(
          '🚫 CALL_HYDRATE_PENDING_BLOCKED_AFTER_EXIT => '
              'stream:$sid caller:$callerId',
        );
        return;
      }

      final int pendingIndex = pendingCall.indexWhere((raw) {
        return raw is Map &&
            _callUserId(Map<String, dynamic>.from(raw)) == callerId;
      });

      if (pendingIndex == -1) {
        // Accepted/joined/left caller: nothing to add to pendingCall.
        return;
      }

      final old = pendingCall[pendingIndex] is Map
          ? Map<String, dynamic>.from(pendingCall[pendingIndex])
          : <String, dynamic>{};
      final oldUser = old['user'] is Map
          ? Map<String, dynamic>.from(old['user'])
          : <String, dynamic>{};
      final newUser = callData['user'] is Map
          ? Map<String, dynamic>.from(callData['user'])
          : <String, dynamic>{};

      pendingCall[pendingIndex] = <String, dynamic>{
        ...old,
        ...callData,
        'user': <String, dynamic>{...oldUser, ...newUser},
      };
      pendingCall.refresh();
    }();
    _callProfileHydrationFutures[key] = future;
    future.whenComplete(() => _callProfileHydrationFutures.remove(key));
  }

  void _applyNormalSeatAudioState(Map<String, dynamic> callData) {
    /// Fresh seat join must start NORMAL/UNMUTED unless backend explicitly
    /// sends audio_on=0/is_muted=1. This prevents old mute state from sticking
    /// after user was removed from mic and sits again.
    final int normalized = _normalizeAudioOn(callData);
    final int audioOn = normalized == -1 ? 1 : normalized;

    callData['audio_on'] = audioOn;
    callData['is_audio_on'] = audioOn;
    callData['is_muted'] = audioOn == 1 ? 0 : 1;
    callData['is_muted_by_host'] = audioOn == 1 ? 0 : 1;
    callData['is_speaking'] = false;

    if (callData['user'] is Map) {
      final user = Map<String, dynamic>.from(callData['user']);
      user['audio_on'] = audioOn;
      user['is_audio_on'] = audioOn;
      user['is_muted'] = audioOn == 1 ? 0 : 1;
      callData['user'] = user;
    }
  }

  bool _isSelfMutedNow() {
    final int currentUserId = _currentUserIdInt();
    if (currentUserId <= 0) return livestreamController.mute.value == true;

    if (livestreamController.mute.value == true) return true;
    if (audioMutedUserMap[currentUserId] == true) return true;

    for (final item in liveCallList) {
      if (item is! Map) continue;
      final call = Map<String, dynamic>.from(item);
      if (_callUserId(call) != currentUserId) continue;

      final mutedRaw =
          call['is_muted'] ?? call['is_muted_by_host'] ?? call['muted'];
      final audioOnRaw = call['audio_on'] ?? call['is_audio_on'];
      final mutedText = mutedRaw?.toString().toLowerCase().trim() ?? '';
      final audioText = audioOnRaw?.toString().toLowerCase().trim() ?? '';

      if (mutedText == '1' ||
          mutedText == 'true' ||
          mutedText == 'yes' ||
          mutedText == 'muted') {
        return true;
      }
      if (audioText == '0' ||
          audioText == 'false' ||
          audioText == 'off' ||
          audioText == 'muted') {
        return true;
      }
    }

    return false;
  }

  void _markSelfSeatMicStateInState({
    required String reason,
    required bool muted,
  }) {
    final int currentUserId = _currentUserIdInt();
    if (currentUserId <= 0) return;

    /// ✅ Preserve manual mute. Seat join should not clear host/caller mute icon.
    livestreamController.mute.value = muted;
    audioMutedUserMap[currentUserId] = muted;

    for (int i = 0; i < liveCallList.length; i++) {
      final item = liveCallList[i];
      if (item is! Map) continue;

      final call = Map<String, dynamic>.from(item);
      final rowUserId = _callUserId(call);
      if (rowUserId != currentUserId) continue;

      call['audio_on'] = muted ? 0 : 1;
      call['is_audio_on'] = muted ? 0 : 1;
      call['is_muted'] = muted ? 1 : 0;
      call['is_muted_by_host'] = muted ? 1 : 0;

      if (call['user'] is Map) {
        final user = Map<String, dynamic>.from(call['user']);
        user['audio_on'] = muted ? 0 : 1;
        user['is_audio_on'] = muted ? 0 : 1;
        user['is_muted'] = muted ? 1 : 0;
        call['user'] = user;
      }

      liveCallList[i] = call;
    }

    _refreshLiveCallListSmooth();
    audioMutedUserMap.refresh();
    livestreamController.update();
    liveLog(
      '✅ Self seat mic state synced => $reason user:$currentUserId muted:$muted',
    );
  }

  Future<void> _forceRepublishMySeatMic({required String reason}) async {
    /// Agora sometimes stays silent after seat leave/rejoin unless the mic
    /// is re-published with ChannelMediaOptions again.
    /// But user-er manual mute state preserve korte hobe.
    final bool keepMuted = _isSelfMutedNow();
    _markSelfSeatMicStateInState(reason: reason, muted: keepMuted);

    final engine = _agoraService.engine;
    if (engine == null) return;

    try {
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableAudio();
      await engine.enableLocalAudio(true);

      try {
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
          ),
        );
      } catch (e) {
        liveLog('⚠️ republish updateChannelMediaOptions skipped => $e');
      }

      /// Keep track published. Manual mute hole recording volume 0 kore rakhi;
      /// unmute korle backend toggle abar 100 kore debe.
      await engine.muteLocalAudioStream(false);

      try {
        await engine.adjustRecordingSignalVolume(keepMuted ? 0 : 100);
      } catch (_) {}

      try {
        await engine.enableAudioVolumeIndication(
          interval: 600,
          smooth: 3,
          reportVad: true,
        );
      } catch (_) {}

      livestreamController.mute.value = keepMuted;
      livestreamController.isMuted.value = keepMuted;
      livestreamController.isAudioEnabled.value = !keepMuted;
      liveLog(
        '✅ Seat mic republished for current user => $reason muted_preserved:$keepMuted',
      );
    } catch (e) {
      liveLog('❌ Seat mic republish failed => $reason error=$e');
    }
  }

  Future<void> _activateAcceptedCallerMedia(
      Map<String, dynamic> callData,
      int callerId,
      ) {
    final existing = _callerMediaTransitionFutures[callerId];
    if (existing != null) return existing;
    final transition = _performAcceptedCallerMedia(callData, callerId);
    _callerMediaTransitionFutures[callerId] = transition;
    return transition.whenComplete(
          () => _callerMediaTransitionFutures.remove(callerId),
    );
  }

  Future<void> _performAcceptedCallerMedia(
      Map<String, dynamic> callData,
      int callerId,
      ) async {
    final engine = _agoraService.engine;
    if (engine == null) return;
    final callType = (callData['call_type'] ?? '').toString().toLowerCase();
    final wantsVideo = callType == 'video' || callType == 'popular';

    PermissionStatus microphone = await Permission.microphone.status;
    if (!microphone.isGranted)
      microphone = await Permission.microphone.request();
    PermissionStatus camera = await Permission.camera.status;
    if (wantsVideo && !camera.isGranted)
      camera = await Permission.camera.request();

    final stillAccepted = liveCallList.any((raw) {
      if (raw is! Map) return false;
      final call = Map<String, dynamic>.from(raw);
      final status = (call['call_status'] ?? call['status'] ?? '')
          .toString()
          .toLowerCase();
      return _callUserId(call) == callerId &&
          (status == 'accepted' ||
              status == 'joined' ||
              status == 'active' ||
              status == 'live' ||
              status == 'on_seat');
    });
    if (!stillAccepted) return;

    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine.enableAudio();
    await engine.enableLocalAudio(microphone.isGranted);
    await engine.muteLocalAudioStream(!microphone.isGranted);

    final publishVideo = wantsVideo && camera.isGranted;
    if (publishVideo) {
      try {
        // Keep the caller camera in the same portrait configuration used by
        // the create-live preview. Switching to a landscape 640x360 profile
        // made faces look soft/dark and forced an expensive camera restart.
        await engine.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 540, height: 960),
            frameRate: 15,
            bitrate: 0,
            orientationMode: OrientationMode.orientationModeAdaptive,
            degradationPreference: DegradationPreference.maintainBalanced,
          ),
        );
        await engine.setParameters(
          '{"che.video.hardware_encoding": true,'
              '"che.video.enableAdaptiveBitrate": true,'
              '"rtc.video.dynamic_switch": true}',
        );
        await _agoraService.applyNaturalLowLightEnhancement();
        await _agoraService.setBeautyNatural();
      } catch (e) {
        liveLog('⚠️ Caller camera quality setup skipped safely => $e');
      }
    }
    livestreamController.isVideoEnabled.value = publishVideo;
    if (publishVideo) {
      await engine.enableVideo();
      await engine.enableLocalVideo(true);
      await engine.muteLocalVideoStream(false);
    } else {
      await engine.muteLocalVideoStream(true);
      await engine.enableLocalVideo(false);
    }

    await engine.updateChannelMediaOptions(
      ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: microphone.isGranted,
        publishCameraTrack: publishVideo,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    if (publishVideo && !_localVideoPreviewActive) {
      await engine.startPreview();
      _localVideoPreviewActive = true;
    }
    _localPublishingCallerId = callerId;
    debugPrint(
      'VIDEO_CALL_ROLE_READY => role=caller user=$callerId '
          'mic=${microphone.isGranted} camera=$publishVideo',
    );

    if (wantsVideo && !camera.isGranted) {
      Fluttertoast.showToast(
        msg: ('Camera permission is required to publish video').appTr,
      );
    }
    if (!microphone.isGranted) {
      Fluttertoast.showToast(
        msg: ('Microphone permission is required to speak').appTr,
      );
    }
    liveLog(
      '✅ Accepted caller media published => caller:$callerId '
          'mic:${microphone.isGranted} camera:$publishVideo',
    );
  }

  Future<void> _deactivateLocalCallerMedia(int callerId) async {
    final active = _callerMediaTransitionFutures[callerId];
    if (active != null) await active;
    final engine = _agoraService.engine;
    if (engine == null) return;

    if (_localVideoPreviewActive) {
      try {
        await engine.stopPreview();
      } catch (_) {}
      _localVideoPreviewActive = false;
    }
    try {
      await engine.adjustRecordingSignalVolume(0);
    } catch (_) {}
    await engine.muteLocalAudioStream(true);
    await engine.muteLocalVideoStream(true);
    await engine.enableLocalVideo(false);
    try {
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      liveLog('⚠️ Caller media unpublish options ignored => $e');
    }
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    if (_localPublishingCallerId == callerId) _localPublishingCallerId = 0;
    liveLog('✅ Local caller media unpublished => caller:$callerId');
  }

  Future<void> deactivateLocalCallerMediaForLeave(int callerId) {
    return _deactivateLocalCallerMedia(callerId);
  }

  /// Privacy-safe seat exit handling for the current device.
  ///
  /// A caller can be removed by an explicit seat-left event, a heartbeat
  /// timeout, or an authoritative occupied-seat snapshot. In every case the
  /// microphone is muted immediately. For a confirmed seat exit we also
  /// unpublish the microphone track and switch Agora back to audience mode.
  /// For a weak heartbeat timeout we keep the caller role/seat temporarily,
  /// but still mute recording so no background voice can leak.
  Future<void> _autoMuteCurrentUserAfterSeatSignal({
    required int userId,
    required String reason,
    required bool confirmedSeatExit,
  }) async {
    final int currentUserId = _currentUserIdInt();
    if (currentUserId <= 0 || userId != currentUserId) return;

    audioMutedUserMap[currentUserId] = true;
    audioMutedUserMap.refresh();

    livestreamController.mute.value = true;
    livestreamController.isMuted.value = true;
    livestreamController.isAudioEnabled.value = false;

    final engine = _agoraService.engine;
    if (engine != null) {
      try {
        /// Recording volume 0 is applied first so voice transmission stops even
        /// if Android delays the following Agora role/media-option change.
        await engine.adjustRecordingSignalVolume(0);
      } catch (_) {}

      try {
        await engine.muteLocalAudioStream(true);
      } catch (e) {
        liveLog('⚠️ Auto-mute local audio ignored [$reason] => $e');
      }

      if (confirmedSeatExit) {
        try {
          await engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleAudience,
              publishMicrophoneTrack: false,
              publishCameraTrack: false,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
        } catch (e) {
          liveLog('⚠️ Auto-unpublish mic options ignored [$reason] => $e');
        }

        try {
          await engine.setClientRole(
            role: ClientRoleType.clientRoleAudience,
          );
        } catch (e) {
          liveLog('⚠️ Auto audience role ignored [$reason] => $e');
        }
      }
    }

    if (confirmedSeatExit) {
      _heartbeatTimeoutSeatGuardUntilMs.remove(currentUserId);
      _lastKnownSelfSeatNo = 0;
      livestreamController.updateLivePresenceRole(
        role: 'viewer',
        isOnSeat: false,
        seatNo: null,
      );
    }

    livestreamController.update();
    liveLog(
      '🔇 Current user auto-muted after seat signal => '
          'user:$currentUserId confirmed:$confirmedSeatExit reason:$reason',
    );
  }

  Future<void> _muteRemoteCallerAfterConfirmedSeatExit({
    required int userId,
    required String reason,
  }) async {
    if (userId <= 0 || userId == _currentUserIdInt()) return;
    final engine = _agoraService.engine;
    if (engine == null) return;

    try {
      /// Defense in depth: even if the leaving device is slow to process its
      /// own event, this device stops playing that user's old Agora audio.
      await engine.muteRemoteAudioStream(uid: userId, mute: true);
      liveLog('🔇 Remote caller audio stopped after seat exit => user:$userId reason:$reason');
    } catch (e) {
      liveLog('⚠️ Remote caller auto-mute ignored [$reason] => $e');
    }
  }

  Future<void> _handleUnifiedLiveCall(Map<String, dynamic> payload) async {
    /// Backend-er unified event-e call data sometimes different key-te ase:
    /// call_data / caller / livestream_call / data / direct payload.
    final dynamic rawCallData =
        payload['call_data'] ??
            payload['caller_data'] ??
            payload['caller'] ??
            payload['livestream_call'] ??
            payload['live_call'] ??
            payload['call'] ??
            payload['data'] ??
            payload;

    if (rawCallData is! Map) {
      printSeatTrace('live_call_invalid_payload', error: 'payload_not_map');
      return;
    }

    final callData = Map<String, dynamic>.from(rawCallData);

    /// Popup-er name/profile/level null issue fix:
    /// backend payload-er jekhanei user data thakuk, ekhane normalize kore
    /// callData['user'] e boshiye dicchi.
    _normalizeUnifiedCallUser(payload, callData);

    /// ✅ Video call request is not a real locked seat.
    /// Backend may send seat_no=100 and is_locked=yes for video call request.
    /// That old value must not pollute seat/call UI.
    final String _incomingCallType =
    (callData['call_type'] ?? payload['call_type'] ?? '')
        .toString()
        .toLowerCase();
    final int _incomingSeatNo = _toInt(
      callData['seat_no'] ?? payload['seat_no'],
    );
    if ((_incomingCallType == 'video' || _incomingCallType == 'popular') &&
        _incomingSeatNo >= 100) {
      callData['is_locked'] = 'no';
      callData['seat_locked'] = 0;
      callData['lock_status'] = 'unlocked';
    }

    final livestreamId =
        callData['livestream_id'] ??
            callData['stream_id'] ??
            payload['livestream_id'] ??
            payload['stream_id'];

    /// streamID empty/null thakle current room set kore nebo, nahole popup block hoy.
    if ((streamID.value == null || streamID.value.toString().isEmpty) &&
        livestreamId != null) {
      streamID.value = livestreamId;
    }

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog(
        'ℹ️ live_stream_call ignored. event stream=$livestreamId current=${streamID.value}',
      );
      return;
    }

    if (!_normalizeCallTypeForCurrentRoom(
      callData,
      payload,
      livestreamId: livestreamId,
    )) {
      return;
    }

    syncCpSeatConnectionsFromAnyPayload(<String, dynamic>{
      ...payload,
      ...callData,
    }, source: 'live_stream_call_payload');

    final callerId = _toInt(
      callData['caller_id'] ??
          callData['user_id'] ??
          callData['user']?['id'] ??
          callData['user']?['user_id'] ??
          payload['caller_id'] ??
          payload['user_id'],
    );

    if (callerId == 0) {
      printSeatTrace('live_call_missing_user', streamId: _toInt(livestreamId), error: 'caller_id_missing');
      return;
    }

    /// Show payload data immediately. Missing profile details are hydrated once
    /// in the background and merged into the canonical pending request.
    _hydrateCallDataOnce(callData, livestreamId, callerId);

    final String _callTypeAfterHydrate =
    (callData['call_type'] ?? payload['call_type'] ?? '')
        .toString()
        .toLowerCase();
    final int _seatAfterHydrate = _toInt(
      callData['seat_no'] ?? payload['seat_no'],
    );
    if ((_callTypeAfterHydrate == 'video' ||
        _callTypeAfterHydrate == 'popular') &&
        _seatAfterHydrate >= 100) {
      callData['is_locked'] = 'no';
      callData['seat_locked'] = 0;
      callData['lock_status'] = 'unlocked';
    }

    /// Normalize status from many possible backend keys.
    String callStatus =
    (callData['call_status'] ??
        callData['status'] ??
        payload['call_status'] ??
        payload['status'] ??
        '')
        .toString()
        .toLowerCase()
        .trim();

    final action =
    (callData['action'] ??
        callData['call_action'] ??
        payload['action'] ??
        payload['call_action'] ??
        '')
        .toString()
        .toLowerCase()
        .trim();

    final actionType = (payload['action_type'] ?? payload['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final bool audioRoom =
        _isCurrentAudioOnlyRoom(livestreamId: livestreamId) ||
            _truthy(payload['is_audio_seat_join']) ||
            _truthy(callData['is_audio_seat_join']) ||
            ((_truthy(payload['auto_accepted']) ||
                _truthy(callData['auto_accepted'])) &&
                !_truthy(payload['requires_host_acceptance'] ??
                    callData['requires_host_acceptance']));

    if (callStatus.isEmpty) {
      /// Terminal/accepted actions MUST win before generic live_stream_call.
      /// Otherwise a room-exit/cancel frame with action_type=live_stream_call
      /// can be misclassified as a new pending request.
      if (action == 'call_accept' ||
          action == 'call_accepted' ||
          action == 'accepted') {
        callStatus = 'accepted';
      } else if (action == 'call_reject' ||
          action == 'call_rejected' ||
          action == 'rejected') {
        callStatus = 'rejected';
      } else if (action == 'call_cancel' ||
          action == 'call_canceled' ||
          action == 'canceled' ||
          action == 'cancelled') {
        callStatus = 'canceled';
      } else if (action == 'room_exit' ||
          action == 'viewer_left' ||
          action == 'viewer_remove' ||
          action == 'seat_leave' ||
          action == 'seat_left' ||
          action == 'call_end' ||
          action == 'call_ended') {
        callStatus = 'left';
      } else if (action == 'call_request' ||
          action == 'request' ||
          action == 'pending') {
        callStatus = 'pending';
      } else if (actionType == 'multi_live_seat_joined') {
        callStatus = 'joined';
      } else if (actionType == 'multi_live_seat_left' ||
          actionType == 'caller_left' ||
          actionType == 'viewer_left') {
        callStatus = 'left';
      } else if (actionType == 'live_stream_call') {
        /// Direct audio seats are auto accepted. A status-less generic frame
        /// inside audio live must never become a host confirmation request.
        callStatus = audioRoom ? 'accepted' : 'pending';
      }
    }

    if (callStatus.isEmpty) {
      callStatus = audioRoom ? 'accepted' : 'pending';
    }

    final int eventSeatNo = _toInt(
      callData['seat_no'] ?? callData['seat'] ?? callData['seat_number'],
    );

    /// Audio live has no pending host-confirmation call flow. Drop any stale
    /// pending frame instead of converting it to accepted (which could re-add a
    /// user after leave).
    if (audioRoom && callStatus == 'pending') {
      pendingCall.removeWhere((raw) {
        return raw is Map &&
            _callUserId(Map<String, dynamic>.from(raw)) == callerId;
      });
      pendingCall.refresh();
      _activeCallPopupKeys.removeWhere((key) =>
          key.startsWith('${_toInt(livestreamId)}_${_toInt(callerId)}_'));
      liveLog(
        '🚫 AUDIO_PENDING_CALL_EVENT_DROPPED => '
            'stream:${_toInt(livestreamId)} caller:$callerId seat:$eventSeatNo '
            'action:$action actionType:$actionType',
      );
      return;
    }

    /// A full room exit wins over any delayed join/pending/accepted frame.
    /// A genuine rejoin clears this guard when viewer_joined is processed.
    if (_hasRecentRoomExit(streamId: livestreamId, userId: callerId) &&
        (callStatus == 'pending' ||
            callStatus == 'accepted' ||
            callStatus == 'joined')) {
      pendingCall.removeWhere((raw) {
        return raw is Map &&
            _callUserId(Map<String, dynamic>.from(raw)) == callerId;
      });
      pendingCall.refresh();
      liveLog(
        '🚫 STALE_LIVE_CALL_IGNORED_AFTER_ROOM_EXIT => '
            'stream:${_toInt(livestreamId)} caller:$callerId '
            'status:$callStatus action:$action',
      );
      return;
    }

    printSeatTrace(
      'live_call_event',
      streamId: _toInt(livestreamId),
      userId: callerId,
      seatNo: eventSeatNo,
      status: callStatus,
      reason: action.isEmpty ? actionType : action,
    );

    final currentUserId = authController.userProfile.value.user?.id;
    final isMeCaller = currentUserId.toString() == callerId.toString();

    final popupKey = _callPopupKey(
      streamId: livestreamId ?? streamID.value,
      callerId: callerId,
      callType: callData['call_type'] ?? 'audio',
    );

    /// Jodi ei caller already liveCallList e accepted thake, late pending event ignore.
    final alreadyAccepted = liveCallList.any((call) {
      return call['caller_id'].toString() == callerId.toString() &&
          (call['call_status']?.toString().toLowerCase() == 'accepted' ||
              call['call_status']?.toString().toLowerCase() == 'joined');
    });

    if (callStatus == 'pending' &&
        (_handledCallPopupKeys.contains(popupKey) || alreadyAccepted)) {
      pendingCall.removeWhere(
            (call) => call['caller_id'].toString() == callerId.toString(),
      );
      pendingCall.refresh();
      return;
    }

    if (callStatus == 'accepted' || callStatus == 'joined') {
      livestreamController.clearDepartedCallerGuard(callerId);
      _activeCallPopupKeys.remove(popupKey);
      _handledCallPopupKeys.add(popupKey);

      /// Current user jokhon seat-e uthbe, old backend mute snapshot jeno
      /// mic off kore na dey. Fresh seat join always starts self as unmuted.
      if (isMeCaller) {
        callData['audio_on'] = 1;
        callData['is_audio_on'] = 1;
        callData['is_muted'] = 0;
        callData['is_muted_by_host'] = 0;
        if (callData['user'] is Map) {
          final user = Map<String, dynamic>.from(callData['user']);
          user['audio_on'] = 1;
          user['is_audio_on'] = 1;
          user['is_muted'] = 0;
          callData['user'] = user;
        }
      }

      pendingCall.removeWhere(
            (call) => call['caller_id'].toString() == callerId.toString(),
      );

      if (!liveCallList.any((call) {
        if (call is! Map) return false;
        final oldCallerId =
            call['caller_id'] ??
                call['user_id'] ??
                (call['user'] is Map ? call['user']['id'] : null);
        return oldCallerId.toString() == callerId.toString();
      })) {
        _applyNormalSeatAudioState(callData);
        liveCallList.add(callData);

        final int joinedUserId = _callUserId(callData);
        final int joinedAudio = _normalizeAudioOn(callData);
        if (joinedUserId > 0) {
          /// Keep mic icon/wave cache aligned with the actual seat row.
          /// Without this, old muted=true cache could survive rejoin/unmute.
          audioMutedUserMap[joinedUserId] = joinedAudio == 0;
          audioMutedUserMap.refresh();
        }
      } else {
        final index = liveCallList.indexWhere((call) {
          if (call is! Map) return false;
          final oldCallerId =
              call['caller_id'] ??
                  call['user_id'] ??
                  (call['user'] is Map ? call['user']['id'] : null);
          return oldCallerId.toString() == callerId.toString();
        });
        if (index != -1) {
          final old = liveCallList[index] is Map
              ? Map<String, dynamic>.from(liveCallList[index])
              : <String, dynamic>{};

          /// Preserve full profile/name/frame + mute/video state if late refresh event has null/minimal data.
          final merged = <String, dynamic>{...old, ...callData};

          final oldUser = old['user'] is Map
              ? Map<String, dynamic>.from(old['user'])
              : <String, dynamic>{};
          final newUser = callData['user'] is Map
              ? Map<String, dynamic>.from(callData['user'])
              : <String, dynamic>{};

          final newName = newUser['name']?.toString() ?? '';
          final oldName = oldUser['name']?.toString() ?? '';
          final newLooksFallback =
              newName.isEmpty ||
                  newName == 'Unknown User' ||
                  newName.startsWith('User ');

          if (oldUser.isNotEmpty &&
              (newUser.isEmpty || newLooksFallback) &&
              oldName.isNotEmpty) {
            merged['user'] = oldUser;
          } else {
            merged['user'] = {...oldUser, ...newUser};
          }

          /// Preserve mute state if the new event is partial/missing audio keys.
          final int newAudio = _normalizeAudioOn(callData);
          final int oldAudio = _normalizeAudioOn(old);

          final bool isSeatJoinedEvent =
              actionType == 'multi_live_seat_joined' ||
                  callStatus == 'joined' ||
                  callStatus == 'accepted';

          final int mergedAudio = newAudio != -1
              ? newAudio
              : (isSeatJoinedEvent
              ? 1
              : (oldAudio == -1
              ? (old['audio_on']?.toString() == '0' ? 0 : 1)
              : oldAudio));

          merged['audio_on'] = mergedAudio;
          merged['is_audio_on'] = mergedAudio;
          merged['is_muted'] = mergedAudio == 1 ? 0 : 1;
          merged['is_muted_by_host'] = mergedAudio == 1 ? 0 : 1;
          merged['is_speaking'] = mergedAudio == 1
              ? (merged['is_speaking'] ?? false)
              : false;

          if (merged['user'] is Map) {
            final userMap = Map<String, dynamic>.from(merged['user']);
            userMap['audio_on'] = mergedAudio;
            userMap['is_audio_on'] = mergedAudio;
            userMap['is_muted'] = mergedAudio == 1 ? 0 : 1;
            merged['user'] = userMap;
          }

          final int joinedUserId =
              int.tryParse(
                (merged['user'] is Map
                    ? merged['user']['id']
                    : (merged['user_id'] ??
                    merged['caller_id'] ??
                    callerId))
                    ?.toString() ??
                    '0',
              ) ??
                  0;
          if (joinedUserId > 0) {
            /// ✅ Critical: do not use putIfAbsent here.
            /// If user was muted before and later unmuted/rejoined, old cache=true
            /// made viewers keep muted icon and blocked speaking wave.
            audioMutedUserMap[joinedUserId] = mergedAudio == 0;
            audioMutedUserMap.refresh();
          }

          /// Preserve seat/user earned coin when late refresh sends empty/zero values.
          final int oldEarnCoins = _toInt(
            old['earn_coins'] ?? old['gift_coins'] ?? old['received_coins'],
          );
          final int newEarnCoins = _toInt(
            callData['earn_coins'] ??
                callData['gift_coins'] ??
                callData['received_coins'],
          );
          if (newEarnCoins == 0 && oldEarnCoins > 0) {
            merged['earn_coins'] = oldEarnCoins;
          } else if (newEarnCoins > 0) {
            merged['earn_coins'] = newEarnCoins;
          }

          if (merged['user'] is Map) {
            final userMap = Map<String, dynamic>.from(merged['user']);
            final int oldUserEarn = _toInt(
              oldUser['earned_coins'] ??
                  oldUser['gifts_coins'] ??
                  oldUser['coins'],
            );
            final int newUserEarn = _toInt(
              newUser['earned_coins'] ??
                  newUser['gifts_coins'] ??
                  newUser['coins'],
            );
            if (newUserEarn == 0 && oldUserEarn > 0) {
              userMap['earned_coins'] = oldUserEarn;
            }
            merged['user'] = userMap;
          }

          merged['video_on'] = callData['video_on'] ?? old['video_on'];
          merged['seat_no'] = callData['seat_no'] ?? old['seat_no'];
          merged['call_status'] =
              callData['call_status'] ?? old['call_status'] ?? 'accepted';

          liveCallList[index] = merged;
        }
      }

      if (isMeCaller) {
        final int selfSeat = _toInt(
          callData['seat_no'] ?? callData['seat'] ?? callData['seat_number'],
        );
        if (selfSeat > 0) {
          _lastKnownSelfSeatNo = selfSeat;
        }

        /// ✅ Caller-side accepted event fix:
        /// The caller app receives websocket accepted/joined event, but it may not
        /// call tryToAcceptCall() itself. So set heartbeat role here too.
        livestreamController.updateLivePresenceRole(
          role: 'caller',
          isOnSeat: true,
          seatNo: selfSeat > 0 ? selfSeat : null,
        );

        final acceptedType = (callData['call_type'] ?? '')
            .toString()
            .toLowerCase();
        if (acceptedType == 'video' || acceptedType == 'popular') {
          await _activateAcceptedCallerMedia(callData, callerId);
        } else {
          await _forceRepublishMySeatMic(
            reason: 'seat_join_or_accept caller=$callerId',
          );
        }
      }

      if (isMeCaller) {
        final selfSeat = _toInt(
          callData['seat_no'] ?? callData['seat'] ?? callData['seat_number'],
        );
        if (selfSeat > 0) {
          _lastKnownSelfSeatNo = selfSeat;
          _heartbeatTimeoutSeatGuardUntilMs.remove(_currentUserIdInt());
        }
      }

      refreshCpSeatConnectionsFromCurrentCallList(
        source: 'live_call_after_accept',
      );
      printSeatTrace(
        'live_call_accepted_applied',
        streamId: _toInt(livestreamId),
        userId: callerId,
        seatNo: _toInt(callData['seat_no'] ?? callData['seat']),
        status: callStatus,
        note: 'isSelf=$isMeCaller',
      );
      syncLivestreamCallers();
      livestreamController.syncVideoCallerAgoraMappingsFromCalls(liveCallList);
    } else if (callStatus == 'pending') {
      /// Final safety: pending confirmation is never valid in an audio-only room.
      if (audioRoom) {
        pendingCall.removeWhere((raw) {
          return raw is Map &&
              _callUserId(Map<String, dynamic>.from(raw)) == callerId;
        });
        pendingCall.refresh();
        return;
      }

      /// New pending request must be able to show again after old request was cleared.
      _handledCallPopupKeys.remove(popupKey);

      _upsertPendingCall(callData);

      if (livestreamController.canModerateLive && !isMeCaller) {
        if (_activeCallPopupKeys.contains(popupKey) ||
            _handledCallPopupKeys.contains(popupKey)) {
        } else {
          _showCallRequestPopup(
            callData,
            rtcEngine: _agoraService.engine,
            popupKey: popupKey,
          );
        }
      }
    } else if (callStatus == 'canceled' ||
        callStatus == 'cancelled' ||
        callStatus == 'rejected' ||
        callStatus == 'left' ||
        callStatus == 'ended' ||
        callStatus == 'end' ||
        callStatus == 'timeout' ||
        callStatus == 'timed_out' ||
        callStatus == 'seat_leave' ||
        callStatus == 'seat_left') {
      final bool weakAcceptedTimeout =
          (callStatus == 'timeout' || callStatus == 'timed_out') &&
              (_isUserAcceptedSeatLocally(callerId) ||
                  _isVideoCallerMediaStillActive(_toInt(callerId))) &&
              callData['remove_viewer'] != true &&
              callData['viewer_removed'] != true;

      /// Backend heartbeat/presence timeout can arrive while the caller is
      /// still connected, visible and publishing. Keep the accepted seat/call
      /// until an explicit reject/seat-left/call-end/kick event arrives.
      if (weakAcceptedTimeout) {
        for (final raw in liveCallList) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          if (_callUserId(row) != _toInt(callerId)) continue;
          _ensureViewerRowFromCall(row);
          break;
        }
        if (isMeCaller) {
          final int currentSeat = _selfSeatNoFromLiveCallList();
          final int sid = _toInt(livestreamId);
          if (_isVideoCallerMediaStillActive(_toInt(callerId)) && sid > 0) {
            livestreamController.startLivePresenceHeartbeat(
              livestreamId: sid,
              role: 'caller',
              isOnSeat: true,
              seatNo: currentSeat > 0 ? currentSeat : null,
              backgroundMode: false,
            );
          } else {
            livestreamController.updateLivePresenceRole(
              role: 'caller',
              isOnSeat: true,
              seatNo: currentSeat > 0 ? currentSeat : null,
            );
          }
        }
        _refreshLiveCallListSmooth();
        livestreamController.liveViewerList.refresh();
        printSeatTrace(
          'live_call_timeout_preserved',
          streamId: _toInt(livestreamId),
          userId: callerId,
          seatNo: _selfSeatNoFromLiveCallList(),
          status: callStatus,
          reason: 'weak_timeout',
        );
        return;
      }

      _activeCallPopupKeys.remove(popupKey);
      _handledCallPopupKeys.remove(popupKey);
      final int beforeCallCleanupCount = liveCallList.length;

      _clearStaleCallStateForUser(
        callerId: callerId,
        streamId: livestreamId,
        removeAcceptedCall: true,
        closePopupIfOpen: true,
        reason: 'call_${callStatus}',
      );
      debugPrint(
        'CALL_SESSION_CLEANUP_ONLY => user=$callerId reason=call_$callStatus',
      );
      debugPrint(
        'VIEWER_PRESENCE_PRESERVED => user=$callerId reason=call_$callStatus '
            'removeViewer=${callData['remove_viewer']} viewerRemoved=${callData['viewer_removed']}',
      );

      // This is a seat/mic leave event, not live-room leave.
      // Keep the user in viewer list so host side show/hide/profile state stays visible.
      _ensureViewerRowAfterSeatLeft(Map<String, dynamic>.from(callData));

      final int leavingUserId = int.tryParse(callerId?.toString() ?? '0') ?? 0;
      if (leavingUserId > 0) {
        // Seat leave/removal is not explicit unmute. Preserve mute state so
        // muted icon/state does not disappear after host removes user from seat.
        audioMutedUserMap.refresh();
      }

      liveCallList.removeWhere((call) {
        if (call is! Map) return false;
        final oldCallerId =
            call['caller_id'] ??
                call['user_id'] ??
                (call['user'] is Map ? call['user']['id'] : null);
        return oldCallerId.toString() == callerId.toString();
      });

      if (isMeCaller) {
        await _autoMuteCurrentUserAfterSeatSignal(
          userId: _toInt(callerId),
          reason: 'live_call_status_$callStatus',
          confirmedSeatExit: true,
        );
        await _deactivateLocalCallerMedia(callerId);
      } else {
        await _muteRemoteCallerAfterConfirmedSeatExit(
          userId: _toInt(callerId),
          reason: 'live_call_status_$callStatus',
        );
      }

      refreshCpSeatConnectionsFromCurrentCallList(
        source: 'live_call_status_${callStatus}',
      );
      printSeatTrace(
        'live_call_cleanup_applied',
        streamId: _toInt(livestreamId),
        userId: callerId,
        seatNo: eventSeatNo,
        status: callStatus,
        reason: 'explicit_call_status',
        beforeCount: beforeCallCleanupCount,
        afterCount: liveCallList.length,
      );
      syncLivestreamCallers();
    }

    _refreshLiveCallListSmooth();
    pendingCall.refresh();
  }

  Future<void> _handleUnifiedModeration(Map<String, dynamic> payload) async {
    try {
      final moderationData = Map<String, dynamic>.from(
        payload['moderation_data'] ?? payload['data'] ?? payload,
      );

      final action =
      (moderationData['action'] ??
          moderationData['moderation_action'] ??
          moderationData['type'] ??
          moderationData['action_type'] ??
          '')
          .toString()
          .toLowerCase();

      liveLog(
        '🔔 Unified moderation action => $action payload=$moderationData',
      );

      switch (action) {
        case 'kickout':
        case 'kick_out':
          _handleKickOut(moderationData);
          break;

        case 'audio_toggle':
        case 'multi_live_audio_toggle':
        case 'mute_toggle':
        case 'mic_toggle':
        case 'microphone_toggle':
        case 'mute':
        case 'unmute':
          await _handleUnifiedAudioToggle(moderationData);
          break;

        case 'video_toggle':
        case 'multi_live_video_toggle':
          await _handleUnifiedVideoToggle(moderationData);
          break;

        case 'make_guardian':
        case 'set_guardian':
        case 'assign_guardian':
        case 'guardian_assigned':
        case 'remove_guardian':
        case 'guardian_removed':
        case 'unassign_guardian':
          await livestreamController.applyGuardianFromSocket(moderationData);
          break;

        case 'live_stream_ended':
        case 'live_ended':
          _handleUnifiedLiveStreamEnded(moderationData);
          break;

        case 'broadcaster_disconnected':
        case 'host_left_room':
        case 'host_left':
        case 'host_disconnected':
        case 'host_reconnecting':
        case 'broadcaster_reconnecting':
          liveLog('ℹ️ Host disconnected moderation ignored for live end');
          break;

        default:
          liveLog('ℹ️ Unknown moderation action: $action');
          liveLog('Payload: $moderationData');
          break;
      }
    } catch (e, st) {
      liveLog('❌ _handleUnifiedModeration error => $e\n$st');
    }
  }

  Future<void> _handleUnifiedAudioToggle(Map<String, dynamic> payload) async {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final dynamic livestreamId =
          data['livestream_id'] ??
              data['stream_id'] ??
              payload['livestream_id'];

      final dynamic seatNo =
          data['seat_no'] ??
              data['seat'] ??
              data['seat_number'] ??
              data['seatNo'];

      final bool hasExplicitTargetUser =
          data['target_user_id'] != null ||
              data['receiver_id'] != null ||
              data['to_user_id'] != null ||
              data['caller_id'] != null ||
              data['user_id'] != null ||
              data['uid'] != null;

      dynamic userId =
          data['target_user_id'] ??
              data['receiver_id'] ??
              data['to_user_id'] ??
              data['caller_id'] ??
              data['user_id'] ??
              data['uid'];

      /// Host-er nijer mute/unmute event-e kichu backend only host_id/broadcaster_id
      /// pathay. Seat remove/join event-e host_id actor hote pare, tai only
      /// audio_toggle handler-e explicit target na thakle ebong seatNo na thakle
      /// host_id ke host mute target dhorbo.
      if (!hasExplicitTargetUser && seatNo == null) {
        userId =
            data['host_id'] ??
                data['broadcaster_id'] ??
                data['broadcaster_user_id'] ??
                payload['host_id'] ??
                payload['broadcaster_id'];
      }

      final dynamic audioRaw =
          data['audio_on'] ??
              data['is_audio_on'] ??
              data['mic_on'] ??
              data['microphone_on'];

      final dynamic mutedRaw =
          data['is_muted'] ??
              data['muted'] ??
              data['is_muted_by_host'] ??
              data['mute_status'];

      bool audioFalse(dynamic v) {
        final s = v?.toString().toLowerCase().trim() ?? '';
        return s == '0' ||
            s == 'false' ||
            s == 'no' ||
            s == 'off' ||
            s == 'mute' ||
            s == 'muted';
      }

      bool audioTrue(dynamic v) {
        final s = v?.toString().toLowerCase().trim() ?? '';
        return s == '1' ||
            s == 'true' ||
            s == 'yes' ||
            s == 'on' ||
            s == 'unmute' ||
            s == 'unmuted';
      }

      bool? muted;

      if (audioFalse(audioRaw)) muted = true;
      if (audioTrue(audioRaw)) muted = false;

      /// is_muted true means muted, is_muted false means unmuted.
      if (audioTrue(mutedRaw)) muted = true;
      if (audioFalse(mutedRaw)) muted = false;

      /// No audio/mute key means this is a partial payload. Never reset old state.
      if (muted == null) {
        return;
      }

      final int currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;

      final int targetUserIdForMuteMap =
          int.tryParse(userId?.toString() ?? '0') ?? 0;
      if (targetUserIdForMuteMap > 0) {
        audioMutedUserMap[targetUserIdForMuteMap] = muted;
        audioMutedUserMap.refresh();
      }

      bool updated = false;
      bool eventTargetsCurrentUser = false;

      for (int i = 0; i < liveCallList.length; i++) {
        final item = liveCallList[i];
        if (item is! Map) continue;

        final Map<String, dynamic> call = Map<String, dynamic>.from(item);

        final dynamic itemUserId = call['user'] is Map
            ? call['user']['id']
            : (call['user_id'] ?? call['caller_id'] ?? call['id']);

        final dynamic itemSeatNo =
            call['seat_no'] ??
                call['seat'] ??
                call['seat_number'] ??
                call['seatNo'];

        final bool sameUser =
            userId != null &&
                itemUserId != null &&
                userId.toString() == itemUserId.toString();

        final bool sameSeat =
            seatNo != null &&
                itemSeatNo != null &&
                seatNo.toString() == itemSeatNo.toString();

        if (sameUser || sameSeat) {
          final dynamic rowUserId = call['user'] is Map
              ? call['user']['id']
              : (call['user_id'] ?? call['caller_id'] ?? call['id']);

          final bool rowIsCurrentUser =
              currentUserId > 0 &&
                  rowUserId != null &&
                  rowUserId.toString() == currentUserId.toString();

          if (rowIsCurrentUser) {
            eventTargetsCurrentUser = true;
          }

          final int rowUserInt =
              int.tryParse(rowUserId?.toString() ?? '0') ?? 0;
          if (rowUserInt > 0) {
            audioMutedUserMap[rowUserInt] = muted;
          }

          call['audio_on'] = muted ? 0 : 1;
          call['is_audio_on'] = muted ? 0 : 1;
          call['is_muted'] = muted ? 1 : 0;
          call['is_muted_by_host'] = muted ? 1 : 0;
          if (muted) {
            call['is_speaking'] = false;
          }

          if (call['user'] is Map) {
            final user = Map<String, dynamic>.from(call['user']);
            user['audio_on'] = muted ? 0 : 1;
            user['is_audio_on'] = muted ? 0 : 1;
            user['is_muted'] = muted ? 1 : 0;
            call['user'] = user;
          }

          liveCallList[i] = call;
          updated = true;
        }
      }

      /// If backend sends only user_id (without hydrated liveCallList row yet),
      /// still apply the real Agora mic state when this event is for me.
      if (currentUserId > 0 &&
          userId != null &&
          userId.toString() == currentUserId.toString()) {
        eventTargetsCurrentUser = true;
      }

      if (updated) {
        _refreshLiveCallListSmooth();
        audioMutedUserMap.refresh();
        livestreamController.update();
      } else {}

      /// ✅ CRITICAL FIX v3:
      /// Host/admin mute/unmute must control the TARGET user's real Agora
      /// microphone publishing state. UI icon update alone is not enough.
      ///
      /// Important:
      /// - Never keep enableLocalAudio(false) after host-unmute.
      /// - On unmute, force caller role back to broadcaster and explicitly
      ///   publish microphone track again. Otherwise UI can show unmuted but
      ///   the host will not hear audio until the user taps his own mic button.
      if (eventTargetsCurrentUser && _agoraService.engine != null) {
        final engine = _agoraService.engine!;

        // Keep controller self mute flag in sync with host/admin mute state.
        // write_comments.dart uses livestreamController.mute as fallback.
        livestreamController.mute.value = muted;

        if (muted) {
          await engine.enableAudio();
          await engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await engine.enableLocalAudio(true);
          await engine.muteLocalAudioStream(true);

          // Extra safety: stop volume/wave from this local user while muted.
          try {
            await engine.adjustRecordingSignalVolume(0);
          } catch (_) {}
        } else {
          // Force full microphone re-publish when host unmute kore.
          // Order matters for Agora: role -> audio engine -> local audio -> unmute.
          await engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await engine.enableAudio();
          await engine.enableLocalAudio(true);

          // Agora 6.x: make sure microphone publishing is turned back on.
          // Some devices keep publishMicrophoneTrack=false after admin mute/role switch.
          try {
            await engine.updateChannelMediaOptions(
              const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishMicrophoneTrack: true,
                autoSubscribeAudio: true,
              ),
            );
          } catch (e) {}

          await engine.muteLocalAudioStream(false);

          // Restore recording volume. Without this, wave/audio can stay silent
          // after previous forced mute.
          try {
            await engine.adjustRecordingSignalVolume(100);
          } catch (_) {}

          try {
            await engine.enableAudioVolumeIndication(
              interval: 600,
              smooth: 3,
              reportVad: true,
            );
          } catch (_) {}
        }
      }
    } catch (e, st) {
      liveLog('❌ _handleUnifiedAudioToggle error => $e\n$st');
    }
  }

  Future<void> _handleUnifiedVideoToggle(Map<String, dynamic> payload) async {
    final normalized = <String, dynamic>{
      ...payload,
      'user_id': payload['user_id'] ?? payload['caller_id'],
    };
    if (payload.containsKey('video_on')) {
      normalized['video_on'] = payload['video_on'];
    } else if (payload.containsKey('is_video_on')) {
      normalized['is_video_on'] = payload['is_video_on'];
    }
    await _handleVideoToggle(normalized);
  }

  void _handleUnifiedSpeaking(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : Map<String, dynamic>.from(payload);

    final userId =
        data['user_id'] ??
            data['target_user_id'] ??
            data['receiver_id'] ??
            data['caller_id'] ??
            data['uid'];
    final isSpeaking = data['is_speaking'] ?? data['speaking'] ?? false;

    final index = liveCallList.indexWhere((call) {
      if (call is! Map) return false;
      final dynamic rowUserId = call['user'] is Map
          ? call['user']['id']
          : (call['caller_id'] ?? call['user_id'] ?? call['id']);
      return rowUserId.toString() == userId.toString();
    });

    if (index != -1) {
      final item = liveCallList[index];
      if (item is Map) {
        final call = Map<String, dynamic>.from(item);
        final bool muted =
            call['audio_on']?.toString() == '0' ||
                call['is_muted']?.toString() == '1' ||
                call['is_muted_by_host']?.toString() == '1';

        /// Muted seat/user should not show voice wave even if a late speaking
        /// event arrives from Agora/backend.
        call['is_speaking'] = muted ? false : isSpeaking;
        liveCallList[index] = call;
      } else {
        liveCallList[index]['is_speaking'] = isSpeaking;
      }
      _refreshLiveCallListSmooth();
    }
  }

  Map<String, dynamic> _redPacketPayloadMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _redPacketIdFrom(Map<String, dynamic> packet) {
    return _toInt(
      packet['id'] ??
          packet['red_packet_id'] ??
          packet['redPacketId'] ??
          packet['packet_id'] ??
          packet['packetId'],
    );
  }

  Map<String, dynamic> _normalizeRedPacket(Map<String, dynamic> payload) {
    final data = _redPacketPayloadMap(payload['data']);
    final candidates = <dynamic>[
      data['red_packet'],
      data['redPacket'],
      data['packet'],
      payload['red_packet'],
      payload['redPacket'],
      payload['packet'],
      data,
      payload,
    ];

    for (final item in candidates) {
      final map = _redPacketPayloadMap(item);
      if (map.isEmpty) continue;
      if (_redPacketIdFrom(map) > 0 || map['livestream_id'] != null) {
        final normalized = <String, dynamic>{...map};

        normalized['id'] = _redPacketIdFrom(normalized);
        normalized['livestream_id'] =
            normalized['livestream_id'] ??
                normalized['stream_id'] ??
                data['livestream_id'] ??
                data['stream_id'] ??
                payload['livestream_id'] ??
                payload['stream_id'];

        normalized['message'] =
            normalized['message'] ??
                data['message'] ??
                payload['message'] ??
                'Sent you a Lucky Bag';

        normalized['sender'] =
            normalized['sender'] ??
                data['sender'] ??
                payload['sender'] ??
                data['user'] ??
                payload['user'];

        normalized['expires_in_seconds'] =
            normalized['expires_in_seconds'] ??
                normalized['duration_seconds'] ??
                data['expires_in_seconds'] ??
                data['duration_seconds'] ??
                payload['expires_in_seconds'] ??
                payload['duration_seconds'] ??
                30;

        final int serverUnlockSeconds = _toInt(
          normalized['unlock_after_seconds'] ??
              normalized['open_after_seconds'] ??
              normalized['unlock_after'] ??
              normalized['open_after'] ??
              data['unlock_after_seconds'] ??
              data['open_after_seconds'] ??
              payload['unlock_after_seconds'] ??
              payload['open_after_seconds'],
        );
        final int safeOpenAfter = serverUnlockSeconds > 0
            ? serverUnlockSeconds
            : 30;
        normalized['open_after_seconds'] =
            normalized['open_after_seconds'] ?? safeOpenAfter;
        normalized['unlock_after_seconds'] =
            normalized['unlock_after_seconds'] ?? safeOpenAfter;

        normalized['status'] =
            normalized['status'] ??
                data['status'] ??
                payload['status'] ??
                'active';
        normalized['is_global'] =
            normalized['is_global'] ??
                data['is_global'] ??
                payload['is_global'] ??
                false;
        normalized['event_received_at_ms'] =
            DateTime.now().millisecondsSinceEpoch;

        return normalized;
      }
    }

    return <String, dynamic>{};
  }

  bool _sameRedPacket(Map<String, dynamic> a, Map<String, dynamic> b) {
    final int aId = _redPacketIdFrom(a);
    final int bId = _redPacketIdFrom(b);
    return aId > 0 && bId > 0 && aId == bId;
  }

  bool _redPacketForCurrentStream(Map<String, dynamic> packet) {
    final dynamic stream = packet['livestream_id'] ?? packet['stream_id'];
    if (stream == null) return true;
    return _isCurrentStream(stream);
  }

  bool _redPacketTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'global';
  }

  void _handleUnifiedRedPacketSent(Map<String, dynamic> payload) {
    _printFullLiveDebug('RED PACKET WEBSOCKET SENT RAW', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'websocket_stream_id': streamID.value,
      'active_audio_stream_id': activeAudioStreamId.value,
      'controller_stream_id': livestreamController.streamId.value,
      'raw_payload': payload,
    });

    final packet = _normalizeRedPacket(payload);

    _printFullLiveDebug('RED PACKET WEBSOCKET SENT NORMALIZED', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'normalized_packet': packet,
      'for_current_stream': packet.isNotEmpty
          ? _redPacketForCurrentStream(packet)
          : false,
      'current_red_packet_before':
      Map<String, dynamic>.from(currentRedPacket),
      'global_red_packet_before':
      Map<String, dynamic>.from(globalCurrentRedPacket),
    });

    if (packet.isEmpty) return;

    final bool global = _redPacketTruthy(packet['is_global']);

    if (global) {
      globalCurrentRedPacket.value = packet;
      globalRedPacketVisible.value = true;
      _cancelGlobalRedPacketTimer();

      /// ✅ Show app-wide Lucky Bag banner on all pages.
      /// This updates RedPacketController.globalLuckyBagData, used by the
      /// app-wide GlobalLuckyBagBanner.
      try {
        livestreamController.redPacketController
            .handleRedPacketSentForGlobalBanner(payload);
      } catch (e) {
        liveLog('⚠️ Global Lucky Bag banner handler failed => $e');
      }
    }

    if (!_redPacketForCurrentStream(packet)) {
      _printFullLiveDebug('RED PACKET WEBSOCKET SENT IGNORED FOR OTHER ROOM',
          <String, dynamic>{
            'packet': packet,
            'websocket_stream_id': streamID.value,
            'active_audio_stream_id': activeAudioStreamId.value,
            'controller_stream_id': livestreamController.streamId.value,
          });
      return;
    }

    currentRedPacket.value = packet;
    redPacketVisible.value = true;
    _cancelRedPacketTimer();

    _printFullLiveDebug('RED PACKET WEBSOCKET CURRENT STATE AFTER SENT',
        <String, dynamic>{
          'local_time': DateTime.now().toIso8601String(),
          'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
          'red_packet_visible': redPacketVisible.value,
          'current_red_packet': Map<String, dynamic>.from(currentRedPacket),
          'global_red_packet_visible': globalRedPacketVisible.value,
          'global_current_red_packet':
          Map<String, dynamic>.from(globalCurrentRedPacket),
        });

    try {
      onRedPacketReceived?.call(packet);
    } catch (e) {
      liveLog('⚠️ onRedPacketReceived failed => $e');
    }

    liveLog(
      '🧧 Red packet sent handled => id:${packet['id']} stream:${packet['livestream_id']} global:$global',
    );
  }

  void _handleUnifiedRedPacketCollected(Map<String, dynamic> payload) {
    _printFullLiveDebug('RED PACKET WEBSOCKET COLLECTED RAW',
        <String, dynamic>{
          'local_time': DateTime.now().toIso8601String(),
          'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
          'raw_payload': payload,
          'current_red_packet_before':
          Map<String, dynamic>.from(currentRedPacket),
          'global_red_packet_before':
          Map<String, dynamic>.from(globalCurrentRedPacket),
        });

    final packet = _normalizeRedPacket(payload);
    final data = _redPacketPayloadMap(payload['data']);
    final collection = _redPacketPayloadMap(
      data['collection'] ?? payload['collection'],
    );

    if (packet.isNotEmpty) {
      if (currentRedPacket.isNotEmpty &&
          _sameRedPacket(currentRedPacket, packet)) {
        currentRedPacket.value = {
          ...Map<String, dynamic>.from(currentRedPacket),
          ...packet,
        };
      }

      if (globalCurrentRedPacket.isNotEmpty &&
          _sameRedPacket(globalCurrentRedPacket, packet)) {
        globalCurrentRedPacket.value = {
          ...Map<String, dynamic>.from(globalCurrentRedPacket),
          ...packet,
        };
      }
    }

    final merged = <String, dynamic>{
      ...payload,
      if (packet.isNotEmpty) 'red_packet': packet,
      if (collection.isNotEmpty) 'collection': collection,
    };

    _printFullLiveDebug('RED PACKET WEBSOCKET COLLECTED NORMALIZED',
        <String, dynamic>{
          'local_time': DateTime.now().toIso8601String(),
          'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
          'normalized_packet': packet,
          'collection': collection,
          'merged_event': merged,
          'current_red_packet_after_merge':
          Map<String, dynamic>.from(currentRedPacket),
          'global_red_packet_after_merge':
          Map<String, dynamic>.from(globalCurrentRedPacket),
        });

    try {
      onRedPacketCollected?.call(merged);
    } catch (e) {
      liveLog('⚠️ onRedPacketCollected failed => $e');
    }

    final status = (packet['status'] ?? '').toString().toLowerCase();
    final int remainingQty = _toInt(packet['remaining_quantity']);
    if (status == 'closed' ||
        status == 'expired' ||
        status == 'refunded' ||
        remainingQty == 0 && packet.containsKey('remaining_quantity')) {
      _handleUnifiedRedPacketClosed({
        'red_packet': packet,
      }, source: 'red_packet_collected_finish');
    }
  }

  void _handleUnifiedRedPacketClosed(
      Map<String, dynamic> payload, {
        String source = 'red_packet_closed',
      }) {
    _printFullLiveDebug('RED PACKET WEBSOCKET CLOSED RAW',
        <String, dynamic>{
          'local_time': DateTime.now().toIso8601String(),
          'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
          'source': source,
          'raw_payload': payload,
          'current_red_packet_before':
          Map<String, dynamic>.from(currentRedPacket),
          'global_red_packet_before':
          Map<String, dynamic>.from(globalCurrentRedPacket),
        });

    final packet = _normalizeRedPacket(payload);

    if (packet.isEmpty) {
      hideRedPacket();
      hideGlobalRedPacket();
      return;
    }

    if (currentRedPacket.isNotEmpty &&
        _sameRedPacket(currentRedPacket, packet)) {
      hideRedPacket();
    }

    if (globalCurrentRedPacket.isNotEmpty &&
        _sameRedPacket(globalCurrentRedPacket, packet)) {
      hideGlobalRedPacket();
    }

    liveLog('🧧 Red packet closed => source:$source id:${packet['id']}');
  }

  int _pkToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> _pkAsMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  void _handlePkRequestReceived(Map<String, dynamic> payload) {
    final data = _pkAsMap(payload['data']);
    final source = data.isNotEmpty ? {...payload, ...data} : payload;
    final pkId = _pkToInt(source['pk_id'] ?? source['id']);
    final receiverHostId = _pkToInt(
      source['to_host_id'] ?? source['receiver_host_id'],
    );
    final fromHostId = _pkToInt(
      source['from_host_id'] ?? source['sender_host_id'],
    );
    final fromLivestreamId = _pkToInt(
      source['from_livestream_id'] ?? source['sender_livestream_id'],
    );

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (receiverHostId != 0 &&
        currentUserId != 0 &&
        receiverHostId != currentUserId) {
      return;
    }

    if (pkId <= 0) return;

    if (Get.isDialogOpen == true) {
      Get.back();
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.pinkAccent),
            SizedBox(width: 8),
            Text(('PK Request').appTr),
          ],
        ),
        content: Text(
          payload['message']?.toString() ??
              ('Host $fromHostId wants to start PK with you.\nLive ID: $fromLivestreamId')
                  .appTr,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (Get.isDialogOpen == true) Get.back();
              await livestreamController.respondPkRequest(
                pkId: pkId,
                receiverHostId: receiverHostId == 0
                    ? currentUserId
                    : receiverHostId,
                responseText: 'rejected',
              );
            },
            child: Text(('Reject').appTr, style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Get.isDialogOpen == true) Get.back();
              await livestreamController.respondPkRequest(
                pkId: pkId,
                receiverHostId: receiverHostId == 0
                    ? currentUserId
                    : receiverHostId,
                responseText: 'accepted',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            child: Text(
              ('Accept').appTr,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showPkWaitingToast(Map<String, dynamic> payload) {
    Fluttertoast.showToast(
      msg:
      payload['message']?.toString() ??
          ('Waiting for host to accept PK request...').appTr,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  void onClose() {
    _socketLifecycleClosed = true;
    _unifiedDisconnectIntentional = true;
    _unifiedSocketGeneration++;
    for (final purpose in _socketGenerations.keys.toList()) {
      _nextSocketGeneration(purpose);
    }
    unawaited(_disposeOwnedWebSockets());
    _liveCallRefreshTimer?.cancel();
    _commentsRefreshTimer?.cancel();
    _giftMessagesRefreshTimer?.cancel();
    _giftTotalsRefreshTimer?.cancel();
    _pendingGiftMessageRows.clear();
    _pendingGiftCommentRows.clear();
    _liveCallRefreshTimer = null;
    _commentsRefreshTimer = null;
    _giftMessagesRefreshTimer = null;
    _unifiedReconnectTimer?.cancel();
    _unifiedReconnectTimer = null;
    _rechargePopupRetryTimer?.cancel();
    _rechargePopupRetryTimer = null;
    _rechargePopupQueue.clear();
    _processedRechargeEventIds.clear();
    _giftAnimationQueue.clear();
    _giftAnimationQueueMounting = false;
    _optimisticGiftAnimationUntilMs.clear();
    _optimisticGiftEchoCredits.clear();
    _cancelRedPacketTimer();
    _cancelGlobalRedPacketTimer();
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
    inactivityTimer?.cancel();
    inactivityTimer = null;
    _realtimeLiveRefreshTimer?.cancel();
    _realtimeLiveRefreshTimer = null;
    _entryAnimationSafetyTimer?.cancel();
    _giftAnimationHideTimer?.cancel();
    _luckyCardHideTimer?.cancel();
    _accountBlockPrivateChannelName = '';
    _accountBlockPendingChannelName = '';
    _accountBlockSubscribedUserId = 0;
    _isAuthorizingAccountBlockChannel = false;
    _activeCallPopupKeys.clear();
    _handledCallPopupKeys.clear();
    _locallyLeftStreamIds.clear();
    _viewerJoinedAtMs.clear();
    _recentRoomExitUserUntilMs.clear();
    lockedSeatMap.clear();
    liveCallList.clear();
    pendingCall.clear();
    livestreamController.liveViewerList.clear();
    super.onClose();
  }

  Future<void> _disposeOwnedWebSockets() async {
    await Future.wait<void>(<Future<void>>[
      _cancelSocketSubscription(_liveListSubscription, 'live-list dispose'),
      _cancelSocketSubscription(_viewersSubscription, 'viewers dispose'),
      _cancelSocketSubscription(_commentsSubscription, 'comments dispose'),
      _cancelSocketSubscription(_callListSubscription, 'call-list dispose'),
      _cancelSocketSubscription(_moderationSubscription, 'moderation dispose'),
      _cancelSocketSubscription(_unifiedSubscription, 'unified dispose'),
    ]);
    _liveListSubscription = null;
    _viewersSubscription = null;
    _commentsSubscription = null;
    _callListSubscription = null;
    _moderationSubscription = null;
    _unifiedSubscription = null;

    await Future.wait<void>(<Future<void>>[
      _closeSocketChannel(channel, 'live-list dispose'),
      _closeSocketChannel(_viewersChannel, 'viewers dispose'),
      _closeSocketChannel(_commentsChannel, 'comments dispose'),
      _closeSocketChannel(_callListChannel, 'call-list dispose'),
      _closeSocketChannel(_moderationChannel, 'moderation dispose'),
      _closeSocketChannel(liveStreamEventChannel, 'unified dispose'),
      _closeSocketChannel(broadcasterWebsocket, 'broadcaster dispose'),
    ]);
    channel = null;
    _viewersChannel = null;
    _commentsChannel = null;
    _callListChannel = null;
    _moderationChannel = null;
    liveStreamEventChannel = null;
  }
}
