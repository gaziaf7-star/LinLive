part of '../popular_live_view.dart';

/// Agora engine safety wrappers, broadcaster/audience stream-data setup,
/// and safe event-handler registration. Extracted from
/// _PopularLiveViewState during file-splitting refactor — pure logic
/// move only, no behavior changes.
extension PopularLiveAgoraSafety on _PopularLiveViewState {
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
    // Apply the canonical route owner synchronously. The first caller is a
    // seat user, not an authoritative broadcaster fallback.
    final live = streamData['livestreamdata'] is Map
        ? Map<String, dynamic>.from(streamData['livestreamdata'])
        : streamData['livestream'] is Map
        ? Map<String, dynamic>.from(streamData['livestream'])
        : <String, dynamic>{};
    final user = streamData['user'] is Map
        ? Map<String, dynamic>.from(streamData['user'])
        : live['user'] is Map
        ? Map<String, dynamic>.from(live['user'])
        : <String, dynamic>{};
    streamInfo.value = streamData;
    broadcasterData.value = <String, dynamic>{...live, ...streamData, 'user': user};
    liveController.broadcasterId.value = _safeUserId(broadcasterData);
    _bootstrapPkStateFromArguments(source: 'audience_stream_data');

    await liveController.tryToGetCallList(streamId: streamData['id']);

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
              isSpeaking: volume >= _PopularLiveViewState._speakingVolumeThreshold,
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
}