part of '../websocket_controller.dart';

extension ModerationEventHandler on WebsocketController {
  Future<void> _handleUnifiedModeration(Map<String, dynamic> payload) async {
    try {
      final moderationData = Map<String, dynamic>.from(
        payload['moderation_data'] ?? payload['data'] ?? payload,
      );

      final action =
          (moderationData['action'] ??
                  moderationData['moderation_action'] ??
                  moderationData['type'] ??
                  moderationData['action_type'] ??
                  '')
              .toString()
              .toLowerCase();

      liveLog(
        '🔔 Unified moderation action => $action payload=$moderationData',
      );

      switch (action) {
        case 'kickout':
        case 'kick_out':
          _handleKickOut(moderationData);
          break;

        case 'audio_toggle':
        case 'multi_live_audio_toggle':
        case 'mute_toggle':
        case 'mic_toggle':
        case 'microphone_toggle':
        case 'mute':
        case 'unmute':
          await _handleUnifiedAudioToggle(moderationData);
          break;

        case 'video_toggle':
        case 'multi_live_video_toggle':
          await _handleUnifiedVideoToggle(moderationData);
          break;

        case 'make_guardian':
        case 'set_guardian':
        case 'assign_guardian':
        case 'guardian_assigned':
        case 'remove_guardian':
        case 'guardian_removed':
        case 'unassign_guardian':
          await livestreamController.applyGuardianFromSocket(moderationData);
          break;

        case 'live_stream_ended':
        case 'live_ended':
          _handleUnifiedLiveStreamEnded(moderationData);
          break;

        case 'broadcaster_disconnected':
        case 'host_left_room':
        case 'host_left':
        case 'host_disconnected':
        case 'host_reconnecting':
        case 'broadcaster_reconnecting':
          liveLog('ℹ️ Host disconnected moderation ignored for live end');
          break;

        default:
          liveLog('ℹ️ Unknown moderation action: $action');
          liveLog('Payload: $moderationData');
          break;
      }
    } catch (e, st) {
      liveLog('❌ _handleUnifiedModeration error => $e\n$st');
    }
  }

