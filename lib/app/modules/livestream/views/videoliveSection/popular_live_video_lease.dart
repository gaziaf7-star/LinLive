part of '../popular_live_view.dart';

/// Video-call presence lease/cache management, and the battery-based
/// video-quality guard. Extracted from _PopularLiveViewState during
/// file-splitting refactor — pure logic move only, no behavior changes.
/// Related fields (_batteryGuardTimer, _batteryGuardOptimizer, etc.)
/// remain in the main state class, as Dart extensions cannot declare
/// instance fields.
extension PopularLiveVideoLease on _PopularLiveViewState {
  void _startBatteryVideoGuard() {
    _batteryGuardTimer ??= Timer.periodic(
      const Duration(seconds: 60),
          (_) => _checkBatteryVideoGuard(),
    );
  }

  Future<void> _checkBatteryVideoGuard() async {
    if (!mounted || _agoraService.engine == null) return;
    try {
      final int level = await _batteryGuardOptimizer.getCurrentBatteryLevel();
      final bool critical = level <= BatteryOptimizer.criticalBatteryThreshold;
      if (critical && !_batteryGuardVideoDisabled) {
        _batteryGuardVideoDisabled = true;
        await _agoraService.engine!.enableLocalVideo(false);
        debugPrint('🔋 Critical battery ($level%) => local video paused');
      } else if (!critical && _batteryGuardVideoDisabled) {
        _batteryGuardVideoDisabled = false;
        if (widget.isBroadcaster) {
          await _agoraService.engine!.enableLocalVideo(true);
          debugPrint('🔋 Battery recovered ($level%) => local video resumed');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Battery video guard skipped: $e');
    }
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
      if (lastSeen <= 0 || nowMs - lastSeen >= _PopularLiveViewState._videoCallOfflineGraceMs) {
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
}