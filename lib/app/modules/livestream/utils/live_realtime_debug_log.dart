import 'package:flutter/foundation.dart';

class LiveRealtimeDebugLog {
  LiveRealtimeDebugLog._();

  static int _lastHeartbeatAtMs = 0;
  static final Map<String, int> _lastThrottledAtMs = <String, int>{};

  static bool allowThrottled(String key, Duration interval) {
    if (!kDebugMode) return false;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int previous = _lastThrottledAtMs[key] ?? 0;
    if (now - previous < interval.inMilliseconds) return false;
    _lastThrottledAtMs[key] = now;
    return true;
  }

  static void event(String tag, Map<String, Object?> fields) {
    if (!kDebugMode) return;
    final String details = fields.entries
        .where((entry) => entry.value != null && '${entry.value}'.isNotEmpty)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint('[LIVE_RT][$tag] $details');
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int userId(dynamic raw) {
    if (raw is! Map) return 0;
    final dynamic user = raw['user'];
    return intValue(
      raw['caller_id'] ??
          raw['user_id'] ??
          raw['viewer_id'] ??
          (user is Map ? user['id'] ?? user['user_id'] : null),
    );
  }

  static int seatNo(dynamic raw) {
    if (raw is! Map) return 0;
    return intValue(
      raw['seat_no'] ?? raw['seatNo'] ?? raw['seat'] ?? raw['seat_number'],
    );
  }

  static List<String> seatEntries(Iterable<dynamic> callers) {
    final Map<int, int> seats = <int, int>{};
    for (final dynamic raw in callers) {
      final int seat = seatNo(raw);
      final int user = userId(raw);
      if (seat > 0 && user > 0) seats[seat] = user;
    }
    final List<int> ordered = seats.keys.toList()..sort();
    return ordered.map((seat) => '$seat:${seats[seat]}').toList();
  }

  static void seats({
    required int room,
    required Iterable<dynamic> callers,
    required int capacity,
  }) {
    if (!kDebugMode) return;
    final entries = seatEntries(callers);
    event('SEATS', <String, Object?>{
      'room': room,
      'occupied': '${entries.length}/$capacity',
      'list': '[${entries.join(',')}]',
    });
  }

  static void state({
    required int room,
    required int viewers,
    required Iterable<dynamic> callers,
    required String socket,
    required int capacity,
  }) {
    if (!kDebugMode) return;
    final entries = seatEntries(callers);
    event('STATE', <String, Object?>{
      'room': room,
      'viewers': viewers,
      'callers': callers.length,
      'occupied_seats': '${entries.length}/$capacity',
      'socket': socket,
    });
  }

  static void heartbeat({
    required int room,
    required int serverViewers,
    required int localViewers,
    required Iterable<dynamic> callers,
    required int capacity,
  }) {
    if (!kDebugMode) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHeartbeatAtMs < 5000) return;
    _lastHeartbeatAtMs = now;
    final entries = seatEntries(callers);
    event('HEARTBEAT', <String, Object?>{
      'room': room,
      'viewer_count': serverViewers,
      'local_viewers': localViewers,
      'occupied_seats': entries.length,
      'seat_capacity': capacity,
      'seats': '[${entries.join(',')}]',
    });
  }
}
