
import 'dart:async';
import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/safe_network_image.dart';
import '../../../../widgets/tasksLiveView.dart';
import '../../../services/agora_service.dart';
import '../../auth/views/profile_view.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../myprofile/views/ProfileConribution.dart';
import '../controllers/livestream_action_controller.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/websocket_controller.dart';
import '../helper_functions/call_list_helper.dart';
import '../widgets/AnimatedProgressBar.dart';
import '../widgets/CustomPartyRoom.dart';
import '../widgets/LiveProfile_AppBar.dart';
import '../widgets/Live_view _imageCard.dart';
import '../widgets/entry_animation.dart';
import '../widgets/gifts_animation.dart';
import '../widgets/live_comments.dart';
import '../widgets/live_viewer_list.dart';
import '../widgets/pk_live_widgets.dart';
import '../widgets/red_packet_animation.dart';
import '../widgets/rocket_launch_overlay.dart';
import '../widgets/towVsTowPk.dart';
import '../widgets/write_comments.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class PopularLiveView extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;
  final String token;

  const PopularLiveView({
    super.key,
    required this.channelName,
    required this.isBroadcaster,
    required this.token,
  });

  @override
  State<PopularLiveView> createState() => _PopularLiveViewState();
}

/// Persistent normal/Lucky gift repaint island for video/PK rooms.
class _PopularGiftOverlayHost extends StatelessWidget {
  const _PopularGiftOverlayHost({required this.controller});

  final WebsocketController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Obx(() {
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            controller.giftsData,
          );
          final bool active = controller.isGiftAnimationShowing.value;

          return IgnorePointer(
            ignoring: true,
            child: GiftAnimationWidget(
              key: const ValueKey('persistent_popular_gift_overlay'),
              giftData: data,
              isActive: active,
            ),
          );
        }),
      ),
    );
  }
}

