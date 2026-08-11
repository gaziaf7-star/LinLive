part of '../websocket_controller.dart';

extension CommentEventHandler on WebsocketController {
  void clearLiveCommentsLocal({int? livestreamId, String source = 'unknown'}) {
    try {
      if (livestreamId != null &&
          livestreamId > 0 &&
          !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ CLEAR LIVE COMMENTS ignored: not current stream => $livestreamId',
        );
        return;
      }

      final int beforeComments = commentsList.length;
      final int beforeGifts = giftMessagesList.length;

      commentsList.clear();
      giftMessagesList.clear();
      _refreshCommentsListSmooth();
      _refreshGiftMessagesListSmooth();

      liveLog(
        '🧹 LIVE COMMENTS LOCAL CLEARED => stream:${livestreamId ?? streamID.value} '
        'source:$source comments:$beforeComments->${commentsList.length} '
        'gifts:$beforeGifts->${giftMessagesList.length}',
      );
    } catch (e, st) {
      liveLog('❌ clearLiveCommentsLocal error => $e\n$st');
    }
  }

  void _handleUnifiedClearLiveComments(Map<String, dynamic> payload) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : payload;

      final dynamic rawStreamId =
          data['livestream_id'] ??
          data['liveSteamId'] ??
          data['stream_id'] ??
          data['live_stream_id'] ??
          payload['livestream_id'] ??
          payload['liveSteamId'] ??
          payload['stream_id'] ??
          payload['live_stream_id'];

      final int livestreamId = _toInt(rawStreamId);

      if (livestreamId > 0 && !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ CLEAR LIVE COMMENTS ignored: not current stream => $livestreamId',
        );
        return;
      }

      final dynamic rawClearValue =
          data['clear_comments'] ??
          data['comments_cleared'] ??
          payload['clear_comments'] ??
          payload['comments_cleared'];

      final bool shouldClear = rawClearValue == null
          ? true
          : _truthy(rawClearValue);

      if (!shouldClear) {
        liveLog('ℹ️ CLEAR LIVE COMMENTS event ignored: clear_comments=false');
        return;
      }

      liveLog(
        '🧹 CLEAR LIVE COMMENTS EVENT RECEIVED => stream:$livestreamId payload:$payload',
      );

      clearLiveCommentsLocal(
        livestreamId: livestreamId > 0 ? livestreamId : null,
        source: 'websocket_clear_live_comments',
      );
    } catch (e, st) {
      liveLog('❌ CLEAR LIVE COMMENTS EVENT ERROR => $e\n$st');
    }
  }

  void _handleUnifiedComment(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload;

    final livestreamId =
        data['livestream_id'] ??
        data['stream_id'] ??
        payload['livestream_id'] ??
        payload['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ COMMENT ignored: not current stream => $livestreamId');
      return;
    }

    final user = data['user'] ?? payload['user'];

    final commentData = {
      'type': 'message',
      'livestream_id': livestreamId,
      'user': user,
      'comment':
          data['comment'] ??
          data['message'] ??
          payload['comment'] ??
          payload['message'] ??
          '',
      'timestamp':
          data['timestamp'] ??
          payload['timestamp'] ??
          DateTime.now().toIso8601String(),
    };

    commentsList.add(commentData);
    _refreshCommentsListSmooth();

    _handleViewerSystemCommentFromLiveComment(commentData, payload);
  }

  void _handleViewerSystemCommentFromLiveComment(
    Map<String, dynamic> commentData,
    Map<String, dynamic> originalPayload,
  ) {
    try {
      final systemType =
          (originalPayload['system_type'] ??
                  originalPayload['type'] ??
                  commentData['system_type'] ??
                  '')
              .toString()
              .toLowerCase();

      final commentText = (commentData['comment'] ?? '')
          .toString()
          .toLowerCase();

      final bool isJoin =
          systemType == 'viewer_join' ||
          systemType == 'viewer_joined' ||
          commentText.contains('has joined');
      final bool isLeft =
          systemType == 'viewer_left' ||
          systemType == 'viewer_leave' ||
          systemType == 'viewer_removed' ||
          commentText.contains('left the');

      if (!isJoin && !isLeft) return;

      final dynamic livestreamId =
          commentData['livestream_id'] ??
          originalPayload['livestream_id'] ??
          originalPayload['stream_id'];

      if (livestreamId != null && !_isCurrentStream(livestreamId)) return;

      final rawUser =
          commentData['user'] ??
          originalPayload['user'] ??
          originalPayload['viewer'];
      if (rawUser is! Map) return;

      final user = Map<String, dynamic>.from(rawUser);
      final dynamic userId =
          user['id'] ??
          originalPayload['user_id'] ??
          originalPayload['viewer_id'];
      if (userId == null) return;

      final currentUserId = authController.userProfile.value.user?.id
          ?.toString();
      final bool isSelf =
          currentUserId != null && userId.toString() == currentUserId;

      if (isLeft) {
        final int sidForGuard = _toInt(livestreamId);
        final int uidForGuard = _toInt(userId);

        /// A live_comment `viewer_left` row is informational and can arrive
        /// late/out of order after a caller was accepted. Never let that weak
        /// comment remove an active caller from the host viewer list. Explicit
        /// viewer/kick/live-end events remain the authority for room removal.
        if (_isUserAcceptedSeatLocally(userId)) {
          livestreamController.addOrUpdateViewerLocal({
            'id': uidForGuard,
            'viewer_id': uidForGuard,
            'user_id': uidForGuard,
            'livestream_id': livestreamId,
            'is_active': true,
            'user': user,
          }, force: true);
          _refreshLiveCallListSmooth();
          livestreamController.liveViewerList.refresh();
          liveLog(
            '🛡️ Ignored weak viewer_left comment for accepted caller '
            '=> user:$userId stream:$livestreamId',
          );
          return;
        }

        /// ✅ Same protection for live_comment system_type=viewer_left.
        /// A system comment can arrive after seat change/reconnect and should not
        /// remove the current user's viewer row while he is still seated.
        if (isSelf &&
            sidForGuard > 0 &&
            uidForGuard > 0 &&
            !_locallyLeftStreamIds.contains(sidForGuard) &&
            (_selfIsStillOnSeatLocally() ||
                _selfSeatNoFromLiveCallList() > 0)) {
          final int protectedSeat = _selfSeatNoFromLiveCallList();
          _markSelfHeartbeatSeatGuard(
            userId: uidForGuard,
            seatNo: protectedSeat,
          );
          livestreamController.addOrUpdateViewerLocal({
            'id': uidForGuard,
            'viewer_id': uidForGuard,
            'user_id': uidForGuard,
            'livestream_id': livestreamId,
            'is_active': true,
            'user': user,
          }, force: true);
          livestreamController.updateLivePresenceRole(
            role: 'caller',
            isOnSeat: true,
            seatNo: protectedSeat > 0 ? protectedSeat : null,
          );
          liveLog(
            '🛡️ Protected self viewer_left comment while still on seat => user:$userId seat:$protectedSeat',
          );
          return;
        }

        _markRecentRoomExit(
          streamId: livestreamId,
          userId: userId,
          milliseconds: 60000,
        );
        livestreamController.removeViewerLocal(userId);
        _viewerJoinedAtMs.remove(_toInt(userId));
        liveLog('✅ Viewer removed from live_comment system event => $userId');
        return;
      }

      /// Re-join entry fix:
      /// Backend sometimes sends only live_comment/system_type=viewer_join on 2nd join.
      /// Use manager so duplicate/stale rows are merged safely.
      if (_hasRecentRoomExit(streamId: livestreamId, userId: userId)) {
        liveLog(
          '🚫 Stale viewer_join live_comment ignored after recent room exit => user:$userId',
        );
        return;
      }

      _clearRecentRoomExit(streamId: livestreamId, userId: userId);

      final viewerInfo = <String, dynamic>{
        ...user,
        'id': userId,
        'viewer_id': originalPayload['viewer_id'] ?? userId,
        'livestream_id': livestreamId,
        'user': user,
      };

      livestreamController.addOrUpdateViewerLocal(viewerInfo, force: true);
      _viewerJoinedAtMs[_toInt(userId)] = DateTime.now().millisecondsSinceEpoch;

      // Self viewer should also see entry animation when joining another live.
      showEntryAnimationForViewer(
        entryData: Map<String, dynamic>.from(viewerInfo),
        userId: userId,
      );

      liveLog('✅ Viewer join synced from live_comment system event => $userId');
    } catch (e) {
      liveLog('⚠️ viewer system comment sync skipped => $e');
    }
  }
}
