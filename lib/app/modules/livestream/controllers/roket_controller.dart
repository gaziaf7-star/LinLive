import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../../apis/api_endpoints.dart';
import '../../auth/controllers/auth_controller.dart';
import '../utils/LiveTestingLogger.dart';

/// Realtime + API state for the LINLIVE Rocket system.
///
/// Performance rules:
/// - one controller for the whole app
/// - room progress updates only when livestream_id matches the open room
/// - launch overlays and global banners are queued with hard limits
/// - no full page update()/refresh() calls are used
class RocketController extends GetxController {
  final Dio _dio = Dio();

  final RxBool enabled = false.obs;
  final RxBool loading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxInt currentLivestreamId = 0.obs;

  final RxMap<String, dynamic> setting = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> rocket = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> levels = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> rewards = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> ranking = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> myRanking = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> launchHistory =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> myRewards = <Map<String, dynamic>>[].obs;
  final RxMap<String, dynamic> lastLaunch = <String, dynamic>{}.obs;

  final RxInt sessionId = 0.obs;
  final RxInt progressCoins = 0.obs;
  final RxInt targetCoins = 0.obs;
  final RxDouble progressPercent = 0.0.obs;
  final RxInt remainingSeconds = 0.obs;
  final RxInt levelNo = 0.obs;
  final RxMap<String, dynamic> currentLevel = <String, dynamic>{}.obs;

  /// In-room launch overlay queue.
  final RxBool roomLaunchVisible = false.obs;
  final RxMap<String, dynamic> roomLaunchData = <String, dynamic>{}.obs;
  final Queue<Map<String, dynamic>> _roomLaunchQueue =
      Queue<Map<String, dynamic>>();

  /// App-wide launch banner queue.
  final RxBool globalLaunchBannerVisible = false.obs;
  final RxMap<String, dynamic> globalLaunchData = <String, dynamic>{}.obs;
  final Queue<Map<String, dynamic>> _globalLaunchQueue =
      Queue<Map<String, dynamic>>();

  final Set<String> _seenRealtimeKeys = <String>{};
  final Queue<String> _seenRealtimeOrder = Queue<String>();

  Timer? _countdownTimer;
  Timer? _giftReconcileTimer;
  int _lastFetchAtMs = 0;
  int _boundRoomGeneration = 0;

