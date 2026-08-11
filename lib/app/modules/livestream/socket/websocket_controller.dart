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
import '../controllers/livestream_controller.dart';
import '../controllers/global_live_banner_queue_controller.dart';

import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

part 'handlers/call_event_handler.dart';
part 'handlers/comment_event_handler.dart';
part 'handlers/emoji_event_handler.dart';
part 'handlers/gift_event_handler.dart';
part 'handlers/lucky_event_handler.dart';
part 'handlers/media_event_handler.dart';
part 'handlers/moderation_event_handler.dart';
part 'handlers/pk_event_handler.dart';
part 'handlers/red_packet_event_handler.dart';
part 'handlers/room_event_handler.dart';
part 'handlers/seat_event_handler.dart';
part 'handlers/viewer_event_handler.dart';

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
  int _roomTransitionGeneration = 0;
  bool _roomTransitionInProgress = false;

  void beginRoomTransition({
    required int generation,
    required int oldStreamId,
  }) {
    _roomTransitionGeneration = generation;
    _roomTransitionInProgress = true;
    if (oldStreamId > 0) {
      _locallyLeftStreamIds.add(oldStreamId);
    }
    streamID.value = 0;
    activeAudioStreamId.value = 0;
    liveRoomUpdateStreamId.value = 0;
  }

  void activateRoomTransition({
    required int generation,
    required int streamId,
  }) {
    if (generation != _roomTransitionGeneration || streamId <= 0) return;
    _roomTransitionInProgress = false;
    streamID.value = streamId;
  }

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
      final String status = (row['call_status'] ?? row['status'] ?? 'unknown')
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
      parts.add(
        'count=${beforeCount ?? liveCallList.length}->${afterCount ?? liveCallList.length}',
      );
    }
    if (note != null && note.trim().isNotEmpty)
      parts.add('note=${note.trim()}');
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
        const <String>['last_ping_at', 'last_ping', 'ping_at', 'last_seen_at'],
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
          'open':
              liveStreamEventChannel != null &&
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
        'last_activity_age_seconds': DateTime.now()
            .difference(lastActivityTime.value)
            .inSeconds,
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

  final isGiftAnimationShowing = false.obs;
  final giftsData = {}.obs;
  final totalGiftCoins = 0.obs;
  final userGiftCounts = <String, Map<String, dynamic>>{}.obs;
  final RxMap<String, int> liveUserGiftCoins = <String, int>{}.obs;
  Timer? _giftAnimationHideTimer;
  final Map<String, int> _recentGiftEventMs = <String, int>{};
  final Map<String, int> _optimisticGiftAnimationUntilMs = <String, int>{};
  final Map<String, int> _optimisticGiftEchoCredits = <String, int>{};
  final Map<String, int> _optimisticClientEventUntilMs = <String, int>{};
  final Queue<Map<String, dynamic>> _giftAnimationQueue =
      Queue<Map<String, dynamic>>();
  bool _giftAnimationQueueMounting = false;
  Timer? _luckyCardHideTimer;
  bool _luckyCurrentFlightComplete = false;
  int _giftAnimationSerial = 0;
  Timer? _entryAnimationSafetyTimer;
  final Map<int, int> _recentEntryShownUntilMs = <int, int>{};
  final isBroadcasterOnline = true.obs;
  final isStreamEnded = false.obs;
  final streamEndReason = ''.obs;

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
      final user = liveCallList.firstWhere((viewer) {
        if (viewer is! Map) return false;
        final nestedUserId = viewer['user'] is Map
            ? viewer['user']['id']
            : null;
        return viewer['caller_id'].toString() == userId.toString() ||
            viewer['user_id'].toString() == userId.toString() ||
            nestedUserId.toString() == userId.toString();
      }, orElse: () => null);

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
          isVideoEnabled =
              text == '1' ||
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
                final bool legacyAudioRoom =
                    _isCurrentAudioOnlyRoom(
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
    _heartbeatTimeoutSeatGuardUntilMs.clear();
    _lastKnownSelfSeatNo = 0;
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
    _heartbeatTimeoutSeatGuardUntilMs.clear();
    _lastKnownSelfSeatNo = 0;

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

      if (livestreamId != null && !_isCurrentStream(livestreamId)) {
        liveLog('Kickout ignored: not current stream => $livestreamId');
        return;
      }

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
        await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
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
      liveLog('✅ Video toggle applied => user:$userId video_on:$videoOnValue');
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
    final bool audioRoom = _isCurrentAudioOnlyRoom(livestreamId: livestreamId);

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
        LiveTestingLogger.printBlock(
          'LIVE TEST WS PUSHER PING #$eventSequence',
          {
            'time': DateTime.now().toIso8601String(),
            'event': eventName,
            'frame_count': _testingWsFrameCount,
            'raw': decodedMessage,
          },
        );
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
        const <String>['last_ping_at', 'last_ping', 'ping_at', 'last_seen_at'],
      );
      final bool isGiftLikeForTesting =
          actionType.contains('gift') ||
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
          'stream_id':
              payload['livestream_id'] ??
              payload['stream_id'] ??
              payload['live_id'] ??
              testingNestedData['livestream_id'],
          'user_id':
              payload['user_id'] ??
              payload['caller_id'] ??
              payload['viewer_id'] ??
              testingNestedData['user_id'],
          'call_status':
              payload['call_status'] ??
              payload['status'] ??
              testingNestedData['call_status'],
          'last_ping_at': eventLastPingAt,
          'last_ping_age_seconds': LiveTestingLogger.ageSeconds(
            eventLastPingAt,
          ),
          'payload_keys': payload.keys.toList(),
          'payload': isGiftLikeForTesting
              ? {
                  'summary_only_for_performance': true,
                  'gift_id': payload['gift_id'] ?? testingGiftData['id'],
                  'sender_id': payload['sender_id'] ?? payload['user_id'],
                  'receiver_id':
                      payload['receiver_id'] ?? payload['target_user_id'],
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

      // Normal 100K/200K gift announcements are app-global, so validate and
      // dedupe them before the current-room mutation guard. This only enqueues
      // presentation; normal gift accounting remains in the room handler.
      if (actionType == 'gift_sent' ||
          actionType == 'multi_live_gift_sent' ||
          actionType == 'pk_gift_sent') {
        try {
          globalLiveBannerQueue().showGlobalBigGiftBannerFromPayload(payload);
        } catch (e) {
          liveLog('Big Gift global pre-guard skipped safely: $e');
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
      LiveTestingLogger.printBlock('LIVE TEST EVENT ERROR #$eventSequence', {
        'elapsed_ms': eventStopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'stack_trace': st.toString(),
        'raw_message': message.toString(),
      });
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
    if (_roomTransitionInProgress) return false;

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
          syncGiftCoinsFromPayload(
            payload,
            source: 'dispatch_gift_$actionType',
          );
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
            final int userId = _toInt(
              payload['caller_id'] ?? payload['user_id'],
            );
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
      LiveTestingLogger.printBlock(
        'LIVE TEST EVENT DISPATCH ERROR [$actionType]',
        {
          'elapsed_ms': dispatchStopwatch.elapsedMilliseconds,
          'error': error.toString(),
          'stack_trace': stackTrace.toString(),
          'payload': payload,
        },
      );
      rethrow;
    } finally {
      dispatchStopwatch.stop();
      LiveTestingLogger.line(
        '🧪 EVENT DISPATCH END => action=$actionType elapsed=${dispatchStopwatch.elapsedMilliseconds}ms',
      );
    }
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
