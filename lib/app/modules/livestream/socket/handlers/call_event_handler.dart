part of '../websocket_controller.dart';

extension CallEventHandler on WebsocketController {
  Future<void> _handleUnifiedCallerLeft(Map<String, dynamic> payload) async {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? {
        ...Map<String, dynamic>.from(payload),
        ...Map<String, dynamic>.from(payload['data']),
      }
          : Map<String, dynamic>.from(payload);

      _cacheLiveUserProfileFromPayload(data);
      livestreamController.syncVipStateFromPayload(data);

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
      final bool videoMediaStillActive = _isVideoCallerMediaStillActive(uidInt);

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
      if (_isWeakCallerTimeoutReason(reason)) {
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
      final int rtOccupiedBefore = kDebugMode
          ? LiveRealtimeDebugLog.seatEntries(liveCallList).length
          : 0;
      liveCallList.removeWhere((call) {
        if (call is! Map) return false;
        final callerId = call['caller_id'];
        final userIdField = call['user_id'];
        final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
        return callerId.toString() == uid ||
            userIdField.toString() == uid ||
            nestedUserId.toString() == uid;
      });
      if (kDebugMode) {
        debugPrint(
          'SEAT_RELEASE room=${_toInt(livestreamId)} '
              'seat=$seatNo user=$uidInt',
        );
      }
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
        'SEAT_RELEASE',
        streamId: _toInt(livestreamId),
        userId: uidInt,
        seatNo: seatNo,
        status: 'removed',
        reason: reason.isEmpty ? 'caller_left' : reason,
        beforeCount: beforeCallRemoveCount,
        afterCount: liveCallList.length,
        note: 'viewerCount=${livestreamController.liveViewerList.length}',
      );
      LiveRealtimeDebugLog.event('CALL_END', <String, Object?>{
        'room': _toInt(livestreamId),
        'user': uidInt,
        'seat': seatNo,
        'status': 'left',
        'event_id': data['event_id'],
        'reason': reason,
      });
      LiveRealtimeDebugLog.event('SEAT_LEFT', <String, Object?>{
        'room': _toInt(livestreamId),
        'seat': seatNo,
        'user': uidInt,
        'reason': reason,
        'occupied_before': rtOccupiedBefore,
        'occupied_after': kDebugMode
            ? LiveRealtimeDebugLog.seatEntries(liveCallList).length
            : 0,
      });
      _rtSeats(data);
      _rtState(data);
    } catch (e, st) {
      liveLog('❌ _handleUnifiedCallerLeft error => $e\n$st');
    }
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
    final bool mutedByHost =
        _mutedFlagValue(callData['is_muted_by_host']) ?? false;

    callData['audio_on'] = audioOn;
    callData['is_audio_on'] = audioOn;
    callData['is_muted'] = audioOn == 1 ? 0 : 1;
    callData['is_muted_by_host'] = mutedByHost ? 1 : 0;
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

