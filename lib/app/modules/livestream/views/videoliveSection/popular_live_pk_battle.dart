part of '../popular_live_view.dart';

/// PK (host-vs-host video battle) system: Agora channel switching for PK,
/// PK video rendering, intro/countdown/result overlays, and related
/// state helpers. Extracted from _PopularLiveViewState during
/// file-splitting refactor — pure logic move only, no behavior changes.
extension PopularLivePkBattle on _PopularLiveViewState {
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
    final arg = streamData;
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
      final String rendererKey = 'pk_local_video_${channelId}_$currentUid';
      video = _stablePkVideoRenderers.putIfAbsent(
        rendererKey,
            () => AgoraVideoView(
          key: ValueKey<String>(rendererKey),
          controller: VideoViewController(
            rtcEngine: engine,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      );
    } else if (!remoteOnline) {
      video = _pkBlurProfilePlaceholder(user, waiting: true);
    } else {
      final String rendererKey =
          'pk_remote_video_${channelId}_$remoteAgoraUid';
      video = _stablePkVideoRenderers.putIfAbsent(
        rendererKey,
            () => AgoraVideoView(
          key: ValueKey<String>(rendererKey),
          controller: VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: remoteAgoraUid),
            connection: RtcConnection(channelId: channelId),
          ),
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

}