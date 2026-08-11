part of '../websocket_controller.dart';

extension SeatEventHandler on WebsocketController {
  void applySeatSwitch({
    required int userId,
    required int fromSeatNo,
    required int toSeatNo,
    required Map<String, dynamic> callData,
  }) {
    try {
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
        if (old is Map) {
          normalizedCall['user'] ??= old['user'];
          normalizedCall['audio_on'] ??= old['audio_on'];
          normalizedCall['video_on'] ??= old['video_on'];
          normalizedCall['is_muted'] ??= old['is_muted'];
          normalizedCall['is_muted_by_host'] ??= old['is_muted_by_host'];
        }
        liveCallList[index] = normalizedCall;
      } else {
        liveCallList.add(normalizedCall);
      }

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
      livestreamController.update();

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
        '✅ Seat switched applied => user:$userId from:$fromSeatNo to:$toSeatNo',
      );
    } catch (e) {
      liveLog('❌ applySeatSwitch error: $e');
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
    final fromSeatNo =
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

    applySeatSwitch(
      userId: userId,
      fromSeatNo: fromSeatNo,
      toSeatNo: toSeatNo,
      callData: callData,
    );

    /// CP connection/base image can be sent at root level, not inside call_data.
    /// Sync it immediately so every viewer sees the base without waiting for an API refresh.
    syncCpSeatConnectionsFromAnyPayload(data, source: 'seat_switched');
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
