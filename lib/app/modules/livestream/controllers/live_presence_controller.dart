import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/LiveTestingLogger.dart';
import '../utils/live_realtime_debug_log.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns livestream online/offline presence and heartbeat leases.
class LivePresenceController extends GetxController {
  LivePresenceController(this.owner);

  final LivestreamController owner;

  Timer? _pingTimer;

  /// ===================== PRESENCE / LIVE ROOM HEARTBEAT =====================
  /// State machine:
  /// viewer -> seat accepted/joined -> caller
  /// caller -> explicit leave seat/host remove -> viewer
  /// viewer/caller -> explicit room exit -> none
  /// background/minimize -> keep current role and seat
  Timer? _presenceHeartbeatTimer;
  int _presenceStreamId = 0;
  String _presenceRole = 'viewer';
  bool _presenceIsOnSeat = false;
  int? _presenceSeatNo;
  bool _presenceRequestRunning = false;
  bool _presenceHeartbeatQueued = false;
  bool _presenceBackgroundMode = false;

  /// Presence request watchdog. A Dio request that never finishes leaves
  /// `_presenceRequestRunning=true`; every later timer tick then only queues and
  /// the backend eventually removes the active video caller after its lease
  /// timeout. These fields let us unlock a stale request and resend safely.
  int _presenceRequestStartedAtMs = 0;
  int _lastPresenceRequestAtMs = 0;
  int _lastPresenceSuccessAtMs = 0;
  String _lastPresenceBodyKey = '';

  int _presenceRequestSequence = 0;
  int _presenceLeaseGeneration = 0;
  int _presenceSuccessCount = 0;
  int _presenceFailureCount = 0;
  int? _lastPresenceStatusCode;
  dynamic _lastPresenceResponseData;
  String _lastPresenceError = '';
  dynamic _lastPresenceServerPingAt;
  int _lastPermanentPingRequestAtMs = 0;
  int _lastPermanentPingSuccessAtMs = 0;
  int? _lastPermanentPingStatusCode;
  dynamic _lastPermanentPingResponseData;
  String _lastPermanentPingError = '';

  static const Duration _foregroundPresenceInterval = Duration(seconds: 15);
  static const Duration _backgroundPresenceInterval = Duration(seconds: 20);

  int get currentPresenceStreamId => _presenceStreamId;
  String get currentPresenceRole => _presenceRole;
  bool get currentPresenceIsOnSeat => _presenceIsOnSeat;
  int? get currentPresenceSeatNo => _presenceSeatNo;