  /// Reward-log ids already reflected into the local authenticated wallet.
  /// Backend remains authoritative; this only makes a delivered coin reward
  /// visible instantly without double-applying the same launch event.
  final Set<int> _appliedOwnRewardLogIds = <int>{};

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final String text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'enabled' ||
        text == 'active' ||
        text == 'on';
  }

  String _text(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  Map<String, dynamic> _payload(dynamic raw) {
    final Map<String, dynamic> root = _map(raw);
    if (root.isEmpty) return <String, dynamic>{};

    final Map<String, dynamic> data = _map(root['data']);
    final Map<String, dynamic> payload = _map(data['data']);

    return <String, dynamic>{...root, ...data, ...payload};
  }

  int _livestreamIdFrom(dynamic raw) {
    final Map<String, dynamic> p = _payload(raw);
    final Map<String, dynamic> live = _map(
      p['livestream'] ?? p['live_stream'] ?? p['stream'] ?? p['room'],
    );
    final Map<String, dynamic> launch = _map(p['launch'] ?? p['rocket_launch']);
    return _int(
      p['livestream_id'] ??
          p['live_stream_id'] ??
          p['stream_id'] ??
          p['room_livestream_id'] ??
          launch['livestream_id'] ??
          launch['stream_id'] ??
          live['livestream_id'] ??
          live['stream_id'] ??
          live['id'],
    );
  }

  String _token() {
    try {
      if (!Get.isRegistered<AuthController>()) return '';
      return Get.find<AuthController>().userProfile.value.token
              ?.toString()
              .trim() ??
          '';
    } catch (_) {
      return '';
    }
  }

  Options _options() {
    final String token = _token();
    return Options(
      headers: <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    );
  }

  Future<void> bindLivestream(int livestreamId, {bool force = false}) async {
    if (livestreamId <= 0) return;

    final bool changed = currentLivestreamId.value != livestreamId;
    if (changed) {
      _boundRoomGeneration++;
      currentLivestreamId.value = livestreamId;
      _resetRoomState(keepEnabled: true);
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!force && !changed && now - _lastFetchAtMs < 5000) return;

    await fetchHome(livestreamId: livestreamId, showLoader: changed || force);

    // Keep current-session ranking warm before a rocket launches. This makes
    // TOP1 profile available instantly even when rocket_launched is compact.
    unawaited(fetchRanking(livestreamId: livestreamId));
  }

  Future<void> fetchHome({int? livestreamId, bool showLoader = true}) async {
    final int sid = livestreamId ?? currentLivestreamId.value;
    if (sid <= 0) return;

    final int generation = _boundRoomGeneration;
    if (showLoader) loading.value = true;
    errorMessage.value = '';

    try {
      final Response<dynamic> response = await _dio.get(
        rocketLivestreamApi(sid),
        options: _options(),
      );
      if (generation != _boundRoomGeneration ||
          sid != currentLivestreamId.value) {
        return;
      }
      _lastFetchAtMs = DateTime.now().millisecondsSinceEpoch;
      _applyHomeSnapshot(response.data, source: 'api_home');
    } on DioException catch (e) {
      errorMessage.value = _text(
        _map(e.response?.data)['message'] ?? e.message ?? 'Rocket load failed',
      );
    } catch (e) {
      errorMessage.value = 'Rocket load failed: $e';
    } finally {
      if (generation == _boundRoomGeneration &&
          sid == currentLivestreamId.value) {
        loading.value = false;
      }
    }
  }

  Future<void> fetchRanking({int? livestreamId}) async {
    final int sid = livestreamId ?? currentLivestreamId.value;
    if (sid <= 0) return;
    try {
      final Response<dynamic> response = await _dio.get(
        rocketRankingApi(sid),
        options: _options(),
      );
      final Map<String, dynamic> p = _payload(response.data);
      final List<Map<String, dynamic>> rows = _mapList(
        p['ranking'] ?? p['data'] ?? p['contributors'] ?? p['items'],
      );
      ranking.assignAll(rows);
      final Map<String, dynamic> mine = _map(p['my_ranking'] ?? p['myRanking']);
      if (mine.isNotEmpty) myRanking.assignAll(mine);
    } catch (_) {}
  }

  Future<void> fetchLaunchHistory({int? livestreamId}) async {
    final int sid = livestreamId ?? currentLivestreamId.value;
    if (sid <= 0) return;
    try {
      final Response<dynamic> response = await _dio.get(
        rocketLaunchHistoryApi(sid),
        options: _options(),
      );
      final Map<String, dynamic> p = _payload(response.data);
      launchHistory.assignAll(
        _mapList(
          p['launch_history'] ?? p['history'] ?? p['data'] ?? p['items'],
        ),
      );
    } catch (_) {}
  }

  Future<void> fetchMyRewards() async {
    try {
      final Response<dynamic> response = await _dio.get(
        rocketMyRewardsApi,
        options: _options(),
      );
      final Map<String, dynamic> p = _payload(response.data);
      myRewards.assignAll(
        _mapList(p['rewards'] ?? p['my_rewards'] ?? p['data'] ?? p['items']),
      );
    } catch (_) {}
  }

  Future<void> refreshAll({int? livestreamId}) async {
    final int sid = livestreamId ?? currentLivestreamId.value;
    if (sid <= 0) return;
    await fetchHome(livestreamId: sid, showLoader: true);
    await Future.wait<void>(<Future<void>>[
      fetchRanking(livestreamId: sid),
      fetchLaunchHistory(livestreamId: sid),
    ]);
  }

  void _applyHomeSnapshot(dynamic raw, {required String source}) {
    final Map<String, dynamic> p = _payload(raw);
    if (p.isEmpty) return;

    final Map<String, dynamic> rocketMap = _map(
      p['rocket'] ?? p['rocket_state'] ?? p['state'],
    );
    final Map<String, dynamic> settingMap = _map(
      p['setting'] ?? p['settings'] ?? rocketMap['setting'],
    );
    final Map<String, dynamic> levelMap = _map(
      rocketMap['level'] ?? p['level'] ?? p['current_level'],
    );

    final dynamic enabledRaw =
        p['enabled'] ??
        settingMap['enabled'] ??
        settingMap['status'] ??
        rocketMap['enabled'];
    if (enabledRaw != null) enabled.value = _bool(enabledRaw);

    if (settingMap.isNotEmpty) setting.assignAll(settingMap);
    if (rocketMap.isNotEmpty) rocket.assignAll(rocketMap);

    final List<Map<String, dynamic>> levelRows = _mapList(
      p['levels'] ?? rocketMap['levels'],
    );
    if (levelRows.isNotEmpty) levels.assignAll(levelRows);

    final Map<String, dynamic> rewardMap = _map(
      p['rewards'] ?? rocketMap['rewards'],
    );
    if (rewardMap.isNotEmpty) rewards.assignAll(rewardMap);

    final List<Map<String, dynamic>> rankRows = _mapList(
      p['ranking'] ?? rocketMap['ranking'],
    );
    if (rankRows.isNotEmpty) ranking.assignAll(rankRows);

    final Map<String, dynamic> mine = _map(
      p['my_ranking'] ?? rocketMap['my_ranking'],
    );
    if (mine.isNotEmpty) myRanking.assignAll(mine);

    final Map<String, dynamic> last = _map(
      p['last_launch'] ?? rocketMap['last_launch'],
    );
    if (last.isNotEmpty) lastLaunch.assignAll(last);

    sessionId.value = _int(
      rocketMap['session_id'] ?? p['session_id'] ?? sessionId.value,
    );
    progressCoins.value = _int(
      rocketMap['progress_coins'] ?? p['progress_coins'] ?? progressCoins.value,
    );
    targetCoins.value = _int(
      rocketMap['target_coins'] ??
          p['target_coins'] ??
          levelMap['required_coins'] ??
          targetCoins.value,
    );

    double percent = _double(
      rocketMap['progress_percent'] ?? p['progress_percent'],
    );
    if (percent <= 0 && targetCoins.value > 0) {
      percent = (progressCoins.value / targetCoins.value) * 100;
    }
    progressPercent.value = percent.clamp(0.0, 100.0).toDouble();

    final int remaining = _int(
      rocketMap['remaining_seconds'] ??
          p['remaining_seconds'] ??
          settingMap['remaining_seconds'],
    );
    if (remaining >= 0) {
      remainingSeconds.value = remaining;
      _ensureCountdown();
    }

    if (levelMap.isNotEmpty) {
      currentLevel.assignAll(levelMap);
      levelNo.value = _int(
        levelMap['level_no'] ?? levelMap['level'] ?? levelMap['id'],
      );
    } else {
      levelNo.value = _int(
        rocketMap['level_no'] ?? p['level_no'] ?? levelNo.value,
      );
    }
  }

  /// Apply a Rocket websocket event for the room that is actually open.
  ///
  /// [activeLivestreamId] is supplied by WebsocketController. This repairs the
  /// common race where the Rocket button was created while its livestreamId was
  /// still 0, so this controller stayed bound to 0/old room and silently
  /// discarded valid progress + launch events.
  void handleRealtime(
    String actionType,
    dynamic rawPayload, {
    int? activeLivestreamId,
  }) {
    final String action = actionType.trim().toLowerCase();
    if (!action.startsWith('rocket_')) return;

    final Map<String, dynamic> p = _payload(rawPayload);
    final int sid = _livestreamIdFrom(p);
    final int activeSid = _int(activeLivestreamId);

    if (sid > 0 && activeSid > 0 && sid == activeSid) {
      _bindRealtimeRoomNow(sid);
    }

    final bool sameRoom = sid > 0 && sid == currentLivestreamId.value;

    switch (action) {
      case 'rocket_progress_updated':
        if (sameRoom) {
          _applyRealtimeProgress(p);
        }
        break;

      case 'rocket_launched':
        final List<Map<String, dynamic>> launches = _extractLaunches(p);
        for (final Map<String, dynamic> launch in launches) {
          final int launchSid = sid > 0 ? sid : _livestreamIdFrom(launch);
          final Map<String, dynamic> normalized = <String, dynamic>{
            ...p,
            ...launch,
            'action_type': action,
            'livestream_id': launchSid,
          };
          if (!_rememberEvent(_eventKey(normalized, action))) continue;

          final bool launchIsCurrentRoom =
              launchSid > 0 &&
              launchSid == currentLivestreamId.value &&
              (activeSid <= 0 || launchSid == activeSid);

          if (launchIsCurrentRoom) {
            _enqueueRoomLaunch(normalized);
            _applyOwnDeliveredRewardEffects(normalized);
            unawaited(_hydrateVisibleRoomLaunch(normalized, launchSid));
          }

          // Global launch banner stays global, exactly as before.
          _enqueueGlobalLaunch(normalized);
        }

        if (sameRoom) {
          _applyRealtimeProgress(p);
          final Map<String, dynamic> last = launches.isNotEmpty
              ? <String, dynamic>{...p, ...launches.last}
              : p;
          lastLaunch.assignAll(last);
          _applyOwnDeliveredRewardEffects(last);

          // Refresh My Rewards after delivery so Frame/Entry/Gift/VIP inventory
          // information is immediately available to the current user.
          unawaited(fetchMyRewards());
        }
        break;

      case 'rocket_session_expired':
        if (sameRoom) {
          remainingSeconds.value = 0;
          progressCoins.value = 0;
          progressPercent.value = 0;
          sessionId.value = _int(p['next_session_id']);
        }
        break;

      case 'rocket_session_reset':
        if (sameRoom) {
          _applyRealtimeProgress(p);
          if (_int(p['progress_coins']) == 0 || p['progress_coins'] == null) {
            progressCoins.value = 0;
            progressPercent.value = 0;
          }
          Future<void>.delayed(const Duration(milliseconds: 350), () {
            if (currentLivestreamId.value == sid) {
              fetchHome(livestreamId: sid, showLoader: false);
            }
          });
        }
        break;
    }
  }

  void restoreRoomLaunchPresentation({
    required int livestreamId,
    required Map<String, dynamic> payload,
  }) {
    if (livestreamId <= 0) return;
    _bindRealtimeRoomNow(livestreamId);
    final normalized = <String, dynamic>{
      ...payload,
      'action_type': 'rocket_launched',
      'livestream_id': livestreamId,
    };
    _enqueueRoomLaunch(normalized);
    unawaited(_hydrateVisibleRoomLaunch(normalized, livestreamId));
  }

  /// Synchronous room binding used only after WebsocketController has already
  /// verified that the Rocket event belongs to the currently open live room.
  void _bindRealtimeRoomNow(int livestreamId) {
    if (livestreamId <= 0 || currentLivestreamId.value == livestreamId) return;
    _boundRoomGeneration++;
    currentLivestreamId.value = livestreamId;
    _lastFetchAtMs = 0;
    _resetRoomState(keepEnabled: true);
  }

  /// Safety net for a dropped/delayed rocket_progress_updated frame.
  /// Rapid gifts are debounced into one lightweight Rocket home reconciliation.
  void reconcileAfterGift(int livestreamId) {
    if (livestreamId <= 0) return;
    _bindRealtimeRoomNow(livestreamId);

    _giftReconcileTimer?.cancel();
    _giftReconcileTimer = Timer(const Duration(milliseconds: 450), () {
      if (currentLivestreamId.value != livestreamId) return;
      unawaited(fetchHome(livestreamId: livestreamId, showLoader: false));
    });
  }

  void _applyOwnDeliveredRewardEffects(Map<String, dynamic> launch) {
    try {
      if (!Get.isRegistered<AuthController>()) return;
      final AuthController auth = Get.find<AuthController>();
      final dynamic authUser = auth.userProfile.value.user;
      final int myId = _int(authUser?.id);
      if (myId <= 0) return;

      final List<Map<String, dynamic>> logs = _mapList(
        launch['delivered_reward_logs'] ?? launch['reward_logs'],
      );

      for (final Map<String, dynamic> log in logs) {
        if (_int(log['user_id']) != myId) continue;
        final String status = _text(log['status']).toLowerCase();
        if (status.isNotEmpty && status != 'delivered') continue;

        final int logId = _int(log['id']);
        if (logId > 0 && _appliedOwnRewardLogIds.contains(logId)) continue;

        final String rewardType = _text(log['reward_type']).toLowerCase();
        final Map<String, dynamic> details = _map(log['details']);

        if (rewardType == 'coin') {
          final bool hasExactBalance =
              details.containsKey('new_coin_balance') ||
              details.containsKey('coin_balance');
          if (hasExactBalance && authUser != null) {
            final int exactBalance = _int(
              details['new_coin_balance'] ?? details['coin_balance'],
            );
            authUser.coins = exactBalance.toString();
            auth.userProfile.refresh();
          }
        }

        if (logId > 0) _appliedOwnRewardLogIds.add(logId);
      }

      if (_appliedOwnRewardLogIds.length > 300) {
        _appliedOwnRewardLogIds.clear();
      }
    } catch (_) {
      // Backend has already delivered the reward. Local reflection failure must
      // never interrupt launch animation/progress processing.
    }
  }

  void _applyRealtimeProgress(Map<String, dynamic> p) {
    final Map<String, dynamic> r = _map(
      p['rocket'] ?? p['rocket_state'] ?? p['state'],
    );
    final Map<String, dynamic> merged = <String, dynamic>{...p, ...r};

    final int nextSession = _int(merged['session_id']);
    if (nextSession > 0) sessionId.value = nextSession;

    if (merged.containsKey('progress_coins')) {
      progressCoins.value = _int(merged['progress_coins']);
    }
    if (merged.containsKey('target_coins')) {
      targetCoins.value = _int(merged['target_coins']);
    }

    double percent = _double(merged['progress_percent']);
    if (percent <= 0 && targetCoins.value > 0) {
      percent = (progressCoins.value / targetCoins.value) * 100;
    }
    progressPercent.value = percent.clamp(0.0, 100.0).toDouble();

    final int remaining = _int(merged['remaining_seconds']);
    if (remaining > 0 || merged.containsKey('remaining_seconds')) {
      remainingSeconds.value = remaining;
      _ensureCountdown();
    }

    final Map<String, dynamic> level = _map(
      merged['level'] ?? merged['current_level'],
    );
    if (level.isNotEmpty) {
      currentLevel.assignAll(level);
      levelNo.value = _int(level['level_no'] ?? level['level'] ?? level['id']);
    } else {
      final int nextLevel = _int(merged['level_no']);
      if (nextLevel > 0) levelNo.value = nextLevel;
    }

    final List<Map<String, dynamic>> rankRows = _mapList(merged['ranking']);
    if (rankRows.isNotEmpty) ranking.assignAll(rankRows);
    final Map<String, dynamic> mine = _map(merged['my_ranking']);
    if (mine.isNotEmpty) myRanking.assignAll(mine);
  }

  List<Map<String, dynamic>> _extractLaunches(Map<String, dynamic> p) {
    final List<Map<String, dynamic>> rows = _mapList(
      p['launches'] ?? p['completed_levels'] ?? p['rocket_launches'],
    );
    if (rows.isNotEmpty) return rows;

    final Map<String, dynamic> single = _map(
      p['launch'] ?? p['rocket_launch'] ?? p['last_launch'],
    );
    if (single.isNotEmpty) return <Map<String, dynamic>>[single];
    return <Map<String, dynamic>>[p];
  }

  String _eventKey(Map<String, dynamic> p, String action) {
    final Map<String, dynamic> level = _map(p['level'] ?? p['rocket_level']);
    return <String>[
      action,
      _text(
        p['event_id'] ??
            p['launch_event_id'] ??
            p['rocket_launch_id'] ??
            p['id'],
      ),
      '${_livestreamIdFrom(p)}',
      '${_int(p['session_id'])}',
      '${_int(p['level_id'] ?? level['id'])}',
      '${_int(p['level_no'] ?? level['level_no'] ?? level['level'])}',
      _text(p['timestamp'] ?? p['created_at'] ?? p['server_time']),
    ].join('|');
  }

  bool _rememberEvent(String key) {
    if (_seenRealtimeKeys.contains(key)) return false;
    _seenRealtimeKeys.add(key);
    _seenRealtimeOrder.addLast(key);
    while (_seenRealtimeOrder.length > 300) {
      _seenRealtimeKeys.remove(_seenRealtimeOrder.removeFirst());
    }
    return true;
  }

  bool _launchHasRewardDetails(Map<String, dynamic> launch) {
    final dynamic winners = launch['winners'];
    final dynamic logs = launch['reward_logs'];
    final dynamic delivered = launch['delivered_reward_logs'];

    return (winners is Iterable && winners.isNotEmpty) ||
        (logs is Iterable && logs.isNotEmpty) ||
        (delivered is Iterable && delivered.isNotEmpty) ||
        _map(launch['reward_results']).isNotEmpty;
  }

  int _launchId(Map<String, dynamic> launch) {
    final Map<String, dynamic> nested = _map(
      launch['launch'] ?? launch['rocket_launch'],
    );
    return _int(
      launch['launch_id'] ??
          launch['rocket_launch_id'] ??
          nested['launch_id'] ??
          nested['id'],
    );
  }

  int _launchLevelId(Map<String, dynamic> launch) {
    final Map<String, dynamic> level = _map(
      launch['level'] ?? launch['rocket_level'],
    );
    return _int(
      launch['rocket_level_id'] ??
          launch['level_id'] ??
          level['id'] ??
          level['rocket_level_id'],
    );
  }

  bool _sameLaunchIdentity(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    if (first.isEmpty || second.isEmpty) return false;

    final int firstLaunchId = _launchId(first);
    final int secondLaunchId = _launchId(second);
    if (firstLaunchId > 0 && secondLaunchId > 0) {
      return firstLaunchId == secondLaunchId;
    }

    final int firstSession = _int(first['session_id']);
    final int secondSession = _int(second['session_id']);
    final int firstLevel = _launchLevelId(first);
    final int secondLevel = _launchLevelId(second);

    return firstSession > 0 &&
        secondSession > 0 &&
        firstSession == secondSession &&
        (firstLevel <= 0 || secondLevel <= 0 || firstLevel == secondLevel);
  }

  Map<String, dynamic> _mergeLatestLaunchDetails(Map<String, dynamic> launch) {
    final Map<String, dynamic> original = Map<String, dynamic>.from(launch);
    final Map<String, dynamic> latest = Map<String, dynamic>.from(lastLaunch);

    if (latest.isEmpty ||
        (!_sameLaunchIdentity(original, latest) &&
            !(!_launchHasRewardDetails(original) &&
                _launchLevelId(original) > 0 &&
                _launchLevelId(original) == _launchLevelId(latest)))) {
      return original;
    }

    return <String, dynamic>{
      ...original,
      ...latest,

      /// Preserve realtime identity fields. They keep queue/dedupe stable even
      /// after the API response hydrates winners and delivered reward logs.
      'event_id': original['event_id'] ?? latest['event_id'],
      'launch_event_id':
          original['launch_event_id'] ?? latest['launch_event_id'],
      'action_type':
          original['action_type'] ?? latest['action_type'] ?? 'rocket_launched',
      'livestream_id': original['livestream_id'] ?? latest['livestream_id'],
      'stream_id': original['stream_id'] ?? latest['stream_id'],
      'level':
          latest['level'] ??
          latest['rocket_level'] ??
          original['level'] ??
          original['rocket_level'],
    };
  }

  Map<String, dynamic> _enrichRoomLaunch(Map<String, dynamic> launch) {
    final Map<String, dynamic> enriched = _mergeLatestLaunchDetails(
      Map<String, dynamic>.from(launch),
    );

    /// The launch event can be intentionally compact. Keep the latest current
    /// session ranking snapshot so TOP1/TOP2/TOP3 profiles are available before
    /// the launch animation reaches the reward dialog.
    final dynamic launchRanking = enriched['ranking'];
    if ((launchRanking is! Iterable || launchRanking.isEmpty) &&
        ranking.isNotEmpty) {
      enriched['ranking'] = ranking
          .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    /// Always prefer the rewards configured on the launched level. The current
    /// room can already advance to the next level immediately after launch, so
    /// controller.rewards may otherwise show the next level's rewards.
    final Map<String, dynamic> launchedLevel = _map(
      enriched['level'] ?? enriched['rocket_level'],
    );
    final Map<String, dynamic> launchedLevelRewards = _map(
      launchedLevel['rewards'] ??
          enriched['level_rewards'] ??
          enriched['reward_setup'],
    );

    if (launchedLevelRewards.isNotEmpty) {
      enriched['level_rewards'] = Map<String, dynamic>.from(
        launchedLevelRewards,
      );
      if (_map(enriched['rewards']).isEmpty) {
        enriched['rewards'] = Map<String, dynamic>.from(launchedLevelRewards);
      }
    } else {
      final dynamic launchRewards = enriched['rewards'];
      if ((launchRewards is! Map || launchRewards.isEmpty) &&
          rewards.isNotEmpty) {
        enriched['rewards'] = Map<String, dynamic>.from(rewards);
      }
    }

    return enriched;
  }

  void _enqueueRoomLaunch(Map<String, dynamic> launch) {
    final Map<String, dynamic> enriched = _enrichRoomLaunch(launch);

    if (roomLaunchVisible.value) {
      if (_roomLaunchQueue.length >= 8) _roomLaunchQueue.removeFirst();
      _roomLaunchQueue.addLast(enriched);
      return;
    }
    roomLaunchData.assignAll(enriched);
    roomLaunchVisible.value = true;
  }

  Future<void> _hydrateVisibleRoomLaunch(
    Map<String, dynamic> launch,
    int livestreamId,
  ) async {
    if (livestreamId <= 0 || livestreamId != currentLivestreamId.value) {
      return;
    }

    final Map<String, dynamic> wanted = Map<String, dynamic>.from(launch);

    /// Ranking can arrive from its own endpoint. The complete launch winner and
    /// reward log data comes from home.last_launch, so hydrate both while the
    /// 7-second countdown is playing.
    await fetchRanking(livestreamId: livestreamId);

    for (int attempt = 0; attempt < 2; attempt++) {
      if (livestreamId != currentLivestreamId.value) return;

      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 320 : 760),
      );
      await fetchHome(livestreamId: livestreamId, showLoader: false);

      final Map<String, dynamic> latest = Map<String, dynamic>.from(lastLaunch);
      if (latest.isNotEmpty &&
          _sameLaunchIdentity(wanted, latest) &&
          _launchHasRewardDetails(latest)) {
        break;
      }
    }

    if (livestreamId != currentLivestreamId.value) return;
    if (!roomLaunchVisible.value || roomLaunchData.isEmpty) return;

    final Map<String, dynamic> current = Map<String, dynamic>.from(
      roomLaunchData,
    );
    if (!_sameLaunchIdentity(current, wanted)) return;

    final Map<String, dynamic> refreshed = _enrichRoomLaunch(current);
    roomLaunchData.assignAll(refreshed);
  }

  void finishRoomLaunch() {
    if (_roomLaunchQueue.isNotEmpty) {
      roomLaunchData.assignAll(
        _enrichRoomLaunch(_roomLaunchQueue.removeFirst()),
      );
      roomLaunchVisible.value = true;
      return;
    }
    roomLaunchVisible.value = false;
    roomLaunchData.clear();
  }

  void _enqueueGlobalLaunch(Map<String, dynamic> launch) {
    if (globalLaunchBannerVisible.value) {
      if (_globalLaunchQueue.length >= 20) _globalLaunchQueue.removeFirst();
      _globalLaunchQueue.addLast(Map<String, dynamic>.from(launch));
      return;
    }
    globalLaunchData.assignAll(launch);
    globalLaunchBannerVisible.value = true;
  }

  void finishGlobalLaunchBanner() {
    if (_globalLaunchQueue.isNotEmpty) {
      globalLaunchData.assignAll(_globalLaunchQueue.removeFirst());
      globalLaunchBannerVisible.value = true;
      return;
    }
    globalLaunchBannerVisible.value = false;
    globalLaunchData.clear();
  }

  void hideGlobalLaunchBanner() {
    globalLaunchBannerVisible.value = false;
    finishGlobalLaunchBanner();
  }

  void _ensureCountdown() {
    if (remainingSeconds.value <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      return;
    }
    if (_countdownTimer?.isActive == true) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (remainingSeconds.value <= 1) {
        remainingSeconds.value = 0;
        timer.cancel();
        _countdownTimer = null;
        return;
      }
      remainingSeconds.value--;
    });
  }

  void _resetRoomState({bool keepEnabled = false}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!keepEnabled) enabled.value = false;
    setting.clear();
    rocket.clear();
    levels.clear();
    rewards.clear();
    ranking.clear();
    myRanking.clear();
    launchHistory.clear();
    lastLaunch.clear();
    sessionId.value = 0;
    progressCoins.value = 0;
    targetCoins.value = 0;
    progressPercent.value = 0;
    remainingSeconds.value = 0;
    levelNo.value = 0;
    currentLevel.clear();
    roomLaunchVisible.value = false;
    roomLaunchData.clear();
    _roomLaunchQueue.clear();
  }

  String formatCountdown(int totalSeconds) {
    final int safe = totalSeconds < 0 ? 0 : totalSeconds;
    final int hours = safe ~/ 3600;
    final int minutes = (safe % 3600) ~/ 60;
    final int seconds = safe % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void onInit() {
    LiveTestingLogger.installDio(_dio, owner: 'RocketController');
    super.onInit();
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _giftReconcileTimer?.cancel();
    _roomLaunchQueue.clear();
    _globalLaunchQueue.clear();
    super.onClose();
  }
}
