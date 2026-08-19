part of '../popular_live_view.dart';

/// Video-live prepare/enter/exit/minimize/end lifecycle flow (everything
/// around join/leave, not the @override initState/dispose themselves,
/// which must stay directly on the State class per Dart's extension
/// rules). Extracted from _PopularLiveViewState during file-splitting
/// refactor — pure logic move only, no behavior changes.
extension PopularLiveLifecycle on _PopularLiveViewState {
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

  /// Video live keeps the Android status bar visible but hides the bottom
  /// system navigation/back/home bar, matching the reference live UI.
  Future<void> _enterVideoLiveSystemUi() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const <SystemUiOverlay>[SystemUiOverlay.top],
      );
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      );
    } catch (e) {
      debugPrint('Video live system UI hide skipped safely: $e');
    }
  }

  Future<void> _restoreSystemUiAfterVideoLive() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      debugPrint('Video live system UI restore skipped safely: $e');
    }
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

    final args = Map<String, dynamic>.from(streamData);
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

      // Soft leave only: keep the permanent room active so pressing Create
      // Live later rejoins this same room instead of creating a new one.
      await liveController.leavePermanentRoom(
        livestreamId: _safeStreamId(),
      );

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

}