import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../auth/controllers/auth_controller.dart';
import '../utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

typedef CurrentLivestreamIdResolver = int Function();
typedef CurrentRoomRedPacketResolver = Map<String, dynamic> Function();
typedef CurrentRoomRedPacketUpdater = void Function(
    Map<String, dynamic> packet,
    );

/// Owns every Lucky Bag / Red Packet responsibility that previously made
/// LivestreamController unnecessarily large.
///
/// Room websocket state still belongs to WebsocketController; this controller
/// reads and updates that state only through callbacks, which keeps the three
/// controllers decoupled and preserves the old behavior.
class RedPacketController extends GetxController {
  RedPacketController({
    required this.dio,
    required this.authController,
    required CurrentLivestreamIdResolver currentLivestreamIdResolver,
    required CurrentRoomRedPacketResolver currentRoomPacketResolver,
    required CurrentRoomRedPacketUpdater currentRoomPacketUpdater,
  })  : _currentLivestreamIdResolver = currentLivestreamIdResolver,
        _currentRoomPacketResolver = currentRoomPacketResolver,
        _currentRoomPacketUpdater = currentRoomPacketUpdater;

  final Dio dio;
  final AuthController authController;
  final CurrentLivestreamIdResolver _currentLivestreamIdResolver;
  final CurrentRoomRedPacketResolver _currentRoomPacketResolver;
  final CurrentRoomRedPacketUpdater _currentRoomPacketUpdater;

