part of '../websocket_controller.dart';

extension SeatEventHandler on WebsocketController {
  int _seatEventRevision(Map<String, dynamic> data) {
    final int explicit = _eventTimeMs(
      data['event_timestamp'] ??
          data['occurred_at'] ??
          data['updated_at'] ??
          data['created_at'] ??
          data['timestamp'],
    );
    if (explicit > 0) return explicit;
    final String eventId = (data['event_id'] ?? '').toString();
    final matches = RegExp(r'(\d{10,13})').allMatches(eventId).toList();
    if (matches.isEmpty) return 0;
    return _eventTimeMs(matches.last.group(1));
  }

  /// Best-effort lookup of already-known profile info for [userId] from
  /// anything currently held on-device (live call/seat rows, pending call
  /// requests). Used so a seat_switched payload that omits the user object
  /// still renders a name/avatar instead of a blank seat.
  Map<String, dynamic> _bestKnownSeatUser(int userId) {
    if (userId <= 0) return <String, dynamic>{};

    Map<String, dynamic>? searchList(dynamic list) {
      if (list is! Iterable) return null;
      for (final raw in list) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        if (_callUserId(row) != userId) continue;
        final user = row['user'] is Map
            ? Map<String, dynamic>.from(row['user'])
            : <String, dynamic>{};
        if (user['name']?.toString().trim().isNotEmpty ?? false) {
          return user;
        }
      }
      return null;
    }

    try {
      final fromCallList = searchList(liveCallList);
      if (fromCallList != null) return fromCallList;
      final dynamic pending = pendingCall;
      final fromPending = searchList(pending);
      if (fromPending != null) return fromPending;
    } catch (_) {}

