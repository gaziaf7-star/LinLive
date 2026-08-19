part of '../popular_live_view.dart';

/// Speaking-indicator + mute-state checks, and PK Agora-uid normalization
/// helpers, used across popular_live_view.dart. Extracted from
/// _PopularLiveViewState during file-splitting refactor — pure logic
/// move only, no behavior changes.
extension PopularLiveSpeakingMute on _PopularLiveViewState {
  int _normalizeAgoraUid(int uid) {
    /// Agora local user-er jonno kichu case-e uid 0 aste pare.
    /// Tokhon current logged-in user id use korbo.
    if (uid == 0) {
      return authController.userProfile.value.user?.id?.toInt() ?? 0;
    }
    return uid;
  }

  /// PK remote video render helper.
  /// Backend/App sometimes uses host id directly (100448), and sometimes old host id
  /// gets mapped to Agora uid by adding 100000. This function keeps both safe.
  int _pkAgoraRenderUidFromHostId(int hostId) {
    if (hostId <= 0) return 0;

    // Already Agora-style uid, like 100448.
    if (hostId >= 100000) return hostId;

    // If Agora callback already gave this exact uid, use it.
    if (_pkRemoteUids.contains(hostId)) return hostId;

    final int mappedUid = 100000 + hostId;
    if (_pkRemoteUids.contains(mappedUid)) return mappedUid;

    // Token logs show PK UID as 100xxx, so fallback to mapped uid.
    return mappedUid;
  }

  /// Current logged-in user and PK host can be stored as different but equivalent
  /// ids, for example 448 vs 100448. This keeps local-host detection correct.
  bool _isSamePkHost({required int currentUid, required int hostId}) {
    if (currentUid <= 0 || hostId <= 0) return false;
    if (currentUid == hostId) return true;

    if (currentUid >= 100000 && currentUid - 100000 == hostId) return true;
    if (hostId >= 100000 && hostId - 100000 == currentUid) return true;

    final int mappedCurrent = currentUid >= 100000
        ? currentUid
        : currentUid + 100000;
    final int mappedHost = hostId >= 100000 ? hostId : hostId + 100000;
    return mappedCurrent == mappedHost;
  }

  /// Remote host online check for PK waiting overlay.
  /// Local host should be treated as online immediately.
  bool _isPkRemoteHostOnline(int hostId) {
    if (hostId <= 0) return false;

    final int currentUid =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (_isSamePkHost(currentUid: currentUid, hostId: hostId)) return true;

    if (_pkRemoteUids.contains(hostId)) return true;

    final int renderUid = _pkAgoraRenderUidFromHostId(hostId);
    if (renderUid > 0 && _pkRemoteUids.contains(renderUid)) return true;

    // Reverse mapping support just in case callback returns old uid.
    if (hostId >= 100000 && _pkRemoteUids.contains(hostId - 100000))
      return true;
    if (hostId < 100000 && _pkRemoteUids.contains(hostId + 100000)) return true;

    return false;
  }

  bool _isUserSpeaking(dynamic userId) {
    final id = int.tryParse(userId?.toString() ?? '') ?? 0;
    return id != 0 && _speakingUserIds.contains(id);
  }

  bool _isCallMuted(dynamic call) {
    if (call is! Map) return false;

    bool isTruthy(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value.toInt() == 1;
      final text = value?.toString().toLowerCase().trim() ?? '';
      return text == '1' ||
          text == 'true' ||
          text == 'yes' ||
          text == 'muted' ||
          text == 'mute';
    }

    bool isAudioOff(dynamic value) {
      if (value is bool) return !value;
      if (value is num) return value.toInt() == 0;
      final text = value?.toString().toLowerCase().trim() ?? '';
      return text == '0' ||
          text == 'false' ||
          text == 'off' ||
          text == 'muted' ||
          text == 'mute';
    }

    return isAudioOff(call['audio_on'] ?? call['is_audio_on']) ||
        isTruthy(call['is_muted']) ||
        isTruthy(call['is_muted_by_host']) ||
        isTruthy(call['muted']);
  }

  bool _isUserMuted(dynamic userId) {
    final id = int.tryParse(userId?.toString() ?? '') ?? 0;
    if (id == 0) return false;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (id == currentUserId && liveController.mute.value == true) {
      return true;
    }

    final index = websocketController.liveCallList.indexWhere((call) {
      final callerId = call['caller_id'];
      final uid = call['user']?['id'] ?? callerId;
      return uid.toString() == id.toString();
    });

    if (index == -1) return false;

    return _isCallMuted(websocketController.liveCallList[index]);
  }

  void _setSpeakingStatus({required int uid, required bool isSpeaking}) {
    final userId = _normalizeAgoraUid(uid);
    if (userId == 0) return;

    /// Muted user kotha bolleo wave show korbe na.
    if (isSpeaking && _isUserMuted(userId)) {
      isSpeaking = false;
    }

    final bool alreadySpeaking = _speakingUserIds.contains(userId);

    if (isSpeaking) {
      _speakingOffTimers[userId]?.cancel();
      _speakingOffTimers[userId] = Timer(const Duration(milliseconds: 700), () {
        _setSpeakingStatus(uid: userId, isSpeaking: false);
      });

      if (!alreadySpeaking) {
        _speakingUserIds.add(userId);
        _updateLiveCallSpeakingStatus(userId: userId, isSpeaking: true);
        _scheduleUIUpdate();
      }
    } else {
      _speakingOffTimers[userId]?.cancel();
      _speakingOffTimers.remove(userId);

      if (alreadySpeaking) {
        _speakingUserIds.remove(userId);
        _updateLiveCallSpeakingStatus(userId: userId, isSpeaking: false);
        _scheduleUIUpdate();
      }
    }
  }

  void _updateLiveCallSpeakingStatus({
    required int userId,
    required bool isSpeaking,
  }) {
    final index = websocketController.liveCallList.indexWhere((call) {
      final callerId = call['caller_id'];
      final uid = call['user']?['id'] ?? callerId;
      return uid.toString() == userId.toString();
    });

    if (index != -1) {
      websocketController.liveCallList[index]['is_speaking'] = isSpeaking;
      // Do not refresh the whole Rx call list on every audio-volume callback.
      // The debounced page repaint below is enough and avoids extra heat/jank.
    }
  }
}