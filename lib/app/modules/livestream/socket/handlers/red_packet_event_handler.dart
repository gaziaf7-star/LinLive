part of '../websocket_controller.dart';

extension RedPacketEventHandler on WebsocketController {
  Map<String, dynamic> _redPacketPayloadMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _redPacketIdFrom(Map<String, dynamic> packet) {
    return _toInt(
      packet['id'] ??
          packet['red_packet_id'] ??
          packet['redPacketId'] ??
          packet['packet_id'] ??
          packet['packetId'],
    );
  }

  Map<String, dynamic> _normalizeRedPacket(Map<String, dynamic> payload) {
    final data = _redPacketPayloadMap(payload['data']);
    final candidates = <dynamic>[
      data['red_packet'],
      data['redPacket'],
      data['packet'],
      payload['red_packet'],
      payload['redPacket'],
      payload['packet'],
      data,
      payload,
    ];

    // ✅ FIX: previously a single pass stopped at the first candidate that
    // satisfied EITHER "has a real id" OR "has a livestream_id" — so a
    // candidate carrying only room-routing metadata (livestream_id, no
    // actual red-packet id) could be selected before a later candidate
    // that genuinely had the id, permanently losing it (normalized['id']
    // then recomputed to 0 from the wrong, id-less candidate). Two passes:
    // first look for a real id anywhere in the candidate list; only fall
    // back to a livestream_id-only match if truly none of them have one.
    Map<String, dynamic>? matched;

    for (final item in candidates) {
      final map = _redPacketPayloadMap(item);
      if (map.isEmpty) continue;
      if (_redPacketIdFrom(map) > 0) {
        matched = map;
        break;
      }
    }

    matched ??= () {
      for (final item in candidates) {
        final map = _redPacketPayloadMap(item);
        if (map.isEmpty) continue;
        if (map['livestream_id'] != null) return map;
      }
      return null;
    }();

    if (matched != null) {
      final map = matched;
      final normalized = <String, dynamic>{...map};

      normalized['id'] = _redPacketIdFrom(normalized);
      normalized['livestream_id'] =
          normalized['livestream_id'] ??
              normalized['stream_id'] ??
              data['livestream_id'] ??
              data['stream_id'] ??
              payload['livestream_id'] ??
              payload['stream_id'];

      normalized['message'] =
          normalized['message'] ??
              data['message'] ??
              payload['message'] ??
              'Sent you a Lucky Bag';

      normalized['sender'] =
          normalized['sender'] ??
              data['sender'] ??
              payload['sender'] ??
              data['user'] ??
              payload['user'];

      normalized['expires_in_seconds'] =
          normalized['expires_in_seconds'] ??
              normalized['duration_seconds'] ??
              data['expires_in_seconds'] ??
              data['duration_seconds'] ??
              payload['expires_in_seconds'] ??
              payload['duration_seconds'] ??
              30;

      normalized['status'] =
          normalized['status'] ??
              data['status'] ??
              payload['status'] ??
              'active';
      normalized['is_global'] =
          normalized['is_global'] ??
              data['is_global'] ??
              payload['is_global'] ??
              false;
      final Map<String, dynamic>? previous = currentRedPacket.isNotEmpty &&
          _sameRedPacket(currentRedPacket, normalized)
          ? Map<String, dynamic>.from(currentRedPacket)
          : null;
      return normalizeRedPacketTiming(
        normalized,
        previousPacket: previous,
      );
    }

    return <String, dynamic>{};
  }

  bool _sameRedPacket(Map<String, dynamic> a, Map<String, dynamic> b) {
    final int aId = _redPacketIdFrom(a);
    final int bId = _redPacketIdFrom(b);
    return aId > 0 && bId > 0 && aId == bId;
  }

  bool _redPacketForCurrentStream(Map<String, dynamic> packet) {
    final dynamic stream = packet['livestream_id'] ?? packet['stream_id'];
    if (stream == null) return true;
    return _isCurrentStream(stream);
  }

