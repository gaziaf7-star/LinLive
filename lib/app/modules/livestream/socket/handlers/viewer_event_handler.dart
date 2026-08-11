part of '../websocket_controller.dart';

extension ViewerEventHandler on WebsocketController {
  void reconcileSelfViewerJoinFromApi({
    required int livestreamId,
    required int viewerId,
    required Map<String, dynamic> response,
  }) {
    if (livestreamId <= 0 || viewerId <= 0 || !_isCurrentStream(livestreamId)) {
      return;
    }
    final root = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : response;
    final rawViewer = root['viewer'] ?? root['viewer_data'];
    final viewer = rawViewer is Map
        ? Map<String, dynamic>.from(rawViewer)
        : <String, dynamic>{};
    final rawUser = viewer['user'] ?? root['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : _safeAuthUserForSystemComment(viewerId);
    _handleUnifiedViewer({
      'action_type': 'viewer_joined',
      'livestream_id': livestreamId,
      'viewer_id': viewerId,
      'viewer_data': {
        ...viewer,
        'viewer_id': viewerId,
        'user_id': viewerId,
        'livestream_id': livestreamId,
        'user': user,
      },
      'user': user,
    }, 'viewer_joined');
  }

  void showEntryAnimation() {
    newViewersJoinded.value = true;
  }

  /// Entry/SVGA full play sesh hole widget theke eta call korben.
  void hideEntryAnimation({bool clearData = true}) {
    _entryAnimationSafetyTimer?.cancel();
    _entryAnimationSafetyTimer = null;
    newViewersJoinded.value = false;
    if (clearData) {
      newJoinedUserData.value = {};
    }
    newViewerAction.value = 'join';
  }

  int _entryUserIdFromData(dynamic data) {
    try {
      final root = data is Map<String, dynamic>
          ? data
          : data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};

      final user = root['user'] is Map<String, dynamic>
          ? root['user']
          : root['user'] is Map
          ? Map<String, dynamic>.from(root['user'])
          : <String, dynamic>{};

      final viewerData = root['viewer_data'] is Map<String, dynamic>
          ? root['viewer_data']
          : root['viewer_data'] is Map
          ? Map<String, dynamic>.from(root['viewer_data'])
          : <String, dynamic>{};

      final viewerUser = viewerData['user'] is Map<String, dynamic>
          ? viewerData['user']
          : viewerData['user'] is Map
          ? Map<String, dynamic>.from(viewerData['user'])
          : <String, dynamic>{};

      return _toInt(
        user['id'] ??
            viewerUser['id'] ??
            root['viewer_id'] ??
            root['user_id'] ??
            root['id'],
      );
    } catch (_) {
      return 0;
    }
  }

  bool _isSameEntryAlreadyShowing(dynamic userId) {
    final incomingUserId = _toInt(userId);
    if (incomingUserId <= 0) return false;
    if (newViewersJoinded.value != true) return false;
    return _entryUserIdFromData(newJoinedUserData) == incomingUserId;
  }

  Map<String, dynamic> _safeAuthUserForSystemComment(dynamic fallbackUserId) {
    final int uid = _toInt(fallbackUserId);
    final dynamic profileUser = authController.userProfile.value.user;

    dynamic safeRead(dynamic Function() getter) {
      try {
        return getter();
      } catch (_) {
        return null;
      }
    }

    String safeText(dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty || text.toLowerCase() == 'null') return '';
      return text;
    }

    final dynamic profileId = safeRead(() => profileUser?.id);
    final String name = safeText(safeRead(() => profileUser?.name));
    final String username = safeText(safeRead(() => profileUser?.username));
    final dynamic profileImage =
        safeRead(() => profileUser?.profileImage) ??
        safeRead(() => profileUser?.image);

