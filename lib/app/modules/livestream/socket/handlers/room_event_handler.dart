part of '../websocket_controller.dart';

extension RoomEventHandler on WebsocketController {
  void _handleUnifiedRoomSettingsUpdated(
    Map<String, dynamic> payload, {
    String source = 'room_settings_updated',
  }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};

      final Map<String, dynamic> liveData = payload['livestreamdata'] is Map
          ? Map<String, dynamic>.from(payload['livestreamdata'])
          : payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : payload['live_stream'] is Map
          ? Map<String, dynamic>.from(payload['live_stream'])
          : payload['stream'] is Map
          ? Map<String, dynamic>.from(payload['stream'])
          : payload['room'] is Map
          ? Map<String, dynamic>.from(payload['room'])
          : <String, dynamic>{};

      final Map<String, dynamic> nestedLiveData = data['livestreamdata'] is Map
          ? Map<String, dynamic>.from(data['livestreamdata'])
          : data['livestream'] is Map
          ? Map<String, dynamic>.from(data['livestream'])
          : data['live_stream'] is Map
          ? Map<String, dynamic>.from(data['live_stream'])
          : data['stream'] is Map
          ? Map<String, dynamic>.from(data['stream'])
          : data['room'] is Map
          ? Map<String, dynamic>.from(data['room'])
          : <String, dynamic>{};

      /// IMPORTANT:
      /// Backend sometimes broadcasts room edit with action_type:
      /// room_settings_updated instead of live_stream_updated.
      /// Old code only applied safety flags here, so audience did not see
      /// seat/theme/background/title change instantly. This merged room map is
      /// now used for both safety + full room UI sync.
      final Map<String, dynamic> room = {
        ...payload,
        ...data,
        ...liveData,
        ...nestedLiveData,
      };

      final dynamic rawStreamId =
          room['livestream_id'] ??
          room['liveSteamId'] ??
          room['stream_id'] ??
          room['live_stream_id'] ??
          room['id'];

      final int livestreamId = _toInt(rawStreamId);

      if (livestreamId > 0 && !_isCurrentStream(livestreamId)) {
        liveLog('⛔ ROOM SETTINGS ignored: not current stream => $livestreamId');
        return;
      }

      final int effectiveStreamId = livestreamId > 0
          ? livestreamId
          : streamID.value > 0
          ? streamID.value
          : activeAudioStreamId.value > 0
          ? activeAudioStreamId.value
          : livestreamController.streamId.value;

      livestreamController.applyRoomSafetySettingsFromPayload(
        room,
        source: 'websocket_$source',
      );

      bool hasRoomField(List<String> keys) {
        for (final key in keys) {
          if (room.containsKey(key) && room[key] != null) return true;
        }
        return false;
      }

      String? firstString(List<String> keys) {
        for (final key in keys) {
          if (room.containsKey(key) && room[key] != null) {
            return room[key].toString().trim();
          }
        }
        return null;
      }

      final bool hasRealtimeRoomUpdate =
          hasRoomField(['seat_count', 'total_seats']) ||
          hasRoomField(['room_layout', 'layout']) ||
          hasRoomField(['room_theme', 'theme']) ||
          hasRoomField(['room_background', 'background']) ||
          hasRoomField([
            'stream_bte',
            'title',
            'stream_title',
            'announcement',
            'anousment',
          ]) ||
          hasRoomField(['stream_image', 'image', 'cover_image', 'thumbnail']) ||
          hasRoomField(['room_password', 'stream_password', 'password']);

