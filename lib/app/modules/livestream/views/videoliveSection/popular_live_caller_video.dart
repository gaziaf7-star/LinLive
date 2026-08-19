part of '../popular_live_view.dart';

/// Caller/broadcaster video rendering: accepted-caller overlay cards,
/// stable video-renderer caching, remote-subscription reconciliation,
/// and the broadcast view builders. Extracted from _PopularLiveViewState
/// during file-splitting refactor — pure logic move only, no behavior
/// changes.
extension PopularLiveCallerVideo on _PopularLiveViewState {
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

}