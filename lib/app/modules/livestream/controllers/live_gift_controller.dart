import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../localization/app_localizer.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';
import '../socket/websocket_controller.dart';

/// Owns normal livestream gift catalog, sending, receiver selection, room
/// history/totals, and Quick/Combo orchestration. Realtime received-animation
/// handling and Lucky-result presentation remain in their dedicated owners.
class LiveGiftController extends GetxController {
  LiveGiftController(this.livestreamController);

  final LivestreamController livestreamController;

  final RxList<Map<String, dynamic>> giftList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> giftHistory = <Map<String, dynamic>>[].obs;
  final RxInt totalGiftCoins = 0.obs;
  final RxInt selectedGiftCategoryIndex = 0.obs;
  final RxInt selectedGiftSendingId = 0.obs;
  final RxInt selectedGiftId = 0.obs;
  final RxInt giftReceiverID = 0.obs;
  final RxList<int> selectedReceiverIds = <int>[].obs;
  final RxList<int> selectedProfileIndices = <int>[].obs;
  final RxInt selectedSeatNo = 0.obs;
  final RxBool quickGiftVisible = false.obs;
  final RxBool quickGiftSending = false.obs;
  final RxInt quickGiftCountdown = 0.obs;
  final RxInt quickGiftComboCount = 0.obs;
  final RxMap<String, dynamic> quickGiftData = <String, dynamic>{}.obs;

  Timer? _quickGiftTimer;
  AudioPlayer? _quickGiftLastSoundPlayer;
  bool _quickGiftLastSoundPlayed = false;
  int _quickGiftExpireAtMs = 0;

  /// Every Combo/Quick tap is stored instead of being ignored while an older
  /// network request is running. Queue.removeFirst() is O(1), unlike
  /// List.removeAt(0), so long rapid-tap sessions do not become progressively
  /// slower and freeze the UI.
  final Queue<Map<String, dynamic>> _quickGiftSendQueue =
      Queue<Map<String, dynamic>>();
  final RxInt quickGiftPendingCount = 0.obs;
  bool _quickGiftQueueRunning = false;
  bool _quickGiftPumpScheduled = false;
  int _quickGiftQueueEpoch = 0;
  int _quickGiftClientSerial = 0;

  static const int _quickGiftSeconds = 7;
  static const Duration _quickGiftRequestGap = Duration(milliseconds: 120);

  int _giftClientEventSerial = 0;

  String _newGiftClientEventId({
    required int senderId,
    required int giftId,
    int? streamId,
  }) {
    final int serial = ++_giftClientEventSerial;
    final int micros = DateTime.now().microsecondsSinceEpoch;
    final int eventStreamId = streamId ?? livestreamController.streamId.value;
    return 'gift_${eventStreamId}_${senderId}_${giftId}_${micros}_$serial';
  }