      if (effectiveStreamId > 0 && hasRealtimeRoomUpdate) {
        final int seatCount = _toInt(room['seat_count'] ?? room['total_seats']);
        final int roomLayout = _toInt(room['room_layout'] ?? room['layout']);
        final int roomTheme = _toInt(room['room_theme'] ?? room['theme']);
        final int roomBackground =
            room.containsKey('room_background') ||
                room.containsKey('background')
            ? _toInt(room['room_background'] ?? room['background'])
            : liveRoomBackground.value;

        updateLiveRoomSettings(
          livestreamId: effectiveStreamId,
          seatCount: seatCount > 0 ? seatCount : liveRoomSeatCount.value,
          roomLayout:
              room.containsKey('room_layout') || room.containsKey('layout')
              ? roomLayout
              : liveRoomLayout.value,
          roomTheme: room.containsKey('room_theme') || room.containsKey('theme')
              ? roomTheme
              : liveRoomTheme.value,
          roomBackground: roomBackground,
          streamTitle: firstString(['stream_bte', 'title']),
          streamAnnouncement: firstString([
            'announcement',
            'anousment',
            'stream_title',
          ]),
          streamImage: firstString([
            'stream_image',
            'image',
            'cover_image',
            'thumbnail',
          ]),
          streamPassword: firstString([
            'room_password',
            'stream_password',
            'password',
          ]),
        );

        try {
          syncRoomSnapshotForLateJoin(room, source: source);
        } catch (e) {
          liveLog('⚠️ room_settings snapshot sync skipped => $e');
        }

        try {
          livestreamController.syncLiveGiftCoinsFromPayload(
            room,
            source: source,
          );
        } catch (_) {}

        liveLog(
          '✅ ROOM SETTINGS FULL UI SYNCED => source:$source stream:$effectiveStreamId '
          'seats:${seatCount > 0 ? seatCount : liveRoomSeatCount.value} '
          'layout:${liveRoomLayout.value} theme:${liveRoomTheme.value} '
          'bg:${liveRoomBackground.value}',
        );
      } else {
        liveLog(
          'ℹ️ ROOM SETTINGS only safety fields received => source:$source stream:$effectiveStreamId',
        );
      }

