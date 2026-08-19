part of '../websocket_controller.dart';

extension EmojiEventHandler on WebsocketController {
  void handleEmojiAnimation(Map<String, dynamic> emojiData) {
    try {
      // Add emoji to animation list
      emojiAnimations.add({
        'emoji': emojiData['emoji'],
        'user': emojiData['user'],
        'timestamp': emojiData['timestamp'],
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // Show animation
      showEmojiAnimation.value = true;

      // Remove emoji after 5 seconds
      Timer(Duration(seconds: 5), () {
        if (emojiAnimations.isNotEmpty) {
          emojiAnimations.removeAt(0);
        }
        if (emojiAnimations.isEmpty) {
          showEmojiAnimation.value = false;
        }
      });

      liveLog('✅ Emoji animation started: ${emojiData['emoji']}');
    } catch (e) {
      liveLog('❌ Error showing emoji animation: $e');
    }
  }

  /// New audio room open hole old room-er comments/entry/gift/seat data clear.
  /// Same stream/minimize return hole clear korbe na.

  void handleLocalImogiSent(Map<String, dynamic> payload) {
    _handleUnifiedImogiSent(payload, isLocal: true);
  }

  /// Public helper for local preview if needed.
  /// Existing backend websocket event still controls realtime display for everyone.
  void showLocalImogiAnimation(Map<String, dynamic> payload) {
    _handleUnifiedImogiSent(payload, isLocal: true);
  }

  void _handleUnifiedImogiSent(
      Map<String, dynamic> payload, {
        bool isLocal = false,
      }) {
    // ✅ DEBUG: liveLog may be gated by an extra flag beyond kDebugMode and
    // could be silently suppressing output even though this function runs
    // fine — debugPrint is guaranteed to show in logcat regardless, so this
    // definitively answers "is this function even being entered".
    debugPrint('🤖🤖🤖 [IMOGI_DEBUG] _handleUnifiedImogiSent ENTERED isLocal=$isLocal payload=$payload');
    liveLog('🤖 IMOGI RAW PAYLOAD => $payload');

    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : Map<String, dynamic>.from(payload);

    final livestreamId =
        data['livestream_id'] ??
            data['stream_id'] ??
            data['streamId'] ??
            payload['livestream_id'] ??
            payload['stream_id'];

    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      debugPrint('🤖🤖🤖 [IMOGI_DEBUG] BLOCKED: not current stream => livestreamId=$livestreamId');
      liveLog('⛔ IMOGI ignored: not current stream => $livestreamId');
      return;
    }

    final imogi = data['imogi'] is Map
        ? Map<String, dynamic>.from(data['imogi'])
        : data['emoji'] is Map
        ? Map<String, dynamic>.from(data['emoji'])
        : data['imogi_data'] is Map
        ? Map<String, dynamic>.from(data['imogi_data'])
        : <String, dynamic>{
      'id': data['imogi_id'] ?? data['emoji_id'],
      'name': data['imogi_name'] ?? data['emoji_name'] ?? 'Imogi',
      'image':
      data['imogi_image'] ?? data['emoji_image'] ?? data['image'],
      'category': data['category'],
    };

    final sender = data['sender'] is Map
        ? Map<String, dynamic>.from(data['sender'])
        : data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : <String, dynamic>{
      'id': data['sender_id'] ?? data['user_id'],
      'name': data['sender_name'] ?? data['user_name'] ?? 'User',
      'level': data['sender_level'] ?? data['level'] ?? 0,
      'profile_image':
      data['sender_profile_image'] ??
          data['profile_image'] ??
          data['avatar'],
    };

    final senderId = sender['id'] ?? data['sender_id'] ?? data['user_id'] ?? '';
    final imogiId = imogi['id'] ?? data['imogi_id'] ?? data['emoji_id'] ?? '';
    final eventId =
    (data['id'] ??
        data['event_id'] ??
        '${livestreamId}_${senderId}_${imogiId}_${data['timestamp'] ?? data['created_at'] ?? DateTime.now().millisecondsSinceEpoch}')
        .toString();

    // ✅ FIX (emoji vanishes/never shows): confirmed via logging that the
    // server's REAL confirmation event for a send is a content-less
    // acknowledgement — {success:true, message:"Imogi sent successfully.",
    // sender:{...}} — with NO imogi/image data at all, unlike the LOCAL
    // preview event which does carry the real imogi id + image. Two
    // consequences, both fixed here:
    //
    // 1) echoKey previously included imogiId, but the real event's imogiId
    //    is always empty, so it never matched the local echo's key (which
    //    has the real id) and the "skip this, it's just an echo" check
    //    below never fired. Keying on sender+room only fixes the match.
    final String echoKey = '${livestreamId}_$senderId';
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    // 2) Even with the key fixed, a content-less real event reaching here
    // would still overwrite/hide the correct local entry the instant it
    // arrives, since _activeImogiForUser always shows the most-recently-
    // added entry for a sender. A real event with no actual image can
    // never render anything useful, so skip adding it outright — the
    // local preview (which already displayed the real emoji) is the
    // entry that should keep playing out its full animation undisturbed.
    final String resolvedImage = (imogi['image'] ?? '').toString().trim();
    if (!isLocal && resolvedImage.isEmpty) {
      liveLog(
        'ℹ️ Real imogi event has no image (content-less ack) — not overwriting local preview => sender:$senderId',
      );
      _localImogiEchoes.remove(echoKey);
      return;
    }

    // Local sends never take from processedImogiIds' duplicate-guard below
    // (isLocal always bypasses it, same as before), but they DO register
    // themselves here so the real event can recognize and skip its own echo.
    if (isLocal) {
      _localImogiEchoes[echoKey] = nowMs;
    } else {
      final int? localAt = _localImogiEchoes[echoKey];
      if (localAt != null && nowMs - localAt <= 4000) {
        liveLog(
          'ℹ️ Real imogi event skipped: matches recent local echo => $echoKey',
        );
        _localImogiEchoes.remove(echoKey);
        return;
      }
    }
    // Bound this map the same way processedImogiIds is bounded below.
    if (_localImogiEchoes.length > 60) {
      _localImogiEchoes.remove(_localImogiEchoes.keys.first);
    }

    if (!isLocal && processedImogiIds.contains(eventId)) {
      liveLog('ℹ️ Duplicate imogi ignored => $eventId');
      return;
    }

    processedImogiIds.add(eventId);
    if (processedImogiIds.length > 120) {
      processedImogiIds.remove(processedImogiIds.first);
    }

    final animationData = <String, dynamic>{
      'event_id': eventId,
      'livestream_id': livestreamId,
      'sender': sender,
      'imogi': imogi,
      'image': imogi['image'],
      'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
    };

    liveImogiAnimations.add(animationData);
    liveImogiAnimations.refresh();

    debugPrint('🤖🤖🤖 [IMOGI_DEBUG] ADDED to liveImogiAnimations => event_id=$eventId sender=$senderId image=${imogi['image']} total_count=${liveImogiAnimations.length}');
    liveLog('✅ Imogi animation shown => sender:$senderId imogi:$imogiId');

    Timer(const Duration(milliseconds: 3600), () {
      liveImogiAnimations.removeWhere(
            (item) => item['event_id'].toString() == eventId,
      );
      liveImogiAnimations.refresh();
    });
  }
}