  List<int> _safeQuickReceiverIds(dynamic value) {
    final ids = <int>[];

    void addOne(dynamic raw) {
      final id = int.tryParse(raw?.toString() ?? '0') ?? 0;
      if (id > 0 && !ids.contains(id)) ids.add(id);
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is Map) {
          addOne(
            item['id'] ??
                item['user_id'] ??
                item['receiver_id'] ??
                item['caller_id'],
          );
        } else {
          addOne(item);
        }
      }
    } else if (value is Map) {
      addOne(
        value['id'] ??
            value['user_id'] ??
            value['receiver_id'] ??
            value['caller_id'],
      );
    } else {
      addOne(value);
    }

    return ids;
  }

  Future<void> _playQuickGiftLast5SecSound() async {
    try {
      _quickGiftLastSoundPlayer ??= AudioPlayer();
      await _quickGiftLastSoundPlayer!.stop();
      await _quickGiftLastSoundPlayer!.setReleaseMode(ReleaseMode.stop);
      await _quickGiftLastSoundPlayer!.setVolume(1.0);
      liveLog('🔊 Quick gift last-5-sec sound played');
    } catch (e) {
      liveLog('⚠️ Quick gift last-5-sec sound skipped => $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void _maybePlayQuickGiftLast5Sound(int secondsLeft) {
    if (_quickGiftLastSoundPlayed) return;
    if (secondsLeft > 5 || secondsLeft <= 0) return;

    _quickGiftLastSoundPlayed = true;
    Future.microtask(_playQuickGiftLast5SecSound);
  }

  void _ensureQuickGiftCountdownTicker() {
    if (_quickGiftTimer?.isActive == true) return;

    _quickGiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final int remainingMs =
          _quickGiftExpireAtMs - DateTime.now().millisecondsSinceEpoch;
      final int next = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();

      if (quickGiftCountdown.value != next) {
        quickGiftCountdown.value = next;
      }

      _maybePlayQuickGiftLast5Sound(next);

      if (next <= 0) {
        timer.cancel();
        _quickGiftTimer = null;
        quickGiftVisible.value = false;
        quickGiftComboCount.value = 0;
      }
    });
  }

  void _restartQuickGiftCountdown() {
    _quickGiftExpireAtMs =
        DateTime.now().millisecondsSinceEpoch + (_quickGiftSeconds * 1000);
    quickGiftCountdown.value = _quickGiftSeconds;
    _quickGiftLastSoundPlayed = false;
    _ensureQuickGiftCountdownTicker();
  }

  void showQuickGiftButton({
    required int receiverId,
    required int giftId,
    required int giftPrice,
    Map<String, dynamic>? gift,
    List<int>? receiverIds,
  }) {
    final receivers = <int>[];

    for (final id in receiverIds ?? selectedReceiverIds.toList()) {
      final safeId = int.tryParse(id.toString()) ?? 0;
      if (safeId > 0 && !receivers.contains(safeId)) receivers.add(safeId);
    }

    if (receivers.isEmpty && receiverId > 0) {
      receivers.add(receiverId);
    }

    final bool sameCombo =
        quickGiftVisible.value &&
        int.tryParse('${quickGiftData['gift_id'] ?? 0}') == giftId &&
        _safeQuickReceiverIds(quickGiftData['receiver_ids']).join(',') ==
            receivers.join(',');

    // Do not replace the whole RxMap on every rapid Combo tap. Replacing it
    // rebuilds the gift sheet/card even though gift + receivers are unchanged.
    // Only the lightweight counter/countdown should update for the same combo.
    if (!sameCombo || quickGiftData.isEmpty) {
      quickGiftData.value = {
        'receiver_id': receivers.isNotEmpty ? receivers.first : receiverId,
        'receiver_ids': List<int>.unmodifiable(receivers),
        'gift_id': giftId,
        'gift_price': giftPrice,
        'gift': gift ?? const <String, dynamic>{},
      };
    }

    if (!sameCombo || quickGiftComboCount.value <= 0) {
      quickGiftComboCount.value = 1;
    }

    if (!quickGiftVisible.value) {
      quickGiftVisible.value = true;
    }
    _restartQuickGiftCountdown();
  }

  void _scheduleQuickGiftPump() {
    if (_quickGiftQueueRunning || _quickGiftPumpScheduled) return;
    _quickGiftPumpScheduled = true;

    Future.microtask(() async {
      _quickGiftPumpScheduled = false;
      await _pumpQuickGiftSendQueue();
    });
  }

  Future<void> sendQuickGiftAgain() async {
    final int jobStreamId = livestreamController.streamId.value;
    final int jobGeneration = livestreamController.roomSessionGeneration;
    final receiverIds = _safeQuickReceiverIds(quickGiftData['receiver_ids']);
    final receiverId =
        int.tryParse('${quickGiftData['receiver_id'] ?? 0}') ?? 0;
    if (receiverIds.isEmpty && receiverId > 0) receiverIds.add(receiverId);

    final giftId = int.tryParse('${quickGiftData['gift_id'] ?? 0}') ?? 0;
    final giftPrice = int.tryParse('${quickGiftData['gift_price'] ?? 0}') ?? 0;
    final gift = quickGiftData['gift'] is Map
        ? Map<String, dynamic>.from(quickGiftData['gift'])
        : <String, dynamic>{};

    if (receiverIds.isEmpty || giftId == 0) {
      quickGiftVisible.value = false;
      return;
    }

    final int senderId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
        0;
    if (senderId <= 0) return;

    quickGiftComboCount.value = quickGiftComboCount.value <= 0
        ? 2
        : quickGiftComboCount.value + 1;

    final int clientSerial = ++_quickGiftClientSerial;
    final String clientEventId = _newGiftClientEventId(
      senderId: senderId,
      giftId: giftId,
      streamId: jobStreamId,
    );
    final Map<String, dynamic> job = <String, dynamic>{
      'client_serial': clientSerial,
      'client_event_id': clientEventId,
      'receiver_ids': List<int>.from(receiverIds),
      'receiver_id': receiverIds.first,
      'gift_id': giftId,
      'gift_price': giftPrice,
      'gift': gift,
      'stream_id': jobStreamId,
      'room_generation': jobGeneration,
    };

    /// Do not wait for the previous API call. Every physical/auto tap creates
    /// one visual item immediately; WebsocketController then plays them serially.
    _dispatchGiftToLocalUiImmediately(
      responseData: <String, dynamic>{
        'livestream_id': jobStreamId,
        'stream_id': jobStreamId,
        'client_event_id': clientEventId,
        'client_request_id': clientEventId,
        'client_combo_serial': clientSerial,
        'combo_serial': clientSerial,
        'combo_count': quickGiftComboCount.value,
        'quantity': 1,
        'source': 'quick_combo_tap',
      },
      senderId: senderId,
      receivers: receiverIds,
      giftId: giftId,
      giftPrice: giftPrice,
      clientEventId: clientEventId,
      giftOverride: gift,
    );

    _quickGiftSendQueue.addLast(job);
    quickGiftPendingCount.value = _quickGiftSendQueue.length;

    /// Keep Combo button alive for every tap, including fast auto-click taps.
    showQuickGiftButton(
      receiverId: receiverIds.first,
      receiverIds: receiverIds,
      giftId: giftId,
      giftPrice: giftPrice,
      gift: gift,
    );

    _scheduleQuickGiftPump();
  }

  Future<void> _pumpQuickGiftSendQueue() async {
    if (_quickGiftQueueRunning) return;
    _quickGiftQueueRunning = true;
    final int pumpEpoch = _quickGiftQueueEpoch;

    try {
      while (pumpEpoch == _quickGiftQueueEpoch &&
          _quickGiftSendQueue.isNotEmpty) {
        final Map<String, dynamic> job = Map<String, dynamic>.from(
          _quickGiftSendQueue.removeFirst(),
        );
        quickGiftPendingCount.value = _quickGiftSendQueue.length + 1;

        final receiverIds = _safeQuickReceiverIds(job['receiver_ids']);
        final int receiverId = int.tryParse('${job['receiver_id'] ?? 0}') ?? 0;
        final int giftId = int.tryParse('${job['gift_id'] ?? 0}') ?? 0;
        final int giftPrice = int.tryParse('${job['gift_price'] ?? 0}') ?? 0;
        final String clientEventId =
            job['client_event_id']?.toString().trim() ?? '';
        final int jobStreamId = int.tryParse('${job['stream_id'] ?? 0}') ?? 0;
        final int jobGeneration =
            int.tryParse('${job['room_generation'] ?? -1}') ?? -1;

        if (jobStreamId <= 0 ||
            jobGeneration != livestreamController.roomSessionGeneration ||
            !livestreamController.acceptsRoomMutation(jobStreamId)) {
          livestreamController.websocketController
              .cancelOptimisticGiftAnimation(clientEventId: clientEventId);
          continue;
        }

        if (receiverIds.isEmpty && receiverId > 0) {
          receiverIds.add(receiverId);
        }

        if (receiverIds.isEmpty || giftId <= 0) {
          continue;
        }

        /// Keep the old observable false so the Combo button is never disabled
        /// while the internal queue is processing. The queue-running flag above
        /// prevents two network pumps from running together.
        quickGiftSending.value = false;

        // receiverIdsOverride is already the authoritative receiver list.
        // Mutating selectedReceiverIds here emitted two RxSet changes per tap
        // and rebuilt the bottom sheet repeatedly during 50/100 tap combos.
        await tryToSendGift(
          receiverId: receiverIds.first,
          receiverIdsOverride: receiverIds,
          giftId: giftId,
          giftPrice: giftPrice,
          dispatchLocalAnimation: false,
          clientEventId: clientEventId,
          localGift: job['gift'] is Map
              ? Map<String, dynamic>.from(job['gift'])
              : null,
          requestStreamId: jobStreamId,
          requestGeneration: jobGeneration,
        );

        quickGiftPendingCount.value = _quickGiftSendQueue.length;

        if (pumpEpoch == _quickGiftQueueEpoch &&
            _quickGiftSendQueue.isNotEmpty) {
          await Future<void>.delayed(_quickGiftRequestGap);
        }
      }
    } finally {
      _quickGiftQueueRunning = false;
      quickGiftSending.value = false;
      quickGiftPendingCount.value = _quickGiftSendQueue.length;

      /// A tap can arrive between the final while-check and finally block.
      if (_quickGiftSendQueue.isNotEmpty) {
        _scheduleQuickGiftPump();
      }
    }
  }

  int _giftCoinStreamId = 0;
  DateTime? _lastGiftHistoryFetchAt;
  DateTime? _lastTotalGiftCoinsFetchAt;

  void toggleProfileSelection(int index, int userId) {
    if (selectedProfileIndices.contains(index)) {
      selectedProfileIndices.remove(index);
      selectedReceiverIds.remove(userId);
    } else {
      selectedProfileIndices.add(index);
      selectedReceiverIds.add(userId);
    }
  }

  String giftCategoryOf(Map<String, dynamic> gift) {
    return (gift['category'] ??
            gift['gift_category'] ??
            gift['type'] ??
            'Popular')
        .toString()
        .trim();
  }

  bool isLuckyGift(Map<String, dynamic> gift) {
    final category = giftCategoryOf(gift).toLowerCase();
    final backCoin = gift['back_coin'];
    final explicitLucky =
        (gift['is_lucky_gift'] ?? gift['is_lucky'] ?? gift['lucky'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    return explicitLucky == '1' ||
        explicitLucky == 'true' ||
        explicitLucky == 'yes' ||
        category == 'lucky' ||
        category.contains('lucky') ||
        (backCoin != null &&
            backCoin.toString() != 'null' &&
            backCoin.toString().isNotEmpty);
  }

  void _luckyPrint(String title, dynamic value) {
    // Large per-tap payload logging remains disabled in production.
  }

  List<String> get giftCategories {
    final set = <String>{};
    for (final gift in giftList) {
      final category = giftCategoryOf(Map<String, dynamic>.from(gift));
      if (category.isNotEmpty) set.add(category);
    }

    final list = set.toList();
    list.sort((a, b) {
      final al = a.toLowerCase();
      final bl = b.toLowerCase();
      if (al == 'popular' && bl != 'popular') return -1;
      if (al != 'popular' && bl == 'popular') return 1;

      final aVip =
          al.contains('vip') || al.contains('svip') || al.contains('premium');
      final bVip =
          bl.contains('vip') || bl.contains('svip') || bl.contains('premium');
      if (aVip != bVip) return aVip ? 1 : -1;
      return a.compareTo(b);
    });
    return list;
  }

  List<Map<String, dynamic>> giftsByCategoryIndex(int index) {
    final categories = giftCategories;
    if (categories.isEmpty) {
      return giftList.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final safeIndex = index.clamp(0, categories.length - 1).toInt();
    final category = categories[safeIndex].toLowerCase();
    return giftList
        .map((e) => Map<String, dynamic>.from(e))
        .where((gift) => giftCategoryOf(gift).toLowerCase() == category)
        .toList();
  }

  Map<String, dynamic> _localGiftAssetById(int giftId, int giftPrice) {
    for (final raw in giftList) {
      final gift = Map<String, dynamic>.from(raw);
      final id =
          int.tryParse(
            '${gift['id'] ?? gift['gift_id'] ?? gift['asset_id'] ?? 0}',
          ) ??
          0;
      if (id == giftId) {
        return {
          ...gift,
          'id': gift['id'] ?? giftId,
          'gift_id': gift['gift_id'] ?? giftId,
          'coin': gift['coin'] ?? gift['coins'] ?? gift['price'] ?? giftPrice,
          'coins': gift['coins'] ?? gift['coin'] ?? gift['price'] ?? giftPrice,
          'gift_image':
              gift['gift_image'] ?? gift['image'] ?? gift['show_image'],
          'show_image':
              gift['show_image'] ?? gift['gift_image'] ?? gift['image'],
          'audio': gift['audio'] ?? gift['gift_audio'] ?? gift['sound'],
          'gift_audio': gift['gift_audio'] ?? gift['audio'] ?? gift['sound'],
        };
      }
    }

    return {
      'id': giftId,
      'gift_id': giftId,
      'name': 'Gift',
      'coin': giftPrice,
      'coins': giftPrice,
    };
  }

  void _dispatchGiftToLocalUiImmediately({
    required Map<String, dynamic> responseData,
    required int senderId,
    required List<int> receivers,
    required int giftId,
    required int giftPrice,
    required String clientEventId,
    Map<String, dynamic>? giftOverride,
  }) {
    try {
      final ws = livestreamController.websocketController;
      final currentUser =
          livestreamController.authController.userProfile.value.user;

      final Map<String, dynamic> sourceGift =
          giftOverride != null && giftOverride.isNotEmpty
          ? Map<String, dynamic>.from(giftOverride)
          : _localGiftAssetById(giftId, giftPrice);

      /// The first tap must carry the exact selected animation asset. Looking
      /// the gift up again could return a temporary fallback object while the
      /// list was still refreshing, creating an invisible queue item.
      final Map<String, dynamic> gift = <String, dynamic>{
        ...sourceGift,
        'id': sourceGift['id'] ?? sourceGift['gift_id'] ?? giftId,
        'gift_id': sourceGift['gift_id'] ?? sourceGift['id'] ?? giftId,
        'coin':
            sourceGift['coin'] ??
            sourceGift['coins'] ??
            sourceGift['price'] ??
            giftPrice,
        'coins':
            sourceGift['coins'] ??
            sourceGift['coin'] ??
            sourceGift['price'] ??
            giftPrice,
        'gift_image':
            sourceGift['gift_image'] ??
            sourceGift['image'] ??
            sourceGift['show_image'] ??
            sourceGift['svga'],
        'image':
            sourceGift['image'] ??
            sourceGift['gift_image'] ??
            sourceGift['show_image'] ??
            sourceGift['svga'],
        'show_image':
            sourceGift['show_image'] ??
            sourceGift['gift_image'] ??
            sourceGift['image'] ??
            sourceGift['svga'],
      };

      final sender = responseData['sender'] is Map
          ? Map<String, dynamic>.from(responseData['sender'])
          : <String, dynamic>{
              'id': senderId,
              'user_id': senderId,
              'name': currentUser?.name ?? 'User',
              'profile_image': currentUser?.profileImage ?? '',
              'level': currentUser?.level ?? 0,
              'coins': currentUser?.coins,
              'earned_coins': currentUser?.earnedCoins,
            };

      final int localNow = DateTime.now().microsecondsSinceEpoch;

      final Map<String, dynamic> optimisticPayload = <String, dynamic>{
        ...responseData,
        'success': true,
        'action_type': 'gift_sent',
        'type': 'gift',
        'livestream_id':
            responseData['livestream_id'] ??
            responseData['stream_id'] ??
            livestreamController.streamId.value,
        'stream_id':
            responseData['stream_id'] ??
            responseData['livestream_id'] ??
            livestreamController.streamId.value,
        'sender_id': senderId,
        'user_id': senderId,
        'receiver_ids': receivers,
        'receiver_id': receivers.isNotEmpty ? receivers.first : 0,
        'gift_id': giftId,
        'gift': gift,
        'gift_data': gift,
        'sender': sender,
        'coin': giftPrice,
        'coins': giftPrice,
        'gift_coin': giftPrice,
        'timestamp': DateTime.now().toIso8601String(),
        'client_event_id': clientEventId,
        'client_request_id': clientEventId,
        'gift_animation_serial': localNow,
        'animation_serial': localNow,
        'event_id': 'local_$clientEventId',
      };

      _luckyPrint('GIFT LOCAL OPTIMISTIC PAYLOAD ALL DATA', {
        'gift_object': gift,
        'local_is_lucky_detection': isLuckyGift(gift),
        'optimistic_payload': optimisticPayload,
      });

      ws.handleOptimisticGift(optimisticPayload);

      liveLog(
        '⚡ Gift UI dispatched instantly => receivers:$receivers gift:$giftId coin:$giftPrice',
      );
    } catch (e) {
      liveLog('⚠️ Instant gift UI dispatch skipped => $e');
    }
  }

  String _giftDebugCompact(dynamic value, {int maxLength = 1400}) {
    String text;
    try {
      text = value is String ? value : jsonEncode(value);
    } catch (_) {
      text = value?.toString() ?? '';
    }

    text = text
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...<truncated>';
  }

  String _giftBackendMessage(dynamic body) {
    if (body is Map) {
      final dynamic errors = body['errors'];
      final dynamic message =
          body['message'] ?? body['error'] ?? body['detail'] ?? body['reason'];

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }

      if (errors is Map && errors.isNotEmpty) {
        final List<String> messages = <String>[];
        errors.forEach((dynamic key, dynamic value) {
          if (value is Iterable) {
            messages.addAll(value.map((e) => '$key: $e'));
          } else {
            messages.add('$key: $value');
          }
        });
        if (messages.isNotEmpty) return messages.join(' | ');
      }
    }

    final String fallback = body?.toString().trim() ?? '';
    return fallback.isEmpty ? 'Unknown backend error' : fallback;
  }

  static const bool _giftApiVerboseSuccessLogs = false;

  void _printGiftApiLine(String label, Map<String, dynamic> details) {
    final String upper = label.toUpperCase();
    final bool isFailure =
        upper.contains('ERROR') ||
        upper.contains('REJECTED') ||
        upper.contains('FAILED');

    // Success request/response logging is disabled during normal use. Encoding
    // and printing a large JSON result for every rapid Combo tap blocks Dart's
    // UI isolate and is visible as occasional animation cuts. Failure logs stay
    // enabled so backend problems remain easy to diagnose.
    if (!isFailure && !_giftApiVerboseSuccessLogs) return;

    debugPrint(
      '🎁 $label | ${_giftDebugCompact(details, maxLength: isFailure ? 1600 : 700)}',
      wrapWidth: 1800,
    );
  }

  // Send gift to live stream
  Future<Map<String, dynamic>?> tryToSendGift({
    required int receiverId,
    required int giftId,
    required int giftPrice,
    List<int>? receiverIdsOverride,
    bool dispatchLocalAnimation = true,
    String? clientEventId,
    Map<String, dynamic>? localGift,
    int? requestStreamId,
    int? requestGeneration,
  }) async {
    String resolvedClientEventId = clientEventId?.trim() ?? '';
    final int sendStreamId =
        requestStreamId ?? livestreamController.streamId.value;
    final int sendGeneration =
        requestGeneration ?? livestreamController.roomSessionGeneration;

    try {
      if (sendStreamId <= 0 ||
          sendGeneration != livestreamController.roomSessionGeneration ||
          !livestreamController.acceptsRoomMutation(sendStreamId)) {
        return null;
      }

      final user = livestreamController.authController.userProfile.value.user;
      final userId = user?.id?.toInt() ?? 0;
      final userCoins = int.tryParse(user?.coins.toString() ?? '0') ?? 0;

      if (userId == 0) {
        Fluttertoast.showToast(msg: ("User not found").appTr);
        return null;
      }

      if (resolvedClientEventId.isEmpty) {
        resolvedClientEventId = _newGiftClientEventId(
          senderId: userId,
          giftId: giftId,
          streamId: sendStreamId,
        );
      }

      // 🧾 Local check before API call (extra layer)
      if (userCoins < giftPrice) {
        Fluttertoast.showToast(
          msg: ("Insufficient balance. Please recharge!").appTr,
          backgroundColor: Colors.white,
          textColor: Colors.red,
          gravity: ToastGravity.BOTTOM,
        );
        return null;
      }

      /// If bottom sheet selected no receiver, send to tapped/default receiver.
      /// This also allows self gift when receiverId is current user's id.
      final overrideReceivers = (receiverIdsOverride ?? const <int>[])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toSet()
          .toList();

      final receivers = overrideReceivers.isNotEmpty
          ? overrideReceivers
          : selectedReceiverIds.isNotEmpty
          ? selectedReceiverIds.toList()
          : <int>[receiverId];

      // Per-tap baseline lets the sender device repair every receiver's seat
      // coin exactly once after API/WebSocket confirmation. A simple
      // containsKey check was wrong after the first gift because the key stays
      // in the map forever, so later rapid gifts never changed the displayed
      // coin value.
      final Map<int, int> receiverCoinBaseline = livestreamController
          .websocketController
          .giftCoinSnapshotForUsers(receivers);

      final data = {
        "sender_id": userId,
        // Keep both singular and batch keys. The optimized Lucky endpoint uses
        // receiver_ids, while older validation/routes may still require
        // receiver_id. Sending both is backward compatible.
        "receiver_id": receivers.isNotEmpty ? receivers.first : receiverId,
        "receiver_ids": receivers,
        "gift_id": giftId,
        "quantity": 1,
        "client_event_id": resolvedClientEventId,
        "client_request_id": resolvedClientEventId,
        "stream_id": sendStreamId,
        "livestream_id": sendStreamId,
        if (selectedSeatNo.value > 0) "seat_no": selectedSeatNo.value,
        ...livestreamController.pkCommentGiftMetaBody(),
      };

      if (_giftApiVerboseSuccessLogs) {
        _printGiftApiLine('GIFT_API_REQUEST', <String, dynamic>{
          'url': kSentGift,
          'stream_id': sendStreamId,
          'sender_id': userId,
          'gift_id': giftId,
          'gift_price': giftPrice,
          'receiver_count': receivers.length,
          'receiver_ids': receivers,
          'seat_no': selectedSeatNo.value,
          'local_animation': dispatchLocalAnimation,
        });
      }

      final Map<String, dynamic> selectedGiftForDebug =
          localGift != null && localGift.isNotEmpty
          ? <String, dynamic>{
              ...Map<String, dynamic>.from(localGift),
              'id': localGift['id'] ?? localGift['gift_id'] ?? giftId,
              'gift_id': localGift['gift_id'] ?? localGift['id'] ?? giftId,
              'coin':
                  localGift['coin'] ??
                  localGift['coins'] ??
                  localGift['price'] ??
                  giftPrice,
              'coins':
                  localGift['coins'] ??
                  localGift['coin'] ??
                  localGift['price'] ??
                  giftPrice,
            }
          : _localGiftAssetById(giftId, giftPrice);

      // DEBUG V2: Print every gift request. Some backends expose a Lucky gift
      // as a normal gift_sent request and only return Lucky fields later.
      _luckyPrint('ALL GIFT SEND API REQUEST RAW', {
        'url': kSentGift,
        'request_data': data,
        'selected_gift_from_local_list': selectedGiftForDebug,
        'local_is_lucky_detection': isLuckyGift(selectedGiftForDebug),
        'gift_id': giftId,
        'gift_price': giftPrice,
        'sender_id': userId,
        'sender_balance_before': userCoins,
        'receiver_id_argument': receiverId,
        'resolved_receiver_ids': receivers,
        'receiver_ids_override': receiverIdsOverride,
        'selected_receiver_ids_state': selectedReceiverIds.toList(),
        'selected_seat_no': selectedSeatNo.value,
        'stream_id': sendStreamId,
        'dispatch_local_animation': dispatchLocalAnimation,
      });

      if (isLuckyGift(selectedGiftForDebug)) {
        _luckyPrint('LUCKY GIFT SEND API REQUEST', {
          'url': kSentGift,
          'request_data': data,
          'selected_gift': selectedGiftForDebug,
          'sender_balance_before': userCoins,
          'dispatch_local_animation': dispatchLocalAnimation,
          'selected_receiver_ids_state': selectedReceiverIds.toList(),
          'selected_seat_no': selectedSeatNo.value,
        });
      }

      /// Start the visual animation BEFORE any network/API wait and before the
      /// bottom-sheet loading Rx changes repaint the gift panel. This makes the
      /// sender device feel instant like Bigo/Ligo.
      if (dispatchLocalAnimation) {
        _dispatchGiftToLocalUiImmediately(
          responseData: {
            'livestream_id': sendStreamId,
            'stream_id': sendStreamId,
            'client_event_id': resolvedClientEventId,
            'client_request_id': resolvedClientEventId,
          },
          senderId: userId,
          receivers: receivers,
          giftId: giftId,
          giftPrice: giftPrice,
          clientEventId: resolvedClientEventId,
          giftOverride: selectedGiftForDebug,
        );
      }

      selectedGiftSendingId.value = giftId;

      final String token =
          livestreamController.authController.userProfile.value.token
              ?.toString()
              .trim() ??
          '';

      final response = await livestreamController.dio.post(
        kSentGift,
        data: data,
        options: Options(
          headers: <String, dynamic>{
            "Content-Type": "application/json",
            "Accept": "application/json",
            if (token.isNotEmpty) "Authorization": "Bearer $token",
          },
          // Keep 4xx/5xx responses inside the normal flow so the real backend
          // validation/database message can be printed instead of being hidden.
          validateStatus: (int? status) => status != null && status < 600,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

      final dynamic responseBody = response.data;
      final String responseMessage = _giftBackendMessage(responseBody);
      if (_giftApiVerboseSuccessLogs) {
        _printGiftApiLine('GIFT_API_RESPONSE', <String, dynamic>{
          'status': response.statusCode,
          'status_message': response.statusMessage,
          'success': responseBody is Map ? responseBody['success'] : null,
          'action_type': responseBody is Map
              ? responseBody['action_type']
              : null,
          'message': responseMessage,
        });
      }

      // DEBUG V2: Always print the complete API response before parsing.
      _luckyPrint('ALL GIFT SEND API RESPONSE RAW', {
        'status_code': response.statusCode,
        'status_message': response.statusMessage,
        'request_url': kSentGift,
        'request_data': data,
        'selected_gift_from_local_list': selectedGiftForDebug,
        'local_is_lucky_detection': isLuckyGift(selectedGiftForDebug),
        'response_runtime_type': response.data.runtimeType.toString(),
        'response_data': response.data,
        'response_headers': response.headers.map,
      });

      if (isLuckyGift(selectedGiftForDebug) ||
          (response.data is Map &&
              ((response.data as Map)['action_type'] == 'lucky_gift_result' ||
                  (response.data as Map)['is_lucky_gift'] == true ||
                  (response.data as Map)['lucky_results'] is List ||
                  (response.data as Map)['lucky_result'] is Map))) {
        _luckyPrint('LUCKY GIFT SEND API FULL RESPONSE', {
          'status_code': response.statusCode,
          'status_message': response.statusMessage,
          'request_data': data,
          'response_data': response.data,
          'response_headers': response.headers.map,
        });
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        if (responseData["success"] == true ||
            responseData["action_type"] == "lucky_gift_result") {
          /// ✅ Gift UI source of truth fix:
          /// Do NOT dispatch local/optimistic gift here.
          /// The gift animation, receiver seat coin, and gift history must be
          /// updated from the backend websocket event only. Otherwise sender
          /// device shows one local event and then another websocket event,
          /// causing duplicate/late/wrong multi-receiver coin display.

          /// Normal gift response has sender coins.
          /// Lucky response may include sender coins or win_amount. Only update if backend sends coins.
          if (responseData['sender'] is Map &&
              responseData['sender']['coins'] != null) {
            livestreamController.authController.userProfile.value.user!.coins =
                responseData['sender']['coins'].toString();
            livestreamController.authController.userProfile.refresh();
          }

          /// ✅ Bulk receiver fallback:
          /// Server sometimes accepts receiver_ids like [100577, 100558],
          /// but websocket broadcasts only one receiver_id. Then the missing
          /// receiver's seat coin does not show on sender device.
          /// Wait a little for websocket; then update only receiver ids that
          /// websocket did not update, so no duplicate coin is added.
          Future.delayed(const Duration(milliseconds: 220), () {
            if (sendGeneration != livestreamController.roomSessionGeneration ||
                !livestreamController.acceptsRoomMutation(sendStreamId)) {
              return;
            }
            try {
              livestreamController.websocketController
                  .ensureSenderGiftCoinsAtLeast(
                    receiverIds: receivers
                        .map((e) => int.tryParse(e.toString()) ?? 0)
                        .where((e) => e > 0)
                        .toList(growable: false),
                    baselineCoins: receiverCoinBaseline,
                    coinValue: giftPrice,
                  );
            } catch (e) {
              liveLog('⚠️ Sender gift coin reconciliation skipped => $e');
            }
          });

          /// Lucky gift result can come directly in send response.
          /// WebSocket should also broadcast action_type lucky_gift_result for all users.
          if (responseData['action_type'] == 'lucky_gift_result' ||
              responseData['is_lucky_gift'] == true ||
              responseData['lucky_results'] is List ||
              responseData['lucky_result'] is Map) {
            _luckyPrint('LUCKY GIFT SEND RESPONSE PARSED', {
              'response_data': responseData,
              'data': livestreamController.liveLuckyGiftController.mapOf(
                responseData['data'],
              ),
              'sender': livestreamController.liveLuckyGiftController.mapOf(
                responseData['sender'],
              ),
              'receiver': livestreamController.liveLuckyGiftController.mapOf(
                responseData['receiver'],
              ),
              'gift': livestreamController.liveLuckyGiftController.mapOf(
                responseData['gift'] ?? responseData['gift_data'],
              ),
              'lucky_result': livestreamController.liveLuckyGiftController
                  .mapOf(responseData['lucky_result']),
              'lucky_results': responseData['lucky_results'],
              'multiplier': responseData['multiplier'],
              'win_amount': responseData['win_amount'],
              'is_win': responseData['is_win'],
            });
            // Loss responses arrive for every tap. Rebuilding the Lucky result
            // state for each loss adds avoidable work during long Combo bursts.
            // Only a real positive payout needs the WIN/times UI.
            if (sendGeneration == livestreamController.roomSessionGeneration &&
                livestreamController.acceptsRoomMutation(sendStreamId) &&
                livestreamController.liveLuckyGiftController
                    .responseHasVisibleWin(responseData)) {
              livestreamController.liveLuckyGiftController.showLuckyGiftResult(
                responseData,
              );
            }

            // Fluttertoast.showToast(
            //   msg: isWin
            //       ? 'Lucky win! +$winAmount coins x$multiplier'
            //       : 'Better luck next time',
            //   backgroundColor: isWin ? Colors.green : Colors.black87,
            //   textColor: Colors.white,
            //   gravity: ToastGravity.CENTER,
            // );
          }

          return responseData;
        } else {
          livestreamController.websocketController
              .cancelOptimisticGiftAnimation(
                clientEventId: resolvedClientEventId,
              );
          final String msg = _giftBackendMessage(responseData);
          _printGiftApiLine('GIFT_API_REJECTED', <String, dynamic>{
            'status': response.statusCode,
            'message': msg,
            'gift_id': giftId,
            'receiver_count': receivers.length,
          });
          Fluttertoast.showToast(
            msg: 'Gift failed (${response.statusCode ?? 0}): $msg',
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            gravity: ToastGravity.CENTER,
          );
          liveLog("⚠️ Gift rejected: $msg");
        }
      } else {
        livestreamController.websocketController.cancelOptimisticGiftAnimation(
          clientEventId: resolvedClientEventId,
        );
        final String msg = _giftBackendMessage(response.data);
        _printGiftApiLine('GIFT_API_HTTP_ERROR', <String, dynamic>{
          'status': response.statusCode,
          'status_message': response.statusMessage,
          'message': msg,
          'gift_id': giftId,
          'receiver_count': receivers.length,
          'body': _giftDebugCompact(response.data, maxLength: 900),
        });
        Fluttertoast.showToast(
          msg: 'Gift failed (${response.statusCode ?? 0}): $msg',
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          gravity: ToastGravity.CENTER,
        );
      }
    } on DioException catch (e) {
      livestreamController.websocketController.cancelOptimisticGiftAnimation(
        clientEventId: resolvedClientEventId,
      );

      final dynamic body = e.response?.data;
      final String backendMessage = _giftBackendMessage(body);
      final String safeMessage = e.response != null
          ? backendMessage
          : (e.message?.trim().isNotEmpty == true
                ? e.message!.trim()
                : (e.error?.toString() ?? 'Network request failed'));

      _printGiftApiLine('GIFT_API_DIO_ERROR', <String, dynamic>{
        'type': e.type.toString(),
        'status': e.response?.statusCode,
        'status_message': e.response?.statusMessage,
        'message': safeMessage,
        'uri': e.requestOptions.uri.toString(),
        'method': e.requestOptions.method,
        'gift_id': giftId,
        'gift_price': giftPrice,
        'receiver_id': receiverId,
        'receiver_count': receiverIdsOverride?.length,
        'response': _giftDebugCompact(body, maxLength: 900),
      });

      Fluttertoast.showToast(
        msg: e.response != null
            ? 'Gift failed (${e.response?.statusCode ?? 0}): $safeMessage'
            : 'Gift network error: $safeMessage',
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        gravity: ToastGravity.CENTER,
      );
      liveLog('❌ Gift API error: $safeMessage');
    } catch (e, stackTrace) {
      livestreamController.websocketController.cancelOptimisticGiftAnimation(
        clientEventId: resolvedClientEventId,
      );
      _printGiftApiLine('GIFT_API_UNKNOWN_ERROR', <String, dynamic>{
        'gift_id': giftId,
        'gift_price': giftPrice,
        'receiver_id': receiverId,
        'receiver_count': receiverIdsOverride?.length,
        'error': e.toString(),
        'stack': _giftDebugCompact(stackTrace.toString(), maxLength: 700),
      });
      Fluttertoast.showToast(
        msg: "Gift unexpected error: $e",
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        gravity: ToastGravity.CENTER,
      );
      liveLog("❌ Gift unexpected error: $e");
    } finally {
      if (sendGeneration == livestreamController.roomSessionGeneration &&
          livestreamController.acceptsRoomMutation(sendStreamId) &&
          selectedGiftSendingId.value == giftId) {
        selectedGiftSendingId.value = 0;
      }
    }

    return null;
  }

  Future<void> fetchGiftList() async {
    try {
      final response = await livestreamController.dio.get(
        kGiftList,
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null && responseData['success'] == true) {
          giftList.assignAll(
            List<Map<String, dynamic>>.from(responseData['data']),
          );
          liveLog('Gift list updated successfully.');
        } else {
          liveLog('No gift list data found.');
        }
      } else {
        liveLog(
          'Failed to fetch gifts: ${response.statusCode} - ${response.data}',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          'Gift list server error: ${e.response!.statusCode} - ${e.response!.data}',
        );
      } else {
        liveLog('Gift list network error: ${e.message}');
      }
    } catch (e) {
      liveLog('Gift list unexpected error: $e');
    }
  }

  Future<void> fetchGiftHistory() async {
    final now = DateTime.now();
    if (_lastGiftHistoryFetchAt != null &&
        now.difference(_lastGiftHistoryFetchAt!).inMilliseconds < 2500) {
      return;
    }
    _lastGiftHistoryFetchAt = now;

    final sid =
        int.tryParse(livestreamController.streamId.value.toString()) ?? 0;
    if (sid <= 0) return;

    try {
      final response = await livestreamController.dio.get(
        '$kMainUrl/livestream/$sid/gift-history',
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!livestreamController.acceptsRoomMutation(sid)) {
          liveLog('Late gift history ignored => stream=$sid');
          return;
        }
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null && responseData['success'] == true) {
          giftHistory.assignAll(
            List<Map<String, dynamic>>.from(responseData['gift_history']),
          );
        } else {
          liveLog('No gift history found.');
        }
      } else {
        liveLog(
          'Failed to fetch gift history: ${response.statusCode} - ${response.data}',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          'Gift history server error: ${e.response!.statusCode} - ${e.response!.data}',
        );
      } else {
        liveLog('Gift history network error: ${e.message}');
      }
    } catch (e) {
      liveLog('Gift history unexpected error: $e');
    }
  }

  int _safeCoinInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  void activateGiftRoom(int streamId) {
    if (streamId > 0) _giftCoinStreamId = streamId;
  }

  void resetGiftRoomState({required int streamId}) {
    resetQuickGiftState();
    giftList.clear();
    giftHistory.clear();
    totalGiftCoins.value = 0;
    selectedGiftSendingId.value = 0;
    _giftCoinStreamId = streamId > 0 ? streamId : 0;
  }

  void resetQuickGiftState() {
    _quickGiftTimer?.cancel();
    _quickGiftTimer = null;
    for (final job in _quickGiftSendQueue) {
      final clientEventId = job['client_event_id']?.toString().trim() ?? '';
      if (clientEventId.isNotEmpty) {
        livestreamController.websocketController.cancelOptimisticGiftAnimation(
          clientEventId: clientEventId,
        );
      }
    }
    _quickGiftSendQueue.clear();
    _quickGiftQueueEpoch++;
    quickGiftPendingCount.value = 0;
    quickGiftComboCount.value = 0;
    quickGiftCountdown.value = 0;
    quickGiftVisible.value = false;
    quickGiftSending.value = false;
    quickGiftData.clear();
    _quickGiftExpireAtMs = 0;
    _quickGiftLastSoundPlayed = false;
  }

  Future<void> disposeGiftState() async {
    resetQuickGiftState();
    await _quickGiftLastSoundPlayer?.dispose();
    _quickGiftLastSoundPlayer = null;
  }

  @override
  void onClose() {
    disposeGiftState();
    super.onClose();
  }

  void syncLiveGiftCoinsFromPayload(
    Map<String, dynamic> payload, {
    String source = 'payload',
  }) {
    try {
      final data = payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : payload['live_stream'] is Map
          ? Map<String, dynamic>.from(payload['live_stream'])
          : payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final action = (payload['action_type'] ?? payload['action'] ?? '')
          .toString()
          .toLowerCase();
      final viewerPayload =
          action.contains('viewer') ||
          action.contains('join') ||
          payload.containsKey('viewer') ||
          payload.containsKey('viewer_data') ||
          data.containsKey('viewer_id');
      final hasLiveCoinKey =
          data.containsKey('total_gift_coins') ||
          data.containsKey('total_coins') ||
          data.containsKey('gift_amount') ||
          data.containsKey('stream_coins') ||
          data.containsKey('received_coins');

      if (viewerPayload && !hasLiveCoinKey) return;

      final raw =
          data['total_gift_coins'] ??
          data['total_coins'] ??
          data['gift_amount'] ??
          data['stream_coins'] ??
          data['received_coins'] ??
          data['gifts_coins'];
      if (raw == null) return;

      final newCoins = _safeCoinInt(raw);
      final oldCoins = _safeCoinInt(totalGiftCoins.value);
      final payloadStreamId = _safeCoinInt(
        payload['livestream_id'] ??
            payload['stream_id'] ??
            payload['id'] ??
            data['livestream_id'] ??
            data['stream_id'] ??
            data['id'],
      );
      final currentStreamId =
          int.tryParse(livestreamController.streamId.value.toString()) ?? 0;

      if (currentStreamId > 0 &&
          payloadStreamId > 0 &&
          payloadStreamId != currentStreamId) {
        liveLog(
          'Live gift coin sync ignored from other stream '
          'event=$payloadStreamId current=$currentStreamId source=$source',
        );
        return;
      }
      if (payloadStreamId > 0 &&
          _giftCoinStreamId > 0 &&
          payloadStreamId != _giftCoinStreamId) {
        _giftCoinStreamId = payloadStreamId;
        totalGiftCoins.value = newCoins;
        return;
      }
      if (payloadStreamId > 0 && _giftCoinStreamId == 0) {
        _giftCoinStreamId = payloadStreamId;
      }
      if (newCoins == 0 && oldCoins > 0) return;
      if (newCoins > 0 || oldCoins <= 0) totalGiftCoins.value = newCoins;
    } catch (e) {
      liveLog('syncLiveGiftCoinsFromPayload error: $e');
    }
  }

  Future<void> fetchTotalGiftCoins() async {
    final now = DateTime.now();
    if (_lastTotalGiftCoinsFetchAt != null &&
        now.difference(_lastTotalGiftCoinsFetchAt!).inMilliseconds < 2500) {
      return;
    }
    _lastTotalGiftCoinsFetchAt = now;

    final sid =
        int.tryParse(livestreamController.streamId.value.toString()) ?? 0;
    if (sid <= 0) return;

    try {
      final response = await livestreamController.dio.get(
        kGetTotalGiftCoins(sid),
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!livestreamController.acceptsRoomMutation(sid)) {
          liveLog('Late gift total ignored => stream=$sid');
          return;
        }
        final responseData = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};
        if (responseData['success'] == true ||
            responseData.containsKey('total_gift_coins')) {
          final raw =
              responseData['total_gift_coins'] ??
              responseData['total_coins'] ??
              responseData['gifts_coins'] ??
              responseData['gift_amount'] ??
              responseData['stream_coins'];
          final newCoins = _safeCoinInt(raw);
          final oldCoins = _safeCoinInt(totalGiftCoins.value);
          final streamChanged =
              _giftCoinStreamId > 0 && sid != _giftCoinStreamId;
          if (streamChanged) {
            _giftCoinStreamId = sid;
            totalGiftCoins.value = newCoins;
            return;
          }
          if (_giftCoinStreamId == 0) _giftCoinStreamId = sid;
          if (newCoins == 0 && oldCoins > 0) return;
          if (newCoins > 0 || oldCoins <= 0) totalGiftCoins.value = newCoins;
        }
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          'Gift total server error: ${e.response!.statusCode} - ${e.response!.data}',
        );
      } else {
        liveLog('Gift total network error: ${e.message}');
      }
    } catch (e) {
      liveLog('Gift total unexpected error: $e');
    }
  }
}