class _PopularLiveViewState extends State<PopularLiveView>
    with WidgetsBindingObserver {
  LivestreamController liveController = Get.find();

  /// Keep old `livestreamController` usages safe without creating another controller.
  LivestreamController get livestreamController => liveController;
  LiveStreamActionController actionController = Get.put(
    LiveStreamActionController(),
  );
  WebsocketController websocketController = Get.put(WebsocketController());
  AnimatedProgressBarController animatedProgressBarController = Get.put(
    AnimatedProgressBarController(),
  );
  final AgoraService _agoraService = AgoraService();

  final streamData = Get.arguments;

  final streamInfo = {}.obs;
  final broadcasterData = {}.obs;
  String? _currentToken;

  /// Agora prepare guard.
  /// Fixes AgoraRtcException(-8) when opening another live while old channel
  /// is still active in the shared Agora engine.
  bool _prepareForLiveInProgress = false;

  /// Video live safe lifecycle flags.
  /// Host normal back/minimize/route change-e live end/remove hobe na.
  bool _isLiveMinimized = false;
  bool _isLiveExiting = false;
  bool _isHostLeavingRoomOnly = false;
  bool _videoExitCleanupStarted = false;
  bool _isVideoAppInBackground = false;
  Future<void>? _audienceExitCleanupFuture;
  RtcEngineEventHandler? _agoraEventHandler;
  final Set<int> _joinedRemoteUids = <int>{};
  final Set<int> _offlineRemoteUids = <int>{};
  final Set<int> _remoteVideoReadyUids = <int>{};
  final Set<String> _loggedVideoLayoutKeys = <String>{};
  final Map<String, Widget> _stableVideoRenderers = <String, Widget>{};
  final Map<int, Timer> _remoteOfflineGraceTimers = <int, Timer>{};
  Worker? _videoCallListWorker;
  Future<void>? _remoteSubscriptionReconcileFuture;

  /// Accepted video/audio callers are cached while their real Agora media is
  /// still connected. Backend/API snapshots can briefly omit a caller after a
  /// 2-4 minute presence timeout even though both users still see/hear each
  /// other. The cache repairs that weak snapshot instead of hiding the seat.
  final Map<int, Map<String, dynamic>> _activeVideoCallLeaseCache =
  <int, Map<String, dynamic>>{};
  final Map<int, int> _activeVideoCallLeaseSeenAtMs = <int, int>{};
  Timer? _videoCallLeaseKeepAliveTimer;
  bool _videoCallLeaseRepairScheduled = false;
  static const int _videoCallOfflineGraceMs = 8000;

  /// Prevent duplicate camera toggle requests from caller cards.
  final Set<int> _videoToggleUsersInFlight = <int>{};

  String _lastSyncedPkChannel = '';
  bool _pkSyncScheduled = false;

  /// Agora speaking wave state.
  /// Backend chara Agora volume indication diye detect hobe ke kotha bolse.
  final Set<int> _speakingUserIds = <int>{};
  final Map<int, Timer> _speakingOffTimers = <int, Timer>{};
  static const int _speakingVolumeThreshold = 18;

  /// PK Agora channel state. Keeps old normal live safe and prevents repeated join.
  final RxSet<int> _pkRemoteUids = <int>{}.obs;
  String _activeAgoraChannel = '';
  String _lastPkJoinKey = '';
  bool _pkJoinInProgress = false;
  bool _normalReturnInProgress = false;
  bool _wasInPkChannel = false;

  /// Video room presence lease. Audio live already starts this heartbeat, but
  /// video live previously relied only on Agora. The backend therefore removed
  /// an active caller after its 120-second presence timeout while media kept
  /// flowing. This state keeps the video viewer/caller/host lease alive.

  int _normalizeAgoraUid(int uid) {
    /// Agora local user-er jonno kichu case-e uid 0 aste pare.
    /// Tokhon current logged-in user id use korbo.
    if (uid == 0) {
      return authController.userProfile.value.user?.id?.toInt() ?? 0;
    }
    return uid;
  }

  /// PK remote video render helper.
  /// Backend/App sometimes uses host id directly (100448), and sometimes old host id
  /// gets mapped to Agora uid by adding 100000. This function keeps both safe.
  int _pkAgoraRenderUidFromHostId(int hostId) {
    if (hostId <= 0) return 0;

    // Already Agora-style uid, like 100448.
    if (hostId >= 100000) return hostId;

    // If Agora callback already gave this exact uid, use it.
    if (_pkRemoteUids.contains(hostId)) return hostId;

    final int mappedUid = 100000 + hostId;
    if (_pkRemoteUids.contains(mappedUid)) return mappedUid;

    // Token logs show PK UID as 100xxx, so fallback to mapped uid.
    return mappedUid;
  }

  /// Current logged-in user and PK host can be stored as different but equivalent
  /// ids, for example 448 vs 100448. This keeps local-host detection correct.
  bool _isSamePkHost({required int currentUid, required int hostId}) {
    if (currentUid <= 0 || hostId <= 0) return false;
    if (currentUid == hostId) return true;

    if (currentUid >= 100000 && currentUid - 100000 == hostId) return true;
    if (hostId >= 100000 && hostId - 100000 == currentUid) return true;

    final int mappedCurrent = currentUid >= 100000
        ? currentUid
        : currentUid + 100000;
    final int mappedHost = hostId >= 100000 ? hostId : hostId + 100000;
    return mappedCurrent == mappedHost;
  }

  /// Remote host online check for PK waiting overlay.
  /// Local host should be treated as online immediately.
  bool _isPkRemoteHostOnline(int hostId) {
    if (hostId <= 0) return false;

    final int currentUid =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (_isSamePkHost(currentUid: currentUid, hostId: hostId)) return true;

    if (_pkRemoteUids.contains(hostId)) return true;

    final int renderUid = _pkAgoraRenderUidFromHostId(hostId);
    if (renderUid > 0 && _pkRemoteUids.contains(renderUid)) return true;

    // Reverse mapping support just in case callback returns old uid.
    if (hostId >= 100000 && _pkRemoteUids.contains(hostId - 100000))
      return true;
    if (hostId < 100000 && _pkRemoteUids.contains(hostId + 100000)) return true;

    return false;
  }

  bool _isUserSpeaking(dynamic userId) {
    final id = int.tryParse(userId?.toString() ?? '') ?? 0;
    return id != 0 && _speakingUserIds.contains(id);
  }

  bool _isCallMuted(dynamic call) {
    if (call is! Map) return false;

    bool isTruthy(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value.toInt() == 1;
      final text = value?.toString().toLowerCase().trim() ?? '';
      return text == '1' ||
          text == 'true' ||
          text == 'yes' ||
          text == 'muted' ||
          text == 'mute';
    }

    bool isAudioOff(dynamic value) {
      if (value is bool) return !value;
      if (value is num) return value.toInt() == 0;
      final text = value?.toString().toLowerCase().trim() ?? '';
      return text == '0' ||
          text == 'false' ||
          text == 'off' ||
          text == 'muted' ||
          text == 'mute';
    }

    return isAudioOff(call['audio_on'] ?? call['is_audio_on']) ||
        isTruthy(call['is_muted']) ||
        isTruthy(call['is_muted_by_host']) ||
        isTruthy(call['muted']);
  }

  bool _isUserMuted(dynamic userId) {
    final id = int.tryParse(userId?.toString() ?? '') ?? 0;
    if (id == 0) return false;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (id == currentUserId && liveController.mute.value == true) {
      return true;
    }

    final index = websocketController.liveCallList.indexWhere((call) {
      final callerId = call['caller_id'];
      final uid = call['user']?['id'] ?? callerId;
      return uid.toString() == id.toString();
    });

    if (index == -1) return false;

    return _isCallMuted(websocketController.liveCallList[index]);
  }

  void _setSpeakingStatus({required int uid, required bool isSpeaking}) {
    final userId = _normalizeAgoraUid(uid);
    if (userId == 0) return;

    /// Muted user kotha bolleo wave show korbe na.
    if (isSpeaking && _isUserMuted(userId)) {
      isSpeaking = false;
    }

    final bool alreadySpeaking = _speakingUserIds.contains(userId);

    if (isSpeaking) {
      _speakingOffTimers[userId]?.cancel();
      _speakingOffTimers[userId] = Timer(const Duration(milliseconds: 700), () {
        _setSpeakingStatus(uid: userId, isSpeaking: false);
      });

      if (!alreadySpeaking) {
        _speakingUserIds.add(userId);
        _updateLiveCallSpeakingStatus(userId: userId, isSpeaking: true);
        _scheduleUIUpdate();
      }
    } else {
      _speakingOffTimers[userId]?.cancel();
      _speakingOffTimers.remove(userId);

      if (alreadySpeaking) {
        _speakingUserIds.remove(userId);
        _updateLiveCallSpeakingStatus(userId: userId, isSpeaking: false);
        _scheduleUIUpdate();
      }
    }
  }

  void _updateLiveCallSpeakingStatus({
    required int userId,
    required bool isSpeaking,
  }) {
    final index = websocketController.liveCallList.indexWhere((call) {
      final callerId = call['caller_id'];
      final uid = call['user']?['id'] ?? callerId;
      return uid.toString() == userId.toString();
    });

    if (index != -1) {
      websocketController.liveCallList[index]['is_speaking'] = isSpeaking;
      // Do not refresh the whole Rx call list on every audio-volume callback.
      // The debounced page repaint below is enough and avoids extra heat/jank.
    }
  }

  final addComments = TextEditingController();

  // ✅ BATTERY OPTIMIZATION: Debounce setState calls to reduce UI updates
  Timer? _uiUpdateTimer;
  bool _needsUIUpdate = false;
  //sawip
  double _uiOffset = 0.0; // UI-র বর্তমান পজিশন
  bool _isUIVisible = true; // UI কি দেখা যাচ্ছে কি না
  void _handleDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;

    setState(() {
      _uiOffset += details.delta.dx;
      _uiOffset = _uiOffset.clamp(0.0, screenWidth);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.velocity.pixelsPerSecond.dx;

    setState(() {
      // left swipe করলে show হবে
      if (velocity < -300 || _uiOffset < screenWidth * 0.7) {
        _uiOffset = 0;
        _isUIVisible = true;
      }
      // right swipe করলে hide হবে
      else {
        _uiOffset = screenWidth;
        _isUIVisible = false;
      }
    });
  }

  void _scheduleUIUpdate() {
    if (_videoExitCleanupStarted) return;
    if (_uiUpdateTimer?.isActive == true) return;

    _needsUIUpdate = true;
    _uiUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      if (_needsUIUpdate && mounted) {
        setState(() {});
        _needsUIUpdate = false;
      }
    });
  }

  int _videoLeaseNowMs() => DateTime.now().millisecondsSinceEpoch;

  bool _isCachedCallMediaStillActive(
      int userId,
      Map<String, dynamic> call,
      ) {
    if (userId <= 0 || _videoExitCleanupStarted || _isLiveExiting) {
      return false;
    }

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (userId == currentUserId && !widget.isBroadcaster) {
      // Explicit seat leave turns these flags off in LivestreamController. A
      // weak timeout does not, so the current caller can safely keep the lease.
      return liveController.hasJoinedCall.value == true ||
          liveController.isAudioEnabled.value == true ||
          liveController.currentPresenceRole == 'caller' ||
          liveController.currentPresenceIsOnSeat == true;
    }

    final int mappedUid = liveController.videoCallerAgoraUidMap[userId] ?? 0;
    if (mappedUid > 0 &&
        (_joinedRemoteUids.contains(mappedUid) ||
            liveController.videoLiveRemoteUids.contains(mappedUid))) {
      return true;
    }

    return _joinedRemoteUids.any((uid) => _uidsAreEquivalent(uid, userId)) ||
        liveController.videoLiveRemoteUids.any(
              (uid) => _uidsAreEquivalent(uid, userId),
        );
  }

  void _syncActiveVideoCallLeaseCache() {
    final int nowMs = _videoLeaseNowMs();
    final Set<int> currentAcceptedIds = <int>{};

    for (final raw in websocketController.liveCallList) {
      if (raw is! Map) continue;
      final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
      if (!_isAcceptedCall(call)) continue;

      final String type = (call['call_type'] ?? call['type'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (type != 'audio' && type != 'video' && type != 'popular') continue;

      final int userId = _safeUserId(call);
      if (userId <= 0) continue;
      currentAcceptedIds.add(userId);

      final Map<String, dynamic> old =
          _activeVideoCallLeaseCache[userId] ?? <String, dynamic>{};
      _activeVideoCallLeaseCache[userId] = <String, dynamic>{
        ...old,
        ...call,
        'caller_id': call['caller_id'] ?? call['user_id'] ?? userId,
        'user_id': call['user_id'] ?? call['caller_id'] ?? userId,
        'call_status': call['call_status'] ?? call['status'] ?? 'accepted',
      };
      _activeVideoCallLeaseSeenAtMs[userId] = nowMs;
    }

    final List<int> removeIds = <int>[];
    for (final entry in _activeVideoCallLeaseCache.entries) {
      final int userId = entry.key;
      if (currentAcceptedIds.contains(userId)) continue;

      if (_isCachedCallMediaStillActive(userId, entry.value)) continue;

      final int lastSeen = _activeVideoCallLeaseSeenAtMs[userId] ?? 0;
      if (lastSeen <= 0 || nowMs - lastSeen >= _videoCallOfflineGraceMs) {
        removeIds.add(userId);
      }
    }

    for (final int userId in removeIds) {
      _activeVideoCallLeaseCache.remove(userId);
      _activeVideoCallLeaseSeenAtMs.remove(userId);
    }
  }

  List<Map<String, dynamic>> _effectiveVideoCallRows() {
    _syncActiveVideoCallLeaseCache();

    final Map<int, Map<String, dynamic>> rows =
    <int, Map<String, dynamic>>{};

    for (final raw in websocketController.liveCallList) {
      if (raw is! Map) continue;
      final Map<String, dynamic> call = Map<String, dynamic>.from(raw);
      final int userId = _safeUserId(call);
      if (userId <= 0) continue;
      rows[userId] = call;
    }

    for (final entry in _activeVideoCallLeaseCache.entries) {
      if (rows.containsKey(entry.key)) continue;
      if (!_isCachedCallMediaStillActive(entry.key, entry.value)) continue;
      rows[entry.key] = Map<String, dynamic>.from(entry.value);
    }

    return rows.values.toList(growable: false);
  }

  void _scheduleActiveVideoCallLeaseRepair({
    String source = 'call_list_changed',
  }) {
    if (_videoCallLeaseRepairScheduled || _videoExitCleanupStarted) return;
    _videoCallLeaseRepairScheduled = true;

    Future.microtask(() {
      _videoCallLeaseRepairScheduled = false;
      if (!mounted || _videoExitCleanupStarted) return;

      _syncActiveVideoCallLeaseCache();
      final Set<int> currentIds = websocketController.liveCallList
          .whereType<Map>()
          .map(_safeUserId)
          .where((id) => id > 0)
          .toSet();

      bool repaired = false;
      for (final entry in _activeVideoCallLeaseCache.entries) {
        final int userId = entry.key;
        if (currentIds.contains(userId)) continue;
        if (!_isCachedCallMediaStillActive(userId, entry.value)) continue;

        websocketController.liveCallList.add(<String, dynamic>{
          ...entry.value,
          'caller_id':
          entry.value['caller_id'] ?? entry.value['user_id'] ?? userId,
          'user_id':
          entry.value['user_id'] ?? entry.value['caller_id'] ?? userId,
          'call_status': 'accepted',
          'status': 'accepted',
          '_client_media_lease_repaired': true,
        });
        currentIds.add(userId);
        repaired = true;
      }

      if (repaired) {
        websocketController.liveCallList.refresh();
        debugPrint(
          'VIDEO_CALL_LEASE_REPAIRED => source=$source '
              'calls=${websocketController.liveCallList.length}',
        );
      }
    });
  }

  Map<String, dynamic>? _currentSelfVideoCall() {
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId <= 0) return null;

    for (final call in _effectiveVideoCallRows()) {
      if (_safeUserId(call) != currentUserId) continue;
      if (!_isActiveVideoCall(call)) continue;
      return call;
    }
    return null;
  }

  int _currentSelfVideoSeatNo() {
    final call = _currentSelfVideoCall();
    if (call == null) return 0;
    return _safeInt(
      call['seat_no'] ??
          call['seat'] ??
          call['seat_number'] ??
          call['seatNo'],
    );
  }

  void _ensureVideoPresenceHeartbeat({
    String source = 'video_live',
    bool? backgroundMode,
  }) {
    if (_videoExitCleanupStarted || _isLiveExiting) return;

    final int sid = _safeStreamId();
    if (sid <= 0) return;

    final Map<String, dynamic>? selfVideoCall = _currentSelfVideoCall();
    final bool isCaller = !widget.isBroadcaster && selfVideoCall != null;
    final String role = widget.isBroadcaster
        ? 'host'
        : (isCaller ? 'caller' : 'viewer');
    final int seatNo = widget.isBroadcaster
        ? 1
        : (isCaller ? _currentSelfVideoSeatNo() : 0);

    liveController.startLivePresenceHeartbeat(
      livestreamId: sid,
      role: role,
      isOnSeat: role == 'host' || role == 'caller',
      seatNo: seatNo > 0 ? seatNo : null,
      backgroundMode: backgroundMode ?? _isVideoAppInBackground,
    );

    debugPrint(
      'VIDEO_PRESENCE_READY => stream=$sid role=$role '
          'seat=${seatNo > 0 ? seatNo : 0} source=$source',
    );
  }

  Future<void> _restoreVideoMediaAfterResume() async {
    if (_videoExitCleanupStarted || !mounted) return;
    final engine = _agoraService.engine;
    if (engine == null) return;

    final Map<String, dynamic>? selfVideoCall = _currentSelfVideoCall();
    final bool selfIsVideoCaller = selfVideoCall != null;
    final bool shouldPublishLocal = widget.isBroadcaster || selfIsVideoCaller;
    final bool keepMicMuted = liveController.mute.value == true;
    final bool keepCameraEnabled = widget.isBroadcaster
        ? liveController.isVideoEnabled.value
        : (selfVideoCall == null ? false : _callVideoEnabled(selfVideoCall));

    await _safeAgoraAction('resume enableAudio', () => engine.enableAudio());
    await _safeAgoraAction('resume enableVideo', () => engine.enableVideo());
    await _safeAgoraAction(
      'resume remote audio',
          () => engine.muteAllRemoteAudioStreams(false),
    );
    await _safeAgoraAction(
      'resume remote video',
          () => engine.muteAllRemoteVideoStreams(false),
    );

    if (shouldPublishLocal) {
      await _safeAgoraAction(
        'resume broadcaster role',
            () => engine.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      await _safeAgoraAction(
        'resume local video',
            () => engine.enableLocalVideo(true),
      );
      await _safeAgoraAction(
        'resume local audio',
            () => engine.enableLocalAudio(true),
      );
      await _safeAgoraAction(
        'resume publish media',
            () => engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: keepCameraEnabled,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          ),
        ),
      );
      await _safeAgoraAction(
        'resume local camera state',
            () => engine.muteLocalVideoStream(!keepCameraEnabled),
      );
      await _safeAgoraAction(
        'resume local mic state',
            () => engine.muteLocalAudioStream(keepMicMuted),
      );
      await _safeAgoraAction(
        'resume recording volume',
            () => engine.adjustRecordingSignalVolume(keepMicMuted ? 0 : 100),
      );
      if (keepCameraEnabled) {
        await _safeAgoraAction(
          'resume camera preview',
              () => _agoraService.startPreview(),
        );
      }
      try {
        await _agoraService.applyNaturalLowLightEnhancement();
      } catch (_) {}
    }

    _reconcileRemoteCallerSubscriptions();
    _scheduleUIUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoExitCleanupStarted) return;

    if (state == AppLifecycleState.resumed) {
      _isVideoAppInBackground = false;
      liveController.setLivePresenceBackgroundMode(false);
      _ensureVideoPresenceHeartbeat(source: 'app_resumed');
      unawaited(_restoreVideoMediaAfterResume());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isVideoAppInBackground = true;
      liveController.setLivePresenceBackgroundMode(true);
    }
  }

  void setLiveStreamDataAsBroadcaster() {
    if (streamData != null) {
      streamInfo.value = streamData['livestreamdata'] ?? {};
      broadcasterData.value = streamData['broadcaster_call_data'] ?? {};
      _bootstrapPkStateFromArguments(source: 'broadcaster_stream_data');

      if (broadcasterData.value.isNotEmpty &&
          broadcasterData.value['user'] != null) {
        liveController.broadcasterId.value = _safeUserId(broadcasterData);
        print('broadcaster id ${liveController.broadcasterId}');
      }
      // Battery Optimization: Use optimized ping interval
      liveController.lastPingUpdate(id: streamInfo['id']);
      _ensureVideoPresenceHeartbeat(source: 'broadcaster_stream_data');

      // Timer start করি broadcaster এর জন্য
      if (!liveController.isLive.value) {
        String? createdAt =
            streamData['livestreamdata']?['created_at'] ??
                broadcasterData['created_at'];
        if (createdAt != null) {
          liveController.startLive(createdAt);
        } else {
          liveController.startLive(DateTime.now().toIso8601String());
        }
      }
    } else {
      streamInfo.value = {};
      broadcasterData.value = {};
      print('Warning: streamData is null in setLiveStreamDataAsBroadcaster');
    }
  }

  void setLiveStreamDataAsAudience() async {
    // print('stream data $streamData');
    // // Ensure call list is populated for first-time audience members
    await liveController.tryToGetCallList(streamId: streamData['id']);
    // Check if livestream_callers exists and is not empty
    if (streamData != null &&
        streamData['livestream_callers'] != null &&
        streamData['livestream_callers'].isNotEmpty) {
      broadcasterData.value = streamData['livestream_callers'][0];
      liveController.broadcasterId.value = _safeUserId(broadcasterData);
      print('this is broadcaster data ${_safeUserName(broadcasterData)}');
    } else {
      // Fallback: try to get broadcaster data from other sources
      broadcasterData.value = streamData['broadcaster_call_data'] ?? {};
      if (broadcasterData.value.isNotEmpty &&
          broadcasterData.value['user'] != null) {
        liveController.broadcasterId.value = _safeUserId(broadcasterData);
      }
      print('Using fallback broadcaster data');
    }

    // Set streamInfo with proper fallback
    if (streamData != null) {
      streamInfo.value = streamData;
      _bootstrapPkStateFromArguments(source: 'audience_stream_data');
    } else {
      streamInfo.value = {};
      print('Warning: streamData is null in setLiveStreamDataAsAudience');
    }

    // Set the stream ID in WebSocket controller and fetch initial gift total
    if (streamData != null && streamData['id'] != null) {
      websocketController.streamID.value = streamData['id'];
      liveController.streamId.value = _safeInt(streamData['id']);
      websocketController.fetchInitialGiftTotal();
      _ensureVideoPresenceHeartbeat(source: 'audience_stream_data');
    }

    // Timer start করি audience এর জন্য
    if (!liveController.isLive.value) {
      String? createdAt =
          streamData['created_at'] ?? broadcasterData['created_at'];
      if (createdAt != null) {
        liveController.startLive(createdAt);
      } else {
        liveController.startLive(DateTime.now().toIso8601String());
      }
    }
  }

  bool _isAgoraStateError(dynamic error, int code) {
    final text = error.toString();
    return text.contains('($code') ||
        text.contains(' $code') ||
        text.contains('code: $code');
  }

  Future<void> _safeAgoraAction(
      String label,
      Future<void> Function() action, {
        bool ignoreMinus8 = true,
      }) async {
    try {
      await action();
    } catch (e) {
      if (ignoreMinus8 && _isAgoraStateError(e, -8)) {
        debugPrint(
          '⚠️ $label ignored safely => Agora already in joined state: $e',
        );
        return;
      }
      debugPrint('⚠️ $label ignored safely => $e');
    }
  }

  void _registerAgoraEventHandlerSafe(RtcEngine engine) {
    try {
      final previousHandler = _agoraEventHandler;
      if (previousHandler != null) {
        engine.unregisterEventHandler(previousHandler);
      }
      _agoraEventHandler = RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          _activeAgoraChannel = connection.channelId ?? _activeAgoraChannel;
          if (kDebugMode) {
            final String prefix = widget.isBroadcaster ? 'create' : 'join';
            debugPrint(
              '${prefix}_agora_join_success=${DateTime.now().microsecondsSinceEpoch}',
            );
            debugPrint(
              '${prefix}_first_audio_ready=${DateTime.now().microsecondsSinceEpoch}',
            );
          }
          print("🎉 Joined channel successfully => ${connection.channelId}");
          _ensureVideoPresenceHeartbeat(source: 'agora_join_success');
          _scheduleUIUpdate();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          debugPrint('AGORA_REMOTE_USER_JOINED => uid=$remoteUid');
          _joinedRemoteUids.add(remoteUid);
          liveController.syncVideoLiveRemoteUid(remoteUid, connected: true);
          _syncAcceptedCallerAgoraUidMappings();
          _offlineRemoteUids.removeWhere(
                (uid) => _uidsAreEquivalent(uid, remoteUid),
          );
          final reconnectedTimerUids = _remoteOfflineGraceTimers.keys
              .where((uid) => _uidsAreEquivalent(uid, remoteUid))
              .toList(growable: false);
          for (final uid in reconnectedTimerUids) {
            _remoteOfflineGraceTimers.remove(uid)?.cancel();
          }
          _pkRemoteUids.add(remoteUid);
          _reconcileRemoteCallerSubscriptions();
          _scheduleUIUpdate();
        },
        onFirstRemoteVideoFrame:
            (
            RtcConnection connection,
            int remoteUid,
            int width,
            int height,
            int elapsed,
            ) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          _pkRemoteUids.add(remoteUid);
          _scheduleUIUpdate();
        },
        onRemoteVideoStateChanged:
            (
            RtcConnection connection,
            int remoteUid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
            ) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          if (state == RemoteVideoState.remoteVideoStateStarting ||
              state == RemoteVideoState.remoteVideoStateDecoding) {
            if (_remoteVideoReadyUids.add(remoteUid)) {
              debugPrint('AGORA_REMOTE_VIDEO_READY => uid=$remoteUid');
            }
            liveController.syncVideoLiveRemoteVideo(
              remoteUid,
              enabled: true,
            );
            _pkRemoteUids.add(remoteUid);
            _syncAcceptedCallerAgoraUidMappings();
            _logVideoCallLayoutReady(remoteUid);
            _scheduleUIUpdate();
          } else if (state == RemoteVideoState.remoteVideoStateStopped ||
              state == RemoteVideoState.remoteVideoStateFailed) {
            liveController.syncVideoLiveRemoteVideo(
              remoteUid,
              enabled: false,
            );
            _scheduleUIUpdate();
          }
        },
        onUserOffline:
            (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
            ) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          final matchingCallerEntries = liveController
              .videoCallerAgoraUidMap
              .entries
              .where((entry) => entry.value == remoteUid);
          final mappedCallerId = matchingCallerEntries.isEmpty
              ? null
              : matchingCallerEntries.first.key;
          debugPrint(
            'VIDEO_CALL_REMOTE_LEFT => uid=$remoteUid caller=$mappedCallerId',
          );
          debugPrint(
            'AGORA_REMOTE_MEDIA_LEFT => uid=$remoteUid caller=$mappedCallerId reason=$reason',
          );
          _joinedRemoteUids.remove(remoteUid);
          liveController.syncVideoLiveRemoteUid(
            remoteUid,
            connected: false,
          );
          _offlineRemoteUids.add(remoteUid);
          _remoteVideoReadyUids.remove(remoteUid);
          _loggedVideoLayoutKeys.removeWhere(
                (key) => key.endsWith(':$remoteUid'),
          );
          _pkRemoteUids.remove(remoteUid);
          _setSpeakingStatus(uid: remoteUid, isSpeaking: false);
          _removeStableVideoRenderer(remoteUid);
          if (mappedCallerId != null && mappedCallerId > 0) {
            debugPrint(
              'CALL_SESSION_MEDIA_OFFLINE_PRESERVED => '
                  'user=$mappedCallerId reason=video_rtc_user_offline',
            );
            debugPrint(
              'VIEWER_PRESENCE_PRESERVED => user=$mappedCallerId '
                  'reason=video_rtc_user_offline removeViewer=false viewerRemoved=false',
            );

            // Agora offline is only a media transport signal. A short network
            // switch can fire this while the accepted call is still active.
            // Keep the host call card/list row; explicit reject/seat-left/end
            // websocket events remain the only removal authority.
            for (final raw in websocketController.liveCallList) {
              if (raw is! Map) continue;
              final call = Map<String, dynamic>.from(raw);
              if (_safeUserId(call) != mappedCallerId) continue;
              liveController.addOrUpdateViewerLocal(<String, dynamic>{
                ...call,
                'id': mappedCallerId,
                'viewer_id': mappedCallerId,
                'user_id': mappedCallerId,
                'livestream_id':
                call['livestream_id'] ??
                    call['stream_id'] ??
                    _safeStreamId(),
                'is_active': true,
              }, force: true);
              break;
            }

            _remoteOfflineGraceTimers.remove(remoteUid)?.cancel();
            _remoteOfflineGraceTimers[remoteUid] = Timer(
              const Duration(seconds: 4),
                  () {
                _remoteOfflineGraceTimers.remove(remoteUid);
                if (!mounted || _videoExitCleanupStarted) return;
                unawaited(
                  liveController.tryToGetCallList(streamId: _safeStreamId()),
                );
                websocketController.liveCallList.refresh();
                liveController.liveViewerList.refresh();
                _reconcileRemoteCallerSubscriptions();
                _scheduleUIUpdate();
              },
            );
          }
          _scheduleUIUpdate();
        },
        onRemoteAudioStateChanged:
            (
            RtcConnection connection,
            int remoteUid,
            RemoteAudioState state,
            RemoteAudioStateReason reason,
            int elapsed,
            ) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          if (state == RemoteAudioState.remoteAudioStateStopped ||
              state == RemoteAudioState.remoteAudioStateFailed) {
            _setSpeakingStatus(uid: remoteUid, isSpeaking: false);
          }
        },
        onAudioVolumeIndication:
            (
            RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume,
            ) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          for (final speaker in speakers) {
            final int uid = _normalizeAgoraUid(speaker.uid ?? 0);
            final int volume = speaker.volume ?? 0;
            if (uid == 0) continue;
            _setSpeakingStatus(
              uid: uid,
              isSpeaking: volume >= _speakingVolumeThreshold,
            );
          }
        },
        onError: (ErrorCodeType err, String msg) {
          if (_videoExitCleanupStarted ||
              !mounted ||
              !_agoraService.isCurrentEngineInstance(engine)) {
            return;
          }
          print("⚠️ Agora Error: $err | Message: $msg");
          if (widget.isBroadcaster) {
            livestreamController.agoraTokenGenerateError();
          }
        },
      );
      engine.registerEventHandler(_agoraEventHandler!);
    } catch (e) {
      debugPrint('⚠️ Agora event handler register ignored => $e');
    }
  }

  Future<void> prepareForLive() async {
    if (_videoExitCleanupStarted || _prepareForLiveInProgress) {
      debugPrint('⚠️ prepareForLive skipped: already running');
      return;
    }

    _prepareForLiveInProgress = true;

    try {
      // 🔹 Ensure Agora service is initialized
      if (!_agoraService.isInitialized || _agoraService.engine == null) {
        print("AgoraService not ready, attempting to initialize...");
        bool initialized = await _agoraService.initializeEngine();
        if (!initialized) {
          print("Failed to initialize Agora engine");
          return;
        }
      }

      if (_videoExitCleanupStarted || !mounted) return;

      final engine = _agoraService.engine;
      if (engine == null) {
        print("Engine is null after initialization");
        return;
      }

      _registerAgoraEventHandlerSafe(engine);

      final String activePkChannel = liveController.pkChannelName.value.trim();
      final bool shouldSkipNormalJoinForPk =
          liveController.pkIsRunning.value &&
              _isRealPkAgoraChannel(activePkChannel);

      // ✅ IMPORTANT FIX:
      // PK room hole prepareForLive() normal 101010/100550 channel e join korbe na.
      // PK join function already leave + join PK channel handle kore.
      if (shouldSkipNormalJoinForPk) {
        debugPrint(
          '✅ Normal Agora join skipped: PK channel active => $activePkChannel',
        );
        _scheduleUIUpdate();
        return;
      }

      final int userId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (userId == 0) {
        debugPrint('❌ prepareForLive stopped: current user id missing');
        return;
      }

      final String normalChannel = widget.channelName.trim();
      if (normalChannel.isEmpty) {
        debugPrint('❌ prepareForLive stopped: normal channel missing');
        return;
      }

      print("⚙️ Configuring Agora for stable normal live...");

      // ✅ CRITICAL FIX:
      // Old live/PK channel active thakle setChannelProfile() -8 dey.
      // Tai normal live fresh join er age old channel safely leave korbo.
      try {
        await _agoraService.leaveChannel();
        _pkRemoteUids.clear();
        _setAllSpeakingOff();
        debugPrint('✅ Old Agora channel left before normal join');
      } catch (e) {
        debugPrint('⚠️ leaveChannel before normal join ignored => $e');
      }

      await Future.delayed(const Duration(milliseconds: 180));

      await _safeAgoraAction(
        'setChannelProfile(normal)',
            () => engine.setChannelProfile(
          ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      await _safeAgoraAction('enableVideo(normal)', () => engine.enableVideo());
      await _safeAgoraAction('enableAudio(normal)', () => engine.enableAudio());
      await _safeAgoraAction(
        'enableAudioVolumeIndication(normal)',
            () => engine.enableAudioVolumeIndication(
          interval: 300,
          smooth: 3,
          reportVad: true,
        ),
      );
      await _safeAgoraAction(
        'hardware_encoding(normal)',
            () => engine.setParameters('{"che.video.hardware_encoding": true}'),
      );
      await _safeAgoraAction(
        'video_config_balanced_portrait(normal)',
            () => engine.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 540, height: 960),
            frameRate: 15,
            bitrate: 0,
            orientationMode: OrientationMode.orientationModeAdaptive,
            degradationPreference: DegradationPreference.maintainBalanced,
          ),
        ),
      );
      await _safeAgoraAction(
        'adaptive_bitrate(normal)',
            () => engine.setParameters('{"che.video.enableAdaptiveBitrate": true}'),
      );
      await _safeAgoraAction(
        'dynamic_switch(normal)',
            () => engine.setParameters('{"rtc.video.dynamic_switch": true}'),
      );
      await _safeAgoraAction(
        'low_latency(normal)',
            () => engine.setParameters('{"rtc.low_latency_mode": true}'),
      );

      if (widget.isBroadcaster) {
        await _safeAgoraAction(
          'setClientRoleBroadcaster(normal)',
              () =>
              engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster),
        );
        await _safeAgoraAction(
          'enableLocalVideo(normal host)',
              () => engine.enableLocalVideo(true),
        );
        await _safeAgoraAction(
          'enableLocalAudio(normal host)',
              () => engine.enableLocalAudio(true),
        );
        await _safeAgoraAction(
          'muteLocalVideoStream(false normal host)',
              () => engine.muteLocalVideoStream(false),
        );
        await _safeAgoraAction(
          'muteLocalAudioStream(false normal host)',
              () => engine.muteLocalAudioStream(false),
        );
        await _safeAgoraAction(
          'startPreview(normal host)',
              () => _agoraService.startPreview(),
        );
        try {
          await _agoraService.applyNaturalLowLightEnhancement();
        } catch (e) {
          debugPrint('⚠️ Host low-light enhancement skipped => $e');
        }
      } else {
        await _safeAgoraAction(
          'setClientRoleAudience(normal)',
              () => engine.setClientRole(role: ClientRoleType.clientRoleAudience),
        );
        await _safeAgoraAction(
          'enableLocalVideo(false normal audience)',
              () => engine.enableLocalVideo(false),
        );
        await _safeAgoraAction(
          'muteLocalVideoStream(true normal audience)',
              () => engine.muteLocalVideoStream(true),
        );
        await _safeAgoraAction(
          'muteLocalAudioStream(true normal audience)',
              () => engine.muteLocalAudioStream(true),
        );
      }

      await _safeAgoraAction(
        'setEnableSpeakerphone(normal)',
            () => engine.setEnableSpeakerphone(true),
      );
      await _safeAgoraAction(
        'unmuteAllRemoteAudioStreams(normal)',
            () => engine.muteAllRemoteAudioStreams(false),
      );
      await _safeAgoraAction(
        'unmuteAllRemoteVideoStreams(normal)',
            () => engine.muteAllRemoteVideoStreams(false),
      );

      if (_videoExitCleanupStarted || !mounted) return;

      try {
        if (kDebugMode) {
          final String prefix = widget.isBroadcaster ? 'create' : 'join';
          debugPrint(
            '${prefix}_agora_join_start=${DateTime.now().microsecondsSinceEpoch}',
          );
        }
        await _agoraService.joinChannelWithOptions(
          token: widget.token,
          channelId: normalChannel,
          uid: userId,
          options: ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: widget.isBroadcaster
                ? ClientRoleType.clientRoleBroadcaster
                : ClientRoleType.clientRoleAudience,
            publishCameraTrack: widget.isBroadcaster,
            publishMicrophoneTrack: widget.isBroadcaster,
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
          ),
        );
        _activeAgoraChannel = normalChannel;
        _wasInPkChannel = false;
        _lastPkJoinKey = '';
        debugPrint(
          '✅ Normal Agora join called => channel=$normalChannel uid=$userId broadcaster=${widget.isBroadcaster}',
        );
      } catch (e) {
        debugPrint('❌ Normal Agora join error => $e');
      }

      await _safeAgoraAction(
        'enable_render(normal)',
            () => engine.setParameters('{"che.video.disable_render": false}'),
      );

      _scheduleUIUpdate();
      print("✅ Agora ready with stable normal live config");
    } catch (e, stack) {
      debugPrint('❌ prepareForLive safe error => $e');
      debugPrint('$stack');
    } finally {
      _prepareForLiveInProgress = false;
    }
  }

  Future<void> _restoreExistingVideoLiveSession() async {
    final engine = _agoraService.engine;
    if (engine == null || !mounted) {
      await prepareForLive();
      return;
    }
    _registerAgoraEventHandlerSafe(engine);
    _activeAgoraChannel = widget.channelName;
    _joinedRemoteUids
      ..clear()
      ..addAll(liveController.videoLiveRemoteUids);
    await _safeAgoraAction('restore enableVideo', () => engine.enableVideo());
    await _safeAgoraAction('restore enableAudio', () => engine.enableAudio());
    await _safeAgoraAction(
      'restore remote video subscriptions',
          () => engine.muteAllRemoteVideoStreams(false),
    );
    await _safeAgoraAction(
      'restore remote audio subscriptions',
          () => engine.muteAllRemoteAudioStreams(false),
    );
    if (widget.isBroadcaster) {
      await _safeAgoraAction(
        'restore broadcaster role',
            () => engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster),
      );
      await _safeAgoraAction(
        'restore local camera',
            () => engine.enableLocalVideo(true),
      );
      await _safeAgoraAction(
        'restore local video publish',
            () => engine.muteLocalVideoStream(false),
      );
      await _safeAgoraAction(
        'restore local microphone',
            () => engine.muteLocalAudioStream(false),
      );
      await _safeAgoraAction(
        'restore preview',
            () => _agoraService.startPreview(),
      );
    }
    _scheduleUIUpdate();
  }

  // ------------------------- timer ---------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Enable wake lock to keep screen on during live streaming
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !kDebugMode) return;
      final String prefix = widget.isBroadcaster ? 'create' : 'join';
      debugPrint(
        '${prefix}_first_ui_ready=${DateTime.now().microsecondsSinceEpoch}',
      );
    });
    _currentToken = widget.token;
    final Map<String, dynamic> initArgs = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments)
        : <String, dynamic>{};
    final bool initLooksPk =
        initArgs['is_pk'] == 1 ||
            initArgs['is_pk'] == true ||
            initArgs['is_pk_room'] == true ||
            initArgs['stream_type']?.toString().toLowerCase() == 'pk' ||
            (initArgs['pk_id'] != null && initArgs['pk_id'].toString() != '0');
    final String normalChannelForReturn =
    (initArgs['normal_room_id'] ??
        initArgs['normal_channel_name'] ??
        initArgs['normal_agora_channel'] ??
        '')
        .toString()
        .trim();
    if (!initLooksPk || normalChannelForReturn.isNotEmpty) {
      liveController.saveNormalLiveAgoraSession(
        channelName: normalChannelForReturn.isNotEmpty
            ? normalChannelForReturn
            : widget.channelName,
        token: widget.token,
        isBroadcaster: widget.isBroadcaster,
      );
    }
    _bootstrapPkStateFromArguments(source: 'init_state_arguments');
    _videoCallListWorker = ever<List<dynamic>>(
      websocketController.liveCallList,
          (_) {
        _syncActiveVideoCallLeaseCache();
        _scheduleActiveVideoCallLeaseRepair(source: 'call_list_changed');
        _reconcileRemoteCallerSubscriptions();
        _ensureVideoPresenceHeartbeat(source: 'call_list_changed');
      },
    );

    _videoCallLeaseKeepAliveTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) {
        if (!mounted || _videoExitCleanupStarted || _isLiveExiting) return;
        _syncActiveVideoCallLeaseCache();
        _scheduleActiveVideoCallLeaseRepair(source: 'lease_keep_alive');
        _ensureVideoPresenceHeartbeat(source: 'lease_keep_alive');
        _reconcileRemoteCallerSubscriptions();
      },
    );
    String? createdAt;

    // প্রথমে createData থেকে check করি
    createdAt = liveController.createData['viewer']?['created_at'];

    // যদি createData থেকে না পাই, তাহলে arguments থেকে check করি
    if (createdAt == null && Get.arguments != null) {
      createdAt = Get.arguments['created_at'];
    }

    // যদি এখনো না পাই, তাহলে current time use করি
    if (createdAt != null) {
      liveController.startLive(createdAt);
    } else {
      // Fallback: current time দিয়ে timer start করি
      liveController.startLive(DateTime.now().toIso8601String());
    }

    final bool restoringMinimizedVideo =
        initArgs['restore_minimized_video_live'] == true;
    if (restoringMinimizedVideo) {
      unawaited(_restoreExistingVideoLiveSession());
    } else {
      prepareForLive();
    }
    if (widget.isBroadcaster) {
      liveController.isBroadcaster.value = true;
      setLiveStreamDataAsBroadcaster();
      websocketController.tryToConnectToUnifiedLiveStreamEventWs(force: false);
    } else {
      setLiveStreamDataAsAudience();
    }

    /// Initial call list refresh. Accept event late holeo UI sync thakbe.
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (_videoExitCleanupStarted || !mounted) return;
      try {
        final streamId = streamInfo['id'] ?? streamData?['id'];
        if (streamId != null) {
          await liveController.tryToGetCallList(streamId: streamId);
          websocketController.liveCallList.refresh();
          _ensureVideoPresenceHeartbeat(source: 'initial_call_list_refresh');
          if (mounted) _scheduleUIUpdate();
        }
      } catch (e) {
        print('❌ Popular call list initial refresh failed: $e');
      }
    });
    // Setup red packet callbacks
    _setupRedPacketCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isLiveMinimized) {
      final handler = _agoraEventHandler;
      _agoraEventHandler = null;
      final engine = _agoraService.engine;
      if (handler != null && engine != null) {
        try {
          engine.unregisterEventHandler(handler);
        } catch (_) {}
      }
    }
    _videoCallListWorker?.dispose();
    _videoCallListWorker = null;
    _videoCallLeaseKeepAliveTimer?.cancel();
    _videoCallLeaseKeepAliveTimer = null;
    _activeVideoCallLeaseCache.clear();
    _activeVideoCallLeaseSeenAtMs.clear();
    // ✅ BATTERY OPTIMIZATION: Cancel UI update timer to prevent memory leaks
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;

    for (final timer in _speakingOffTimers.values) {
      timer.cancel();
    }
    _speakingOffTimers.clear();
    _speakingUserIds.clear();
    _pkRemoteUids.clear();
    _joinedRemoteUids.clear();
    _offlineRemoteUids.clear();
    for (final timer in _remoteOfflineGraceTimers.values) {
      timer.cancel();
    }
    _remoteOfflineGraceTimers.clear();
    _stableVideoRenderers.clear();

    // Disable wake lock to restore normal screen behavior
    WakelockPlus.disable();

    // Route disposal is not a live exit. Backend/Agora cleanup is performed
    // only by the explicit Keep/Exit dialog's true Exit methods.
    print(
      '✅ Video live route disposed without implicit cleanup '
          '=> minimized=$_isLiveMinimized actuallyLeaving=$_videoExitCleanupStarted',
    );

    websocketController.clearRedPacketCallbacks();
    super.dispose();
  }

  Future<void> _leaveAudienceVideoBroadcast() {
    if (widget.isBroadcaster) return Future<void>.value();
    return _audienceExitCleanupFuture ??= _performAudienceVideoExitCleanup();
  }

  Future<void> _performAudienceVideoExitCleanup() async {
    _videoExitCleanupStarted = true;
    _isLiveExiting = true;
    _isHostLeavingRoomOnly = false;
    _isLiveMinimized = false;
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    final int streamId = _safeStreamId();
    final engine = _agoraService.engine;
    debugPrint(
      'ROOM_EXIT_REQUESTED => user=$userId source=audience_exit_confirmed',
    );

    final handler = _agoraEventHandler;
    _agoraEventHandler = null;
    if (engine != null && handler != null) {
      try {
        engine.unregisterEventHandler(handler);
      } catch (e) {
        debugPrint('Video audience Agora handler unregister ignored: $e');
      }
    }

    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
    _setAllSpeakingOff();
    _pkRemoteUids.clear();

    liveController.stopPingUpdate();
    liveController.stopLivePresenceHeartbeat();
    liveController.stopLive();
    liveController.isBroadcaster.value = false;

    if (engine != null) {
      await _safeAgoraAction(
        'muteAllRemoteAudioStreams(video audience exit)',
            () => engine.muteAllRemoteAudioStreams(true),
      );
      await _safeAgoraAction(
        'muteAllRemoteVideoStreams(video audience exit)',
            () => engine.muteAllRemoteVideoStreams(true),
      );
      await _safeAgoraAction(
        'muteLocalAudioStream(video audience exit)',
            () => engine.muteLocalAudioStream(true),
      );
      await _safeAgoraAction(
        'muteLocalVideoStream(video audience exit)',
            () => engine.muteLocalVideoStream(true),
      );
      await _safeAgoraAction(
        'enableLocalAudio(false video audience exit)',
            () => engine.enableLocalAudio(false),
      );
      await _safeAgoraAction(
        'enableLocalVideo(false video audience exit)',
            () => engine.enableLocalVideo(false),
      );
      await _safeAgoraAction(
        'resetClientRole(video audience exit)',
            () => engine.setClientRole(role: ClientRoleType.clientRoleAudience),
      );
      await _safeAgoraAction(
        'disableSubscriptions(video audience exit)',
            () => engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            publishCameraTrack: false,
            publishMicrophoneTrack: false,
            autoSubscribeAudio: false,
            autoSubscribeVideo: false,
          ),
        ),
      );
    }

    if (userId > 0) {
      liveController.removeViewerLocal(userId);
      try {
        await websocketController.clearSpecificUserStreamData(
          userId: userId.toString(),
          rejectCallIfInCallList: false,
          removeAcceptedCall: true,
          closePopupIfOpen: false,
          removeViewer: true,
          reason: 'video_audience_full_room_exit',
        );
      } catch (e) {
        debugPrint('Video audience local cleanup ignored safely: $e');
      }
    }

    final Future<void> rtcLeaveFuture = () async {
      try {
        await _agoraService.leaveChannel();
      } catch (e) {
        debugPrint('Video audience Agora leave ignored safely: $e');
      }
    }();

    final futures = <Future<void>>[rtcLeaveFuture];
    if (userId > 0 && streamId > 0) {
      futures.add(
        liveController.tryToRemoveViewer(streamId: streamId, viewerId: userId),
      );
      futures.add(
        liveController.markUserOffline(livestreamId: streamId, role: 'viewer'),
      );
    }

    await Future.wait(futures);
    try {
      await _agoraService.stopPreview();
    } catch (e) {
      debugPrint('Video audience preview stop ignored safely: $e');
    }
    await websocketController.leaveVideoRoomState(livestreamId: streamId);
    liveController.clearMinimizedVideoLiveSession();
    liveController.clearViewerLocal();
    liveController.viewerList.clear();
    liveController.liveViewerList.clear();
    liveController.giftList.clear();
    liveController.giftHistory.clear();
    liveController.totalGiftCoins.value = 0;
    if (liveController.streamId.value == streamId) {
      liveController.streamId.value = 0;
    }

    _activeAgoraChannel = '';
    _lastPkJoinKey = '';
    _wasInPkChannel = false;
    websocketController.activeAudioStreamId.value = 0;

    if (userId > 0) {
      liveController.removeViewerLocal(userId);
      try {
        await websocketController.clearSpecificUserStreamData(
          userId: userId.toString(),
          rejectCallIfInCallList: false,
          removeAcceptedCall: true,
          closePopupIfOpen: false,
          removeViewer: true,
          reason: 'video_audience_full_room_exit_complete',
        );
      } catch (e) {
        debugPrint('Video audience final local cleanup ignored safely: $e');
      }
    }

    print('Video audience exit cleanup completed');
  }

  Future<void> _minimizeVideoLiveRoom() async {
    if (_isLiveExiting) return;
    _isLiveMinimized = true;
    _isHostLeavingRoomOnly = false;
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final bool isAcceptedVideoCaller = _effectiveVideoCallRows().any(
          (call) => _isActiveVideoCall(call) && _safeUserId(call) == currentUserId,
    );

    try {
      final engine = _agoraService.engine;
      if (engine != null) {
        await engine.enableAudio();
        await engine.enableVideo();
        await engine.enableAudioVolumeIndication(
          interval: 300,
          smooth: 3,
          reportVad: true,
        );
        if (widget.isBroadcaster || isAcceptedVideoCaller) {
          await engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await engine.enableLocalVideo(true);
          await engine.muteLocalAudioStream(false);
          await engine.muteLocalVideoStream(false);
          await engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleBroadcaster,
              publishCameraTrack: true,
              publishMicrophoneTrack: true,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
          await _agoraService.startPreview();
        } else {
          // Audience preview stays local-only until a video call is accepted.
          await engine.enableLocalVideo(true);
          await engine.muteLocalVideoStream(true);
          await _agoraService.startPreview();
        }
        await engine.muteAllRemoteAudioStreams(false);
        await engine.muteAllRemoteVideoStreams(false);
      }
    } catch (e) {
      print('⚠️ Video minimize keep-alive ignored: $e');
    }

    final args = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : <String, dynamic>{};
    liveController.minimizeVideoLiveSession(
      livestreamId: _safeStreamId(),
      channelName: _activeAgoraChannelForVideo().isNotEmpty
          ? _activeAgoraChannelForVideo()
          : widget.channelName,
      token: widget.token,
      isBroadcaster: widget.isBroadcaster,
      arguments: args,
      activateImmediately: false,
    );
    Get.offAll(() => BottomnavView());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      liveController.activateMinimizedVideoLiveRenderer();
    });
    Fluttertoast.showToast(msg: ('Live minimized').appTr);
  }

  Future<void> _leaveHostVideoRoomOnlyKeepLive() async {
    if (_isLiveExiting) return;
    _isLiveExiting = true;
    _isHostLeavingRoomOnly = true;
    _isLiveMinimized = false;
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    debugPrint(
      'ROOM_EXIT_REQUESTED => user=$userId source=host_room_exit_confirmed',
    );

    try {
      /// Host room theke ber hobe, but backend live active/list card thakbe.
      /// tryToRemoveLivestream / liveEndTimeCase call korbo na.
      try {
        await _agoraService.engine?.muteLocalAudioStream(true);
        await _agoraService.engine?.muteLocalVideoStream(true);
        await _agoraService.leaveChannel();
      } catch (e) {
        print('⚠️ Video host leave channel ignored: $e');
      }

      liveController.isBroadcaster.value = false;
      liveController.stopPingUpdate();
      liveController.stopLivePresenceHeartbeat();

      Get.offAll(() => BottomnavView());
      print('✅ Host left video room only, live kept active in list');
    } catch (e) {
      print('❌ Host video leave room only error: $e');
      Fluttertoast.showToast(msg: ('Exit failed').appTr);
    } finally {
      Future.delayed(const Duration(milliseconds: 700), () {
        _isLiveExiting = false;
      });
    }
  }

  Future<void> _endVideoLiveNow() async {
    if (_isLiveExiting) return;
    _isLiveExiting = true;
    _isHostLeavingRoomOnly = false;
    _isLiveMinimized = false;
    final int exitingStreamId = _safeStreamId();
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    debugPrint(
      'ROOM_EXIT_REQUESTED => user=$userId source=host_live_end_confirmed',
    );

    try {
      liveController.stopLivePresenceHeartbeat();
      await liveController.tryToRemoveLivestream(
        streamId:
        streamInfo['id'] ??
            streamData?['id'] ??
            liveController.streamId.value,
      );
      await _agoraService.leaveChannel();
    } catch (e) {
      print('❌ End video live error: $e');
      Fluttertoast.showToast(msg: ('End live failed').appTr);
    } finally {
      _videoExitCleanupStarted = true;
      final engine = _agoraService.engine;
      final handler = _agoraEventHandler;
      _agoraEventHandler = null;
      if (engine != null && handler != null) {
        try {
          engine.unregisterEventHandler(handler);
        } catch (_) {}
      }
      try {
        await engine?.muteAllRemoteAudioStreams(true);
        await engine?.muteLocalAudioStream(true);
        await engine?.muteLocalVideoStream(true);
        await _agoraService.stopPreview();
      } catch (e) {
        debugPrint('Host video media stop ignored safely: $e');
      }
      try {
        await _agoraService.leaveChannel();
      } catch (e) {
        debugPrint('Host video Agora leave ignored safely: $e');
      }
      await websocketController.leaveVideoRoomState(
        livestreamId: exitingStreamId,
      );
      liveController.clearMinimizedVideoLiveSession();
      liveController.clearViewerLocal();
      liveController.viewerList.clear();
      liveController.liveViewerList.clear();
      liveController.giftList.clear();
      liveController.giftHistory.clear();
      liveController.totalGiftCoins.value = 0;
      if (liveController.streamId.value == exitingStreamId) {
        liveController.streamId.value = 0;
      }
    }
  }

  Future<void> _showVideoLiveCloseOptions() async {
    if (_isLiveExiting || _isLiveMinimized || !mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(('Video Live').appTr),
        content: Text(
          ('Keep keeps the live running in a floating window. Exit closes the live.')
              .appTr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('keep'),
            child: Text(('Keep').appTr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('exit'),
            child: Text(
              ('Exit').appTr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'keep') {
      await _minimizeVideoLiveRoom();
    } else if (action == 'exit') {
      if (widget.isBroadcaster) {
        await _endVideoLiveNow();
      } else {
        await _leaveAudienceVideoBroadcast();
        if (mounted) Get.back();
      }
    }
  }

  void _setupRedPacketCallbacks() {
    websocketController.setRedPacketCallbacks(
      onReceived: (redPacketData) {
        print('🧧 Red packet received in PopularLiveView: $redPacketData');
        // Red packet animation will be shown automatically via Obx
      },
      onCollected: (collectionData) {
        print('🧧 Red packet collected in PopularLiveView: $collectionData');
        // Update balance or show success message
        Get.snackbar(
          ('🧧 Red Packet Collected!').appTr,
          ('You received ${collectionData["amount"]} coins').appTr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      },
    );
  }

  //for live stream end
  @override
  Widget build(BuildContext context) {
    // ✅ KEEP SYSTEM UI: Keep bottom navigation visible, UI starts above it
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return WillPopScope(
      onWillPop: () async {
        await _showVideoLiveCloseOptions();
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: true,
          child: broadcasterData.isEmpty
              ? Stack(
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: SafeLiveBackgroundImage(
                  imageUrl: _popularBackgroundImageUrl(),
                  fit: BoxFit.cover,
                  height: kHeight,
                  width: kWeight,
                  memCacheWidth: 720,
                  memCacheHeight: 1280,
                  maxWidthDiskCache: 1080,
                  maxHeightDiskCache: 1920,
                ),
              ),
              // Image.asset(
              //   'assets/audio_live/1136.jpg',
              //   fit: BoxFit.cover,
              //   height: kHeight,
              //   width: kWeight,
              // ),
              // SpinKitChasingDots(size: 40, color: kPrimaryColor),
            ],
          )
              : Container(
            child: Stack(
              children: [
                // ✅ PK running হলে background camera hide করে premium gradient দেখাবো.
                // ✅ Normal popular live হলে old camera/background exactly same থাকবে.
                Obx(() {
                  if (!liveController.pkIsRunning.value) {
                    return const SizedBox.shrink();
                  }
                  return _premiumPkGradientBackground();
                }),

                Obx(() {
                  if (liveController.pkIsRunning.value) {
                    return const SizedBox.shrink();
                  }
                  return _broadcastView();
                }),

                Obx(() {
                  if (liveController.pkIsRunning.value) {
                    return const SizedBox.shrink();
                  }
                  // ✅ Normal popular/video live camera must stay clear.
                  // আগে এখানে black opacity 0.4 ছিল, তাই camera halka black/dark দেখাচ্ছিল।
                  // PK overlay untouched আছে; শুধু normal camera overlay remove করা হলো।
                  return const SizedBox.shrink();
                }),

                _pkAgoraSyncWatcher(),

                /// ✅ Video PK request button + real Agora PK split overlay.
                if (widget.isBroadcaster)
                  Positioned(
                    top: kHeight * 0.14,
                    right: 12,
                    child: Obx(() {
                      if (liveController.pkIsRunning.value)
                        return const SizedBox.shrink();
                      return PkRequestButton(
                        currentLivestreamId: _safeStreamId(),
                        currentHostId:
                        authController.userProfile.value.user?.id
                            ?.toInt() ??
                            0,
                      );
                    }),
                  ),

                Positioned(
                  top: kHeight * 0.12,
                  left: 0,
                  right: 0,
                  child: Obx(() {
                    if (!liveController.pkIsRunning.value)
                      return const SizedBox.shrink();
                    return _buildRealPkVideoOverlay();
                  }),
                ),

                _buildPkStartIntroOverlay(),
                _buildPkBigCountdownOverlay(),
                _buildPkResultPreviewOverlay(),

                RocketLaunchOverlay(livestreamId: _safeStreamId()),

                /// Persistent full-screen gift layer. Keeping one widget
                /// mounted prevents repeated same-URL SVGA gifts from losing
                /// their onFinished callback or cutting the FIFO queue.
                _PopularGiftOverlayHost(controller: websocketController),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  left: _uiOffset,
                  right: -_uiOffset,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            SizedBox(height: kHeight * 0.018),
                            //Live view Part one start
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  //fast row start
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      // ==== Left fixed Stack ====
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Main Container (Background + Info + Follow Button)
                                          Container(
                                            margin: EdgeInsets.only(
                                              left: Get.width * 0.02,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(
                                                20,
                                              ),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(0xffe85c7d),
                                                  Color(0xfffdcdfb),
                                                  Color(0xff15bccd),
                                                ],
                                              ),
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.only(
                                                right: Get.width * 0.02,
                                              ),
                                              margin: EdgeInsets.all(
                                                Get.width * 0.005,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                BorderRadius.circular(
                                                  15,
                                                ),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xff650256),
                                                    Color(0xff020947),
                                                  ],
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width:
                                                    Get.width * 0.11,
                                                  ), // profile এর জায়গা
                                                  Column(
                                                    spacing: 2,
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                    children: [
                                                      _safeUserMap(
                                                        broadcasterData,
                                                      ).isNotEmpty
                                                          ? Text(
                                                        (() {
                                                          final name =
                                                              _safeUserMap(
                                                                broadcasterData,
                                                              )['name'] ??
                                                                  '';
                                                          // ৬ অক্ষরের বেশি হলে শেষে ... দেখাবে
                                                          return name.length >
                                                              8
                                                              ? '${name.substring(0, 8)}...'
                                                              : name;
                                                        })(),
                                                        style: GoogleFonts.poppins(
                                                          color: Colors
                                                              .white,
                                                          fontSize:
                                                          (Get.height *
                                                              0.013)
                                                              .clamp(
                                                            9.0,
                                                            13.0,
                                                          ),
                                                          fontWeight:
                                                          FontWeight
                                                              .w500,
                                                        ),
                                                      )
                                                          : const SizedBox(),
                                                      (_safeUserMap(
                                                        broadcasterData,
                                                      )['user_id'] !=
                                                          null)
                                                          ? Text(
                                                        ('Uid : ${_safeUserMap(broadcasterData)['user_id']}')
                                                            .appTr,
                                                        style: GoogleFonts.poppins(
                                                          color: Colors
                                                              .white,
                                                          fontSize:
                                                          (Get.height *
                                                              0.012)
                                                              .clamp(
                                                            9.0,
                                                            14.0,
                                                          ),
                                                          fontWeight:
                                                          FontWeight
                                                              .w500,
                                                        ),
                                                      )
                                                          : const SizedBox(),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    width:
                                                    Get.width * 0.015,
                                                  ),

                                                  Obx(() {
                                                    if (_safeUserId(
                                                      broadcasterData,
                                                    ) ==
                                                        authController
                                                            .userProfile
                                                            .value
                                                            .user
                                                            ?.id) {
                                                      return const SizedBox();
                                                    }

                                                    return AnimatedSwitcher(
                                                      duration:
                                                      const Duration(
                                                        milliseconds:
                                                        300,
                                                      ),
                                                      child:
                                                      momentsController
                                                          .isFollowing1
                                                          .value
                                                          ? Container()
                                                          : InkWell(
                                                        key: const ValueKey(
                                                          'follow',
                                                        ),
                                                        onTap: () {
                                                          momentsController.followCreate(
                                                            userId:
                                                            '${_safeUserId(broadcasterData)}',
                                                          );
                                                        },
                                                        child: Container(
                                                          padding: EdgeInsets.symmetric(
                                                            vertical:
                                                            Get.height *
                                                                0.007,
                                                            horizontal:
                                                            Get.width *
                                                                0.03,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                            BorderRadius.circular(
                                                              30,
                                                            ),
                                                            gradient: const LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xfffdcdfb,
                                                                ),
                                                                Color(
                                                                  0xff15bccd,
                                                                ),
                                                              ],
                                                              begin:
                                                              Alignment.topCenter,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            ('Follow')
                                                                .appTr,
                                                            style: GoogleFonts.lato(
                                                              fontWeight:
                                                              FontWeight.w600,
                                                              fontSize:
                                                              (Get.height *
                                                                  0.006)
                                                                  .clamp(
                                                                9.0,
                                                                14.0,
                                                              ),
                                                              color:
                                                              Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Profile + Fame Overlay
                                          Positioned(
                                            left: -kWeight * 0.048,
                                            top: -Get.height * 0.03,
                                            child: GestureDetector(
                                              onTap: () {
                                                homeController.liveVisitProfile(
                                                  userId:
                                                  '${_safeUserId(broadcasterData)}',
                                                  seatData:
                                                  websocketController
                                                      .liveCallList
                                                      .isNotEmpty
                                                      ? websocketController
                                                      .liveCallList
                                                      .first
                                                      : broadcasterData,
                                                );
                                              },
                                              child: Obx(() {
                                                double size =
                                                    Get.height * 0.055;
                                                final user = _safeUserMap(
                                                  broadcasterData,
                                                );
                                                final frameData =
                                                user['asset_purchase_history'];
                                                // Safe convert
                                                final agencyIdRaw =
                                                user['agencyId'];
                                                final int agencyId =
                                                    int.tryParse(
                                                      agencyIdRaw
                                                          ?.toString() ??
                                                          '0',
                                                    ) ??
                                                        0;

                                                return SizedBox(
                                                  height: kHeight * 0.1,
                                                  width: kHeight * 0.11,
                                                  child: Stack(
                                                    alignment:
                                                    Alignment.center,
                                                    children: [
                                                      if (_isUserSpeaking(
                                                        user['id'],
                                                      ) &&
                                                          !_isUserMuted(
                                                            user['id'],
                                                          ))
                                                        SpeakingWave(
                                                          size:
                                                          size * 0.92,
                                                        ),

                                                      // ---------------- PROFILE IMAGE ----------------
                                                      ClipOval(
                                                        child: CachedNetworkImage(
                                                          imageUrl:
                                                          ImageHelper.getImageUrl(
                                                            "${user['profile_image']}",
                                                          ),
                                                          fit: BoxFit
                                                              .cover,
                                                          height:
                                                          size * 0.7,
                                                          width:
                                                          size * 0.7,
                                                        ),
                                                      ),

                                                      // ---------------- AGENCY FRAME (if agencyId > 0) ----------------
                                                      if (agencyId > 0)
                                                        SVGAEasyPlayer(
                                                          key: const ValueKey(
                                                            'video-host-agency-frame',
                                                          ),
                                                          assetsName:
                                                          'assets/svga/Frame/Agency frame.svga',
                                                          fit: BoxFit
                                                              .cover,
                                                        )
                                                      // ---------------- NORMAL FRAME (if no agency frame) --------------
                                                      else if (frameData !=
                                                          null &&
                                                          frameData['asset'] !=
                                                              null &&
                                                          frameData['asset']['asset'] !=
                                                              null)
                                                      // Check if the asset path ends with .svga
                                                        (frameData['asset']['asset']
                                                            .toString()
                                                            .endsWith(
                                                          '.svga',
                                                        ))
                                                            ? SizedBox(
                                                          height:
                                                          kHeight *
                                                              0.055,
                                                          width:
                                                          kHeight *
                                                              0.055,
                                                          child: SVGAEasyPlayer(
                                                            key:
                                                            ValueKey<
                                                                String
                                                            >(
                                                              'video-host-frame-${frameData['asset']['asset']}',
                                                            ),
                                                            resUrl:
                                                            '$kDomainUrl/${frameData['asset']['asset']}',
                                                            fit: BoxFit
                                                                .cover,
                                                          ),
                                                        )
                                                            : CachedNetworkImage(
                                                          imageUrl:
                                                          "$kDomainUrl/${frameData['asset']['asset']}",
                                                          height:
                                                          kHeight *
                                                              0.055,
                                                          width:
                                                          kHeight *
                                                              0.055,
                                                          fit: BoxFit
                                                              .cover,
                                                          placeholder:
                                                              (
                                                              context,
                                                              url,
                                                              ) => Container(
                                                            height:
                                                            kHeight *
                                                                0.12,
                                                            width:
                                                            kHeight *
                                                                0.12,
                                                            decoration: BoxDecoration(
                                                              color: kAppColor.withOpacity(
                                                                .02,
                                                              ),
                                                              borderRadius: BorderRadius.circular(
                                                                12,
                                                              ),
                                                            ),
                                                          ),
                                                          errorWidget:
                                                              (
                                                              context,
                                                              url,
                                                              error,
                                                              ) => Container(
                                                            height:
                                                            kHeight *
                                                                0.12,
                                                            width:
                                                            kHeight *
                                                                0.12,
                                                            decoration: BoxDecoration(
                                                              color: Colors.transparent,
                                                              borderRadius: BorderRadius.circular(
                                                                12,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons.broken_image,
                                                              size: 40,
                                                              color: kAppColor.withOpacity(
                                                                .2,
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      // ---------------- NOTHING (no frame) ----------------
                                                      else
                                                        SizedBox(
                                                          height:
                                                          kHeight *
                                                              0.03,
                                                          width:
                                                          kHeight *
                                                              0.03,
                                                        ),

                                                      if (_isUserMuted(
                                                        user['id'],
                                                      ))
                                                        Positioned(
                                                          right:
                                                          kHeight *
                                                              0.018,
                                                          bottom:
                                                          kHeight *
                                                              0.020,
                                                          child: _SmallMuteBadge(
                                                            fontSize:
                                                            kHeight *
                                                                0.007,
                                                            iconSize:
                                                            kHeight *
                                                                0.008,
                                                            compact: true,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // SizedBox(
                                      //   width: kWeight * 0.004,
                                      // ),
                                      // InkWell(
                                      //   onTap: () {
                                      //     final coming = true;
                                      //     if (coming) {
                                      //       Fluttertoast.showToast(
                                      //         msg: "Coming Soon!",
                                      //         toastLength:
                                      //         Toast.LENGTH_SHORT,
                                      //         // or LENGTH_LONG
                                      //         gravity: ToastGravity.BOTTOM,
                                      //         // where the toast will appear
                                      //         backgroundColor: kAppColor,
                                      //         textColor: Colors.white,
                                      //         fontSize: 16.0,
                                      //       );
                                      //     }
                                      //   },
                                      //   child: SizedBox(
                                      //     height: kHeight * 0.045,
                                      //     width: kHeight * 0.045,
                                      //     child: Stack(
                                      //       alignment: Alignment.center,
                                      //       children: [
                                      //         // ---------------- PROFILE IMAGE ----------------
                                      //         ClipRRect(
                                      //           borderRadius:
                                      //           BorderRadius.circular(
                                      //               100),
                                      //           child: Image.asset(
                                      //             'assets/flaticons/boy.png',
                                      //             height: kHeight * 0.03,
                                      //             width: kHeight * 0.03,
                                      //             fit: BoxFit.cover,
                                      //           ),
                                      //         ),
                                      //
                                      //         Image.asset(
                                      //           "assets/audio_live/gradian.png",
                                      //           height: kHeight * 0.06,
                                      //           width: kHeight * 0.06,
                                      //           fit: BoxFit.cover,
                                      //         ),
                                      //
                                      //         // ---------------- NOTHING (no frame) ----------------
                                      //       ],
                                      //     ),
                                      //   ),
                                      // ),
                                      SizedBox(width: kWeight * 0.004),
                                      // ==== Right viewers + close ==== (Flexible so it won’t overflow)
                                      Flexible(
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                          children: [
                                            SizedBox(
                                              width: Get.width * 0.22,
                                              height: Get.height * 0.04,
                                              child: Obx(() {
                                                // Filter list একবারেই বের করো
                                                final filteredList =
                                                livestreamController
                                                    .liveViewerList
                                                    .where(
                                                      (viewer) =>
                                                  _safeUserId(
                                                    viewer,
                                                  ) !=
                                                      _safeUserId(
                                                        broadcasterData,
                                                      ),
                                                )
                                                    .toList();

                                                if (filteredList
                                                    .isEmpty) {
                                                  return const SizedBox(); // কিছু না দেখানোর জন্য (empty state)
                                                }

                                                return ListView.builder(
                                                  scrollDirection:
                                                  Axis.horizontal,
                                                  itemCount:
                                                  filteredList.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final data =
                                                    filteredList[index];
                                                    return LiveProfile(
                                                      data: data,
                                                    );
                                                  },
                                                );
                                              }),
                                            ),
                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    /// *********** All Viewer List Bottom sheet ***********
                                                    final filteredList =
                                                    livestreamController
                                                        .liveViewerList
                                                        .where(
                                                          (viewer) =>
                                                      _safeUserId(
                                                        viewer,
                                                      ) !=
                                                          _safeUserId(
                                                            broadcasterData,
                                                          ),
                                                    )
                                                        .toList();

                                                    Get.bottomSheet(
                                                      LiveViewerList(
                                                        filteredList:
                                                        filteredList,
                                                      ),
                                                      isScrollControlled:
                                                      true,
                                                    );
                                                  },
                                                  child: Container(
                                                    margin:
                                                    EdgeInsets.only(
                                                      right:
                                                      Get.width *
                                                          0.01,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        20,
                                                      ),
                                                      gradient:
                                                      LinearGradient(
                                                        colors: [
                                                          Color(
                                                            0xffe85c7d,
                                                          ),
                                                          Color(
                                                            0xfffdcdfb,
                                                          ),
                                                          Color(
                                                            0xff15bccd,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    child: Container(
                                                      margin:
                                                      EdgeInsets.all(
                                                        1,
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          100,
                                                        ),
                                                        child: Container(
                                                          height:
                                                          Get.height *
                                                              0.035,
                                                          width:
                                                          Get.height *
                                                              0.035,
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                            BorderRadius.circular(
                                                              15,
                                                            ),
                                                            gradient: LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xff650256,
                                                                ),
                                                                Color(
                                                                  0xff020947,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          child: Center(
                                                            child: Obx(() {
                                                              final filteredCount = livestreamController
                                                                  .liveViewerList
                                                                  .where(
                                                                    (
                                                                    viewer,
                                                                    ) =>
                                                                _safeUserId(
                                                                  viewer,
                                                                ) !=
                                                                    _safeUserId(
                                                                      broadcasterData,
                                                                    ),
                                                              )
                                                                  .length;
                                                              return Text(
                                                                '$filteredCount+',
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                  FontWeight.w500,
                                                                ),
                                                              );
                                                            }),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                (broadcasterData !=
                                                    null &&
                                                    widget
                                                        .isBroadcaster)
                                                    ? GestureDetector(
                                                  onTap: () async {
                                                    await _showVideoLiveCloseOptions();
                                                  },
                                                  child: Container(
                                                    margin:
                                                    EdgeInsets.only(
                                                      right: 2,
                                                      left: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        20,
                                                      ),
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Color(
                                                            0xffe85c7d,
                                                          ),
                                                          Color(
                                                            0xfffdcdfb,
                                                          ),
                                                          Color(
                                                            0xff15bccd,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    child: Container(
                                                      margin:
                                                      EdgeInsets.all(
                                                        1,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            Color(
                                                              0xff650256,
                                                            ),
                                                            Color(
                                                              0xff020947,
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      height:
                                                      Get.height *
                                                          0.035,
                                                      width:
                                                      Get.height *
                                                          0.035,
                                                      child: Icon(
                                                        Icons
                                                            .close_rounded,
                                                        color: Colors
                                                            .white,
                                                        size:
                                                        Get.height *
                                                            0.02,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                    : IconButton(
                                                  style: IconButton.styleFrom(
                                                    backgroundColor:
                                                    Colors
                                                        .grey[100],
                                                    padding:
                                                    EdgeInsets.all(
                                                      4,
                                                    ),
                                                    // ভিতরের space ছোট করা
                                                    minimumSize: Size(
                                                      28,
                                                      28,
                                                    ), // button এর overall size ছোট করা
                                                  ),
                                                  onPressed: () async {
                                                    if (mounted) {
                                                      await Navigator.of(
                                                        context,
                                                      ).maybePop();
                                                    }
                                                  },
                                                  icon: Icon(
                                                    Icons.close,
                                                    color:
                                                    kAppColor,
                                                    size:
                                                    18, // icon টার সাইজ ছোট
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: kWeight * 0.01,
                                                ),
                                              ],
                                            ),

                                            ///------------- viewer list show

                                            // Nothing will be shown if broadcasterData is null
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: kHeight * 0.006),

                                  ///---------- timer -------------
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8.0,
                                      top: 5,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Get.to(
                                              Profileconribution(),
                                              transition:
                                              Transition.rightToLeft,
                                            );
                                          },
                                          child: Obx(() {
                                            return TaskLiveProfile(
                                              text: (() {
                                                final int coins =
                                                _safeCurrentGiftCoins();
                                                return _formatShortCoins(
                                                  coins,
                                                );
                                              })(),
                                              seccondtext: 'Receive: ',
                                            );
                                          }),
                                        ),
                                        _safeUserId(broadcasterData) ==
                                            authController
                                                .userProfile
                                                .value
                                                .user!
                                                .id
                                            ? Container(
                                          padding:
                                          EdgeInsets.symmetric(
                                            horizontal:
                                            kWeight * 0.03,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(
                                              15,
                                            ),
                                            gradient:
                                            LinearGradient(
                                              colors: [
                                                Color(
                                                  0xff650256,
                                                ),
                                                Color(
                                                  0xff020947,
                                                ),
                                              ],
                                            ),
                                          ),
                                          child: Obx(
                                                () => Castontext(
                                              fontSize:
                                              kHeight * 0.015,
                                              textColor:
                                              liveController
                                                  .isLive
                                                  .value
                                                  ? const Color(
                                                0xffffffff,
                                              ) // Live active = green
                                                  : const Color(
                                                0xff808080,
                                              ), // Inactive = gray
                                              text:
                                              liveController
                                                  .pkIsRunning
                                                  .value
                                                  ? liveController
                                                  .pkFormattedRemainingTime
                                                  : liveController
                                                  .formattedTime,
                                            ),
                                          ),
                                        )
                                            : const SizedBox.shrink(),
                                        GestureDetector(
                                          onTap: () {
                                            // Get.to(RankingView(),
                                            //     transition: Transition.rightToLeft);
                                          },
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              left: 5,
                                              right: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(
                                                20,
                                              ),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(0xffe85c7d),
                                                  Color(0xfffdcdfb),
                                                  Color(0xff15bccd),
                                                ],
                                              ),
                                            ),
                                            child: Container(
                                              margin: EdgeInsets.all(1),
                                              padding:
                                              EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                BorderRadius.circular(
                                                  15,
                                                ),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xff650256),
                                                    Color(0xff020947),
                                                  ],
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    ('Current:').appTr,
                                                    style:
                                                    GoogleFonts.roboto(
                                                      color: Colors
                                                          .white,
                                                      fontWeight:
                                                      FontWeight
                                                          .w400,
                                                      fontSize:
                                                      kHeight *
                                                          0.012,
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Obx(() {
                                                    final int coins =
                                                    _safeCurrentGiftCoins();
                                                    final String
                                                    displayText =
                                                    _formatShortCoins(
                                                      coins,
                                                    );

                                                    // 🔹 UI return
                                                    return Text(
                                                      displayText,
                                                      style: TextStyle(
                                                        color:
                                                        Colors.white,
                                                        fontWeight:
                                                        FontWeight
                                                            .bold,
                                                        fontSize:
                                                        kHeight *
                                                            0.014,
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ///----- noble part ----------
                                  // InkWell(
                                  //   onTap: () {},
                                  //   child: Container(
                                  //       width: kWeight * 0.25,
                                  //       margin: EdgeInsets.symmetric(
                                  //           vertical: 10, horizontal: 10),
                                  //       padding: EdgeInsets.symmetric(
                                  //           vertical: 3, horizontal: 8),
                                  //       decoration: BoxDecoration(
                                  //         borderRadius:
                                  //         BorderRadius.circular(30),
                                  //         gradient: LinearGradient(colors: [
                                  //           Color(0xff8c61e1),
                                  //           Color(0xff5815dc)
                                  //         ]),
                                  //       ),
                                  //       child: Row(
                                  //         children: [
                                  //           Image(
                                  //             image: AssetImage(
                                  //                 'assets/flaticons/crown.png'),
                                  //             height: kHeight * 0.03,
                                  //           ),
                                  //           Text(
                                  //             (' Noble').appTr,
                                  //             style: GoogleFonts.poppins(
                                  //                 fontWeight:
                                  //                 FontWeight.w600,
                                  //                 color: Colors.white,
                                  //                 fontSize:
                                  //                 kWeight * 0.029),
                                  //           ),
                                  //         ],
                                  //       )),
                                  // ),
                                ],
                              ),
                            ),

                            ///---------------- Call part ----------
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  right: 9,
                                ),
                                child: Row(
                                  children: [
                                    LiveCommentsSection(
                                      broadcasterData: broadcasterData,
                                    ),

                                    //container  text end
                                    SizedBox(width: 5),
                                    Expanded(
                                      flex: 2,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: kHeight * 0.32,
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                right: kWeight * 0.03,
                                              ),
                                              child:
                                              _safeUserId(
                                                broadcasterData,
                                              ) ==
                                                  authController
                                                      .userProfile
                                                      .value
                                                      .user!
                                                      .id
                                                  ? Container()
                                                  : Align(
                                                alignment: Alignment
                                                    .bottomRight,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    final bool
                                                    pkRunningForAudienceCall =
                                                        liveController
                                                            .pkIsRunning
                                                            .value ||
                                                            liveController
                                                                .currentPkId
                                                                .value >
                                                                0;
                                                    if (pkRunningForAudienceCall &&
                                                        !widget
                                                            .isBroadcaster) {
                                                      Fluttertoast.showToast(
                                                        msg: ('PK is running. Call option is disabled during PK.')
                                                            .appTr,
                                                        toastLength:
                                                        Toast
                                                            .LENGTH_SHORT,
                                                        gravity:
                                                        ToastGravity
                                                            .BOTTOM,
                                                        backgroundColor:
                                                        Colors
                                                            .black87,
                                                        textColor:
                                                        Colors
                                                            .white,
                                                        fontSize:
                                                        13.0,
                                                      );
                                                      return;
                                                    }

                                                    websocketController
                                                        .tryToConnectToCallListWs();
                                                    if (livestreamController
                                                        .isBroadcaster
                                                        .value) {
                                                      // ✅ Broadcaster হলে BottomSheet
                                                    } else {
                                                      Get.bottomSheet(
                                                        SafeArea(
                                                          top:
                                                          false,
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: const BorderRadius.only(
                                                                topLeft: Radius.circular(
                                                                  32,
                                                                ),
                                                                topRight: Radius.circular(
                                                                  32,
                                                                ),
                                                              ),
                                                              color:
                                                              Colors.white,
                                                              border: Border.all(
                                                                color: const Color(
                                                                  0xFFE8E1E4,
                                                                ),
                                                              ),
                                                              boxShadow: const [
                                                                BoxShadow(
                                                                  color: Color(
                                                                    0x26000000,
                                                                  ),
                                                                  blurRadius: 18,
                                                                  offset: Offset(
                                                                    0,
                                                                    -4,
                                                                  ),
                                                                ),
                                                              ],
                                                              gradient: LinearGradient(
                                                                begin:
                                                                Alignment.topLeft,
                                                                end:
                                                                Alignment.bottomRight,
                                                                colors: [
                                                                  Colors.white,
                                                                  Colors.white,
                                                                ],
                                                              ),
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius: const BorderRadius.only(
                                                                topLeft: Radius.circular(
                                                                  32,
                                                                ),
                                                                topRight: Radius.circular(
                                                                  32,
                                                                ),
                                                              ),
                                                              child: BackdropFilter(
                                                                filter: ImageFilter.blur(
                                                                  sigmaX: 24,
                                                                  sigmaY: 24,
                                                                ),
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const SizedBox(
                                                                      height: 16,
                                                                    ),

                                                                    // Handle bar
                                                                    Container(
                                                                      width: 40,
                                                                      height: 4,
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.grey.shade300,
                                                                        borderRadius: BorderRadius.circular(
                                                                          2,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 20,
                                                                    ),

                                                                    // Premium badge
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal: 14,
                                                                        vertical: 5,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(
                                                                          0xFFFFF6F8,
                                                                        ),
                                                                        borderRadius: BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                        border: Border.all(
                                                                          color: const Color(
                                                                            0xFFF1DDE3,
                                                                          ),
                                                                          width: 1,
                                                                        ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.star_rounded,
                                                                            color: Color(
                                                                              0xFFFFD700,
                                                                            ),
                                                                            size: 13,
                                                                          ),
                                                                          const SizedBox(
                                                                            width: 5,
                                                                          ),
                                                                          Text(
                                                                            ("Premium Live Call").appTr,
                                                                            style: GoogleFonts.poppins(
                                                                              fontSize: 11,
                                                                              color: const Color(
                                                                                0xFF4B4045,
                                                                              ),
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 14,
                                                                    ),

                                                                    // Title
                                                                    Text(
                                                                      ("Join Live Stream").appTr,
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 16,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: const Color(
                                                                          0xFF241D20,
                                                                        ),
                                                                        letterSpacing: 0.3,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),

                                                                    // Subtitle
                                                                    Text(
                                                                      ("Choose your preferred call type").appTr,
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 12,
                                                                        color: const Color(
                                                                          0xFF746A6F,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 20,
                                                                    ),

                                                                    // Divider
                                                                    Divider(
                                                                      color: const Color(
                                                                        0xFFE8E1E4,
                                                                      ),
                                                                      thickness: 0.5,
                                                                      height: 1,
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 24,
                                                                    ),

                                                                    // Buttons
                                                                    Padding(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal: 20,
                                                                      ),
                                                                      child: Row(
                                                                        children: [
                                                                          // Video Call Button
                                                                          Expanded(
                                                                            child: _GlassCallButton(
                                                                              label: ("Video Call").appTr,
                                                                              icon: Icons.videocam_rounded,
                                                                              gradientColors: const [
                                                                                Color(
                                                                                  0xFFFF5F6D,
                                                                                ),
                                                                                Color(
                                                                                  0xFFFF8C42,
                                                                                ),
                                                                                Color(
                                                                                  0xFFFFC371,
                                                                                ),
                                                                              ],
                                                                              shadowColor: const Color(
                                                                                0xFFFF5F6D,
                                                                              ),
                                                                              onTap: () {
                                                                                final int safeTotalSeats = _safeInt(
                                                                                  broadcasterData['seat_count'] ??
                                                                                      streamInfo['seat_count'] ??
                                                                                      liveController.seatCount.value,
                                                                                  fallback:
                                                                                  liveController.seatCount.value >
                                                                                      0
                                                                                      ? liveController.seatCount.value
                                                                                      : 5,
                                                                                );

                                                                                livestreamController.tryToCallLivestream(
                                                                                  streamId: _safeStreamId(),
                                                                                  callerId: authController.userProfile.value.user!.id!.toInt(),
                                                                                  callType: 'video',
                                                                                  totalSeats: safeTotalSeats,
                                                                                );
                                                                                Get.back();
                                                                              },
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width: 12,
                                                                          ),

                                                                          // Voice Call Button
                                                                          Expanded(
                                                                            child: _GlassCallButton(
                                                                              label: ("Audio Call").appTr,
                                                                              icon: Icons.mic_rounded,
                                                                              gradientColors: const [
                                                                                Color(
                                                                                  0xFF667EEA,
                                                                                ),
                                                                                Color(
                                                                                  0xFF7F5FC5,
                                                                                ),
                                                                                Color(
                                                                                  0xFF764BA2,
                                                                                ),
                                                                              ],
                                                                              shadowColor: const Color(
                                                                                0xFF667EEA,
                                                                              ),
                                                                              onTap: () {
                                                                                final int safeTotalSeats = _safeInt(
                                                                                  broadcasterData['seat_count'] ??
                                                                                      streamInfo['seat_count'] ??
                                                                                      liveController.seatCount.value,
                                                                                  fallback:
                                                                                  liveController.seatCount.value >
                                                                                      0
                                                                                      ? liveController.seatCount.value
                                                                                      : 9,
                                                                                );

                                                                                livestreamController.tryToCallLivestream(
                                                                                  streamId: _safeStreamId(),
                                                                                  callerId: authController.userProfile.value.user!.id!.toInt(),
                                                                                  callType: 'audio',
                                                                                  totalSeats: safeTotalSeats,
                                                                                );
                                                                                Get.back();
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height:
                                                                      kHeight *
                                                                          0.05,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        backgroundColor:
                                                        Colors
                                                            .white,
                                                        isScrollControlled:
                                                        true,
                                                      );
                                                    }
                                                  },
                                                  child: LiveViewsecond_Image(
                                                    image:
                                                    'assets/flaticons/link (1).png',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: kHeight * 0.06),
                          ],
                        ),

                        //Pk
                        Obx(() {
                          if (!livestreamController.showPkView.value)
                            return const SizedBox();
                          return Positioned(
                            top: Get.height * 0.15,
                            left: 0,
                            right: 0,
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        // 🔵 Left side (Player A)
                                        Container(
                                          width: Get.width * 0.5,
                                          height: Get.height * 0.15,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            const BorderRadius.only(
                                              topLeft:
                                              Radius.circular(20),
                                            ),
                                            gradient:
                                            const LinearGradient(
                                              begin:
                                              Alignment.topLeft,
                                              end: Alignment
                                                  .bottomRight,
                                              colors: [
                                                Color(0xff2196F3),
                                                Color(0xff673AB7),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.25),
                                                blurRadius: 10,
                                                offset: const Offset(
                                                  0,
                                                  5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: Get.height * 0.04,
                                              ),
                                              // Player avatar
                                              Container(
                                                padding:
                                                const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 3,
                                                  ),
                                                  gradient:
                                                  const LinearGradient(
                                                    colors: [
                                                      Colors
                                                          .blueAccent,
                                                      Colors
                                                          .purpleAccent,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(
                                                        0.2,
                                                      ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                                    height:
                                                    Get.height * 0.05,
                                                    width:
                                                    Get.height * 0.05,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                ("Md Abdul").appTr,
                                                style:
                                                GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontSize:
                                                  Get.height *
                                                      0.014,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 🔴 Right side (Player B)
                                        Container(
                                          width: Get.width * 0.5,
                                          height: Get.height * 0.15,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            const BorderRadius.only(
                                              topRight:
                                              Radius.circular(20),
                                            ),
                                            gradient:
                                            const LinearGradient(
                                              begin:
                                              Alignment.topLeft,
                                              end: Alignment
                                                  .bottomRight,
                                              colors: [
                                                Color(0xffE91E63),
                                                Color(0xff6A1B9A),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.25),
                                                blurRadius: 10,
                                                offset: const Offset(
                                                  0,
                                                  5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: Get.height * 0.04,
                                              ),
                                              // Player avatar
                                              Container(
                                                padding:
                                                const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 3,
                                                  ),
                                                  gradient:
                                                  const LinearGradient(
                                                    colors: [
                                                      Colors
                                                          .blueAccent,
                                                      Colors
                                                          .purpleAccent,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(
                                                        0.2,
                                                      ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                                    height:
                                                    Get.height * 0.05,
                                                    width:
                                                    Get.height * 0.05,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                ("Md Abdul").appTr,
                                                style:
                                                GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontSize:
                                                  Get.height *
                                                      0.014,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedProgressBar(
                                      controller:
                                      animatedProgressBarController,
                                    ),
                                  ],
                                ),

                                // 🆚 VS text overlay
                                Positioned(
                                  top: 40,
                                  left: 215,
                                  right: 0,
                                  child: Text(
                                    ("VS").appTr,
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: Get.height * 0.08,
                                      color: Colors.white.withOpacity(
                                        0.3,
                                      ),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),

                                // 📊 Bottom bar

                                // ⏱ Timer + Exit
                                Positioned(
                                  top: 5,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(width: 40),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(30),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              ("PK ").appTr,
                                              style: GoogleFonts.poppins(
                                                color:
                                                Colors.yellowAccent,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "05:00",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight:
                                                FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.exit_to_app,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          Get.defaultDialog(
                                            title: ("Exit").appTr,
                                            middleText:
                                            ("Are you sure you want to exit?")
                                                .appTr,
                                            textCancel: ("No").appTr,
                                            textConfirm: ("Yes").appTr,
                                            confirmTextColor:
                                            Colors.white,
                                            onConfirm: () {
                                              Get.back();
                                              livestreamController
                                                  .hidePk();
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        Obx(() {
                          if (!livestreamController.showPkView.value)
                            return const SizedBox();
                          return Positioned(
                            top: Get.height * 0.155,
                            left: 0,
                            right: 0,
                            child: towVsTowPk(
                              animatedProgressBarController:
                              animatedProgressBarController,
                              livestreamController: livestreamController,
                            ),
                          );
                        }),
                        Obx(() {
                          if (!livestreamController.showPkRoom.value)
                            return SizedBox();
                          return Positioned(
                            top: Get.height * 0.155,
                            left: 0,
                            right: 0,
                            child: CustomPartyRoom(
                              livestreamController: livestreamController,
                              animatedProgressBarController:
                              animatedProgressBarController,
                            ),
                          );
                        }),
                        Obx(() {
                          final newUser =
                              websocketController.newJoinedUserData;

                          if (websocketController
                              .newViewersJoinded
                              .value) {
                            final hasEntry =
                                newUser?['user']?['entry_histories']?['asset']?['asset'] !=
                                    null;

                            if (hasEntry) {
                              // ✅ SVGA আছে → onFinished callback দিয়ে hide হবে
                              return Positioned.fill(
                                child: EntryAnimation(
                                  data: newUser,
                                  // onFinished: () {
                                  //   websocketController.newViewersJoinded.value = false;
                                  // },
                                ),
                              );
                            }

                            // ✅ SVGA নেই → slide animation → 3s পরে hide
                            Future.delayed(
                              const Duration(seconds: 3),
                                  () {
                                if (websocketController
                                    .newViewersJoinded
                                    .value) {
                                  websocketController
                                      .newViewersJoinded
                                      .value =
                                  false;
                                }
                              },
                            );

                            return Positioned(
                              left: 12,
                              top: Get.height * 0.5,
                              child: SizedBox(
                                width: Get.width * 0.9,
                                child: EntryAnimation(
                                  data: newUser,
                                  // onFinished: () {
                                  //   websocketController.newViewersJoinded.value = false;
                                  // },
                                ),
                              ),
                            );
                          }

                          return const SizedBox();
                        }),
                        // Red Packet Animation
                        Obx(
                              () =>
                          websocketController
                              .redPacketVisible
                              .value &&
                              websocketController
                                  .currentRedPacket
                                  .value
                                  .isNotEmpty
                              ? Positioned.fill(
                            child: RedPacketAnimation(
                              isVisible: websocketController
                                  .redPacketVisible
                                  .value,
                              onTap: () async {
                                // Collect red packet
                                final redPacket =
                                    websocketController
                                        .currentRedPacket
                                        .value;
                                if (redPacket.isNotEmpty) {
                                  await liveController
                                      .collectRedPacket(
                                    redPacket['id'],
                                  );
                                  websocketController
                                      .hideRedPacket();
                                }
                              },
                            ),
                          )
                              : Container(),
                        ),
                        Obx(
                              () => livestreamController.showMiniScene.value
                              ? Positioned(
                            top: 60,
                            right: 10,
                            child: AnimatedOpacity(
                              opacity:
                              livestreamController
                                  .showMiniScene
                                  .value
                                  ? 1
                                  : 0,
                              duration: const Duration(
                                milliseconds: 300,
                              ),
                              child: Container(
                                width: Get.width * 0.5,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    0.95,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      ("🎁 Mini Scene").appTr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ("This is a small overlay above live.")
                                          .appTr,
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: () {
                                        livestreamController
                                            .showMiniScene
                                            .value =
                                        false;
                                      },
                                      child: Text(("Close").appTr),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isUIVisible)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 60,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _handleDragUpdate,
                      onHorizontalDragEnd: _handleDragEnd,
                      onTap: () {
                        setState(() {
                          _uiOffset = 0;
                          _isUIVisible = true;
                        });
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                ///------------- bottom part -------
                _agoraService.engine != null
                    ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kWeight * 0.0,
                    ),
                    child: Row(
                      children: [
                        // WriteCommentSection takes most of the space
                        Expanded(
                          child: WriteCommentSection(
                            rtcEngine: _agoraService.engine!,
                            streamType: 'popular',
                            broadcasterData: broadcasterData,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : Container(
                  color: Colors
                      .transparent, // Optional: blank red bar if engine null
                  height: 60, // adjust height if needed
                ),
                _agoraService.engine == null
                    ? const Center(
                  child: CircularProgressIndicator(),
                ) // Show loading
                    : Container(),

                //Live view bottom part end
              ],
            ),
          ),
        ),

        // body parameter শেষ
      ),
    );
  }

  bool muted = false, videoDisabled = false, loudSpeaker = false;

  Widget _miniNamePill(dynamic broadcaster) {
    final name = _safeUserName(broadcaster, fallback: '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name != null
            ? name.length > 10
            ? '${name.substring(0, 10)}...'
            : name
            : '',
        style: TextStyle(
          color: Colors.white,
          fontSize: kHeight * 0.011,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _popularBackgroundImageUrl() {
    final Map<String, dynamic> live = _safeMap(streamData?['livestreamdata']);
    final List<dynamic> candidates = <dynamic>[
      live['room_background_image'],
      live['background_image'],
      live['stream_image'],
      streamData?['room_background_image'],
      streamData?['background_image'],
      streamData?['stream_image'],
      broadcasterData['room_background_image'],
      broadcasterData['background_image'],
      broadcasterData['stream_image'],
      _safeUserMap(broadcasterData)['profile_image'],
    ];
    for (final dynamic candidate in candidates) {
      final String raw = candidate?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') continue;
      return ImageHelper.getImageUrl(raw);
    }
    return '';
  }

  String _safeProfileImage(dynamic image) {
    final raw = image?.toString().trim() ?? '';

    if (raw.isEmpty || raw == 'null') {
      return 'https://ui-avatars.com/api/?name=User&background=8A4CF7&color=fff';
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final url = ImageHelper.getImageUrl(raw);
    if (url.trim().isEmpty || url == 'file:///') {
      return 'https://ui-avatars.com/api/?name=User&background=8A4CF7&color=fff';
    }

    return url;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _safeUserMap(dynamic value) {
    final map = _safeMap(value);

    final directUser = map['user'] ?? map['User'];
    if (directUser is Map) {
      return Map<String, dynamic>.from(directUser);
    }

    final callerData =
        map['caller_data'] ?? map['call_data'] ?? map['accepted_caller'];
    if (callerData is Map) {
      final nestedUser = callerData['user'] ?? callerData['User'];
      if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
    }

    final viewerData = map['viewer_data'] ?? map['viewer'];
    if (viewerData is Map) {
      final nestedUser = viewerData['user'] ?? viewerData['User'];
      if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
    }

    return <String, dynamic>{};
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return fallback;
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt() ?? fallback;
  }

  int _safeUserId(dynamic value) {
    final map = _safeMap(value);
    final user = _safeUserMap(value);

    return _safeInt(
      user['id'] ??
          user['user_id'] ??
          map['user_id'] ??
          map['caller_id'] ??
          map['viewer_id'] ??
          map['host_id'] ??
          map['uid'],
    );
  }

  String _safeUserName(dynamic value, {String fallback = 'User'}) {
    final map = _safeMap(value);
    final user = _safeUserMap(value);
    final raw =
    (user['name'] ??
        user['full_name'] ??
        map['name'] ??
        map['caller_name'] ??
        map['display_name'] ??
        fallback)
        .toString()
        .trim();
    return raw.isEmpty || raw == 'null' ? fallback : raw;
  }

  String _safeUserProfile(dynamic value) {
    final map = _safeMap(value);
    final user = _safeUserMap(value);
    return _safeProfileImage(
      user['profile_image'] ??
          user['avatar'] ??
          map['profile_image'] ??
          map['caller_image'] ??
          map['image'],
    );
  }

  bool _hasValidUser(dynamic value) {
    return _safeUserId(value) > 0 || _safeUserMap(value).isNotEmpty;
  }

  int _safeCurrentGiftCoins() {
    final fromWs = _safeInt(websocketController.totalGiftCoins.value);
    if (fromWs > 0) return fromWs;

    final callList = websocketController.liveCallList;
    if (callList.isNotEmpty) {
      final first = _safeMap(callList.first);
      return _safeInt(
        first['earn_coins'] ??
            first['earned_coins'] ??
            first['total_gift_coins'] ??
            first['received_coins'] ??
            first['stream_coins'] ??
            first['gifts_coins'],
      );
    }

    return _safeInt(
      streamInfo['total_gift_coins'] ??
          streamInfo['received_coins'] ??
          streamInfo['stream_coins'] ??
          streamInfo['gifts_coins'],
    );
  }

  String _formatShortCoins(int coins) {
    if (coins >= 1000000) {
      final value = coins / 1000000;
      return value % 1 == 0
          ? '${value.toInt()}M'
          : '${value.toStringAsFixed(1)}M';
    }
    if (coins >= 1000) {
      final value = coins / 1000;
      return value % 1 == 0
          ? '${value.toInt()}k'
          : '${value.toStringAsFixed(1)}k';
    }
    return coins.toString();
  }

  bool _isAcceptedCall(dynamic raw) {
    final call = _safeMap(raw);
    final status = (call['call_status'] ?? call['status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'live' ||
        status == 'on_seat';
  }

  bool _callWantsVideo(dynamic raw) {
    final call = _safeMap(raw);
    final type = (call['call_type'] ?? call['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return type == 'video' || type == 'popular';
  }

  bool _callVideoEnabled(dynamic raw) {
    final call = _safeMap(raw);
    final value = call['video_on'] ?? call['is_video_on'];
    if (value == null) return _callWantsVideo(call);
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;
    final text = value.toString().toLowerCase().trim();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'enabled';
  }

  bool _isActiveVideoCall(dynamic raw) {
    return _isAcceptedCall(raw) && _callWantsVideo(raw);
  }

  bool _uidsAreEquivalent(int first, int second) {
    if (first <= 0 || second <= 0) return false;
    return first == second ||
        first + 100000 == second ||
        second + 100000 == first;
  }

  int _resolvedHostUserId() {
    final streamUser = _safeUserMap(streamInfo);
    final direct = _safeInt(
      streamInfo['user_id'] ??
          streamInfo['host_id'] ??
          streamInfo['broadcaster_id'] ??
          streamInfo['owner_user_id'] ??
          streamUser['id'] ??
          streamUser['user_id'],
    );
    if (direct > 0) return direct;
    return _safeUserId(broadcasterData);
  }

  int _remoteUidForCaller(int callerId) {
    if (callerId <= 0) return 0;
    final mapped = liveController.videoCallerAgoraUidMap[callerId] ?? 0;
    if (mapped > 0 && _joinedRemoteUids.contains(mapped)) return mapped;
    return _joinedRemoteUids.firstWhere(
          (uid) => _uidsAreEquivalent(uid, callerId),
      orElse: () => 0,
    );
  }

  List<Map<String, dynamic>> _acceptedCallersForOverlay() {
    final hostUserId = _resolvedHostUserId();
    final seenUserIds = <int>{};
    final callers = <Map<String, dynamic>>[];

    for (final call in _effectiveVideoCallRows()) {
      if (!_isAcceptedCall(call)) continue;
      final type = (call['call_type'] ?? call['type'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (type != 'audio' && type != 'video' && type != 'popular') continue;

      final userId = _safeUserId(call);
      if (userId <= 0 || userId == hostUserId || !seenUserIds.add(userId)) {
        continue;
      }
      callers.add(call);
      if (callers.length == 4) break;
    }
    return callers;
  }

  Set<int> _activeAcceptedCallerUids() {
    return _effectiveVideoCallRows()
        .where(_isAcceptedCall)
        .map(_safeUserId)
        .where((uid) => uid > 0 && !_offlineRemoteUids.contains(uid))
        .toSet();
  }

  void _syncAcceptedCallerAgoraUidMappings() {
    final List<Map<String, dynamic>> effectiveCalls =
    _effectiveVideoCallRows();
    liveController.syncVideoCallerAgoraMappingsFromCalls(effectiveCalls);
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final acceptedCallerIds = effectiveCalls
        .where(_isActiveVideoCall)
        .map(_safeUserId)
        .where((id) => id > 0 && id != currentUserId)
        .toSet();
    if (acceptedCallerIds.isEmpty || _joinedRemoteUids.isEmpty) return;

    final availableRemoteUids = _joinedRemoteUids.toSet();
    for (final callerId in acceptedCallerIds) {
      final existing = liveController.videoCallerAgoraUidMap[callerId] ?? 0;
      if (existing > 0 && availableRemoteUids.contains(existing)) {
        availableRemoteUids.remove(existing);
        continue;
      }
      final equivalent = availableRemoteUids.firstWhere(
            (uid) =>
        uid == callerId ||
            uid == callerId + 100000 ||
            (callerId >= 100000 && uid == callerId - 100000),
        orElse: () => 0,
      );
      if (equivalent > 0) {
        liveController.mapVideoCallerToAgoraUid(
          callerId: callerId,
          remoteUid: equivalent,
        );
        availableRemoteUids.remove(equivalent);
      }
    }

    final unmappedCallerIds = acceptedCallerIds
        .where(
          (id) =>
      !(liveController.videoCallerAgoraUidMap[id] != null &&
          _joinedRemoteUids.contains(
            liveController.videoCallerAgoraUidMap[id],
          )),
    )
        .toList();
    if (unmappedCallerIds.length == 1 && availableRemoteUids.length == 1) {
      liveController.mapVideoCallerToAgoraUid(
        callerId: unmappedCallerIds.single,
        remoteUid: availableRemoteUids.single,
      );
    }

    final engine = _agoraService.engine;
    if (engine != null) {
      for (final callerId in acceptedCallerIds) {
        final remoteUid = liveController.videoCallerAgoraUidMap[callerId] ?? 0;
        if (remoteUid <= 0) continue;
        unawaited(engine.muteRemoteVideoStream(uid: remoteUid, mute: false));
        unawaited(engine.muteRemoteAudioStream(uid: remoteUid, mute: false));
      }
    }
  }

  void _logVideoCallLayoutReady(int remoteUid) {
    if (!_remoteVideoReadyUids.contains(remoteUid)) return;
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final selfIsAcceptedCaller = _effectiveVideoCallRows().any(
          (call) => _isActiveVideoCall(call) && _safeUserId(call) == currentUserId,
    );
    final callerIsMapped = liveController.videoCallerAgoraUidMap.values
        .contains(remoteUid);
    final layout = widget.isBroadcaster && callerIsMapped
        ? 'host_local_full_remote_pip'
        : (!widget.isBroadcaster && selfIsAcceptedCaller
        ? 'caller_remote_host_full_local_pip'
        : '');
    if (layout.isEmpty) return;
    final key = '$layout:$remoteUid';
    if (_loggedVideoLayoutKeys.add(key)) {
      debugPrint('VIDEO_CALL_LAYOUT_READY => layout=$layout uid=$remoteUid');
    }
  }

  void _reconcileRemoteCallerSubscriptions() {
    if (_videoExitCleanupStarted || !mounted) return;
    _syncAcceptedCallerAgoraUidMappings();
    if (_remoteSubscriptionReconcileFuture != null) return;
    _remoteSubscriptionReconcileFuture = _performRemoteSubscriptionReconcile();
  }

  Future<void> _performRemoteSubscriptionReconcile() async {
    try {
      final engine = _agoraService.engine;
      if (engine == null || _videoExitCleanupStarted) return;

      final activeCallerIds = _activeAcceptedCallerUids();
      final activeVideoCallerIds = _effectiveVideoCallRows()
          .where(_isActiveVideoCall)
          .map(_safeUserId)
          .where((id) => id > 0)
          .toSet();
      final mappedVideoUids = liveController.videoCallerAgoraUidMap.values
          .toSet();
      final hostUid = _resolvedHostUserId();

      for (final uid in _joinedRemoteUids.toList(growable: false)) {
        final isRemoteHost = _uidsAreEquivalent(uid, hostUid);
        final matchesAcceptedCaller = activeCallerIds.any(
              (callerId) => _uidsAreEquivalent(uid, callerId),
        );
        final matchesVideoCaller = activeVideoCallerIds.any(
              (callerId) => _uidsAreEquivalent(uid, callerId),
        );
        final shouldSubscribeAudio =
            isRemoteHost || matchesAcceptedCaller || mappedVideoUids.contains(uid);
        final shouldSubscribeVideo =
            isRemoteHost || matchesVideoCaller || mappedVideoUids.contains(uid);

        await _safeAgoraAction(
          'muteRemoteAudioStream($uid, ${!shouldSubscribeAudio})',
              () => engine.muteRemoteAudioStream(
            uid: uid,
            mute: !shouldSubscribeAudio,
          ),
        );
        await _safeAgoraAction(
          'muteRemoteVideoStream($uid, ${!shouldSubscribeVideo})',
              () => engine.muteRemoteVideoStream(
            uid: uid,
            mute: !shouldSubscribeVideo,
          ),
        );
        if (!shouldSubscribeAudio) {
          _setSpeakingStatus(uid: uid, isSpeaking: false);
        }
        if (!shouldSubscribeVideo) {
          _removeStableVideoRenderer(uid);
        }
        _logVideoCallLayoutReady(uid);
      }
    } finally {
      _remoteSubscriptionReconcileFuture = null;
    }
  }

  String _videoRendererKey({required int uid, required bool local}) {
    return '${_activeAgoraChannelForVideo()}:${local ? 'local' : 'remote'}:$uid';
  }

  Widget _stableVideoRenderer({required int uid, required bool local}) {
    final key = _videoRendererKey(uid: uid, local: local);
    return _stableVideoRenderers.putIfAbsent(
      key,
          () => RepaintBoundary(
        key: ValueKey<String>('video-surface-$key'),
        child: AgoraVideoView(
          key: ValueKey<String>('agora-video-$key'),
          controller: local
              ? VideoViewController(
            rtcEngine: _agoraService.engine!,
            canvas: const VideoCanvas(
              uid: 0,
              renderMode: RenderModeType.renderModeHidden,
              mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
            ),
          )
              : VideoViewController.remote(
            rtcEngine: _agoraService.engine!,
            canvas: VideoCanvas(
              uid: uid,
              renderMode: RenderModeType.renderModeHidden,
            ),
            connection: RtcConnection(
              channelId: _activeAgoraChannelForVideo(),
            ),
          ),
        ),
      ),
    );
  }

  void _removeStableVideoRenderer(int uid) {
    _stableVideoRenderers.removeWhere(
          (key, _) => key.endsWith(':remote:$uid') || key.endsWith(':local:$uid'),
    );
  }

  void _retainCurrentVideoRenderers(Set<String> activeKeys) {
    _stableVideoRenderers.removeWhere((key, _) => !activeKeys.contains(key));
  }

  Widget _broadcastView() {
    return Obx(() {
      final engine = _agoraService.engine;
      if (engine == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final callers = _acceptedCallersForOverlay();
      final hostUserId = _resolvedHostUserId();
      final hostRemoteUid = _joinedRemoteUids.firstWhere(
            (uid) => _uidsAreEquivalent(uid, hostUserId),
        orElse: () => hostUserId <= 0 && _joinedRemoteUids.length == 1
            ? _joinedRemoteUids.first
            : 0,
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.isBroadcaster)
            ClipRect(child: _stableVideoRenderer(uid: 0, local: true))
          else if (hostRemoteUid > 0)
            ClipRect(
              child: _stableVideoRenderer(uid: hostRemoteUid, local: false),
            )
          else
            ColoredBox(
              color: const Color(0xff111111),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      ('Connecting to host...').appTr,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          if (callers.isNotEmpty) _buildAcceptedCallerOverlay(callers),
        ],
      );
    });
  }

  Widget _buildAcceptedCallerOverlay(List<Map<String, dynamic>> callers) {
    final visibleCallers = callers.take(4).toList(growable: false);
    final count = visibleCallers.length;
    if (count == 0) return const SizedBox.shrink();

    final bool useGrid = count == 4;
    final double panelWidth = useGrid
        ? (Get.width * 0.46).clamp(164.0, 224.0).toDouble()
        : (Get.width * 0.30).clamp(108.0, 142.0).toDouble();
    final double cardWidth = useGrid
        ? (panelWidth - 7) / 2
        : panelWidth;
    final double cardHeight = useGrid
        ? (Get.height * 0.135).clamp(88.0, 118.0).toDouble()
        : count == 1
        ? (Get.height * 0.18).clamp(118.0, 158.0).toDouble()
        : (Get.height * 0.14).clamp(94.0, 124.0).toDouble();
    final double panelHeight = useGrid
        ? (cardHeight * 2) + 7
        : (cardHeight * count) + (7 * (count - 1));

    final usedRemoteUids = <int>{};
    bool localRendererUsed = false;

    Widget buildCard(Map<String, dynamic> call) {
      final callerId = _safeUserId(call);
      final currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      final bool isSelf = callerId > 0 && callerId == currentUserId;
      final int remoteUid = isSelf ? 0 : _remoteUidForCaller(callerId);
      bool allowVideoRenderer = false;
      if (isSelf) {
        allowVideoRenderer = !localRendererUsed;
        localRendererUsed = true;
      } else if (remoteUid > 0) {
        allowVideoRenderer = usedRemoteUids.add(remoteUid);
      }

      return _buildAcceptedCallerCard(
        call,
        width: cardWidth,
        height: cardHeight,
        isSelf: isSelf,
        remoteUid: remoteUid,
        allowVideoRenderer: allowVideoRenderer,
      );
    }

    return Positioned(
      right: 10,
      bottom: (kHeight * 0.17).clamp(104.0, 168.0).toDouble(),
      width: panelWidth,
      height: panelHeight,
      child: RepaintBoundary(
        child: useGrid
            ? GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 7,
            mainAxisSpacing: 7,
            childAspectRatio: cardWidth / cardHeight,
          ),
          itemCount: visibleCallers.length,
          itemBuilder: (_, index) => buildCard(visibleCallers[index]),
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int index = 0; index < visibleCallers.length; index++) ...[
              if (index > 0) const SizedBox(height: 7),
              buildCard(visibleCallers[index]),
            ],
          ],
        ),
      ),
    );
  }

  bool _canControlCallerVideo(int callerId) {
    if (callerId <= 0) return false;

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    /// Host can moderate every accepted video caller. A caller can only control
    /// their own camera. Normal audience cannot change another user's camera.
    return widget.isBroadcaster || callerId == currentUserId;
  }

  void _openCallerProfile(Map<String, dynamic> call) {
    final int callerId = _safeUserId(call);
    if (callerId <= 0) return;

    homeController.liveVisitProfile(
      userId: '$callerId',
      seatData: call,
    );
  }

  Future<void> _showCallerCardActions(
      Map<String, dynamic> call,
      ) async {
    final int callerId = _safeUserId(call);
    if (callerId <= 0) return;

    final bool isVideoCall = _callWantsVideo(call);
    final bool canControlVideo =
        isVideoCall && _canControlCallerVideo(callerId);

    if (!canControlVideo) {
      _openCallerProfile(call);
      return;
    }

    final String name = _safeUserName(call, fallback: 'Caller');
    final String profileImage = _safeUserProfile(call);

    await Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final bool cameraOn =
          websocketController.getUserVideoStatus(callerId);
          final bool isLoading =
          _videoToggleUsersInFlight.contains(callerId);

          Future<void> toggleCamera() async {
            if (isLoading ||
                _videoToggleUsersInFlight.contains(callerId)) {
              return;
            }

            setSheetState(() {
              _videoToggleUsersInFlight.add(callerId);
            });

            try {
              await liveController.toggleSpecificUserVideo(
                callerId,
                rtcEngine: _agoraService.engine,
              );

              if (Get.isBottomSheetOpen == true) {
                Get.back();
              }
            } finally {
              _videoToggleUsersInFlight.remove(callerId);
              if (mounted) {
                _scheduleUIUpdate();
              }
            }
          }

          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xffd8d8dd),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: profileImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Color(0xffeeeeee),
                            child: Icon(
                              Icons.person_rounded,
                              color: Color(0xff777777),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff17131b),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              callerId ==
                                  (authController.userProfile.value.user?.id
                                      ?.toInt() ??
                                      0)
                                  ? ('Control your camera').appTr
                                  : ('Manage caller camera').appTr,
                              style: const TextStyle(
                                color: Color(0xff77717a),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: cameraOn
                        ? const Color(0xffffeef3)
                        : const Color(0xffecf8f4),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: isLoading ? null : toggleCamera,
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cameraOn
                                    ? const Color(0xffe85c7d)
                                    : const Color(0xff16a879),
                                shape: BoxShape.circle,
                              ),
                              child: isLoading
                                  ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Icon(
                                cameraOn
                                    ? Icons.videocam_off_rounded
                                    : Icons.videocam_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cameraOn
                                    ? ('Turn Camera Off').appTr
                                    : ('Turn Camera On').appTr,
                                style: const TextStyle(
                                  color: Color(0xff201b20),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xff817a82),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Material(
                    color: const Color(0xfff5f3f5),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: isLoading
                          ? null
                          : () {
                        Get.back();
                        _openCallerProfile(call);
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.account_circle_rounded,
                                color: Color(0xff695f68),
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ('View Profile').appTr,
                                style: const TextStyle(
                                  color: Color(0xff201b20),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xff817a82),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  Widget _buildAcceptedCallerCard(
      Map<String, dynamic> call, {
        required double width,
        required double height,
        required bool isSelf,
        required int remoteUid,
        required bool allowVideoRenderer,
      }) {
    final callerId = _safeUserId(call);
    final name = _safeUserName(call, fallback: 'Caller');
    final imageUrl = _safeUserProfile(call);
    final muted = _isCallMuted(call);
    final speaking = _isUserSpeaking(callerId) && !muted;
    final wantsVideo = _callWantsVideo(call);
    final videoEnabled = wantsVideo && _callVideoEnabled(call);
    final remoteJoined = remoteUid > 0 &&
        _joinedRemoteUids.contains(remoteUid) &&
        !_offlineRemoteUids.contains(remoteUid);
    final remoteVideoReady = remoteJoined &&
        _remoteVideoReadyUids.contains(remoteUid) &&
        liveController.videoLiveRemoteVideoEnabled[remoteUid] != false;
    final showVideo = videoEnabled &&
        allowVideoRenderer &&
        (isSelf || remoteVideoReady);

    Widget avatarBackground() {
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(
                color: Color(0xff302b35),
              ),
            ),
          ),
          ColoredBox(color: Colors.black.withOpacity(0.34)),
          Center(
            child: Container(
              width: (width * 0.48).clamp(42.0, 62.0).toDouble(),
              height: (width * 0.48).clamp(42.0, 62.0).toDouble(),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 9),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: Color(0xffeeeeee),
                    child: Icon(Icons.person, color: Color(0xff777777)),
                  ),
                ),
              ),
            ),
          ),
          if (wantsVideo && videoEnabled && !showVideo)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onTap: callerId > 0
            ? () => _showCallerCardActions(call)
            : null,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xff17131b),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: speaking
                  ? const Color(0xff35e6a5)
                  : Colors.white.withOpacity(0.9),
              width: speaking ? 2.2 : 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showVideo)
                _stableVideoRenderer(
                  uid: isSelf ? 0 : remoteUid,
                  local: isSelf,
                )
              else
                avatarBackground(),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.62),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 15,
                    color: muted
                        ? const Color(0xffff6b6b)
                        : speaking
                        ? const Color(0xff35e6a5)
                        : Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    wantsVideo
                        ? (videoEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded)
                        : Icons.headset_mic_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 5,
                right: 5,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    isSelf ? '$name • You' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width < 95 ? 8.5 : 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legacyBroadcastView() {
    if (_agoraService.engine == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Obx(() {
      final views = _getRenderViews(
        listActive: websocketController.liveCallList,
      );

      if (views.isEmpty) {
        if (widget.isBroadcaster && _agoraService.engine != null) {
          return _stableVideoRenderer(uid: 0, local: true);
        }
        return Center(child: Text(("Waiting for remote user...").appTr));
      }

      final mainView = views[0];

      final smallBroadcasters = websocketController.liveCallList
          .asMap()
          .entries
          .where(
            (e) =>
        e.key > 0 &&
            e.key <= 4 &&
            e.key < views.length &&
            _hasValidUser(e.value),
      )
          .map((e) {
        final index = e.key;
        final broadcaster = e.value;
        final userId = _safeUserId(broadcaster);
        final bool isMuted = _isCallMuted(broadcaster);
        final bool isSpeaking = _isUserSpeaking(userId) && !isMuted;
        final bool isAudioOnly =
            broadcaster['video_on'] == 0 ||
                broadcaster['call_type'] == 'audio';

        return GestureDetector(
          onTap: () {
            homeController.liveVisitProfile(
              userId: '${_safeUserId(broadcaster)}',
              seatData: broadcaster,
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isSpeaking)
                Positioned.fill(child: SpeakingCardWave(borderRadius: 10)),
              Container(
                margin: EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: isSpeaking
                        ? const [
                      Color(0xff38ffb3),
                      Color(0xff15bccd),
                      Color(0xff38ffb3),
                    ]
                        : const [
                      Color(0xffe85c7d),
                      Color(0xfffdcdfb),
                      Color(0xff15bccd),
                    ],
                  ),
                  boxShadow: isSpeaking
                      ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(.42),
                      blurRadius: 16,
                      spreadRadius: 1.5,
                    ),
                  ]
                      : null,
                ),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  width: Get.width * 0.27,
                  height: Get.height * 0.15,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isAudioOnly
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _safeUserMap(broadcaster)['profile_image'] !=
                            null &&
                            _safeUserMap(
                              broadcaster,
                            )['profile_image']
                                .toString()
                                .isNotEmpty
                            ? ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 8,
                            sigmaY: 8,
                          ),
                          child: CachedNetworkImage(
                            imageUrl: _safeUserProfile(
                              broadcaster,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(
                                  color: Colors.grey.shade800,
                                ),
                            errorWidget:
                                (context, url, error) =>
                                Container(
                                  color:
                                  Colors.grey.shade800,
                                ),
                          ),
                        )
                            : Container(color: Colors.grey.shade800),

                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: kHeight * 0.018),
                              SizedBox(
                                height: Get.height * 0.080,
                                width: Get.height * 0.080,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isSpeaking)
                                      SpeakingWave(
                                        size: Get.height * 0.080,
                                      ),
                                    ClipOval(
                                      child:
                                      _safeUserProfile(
                                        broadcaster,
                                      ).isNotEmpty
                                          ? CachedNetworkImage(
                                        imageUrl:
                                        _safeUserProfile(
                                          broadcaster,
                                        ),
                                        height:
                                        Get.height * 0.064,
                                        width:
                                        Get.height * 0.064,
                                        fit: BoxFit.cover,
                                        filterQuality:
                                        FilterQuality.high,
                                        placeholder:
                                            (
                                            context,
                                            url,
                                            ) => Container(
                                          height:
                                          Get.height *
                                              0.064,
                                          width:
                                          Get.height *
                                              0.064,
                                          color: Colors
                                              .grey
                                              .shade600,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors
                                                .white,
                                          ),
                                        ),
                                        errorWidget:
                                            (
                                            context,
                                            url,
                                            error,
                                            ) => Container(
                                          height:
                                          Get.height *
                                              0.064,
                                          width:
                                          Get.height *
                                              0.064,
                                          color: Colors
                                              .grey
                                              .shade600,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors
                                                .white,
                                          ),
                                        ),
                                      )
                                          : Container(
                                        height:
                                        Get.height * 0.064,
                                        width:
                                        Get.height * 0.064,
                                        color: Colors
                                            .grey
                                            .shade600,
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (isMuted)
                                      Positioned(
                                        right: 4,
                                        bottom: 6,
                                        child: _SmallMuteBadge(
                                          fontSize: kHeight * 0.007,
                                          iconSize: kHeight * 0.009,
                                          compact: true,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(height: kHeight * 0.010),
                              _miniNamePill(broadcaster),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(child: views[index]),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    (() {
                                      final name = _safeUserName(
                                        broadcaster,
                                        fallback: '',
                                      );
                                      return name.length > 10
                                          ? '${name.substring(0, 10)}...'
                                          : name;
                                    })(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: kHeight * 0.011,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isMuted)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: _SmallMuteBadge(
                              fontSize: kHeight * 0.0075,
                              iconSize: kHeight * 0.010,
                              compact: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      })
          .toList();

      return Stack(
        children: [
          // 🎥 Main broadcaster view
          mainView,

          // 👥 ছোট broadcaster preview গুলো bottom-right এ floating style এ
          if (smallBroadcasters.isNotEmpty)
            Positioned(
              bottom: kHeight * 0.15, // স্ক্রিনের নিচ থেকে 10px
              right: 10, // ডান দিক থেকে 10px
              child: Column(
                mainAxisSize: MainAxisSize.min,
                verticalDirection: VerticalDirection.up, // নিচ থেকে উপরে সাজাবে
                children: smallBroadcasters,
              ),
            ),
        ],
      );
    });
  }

  Widget _pkAgoraSyncWatcher() {
    return Obx(() {
      final bool pkRunning = liveController.pkIsRunning.value;
      final String pkChannel = liveController.pkChannelName.value.trim();
      final bool pkJoining = liveController.pkAgoraJoining.value;

      if (!pkRunning) {
        if (_wasInPkChannel && !_normalReturnInProgress) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _returnToNormalAgoraChannelIfNeeded();
          });
        }
        _lastSyncedPkChannel = '';
        _pkSyncScheduled = false;
        return const SizedBox.shrink();
      }

      if (pkChannel.isEmpty) {
        _lastSyncedPkChannel = '';
        _pkSyncScheduled = false;
        return const SizedBox.shrink();
      }

      if (!pkJoining &&
          !_pkSyncScheduled &&
          _lastSyncedPkChannel != pkChannel) {
        _pkSyncScheduled = true;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          await _syncPkAgoraChannelState();

          _lastSyncedPkChannel = pkChannel;
          _pkSyncScheduled = false;
        });
      }

      return const SizedBox.shrink();
    });
  }

  Future<void> _syncPkAgoraChannelState() async {
    if (!mounted || _videoExitCleanupStarted) return;

    final pkRunning = liveController.pkIsRunning.value;
    final pkChannel = liveController.pkChannelName.value.trim();

    if (pkRunning && pkChannel.isNotEmpty) {
      await _joinPkAgoraChannelIfNeeded(pkChannel);
      return;
    }

    if (!pkRunning && _wasInPkChannel) {
      await _returnToNormalAgoraChannelIfNeeded();
    }
  }

  Future<String> _generateAgoraTokenForChannel({
    required String channelName,
    required int uid,
    required bool isBroadcaster,
  }) async {
    try {
      final int pkId = liveController.currentPkId.value;

      await liveController.agoraTokenController.tryToGenerateBroadcasterToken(
        isBroadcaster: isBroadcaster,
        userId: uid,
        channelName: channelName,
        streamId: _safeStreamId().toString(),
        pkId: pkId > 0 ? pkId : null,
      );

      final String token = liveController.agoraTokenController.getTokenString();
      final String appId = liveController.agoraTokenController.getAppIdString();
      final String tokenChannel = liveController.agoraTokenController
          .getChannelNameString();

      debugPrint(
        '✅ PK token generated => appId=$appId channel=$tokenChannel pkId=$pkId uid=$uid',
      );

      if (token.isEmpty) {
        debugPrint('❌ PK token empty');
        return '';
      }

      return token;
    } catch (e) {
      debugPrint('⚠️ PK token generate failed => $e');
      return '';
    }
  }

  Future<void> _joinPkAgoraChannelIfNeeded(String pkChannel) async {
    if (_videoExitCleanupStarted || !mounted) return;

    final String safePkChannel = pkChannel.trim();

    if (safePkChannel.isEmpty) {
      debugPrint('❌ PK Agora join failed: pkChannel empty');
      return;
    }

    final engine = _agoraService.engine;
    if (engine == null) {
      debugPrint('❌ PK Agora join failed: engine null');
      return;
    }

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (currentUserId == 0) {
      debugPrint('❌ PK Agora join failed: currentUserId 0');
      return;
    }

    final bool isPkHost =
        currentUserId == liveController.pkSenderHostId.value ||
            currentUserId == liveController.pkReceiverHostId.value;

    final String joinKey = '$safePkChannel-$currentUserId-$isPkHost';

    /// Already same PK channel e thakle abar join korbo na
    if (_activeAgoraChannel == safePkChannel && _lastPkJoinKey == joinKey) {
      debugPrint('⚠️ PK Agora join skipped: already joined => $joinKey');
      return;
    }

    /// Join already running hole skip
    if (_pkJoinInProgress || liveController.pkAgoraJoining.value) {
      debugPrint('⚠️ PK Agora join skipped: join already running');
      return;
    }

    _pkJoinInProgress = true;
    liveController.pkAgoraJoining.value = true;

    try {
      debugPrint(
        '🚀 PK Agora join start => channel=$safePkChannel uid=$currentUserId host=$isPkHost pkId=${liveController.currentPkId.value}',
      );

      /// 1. PK channel er token generate.
      /// Important: _generateAgoraTokenForChannel() er vitore pkId pathate hobe.
      final String pkToken = await _generateAgoraTokenForChannel(
        channelName: safePkChannel,
        uid: currentUserId,
        isBroadcaster: isPkHost,
      );

      if (_videoExitCleanupStarted || !mounted) return;

      if (pkToken.trim().isEmpty) {
        debugPrint('❌ PK Agora join stopped: token empty');
        return;
      }

      final String tokenAppId = liveController.agoraTokenController
          .getAppIdString();
      final String tokenChannel = liveController.agoraTokenController
          .getChannelNameString();

      debugPrint('✅ PK token appId => $tokenAppId');
      debugPrint('✅ PK token channel => $tokenChannel');

      /// Optional warning. App ID mismatch hole remote ashbe na.
      /// Ei App ID ta AgoraService er appId er sathe same hote hobe.
      if (tokenChannel.isNotEmpty && tokenChannel != safePkChannel) {
        debugPrint(
          '❌ PK token channel mismatch => token=$tokenChannel expected=$safePkChannel',
        );
        return;
      }

      final String finalPkJoinChannel = _isRealPkAgoraChannel(tokenChannel)
          ? tokenChannel
          : safePkChannel;

      /// 2. Old channel leave
      try {
        await _agoraService.leaveChannel();
        debugPrint('✅ Old Agora channel left before PK join');
      } catch (e) {
        debugPrint('⚠️ leaveChannel before PK join ignored => $e');
      }

      _pkRemoteUids.clear();
      _setAllSpeakingOff();

      /// Camera/audio release korte small delay helpful.
      /// 250ms enough; beshi delay dile first camera render late/black hoy.
      await Future.delayed(const Duration(milliseconds: 250));

      if (_videoExitCleanupStarted || !mounted) return;

      /// 3. Agora config
      await _safeAgoraAction(
        'setChannelProfile(pk)',
            () => engine.setChannelProfile(
          ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      await _safeAgoraAction('enableAudio(pk)', () => engine.enableAudio());
      await _safeAgoraAction('enableVideo(pk)', () => engine.enableVideo());
      try {
        await engine.setRemoteDefaultVideoStreamType(
          VideoStreamType.videoStreamLow,
        );
      } catch (e) {
        debugPrint('⚠️ setRemoteDefaultVideoStreamType ignored => $e');
      }

      await engine.enableAudioVolumeIndication(
        interval: 300,
        smooth: 3,
        reportVad: true,
      );

      await engine.setClientRole(
        role: isPkHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );

      if (isPkHost) {
        await engine.enableLocalVideo(true);
        await engine.muteLocalVideoStream(false);
        await engine.muteLocalAudioStream(false);

        /// Host hole preview start korte hobe
        try {
          await _agoraService.startPreview();
        } catch (e) {
          debugPrint('⚠️ startPreview ignored => $e');
        }
      } else {
        await engine.enableLocalVideo(false);
        await engine.muteLocalVideoStream(true);
        await engine.muteLocalAudioStream(true);
      }

      /// 4. Speaker on
      try {
        await engine.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint('⚠️ setEnableSpeakerphone ignored => $e');
      }

      await _safeAgoraAction(
        'unmuteAllRemoteAudioStreams(pk)',
            () => engine.muteAllRemoteAudioStreams(false),
      );
      await _safeAgoraAction(
        'unmuteAllRemoteVideoStreams(pk)',
            () => engine.muteAllRemoteVideoStreams(false),
      );

      if (_videoExitCleanupStarted || !mounted) return;

      /// 5. Join PK channel
      await _agoraService.joinChannelWithOptions(
        token: pkToken,
        channelId: finalPkJoinChannel,
        uid: currentUserId,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: isPkHost
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishCameraTrack: isPkHost,
          publishMicrophoneTrack: isPkHost,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      /// joinChannel call success hole state set
      _activeAgoraChannel = finalPkJoinChannel;
      _lastPkJoinKey = joinKey;
      _wasInPkChannel = true;

      debugPrint(
        '✅ PK Agora join called => channel=$finalPkJoinChannel uid=$currentUserId host=$isPkHost',
      );
    } catch (e) {
      debugPrint('❌ PK Agora join error => $e');

      /// Error hole state reset, jate next time abar try korte pare
      if (_activeAgoraChannel == safePkChannel) {
        _activeAgoraChannel = '';
      }
      if (_lastPkJoinKey == joinKey) {
        _lastPkJoinKey = '';
      }
    } finally {
      _pkJoinInProgress = false;
      liveController.pkAgoraJoining.value = false;
      _scheduleUIUpdate();
    }
  }

  Future<void> _returnToNormalAgoraChannelIfNeeded() async {
    final engine = _agoraService.engine;
    if (engine == null ||
        _normalReturnInProgress ||
        _videoExitCleanupStarted ||
        !mounted) {
      return;
    }

    final normalChannel =
    liveController.normalAgoraChannelName.trim().isNotEmpty
        ? liveController.normalAgoraChannelName.trim()
        : widget.channelName;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (normalChannel.isEmpty || currentUserId == 0) return;

    _normalReturnInProgress = true;
    try {
      debugPrint('↩️ Returning to normal Agora channel => $normalChannel');

      String normalToken = '';

      /// Always generate a fresh normal-live token after PK ends.
      /// This avoids using the PK token for normal channel and fixes audience
      /// not seeing/hearing host after PK end.
      try {
        await liveController.agoraTokenController.tryToGenerateBroadcasterToken(
          isBroadcaster: widget.isBroadcaster,
          userId: currentUserId,
          channelName: normalChannel,
          streamId: _safeStreamId().toString(),
          pkId: null,
        );

        normalToken = liveController.agoraTokenController.getTokenString();
      } catch (e) {
        debugPrint('⚠️ Normal token refresh failed => $e');
      }

      if (_videoExitCleanupStarted || !mounted) return;

      if (normalToken.trim().isEmpty) {
        normalToken = liveController.normalAgoraToken.isNotEmpty
            ? liveController.normalAgoraToken
            : widget.token;
      }

      await _agoraService.leaveChannel();
      _pkRemoteUids.clear();
      _setAllSpeakingOff();

      await Future.delayed(const Duration(milliseconds: 550));

      if (_videoExitCleanupStarted || !mounted) return;

      await _safeAgoraAction(
        'setChannelProfile(return_normal)',
            () => engine.setChannelProfile(
          ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      await _safeAgoraAction(
        'enableAudio(return_normal)',
            () => engine.enableAudio(),
      );
      await _safeAgoraAction(
        'enableVideo(return_normal)',
            () => engine.enableVideo(),
      );
      await engine.setClientRole(
        role: widget.isBroadcaster
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      );

      if (widget.isBroadcaster) {
        await engine.enableLocalVideo(true);
        await engine.enableLocalAudio(true);
        await engine.muteLocalVideoStream(false);
        await engine.muteLocalAudioStream(false);
        await _agoraService.startPreview();
      } else {
        await engine.enableLocalVideo(false);
        await engine.muteLocalVideoStream(true);
        await engine.muteLocalAudioStream(true);
      }

      await _safeAgoraAction(
        'unmuteAllRemoteAudioStreams(return_normal)',
            () => engine.muteAllRemoteAudioStreams(false),
      );
      await _safeAgoraAction(
        'unmuteAllRemoteVideoStreams(return_normal)',
            () => engine.muteAllRemoteVideoStreams(false),
      );

      if (_videoExitCleanupStarted || !mounted) return;

      await _agoraService.joinChannelWithOptions(
        token: normalToken,
        channelId: normalChannel,
        uid: currentUserId,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: widget.isBroadcaster
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishCameraTrack: widget.isBroadcaster,
          publishMicrophoneTrack: widget.isBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      _activeAgoraChannel = normalChannel;
      _lastPkJoinKey = '';
      _wasInPkChannel = false;
      _lastSyncedPkChannel = '';
      _pkSyncScheduled = false;
      debugPrint('✅ Returned to normal Agora channel => $normalChannel');
    } catch (e) {
      debugPrint('❌ Return normal Agora error => $e');
    } finally {
      _normalReturnInProgress = false;
      _scheduleUIUpdate();
    }
  }

  void _setAllSpeakingOff() {
    for (final timer in _speakingOffTimers.values) {
      timer.cancel();
    }
    _speakingOffTimers.clear();
    _speakingUserIds.clear();
  }

  /// Helper function to get list of native views

  List<Widget> _getRenderViews({required List<dynamic> listActive}) {
    final List<Widget> list = <Widget>[];
    final Set<int> addedUids = <int>{};
    final Set<String> activeRendererKeys = <String>{};
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final int hostUserId = _safeUserId(broadcasterData);

    for (var activeCallData in listActive) {
      if (activeCallData == null || activeCallData is! Map) {
        continue;
      }

      final Map<String, dynamic> activeMap = _safeMap(activeCallData);
      int uid = _safeUserId(activeMap);
      if (uid <= 0) {
        uid = _safeInt(
          activeMap['uid'] ?? activeMap['caller_id'] ?? activeMap['user_id'],
        );
      }
      if (uid <= 0) {
        debugPrint('⚠️ Render view skipped: missing uid/user => $activeMap');
        continue;
      }
      if (!addedUids.add(uid) || _offlineRemoteUids.contains(uid)) continue;

      final bool isHost =
          uid.toString() == widget.channelName || uid == hostUserId;
      final bool isLocal = uid == currentUserId;
      final bool isAcceptedCaller = _isActiveVideoCall(activeMap);
      if (!isHost && !isAcceptedCaller) continue;
      int renderUid = uid;
      if (!isLocal && !_joinedRemoteUids.contains(renderUid)) {
        final equivalentUid = _joinedRemoteUids.firstWhere(
              (joinedUid) =>
          joinedUid == uid + 100000 ||
              (uid >= 100000 && joinedUid == uid - 100000),
          orElse: () => 0,
        );
        if (equivalentUid > 0) {
          renderUid = equivalentUid;
        } else if (isAcceptedCaller && _joinedRemoteUids.length == 1) {
          // Backend caller id and Agora uid can differ. For a single accepted
          // caller the actual onUserJoined uid is authoritative for rendering.
          renderUid = _joinedRemoteUids.first;
        } else {
          continue;
        }
      }

      final bool hasVideo = isHost || isAcceptedCaller;
      if (!hasVideo) continue;

      final rendererKey = _videoRendererKey(
        uid: isLocal ? 0 : renderUid,
        local: isLocal,
      );
      activeRendererKeys.add(rendererKey);
      final renderer = _stableVideoRenderer(
        uid: isLocal ? 0 : renderUid,
        local: isLocal,
      );
      if (isHost) {
        list.insert(0, renderer);
      } else {
        list.add(renderer);
      }
    }

    if (widget.isBroadcaster && !addedUids.contains(currentUserId)) {
      final rendererKey = _videoRendererKey(uid: 0, local: true);
      activeRendererKeys.add(rendererKey);
      list.insert(0, _stableVideoRenderer(uid: 0, local: true));
    }

    _retainCurrentVideoRenderers(activeRendererKeys);

    return list;
  }

  int _safeStreamId() {
    final direct =
        int.tryParse(
          (streamInfo['id'] ?? liveController.streamId.value).toString(),
        ) ??
            0;
    if (direct > 0) return direct;
    final arg = Get.arguments;
    if (arg is Map) {
      final live = arg['livestreamdata'] ?? arg['livestream'] ?? arg['data'];
      if (live is Map) {
        return int.tryParse(
          (live['id'] ?? live['livestream_id'] ?? 0).toString(),
        ) ??
            0;
      }
      return int.tryParse(
        (arg['id'] ?? arg['livestream_id'] ?? 0).toString(),
      ) ??
          0;
    }
    return liveController.streamId.value;
  }

  int _selectedGiftCoinPrice() {
    final int selectedId = livestreamController.selectedGiftId.value;
    if (selectedId <= 0) return 0;

    for (final raw in livestreamController.giftList) {
      if (raw is! Map) continue;
      final int id = int.tryParse('${raw['id'] ?? raw['gift_id'] ?? 0}') ?? 0;
      if (id != selectedId) continue;

      final int coin =
          int.tryParse(
            '${raw['coin'] ?? raw['coins'] ?? raw['price'] ?? raw['gift_price'] ?? 0}',
          ) ??
              0;
      if (coin > 0) return coin;
    }
    return 0;
  }

  bool _isRealPkAgoraChannel(String value) {
    final channel = value.trim();
    // Real PK channel example: pk_8211_8210_1782927658.
    // Do not accept numeric normal channels like 101010/100550 as PK channel.
    return channel.startsWith('pk_') && channel.split('_').length >= 4;
  }

  String _findRealPkChannelFromRaw(Map<String, dynamic> raw) {
    final pkRoomData = raw['pk_room_data'];
    final pkRoom = raw['pk_room'];
    final maps = <Map<String, dynamic>>[];

    maps.add(raw);
    if (pkRoomData is Map) maps.add(Map<String, dynamic>.from(pkRoomData));
    if (pkRoom is Map) maps.add(Map<String, dynamic>.from(pkRoom));

    for (final map in maps) {
      for (final key in const [
        'pk_channel_name',
        'pk_channel',
        'pk_agora_channel',
        'agora_channel_name',
        'channel_name',
      ]) {
        final value = map[key]?.toString().trim() ?? '';
        if (_isRealPkAgoraChannel(value)) return value;
      }
    }
    return '';
  }

  void _bootstrapPkStateFromArguments({String source = 'live_view_arguments'}) {
    try {
      final Map<String, dynamic> raw = <String, dynamic>{};

      if (streamData is Map) {
        raw.addAll(Map<String, dynamic>.from(streamData));
      }
      if (streamInfo.isNotEmpty) {
        raw.addAll(Map<String, dynamic>.from(streamInfo));
      }

      final dynamic liveData =
          raw['livestreamdata'] ??
              raw['livestream'] ??
              raw['live_stream'] ??
              raw['data'];
      if (liveData is Map) {
        raw.addAll(Map<String, dynamic>.from(liveData));
      }

      final bool looksPk =
          raw['is_pk_room'] == true ||
              raw['is_real_pk_room'] == true ||
              raw['is_pk'] == 1 ||
              raw['is_pk'] == true ||
              '${raw['stream_type'] ?? ''}'.toLowerCase() == 'pk' ||
              (raw['pk_id'] != null && raw['pk_id'].toString().trim().isNotEmpty) ||
              raw['sender_livestream_id'] != null ||
              raw['receiver_livestream_id'] != null;

      if (!looksPk) return;

      final String realPkChannel = _findRealPkChannelFromRaw(raw);
      if (!_isRealPkAgoraChannel(realPkChannel)) {
        debugPrint(
          '⚠️ PopularLiveView PK bootstrap skipped: real PK channel missing. '
              'source=$source normalChannel=${raw['channel_name'] ?? raw['room_id']}',
        );
        return;
      }

      raw['pk_channel_name'] = realPkChannel;
      raw['pk_channel'] = realPkChannel;
      raw['channel_name'] = realPkChannel;

      liveController.syncPkStateFromLiveData(raw, source: source);
      debugPrint(
        '✅ PopularLiveView PK bootstrap => channel=${liveController.pkChannelName.value} '
            'pk=${liveController.currentPkId.value}',
      );
    } catch (e) {
      debugPrint('⚠️ PopularLiveView PK bootstrap skipped => $e');
    }
  }

  String _activeAgoraChannelForVideo() {
    return liveController.pkIsRunning.value &&
        liveController.pkChannelName.value.trim().isNotEmpty
        ? liveController.pkChannelName.value.trim()
        : (_activeAgoraChannel.isNotEmpty
        ? _activeAgoraChannel
        : widget.channelName);
  }

  Widget _premiumPkGradientBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xff850038),
              Color(0xff46106f),
              Color(0xff1231a0),
              Color(0xff006eea),
            ],
            stops: [0.0, .35, .68, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.95, -.75),
                    radius: 1.05,
                    colors: [
                      const Color(0xffff2d75).withOpacity(.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.95, -.65),
                    radius: 1.15,
                    colors: [
                      const Color(0xff00c8ff).withOpacity(.48),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: .10,
                child: CustomPaint(painter: _PkGridPatternPainter()),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(.08)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pkSpeakingBars(bool active, {bool leftSide = true}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: active ? 1 : .38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (index) {
          final double height = active
              ? (8 + (index.isEven ? 7 : 13)).toDouble()
              : 6;
          return AnimatedContainer(
            duration: Duration(milliseconds: 170 + (index * 45)),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 1.6),
            width: 3.2,
            height: height,
            decoration: BoxDecoration(
              color: active
                  ? (leftSide
                  ? const Color(0xffffe66d)
                  : const Color(0xff7dfffb))
                  : Colors.white.withOpacity(.75),
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? [
                BoxShadow(
                  color:
                  (leftSide
                      ? const Color(0xffffe66d)
                      : const Color(0xff7dfffb))
                      .withOpacity(.55),
                  blurRadius: 8,
                ),
              ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  int _pkToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  Map<String, dynamic> _pkAsMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _pkAsList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  Map<String, dynamic> _pkUserFromLiveData(Map<String, dynamic> liveData) {
    final callers = _pkAsList(liveData['livestream_callers']);
    if (callers.isNotEmpty) {
      final first = _pkAsMap(callers.first);
      final user = _pkAsMap(first['user']);
      if (user.isNotEmpty) return user;
    }

    final user = _pkAsMap(liveData['user']);
    if (user.isNotEmpty) return user;

    return <String, dynamic>{};
  }

  Map<String, dynamic> _pkSenderUser() {
    final data = _pkAsMap(liveController.currentPkData);
    final nested = _pkAsMap(data['data']);

    final direct = _pkAsMap(data['sender_host']);
    if (direct.isNotEmpty) return direct;

    final nestedDirect = _pkAsMap(nested['sender_host']);
    if (nestedDirect.isNotEmpty) return nestedDirect;

    final live = _pkAsMap(data['sender_livestream']).isNotEmpty
        ? _pkAsMap(data['sender_livestream'])
        : (_pkAsMap(nested['sender_livestream']).isNotEmpty
        ? _pkAsMap(nested['sender_livestream'])
        : _pkAsMap(liveController.pkSenderLiveData));
    final fromLive = _pkUserFromLiveData(live);
    if (fromLive.isNotEmpty) return fromLive;

    final broadcasterUser = _pkAsMap(broadcasterData['user']);
    if (_pkToInt(broadcasterUser['id']) ==
        liveController.pkSenderHostId.value) {
      return broadcasterUser;
    }

    final int hostId = liveController.pkSenderHostId.value > 0
        ? liveController.pkSenderHostId.value
        : _pkToInt(data['sender_host_id'] ?? nested['sender_host_id']);

    return <String, dynamic>{
      'id': hostId,
      'user_id': hostId,
      'name': hostId > 0 ? 'Host $hostId' : ('Host').appTr,
      'profile_image': null,
    };
  }

  Map<String, dynamic> _pkReceiverUser() {
    final data = _pkAsMap(liveController.currentPkData);
    final nested = _pkAsMap(data['data']);

    final direct = _pkAsMap(data['receiver_host']);
    if (direct.isNotEmpty) return direct;

    final nestedDirect = _pkAsMap(nested['receiver_host']);
    if (nestedDirect.isNotEmpty) return nestedDirect;

    final live = _pkAsMap(data['receiver_livestream']).isNotEmpty
        ? _pkAsMap(data['receiver_livestream'])
        : (_pkAsMap(nested['receiver_livestream']).isNotEmpty
        ? _pkAsMap(nested['receiver_livestream'])
        : _pkAsMap(liveController.pkReceiverLiveData));
    final fromLive = _pkUserFromLiveData(live);
    if (fromLive.isNotEmpty) return fromLive;

    final broadcasterUser = _pkAsMap(broadcasterData['user']);
    if (_pkToInt(broadcasterUser['id']) ==
        liveController.pkReceiverHostId.value) {
      return broadcasterUser;
    }

    final int hostId = liveController.pkReceiverHostId.value > 0
        ? liveController.pkReceiverHostId.value
        : _pkToInt(data['receiver_host_id'] ?? nested['receiver_host_id']);

    return <String, dynamic>{
      'id': hostId,
      'user_id': hostId,
      'name': hostId > 0 ? 'Host $hostId' : 'Opponent',
      'profile_image': null,
    };
  }

  bool _joinedStreamIsSenderSide() {
    final int joinedStreamId = _safeStreamId();
    final int senderStreamId = liveController.pkSenderLivestreamId.value;
    final int receiverStreamId = liveController.pkReceiverLivestreamId.value;

    if (joinedStreamId > 0 &&
        senderStreamId > 0 &&
        joinedStreamId == senderStreamId) {
      return true;
    }
    if (joinedStreamId > 0 &&
        receiverStreamId > 0 &&
        joinedStreamId == receiverStreamId) {
      return false;
    }

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (_isSamePkHost(
      currentUid: currentUserId,
      hostId: liveController.pkSenderHostId.value,
    )) {
      return true;
    }
    if (_isSamePkHost(
      currentUid: currentUserId,
      hostId: liveController.pkReceiverHostId.value,
    )) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> _pkDisplaySide({required bool rightSide}) {
    // Right side is always OUR/JOINED side. Left side is always the opponent.
    final bool joinedIsSender = _joinedStreamIsSenderSide();
    final bool useSender = rightSide ? joinedIsSender : !joinedIsSender;

    final int senderScore = liveController.pkSenderScore.value;
    final int receiverScore = liveController.pkReceiverScore.value;

    final int senderViewerCount = liveController.pkSenderViewerCount.value;
    final int receiverViewerCount = liveController.pkReceiverViewerCount.value;

    if (useSender) {
      return <String, dynamic>{
        'is_sender_side': true,
        'host_id': liveController.pkSenderHostId.value,
        'stream_id': liveController.pkSenderLivestreamId.value,
        'score': senderScore,
        'viewer_count': senderViewerCount,
        'user': _pkSenderUser(),
        'side_label': rightSide ? 'OUR SIDE' : 'OTHER SIDE',
      };
    }

    return <String, dynamic>{
      'is_sender_side': false,
      'host_id': liveController.pkReceiverHostId.value,
      'stream_id': liveController.pkReceiverLivestreamId.value,
      'score': receiverScore,
      'viewer_count': receiverViewerCount,
      'user': _pkReceiverUser(),
      'side_label': rightSide ? 'OUR SIDE' : 'OTHER SIDE',
    };
  }

  String _pkProfileImageUrl(Map<String, dynamic> user) {
    final raw = '${user['profile_image'] ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return '';
    return raw.startsWith('http') ? raw : ImageHelper.getImageUrl(raw);
  }

  Widget _pkBlurProfilePlaceholder(
      Map<String, dynamic> user, {
        String label = 'Connecting camera...',
        bool waiting = false,
      }) {
    final String imageUrl = _pkProfileImageUrl(user);
    final String name = '${user['name'] ?? 'Host'}';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Container(color: Colors.black.withOpacity(.36)),
            ),
          )
        else
          Container(color: Colors.black.withOpacity(.36)),
        Container(color: Colors.black.withOpacity(.44)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withOpacity(.18),
                backgroundImage: imageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 34,
                )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                waiting ? ('Waiting for host...').appTr : label,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pkVideoForHost({
    required int hostId,
    required String label,
    required bool leftSide,
    required Map<String, dynamic> user,
    required int score,
    required int viewerCount,
  }) {
    final engine = _agoraService.engine;
    final channelId = _activeAgoraChannelForVideo();
    final currentUid = authController.userProfile.value.user?.id?.toInt() ?? 0;
    final int remoteAgoraUid = _pkAgoraRenderUidFromHostId(hostId);
    final bool isLocalHost =
        _isSamePkHost(currentUid: currentUid, hostId: hostId) &&
            widget.isBroadcaster;
    final bool remoteOnline = isLocalHost || _isPkRemoteHostOnline(hostId);

    final bool isSpeaking =
        _isUserSpeaking(hostId) ||
            _isUserSpeaking(remoteAgoraUid) ||
            (isLocalHost && _isUserSpeaking(currentUid));

    Widget video;
    if (engine == null || channelId.isEmpty || hostId <= 0) {
      video = _pkBlurProfilePlaceholder(user);
    } else if (isLocalHost) {
      video = AgoraVideoView(
        key: ValueKey('pk_local_video_${channelId}_$currentUid'),
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else if (!remoteOnline) {
      video = _pkBlurProfilePlaceholder(user, waiting: true);
    } else {
      video = AgoraVideoView(
        key: ValueKey('pk_remote_video_${channelId}_$remoteAgoraUid'),
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: remoteAgoraUid),
          connection: RtcConnection(channelId: channelId),
        ),
      );
    }

    final Color sideColor = leftSide
        ? const Color(0xffff2d75)
        : const Color(0xff27a7ff);
    final Color glowColor = isSpeaking
        ? (leftSide ? const Color(0xffffe66d) : const Color(0xff7dfffb))
        : sideColor;
    final String name = '${user['name'] ?? 'Host'}';
    final String uid = '${user['user_id'] ?? user['id'] ?? hostId}';

    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: leftSide ? -0.18 : 0.18, end: 0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (_, dx, child) => Transform.translate(
          offset: Offset(dx * Get.width, 0),
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: kHeight * 0.345,

          padding: EdgeInsets.all(isSpeaking ? 1 : .3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                glowColor.withOpacity(isSpeaking ? .98 : .88),
                sideColor.withOpacity(.75),
                Colors.white.withOpacity(.22),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isSpeaking ? .45 : .22),
                blurRadius: isSpeaking ? 24 : 13,
                spreadRadius: isSpeaking ? 2 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                video,
                if (isSpeaking)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: SpeakingCardWave(borderRadius: 1),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(.08),
                            Colors.transparent,
                            Colors.black.withOpacity(.50),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: leftSide ? 8 : null,
                  right: leftSide ? null : 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.48),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(.22)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!leftSide)
                          _pkSpeakingBars(isSpeaking, leftSide: leftSide),
                        if (!leftSide) const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                        if (leftSide) const SizedBox(width: 6),
                        if (leftSide)
                          _pkSpeakingBars(isSpeaking, leftSide: leftSide),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.48),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.18)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white.withOpacity(.18),
                          backgroundImage: _pkProfileImageUrl(user).isNotEmpty
                              ? CachedNetworkImageProvider(
                            _pkProfileImageUrl(user),
                          )
                              : null,
                          child: _pkProfileImageUrl(user).isEmpty
                              ? const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 13,
                          )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                ('ID $uid').appTr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 8.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: leftSide
                                  ? [
                                const Color(0xffff1744),
                                const Color(0xffff8a00),
                              ]
                                  : [
                                const Color(0xff00c8ff),
                                const Color(0xff0077ff),
                              ],
                            ),
                          ),
                          child: Text(
                            '$score',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRealPkVideoOverlay() {
    final leftSide = _pkDisplaySide(rightSide: false); // opponent
    final rightSide = _pkDisplaySide(rightSide: true); // our joined side

    final int leftScore = _pkToInt(leftSide['score']);
    final int rightScore = _pkToInt(rightSide['score']);
    final int total = (leftScore + rightScore) <= 0
        ? 1
        : (leftScore + rightScore);

    final int leftFlex = ((leftScore / total) * 1000)
        .round()
        .clamp(1, 999)
        .toInt();
    final int rightFlex = (1000 - leftFlex).clamp(1, 999).toInt();

    final leftUser = _pkAsMap(leftSide['user']);
    final rightUser = _pkAsMap(rightSide['user']);

    return IgnorePointer(
      ignoring: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _pkVideoForHost(
                hostId: _pkToInt(leftSide['host_id']),
                label: ('OTHER SIDE').appTr,
                leftSide: true,
                user: leftUser,
                score: leftScore,
                viewerCount: _pkToInt(leftSide['viewer_count']),
              ),
              _pkVideoForHost(
                hostId: _pkToInt(rightSide['host_id']),
                label: ('OUR SIDE').appTr,
                leftSide: false,
                user: rightUser,
                score: rightScore,
                viewerCount: _pkToInt(rightSide['viewer_count']),
              ),
            ],
          ),
          // Transform.translate(
          //   offset: const Offset(0, -20),
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          //     decoration: BoxDecoration(
          //       borderRadius: BorderRadius.circular(999),
          //       gradient: const LinearGradient(colors: [Color(0xffff2d75), Color(0xff7a4dff), Color(0xff27a7ff)]),
          //       border: Border.all(color: Colors.white.withOpacity(.30)),
          //       boxShadow: [BoxShadow(color: Colors.black.withOpacity(.32), blurRadius: 15, offset: const Offset(0, 5))],
          //     ),
          //     child: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Container(
          //           height: 25,
          //           width: 25,
          //           decoration: BoxDecoration(
          //             shape: BoxShape.circle,
          //             color: Colors.white.withOpacity(.16),
          //           ),
          //           child: const Center(
          //             child: Text(('PK').appTr, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
          //           ),
          //         ),
          //         const SizedBox(width: 8),
          //         Obx(() => Text(
          //           liveController.pkFormattedRemainingTime,
          //           style: GoogleFonts.poppins(
          //             color: Colors.white,
          //             fontWeight: FontWeight.w900,
          //             fontSize: 13,
          //             letterSpacing: .2,
          //           ),
          //         )),
          //         if (widget.isBroadcaster) ...[
          //           const SizedBox(width: 10),
          //           GestureDetector(
          //             onTap: () => liveController.endPk(),
          //             child: Container(
          //               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          //               decoration: BoxDecoration(
          //                 color: Colors.white.withOpacity(.18),
          //                 borderRadius: BorderRadius.circular(999),
          //                 border: Border.all(color: Colors.white.withOpacity(.18)),
          //               ),
          //               child: const Text(
          //                 'End',
          //                 style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          //               ),
          //             ),
          //           ),
          //         ],
          //       ],
          //     ),
          //   ),
          // ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withOpacity(.16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  children: [
                    Expanded(
                      flex: leftFlex,
                      child: Container(
                        height: 14,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xffff005d), Color(0xffff8a00)],
                          ),
                        ),
                        child: Text(
                          ('Other $leftScore').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 14,
                      color: Colors.white.withOpacity(.9),
                    ),
                    Expanded(
                      flex: rightFlex,
                      child: Container(
                        height: 14,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xff00c8ff), Color(0xff0077ff)],
                          ),
                        ),
                        child: Text(
                          ('Our $rightScore').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPkStartIntroOverlay() {
    return Obx(() {
      if (!liveController.pkStartIntroVisible.value) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(
                'pk_start_${liveController.currentPkId.value}_${liveController.pkStartIntroText.value}',
              ),
              tween: Tween<double>(begin: .50, end: 1.10),
              duration: const Duration(milliseconds: 680),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xffff1744),
                      Color(0xff6a00ff),
                      Color(0xff00b8ff),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(.35),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withOpacity(.55),
                      blurRadius: 38,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(.35),
                      blurRadius: 48,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  liveController.pkStartIntroText.value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPkBigCountdownOverlay() {
    return Obx(() {
      final int sec = liveController.pkRemainingSeconds.value;
      if (!liveController.pkIsRunning.value || sec <= 0 || sec > 3) {
        return const SizedBox.shrink();
      }

      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('pk_big_countdown_$sec'),
              tween: Tween<double>(begin: .35, end: 1.22),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: (1.35 - scale).clamp(.0, 1.0).toDouble(),
                    child: Text(
                      '$sec',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 118,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(color: Color(0xffff2d75), blurRadius: 34),
                          Shadow(color: Color(0xff27a7ff), blurRadius: 44),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPkResultPreviewOverlay() {
    return Obx(() {
      if (!liveController.pkResultVisible.value) {
        return const SizedBox.shrink();
      }

      final String controllerText = liveController.pkResultText.value
          .trim()
          .toUpperCase();
      final String dataText =
      '${liveController.pkResultData['result_text'] ?? ''}'
          .trim()
          .toUpperCase();
      final String text = controllerText.isNotEmpty
          ? controllerText
          : (dataText.isNotEmpty ? dataText : 'DRAW');

      final bool isDraw = text == 'DRAW';
      final bool win = text == 'WIN';

      final IconData icon = isDraw
          ? Icons.handshake_rounded
          : win
          ? Icons.emoji_events_rounded
          : Icons.heart_broken_rounded;

      final List<Color> colors = isDraw
          ? [const Color(0xffffb300), const Color(0xffff6f00)]
          : win
          ? [const Color(0xff00d084), const Color(0xff00b8ff)]
          : [const Color(0xffff1744), const Color(0xff6a00ff)];

      return Positioned.fill(
        child: IgnorePointer(
          child: Container(
            color: Colors.black.withOpacity(.18),
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('pk_result_$text'),
                tween: Tween(begin: .72, end: 1.0),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(colors: colors),
                    border: Border.all(
                      color: Colors.white.withOpacity(.34),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.first.withOpacity(.52),
                        blurRadius: 35,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 42),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  //Pk match

  Future giftBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xff16261c),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // **Premium Banner**
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff24a177),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(Icons.close, color: Colors.red),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // **Title**
            Text(
              ("Choose Your Gift 🎁").appTr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),

            // **Gift GridView**
            Obx(() {
              return livestreamController.giftList.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  ("No gifts available 😔").appTr,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              )
                  : Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisExtent: 120,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: livestreamController.giftList.length,
                  itemBuilder: (context, index) {
                    final gift = livestreamController.giftList[index];
                    bool isSelected =
                        livestreamController.selectedGiftId.value ==
                            gift['id'];
                    return GestureDetector(
                      onTap: () {
                        livestreamController.selectedGiftId.value =
                        gift['id'];
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(0xff16261c)
                              : Color(0xff16261c),
                          border: Border.all(
                            color: isSelected
                                ? Color(0xff24a177)
                                : Color(0xff16261c),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // **Gift Image**
                            gift['gift_image'].toString().endsWith(
                              '.svga',
                            )
                                ? SizedBox(
                              height: kHeight * 0.05,
                              width: kHeight * 0.05,
                              child: SVGAEasyPlayer(
                                resUrl:
                                "$kDomainUrl/${gift['gift_image']}",
                                fit: BoxFit.cover,
                              ),
                            )
                                : ClipRRect(
                              borderRadius: BorderRadius.circular(
                                10,
                              ),
                              child: Image.network(
                                "$kDomainUrl/${gift['gift_image']}",
                                height: 50,
                                width: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: 8),

                            // **Gift Name**
                            Text(
                              gift['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),

                            // **Gift Coin Price**
                            Center(
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Image(
                                    image: AssetImage(
                                      'assets/icons/coin.png',
                                    ),
                                    height: 10,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    "${gift['coin']}  ",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
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
              );
            }),

            SizedBox(height: 16),

            Obx(() {
              return livestreamController.selectedGiftId.value != 0
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final int selectedGiftPrice =
                      _selectedGiftCoinPrice();
                      if (selectedGiftPrice <= 0) {
                        Fluttertoast.showToast(
                          msg: ('Gift price not found').appTr,
                          gravity: ToastGravity.BOTTOM,
                        );
                        return;
                      }

                      livestreamController.tryToSendGift(
                        receiverId:
                        livestreamController.broadcasterId.value,
                        giftId: livestreamController.selectedGiftId.value,
                        giftPrice: selectedGiftPrice,
                      );

                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 10,
                      ),
                      backgroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        ("Send").appTr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  : SizedBox();
            }),
          ],
        ),
      ),
    );
  }
}

class SpeakingWave extends StatefulWidget {
  final double size;

  const SpeakingWave({super.key, required this.size});

  @override
  State<SpeakingWave> createState() => _SpeakingWaveState();
}

class _SpeakingWaveState extends State<SpeakingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: .88,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(
      begin: .85,
      end: .25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              height: widget.size,
              width: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(_opacity.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(_opacity.value * .45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PkGridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = .55;

    const double gap = 18;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpeakingCardWave extends StatefulWidget {
  final double borderRadius;

  const SpeakingCardWave({super.key, required this.borderRadius});

  @override
  State<SpeakingCardWave> createState() => _SpeakingCardWaveState();
}

class _SpeakingCardWaveState extends State<SpeakingCardWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _spread;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..repeat(reverse: true);

    _spread = Tween<double>(
      begin: 1.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(
      begin: .70,
      end: .22,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(_opacity.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(_opacity.value * .55),
                  blurRadius: 18,
                  spreadRadius: _spread.value,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SmallMuteBadge extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final bool compact;

  const _SmallMuteBadge({
    required this.fontSize,
    required this.iconSize,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.65), width: .6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off, color: Colors.white, size: iconSize),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              ('Mute').appTr,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassCallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _GlassCallButton({
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: kHeight * 0.062,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glass shine overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kHeight * 0.031,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: kHeight * 0.016,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