  int get currentLivestreamId {
    try {
      return _currentLivestreamIdResolver();
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> _currentRoomPacketSnapshot() {
    try {
      return Map<String, dynamic>.from(_currentRoomPacketResolver());
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _applyCurrentRoomPacket(Map<String, dynamic> packet) {
    try {
      _currentRoomPacketUpdater(Map<String, dynamic>.from(packet));
    } catch (error) {
      liveLog('⚠️ Red packet room-state update skipped: $error');
    }
  }

  /// ===================== GLOBAL LUCKY BAG / RED PACKET BANNER =====================
  /// This banner is for all app pages and all live rooms. It shows for 5 seconds
  /// after receiving a global red_packet_sent event.
  final globalLuckyBagData = <String, dynamic>{}.obs;
  final globalLuckyBagBannerVisible = false.obs;
  final globalLuckyBagBannerSeconds = 0.obs;
  Timer? _globalLuckyBagBannerTimer;

  /// packetId -> my collected coin amount. Backend can reply "already collected"
  /// without returning the amount; keep the amount from the first successful
  /// collection so the result card never falls back to 0.
  final Map<int, int> _redPacketMyAmountCache = <int, int>{};

  void showGlobalLuckyBagBanner(
      Map<String, dynamic> packet, {
        int seconds = 5,
      }) {
    final Map<String, dynamic> safePacket = Map<String, dynamic>.from(packet);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;

    /// ✅ Keep UI metadata so every page/banner/dialog can calculate correctly.
    /// Backend sometimes sends only unlock_after_seconds (example: 3s). Do not
    /// overwrite that with a hard 30s value, otherwise users reach the room late
    /// and OPEN can return already collected/expired.
    safePacket['event_received_at_ms'] ??= nowMs;
    safePacket['banner_received_at_ms'] = nowMs;
    final int serverUnlockSeconds = _redPacketInt(
      safePacket['unlock_after_seconds'] ??
          safePacket['open_after_seconds'] ??
          safePacket['unlock_after'] ??
          safePacket['open_after'],
    );
    final int safeOpenAfter = serverUnlockSeconds > 0
        ? serverUnlockSeconds
        : 30;
    safePacket['open_after_seconds'] ??= safeOpenAfter;
    safePacket['unlock_after_seconds'] ??= safeOpenAfter;

    _redPacketPrint('GLOBAL LUCKY BAG BANNER SHOW DATA', safePacket);

    _globalLuckyBagBannerTimer?.cancel();
    globalLuckyBagData.assignAll(safePacket);
    globalLuckyBagBannerSeconds.value = seconds <= 0 ? 5 : seconds;
    globalLuckyBagBannerVisible.value = true;

    _globalLuckyBagBannerTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
        ) {
      if (globalLuckyBagBannerSeconds.value <= 1) {
        timer.cancel();
        hideGlobalLuckyBagBanner();
        return;
      }
      globalLuckyBagBannerSeconds.value--;
    });
  }

  void hideGlobalLuckyBagBanner() {
    _globalLuckyBagBannerTimer?.cancel();
    _globalLuckyBagBannerTimer = null;
    globalLuckyBagBannerVisible.value = false;
    globalLuckyBagBannerSeconds.value = 0;
  }

  Map<String, dynamic> extractRedPacketFromEvent(dynamic payload) {
    final root = _redPacketMap(payload);
    final data = _redPacketMap(root['data']);

    final redPacket = _redPacketMap(
      root['red_packet'] ??
          root['redPacket'] ??
          data['red_packet'] ??
          data['redPacket'] ??
          data['packet'] ??
          root['packet'],
    );

    if (redPacket.isNotEmpty) return redPacket;

    // Some websocket payloads send the red packet fields directly.
    if (root['id'] != null &&
        (root['amount'] != null || root['coins'] != null)) {
      return root;
    }

    if (data['id'] != null &&
        (data['amount'] != null || data['coins'] != null)) {
      return data;
    }

    return <String, dynamic>{};
  }

  bool redPacketEventIsGlobal(dynamic payload, Map<String, dynamic> packet) {
    final root = _redPacketMap(payload);
    final data = _redPacketMap(root['data']);

    final dynamic value =
        packet['is_global'] ??
            packet['global'] ??
            data['is_global'] ??
            data['global'] ??
            root['is_global'] ??
            root['global'];

    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'global';
  }

  void handleRedPacketSentForGlobalBanner(dynamic payload) {
    final packet = extractRedPacketFromEvent(payload);

    _redPacketPrint('RED PACKET REALTIME EVENT RAW', payload);
    _redPacketPrint('RED PACKET REALTIME PACKET PARSED', packet);

    if (packet.isEmpty) {
      liveLog('⚠️ Global Lucky Bag banner skipped: packet empty');
      return;
    }

    final bool isGlobal = redPacketEventIsGlobal(payload, packet);
    if (!isGlobal) {
      liveLog('ℹ️ Global Lucky Bag banner skipped: is_global=false');
      return;
    }

    showGlobalLuckyBagBanner(packet, seconds: 5);
  }


  int _redPacketInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _redPacketMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, String> _redPacketHeaders() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer ${authController.userProfile.value.token}",
    };
  }

  void _syncRedPacketBalance(dynamic value) {
    final int balance = _redPacketInt(value);
    if (balance <= 0) return;

    try {
      final dynamic user = authController.userProfile.value.user;
      try {
        user?.coins = balance;
      } catch (_) {}
      try {
        user?.balance = balance;
      } catch (_) {}
      authController.userProfile.refresh();
    } catch (_) {}
  }

  String _redPacketMessageFromResponse(dynamic body, String fallback) {
    final map = _redPacketMap(body);
    final data = _redPacketMap(map['data']);
    final message =
        (map['message'] ?? data['message'])?.toString().trim() ?? '';
    return message.isEmpty ? fallback : message;
  }

  int _redPacketCollectedAmountFromMaps(
      Map<String, dynamic> dataMap,
      Map<String, dynamic> redPacketMap,
      Map<String, dynamic> collectionMap,
      ) {
    final values = <dynamic>[
      dataMap['collected_amount'],
      dataMap['amount_collected'],
      dataMap['my_collection_amount'],
      collectionMap['amount_collected'],
      collectionMap['collected_amount'],
      collectionMap['amount'],
      redPacketMap['my_collection_amount'],
      redPacketMap['amount_collected'],
      redPacketMap['collected_amount'],
    ];

    for (final value in values) {
      final amount = _redPacketInt(value);
      if (amount > 0) return amount;
    }
    return 0;
  }