  Map<String, dynamic> get livePresenceDebugSnapshot {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{
      'time': DateTime.now().toIso8601String(),
      'stream_id': _presenceStreamId,
      'role': _presenceRole,
      'is_on_seat': _presenceIsOnSeat,
      'seat_no': _presenceSeatNo,
      'background_mode': _presenceBackgroundMode,
      'heartbeat_timer_active': _presenceHeartbeatTimer?.isActive == true,
      'heartbeat_interval_seconds': _presenceBackgroundMode
          ? _backgroundPresenceInterval.inSeconds
          : _foregroundPresenceInterval.inSeconds,
      'request_running': _presenceRequestRunning,
      'request_running_for_ms':
          _presenceRequestRunning && _presenceRequestStartedAtMs > 0
          ? nowMs - _presenceRequestStartedAtMs
          : 0,
      'request_queued': _presenceHeartbeatQueued,
      'request_sequence': _presenceRequestSequence,
      'success_count': _presenceSuccessCount,
      'failure_count': _presenceFailureCount,
      'last_request_at': _lastPresenceRequestAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              _lastPresenceRequestAtMs,
            ).toIso8601String()
          : null,
      'last_request_age_seconds': _lastPresenceRequestAtMs > 0
          ? ((nowMs - _lastPresenceRequestAtMs) / 1000).round()
          : null,
      'last_success_at': _lastPresenceSuccessAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              _lastPresenceSuccessAtMs,
            ).toIso8601String()
          : null,
      'last_success_age_seconds': _lastPresenceSuccessAtMs > 0
          ? ((nowMs - _lastPresenceSuccessAtMs) / 1000).round()
          : null,
      'last_status_code': _lastPresenceStatusCode,
      'last_error': _lastPresenceError,
      'last_server_ping_at': _lastPresenceServerPingAt,
      'last_server_ping_age_seconds': LiveTestingLogger.ageSeconds(
        _lastPresenceServerPingAt,
      ),
      'last_response': _lastPresenceResponseData,
      'permanent_ping_timer_active': _pingTimer?.isActive == true,
      'last_permanent_ping_request_at': _lastPermanentPingRequestAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              _lastPermanentPingRequestAtMs,
            ).toIso8601String()
          : null,
      'last_permanent_ping_success_at': _lastPermanentPingSuccessAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              _lastPermanentPingSuccessAtMs,
            ).toIso8601String()
          : null,
      'last_permanent_ping_status_code': _lastPermanentPingStatusCode,
      'last_permanent_ping_error': _lastPermanentPingError,
      'last_permanent_ping_response': _lastPermanentPingResponseData,
    };
  }

  void _setPresenceState({
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) {
    if (livestreamId != null && livestreamId > 0) {
      _presenceStreamId = livestreamId;
    }

    final normalizedRole = (role ?? _presenceRole).toLowerCase().trim();

    if (normalizedRole == 'host') {
      _presenceRole = 'host';
      _presenceIsOnSeat = true;
      _presenceSeatNo = seatNo != null && seatNo > 0
          ? seatNo
          : (_presenceSeatNo ?? 1);
      return;
    }

    if (normalizedRole == 'caller') {
      _presenceRole = 'caller';
      _presenceIsOnSeat = true;

      if (seatNo != null && seatNo > 0) {
        _presenceSeatNo = seatNo;
      }

      return;
    }

    _presenceRole = 'viewer';
    _presenceIsOnSeat = false;
    _presenceSeatNo = null;
  }

  Map<String, dynamic> _presenceBody({
    int? userId,
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) {
    final uid =
        userId ?? owner.authController.userProfile.value.user?.id?.toInt() ?? 0;

    final sid = livestreamId ?? _presenceStreamId;
    final resolvedRole = (role ?? _presenceRole).toLowerCase().trim();

    final onSeat = resolvedRole == 'caller' || resolvedRole == 'host';

    int? resolvedSeat;
    if (onSeat) {
      resolvedSeat = seatNo ?? _presenceSeatNo;

      if (resolvedRole == 'host' &&
          (resolvedSeat == null || resolvedSeat <= 0)) {
        resolvedSeat = 1;
      }
    }

    final body = <String, dynamic>{'user_id': uid};

    if (sid > 0) {
      body['livestream_id'] = sid;
      body['role'] = onSeat ? resolvedRole : 'viewer';
      body['is_on_seat'] = onSeat;
      body['seat_no'] = onSeat ? resolvedSeat : null;
    }

    return body;
  }

  void _reconcileSelfSeatFromBackendPresence(dynamic responseData) {
    final root = _asMap(responseData);
    final data = _asMap(root['data']);
    final liveData = _asMap(data['livestream_data']);

    if (liveData.isEmpty) return;

    final backendRole = (liveData['role'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final backendOnSeat =
        liveData['is_on_seat'] == true ||
        liveData['is_on_seat']?.toString() == '1' ||
        liveData['is_on_seat']?.toString().toLowerCase() == 'true';

    final backendSeatNo = _toInt(liveData['seat_no']);
    final localSeatNo = owner.currentUserSeatNo(ignorePresence: true);

    if ((backendRole == 'caller' || backendRole == 'host') &&
        backendOnSeat &&
        backendSeatNo > 0) {
      // Host heartbeat must never be downgraded to caller by backend response.
      // Backend may return caller because host also has a livestream_callers row,
      // but frontend source of truth is the local requested host role.
      final String safeRole = _presenceRole == 'host' ? 'host' : backendRole;

      _setPresenceState(
        role: safeRole,
        isOnSeat: true,
        seatNo: safeRole == 'host' ? 1 : backendSeatNo,
      );
      return;
    }

    // A delayed viewer heartbeat must not remove a caller who is still
    // visible in the call list or whose caller seat is remembered locally.
    final rememberedSeat = localSeatNo > 0
        ? localSeatNo
        : (_presenceRole == 'caller' ? (_presenceSeatNo ?? 0) : 0);

    if (rememberedSeat > 0) {
      _setPresenceState(role: 'caller', isOnSeat: true, seatNo: rememberedSeat);

      liveLog(
        '🛡️ Weak viewer heartbeat ignored; caller seat repaired '
        '=> seat=$rememberedSeat backendRole=$backendRole',
      );

      Future.microtask(() async {
        await sendPresenceHeartbeatOnce(
          livestreamId: _presenceStreamId,
          role: 'caller',
          isOnSeat: true,
          seatNo: rememberedSeat,
        );

        if (_presenceStreamId > 0) {
          await owner.tryToGetCallList(streamId: _presenceStreamId);
        }
      });

      return;
    }

    _setPresenceState(role: 'viewer', isOnSeat: false, seatNo: null);
  }

  Future<void> sendPresenceHeartbeatOnce({
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) async {
    final int leaseGeneration = _presenceLeaseGeneration;
    final int uid =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (uid <= 0) {
      liveLog('❌ Presence heartbeat stopped: uid is 0');
      return;
    }

    final int sid = livestreamId ?? _presenceStreamId;

    _setPresenceState(
      livestreamId: sid > 0 ? sid : null,
      role: role,
      isOnSeat: isOnSeat,
      seatNo: seatNo,
    );

    final Map<String, dynamic> body = _presenceBody(
      userId: uid,
      livestreamId: sid > 0 ? sid : null,
      role: _presenceRole,
      isOnSeat: _presenceIsOnSeat,
      seatNo: _presenceSeatNo,
    );

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String bodyKey =
        '${body['livestream_id']}|${body['role']}|${body['is_on_seat']}|${body['seat_no']}';

    // Several UI/websocket callbacks can request the same heartbeat together.
    // Skip only a very recent duplicate; the periodic 15/20-second lease update
    // is never blocked by this guard.
    if (bodyKey == _lastPresenceBodyKey &&
        nowMs - _lastPresenceRequestAtMs < 8000) {
      liveLog('⏭️ Presence heartbeat duplicate skipped => $bodyKey');
      return;
    }

    if (_presenceRequestRunning) {
      final int runningForMs = nowMs - _presenceRequestStartedAtMs;

      // Network/Dio can occasionally leave a request pending. Without this
      // watchdog all later heartbeats are blocked and a video caller is removed
      // after roughly 2-4 minutes even though Agora media is still connected.
      if (_presenceRequestStartedAtMs > 0 && runningForMs > 12000) {
        liveLog(
          '🛡️ Presence heartbeat stuck for ${runningForMs}ms; force unlock',
        );
        _presenceRequestRunning = false;
        _presenceHeartbeatQueued = false;
      } else {
        _presenceHeartbeatQueued = true;
        liveLog('ℹ️ Presence heartbeat queued; request already running');
        return;
      }
    }

    _presenceRequestRunning = true;
    _presenceRequestStartedAtMs = nowMs;
    _lastPresenceBodyKey = bodyKey;
    _lastPresenceRequestAtMs = nowMs;
    final int requestSequence = ++_presenceRequestSequence;
    final Stopwatch heartbeatStopwatch = Stopwatch()..start();
    _lastPresenceError = '';

    liveLog(
      '📤 Presence heartbeat => stream=${body['livestream_id']} '
      'role=${body['role']} seat=${body['seat_no']}',
    );
    LiveTestingLogger.printBlock(
      'LIVE TEST PRESENCE HEARTBEAT REQUEST #$requestSequence',
      {
        'time': DateTime.now().toIso8601String(),
        'url': '$kMainUrl/user/heartbeat',
        'body': body,
        'state_before': livePresenceDebugSnapshot,
      },
    );

    try {
      final response = await owner.dio.post(
        '$kMainUrl/user/heartbeat',
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );

      _lastPresenceStatusCode = response.statusCode;
      _lastPresenceResponseData = response.data;
      _lastPresenceServerPingAt = LiveTestingLogger.findFirstByKeys(
        response.data,
        const <String>['last_ping_at', 'last_ping', 'ping_at', 'last_seen_at'],
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastPresenceSuccessAtMs = DateTime.now().millisecondsSinceEpoch;
        _presenceSuccessCount++;
        if (leaseGeneration == _presenceLeaseGeneration &&
            sid == _presenceStreamId) {
          _reconcileSelfSeatFromBackendPresence(response.data);
        } else {
          liveLog(
            'Ignored stale presence response => stream:$sid '
            'active:$_presenceStreamId lease:$leaseGeneration/'
            '$_presenceLeaseGeneration',
          );
        }

        liveLog(
          '✅ Presence heartbeat ok => stream=$_presenceStreamId '
          'role=$_presenceRole seat=$_presenceSeatNo',
        );
        final int serverViewers = LiveRealtimeDebugLog.intValue(
          LiveTestingLogger.findFirstByKeys(response.data, const <String>[
            'viewer_count',
            'viewers_count',
            'total_viewers',
          ]),
        );
        LiveRealtimeDebugLog.heartbeat(
          room: _presenceStreamId,
          serverViewers: serverViewers,
          localViewers: owner.liveViewerList.length,
          callers: owner.websocketController.liveCallList,
          capacity: owner.websocketController.activeSeatCapacity,
        );
      } else {
        _presenceFailureCount++;
        _lastPresenceError =
            'HTTP ${response.statusCode}: ${response.statusMessage ?? ''}';
        liveLog('⚠️ Presence heartbeat failed: ${response.statusCode}');
      }

      LiveTestingLogger.printBlock(
        'LIVE TEST PRESENCE HEARTBEAT RESPONSE #$requestSequence',
        {
          'elapsed_ms': heartbeatStopwatch.elapsedMilliseconds,
          'status_code': response.statusCode,
          'status_message': response.statusMessage,
          'last_ping_at': _lastPresenceServerPingAt,
          'last_ping_age_seconds': LiveTestingLogger.ageSeconds(
            _lastPresenceServerPingAt,
          ),
          'response': response.data,
          'state_after': livePresenceDebugSnapshot,
        },
      );
    } on DioException catch (e) {
      _presenceFailureCount++;
      _lastPresenceStatusCode = e.response?.statusCode;
      _lastPresenceResponseData = e.response?.data;
      _lastPresenceError = e.message ?? e.error?.toString() ?? 'Dio error';
      liveLog(
        '⚠️ Presence heartbeat network/server error: '
        '${e.response?.statusCode ?? e.message}',
      );
      LiveTestingLogger.printBlock(
        'LIVE TEST PRESENCE HEARTBEAT DIO ERROR #$requestSequence',
        {
          'elapsed_ms': heartbeatStopwatch.elapsedMilliseconds,
          'dio_type': e.type.toString(),
          'message': e.message,
          'error': e.error?.toString(),
          'status_code': e.response?.statusCode,
          'response': e.response?.data,
          'request_body': body,
          'state': livePresenceDebugSnapshot,
        },
      );
    } catch (e, st) {
      _presenceFailureCount++;
      _lastPresenceError = e.toString();
      liveLog('❌ Presence heartbeat error => $e');
      liveLog('❌ StackTrace => $st');
      LiveTestingLogger.printBlock(
        'LIVE TEST PRESENCE HEARTBEAT ERROR #$requestSequence',
        {
          'elapsed_ms': heartbeatStopwatch.elapsedMilliseconds,
          'error': e.toString(),
          'stack_trace': st.toString(),
          'request_body': body,
          'state': livePresenceDebugSnapshot,
        },
      );
    } finally {
      heartbeatStopwatch.stop();
      _presenceRequestRunning = false;
      _presenceRequestStartedAtMs = 0;
      LiveTestingLogger.line(
        '💓 LIVE TEST HEARTBEAT COMPLETE #$requestSequence => '
        'elapsed=${heartbeatStopwatch.elapsedMilliseconds}ms '
        'status=$_lastPresenceStatusCode success=$_presenceSuccessCount '
        'failed=$_presenceFailureCount role=$_presenceRole '
        'seat=$_presenceSeatNo lastPing=$_lastPresenceServerPingAt',
      );

      if (_presenceHeartbeatQueued &&
          leaseGeneration == _presenceLeaseGeneration &&
          sid == _presenceStreamId) {
        _presenceHeartbeatQueued = false;

        Future<void>.delayed(const Duration(milliseconds: 120), () {
          sendPresenceHeartbeatOnce(
            livestreamId: _presenceStreamId,
            role: _presenceRole,
            isOnSeat: _presenceIsOnSeat,
            seatNo: _presenceSeatNo,
          );
        });
      }
    }
  }

  void startLivePresenceHeartbeat({
    required int livestreamId,
    required String role,
    bool isOnSeat = false,
    int? seatNo,
    Duration? interval,
    bool backgroundMode = false,
  }) {
    if (livestreamId <= 0) return;

    final String normalizedRole = role.toLowerCase().trim();
    final int? normalizedSeat = isOnSeat ? seatNo : null;

    final effectiveInterval =
        interval ??
        (backgroundMode
            ? _backgroundPresenceInterval
            : _foregroundPresenceInterval);

    final bool sameStateRunning =
        _presenceHeartbeatTimer != null &&
        _presenceStreamId == livestreamId &&
        _presenceRole == normalizedRole &&
        _presenceIsOnSeat == isOnSeat &&
        _presenceSeatNo == normalizedSeat &&
        _presenceBackgroundMode == backgroundMode;

    if (sameStateRunning) {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final bool successIsStale =
          _lastPresenceSuccessAtMs == 0 ||
          nowMs - _lastPresenceSuccessAtMs > 26000;
      final bool requestLooksStuck =
          _presenceRequestRunning &&
          _presenceRequestStartedAtMs > 0 &&
          nowMs - _presenceRequestStartedAtMs > 12000;

      if (successIsStale || requestLooksStuck) {
        liveLog(
          '🛡️ Presence lease watchdog resend => '
          'stream=$livestreamId role=$normalizedRole seat=$normalizedSeat',
        );
        unawaited(
          sendPresenceHeartbeatOnce(
            livestreamId: livestreamId,
            role: normalizedRole,
            isOnSeat: isOnSeat,
            seatNo: normalizedSeat,
          ),
        );
      } else {
        liveLog(
          '🛡️ Presence heartbeat already running => '
          'stream=$livestreamId role=$normalizedRole seat=$normalizedSeat',
        );
      }
      return;
    }

    _setPresenceState(
      livestreamId: livestreamId,
      role: normalizedRole,
      isOnSeat: isOnSeat,
      seatNo: normalizedSeat,
    );

    _presenceBackgroundMode = backgroundMode;
    _presenceLeaseGeneration++;

    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;

    sendPresenceHeartbeatOnce(
      livestreamId: _presenceStreamId,
      role: _presenceRole,
      isOnSeat: _presenceIsOnSeat,
      seatNo: _presenceSeatNo,
    );

    final int timerLeaseGeneration = _presenceLeaseGeneration;
    final int timerStreamId = _presenceStreamId;
    _presenceHeartbeatTimer = Timer.periodic(effectiveInterval, (timer) {
      if (timerLeaseGeneration != _presenceLeaseGeneration ||
          timerStreamId != _presenceStreamId) {
        timer.cancel();
        return;
      }
      sendPresenceHeartbeatOnce(
        livestreamId: timerStreamId,
        role: _presenceRole,
        isOnSeat: _presenceIsOnSeat,
        seatNo: _presenceSeatNo,
      );
    });

    LiveTestingLogger.printBlock('LIVE TEST PRESENCE TIMER STARTED', {
      'effective_interval_seconds': effectiveInterval.inSeconds,
      'state': livePresenceDebugSnapshot,
    });
    liveLog(
      '✅ Live presence started => stream=$_presenceStreamId '
      'role=$_presenceRole seat=$_presenceSeatNo '
      'background=$_presenceBackgroundMode '
      'interval=${effectiveInterval.inSeconds}s',
    );
  }

  void setLivePresenceBackgroundMode(bool enabled) {
    if (_presenceStreamId <= 0) return;

    if (_presenceBackgroundMode == enabled && _presenceHeartbeatTimer != null) {
      return;
    }

    startLivePresenceHeartbeat(
      livestreamId: _presenceStreamId,
      role: _presenceRole,
      isOnSeat: _presenceIsOnSeat,
      seatNo: _presenceSeatNo,
      backgroundMode: enabled,
    );
  }

  void updateLivePresenceRole({
    required String role,
    bool? isOnSeat,
    int? seatNo,
  }) {
    String normalizedRole = role.toLowerCase().trim();

    // Host live page can receive late caller/viewer updates from old snapshots.
    // Do not downgrade a host heartbeat unless caller explicitly stopped it.
    if (_presenceRole == 'host' && normalizedRole != 'host') {
      liveLog(
        '🛡️ Host presence downgrade blocked => requested=$normalizedRole',
      );
      normalizedRole = 'host';
      isOnSeat = true;
      seatNo = 1;
    }

    final bool nextIsOnSeat = isOnSeat ?? _presenceIsOnSeat;
    final int? nextSeat = nextIsOnSeat ? (seatNo ?? _presenceSeatNo) : null;

    final int resolvedStreamId = _presenceStreamId > 0
        ? _presenceStreamId
        : (owner.streamId.value > 0
              ? owner.streamId.value
              : owner.websocketController.streamID.value);

    final bool sameState =
        _presenceRole == normalizedRole &&
        _presenceIsOnSeat == nextIsOnSeat &&
        _presenceSeatNo == nextSeat;

    _setPresenceState(
      livestreamId: resolvedStreamId > 0 ? resolvedStreamId : null,
      role: normalizedRole,
      isOnSeat: nextIsOnSeat,
      seatNo: nextSeat,
    );

    // Video live used to call updateLivePresenceRole() before any heartbeat
    // timer existed. Then /user/heartbeat was sent without livestream_id and
    // the backend removed an otherwise healthy Agora caller after 120 seconds.
    if (resolvedStreamId > 0 && _presenceHeartbeatTimer == null) {
      startLivePresenceHeartbeat(
        livestreamId: resolvedStreamId,
        role: _presenceRole,
        isOnSeat: _presenceIsOnSeat,
        seatNo: _presenceSeatNo,
        backgroundMode: _presenceBackgroundMode,
      );
      liveLog(
        '✅ Presence heartbeat auto-started from role update '
        '=> stream=$resolvedStreamId role=$_presenceRole seat=$_presenceSeatNo',
      );
      return;
    }

    if (sameState) {
      if (resolvedStreamId > 0) {
        unawaited(
          sendPresenceHeartbeatOnce(
            livestreamId: resolvedStreamId,
            role: _presenceRole,
            isOnSeat: _presenceIsOnSeat,
            seatNo: _presenceSeatNo,
          ),
        );
      }
      return;
    }

    unawaited(
      sendPresenceHeartbeatOnce(
        livestreamId: resolvedStreamId > 0 ? resolvedStreamId : null,
        role: _presenceRole,
        isOnSeat: _presenceIsOnSeat,
        seatNo: _presenceSeatNo,
      ),
    );
  }

  void stopLivePresenceHeartbeat() {
    LiveTestingLogger.printBlock(
      'LIVE TEST PRESENCE TIMER STOP',
      livePresenceDebugSnapshot,
    );
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _presenceLeaseGeneration++;
    _presenceHeartbeatQueued = false;
    _presenceRequestRunning = false;
    _presenceRequestStartedAtMs = 0;
    _lastPresenceRequestAtMs = 0;
    _lastPresenceSuccessAtMs = 0;
    _lastPresenceBodyKey = '';
  }

  Future<void> markUserOffline({
    int? livestreamId,
    String? role,
    int? seatNo,
  }) async {
    final uid = owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (uid <= 0) return;

    final sid = livestreamId ?? _presenceStreamId;
    final outgoingRole = (role ?? _presenceRole).toLowerCase().trim();

    try {
      await owner.dio.post(
        '$kMainUrl/user/offline',
        data: _presenceBody(
          userId: uid,
          livestreamId: sid > 0 ? sid : null,
          role: outgoingRole,
          isOnSeat: outgoingRole == 'caller' || outgoingRole == 'host',
          seatNo: seatNo ?? _presenceSeatNo,
        ),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );
    } catch (e) {
      liveLog('⚠️ User offline failed safely: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchPresenceWithLiveState({
    int? livestreamId,
  }) async {
    final uid = owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (uid <= 0) return null;

    final sid = livestreamId ?? _presenceStreamId;
    final url = sid > 0
        ? '$kMainUrl/user/presence/$uid?livestream_id=$sid'
        : '$kMainUrl/user/presence/$uid';

    try {
      final response = await owner.dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );

      final dynamic fetchedLastPingAt = LiveTestingLogger.findFirstByKeys(
        response.data,
        const <String>['last_ping_at', 'last_ping', 'ping_at', 'last_seen_at'],
      );
      LiveTestingLogger.printBlock('LIVE TEST PRESENCE FETCH RESULT', {
        'url': url,
        'status_code': response.statusCode,
        'last_ping_at': fetchedLastPingAt,
        'last_ping_age_seconds': LiveTestingLogger.ageSeconds(
          fetchedLastPingAt,
        ),
        'response': response.data,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }

        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data as Map);
        }
      }
    } catch (e) {
      liveLog('⚠️ Presence/live state fetch failed safely: $e');
    }

    return null;
  }

  void lastPingUpdate({required int id}) {
    if (id <= 0) {
      liveLog('⚠️ Ping skipped: invalid stream id $id');
      return;
    }

    owner.streamId.value = id;
    _pingTimer?.cancel();
    _pingTimer = null;

    lastPingOnce(id: id);

    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await lastPingOnce(id: id);
    });
  }

  Future<void> lastPingOnce({required int id}) async {
    if (id <= 0) return;

    final int userId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    _lastPermanentPingRequestAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastPermanentPingError = '';
    final Stopwatch permanentPingStopwatch = Stopwatch()..start();
    LiveTestingLogger.printBlock('LIVE TEST PERMANENT PING REQUEST', {
      'time': DateTime.now().toIso8601String(),
      'stream_id': id,
      'user_id': userId,
      'url': kPermanentRoomHeartbeatUrl(id),
    });
    try {
      final response = await owner.dio.post(
        kPermanentRoomHeartbeatUrl(id),
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      _lastPermanentPingStatusCode = response.statusCode;
      _lastPermanentPingResponseData = response.data;
      final dynamic permanentLastPingAt = LiveTestingLogger.findFirstByKeys(
        response.data,
        const <String>['last_ping_at', 'last_ping', 'ping_at', 'last_seen_at'],
      );
      LiveTestingLogger.printBlock('LIVE TEST PERMANENT PING RESPONSE', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'status_code': response.statusCode,
        'last_ping_at': permanentLastPingAt,
        'last_ping_age_seconds': LiveTestingLogger.ageSeconds(
          permanentLastPingAt,
        ),
        'response': response.data,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastPermanentPingSuccessAtMs = DateTime.now().millisecondsSinceEpoch;
        liveLog('✅ Permanent room heartbeat ok => stream=$id');
        return;
      }

      if (response.statusCode != 404 && response.statusCode != 405) {
        _lastPermanentPingError = 'HTTP ${response.statusCode}';
        liveLog('⚠️ Permanent heartbeat failed: ${response.statusCode}');
        return;
      }
    } catch (e, st) {
      _lastPermanentPingError = e.toString();
      LiveTestingLogger.printBlock('LIVE TEST PERMANENT PING ERROR', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
      liveLog('⚠️ Permanent heartbeat fallback requested: $e');
    }

    // Backward-compatible fallback while an older backend is still deployed.
    try {
      final response = await owner.dio.get(
        lastPingUpdateUrl(id),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );
      _lastPermanentPingStatusCode = response.statusCode;
      _lastPermanentPingResponseData = response.data;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastPermanentPingSuccessAtMs = DateTime.now().millisecondsSinceEpoch;
      }
      LiveTestingLogger.printBlock('LIVE TEST LEGACY LAST PING RESPONSE', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'status_code': response.statusCode,
        'response': response.data,
      });
      liveLog('ℹ️ Legacy heartbeat status => ${response.statusCode}');
    } catch (e, st) {
      _lastPermanentPingError = e.toString();
      LiveTestingLogger.printBlock('LIVE TEST LEGACY LAST PING ERROR', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
      liveLog('⚠️ Legacy lastPing ignored safely: $e');
    } finally {
      permanentPingStopwatch.stop();
      LiveTestingLogger.line(
        '💗 LIVE TEST PERMANENT PING COMPLETE => stream=$id '
        'elapsed=${permanentPingStopwatch.elapsedMilliseconds}ms '
        'status=$_lastPermanentPingStatusCode '
        'successAt=$_lastPermanentPingSuccessAtMs',
      );
    }
  }

  // Method to stop the ping timer
  void stopPingUpdate() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ✅ BATTERY OPTIMIZATION: Method to update ping interval based on battery level
  void updatePingInterval(Duration newInterval) {
    if (_pingTimer == null) return;

    final sid = owner.streamId.value;
    if (sid <= 0) return;

    _pingTimer?.cancel();
    _pingTimer = null;

    _pingTimer = Timer.periodic(newInterval, (_) async {
      await lastPingOnce(id: sid);
    });

    liveLog('🔋 Legacy ping interval updated => ${newInterval.inSeconds}s');
  }

  void ensureViewerPresenceAfterAdd(int joinedStreamId) {
    final bool keepCallerRole =
        _presenceStreamId == joinedStreamId &&
        (_presenceRole == 'caller' || _presenceRole == 'host');

    startLivePresenceHeartbeat(
      livestreamId: joinedStreamId,
      role: keepCallerRole ? _presenceRole : 'viewer',
      isOnSeat: keepCallerRole ? _presenceIsOnSeat : false,
      seatNo: keepCallerRole ? _presenceSeatNo : null,
      backgroundMode: _presenceBackgroundMode,
    );

    liveLog(
      'Viewer presence heartbeat ensured after addViewer '
      '=> stream=$joinedStreamId role=$_presenceRole seat=$_presenceSeatNo',
    );
  }

  void setPresenceState({
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) => _setPresenceState(
    livestreamId: livestreamId,
    role: role,
    isOnSeat: isOnSeat,
    seatNo: seatNo,
  );

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

  @override
  void onClose() {
    stopLivePresenceHeartbeat();
    stopPingUpdate();
    super.onClose();
  }
}
