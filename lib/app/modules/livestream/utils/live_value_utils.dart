import 'package:get/get.dart';

/// Small, dependency-light helpers for realtime live room state.
/// Keep all dynamic payload parsing here so controllers stay cleaner.
class LiveValueUtils {
  const LiveValueUtils._();

  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final text = value.toString().toLowerCase().trim();
    if (['1', 'true', 'yes', 'active', 'accepted', 'joined', 'live'].contains(text)) return true;
    if (['0', 'false', 'no', 'inactive', 'left', 'ended', 'rejected'].contains(text)) return false;
    return fallback;
  }

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> asList(dynamic value) {
    if (value == null) return <dynamic>[];
    if (value is List) return value;
    return <dynamic>[value];
  }

  static int userIdFrom(dynamic raw) {
    final map = asMap(raw);
    if (map.isEmpty) return toInt(raw);
    return toInt(
      map['viewer_id'] ??
          map['caller_id'] ??
          map['user_id'] ??
          map['id'] ??
          asMap(map['user'])['id'] ??
          asMap(map['viewer'])['id'] ??
          asMap(map['caller'])['id'],
    );
  }

  static bool isActiveViewer(dynamic raw) {
    final map = asMap(raw);
    if (map.isEmpty) return false;

    final status = (map['status'] ?? map['viewer_status'] ?? '').toString().toLowerCase().trim();
    if (['left', 'inactive', 'removed', 'ended', 'offline'].contains(status)) return false;

    if (map.containsKey('is_active')) return toBool(map['is_active']);
    if (map.containsKey('active')) return toBool(map['active']);

    return userIdFrom(map) > 0;
  }

  static bool isAcceptedCaller(dynamic raw) {
    final map = asMap(raw);
    if (map.isEmpty) return false;
    final status = (map['call_status'] ?? map['status'] ?? 'accepted').toString().toLowerCase().trim();
    return ['accepted', 'joined', 'active', 'live'].contains(status);
  }

  static int extractReceiveCoinsFromProfile(dynamic user) {
    final map = asMap(user);
    if (map.isEmpty) return 0;
    for (final key in const [
      'earnedCoins',
      'earned_coins',
      'earnCoin',
      'earn_coin',
      'earn_coins',
      'received_coins',
    ]) {
      final value = toInt(map[key]);
      if (value > 0) return value;
    }
    return 0;
  }

  static int extractCurrentCoinsFromProfile(dynamic user) {
    final map = asMap(user);
    if (map.isEmpty) return 0;
    for (final key in const ['coins', 'coin', 'balance']) {
      final value = toInt(map[key]);
      if (value >= 0) return value;
    }
    return 0;
  }

  static int extractLiveGiftTotal(dynamic payload) {
    final map = asMap(payload);
    if (map.isEmpty) return toInt(payload);

    for (final key in const [
      'total_gift_coins',
      'stream_coins',
      'gifts_coins',
      'gift_amount',
      'received_coins',
      'total_coins',
    ]) {
      final value = toInt(map[key]);
      if (value > 0) return value;
    }

    for (final key in const ['livestream', 'livestreamdata', 'data']) {
      final nested = asMap(map[key]);
      if (nested.isEmpty) continue;
      final value = extractLiveGiftTotal(nested);
      if (value > 0) return value;
    }

    return 0;
  }

  static String formatCoins(dynamic raw) {
    final coins = toInt(raw);
    if (coins >= 1000000) {
      final value = coins / 1000000;
      return value % 1 == 0 ? '${value.toInt()}M' : '${value.toStringAsFixed(1)}M';
    }
    if (coins >= 1000) {
      final value = coins / 1000;
      return value % 1 == 0 ? '${value.toInt()}k' : '${value.toStringAsFixed(1)}k';
    }
    return coins.toString();
  }
}

extension LiveRxListSafeRefresh on RxList<dynamic> {
  void refreshLater() {
    Future.microtask(refresh);
  }
}