  Map<String, dynamic> _redPacketMyCollectionFromPacket(
      Map<String, dynamic> redPacketMap,
      ) {
    final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (myId <= 0) return <String, dynamic>{};

    final directAmount = _redPacketInt(
      redPacketMap['my_collection_amount'] ??
          redPacketMap['amount_collected'] ??
          redPacketMap['collected_amount'],
    );
    final collectedByMe =
        redPacketMap['collected_by_me'] == true ||
            redPacketMap['collected_by_me']?.toString() == '1';
    if (directAmount > 0 &&
        (collectedByMe || redPacketMap['my_collection_amount'] != null)) {
      return <String, dynamic>{
        'user_id': myId,
        'amount_collected': directAmount,
        'collected_amount': directAmount,
        'amount': directAmount,
      };
    }

    final rawCollections =
        redPacketMap['collections'] ??
            redPacketMap['collectors'] ??
            redPacketMap['collection_list'];
    if (rawCollections is! List) return <String, dynamic>{};

    for (final raw in rawCollections) {
      final item = _redPacketMap(raw);
      if (item.isEmpty) continue;
      final collector = _redPacketMap(item['collector'] ?? item['user']);
      final int collectorId = _redPacketInt(
        item['user_id'] ??
            item['collector_id'] ??
            item['receiver_id'] ??
            collector['id'] ??
            collector['user_id'],
      );
      if (collectorId == myId) return item;
    }

    return <String, dynamic>{};
  }

  bool _redPacketAlreadyCollectedResponse(
      String message,
      Map<String, dynamic> bodyMap,
      Map<String, dynamic> dataMap,
      Map<String, dynamic> redPacketMap,
      Map<String, dynamic> collectionMap,
      ) {
    final text = message.toLowerCase();
    final bool messageSaysCollected =
        text.contains('already') &&
            (text.contains('collect') ||
                text.contains('receive') ||
                text.contains('claim'));

    final collectedByMe =
        redPacketMap['collected_by_me'] == true ||
            dataMap['collected_by_me'] == true ||
            bodyMap['collected_by_me'] == true ||
            redPacketMap['collected_by_me']?.toString() == '1' ||
            dataMap['collected_by_me']?.toString() == '1' ||
            bodyMap['collected_by_me']?.toString() == '1';

    final myCollection = collectionMap.isNotEmpty
        ? collectionMap
        : _redPacketMyCollectionFromPacket(redPacketMap);
    final hasCollection =
        myCollection.isNotEmpty ||
            _redPacketCollectedAmountFromMaps(dataMap, redPacketMap, myCollection) >
                0;

    return messageSaysCollected || collectedByMe || hasCollection;
  }

  Map<String, dynamic> _normalizeRedPacketCollectData(
      Map<String, dynamic> bodyMap,
      Map<String, dynamic> dataMap,
      Map<String, dynamic> redPacketMap,
      Map<String, dynamic> collectionMap,
      ) {
    final normalized = <String, dynamic>{...bodyMap, ...dataMap};

    final myCollection = collectionMap.isNotEmpty
        ? collectionMap
        : _redPacketMyCollectionFromPacket(redPacketMap);

    if (redPacketMap.isNotEmpty) normalized['red_packet'] = redPacketMap;
    if (myCollection.isNotEmpty) normalized['collection'] = myCollection;

    final int amount = _redPacketCollectedAmountFromMaps(
      normalized,
      redPacketMap,
      myCollection,
    );
    if (amount > 0) {
      normalized['collected_amount'] = amount;
      normalized['amount_collected'] = amount;
      normalized['my_collection_amount'] = amount;
      final packetId = _redPacketInt(
        redPacketMap['id'] ??
            redPacketMap['red_packet_id'] ??
            normalized['red_packet_id'],
      );
      if (packetId > 0) _redPacketMyAmountCache[packetId] = amount;
    }

    return normalized;
  }