      if (_normalizeAudioOn(call) == 0) return true;
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
      // Local republish changes the user's mic state, not host moderation.
      call['is_muted_by_host'] = call['is_muted_by_host'] ?? 0;

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
    liveLog(
      '✅ Self seat mic state synced => $reason user:$currentUserId muted:$muted',
    );
  }

  Future<void> _forceRepublishMySeatMic({required String reason}) async {
    /// Agora sometimes stays silent after seat leave/rejoin unless the mic
    /// is re-published with ChannelMediaOptions again.
    /// But user-er manual mute state preserve korte hobe.
    final bool keepMuted = _isSelfMutedNow();
    final int currentUserId = _currentUserIdInt();
    if (_selfMicPublishedUserId == currentUserId &&
        _selfMicPublishedMuted == keepMuted) {
      return;
    }
    final engine = _agoraService.engine;
    if (engine == null) {
      liveLog(
        '⚠️ Seat mic republish skipped: Agora engine not ready => $reason',
      );
      return;
    }
    _markSelfSeatMicStateInState(reason: reason, muted: keepMuted);

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
      _selfMicPublishedUserId = currentUserId;
      _selfMicPublishedMuted = keepMuted;
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
          await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
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
      await applyRemoteAudioMuteIfChanged(
        userId: userId,
        muted: true,
        reason: reason,
      );
      liveLog(
        '🔇 Remote caller audio stopped after seat exit => user:$userId reason:$reason',
      );
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
    livestreamController.syncVipStateFromPayload(<String, dynamic>{
      ...payload,
      'user': callData['user'] ?? payload['user'],
    });

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
    if (streamID.value.toString().isEmpty && livestreamId != null) {
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
      printSeatTrace(
        'live_call_missing_user',
        streamId: _toInt(livestreamId),
        error: 'caller_id_missing',
      );
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
                !_truthy(
                  payload['requires_host_acceptance'] ??
                      callData['requires_host_acceptance'],
                ));

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
      } else if (actionType == 'multi_live_seat_joined' ||
          actionType == 'seat_updated' ||
          actionType == 'seat_joined' ||
          actionType == 'live_seat_joined') {
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
    int seatEventRevision = _eventTimeMs(
      callData['event_timestamp'] ??
          callData['occurred_at'] ??
          callData['updated_at'] ??
          callData['created_at'] ??
          payload['timestamp'],
    );
    if (seatEventRevision == 0) {
      final matches = RegExp(
        r'(\d{10,13})',
      ).allMatches((payload['event_id'] ?? '').toString()).toList();
      if (matches.isNotEmpty) {
        seatEventRevision = _eventTimeMs(matches.last.group(1));
      }
    }
    final String callSessionId =
    (callData['call_session_id'] ??
        callData['request_id'] ??
        payload['call_session_id'] ??
        payload['request_id'] ??
        '')
        .toString()
        .trim();
    final String callPrefix = '${_toInt(livestreamId)}:$callerId:';
    final String logicalCallKey =
        '$callPrefix${callSessionId.isNotEmpty ? callSessionId : eventSeatNo}';
    final bool terminalCallStatus =
        callStatus == 'canceled' ||
            callStatus == 'cancelled' ||
            callStatus == 'rejected' ||
            callStatus == 'left' ||
            callStatus == 'ended' ||
            callStatus == 'end' ||
            callStatus == 'seat_leave' ||
            callStatus == 'seat_left';
    if (callStatus == 'pending' ||
        callStatus == 'accepted' ||
        callStatus == 'joined') {
      _terminalCallSessions.removeWhere((key, _) => key.startsWith(callPrefix));
    } else if (terminalCallStatus) {
      if (_terminalCallSessions.containsKey(logicalCallKey)) {
        LiveRealtimeDebugLog.event(
          'CALL_TERMINAL_DUPLICATE_IGNORED',
          <String, Object?>{
            'room': _toInt(livestreamId),
            'user': callerId,
            'seat': eventSeatNo,
            'status': callStatus,
            'session': callSessionId,
          },
        );
        return;
      }
      _terminalCallSessions[logicalCallKey] =
          DateTime.now().millisecondsSinceEpoch;
      while (_terminalCallSessions.length >
          WebsocketController._maxTerminalCallSessions) {
        _terminalCallSessions.remove(_terminalCallSessions.keys.first);
      }
    }
    final int rtOccupiedBefore = kDebugMode
        ? LiveRealtimeDebugLog.seatEntries(liveCallList).length
        : 0;
    final String rtCallTag =
    (callStatus == 'accepted' || callStatus == 'joined')
        ? 'CALL_ACCEPT'
        : callStatus == 'pending'
        ? 'CALL_REQUEST'
        : (callStatus == 'rejected' || callStatus == 'canceled')
        ? 'CALL_REJECT'
        : 'CALL_END';
    LiveRealtimeDebugLog.event(rtCallTag, <String, Object?>{
      'room': _toInt(livestreamId),
      'user': callerId,
      'seat': eventSeatNo,
      'status': callStatus,
      'event_id': payload['event_id'],
    });

    /// Audio live has no pending host-confirmation call flow. Drop any stale
    /// pending frame instead of converting it to accepted (which could re-add a
    /// user after leave).
    if (audioRoom && callStatus == 'pending') {
      pendingCall.removeWhere((raw) {
        return raw is Map &&
            _callUserId(Map<String, dynamic>.from(raw)) == callerId;
      });
      pendingCall.refresh();
      _activeCallPopupKeys.removeWhere(
            (key) => key.startsWith('${_toInt(livestreamId)}_${_toInt(callerId)}_'),
      );
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
      final int previousSeatRevision = _seatRevisionByUser[callerId] ?? 0;
      if (seatEventRevision > 0 && seatEventRevision < previousSeatRevision) {
        LiveRealtimeDebugLog.event(
          'STALE_SEAT_EVENT_IGNORED',
          <String, Object?>{
            'room': _toInt(livestreamId),
            'user': callerId,
            'seat': eventSeatNo,
            'event_id': payload['event_id'],
          },
        );
        return;
      }
      _seatRevisionByUser[callerId] = seatEventRevision > 0
          ? seatEventRevision
          : DateTime.now().millisecondsSinceEpoch;
      livestreamController.clearDepartedCallerGuard(callerId);
      _activeCallPopupKeys.remove(popupKey);
      _handledCallPopupKeys.add(popupKey);

      pendingCall.removeWhere(
            (call) => call['caller_id'].toString() == callerId.toString(),
      );

      if (eventSeatNo > 0) {
        final int acceptedUserId = _toInt(callerId);
        final bool occupiedByOther = liveCallList.any((raw) {
          if (raw is! Map) return false;
          final old = Map<String, dynamic>.from(raw);
          final oldUserId = _callUserId(old);
          final oldSeatNo = _toInt(
            old['seat_no'] ?? old['seat'] ?? old['seat_number'],
          );
          return oldSeatNo == eventSeatNo && oldUserId != acceptedUserId;
        });
        if (occupiedByOther) {
          LiveRealtimeDebugLog.event(
            'SEAT_CONFLICT_RECONCILE',
            <String, Object?>{
              'room': _toInt(livestreamId),
              'user': callerId,
              'seat': eventSeatNo,
              'source': actionType.isEmpty ? action : actionType,
            },
          );
          unawaited(
            livestreamController.tryToGetCallList(
              streamId: _toInt(livestreamId),
              force: true,
            ),
          );
          return;
        }
        // A realtime seat delta is authoritative for this one seat. Remove a
        // previous occupant of the same seat and any old seat row for this
        // user before the normal rich-profile merge below. Duplicate delivery
        // remains idempotent because the matching user row is retained.
        liveCallList.removeWhere((raw) {
          if (raw is! Map) return false;
          final old = Map<String, dynamic>.from(raw);
          final oldUserId = _callUserId(old);
          final oldSeatNo = _toInt(
            old['seat_no'] ?? old['seat'] ?? old['seat_number'],
          );
          return (oldSeatNo == eventSeatNo && oldUserId != acceptedUserId) ||
              (oldUserId == acceptedUserId && oldSeatNo != eventSeatNo);
        });
        if (kDebugMode) {
          debugPrint(
            'SEAT_UPSERT room=${_toInt(livestreamId)} '
                'seat=$eventSeatNo user=$callerId',
          );
        }
      }

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

          if (merged['user'] is Map) {
            final richUser = Map<String, dynamic>.from(merged['user']);
            for (final key in const <String>[
              'vip_purchase_history',
              'vipPurchaseHistory',
              'asset_purchase_histories',
              'profile_frame_history',
            ]) {
              if ((richUser[key] == null ||
                  (richUser[key] is Map && richUser[key].isEmpty)) &&
                  oldUser[key] != null) {
                richUser[key] = oldUser[key];
              }
            }
            merged['user'] = richUser;
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
          final bool mergedMutedByHost =
              _mutedFlagValue(
                callData.containsKey('is_muted_by_host')
                    ? callData['is_muted_by_host']
                    : old['is_muted_by_host'],
              ) ??
                  false;
          merged['is_muted_by_host'] = mergedMutedByHost ? 1 : 0;
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
      } else {
        final bool effectiveMuted = audioMutedUserMap[callerId] ?? false;
        await applyRemoteAudioMuteIfChanged(
          userId: callerId,
          muted: effectiveMuted,
          reason: 'seat_join_or_accept',
        );
      }

      LiveRealtimeDebugLog.event('SEAT_AUDIO_STATE', <String, Object?>{
        'room': _toInt(livestreamId),
        'user': callerId,
        'seat': eventSeatNo,
        'muted': audioMutedUserMap[callerId] ?? false,
      });

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
      // ✅ FIX: see _ensureViewerPresenceForAcceptedSeat. Without this, a
      // seated user whose own viewer_joined event never registered locally
      // stayed missing from the viewer list forever, so the viewer count
      // could read lower than the number of occupied seats.
      _ensureViewerPresenceForAcceptedSeat(callData);
      LiveRealtimeDebugLog.event('SEAT_JOIN', <String, Object?>{
        'room': _toInt(livestreamId),
        'seat': eventSeatNo,
        'user': callerId,
        'name': callData['user'] is Map ? callData['user']['name'] : null,
        'source': actionType.isEmpty ? action : actionType,
        'occupied_before': rtOccupiedBefore,
        'occupied_after': kDebugMode
            ? LiveRealtimeDebugLog.seatEntries(liveCallList).length
            : 0,
      });
      _rtSeats(payload);
      _rtState(payload);
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

      final int leavingUserId = int.tryParse(callerId.toString()) ?? 0;
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
}