    return {
      'id': uid > 0 ? uid : profileId,
      'user_id': uid > 0 ? uid : profileId,
      'name': name.isNotEmpty ? name : (username.isNotEmpty ? username : 'You'),
      'username': username,
      'level': safeRead(() => profileUser?.level) ?? 0,
      'profile_image': profileImage,
      'image': safeRead(() => profileUser?.image) ?? profileImage,
      'frame': safeRead(() => profileUser?.frame),
      'gender': safeRead(() => profileUser?.gender),
      'is_online': true,
    };
  }

  void _addSelfJoinCommentFromEntry({
    required Map<String, dynamic> entryData,
    required dynamic userId,
  }) {
    try {
      final int incomingUserId = _toInt(userId);
      final int currentUserId = _toInt(
        authController.userProfile.value.user?.id,
      );
      if (incomingUserId <= 0 ||
          currentUserId <= 0 ||
          incomingUserId != currentUserId)
        return;

      int sid = _toInt(
        entryData['livestream_id'] ??
            entryData['stream_id'] ??
            entryData['live_stream_id'],
      );
      if (sid <= 0) sid = _toInt(streamID.value);
      if (sid <= 0) sid = _toInt(activeAudioStreamId.value);
      if (sid <= 0) sid = _toInt(liveRoomUpdateStreamId.value);
      if (sid <= 0 || !_isCurrentStream(sid)) return;

      Map<String, dynamic> userMap = entryData['user'] is Map
          ? Map<String, dynamic>.from(entryData['user'])
          : <String, dynamic>{};

      final fallback = _safeAuthUserForSystemComment(incomingUserId);
      userMap = {
        ...fallback,
        ...userMap,
        'id': userMap['id'] ?? fallback['id'],
        'user_id': userMap['user_id'] ?? userMap['id'] ?? fallback['user_id'],
        'name': (userMap['name']?.toString().trim().isNotEmpty ?? false)
            ? userMap['name']
            : fallback['name'],
      };

      _addSystemViewerComment(
        livestreamId: sid,
        user: userMap,
        comment: 'has joined the stream',
        systemType: 'viewer_join',
      );
      liveLog(
        '✅ Self join timeline item added => stream:$sid user:$incomingUserId',
      );
    } catch (e) {
      liveLog('⚠️ Self join timeline add skipped => $e');
    }
  }

  void showEntryAnimationForViewer({
    required Map<String, dynamic> entryData,
    required dynamic userId,
  }) {
    final incomingUserId = _toInt(userId);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    /// ✅ Backend onek somoy nijer device-e viewer_joined echo kore na,
    /// abar duplicate cooldown er jonno animation skip holeo self timeline miss hoto.
    /// Tai duplicate guard-er age self join comment add korte hobe.
    _addSelfJoinCommentFromEntry(entryData: entryData, userId: incomingUserId);

    // Same viewer er viewer_joined + live_comment duplicate ashle running
    // SVGA restart/replace korbe na. Tai full animation cut hobe na.
    if (_isSameEntryAlreadyShowing(incomingUserId)) {
      liveLog(
        'ℹ️ Duplicate entry ignored while running => user:$incomingUserId',
      );
      return;
    }

    final int blockedUntil = _recentEntryShownUntilMs[incomingUserId] ?? 0;
    if (incomingUserId > 0 && blockedUntil > nowMs) {
      liveLog('ℹ️ Duplicate entry ignored by cooldown => user:$incomingUserId');
      return;
    }

    if (incomingUserId > 0) {
      _recentEntryShownUntilMs[incomingUserId] = nowMs + 8000;
    }

    newJoinedUserData.assignAll(entryData);
    newViewerAction.value = 'join';
    showEntryAnimation();

    _entryAnimationSafetyTimer?.cancel();
    _entryAnimationSafetyTimer = Timer(const Duration(seconds: 8), () {
      try {
        if (_entryUserIdFromData(newJoinedUserData) == incomingUserId) {
          hideEntryAnimation();
        }
      } catch (_) {
        hideEntryAnimation();
      }
    });
  }

  void _addSystemViewerComment({
    required dynamic livestreamId,
    required Map<String, dynamic> user,
    required String comment,
    required String systemType,
  }) {
    final userId = user['id'] ?? user['user_id'] ?? user['viewer_id'];

    if (userId == null ||
        user['name'] == null ||
        user['name'].toString().trim().isEmpty ||
        user['name'].toString().toLowerCase() == 'null') {
      liveLog('⚠️ System viewer comment skipped, bad user => $user');
      return;
    }

    /// duplicate stop: same user + same stream + same join/left comment already recent thakle add korbo na.
    /// Age only user/comment check chilo, tai self join ba room switch-e wrong skip hote parto.
    final int incomingStreamId = _toInt(livestreamId);
    final String incomingSystemType = systemType.toString();
    final exists = commentsList.reversed.take(25).any((item) {
      if (item is! Map) return false;

      final itemUser = item['user'];
      final itemUserId = itemUser is Map
          ? (itemUser['id'] ?? itemUser['user_id'] ?? itemUser['viewer_id'])
          : null;

      final int itemStreamId = _toInt(
        item['livestream_id'] ??
            item['stream_id'] ??
            item['live_stream_id'] ??
            item['room_id'],
      );
      final String itemSystemType = (item['system_type'] ?? item['type'] ?? '')
          .toString();

      return item['comment'].toString() == comment &&
          itemUserId.toString() == userId.toString() &&
          itemStreamId == incomingStreamId &&
          itemSystemType == incomingSystemType;
    });

    if (exists) {
      liveLog(
        'ℹ️ Duplicate system viewer comment skipped: $comment user=$userId',
      );
      return;
    }

    final systemComment = {
      'type': systemType,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'user': user,
      'comment': comment,
      'timestamp': DateTime.now().toIso8601String(),
      'system_type': systemType,
      'comment_key': '${systemType}_${livestreamId}_$userId',
      'is_local_self_activity':
          userId.toString() ==
          authController.userProfile.value.user?.id?.toString(),
    };

    commentsList.add(systemComment);
    _refreshCommentsListSmooth();
  }

  bool _isUserAcceptedSeatLocally(dynamic userId) {
    final int uid = _toInt(userId);
    if (uid <= 0) return false;

    for (final raw in liveCallList) {
      if (raw is! Map) continue;

      final user = raw['user'] is Map
          ? Map<String, dynamic>.from(raw['user'])
          : <String, dynamic>{};

      final int rowId = _toInt(
        raw['caller_id'] ??
            raw['user_id'] ??
            raw['viewer_id'] ??
            user['id'] ??
            user['user_id'],
      );

      final String status = (raw['call_status'] ?? raw['status'] ?? 'accepted')
          .toString()
          .toLowerCase()
          .trim();

      final bool accepted =
          status == 'accepted' ||
          status == 'joined' ||
          status == 'active' ||
          status == 'live' ||
          status == 'on_seat';

      if (rowId == uid && accepted) return true;
    }

    return false;
  }

  bool _isWeakCallerTimeoutReason(String reason) {
    final String value = reason.toLowerCase().trim();
    if (value.isEmpty) return false;
    return value == 'heartbeat_timeout' ||
        value == 'heartbeat_delayed' ||
        value == 'presence_timeout' ||
        value == 'inactivity_timeout' ||
        value == 'ping_timeout' ||
        value == 'connection_lost' ||
        value == 'network_timeout' ||
        value == 'transport_timeout';
  }

  bool _isVideoCallerMediaStillActive(int userId) {
    if (userId <= 0) return false;

    final int currentUserId = _currentUserIdInt();
    if (userId == currentUserId && _localPublishingCallerId == userId) {
      return true;
    }

    final int mappedUid =
        livestreamController.videoCallerAgoraUidMap[userId] ?? 0;
    if (mappedUid <= 0) return false;

    // The caller->Agora mapping is created only for accepted video/popular
    // calls. Requiring that mapping prevents a stale remote UID from an old
    // video room from affecting audio-live seat cleanup.
    return livestreamController.videoLiveRemoteUids.any(
      (uid) =>
          uid == mappedUid ||
          uid == userId ||
          uid == userId + 100000 ||
          (userId >= 100000 && uid == userId - 100000),
    );
  }

  bool _viewerLeftIsRealRoomExit(String reason) {
    final String r = reason.toLowerCase().trim();

    return r.contains('kick') ||
        r.contains('ban') ||
        r.contains('live_end') ||
        r.contains('live_ended') ||
        r.contains('room_exit') ||
        r.contains('full_exit') ||
        r.contains('close') ||
        r.contains('owner_close') ||
        r.contains('leave_room');
  }

  void _handleUnifiedViewer(Map<String, dynamic> payload, String actionType) {
    final viewerInfoRaw =
        payload['viewer_data'] ??
        payload['viewer'] ??
        payload['user'] ??
        payload['data'] ??
        payload;

    if (viewerInfoRaw is! Map) {
      liveLog('⚠️ viewer payload invalid: $payload');
      return;
    }

    final viewerInfo = Map<String, dynamic>.from(viewerInfoRaw);

    // Viewer rows have their own database id (for example 15357) and the real
    // user id in viewer_id/user_id/user.id (for example 100558). Always prefer
    // the full user payload, otherwise viewer_left can clear the wrong id and
    // stale seat/profile rows remain in the room.
    final Map<String, dynamic> userMap = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'])
        : payload['viewer'] is Map
        ? Map<String, dynamic>.from(payload['viewer'])
        : viewerInfo['user'] is Map
        ? Map<String, dynamic>.from(viewerInfo['user'])
        : <String, dynamic>{};

    final livestreamId =
        payload['livestream_id'] ??
        payload['stream_id'] ??
        viewerInfo['livestream_id'] ??
        viewerInfo['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ VIEWER ignored: not current stream => $livestreamId');
      return;
    }

    final userId =
        userMap['id'] ??
        userMap['user_id'] ??
        payload['user_id'] ??
        payload['viewer_id'] ??
        viewerInfo['viewer_id'] ??
        viewerInfo['user_id'];

    if (userId == null) {
      liveLog('⚠️ viewer user id missing: $payload');
      return;
    }

    final currentUserId = authController.userProfile.value.user?.id?.toString();
    final action =
        (payload['action'] ??
                payload['viewer_action'] ??
                payload['action_type'] ??
                actionType)
            .toString()
            .toLowerCase();

    /// Backend can send action_type=viewer_add with action=viewer_remove.
    final isLeft =
        action.contains('remove') ||
        action.contains('left') ||
        action.contains('leave') ||
        action == 'viewer_out';

    final isSelf = currentUserId != null && userId.toString() == currentUserId;

    final int sidForGuard = _toInt(livestreamId);
    final int uidForGuard = _toInt(userId);
    final String leaveReason =
        (payload['reason'] ??
                payload['leave_reason'] ??
                payload['system_type'] ??
                payload['message'] ??
                '')
            .toString()
            .toLowerCase();

    /// ✅ Permanent audio seat fix:
    /// Sometimes backend sends viewer_left for current user while the user is still
    /// accepted on an audio seat. That event must NOT demote caller -> viewer,
    /// must NOT call rejectCall, and must NOT remove the user from viewer list.
    final bool selfSeatProtectedViewerLeft =
        isLeft &&
        isSelf &&
        sidForGuard > 0 &&
        uidForGuard > 0 &&
        !_locallyLeftStreamIds.contains(sidForGuard) &&
        (_selfIsStillOnSeatLocally() || _selfSeatNoFromLiveCallList() > 0) &&
        !leaveReason.contains('kick') &&
        !leaveReason.contains('ban') &&
        !leaveReason.contains('live_end') &&
        !leaveReason.contains('room_exit') &&
        !leaveReason.contains('full_exit');

    if (selfSeatProtectedViewerLeft) {
      final int protectedSeat = _selfSeatNoFromLiveCallList();
      _markSelfHeartbeatSeatGuard(userId: uidForGuard, seatNo: protectedSeat);
      if (userMap.isNotEmpty) {
        livestreamController.addOrUpdateViewerLocal({
          'id': uidForGuard,
          'viewer_id': uidForGuard,
          'user_id': uidForGuard,
          'livestream_id': livestreamId,
          'is_active': true,
          'user': userMap,
        }, force: true);
      }
      livestreamController.updateLivePresenceRole(
        role: 'caller',
        isOnSeat: true,
        seatNo: protectedSeat > 0 ? protectedSeat : null,
      );
      liveLog(
        '🛡️ Protected self viewer_left while still on seat => user:$userId seat:$protectedSeat',
      );
      return;
    }

    final bool viewerLeftUserStillOnSeat =
        isLeft && _isUserAcceptedSeatLocally(userId);
    final bool removeViewer =
        payload['remove_viewer'] == true || payload['viewer_removed'] == true;
    final bool forcedRoomExit =
        removeViewer || _viewerLeftIsRealRoomExit(leaveReason);
    final bool preserveViewer =
        !forcedRoomExit &&
        (payload['remove_viewer'] == false ||
            payload['viewer_removed'] == false ||
            leaveReason.contains('reject') ||
            leaveReason.contains('cancel') ||
            leaveReason.contains('seat_leave') ||
            leaveReason.contains('leave_seat') ||
            leaveReason.contains('call_end') ||
            leaveReason.contains('call_timeout'));
    final bool explicitViewerLeaveAction =
        action == 'viewer_left' ||
        action == 'viewer_leave' ||
        action == 'viewer_remove' ||
        action == 'viewer_removed' ||
        action == 'viewer_out';
    final bool viewerLeftRealRoomExit =
        isLeft &&
        !preserveViewer &&
        (forcedRoomExit ||
            (explicitViewerLeaveAction && !viewerLeftUserStillOnSeat));

    _cacheLiveUserProfile(userMap);

    /// ✅ Video live stale call popup fix + audio seat protection:
    /// viewer_left is a weak presence event. It must not remove an accepted
    /// audio seat. Seat removal happens only on explicit leave/reject/kick/end.
    if (isLeft) {
      if (viewerLeftRealRoomExit) {
        _markRecentRoomExit(
          streamId: livestreamId,
          userId: userId,
          milliseconds: 60000,
        );
      }

      if (isSelf && viewerLeftRealRoomExit) {
        final sid = _toInt(livestreamId);
        if (sid > 0) {
          _locallyLeftStreamIds.add(sid);
          if (streamID.value == sid) streamID.value = 0;
        }
      }

      if (viewerLeftRealRoomExit) {
        _viewerJoinedAtMs.remove(_toInt(userId));
      }

      _clearStaleCallStateForUser(
        callerId: userId,
        streamId: livestreamId,
        // Explicit room_exit/full_exit is authoritative. The local seat row can
        // still be present for a few milliseconds because caller_left/viewer_left
        // are separate realtime frames. Never let that stale row keep the user
        // visible on the host seat after they have left the room.
        removeAcceptedCall: viewerLeftRealRoomExit,
        closePopupIfOpen: viewerLeftRealRoomExit,
        reason: 'viewer_left_safe',
      );
      if (!viewerLeftRealRoomExit) {
        debugPrint(
          'VIEWER_PRESENCE_PRESERVED => user=$userId reason=$leaveReason '
          'removeViewer=${payload['remove_viewer']} viewerRemoved=${payload['viewer_removed']}',
        );
        if (viewerLeftUserStillOnSeat) {
          for (final raw in liveCallList) {
            if (raw is! Map) continue;
            final call = Map<String, dynamic>.from(raw);
            if (_callUserId(call) != _toInt(userId)) continue;
            _ensureViewerRowFromCall(call);
            break;
          }
        } else {
          _ensureViewerRowAfterSeatLeft({
            ...payload,
            if (userMap.isNotEmpty) 'user': userMap,
          });
        }
      }

      /// Only reject backend call for a real room/seat exit. Random viewer_left
      /// from presence/websocket must not kick audience out of seat.
      final int sid = _toInt(livestreamId);
      final int uid = _toInt(userId);
      if (viewerLeftRealRoomExit &&
          !viewerLeftUserStillOnSeat &&
          sid > 0 &&
          uid > 0) {
        Future.microtask(() async {
          try {
            await livestreamController.tryToRejectCall(
              streamId: sid,
              userId: uid,
            );
          } catch (e) {
            liveLog('⚠️ reject stale call on real viewer_left skipped => $e');
          }
        });
      } else {}
    } else {
      final sid = _toInt(livestreamId);
      _clearRecentRoomExit(streamId: sid, userId: userId);
      if (isSelf && sid > 0) {
        _locallyLeftStreamIds.remove(sid);
        streamID.value = sid;
      }

      _viewerJoinedAtMs[_toInt(userId)] = DateTime.now().millisecondsSinceEpoch;

      _clearStaleCallStateForUser(
        callerId: userId,
        streamId: livestreamId,
        removeAcceptedCall: false,
        closePopupIfOpen: false,
        reason: 'viewer_join_reset_old_pending',
      );
    }

    bool sameViewer(dynamic viewer) {
      if (viewer is! Map) return false;
      final nestedUserId = viewer['user'] is Map ? viewer['user']['id'] : null;
      final viewerId = viewer['viewer_id'];
      final userIdField = viewer['user_id'];
      final directId = viewer['id'];

      // viewer['id'] can be the livestream_viewers table row id, not the user id.
      // Only use it as a last fallback when no real viewer/user id is present.
      final bool hasRealViewerId =
          viewerId != null || userIdField != null || nestedUserId != null;

      return nestedUserId.toString() == userId.toString() ||
          viewerId.toString() == userId.toString() ||
          userIdField.toString() == userId.toString() ||
          (!hasRealViewerId && directId.toString() == userId.toString());
    }

    if (!isLeft) {
      // Viewer join payload jodi current room snapshot niye ase, late audience/host side
      // immediately lock/mute/gift coin current state sync kore nebo.
      syncRoomSnapshotForLateJoin(payload, source: 'viewer_add_payload');

      final exists = livestreamController.liveViewerList.any(sameViewer);

      if (!exists) {
        livestreamController.addOrUpdateViewerLocal(
          Map<String, dynamic>.from(viewerInfo),
          force: true,
        );
      }

      // Everybody should see their own entry animation after joining another live.
      // Only duplicate websocket/live_comment events are ignored by showEntryAnimationForViewer().
      if (!exists || isSelf) {
        showEntryAnimationForViewer(
          entryData: Map<String, dynamic>.from({
            ...viewerInfo,
            'user': userMap.isNotEmpty ? userMap : viewerInfo['user'],
            'viewer_id': userId,
            'livestream_id': livestreamId,
          }),
          userId: userId,
        );
      }

      if (!exists || isSelf) {
        final safeUser = userMap.isNotEmpty
            ? userMap
            : _safeAuthUserForSystemComment(userId);
        _addSystemViewerComment(
          livestreamId: livestreamId,
          user: safeUser,
          comment: 'has joined the stream',
          systemType: 'viewer_join',
        );
      }

      liveLog('✅ Unified viewer added: $userId exists=$exists');
    } else {
      // viewer_left is often a weak presence event. For normal viewer leave, remove
      // only that viewer row; never clear accepted seat/call/broadcaster state unless
      // it is an explicit room/seat exit.
      clearSpecificUserStreamData(
        userId: userId.toString(),
        rejectCallIfInCallList: false,
        // A confirmed full room exit must clear the seat/call immediately,
        // even if the previous accepted row is still present locally.
        removeAcceptedCall: viewerLeftRealRoomExit,
        closePopupIfOpen: viewerLeftRealRoomExit,
        removeViewer: viewerLeftRealRoomExit,
        reason: viewerLeftRealRoomExit
            ? 'viewer_left_safe_final'
            : 'viewer_left_presence_only',
      );

      if (!viewerLeftRealRoomExit) {
        _refreshLiveCallListSmooth();
        livestreamController.liveViewerList.refresh();
      }

      if (viewerLeftRealRoomExit) {
        final safeUser = userMap.isNotEmpty
            ? userMap
            : _safeAuthUserForSystemComment(userId);
        _addSystemViewerComment(
          livestreamId: livestreamId,
          user: safeUser,
          comment: 'left the room',
          systemType: 'viewer_left',
        );
      }
    }
  }
}
