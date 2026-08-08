import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../../../../apis/api_endpoints.dart';
import '../../auth/controllers/auth_controller.dart';

class FruitGameController extends GetxController {
  final authController = Get.find<AuthController>();
  final Dio _dio = Dio();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _spinPlayer = AudioPlayer();
  final isMusicOn = true.obs;
// Sound toggle — UI থেকে call হবে
  void toggleSound() {
    isMusicOn.value = !isMusicOn.value;
    if (isMusicOn.value) {
      playBgm();
    } else {
      stopBgm();
      stopSpinSound();
    }
  }

// এই দুটো alias রাখো যাতে পুরনো call break না করে
  void stopBackgroundAudio() => stopBgm();
  void stopCoinsAudio() => stopSpinSound();
  void playBackgroundAudio() => playBgm();
  // অডিও মিক্সিং সেটআপ
  Future<void> _setupAudioContext() async {
    await AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none, // এটি আগের সাউন্ড বন্ধ হতে দেবে না
      ),
    ));
  }

  // ব্যাকগ্রাউন্ড মিউজিক প্লে
  void playBgm() async {
    if (!isMusicOn.value) return;
    if (_bgmPlayer.state == PlayerState.playing) return;

    await _setupAudioContext(); // মিক্সিং সেটআপ কল করুন

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('game/bgsoundfrash.mp3'), volume: 0.4);
    } catch (e) {
      print("BGM Error: $e");
    }
  }

  void stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      print("Stop BGM Error: $e");
    }
  }

  // স্পিন সাউন্ড প্লে
  void playSpinSound() async {
    if (!isMusicOn.value) return;
    // স্পিন সাউন্ড শুরু করার আগে বিজিএম বন্ধ করবেন না
    try {
      await _spinPlayer.setReleaseMode(ReleaseMode.loop);
      await _spinPlayer.play(AssetSource('game/spinsound.mp3'), volume: 0.6);
    } catch (e) {
      print("Spin Sound Error: $e");
    }
  }

  void stopSpinSound() async {
    try {
      await _spinPlayer.stop();
    } catch (e) {
      print("Stop Spin Sound Error: $e");
    }
  }

  // Observable properties for reactive UI
  final isLoading = false.obs;
  final remainingTime = 0.obs;
  final winnerNumber = 0.obs;
  final amount1 = 0.obs;
  final amount2 = 0.obs;
  final amount3 = 0.obs;

  // Winner trend data
  final winnerTrend = [].obs;

  // Active users in the game
  final activeUsers = [].obs;

  // Single WebSocket channel for all communications
  IOWebSocketChannel? webSocketChannel;

  // ✅ 25s professional round config
  static const int gameRoundSeconds = 25;
  Timer? _reconnectTimer;
  bool _isConnectingSocket = false;
  bool _isSocketClosedManually = false;

  int _normalizeTimerValue(int raw) {
    if (raw < 0) return 0;

    // Backend old format may send 50 for a 25s round.
    // Frontend stays 1s = 1s by normalizing 26..50 into 13..25.
    if (raw > gameRoundSeconds && raw <= gameRoundSeconds * 2) {
      return (raw / 2).ceil().clamp(0, gameRoundSeconds).toInt();
    }

    if (raw > gameRoundSeconds * 2) return gameRoundSeconds;

    return raw.clamp(0, gameRoundSeconds).toInt();
  }

  void _updateRemainingTime(int rawTime) {
    final int normalized = _normalizeTimerValue(rawTime);
    if (remainingTime.value == normalized) return;

    remainingTime.value = normalized;
    debugPrint('FruitGame timer normalized: raw=$rawTime => $normalized');
  }

  // Initialize single WebSocket connection for all fruit game communications
  initWebSocketConnection() async {
    if (_isConnectingSocket) {
      debugPrint('FruitGame WebSocket connect skipped: already connecting');
      return;
    }

    _isConnectingSocket = true;
    _isSocketClosedManually = false;
    _reconnectTimer?.cancel();

    try {
      try {
        await webSocketChannel?.sink.close(status.normalClosure);
      } catch (_) {}

      webSocketChannel = IOWebSocketChannel.connect(Uri.parse(kWsUrl));
      debugPrint('FruitGame WebSocket connected');

      webSocketChannel!.stream.listen(
            (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) async {
          debugPrint('FruitGame WebSocket error: $error');
          await _scheduleReconnect();
        },
        onDone: () async {
          debugPrint('FruitGame WebSocket closed');
          await _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _subscribeToChannels();
    } catch (e) {
      debugPrint('Error connecting to fruit game WebSocket: $e');
      await _scheduleReconnect();
    } finally {
      _isConnectingSocket = false;
    }
  }

  Future<void> _scheduleReconnect() async {
    if (_isSocketClosedManually || isClosed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_isSocketClosedManually || isClosed) return;
      initWebSocketConnection();
    });
  }


  // Handle incoming WebSocket messages
  // Utility to decode inner payloads that may arrive as JSON strings
  dynamic _decodePayload(dynamic payload) {
    if (payload is String) {
      try {
        return jsonDecode(payload);
      } catch (e) {
        debugPrint('FruitGame payload decode error: $e');
        return payload;
      }
    }
    return payload;
  }

  void _handleWebSocketMessage(String message) {
    // Respond to ping to keep the connection alive
    if (message.toString().contains('ping')) {
      try {
        webSocketChannel?.sink.add(jsonEncode({"event": "pusher:pong"}));
        debugPrint('FruitGame pong sent');
      } catch (e) {
        debugPrint('Error sending pong: $e');
      }
      return;
    }
    try {
      dynamic data = jsonDecode(message);
      if (data != null && data.containsKey('data')) {
        final String? event = data['event'];
        final String? channel = data['channel'];

        // Handle Pusher/Reverb system events quietly
        if (event == 'pusher:connection_established' ||
            event == 'pusher_internal:subscription_succeeded' ||
            event == 'pusher:subscription_succeeded') {
          debugPrint(
              'FruitGame system event: $event on channel: ${channel ?? 'n/a'}');
          return; // Don't route system events further
        }

        final dynamic payload = _decodePayload(data['data']);
        // print('Sagor $payload');
        if (channel != null) {
          _handleChannelMessage(channel, event, payload);
        } else {
          // Handle general messages that might not have channel info
          _handleGeneralMessage(event, payload);
        }
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  // Handle general messages (fallback for messages without channel info)
  // Utility: parse dynamic numeric into int safely
  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final v = int.tryParse(value) ?? double.tryParse(value)?.round();
      return v;
    }
    return null;
  }

  void _sortActiveUsersSafely() {
    try {
      activeUsers.sort((a, b) {
        final int ac = _toInt(a is Map ? a['coins'] : 0) ?? 0;
        final int bc = _toInt(b is Map ? b['coins'] : 0) ?? 0;
        return bc.compareTo(ac);
      });
    } catch (_) {}
  }


  void _handleGeneralMessage(String? event, dynamic payload) {
    final decoded = _decodePayload(payload);
    if (event == 'game.timer') {
      if (decoded is Map) {
        int? t;
        // New: robust nested parsing to support {data: {data: {data: {time}}}} as well
        if (decoded.containsKey('data')) {
          final innerRaw = decoded['data'];
          final inner = _decodePayload(innerRaw);
          if (inner is Map) {
            if (t == null && inner.containsKey('time')) {
              t = _toInt(inner['time']);
            }
            if (t == null && inner.containsKey('data')) {
              final deeperRaw = inner['data'];
              final deeper = _decodePayload(deeperRaw);
              if (deeper is Map) {
                if (deeper.containsKey('time')) {
                  t = _toInt(deeper['time']);
                } else if (deeper.containsKey('data')) {
                  final deepestRaw = deeper['data'];
                  final deepest = _decodePayload(deepestRaw);
                  if (deepest is Map && deepest.containsKey('time')) {
                    t = _toInt(deepest['time']);
                  }
                }
              }
            }
          }
        }
        // Existing formats
        if (t == null && decoded.containsKey('remaining_time')) {
          t = _toInt(decoded['remaining_time']);
        } else if (t == null && decoded.containsKey('time')) {
          t = _toInt(decoded['time']);
        } else if (t == null && decoded.containsKey('timer')) {
          final inner = decoded['timer'];
          if (inner is Map && inner.containsKey('remaining_time')) {
            t = _toInt(inner['remaining_time']);
          }
        }
        if (t != null) {
          _updateRemainingTime(t);
          debugPrint('FruitGame general timer update: ${remainingTime.value}');
        } else {
          debugPrint('FruitGame general timer payload missing time: $decoded');
        }
      } else {
        debugPrint('FruitGame general timer payload malformed: $decoded');
      }
    } else if (event != null &&
        !(event.startsWith('pusher') || event.startsWith('pusher_internal'))) {
      // Route other known events to action handler
      _handleActionMessage(event, decoded);
    } else if (decoded is List) {
      activeUsers.clear();
      activeUsers.addAll(decoded);
      _sortActiveUsersSafely();
      debugPrint('FruitGame activeUsers updated: ${activeUsers.length} users');
    }
  }

  // Handle fruit-game channel messages (timer)
  void _handleFruitGameMessage(String? event, dynamic payload) {
    if (event == null) return;
    switch (event) {
      case 'game.timer':
        final decoded = _decodePayload(payload);
        if (decoded is Map) {
          int? t;
          // New: robust nested parsing to support {data: {data: {data: {time}}}} as well
          if (decoded.containsKey('data')) {
            final innerRaw = decoded['data'];
            final inner = _decodePayload(innerRaw);
            if (inner is Map) {
              if (t == null && inner.containsKey('time')) {
                t = _toInt(inner['time']);
              }
              if (t == null && inner.containsKey('data')) {
                final deeperRaw = inner['data'];
                final deeper = _decodePayload(deeperRaw);
                if (deeper is Map) {
                  if (deeper.containsKey('time')) {
                    t = _toInt(deeper['time']);
                  } else if (deeper.containsKey('data')) {
                    final deepestRaw = deeper['data'];
                    final deepest = _decodePayload(deepestRaw);
                    if (deepest is Map && deepest.containsKey('time')) {
                      t = _toInt(deepest['time']);
                    }
                  }
                }
              }
            }
          }
          // Existing formats
          if (t == null && decoded.containsKey('remaining_time')) {
            t = _toInt(decoded['remaining_time']);
          } else if (t == null && decoded.containsKey('time')) {
            t = _toInt(decoded['time']);
          } else if (t == null && decoded.containsKey('timer')) {
            final inner = decoded['timer'];
            if (inner is Map && inner.containsKey('remaining_time')) {
              t = _toInt(inner['remaining_time']);
            }
          }
          if (t != null) {
            _updateRemainingTime(t);
            // debugPrint('FruitGame timer update: ${remainingTime.value}');
          } else {
            debugPrint('FruitGame timer payload missing time: $decoded');
          }
        } else {
          debugPrint('FruitGame timer payload malformed: $decoded');
        }
        break;
      default:
        debugPrint('Unknown fruit-game event: $event');
    }
  }

  // Handle action-specific messages based on event name
  void _handleActionMessage(String eventName, dynamic data) {
    final payload = _decodePayload(data);
    // print('sagor from action socket');
    // print(payload);
    switch (eventName) {
      case "game.winner":
        print(payload);
        final int n = _toInt(payload['data']['number']) ?? 0;
        winnerNumber.value = n;
        debugPrint('FruitGame winner update: $n');

        break;
      case "game.total":
      // print('from game total $payload');
        final decoded = _decodePayload(payload);
        if (decoded is Map) {
          // Try to unwrap nested 'data' up to 3 levels to reach totals
          dynamic current = decoded;
          Map<String, dynamic>? totals;
          for (int i = 0; i < 3; i++) {
            if (current is Map &&
                (current.containsKey('totalAmount1') ||
                    current.containsKey('totalAmount2') ||
                    current.containsKey('totalAmount3'))) {
              totals = Map<String, dynamic>.from(current);
              break;
            }
            if (current is Map && current.containsKey('data')) {
              final nextRaw = current['data'];
              current = _decodePayload(nextRaw);
            } else {
              break;
            }
          }
          totals ??=
          (decoded is Map) ? Map<String, dynamic>.from(decoded) : null;
          if (totals != null) {
            final a1 = _toInt(totals['totalAmount1']);
            final a2 = _toInt(totals['totalAmount2']);
            final a3 = _toInt(totals['totalAmount3']);
            if (a1 != null) amount1.value = a1;
            if (a2 != null) amount2.value = a2;
            if (a3 != null) amount3.value = a3;
            debugPrint(
                'FruitGame totals: A1=${amount1.value}, A2=${amount2.value}, A3=${amount3.value}');
          } else {
            debugPrint(
                'FruitGame game.total payload did not contain totals: $decoded');
          }
        } else {
          debugPrint('FruitGame game.total payload malformed: $decoded');
        }
        break;
      case "user.joined":
        if (payload != null) {
          activeUsers.add(payload);
          try {
            _sortActiveUsersSafely();
          } catch (_) {}
          debugPrint(
              'FruitGame user joined: ${payload is Map ? (payload['uid'] ?? payload['user_name'] ?? 'unknown') : 'unknown'}');
        } else {
          debugPrint('FruitGame user.joined payload empty');
        }
        break;
      case "user.left":
        if (payload is Map && payload.containsKey('uid')) {
          activeUsers.removeWhere((user) => user['uid'] == payload['uid']);
          debugPrint('FruitGame user left: ${payload['uid']}');
        } else {
          debugPrint('FruitGame user.left payload malformed: $payload');
        }
        break;
      default:
        debugPrint('Unknown event: $eventName');
    }
  }

  // Handle users channel messages
  void _handleUsersMessage(dynamic jsonData) {
    if (jsonData['data'] != null) {
      final payload = _decodePayload(jsonData['data']);
      if (payload is List) {
        activeUsers.clear();
        activeUsers.addAll(payload);
        _sortActiveUsersSafely();
      } else if (payload is Map) {
        // Try extracting users list from known keys (presence/memberships)
        final dynamic usersList = payload['users'] ?? payload['members'];
        if (usersList is List) {
          activeUsers.clear();
          activeUsers.addAll(usersList);
          // Sort if coins info exists, otherwise keep as-is
          try {
            _sortActiveUsersSafely();
          } catch (_) {
            // Ignore sort errors for non-map items
          }
        } // else: silently ignore presence info without a list
      } // else: ignore non-supported payload types
    }
  }

  // Handle messages based on channel
  void _handleChannelMessage(String channel, String? event, dynamic payload) {
    String? localEvent = event;
    dynamic localPayload = payload;
    if (payload is Map) {
      if (payload.containsKey('event')) {
        localEvent = payload['event'];
        if (payload.containsKey('data')) {
          localPayload = payload['data'];
        }
      }
    }
    switch (channel) {
      case 'fruit-game':
        _handleFruitGameMessage(localEvent, localPayload);
        break;
      case 'fruit-game-actions':
        if (localEvent != null) {
          _handleActionMessage(localEvent, localPayload);
        } else {
          debugPrint('Invalid fruit-game-actions payload: $payload');
        }
        break;
      case 'users':
        _handleUsersMessage({'data': localPayload});
        break;
      default:
        debugPrint('Unknown channel: $channel');
    }
  }

  // Subscribe to all required channels
  void _subscribeToChannels() {
    final channels = ['fruit-game', 'fruit-game-actions', 'users'];

    for (String channel in channels) {
      debugPrint('FruitGame subscribing to channel: $channel');
      final jsonData = {
        "event": "pusher:subscribe",
        "data": {"channel": channel}
      };
      webSocketChannel?.sink.add(json.encode(jsonData));
    }
  }

  // onInit intentionally not overridden; no custom init logic needed

  @override
  void onReady() {
    initWebSocketConnection();
    // Preload status (including winner trends) so UI shows trends on open
    fetchStatus();
    playBgm();
    super.onReady();
  }

  @override
  void onClose() {
    _isSocketClosedManually = true;
    _reconnectTimer?.cancel();

    _bgmPlayer.dispose();
    _spinPlayer.dispose();

    try {
      webSocketChannel?.sink.close(status.normalClosure);
    } catch (_) {}

    activeUsers.clear();
    super.onClose();
  }


  // HTTP methods for Fruit Game API
  Future<void> joinGame({required int userId}) async {
    try {
      final response = await _dio.post(
        kFruitGameJoinUrl,
        data: {
          'user_id': userId,
          'user_name': authController.userProfile.value.user?.name,
          'profile_image': authController.userProfile.value.user?.profileImage,
          'coins': authController.userProfile.value.user?.balance,
        },
        options: Options(headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
        }),
      );
      debugPrint('Joined fruit game: ${response.data}');
    } catch (e) {
      debugPrint('joinGame error: $e');
    }
  }

  Future<void> leaveGame({required int userId}) async {
    try {
      final response = await _dio.post(
        kFruitGameLeaveUrl,
        data: {
          'user_id': userId,
        },
        options: Options(headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
        }),
      );
      debugPrint('Left fruit game: ${response.data}');
    } catch (e) {
      debugPrint('leaveGame error: $e');
    }
  }

  Future<bool> placeBet({
    required int userId,
    required int betType,
    required int amount,
  }) async {
    try {
      final response = await _dio.post(
        kFruitGameBetUrl,
        data: {
          'user_id': userId,
          'position': betType, // Backend expects 'position', not 'bet_type'
          'amount': amount,
        },
        options: Options(headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
        }),
      );

      final bool ok = response.statusCode == 200 || response.statusCode == 201;
      if (!ok) return false;

      userCurrentCoins.value -= amount;
      debugPrint('Placed bet: ${response.data}');

      // Fallback: fetch status to ensure totals update even if websocket message is delayed/missed.
      // Small delay keeps UI smooth and avoids racing with websocket broadcast.
      Future.delayed(const Duration(milliseconds: 250), fetchStatus);
      return true;
    } catch (e) {
      if (e is DioException) {
        debugPrint(
            'placeBet error: status=${e.response?.statusCode}, data=${e.response?.data}, url=${e.requestOptions.uri}');
      } else {
        debugPrint('placeBet error: $e');
      }
      return false;
    }
  }

  Future<void> fetchStatus() async {
    try {
      final response = await _dio.get(
        kFruitGameStatusUrl,
        options: Options(headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
        }),
      );
      final data = response.data;
      if (data is Map) {
        final int? statusTime = _toInt(data['remaining_time']);
        if (statusTime != null) {
          _updateRemainingTime(statusTime);
        }

        amount1.value = _toInt(data['total_amount1']) ?? amount1.value;
        amount2.value = _toInt(data['total_amount2']) ?? amount2.value;
        amount3.value = _toInt(data['total_amount3']) ?? amount3.value;

        if (data['active_users'] is List) {
          activeUsers.clear();
          activeUsers.addAll(List<Map<String, dynamic>>.from(data['active_users']));
          _sortActiveUsersSafely();
        }

        if (data['winner_trend_struct'] is List) {
          winnerTrend.clear();
          winnerTrend.addAll(
              List<Map<String, dynamic>>.from(data['winner_trend_struct']));
        } else if (data['winner_trend'] is List) {
          final structured =
          (data['winner_trend'] as List).map<Map<String, dynamic>>((pos) {
            try {
              final p = pos is int ? pos : int.tryParse(pos.toString()) ?? 0;
              return {
                'field1': p == 1 ? 'Win' : '-',
                'field2': p == 2 ? 'Win' : '-',
                'field3': p == 3 ? 'Win' : '-',
              };
            } catch (_) {
              return {'field1': '-', 'field2': '-', 'field3': '-'};
            }
          }).toList();
          winnerTrend.clear();
          winnerTrend.addAll(structured);
        }
      }
    } catch (e) {
      debugPrint('fetchStatus error: $e');
    }
  }


  final userCurrentCoins = 0.obs;

  Future<void> fetchUserCoins() async {
    try {
      final response = await _dio.get(
        kUserCoinsUrl,
        options: Options(headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
        }),
      );

      final data = response.data;

      if (data is Map && data.containsKey('coins')) {
        userCurrentCoins.value = data['coins'] ?? userCurrentCoins.value;
      }
    } catch (e) {
      debugPrint('fetchStatus error: $e');
    }
  }
}
