const int kRedPacketOpenAfterSeconds = 30;

int _redPacketTimingInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _redPacketTimingDate(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final int raw = value.toInt();
    if (raw <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      raw < 100000000000 ? raw * 1000 : raw,
    );
  }

  final String text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  final int? numeric = int.tryParse(text);
  if (numeric != null && numeric > 0) {
    return DateTime.fromMillisecondsSinceEpoch(
      numeric < 100000000000 ? numeric * 1000 : numeric,
    );
  }
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

int redPacketIdOf(Map<String, dynamic> packet) {
  return _redPacketTimingInt(
    packet['id'] ?? packet['red_packet_id'] ?? packet['packet_id'],
  );
}

Map<String, dynamic> normalizeRedPacketTiming(
  Map<String, dynamic> packet, {
  Map<String, dynamic>? previousPacket,
  int? receivedAtMs,
}) {
  final Map<String, dynamic> normalized = Map<String, dynamic>.from(packet);
  final int packetId = redPacketIdOf(normalized);
  final int nowMs = receivedAtMs ?? DateTime.now().millisecondsSinceEpoch;
  final bool sameAsPrevious =
      previousPacket != null &&
      packetId > 0 &&
      redPacketIdOf(previousPacket) == packetId;

  int openAtMs = sameAsPrevious
      ? _redPacketTimingInt(previousPacket['red_packet_open_at_ms'])
      : 0;
  openAtMs = openAtMs > 0
      ? openAtMs
      : _redPacketTimingInt(normalized['red_packet_open_at_ms']);

  if (openAtMs <= 0) {
    final DateTime? absoluteOpen = _redPacketTimingDate(
      normalized['opens_at'] ??
          normalized['open_at'] ??
          normalized['unlock_at'],
    );
    final DateTime? absoluteAnchor = _redPacketTimingDate(
      normalized['created_at'] ?? normalized['sent_at'],
    );
    final bool matchesCanonicalDelay =
        absoluteOpen != null &&
        (absoluteAnchor == null ||
            (absoluteOpen.difference(absoluteAnchor).inSeconds -
                        kRedPacketOpenAfterSeconds)
                    .abs() <=
                2);
    if (matchesCanonicalDelay) {
      openAtMs = absoluteOpen.millisecondsSinceEpoch;
    }
  }

  if (openAtMs <= 0) {
    final DateTime? createdAt = _redPacketTimingDate(normalized['created_at']);
    if (createdAt != null) {
      openAtMs =
          createdAt.millisecondsSinceEpoch +
          (kRedPacketOpenAfterSeconds * 1000);
    }
  }

  if (openAtMs <= 0) {
    final DateTime? sentAt = _redPacketTimingDate(normalized['sent_at']);
    if (sentAt != null) {
      openAtMs =
          sentAt.millisecondsSinceEpoch + (kRedPacketOpenAfterSeconds * 1000);
    }
  }

  final int stableReceivedAtMs = sameAsPrevious
      ? _redPacketTimingInt(previousPacket['event_received_at_ms'])
      : _redPacketTimingInt(normalized['event_received_at_ms']);
  final int eventReceivedAtMs = stableReceivedAtMs > 0
      ? stableReceivedAtMs
      : nowMs;

  openAtMs = openAtMs > 0
      ? openAtMs
      : eventReceivedAtMs + (kRedPacketOpenAfterSeconds * 1000);

  normalized['open_after_seconds'] = kRedPacketOpenAfterSeconds;
  normalized['unlock_after_seconds'] = kRedPacketOpenAfterSeconds;
  normalized['event_received_at_ms'] = eventReceivedAtMs;
  normalized['red_packet_open_at_ms'] = openAtMs;
  normalized['opens_at'] ??= DateTime.fromMillisecondsSinceEpoch(
    openAtMs,
    isUtc: true,
  ).toIso8601String();
  return normalized;
}

int redPacketOpenRemainingSeconds(Map<String, dynamic> packet) {
  final Map<String, dynamic> normalized = normalizeRedPacketTiming(packet);
  final int openAtMs = _redPacketTimingInt(normalized['red_packet_open_at_ms']);
  final int remainingMs = openAtMs - DateTime.now().millisecondsSinceEpoch;
  if (remainingMs <= 0) return 0;
  return (remainingMs / 1000).ceil();
}