  void _syncRedPacketAfterCollect(Map<String, dynamic> collectData) {
    final packet = _redPacketMap(collectData['red_packet']);
    if (packet.isEmpty) return;

    final current = _currentRoomPacketSnapshot();
    final int packetId = _redPacketInt(
      packet['id'] ?? packet['red_packet_id'],
    );
    final int currentId = _redPacketInt(
      current['id'] ?? current['red_packet_id'],
    );

    if (current.isEmpty || currentId == 0 || currentId == packetId) {
      _applyCurrentRoomPacket(<String, dynamic>{
        ...current,
        ...packet,
        'id': packetId > 0 ? packetId : (packet['id'] ?? current['id']),
        'collected_by_me': true,
        'can_collect': false,
        'my_collection_amount':
        collectData['collected_amount'] ??
            collectData['amount_collected'] ??
            packet['my_collection_amount'],
      });
    }
  }

  /// Send Lucky Bag to livestream.
  /// Backend supports: amount/coins, quantity/number_of_users, duration_seconds.
  Future<bool> sendRedPacket({
    required double amount,
    int quantity = 10,
    int durationSeconds = 120,
    int openAfterSeconds = 30,
    bool? isGlobal,
    String? message,
  }) async {
    final int safeAmount = amount.round();
    final int safeQuantity = quantity <= 0 ? 1 : quantity;

    /// ✅ User will see minimum 30s countdown before OPEN.
    /// Backend `duration_seconds` is expiry time, so it must be longer than open time.
    /// If UI sends 30, we send 120 to backend so OPEN at 30s will not be expired.
    final int safeOpenAfter = openAfterSeconds <= 0 ? 30 : openAfterSeconds;
    final int requestedDuration = durationSeconds <= 0 ? 120 : durationSeconds;
    final int safeDuration = requestedDuration <= safeOpenAfter
        ? safeOpenAfter + 90
        : requestedDuration;

    if (currentLivestreamId <= 0 || safeAmount <= 0) {
      return false;
    }

    try {
      final Map<String, dynamic> data = {
        "livestream_id": currentLivestreamId,
        "amount": safeAmount,
        "coins": safeAmount,
        "quantity": safeQuantity,
        "number_of_users": safeQuantity,
        "packet_type": "random",
        "duration_seconds": safeDuration,

        /// ✅ Flutter UI opens after 30s; backend may ignore these extra keys safely.
        "open_after_seconds": safeOpenAfter,
        "unlock_after_seconds": safeOpenAfter,

        /// ✅ all app page / all broad banner-er jonno true
        "is_global": true,

        "message": (message?.trim().isNotEmpty ?? false)
            ? message!.trim()
            : "Sent you a Lucky Bag",
      };

      _redPacketPrint('RED PACKET SEND REQUEST', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'url': kSendRedPacketUrl,
        'controller_stream_id': currentLivestreamId,
        'safe_open_after_seconds': safeOpenAfter,
        'safe_duration_seconds': safeDuration,
        'request_payload': data,
      });

      final Stopwatch requestStopwatch = Stopwatch()..start();

      final response = await dio.post(
        kSendRedPacketUrl,
        data: data,
        options: Options(
          headers: _redPacketHeaders(),

          /// 500 er niche sob response amra handle korbo
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      requestStopwatch.stop();

      _redPacketPrint('RED PACKET SEND RESPONSE STATUS', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'elapsed_ms': requestStopwatch.elapsedMilliseconds,
        'status_code': response.statusCode,
        'status_message': response.statusMessage,
        'request_payload': data,
      });
      _redPacketPrint('RED PACKET SEND RESPONSE DATA', response.data);

      final body = response.data;
      final bodyMap = _redPacketMap(body);
      final dataMap = _redPacketMap(bodyMap['data']);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final redPacketData = _redPacketMap(dataMap['red_packet']);

        /// ✅ Enrich local packet immediately. Some websocket payloads may not include
        /// open_after_seconds, so keep it here too.
        if (redPacketData.isNotEmpty) {
          redPacketData['open_after_seconds'] ??= safeOpenAfter;
          redPacketData['unlock_after_seconds'] ??= safeOpenAfter;
          redPacketData['event_received_at_ms'] ??=
              DateTime.now().millisecondsSinceEpoch;
          redPacketData['is_global'] = true;

          /// ✅ Sender device should also see the global banner immediately.
          showGlobalLuckyBagBanner(redPacketData, seconds: 5);
        }

        return true;
      }

      final errorMessage = _redPacketMessageFromResponse(
        body,
        ('Failed to send Lucky Bag').appTr,
      );

      _redPacketPrint('RED PACKET SEND FAILED', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'status_code': response.statusCode,
        'status_message': response.statusMessage,
        'message': errorMessage,
        'request_payload': data,
        'response': body,
      });