    return <String, dynamic>{};
  }

  bool applySeatSwitch({
    required int userId,
    required int fromSeatNo,
    required int toSeatNo,
    required Map<String, dynamic> callData,
    String source = 'socket',
    int revision = 0,
  }) {
    try {
      final int currentSeat = canonicalSeatForUser(userId);
      final int resolvedFromSeat = fromSeatNo > 0 ? fromSeatNo : currentSeat;
      // ✅ FIX: DateTime.now() as a fallback "revision" made ordering depend on
      // wall-clock time, which is unreliable across reconnects/processing
      // delays and could let a late-arriving-but-actually-older event win.
      // A monotonic local counter guarantees strictly-increasing revisions
      // for untimestamped events in the order this device actually processed
      // them.
      final int effectiveRevision = revision > 0
          ? revision
          : _nextLocalSeatRevision();
      final int previousRevision = _seatRevisionByUser[userId] ?? 0;
      if (effectiveRevision < previousRevision) {
        LiveRealtimeDebugLog.event('STALE_SEAT_EVENT_IGNORED', <String, Object?>{
          'user': userId,
          'from': resolvedFromSeat,
          'to': toSeatNo,
          'source': source,
        });
        return false;
      }

      // ✅ FIX: previously ANY existing occupant on the target seat caused this
      // switch to be rejected outright, even if that occupant's own local row
      // was stale (e.g. we simply missed their leave/seat-change event). That
      // silently blocked legitimate seat_switched updates from ever reaching
      // the host's screen. Now: only ignore this event if it is itself older
      // than what we already know about the conflicting occupant; otherwise
      // trust the newer, backend-confirmed switch and clear the stale ghost
      // occupant so the seat correctly shows the new user.
      Map<String, dynamic>? conflictingCall;
      for (final raw in liveCallList) {
        if (raw is! Map) continue;
        final call = Map<String, dynamic>.from(raw);
        final int seatOfCall = _toInt(
          call['seat_no'] ?? call['seat'] ?? call['seat_number'],
        );
        if (seatOfCall == toSeatNo && _callUserId(call) != userId) {
          conflictingCall = call;
          break;
        }
      }

      if (conflictingCall != null) {
        final int conflictingUserId = _callUserId(conflictingCall);
        final int conflictingRevision =
            _seatRevisionByUser[conflictingUserId] ?? 0;
        if (effectiveRevision <= conflictingRevision) {
          LiveRealtimeDebugLog.event('SEAT_CONFLICT_IGNORED', <String, Object?>{
            'user': userId,
            'from': resolvedFromSeat,
            'to': toSeatNo,
            'source': source,
            'conflicting_user': conflictingUserId,
          });
          return false;
        }

        liveCallList.removeWhere((raw) {
          if (raw is! Map) return false;
          final call = Map<String, dynamic>.from(raw);
          return _callUserId(call) == conflictingUserId &&
              _toInt(call['seat_no'] ?? call['seat'] ?? call['seat_number']) ==
                  toSeatNo;
        });
        printSeatTrace(
          'SEAT_CONFLICT_SELF_HEALED',
          streamId: _toInt(callData['livestream_id'] ?? streamID.value),
          seatNo: toSeatNo,
          userId: userId,
          note: 'displaced=$conflictingUserId source=$source',
        );
      }
      final index = liveCallList.indexWhere((call) {
        final callerId = call['caller_id'];
        final callUserId = call['user']?['id'] ?? call['User']?['id'];
        return callerId.toString() == userId.toString() ||
            callUserId.toString() == userId.toString();
      });

      final Map<String, dynamic> cpConnection = _cpSafeMap(
        callData['cp_connection'] ??
            callData['connection'] ??
            (callData['data'] is Map
                ? callData['data']['cp_connection']
                : null),
      );

      final normalizedCall = <String, dynamic>{
        ...callData,
        if (cpConnection.isNotEmpty) 'cp_connection': cpConnection,
        'caller_id': callData['caller_id'] ?? callData['user_id'] ?? userId,
        'user_id': callData['user_id'] ?? callData['caller_id'] ?? userId,
        'seat_no': toSeatNo,
        'my_seat_no': toSeatNo,
        'call_status':
        callData['call_status'] ?? callData['status'] ?? 'accepted',
      };

      if (index != -1) {
        final old = liveCallList[index];
        bool profilePreserved = false;
        if (old is Map) {
          final oldUser = old['user'] is Map
              ? Map<String, dynamic>.from(old['user'])
              : <String, dynamic>{};
          final newUser = normalizedCall['user'] is Map
              ? Map<String, dynamic>.from(normalizedCall['user'])
              : <String, dynamic>{};
          if (oldUser.isNotEmpty) {
            profilePreserved = newUser.isEmpty ||
                !newUser.containsKey('profile_image') ||
                !newUser.containsKey('name');
            final mergedUser = <String, dynamic>{
              ...oldUser,
              ...newUser,
            };
            for (final key in const <String>[
              'name',
              'username',
              'profile_image',
              'image',
              'avatar',
              'frame',
              'asset_purchase_history',
              'asset_purchase_histories',
              'profile_frame',
              'profile_frame_history',
            ]) {
              final value = mergedUser[key]?.toString().trim() ?? '';
              final oldValue = oldUser[key]?.toString().trim() ?? '';
              if ((value.isEmpty || value == 'null') && oldValue.isNotEmpty) {
                mergedUser[key] = oldUser[key];
                profilePreserved = true;
              }
            }
            normalizedCall['user'] = mergedUser;
          }
          normalizedCall['audio_on'] ??= old['audio_on'];
          normalizedCall['video_on'] ??= old['video_on'];
          normalizedCall['is_muted'] ??= old['is_muted'];
          normalizedCall['is_muted_by_host'] ??= old['is_muted_by_host'];
        }
        liveCallList[index] = normalizedCall;
        printSeatTrace(
          'SEAT_PROFILE_MERGE',
          streamId: _toInt(normalizedCall['livestream_id'] ?? streamID.value),
          seatNo: toSeatNo,
          userId: userId,
          note: 'profilePreserved=$profilePreserved',
        );
      } else {
        // ✅ FIX: previously a brand-new row was added as-is. If this
        // particular seat_switched payload didn't embed a full user object
        // (some backend events only send bare ids), the row went in with an
        // empty 'user' map and the seat rendered with no name/avatar at all
        // ("id hide hoye gese"). Now we first look for this same user
        // anywhere else already known on-device (e.g. their viewer_joined
        // row, or another stale seat row) and borrow real profile fields
        // from there before ever adding an empty-profile row.
        final Map<String, dynamic> incomingUser =
        normalizedCall['user'] is Map
            ? Map<String, dynamic>.from(normalizedCall['user'])
            : <String, dynamic>{};
        final bool incomingHasName =
        (incomingUser['name']?.toString().trim().isNotEmpty ?? false);
        if (!incomingHasName) {
          final Map<String, dynamic> hydratedUser = _bestKnownSeatUser(
            userId,
          );
          if (hydratedUser.isNotEmpty) {
            normalizedCall['user'] = {...hydratedUser, ...incomingUser};
          }
        }
        liveCallList.add(normalizedCall);
      }

      bool keptCanonicalUserRow = false;
      liveCallList.removeWhere((raw) {
        if (raw is! Map) return false;
        final call = Map<String, dynamic>.from(raw);
        if (_callUserId(call) != userId) return false;
        final int seat = _toInt(
          call['seat_no'] ?? call['seat'] ?? call['seat_number'],
        );
        if (seat == toSeatNo && !keptCanonicalUserRow) {
          keptCanonicalUserRow = true;
          return false;
        }
        return true;
      });
      _seatRevisionByUser[userId] = effectiveRevision;

      final seen = <String>{};
      liveCallList.removeWhere((call) {
        final seatNo = call['seat_no']?.toString() ?? '';
        final callerId =
            call['caller_id']?.toString() ??
                call['user']?['id']?.toString() ??
                '';
        final key = '$seatNo-$callerId';

        if (seen.contains(key)) return true;
        seen.add(key);
        return false;
      });

      _refreshLiveCallListSmooth();
      refreshCpSeatConnectionsFromCurrentCallList(
        source: 'apply_seat_switch_call_list',
      );
      syncCpSeatConnectionsFromAnyPayload(
        normalizedCall,
        source: 'apply_seat_switch',
      );
      printSeatTrace(
        'SEAT_OCCUPY',
        streamId: _toInt(normalizedCall['livestream_id'] ?? streamID.value),
        seatNo: toSeatNo,
        userId: userId,
        status: 'accepted',
        note: 'source=$source',
      );

      final currentUserId = _currentUserIdInt();

      if (currentUserId == userId) {
        _lastKnownSelfSeatNo = toSeatNo;
        _heartbeatTimeoutSeatGuardUntilMs.remove(userId);

        try {
          livestreamController.updateLivePresenceRole(
            role: 'caller',
            isOnSeat: true,
            seatNo: toSeatNo,
          );
        } catch (e) {
          liveLog('⚠️ Self seat-switch presence repair skipped: $e');
        }
      }

      liveLog(
        '✅ Seat switched applied => user:$userId from:$resolvedFromSeat to:$toSeatNo',
      );

      // ✅ FIX: same gap as the call-accept path in call_event_handler.dart —
      // a user landing on a seat via seat_switched must also be reflected in
      // the viewer list, even if their own viewer_joined event never
      // registered locally.
      _ensureViewerPresenceForAcceptedSeat(normalizedCall);

      return true;
    } catch (e) {
      liveLog('❌ applySeatSwitch error: $e');
      return false;
    }
  }

  void _handleUnifiedSeatSwitched(Map<String, dynamic> payload) {
    final Map<String, dynamic> data = payload['data'] is Map
        ? {
      ...Map<String, dynamic>.from(payload),
      ...Map<String, dynamic>.from(payload['data']),
    }
        : Map<String, dynamic>.from(payload);

    final livestreamId =
        data['livestream_id'] ?? data['stream_id'] ?? data['live_id'];
    if (livestreamId != null &&
        _toInt(livestreamId) > 0 &&
        !_isCurrentStream(livestreamId)) {
      liveLog(
        '⛔ seat_switched ignored: not current stream => $livestreamId current=${streamID.value}/${activeAudioStreamId.value}/${livestreamController.streamId.value}',
      );
      return;
    }

    final userId =
        int.tryParse(
          (data['user_id'] ?? data['caller_id'] ?? data['sender_id'] ?? 0)
              .toString(),
        ) ??
            0;
    final wireFromSeatNo =
        int.tryParse(
          (data['from_seat_no'] ?? data['old_seat_no'] ?? 0).toString(),
        ) ??
            0;
    final toSeatNo =
        int.tryParse(
          (data['to_seat_no'] ?? data['seat_no'] ?? data['my_seat_no'] ?? 0)
              .toString(),
        ) ??
            0;

    final callDataRaw =
        data['call_data'] ??
            data['caller'] ??
            data['call'] ??
            data['seat_user'];
    final callData = callDataRaw is Map
        ? <String, dynamic>{...data, ...Map<String, dynamic>.from(callDataRaw)}
        : <String, dynamic>{
      ...data,
      'livestream_id': data['livestream_id'],
      'caller_id': userId,
      'user_id': userId,
      'seat_no': toSeatNo,
      'call_status': 'accepted',
    };

    if (userId == 0 || toSeatNo == 0) {
      liveLog('⚠️ seat_switched ignored: invalid payload => $payload');
      return;
    }
    final int canonicalFromSeatNo = canonicalSeatForUser(userId);
    final int fromSeatNo = wireFromSeatNo > 0
        ? wireFromSeatNo
        : canonicalFromSeatNo;

    final int occupiedBefore = kDebugMode
        ? LiveRealtimeDebugLog.seatEntries(liveCallList).length
        : 0;
    final bool applied = applySeatSwitch(
      userId: userId,
      fromSeatNo: fromSeatNo,
      toSeatNo: toSeatNo,
      callData: callData,
      revision: _seatEventRevision(data),
    );
    if (!applied) return;

    /// CP connection/base image can be sent at root level, not inside call_data.
    /// Sync it immediately so every viewer sees the base without waiting for an API refresh.
    syncCpSeatConnectionsFromAnyPayload(data, source: 'seat_switched');
    LiveRealtimeDebugLog.event('SEAT_SWITCH', <String, Object?>{
      'room': _toInt(livestreamId),
      'user': userId,
      'from': fromSeatNo,
      'to': toSeatNo,
      'event_id': data['event_id'],
      'occupied_before': occupiedBefore,
      'occupied_after': kDebugMode
          ? LiveRealtimeDebugLog.seatEntries(liveCallList).length
          : 0,
    });
    _rtSeats(data);
    _rtState(data);
  }

  void _handleUnifiedSeatLockToggle(Map<String, dynamic> payload) {
    final Map<String, dynamic> data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload['seat'] is Map
        ? Map<String, dynamic>.from(payload['seat'])
        : Map<String, dynamic>.from(payload);

    final livestreamId =
        payload['livestream_id'] ??
            payload['stream_id'] ??
            data['livestream_id'] ??
            data['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      return;
    }

    /// Sync full locked_seats list first. Important: allowUnlock=false keeps
    /// already locked seats safe during viewer join / resume / partial refresh.
    try {
      syncSeatLocksFromAnyPayload(
        {...payload, ...data},
        allowUnlock: false,
        source: 'seat_lock_toggle_payload',
      );
    } catch (e) {
      liveLog('⚠️ seat lock list sync failed => $e');
    }

    final int seatNo =
        _seatToInt(
          data['seat_no'] ??
              data['seatNo'] ??
              data['seat'] ??
              data['seat_number'] ??
              payload['seat_no'] ??
              payload['seatNo'] ??
              payload['seat_number'],
        ) ??
            0;

    if (seatNo == 0) {
      liveLog('⚠️ seat_lock_toggle missing seat_no: $payload');
      return;
    }

    final rawLocked =
        data['is_locked'] ??
            data['locked'] ??
            data['lock'] ??
            data['seat_locked'] ??
            data['lock_status'] ??
            data['status'] ??
            data['action'] ??
            payload['is_locked'] ??
            payload['locked'] ??
            payload['status'] ??
            payload['action'];

    final text = rawLocked?.toString().toLowerCase().trim() ?? '';

    final bool explicitUnlock =
        _seatFalsey(rawLocked) || text.contains('unlock');
    final bool explicitLock =
        _seatTruthy(rawLocked) ||
            (text.contains('lock') && !text.contains('unlock'));

    if (explicitUnlock) {
      updateSeatLockStatus(
        seatNo: seatNo,
        isLocked: false,
        source: 'seat_lock_toggle_unlock',
      );
    } else if (explicitLock) {
      updateSeatLockStatus(
        seatNo: seatNo,
        isLocked: true,
        source: 'seat_lock_toggle_lock',
      );
    } else {
      /// Do not unlock on empty/partial seat payload.
      /// Viewer join/live refresh sometimes sends seat data without lock keys,
      /// and that must not clear a previously locked seat.
      liveLog(
        'ℹ️ seat_lock_toggle ignored: no explicit lock/unlock value => seat:$seatNo raw:$rawLocked',
      );
      return;
    }

    liveLog(
      '✅ Unified seat lock toggle handled => seat:$seatNo locked:${isSeatLocked(seatNo)} raw:$rawLocked',
    );
  }
}