  bool _redPacketTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value?.toString().toLowerCase().trim() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'global';
  }

  void _handleUnifiedRedPacketSent(Map<String, dynamic> payload) {
    _printFullLiveDebug('RED PACKET WEBSOCKET SENT RAW', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'websocket_stream_id': streamID.value,
      'active_audio_stream_id': activeAudioStreamId.value,
      'controller_stream_id': livestreamController.streamId.value,
      'raw_payload': payload,
    });

    final packet = _normalizeRedPacket(payload);

    _printFullLiveDebug('RED PACKET WEBSOCKET SENT NORMALIZED', <
        String,
        dynamic
    >{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'normalized_packet': packet,
      'for_current_stream': packet.isNotEmpty
          ? _redPacketForCurrentStream(packet)
          : false,
      'current_red_packet_before': Map<String, dynamic>.from(currentRedPacket),
      'global_red_packet_before': Map<String, dynamic>.from(
        globalCurrentRedPacket,
      ),
    });

    if (packet.isEmpty) return;

    final bool global = _redPacketTruthy(packet['is_global']);

    if (global) {
      globalCurrentRedPacket.value = packet;
      globalRedPacketVisible.value = true;
      _cancelGlobalRedPacketTimer();

      /// ✅ Show app-wide Lucky Bag banner on all pages.
      /// This updates RedPacketController.globalLuckyBagData, used by the
      /// app-wide GlobalLuckyBagBanner.
      try {
        livestreamController.redPacketController
            .handleRedPacketSentForGlobalBanner(payload);
      } catch (e) {
        liveLog('⚠️ Global Lucky Bag banner handler failed => $e');
      }
    }

    if (!_redPacketForCurrentStream(packet)) {
      _printFullLiveDebug(
        'RED PACKET WEBSOCKET SENT IGNORED FOR OTHER ROOM',
        <String, dynamic>{
          'packet': packet,
          'websocket_stream_id': streamID.value,
          'active_audio_stream_id': activeAudioStreamId.value,
          'controller_stream_id': livestreamController.streamId.value,
        },
      );
      return;
    }

    currentRedPacket.value = packet;
    redPacketVisible.value = true;
    _cancelRedPacketTimer();

    _printFullLiveDebug(
      'RED PACKET WEBSOCKET CURRENT STATE AFTER SENT',
      <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'red_packet_visible': redPacketVisible.value,
        'current_red_packet': Map<String, dynamic>.from(currentRedPacket),
        'global_red_packet_visible': globalRedPacketVisible.value,
        'global_current_red_packet': Map<String, dynamic>.from(
          globalCurrentRedPacket,
        ),
      },
    );

    try {
      onRedPacketReceived?.call(packet);
    } catch (e) {
      liveLog('⚠️ onRedPacketReceived failed => $e');
    }

    liveLog(
      '🧧 Red packet sent handled => id:${packet['id']} stream:${packet['livestream_id']} global:$global',
    );
  }

  void _handleUnifiedRedPacketCollected(Map<String, dynamic> payload) {
    _printFullLiveDebug('RED PACKET WEBSOCKET COLLECTED RAW', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'raw_payload': payload,
      'current_red_packet_before': Map<String, dynamic>.from(currentRedPacket),
      'global_red_packet_before': Map<String, dynamic>.from(
        globalCurrentRedPacket,
      ),
    });

    final packet = _normalizeRedPacket(payload);
    final data = _redPacketPayloadMap(payload['data']);
    final collection = _redPacketPayloadMap(
      data['collection'] ?? payload['collection'],
    );

    if (packet.isNotEmpty) {
      if (currentRedPacket.isNotEmpty &&
          _sameRedPacket(currentRedPacket, packet)) {
        currentRedPacket.value = {
          ...Map<String, dynamic>.from(currentRedPacket),
          ...packet,
        };
      }

      if (globalCurrentRedPacket.isNotEmpty &&
          _sameRedPacket(globalCurrentRedPacket, packet)) {
        globalCurrentRedPacket.value = {
          ...Map<String, dynamic>.from(globalCurrentRedPacket),
          ...packet,
        };
      }
    }

    final merged = <String, dynamic>{
      ...payload,
      if (packet.isNotEmpty) 'red_packet': packet,
      if (collection.isNotEmpty) 'collection': collection,
    };

    _printFullLiveDebug(
      'RED PACKET WEBSOCKET COLLECTED NORMALIZED',
      <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'normalized_packet': packet,
        'collection': collection,
        'merged_event': merged,
        'current_red_packet_after_merge': Map<String, dynamic>.from(
          currentRedPacket,
        ),
        'global_red_packet_after_merge': Map<String, dynamic>.from(
          globalCurrentRedPacket,
        ),
      },
    );

    try {
      onRedPacketCollected?.call(merged);
    } catch (e) {
      liveLog('⚠️ onRedPacketCollected failed => $e');
    }

    final status = (packet['status'] ?? '').toString().toLowerCase();
    final int remainingQty = _toInt(packet['remaining_quantity']);
    if (status == 'closed' ||
        status == 'expired' ||
        status == 'refunded' ||
        remainingQty == 0 && packet.containsKey('remaining_quantity')) {
      _handleUnifiedRedPacketClosed({
        'red_packet': packet,
      }, source: 'red_packet_collected_finish');
    }
  }

  void _handleUnifiedRedPacketClosed(
      Map<String, dynamic> payload, {
        String source = 'red_packet_closed',
      }) {
    _printFullLiveDebug('RED PACKET WEBSOCKET CLOSED RAW', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'source': source,
      'raw_payload': payload,
      'current_red_packet_before': Map<String, dynamic>.from(currentRedPacket),
      'global_red_packet_before': Map<String, dynamic>.from(
        globalCurrentRedPacket,
      ),
    });

    final packet = _normalizeRedPacket(payload);

    if (packet.isEmpty) {
      hideRedPacket();
      hideGlobalRedPacket();
      return;
    }

    if (currentRedPacket.isNotEmpty &&
        _sameRedPacket(currentRedPacket, packet)) {
      hideRedPacket();
    }

    if (globalCurrentRedPacket.isNotEmpty &&
        _sameRedPacket(globalCurrentRedPacket, packet)) {
      hideGlobalRedPacket();
    }

    liveLog('🧧 Red packet closed => source:$source id:${packet['id']}');
  }
}