  Future<void> _handleUnifiedAudioToggle(Map<String, dynamic> payload) async {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final dynamic seatNo =
          data['seat_no'] ??
          data['seat'] ??
          data['seat_number'] ??
          data['seatNo'];

      final bool hasExplicitTargetUser =
          data['target_user_id'] != null ||
          data['receiver_id'] != null ||
          data['to_user_id'] != null ||
          data['caller_id'] != null ||
          data['user_id'] != null ||
          data['uid'] != null;

      dynamic userId =
          data['target_user_id'] ??
          data['receiver_id'] ??
          data['to_user_id'] ??
          data['caller_id'] ??
          data['user_id'] ??
          data['uid'];

      /// Host-er nijer mute/unmute event-e kichu backend only host_id/broadcaster_id
      /// pathay. Seat remove/join event-e host_id actor hote pare, tai only
      /// audio_toggle handler-e explicit target na thakle ebong seatNo na thakle
      /// host_id ke host mute target dhorbo.
      if (!hasExplicitTargetUser && seatNo == null) {
        userId =
            data['host_id'] ??
            data['broadcaster_id'] ??
            data['broadcaster_user_id'] ??
            payload['host_id'] ??
            payload['broadcaster_id'];
      }

      final dynamic audioRaw =
          data['audio_on'] ??
          data['is_audio_on'] ??
          data['mic_on'] ??
          data['microphone_on'];

      final dynamic mutedRaw =
          data['is_muted'] ??
          data['muted'] ??
          data['is_muted_by_host'] ??
          data['mute_status'];

      bool audioFalse(dynamic v) {
        final s = v?.toString().toLowerCase().trim() ?? '';
        return s == '0' ||
            s == 'false' ||
            s == 'no' ||
            s == 'off' ||
            s == 'mute' ||
            s == 'muted';
      }

      bool audioTrue(dynamic v) {
        final s = v?.toString().toLowerCase().trim() ?? '';
        return s == '1' ||
            s == 'true' ||
            s == 'yes' ||
            s == 'on' ||
            s == 'unmute' ||
            s == 'unmuted';
      }

      bool? muted;

      if (audioFalse(audioRaw)) muted = true;
      if (audioTrue(audioRaw)) muted = false;

      /// is_muted true means muted, is_muted false means unmuted.
      if (audioTrue(mutedRaw)) muted = true;
      if (audioFalse(mutedRaw)) muted = false;

      /// No audio/mute key means this is a partial payload. Never reset old state.
      if (muted == null) {
        return;
      }

      final int currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;

      final int targetUserIdForMuteMap =
          int.tryParse(userId?.toString() ?? '0') ?? 0;
      if (targetUserIdForMuteMap > 0) {
        audioMutedUserMap[targetUserIdForMuteMap] = muted;
        audioMutedUserMap.refresh();
      }

      bool updated = false;
      bool eventTargetsCurrentUser = false;

      for (int i = 0; i < liveCallList.length; i++) {
        final item = liveCallList[i];
        if (item is! Map) continue;

        final Map<String, dynamic> call = Map<String, dynamic>.from(item);

        final dynamic itemUserId = call['user'] is Map
            ? call['user']['id']
            : (call['user_id'] ?? call['caller_id'] ?? call['id']);

        final dynamic itemSeatNo =
            call['seat_no'] ??
            call['seat'] ??
            call['seat_number'] ??
            call['seatNo'];

        final bool sameUser =
            userId != null &&
            itemUserId != null &&
            userId.toString() == itemUserId.toString();

        final bool sameSeat =
            seatNo != null &&
            itemSeatNo != null &&
            seatNo.toString() == itemSeatNo.toString();

        if (sameUser || sameSeat) {
          final dynamic rowUserId = call['user'] is Map
              ? call['user']['id']
              : (call['user_id'] ?? call['caller_id'] ?? call['id']);

          final bool rowIsCurrentUser =
              currentUserId > 0 &&
              rowUserId != null &&
              rowUserId.toString() == currentUserId.toString();

          if (rowIsCurrentUser) {
            eventTargetsCurrentUser = true;
          }

          final int rowUserInt =
              int.tryParse(rowUserId?.toString() ?? '0') ?? 0;
          if (rowUserInt > 0) {
            audioMutedUserMap[rowUserInt] = muted;
          }

          call['audio_on'] = muted ? 0 : 1;
          call['is_audio_on'] = muted ? 0 : 1;
          call['is_muted'] = muted ? 1 : 0;
          call['is_muted_by_host'] = muted ? 1 : 0;
          if (muted) {
            call['is_speaking'] = false;
          }

          if (call['user'] is Map) {
            final user = Map<String, dynamic>.from(call['user']);
            user['audio_on'] = muted ? 0 : 1;
            user['is_audio_on'] = muted ? 0 : 1;
            user['is_muted'] = muted ? 1 : 0;
            call['user'] = user;
          }

          liveCallList[i] = call;
          updated = true;
        }
      }

      /// If backend sends only user_id (without hydrated liveCallList row yet),
      /// still apply the real Agora mic state when this event is for me.
      if (currentUserId > 0 &&
          userId != null &&
          userId.toString() == currentUserId.toString()) {
        eventTargetsCurrentUser = true;
      }

      if (updated) {
        _refreshLiveCallListSmooth();
        audioMutedUserMap.refresh();
        livestreamController.update();
      } else {}

      /// ✅ CRITICAL FIX v3:
      /// Host/admin mute/unmute must control the TARGET user's real Agora
      /// microphone publishing state. UI icon update alone is not enough.
      ///
      /// Important:
      /// - Never keep enableLocalAudio(false) after host-unmute.
      /// - On unmute, force caller role back to broadcaster and explicitly
      ///   publish microphone track again. Otherwise UI can show unmuted but
      ///   the host will not hear audio until the user taps his own mic button.
      if (eventTargetsCurrentUser && _agoraService.engine != null) {
        final engine = _agoraService.engine!;

        // Keep controller self mute flag in sync with host/admin mute state.
        // write_comments.dart uses livestreamController.mute as fallback.
        livestreamController.mute.value = muted;

        if (muted) {
          await engine.enableAudio();
          await engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await engine.enableLocalAudio(true);
          await engine.muteLocalAudioStream(true);

          // Extra safety: stop volume/wave from this local user while muted.
          try {
            await engine.adjustRecordingSignalVolume(0);
          } catch (_) {}
        } else {
          // Force full microphone re-publish when host unmute kore.
          // Order matters for Agora: role -> audio engine -> local audio -> unmute.
          await engine.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          await engine.enableAudio();
          await engine.enableLocalAudio(true);

          // Agora 6.x: make sure microphone publishing is turned back on.
          // Some devices keep publishMicrophoneTrack=false after admin mute/role switch.
          try {
            await engine.updateChannelMediaOptions(
              const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishMicrophoneTrack: true,
                autoSubscribeAudio: true,
              ),
            );
          } catch (e) {}

          await engine.muteLocalAudioStream(false);

          // Restore recording volume. Without this, wave/audio can stay silent
          // after previous forced mute.
          try {
            await engine.adjustRecordingSignalVolume(100);
          } catch (_) {}

          try {
            await engine.enableAudioVolumeIndication(
              interval: 600,
              smooth: 3,
              reportVad: true,
            );
          } catch (_) {}
        }
      }
    } catch (e, st) {
      liveLog('❌ _handleUnifiedAudioToggle error => $e\n$st');
    }
  }

  Future<void> _handleUnifiedVideoToggle(Map<String, dynamic> payload) async {
    final normalized = <String, dynamic>{
      ...payload,
      'user_id': payload['user_id'] ?? payload['caller_id'],
    };
    if (payload.containsKey('video_on')) {
      normalized['video_on'] = payload['video_on'];
    } else if (payload.containsKey('is_video_on')) {
      normalized['is_video_on'] = payload['is_video_on'];
    }
    await _handleVideoToggle(normalized);
  }

  void _handleUnifiedSpeaking(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : Map<String, dynamic>.from(payload);

    final userId =
        data['user_id'] ??
        data['target_user_id'] ??
        data['receiver_id'] ??
        data['caller_id'] ??
        data['uid'];
    final isSpeaking = data['is_speaking'] ?? data['speaking'] ?? false;

    final index = liveCallList.indexWhere((call) {
      if (call is! Map) return false;
      final dynamic rowUserId = call['user'] is Map
          ? call['user']['id']
          : (call['caller_id'] ?? call['user_id'] ?? call['id']);
      return rowUserId.toString() == userId.toString();
    });

    if (index != -1) {
      final item = liveCallList[index];
      if (item is Map) {
        final call = Map<String, dynamic>.from(item);
        final bool muted =
            call['audio_on']?.toString() == '0' ||
            call['is_muted']?.toString() == '1' ||
            call['is_muted_by_host']?.toString() == '1';

        /// Muted seat/user should not show voice wave even if a late speaking
        /// event arrives from Agora/backend.
        call['is_speaking'] = muted ? false : isSpeaking;
        liveCallList[index] = call;
      } else {
        liveCallList[index]['is_speaking'] = isSpeaking;
      }
      _refreshLiveCallListSmooth();
    }
  }
}
