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

    liveLog('✅ Imogi animation shown => sender:$senderId imogi:$imogiId');

    Timer(const Duration(milliseconds: 3600), () {
      liveImogiAnimations.removeWhere(
        (item) => item['event_id'].toString() == eventId,
      );
      liveImogiAnimations.refresh();
    });
  }
}
