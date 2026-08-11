import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/livestream_controller.dart';
import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import '../../../../apis/api_endpoints.dart';

/// Owns PK requests, room-local PK state, scoring, results, and countdowns.
/// Agora engine work and WebSocket routing intentionally remain with their
/// existing owners; [LivestreamController] is only a compatibility facade.
class LivePkController extends GetxController {
  LivePkController(this.owner);

  final LivestreamController owner;

  final pkModeActive = false.obs;
  final pkRequestLoading = false.obs;
  final pkWaitingForResponse = false.obs;
  final pkRequestPopupVisible = false.obs;
  final pkResultVisible = false.obs;
  final pkResultText = ''.obs;
  final pkStartIntroVisible = false.obs;
  final pkStartIntroText = 'PK START'.obs;
  final pkEndingCountdownVisible = false.obs;
  final pkEndingCountdownText = ''.obs;
  final currentPkData = <String, dynamic>{}.obs;
  final incomingPkRequest = <String, dynamic>{}.obs;
  final pkResultData = <String, dynamic>{}.obs;
  final pkSenderLiveDataState = <String, dynamic>{}.obs;
  final pkReceiverLiveDataState = <String, dynamic>{}.obs;
  final currentPkId = 0.obs;
  final pkSenderLivestreamId = 0.obs;
  final pkReceiverLivestreamId = 0.obs;
  final pkSenderHostId = 0.obs;
  final pkReceiverHostId = 0.obs;
  final pkSenderScore = 0.obs;
  final pkReceiverScore = 0.obs;
  final pkSenderViewerCount = 0.obs;
  final pkReceiverViewerCount = 0.obs;
  final pkDurationSeconds = 300.obs;
  final pkRemainingSeconds = 0.obs;
  final pkChannelName = ''.obs;
  final pkSenderRoomId = ''.obs;
  final pkReceiverRoomId = ''.obs;
  final pkAgoraJoining = false.obs;

  final Set<String> _processedGiftScoreKeys = <String>{};
  Timer? _timer;

  RxBool get pkIsRunning => pkModeActive;
  Map<String, dynamic> get pkSenderLiveData => pkSenderLiveDataState;
  Map<String, dynamic> get pkReceiverLiveData => pkReceiverLiveDataState;

