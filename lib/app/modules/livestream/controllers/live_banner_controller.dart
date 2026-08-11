import 'dart:async';
import 'dart:collection';

import 'package:get/get.dart';

import 'audience_join_controller.dart';
import 'livestream_controller.dart';

enum GlobalLiveBannerType { luckyBag, luckyWin, rocket, bigGift }

class GlobalLiveBannerItem {
  const GlobalLiveBannerItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.displaySeconds,
  });

  final String id;
  final GlobalLiveBannerType type;
  final Map<String, dynamic> payload;
  final int displaySeconds;
}

/// App-global presentation queue plus Lucky-win banner source orchestration.
///
/// Lucky, Rocket and Red Packet business state remains with its existing owner.
/// This controller owns only normalized presentation order, dismissal,
/// duplicate suppression and Lucky banner navigation intent.
class LiveBannerController extends GetxController {
  static const int maxVisibleBanners = 2;

  final visibleBanners = <GlobalLiveBannerItem>[].obs;
  final Queue<GlobalLiveBannerItem> _pending = Queue<GlobalLiveBannerItem>();
  final LinkedHashSet<String> _seenIds = LinkedHashSet<String>();

  final globalLuckyWinData = <String, dynamic>{}.obs;
  final globalLuckyWinBannerVisible = false.obs;
  final globalLuckyWinBannerSeconds = 0.obs;
  final Queue<Map<String, dynamic>> _luckyPending =
      Queue<Map<String, dynamic>>();
  final Set<String> _luckySeenKeys = <String>{};
  final Map<String, int> _luckyRecentFingerprints = <String, int>{};
  final Set<String> _luckyPendingKeys = <String>{};

  Timer? _luckyPromotionTimer;
  bool _navigationInFlight = false;

  LivestreamController get _live => Get.find<LivestreamController>();

  bool hasSeen(String id) => _seenIds.contains(id);
  int get pendingCount => _pending.length;
  bool get navigationInFlight => _navigationInFlight;

  bool isVisible(String id) => visibleBanners.any((item) => item.id == id);

