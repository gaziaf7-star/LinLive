part of '../popular_live_view.dart';

/// Small utility/formatting helpers used across popular_live_view.dart.
/// Extracted from _PopularLiveViewState during file-splitting refactor —
/// pure logic move only, no behavior changes.
extension PopularLiveHelpers on _PopularLiveViewState {
  Widget _miniNamePill(dynamic broadcaster) {
    final name = _safeUserName(broadcaster, fallback: '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name != null
            ? name.length > 10
            ? '${name.substring(0, 10)}...'
            : name
            : '',
        style: TextStyle(
          color: Colors.white,
          fontSize: kHeight * 0.011,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _popularBackgroundImageUrl() {
    final Map<String, dynamic> live = _safeMap(streamData?['livestreamdata']);
    final List<dynamic> candidates = <dynamic>[
      live['room_background_image'],
      live['background_image'],
      live['stream_image'],
      streamData?['room_background_image'],
      streamData?['background_image'],
      streamData?['stream_image'],
      broadcasterData['room_background_image'],
      broadcasterData['background_image'],
      broadcasterData['stream_image'],
      _safeUserMap(broadcasterData)['profile_image'],
    ];
    for (final dynamic candidate in candidates) {
      final String raw = candidate?.toString().trim() ?? '';
      if (raw.isEmpty || raw == 'null') continue;
      return ImageHelper.getImageUrl(raw);
    }
    return '';
  }

  String _safeProfileImage(dynamic image) {
    final raw = image?.toString().trim() ?? '';

    if (raw.isEmpty || raw == 'null') {
      return 'https://ui-avatars.com/api/?name=User&background=8A4CF7&color=fff';
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final url = ImageHelper.getImageUrl(raw);
    if (url.trim().isEmpty || url == 'file:///') {
      return 'https://ui-avatars.com/api/?name=User&background=8A4CF7&color=fff';
    }

    return url;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _safeUserMap(dynamic value) {
    final map = _safeMap(value);

    final directUser = map['user'] ?? map['User'];
    if (directUser is Map) {
      return Map<String, dynamic>.from(directUser);
    }

    final callerData =
        map['caller_data'] ?? map['call_data'] ?? map['accepted_caller'];
    if (callerData is Map) {
      final nestedUser = callerData['user'] ?? callerData['User'];
      if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
    }

    final viewerData = map['viewer_data'] ?? map['viewer'];
    if (viewerData is Map) {
      final nestedUser = viewerData['user'] ?? viewerData['User'];
      if (nestedUser is Map) return Map<String, dynamic>.from(nestedUser);
    }

    return <String, dynamic>{};
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return fallback;
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt() ?? fallback;
  }

  int _safeUserId(dynamic value) {
    final map = _safeMap(value);
    final user = _safeUserMap(value);

    return _safeInt(
      user['id'] ??
          user['user_id'] ??
          map['user_id'] ??
          map['caller_id'] ??
          map['viewer_id'] ??
          map['host_id'] ??
          map['uid'],
    );
  }

  String _safeUserName(dynamic value, {String fallback = 'User'}) {
    final map = _safeMap(value);
    final user = _safeUserMap(value);
    final raw =
    (user['name'] ??
        user['full_name'] ??
        map['name'] ??
        map['caller_name'] ??
        map['display_name'] ??
        fallback)
        .toString()
        .trim();
    return raw.isEmpty || raw == 'null' ? fallback : raw;
  }

  String _safeUserProfile(dynamic value) {
    final map = _safeMap(value);
    final user = _safeUserMap(value);
    return _safeProfileImage(
      user['profile_image'] ??
          user['avatar'] ??
          map['profile_image'] ??
          map['caller_image'] ??
          map['image'],
    );
  }

  bool _hasValidUser(dynamic value) {
    return _safeUserId(value) > 0 || _safeUserMap(value).isNotEmpty;
  }

  int _safeCurrentGiftCoins() {
    final fromWs = _safeInt(websocketController.totalGiftCoins.value);
    if (fromWs > 0) return fromWs;

    final callList = websocketController.liveCallList;
    if (callList.isNotEmpty) {
      final first = _safeMap(callList.first);
      return _safeInt(
        first['earn_coins'] ??
            first['earned_coins'] ??
            first['total_gift_coins'] ??
            first['received_coins'] ??
            first['stream_coins'] ??
            first['gifts_coins'],
      );
    }

    return _safeInt(
      streamInfo['total_gift_coins'] ??
          streamInfo['received_coins'] ??
          streamInfo['stream_coins'] ??
          streamInfo['gifts_coins'],
    );
  }

  String _formatShortCoins(int coins) {
    if (coins >= 1000000) {
      final value = coins / 1000000;
      return value % 1 == 0
          ? '${value.toInt()}M'
          : '${value.toStringAsFixed(1)}M';
    }
    if (coins >= 1000) {
      final value = coins / 1000;
      return value % 1 == 0
          ? '${value.toInt()}k'
          : '${value.toStringAsFixed(1)}k';
    }
    return coins.toString();
  }

  bool _isAcceptedCall(dynamic raw) {
    final call = _safeMap(raw);
    final status = (call['call_status'] ?? call['status'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'live' ||
        status == 'on_seat';
  }

  bool _callWantsVideo(dynamic raw) {
    final call = _safeMap(raw);
    final type = (call['call_type'] ?? call['type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return type == 'video' || type == 'popular';
  }

  bool _callVideoEnabled(dynamic raw) {
    final call = _safeMap(raw);
    final value = call['video_on'] ?? call['is_video_on'];
    if (value == null) return _callWantsVideo(call);
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;
    final text = value.toString().toLowerCase().trim();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'enabled';
  }

  bool _isActiveVideoCall(dynamic raw) {
    return _isAcceptedCall(raw) && _callWantsVideo(raw);
  }

  bool _uidsAreEquivalent(int first, int second) {
    if (first <= 0 || second <= 0) return false;
    return first == second ||
        first + 100000 == second ||
        second + 100000 == first;
  }

  int _resolvedHostUserId() {
    final streamUser = _safeUserMap(streamInfo);
    final direct = _safeInt(
      streamInfo['user_id'] ??
          streamInfo['host_id'] ??
          streamInfo['broadcaster_id'] ??
          streamInfo['owner_user_id'] ??
          streamUser['id'] ??
          streamUser['user_id'],
    );
    if (direct > 0) return direct;
    return _safeUserId(broadcasterData);
  }

  int _remoteUidForCaller(int callerId) {
    if (callerId <= 0) return 0;
    final mapped = liveController.videoCallerAgoraUidMap[callerId] ?? 0;
    if (mapped > 0 && _joinedRemoteUids.contains(mapped)) return mapped;
    return _joinedRemoteUids.firstWhere(
          (uid) => _uidsAreEquivalent(uid, callerId),
      orElse: () => 0,
    );
  }

}