      return false;
    } catch (e, stackTrace) {
      _redPacketPrint('RED PACKET SEND EXCEPTION', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });

      Fluttertoast.showToast(
        msg: ('Failed to send Lucky Bag').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      return false;
    }
  }

  void _redPacketPrint(String title, dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final text = data is String ? data : encoder.convert(data);

      liveLog('================ $title ================');

      const int chunkSize = 900;
      for (int i = 0; i < text.length; i += chunkSize) {
        final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
        liveLog(text.substring(i, end));
      }

      liveLog('================ END $title ================');
    } catch (e) {
      liveLog('$title print error: $e');
      liveLog(data.toString());
    }
  }

  /// Collect Lucky Bag and return full response data for UI popup.
  Future<Map<String, dynamic>?> collectRedPacketData(int redPacketId) async {
    if (redPacketId <= 0) {
      _redPacketPrint('RED PACKET COLLECT INVALID ID', {
        'red_packet_id': redPacketId,
      });

      return null;
    }

    try {
      final String url = kCollectRedPacketUrl(redPacketId);

      _redPacketPrint('RED PACKET COLLECT REQUEST', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'url': url,
        'red_packet_id': redPacketId,
        'controller_stream_id': currentLivestreamId,
        'current_red_packet':
        _currentRoomPacketSnapshot(),
        'global_lucky_bag_data':
        Map<String, dynamic>.from(globalLuckyBagData),
      });

      final Stopwatch collectStopwatch = Stopwatch()..start();

      final response = await dio.post(
        url,
        data: <String, dynamic>{},
        options: Options(
          headers: _redPacketHeaders(),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      collectStopwatch.stop();

      _redPacketPrint('RED PACKET COLLECT RESPONSE STATUS', {
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'elapsed_ms': collectStopwatch.elapsedMilliseconds,
        'red_packet_id': redPacketId,
        'statusCode': response.statusCode,
        'statusMessage': response.statusMessage,
      });

      _redPacketPrint('RED PACKET COLLECT RESPONSE DATA', response.data);

      final body = response.data;
      final bodyMap = _redPacketMap(body);
      final dataMap = _redPacketMap(bodyMap['data']);
      final redPacketMap = _redPacketMap(
        dataMap['red_packet'] ??
            bodyMap['red_packet'] ??
            dataMap['packet'] ??
            bodyMap['packet'],
      );
      final collectionMap = _redPacketMap(
        dataMap['collection'] ??
            bodyMap['collection'] ??
            dataMap['my_collection'] ??
            bodyMap['my_collection'],
      );

      final normalizedCollectData = _normalizeRedPacketCollectData(
        bodyMap,
        dataMap,
        redPacketMap,
        collectionMap,
      );

      _redPacketPrint('RED PACKET COLLECT NORMALIZED DATA', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'red_packet_id': redPacketId,
        'body_map': bodyMap,
        'data_map': dataMap,
        'red_packet_map': redPacketMap,
        'collection_map': collectionMap,
        'normalized_collect_data': normalizedCollectData,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _syncRedPacketBalance(
          normalizedCollectData['user_balance'] ?? bodyMap['user_balance'],
        );
        _syncRedPacketAfterCollect(normalizedCollectData);

        return normalizedCollectData;
      }

      final String errorMessage = _redPacketMessageFromResponse(
        body,
        ('Lucky Bag collect failed').appTr,
      );

      /// ✅ Backend may return 409/422 with "already collected" even though it
      /// includes this user's collection amount. Treat it as a successful UI
      /// result so OPEN shows the received coin card instead of only a toast.
      if (_redPacketAlreadyCollectedResponse(
        errorMessage,
        bodyMap,
        dataMap,
        redPacketMap,
        collectionMap,
      )) {
        Map<String, dynamic> alreadyCollectData = normalizedCollectData;

        /// Some backends return only {message: already collected}. In that case
        /// hydrate the packet from the room list and recover my collection amount.
        if (_redPacketInt(alreadyCollectData['collected_amount']) <= 0) {
          final int liveId = _redPacketInt(
            redPacketMap['livestream_id'] ??
                dataMap['livestream_id'] ??
                bodyMap['livestream_id'] ??
                _currentRoomPacketSnapshot()['livestream_id'] ??
                globalLuckyBagData['livestream_id'] ??
                currentLivestreamId,
          );

          if (liveId > 0) {
            final packets = await getLivestreamRedPackets(
              livestreamId: liveId,
              status: 'all',
              perPage: 30,
            );
            final latestPacket = packets.firstWhere(
                  (packet) =>
              _redPacketInt(packet['id'] ?? packet['red_packet_id']) ==
                  redPacketId,
              orElse: () => <String, dynamic>{},
            );
            if (latestPacket.isNotEmpty) {
              final myCollection = _redPacketMyCollectionFromPacket(
                latestPacket,
              );
              alreadyCollectData = _normalizeRedPacketCollectData(
                bodyMap,
                <String, dynamic>{...dataMap, 'red_packet': latestPacket},
                latestPacket,
                myCollection,
              );
            }
          }
        }

        if (_redPacketInt(alreadyCollectData['collected_amount']) <= 0) {
          final cachedAmount = _redPacketMyAmountCache[redPacketId] ?? 0;
          if (cachedAmount > 0) {
            alreadyCollectData = <String, dynamic>{
              ...alreadyCollectData,
              'collected_amount': cachedAmount,
              'amount_collected': cachedAmount,
              'my_collection_amount': cachedAmount,
              'collection': {
                ..._redPacketMap(alreadyCollectData['collection']),
                'user_id': authController.userProfile.value.user?.id,
                'amount_collected': cachedAmount,
              },
            };
          } else {
            // Backend only says already collected but does not return the amount
            // and the list API also hides my collection. Do not show 0 coins;
            // UI will display "Already collected / Collected" instead.
            alreadyCollectData = <String, dynamic>{
              ...alreadyCollectData,
              'already_collected_without_amount': true,
              'red_packet': {
                ..._redPacketMap(alreadyCollectData['red_packet']),
                if (_redPacketMap(alreadyCollectData['red_packet']).isEmpty)
                  ..._redPacketMap(_currentRoomPacketSnapshot()),
                'id': redPacketId,
                'collected_by_me': true,
                'can_collect': false,
                'already_collected_without_amount': true,
              },
            };
          }
        }

        _syncRedPacketBalance(
          alreadyCollectData['user_balance'] ?? bodyMap['user_balance'],
        );
        _syncRedPacketAfterCollect(alreadyCollectData);

        return alreadyCollectData;
      }

      _redPacketPrint('RED PACKET COLLECT FAILED', {
        'red_packet_id': redPacketId,
        'statusCode': response.statusCode,
        'message': errorMessage,
        'body': body,
      });

      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    } catch (e, stackTrace) {
      _redPacketPrint('RED PACKET COLLECT EXCEPTION', {
        'red_packet_id': redPacketId,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });

      Fluttertoast.showToast(
        msg: ('Lucky Bag collect failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return null;
    }
  }

  /// Backward compatible bool method.
  Future<bool> collectRedPacket(String redPacketId) async {
    final int id = _redPacketInt(redPacketId);
    final data = await collectRedPacketData(id);
    return data != null;
  }

  Future<List<Map<String, dynamic>>> getLivestreamRedPackets({
    required int livestreamId,
    String status = 'active',
    int perPage = 20,
  }) async {
    if (livestreamId <= 0) return <Map<String, dynamic>>[];

    try {
      final String url = kGetRedPacketsForLivestreamUrl(livestreamId);

      _redPacketPrint('RED PACKET LIVESTREAM LIST REQUEST', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'url': url,
        'livestream_id': livestreamId,
        'status': status,
        'per_page': perPage,
      });

      final Stopwatch listStopwatch = Stopwatch()..start();

      final response = await dio.get(
        url,
        queryParameters: {
          if (status.trim().isNotEmpty && status != 'all') 'status': status,
          'per_page': perPage,
        },
        options: Options(
          headers: _redPacketHeaders(),
          validateStatus: (code) => code != null && code < 500,
        ),
      );

      listStopwatch.stop();

      _redPacketPrint('RED PACKET LIVESTREAM LIST RAW RESPONSE', <String, dynamic>{
        'local_time': DateTime.now().toIso8601String(),
        'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
        'elapsed_ms': listStopwatch.elapsedMilliseconds,
        'status_code': response.statusCode,
        'status_message': response.statusMessage,
        'livestream_id': livestreamId,
        'requested_status': status,
        'response': response.data,
      });

      final body = _redPacketMap(response.data);
      final data = body['data'];

      if (data is List) {
        final list = data.whereType<Map>().map((e) {
          final item = Map<String, dynamic>.from(e);
          final int serverUnlockSeconds = _redPacketInt(
            item['unlock_after_seconds'] ??
                item['open_after_seconds'] ??
                item['unlock_after'] ??
                item['open_after'],
          );
          final int safeOpenAfter = serverUnlockSeconds > 0
              ? serverUnlockSeconds
              : 30;
          item['open_after_seconds'] ??= safeOpenAfter;
          item['unlock_after_seconds'] ??= safeOpenAfter;
          item['event_received_at_ms'] ??=
              DateTime.now().millisecondsSinceEpoch;
          return item;
        }).toList();
        _redPacketPrint('RED PACKET LIVESTREAM LIST RESPONSE', {
          'livestream_id': livestreamId,
          'status': status,
          'count': list.length,
          'items': list,
        });
        return list;
      }

      if (data is Map && data['data'] is List) {
        final list = (data['data'] as List).whereType<Map>().map((e) {
          final item = Map<String, dynamic>.from(e);
          final int serverUnlockSeconds = _redPacketInt(
            item['unlock_after_seconds'] ??
                item['open_after_seconds'] ??
                item['unlock_after'] ??
                item['open_after'],
          );
          final int safeOpenAfter = serverUnlockSeconds > 0
              ? serverUnlockSeconds
              : 30;
          item['open_after_seconds'] ??= safeOpenAfter;
          item['unlock_after_seconds'] ??= safeOpenAfter;
          item['event_received_at_ms'] ??=
              DateTime.now().millisecondsSinceEpoch;
          return item;
        }).toList();
        _redPacketPrint('RED PACKET LIVESTREAM PAGINATED LIST RESPONSE', {
          'livestream_id': livestreamId,
          'status': status,
          'count': list.length,
          'items': list,
        });
        return list;
      }
    } catch (e) {
      liveLog('❌ getLivestreamRedPackets error => $e');
    }

    return <Map<String, dynamic>>[];
  }


  /// Called by LivestreamController when its lifecycle closes.
  void disposeRedPacketState() {
    _globalLuckyBagBannerTimer?.cancel();
    _globalLuckyBagBannerTimer = null;
    globalLuckyBagBannerVisible.value = false;
    globalLuckyBagBannerSeconds.value = 0;
    globalLuckyBagData.clear();
    _redPacketMyAmountCache.clear();
  }

  @override
  void onClose() {
    disposeRedPacketState();
    super.onClose();
  }
}