  void enqueue({
    required String id,
    required GlobalLiveBannerType type,
    required Map<String, dynamic> payload,
    int displaySeconds = 5,
  }) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || _seenIds.contains(normalizedId)) return;
    _remember(normalizedId);

    final item = GlobalLiveBannerItem(
      id: normalizedId,
      type: type,
      payload: Map<String, dynamic>.from(payload),
      displaySeconds: displaySeconds.clamp(3, 15).toInt(),
    );
    if (_canShowNow(item)) {
      visibleBanners.add(item);
    } else {
      _pending.addLast(item);
    }
  }

  GlobalLiveBannerItem? activeItem(GlobalLiveBannerType type) {
    for (final item in visibleBanners) {
      if (item.type == type) return item;
    }
    return null;
  }

  int slotOf(String id) => visibleBanners.indexWhere((item) => item.id == id);

  void finish(String id) {
    final oldLength = visibleBanners.length;
    visibleBanners.removeWhere((item) => item.id == id);
    if (visibleBanners.length != oldLength) _promotePending();
  }

  bool _canShowNow(GlobalLiveBannerItem item) {
    if (visibleBanners.length >= maxVisibleBanners) return false;
    return !visibleBanners.any((active) => active.type == item.type);
  }

  void _promotePending() {
    while (visibleBanners.length < maxVisibleBanners && _pending.isNotEmpty) {
      final candidates = _pending.length;
      GlobalLiveBannerItem? selected;
      for (int index = 0; index < candidates; index++) {
        final candidate = _pending.removeFirst();
        if (_canShowNow(candidate)) {
          selected = candidate;
          break;
        }
        _pending.addLast(candidate);
      }
      if (selected == null) break;
      visibleBanners.add(selected);
    }
  }

  void _remember(String id) {
    _seenIds.add(id);
    while (_seenIds.length > 500) {
      _seenIds.remove(_seenIds.first);
    }
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  void showGlobalBigGiftBannerFromPayload(Map<String, dynamic> payload) {
    final root = Map<String, dynamic>.from(payload);
    final nested = _map(root['data']);
    final data = nested.isEmpty ? root : <String, dynamic>{...root, ...nested};
    final gift = _map(
      data['gift'] ?? data['gift_data'] ?? data['gift_info'] ?? data['asset'],
    );

    bool truthy(dynamic value) {
      final text = _text(value).toLowerCase();
      return value == true || text == '1' || text == 'true' || text == 'yes';
    }

    final category = _text(
      gift['category'] ??
          gift['gift_category'] ??
          gift['gift_type'] ??
          data['gift_category'] ??
          data['gift_type'],
    ).toLowerCase();
    final isLucky =
        truthy(data['is_lucky_gift']) ||
        truthy(data['is_lucky']) ||
        truthy(gift['is_lucky_gift']) ||
        truthy(gift['is_lucky']) ||
        truthy(gift['lucky']) ||
        category.contains('lucky') ||
        data['lucky_result'] is Map ||
        data['lucky_results'] is List ||
        data['big_win_events'] is List;
    if (isLucky) return;

    // Only the authoritative per-item catalog/event value is eligible. Do not
    // use amount, quantity, total_coins or sender wallet deduction here.
    final perGiftCoins = _int(
      gift['gift_coin'] ??
          gift['gift_coins'] ??
          gift['coin'] ??
          gift['coins'] ??
          gift['price'] ??
          gift['gift_price'] ??
          gift['gift_value'] ??
          data['gift_coin'] ??
          data['gift_coins'] ??
          data['gift_price'] ??
          data['gift_value'],
    );
    if (perGiftCoins < 100000) return;

    final sender = _map(data['sender'] ?? data['gifter'] ?? data['user']);
    final streamId = _int(
      data['livestream_id'] ??
          data['live_stream_id'] ??
          data['stream_id'] ??
          root['livestream_id'] ??
          root['stream_id'],
    );
    if (streamId <= 0) return;

    final sourceEventId = _text(
      data['event_id'] ??
          data['gift_event_id'] ??
          data['transaction_id'] ??
          data['message_id'] ??
          data['client_event_id'] ??
          data['gift_history_id'],
    );
    final senderId = sender['id'] ?? sender['user_id'] ?? data['sender_id'];
    final giftId = gift['id'] ?? gift['gift_id'] ?? data['gift_id'];
    final timestamp = _text(
      data['timestamp'] ?? data['created_at'] ?? data['sent_at'],
    );
    final fallbackSerial = _text(data['serial'] ?? data['combo_serial']);
    if (sourceEventId.isEmpty && timestamp.isEmpty && fallbackSerial.isEmpty) {
      return;
    }
    final id = sourceEventId.isNotEmpty
        ? 'big_gift_$sourceEventId'
        : 'big_gift_${streamId}_${senderId}_${giftId}_${timestamp}_$fallbackSerial';

    enqueue(
      id: id,
      type: GlobalLiveBannerType.bigGift,
      payload: <String, dynamic>{
        'event_id': id,
        'source_event_id': sourceEventId,
        'livestream_id': streamId,
        'stream_id': streamId,
        'sender': sender,
        'gift': gift,
        'gift_value': perGiftCoins,
        'channel_name': data['channel_name'],
        'room_id': data['room_id'],
        'stream_type': data['stream_type'],
      },
      displaySeconds: 5,
    );
  }

  List<Map<String, dynamic>> _luckyCandidates(Map<String, dynamic> payload) {
    final root = Map<String, dynamic>.from(payload);
    final data = _map(root['data']).isNotEmpty ? _map(root['data']) : root;
    final sender = _map(data['sender'] ?? data['user'] ?? root['sender']);
    final receiver = _map(data['receiver'] ?? root['receiver']);
    final gift = _map(data['gift'] ?? data['gift_data'] ?? root['gift']);
    final rawResults = <Map<String, dynamic>>[];

    void addResult(dynamic value) {
      if (value is Map) {
        rawResults.add(Map<String, dynamic>.from(value));
      } else if (value is Iterable) {
        for (final item in value) {
          if (item is Map) rawResults.add(Map<String, dynamic>.from(item));
        }
      }
    }

    addResult(data['big_win_events']);
    addResult(root['big_win_events']);
    addResult(data['lucky_results']);
    addResult(root['lucky_results']);
    addResult(data['lucky_result']);
    addResult(root['lucky_result']);

    final hasDirectResult =
        data['multiplier'] != null ||
        data['multiple'] != null ||
        data['x'] != null ||
        data['gun'] != null ||
        data['win_amount'] != null ||
        data['back_coin'] != null ||
        data['win_coin'] != null;
    if (rawResults.isEmpty && hasDirectResult) {
      rawResults.add(<String, dynamic>{});
    }

    return rawResults.map((result) {
      final multiplier = _double(
        result['multiplier'] ??
            result['multiple'] ??
            result['x'] ??
            result['gun'] ??
            data['multiplier'] ??
            data['multiple'] ??
            data['x'] ??
            data['gun'],
      );
      final winAmount = _int(
        result['win_amount'] ??
            result['back_coin'] ??
            result['win_coin'] ??
            result['bonus_coin'] ??
            data['win_amount'] ??
            data['back_coin'] ??
            data['win_coin'] ??
            data['bonus_coin'],
      );
      final isWin =
          result['is_win'] == true ||
          result['is_win']?.toString() == '1' ||
          data['is_win'] == true ||
          data['is_win']?.toString() == '1' ||
          multiplier > 0 ||
          winAmount > 0;
      return <String, dynamic>{
        ...root,
        ...data,
        ...result,
        'sender': sender,
        'user': sender,
        'receiver': receiver,
        'gift': gift,
        'multiplier': multiplier,
        'win_amount': winAmount,
        'back_coin': winAmount,
        'win_coin': winAmount,
        'is_win': isWin,
        'livestream_id':
            result['livestream_id'] ??
            result['stream_id'] ??
            data['livestream_id'] ??
            data['stream_id'] ??
            root['livestream_id'] ??
            root['stream_id'],
        'channel_name':
            result['channel_name'] ??
            result['agora_channel_name'] ??
            data['channel_name'] ??
            data['agora_channel_name'] ??
            data['room_id'] ??
            root['channel_name'] ??
            root['agora_channel_name'] ??
            root['room_id'],
        'stream_type':
            result['stream_type'] ??
            data['stream_type'] ??
            root['stream_type'] ??
            'audio',
      };
    }).toList();
  }

  String _eventId(Map<String, dynamic> data) {
    final result = _map(
      data['lucky_result'] ?? data['result'] ?? data['win_result'],
    );
    final values = <dynamic>[
      data['gift_history_id'],
      data['gift_send_id'],
      data['gift_transaction_id'],
      data['transaction_id'],
      data['lucky_result_id'],
      data['result_id'],
      result['gift_history_id'],
      result['gift_send_id'],
      result['gift_transaction_id'],
      result['transaction_id'],
      result['lucky_result_id'],
      result['result_id'],
      data['result_event_id'],
      data['lucky_event_id'],
      result['result_event_id'],
      result['lucky_event_id'],
      data['event_id'],
      result['event_id'],
    ];
    for (final raw in values) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null' && value != '0') {
        return value;
      }
    }
    return '';
  }

  String _fingerprint(Map<String, dynamic> data) {
    final sender = _map(data['sender'] ?? data['user']);
    final receiver = _map(data['receiver']);
    final gift = _map(data['gift']);
    return <dynamic>[
      data['livestream_id'] ?? data['stream_id'],
      sender['id'] ?? sender['user_id'] ?? data['sender_id'] ?? data['user_id'],
      receiver['id'] ?? receiver['user_id'] ?? data['receiver_id'],
      gift['id'] ?? gift['gift_id'] ?? data['gift_id'],
      _double(data['multiplier']),
      _int(data['win_amount'] ?? data['back_coin'] ?? data['win_coin']),
    ].map((value) => value?.toString() ?? '').join('|');
  }

  String _luckyKey(Map<String, dynamic> data) {
    final eventId = _eventId(data);
    return eventId.isNotEmpty
        ? 'event|$eventId'
        : 'fallback|${_fingerprint(data)}';
  }

  void showGlobalLuckyWinBannerFromPayload(Map<String, dynamic> payload) {
    final payloadKeys = <String>{};
    for (final candidate in _luckyCandidates(payload)) {
      final multiplier = _double(candidate['multiplier']);
      final winAmount = _int(candidate['win_amount']);
      if (multiplier < 5 || winAmount <= 0) continue;
      final realId = _eventId(candidate);
      final timestamp = _text(
        candidate['result_timestamp'] ??
            candidate['timestamp'] ??
            candidate['created_at'] ??
            candidate['updated_at'],
      );
      final payloadKey = realId.isNotEmpty
          ? 'id|$realId'
          : 'fallback|${_fingerprint(candidate)}|$timestamp';
      if (payloadKeys.add(payloadKey)) _enqueueLucky(candidate);
    }
  }

  void _enqueueLucky(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    if (_double(data['multiplier']) < 5 ||
        _int(data['win_amount'] ?? data['back_coin'] ?? data['win_coin']) <=
            0) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final eventId = _eventId(data);
    final fingerprint = _fingerprint(data);
    final key = _luckyKey(data);
    if (_luckyPendingKeys.contains(key)) return;

    if (eventId.isNotEmpty) {
      if (!_luckySeenKeys.add(key)) return;
      _luckyRecentFingerprints[fingerprint] = now;
    } else {
      final lastSeen = _luckyRecentFingerprints[fingerprint] ?? 0;
      if (now - lastSeen < 12000) return;
      _luckyRecentFingerprints[fingerprint] = now;
    }
    while (_luckySeenKeys.length > 500) {
      _luckySeenKeys.remove(_luckySeenKeys.first);
    }
    _luckyRecentFingerprints.removeWhere((_, seenAt) => now - seenAt > 60000);
    data['global_lucky_banner_key'] = key;
    _luckyPendingKeys.add(key);
    _luckyPending.addLast(data);
    if (!globalLuckyWinBannerVisible.value) _showNextLucky();
  }

  void _showNextLucky() {
    _luckyPromotionTimer?.cancel();
    _luckyPromotionTimer = null;
    if (_luckyPending.isEmpty) {
      globalLuckyWinBannerVisible.value = false;
      globalLuckyWinBannerSeconds.value = 0;
      globalLuckyWinData.clear();
      return;
    }
    globalLuckyWinData.assignAll(_luckyPending.removeFirst());
    globalLuckyWinBannerSeconds.value = 5;
    globalLuckyWinBannerVisible.value = true;
  }

  void hideGlobalLuckyWinBanner({bool showNext = true}) {
    _luckyPromotionTimer?.cancel();
    _luckyPromotionTimer = null;
    final activeKey =
        globalLuckyWinData['global_lucky_banner_key']?.toString() ?? '';
    if (activeKey.isNotEmpty) _luckyPendingKeys.remove(activeKey);
    globalLuckyWinBannerVisible.value = false;
    globalLuckyWinBannerSeconds.value = 0;
    globalLuckyWinData.clear();
    if (showNext && _luckyPending.isNotEmpty) {
      _luckyPromotionTimer = Timer(
        const Duration(milliseconds: 180),
        _showNextLucky,
      );
    }
  }

  Future<void> openGlobalLuckyWinRoom(Map<String, dynamic> raw) async {
    hideGlobalLuckyWinBanner();
    if (_navigationInFlight) return;
    final data = Map<String, dynamic>.from(raw);
    final liveId = _int(
      data['livestream_id'] ?? data['stream_id'] ?? data['live_id'],
    );
    if (liveId <= 0) return;

    final live = _live;
    final ws = live.websocketController;
    if (live.streamId.value == liveId ||
        ws.streamID.value == liveId ||
        ws.activeAudioStreamId.value == liveId) {
      return;
    }

    _navigationInFlight = true;
    try {
      Map<String, dynamic> liveData = <String, dynamic>{};
      try {
        final match = ws.homeController.showingLiveStreamList.firstWhere((
          item,
        ) {
          if (item is! Map) return false;
          return _int(
                item['id'] ?? item['livestream_id'] ?? item['stream_id'],
              ) ==
              liveId;
        }, orElse: () => null);
        if (match is Map) liveData = Map<String, dynamic>.from(match);
      } catch (_) {}

      final sender = _map(data['sender']);
      final broadcaster = _map(data['broadcaster'] ?? data['host']);
      liveData = <String, dynamic>{
        ...data,
        ...liveData,
        'id': liveId,
        'livestream_id': liveId,
        'stream_id': liveId,
        if (broadcaster.isNotEmpty && liveData['user'] == null)
          'user': broadcaster,
        'global_lucky_event': Map<String, dynamic>.from(data),
        'global_banner_type': data['global_banner_type'] ?? 'lucky',
      };
      final channelName = _text(
        liveData['room_id'] ??
            liveData['channel_name'] ??
            liveData['agora_channel_name'] ??
            liveData['agora_channel'] ??
            liveData['owner_user_id'] ??
            liveData['user_id'] ??
            broadcaster['id'] ??
            sender['id'],
      );
      if (channelName.isEmpty) return;

      final joinController = Get.isRegistered<AudienceJoinController>()
          ? Get.find<AudienceJoinController>()
          : Get.put(AudienceJoinController());
      await joinController.joinAsAudience(
        channelName: channelName,
        data: liveData,
      );
    } finally {
      _navigationInFlight = false;
    }
  }

  void clearAll({bool clearSeen = true}) {
    visibleBanners.clear();
    _pending.clear();
    if (clearSeen) _seenIds.clear();
  }

  void resetLuckyPresentation({bool clearSeen = false}) {
    _luckyPromotionTimer?.cancel();
    _luckyPromotionTimer = null;
    hideGlobalLuckyWinBanner(showNext: false);
    _luckyPending.clear();
    _luckyPendingKeys.clear();
    if (clearSeen) {
      _luckySeenKeys.clear();
      _luckyRecentFingerprints.clear();
    }
  }

  @override
  void onClose() {
    resetLuckyPresentation();
    super.onClose();
  }
}

typedef GlobalLiveBannerQueueController = LiveBannerController;

LiveBannerController globalLiveBannerQueue() {
  if (Get.isRegistered<LiveBannerController>()) {
    return Get.find<LiveBannerController>();
  }
  return Get.put<LiveBannerController>(LiveBannerController(), permanent: true);
}