  String get pkFormattedRemainingTime {
    final total = pkRemainingSeconds.value < 0 ? 0 : pkRemainingSeconds.value;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  double get pkSenderProgress {
    final total = pkSenderScore.value + pkReceiverScore.value;
    return total <= 0 ? 0.5 : pkSenderScore.value / total;
  }

  int get _userId =>
      owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
  bool get isCurrentUserPkSender =>
      _userId > 0 && _userId == pkSenderHostId.value;
  bool get isCurrentUserPkReceiver =>
      _userId > 0 && _userId == pkReceiverHostId.value;
  bool get isCurrentUserInPk =>
      isCurrentUserPkSender || isCurrentUserPkReceiver;

  bool get isPkCommentGiftActive {
    return currentPkId.value > 0 &&
        (pkModeActive.value ||
            pkSenderLivestreamId.value > 0 ||
            pkReceiverLivestreamId.value > 0);
  }

  int get currentPkOpponentLivestreamId {
    final current = _toInt(owner.streamId.value);
    if (current == pkSenderLivestreamId.value)
      return pkReceiverLivestreamId.value;
    if (current == pkReceiverLivestreamId.value)
      return pkSenderLivestreamId.value;
    if (pkReceiverLivestreamId.value > 0 &&
        pkReceiverLivestreamId.value != current) {
      return pkReceiverLivestreamId.value;
    }
    if (pkSenderLivestreamId.value > 0 &&
        pkSenderLivestreamId.value != current) {
      return pkSenderLivestreamId.value;
    }
    return 0;
  }

  Map<String, dynamic> pkCommentGiftMetaBody() {
    if (!isPkCommentGiftActive) return <String, dynamic>{};
    final current = _toInt(owner.streamId.value);
    final opponent = currentPkOpponentLivestreamId;
    return {
      'is_pk': 1,
      'pk_id': currentPkId.value,
      'pk_channel_name': pkChannelName.value,
      'pk_channel': pkChannelName.value,
      'sender_livestream_id': current,
      'receiver_livestream_id': opponent,
      'opponent_livestream_id': opponent,
      'pk_sender_livestream_id': pkSenderLivestreamId.value,
      'pk_receiver_livestream_id': pkReceiverLivestreamId.value,
      'pk_sender_host_id': pkSenderHostId.value,
      'pk_receiver_host_id': pkReceiverHostId.value,
    };
  }

  void clearPkAgoraSession() {
    pkChannelName.value = '';
    pkSenderRoomId.value = '';
    pkReceiverRoomId.value = '';
    pkAgoraJoining.value = false;
    _processedGiftScoreKeys.clear();
  }

  String _extractChannel(List<Map<String, dynamic>> maps) {
    const keys = [
      'pk_channel_name',
      'pk_channel',
      'pk_agora_channel',
      'pk_room_channel',
      'agora_channel_name',
      'channel_name',
    ];
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.startsWith('pk_') && value.split('_').length >= 4)
          return value;
      }
    }
    return '';
  }

  void syncPkStateFromLiveData(
    Map<String, dynamic> raw, {
    String source = 'initial_pk_state',
  }) {
    try {
      final root = Map<String, dynamic>.from(raw);
      final nested = _map(root['data']);
      final data = nested.isNotEmpty ? nested : root;
      final room = _map(root['pk_room'] ?? data['pk_room']);
      final sender = _map(
        root['sender_livestream'] ??
            data['sender_livestream'] ??
            root['sender_live'] ??
            data['sender_live'],
      );
      final receiver = _map(
        root['receiver_livestream'] ??
            data['receiver_livestream'] ??
            root['receiver_live'] ??
            data['receiver_live'],
      );
      final pkId = _toInt(
        root['pk_id'] ?? data['pk_id'] ?? room['pk_id'] ?? room['id'],
      );
      final looksPk =
          root['is_pk_room'] == true ||
          root['is_real_pk_room'] == true ||
          root['is_pk'] == true ||
          root['is_pk'] == 1 ||
          '${root['stream_type'] ?? data['stream_type']}'.toLowerCase() ==
              'pk' ||
          pkId > 0 ||
          sender.isNotEmpty ||
          receiver.isNotEmpty;
      if (!looksPk) return;
      currentPkId.value = pkId > 0 ? pkId : currentPkId.value;
      _setPositive(
        pkSenderLivestreamId,
        root['sender_livestream_id'] ??
            root['pk_sender_livestream_id'] ??
            data['sender_livestream_id'] ??
            data['pk_sender_livestream_id'] ??
            sender['id'],
      );
      _setPositive(
        pkReceiverLivestreamId,
        root['receiver_livestream_id'] ??
            root['pk_receiver_livestream_id'] ??
            data['receiver_livestream_id'] ??
            data['pk_receiver_livestream_id'] ??
            receiver['id'],
      );
      _setPositive(
        pkSenderHostId,
        root['sender_host_id'] ??
            root['pk_sender_host_id'] ??
            data['sender_host_id'] ??
            sender['user_id'] ??
            sender['owner_user_id'] ??
            sender['current_host_id'],
      );
      _setPositive(
        pkReceiverHostId,
        root['receiver_host_id'] ??
            root['pk_receiver_host_id'] ??
            data['receiver_host_id'] ??
            receiver['user_id'] ??
            receiver['owner_user_id'] ??
            receiver['current_host_id'],
      );
      final channel = _extractChannel([root, data, room, sender, receiver]);
      if (channel.isNotEmpty) pkChannelName.value = channel;
      pkSenderScore.value = _toInt(
        root['sender_score'] ?? data['sender_score'],
      );
      pkReceiverScore.value = _toInt(
        root['receiver_score'] ?? data['receiver_score'],
      );
      if (sender.isNotEmpty) pkSenderLiveDataState.value = sender;
      if (receiver.isNotEmpty) pkReceiverLiveDataState.value = receiver;
      currentPkData.value = {
        ...currentPkData,
        ...root,
        ...data,
        'pk_id': currentPkId.value,
        'channel_name': pkChannelName.value,
        'pk_channel_name': pkChannelName.value,
        'sender_livestream_id': pkSenderLivestreamId.value,
        'receiver_livestream_id': pkReceiverLivestreamId.value,
        'sender_host_id': pkSenderHostId.value,
        'receiver_host_id': pkReceiverHostId.value,
      };
      pkModeActive.value = true;
      pkWaitingForResponse.value = false;
      pkRequestPopupVisible.value = false;
      liveLog(
        'PK state synced [$source] => pk=${currentPkId.value} channel=${pkChannelName.value}',
      );
    } catch (e) {
      liveLog('syncPkStateFromLiveData failed [$source] => $e');
    }
  }

  void _startTimer(int duration) {
    stopPkTimer();
    pkDurationSeconds.value = duration <= 0 ? 300 : duration;
    pkRemainingSeconds.value = pkDurationSeconds.value;
    final generation = owner.roomSessionGeneration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!pkModeActive.value || generation != owner.roomSessionGeneration) {
        timer.cancel();
        return;
      }
      if (pkRemainingSeconds.value <= 0) {
        pkEndingCountdownVisible.value = false;
        timer.cancel();
        if (isCurrentUserInPk && currentPkId.value > 0)
          endPk(pkId: currentPkId.value);
        return;
      }
      pkRemainingSeconds.value--;
      final ending =
          pkRemainingSeconds.value > 0 && pkRemainingSeconds.value <= 3;
      pkEndingCountdownVisible.value = ending;
      pkEndingCountdownText.value = ending ? '${pkRemainingSeconds.value}' : '';
    });
  }

  void stopPkTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void resetPkState({bool clearResult = true}) {
    stopPkTimer();
    pkModeActive.value = false;
    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;
    currentPkData.clear();
    incomingPkRequest.clear();
    pkSenderLiveDataState.clear();
    pkReceiverLiveDataState.clear();
    for (final value in [
      currentPkId,
      pkSenderLivestreamId,
      pkReceiverLivestreamId,
      pkSenderHostId,
      pkReceiverHostId,
      pkSenderScore,
      pkReceiverScore,
      pkSenderViewerCount,
      pkReceiverViewerCount,
      pkRemainingSeconds,
    ]) {
      value.value = 0;
    }
    _processedGiftScoreKeys.clear();
    pkDurationSeconds.value = 300;
    pkStartIntroVisible.value = false;
    pkEndingCountdownVisible.value = false;
    pkEndingCountdownText.value = '';
    clearPkAgoraSession();
    if (clearResult) {
      pkResultVisible.value = false;
      pkResultText.value = '';
      pkResultData.clear();
    }
    owner.update();
  }

  Future<bool> sendPkRequest({
    required int senderLivestreamId,
    required int receiverLivestreamId,
    required int senderHostId,
    required int receiverHostId,
    Map<String, dynamic>? receiverLiveData,
  }) async {
    if (pkRequestLoading.value) return false;
    if ([
      senderLivestreamId,
      receiverLivestreamId,
      senderHostId,
      receiverHostId,
    ].any((id) => id <= 0)) {
      Fluttertoast.showToast(msg: ('PK data missing').appTr);
      return false;
    }
    final generation = owner.roomSessionGeneration;
    try {
      pkRequestLoading.value = true;
      if (receiverLiveData != null)
        pkReceiverLiveDataState.value = Map<String, dynamic>.from(
          receiverLiveData,
        );
      final response = await owner.dio.post(
        '$kMainUrl/pk/request',
        data: {
          'sender_livestream_id': senderLivestreamId,
          'receiver_livestream_id': receiverLivestreamId,
          'sender_host_id': senderHostId,
          'receiver_host_id': receiverHostId,
        },
        options: _options(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (generation != owner.roomSessionGeneration) return true;
        pkWaitingForResponse.value = true;
        final data = _map(response.data is Map ? response.data['data'] : null);
        if (data.isNotEmpty) {
          currentPkId.value = _toInt(data['id']);
          _setPositive(pkSenderLivestreamId, data['sender_livestream_id']);
          _setPositive(pkReceiverLivestreamId, data['receiver_livestream_id']);
          _setPositive(pkSenderHostId, data['sender_host_id']);
          _setPositive(pkReceiverHostId, data['receiver_host_id']);
          final channel = _extractChannel([data]);
          if (channel.isNotEmpty) pkChannelName.value = channel;
          currentPkData.value = data;
        }
        Fluttertoast.showToast(msg: ('PK request sent').appTr);
        return true;
      }
      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? '${response.data['message']}'
            : ('PK request failed').appTr,
      );
      return false;
    } catch (e) {
      liveLog('sendPkRequest error: $e');
      Fluttertoast.showToast(msg: ('PK request failed').appTr);
      return false;
    } finally {
      if (generation == owner.roomSessionGeneration)
        pkRequestLoading.value = false;
    }
  }

  Future<bool> respondPkRequest({
    required int pkId,
    required int receiverHostId,
    required String responseText,
  }) async {
    if (pkId <= 0 || receiverHostId <= 0) {
      Fluttertoast.showToast(msg: ('PK request data missing').appTr);
      return false;
    }
    final generation = owner.roomSessionGeneration;
    try {
      final response = await owner.dio.post(
        '$kMainUrl/pk/respond',
        data: {
          'pk_id': pkId,
          'receiver_host_id': receiverHostId,
          'response': responseText,
        },
        options: _options(),
      );
      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success && generation == owner.roomSessionGeneration) {
        pkRequestPopupVisible.value = false;
        incomingPkRequest.clear();
      }
      if (!success)
        Fluttertoast.showToast(
          msg: response.data is Map && response.data['message'] != null
              ? '${response.data['message']}'
              : ('PK response failed').appTr,
        );
      return success;
    } catch (_) {
      Fluttertoast.showToast(msg: ('PK response failed').appTr);
      return false;
    }
  }

  Future<bool> endPk({int? pkId}) async {
    final target = pkId ?? currentPkId.value;
    if (target <= 0) return false;
    try {
      final response = await owner.dio.post(
        '$kMainUrl/pk/end/$target',
        options: _options(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      liveLog('endPk error: $e');
      return false;
    }
  }

  void handlePkRequestReceived(Map<String, dynamic> payload) {
    incomingPkRequest.value = Map.from(payload);
    _hydrateIds(payload);
    pkRequestPopupVisible.value = true;
  }

  void handlePkRequestSent(Map<String, dynamic> payload) {
    _hydrateIds(payload);
    pkWaitingForResponse.value = true;
  }

  void _hydrateIds(Map<String, dynamic> payload) {
    final data = _map(payload['data']);
    _setPositive(currentPkId, payload['pk_id'] ?? data['id']);
    _setPositive(
      pkSenderLivestreamId,
      payload['from_livestream_id'] ??
          payload['livestream_id'] ??
          payload['sender_livestream_id'] ??
          data['sender_livestream_id'],
    );
    _setPositive(
      pkReceiverLivestreamId,
      payload['to_livestream_id'] ??
          payload['receiver_livestream_id'] ??
          data['receiver_livestream_id'],
    );
    _setPositive(
      pkSenderHostId,
      payload['from_host_id'] ??
          payload['sender_host_id'] ??
          data['sender_host_id'],
    );
    _setPositive(
      pkReceiverHostId,
      payload['to_host_id'] ??
          payload['receiver_host_id'] ??
          data['receiver_host_id'],
    );
  }

  void handlePkStarted(Map<String, dynamic> payload) {
    final nested = _map(payload['data']);
    final data = nested.isNotEmpty ? nested : payload;
    _hydrateIds({...data, ...payload});
    pkSenderScore.value = _toInt(
      payload['sender_score'] ?? data['sender_score'],
    );
    pkReceiverScore.value = _toInt(
      payload['receiver_score'] ?? data['receiver_score'],
    );
    final sender = _map(
      data['sender_livestream'] ?? payload['sender_livestream'],
    );
    final receiver = _map(
      data['receiver_livestream'] ?? payload['receiver_livestream'],
    );
    final channel = _extractChannel([payload, data, sender, receiver]);
    if (channel.isNotEmpty) pkChannelName.value = channel;
    pkSenderRoomId.value =
        '${payload['sender_room_id'] ?? data['sender_room_id'] ?? ''}';
    pkReceiverRoomId.value =
        '${payload['receiver_room_id'] ?? data['receiver_room_id'] ?? ''}';
    if (sender.isNotEmpty) pkSenderLiveDataState.value = sender;
    if (receiver.isNotEmpty) pkReceiverLiveDataState.value = receiver;
    currentPkData.value = {
      ...nested,
      ...payload,
      'channel_name': pkChannelName.value,
      'pk_channel_name': pkChannelName.value,
    };
    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;
    pkResultVisible.value = false;
    pkModeActive.value = true;
    pkStartIntroVisible.value = true;
    final generation = owner.roomSessionGeneration;
    Future.delayed(const Duration(seconds: 2), () {
      if (generation == owner.roomSessionGeneration)
        pkStartIntroVisible.value = false;
    });
    _startTimer(
      _toInt(payload['duration_seconds'] ?? data['duration_seconds']),
    );
  }

  void handlePkScoreUpdated(Map<String, dynamic> payload) {
    final nested = _map(payload['data']);
    final data = nested.isNotEmpty
        ? {...payload, ...nested}
        : Map<String, dynamic>.from(payload);
    final gift = _map(
      payload['gift'] ??
          payload['gift_data'] ??
          payload['gift_info'] ??
          payload['asset'],
    );
    _setPositive(currentPkId, data['pk_id'] ?? data['id']);
    final hasSender =
        data.containsKey('sender_score') ||
        data.containsKey('pk_sender_score') ||
        data.containsKey('sender_total_score');
    final hasReceiver =
        data.containsKey('receiver_score') ||
        data.containsKey('pk_receiver_score') ||
        data.containsKey('receiver_total_score');
    if (hasSender || hasReceiver) {
      final sender = _toInt(
        data['sender_score'] ??
            data['pk_sender_score'] ??
            data['sender_total_score'] ??
            pkSenderScore.value,
      );
      final receiver = _toInt(
        data['receiver_score'] ??
            data['pk_receiver_score'] ??
            data['receiver_total_score'] ??
            pkReceiverScore.value,
      );
      if (!(sender == 0 &&
          receiver == 0 &&
          pkSenderScore.value + pkReceiverScore.value > 0)) {
        pkSenderScore.value = sender;
        pkReceiverScore.value = receiver;
      }
      return;
    }
    final coin = _toInt(
      data['gift_coin'] ??
          data['gift_coins'] ??
          data['gift_price'] ??
          data['price'] ??
          data['coin'] ??
          data['coins'] ??
          data['amount'] ??
          data['diamond'] ??
          gift['gift_coin'] ??
          gift['coin'] ??
          gift['price'],
    );
    if (coin <= 0) return;
    final eventKey =
        '${data['event_id'] ?? data['gift_event_id'] ?? data['gift_log_id'] ?? data['transaction_id'] ?? data['id'] ?? ''}'
            .trim();
    if (eventKey.isNotEmpty) {
      final key = 'pk_${currentPkId.value}_$eventKey';
      if (!_processedGiftScoreKeys.add(key)) return;
      if (_processedGiftScoreKeys.length > 120)
        _processedGiftScoreKeys.remove(_processedGiftScoreKeys.first);
    }
    final receiverId = _toInt(
      data['receiver_id'] ??
          data['to_user_id'] ??
          data['receiver_user_id'] ??
          data['host_id'] ??
          _map(data['receiver'])['id'],
    );
    final eventStream = _toInt(
      data['livestream_id'] ??
          data['stream_id'] ??
          data['receiver_livestream_id'],
    );
    final side = '${data['pk_side'] ?? data['side'] ?? ''}'.toLowerCase();
    final senderSide =
        side == 'sender' ||
        side == 'left' ||
        receiverId == pkSenderHostId.value ||
        eventStream == pkSenderLivestreamId.value;
    final receiverSide =
        side == 'receiver' ||
        side == 'right' ||
        receiverId == pkReceiverHostId.value ||
        eventStream == pkReceiverLivestreamId.value;
    if (senderSide && !receiverSide) {
      pkSenderScore.value += coin;
    } else if (receiverSide && !senderSide) {
      pkReceiverScore.value += coin;
    } else if (_toInt(owner.streamId.value) == pkSenderLivestreamId.value) {
      pkSenderScore.value += coin;
    } else if (_toInt(owner.streamId.value) == pkReceiverLivestreamId.value) {
      pkReceiverScore.value += coin;
    }
  }

  void updatePkViewerCountFromEvent(Map<String, dynamic> payload) {
    final nested = _map(payload['data']);
    final data = nested.isNotEmpty ? nested : payload;
    final stream = _toInt(
      data['livestream_id'] ??
          data['stream_id'] ??
          data['live_stream_id'] ??
          data['room_id'],
    );
    if (stream <= 0) return;
    var count = _toInt(
      data['viewer_count'] ??
          data['livestream_viewers_count'] ??
          data['total_viewers'] ??
          data['count'],
    );
    if (count <= 0 && stream == _toInt(owner.streamId.value))
      count = owner.liveViewerList.length;
    if (stream == pkSenderLivestreamId.value) pkSenderViewerCount.value = count;
    if (stream == pkReceiverLivestreamId.value)
      pkReceiverViewerCount.value = count;
    owner.update();
  }

  void handlePkRejected(Map<String, dynamic> payload) {
    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;
    incomingPkRequest.clear();
    Fluttertoast.showToast(
      msg: payload['message']?.toString() ?? ('PK request rejected').appTr,
    );
  }

  void _applyResult(Map<String, dynamic> payload, String source) {
    final nested = _map(payload['data']);
    dynamic pick(String key) => payload[key] ?? nested[key];
    final mine = _toInt(owner.streamId.value);
    final senderStream = _toInt(pick('sender_livestream_id'));
    final receiverStream = _toInt(pick('receiver_livestream_id'));
    final senderScore = _toInt(pick('sender_score'));
    final receiverScore = _toInt(pick('receiver_score'));
    var winner = _toInt(pick('winner_livestream_id'));
    var loser = _toInt(pick('loser_livestream_id'));
    final result = '${pick('result') ?? ''}'.toLowerCase();
    var draw =
        pick('is_draw') == true ||
        '${pick('is_draw')}' == '1' ||
        result == 'draw';
    if (!draw && winner == 0) {
      if (result == 'sender_win' || senderScore > receiverScore) {
        winner = senderStream;
        loser = receiverStream;
      } else if (result == 'receiver_win' || receiverScore > senderScore) {
        winner = receiverStream;
        loser = senderStream;
      } else {
        draw = true;
      }
    }
    final text = draw
        ? 'DRAW'
        : winner == mine
        ? 'WIN'
        : 'LOSS';
    pkResultText.value = text;
    pkResultVisible.value = true;
    pkResultData.assignAll({
      ...payload,
      'sender_livestream_id': senderStream,
      'receiver_livestream_id': receiverStream,
      'sender_score': senderScore,
      'receiver_score': receiverScore,
      'winner_livestream_id': winner,
      'loser_livestream_id': loser,
      'is_draw': draw ? 1 : 0,
      'result_text': text,
      'source': source,
    });
    owner.update();
  }

  void handlePkResultPreview(
    Map<String, dynamic> payload, {
    bool isEnded = false,
  }) {
    final nested = _map(payload['data']);
    _applyResult({...nested, ...payload}, isEnded ? 'ended' : 'preview');
    final generation = owner.roomSessionGeneration;
    Future.delayed(Duration(seconds: isEnded ? 5 : 4), () {
      if (generation == owner.roomSessionGeneration)
        pkResultVisible.value = false;
    });
  }

  void handlePkEnded(Map<String, dynamic> payload) {
    final nested = _map(payload['data']);
    _applyResult({...nested, ...payload}, 'ended');
    resetPkState(clearResult: false);
    final generation = owner.roomSessionGeneration;
    Future.delayed(const Duration(seconds: 5), () {
      if (generation == owner.roomSessionGeneration) {
        pkResultVisible.value = false;
        pkResultText.value = '';
        pkResultData.clear();
        owner.update();
      }
    });
  }

  Options _options() => Options(
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${owner.authController.userProfile.value.token}',
    },
    validateStatus: (_) => true,
  );
  Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};
  int _toInt(dynamic value) => value is int
      ? value
      : value is double
      ? value.toInt()
      : int.tryParse('${value ?? 0}') ?? 0;
  void _setPositive(RxInt target, dynamic value) {
    final parsed = _toInt(value);
    if (parsed > 0) target.value = parsed;
  }

  @override
  void onClose() {
    stopPkTimer();
    super.onClose();
  }
}