      liveLog(
        '✅ ROOM SETTINGS EVENT APPLIED => source:$source stream:$livestreamId',
      );
    } catch (e, st) {
      liveLog('❌ ROOM SETTINGS EVENT ERROR => $e\n$st');
    }
  }

  void _handleUnifiedLiveStreamStateUpdated(Map<String, dynamic> payload) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? {
              ...Map<String, dynamic>.from(payload),
              ...Map<String, dynamic>.from(payload['data']),
            }
          : Map<String, dynamic>.from(payload);

      final livestreamId =
          data['livestream_id'] ??
          data['stream_id'] ??
          data['id'] ??
          payload['livestream_id'];

      if (livestreamId != null && !_isCurrentStream(livestreamId)) {
        liveLog(
          '⛔ livestream_state_updated ignored: not current stream => $livestreamId',
        );
        return;
      }

      final int viewerCount = _toInt(
        data['viewer_count'] ?? data['viewers_count'],
      );
      final int callerCount = _toInt(
        data['caller_count'] ?? data['callers_count'],
      );

      printSeatTrace(
        'live_state_event',
        streamId: _toInt(livestreamId),
        status: 'snapshot',
        note:
            'serverViewers=$viewerCount serverCallers=$callerCount occupied=${data['occupied_seats']}',
      );

      /// Seat lock source of truth. Here allowUnlock=true because this event is
      /// backend authoritative state after join/left/lock/unlock.
      syncSeatLocksFromAnyPayload(
        data,
        allowUnlock: true,
        source: 'livestream_state_updated',
      );

      /// If backend explicitly says locked_seats: [], clear old visual locks.
      if ((data['locked_seats'] is List &&
              (data['locked_seats'] as List).isEmpty) ||
          (data['lockedSeats'] is List &&
              (data['lockedSeats'] as List).isEmpty)) {
        lockedSeatMap.clear();
        lockedSeatMap.refresh();
      }

      /// If backend says no viewer, host UI must not keep stale viewer avatars.
      /// If viewerCount > 0 but no viewer objects are provided, only count/log is applied;
      /// never create fake list rows from count-only payload.
      livestreamController.viewerState.applyState(data);
      if (viewerCount == 0) {
        newViewersJoinded.value = false;
        newJoinedUserData.value = {};
      }

      /// If no caller/seat user except host, clear stale non-host call rows.
      /// Seat 1 host row should stay because audio room broadcaster is seeded there.
      if (callerCount <= 1 && data['occupied_seats'] is List) {
        final occupied = (data['occupied_seats'] as List)
            .map((e) => _seatToInt(e))
            .whereType<int>()
            .toSet();

        bool currentUserRemovedByAuthoritativeState = false;
        final Set<int> removedRemoteUserIds = <int>{};
        final int beforeStateRemoveCount = liveCallList.length;

        liveCallList.removeWhere((call) {
          if (call is! Map) return false;
          final callMap = Map<String, dynamic>.from(call);
          final seat = _seatToInt(
            callMap['seat_no'] ?? callMap['seat'] ?? callMap['seat_number'],
          );
          if (seat == null) return false;

          final int callUserId = _callUserId(callMap);
          final int currentUserId = _currentUserIdInt();
          if (currentUserId > 0 &&
              callUserId == currentUserId &&
              _hasSelfHeartbeatSeatGuard(currentUserId)) {
            liveLog(
              '🛡️ live_state_update kept current user seat during heartbeat guard => user:$currentUserId seat:$seat',
            );
            return false;
          }

          final bool shouldRemove = !occupied.contains(seat);
          if (shouldRemove && callUserId > 0) {
            if (currentUserId > 0 && callUserId == currentUserId) {
              currentUserRemovedByAuthoritativeState = true;
            } else {
              removedRemoteUserIds.add(callUserId);
            }
          }
          return shouldRemove;
        });
        _refreshLiveCallListSmooth();
        if (beforeStateRemoveCount != liveCallList.length) {
          printSeatTrace(
            'live_state_removed_missing_seat',
            streamId: _toInt(livestreamId),
            beforeCount: beforeStateRemoveCount,
            afterCount: liveCallList.length,
            reason: 'occupied_seats_authoritative',
            note:
                'occupied=$occupied removedRemote=${removedRemoteUserIds.join(',')} selfRemoved=$currentUserRemovedByAuthoritativeState',
          );
        }

        if (currentUserRemovedByAuthoritativeState) {
          unawaited(
            _autoMuteCurrentUserAfterSeatSignal(
              userId: _currentUserIdInt(),
              reason: 'authoritative_live_state_seat_missing',
              confirmedSeatExit: true,
            ),
          );
        }

        for (final int removedUserId in removedRemoteUserIds) {
          unawaited(
            _muteRemoteCallerAfterConfirmedSeatExit(
              userId: removedUserId,
              reason: 'authoritative_live_state_seat_missing',
            ),
          );
        }
      }

      audioMutedUserMap.refresh();
      syncCpSeatConnectionsFromAnyPayload(
        data,
        source: 'livestream_state_updated',
      );
      livestreamController.update();

      liveLog(
        '✅ Live state applied => viewers:$viewerCount callers:$callerCount locks:${lockedSeatMap.keys.toList()}',
      );
    } catch (e, st) {
      liveLog('❌ _handleUnifiedLiveStreamStateUpdated error => $e\n$st');
    }
  }

  void _handleUnifiedLiveStreamUpdated(Map<String, dynamic> payload) {
    Map<String, dynamic> room = Map<String, dynamic>.from(payload);

    if (payload['data'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['data'])};
    }

    if (payload['livestreamdata'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['livestreamdata'])};
    }

    if (payload['livestream'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['livestream'])};
    }

    if (payload['live_stream'] is Map) {
      room = {...room, ...Map<String, dynamic>.from(payload['live_stream'])};
    }

    final livestreamId =
        payload['livestream_id'] ??
        payload['stream_id'] ??
        room['livestream_id'] ??
        room['stream_id'] ??
        room['id'];

    if (livestreamId == null) {
      liveLog('⚠️ live_stream_updated missing livestream id. payload=$payload');
      return;
    }

    if (!_isCurrentStream(livestreamId)) {
      liveLog(
        '⛔ live_stream_updated ignored: not current stream => $livestreamId current=${streamID.value}',
      );
      return;
    }

    final int streamId =
        int.tryParse(livestreamId.toString()) ?? streamID.value;

    final int seatCount =
        int.tryParse(
          (room['seat_count'] ??
                  payload['seat_count'] ??
                  liveRoomSeatCount.value)
              .toString(),
        ) ??
        liveRoomSeatCount.value;

    final int roomLayout =
        int.tryParse(
          (room['room_layout'] ??
                  payload['room_layout'] ??
                  liveRoomLayout.value)
              .toString(),
        ) ??
        liveRoomLayout.value;

    final int roomTheme =
        int.tryParse(
          (room['room_theme'] ?? payload['room_theme'] ?? liveRoomTheme.value)
              .toString(),
        ) ??
        liveRoomTheme.value;

    final int roomBackground =
        int.tryParse(
          (room['room_background'] ??
                  payload['room_background'] ??
                  liveRoomBackground.value)
              .toString(),
        ) ??
        liveRoomBackground.value;

    final String streamTitle =
        (room['stream_bte'] ??
                room['title'] ??
                payload['stream_bte'] ??
                payload['title'] ??
                liveRoomTitle.value)
            .toString()
            .trim();

    final String streamAnnouncement =
        (room['announcement'] ??
                room['anousment'] ??
                room['stream_title'] ??
                payload['announcement'] ??
                payload['anousment'] ??
                payload['stream_title'] ??
                liveRoomAnnouncement.value)
            .toString()
            .trim();

    final String streamImage =
        (room['stream_image'] ??
                room['image'] ??
                room['cover_image'] ??
                room['thumbnail'] ??
                payload['stream_image'] ??
                payload['image'] ??
                liveRoomStreamImage.value)
            .toString()
            .trim();

    final String streamPassword =
        (room['room_password'] ??
                room['stream_password'] ??
                room['password'] ??
                payload['room_password'] ??
                payload['stream_password'] ??
                payload['password'] ??
                liveRoomPassword.value)
            .toString()
            .trim();

    updateLiveRoomSettings(
      livestreamId: streamId,
      seatCount: seatCount,
      roomLayout: roomLayout,
      roomTheme: roomTheme,
      roomBackground: roomBackground,
      streamTitle: streamTitle,
      streamAnnouncement: streamAnnouncement,
      streamImage: streamImage,
      streamPassword: streamPassword,
    );

    try {
      livestreamController.applyRoomSafetySettingsFromPayload(
        room,
        source: 'websocket_live_stream_updated',
      );
    } catch (e) {
      liveLog('⚠️ live_stream_updated room safety sync skipped => $e');
    }

    syncRoomSnapshotForLateJoin(room, source: 'live_stream_updated');
    syncCpSeatConnectionsFromAnyPayload(room, source: 'live_stream_updated');
  }

  dynamic _safeReadLiveUser(dynamic Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  String _cleanLiveText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  bool _missingLiveText(dynamic value) => _cleanLiveText(value).isEmpty;

  bool _looksLikeBadFallbackImage(dynamic value) {
    final url = _cleanLiveText(value).toLowerCase();
    return url.isEmpty ||
        url == 'null' ||
        url.contains('photosbulk.com') ||
        url.contains('hijab-girl-pic_108.webp');
  }

  Map<String, dynamic> _safeCurrentUserMapForLiveCard() {
    final dynamic currentUser = authController.userProfile.value.user;
    final dynamic id = _safeReadLiveUser(() => currentUser?.id);
    final String userId = _cleanLiveText(
      _safeReadLiveUser(() => currentUser?.userId),
    );
    final String name = _cleanLiveText(
      _safeReadLiveUser(() => currentUser?.name),
    );
    final String username = _cleanLiveText(
      _safeReadLiveUser(() => currentUser?.username),
    );
    final dynamic profileImage =
        _safeReadLiveUser(() => currentUser?.profileImage) ??
        _safeReadLiveUser(() => currentUser?.image);

    return <String, dynamic>{
      'id': id,
      'user_id': userId.isNotEmpty ? userId : id,
      'name': name.isNotEmpty
          ? name
          : (username.isNotEmpty ? username : ('User').appTr),
      'username': username,
      'profile_image': profileImage,
      'image': profileImage,
      'level': _safeReadLiveUser(() => currentUser?.level) ?? 0,
      'coins': _safeReadLiveUser(() => currentUser?.coins),
      'earned_coins': _safeReadLiveUser(() => currentUser?.earnedCoins),
      'is_online': true,
    };
  }

  bool _hasRealUserMap(dynamic value) {
    if (value is! Map) return false;
    final user = Map<String, dynamic>.from(value);
    return _cleanLiveText(user['name']).isNotEmpty ||
        _cleanLiveText(user['username']).isNotEmpty ||
        _cleanLiveText(user['profile_image']).isNotEmpty ||
        _cleanLiveText(user['image']).isNotEmpty;
  }

  bool _sameLiveCardIdentity(Map<String, dynamic> a, Map<String, dynamic> b) {
    final String aId = _cleanLiveText(
      a['id'] ?? a['livestream_id'] ?? a['stream_id'],
    );
    final String bId = _cleanLiveText(
      b['id'] ?? b['livestream_id'] ?? b['stream_id'],
    );
    if (aId.isNotEmpty && bId.isNotEmpty && aId == bId) return true;

    final String aUser = _cleanLiveText(
      a['user_id'] ?? a['room_id'] ?? a['host_id'],
    );
    final String bUser = _cleanLiveText(
      b['user_id'] ?? b['room_id'] ?? b['host_id'],
    );
    return aUser.isNotEmpty && bUser.isNotEmpty && aUser == bUser;
  }

  Map<String, dynamic> _mergeLiveCardKeepingRichData(
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    final merged = <String, dynamic>{...oldData, ...newData};

    if (!_hasRealUserMap(newData['user']) && _hasRealUserMap(oldData['user'])) {
      merged['user'] = oldData['user'];
    }
    if (!_hasRealUserMap(newData['User']) && _hasRealUserMap(oldData['User'])) {
      merged['User'] = oldData['User'];
    }

    for (final key in ['stream_bte', 'name', 'title']) {
      if (_missingLiveText(merged[key]) && !_missingLiveText(oldData[key])) {
        merged[key] = oldData[key];
      }
    }

    for (final key in [
      'stream_image',
      'stream_img',
      'image',
      'cover_image',
      'profile_image',
    ]) {
      if (_looksLikeBadFallbackImage(merged[key]) &&
          !_looksLikeBadFallbackImage(oldData[key])) {
        merged[key] = oldData[key];
      }
    }

    return merged;
  }

  Map<String, dynamic> _hydrateLiveCardForList(Map<String, dynamic> rawData) {
    Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    for (final oldRaw in homeController.showingLiveStreamList) {
      if (oldRaw is! Map) continue;
      final oldData = Map<String, dynamic>.from(oldRaw);
      if (_sameLiveCardIdentity(oldData, data)) {
        data = _mergeLiveCardKeepingRichData(oldData, data);
        break;
      }
    }

    final Map<String, dynamic> currentUserMap =
        _safeCurrentUserMapForLiveCard();
    final int myId = _toInt(currentUserMap['id']);
    final int dataHostId = _toInt(
      data['user_id'] ??
          data['room_id'] ??
          data['host_id'] ??
          data['broadcaster_id'] ??
          (data['user'] is Map ? data['user']['id'] : null) ??
          (data['User'] is Map ? data['User']['id'] : null),
    );

    if (myId > 0 && dataHostId == myId) {
      data['user'] = _hasRealUserMap(data['user'])
          ? _mergeLiveCardKeepingRichData(
              {'user': currentUserMap},
              {'user': data['user']},
            )['user']
          : currentUserMap;
      data['User'] = data['user'];

      if (_missingLiveText(data['stream_bte']) ||
          data['stream_bte'].toString().toLowerCase() == 'user') {
        data['stream_bte'] = currentUserMap['name'];
      }
      data['name'] = _missingLiveText(data['name'])
          ? currentUserMap['name']
          : data['name'];
      data['profile_image'] = _looksLikeBadFallbackImage(data['profile_image'])
          ? currentUserMap['profile_image']
          : data['profile_image'];

      // Realtime create event often comes before API returns stream_image.
      // Use host profile image temporarily so the live card never shows random fallback.
      if (_looksLikeBadFallbackImage(data['stream_image']) &&
          !_looksLikeBadFallbackImage(currentUserMap['profile_image'])) {
        data['stream_image'] = currentUserMap['profile_image'];
      }
      if (_looksLikeBadFallbackImage(data['image']) &&
          !_looksLikeBadFallbackImage(currentUserMap['profile_image'])) {
        data['image'] = currentUserMap['profile_image'];
      }

      liveLog(
        '✅ Own live card hydrated from auth profile => ${data['id'] ?? data['livestream_id']} name=${currentUserMap['name']}',
      );
    }

    return data;
  }

  void _scheduleRealtimeLiveListRefresh() {
    if (_realtimeLiveRefreshScheduled) return;
    _realtimeLiveRefreshScheduled = true;

    _realtimeLiveRefreshTimer?.cancel();
    _realtimeLiveRefreshTimer = Timer(
      const Duration(milliseconds: 900),
      () async {
        if (_socketLifecycleClosed) {
          _realtimeLiveRefreshScheduled = false;
          return;
        }
        try {
          await homeController.getLivestreamList(
            page: 1,
            perPage: homeController.livePerPage.value,
            refresh: true,
          );
          liveLog('✅ Live list auto refreshed after realtime create/update');
        } catch (e) {
          liveLog('⚠️ Live list auto refresh skipped => $e');
        } finally {
          _realtimeLiveRefreshScheduled = false;
          _realtimeLiveRefreshTimer = null;
        }
      },
    );
  }

  void _handleUnifiedLiveStreamCreated(Map<String, dynamic> payload) {
    final streamDataRaw =
        payload['livestream'] ??
        payload['live_stream'] ??
        payload['stream'] ??
        payload['data'] ??
        payload;

    if (streamDataRaw is! Map) {
      liveLog('⚠️ live_stream_created invalid payload: $payload');
      return;
    }

    final streamData = _hydrateLiveCardForList(
      Map<String, dynamic>.from(streamDataRaw),
    );

    final streamId = streamData['id'] ?? streamData['livestream_id'];
    final userId = streamData['user_id'] ?? streamData['room_id'];

    if (streamId == null && userId == null) {
      liveLog('⚠️ live_stream_created missing stream id/user id: $payload');
      return;
    }

    homeController.showingLiveStreamList.removeWhere((stream) {
      final oldId = stream['id'] ?? stream['livestream_id'];
      final oldUserId = stream['user_id'] ?? stream['room_id'];
      return (streamId != null && oldId.toString() == streamId.toString()) ||
          (userId != null && oldUserId.toString() == userId.toString());
    });

    homeController.showingLiveStreamList.insert(0, streamData);
    homeController.sortLiveStreamList();
    homeController.showingLiveStreamList.refresh();
    _scheduleRealtimeLiveListRefresh();

    final int createdStreamId = _toInt(
      streamData['id'] ??
          streamData['livestream_id'] ??
          streamData['stream_id'],
    );
    final int currentStreamId = _toInt(streamID.value);

    /// IMPORTANT:
    /// অন্য host নতুন live create করলে current room এর seat/call/gift/comment state clear করা যাবে না।
    /// Example: current=6810, event=6931. Only live list update হবে, room state untouched থাকবে।
    if (currentStreamId > 0 &&
        createdStreamId > 0 &&
        createdStreamId != currentStreamId) {
      liveLog(
        '⛔ Other live_stream_created ignored for room state => event:$createdStreamId current:$currentStreamId',
      );
      return;
    }

    _activeCallPopupKeys.clear();
    _handledCallPopupKeys.clear();
    _locallyLeftStreamIds.clear();
    _viewerJoinedAtMs.clear();
    _recentRoomExitUserUntilMs.clear();
    pendingCall.clear();
    liveCallList.clear();
    pendingCall.refresh();
    _refreshLiveCallListSmooth();
    refreshCpSeatConnectionsFromCurrentCallList(
      source: 'live_stream_created_clear',
    );

    syncSeatLocksFromAnyPayload(
      streamData,
      allowUnlock: false,
      source: 'live_stream_created',
    );
    syncGiftCoinsFromPayload(streamData, source: 'live_stream_created');
    try {
      livestreamController.syncLiveGiftCoinsFromPayload(
        streamData,
        source: 'live_stream_created',
      );
    } catch (_) {}

    if (createdStreamId > 0) {
      fetchInitialGiftTotal(streamId: createdStreamId);
    }

    liveLog('✅ Unified live stream created/list updated: ${streamData['id']}');
  }

  bool _isLocalOwnerCloseInProgress(Map<String, dynamic> payload) {
    final String reason =
        (payload['reason'] ?? payload['end_reason'] ?? payload['message'] ?? '')
            .toString()
            .toLowerCase();

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    final int actorId = _toInt(
      payload['host_id'] ??
          payload['owner_user_id'] ??
          payload['actor_id'] ??
          payload['user_id'],
    );

    final bool ownerCloseReason =
        reason.contains('owner_closed_room') ||
        reason.contains('closed by owner') ||
        reason.contains('owner close');

    return livestreamController.isOwnerClosingPermanentRoom.value &&
        ownerCloseReason &&
        currentUserId > 0 &&
        (actorId <= 0 || actorId == currentUserId);
  }

  bool _isExplicitLiveEndPayload(Map<String, dynamic> payload) {
    final String reason =
        (payload['reason'] ??
                payload['end_reason'] ??
                payload['type'] ??
                payload['action'] ??
                '')
            .toString()
            .toLowerCase();

    final String message = (payload['message'] ?? '').toString().toLowerCase();

    /// These are temporary host/app lifecycle events.
    /// Backend can still send them as live_ended sometimes, but the REST list
    /// later shows the room again. So do not remove the card for these cases.
    final String joined = '$reason $message';
    if (joined.contains('new_live_created') ||
        joined.contains('host_left') ||
        joined.contains('host leave') ||
        joined.contains('host_disconnected') ||
        joined.contains('broadcaster_disconnected') ||
        joined.contains('reconnecting') ||
        joined.contains('background') ||
        joined.contains('minimize') ||
        joined.contains('temporary')) {
      return false;
    }

    /// Explicit end reasons should remove the room and force audience out.
    if (joined.contains('host_ended') ||
        joined.contains('ended_by_host') ||
        joined.contains('end_live') ||
        joined.contains('manual') ||
        joined.contains('admin') ||
        joined.contains('expired') ||
        joined.contains('force_end')) {
      return true;
    }

    /// If no soft reason is present, keep old behaviour for real live_ended events.
    return true;
  }

  void _handleUnifiedLiveStreamEnded(Map<String, dynamic> payload) {
    final livestreamId =
        payload['livestream_id'] ?? payload['stream_id'] ?? payload['id'];
    final userId = payload['user_id'] ?? payload['room_id'];

    if (livestreamId == null && userId == null) {
      liveLog('⚠️ live_stream_ended missing livestream_id/user_id: $payload');
      return;
    }

    final bool explicitEnd = _isExplicitLiveEndPayload(payload);

    if (!explicitEnd) {
      /// Do not remove the list item for temporary host leave/disconnect events.
      /// This fixes the glitch where the card disappears, then comes back after refresh.
      liveLog(
        'ℹ️ Soft live_end ignored, keeping live card => $livestreamId payload=$payload',
      );
      return;
    }

    homeController.showingLiveStreamList.removeWhere((stream) {
      final oldId = stream['id'] ?? stream['livestream_id'];
      final oldUserId = stream['user_id'] ?? stream['room_id'];

      return (livestreamId != null &&
              oldId.toString() == livestreamId.toString()) ||
          (userId != null && oldUserId.toString() == userId.toString());
    });

    homeController.sortLiveStreamList();
    homeController.showingLiveStreamList.refresh();

    final int endedStreamId = _toInt(livestreamId);

    if (endedStreamId > 0) {
      _locallyLeftStreamIds.add(endedStreamId);
    }

    /// For the owner who pressed Close Room, REST response is responsible
    /// for opening Endlive with complete arguments. Audience/guardian devices
    /// still follow the normal force-exit path below.
    if (_isLocalOwnerCloseInProgress(payload)) {
      isStreamEnded.value = true;
      isBroadcasterOnline.value = false;
      liveLog(
        '✅ Owner close live_ended received; waiting for REST Endlive navigation '
        '=> stream:$endedStreamId',
      );
      return;
    }

    final bool shouldForceExit =
        livestreamId != null && _isLiveRoomCurrentlyOpen(livestreamId);

    if (shouldForceExit) {
      _handleLiveStreamEnded({
        ...payload,
        'livestream_id': livestreamId,
        'joined_users': payload['joined_users'] ?? [],
        'message': payload['message'] ?? 'Live stream has ended',
      });
    } else {
      liveLog(
        'ℹ️ Live end list removed only, room not open here => $livestreamId',
      );
    }

    liveLog('✅ Unified live stream ended/list removed: $livestreamId');
  }

  void _handleUnifiedLiveStreamList(Map<String, dynamic> payload) {
    final list =
        payload['data'] ??
        payload['streams'] ??
        payload['live_streams'] ??
        payload['livestreams'];

    if (list is List) {
      /// Avoid UI flicker: sometimes websocket sends an empty/partial snapshot,
      /// then REST refresh brings the cards back. Keep the existing list in that case.
      if (list.isEmpty && homeController.showingLiveStreamList.isNotEmpty) {
        liveLog('ℹ️ Empty live_stream_list ignored to prevent list flicker');
        return;
      }

      homeController.showingLiveStreamList.assignAll(list);
      homeController.sortLiveStreamList();
      homeController.showingLiveStreamList.refresh();
      liveLog('✅ Unified live stream list updated: ${list.length}');
    } else {
      liveLog('⚠️ live_stream_list does not contain list: $payload');
    }
  }
}
