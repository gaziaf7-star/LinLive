import 'dart:async';

import 'package:get/get.dart';

import '../../../localization/app_localizer.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns in-room Lucky Gift result normalization and presentation state.
///
/// Normal gift sending stays with its existing owner. App-global Lucky banner
/// queueing, deduplication and navigation stay with [LiveBannerController].
class LiveLuckyGiftController extends GetxController {
  LiveLuckyGiftController(this._owner);

  final LivestreamController _owner;

  final luckyGiftOverlayData = <String, dynamic>{}.obs;
  final luckyGiftOverlayVisible = false.obs;
  final luckyGiftTickerQueue = <Map<String, dynamic>>[].obs;
  final luckyGiftCoinRainVisible = false.obs;
  final luckyGiftResult = <String, dynamic>{}.obs;
  final luckyGiftResultVisible = false.obs;

  int _animationSerial = 0;
  Timer? _resultHideTimer;

  static const int _maxTickerItems = 10;

  void debugPrint(String title, dynamic value) {
    // Large Lucky payload logging intentionally remains disabled in production.
  }

  int intOf(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double doubleOf(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool responseHasVisibleWin(Map<String, dynamic> responseData) {
    bool truthy(dynamic value) {
      if (value == true || value == 1) return true;
      final text = value?.toString().trim().toLowerCase() ?? '';
      return text == '1' || text == 'true' || text == 'yes' || text == 'win';
    }

    final direct = mapOf(responseData['lucky_result']);
    Map<String, dynamic> result = direct;
    final listRaw = responseData['lucky_results'];
    if (result.isEmpty && listRaw is List) {
      for (final item in listRaw) {
        final candidate = mapOf(item);
        if (candidate.isNotEmpty) {
          result = candidate;
          break;
        }
      }
    }

    final winAmount = intOf(
      result['win_amount'] ??
          result['back_coin'] ??
          result['win_coin'] ??
          responseData['win_amount'] ??
          responseData['back_coin'] ??
          responseData['win_coin'],
    );
    return winAmount > 0 &&
        (truthy(result['is_win'] ?? responseData['is_win']) ||
            intOf(result['multiplier'] ?? responseData['multiplier']) > 0);
  }

  void showLuckyGiftResult(Map<String, dynamic> data) {
    debugPrint('SHOW LUCKY GIFT RESULT INPUT', data);
    final map = Map<String, dynamic>.from(data);
    if (!map.containsKey('timestamp') || map['timestamp'] == null) {
      map['timestamp'] = DateTime.now().toIso8601String();
    }
    luckyGiftResult.value = map;
    luckyGiftResultVisible.value = true;
    showLuckyGiftVideoStyleResult(map);
  }

  void showLuckyGiftVideoStyleResult(Map<String, dynamic> payload) {
    try {
      final data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);
      final sender = mapOf(
        data['sender'] ??
            data['user'] ??
            data['sender_user'] ??
            payload['sender'] ??
            payload['user'],
      );
      final receiver = mapOf(data['receiver'] ?? payload['receiver']);
      final gift = mapOf(
        data['gift'] ??
            data['gift_data'] ??
            payload['gift'] ??
            payload['gift_data'],
      );
      final List results = data['lucky_results'] is List
          ? data['lucky_results']
          : payload['lucky_results'] is List
          ? payload['lucky_results']
          : [];
      Map<String, dynamic> firstResult = <String, dynamic>{};
      if (results.isNotEmpty && results.first is Map) {
        firstResult = Map<String, dynamic>.from(results.first);
      }

      final rawMultiplier = doubleOf(
        firstResult['multiplier'] ??
            data['multiplier'] ??
            data['multiple'] ??
            data['x'] ??
            data['gun'],
      );
      final visualMultiplier = rawMultiplier <= 0 ? 1.0 : rawMultiplier;
      final winAmount = intOf(
        firstResult['win_amount'] ??
            firstResult['back_coin'] ??
            firstResult['win_coin'] ??
            data['win_amount'] ??
            data['back_coin'] ??
            data['win_coin'],
      );
      final isWin =
          firstResult['is_win'] == true ||
          firstResult['is_win']?.toString() == '1' ||
          firstResult['is_win']?.toString().toLowerCase() == 'true' ||
          data['is_win'] == true ||
          data['is_win']?.toString() == '1' ||
          winAmount > 0 ||
          rawMultiplier > 0;
      final winType =
          (firstResult['win_type'] ??
                  data['win_type'] ??
                  (visualMultiplier >= 50 || winAmount >= 5000
                      ? 'jackpot'
                      : isWin
                      ? 'small_win'
                      : 'loss'))
              .toString()
              .toLowerCase();
      final isBigWin =
          winType.contains('big') ||
          winType.contains('jackpot') ||
          visualMultiplier >= 50 ||
          winAmount >= 5000 ||
          data['is_big_win'] == true ||
          data['is_jackpot'] == true;

      final serial = ++_animationSerial;
      final roomGeneration = _owner.roomSessionGeneration;
      final eventTimestamp = '${DateTime.now().microsecondsSinceEpoch}_$serial';
      final normalized = <String, dynamic>{
        ...data,
        'sender': sender,
        'receiver': receiver,
        'gift': gift,
        'is_win': isWin,
        'raw_multiplier': rawMultiplier,
        'multiplier': visualMultiplier,
        'win_amount': winAmount,
        'win_type': winType,
        'is_big_win': isBigWin,
        'is_jackpot': isBigWin,
        'title': isBigWin ? 'JACKPOT' : 'LUCKY WIN',
        'message': winAmount > 0
            ? '${sender['name'] ?? ('User').appTr} won ${visualMultiplier}x +$winAmount coins'
            : '${sender['name'] ?? ('User').appTr} got ${visualMultiplier}x lucky bonus',
        'timestamp': eventTimestamp,
        'animation_duration_ms': 5000,
      };

      luckyGiftOverlayData.value = normalized;
      luckyGiftResult.value = normalized;
      luckyGiftResultVisible.value = true;
      luckyGiftOverlayVisible.value = false;
      luckyGiftCoinRainVisible.value = false;

      if (visualMultiplier >= 5 && winAmount > 0) {
        luckyGiftTickerQueue.add(normalized);
        final overflow = luckyGiftTickerQueue.length - _maxTickerItems;
        if (overflow > 0) {
          luckyGiftTickerQueue.removeRange(0, overflow);
        }
      }

      // A Lucky burst used to allocate one delayed callback per result. Only
      // the latest result owns the visible overlay, so one replaceable timer
      // preserves presentation semantics without retaining every callback.
      _resultHideTimer?.cancel();
      _resultHideTimer = Timer(const Duration(seconds: 7), () {
        if (_animationSerial != serial ||
            _owner.roomSessionGeneration != roomGeneration) {
          return;
        }
        luckyGiftOverlayVisible.value = false;
        luckyGiftResultVisible.value = false;
        luckyGiftCoinRainVisible.value = false;
      });

      liveLog(
        '🍀 5s center gift rain => gift=${gift['name'] ?? gift['gift_name']} '
        'win=$isWin multiplier=$visualMultiplier amount=$winAmount serial=$serial',
      );
    } catch (error) {
      liveLog(
        '❌ showLuckyGiftVideoStyleResult error => $error payload=$payload',
      );
    }
  }

  void resetRoomLuckyState() {
    _animationSerial++;
    _resultHideTimer?.cancel();
    _resultHideTimer = null;
    luckyGiftOverlayData.clear();
    luckyGiftOverlayVisible.value = false;
    luckyGiftTickerQueue.clear();
    luckyGiftCoinRainVisible.value = false;
    luckyGiftResult.clear();
    luckyGiftResultVisible.value = false;
  }

  @override
  void onClose() {
    _resultHideTimer?.cancel();
    _resultHideTimer = null;
    super.onClose();
  }
}
