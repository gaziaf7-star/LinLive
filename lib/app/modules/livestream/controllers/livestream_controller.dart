import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/websocket_controller.dart';
import 'package:meetlivepro/app/modules/livestream/managers/live_viewer_state_manager.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../services/agora_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../messanger/views/audio_call_view.dart';
import '../../messanger/views/video_call_view.dart';
import '../endLive/endLive.dart';
import '../utils/LiveTestingLogger.dart';
import '../views/audio_live_view.dart';
import '../views/multi_live_view.dart';
import '../views/popular_live_view.dart';
import 'agoraTokenController.dart';
import 'audience_join_controller.dart';
import 'red_packet_controller.dart';
import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class LivestreamController extends GetxController {
  RxBool isLocked = false.obs;
  RxBool isShow = false.obs;
  RxBool showProfile = false.obs;
  RxBool showPkRoom = false.obs;
  RxBool showPkView = false.obs;
  RxBool selectSuperMic = false.obs;
  RxBool effectSetting = false.obs;
  RxBool selectedRoom = false.obs;
  RxBool isMuted = false.obs;
  RxBool hidePk = false.obs;
  int selectPaymentIndex = 0;

  //lucky
  final luckyGiftOverlayData = <String, dynamic>{}.obs;
  final luckyGiftOverlayVisible = false.obs;
  final luckyGiftTickerQueue = <Map<String, dynamic>>[].obs;
  final luckyGiftCoinRainVisible = false.obs;

  /// 5x and above Lucky wins are shown through a root OverlayEntry, therefore
  /// the banner remains visible on Home, profile, messages and every live room.
  OverlayEntry? _globalLuckyWinEntry;
  Timer? _globalLuckyWinTimer;
  String _lastGlobalLuckyWinKey = '';
  int _lastGlobalLuckyWinAtMs = 0;

  /// App-wide Lucky Win banner state. This lives in MyApp.builder, so it stays
  /// visible on Home, Messages, Profile, Games and every live-room route.
  final globalLuckyWinData = <String, dynamic>{}.obs;
  final globalLuckyWinBannerVisible = false.obs;
  final globalLuckyWinBannerSeconds = 0.obs;
  final Queue<Map<String, dynamic>> _globalLuckyWinQueue =
  Queue<Map<String, dynamic>>();

  /// Real backend event IDs are remembered so API/local/websocket copies of the
  /// same Lucky win can never create two banners. Fingerprints are only used as
  /// a short fallback when one copy arrives without an event ID.
  final Set<String> _globalLuckyWinSeenKeys = <String>{};
  final Map<String, int> _globalLuckyWinRecentFingerprints = <String, int>{};

  /// Keys already active or waiting in the queue. This closes the small gap
  /// between receiving duplicate websocket frames and mounting the next banner.
  final Set<String> _globalLuckyWinPendingKeys = <String>{};

  Timer? _globalLuckyWinBannerTimer;

  /// Red Packet implementation now lives in RedPacketController.
  late final RedPacketController redPacketController;

  /// Backward-compatible observable aliases. Existing UI files can migrate
  /// gradually without keeping Red Packet business logic in this controller.
  RxMap<String, dynamic> get globalLuckyBagData =>
      redPacketController.globalLuckyBagData;
  RxBool get globalLuckyBagBannerVisible =>
      redPacketController.globalLuckyBagBannerVisible;
  RxInt get globalLuckyBagBannerSeconds =>
      redPacketController.globalLuckyBagBannerSeconds;

  void showGlobalLuckyBagBanner(
      Map<String, dynamic> packet, {
        int seconds = 5,
      }) =>
      redPacketController.showGlobalLuckyBagBanner(packet, seconds: seconds);

  void hideGlobalLuckyBagBanner() =>
      redPacketController.hideGlobalLuckyBagBanner();

  Map<String, dynamic> extractRedPacketFromEvent(dynamic payload) =>
      redPacketController.extractRedPacketFromEvent(payload);

  bool redPacketEventIsGlobal(
      dynamic payload,
      Map<String, dynamic> packet,
      ) =>
      redPacketController.redPacketEventIsGlobal(payload, packet);

  void handleRedPacketSentForGlobalBanner(dynamic payload) =>
      redPacketController.handleRedPacketSentForGlobalBanner(payload);

  final RxBool showMiniScene = false.obs;
  final RxBool isVideoLiveMinimized = false.obs;
  final RxMap<String, dynamic> minimizedVideoLiveSession =
      <String, dynamic>{}.obs;
  final RxSet<int> videoLiveRemoteUids = <int>{}.obs;
  final RxMap<int, bool> videoLiveRemoteVideoEnabled = <int, bool>{}.obs;
  final RxMap<int, int> videoCallerAgoraUidMap = <int, int>{}.obs;
  RtcEngineEventHandler? _minimizedVideoEventHandler;

  void syncVideoLiveRemoteUid(int uid, {required bool connected}) {
    if (uid <= 0) return;
    if (connected) {
      videoLiveRemoteUids.add(uid);
      videoLiveRemoteVideoEnabled[uid] ??= true;
    } else {
      videoLiveRemoteUids.remove(uid);
      videoLiveRemoteVideoEnabled.remove(uid);
      removeVideoCallerAgoraMappingByRemoteUid(uid);
    }
    videoLiveRemoteUids.refresh();
    videoLiveRemoteVideoEnabled.refresh();
  }

  void syncVideoLiveRemoteVideo(int uid, {required bool enabled}) {
    if (uid <= 0 || !videoLiveRemoteUids.contains(uid)) return;
    videoLiveRemoteVideoEnabled[uid] = enabled;
    videoLiveRemoteVideoEnabled.refresh();
  }

  void mapVideoCallerToAgoraUid({
    required int callerId,
    required int remoteUid,
  }) {
    if (callerId <= 0 || remoteUid <= 0) return;
    videoCallerAgoraUidMap[callerId] = remoteUid;
    videoCallerAgoraUidMap.refresh();
  }

  void syncVideoCallerAgoraMappingsFromCalls(Iterable<dynamic> calls) {
    final currentUserId = authController.userProfile.value.user?.id ?? 0;
    final callerIds = <int>{};
    for (final raw in calls) {
      if (raw is! Map) continue;
      final call = Map<String, dynamic>.from(raw);
      final status = '${call['call_status'] ?? call['status'] ?? ''}'
          .toLowerCase();
      final type = '${call['call_type'] ?? call['type'] ?? ''}'.toLowerCase();
      final videoOn =
          int.tryParse('${call['video_on'] ?? call['is_video_on'] ?? 1}') ?? 1;
      final acceptedStatus =
          status == 'accepted' ||
              status == 'joined' ||
              status == 'active' ||
              status == 'live' ||
              status == 'on_seat';
      if (!acceptedStatus ||
          !(type == 'video' || type == 'popular') ||
          videoOn == 0) {
        continue;
      }
      final user = call['user'] is Map
          ? Map<String, dynamic>.from(call['user'])
          : <String, dynamic>{};
      final callerId =
          int.tryParse(
            '${call['caller_id'] ?? call['user_id'] ?? user['id'] ?? 0}',
          ) ??
              0;
      if (callerId > 0 && callerId != currentUserId) callerIds.add(callerId);
    }
    final staleCallerIds = videoCallerAgoraUidMap.keys.where((callerId) {
      if (callerIds.contains(callerId)) return false;

      final int mappedUid = videoCallerAgoraUidMap[callerId] ?? 0;
      final bool mediaStillConnected = mappedUid > 0 &&
          videoLiveRemoteUids.any(
                (uid) =>
            uid == mappedUid ||
                uid == callerId ||
                uid == callerId + 100000 ||
                (callerId >= 100000 && uid == callerId - 100000),
          );

      // A reordered API/websocket snapshot may temporarily omit an accepted
      // caller while Agora audio/video is still flowing. Keep the mapping so
      // the timeout guard and video renderer can preserve the live call card.
      return !mediaStillConnected;
    }).toList(growable: false);
    if (staleCallerIds.isNotEmpty) {
      for (final callerId in staleCallerIds) {
        videoCallerAgoraUidMap.remove(callerId);
      }
      videoCallerAgoraUidMap.refresh();
    }
    final available = videoLiveRemoteUids.toSet();
    for (final callerId in callerIds) {
      final existing = videoCallerAgoraUidMap[callerId] ?? 0;
      if (existing > 0 && available.remove(existing)) continue;
      final equivalent = available.firstWhere(
            (uid) =>
        uid == callerId ||
            uid == callerId + 100000 ||
            (callerId >= 100000 && uid == callerId - 100000),
        orElse: () => 0,
      );
      if (equivalent > 0) {
        mapVideoCallerToAgoraUid(callerId: callerId, remoteUid: equivalent);
        available.remove(equivalent);
      }
    }
    final unmapped = callerIds
        .where(
          (id) => !videoLiveRemoteUids.contains(videoCallerAgoraUidMap[id]),
    )
        .toList();
    if (unmapped.length == 1 && available.length == 1) {
      mapVideoCallerToAgoraUid(
        callerId: unmapped.single,
        remoteUid: available.single,
      );
    }
    final engine = AgoraService().engine;
    if (engine != null) {
      for (final callerId in callerIds) {
        final remoteUid = videoCallerAgoraUidMap[callerId] ?? 0;
        if (remoteUid <= 0) continue;
        unawaited(engine.muteRemoteVideoStream(uid: remoteUid, mute: false));
        unawaited(engine.muteRemoteAudioStream(uid: remoteUid, mute: false));
      }
    }
  }

  void removeVideoCallerAgoraMappingByRemoteUid(int remoteUid) {
    videoCallerAgoraUidMap.removeWhere((_, uid) => uid == remoteUid);
    videoCallerAgoraUidMap.refresh();
  }

  void minimizeVideoLiveSession({
    required int livestreamId,
    required String channelName,
    required String token,
    required bool isBroadcaster,
    required Map<String, dynamic> arguments,
    bool activateImmediately = true,
  }) {
    minimizedVideoLiveSession.assignAll(<String, dynamic>{
      'livestream_id': livestreamId,
      'channel_name': channelName,
      'token': token,
      'is_broadcaster': isBroadcaster,
      'arguments': Map<String, dynamic>.from(arguments),
    });
    isVideoLiveMinimized.value = activateImmediately;
    if (activateImmediately) _bindMinimizedVideoEvents();
  }

  void activateMinimizedVideoLiveRenderer() {
    if (minimizedVideoLiveSession.isEmpty) return;
    isVideoLiveMinimized.value = true;
    _bindMinimizedVideoEvents();
  }

  void _bindMinimizedVideoEvents() {
    final engine = AgoraService().engine;
    if (engine == null) return;
    final oldHandler = _minimizedVideoEventHandler;
    if (oldHandler != null) {
      try {
        engine.unregisterEventHandler(oldHandler);
      } catch (_) {}
    }
    _minimizedVideoEventHandler = RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        if (!isVideoLiveMinimized.value) return;
        syncVideoLiveRemoteUid(remoteUid, connected: true);
        try {
          syncVideoCallerAgoraMappingsFromCalls(
            Get.find<WebsocketController>().liveCallList,
          );
        } catch (_) {}
        engine.muteRemoteVideoStream(uid: remoteUid, mute: false);
        engine.muteRemoteAudioStream(uid: remoteUid, mute: false);
      },
      onUserOffline: (connection, remoteUid, reason) {
        syncVideoLiveRemoteUid(remoteUid, connected: false);
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
        final enabled =
            state == RemoteVideoState.remoteVideoStateStarting ||
                state == RemoteVideoState.remoteVideoStateDecoding;
        syncVideoLiveRemoteVideo(remoteUid, enabled: enabled);
      },
    );
    engine.registerEventHandler(_minimizedVideoEventHandler!);
  }

  void beginVideoLiveRestore() {
    final engine = AgoraService().engine;
    final handler = _minimizedVideoEventHandler;
    _minimizedVideoEventHandler = null;
    if (engine != null && handler != null) {
      try {
        engine.unregisterEventHandler(handler);
      } catch (_) {}
    }
    isVideoLiveMinimized.value = false;
  }

  void clearMinimizedVideoLiveSession() {
    beginVideoLiveRestore();
    minimizedVideoLiveSession.clear();
    videoLiveRemoteUids.clear();
    videoLiveRemoteVideoEnabled.clear();
    videoCallerAgoraUidMap.clear();
  }

  final dio = Dio();
  final AuthController authController = Get.find();
  final isLock = true.obs;
  final audienscMute = false.obs;

  /// ===================== LIVE MUSIC / AUDIO MIXING =====================
  /// Host local gallery music path. Audience only gets status/name by websocket.
  final selectedMusicPath = ''.obs;
  final liveMusicName = ''.obs;
  final liveMusicStatus =
      'stopped'.obs; // playing, paused, resumed, stopped, changed
  final musicLoading = false.obs;

  /// True only while the professional music bottom sheet is visible.
  /// AudioLiveView uses this to hide the minimized card behind the sheet.
  final isMusicPlayerSheetOpen = false.obs;

  /// Professional player state. All values are local to the host device;
  /// status/name are still broadcast through the existing backend websocket.
  final musicPositionMs = 0.obs;
  final musicDurationMs = 0.obs;
  final musicVolume = 65.obs;
  final musicRepeat = true.obs;
  final musicSeeking = false.obs;
  final recentLiveMusics = <Map<String, String>>[].obs;

  Timer? _musicProgressTimer;
  bool _musicActionRunning = false;

  double get liveMusicProgress {
    final duration = musicDurationMs.value;
    if (duration <= 0) return 0;
    return (musicPositionMs.value / duration).clamp(0.0, 1.0);
  }

  String formatMusicTime(int milliseconds) {
    final totalSeconds = (milliseconds < 0 ? 0 : milliseconds) ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// ===================== LIVE YOUTUBE CONTROL =====================
  /// YouTube video locally play hobe sob audience app-e.
  /// Host mute/music mute er sathe YouTube sound relation nai.
  final liveYoutubeStatus =
      'stopped'.obs; // playing, paused, resumed, stopped, changed
  final liveYoutubeUrl = ''.obs;
  final liveYoutubeVideoId = ''.obs;
  final youtubeLoading = false.obs;

  bool get isLiveMusicPlaying =>
      liveMusicStatus.value == 'playing' ||
          liveMusicStatus.value == 'resumed' ||
          liveMusicStatus.value == 'changed';

  AgoraTokenController agoraTokenController = Get.find();

  // ---------------------- Emoji send -------
  RxBool showEmoji = false.obs;

  List<String> emojiList = ['😄', '😂', '😍', '🔥', '👍', '🥳'];

  /// ===================== LIVE IMOGI / EMOJI =====================
  /// Old emojiList stays unchanged. These states are only for backend imogi.
  final imogiLoading = false.obs;
  final imogiSending = false.obs;
  final selectedImogiCategoryIndex = 0.obs;

  /// Category list format:
  /// [{id,name,image,imogies:[...]}]
  final imogiCategoryList = <Map<String, dynamic>>[].obs;

  /// Flat imogi list fallback.
  final imogiList = <Map<String, dynamic>>[].obs;
  final RxBool quickGiftVisible = false.obs;
  final RxBool quickGiftSending = false.obs;
  final RxInt quickGiftCountdown = 0.obs;
  final RxInt quickGiftComboCount = 0.obs;
  final RxMap<String, dynamic> quickGiftData = <String, dynamic>{}.obs;

  Timer? _quickGiftTimer;
  Timer? _giftAnimationHideTimer;
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
  int _quickGiftClientSerial = 0;

  static const int _quickGiftSeconds = 7;
  static const Duration _quickGiftRequestGap = Duration(milliseconds: 120);

  final Map<String, int> _recentGiftEventMs = {};
  int _giftAnimationSerial = 0;
  int _giftClientEventSerial = 0;

  String _newGiftClientEventId({required int senderId, required int giftId}) {
    final int serial = ++_giftClientEventSerial;
    final int micros = DateTime.now().microsecondsSinceEpoch;
    return 'gift_${streamId.value}_${senderId}_${giftId}_${micros}_$serial';
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
      // await _quickGiftLastSoundPlayer!.play(
      //   // pubspec path: assets/audio_live/giftlast5secoundsound.mp3
      //   AssetSource('audio_live/giftlast5secoundsound.mp3'),
      // );
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
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (senderId <= 0) return;

    quickGiftComboCount.value = quickGiftComboCount.value <= 0
        ? 2
        : quickGiftComboCount.value + 1;

    final int clientSerial = ++_quickGiftClientSerial;
    final String clientEventId = _newGiftClientEventId(
      senderId: senderId,
      giftId: giftId,
    );
    final Map<String, dynamic> job = <String, dynamic>{
      'client_serial': clientSerial,
      'client_event_id': clientEventId,
      'receiver_ids': List<int>.from(receiverIds),
      'receiver_id': receiverIds.first,
      'gift_id': giftId,
      'gift_price': giftPrice,
      'gift': gift,
    };

    /// Do not wait for the previous API call. Every physical/auto tap creates
    /// one visual item immediately; WebsocketController then plays them serially.
    _dispatchGiftToLocalUiImmediately(
      responseData: <String, dynamic>{
        'livestream_id': streamId.value,
        'stream_id': streamId.value,
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

    try {
      while (_quickGiftSendQueue.isNotEmpty) {
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
        );

        quickGiftPendingCount.value = _quickGiftSendQueue.length;

        if (_quickGiftSendQueue.isNotEmpty) {
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

  RxInt selectedIndex1 = (-1).obs;
  void selectRoom(int index) {
    selectedIndex1.value = index;
  }

  final durations = ['1 Month', '3 Months', '6 Months', '12 Months'];
  RxInt selectedIndex = 0.obs;

  final mute = false.obs;
  final voice = false.obs;
  final hasJoinedCall = false.obs;

  final List<String> nationalIdentity = [
    'Please set room password',
    'Please set room gift',
  ];
  final selectedType = 'Please set room password'.obs;

  final String appId = "d0015737a05546b6be82f188951f5772";

  //for live stream

  final isBroadcaster = false.obs;
  final isHost = false.obs;
  final streamId = 0.obs;
  final broadcasterId = 0.obs;
  //for live stream start
  //generate token
  final getTokens = {}.obs;
  WebsocketController get websocketController =>
      Get.find<WebsocketController>();

  Timer? _pingTimer;

  /// ===================== PRESENCE / LIVE ROOM HEARTBEAT =====================
  /// State machine:
  /// viewer -> seat accepted/joined -> caller
  /// caller -> explicit leave seat/host remove -> viewer
  /// viewer/caller -> explicit room exit -> none
  /// background/minimize -> keep current role and seat
  Timer? _presenceHeartbeatTimer;
  int _presenceStreamId = 0;
  String _presenceRole = 'viewer';
  bool _presenceIsOnSeat = false;
  int? _presenceSeatNo;
  bool _presenceRequestRunning = false;
  bool _presenceHeartbeatQueued = false;
  bool _presenceBackgroundMode = false;

  /// Presence request watchdog. A Dio request that never finishes leaves
  /// `_presenceRequestRunning=true`; every later timer tick then only queues and
  /// the backend eventually removes the active video caller after its lease
  /// timeout. These fields let us unlock a stale request and resend safely.
  int _presenceRequestStartedAtMs = 0;
  int _lastPresenceRequestAtMs = 0;
  int _lastPresenceSuccessAtMs = 0;
  String _lastPresenceBodyKey = '';

  int _presenceRequestSequence = 0;
  int _presenceSuccessCount = 0;
  int _presenceFailureCount = 0;
  int? _lastPresenceStatusCode;
  dynamic _lastPresenceResponseData;
  String _lastPresenceError = '';
  dynamic _lastPresenceServerPingAt;
  int _lastPermanentPingRequestAtMs = 0;
  int _lastPermanentPingSuccessAtMs = 0;
  int? _lastPermanentPingStatusCode;
  dynamic _lastPermanentPingResponseData;
  String _lastPermanentPingError = '';

  static const Duration _foregroundPresenceInterval = Duration(seconds: 15);
  static const Duration _backgroundPresenceInterval = Duration(seconds: 20);

  int get currentPresenceStreamId => _presenceStreamId;
  String get currentPresenceRole => _presenceRole;
  bool get currentPresenceIsOnSeat => _presenceIsOnSeat;
  int? get currentPresenceSeatNo => _presenceSeatNo;

  Map<String, dynamic> get livePresenceDebugSnapshot {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{
      'time': DateTime.now().toIso8601String(),
      'stream_id': _presenceStreamId,
      'role': _presenceRole,
      'is_on_seat': _presenceIsOnSeat,
      'seat_no': _presenceSeatNo,
      'background_mode': _presenceBackgroundMode,
      'heartbeat_timer_active': _presenceHeartbeatTimer?.isActive == true,
      'heartbeat_interval_seconds': _presenceBackgroundMode
          ? _backgroundPresenceInterval.inSeconds
          : _foregroundPresenceInterval.inSeconds,
      'request_running': _presenceRequestRunning,
      'request_running_for_ms': _presenceRequestRunning &&
          _presenceRequestStartedAtMs > 0
          ? nowMs - _presenceRequestStartedAtMs
          : 0,
      'request_queued': _presenceHeartbeatQueued,
      'request_sequence': _presenceRequestSequence,
      'success_count': _presenceSuccessCount,
      'failure_count': _presenceFailureCount,
      'last_request_at': _lastPresenceRequestAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(_lastPresenceRequestAtMs)
          .toIso8601String()
          : null,
      'last_request_age_seconds': _lastPresenceRequestAtMs > 0
          ? ((nowMs - _lastPresenceRequestAtMs) / 1000).round()
          : null,
      'last_success_at': _lastPresenceSuccessAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(_lastPresenceSuccessAtMs)
          .toIso8601String()
          : null,
      'last_success_age_seconds': _lastPresenceSuccessAtMs > 0
          ? ((nowMs - _lastPresenceSuccessAtMs) / 1000).round()
          : null,
      'last_status_code': _lastPresenceStatusCode,
      'last_error': _lastPresenceError,
      'last_server_ping_at': _lastPresenceServerPingAt,
      'last_server_ping_age_seconds':
      LiveTestingLogger.ageSeconds(_lastPresenceServerPingAt),
      'last_response': _lastPresenceResponseData,
      'permanent_ping_timer_active': _pingTimer?.isActive == true,
      'last_permanent_ping_request_at': _lastPermanentPingRequestAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(_lastPermanentPingRequestAtMs)
          .toIso8601String()
          : null,
      'last_permanent_ping_success_at': _lastPermanentPingSuccessAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(_lastPermanentPingSuccessAtMs)
          .toIso8601String()
          : null,
      'last_permanent_ping_status_code': _lastPermanentPingStatusCode,
      'last_permanent_ping_error': _lastPermanentPingError,
      'last_permanent_ping_response': _lastPermanentPingResponseData,
    };
  }

  void printLivePresenceDebugSnapshot({String source = 'manual'}) {
    LiveTestingLogger.printBlock(
      'LIVE TEST PRESENCE SNAPSHOT [$source]',
      livePresenceDebugSnapshot,
    );
  }

  void _setPresenceState({
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) {
    if (livestreamId != null && livestreamId > 0) {
      _presenceStreamId = livestreamId;
    }

    final normalizedRole = (role ?? _presenceRole).toLowerCase().trim();

    if (normalizedRole == 'host') {
      _presenceRole = 'host';
      _presenceIsOnSeat = true;
      _presenceSeatNo = seatNo != null && seatNo > 0
          ? seatNo
          : (_presenceSeatNo ?? 1);
      return;
    }

    if (normalizedRole == 'caller') {
      _presenceRole = 'caller';
      _presenceIsOnSeat = true;

      if (seatNo != null && seatNo > 0) {
        _presenceSeatNo = seatNo;
      }

      return;
    }

    _presenceRole = 'viewer';
    _presenceIsOnSeat = false;
    _presenceSeatNo = null;
  }

  Map<String, dynamic> _presenceBody({
    int? userId,
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) {
    final uid =
        userId ?? authController.userProfile.value.user?.id?.toInt() ?? 0;

    final sid = livestreamId ?? _presenceStreamId;
    final resolvedRole = (role ?? _presenceRole).toLowerCase().trim();

    final onSeat = resolvedRole == 'caller' || resolvedRole == 'host';

    int? resolvedSeat;
    if (onSeat) {
      resolvedSeat = seatNo ?? _presenceSeatNo;

      if (resolvedRole == 'host' &&
          (resolvedSeat == null || resolvedSeat <= 0)) {
        resolvedSeat = 1;
      }
    }

    final body = <String, dynamic>{'user_id': uid};

    if (sid > 0) {
      body['livestream_id'] = sid;
      body['role'] = onSeat ? resolvedRole : 'viewer';
      body['is_on_seat'] = onSeat;
      body['seat_no'] = onSeat ? resolvedSeat : null;
    }

    return body;
  }

  void _reconcileSelfSeatFromBackendPresence(dynamic responseData) {
    final root = _asMap(responseData);
    final data = _asMap(root['data']);
    final liveData = _asMap(data['livestream_data']);

    if (liveData.isEmpty) return;

    final backendRole = (liveData['role'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final backendOnSeat =
        liveData['is_on_seat'] == true ||
            liveData['is_on_seat']?.toString() == '1' ||
            liveData['is_on_seat']?.toString().toLowerCase() == 'true';

    final backendSeatNo = _toInt(liveData['seat_no']);
    final localSeatNo = currentUserSeatNo(ignorePresence: true);

    if ((backendRole == 'caller' || backendRole == 'host') &&
        backendOnSeat &&
        backendSeatNo > 0) {
      // Host heartbeat must never be downgraded to caller by backend response.
      // Backend may return caller because host also has a livestream_callers row,
      // but frontend source of truth is the local requested host role.
      final String safeRole = _presenceRole == 'host' ? 'host' : backendRole;

      _setPresenceState(
        role: safeRole,
        isOnSeat: true,
        seatNo: safeRole == 'host' ? 1 : backendSeatNo,
      );
      return;
    }

    // A delayed viewer heartbeat must not remove a caller who is still
    // visible in the call list or whose caller seat is remembered locally.
    final rememberedSeat = localSeatNo > 0
        ? localSeatNo
        : (_presenceRole == 'caller' ? (_presenceSeatNo ?? 0) : 0);

    if (rememberedSeat > 0) {
      _setPresenceState(role: 'caller', isOnSeat: true, seatNo: rememberedSeat);

      liveLog(
        '🛡️ Weak viewer heartbeat ignored; caller seat repaired '
            '=> seat=$rememberedSeat backendRole=$backendRole',
      );

      Future.microtask(() async {
        await sendPresenceHeartbeatOnce(
          livestreamId: _presenceStreamId,
          role: 'caller',
          isOnSeat: true,
          seatNo: rememberedSeat,
        );

        if (_presenceStreamId > 0) {
          await tryToGetCallList(streamId: _presenceStreamId);
        }
      });

      return;
    }

    _setPresenceState(role: 'viewer', isOnSeat: false, seatNo: null);
  }

  Future<void> sendPresenceHeartbeatOnce({
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) async {
    final int uid =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (uid <= 0) {
      liveLog('❌ Presence heartbeat stopped: uid is 0');
      return;
    }

    final int sid = livestreamId ?? _presenceStreamId;

    _setPresenceState(
      livestreamId: sid > 0 ? sid : null,
      role: role,
      isOnSeat: isOnSeat,
      seatNo: seatNo,
    );

    final Map<String, dynamic> body = _presenceBody(
      userId: uid,
      livestreamId: sid > 0 ? sid : null,
      role: _presenceRole,
      isOnSeat: _presenceIsOnSeat,
      seatNo: _presenceSeatNo,
    );

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final String bodyKey =
        '${body['livestream_id']}|${body['role']}|${body['is_on_seat']}|${body['seat_no']}';

    // Several UI/websocket callbacks can request the same heartbeat together.
    // Skip only a very recent duplicate; the periodic 15/20-second lease update
    // is never blocked by this guard.
    if (bodyKey == _lastPresenceBodyKey &&
        nowMs - _lastPresenceRequestAtMs < 8000) {
      liveLog('⏭️ Presence heartbeat duplicate skipped => $bodyKey');
      return;
    }

    if (_presenceRequestRunning) {
      final int runningForMs = nowMs - _presenceRequestStartedAtMs;

      // Network/Dio can occasionally leave a request pending. Without this
      // watchdog all later heartbeats are blocked and a video caller is removed
      // after roughly 2-4 minutes even though Agora media is still connected.
      if (_presenceRequestStartedAtMs > 0 && runningForMs > 12000) {
        liveLog(
          '🛡️ Presence heartbeat stuck for ${runningForMs}ms; force unlock',
        );
        _presenceRequestRunning = false;
        _presenceHeartbeatQueued = false;
      } else {
        _presenceHeartbeatQueued = true;
        liveLog('ℹ️ Presence heartbeat queued; request already running');
        return;
      }
    }

    _presenceRequestRunning = true;
    _presenceRequestStartedAtMs = nowMs;
    _lastPresenceBodyKey = bodyKey;
    _lastPresenceRequestAtMs = nowMs;
    final int requestSequence = ++_presenceRequestSequence;
    final Stopwatch heartbeatStopwatch = Stopwatch()..start();
    _lastPresenceError = '';

    liveLog(
      '📤 Presence heartbeat => stream=${body['livestream_id']} '
          'role=${body['role']} seat=${body['seat_no']}',
    );
    LiveTestingLogger.printBlock(
      'LIVE TEST PRESENCE HEARTBEAT REQUEST #$requestSequence',
      {
        'time': DateTime.now().toIso8601String(),
        'url': '$kMainUrl/user/heartbeat',
        'body': body,
        'state_before': livePresenceDebugSnapshot,
      },
    );

    try {
      final response = await dio.post(
        '$kMainUrl/user/heartbeat',
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      _lastPresenceStatusCode = response.statusCode;
      _lastPresenceResponseData = response.data;
      _lastPresenceServerPingAt = LiveTestingLogger.findFirstByKeys(
        response.data,
        const <String>[
          'last_ping_at',
          'last_ping',
          'ping_at',
          'last_seen_at',
        ],
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastPresenceSuccessAtMs = DateTime.now().millisecondsSinceEpoch;
        _presenceSuccessCount++;
        _reconcileSelfSeatFromBackendPresence(response.data);

        liveLog(
          '✅ Presence heartbeat ok => stream=$_presenceStreamId '
              'role=$_presenceRole seat=$_presenceSeatNo',
        );
      } else {
        _presenceFailureCount++;
        _lastPresenceError =
        'HTTP ${response.statusCode}: ${response.statusMessage ?? ''}';
        liveLog('⚠️ Presence heartbeat failed: ${response.statusCode}');
      }

      LiveTestingLogger.printBlock(
        'LIVE TEST PRESENCE HEARTBEAT RESPONSE #$requestSequence',
        {
          'elapsed_ms': heartbeatStopwatch.elapsedMilliseconds,
          'status_code': response.statusCode,
          'status_message': response.statusMessage,
          'last_ping_at': _lastPresenceServerPingAt,
          'last_ping_age_seconds':
          LiveTestingLogger.ageSeconds(_lastPresenceServerPingAt),
          'response': response.data,
          'state_after': livePresenceDebugSnapshot,
        },
      );
    } on DioException catch (e) {
      _presenceFailureCount++;
      _lastPresenceStatusCode = e.response?.statusCode;
      _lastPresenceResponseData = e.response?.data;
      _lastPresenceError = e.message ?? e.error?.toString() ?? 'Dio error';
      liveLog(
        '⚠️ Presence heartbeat network/server error: '
            '${e.response?.statusCode ?? e.message}',
      );
      LiveTestingLogger.printBlock(
        'LIVE TEST PRESENCE HEARTBEAT DIO ERROR #$requestSequence',
        {
          'elapsed_ms': heartbeatStopwatch.elapsedMilliseconds,
          'dio_type': e.type.toString(),
          'message': e.message,
          'error': e.error?.toString(),
          'status_code': e.response?.statusCode,
          'response': e.response?.data,
          'request_body': body,
          'state': livePresenceDebugSnapshot,
        },
      );
    } catch (e, st) {
      _presenceFailureCount++;
      _lastPresenceError = e.toString();
      liveLog('❌ Presence heartbeat error => $e');
      liveLog('❌ StackTrace => $st');
      LiveTestingLogger.printBlock(
        'LIVE TEST PRESENCE HEARTBEAT ERROR #$requestSequence',
        {
          'elapsed_ms': heartbeatStopwatch.elapsedMilliseconds,
          'error': e.toString(),
          'stack_trace': st.toString(),
          'request_body': body,
          'state': livePresenceDebugSnapshot,
        },
      );
    } finally {
      heartbeatStopwatch.stop();
      _presenceRequestRunning = false;
      _presenceRequestStartedAtMs = 0;
      LiveTestingLogger.line(
        '💓 LIVE TEST HEARTBEAT COMPLETE #$requestSequence => '
            'elapsed=${heartbeatStopwatch.elapsedMilliseconds}ms '
            'status=$_lastPresenceStatusCode success=$_presenceSuccessCount '
            'failed=$_presenceFailureCount role=$_presenceRole '
            'seat=$_presenceSeatNo lastPing=$_lastPresenceServerPingAt',
      );

      if (_presenceHeartbeatQueued) {
        _presenceHeartbeatQueued = false;

        Future<void>.delayed(const Duration(milliseconds: 120), () {
          sendPresenceHeartbeatOnce(
            livestreamId: _presenceStreamId,
            role: _presenceRole,
            isOnSeat: _presenceIsOnSeat,
            seatNo: _presenceSeatNo,
          );
        });
      }
    }
  }

  void startLivePresenceHeartbeat({
    required int livestreamId,
    required String role,
    bool isOnSeat = false,
    int? seatNo,
    Duration? interval,
    bool backgroundMode = false,
  }) {
    if (livestreamId <= 0) return;

    final String normalizedRole = role.toLowerCase().trim();
    final int? normalizedSeat = isOnSeat ? seatNo : null;

    final effectiveInterval =
        interval ??
            (backgroundMode
                ? _backgroundPresenceInterval
                : _foregroundPresenceInterval);

    final bool sameStateRunning =
        _presenceHeartbeatTimer != null &&
            _presenceStreamId == livestreamId &&
            _presenceRole == normalizedRole &&
            _presenceIsOnSeat == isOnSeat &&
            _presenceSeatNo == normalizedSeat &&
            _presenceBackgroundMode == backgroundMode;

    if (sameStateRunning) {
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final bool successIsStale =
          _lastPresenceSuccessAtMs == 0 ||
              nowMs - _lastPresenceSuccessAtMs > 26000;
      final bool requestLooksStuck =
          _presenceRequestRunning &&
              _presenceRequestStartedAtMs > 0 &&
              nowMs - _presenceRequestStartedAtMs > 12000;

      if (successIsStale || requestLooksStuck) {
        liveLog(
          '🛡️ Presence lease watchdog resend => '
              'stream=$livestreamId role=$normalizedRole seat=$normalizedSeat',
        );
        unawaited(
          sendPresenceHeartbeatOnce(
            livestreamId: livestreamId,
            role: normalizedRole,
            isOnSeat: isOnSeat,
            seatNo: normalizedSeat,
          ),
        );
      } else {
        liveLog(
          '🛡️ Presence heartbeat already running => '
              'stream=$livestreamId role=$normalizedRole seat=$normalizedSeat',
        );
      }
      return;
    }

    _setPresenceState(
      livestreamId: livestreamId,
      role: normalizedRole,
      isOnSeat: isOnSeat,
      seatNo: normalizedSeat,
    );

    _presenceBackgroundMode = backgroundMode;

    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;

    sendPresenceHeartbeatOnce(
      livestreamId: _presenceStreamId,
      role: _presenceRole,
      isOnSeat: _presenceIsOnSeat,
      seatNo: _presenceSeatNo,
    );

    _presenceHeartbeatTimer = Timer.periodic(effectiveInterval, (_) {
      sendPresenceHeartbeatOnce(
        livestreamId: _presenceStreamId,
        role: _presenceRole,
        isOnSeat: _presenceIsOnSeat,
        seatNo: _presenceSeatNo,
      );
    });

    LiveTestingLogger.printBlock('LIVE TEST PRESENCE TIMER STARTED', {
      'effective_interval_seconds': effectiveInterval.inSeconds,
      'state': livePresenceDebugSnapshot,
    });
    liveLog(
      '✅ Live presence started => stream=$_presenceStreamId '
          'role=$_presenceRole seat=$_presenceSeatNo '
          'background=$_presenceBackgroundMode '
          'interval=${effectiveInterval.inSeconds}s',
    );
  }

  void setLivePresenceBackgroundMode(bool enabled) {
    if (_presenceStreamId <= 0) return;

    if (_presenceBackgroundMode == enabled && _presenceHeartbeatTimer != null) {
      return;
    }

    startLivePresenceHeartbeat(
      livestreamId: _presenceStreamId,
      role: _presenceRole,
      isOnSeat: _presenceIsOnSeat,
      seatNo: _presenceSeatNo,
      backgroundMode: enabled,
    );
  }

  void updateLivePresenceRole({
    required String role,
    bool? isOnSeat,
    int? seatNo,
  }) {
    String normalizedRole = role.toLowerCase().trim();

    // Host live page can receive late caller/viewer updates from old snapshots.
    // Do not downgrade a host heartbeat unless caller explicitly stopped it.
    if (_presenceRole == 'host' && normalizedRole != 'host') {
      liveLog(
        '🛡️ Host presence downgrade blocked => requested=$normalizedRole',
      );
      normalizedRole = 'host';
      isOnSeat = true;
      seatNo = 1;
    }

    final bool nextIsOnSeat = isOnSeat ?? _presenceIsOnSeat;
    final int? nextSeat = nextIsOnSeat ? (seatNo ?? _presenceSeatNo) : null;

    final int resolvedStreamId = _presenceStreamId > 0
        ? _presenceStreamId
        : (streamId.value > 0
        ? streamId.value
        : websocketController.streamID.value);

    final bool sameState =
        _presenceRole == normalizedRole &&
            _presenceIsOnSeat == nextIsOnSeat &&
            _presenceSeatNo == nextSeat;

    _setPresenceState(
      livestreamId: resolvedStreamId > 0 ? resolvedStreamId : null,
      role: normalizedRole,
      isOnSeat: nextIsOnSeat,
      seatNo: nextSeat,
    );

    // Video live used to call updateLivePresenceRole() before any heartbeat
    // timer existed. Then /user/heartbeat was sent without livestream_id and
    // the backend removed an otherwise healthy Agora caller after 120 seconds.
    if (resolvedStreamId > 0 && _presenceHeartbeatTimer == null) {
      startLivePresenceHeartbeat(
        livestreamId: resolvedStreamId,
        role: _presenceRole,
        isOnSeat: _presenceIsOnSeat,
        seatNo: _presenceSeatNo,
        backgroundMode: _presenceBackgroundMode,
      );
      liveLog(
        '✅ Presence heartbeat auto-started from role update '
            '=> stream=$resolvedStreamId role=$_presenceRole seat=$_presenceSeatNo',
      );
      return;
    }

    if (sameState) {
      if (resolvedStreamId > 0) {
        unawaited(
          sendPresenceHeartbeatOnce(
            livestreamId: resolvedStreamId,
            role: _presenceRole,
            isOnSeat: _presenceIsOnSeat,
            seatNo: _presenceSeatNo,
          ),
        );
      }
      return;
    }

    unawaited(
      sendPresenceHeartbeatOnce(
        livestreamId: resolvedStreamId > 0 ? resolvedStreamId : null,
        role: _presenceRole,
        isOnSeat: _presenceIsOnSeat,
        seatNo: _presenceSeatNo,
      ),
    );
  }

  void stopLivePresenceHeartbeat() {
    LiveTestingLogger.printBlock(
      'LIVE TEST PRESENCE TIMER STOP',
      livePresenceDebugSnapshot,
    );
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _presenceHeartbeatQueued = false;
    _presenceRequestRunning = false;
    _presenceRequestStartedAtMs = 0;
    _lastPresenceRequestAtMs = 0;
    _lastPresenceSuccessAtMs = 0;
    _lastPresenceBodyKey = '';
  }

  Future<void> markUserOffline({
    int? livestreamId,
    String? role,
    int? seatNo,
  }) async {
    final uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (uid <= 0) return;

    final sid = livestreamId ?? _presenceStreamId;
    final outgoingRole = (role ?? _presenceRole).toLowerCase().trim();

    try {
      await dio.post(
        '$kMainUrl/user/offline',
        data: _presenceBody(
          userId: uid,
          livestreamId: sid > 0 ? sid : null,
          role: outgoingRole,
          isOnSeat: outgoingRole == 'caller' || outgoingRole == 'host',
          seatNo: seatNo ?? _presenceSeatNo,
        ),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
    } catch (e) {
      liveLog('⚠️ User offline failed safely: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchPresenceWithLiveState({
    int? livestreamId,
  }) async {
    final uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (uid <= 0) return null;

    final sid = livestreamId ?? _presenceStreamId;
    final url = sid > 0
        ? '$kMainUrl/user/presence/$uid?livestream_id=$sid'
        : '$kMainUrl/user/presence/$uid';

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      final dynamic fetchedLastPingAt = LiveTestingLogger.findFirstByKeys(
        response.data,
        const <String>[
          'last_ping_at',
          'last_ping',
          'ping_at',
          'last_seen_at',
        ],
      );
      LiveTestingLogger.printBlock('LIVE TEST PRESENCE FETCH RESULT', {
        'url': url,
        'status_code': response.statusCode,
        'last_ping_at': fetchedLastPingAt,
        'last_ping_age_seconds':
        LiveTestingLogger.ageSeconds(fetchedLastPingAt),
        'response': response.data,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        }

        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data as Map);
        }
      }
    } catch (e) {
      liveLog('⚠️ Presence/live state fetch failed safely: $e');
    }

    return null;
  }

  /// ===================== NORMAL / PK AGORA SESSION =====================
  /// PK start hole normal live channel/token save kore rakha hobe.
  /// PK end hole abar normal live channel e fire jawa jabe.
  String _normalAgoraChannelName = '';
  String _normalAgoraToken = '';
  bool _normalAgoraWasBroadcaster = false;

  final RxString pkChannelName = ''.obs;
  final RxString pkSenderRoomId = ''.obs;
  final RxString pkReceiverRoomId = ''.obs;
  final RxBool pkAgoraJoining = false.obs;

  String get normalAgoraChannelName => _normalAgoraChannelName;
  String get normalAgoraToken => _normalAgoraToken;
  bool get normalAgoraWasBroadcaster => _normalAgoraWasBroadcaster;

  void saveNormalLiveAgoraSession({
    required String channelName,
    required String token,
    required bool isBroadcaster,
  }) {
    if (channelName.trim().isEmpty) return;

    _normalAgoraChannelName = channelName;
    _normalAgoraToken = token;
    _normalAgoraWasBroadcaster = isBroadcaster;

    liveLog(
      '✅ Normal Agora session saved => channel=$channelName broadcaster=$isBroadcaster',
    );
  }

  void clearPkAgoraSession() {
    pkChannelName.value = '';
    pkSenderRoomId.value = '';
    pkReceiverRoomId.value = '';
    pkAgoraJoining.value = false;
    _processedPkGiftScoreEventKeys.clear();
  }

  /// ✅ PK channel + state sync helper.
  /// Backend/list/ws different key dite pare: channel_name / pk_channel_name / pk_channel.
  /// Wrong channel e join korle PK camera/audio ashe na, tai sob key support kora holo.
  String _firstCleanStringFromMaps(
      List<Map<String, dynamic>> maps,
      List<String> keys,
      ) {
    for (final map in maps) {
      if (map.isEmpty) continue;
      for (final key in keys) {
        final raw = map[key];
        final value = raw?.toString().trim() ?? '';
        if (value.isNotEmpty && value != 'null') return value;
      }
    }
    return '';
  }

  bool _isRealPkAgoraChannel(String value) {
    final channel = value.trim();
    // Real PK channel format: pk_<senderLiveId>_<receiverLiveId>_<timestamp>
    // Numeric room channels like 101010/100550 must NOT be used as PK channel.
    return channel.startsWith('pk_') && channel.split('_').length >= 4;
  }

  String _extractPkChannelFromMaps(List<Map<String, dynamic>> maps) {
    // 1) Strong PK-specific keys first.
    for (final map in maps) {
      if (map.isEmpty) continue;
      for (final key in const [
        'pk_channel_name',
        'pk_channel',
        'pk_agora_channel',
        'pk_room_channel',
        'agora_channel_name',
      ]) {
        final value = map[key]?.toString().trim() ?? '';
        if (_isRealPkAgoraChannel(value)) return value;
      }
    }

    // 2) channel_name is safe only when it is the real PK channel.
    for (final map in maps) {
      final value = map['channel_name']?.toString().trim() ?? '';
      if (_isRealPkAgoraChannel(value)) return value;
    }

    // Important: never return normal room_id/channel like 101010 as PK channel.
    return '';
  }

  /// ✅ Used when user enters PK live directly from PK list.
  /// This keeps normal single-live untouched, but if initial data is PK then
  /// controller gets pk_id/channel/sender/receiver before Agora watcher runs.
  void syncPkStateFromLiveData(
      Map<String, dynamic> raw, {
        String source = 'initial_pk_state',
      }) {
    try {
      final Map<String, dynamic> root = Map<String, dynamic>.from(raw);
      final Map<String, dynamic> data = _asMap(root['data']).isNotEmpty
          ? _asMap(root['data'])
          : root;
      final Map<String, dynamic> pkRoom = _asMap(
        root['pk_room'] ?? data['pk_room'],
      );
      final Map<String, dynamic> senderLive = _asMap(
        root['sender_livestream'] ??
            data['sender_livestream'] ??
            root['sender_live'] ??
            data['sender_live'],
      );
      final Map<String, dynamic> receiverLive = _asMap(
        root['receiver_livestream'] ??
            data['receiver_livestream'] ??
            root['receiver_live'] ??
            data['receiver_live'],
      );

      final bool looksPk =
          root['is_pk_room'] == true ||
              root['is_real_pk_room'] == true ||
              root['is_pk'] == true ||
              root['is_pk'] == 1 ||
              '${root['stream_type'] ?? data['stream_type']}'.toLowerCase() ==
                  'pk' ||
              _toInt(
                root['pk_id'] ??
                    data['pk_id'] ??
                    pkRoom['pk_id'] ??
                    pkRoom['id'],
              ) >
                  0 ||
              senderLive.isNotEmpty ||
              receiverLive.isNotEmpty;

      if (!looksPk) return;

      final String channel = _extractPkChannelFromMaps([
        root,
        data,
        pkRoom,
        senderLive,
        receiverLive,
      ]);

      final int pkId = _toInt(
        root['pk_id'] ?? data['pk_id'] ?? pkRoom['pk_id'] ?? pkRoom['id'],
      );
      final int senderStream = _toInt(
        root['sender_livestream_id'] ??
            root['pk_sender_livestream_id'] ??
            data['sender_livestream_id'] ??
            data['pk_sender_livestream_id'] ??
            senderLive['id'],
      );
      final int receiverStream = _toInt(
        root['receiver_livestream_id'] ??
            root['pk_receiver_livestream_id'] ??
            data['receiver_livestream_id'] ??
            data['pk_receiver_livestream_id'] ??
            receiverLive['id'],
      );
      final int senderHost = _toInt(
        root['sender_host_id'] ??
            root['pk_sender_host_id'] ??
            data['sender_host_id'] ??
            data['pk_sender_host_id'] ??
            senderLive['user_id'] ??
            senderLive['owner_user_id'] ??
            senderLive['current_host_id'],
      );
      final int receiverHost = _toInt(
        root['receiver_host_id'] ??
            root['pk_receiver_host_id'] ??
            data['receiver_host_id'] ??
            data['pk_receiver_host_id'] ??
            receiverLive['user_id'] ??
            receiverLive['owner_user_id'] ??
            receiverLive['current_host_id'],
      );

      if (pkId > 0) currentPkId.value = pkId;
      if (senderStream > 0) pkSenderLivestreamId.value = senderStream;
      if (receiverStream > 0) pkReceiverLivestreamId.value = receiverStream;
      if (senderHost > 0) pkSenderHostId.value = senderHost;
      if (receiverHost > 0) pkReceiverHostId.value = receiverHost;
      if (channel.isNotEmpty) {
        pkChannelName.value = channel;
      } else if (pkChannelName.value.trim().isEmpty) {
        liveLog(
          '⚠️ PK state sync skipped channel update [$source]: real pk channel missing',
        );
      }

      final int senderScore = _toInt(
        root['sender_score'] ?? data['sender_score'],
      );
      final int receiverScore = _toInt(
        root['receiver_score'] ?? data['receiver_score'],
      );
      if (senderScore > 0 || pkSenderScore.value <= 0)
        pkSenderScore.value = senderScore;
      if (receiverScore > 0 || pkReceiverScore.value <= 0)
        pkReceiverScore.value = receiverScore;

      if (senderLive.isNotEmpty) _pkSenderLiveData.value = senderLive;
      if (receiverLive.isNotEmpty) _pkReceiverLiveData.value = receiverLive;

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
        '✅ PK state synced [$source] => pk=${currentPkId.value} '
            'channel=${pkChannelName.value} senderLive=${pkSenderLivestreamId.value} '
            'receiverLive=${pkReceiverLivestreamId.value}',
      );
    } catch (e) {
      liveLog('⚠️ syncPkStateFromLiveData failed [$source] => $e');
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value == null) return [];
    return [value];
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  bool _isCurrentUserCall(dynamic raw, int currentUserId) {
    final call = _asMap(raw);
    if (call.isEmpty || currentUserId <= 0) return false;

    final user = _asMap(call['user']);
    final caller = _asMap(call['caller']);

    final ids = <int>{
      _toInt(call['caller_id']),
      _toInt(call['user_id']),
      _toInt(call['viewer_id']),
      _toInt(user['id']),
      _toInt(user['user_id']),
      _toInt(caller['id']),
      _toInt(caller['user_id']),
    };

    return ids.contains(currentUserId);
  }

  void _clearCurrentUserSeatLocal({
    String reason = 'seat_state_mismatch',
    int? seatNo,
  }) {
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId <= 0) return;

    final beforeLive = websocketController.liveCallList.length;
    final beforePending = websocketController.pendingCall.length;

    int oldSeatNo = seatNo ?? 0;
    if (oldSeatNo <= 0) {
      for (final item in websocketController.liveCallList) {
        if (_isCurrentUserCall(item, currentUserId)) {
          oldSeatNo = _seatNoFromCall(item) ?? 0;
          break;
        }
      }
    }

    websocketController.liveCallList.removeWhere(
          (call) => _isCurrentUserCall(call, currentUserId),
    );
    websocketController.pendingCall.removeWhere(
          (call) => _isCurrentUserCall(call, currentUserId),
    );

    if (oldSeatNo > 0) {
      websocketController.lockedSeatMap.remove(oldSeatNo);
      try {
        websocketController.lockedSeatMap.refresh();
      } catch (_) {}
    }

    /// Privacy rule: once the current user is no longer on a seat, the local
    /// microphone must become muted immediately. Keeping mute=false here allowed
    /// Agora to continue publishing the user's voice after a timeout/seat drop,
    /// including while the app was in the background.
    websocketController.audioMutedUserMap[currentUserId] = true;
    mute.value = true;
    isMuted.value = true;
    isAudioEnabled.value = false;

    /// Stop the Agora microphone as well as updating the UI state. This method
    /// is intentionally fire-and-forget because the local seat snapshot cleanup
    /// itself is synchronous.
    unawaited(
      websocketController.deactivateLocalCallerMediaForLeave(currentUserId),
    );
    websocketController.liveCallList.refresh();
    websocketController.pendingCall.refresh();
    websocketController.lockedSeatMap.refresh();
    websocketController.audioMutedUserMap.refresh();

    _presenceRole = 'viewer';
    _presenceIsOnSeat = false;
    _presenceSeatNo = null;

    liveLog(
      '🧹 Current user stale seat cleared => user:$currentUserId seat:$oldSeatNo '
          'live:$beforeLive->${websocketController.liveCallList.length} '
          'pending:$beforePending->${websocketController.pendingCall.length} reason:$reason',
    );
  }

  void _reconcileSelfSeatFromAvailableSeats(Map<String, dynamic> seatsData) {
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (currentUserId <= 0) return;

    final int localSeat = currentUserSeatNo(ignorePresence: true);
    if (localSeat <= 0) return;

    final occupied = _asList(
      seatsData['occupied_seats'],
    ).map(_toInt).where((e) => e > 0).toSet();

    if (occupied.contains(localSeat)) {
      return;
    }

    /*
    |--------------------------------------------------------------------------
    | available_seats is not enough to remove the current user
    |--------------------------------------------------------------------------
    | It may be a delayed snapshot. Verify the call list and repair heartbeat.
    |--------------------------------------------------------------------------
    */
    liveLog(
      '🛡️ Seat snapshot temporarily misses local seat=$localSeat; verifying',
    );

    Future.microtask(() async {
      _presenceRole = 'caller';
      _presenceIsOnSeat = true;
      _presenceSeatNo = localSeat;

      await sendPresenceHeartbeatOnce(
        livestreamId: _presenceStreamId,
        role: 'caller',
        isOnSeat: true,
        seatNo: localSeat,
      );

      if (_presenceStreamId > 0) {
        await tryToGetCallList(streamId: _presenceStreamId);
      }
    });
  }

  int? _seatNoFromCall(dynamic raw) {
    final call = _asMap(raw);
    final seat = call['seat_no'] ?? call['seat'] ?? call['seat_number'];
    final parsed = int.tryParse(seat?.toString() ?? '');
    return parsed == 0 ? null : parsed;
  }

  bool _isAcceptedCaller(Map<String, dynamic> call) {
    final status = (call['call_status'] ?? call['status'] ?? 'accepted')
        .toString()
        .toLowerCase()
        .trim();

    return status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'live' ||
        status == 'on_seat';
  }

  Map<String, dynamic> _callerAsViewerRow(Map<String, dynamic> caller) {
    final user = caller['user'] is Map
        ? Map<String, dynamic>.from(caller['user'])
        : <String, dynamic>{};

    final int userId = _toInt(
      caller['caller_id'] ?? caller['user_id'] ?? user['id'] ?? user['user_id'],
    );

    if (userId <= 0) {
      return <String, dynamic>{};
    }

    final Map<String, dynamic> normalizedUser = <String, dynamic>{
      ...user,
      'id': userId,
    };

    return <String, dynamic>{
      'livestream_id': caller['livestream_id'] ?? streamId.value,
      'viewer_id': userId,
      'user_id': userId,
      'is_active': true,
      'is_seated': true,
      'seat_no': caller['seat_no'],
      'call_status': caller['call_status'],
      'user': normalizedUser,
    };
  }

  void _mergeAcceptedCallersIntoViewerList(
      Iterable<Map<String, dynamic>> callers, {
        String source = 'caller_merge',
      }) {
    int merged = 0;

    for (final caller in callers) {
      if (!_isAcceptedCaller(caller)) continue;

      final viewerRow = _callerAsViewerRow(caller);
      if (viewerRow.isEmpty) continue;

      addOrUpdateViewerLocal(viewerRow, force: true);
      merged++;
    }

    liveLog(
      '✅ Room members merged into viewer list '
          '=> source=$source callers=$merged '
          'viewerTotal=${liveViewerList.length}',
    );
  }

  bool _stateExplicitlyClearsRoom(
      Map<String, dynamic> state,
      Map<String, dynamic> livestream,
      ) {
    final String status =
    (state['live_status'] ??
        livestream['live_status'] ??
        state['status'] ??
        '')
        .toString()
        .toLowerCase()
        .trim();

    return state['room_ended'] == true ||
        state['live_ended'] == true ||
        state['clear_callers'] == true ||
        state['clear_viewers'] == true ||
        status == 'ended' ||
        status == 'closed';
  }

  Future<void> applyLivestreamState(dynamic rawState) async {
    final state = _asMap(rawState);
    if (state.isEmpty) return;

    final livestream = _asMap(state['livestream']);

    final bool hasViewerList =
        state.containsKey('viewers') ||
            state.containsKey('livestream_viewers') ||
            livestream.containsKey('viewers') ||
            livestream.containsKey('livestream_viewers');

    final bool hasCallerList =
        state.containsKey('callers') ||
            state.containsKey('livestream_callers') ||
            livestream.containsKey('callers') ||
            livestream.containsKey('livestream_callers');

    final viewers = _asList(
      state['viewers'] ??
          state['livestream_viewers'] ??
          livestream['viewers'] ??
          livestream['livestream_viewers'],
    );

    final callersRaw = _asList(
      state['callers'] ??
          state['livestream_callers'] ??
          livestream['callers'] ??
          livestream['livestream_callers'],
    );

    final callers = callersRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isAcceptedCaller)
        .toList();

    final lockedSeats = _asList(
      state['locked_seats'] ??
          livestream['locked_seats'] ??
          state['lockedSeats'] ??
          livestream['lockedSeats'],
    );

    final bool explicitClear = _stateExplicitlyClearsRoom(state, livestream);

    /*
    |--------------------------------------------------------------------------
    | Viewer list authority
    |--------------------------------------------------------------------------
    | A non-empty explicit list may replace local viewers.
    | Empty/partial resume snapshots must never wipe a currently populated list.
    |--------------------------------------------------------------------------
    */
    if (hasViewerList && viewers.isNotEmpty) {
      viewerState.replaceAll(viewers);
    } else if (hasViewerList && explicitClear) {
      viewerState.clear();
    } else if (hasViewerList && viewers.isEmpty) {
      liveLog(
        '🛡️ Empty viewer snapshot ignored '
            '=> keep=${liveViewerList.length}',
      );
    }

    /*
    |--------------------------------------------------------------------------
    | Caller/seat list authority
    |--------------------------------------------------------------------------
    | Never clear 10-15 active seats because one temporary presence snapshot
    | returned callers=[] during resume/network latency.
    |--------------------------------------------------------------------------
    */
    if (hasCallerList && callers.isNotEmpty) {
      _mergeAcceptedCallListSafely(callers);

      websocketController.pendingCall.removeWhere((raw) {
        if (raw is! Map) return false;

        final status = (raw['call_status'] ?? raw['status'] ?? '')
            .toString()
            .toLowerCase();

        return status == 'accepted' ||
            status == 'joined' ||
            status == 'active' ||
            status == 'live';
      });
      websocketController.pendingCall.refresh();
    } else if (hasCallerList && explicitClear) {
      callList.clear();
      callList.refresh();
      websocketController.liveCallList.clear();
      websocketController.liveCallList.refresh();
    } else if (hasCallerList && callers.isEmpty) {
      liveLog(
        '🛡️ Empty caller snapshot ignored '
            '=> keep=${websocketController.liveCallList.length}',
      );
    }

    /*
    |--------------------------------------------------------------------------
    | Unified room-member list
    |--------------------------------------------------------------------------
    | Viewer API rows and active seat callers are different backend relations.
    | The visible viewer/member popup should contain both, deduped by user id.
    |--------------------------------------------------------------------------
    */
    final currentCallers = websocketController.liveCallList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isAcceptedCaller)
        .toList();

    _mergeAcceptedCallersIntoViewerList(
      currentCallers,
      source: 'apply_livestream_state',
    );

    if (lockedSeats.isNotEmpty) {
      websocketController.lockedSeatMap.clear();

      for (final item in lockedSeats) {
        final seatNo = item is Map
            ? _toInt(item['seat_no'] ?? item['seat'])
            : _toInt(item);

        if (seatNo > 0) {
          websocketController.lockedSeatMap[seatNo] = true;
        }
      }

      websocketController.lockedSeatMap.refresh();
    }

    try {
      websocketController.syncRoomSnapshotForLateJoin(
        Map<String, dynamic>.from(state),
        source: 'livestream_controller_apply_state',
      );
    } catch (e) {
      liveLog(
        '⚠️ syncRoomSnapshotForLateJoin skipped '
            'from applyLivestreamState: $e',
      );
    }

    final int sid = livestream.isNotEmpty
        ? _toInt(livestream['id'] ?? livestream['livestream_id'])
        : _toInt(state['livestream_id'] ?? state['stream_id'] ?? state['id']);

    if (sid > 0) {
      streamId.value = sid;
      websocketController.streamID.value = sid;
    }

    liveLog(
      '✅ Stable live state applied '
          '=> viewers=${liveViewerList.length} '
          'callers=${websocketController.liveCallList.length} '
          'incomingViewers=${viewers.length} '
          'incomingCallers=${callers.length} '
          'locks=${lockedSeats.length}',
    );
  }

  final Map<int, Future<void>> _roomWarmStateInFlight = {};
  final Map<int, DateTime> _roomWarmStateLastDoneAt = <int, DateTime>{};
  static const Duration _roomWarmStateCooldown = Duration(milliseconds: 2500);

  Future<void> warmLiveRoomStateFast({
    required int streamId,
    String source = 'manual',
  }) {
    if (streamId <= 0) return Future<void>.value();

    final lastDone = _roomWarmStateLastDoneAt[streamId];
    if (lastDone != null &&
        DateTime.now().difference(lastDone) < _roomWarmStateCooldown &&
        !source.toLowerCase().contains('force')) {
      liveLog(
        '⚡ Warm room state cooldown skipped => stream=$streamId source=$source',
      );
      return Future<void>.value();
    }

    final running = _roomWarmStateInFlight[streamId];
    if (running != null) {
      liveLog(
        '♻️ Warm room state already running => stream=$streamId source=$source',
      );
      return running;
    }

    final future =
    Future.wait([
      tryToGetCallList(streamId: streamId),
      showLiveViewerListList(streamId: streamId),
      getAvailableSeats(streamId),
    ])
        .then((_) {
      _roomWarmStateLastDoneAt[streamId] = DateTime.now();
      liveLog(
        '✅ Warm room state done => stream=$streamId source=$source',
      );
    })
        .catchError((Object e) {
      liveLog(
        '⚠️ Warm room state failed safely => stream=$streamId source=$source error=$e',
      );
    })
        .whenComplete(() {
      _roomWarmStateInFlight.remove(streamId);
    });

    _roomWarmStateInFlight[streamId] = future;
    return future;
  }

  final Map<int, Future<void>> _roomRealtimeRefreshInFlight =
  <int, Future<void>>{};
  final Map<int, DateTime> _roomRealtimeRefreshLastAt = <int, DateTime>{};
  static const Duration _roomRealtimeRefreshCooldown = Duration(
    milliseconds: 1800,
  );

  Future<void> refreshLiveRoomRealtimeState({
    required int streamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) async {
    if (streamId <= 0) return;

    final last = _roomRealtimeRefreshLastAt[streamId];
    if (last != null &&
        DateTime.now().difference(last) < _roomRealtimeRefreshCooldown) {
      liveLog('⚡ Realtime room refresh cooldown skipped => stream:$streamId');
      return;
    }

    final running = _roomRealtimeRefreshInFlight[streamId];
    if (running != null) {
      liveLog('♻️ Realtime room refresh joined in-flight => stream:$streamId');
      return running;
    }

    final future = _refreshLiveRoomRealtimeStateNetwork(
      streamId: streamId,
      role: role,
      isOnSeat: isOnSeat,
      seatNo: seatNo,
    );
    _roomRealtimeRefreshInFlight[streamId] = future;

    try {
      await future;
      _roomRealtimeRefreshLastAt[streamId] = DateTime.now();
    } finally {
      _roomRealtimeRefreshInFlight.remove(streamId);
    }
  }

  Future<void> _refreshLiveRoomRealtimeStateNetwork({
    required int streamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) async {
    if (streamId <= 0) return;

    await sendPresenceHeartbeatOnce(
      livestreamId: streamId,
      role: role ?? _presenceRole,
      isOnSeat: isOnSeat ?? _presenceIsOnSeat,
      seatNo: seatNo ?? _presenceSeatNo,
    );

    final response = await fetchPresenceWithLiveState(livestreamId: streamId);
    final data = _asMap(response?['data']);
    final liveState = data['livestream_state'];

    if (liveState != null) {
      await applyLivestreamState(liveState);

      /*
      | Presence live_state can be partial. Always reconcile callers/viewers
      | with their dedicated endpoints, but the non-destructive guards above
      | preserve last-good state if one endpoint temporarily fails.
      */
      await Future.wait([
        tryToGetCallList(streamId: streamId),
        showLiveViewerListList(streamId: streamId),
        getAvailableSeats(streamId),
      ]);
      return;
    }

    /// Fallback for old backend response / temporary API issue.
    await Future.wait([
      tryToGetCallList(streamId: streamId),
      showLiveViewerListList(streamId: streamId),
      getAvailableSeats(streamId),
    ]);
  }

  void lastPingUpdate({required int id}) {
    if (id <= 0) {
      liveLog('⚠️ Ping skipped: invalid stream id $id');
      return;
    }

    streamId.value = id;
    _pingTimer?.cancel();
    _pingTimer = null;

    lastPingOnce(id: id);

    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await lastPingOnce(id: id);
    });
  }

  Future<void> lastPingOnce({required int id}) async {
    if (id <= 0) return;

    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    _lastPermanentPingRequestAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastPermanentPingError = '';
    final Stopwatch permanentPingStopwatch = Stopwatch()..start();
    LiveTestingLogger.printBlock('LIVE TEST PERMANENT PING REQUEST', {
      'time': DateTime.now().toIso8601String(),
      'stream_id': id,
      'user_id': userId,
      'url': kPermanentRoomHeartbeatUrl(id),
    });
    try {
      final response = await dio.post(
        kPermanentRoomHeartbeatUrl(id),
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      _lastPermanentPingStatusCode = response.statusCode;
      _lastPermanentPingResponseData = response.data;
      final dynamic permanentLastPingAt = LiveTestingLogger.findFirstByKeys(
        response.data,
        const <String>[
          'last_ping_at',
          'last_ping',
          'ping_at',
          'last_seen_at',
        ],
      );
      LiveTestingLogger.printBlock('LIVE TEST PERMANENT PING RESPONSE', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'status_code': response.statusCode,
        'last_ping_at': permanentLastPingAt,
        'last_ping_age_seconds':
        LiveTestingLogger.ageSeconds(permanentLastPingAt),
        'response': response.data,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastPermanentPingSuccessAtMs =
            DateTime.now().millisecondsSinceEpoch;
        liveLog('✅ Permanent room heartbeat ok => stream=$id');
        return;
      }

      if (response.statusCode != 404 && response.statusCode != 405) {
        _lastPermanentPingError = 'HTTP ${response.statusCode}';
        liveLog('⚠️ Permanent heartbeat failed: ${response.statusCode}');
        return;
      }
    } catch (e, st) {
      _lastPermanentPingError = e.toString();
      LiveTestingLogger.printBlock('LIVE TEST PERMANENT PING ERROR', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
      liveLog('⚠️ Permanent heartbeat fallback requested: $e');
    }

    // Backward-compatible fallback while an older backend is still deployed.
    try {
      final response = await dio.get(
        lastPingUpdateUrl(id),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      _lastPermanentPingStatusCode = response.statusCode;
      _lastPermanentPingResponseData = response.data;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _lastPermanentPingSuccessAtMs =
            DateTime.now().millisecondsSinceEpoch;
      }
      LiveTestingLogger.printBlock('LIVE TEST LEGACY LAST PING RESPONSE', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'status_code': response.statusCode,
        'response': response.data,
      });
      liveLog('ℹ️ Legacy heartbeat status => ${response.statusCode}');
    } catch (e, st) {
      _lastPermanentPingError = e.toString();
      LiveTestingLogger.printBlock('LIVE TEST LEGACY LAST PING ERROR', {
        'elapsed_ms': permanentPingStopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'stack_trace': st.toString(),
      });
      liveLog('⚠️ Legacy lastPing ignored safely: $e');
    } finally {
      permanentPingStopwatch.stop();
      LiveTestingLogger.line(
        '💗 LIVE TEST PERMANENT PING COMPLETE => stream=$id '
            'elapsed=${permanentPingStopwatch.elapsedMilliseconds}ms '
            'status=$_lastPermanentPingStatusCode '
            'successAt=$_lastPermanentPingSuccessAtMs',
      );
    }
  }

  // Method to stop the ping timer
  void stopPingUpdate() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ✅ BATTERY OPTIMIZATION: Method to update ping interval based on battery level
  void updatePingInterval(Duration newInterval) {
    if (_pingTimer == null) return;

    final sid = streamId.value;
    if (sid <= 0) return;

    _pingTimer?.cancel();
    _pingTimer = null;

    _pingTimer = Timer.periodic(newInterval, (_) async {
      await lastPingOnce(id: sid);
    });

    liveLog('🔋 Legacy ping interval updated => ${newInterval.inSeconds}s');
  }

  Future<void> tryToGenerateToken({
    required roleId,
    required int userId,
    required String channelName,
  }) async {
    // ✅ uid আর channel_name আলাদা — uid = নিজের ID, channel = caller এর channel
    final data = {
      "channel_name": channelName, // caller এর channel (100290)
      "uid": userId, // নিজের uid (100534)
      "role": roleId,
    };

    try {
      liveLog('🔑 Token request - channel: $channelName, uid: $userId');
      final response = await dio.post(
        kAgoraTokenGenerateUrl,
        data: data,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        getTokens.value = response.data;
        liveLog("✅ Token generated: ${response.data}");
      } else {
        liveLog("⚠️ Token failed: ${response.statusCode} - ${response.data}");
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }

  ///--------------------------  show Viewer  list ----------------------
  final liveViewerList = [].obs;

  /// Professional viewer state manager.
  /// Every viewer add/remove/API sync should pass through this one source of truth.
  late final LiveViewerStateManager viewerState = LiveViewerStateManager(
    liveViewerList,
  );

  bool _viewerValueOk(dynamic value) {
    if (value == null) return false;
    final v = value.toString().trim();
    return v.isNotEmpty && v.toLowerCase() != 'null' && v != '0';
  }

  dynamic _viewerUserId(dynamic viewer) {
    if (viewer is! Map) return null;
    final user = viewer['user'] is Map
        ? Map<String, dynamic>.from(viewer['user'])
        : <String, dynamic>{};
    final nestedViewer = viewer['viewer'] is Map
        ? Map<String, dynamic>.from(viewer['viewer'])
        : <String, dynamic>{};
    final caller = viewer['caller'] is Map
        ? Map<String, dynamic>.from(viewer['caller'])
        : <String, dynamic>{};

    // viewer['id'] can be DB row id. Keep it as final fallback only.
    return viewer['viewer_id'] ??
        viewer['user_id'] ??
        viewer['caller_id'] ??
        user['id'] ??
        user['user_id'] ??
        nestedViewer['viewer_id'] ??
        nestedViewer['user_id'] ??
        nestedViewer['id'] ??
        caller['caller_id'] ??
        caller['user_id'] ??
        caller['id'] ??
        viewer['id'];
  }

  Map<String, dynamic> _mergeViewerWithExisting(dynamic viewer) {
    if (viewer is! Map) return <String, dynamic>{};
    final incoming = Map<String, dynamic>.from(viewer);
    final uid = _viewerUserId(incoming)?.toString();
    if (uid == null || uid.isEmpty || uid == '0' || uid == 'null') {
      return incoming;
    }

    Map<String, dynamic>? oldViewer;
    for (final item in liveViewerList) {
      if (item is! Map) continue;
      final oldId = _viewerUserId(item)?.toString();
      if (oldId == uid) {
        oldViewer = Map<String, dynamic>.from(item);
        break;
      }
    }

    if (oldViewer == null) return incoming;

    final oldUser = oldViewer['user'] is Map
        ? Map<String, dynamic>.from(oldViewer['user'])
        : <String, dynamic>{};
    final newUser = incoming['user'] is Map
        ? Map<String, dynamic>.from(incoming['user'])
        : <String, dynamic>{};

    final mergedUser = Map<String, dynamic>.from(oldUser);
    newUser.forEach((key, value) {
      if (_viewerValueOk(value) || value is Map || value is List) {
        mergedUser[key.toString()] = value;
      }
    });

    if (mergedUser.isNotEmpty) {
      incoming['user'] = mergedUser;
    }

    return {...oldViewer, ...incoming};
  }

  void addOrUpdateViewerLocal(dynamic viewer, {bool force = false}) {
    viewerState.addOrUpdate(_mergeViewerWithExisting(viewer), force: force);
  }

  void removeViewerLocal(dynamic userId) {
    viewerState.removeByUserId(userId);
  }

  void clearViewerLocal() {
    viewerState.clear();
  }

  void resetRoomRealtimeState({required int streamId, bool force = false}) {
    if (streamId <= 0) return;

    final int currentStream = int.tryParse(this.streamId.value.toString()) ?? 0;

    if (!force && currentStream == streamId) {
      liveLog('🛡️ Same-room realtime reset ignored => stream=$streamId');
      return;
    }

    clearViewerLocal();
    callList.clear();
    callList.refresh();

    websocketController.liveCallList.clear();
    websocketController.pendingCall.clear();
    websocketController.liveCallList.refresh();
    websocketController.pendingCall.refresh();

    websocketController.lockedSeatMap.clear();
    websocketController.lockedSeatMap.refresh();

    liveLog(
      '🧹 Local realtime room state reset '
          '=> old=$currentStream new=$streamId force=$force',
    );
  }

  Future<void> showLiveViewerListList({required int streamId}) async {
    if (streamId <= 0) return;

    try {
      final response = await dio.get(
        kLiveViewersList(streamId),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        liveLog('⚠️ Viewer list failed: ${response.statusCode}');
        return;
      }

      final dynamic raw = response.data;
      final Map<String, dynamic> root = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      dynamic rawViewers =
          root['viewers'] ??
              root['livestream_viewers'] ??
              (root['data'] is Map ? root['data']['viewers'] : null) ??
              (root['livestream'] is Map
                  ? root['livestream']['livestream_viewers']
                  : null);

      final List<dynamic> viewers = rawViewers is List
          ? List<dynamic>.from(rawViewers)
          : <dynamic>[];

      /*
      |--------------------------------------------------------------------------
      | Preserve last good viewers on temporary empty/partial responses
      |--------------------------------------------------------------------------
      */
      if (viewers.isNotEmpty) {
        viewerState.replaceAll(viewers);
      } else if (liveViewerList.isEmpty) {
        viewerState.replaceAll(viewers);
      } else {
        liveLog(
          '🛡️ Empty viewer API list ignored '
              '=> keep=${liveViewerList.length}',
        );
      }

      // Apply callers/locks too when this endpoint returns a full room snapshot.
      if (root.containsKey('livestream_callers') ||
          root.containsKey('callers') ||
          root.containsKey('locked_seats') ||
          root.containsKey('livestream')) {
        await applyLivestreamState(root);
      }

      _mergeAcceptedCallersIntoViewerList(
        websocketController.liveCallList.whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
        ),
        source: 'viewer_api_sync',
      );

      liveLog(
        '✅ Viewer/member list synced '
            '=> stream=$streamId total=${liveViewerList.length}',
      );
    } on DioException catch (e) {
      liveLog(
        '⚠️ Viewer list Dio error: ${e.response?.statusCode ?? e.message}',
      );
    } catch (e) {
      liveLog('⚠️ Viewer list sync failed safely: $e');
    }
  }

  ///--------------------------  show gitSent list ----------------------
  var seatCount = 5.obs;

  ///-------------------------- Red Packet delegates ----------------------
  /// Actual implementation is in red_packet_controller.dart.

  Future<bool> sendRedPacket({
    required double amount,
    int quantity = 10,
    int durationSeconds = 120,
    int openAfterSeconds = 30,
    bool? isGlobal,
    String? message,
  }) =>
      redPacketController.sendRedPacket(
        amount: amount,
        quantity: quantity,
        durationSeconds: durationSeconds,
        openAfterSeconds: openAfterSeconds,
        isGlobal: isGlobal,
        message: message,
      );

  Future<Map<String, dynamic>?> collectRedPacketData(int redPacketId) =>
      redPacketController.collectRedPacketData(redPacketId);

  Future<bool> collectRedPacket(String redPacketId) =>
      redPacketController.collectRedPacket(redPacketId);

  Future<List<Map<String, dynamic>>> getLivestreamRedPackets({
    required int livestreamId,
    String status = 'active',
    int perPage = 20,
  }) =>
      redPacketController.getLivestreamRedPackets(
        livestreamId: livestreamId,
        status: status,
        perPage: perPage,
      );

  //create live stream
  final createStreamData = {}.obs;
  final isCreatingLive = false.obs;
  final isPermanentRoomActionLoading = false.obs;

  /// True only while the current owner is permanently closing the room.
  /// WebSocket uses this flag to avoid routing the same device to Bottomnav
  /// before the REST close response opens the Endlive summary page.
  final isOwnerClosingPermanentRoom = false.obs;

  final lastPermanentRoomActionData = <String, dynamic>{}.obs;

  String resolvePermanentRoomChannel(
      dynamic payload, {
        int fallbackOwnerId = 0,
      }) {
    final root = _asMap(payload);
    final data = _asMap(root['data']);
    final live = {
      ..._asMap(data['livestreamdata']),
      ..._asMap(data['livestream']),
      ..._asMap(root['livestreamdata']),
      ..._asMap(root['livestream']),
    };

    // One permanent room must always use one stable Agora channel.
    // Existing production rooms already use owner/room_id (for example 100558).
    // Some rejoin responses returned live_<livestreamId>; preferring that value
    // split host and audience into different Agora channels.
    final candidates = <dynamic>[
      live['room_id'],
      live['channel_name'],
      root['room_id'],
      root['channel_name'],
      live['owner_user_id'],
      live['user_id'],
      fallbackOwnerId,
      root['agora_channel_name'],
      root['audience_join_agora_channel'],
      data['agora_channel_name'],
      live['agora_channel'],
      root['agora_channel'],
    ];

    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null' && value != '0') {
        return value;
      }
    }

    return '';
  }

  Map<String, dynamic> _normalizePermanentRoomResponse(
      dynamic responseData, {
        Map<String, dynamic>? fallbackLiveData,
      }) {
    final root = _asMap(responseData);
    final nestedData = _asMap(root['data']);
    final responseLive = {
      ...?fallbackLiveData,
      ..._asMap(nestedData['livestreamdata']),
      ..._asMap(nestedData['livestream']),
      ..._asMap(root['livestreamdata']),
      ..._asMap(root['livestream']),
    };

    if (responseLive.isNotEmpty) {
      root['livestreamdata'] = responseLive;
    }

    return root;
  }

  Future<bool> _openPermanentRoomAsHost({
    required Map<String, dynamic> responseMap,
    required int userId,
    bool preserveExistingMute = false,
    String? requestedStreamType,
    int? requestedSeatCount,
    int? requestedRoomLayout,
    int? requestedRoomTheme,
    int? requestedRoomBackground,
  }) async {
    final live = _asMap(responseMap['livestreamdata']);
    final int livestreamId = _toInt(live['id'] ?? live['livestream_id']);
    final String channelName = resolvePermanentRoomChannel(
      responseMap,
      fallbackOwnerId: userId,
    );

    if (livestreamId <= 0 || channelName.isEmpty) {
      Get.snackbar(
        ('Room Error').appTr,
        ('Permanent room ID or Agora channel is missing.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    bool mutedFromFields(dynamic audioOn, dynamic mutedRaw) {
      final String audio = audioOn?.toString().trim().toLowerCase() ?? '';
      final String muted = mutedRaw?.toString().trim().toLowerCase() ?? '';

      if (audio == '0' ||
          audio == 'false' ||
          audio == 'off' ||
          audio == 'mute' ||
          audio == 'muted') {
        return true;
      }
      if (audio == '1' ||
          audio == 'true' ||
          audio == 'on' ||
          audio == 'unmute' ||
          audio == 'unmuted') {
        return false;
      }
      return muted == '1' ||
          muted == 'true' ||
          muted == 'yes' ||
          muted == 'mute' ||
          muted == 'muted';
    }

    bool responseHostMuted = false;
    final dynamic originalCallersRaw = live['livestream_callers'];
    if (originalCallersRaw is List) {
      for (final raw in originalCallersRaw) {
        final Map<String, dynamic> call = _asMap(raw);
        final Map<String, dynamic> callUser = _asMap(call['user']);
        final int callerId = _toInt(
          call['caller_id'] ?? call['user_id'] ?? callUser['id'],
        );
        final bool isHostRow = callerId == userId ||
            call['is_broadcaster'] == true ||
            call['is_broadcaster'] == 1 ||
            call['is_broadcaster']?.toString() == '1';
        if (!isHostRow) continue;

        responseHostMuted = mutedFromFields(
          call['audio_on'] ??
              call['is_audio_on'] ??
              callUser['audio_on'] ??
              callUser['is_audio_on'],
          call['is_muted'] ??
              call['muted'] ??
              call['is_muted_by_host'] ??
              callUser['is_muted'] ??
              callUser['muted'],
        );
        break;
      }
    }

    final bool localHostMuted = mute.value == true ||
        websocketController.audioMutedUserMap[userId] == true;
    /// The server may mark an offline host row audio_on=0 simply because the
    /// host left the Agora channel. That is not always a manual mute. For a
    /// same-app permanent-room rejoin, the persistent local controller state is
    /// the safe source of the user's actual mute choice.
    final bool hostStartsMuted = preserveExistingMute && localHostMuted;
    final int restoredAudioOn = hostStartsMuted ? 0 : 1;

    live['id'] = livestreamId;
    live['livestream_id'] = livestreamId;
    live['room_id'] = channelName;
    live['channel_name'] = channelName;
    live['agora_channel'] = channelName;
    live['host_online'] = true;
    live['room_status'] = 'active';

    // A closed/left room can contain an offline broadcaster row with
    // audio_on=0. Fresh create starts unmuted; same-session rejoin uses the
    // preserved local manual mute choice resolved above.
    final dynamic callersRaw = live['livestream_callers'];
    if (callersRaw is List) {
      live['livestream_callers'] = callersRaw.map((raw) {
        final call = _asMap(raw);
        final callUser = _asMap(call['user']);
        final callerId = _toInt(
          call['caller_id'] ?? call['user_id'] ?? callUser['id'],
        );
        if (callerId == userId ||
            call['is_broadcaster'] == true ||
            call['is_broadcaster'] == 1) {
          call['caller_id'] = userId;
          call['seat_no'] = 1;
          call['call_status'] = 'accepted';
          call['is_broadcaster'] = true;
          call['audio_on'] = restoredAudioOn;
          call['is_audio_on'] = restoredAudioOn;
          call['is_muted'] = hostStartsMuted ? 1 : 0;
          call['is_muted_by_host'] = 0;
          call['is_active'] = 1;
        }
        return call;
      }).toList();
    }

    responseMap['livestreamdata'] = live;
    responseMap['agora_channel_name'] = channelName;
    responseMap['room_id'] = channelName;
    responseMap['channel_name'] = channelName;

    final String backgroundRaw =
    (live['room_background_image'] ??
        live['background_image'] ??
        live['stream_image'] ??
        '')
        .toString()
        .trim();
    final BuildContext? prefetchContext = Get.context;
    if (backgroundRaw.isNotEmpty &&
        backgroundRaw != 'null' &&
        prefetchContext != null) {
      final String backgroundUrl = ImageHelper.getImageUrl(backgroundRaw);
      if (backgroundUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(
            backgroundUrl,
            cacheKey: backgroundUrl,
            maxWidth: 1080,
            maxHeight: 1920,
          ),
          prefetchContext,
        ).ignore();
      }
    }

    /// Clear old room-scoped lists first, then restore this room's host mute.
    /// Doing it in the opposite order made resetAudioRoomStateForStream() erase
    /// the rejoin mute state and produced an unmuted icon with a silent Agora mic.
    websocketController.resetAudioRoomStateForStream(
      newStreamId: livestreamId,
      force: true,
    );

    mute.value = hostStartsMuted;
    isMuted.value = hostStartsMuted;
    isAudioEnabled.value = !hostStartsMuted;
    websocketController.audioMutedUserMap[userId] = hostStartsMuted;
    websocketController.audioMutedUserMap.refresh();

    liveLog(
      '🎙️ Permanent room host mute restored => stream=$livestreamId '
          'rejoin=$preserveExistingMute local=$localHostMuted '
          'response=$responseHostMuted muted=$hostStartsMuted',
    );
    createStreamData.value = responseMap;
    isHost.value = true;
    isBroadcaster.value = true;
    streamId.value = livestreamId;
    websocketController.streamID.value = livestreamId;

    selectedMusicPath.value = '';
    liveMusicName.value = '';
    liveMusicStatus.value = 'stopped';
    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';

    websocketController.liveCallList.clear();
    dynamic broadcasterCall = responseMap['broadcaster_call_data'];
    if (broadcasterCall == null && live['livestream_callers'] is List) {
      final callers = List<dynamic>.from(live['livestream_callers']);
      for (final raw in callers) {
        final call = _asMap(raw);
        final callerId = _toInt(
          call['caller_id'] ?? call['user_id'] ?? _asMap(call['user'])['id'],
        );
        if (callerId == userId ||
            call['is_broadcaster'] == true ||
            call['is_broadcaster'] == 1) {
          broadcasterCall = raw;
          break;
        }
      }
    }
    if (broadcasterCall != null) {
      final normalizedBroadcaster = _asMap(broadcasterCall);
      normalizedBroadcaster['caller_id'] = userId;
      normalizedBroadcaster['seat_no'] = 1;
      normalizedBroadcaster['call_status'] = 'accepted';
      normalizedBroadcaster['is_broadcaster'] = true;
      normalizedBroadcaster['audio_on'] = restoredAudioOn;
      normalizedBroadcaster['is_audio_on'] = restoredAudioOn;
      normalizedBroadcaster['is_muted'] = hostStartsMuted ? 1 : 0;
      normalizedBroadcaster['is_muted_by_host'] = 0;
      normalizedBroadcaster['is_active'] = 1;
      websocketController.liveCallList.add(normalizedBroadcaster);
      responseMap['broadcaster_call_data'] = normalizedBroadcaster;
    }

    final createdAt = (live['start_time'] ?? live['created_at'])?.toString();
    liveTimeCase(
      streamId: livestreamId,
      startTime: DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
    );

    final tokenReady = await agoraTokenController.tryToGenerateBroadcasterToken(
      isBroadcaster: true,
      userId: userId,
      channelName: channelName,
      streamId: livestreamId.toString(),
    );

    final token = agoraTokenController.getTokenString();
    if (!tokenReady || token.isEmpty) {
      Get.snackbar(
        ('Token Error').appTr,
        ('Could not generate the Agora broadcaster token.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    saveNormalLiveAgoraSession(
      channelName: channelName,
      token: token,
      isBroadcaster: true,
    );

    final String streamType =
    (requestedStreamType ?? live['stream_type'] ?? 'audio')
        .toString()
        .toLowerCase();
    final int safeSeatCount = requestedSeatCount ?? _toInt(live['seat_count']);
    final int safeLayout = requestedRoomLayout ?? _toInt(live['room_layout']);
    final int safeTheme = requestedRoomTheme ?? _toInt(live['room_theme']);
    final int safeBackground =
        requestedRoomBackground ?? _toInt(live['room_background'] ?? -1);

    if (kDebugMode) {
      debugPrint('create_navigation=${DateTime.now().microsecondsSinceEpoch}');
    }
    if (streamType == 'audio') {
      clearMinimizedVideoLiveSession();
      // await AgoraService().prepareAudioOnlyMode(
      //   reason: 'open_audio_room',
      // );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      Get.to(
            () => AudioLiveView(
          channelName: channelName,
          isBroadcaster: true,
          token: token,
          seatCount: safeSeatCount > 0 ? safeSeatCount : seatCount.value,
          roomLayout: safeLayout,
          roomTheme: safeTheme,
          roomBackground: safeBackground,
        ),
        arguments: responseMap,
      );
    } else if (streamType == 'multi') {
      Get.to(
            () => MultiLiveView(
          channelName: channelName,
          isBroadcaster: true,
          token: token,
          seatCount: safeSeatCount > 0 ? safeSeatCount : seatCount.value,
        ),
        arguments: responseMap,
      );
    } else if (streamType == 'popular' || streamType == 'video') {
      Get.to(
            () => PopularLiveView(
          channelName: channelName,
          isBroadcaster: true,
          token: token,
        ),
        arguments: responseMap,
      );
    } else {
      Get.snackbar(
        ('Unsupported Room').appTr,
        ('This permanent-room rejoin flow supports audio, multi and popular rooms.')
            .appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  Future<Map<String, dynamic>?> getMyPermanentRoom({
    required int userId,
    bool showNotFound = false,
  }) async {
    try {
      final response = await dio.get(
        kMyPermanentRoomUrl(userId),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }

      if (showNotFound) {
        Get.snackbar(('Room').appTr, ('Permanent room not found.').appTr);
      }
    } on DioException catch (e) {
      if (showNotFound && e.response?.statusCode != 404) {
        Get.snackbar(('Room Error').appTr, '${e.response?.data ?? e.message}');
      }
    } catch (e) {
      if (showNotFound) Get.snackbar(('Room Error').appTr, '$e');
    }
    return null;
  }

  Future<bool> _restartClosedPermanentRoom({
    required int userId,
    Map<String, dynamic>? fallbackLiveData,
  }) async {
    final live = _asMap(fallbackLiveData);
    final title = (live['stream_bte'] ?? live['title'] ?? 'Live Room')
        .toString()
        .trim();
    final announcement =
    (live['anousment'] ??
        live['announcement'] ??
        live['stream_title'] ??
        '')
        .toString()
        .trim();

    liveLog('♻️ Closed permanent room will be reopened through create API');

    return tryToCreateLivestream(
      streamTitle: title.isEmpty ? 'Live Room' : title,
      anousment: announcement,
      streamType: (live['stream_type'] ?? 'audio').toString(),
      userId: userId,
      seatCountValue: _toInt(live['seat_count']) > 0
          ? _toInt(live['seat_count'])
          : seatCount.value,
      roomLayout: _toInt(live['room_layout']),
      roomTheme: _toInt(live['room_theme']),
      roomBackground: live.containsKey('room_background')
          ? _toInt(live['room_background'])
          : -1,
      roomPassword: live['room_password']?.toString(),
    );
  }

  Future<bool> rejoinPermanentRoom({
    required int livestreamId,
    Map<String, dynamic>? fallbackLiveData,
  }) async {
    if (isPermanentRoomActionLoading.value || livestreamId <= 0) return false;

    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId <= 0) return false;

    isPermanentRoomActionLoading.value = true;
    try {
      final response = await dio.post(
        kJoinPermanentRoomUrl(livestreamId),
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        // A room explicitly closed by its owner cannot use the join endpoint.
        // Reopen the same permanent room through the create API instead.
        if (response.statusCode == 409 || response.statusCode == 410) {
          return _restartClosedPermanentRoom(
            userId: userId,
            fallbackLiveData: fallbackLiveData,
          );
        }

        Get.snackbar(
          ('Rejoin Failed').appTr,
          ('Could not rejoin this permanent room.').appTr,
        );
        return false;
      }

      final responseMap = _normalizePermanentRoomResponse(
        response.data,
        fallbackLiveData: fallbackLiveData,
      );
      lastPermanentRoomActionData.value = responseMap;

      return _openPermanentRoomAsHost(
        responseMap: responseMap,
        userId: userId,
        preserveExistingMute: true,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 || e.response?.statusCode == 410) {
        return _restartClosedPermanentRoom(
          userId: userId,
          fallbackLiveData: fallbackLiveData,
        );
      }

      final message = e.response?.data is Map
          ? '${e.response?.data['message'] ?? 'Permanent room rejoin failed'}'
          : 'Permanent room rejoin failed';
      Get.snackbar(
        ('Rejoin Failed').appTr,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e) {
      Get.snackbar(
        ('Rejoin Failed').appTr,
        '$e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isPermanentRoomActionLoading.value = false;
    }
  }

  Future<bool> leavePermanentRoom({required int livestreamId}) async {
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (livestreamId <= 0 || userId <= 0) return false;

    try {
      final response = await dio.post(
        kHostLeavePermanentRoomUrl(livestreamId),
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.data is Map) {
        lastPermanentRoomActionData.value = Map<String, dynamic>.from(
          response.data as Map,
        );
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      liveLog('⚠️ Permanent host leave API failed safely: $e');
      return false;
    }
  }

  Future<bool> closePermanentRoom({
    required int livestreamId,
    bool navigateToEnd = true,
  }) async {
    if (isPermanentRoomActionLoading.value) return false;

    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (livestreamId <= 0 || userId <= 0) {
      Get.snackbar(
        ('Close Failed').appTr,
        ('Invalid room or user information.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    isPermanentRoomActionLoading.value = true;
    isOwnerClosingPermanentRoom.value = true;

    try {
      final response = await dio.post(
        kOwnerClosePermanentRoomUrl(livestreamId),
        data: {'owner_user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final responseMap = _asMap(response.data);
        Get.snackbar(
          ('Close Failed').appTr,
          '${responseMap['message'] ?? 'Only the room owner can close this room.'}',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final Map<String, dynamic> rawResult = _asMap(response.data);
      final Map<String, dynamic> rawLiveData = _asMap(
        rawResult['livestream_data'],
      );
      final Map<String, dynamic> rawEndData = _asMap(
        rawResult['end_live_data'],
      );

      Map<String, dynamic> fallbackUser = <String, dynamic>{};
      try {
        final dynamic profileUser = authController.userProfile.value.user;
        fallbackUser = _asMap(profileUser?.toJson());
      } catch (_) {
        fallbackUser = <String, dynamic>{};
      }

      final Map<String, dynamic> responseUser = _asMap(
        rawLiveData['user'] ?? rawLiveData['User'] ?? rawResult['user'],
      );

      final Map<String, dynamic> safeUser = {...fallbackUser, ...responseUser};

      final Map<String, dynamic> safeLiveData = {
        ...rawLiveData,
        'id': rawLiveData['id'] ?? rawLiveData['livestream_id'] ?? livestreamId,
        'livestream_id':
        rawLiveData['livestream_id'] ?? rawLiveData['id'] ?? livestreamId,
        'user': safeUser,
        'live_duration_seconds':
        rawLiveData['live_duration_seconds'] ??
            rawEndData['live_duration_seconds'] ??
            elapsed.value,
      };

      final Map<String, dynamic> safeEndData = {
        ...rawEndData,
        'livestream_id': rawEndData['livestream_id'] ?? livestreamId,
        'gift_amount':
        rawEndData['gift_amount'] ??
            rawResult['gift_amount'] ??
            totalGiftCoins.value,
        'audience':
        rawEndData['audience'] ??
            rawResult['audience'] ??
            rawResult['viewer_count'] ??
            0,
      };

      final Map<String, dynamic> safeResult = {
        ...rawResult,
        'success': rawResult['success'] ?? true,
        'livestream_id': rawResult['livestream_id'] ?? livestreamId,
        'livestream_data': safeLiveData,
        'end_live_data': safeEndData,
        'new_followers': rawResult['new_followers'] ?? 0,
      };

      lastPermanentRoomActionData.value = safeResult;

      stopPingUpdate();
      stopLivePresenceHeartbeat();
      stopLive();
      isHost.value = false;
      isBroadcaster.value = false;
      websocketController.streamID.value = 0;
      websocketController.activeAudioStreamId.value = 0;

      if (navigateToEnd) {
        /// The owner-close WebSocket event can arrive before this REST response.
        /// WebSocket now skips its Bottomnav redirect while the flag above is true.
        /// A small microtask keeps GetX navigation deterministic.
        await Future<void>.delayed(const Duration(milliseconds: 80));

        Get.offAll(
              () => const Endlive(),
          arguments: safeResult,
          transition: Transition.cupertino,
        );
      }

      return true;
    } on DioException catch (e) {
      final responseMap = _asMap(e.response?.data);
      final message = '${responseMap['message'] ?? 'Room close failed'}';

      Get.snackbar(
        ('Close Failed').appTr,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e, st) {
      liveLog('❌ Permanent room close error => $e');
      liveLog('$st');

      Get.snackbar(
        ('Close Failed').appTr,
        ('Room close failed. Please try again.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isPermanentRoomActionLoading.value = false;

      /// Keep the protection alive briefly so a delayed live_ended socket
      /// event cannot replace Endlive with Bottomnav.
      Future<void>.delayed(const Duration(seconds: 2), () {
        isOwnerClosingPermanentRoom.value = false;
      });
    }
  }

  Future<bool> tryToCreateLivestream({
    required String streamTitle,
    String anousment = '',
    required String streamType,
    required int userId,
    int? seatCountValue,
    int roomLayout = 0,
    int roomTheme = 0,
    int roomBackground = -1,
    File? streamImageFile,
    String? roomPassword,
    int? roomLock,
    int? lockComent,
    int? hiddenRoom,
    int? screenRecords,
    int? screenshort,
  }) async {
    final Stopwatch createStopwatch = Stopwatch()..start();
    void timing(String label) {
      if (kDebugMode) {
        debugPrint('$label=${createStopwatch.elapsedMilliseconds}ms');
      }
    }

    timing('create_validation_done');

    liveLog('==================================================');
    liveLog('🚀 CREATE LIVE STREAM PROCESS STARTED');
    liveLog('==================================================');

    if (isCreatingLive.value) {
      liveLog('⚠️ Live stream creation already in progress.');
      return false;
    }

    isCreatingLive.value = true;
    debugPrint('LIVE_CREATE_START => type=$streamType');

    final selectedSeatCount = seatCountValue ?? seatCount.value;

    final safeStreamTitle = streamTitle.trim().isEmpty
        ? 'Live'
        : streamTitle.trim();

    final safeAnnouncement = anousment.trim();

    final String pickedImagePath =
        streamImageFile?.path ?? audioImage.value.trim();

    final String createLiveUrl = createLiveStream(userId);

    final data = <String, dynamic>{
      'stream_bte': safeStreamTitle,
      'stream_title': safeAnnouncement,
      'announcement': safeAnnouncement,
      'anousment': safeAnnouncement,
      'title': safeStreamTitle,
      'stream_coins': 0,
      'stream_type': streamType,
      'seat_count': selectedSeatCount,
      'gifts_coins': 0,
      'room_layout': roomLayout.toString(),
      'room_theme': roomTheme.toString(),
      'room_background': roomBackground.toString(),
      if (roomPassword != null && roomPassword.trim().isNotEmpty)
        'room_password': roomPassword.trim(),
    };

    try {
      liveLog('📌 Live create information:');
      liveLog('➡️ API URL: $createLiveUrl');
      liveLog('➡️ User ID: $userId');
      liveLog('➡️ Stream title: $safeStreamTitle');
      liveLog('➡️ Announcement: $safeAnnouncement');
      liveLog('➡️ Stream type: $streamType');
      liveLog('➡️ Seat count: $selectedSeatCount');
      liveLog('➡️ Room layout: $roomLayout');
      liveLog('➡️ Room theme: $roomTheme');
      liveLog('➡️ Room background: $roomBackground');
      liveLog(
        '➡️ Password provided: '
            '${roomPassword != null && roomPassword.trim().isNotEmpty}',
      );
      liveLog('➡️ Selected image path: $pickedImagePath');

      dynamic requestData;
      late Options requestOptions;

      final bool pathIsNotEmpty = pickedImagePath.trim().isNotEmpty;
      final File selectedImageFile = File(pickedImagePath);

      final bool imageExists = pathIsNotEmpty
          ? await selectedImageFile.exists()
          : false;

      final bool hasPickedFile = pathIsNotEmpty && imageExists;

      liveLog('🖼️ Image path is not empty: $pathIsNotEmpty');
      liveLog('🖼️ Image file exists: $imageExists');
      liveLog('🖼️ Will upload image: $hasPickedFile');

      if (hasPickedFile) {
        final int imageSize = await selectedImageFile.length();

        final String imageName = pickedImagePath
            .split(Platform.pathSeparator)
            .last;

        liveLog('📁 Image name: $imageName');
        liveLog('📁 Image size: $imageSize bytes');
        liveLog('📦 Request type: multipart/form-data');

        requestData = FormData.fromMap({
          ...data,
          'stream_image': await MultipartFile.fromFile(
            pickedImagePath,
            filename: imageName,
          ),
        });

        requestOptions = Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        );
      } else {
        liveLog('📦 Request type: application/json');

        if (pathIsNotEmpty && !imageExists) {
          liveLog('⚠️ Selected image was not found at path: $pickedImagePath');
        }

        requestData = data;

        requestOptions = Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        );
      }

      liveLog('📤 REQUEST DATA:');

      data.forEach((key, value) {
        if (key == 'room_password') {
          liveLog('➡️ $key: ********');
        } else {
          liveLog('➡️ $key: $value');
        }
      });

      liveLog('⏳ Sending create live API request...');

      timing('create_api_start');
      final response = await dio.post(
        createLiveUrl,
        data: requestData,
        options: requestOptions,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = ((sent / total) * 100).toStringAsFixed(1);
            liveLog('📤 Upload progress: $progress% ($sent/$total bytes)');
          }
        },
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = ((received / total) * 100).toStringAsFixed(1);

            liveLog(
              '📥 Response progress: $progress% '
                  '($received/$total bytes)',
            );
          }
        },
      );
      timing('create_api_done');

      liveLog('==================================================');
      liveLog('✅ CREATE LIVE API RESPONSE RECEIVED');
      liveLog('==================================================');
      liveLog('📥 Status code: ${response.statusCode}');
      liveLog('📥 Status message: ${response.statusMessage}');
      liveLog('📥 Response headers: ${response.headers.map}');
      liveLog('📥 Response data type: ${response.data.runtimeType}');
      if (kDebugMode) {
        liveLog('📥 Create response received');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        liveLog('❌ Invalid create live response status.');
        liveLog('❌ Expected status: 200 or 201');
        liveLog('❌ Received status: ${response.statusCode}');
        liveLog('❌ Create response rejected by status');

        Get.snackbar(
          ('Error').appTr,
          ('Failed to create live stream. '
              'Status code: ${response.statusCode}')
              .appTr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        return false;
      }

      liveLog('🔄 Normalizing permanent room response...');

      final responseMap = _normalizePermanentRoomResponse(response.data);

      liveLog('✅ Normalized response: $responseMap');
      liveLog('✅ Normalized response keys: ${responseMap.keys.toList()}');

      final live = _asMap(responseMap['livestreamdata']);

      liveLog('📺 Original livestream data: $live');

      if (live.isEmpty) {
        liveLog('⚠️ livestreamdata is empty after normalization.');
      }

      live['stream_bte'] = (live['stream_bte'] ?? safeStreamTitle).toString();

      live['title'] = (live['title'] ?? safeStreamTitle).toString();

      live['stream_title'] = (live['stream_title'] ?? safeAnnouncement)
          .toString();

      live['announcement'] = (live['announcement'] ?? safeAnnouncement)
          .toString();

      live['anousment'] = (live['anousment'] ?? safeAnnouncement).toString();

      live['stream_image'] = (live['stream_image'] ?? '').toString();

      responseMap['livestreamdata'] = live;

      liveLog('📺 Final livestream data: $live');
      liveLog('📺 Final response map: $responseMap');

      liveLog('🚪 Opening permanent room as host...');
      liveLog('➡️ Requested user ID: $userId');
      liveLog('➡️ Requested stream type: $streamType');
      liveLog('➡️ Requested seat count: $selectedSeatCount');
      liveLog('➡️ Requested room layout: $roomLayout');
      liveLog('➡️ Requested room theme: $roomTheme');
      liveLog('➡️ Requested room background: $roomBackground');

      final opened = await _openPermanentRoomAsHost(
        responseMap: responseMap,
        userId: userId,
        requestedStreamType: streamType,
        requestedSeatCount: selectedSeatCount,
        requestedRoomLayout: roomLayout,
        requestedRoomTheme: roomTheme,
        requestedRoomBackground: roomBackground,
      );

      liveLog('==================================================');

      if (opened) {
        debugPrint('LIVE_CREATE_SUCCESS => type=$streamType');
      } else {
        debugPrint('LIVE_CREATE_FAILED => type=$streamType');
        liveLog('❌ LIVE ROOM COULD NOT BE OPENED');
        liveLog('❌ _openPermanentRoomAsHost returned false.');
      }

      liveLog('==================================================');

      return opened;
    } on DioException catch (e, stackTrace) {
      debugPrint('LIVE_CREATE_FAILED => type=$streamType');
      liveLog('==================================================');
      liveLog('❌ DIO CREATE LIVE ERROR');
      liveLog('==================================================');

      liveLog('❌ Dio error type: ${e.type}');
      liveLog('❌ Dio error message: ${e.message}');
      liveLog('❌ Dio error object: ${e.error}');

      liveLog('❌ Request method: ${e.requestOptions.method}');
      liveLog('❌ Request URI: ${e.requestOptions.uri}');
      liveLog('❌ Request base URL: ${e.requestOptions.baseUrl}');
      liveLog('❌ Request path: ${e.requestOptions.path}');
      liveLog(
        '❌ Request content type: '
            '${e.requestOptions.contentType}',
      );

      final safeHeaders = Map<String, dynamic>.from(e.requestOptions.headers);

      if (safeHeaders.containsKey('Authorization')) {
        safeHeaders['Authorization'] = 'Bearer ********';
      }

      liveLog('❌ Request headers: $safeHeaders');

      if (e.requestOptions.data is FormData) {
        final formData = e.requestOptions.data as FormData;

        liveLog('❌ Multipart fields:');

        for (final field in formData.fields) {
          if (field.key == 'room_password') {
            liveLog('   ${field.key}: ********');
          } else {
            liveLog('   ${field.key}: ${field.value}');
          }
        }

        liveLog(
          '❌ Multipart files: '
              '${formData.files.map((file) {
            return {'field': file.key, 'filename': file.value.filename, 'contentType': file.value.contentType.toString()};
          }).toList()}',
        );
      } else {
        liveLog('❌ Request data: ${e.requestOptions.data}');
      }

      liveLog('❌ Response status code: ${e.response?.statusCode}');
      liveLog('❌ Response status message: ${e.response?.statusMessage}');
      liveLog('❌ Response headers: ${e.response?.headers.map}');
      liveLog(
        '❌ Response data type: '
            '${e.response?.data.runtimeType}',
      );
      liveLog('❌ Create error response received');
      liveLog('❌ Stack trace:\n$stackTrace');
      liveLog('==================================================');

      String message = 'Please check your internet connection and try again.';

      final dynamic errorData = e.response?.data;

      if (errorData is Map) {
        message =
            (errorData['message'] ??
                errorData['error'] ??
                errorData['errors'] ??
                'Server error occurred.')
                .toString();
      } else if (errorData != null) {
        message = errorData.toString();
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      Get.snackbar(
        ('Live Error').appTr,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('LIVE_CREATE_FAILED => type=$streamType');
      liveLog('==================================================');
      liveLog('❌ UNEXPECTED CREATE LIVE ERROR');
      liveLog('==================================================');
      liveLog('❌ Error type: ${e.runtimeType}');
      liveLog('❌ Error details: $e');
      liveLog('❌ Stack trace:\n$stackTrace');
      liveLog('==================================================');

      Get.snackbar(
        ('Error').appTr,
        ('An unexpected error occurred: $e').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      return false;
    } finally {
      isCreatingLive.value = false;
      timing('create_first_ready');

      liveLog('🔓 isCreatingLive reset to false');
      liveLog('🏁 CREATE LIVE STREAM PROCESS FINISHED');
      liveLog('==================================================');
    }
  }

  Future<void> acceptIncomingCall({
    required String streamType,
    required int myUserId, // receiver এর নিজের ID
    required int callerUserId, // caller এর ID (channel name)
    required dynamic callerData,
  }) async {
    // ⚠️ Receiver কে caller এর channel এ join করতে হবে
    // Channel name = caller এর userId
    await tryToGenerateToken(
      roleId: 2, // 2 = audience/subscriber
      userId: myUserId,
      channelName: '$callerUserId', // caller এর channel
    );

    switch (streamType) {
      case 'audio':
        Get.to(
              () => AudioCallView(
            channelName: '$callerUserId', // ⚠️ caller এর channel
            isBroadcaster: false, // ⚠️ receiver = false
            token: getTokens['token'],
            profile: null,
          ),
          arguments: callerData,
        );
        break;
      case 'video':
        Get.to(
              () => VideoCallView(
            channelName: '$callerUserId', // ⚠️ caller এর channel
            isBroadcaster: false,
            token: getTokens['token'],
            profile: null,
          ),
          arguments: callerData,
        );
        break;
    }
  }

  Future<void> tryToMakeCall({
    required String streamType,
    required int userId,
    required dynamic receiverData,
  }) async {
    final agoraTokenController = Get.find<AgoraTokenController>();

    final String channelName = '$userId';
    final receiverId = receiverData['User Data']['id'];

    try {
      liveLog('📞 =============== CALL START ===============');
      liveLog('📞 Caller Id: $userId');
      liveLog('📞 Receiver Id: $receiverId');
      liveLog('📞 Type: $streamType');

      await agoraTokenController.tryToGenerateBroadcasterToken(
        isBroadcaster: true,
        userId: userId,
        channelName: channelName,
        streamId: channelName,
      );

      final token = agoraTokenController.agoraToken['token'];

      if (token == null || token.toString().isEmpty) {
        liveLog('❌ Token empty, cannot make call');
        Get.snackbar(('Call Failed').appTr, ('Agora token empty').appTr);
        return;
      }

      final String callUrl = callSpecificUser(
        callerId: userId,
        receiverId: int.parse(receiverId.toString()),
        type: streamType,
      );

      liveLog('📤 CALL API URL => $callUrl');

      final response = await dio.get(
        callUrl,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      liveLog('📥 CALL API STATUS => ${response.statusCode}');
      liveLog('📥 CALL API RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final argumentData = {
          ...Map<String, dynamic>.from(receiverData),
          'call_id': response.data is Map
              ? '${response.data['call_id'] ?? ''}'
              : '',
          'channel_name': channelName,
          'call_type': streamType,
        };

        if (streamType == 'video') {
          Get.to(
                () => VideoCallView(
              channelName: channelName,
              isBroadcaster: true,
              token: token.toString(),
              profile: null,
              isOutGoingCall: true,
            ),
            arguments: argumentData,
          );
        } else {
          Get.to(
                () => AudioCallView(
              channelName: channelName,
              isBroadcaster: true,
              token: token.toString(),
              profile: null,
              isOutGoingCall: true,
            ),
            arguments: argumentData,
          );
        }
      } else {
        liveLog('❌ Call API failed');
        Get.snackbar(
          ('Call Failed').appTr,
          response.data is Map
              ? '${response.data['message'] ?? ('Receiver unavailable').appTr}'
              : ('Receiver unavailable').appTr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on DioException catch (e) {
      liveLog('❌ CALL DIO ERROR => ${e.message}');
      liveLog('❌ CALL DIO RESPONSE => ${e.response?.data}');
      Get.snackbar(('Call Failed').appTr, ('Server/network error').appTr);
    } catch (e, s) {
      liveLog('❌ CALL UNKNOWN ERROR => $e');
      liveLog('$s');
      Get.snackbar(('Call Failed').appTr, '$e');
    } finally {
      liveLog('📞 =============== CALL END ===============');
    }
  }

  // remove livestream
  final isLoading = false.obs;
  final Set<int> _removingLivestreams = <int>{};
  Future<void> tryToRemoveLivestream({required int streamId}) async {
    if (streamId <= 0 || !_removingLivestreams.add(streamId)) {
      liveLog('Duplicate/inapplicable removeLiveStream skipped => $streamId');
      return;
    }
    try {
      isLoading.value = true;
      liveLog('live stream removed');

      final response = await dio.post(
        removeLiveStream(streamId),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer ${authController.userProfile.value.token}",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ Timer বন্ধ করুন
        stopLive();

        isLoading.value = false;

        // ✅ GetX warning fix - () => widget format use করুন
        Get.offAll(
              () => Endlive(),
          arguments: response.data,
          transition: Transition.cupertino,
        );
      } else {
        isLoading.value = false;
        liveLog(
          "⚠️ Failed to create live stream: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      isLoading.value = false;
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        isLoading.value = false;
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      isLoading.value = false;
      liveLog("❌ Unexpected Error: $e");
    }
  }

  // add viewer
  final createData = {}.obs;
  final Map<String, Future<Map<String, dynamic>?>> _viewerAddInFlight = {};
  final Set<String> _addedViewerRooms = <String>{};
  final Set<String> _viewerRemoveInFlight = <String>{};

  Future<Map<String, dynamic>?> tryToAddViewer({
    required int streamId,
    required int viewerId,
    bool syncState = true,
  }) {
    final roomKey = '$streamId:$viewerId';
    if (_addedViewerRooms.contains(roomKey)) {
      liveLog('Duplicate addViewer skipped for active room => $roomKey');
      return Future<Map<String, dynamic>?>.value(
        createData.isEmpty
            ? <String, dynamic>{'livestream_id': streamId}
            : Map<String, dynamic>.from(createData),
      );
    }

    final key = roomKey;
    final running = _viewerAddInFlight[key];
    if (running != null) {
      liveLog('♻️ Duplicate addViewer joined existing request => $key');
      return running;
    }

    final future = _performAddViewer(
      streamId: streamId,
      viewerId: viewerId,
      syncState: syncState,
    );
    _viewerAddInFlight[key] = future;
    future.whenComplete(() => _viewerAddInFlight.remove(key));
    return future;
  }

  Future<Map<String, dynamic>?> _performAddViewer({
    required int streamId,
    required int viewerId,
    required bool syncState,
  }) async {
    try {
      final response = await dio.get(
        addViewer(streamId, viewerId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _addedViewerRooms.add('$streamId:$viewerId');
        websocketController.prepareViewerRejoin(
          livestreamId: streamId,
          viewerId: viewerId,
        );
        // Viewer join must always remove previous room owner role from this device.
        // Otherwise: own live -> other live -> sit on seat can still show Host/Admin.
        isHost.value = false;
        isBroadcaster.value = false;
        final responseMap = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        createData.value = responseMap;

        final addedViewer = responseMap['viewer'] ?? responseMap['viewer_data'];
        if (addedViewer != null) {
          addOrUpdateViewerLocal(addedViewer, force: true);
        }

        if (syncState) {
          await applyLivestreamState(responseMap);
        } else {
          final int sid = streamId > 0
              ? streamId
              : _toInt(
            responseMap['livestream_id'] ??
                responseMap['stream_id'] ??
                responseMap['id'],
          );
          if (sid > 0) {
            this.streamId.value = sid;
            websocketController.streamID.value = sid;
          }
        }

        final int joinedStreamId = streamId > 0
            ? streamId
            : _toInt(
          responseMap['livestream_id'] ??
              responseMap['stream_id'] ??
              responseMap['id'],
        );
        if (joinedStreamId > 0) {
          this.streamId.value = joinedStreamId;
          websocketController.streamID.value = joinedStreamId;

          final bool keepCallerRole =
              _presenceStreamId == joinedStreamId &&
                  (_presenceRole == 'caller' || _presenceRole == 'host');

          startLivePresenceHeartbeat(
            livestreamId: joinedStreamId,
            role: keepCallerRole ? _presenceRole : 'viewer',
            isOnSeat: keepCallerRole ? _presenceIsOnSeat : false,
            seatNo: keepCallerRole ? _presenceSeatNo : null,
            backgroundMode: _presenceBackgroundMode,
          );

          liveLog(
            '✅ Viewer presence heartbeat ensured after addViewer '
                '=> stream=$joinedStreamId role=$_presenceRole seat=$_presenceSeatNo',
          );
        }
        return responseMap;
      }

      liveLog('⚠️ Failed to add viewer: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      liveLog('❌ Add viewer error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      liveLog('❌ Unexpected add viewer error: $e');
      return null;
    }
  }

  //------------------------- live time ------------------
  var elapsed = 0.obs;
  var isLive = false.obs;
  Timer? _timer;
  DateTime? _startTime;
  int _liveTimerStreamId = 0;

  int get activeLiveTimerStreamId => _liveTimerStreamId;

  bool isTimerRunningForStream(int streamId) {
    return isLive.value && _liveTimerStreamId == streamId && _timer != null;
  }

  DateTime _parseLiveStartTime(String createdAt) {
    DateTime? parsed;
    try {
      parsed = DateTime.tryParse(createdAt);
    } catch (_) {}
    return parsed?.toLocal() ?? DateTime.now();
  }

  // 🟢 Live শুরু
  void startLive(
      String createdAt, {
        int? liveStreamId,
        bool forceRestart = false,
      }) {
    final int sid =
        liveStreamId ?? int.tryParse(streamId.value.toString()) ?? 0;

    if (!forceRestart && sid > 0 && isTimerRunningForStream(sid)) {
      liveLog('⏱️ Live timer already running for stream:$sid');
      return;
    }

    _timer?.cancel();
    _timer = null;
    elapsed.value = 0;

    _startTime = _parseLiveStartTime(createdAt);
    _liveTimerStreamId = sid;
    isLive.value = true;

    void updateElapsed() {
      if (!isLive.value || _startTime == null) {
        _timer?.cancel();
        return;
      }
      final diff = DateTime.now().difference(_startTime!);
      elapsed.value = diff.inSeconds < 0 ? 0 : diff.inSeconds;
    }

    updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => updateElapsed());

    liveLog('Live started at: $_startTime stream:$sid force:$forceRestart');
  }

  void resetLiveTimerForNewStream({
    required int newStreamId,
    String source = 'manual',
  }) {
    if (newStreamId <= 0) return;
    if (_liveTimerStreamId == newStreamId && isLive.value) return;

    _timer?.cancel();
    _timer = null;
    _startTime = null;
    _liveTimerStreamId = 0;
    isLive.value = false;
    elapsed.value = 0;
    liveLog(
      '⏱️ Live timer reset for new stream => $newStreamId source:$source',
    );
  }

  // 🔴 Live End
  void stopLive() {
    liveLog('Stop Live time');
    isLive.value = false;
    _timer?.cancel();
    _timer = null;
    elapsed.value = 0;
    _startTime = null;
    _liveTimerStreamId = 0;
    liveLog('Live stopped and reset to 00:00');
  }

  // 🔁 Reset
  void resetLive() {
    liveLog('Reset Live time');
    isLive.value = false;
    _timer?.cancel();
    _timer = null;
    elapsed.value = 0;
    _startTime = null;
  }

  // ⏱️ Formatted time getter
  String get formattedTime {
    final seconds = elapsed.value % 60;
    final minutes = (elapsed.value ~/ 60) % 60;
    final hours = elapsed.value ~/ 3600;

    return hours > 0
        ? "${hours.toString().padLeft(2, '0')}:"
        "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}"
        : "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void onClose() {
    _timer?.cancel();
    _pingTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _pkTimer?.cancel();
    _musicProgressTimer?.cancel();
    _quickGiftTimer?.cancel();
    redPacketController.disposeRedPacketState();
    _globalLuckyWinTimer?.cancel();
    _globalLuckyWinBannerTimer?.cancel();
    _globalLuckyWinQueue.clear();
    _removeGlobalLuckyWinOverlay();
    _quickGiftSendQueue.clear();
    quickGiftPendingCount.value = 0;
    quickGiftComboCount.value = 0;
    _quickGiftQueueRunning = false;
    _quickGiftPumpScheduled = false;
    _quickGiftExpireAtMs = 0;
    quickGiftSending.value = false;
    _quickGiftLastSoundPlayer?.dispose();
    _quickGiftLastSoundPlayer = null;

    selectedMusicPath.value = '';
    liveMusicName.value = '';
    liveMusicStatus.value = 'stopped';

    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';

    super.onClose();
  }
  //------------------------- live time ------------------

  final removeData = {}.obs;
  // remove viewer
  Future<void> tryToRemoveViewer({
    required int streamId,
    required int viewerId,
  }) async {
    final roomKey = '$streamId:$viewerId';
    final pendingAdd = _viewerAddInFlight[roomKey];
    if (pendingAdd != null) {
      await pendingAdd;
    }
    if (streamId <= 0 ||
        viewerId <= 0 ||
        _viewerRemoveInFlight.contains(roomKey) ||
        !_addedViewerRooms.contains(roomKey)) {
      liveLog('Duplicate/inapplicable removeViewer skipped => $roomKey');
      return;
    }
    _viewerRemoveInFlight.add(roomKey);
    try {
      liveLog(
        '📤 tryToRemoveViewer request => streamId=$streamId viewerId=$viewerId',
      );

      final response = await dio.get(
        removeViewer(streamId, viewerId),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        removeData.value = response.data;

        /// Backend response-er removed_viewer theke real user id nibo.
        /// viewer row id diye clear korle wrong match/404 dite pare.
        final removedViewer = response.data['removed_viewer'];
        final realUserId = removedViewer is Map
            ? (removedViewer['user']?['id'] ??
            removedViewer['viewer_id'] ??
            removedViewer['user_id'] ??
            viewerId)
            : viewerId;

        liveLog(
          "✅ Viewer removed stream: ${removedViewer is Map ? removedViewer['livestream_id'] : streamId}",
        );
        liveLog("🧹 Clear local viewer data for realUserId=$realUserId");

        viewerState.removeByUserId(realUserId);
        websocketController.clearSpecificUserStreamData(
          userId: realUserId.toString(),
          rejectCallIfInCallList: false,
        );
      } else {
        liveLog(
          "⚠️ Failed to remove viewer: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      /// 404 can happen if backend already removed viewer by websocket/another call.
      /// Treat it as already removed, not fatal.
      if (e.response?.statusCode == 404) {
        liveLog("ℹ️ Viewer already removed / not found: ${e.response?.data}");
        viewerState.removeByUserId(viewerId);
        websocketController.clearSpecificUserStreamData(
          userId: viewerId.toString(),
          rejectCallIfInCallList: false,
        );
        return;
      }

      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    } finally {
      _viewerRemoveInFlight.remove(roomKey);
      _addedViewerRooms.remove(roomKey);
    }
  }

  // get viewer list
  final viewerList = [].obs;

  Future<void> tryToGetViewerList({required int streamId}) async {
    try {
      final response = await dio.get(
        getViewerList(streamId),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        viewerList.value = response.data;
        liveLog("✅ Viewer list fetched successfully: ${response.data}");
      } else {
        liveLog(
          "⚠️ Failed to fetch viewer list: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }

  // call live stream
  final callersData = {}.obs;
  final Map<String, Future<bool>> _acceptCallTransitions =
  <String, Future<bool>>{};
  final Map<String, Future<bool>> _rejectCallTransitions =
  <String, Future<bool>>{};
  final Set<int> _locallyDepartedCallers = <int>{};

  void clearDepartedCallerGuard(int userId) {
    if (userId > 0) _locallyDepartedCallers.remove(userId);
  }

  /// Prevents rapid multi-tap/double API calls while seat request is already running.
  final RxBool seatJoinLoading = false.obs;

  int _seatTotalFromData(Map<String, dynamic> data, {int? fallback}) {
    final wrapped = _asMap(data['data']);
    return _toInt(
      data['total_seats'] ??
          data['seat_count'] ??
          data['totalSeats'] ??
          data['seats'] ??
          wrapped['total_seats'] ??
          wrapped['seat_count'] ??
          wrapped['totalSeats'] ??
          fallback ??
          seatCount.value,
    );
  }

  Set<int> _seatNumbersFromAny(dynamic raw) {
    final result = <int>{};

    void addOne(dynamic value) {
      final map = _asMap(value);
      final int seatNo = map.isNotEmpty
          ? _toInt(
        map['seat_no'] ??
            map['seat'] ??
            map['seat_number'] ??
            map['no'] ??
            map['id'] ??
            value,
      )
          : _toInt(value);
      if (seatNo > 0) result.add(seatNo);
    }

    if (raw is Iterable) {
      for (final item in raw) {
        addOne(item);
      }
    } else if (raw is Map) {
      // Some APIs return {"1": true, "2": false} or {"seat_no": 2}.
      if (raw.containsKey('seat_no') ||
          raw.containsKey('seat') ||
          raw.containsKey('seat_number') ||
          raw.containsKey('id')) {
        addOne(raw);
      } else {
        raw.forEach((key, value) {
          final enabled =
              value == true ||
                  value == 1 ||
                  value?.toString().toLowerCase() == 'true' ||
                  value?.toString() == '1';
          if (enabled) addOne(key);
        });
      }
    } else {
      addOne(raw);
    }

    return result.where((e) => e > 0).toSet();
  }

  bool _isActiveSeatStatus(dynamic statusRaw) {
    final status = (statusRaw ?? '').toString().toLowerCase().trim();
    if (status.isEmpty) return true;

    return status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'live' ||
        status == 'running' ||
        status == 'broadcasting';
  }

  int _seatUserIdFromCall(Map<String, dynamic> call) {
    final user = _asMap(call['user']);
    final caller = _asMap(call['caller']);
    return _toInt(
      call['caller_id'] ??
          call['user_id'] ??
          call['viewer_id'] ??
          user['id'] ??
          user['user_id'] ??
          caller['id'] ??
          caller['user_id'],
    );
  }

  Set<int> _localOccupiedSeats({required int callerId}) {
    final occupied = <int>{};

    try {
      final ws = Get.find<WebsocketController>();
      for (final raw in ws.liveCallList) {
        final call = _asMap(raw);
        if (call.isEmpty) continue;

        final int seatNo = _toInt(
          call['seat_no'] ?? call['seat'] ?? call['seat_number'],
        );
        if (seatNo <= 0) continue;
        if (!_isActiveSeatStatus(call['call_status'] ?? call['status']))
          continue;

        final int userId = _seatUserIdFromCall(call);
        if (userId > 0 && userId != callerId) {
          occupied.add(seatNo);
        }
      }
    } catch (e) {
      liveLog('⚠️ Local occupied seats skipped => $e');
    }

    return occupied;
  }

  Set<int> _localLockedSeats({required int totalSeats}) {
    final locked = <int>{};
    if (totalSeats <= 0) return locked;

    try {
      final ws = Get.find<WebsocketController>();
      for (int seat = 1; seat <= totalSeats; seat++) {
        if (ws.isSeatLocked(seat)) locked.add(seat);
      }
    } catch (e) {
      liveLog('⚠️ Local locked seats skipped => $e');
    }

    return locked;
  }

  Future<int?> _resolveJoinSeatNo({
    required int livestreamId,
    required int callerId,
    required String callType,
    int? requestedSeatNo,
    int? requestedTotalSeats,
  }) async {
    Map<String, dynamic> seatsData = <String, dynamic>{};

    try {
      final response = await getAvailableSeats(livestreamId);
      if (response != null) {
        seatsData = _asMap(response['data']).isNotEmpty
            ? _asMap(response['data'])
            : _asMap(response);
      }
    } catch (e) {
      liveLog('⚠️ Available seat resolve skipped => $e');
    }

    final int dataTotalSeats = _seatTotalFromData(seatsData);
    int totalSeats = requestedTotalSeats != null && requestedTotalSeats > 0
        ? requestedTotalSeats
        : dataTotalSeats;

    if (totalSeats <= 0) {
      totalSeats = callType.toLowerCase() == 'video' ? 5 : 9;
    }

    // Backend response is the strongest source. It returns only real open seats.
    final Set<int> backendAvailable = _seatNumbersFromAny(
      seatsData['available_seats'] ?? seatsData['availableSeats'],
    );
    final Set<int> backendLocked = _seatNumbersFromAny(
      seatsData['locked_seats'] ?? seatsData['lockedSeats'],
    );
    final Set<int> backendOccupied = _seatNumbersFromAny(
      seatsData['occupied_seats'] ?? seatsData['occupiedSeats'],
    );

    final Set<int> lockedSeats = <int>{
      ...backendLocked,
      ..._localLockedSeats(totalSeats: totalSeats),
    };
    final Set<int> occupiedSeats = <int>{
      ...backendOccupied,
      ..._localOccupiedSeats(callerId: callerId),
    };

    bool isValidCandidate(int seatNo) {
      if (seatNo <= 0 || seatNo > totalSeats) return false;
      if (lockedSeats.contains(seatNo)) return false;
      if (occupiedSeats.contains(seatNo)) return false;
      if (backendAvailable.isNotEmpty && !backendAvailable.contains(seatNo)) {
        return false;
      }
      return true;
    }

    final int requested = _toInt(requestedSeatNo);
    if (requested > 0) {
      if (requested > totalSeats) {
        Fluttertoast.showToast(
          msg: ('Invalid seat number').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return null;
      }

      if (lockedSeats.contains(requested)) {
        Fluttertoast.showToast(
          msg: ('This seat is locked').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return null;
      }

      if (occupiedSeats.contains(requested) ||
          (backendAvailable.isNotEmpty &&
              !backendAvailable.contains(requested))) {
        Fluttertoast.showToast(
          msg: ('This seat is already occupied').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        return null;
      }

      return requested;
    }

    // No seat selected from UI: choose the first real available seat.
    // Most rooms keep seat 1 for host, so fallback starts from seat 2.
    // Most rooms keep seat 1 for host, so fallback starts from seat 2.
    final List<int> candidates = backendAvailable.isNotEmpty
        ? (backendAvailable.toList()..sort())
        : List<int>.generate(
      totalSeats,
          (index) => index + 1,
    ).where((seat) => totalSeats == 1 || seat > 1).toList();

    for (final seatNo in candidates) {
      if (isValidCandidate(seatNo)) return seatNo;
    }

    Fluttertoast.showToast(
      msg: ('No available seat right now').appTr,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
    return null;
  }

  Future<void> tryToCallLivestream({
    required int streamId,
    int? seatNO,
    int? totalSeats,
    required int callerId,
    required String callType,
  }) async {
    if (seatJoinLoading.value) {
      liveLog('⏳ Seat request ignored: previous request still running');
      return;
    }

    seatJoinLoading.value = true;

    try {
      final int targetSeatNo =
          await _resolveJoinSeatNo(
            livestreamId: streamId,
            callerId: callerId,
            callType: callType,
            requestedSeatNo: seatNO,
            requestedTotalSeats: totalSeats,
          ) ??
              0;

      if (targetSeatNo <= 0) return;
      debugPrint('OUTGOING_CALL_REQUEST_START');

      liveLog('📌 Starting tryToCallLivestream');
      liveLog(
        'StreamID: $streamId, CallerID: $callerId, CallType: $callType, SeatNO: $targetSeatNo, TotalSeats: ${totalSeats ?? seatCount.value}',
      );

      // 1️⃣ Check if can join
      final canJoinResult = await checkCanJoinLivestream(streamId, callerId);
      liveLog('✅ checkCanJoinLivestream result: $canJoinResult');
      if (canJoinResult['can_join'] != true) {
        Fluttertoast.showToast(
          msg:
          (canJoinResult['message'] ??
              ('You can not join this seat right now').appTr)
              .toString(),
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // 2️⃣ Prepare data with a valid room seat. Never send default 100.
      final data = {
        'livestream_id': streamId,
        'caller_id': callerId,
        'call_type': callType,
        'seat_no': targetSeatNo,
      };
      liveLog('📤 Request data: $data');

      // 3️⃣ Send POST request
      final response = await dio.post(
        callLiveStream,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      liveLog('📨 Seat request response => status=${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        callersData.value = response.data;
        debugPrint('OUTGOING_CALL_REQUEST_SUCCESS');

        final bool appliedImmediately = _applyAcceptedSeatFromCallResponse(
          responseData: response.data,
          streamId: streamId,
          callerId: callerId,
          seatNo: targetSeatNo,
          callType: callType,
        );

        liveLog(
          '🪑 SEAT REQUEST OK | stream=$streamId | user=$callerId | '
              'seat=$targetSeatNo | immediate=$appliedImmediately',
        );

        _scheduleSeatJoinReconciliation(
          streamId: streamId,
          callerId: callerId,
          seatNo: targetSeatNo,
          callType: callType,
        );
      } else {
        debugPrint('OUTGOING_CALL_REQUEST_FAILED');
        liveLog(
          '⚠️ Failed to make call: ${response.statusCode} - ${response.data}',
        );
        Fluttertoast.showToast(
          msg: ('Seat join failed. Please try again.').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      debugPrint('OUTGOING_CALL_REQUEST_FAILED');
      liveLog('❌ DioException caught');
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Seat join failed').toString()
          : (e.message ?? 'Seat join failed').toString();
      if (e.response != null) {
        liveLog(
          '❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}',
        );
      } else {
        liveLog('❌ Network Error: ${e.message}');
      }
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint('OUTGOING_CALL_REQUEST_FAILED');
      liveLog('❌ Unexpected Error: $e');
      Fluttertoast.showToast(
        msg: ('Seat join failed. Please try again.').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      seatJoinLoading.value = false;
      liveLog('📌 tryToCallLivestream ended');
    }
  }

  bool _isAcceptedSeatStatus(dynamic rawStatus) {
    final status = (rawStatus ?? '').toString().trim().toLowerCase();
    return status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'live' ||
        status == 'on_seat';
  }

  int _seatCallerId(Map<String, dynamic> call) {
    final user = call['user'] is Map
        ? Map<String, dynamic>.from(call['user'])
        : <String, dynamic>{};
    final caller = call['caller'] is Map
        ? Map<String, dynamic>.from(call['caller'])
        : <String, dynamic>{};
    return _toInt(
      call['caller_id'] ??
          call['user_id'] ??
          call['viewer_id'] ??
          user['id'] ??
          user['user_id'] ??
          caller['id'] ??
          caller['user_id'],
    );
  }

  int _seatNumberFromCall(Map<String, dynamic> call) {
    return _toInt(
      call['seat_no'] ??
          call['seatNo'] ??
          call['seat'] ??
          call['seat_number'],
    );
  }

  Map<String, dynamic> _extractSeatCallFromResponse(dynamic raw) {
    final pending = <dynamic>[raw];
    int inspected = 0;

    while (pending.isNotEmpty && inspected < 30) {
      final current = pending.removeAt(0);
      inspected++;

      if (current is List) {
        pending.addAll(current.take(12));
        continue;
      }
      if (current is! Map) continue;

      final map = Map<String, dynamic>.from(current);
      final int callerId = _seatCallerId(map);
      final int seatNo = _seatNumberFromCall(map);
      if (callerId > 0 && seatNo > 0) return map;

      for (final key in const <String>[
        'caller',
        'call',
        'livestream_caller',
        'livestreamCaller',
        'data',
        'result',
      ]) {
        final nested = map[key];
        if (nested is Map || nested is List) pending.add(nested);
      }
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _currentAuthUserSeatSnapshot(int callerId) {
    final dynamic authUser = authController.userProfile.value.user;
    final int authId = authUser?.id?.toInt() ?? 0;
    if (authUser == null || authId <= 0 || authId != callerId) {
      return <String, dynamic>{};
    }

    final user = <String, dynamic>{'id': authId, 'user_id': authId};
    try {
      final dynamic json = authUser.toJson();
      if (json is Map) user.addAll(Map<String, dynamic>.from(json));
    } catch (_) {}
    try {
      final dynamic name = authUser.name;
      if (name != null) user['name'] = name;
    } catch (_) {}
    try {
      final dynamic image = authUser.profileImage;
      if (image != null) user['profile_image'] = image;
    } catch (_) {}
    return user;
  }

  bool _applyAcceptedSeatFromCallResponse({
    required dynamic responseData,
    required int streamId,
    required int callerId,
    required int seatNo,
    required String callType,
  }) {
    final row = _extractSeatCallFromResponse(responseData);
    if (row.isEmpty) return false;

    final dynamic rawStatus = row['call_status'] ?? row['status'];
    if (!_isAcceptedSeatStatus(rawStatus)) return false;

    final int responseCallerId = _seatCallerId(row);
    final int responseSeatNo = _seatNumberFromCall(row);
    if (responseCallerId > 0 && responseCallerId != callerId) return false;

    final normalized = Map<String, dynamic>.from(row);
    normalized['livestream_id'] ??= streamId;
    normalized['stream_id'] ??= streamId;
    normalized['caller_id'] ??= callerId;
    normalized['user_id'] ??= callerId;
    normalized['seat_no'] = responseSeatNo > 0 ? responseSeatNo : seatNo;
    normalized['call_type'] ??= callType;
    normalized['call_status'] = rawStatus?.toString() ?? 'accepted';
    normalized['is_active'] ??= true;
    normalized['audio_on'] ??= 1;

    if (normalized['user'] is! Map ||
        (normalized['user'] as Map).isEmpty) {
      final selfUser = _currentAuthUserSeatSnapshot(callerId);
      if (selfUser.isNotEmpty) normalized['user'] = selfUser;
    }

    websocketController.liveCallList.removeWhere((raw) {
      if (raw is! Map) return false;
      final old = Map<String, dynamic>.from(raw);
      final oldCallerId = _seatCallerId(old);
      final oldSeatNo = _seatNumberFromCall(old);
      return oldCallerId == callerId ||
          (oldSeatNo > 0 && oldSeatNo == normalized['seat_no']);
    });
    websocketController.liveCallList.add(normalized);
    websocketController.liveCallList.refresh();
    websocketController.pendingCall.removeWhere((raw) {
      if (raw is! Map) return false;
      return _seatCallerId(Map<String, dynamic>.from(raw)) == callerId;
    });
    websocketController.pendingCall.refresh();

    updateLivePresenceRole(
      role: 'caller',
      isOnSeat: true,
      seatNo: _toInt(normalized['seat_no']),
    );

    liveLog(
      '🪑 SEAT APPLY API | stream=$streamId | user=$callerId | '
          'seat=${normalized['seat_no']} | status=${normalized['call_status']}',
    );
    return true;
  }

  bool _hasAcceptedSeatLocally({
    required int streamId,
    required int callerId,
  }) {
    for (final raw in websocketController.liveCallList) {
      if (raw is! Map) continue;
      final call = Map<String, dynamic>.from(raw);
      final int rowStreamId = _toInt(
        call['livestream_id'] ?? call['stream_id'] ?? call['live_id'],
      );
      if (rowStreamId > 0 && rowStreamId != streamId) continue;
      if (_seatCallerId(call) != callerId) continue;
      if (_seatNumberFromCall(call) <= 0) continue;
      if (_isAcceptedSeatStatus(call['call_status'] ?? call['status'])) {
        return true;
      }
    }
    return false;
  }

  void _scheduleSeatJoinReconciliation({
    required int streamId,
    required int callerId,
    required int seatNo,
    required String callType,
  }) {
    Future<void> reconcileAfter(Duration delay, String stage) async {
      await Future<void>.delayed(delay);
      if (streamId <= 0 || callerId <= 0) return;

      await tryToGetCallList(streamId: streamId, force: true);
      final bool seated = _hasAcceptedSeatLocally(
        streamId: streamId,
        callerId: callerId,
      );
      liveLog(
        '🪑 SEAT SYNC $stage | stream=$streamId | user=$callerId | '
            'seat=$seatNo | seated=$seated | type=$callType',
      );
    }

    unawaited(reconcileAfter(const Duration(milliseconds: 300), '300ms'));
    unawaited(reconcileAfter(const Duration(milliseconds: 1600), '1600ms'));
    unawaited(reconcileAfter(const Duration(milliseconds: 3500), '3500ms'));
  }

  Map<String, dynamic> _safeCallMap(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _callIdentity(Map<String, dynamic> call) {
    final user = call['user'] is Map
        ? Map<String, dynamic>.from(call['user'])
        : <String, dynamic>{};
    return (call['caller_id'] ??
        call['user_id'] ??
        user['id'] ??
        user['user_id'] ??
        '')
        .toString();
  }

  Map<String, dynamic> _mergeCallPreservingUser(
      Map<String, dynamic> oldCall,
      Map<String, dynamic> newCall,
      ) {
    final merged = <String, dynamic>{...oldCall, ...newCall};

    final oldUser = oldCall['user'] is Map
        ? Map<String, dynamic>.from(oldCall['user'])
        : <String, dynamic>{};
    final newUser = newCall['user'] is Map
        ? Map<String, dynamic>.from(newCall['user'])
        : <String, dynamic>{};

    // Backend sometimes returns partial caller rows after restore.
    // Preserve old hydrated user data so frame/name/id/profile do not disappear.
    if (oldUser.isNotEmpty || newUser.isNotEmpty) {
      merged['user'] = <String, dynamic>{...oldUser, ...newUser};
    }

    for (final key in [
      'asset_purchase_history',
      'asset_purchase_histories',
      'asset_purchase_history2',
      'profile_frame_history',
      'frame',
      'avatar_frame',
      'profile_frame',
      'profileFrame',
      'active_frame',
    ]) {
      if (merged['user'] is Map &&
          (merged['user'][key] == null ||
              merged['user'][key].toString().isEmpty) &&
          oldUser[key] != null) {
        merged['user'][key] = oldUser[key];
      }
    }

    return merged;
  }

  int _emptyAcceptedCallListHit = 0;

  /// ✅ Safe cleanup throttle fields.
  /// These only reduce duplicate API/log spam; they do not change live seat state.
  bool _callListFetchRunning = false;
  DateTime? _lastCallListFetchAt;
  DateTime? _lastGiftHistoryFetchAt;
  DateTime? _lastTotalGiftCoinsFetchAt;

  bool _shouldPreserveAcceptedCallFromWeakSnapshot(
      Map<String, dynamic> call,
      ) {
    if (!_isAcceptedCaller(call)) return false;

    final user = call['user'] is Map
        ? Map<String, dynamic>.from(call['user'])
        : <String, dynamic>{};
    final callerId = _toInt(
      call['caller_id'] ??
          call['user_id'] ??
          call['viewer_id'] ??
          user['id'] ??
          user['user_id'],
    );
    if (callerId <= 0 || _locallyDepartedCallers.contains(callerId)) {
      return false;
    }

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (callerId == currentUserId) return true;

    final mappedUid = videoCallerAgoraUidMap[callerId] ?? 0;
    if (mappedUid > 0 && videoLiveRemoteUids.contains(mappedUid)) {
      return true;
    }

    final hasEquivalentRemoteUid = videoLiveRemoteUids.any(
          (uid) =>
      uid == callerId ||
          uid == callerId + 100000 ||
          (callerId >= 100000 && uid == callerId - 100000),
    );
    if (hasEquivalentRemoteUid) return true;

    return liveViewerList.any((rawViewer) {
      if (rawViewer is! Map) return false;
      final viewer = Map<String, dynamic>.from(rawViewer);
      final viewerUser = viewer['user'] is Map
          ? Map<String, dynamic>.from(viewer['user'])
          : <String, dynamic>{};
      final viewerId = _toInt(
        viewer['viewer_id'] ??
            viewer['user_id'] ??
            viewer['id'] ??
            viewerUser['id'] ??
            viewerUser['user_id'],
      );
      return viewerId == callerId;
    });
  }

  void _mergeAcceptedCallListSafely(List<Map<String, dynamic>> freshCalls) {
    final Map<String, Map<String, dynamic>> oldById = {};

    for (final oldRaw in websocketController.liveCallList) {
      final oldCall = _safeCallMap(oldRaw);
      final key = _callIdentity(oldCall);
      if (key.isNotEmpty) oldById[key] = oldCall;
    }

    if (freshCalls.isEmpty) {
      _emptyAcceptedCallListHit++;

      // Call-list HTTP snapshots are not authoritative for removing an active
      // media caller. A transient empty response previously made only the host
      // lose the caller card while both sides could still see/hear each other.
      // Explicit reject/seat-left/call-end/kick events remain responsible for
      // removing accepted calls.
      if (websocketController.liveCallList.isNotEmpty) {
        liveLog(
          '🛡️ Empty call list ignored; host accepted callers preserved '
              'hit=$_emptyAcceptedCallListHit '
              'keep=${websocketController.liveCallList.length}',
        );
      }
      return;
    }

    _emptyAcceptedCallListHit = 0;

    final merged = <Map<String, dynamic>>[];
    final freshKeys = <String>{};
    for (final call in freshCalls) {
      final key = _callIdentity(call);
      if (key.isNotEmpty) freshKeys.add(key);
      final old = oldById[key];
      final mergedCall = old == null
          ? call
          : _mergeCallPreservingUser(old, call);
      merged.add(mergedCall);
    }

    // A non-empty API response can still be partial (for example, host only).
    // Keep omitted accepted callers while their viewer/media presence is alive.
    for (final entry in oldById.entries) {
      if (freshKeys.contains(entry.key)) continue;
      final oldCall = entry.value;
      if (!_shouldPreserveAcceptedCallFromWeakSnapshot(oldCall)) continue;
      merged.add(oldCall);
      liveLog(
        '🛡️ Partial call list kept active caller on host '
            '=> user=${entry.key}',
      );
    }

    final deduped = <String, Map<String, dynamic>>{};
    final withoutId = <Map<String, dynamic>>[];
    for (final call in merged) {
      final key = _callIdentity(call);
      if (key.isEmpty) {
        withoutId.add(call);
      } else {
        deduped[key] = call;
      }
    }

    websocketController.liveCallList.assignAll(<Map<String, dynamic>>[
      ...deduped.values,
      ...withoutId,
    ]);
    websocketController.liveCallList.refresh();
  }

  // get call list
  final callList = [].obs;
  final selectIndex = 0.obs;
  Future<void> tryToGetCallList({required int streamId, bool force = false}) async {
    if (streamId <= 0) return;

    // ✅ Cleanup: prevent repeated call-list API spam from rapid WS snapshots.
    // State is not changed here; it only skips duplicate requests fired within 1200ms.
    if (_callListFetchRunning) return;
    final now = DateTime.now();
    if (!force &&
        _lastCallListFetchAt != null &&
        now.difference(_lastCallListFetchAt!).inMilliseconds < 1200) {
      return;
    }

    _callListFetchRunning = true;
    _lastCallListFetchAt = now;

    try {
      final response = await dio.get(
        getCallList(streamId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data;
        final list = raw is List
            ? raw
            : raw is Map && raw['data'] is List
            ? raw['data'] as List
            : raw is Map && raw['callers'] is List
            ? raw['callers'] as List
            : <dynamic>[];

        final bool isAudioRoom =
            websocketController.activeAudioStreamId.value == streamId;
        final safeList = list.where((rawCall) {
          if (!isAudioRoom || rawCall is! Map) return true;
          final type =
          (rawCall['call_type'] ?? rawCall['type'] ?? 'audio')
              .toString()
              .trim()
              .toLowerCase();
          return type != 'video' && type != 'popular';
        }).toList(growable: false);

        callList.assignAll(safeList);

        /// Seat/call UI only accepted/joined/active user show korbe.
        /// Pending/request user never seat e uthbe na. Audio rooms additionally
        /// reject explicit video/popular callers from HTTP reconciliation.
        final filteredCallList = safeList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(_isAcceptedCaller)
            .where((call) {
          final id = int.tryParse(_callIdentity(call)) ?? 0;
          return !_locallyDepartedCallers.contains(id);
        })
            .toList();

        _mergeAcceptedCallListSafely(filteredCallList);
      } else {
        liveLog('⚠️ Failed to fetch call list: ${response.statusCode}');
      }
    } catch (e) {
      liveLog('⚠️ Call list fetch failed safely: $e');
    } finally {
      _callListFetchRunning = false;
    }
  }

  // accept call
  Future<bool> tryToAcceptCall({
    required int streamId,
    required int userId,
  }) async {
    if (streamId <= 0 || userId <= 0) return false;
    final key = '$streamId:$userId';
    final existing = _acceptCallTransitions[key];
    if (existing != null) return existing;
    final transition = _performAcceptCall(streamId: streamId, userId: userId);
    _acceptCallTransitions[key] = transition;
    try {
      return await transition;
    } finally {
      _acceptCallTransitions.remove(key);
    }
  }

  Future<bool> _performAcceptCall({
    required int streamId,
    required int userId,
  }) async {
    Map<String, dynamic>? pendingCall;
    for (final raw in websocketController.pendingCall) {
      if (raw is! Map) continue;
      final candidate = Map<String, dynamic>.from(raw);
      if (_callIdentity(candidate) == userId.toString()) {
        pendingCall = candidate;
        break;
      }
    }
    final requestId =
        pendingCall?['request_id'] ??
            pendingCall?['call_id'] ??
            pendingCall?['id'];
    final seatNo = _seatNoFromCall(pendingCall);
    clearDepartedCallerGuard(userId);
    debugPrint(
      'CALL_ACCEPT_START => stream=$streamId caller=$userId request=$requestId seat=$seatNo',
    );

    try {
      final response = await dio.get(
        acceptCall(streamId, userId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      debugPrint(
        'CALL_ACCEPT_RESPONSE => status=${response.statusCode} body=${response.data}',
      );
      final responseData = response.data;
      final explicitSuccess = responseData is Map
          ? responseData['success']
          : null;
      final accepted =
          (response.statusCode == 200 || response.statusCode == 201) &&
              explicitSuccess != false &&
              explicitSuccess?.toString().toLowerCase() != 'false';
      if (accepted) {
        liveLog('✅ Call accepted => stream=$streamId user=$userId');

        Map<String, dynamic>? acceptedCall = pendingCall;
        if (acceptedCall != null) {
          acceptedCall['call_status'] = 'accepted';
          acceptedCall['status'] = 'accepted';
          final index = websocketController.liveCallList.indexWhere((raw) {
            return raw is Map &&
                _callIdentity(Map<String, dynamic>.from(raw)) ==
                    userId.toString();
          });
          if (index == -1) {
            websocketController.liveCallList.add(acceptedCall);
          } else {
            websocketController.liveCallList[index] = _mergeCallPreservingUser(
              Map<String, dynamic>.from(
                websocketController.liveCallList[index],
              ),
              acceptedCall,
            );
          }
          websocketController.liveCallList.refresh();
        }

        websocketController.pendingCall.removeWhere((call) {
          final callerId = call['caller_id']?.toString();
          final callUserId = call['user']?['id']?.toString();
          return callerId == userId.toString() ||
              callUserId == userId.toString();
        });
        websocketController.pendingCall.refresh();

        await tryToGetCallList(streamId: streamId);

        final currentUserId =
            authController.userProfile.value.user?.id?.toInt() ?? 0;
        final acceptedType =
        (acceptedCall?['call_type'] ?? acceptedCall?['type'] ?? '')
            .toString()
            .toLowerCase();
        if ((acceptedType == 'video' || acceptedType == 'popular') &&
            isBroadcaster.value) {
          final engine = AgoraService().engine;
          if (engine != null) {
            await engine.enableVideo();
            await engine.enableLocalVideo(true);
            await engine.setClientRole(
              role: ClientRoleType.clientRoleBroadcaster,
            );
            await engine.muteLocalVideoStream(false);
            await engine.muteLocalAudioStream(false);
            await engine.updateChannelMediaOptions(
              const ChannelMediaOptions(
                clientRoleType: ClientRoleType.clientRoleBroadcaster,
                publishCameraTrack: true,
                publishMicrophoneTrack: true,
                autoSubscribeAudio: true,
                autoSubscribeVideo: true,
              ),
            );
            await engine.muteAllRemoteVideoStreams(false);
            await engine.muteAllRemoteAudioStreams(false);
            debugPrint('VIDEO_CALL_ROLE_READY => role=host user=$userId');
          }
        }
        if (currentUserId == userId) {
          dynamic currentCall;
          for (final item in websocketController.liveCallList) {
            if (item is! Map) continue;
            final callerId = item['caller_id']?.toString();
            final callUserId = item['user']?['id']?.toString();
            if (callerId == userId.toString() ||
                callUserId == userId.toString()) {
              currentCall = item;
              break;
            }
          }

          updateLivePresenceRole(
            role: 'caller',
            isOnSeat: true,
            seatNo: _seatNoFromCall(currentCall),
          );
        }
        debugPrint(
          'CALL_ACCEPT_SUCCESS => stream=$streamId caller=$userId seat=$seatNo',
        );
        return true;
      } else {
        final message = _resolveAcceptCallMessage(response.data);
        debugPrint(
          'CALL_ACCEPT_FAILED => status=${response.statusCode} message=$message body=${response.data}',
        );
        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (error, stackTrace) {
      final message = _resolveAcceptCallMessage(
        error.response?.data,
        error: error.message,
      );
      if (error.response != null) {
        debugPrint(
          'CALL_ACCEPT_RESPONSE => '
              'status=${error.response?.statusCode} body=${error.response?.data}',
        );
        debugPrint(
          'CALL_ACCEPT_FAILED => '
              'status=${error.response?.statusCode} message=$message '
              'body=${error.response?.data}',
        );
      }
      debugPrint(
        'CALL_ACCEPT_EXCEPTION => type=${error.runtimeType} errorType=${error.type} message=${error.message} status=${error.response?.statusCode} body=${error.response?.data} uri=${error.requestOptions.uri}',
      );
      debugPrintStack(label: 'CALL_ACCEPT_STACK', stackTrace: stackTrace);
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (error, stackTrace) {
      final message = _resolveAcceptCallMessage(null, error: error);
      debugPrint(
        'CALL_ACCEPT_EXCEPTION => type=${error.runtimeType} error=$error',
      );
      debugPrintStack(label: 'CALL_ACCEPT_STACK', stackTrace: stackTrace);
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
    return false;
  }

  String _resolveAcceptCallMessage(dynamic responseData, {Object? error}) {
    dynamic backendMessage;
    if (responseData is Map) {
      backendMessage = responseData['message'] ?? responseData['error'];
      final nestedData = responseData['data'];
      if (backendMessage == null && nestedData is Map) {
        backendMessage = nestedData['message'] ?? nestedData['error'];
      }
    }
    for (final candidate in <dynamic>[backendMessage, error]) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return 'Unable to accept the call. Please try again.';
  }

  // reject call / leave seat
  Future<bool> tryToRejectCall({
    required int streamId,
    required int userId,
  }) async {
    if (streamId <= 0 || userId <= 0) return false;
    final key = '$streamId:$userId';
    final existing = _rejectCallTransitions[key];
    if (existing != null) return existing;
    final transition = _performRejectCall(streamId: streamId, userId: userId);
    _rejectCallTransitions[key] = transition;
    try {
      return await transition;
    } finally {
      _rejectCallTransitions.remove(key);
    }
  }

  Future<bool> _performRejectCall({
    required int streamId,
    required int userId,
  }) async {
    bool rejectSucceeded = false;
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    try {
      final response = await dio.get(
        rejectCall(streamId, userId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        rejectSucceeded = true;
        _locallyDepartedCallers.add(userId);
        if (currentUserId == userId) {
          await websocketController.deactivateLocalCallerMediaForLeave(userId);

          /// Seat leave is a hard microphone boundary. Keep the user inside the
          /// room as a viewer, but never leave the previous caller mic state on.
          websocketController.audioMutedUserMap[userId] = true;
          websocketController.audioMutedUserMap.refresh();
          mute.value = true;
          isMuted.value = true;
          isAudioEnabled.value = false;
        }
        liveLog('✅ Call rejected/left => stream=$streamId user=$userId');
      } else {
        liveLog('⚠️ Reject call status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        liveLog(
          '⚠️ Reject call Dio ignored safely: ${e.response?.statusCode ?? e.message}',
        );
      }
    } catch (e) {
      liveLog('⚠️ Reject call failed safely: $e');
    } finally {
      if (!rejectSucceeded) return false;
      websocketController.pendingCall.removeWhere((call) {
        final callerId = call['caller_id']?.toString();
        final callUserId = call['user']?['id']?.toString();
        return callerId == userId.toString() || callUserId == userId.toString();
      });
      websocketController.liveCallList.removeWhere((call) {
        final callerId = call['caller_id']?.toString();
        final callUserId = call['user']?['id']?.toString();
        return callerId == userId.toString() || callUserId == userId.toString();
      });
      websocketController.pendingCall.refresh();
      websocketController.liveCallList.refresh();

      if (currentUserId == userId) {
        // BIGO style: leaving/removing from seat is NOT leaving the live room.
        // Do not call /user/offline here. Keep user online as viewer so the
        // host can still see viewer profile and show/hide/mute state stays synced.
        updateLivePresenceRole(role: 'viewer', isOnSeat: false, seatNo: null);
        await sendPresenceHeartbeatOnce(
          livestreamId: streamId,
          role: 'viewer',
          isOnSeat: false,
          seatNo: null,
        );
      }

      await refreshLiveRoomRealtimeState(streamId: streamId);
    }
    return rejectSucceeded;
  }

  // live comments
  Future<void> tryToAddComment({required String comment}) async {
    try {
      final userId = authController.userProfile.value.user?.id?.toInt() ?? 0;

      final url = addComment(streamId.value, userId);

      // ✅ DEBUG PRINTS
      liveLog('📌 URL: $url');
      liveLog('📌 User ID: $userId');
      liveLog('📌 Stream ID: ${streamId.value}');
      liveLog('📌 Comment Data: {"comment": $comment}');

      final response = await dio.post(
        url,
        data: {'comment': comment},
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        liveLog("✅ Comment added successfully");
        liveLog("📥 Response Data: ${response.data}");
      } else {
        liveLog("⚠️ Failed: ${response.statusCode} - ${response.data}");
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog("❌ Server Error: ${e.response!.statusCode}");
        liveLog("📥 Error Data: ${e.response!.data}");
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }

  final giftReceiverID = 0.obs;
  final selectedSeatNo = 0.obs;

  bool get isPkCommentGiftActive {
    final int pkId = currentPkId.value;
    final int senderStream = pkSenderLivestreamId.value;
    final int receiverStream = pkReceiverLivestreamId.value;

    return pkId > 0 &&
        (pkModeActive.value == true || senderStream > 0 || receiverStream > 0);
  }

  int get currentPkOpponentLivestreamId {
    final int myStream = streamId.value;
    final int senderStream = pkSenderLivestreamId.value;
    final int receiverStream = pkReceiverLivestreamId.value;

    if (myStream > 0 && myStream == senderStream && receiverStream > 0) {
      return receiverStream;
    }

    if (myStream > 0 && myStream == receiverStream && senderStream > 0) {
      return senderStream;
    }

    if (receiverStream > 0 && receiverStream != myStream) return receiverStream;
    if (senderStream > 0 && senderStream != myStream) return senderStream;

    return 0;
  }

  Map<String, dynamic> pkCommentGiftMetaBody() {
    if (!isPkCommentGiftActive) return <String, dynamic>{};

    final int myStream = streamId.value;
    final int opponentStream = currentPkOpponentLivestreamId;

    return <String, dynamic>{
      'is_pk': 1,
      'pk_id': currentPkId.value,
      'pk_channel_name': pkChannelName.value,
      'pk_channel': pkChannelName.value,
      'sender_livestream_id': myStream,
      'receiver_livestream_id': opponentStream,
      'opponent_livestream_id': opponentStream,
      'pk_sender_livestream_id': pkSenderLivestreamId.value,
      'pk_receiver_livestream_id': pkReceiverLivestreamId.value,
      'pk_sender_host_id': pkSenderHostId.value,
      'pk_receiver_host_id': pkReceiverHostId.value,
    };
  }

  // Controller এ list রাখুন
  final selectedReceiverIds = <int>[].obs;

  // onTap এ ID add/remove করুন
  void toggleProfileSelection(int index, int userId) {
    if (selectedProfileIndices.contains(index)) {
      selectedProfileIndices.remove(index);
      selectedReceiverIds.remove(userId); // ✅ ID remove
    } else {
      selectedProfileIndices.add(index);
      selectedReceiverIds.add(userId); // ✅ ID add
    }
  }

  Map<String, dynamic> _localGiftAssetById(int giftId, int giftPrice) {
    for (final raw in giftList) {
      if (raw is! Map) continue;
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
      final ws = Get.find<WebsocketController>();
      final currentUser = authController.userProfile.value.user;

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
            streamId.value,
        'stream_id':
        responseData['stream_id'] ??
            responseData['livestream_id'] ??
            streamId.value,
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

  bool _luckyResponseHasVisibleWin(Map<String, dynamic> responseData) {
    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value?.toString() ?? '0') ??
          double.tryParse(value?.toString() ?? '0')?.toInt() ??
          0;
    }

    bool truthy(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value.toInt() == 1;
      final String text = value?.toString().trim().toLowerCase() ?? '';
      return text == '1' || text == 'true' || text == 'yes' || text == 'win';
    }

    final Map<String, dynamic> direct = asMap(responseData['lucky_result']);
    Map<String, dynamic> result = direct;
    final dynamic listRaw = responseData['lucky_results'];
    if (result.isEmpty && listRaw is List) {
      for (final dynamic item in listRaw) {
        final Map<String, dynamic> candidate = asMap(item);
        if (candidate.isNotEmpty) {
          result = candidate;
          break;
        }
      }
    }

    final int winAmount = asInt(
      result['win_amount'] ??
          result['back_coin'] ??
          result['win_coin'] ??
          responseData['win_amount'] ??
          responseData['back_coin'] ??
          responseData['win_coin'],
    );

    return winAmount > 0 &&
        (truthy(result['is_win'] ?? responseData['is_win']) ||
            asInt(result['multiplier'] ?? responseData['multiplier']) > 0);
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
  }) async {
    String resolvedClientEventId = clientEventId?.trim() ?? '';

    try {
      final user = authController.userProfile.value.user;
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
      final Map<int, int> receiverCoinBaseline = websocketController
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
        "stream_id": streamId.value,
        "livestream_id": streamId.value,
        if (selectedSeatNo.value > 0) "seat_no": selectedSeatNo.value,
        ...pkCommentGiftMetaBody(),
      };

      if (_giftApiVerboseSuccessLogs) {
        _printGiftApiLine('GIFT_API_REQUEST', <String, dynamic>{
          'url': kSentGift,
          'stream_id': streamId.value,
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
        'stream_id': streamId.value,
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
            'livestream_id': streamId.value,
            'stream_id': streamId.value,
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
          authController.userProfile.value.token?.toString().trim() ?? '';

      final response = await dio.post(
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
            authController.userProfile.value.user!.coins =
                responseData['sender']['coins'].toString();
            authController.userProfile.refresh();
          }

          /// ✅ Bulk receiver fallback:
          /// Server sometimes accepts receiver_ids like [100577, 100558],
          /// but websocket broadcasts only one receiver_id. Then the missing
          /// receiver's seat coin does not show on sender device.
          /// Wait a little for websocket; then update only receiver ids that
          /// websocket did not update, so no duplicate coin is added.
          Future.delayed(const Duration(milliseconds: 220), () {
            try {
              websocketController.ensureSenderGiftCoinsAtLeast(
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
              'data': _luckyMap(responseData['data']),
              'sender': _luckyMap(responseData['sender']),
              'receiver': _luckyMap(responseData['receiver']),
              'gift': _luckyMap(
                responseData['gift'] ?? responseData['gift_data'],
              ),
              'lucky_result': _luckyMap(responseData['lucky_result']),
              'lucky_results': responseData['lucky_results'],
              'multiplier': responseData['multiplier'],
              'win_amount': responseData['win_amount'],
              'is_win': responseData['is_win'],
            });
            // Loss responses arrive for every tap. Rebuilding the Lucky result
            // state for each loss adds avoidable work during long Combo bursts.
            // Only a real positive payout needs the WIN/times UI.
            if (_luckyResponseHasVisibleWin(responseData)) {
              showLuckyGiftResult(responseData);
            }

            final isWin = responseData['is_win'] == true;
            final winAmount = responseData['win_amount'] ?? 0;
            final multiplier = responseData['multiplier'] ?? 0;

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
          websocketController.cancelOptimisticGiftAnimation(
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
        websocketController.cancelOptimisticGiftAnimation(
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
      websocketController.cancelOptimisticGiftAnimation(
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
      websocketController.cancelOptimisticGiftAnimation(
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
      selectedGiftSendingId.value = 0;
    }

    return null;
  }

  final giftList = <Map<String, dynamic>>[].obs;
  final giftHistory = <Map<String, dynamic>>[].obs;
  final totalGiftCoins = 0.obs;

  /// Gift coins are stream-aware. Same stream restore keeps coins;
  /// new stream hard resets so old live coins/time cannot carry over.
  final RxInt _giftCoinStreamId = 0.obs;

  void resetLocalLiveStateForNewStream({
    required int newStreamId,
    String source = 'manual',
    bool force = false,
  }) {
    if (newStreamId <= 0) return;

    final oldStream = int.tryParse(streamId.value.toString()) ?? 0;
    final bool isNewStream =
        force || oldStream == 0 || oldStream != newStreamId;

    /*
    |--------------------------------------------------------------------------
    | Same room reopen/resume must preserve realtime state
    |--------------------------------------------------------------------------
    | AudioLiveView calls this during init. Previously old==new still cleared
    | coins/timers and contributed to same-room state resets.
    |--------------------------------------------------------------------------
    */
    if (!isNewStream) {
      streamId.value = newStreamId;
      _giftCoinStreamId.value = newStreamId;

      try {
        websocketController.streamID.value = newStreamId;
      } catch (_) {}

      liveLog(
        '🛡️ Same-room local reset ignored '
            '=> stream=$newStreamId source=$source',
      );
      return;
    }

    streamId.value = newStreamId;
    _giftCoinStreamId.value = newStreamId;

    // Room-scoped roles must never leak from old live to a different live.
    // Example: user was host/admin in room A, then joins room B and sits on a seat.
    // In room B he must be a normal caller until room B explicitly makes him admin.
    isHost.value = false;
    isBroadcaster.value = false;
    isMyGuardian.value = false;
    guardianListData.clear();
    roomGuardianMap.clear();
    guardianNoticeVisible.value = false;
    guardianNoticeText.value = '';
    try {
      homeController.isGuardianPermission.value = false;
      homeController.isGuardianData['is_guardian'] = false;
      homeController.isGuardianData['value'] = 0;
      homeController.isGuardianData.refresh();
    } catch (_) {}

    // Reset every room-scoped collection before the new room can render.
    clearViewerLocal();
    viewerList.clear();
    liveViewerList.clear();
    callList.clear();
    createData.clear();
    removeData.clear();
    broadcasterId.value = 0;
    giftList.clear();

    // Reset volatile room totals only for a genuinely different/new stream.
    totalGiftCoins.value = 0;
    giftHistory.clear();
    luckyGiftResult.clear();
    luckyGiftResultVisible.value = false;
    selectedGiftSendingId.value = 0;

    // Timer must restart from the new stream created_at/start_time.
    resetLiveTimerForNewStream(newStreamId: newStreamId, source: source);

    // Music/Youtube local state belongs to a single room only.
    selectedMusicPath.value = '';
    liveMusicName.value = '';
    liveMusicStatus.value = 'stopped';
    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';

    try {
      websocketController.totalGiftCoins.value = 0;
      websocketController.userGiftCounts.clear();
      websocketController.liveUserGiftCoins.clear();
      websocketController.processedGiftIds.clear();
      websocketController.processedImogiIds.clear();
      websocketController.streamID.value = newStreamId;
    } catch (_) {}

    liveLog(
      '🧹 Local live state reset for ${isNewStream ? 'new' : 'current'} stream => old:$oldStream new:$newStreamId source:$source',
    );
  }

  /// Gift category / lucky gift UI state.
  final selectedGiftCategoryIndex = 0.obs;
  final selectedGiftSendingId = 0.obs;
  final luckyGiftResult = <String, dynamic>{}.obs;
  final luckyGiftResultVisible = false.obs;

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
    final String explicitLucky =
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
    if (categories.isEmpty)
      return giftList.map((e) => Map<String, dynamic>.from(e)).toList();

    final safeIndex = index.clamp(0, categories.length - 1).toInt();
    final category = categories[safeIndex].toLowerCase();

    return giftList
        .map((e) => Map<String, dynamic>.from(e))
        .where((gift) => giftCategoryOf(gift).toLowerCase() == category)
        .toList();
  }

  /// Video-style lucky gift overlay state

  /// Large Lucky payload dumps are disabled in production. They were encoding
  /// and printing the full response several times per tap on the UI isolate.
  void _luckyPrint(String title, dynamic value) {
    // no-op
  }

  int _luckyInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _luckyDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> _luckyMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _luckyText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  Map<String, dynamic> _globalLuckyResultMap(Map<String, dynamic> payload) {
    final Map<String, dynamic> root = Map<String, dynamic>.from(payload);
    final Map<String, dynamic> data = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'])
        : root;
    final List results = data['lucky_results'] is List
        ? data['lucky_results']
        : root['lucky_results'] is List
        ? root['lucky_results']
        : const [];
    final Map<String, dynamic> result = data['lucky_result'] is Map
        ? Map<String, dynamic>.from(data['lucky_result'])
        : root['lucky_result'] is Map
        ? Map<String, dynamic>.from(root['lucky_result'])
        : results.isNotEmpty && results.first is Map
        ? Map<String, dynamic>.from(results.first)
        : <String, dynamic>{};

    final Map<String, dynamic> sender = _luckyMap(
      data['sender'] ??
          data['user'] ??
          data['sender_user'] ??
          root['sender'] ??
          root['user'],
    );
    final Map<String, dynamic> gift = _luckyMap(
      data['gift'] ?? data['gift_data'] ?? root['gift'] ?? root['gift_data'],
    );

    final double multiplier = _luckyDouble(
      result['multiplier'] ??
          result['multiple'] ??
          result['x'] ??
          result['gun'] ??
          data['multiplier'] ??
          data['multiple'] ??
          data['x'] ??
          data['gun'],
    );
    final int winAmount = _luckyInt(
      result['win_amount'] ??
          result['back_coin'] ??
          result['win_coin'] ??
          data['win_amount'] ??
          data['back_coin'] ??
          data['win_coin'],
    );

    return <String, dynamic>{
      ...root,
      ...data,
      ...result,
      'sender': sender,
      'user': sender,
      'gift': gift,
      'multiplier': multiplier,
      'win_amount': winAmount,
      'livestream_id':
      data['livestream_id'] ??
          data['stream_id'] ??
          root['livestream_id'] ??
          root['stream_id'] ??
          result['livestream_id'],
      'channel_name':
      data['channel_name'] ??
          data['agora_channel_name'] ??
          data['room_id'] ??
          root['channel_name'] ??
          root['agora_channel_name'] ??
          root['room_id'],
      'stream_type': data['stream_type'] ?? root['stream_type'] ?? 'audio',
    };
  }

  /// Extract every possible Lucky result shape from API/WebSocket payloads.
  /// Backend may send lucky_result, lucky_results, big_win_events or direct
  /// multiplier/win_amount fields. All are normalized here before UI use.
  List<Map<String, dynamic>> _globalLuckyResultCandidates(
      Map<String, dynamic> payload,
      ) {
    final Map<String, dynamic> root = Map<String, dynamic>.from(payload);
    final Map<String, dynamic> data = _luckyMap(root['data']).isNotEmpty
        ? _luckyMap(root['data'])
        : root;
    final Map<String, dynamic> sender = _luckyMap(
      data['sender'] ?? data['user'] ?? root['sender'] ?? root['user'],
    );
    final Map<String, dynamic> receiver = _luckyMap(
      data['receiver'] ?? root['receiver'],
    );
    final Map<String, dynamic> gift = _luckyMap(
      data['gift'] ?? data['gift_data'] ?? root['gift'] ?? root['gift_data'],
    );

    final List<Map<String, dynamic>> rawResults = <Map<String, dynamic>>[];

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

    final bool hasDirectResult =
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

    final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[];
    for (final result in rawResults) {
      final double multiplier = _luckyDouble(
        result['multiplier'] ??
            result['multiple'] ??
            result['x'] ??
            result['gun'] ??
            data['multiplier'] ??
            data['multiple'] ??
            data['x'] ??
            data['gun'],
      );
      final int winAmount = _luckyInt(
        result['win_amount'] ??
            result['back_coin'] ??
            result['win_coin'] ??
            result['bonus_coin'] ??
            data['win_amount'] ??
            data['back_coin'] ??
            data['win_coin'] ??
            data['bonus_coin'],
      );
      final bool isWin =
          result['is_win'] == true ||
              result['is_win']?.toString() == '1' ||
              data['is_win'] == true ||
              data['is_win']?.toString() == '1' ||
              multiplier > 0 ||
              winAmount > 0;

      normalized.add(<String, dynamic>{
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
      });
    }
    return normalized;
  }

  String _globalLuckyEventId(Map<String, dynamic> data) {
    final Map<String, dynamic> result = _luckyMap(
      data['lucky_result'] ?? data['result'] ?? data['win_result'],
    );

    // Prefer transaction/history/send identifiers over transport event IDs.
    // API response, gift_sent and lucky_gift_result can use different event_id
    // values for the same real gift send, while these IDs remain stable.
    final List<dynamic> values = <dynamic>[
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

    for (final dynamic raw in values) {
      final String value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null' && value != '0') {
        return value;
      }
    }
    return '';
  }

  String _globalLuckyWinFingerprint(Map<String, dynamic> data) {
    final Map<String, dynamic> sender = _luckyMap(
      data['sender'] ?? data['user'],
    );
    final Map<String, dynamic> receiver = _luckyMap(data['receiver']);
    final Map<String, dynamic> gift = _luckyMap(data['gift']);

    return <dynamic>[
      data['livestream_id'] ?? data['stream_id'],
      sender['id'] ?? sender['user_id'] ?? data['sender_id'] ?? data['user_id'],
      receiver['id'] ?? receiver['user_id'] ?? data['receiver_id'],
      gift['id'] ?? gift['gift_id'] ?? data['gift_id'],
      _luckyDouble(data['multiplier']),
      _luckyInt(data['win_amount'] ?? data['back_coin'] ?? data['win_coin']),
    ].map((e) => e?.toString() ?? '').join('|');
  }

  String _globalLuckyWinKey(Map<String, dynamic> data) {
    final String eventId = _globalLuckyEventId(data);
    if (eventId.isNotEmpty) return 'event|$eventId';
    return 'fallback|${_globalLuckyWinFingerprint(data)}';
  }

  /// Called before the websocket cross-room guard. It accepts every gift-like
  /// event and only queues verified 5x+ results.
  void showGlobalLuckyWinBannerFromPayload(Map<String, dynamic> payload) {
    _luckyPrint('GLOBAL LUCKY BANNER RAW PAYLOAD', payload);
    final List<Map<String, dynamic>> candidates = _globalLuckyResultCandidates(
      payload,
    );
    _luckyPrint('GLOBAL LUCKY BANNER CANDIDATES', candidates);

    // A single websocket payload can contain the same result in
    // lucky_result + lucky_results + big_win_events. Keep only one candidate
    // per real occurrence before it reaches the app-wide queue.
    final Set<String> payloadCandidateKeys = <String>{};

    for (final Map<String, dynamic> candidate in candidates) {
      final double multiplier = _luckyDouble(candidate['multiplier']);
      final int winAmount = _luckyInt(candidate['win_amount']);
      if (multiplier < 5 || winAmount <= 0) continue;

      final String realId = _globalLuckyEventId(candidate);
      final String fingerprint = _globalLuckyWinFingerprint(candidate);
      final String timestamp = _luckyText(
        candidate['result_timestamp'] ??
            candidate['timestamp'] ??
            candidate['created_at'] ??
            candidate['updated_at'],
      );
      final String payloadKey = realId.isNotEmpty
          ? 'id|$realId'
          : 'fallback|$fingerprint|$timestamp';

      if (!payloadCandidateKeys.add(payloadKey)) {
        continue;
      }

      _enqueueGlobalLuckyWin(candidate);
    }
  }

  void _enqueueGlobalLuckyWin(Map<String, dynamic> raw) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    final double multiplier = _luckyDouble(data['multiplier']);
    final int winAmount = _luckyInt(
      data['win_amount'] ?? data['back_coin'] ?? data['win_coin'],
    );
    if (multiplier < 5 || winAmount <= 0) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    final String eventId = _globalLuckyEventId(data);
    final String fingerprint = _globalLuckyWinFingerprint(data);
    final String key = _globalLuckyWinKey(data);

    // The same backend win can arrive through API response, gift_sent,
    // lucky_gift_result and the local result handler. One real event ID = one
    // banner. A later new event ID always creates a new banner, even when the
    // sender/gift/multiplier/amount are identical.
    if (_globalLuckyWinPendingKeys.contains(key)) return;

    if (eventId.isNotEmpty) {
      if (_globalLuckyWinSeenKeys.contains(key)) return;
      _globalLuckyWinSeenKeys.add(key);
      _globalLuckyWinRecentFingerprints[fingerprint] = now;
    } else {
      // Some duplicate copies omit event_id. Match those copies against the
      // recent fingerprint of the real event, without blocking later events
      // that arrive with their own unique event ID.
      final int lastSeen = _globalLuckyWinRecentFingerprints[fingerprint] ?? 0;
      if (now - lastSeen < 12000) return;
      _globalLuckyWinRecentFingerprints[fingerprint] = now;
    }

    if (_globalLuckyWinSeenKeys.length > 500) {
      _globalLuckyWinSeenKeys.remove(_globalLuckyWinSeenKeys.first);
    }
    _globalLuckyWinRecentFingerprints.removeWhere(
          (String _, int seenAt) => now - seenAt > 60000,
    );

    _lastGlobalLuckyWinKey = key;
    _lastGlobalLuckyWinAtMs = now;
    data['global_lucky_banner_key'] = key;
    _globalLuckyWinPendingKeys.add(key);
    _globalLuckyWinQueue.addLast(data);

    if (!globalLuckyWinBannerVisible.value) {
      _showNextGlobalLuckyWin();
    }
  }

  void _showNextGlobalLuckyWin() {
    _globalLuckyWinBannerTimer?.cancel();
    _globalLuckyWinBannerTimer = null;

    if (_globalLuckyWinQueue.isEmpty) {
      globalLuckyWinBannerVisible.value = false;
      globalLuckyWinBannerSeconds.value = 0;
      globalLuckyWinData.clear();
      return;
    }

    final Map<String, dynamic> data = _globalLuckyWinQueue.removeFirst();
    globalLuckyWinData.assignAll(data);
    globalLuckyWinBannerSeconds.value = 5;
    globalLuckyWinBannerVisible.value = true;

    // Entry, 5-second stationary countdown and left-side exit are owned by
    // GlobalLuckyWinBanner. The widget calls hideGlobalLuckyWinBanner only after
    // its exit animation finishes, so the next queued 5x+ result cannot overlap.
  }

  void hideGlobalLuckyWinBanner({bool showNext = true}) {
    _globalLuckyWinBannerTimer?.cancel();
    _globalLuckyWinBannerTimer = null;

    final String activeKey =
        globalLuckyWinData['global_lucky_banner_key']?.toString() ?? '';
    if (activeKey.isNotEmpty) {
      _globalLuckyWinPendingKeys.remove(activeKey);
    }

    globalLuckyWinBannerVisible.value = false;
    globalLuckyWinBannerSeconds.value = 0;
    globalLuckyWinData.clear();

    if (showNext && _globalLuckyWinQueue.isNotEmpty) {
      Future<void>.delayed(
        const Duration(milliseconds: 180),
        _showNextGlobalLuckyWin,
      );
    }
  }

  /// Backward-compatible entry used by older animation code.
  void _showGlobalLuckyWinOverlay(Map<String, dynamic> data) {
    _enqueueGlobalLuckyWin(data);
  }

  void _removeGlobalLuckyWinOverlay() {
    hideGlobalLuckyWinBanner(showNext: false);
    _globalLuckyWinQueue.clear();
    _globalLuckyWinPendingKeys.clear();
    try {
      _globalLuckyWinEntry?.remove();
    } catch (_) {}
    _globalLuckyWinEntry = null;
  }

  Future<void> openGlobalLuckyWinRoom(Map<String, dynamic> raw) async {
    hideGlobalLuckyWinBanner();
    final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    final int liveId = _luckyInt(
      data['livestream_id'] ?? data['stream_id'] ?? data['live_id'],
    );
    if (liveId <= 0) return;

    if (streamId.value == liveId ||
        websocketController.streamID.value == liveId ||
        websocketController.activeAudioStreamId.value == liveId) {
      return;
    }

    Map<String, dynamic> liveData = <String, dynamic>{};
    try {
      final dynamic match = websocketController
          .homeController
          .showingLiveStreamList
          .firstWhere((item) {
        if (item is! Map) return false;
        return _luckyInt(
          item['id'] ?? item['livestream_id'] ?? item['stream_id'],
        ) ==
            liveId;
      }, orElse: () => null);
      if (match is Map) liveData = Map<String, dynamic>.from(match);
    } catch (_) {}

    final Map<String, dynamic> sender = _luckyMap(
      data['sender'] ?? data['user'],
    );
    final Map<String, dynamic> receiver = _luckyMap(data['receiver']);
    final int receiverId = _luckyInt(
      receiver['id'] ?? receiver['user_id'] ?? data['receiver_id'],
    );
    liveData = <String, dynamic>{
      ...data,
      ...liveData,
      'id': liveId,
      'livestream_id': liveId,
      'stream_id': liveId,
      if (receiverId > 0) 'owner_user_id': receiverId,
      if (receiverId > 0) 'user_id': receiverId,
      if (receiver.isNotEmpty) 'user': receiver,
      if (receiver.isEmpty && sender.isNotEmpty) 'user': sender,
    };

    final String channelName = _luckyText(
      liveData['room_id'] ??
          liveData['channel_name'] ??
          liveData['agora_channel_name'] ??
          liveData['agora_channel'] ??
          liveData['owner_user_id'] ??
          liveData['user_id'] ??
          receiver['id'] ??
          sender['id'],
    );
    if (channelName.isEmpty) return;

    final AudienceJoinController joinController =
    Get.isRegistered<AudienceJoinController>()
        ? Get.find<AudienceJoinController>()
        : Get.put(AudienceJoinController());

    await joinController.joinAsAudience(
      channelName: channelName,
      data: liveData,
    );
  }

  void showLuckyGiftResult(Map<String, dynamic> data) {
    _luckyPrint('SHOW LUCKY GIFT RESULT INPUT', data);
    final map = Map<String, dynamic>.from(data);
    if (!map.containsKey('timestamp') || map['timestamp'] == null) {
      map['timestamp'] = DateTime.now().toIso8601String();
    }

    luckyGiftResult.value = map;
    luckyGiftResultVisible.value = true;

    _luckyPrint('SHOW LUCKY GIFT RESULT STATE', {
      'luckyGiftResultVisible': luckyGiftResultVisible.value,
      'luckyGiftResult': luckyGiftResult,
    });

    showLuckyGiftVideoStyleResult(map);
  }

  void showLuckyGiftVideoStyleResult(Map<String, dynamic> payload) {
    try {
      _luckyPrint('LUCKY VIDEO STYLE RAW PAYLOAD', payload);
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final sender = _luckyMap(
        data['sender'] ??
            data['user'] ??
            data['sender_user'] ??
            payload['sender'] ??
            payload['user'],
      );

      final receiver = _luckyMap(data['receiver'] ?? payload['receiver']);

      final gift = _luckyMap(
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

      Map<String, dynamic> firstResult = {};
      if (results.isNotEmpty && results.first is Map) {
        firstResult = Map<String, dynamic>.from(results.first);
      }

      _luckyPrint('LUCKY VIDEO STYLE PARSED PARTS', {
        'data': data,
        'sender': sender,
        'receiver': receiver,
        'gift': gift,
        'lucky_results': results,
        'first_result': firstResult,
      });

      final double rawMultiplier = _luckyDouble(
        firstResult['multiplier'] ??
            data['multiplier'] ??
            data['multiple'] ??
            data['x'] ??
            data['gun'],
      );
      final double visualMultiplier = rawMultiplier <= 0 ? 1 : rawMultiplier;

      final int winAmount = _luckyInt(
        firstResult['win_amount'] ??
            firstResult['back_coin'] ??
            firstResult['win_coin'] ??
            data['win_amount'] ??
            data['back_coin'] ??
            data['win_coin'],
      );

      final bool isWin =
          firstResult['is_win'] == true ||
              firstResult['is_win'].toString() == '1' ||
              firstResult['is_win'].toString().toLowerCase() == 'true' ||
              data['is_win'] == true ||
              data['is_win']?.toString() == '1' ||
              winAmount > 0 ||
              rawMultiplier > 0;

      final String winType =
      (firstResult['win_type'] ??
          data['win_type'] ??
          (visualMultiplier >= 50 || winAmount >= 5000
              ? 'jackpot'
              : isWin
              ? 'small_win'
              : 'loss'))
          .toString()
          .toLowerCase();

      final bool isBigWin =
          winType.contains('big') ||
              winType.contains('jackpot') ||
              visualMultiplier >= 50 ||
              winAmount >= 5000 ||
              data['is_big_win'] == true ||
              data['is_jackpot'] == true;

      // Every new event gets a unique serial. An older 5-second timer can never
      // hide a newer lucky gift animation.
      final int serial = ++_giftAnimationSerial;
      final String eventTimestamp =
          '${DateTime.now().microsecondsSinceEpoch}_$serial';

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

      _luckyPrint('LUCKY VIDEO STYLE FINAL NORMALIZED DATA', normalized);

      luckyGiftOverlayData.value = normalized;
      luckyGiftOverlayData.refresh();
      luckyGiftResult.value = normalized;
      luckyGiftResultVisible.value = true;

      /// Small wins stay inside the horizontal in-room card.
      /// Every confirmed 5x and above result can create the app-wide clickable top banner.
      luckyGiftOverlayVisible.value = false;
      luckyGiftCoinRainVisible.value = false;

      if (visualMultiplier >= 5 && winAmount > 0) {
        luckyGiftTickerQueue.add(normalized);
        luckyGiftTickerQueue.refresh();
        _luckyPrint('LUCKY 5X+ GLOBAL BANNER QUEUE DATA', {
          'queue_length': luckyGiftTickerQueue.length,
          'queue': luckyGiftTickerQueue.toList(),
          'banner_data': normalized,
        });
        // Do not enqueue the app-wide banner from the local/in-room result
        // handler. The unified realtime websocket pre-guard is the single
        // authoritative global source. This prevents one 5x+ win from showing
        // 2-4 times through API + gift_sent + lucky_gift_result echoes.
      } else {
        _luckyPrint('LUCKY BELOW 5X OR ZERO WIN - GLOBAL BANNER SKIPPED', {
          'multiplier': visualMultiplier,
          'win_amount': winAmount,
          'normalized_data': normalized,
        });
      }

      Future.delayed(const Duration(seconds: 7), () {
        if (_giftAnimationSerial != serial) return;
        luckyGiftOverlayVisible.value = false;
        luckyGiftResultVisible.value = false;
        luckyGiftCoinRainVisible.value = false;
      });

      liveLog(
        '🍀 5s center gift rain => gift=${gift['name'] ?? gift['gift_name']} '
            'win=$isWin multiplier=$visualMultiplier amount=$winAmount serial=$serial',
      );
    } catch (e) {
      liveLog('❌ showLuckyGiftVideoStyleResult error => $e payload=$payload');
    }
  }

  Future<void> fetchGiftList() async {
    try {
      final response = await dio.get(
        kGiftList,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null && responseData["success"] == true) {
          giftList.assignAll(
            List<Map<String, dynamic>>.from(responseData["data"]),
          );
          liveLog("✅ Gift list updated successfully.");
        } else {
          liveLog("⚠️ No data found.");
        }
      } else {
        liveLog(
          "⚠️ Failed to fetch gifts: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }

  // Fetch gift history for current livestream
  Future<void> fetchGiftHistory() async {
    final now = DateTime.now();
    if (_lastGiftHistoryFetchAt != null &&
        now.difference(_lastGiftHistoryFetchAt!).inMilliseconds < 2500) {
      return;
    }
    _lastGiftHistoryFetchAt = now;

    try {
      final response = await dio.get(
        '$kMainUrl/livestream/${streamId.value}/gift-history',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null && responseData["success"] == true) {
          giftHistory.assignAll(
            List<Map<String, dynamic>>.from(responseData["gift_history"]),
          );
        } else {
          liveLog("⚠️ No gift history found.");
        }
      } else {
        liveLog(
          "⚠️ Failed to fetch gift history: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }

  int _safeCoinInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  void syncLiveGiftCoinsFromPayload(
      Map<String, dynamic> payload, {
        String source = 'payload',
      }) {
    try {
      final Map<String, dynamic> data = payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : payload['live_stream'] is Map
          ? Map<String, dynamic>.from(payload['live_stream'])
          : payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : Map<String, dynamic>.from(payload);

      final String action = (payload['action_type'] ?? payload['action'] ?? '')
          .toString()
          .toLowerCase();

      final bool viewerPayload =
          action.contains('viewer') ||
              action.contains('join') ||
              payload.containsKey('viewer') ||
              payload.containsKey('viewer_data') ||
              data.containsKey('viewer_id');

      final bool hasLiveCoinKey =
          data.containsKey('total_gift_coins') ||
              data.containsKey('total_coins') ||
              data.containsKey('gift_amount') ||
              data.containsKey('stream_coins') ||
              data.containsKey('received_coins');

      /// viewer.user.gifts_coins is user history, not live received total.
      if (viewerPayload && !hasLiveCoinKey) {
        liveLog('🪙 Live gift coin sync skipped viewer payload from $source');
        return;
      }

      final dynamic raw =
          data['total_gift_coins'] ??
              data['total_coins'] ??
              data['gift_amount'] ??
              data['stream_coins'] ??
              data['received_coins'] ??
              data['gifts_coins'];

      if (raw == null) return;

      final int newCoins = _safeCoinInt(raw);
      final int oldCoins = _safeCoinInt(totalGiftCoins.value);
      final int payloadStreamId = _safeCoinInt(
        payload['livestream_id'] ??
            payload['stream_id'] ??
            payload['id'] ??
            data['livestream_id'] ??
            data['stream_id'] ??
            data['id'],
      );

      final int currentStreamId = int.tryParse(streamId.value.toString()) ?? 0;

      /// IMPORTANT FIX:
      /// While the user is inside stream 6810, another host can create stream 6931.
      /// That live_stream_created event must update only the live list, not this room's
      /// gift total. Previously it reset current room gift coins to 0.
      if (currentStreamId > 0 &&
          payloadStreamId > 0 &&
          payloadStreamId != currentStreamId) {
        liveLog(
          '⛔ Live gift coin sync ignored from other stream '
              '=> event:$payloadStreamId current:$currentStreamId source:$source keep=$oldCoins',
        );
        return;
      }

      if (payloadStreamId > 0 &&
          _giftCoinStreamId.value > 0 &&
          payloadStreamId != _giftCoinStreamId.value) {
        _giftCoinStreamId.value = payloadStreamId;
        totalGiftCoins.value = newCoins;
        return;
      }

      if (payloadStreamId > 0 && _giftCoinStreamId.value == 0) {
        _giftCoinStreamId.value = payloadStreamId;
      }

      if (newCoins == 0 && oldCoins > 0) {
        liveLog(
          '🪙 Live gift coin zero reset ignored from $source, keep=$oldCoins',
        );
        return;
      }

      if (newCoins > 0 || oldCoins <= 0) {
        // totalGiftCoins is already Rx. Calling update() rebuilt unrelated
        // GetBuilder trees (including parts of the live page) for every gift.
        totalGiftCoins.value = newCoins;
      }
    } catch (e) {
      liveLog('⚠️ syncLiveGiftCoinsFromPayload error => $e');
    }
  }

  // Fetch total gift coins for current livestream
  Future<void> fetchTotalGiftCoins() async {
    final now = DateTime.now();
    if (_lastTotalGiftCoinsFetchAt != null &&
        now.difference(_lastTotalGiftCoinsFetchAt!).inMilliseconds < 2500) {
      return;
    }
    _lastTotalGiftCoinsFetchAt = now;

    try {
      final int sid = int.tryParse(streamId.value.toString()) ?? 0;

      if (sid <= 0) {
        liveLog("⚠️ fetchTotalGiftCoins skipped: invalid streamId=$sid");
        return;
      }

      final response = await dio.get(
        '$kMainUrl/livestream/$sid/total-gift-coins',
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        if (responseData["success"] == true ||
            responseData.containsKey("total_gift_coins")) {
          final dynamic raw =
              responseData["total_gift_coins"] ??
                  responseData["total_coins"] ??
                  responseData["gifts_coins"] ??
                  responseData["gift_amount"] ??
                  responseData["stream_coins"];

          final int newCoins = _safeCoinInt(raw);
          final int oldCoins = _safeCoinInt(totalGiftCoins.value);
          final bool streamChanged =
              _giftCoinStreamId.value > 0 && sid != _giftCoinStreamId.value;

          if (streamChanged) {
            _giftCoinStreamId.value = sid;
            totalGiftCoins.value = newCoins;
            liveLog(
              "🪙 fetchTotalGiftCoins reset for new stream:$sid coins=$newCoins",
            );
            return;
          }

          if (_giftCoinStreamId.value == 0) _giftCoinStreamId.value = sid;

          /// Backend partial/old response 0 must not reset an already non-zero balance for the same stream.
          if (newCoins == 0 && oldCoins > 0) {
            liveLog(
              "🪙 fetchTotalGiftCoins ignored zero reset, keep=$oldCoins response=$responseData",
            );
            return;
          }

          if (newCoins > 0 || oldCoins <= 0) {
            totalGiftCoins.value = newCoins;
          }
        } else {
          liveLog("⚠️ No gift coins data found.");
        }
      } else {
        liveLog(
          "⚠️ Failed to fetch gift coins: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }

  @override
  void onInit() {
    authController.configureProtectedDio(dio);

    redPacketController = RedPacketController(
      dio: dio,
      authController: authController,
      currentLivestreamIdResolver: () {
        if (streamId.value > 0) return streamId.value;
        try {
          return websocketController.streamID.value;
        } catch (_) {
          return 0;
        }
      },
      currentRoomPacketResolver: () {
        try {
          return Map<String, dynamic>.from(
            websocketController.currentRedPacket,
          );
        } catch (_) {
          return <String, dynamic>{};
        }
      },
      currentRoomPacketUpdater: (Map<String, dynamic> packet) {
        try {
          websocketController.currentRedPacket.value = packet;
          websocketController.redPacketVisible.value = true;
          websocketController.currentRedPacket.refresh();
        } catch (error) {
          liveLog('⚠️ Room Red Packet state update skipped: $error');
        }
      },
    );

    LiveTestingLogger.installDio(dio, owner: 'LivestreamController');
    LiveTestingLogger.printBlock('LIVE TEST LIVESTREAM CONTROLLER INIT', {
      'time': DateTime.now().toIso8601String(),
      'user_id': authController.userProfile.value.user?.id,
      'presence': livePresenceDebugSnapshot,
    });
    fetchGiftList();

    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  void removeBroadcaster({required RtcEngine engine}) async {
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await engine.muteLocalAudioStream(true);
  }

  final selectedGiftId = 0.obs;

  //Video live image pick
  final videoImage = ''.obs;

  Future<void> kycNidShow() async {
    final ImagePicker picker = ImagePicker();

    // Show a bottom sheet with Camera & Gallery options
    await Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text(
                ('Take Photo').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back(); // Close the bottom sheet
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  audioImage.value = image.path;
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text(
                ('Choose from Gallery').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back(); // Close the bottom sheet
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  audioImage.value = image.path;
                }
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[800],
    );
  }

  ///----------------- audio theme --------------------
  final themeList = [].obs;
  Future<void> showTheme() async {
    try {
      final response = await dio.get(kAudioThemeList);

      if (response.statusCode == 200) {
        themeList.value = response.data['data'];
        liveLog(" show theme list   : $themeList");
      } else {
        liveLog("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      liveLog("Error fetching banner list: $e");
    }
  }

  final backgroundList = [].obs;
  Future<void> showBackground() async {
    try {
      final response = await dio.get(kAudioBackgroundList);

      if (response.statusCode == 200) {
        backgroundList.value = response.data['data'];
      } else {
        liveLog("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      liveLog("Error fetching banner list: $e");
    }
  }

  //-------------- theme set create ---------------
  final audioThemeSet = {}.obs;

  void createTheme({required String userId, required int themeID}) async {
    final data = {'user_id': userId, 'theme_id': themeID};
    try {
      liveLog(kAudioThemeSet);
      liveLog(data);
      final response = await dio.post(kAudioThemeSet, data: data);
      if (response.statusCode == 200) {
        audioThemeSet.value = response.data;
        // showTheme();
        Get.back();
        Fluttertoast.showToast(msg: ("Theme set Success").appTr);
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      liveLog(e);
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  //---------------- audio theme show ----------

  Future<void> liveEndTimeCase({
    required int streamId,
    required DateTime startTime,
  }) async {
    final data = {
      'stream_id': streamId,
      'end_time': startTime.toIso8601String(),
    };
    try {
      liveLog('end data $data');
      final response = await dio.post(kLivestreamEndTime, data: data);

      if (response.statusCode == 200) {
        Get.to(
              () => Endlive(),
          arguments: endLiveTime,
          transition: Transition.fade,
          duration: const Duration(milliseconds: 500),
        );
        endLiveTime.value = response.data;
        liveLog(" show end time: $endLiveTime");
      } else {
        liveLog("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      liveLog("Error fetching banner list: $e");
    }
  }

  //-----------------------for live stream actions------------------------------------

  RxBool isAudioEnabled = true.obs;
  final AgoraService _agoraService = AgoraService();
  RxBool isVideoEnabled = true.obs;

  /// ===================== BROAD SPEAKER / REMOTE AUDIO MUTE =====================
  /// Eta local device only: mic mute hobe na, sudhu onno sobar voice ei device-e off/on hobe.
  final RxBool isBroadSpeakerMuted = false.obs;

  Future<void> applyBroadSpeakerMute({
    RtcEngine? rtcEngine,
    bool? muted,
  }) async {
    final bool shouldMute = muted ?? isBroadSpeakerMuted.value;
    final engine = rtcEngine ?? _agoraService.engine;

    if (engine == null) {
      liveLog('⚠️ Broad speaker mute skipped: Agora engine null');
      return;
    }

    try {
      /// 1) Main reliable local playback volume control.
      /// 0 = ei device-e remote users voice shona jabe na.
      /// 100 = normal remote users voice shona jabe.
      await engine.adjustPlaybackSignalVolume(shouldMute ? 0 : 100);

      /// 2) Extra safe: remote streams local subscribe mute/unmute.
      await engine.muteAllRemoteAudioStreams(shouldMute);

      /// 3) Speaker route restore when unmuted.
      /// Note: speaker off means local output route off/earpiece, but playback volume 0 handles full mute.
      await engine.setEnableSpeakerphone(!shouldMute);

      liveLog('🔇 Broad speaker local mute applied => $shouldMute');
    } catch (e) {
      liveLog('❌ Broad speaker mute apply failed: $e');
      try {
        await engine.adjustPlaybackSignalVolume(shouldMute ? 0 : 100);
      } catch (_) {}
    }
  }

  Future<void> toggleBroadSpeakerMute({RtcEngine? rtcEngine}) async {
    isBroadSpeakerMuted.value = !isBroadSpeakerMuted.value;
    await applyBroadSpeakerMute(
      rtcEngine: rtcEngine,
      muted: isBroadSpeakerMuted.value,
    );
  }

  /// Host mute korleo gallery music audience-er kache publish thakbe.
  /// Important: host-er jonno muteLocalAudioStream(true) use korbo na,
  /// karon eta audio mixing-o audience-er kache bondho kore dite pare.
  Future<void> _keepMusicPublishingWhenMicMuted(
      RtcEngine engine, {
        required bool micMuted,
      }) async {
    try {
      /// Host-er audio track publish active thakbe, kintu mic signal 0 kore dibo.
      /// muteLocalAudioStream(true) dile Agora music mixing publish-o bondho hoye jete pare.
      await engine.enableAudio();
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      await engine.adjustRecordingSignalVolume(micMuted ? 0 : 100);

      /// Local playout + audience publish volume stable rakha.
      await engine.adjustAudioMixingVolume(80);
      await engine.adjustAudioMixingPlayoutVolume(80);
      await engine.adjustAudioMixingPublishVolume(80);

      liveLog('🎙️ Mic muted=$micMuted, music still publishing to audience');
    } catch (e) {
      liveLog('⚠️ keepMusicPublishingWhenMicMuted failed: $e');
    }
  }

  // Send audio toggle to backend via API
  /// isAudioOn meaning:
  /// true  => audio_on = 1 => mic unmute/on
  /// false => audio_on = 0 => mic mute/off
  Future<void> _sendAudioToggleToBackend(
      bool isAudioOn, {
        int? targetUserId,
        RtcEngine? rtcEngine,
      }) async {
    try {
      final userId =
          targetUserId ??
              authController.userProfile.value.user?.id?.toInt() ??
              0;

      if (userId == 0) {
        Fluttertoast.showToast(msg: ('User not found').appTr);
        return;
      }

      final int currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (userId != currentUserId &&
          !_ensureCanModerateCurrentLive('toggle_user_audio')) {
        return;
      }

      final int audioOn = isAudioOn ? 1 : 0;

      /// 1) Local UI instant update.
      _updateAudioStateInLiveCallList(userId: userId, audioOn: audioOn);

      /// Keep the shared mute map updated instantly so viewers/seat UI do not
      /// wait for the websocket echo to show the correct mic icon.
      websocketController.audioMutedUserMap[userId] = audioOn == 0;
      websocketController.audioMutedUserMap.refresh();

      /// 2) Current user-er mic locally apply.
      if (userId == currentUserId) {
        final bool micMuted = audioOn == 0;
        mute.value = micMuted;
        isMuted.value = micMuted;
        isAudioEnabled.value = !micMuted;

        final engine = rtcEngine ?? _agoraService.engine;
        if (engine != null) {
          await _keepMusicPublishingWhenMicMuted(
            engine,
            micMuted: audioOn == 0,
          );
        }
      }

      /// 3) Backend update. Backend broadcast korbe jate sobai mute icon dekhe.
      final response = await dio.post(
        kAudioToggleUrl(streamId.value, userId),
        data: {
          'livestream_id': streamId.value,
          'user_id': userId,
          'audio_on': audioOn,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        liveLog(
          '✅ Audio toggle sent to backend successfully => user:$userId audio_on:$audioOn',
        );
      } else {
        liveLog(
          '⚠️ Failed to send audio toggle: ${response.statusCode} ${response.data}',
        );
      }
    } catch (e) {
      liveLog('❌ Error sending audio toggle: $e');
      Fluttertoast.showToast(msg: ('Audio toggle failed').appTr);
    }
  }

  void _updateAudioStateInLiveCallList({
    required int userId,
    required int audioOn,
  }) {
    try {
      final index = websocketController.liveCallList.indexWhere((call) {
        final callerId = call['caller_id'];
        final callUserId = call['user']?['id'];
        return callerId.toString() == userId.toString() ||
            callUserId.toString() == userId.toString();
      });

      if (index != -1) {
        final row = Map<String, dynamic>.from(
          websocketController.liveCallList[index],
        );
        row['audio_on'] = audioOn;
        row['is_audio_on'] = audioOn;
        row['is_muted'] = audioOn == 0 ? 1 : 0;
        row['is_muted_by_host'] = audioOn == 0 ? 1 : 0;
        if (row['user'] is Map) {
          final user = Map<String, dynamic>.from(row['user']);
          user['audio_on'] = audioOn;
          user['is_audio_on'] = audioOn;
          user['is_muted'] = audioOn == 0 ? 1 : 0;
          row['user'] = user;
        }
        websocketController.liveCallList[index] = row;
        websocketController.liveCallList.refresh();

        liveLog(
          '✅ Local liveCallList audio updated => user:$userId audio_on:$audioOn',
        );
      } else {
        liveLog(
          '⚠️ User $userId not found in liveCallList for local audio update',
        );
      }
    } catch (e) {
      liveLog('❌ Local audio state update failed: $e');
    }
  }

  void _updateVideoStateInLiveCallList({
    required int userId,
    required int videoOn,
  }) {
    try {
      final index = websocketController.liveCallList.indexWhere((call) {
        final callerId = call['caller_id'];
        final callUserId = call['user']?['id'];
        return callerId.toString() == userId.toString() ||
            callUserId.toString() == userId.toString();
      });

      if (index != -1) {
        websocketController.liveCallList[index]['video_on'] = videoOn;
        websocketController.liveCallList.refresh();
        liveLog('✅ Local video updated => user:$userId video_on:$videoOn');
      }
    } catch (e) {
      liveLog('⚠️ Local video update failed safely: $e');
    }
  }

  // Send video toggle to backend via API
  /// isVideoOn meaning:
  /// true  => video_on = 1 => camera on
  /// false => video_on = 0 => camera off
  Future<void> _sendVideoToggleToBackend(
      bool isVideoOn, {
        int? targetUserId,
        RtcEngine? rtcEngine,
      }) async {
    try {
      final userId =
          targetUserId ??
              authController.userProfile.value.user?.id?.toInt() ??
              0;

      if (userId == 0) {
        Fluttertoast.showToast(msg: ('User not found').appTr);
        return;
      }

      final int currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (userId != currentUserId &&
          !_ensureCanModerateCurrentLive('toggle_user_video')) {
        return;
      }

      final int videoOn = isVideoOn ? 1 : 0;

      /// Local UI instant update.
      _updateVideoStateInLiveCallList(userId: userId, videoOn: videoOn);

      /// Current user camera locally apply.
      final engine = rtcEngine ?? _agoraService.engine;
      if (userId == currentUserId && engine != null) {
        await engine.enableLocalVideo(isVideoOn);
        await engine.muteLocalVideoStream(!isVideoOn);
      }

      final response = await dio.post(
        kVideoToggleUrl(streamId.value, userId),
        data: {
          'livestream_id': streamId.value,
          'user_id': userId,
          'video_on': videoOn,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        liveLog('✅ Video toggle backend ok => user:$userId video_on:$videoOn');
      } else {
        liveLog('⚠️ Video toggle failed: ${response.statusCode}');
      }
    } catch (e) {
      liveLog('⚠️ Video toggle failed safely: $e');
      Fluttertoast.showToast(msg: ('Video toggle failed').appTr);
    }
  }

  // Toggle specific user's audio (for moderation / broadcaster / current user)
  Future<void> toggleSpecificUserAudio(
      int targetUserId, {
        RtcEngine? rtcEngine,
      }) async {
    final isAudioOn = websocketController.getUserAudioStatus(targetUserId);
    final bool newAudioOn = !isAudioOn;

    await _sendAudioToggleToBackend(
      newAudioOn,
      targetUserId: targetUserId,
      rtcEngine: rtcEngine,
    );
  }

  /// Use this from any UI button: bottomSheet, writeComment, toolbar, etc.
  Future<void> toggleMyAudioFromAnyButton({RtcEngine? rtcEngine}) async {
    final userId = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (userId == 0) {
      Fluttertoast.showToast(msg: ('User not found').appTr);
      return;
    }

    await toggleSpecificUserAudio(userId, rtcEngine: rtcEngine);
  }

  // Toggle specific user's video (for moderation)
  Future<void> toggleSpecificUserVideo(
      int targetUserId, {
        RtcEngine? rtcEngine,
      }) async {
    final isVideoOn = websocketController.getUserVideoStatus(targetUserId);
    final bool newVideoState = !isVideoOn;

    await _sendVideoToggleToBackend(
      newVideoState,
      targetUserId: targetUserId,
      rtcEngine: rtcEngine,
    );
  }

  // -----------------------End for live stream actions------------------------------------

  ///------------------- live stream end time ----------------
  final endLiveTime = {}.obs;

  // Add user to room blacklist
  Future<Map<String, dynamic>?> addToRoomBlacklist(
      int livestreamId,
      int userId, {
        String reason = 'room_blacklist',
      }) async {
    if (!_ensureCanModerateCurrentLive('room_blacklist')) return null;
    try {
      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/room-blacklist',
        data: {'user_id': userId, 'reason': reason},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        liveLog(
          "✅ Successfully added user to room blacklist: ${response.data}",
        );
        return response.data;
      } else {
        liveLog(
          "⚠️ Failed to add user to room blacklist: ${response.statusCode} - ${response.data}",
        );
        return null;
      }
    } catch (e) {
      liveLog("❌ Error adding user to room blacklist: $e");
      return null;
    }
  }

  // Kick out user from livestream
  Future<bool> kickOutUser(int userId) async {
    if (!_ensureCanModerateCurrentLive('kick_user')) return false;
    try {
      final url = kKickOutUrl(streamId.value, userId);
      final token = authController.userProfile.value.token;
      final response = await dio.post(
        url,
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          // এইটা দিলে 403 তেও catch করবে instead of throw
          validateStatus: (status) => true,
        ),
      );

      liveLog("📌 Status Code: ${response.statusCode}");
      liveLog("📌 Response Data: ${response.data}");

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 403) {
        liveLog('❌ Forbidden: You don\'t have permission or token expired.');
        Get.snackbar(
          ('Permission Denied').appTr,
          ('Only livestream creator or admin can kick users').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      } else if (response.statusCode == 404) {
        liveLog('❌ Livestream not found');
        Get.snackbar(
          ('Error').appTr,
          ('Livestream not found').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      } else {
        liveLog('❌ Failed to kick out user: ${response.statusCode}');
        Get.snackbar(
          ('Error').appTr,
          ('Failed to kick out user. Please try again.').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      liveLog('⚠️ Error kicking out user: $e');
      return false;
    }
  }

  // Get available seats for livestream
  final availableSeatsData = {}.obs;

  /// ✅ STEP 3A PERFORMANCE: available seats API is called from room open,
  /// resume, safety sync and room settings. A very small cache + in-flight
  /// guard prevents 3-5 duplicate HTTP calls in the same second while keeping
  /// realtime seat updates controlled by WebSocket.
  final Map<int, Map<String, dynamic>> _availableSeatsFastCache =
  <int, Map<String, dynamic>>{};
  final Map<int, DateTime> _availableSeatsFastCacheAt = <int, DateTime>{};
  final Map<int, Future<Map<String, dynamic>?>> _availableSeatsInFlight =
  <int, Future<Map<String, dynamic>?>>{};
  static const Duration _availableSeatsFastCacheTtl = Duration(
    milliseconds: 1800,
  );

  Future<Map<String, dynamic>?> getAvailableSeats(int livestreamId) async {
    if (livestreamId <= 0) return null;

    final now = DateTime.now();
    final cached = _availableSeatsFastCache[livestreamId];
    final cachedAt = _availableSeatsFastCacheAt[livestreamId];
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _availableSeatsFastCacheTtl) {
      availableSeatsData.value = cached;
      liveLog('⚡ Available seats cache hit => stream:$livestreamId');
      return cached;
    }

    final running = _availableSeatsInFlight[livestreamId];
    if (running != null) {
      liveLog(
        '♻️ Available seats API joined in-flight => stream:$livestreamId',
      );
      return running;
    }

    final future = _getAvailableSeatsFromNetwork(livestreamId);
    _availableSeatsInFlight[livestreamId] = future;

    try {
      final data = await future;
      if (data != null) {
        _availableSeatsFastCache[livestreamId] = Map<String, dynamic>.from(
          data,
        );
        _availableSeatsFastCacheAt[livestreamId] = DateTime.now();
      }
      return data;
    } finally {
      _availableSeatsInFlight.remove(livestreamId);
    }
  }

  Future<Map<String, dynamic>?> _getAvailableSeatsFromNetwork(
      int livestreamId,
      ) async {
    Future<Response> request(String url) {
      return dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
    }

    try {
      /// New backend route.
      final primaryUrl = '$kMainUrl/livestream/$livestreamId/available-seats';

      /// Old route fallback, jodi server-e old endpoint thake.
      final fallbackUrl = '$kMainUrl/availableseats/$livestreamId';

      Response response;

      try {
        response = await request(primaryUrl);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          liveLog(
            'ℹ️ New available seats route not found, trying old route...',
          );
          response = await request(fallbackUrl);
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        availableSeatsData.value = response.data;
        liveLog("✅ Available seats fetched: ${response.data}");

        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        _reconcileSelfSeatFromAvailableSeats(data);

        return data;
      } else {
        liveLog(
          "⚠️ Failed to fetch available seats: ${response.statusCode} - ${response.data}",
        );
        return null;
      }
    } catch (e) {
      liveLog("❌ Error fetching available seats: $e");
      return null;
    }
  }

  Future<void> sendMusicEvent({
    required int livestreamId,
    required int hostId,
    required String status,
    String? musicName,
  }) async {
    if (livestreamId <= 0 || hostId <= 0) return;
    if (!_ensureCanModerateCurrentLive('music_$status')) return;

    try {
      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/music-control',
        data: {
          'host_id': hostId,
          'music_status': status,
          'music_name': musicName,
          // Optional fields: old backend may ignore them safely.
          'music_position': musicPositionMs.value,
          'music_duration': musicDurationMs.value,
          'music_volume': musicVolume.value,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        liveLog('✅ Music event sent: ${response.data}');
      } else {
        liveLog(
          '⚠️ Music event failed: ${response.statusCode} ${response.data}',
        );
      }
    } catch (e) {
      // Local Agora playback must not stop only because websocket/API failed.
      liveLog('❌ Music event error: $e');
    }
  }

  Future<void> pickAndPlayLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!_ensureCanModerateCurrentLive('pick_music')) return;
    if (rtcEngine == null) {
      Fluttertoast.showToast(msg: ('Audio engine not ready').appTr);
      return;
    }
    if (_musicActionRunning) return;

    try {
      _musicActionRunning = true;
      musicLoading.value = true;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path?.trim() ?? '';

      if (path.isEmpty || !File(path).existsSync()) {
        Fluttertoast.showToast(msg: ('Music file not found').appTr);
        return;
      }

      final name = file.name.trim().isNotEmpty
          ? file.name.trim()
          : ('Music').appTr;
      await startLiveMusic(
        rtcEngine: rtcEngine,
        path: path,
        name: name,
        status: liveMusicStatus.value == 'stopped' ? 'playing' : 'changed',
      );
    } catch (e, st) {
      liveLog('❌ Pick/play music error: $e\n$st');
      Fluttertoast.showToast(msg: ('Music play failed').appTr);
    } finally {
      musicLoading.value = false;
      _musicActionRunning = false;
    }
  }

  Future<void> playRecentLiveMusic({
    required RtcEngine? rtcEngine,
    required Map<String, String> music,
  }) async {
    if (!_ensureCanModerateCurrentLive('play_recent_music')) return;
    if (rtcEngine == null || _musicActionRunning) return;
    final path = music['path']?.trim() ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      recentLiveMusics.removeWhere((item) => item['path'] == path);
      Fluttertoast.showToast(
        msg: ('This music file is no longer available').appTr,
      );
      return;
    }

    _musicActionRunning = true;
    musicLoading.value = true;
    try {
      await startLiveMusic(
        rtcEngine: rtcEngine,
        path: path,
        name: music['name']?.trim().isNotEmpty == true
            ? music['name']!.trim()
            : ('Music').appTr,
        status: liveMusicStatus.value == 'stopped' ? 'playing' : 'changed',
      );
    } finally {
      musicLoading.value = false;
      _musicActionRunning = false;
    }
  }

  void _rememberLiveMusic(String path, String name) {
    recentLiveMusics.removeWhere((item) => item['path'] == path);
    recentLiveMusics.insert(0, {'path': path, 'name': name});
    if (recentLiveMusics.length > 8) {
      recentLiveMusics.removeRange(8, recentLiveMusics.length);
    }
  }

  int _safeMusicValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  /// ================= PROFESSIONAL LIVE MUSIC STATE =================

  final RxBool musicActionRunning = false.obs;

  Future<void> _loadAudioMixingDuration(RtcEngine rtcEngine) async {
    try {
      /// Agora 6.x:
      /// getAudioMixingDuration() kono path receive kore na.
      final int duration = _safeMusicValue(
        await rtcEngine.getAudioMixingDuration(),
      );

      musicDurationMs.value = duration > 0 ? duration : 0;

      liveLog('🎵 Music duration => ${musicDurationMs.value} ms');
    } catch (e) {
      musicDurationMs.value = 0;
      liveLog('⚠️ Music duration unavailable => $e');
    }
  }

  Future<void> startLiveMusic({
    required RtcEngine rtcEngine,
    required String path,
    required String name,
    String status = 'playing',
  }) async {
    if (!_ensureCanModerateCurrentLive('start_music')) return;
    if (musicActionRunning.value) return;

    final cleanPath = path.trim();
    final cleanName = name.trim().isEmpty ? 'Unknown Music' : name.trim();

    if (cleanPath.isEmpty) {
      Fluttertoast.showToast(msg: ('Music file path is empty').appTr);
      return;
    }

    final file = File(cleanPath);

    if (!await file.exists()) {
      Fluttertoast.showToast(msg: ('Music file not found').appTr);
      return;
    }

    musicActionRunning.value = true;
    musicLoading.value = true;

    try {
      /// Music start hole YouTube stop hobe.
      if (liveYoutubeStatus.value != 'stopped') {
        await stopYoutube();
      }

      _stopMusicProgressTracking(reset: true);

      /// Old mixing safely stop.
      try {
        await rtcEngine.stopAudioMixing();
      } catch (_) {}

      await rtcEngine.startAudioMixing(
        filePath: cleanPath,
        loopback: false,
        cycle: musicRepeat.value ? -1 : 1,
        startPos: 0,
      );

      /// Local + audience volume.
      await rtcEngine.adjustAudioMixingVolume(musicVolume.value.clamp(0, 100));

      try {
        await rtcEngine.adjustAudioMixingPlayoutVolume(
          musicVolume.value.clamp(0, 100),
        );
      } catch (e) {
        liveLog('⚠️ Mixing playout volume unsupported/failed => $e');
      }

      try {
        await rtcEngine.adjustAudioMixingPublishVolume(
          musicVolume.value.clamp(0, 100),
        );
      } catch (e) {
        liveLog('⚠️ Mixing publish volume unsupported/failed => $e');
      }

      /// Mic mute thakleo music publish cholbe.
      await _keepMusicPublishingWhenMicMuted(rtcEngine, micMuted: mute.value);

      selectedMusicPath.value = cleanPath;
      liveMusicName.value = cleanName;

      liveMusicStatus.value = status == 'changed' ? 'changed' : 'playing';

      musicPositionMs.value = 0;

      _rememberLiveMusic(cleanPath, cleanName);

      /// IMPORTANT FIX:
      /// path argument remove kora hoyeche.
      await _loadAudioMixingDuration(rtcEngine);

      _startMusicProgressTracking(rtcEngine);

      final sid = streamId.value;
      final hostId = authController.userProfile.value.user?.id?.toInt() ?? 0;

      if (sid > 0 && hostId > 0) {
        await sendMusicEvent(
          livestreamId: sid,
          hostId: hostId,
          status: status == 'changed' ? 'changed' : 'playing',
          musicName: cleanName,
        );
      }

      Fluttertoast.showToast(msg: ('Music started').appTr);
    } catch (e, st) {
      _stopMusicProgressTracking(reset: true);

      selectedMusicPath.value = '';
      liveMusicName.value = '';
      liveMusicStatus.value = 'stopped';

      liveLog('❌ startLiveMusic error => $e');
      liveLog('$st');

      Fluttertoast.showToast(msg: ('Music start failed').appTr);
    } finally {
      musicLoading.value = false;
      musicActionRunning.value = false;
    }
  }

  void _startMusicProgressTracking(RtcEngine rtcEngine) {
    _musicProgressTimer?.cancel();
    _musicProgressTimer = Timer.periodic(const Duration(milliseconds: 700), (
        _,
        ) async {
      if (!isLiveMusicPlaying || musicSeeking.value) return;
      try {
        final position = await rtcEngine.getAudioMixingCurrentPosition();
        if (position >= 0) musicPositionMs.value = position;
      } catch (_) {}
    });
  }

  void _stopMusicProgressTracking({bool reset = false}) {
    _musicProgressTimer?.cancel();
    _musicProgressTimer = null;
    if (reset) {
      musicPositionMs.value = 0;
      musicDurationMs.value = 0;
    }
  }

  Future<void> seekLiveMusic({
    required RtcEngine? rtcEngine,
    required int positionMs,
  }) async {
    if (rtcEngine == null || selectedMusicPath.value.isEmpty) return;
    final max = musicDurationMs.value > 0 ? musicDurationMs.value : positionMs;
    final safePosition = positionMs.clamp(0, max).toInt();
    musicSeeking.value = true;
    try {
      await rtcEngine.setAudioMixingPosition(safePosition);
      musicPositionMs.value = safePosition;
    } catch (e) {
      liveLog('❌ seekLiveMusic error: $e');
    } finally {
      musicSeeking.value = false;
    }
  }

  Future<void> setLiveMusicVolume({
    required RtcEngine? rtcEngine,
    required int volume,
  }) async {
    final safeVolume = volume.clamp(0, 100).toInt();
    musicVolume.value = safeVolume;
    try {
      await rtcEngine?.adjustAudioMixingVolume(safeVolume);
    } catch (e) {
      liveLog('❌ setLiveMusicVolume error: $e');
    }
  }

  Future<void> toggleLiveMusicRepeat({required RtcEngine? rtcEngine}) async {
    musicRepeat.toggle();
    final path = selectedMusicPath.value;
    final name = liveMusicName.value;
    if (rtcEngine != null && path.isNotEmpty && File(path).existsSync()) {
      final oldPosition = musicPositionMs.value;
      await startLiveMusic(
        rtcEngine: rtcEngine,
        path: path,
        name: name,
        status: 'changed',
      );
      if (oldPosition > 0) {
        await seekLiveMusic(rtcEngine: rtcEngine, positionMs: oldPosition);
      }
    }
  }

  Future<void> pauseLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!_ensureCanModerateCurrentLive('pause_music')) return;
    if (rtcEngine == null || liveMusicStatus.value == 'paused') return;
    try {
      await rtcEngine.pauseAudioMixing();
      liveMusicStatus.value = 'paused';
      await sendMusicEvent(
        livestreamId: streamId.value,
        hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
        status: 'paused',
        musicName: liveMusicName.value,
      );
    } catch (e) {
      liveLog('❌ pauseLiveMusic error: $e');
    }
  }

  Future<void> resumeLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!_ensureCanModerateCurrentLive('resume_music')) return;
    if (rtcEngine == null || selectedMusicPath.value.isEmpty) return;
    try {
      await rtcEngine.resumeAudioMixing();
      await _keepMusicPublishingWhenMicMuted(rtcEngine, micMuted: mute.value);
      await rtcEngine.adjustAudioMixingVolume(musicVolume.value);
      liveMusicStatus.value = 'resumed';
      _startMusicProgressTracking(rtcEngine);

      await sendMusicEvent(
        livestreamId: streamId.value,
        hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
        status: 'resumed',
        musicName: liveMusicName.value,
      );
    } catch (e) {
      liveLog('❌ resumeLiveMusic error: $e');
    }
  }

  Future<void> stopLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!_ensureCanModerateCurrentLive('stop_music')) return;
    if (_musicActionRunning) return;
    _musicActionRunning = true;
    try {
      await rtcEngine?.stopAudioMixing();
      _stopMusicProgressTracking(reset: true);
      selectedMusicPath.value = '';
      liveMusicName.value = '';
      liveMusicStatus.value = 'stopped';

      await sendMusicEvent(
        livestreamId: streamId.value,
        hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
        status: 'stopped',
        musicName: null,
      );
    } catch (e) {
      liveLog('❌ stopLiveMusic error: $e');
    } finally {
      _musicActionRunning = false;
    }
  }

  /// ===================== LIVE YOUTUBE APIs =====================
  String extractYoutubeVideoId(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';

    final regExpList = <RegExp>[
      RegExp(r'(?:v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];

    for (final reg in regExpList) {
      final match = reg.firstMatch(raw);
      if (match != null && match.groupCount >= 1) {
        return match.group(1) ?? '';
      }
    }

    /// If user pastes only video id.
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) {
      return raw;
    }

    return '';
  }

  Future<void> sendYoutubeControl({
    required int livestreamId,
    required int hostId,
    required String status,
    String? youtubeUrl,
  }) async {
    if (livestreamId == 0 || hostId == 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return;
    }
    if (!_ensureCanModerateCurrentLive('youtube_$status')) return;

    try {
      youtubeLoading.value = true;

      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/youtube-control',
        data: {
          'host_id': hostId,
          'youtube_status': status,
          if (youtubeUrl != null) 'youtube_url': youtubeUrl,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        final videoId =
        (data['youtube_video_id'] ??
            (youtubeUrl == null
                ? ''
                : extractYoutubeVideoId(youtubeUrl)))
            .toString();
        final url = (data['youtube_url'] ?? youtubeUrl ?? liveYoutubeUrl.value)
            .toString();

        liveYoutubeStatus.value = status;
        liveYoutubeUrl.value = status == 'stopped' ? '' : url;
        liveYoutubeVideoId.value = status == 'stopped' ? '' : videoId;

        liveLog('✅ YouTube control sent: ${response.data}');
      } else {
        liveLog(
          '⚠️ YouTube control failed: ${response.statusCode} ${response.data}',
        );
        Fluttertoast.showToast(msg: ('YouTube control failed').appTr);
      }
    } catch (e) {
      liveLog('❌ YouTube control error: $e');
      Fluttertoast.showToast(msg: ('YouTube control failed').appTr);
    } finally {
      youtubeLoading.value = false;
    }
  }

  Future<void> playOrChangeYoutube(String url) async {
    final videoId = extractYoutubeVideoId(url);
    if (videoId.isEmpty) {
      Fluttertoast.showToast(msg: ('Invalid YouTube link').appTr);
      return;
    }

    final status = liveYoutubeStatus.value == 'stopped' ? 'playing' : 'changed';
    await sendYoutubeControl(
      livestreamId: streamId.value,
      hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
      status: status,
      youtubeUrl: url,
    );
  }

  Future<void> pauseYoutube() async {
    await sendYoutubeControl(
      livestreamId: streamId.value,
      hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
      status: 'paused',
      youtubeUrl: liveYoutubeUrl.value,
    );
  }

  Future<void> resumeYoutube() async {
    await sendYoutubeControl(
      livestreamId: streamId.value,
      hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
      status: 'resumed',
      youtubeUrl: liveYoutubeUrl.value,
    );
  }

  Future<void> stopYoutube() async {
    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';

    await sendYoutubeControl(
      livestreamId: streamId.value,
      hostId: authController.userProfile.value.user?.id?.toInt() ?? 0,
      status: 'stopped',
      youtubeUrl: null,
    );
  }

  Future<Map<String, dynamic>?> fetchYoutubeState(int livestreamId) async {
    if (livestreamId == 0) return null;

    try {
      final response = await dio.get(
        '$kMainUrl/livestream/$livestreamId/youtube-state',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        if (data is Map) {
          final status = (data['youtube_status'] ?? 'stopped')
              .toString()
              .toLowerCase();
          final url = (data['youtube_url'] ?? '').toString();
          final videoId =
          (data['youtube_video_id'] ?? extractYoutubeVideoId(url))
              .toString();

          liveYoutubeStatus.value = status;
          liveYoutubeUrl.value = status == 'stopped' ? '' : url;
          liveYoutubeVideoId.value = status == 'stopped' ? '' : videoId;

          liveLog('✅ YouTube state fetched: $data');
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      liveLog('❌ YouTube state fetch error: $e');
    }

    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';
    return null;
  }

  /// YouTube player error 152/150/101/unavailable hole host side theke call korben.
  /// Eta backend-e stopped event pathabe, audience UI clear hobe.
  Future<void> stopYoutubeBecauseUnavailable() async {
    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';

    final sid = streamId.value;
    final hostId = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (sid != 0 && hostId != 0) {
      await sendYoutubeControl(
        livestreamId: sid,
        hostId: hostId,
        status: 'stopped',
        youtubeUrl: null,
      );
    }

    Fluttertoast.showToast(
      msg:
      ('This YouTube video cannot be played inside the app. Try another link.')
          .appTr,
    );
  }

  /// ===================== LIVE ROOM REALTIME EDIT =====================
  /// Backend route:
  /// POST /livestream/{id}/edit/{userId}
  /// Expected event: action_type = live_stream_updated
  final roomEditLoading = false.obs;

  /// ===================== ROOM SETTINGS / SAFETY STATE =====================
  /// These values are updated from edit API response and realtime events.
  /// 1 = enabled/blocked/hidden/locked, 0 = disabled/allowed/show/unlocked.
  final roomSettingsLoading = false.obs;
  final liveRoomLocked = false.obs;
  final liveCommentLocked = false.obs;
  final liveHiddenRoom = false.obs;
  final liveScreenRecordBlocked = false.obs;
  final liveScreenshotBlocked = false.obs;

  static const MethodChannel _screenSecurityChannel = MethodChannel(
    'linlive/screen_security',
  );

  int _firstIntFromMap(
      Map<String, dynamic> map,
      List<String> keys, {
        int defaultValue = 0,
      }) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return _toInt(map[key]);
      }
    }
    return defaultValue;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is double) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on' ||
        text == 'locked' ||
        text == 'hidden' ||
        text == 'blocked' ||
        text == 'enabled';
  }

  Future<void> _setNativeScreenSecure(bool enable) async {
    try {
      await _screenSecurityChannel.invokeMethod(enable ? 'enable' : 'disable');
      liveLog("🛡️ SCREEN SECURE NATIVE ${enable ? 'ENABLED' : 'DISABLED'}");
    } on MissingPluginException catch (e) {
      liveLog('⚠️ SCREEN SECURE native channel missing => $e');
    } catch (e) {
      liveLog('❌ SCREEN SECURE ERROR => $e');
    }
  }

  Map<String, dynamic> _currentLiveMapForRoomSettings() {
    final raw = createStreamData['livestreamdata'] is Map
        ? Map<String, dynamic>.from(createStreamData['livestreamdata'])
        : createStreamData['livestream'] is Map
        ? Map<String, dynamic>.from(createStreamData['livestream'])
        : <String, dynamic>{};

    final int sid = streamId.value > 0
        ? streamId.value
        : websocketController.streamID.value;
    final int cachedSid = _toInt(
      raw['id'] ?? raw['livestream_id'] ?? raw['stream_id'],
    );

    if (sid > 0 && cachedSid > 0 && sid != cachedSid) {
      liveLog(
        '🧹 Ignored stale room settings cache => current:$sid cached:$cachedSid',
      );
      return <String, dynamic>{};
    }

    return raw;
  }

  void syncRoomSafetyFromCurrentLiveData({
    String source = 'current_live_data',
  }) {
    final current = _currentLiveMapForRoomSettings();
    if (current.isEmpty) return;
    applyRoomSafetySettingsFromPayload(current, source: source);
  }

  void applyRoomSafetySettingsFromPayload(
      Map<String, dynamic> payload, {
        String source = 'unknown',
      }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};

      final Map<String, dynamic> live = payload['livestreamdata'] is Map
          ? Map<String, dynamic>.from(payload['livestreamdata'])
          : payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : <String, dynamic>{};

      final merged = <String, dynamic>{...payload, ...data, ...live};

      int readSetting(List<String> keys, bool current) {
        for (final key in keys) {
          if (merged.containsKey(key) && merged[key] != null) {
            return _truthy(merged[key]) ? 1 : 0;
          }
        }
        return current ? 1 : 0;
      }

      final int roomLock = readSetting([
        'room_lock',
        'is_room_locked',
        'room_locked',
      ], liveRoomLocked.value);
      final int commentLock = readSetting([
        'lock_coment',
        'comment_locked',
        'is_comment_locked',
      ], liveCommentLocked.value);
      final int hiddenRoom = readSetting([
        'hidden_room',
        'is_hidden_room',
        'room_hidden',
      ], liveHiddenRoom.value);
      final int screenRecord = readSetting([
        'screen_records',
        'screen_record_enabled',
      ], liveScreenRecordBlocked.value);
      final int screenShort = readSetting([
        'screenshort',
        'screenshot_enabled',
      ], liveScreenshotBlocked.value);

      liveRoomLocked.value = roomLock == 1;
      liveCommentLocked.value = commentLock == 1;
      liveHiddenRoom.value = hiddenRoom == 1;
      liveScreenRecordBlocked.value = screenRecord == 1;
      liveScreenshotBlocked.value = screenShort == 1;

      if (createStreamData['livestreamdata'] is Map) {
        final current = Map<String, dynamic>.from(
          createStreamData['livestreamdata'],
        );
        createStreamData['livestreamdata'] = {
          ...current,
          'room_lock': roomLock,
          'is_room_locked': roomLock,
          'room_locked': roomLock,
          'lock_coment': commentLock,
          'comment_locked': commentLock,
          'is_comment_locked': commentLock,
          'hidden_room': hiddenRoom,
          'is_hidden_room': hiddenRoom,
          'room_hidden': hiddenRoom,
          'screen_records': screenRecord,
          'screen_record_enabled': screenRecord,
          'screenshort': screenShort,
          'screenshot_enabled': screenShort,
        };
        createStreamData.refresh();
      }

      final bool shouldBlockScreen = screenRecord == 1 || screenShort == 1;
      _setNativeScreenSecure(shouldBlockScreen);

      if (commentLock == 1) {
        FocusManager.instance.primaryFocus?.unfocus();
      }

      liveLog(
        '🔒 ROOM SAFETY SETTINGS APPLIED => source:$source '
            'room_lock:$roomLock lock_coment:$commentLock hidden_room:$hiddenRoom '
            'screen_records:$screenRecord screenshort:$screenShort',
      );
    } catch (e, st) {
      liveLog('❌ applyRoomSafetySettingsFromPayload error => $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> editLiveStreamRoom({
    required int livestreamId,
    required int userId,
    required int seatCount,
    required int roomLayout,
    required int roomTheme,
    required int roomBackground,
    String? streamTitle,
    String? streamAnnouncement,
    File? streamImageFile,
    String? roomPassword,
    int? roomLock,
    int? lockComent,
    int? hiddenRoom,
    int? screenRecords,
    int? screenshort,
  }) async {
    if (livestreamId == 0 || userId == 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return null;
    }
    if (!_ensureCanModerateCurrentLive('edit_room')) return null;

    try {
      roomEditLoading.value = true;

      /// Backend edit API create live-er moto sob key must chay.
      /// Existing value na pele safe default pathabo, nullable pathabo na.
      final rawCurrentLive = createStreamData['livestreamdata'] is Map
          ? Map<String, dynamic>.from(createStreamData['livestreamdata'])
          : createStreamData['livestream'] is Map
          ? Map<String, dynamic>.from(createStreamData['livestream'])
          : <String, dynamic>{};

      final int currentLiveId = _toInt(
        rawCurrentLive['id'] ?? rawCurrentLive['livestream_id'],
      );

      /// HARD ROOM ISOLATION:
      /// createStreamData is a controller-level cache. If user edited room A and
      /// then opened room B, this cache can still contain room A for a short time.
      /// Never use title/announcement/image/password from that cache unless the
      /// cached livestream id is the same room we are editing now.
      final bool currentLiveBelongsToThisRoom =
          rawCurrentLive.isNotEmpty && currentLiveId == livestreamId;
      final currentLive = currentLiveBelongsToThisRoom
          ? rawCurrentLive
          : <String, dynamic>{};

      if (!currentLiveBelongsToThisRoom) {
        liveLog(
          '🧹 Ignored stale createStreamData while editing room => '
              'editing:$livestreamId cached:$currentLiveId',
        );
      }

      final String safeStreamTitle =
      (streamTitle ??
          currentLive['stream_bte'] ??
          currentLive['title'] ??
          'Live')
          .toString()
          .trim()
          .isEmpty
          ? 'Live'
          : (streamTitle ??
          currentLive['stream_bte'] ??
          currentLive['title'] ??
          'Live')
          .toString()
          .trim();

      final String safeAnnouncement =
      (streamAnnouncement ??
          currentLive['stream_title'] ??
          currentLive['announcement'] ??
          currentLive['anousment'] ??
          '')
          .toString()
          .trim();

      final String safeStreamImage =
      (currentLive['stream_image'] ??
          currentLive['image'] ??
          currentLive['cover_image'] ??
          currentLive['thumbnail'] ??
          '')
          .toString()
          .trim();

      final String safeRoomPassword =
      (roomPassword ??
          currentLive['room_password'] ??
          currentLive['stream_password'] ??
          currentLive['password'] ??
          '')
          .toString()
          .trim();

      final int streamCoins =
          int.tryParse((currentLive['stream_coins'] ?? 0).toString()) ?? 0;

      final int giftsCoins =
          int.tryParse((currentLive['gifts_coins'] ?? 0).toString()) ?? 0;

      final String streamType =
      (currentLive['stream_type'] ?? 'audio').toString().trim().isEmpty
          ? 'audio'
          : (currentLive['stream_type'] ?? 'audio').toString();

      final int finalRoomLock =
          roomLock ??
              _firstIntFromMap(currentLive, [
                'room_lock',
                'is_room_locked',
                'room_locked',
              ], defaultValue: safeRoomPassword.isNotEmpty ? 1 : 0);

      final int finalLockComent =
          lockComent ??
              _firstIntFromMap(currentLive, [
                'lock_coment',
                'comment_locked',
                'is_comment_locked',
              ]);

      final int finalHiddenRoom =
          hiddenRoom ??
              _firstIntFromMap(currentLive, [
                'hidden_room',
                'is_hidden_room',
                'room_hidden',
              ]);

      final int finalScreenRecords =
          screenRecords ??
              _firstIntFromMap(currentLive, [
                'screen_records',
                'screen_record_enabled',
              ]);

      final int finalScreenshort =
          screenshort ??
              _firstIntFromMap(currentLive, ['screenshort', 'screenshot_enabled']);

      final data = <String, dynamic>{
        'seat_count': seatCount,

        /// stream_bte/title = live title, stream_title = announcement
        'stream_bte': safeStreamTitle,
        'stream_title': safeAnnouncement,
        'announcement': safeAnnouncement,
        'anousment': safeAnnouncement,
        'title': safeStreamTitle,
        'stream_coins': streamCoins,
        'gifts_coins': giftsCoins,
        'room_layout': roomLayout.toString(),
        'stream_type': streamType,
        'room_theme': roomTheme.toString(),
        'room_background': roomBackground.toString(),
        'room_password': safeRoomPassword,
        'stream_password': safeRoomPassword,
        'password': safeRoomPassword,

        /// Room settings: 1 = lock/hide/block, 0 = unlock/show/allow.
        'room_lock': finalRoomLock,
        'is_room_locked': finalRoomLock,
        'room_locked': finalRoomLock,
        'has_room_password': finalRoomLock == 1 && safeRoomPassword.isNotEmpty
            ? 1
            : 0,
        'lock_coment': finalLockComent,
        'comment_locked': finalLockComent,
        'is_comment_locked': finalLockComent,
        'hidden_room': finalHiddenRoom,
        'is_hidden_room': finalHiddenRoom,
        'room_hidden': finalHiddenRoom,
        'screen_records': finalScreenRecords,
        'screen_record_enabled': finalScreenRecords,
        'screenshort': finalScreenshort,
        'screenshot_enabled': finalScreenshort,

        /// Only preserve an existing stream image when the cached live data
        /// belongs to this same livestream. Otherwise room A image could be sent
        /// while editing room B. Picked file still uploads below.
        if (currentLiveBelongsToThisRoom && safeStreamImage.isNotEmpty)
          'stream_image': safeStreamImage,
      };

      dynamic requestData = data;
      final pickedImagePath = streamImageFile?.path ?? '';
      if (pickedImagePath.isNotEmpty && File(pickedImagePath).existsSync()) {
        requestData = FormData.fromMap({
          ...data,
          "stream_image": await MultipartFile.fromFile(
            pickedImagePath,
            filename: pickedImagePath.split(Platform.pathSeparator).last,
          ),
        });
      }

      final url = '$kMainUrl/livestream/$livestreamId/edit/$userId';
      liveLog('📤 LIVE ROOM EDIT URL => $url');
      liveLog('📤 LIVE ROOM EDIT BODY => $data');

      final response = await dio.post(
        url,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': requestData is FormData
                ? 'multipart/form-data'
                : 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },

          /// 422 response-o print korbo, DioException-e hide hobe na.
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 LIVE ROOM EDIT STATUS => ${response.statusCode}');
      liveLog('📥 LIVE ROOM EDIT RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        final liveData = body['livestreamdata'] is Map
            ? Map<String, dynamic>.from(body['livestreamdata'])
            : body['livestream'] is Map
            ? Map<String, dynamic>.from(body['livestream'])
            : <String, dynamic>{};

        final String responseStreamImage = (liveData['stream_image'] ?? '')
            .toString()
            .trim();
        final String finalStreamImage = responseStreamImage.isNotEmpty
            ? responseStreamImage
            : (currentLiveBelongsToThisRoom ? safeStreamImage : '');

        if (liveData.isNotEmpty) {
          createStreamData['livestreamdata'] = {
            ...liveData,
            'id': livestreamId,
            'livestream_id': livestreamId,
            'stream_bte': safeStreamTitle,
            'stream_title': safeAnnouncement,
            'announcement': safeAnnouncement,
            'anousment': safeAnnouncement,
            'title': safeStreamTitle,
            'stream_image': finalStreamImage,
            'room_password': safeRoomPassword,
            'stream_password': safeRoomPassword,
            'password': safeRoomPassword,
            'seat_count': seatCount,
            'room_layout': roomLayout.toString(),
            'room_theme': roomTheme.toString(),
            'room_background': roomBackground.toString(),
            'room_lock': finalRoomLock,
            'is_room_locked': finalRoomLock,
            'room_locked': finalRoomLock,
            'has_room_password':
            finalRoomLock == 1 && safeRoomPassword.isNotEmpty ? 1 : 0,
            'lock_coment': finalLockComent,
            'comment_locked': finalLockComent,
            'is_comment_locked': finalLockComent,
            'hidden_room': finalHiddenRoom,
            'is_hidden_room': finalHiddenRoom,
            'room_hidden': finalHiddenRoom,
            'screen_records': finalScreenRecords,
            'screen_record_enabled': finalScreenRecords,
            'screenshort': finalScreenshort,
            'screenshot_enabled': finalScreenshort,
          };
        } else {
          /// Response-e livestreamdata na thakleo local value sync thakbe.
          createStreamData['livestreamdata'] = {
            ...currentLive,
            ...data,
            'id': livestreamId,
          };
        }
        createStreamData.refresh();

        applyRoomSafetySettingsFromPayload({
          ...body,
          ...data,
          'livestreamdata': createStreamData['livestreamdata'],
        }, source: 'edit_api_success_local');

        /// Host-er screen-e instantly update. Audience websocket event pabe.
        websocketController.updateLiveRoomSettings(
          livestreamId: livestreamId,
          seatCount: seatCount,
          roomLayout: roomLayout,
          roomTheme: roomTheme,
          roomBackground: roomBackground,
          streamTitle: safeStreamTitle,
          streamAnnouncement: safeAnnouncement,
          streamImage: finalStreamImage,
          streamPassword: safeRoomPassword,
        );

        liveLog(
          '✅ Live room edited locally => title:$safeStreamTitle announcement:$safeAnnouncement seats:$seatCount layout:$roomLayout theme:$roomTheme bg:$roomBackground',
        );
        Fluttertoast.showToast(msg: ('Room updated').appTr);
        return body;
      }

      liveLog(
        '⚠️ Live room edit failed: ${response.statusCode} ${response.data}',
      );
      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : ('Room update failed').appTr,
      );
      return null;
    } catch (e) {
      liveLog('❌ Live room edit error: $e');
      Fluttertoast.showToast(msg: ('Room update failed').appTr);
      return null;
    } finally {
      roomEditLoading.value = false;
    }
  }

  Future<bool> updateRoomSettingsByEditApi({
    int? roomLock,
    String? roomPassword,
    int? lockComent,
    int? hiddenRoom,
    int? screenRecords,
    int? screenshort,
  }) async {
    final int sid = streamId.value > 0
        ? streamId.value
        : websocketController.streamID.value > 0
        ? websocketController.streamID.value
        : websocketController.activeAudioStreamId.value;

    final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (sid <= 0 || uid <= 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return false;
    }
    if (!_ensureCanModerateCurrentLive('update_room_settings')) return false;

    final currentLive = _currentLiveMapForRoomSettings();

    final int seatCount = websocketController.liveRoomSeatCount.value > 0
        ? websocketController.liveRoomSeatCount.value
        : _toInt(currentLive['seat_count']) > 0
        ? _toInt(currentLive['seat_count'])
        : 9;

    final int roomLayout = websocketController.liveRoomLayout.value != 0
        ? websocketController.liveRoomLayout.value
        : _toInt(currentLive['room_layout']);

    final int roomTheme = websocketController.liveRoomTheme.value != 0
        ? websocketController.liveRoomTheme.value
        : _toInt(currentLive['room_theme']);

    final int roomBackground =
    websocketController.liveRoomBackground.value != -1
        ? websocketController.liveRoomBackground.value
        : currentLive.containsKey('room_background')
        ? _toInt(currentLive['room_background'])
        : -1;

    final String title =
    websocketController.liveRoomTitle.value.trim().isNotEmpty
        ? websocketController.liveRoomTitle.value.trim()
        : (currentLive['stream_bte'] ?? currentLive['title'] ?? 'Live')
        .toString();

    final String announcement =
    websocketController.liveRoomAnnouncement.value.trim().isNotEmpty
        ? websocketController.liveRoomAnnouncement.value.trim()
        : (currentLive['stream_title'] ??
        currentLive['announcement'] ??
        currentLive['anousment'] ??
        '')
        .toString();

    liveLog(
      '🔒 UPDATE ROOM SETTINGS BY EDIT API => '
          'stream:$sid user:$uid roomLock:$roomLock lockComent:$lockComent '
          'hiddenRoom:$hiddenRoom screenRecords:$screenRecords screenshort:$screenshort',
    );

    try {
      roomSettingsLoading.value = true;
      final result = await editLiveStreamRoom(
        livestreamId: sid,
        userId: uid,
        seatCount: seatCount,
        roomLayout: roomLayout,
        roomTheme: roomTheme,
        roomBackground: roomBackground,
        streamTitle: title,
        streamAnnouncement: announcement,
        roomPassword: roomPassword,
        roomLock: roomLock,
        lockComent: lockComent,
        hiddenRoom: hiddenRoom,
        screenRecords: screenRecords,
        screenshort: screenshort,
      );

      final bool ok = result != null && result['success'] != false;
      liveLog('🔒 ROOM SETTINGS API RESULT => success:$ok response:$result');
      return ok;
    } finally {
      roomSettingsLoading.value = false;
    }
  }

  Future<bool> cleanLiveComments() async {
    final int sid = streamId.value > 0
        ? streamId.value
        : websocketController.streamID.value > 0
        ? websocketController.streamID.value
        : websocketController.activeAudioStreamId.value;

    final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (sid <= 0 || uid <= 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return false;
    }

    final String url = '$kMainUrl/livestream/$sid/comments/clear/$uid';
    final data = <String, dynamic>{
      'action_type': 'clear_live_comments',
      'livestream_id': sid,
      'clear_comments': true,
      'comments': [],
      'comment_list': [],
      'live_comments': [],
    };

    try {
      roomSettingsLoading.value = true;
      liveLog('========== CLEAN LIVE COMMENTS API START ==========');
      liveLog('🧹 CLEAN LIVE COMMENTS URL => $url');
      liveLog('🧹 CLEAN LIVE COMMENTS BODY => $data');

      final response = await dio.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      liveLog('🧹 CLEAN LIVE COMMENTS STATUS => ${response.statusCode}');
      liveLog('🧹 CLEAN LIVE COMMENTS RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          websocketController.clearLiveCommentsLocal(
            livestreamId: sid,
            source: 'clean_api_success_host',
          );
        } catch (e) {
          liveLog('⚠️ Local clean after API skipped => $e');
        }
        Fluttertoast.showToast(msg: ('Chat cleaned').appTr);
        return true;
      }

      Fluttertoast.showToast(msg: ('Clean chat failed').appTr);
      return false;
    } catch (e, st) {
      liveLog('❌ CLEAN LIVE COMMENTS ERROR => $e\n$st');
      Fluttertoast.showToast(msg: ('Clean chat failed').appTr);
      return false;
    } finally {
      roomSettingsLoading.value = false;
      liveLog('========== CLEAN LIVE COMMENTS API END ==========');
    }
  }

  Future<bool> setRoomPasswordLock({
    required bool lock,
    String roomPassword = '',
  }) {
    return updateRoomSettingsByEditApi(
      roomLock: lock ? 1 : 0,
      roomPassword: lock ? roomPassword : '',
    );
  }

  Future<bool> setLiveCommentLock(bool lock) {
    return updateRoomSettingsByEditApi(lockComent: lock ? 1 : 0);
  }

  Future<bool> setHiddenRoom(bool hide) {
    return updateRoomSettingsByEditApi(hiddenRoom: hide ? 1 : 0);
  }

  Future<bool> setScreenRecordBlock(bool block) {
    return updateRoomSettingsByEditApi(screenRecords: block ? 1 : 0);
  }

  Future<bool> setScreenshotBlock(bool block) {
    return updateRoomSettingsByEditApi(screenshort: block ? 1 : 0);
  }

  /// ===================== SEAT SWITCH API =====================
  final seatSwitchLoading = false.obs;

  int currentUserSeatNo({bool ignorePresence = false}) {
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (currentUserId == 0) return 0;

    if (!ignorePresence &&
        (_presenceRole.toLowerCase() == 'viewer' ||
            _presenceIsOnSeat == false)) {
      return 0;
    }

    for (final call in websocketController.liveCallList) {
      final map = call is Map ? Map<String, dynamic>.from(call) : {};
      if (map.isEmpty) continue;

      final callerId = map['caller_id'];
      final userId = map['user'] is Map ? map['user']['id'] : map['user_id'];
      final seatNo = int.tryParse(map['seat_no']?.toString() ?? '') ?? 0;

      final status = (map['call_status'] ?? '').toString().toLowerCase();
      final accepted =
          status.isEmpty ||
              status == 'accepted' ||
              status == 'active' ||
              status == 'joined';

      if (accepted &&
          seatNo > 0 &&
          (callerId.toString() == currentUserId.toString() ||
              userId.toString() == currentUserId.toString())) {
        return seatNo;
      }
    }

    return 0;
  }

  bool isSeatOccupied(int seatNo) {
    return websocketController.liveCallList.any((call) {
      final map = call is Map ? Map<String, dynamic>.from(call) : {};
      if (map.isEmpty) return false;

      final currentSeat = int.tryParse(map['seat_no']?.toString() ?? '') ?? 0;
      final status = (map['call_status'] ?? '').toString().toLowerCase();

      final accepted =
          status.isEmpty ||
              status == 'accepted' ||
              status == 'active' ||
              status == 'joined';

      return accepted && currentSeat == seatNo;
    });
  }

  Future<Map<String, dynamic>?> switchAudioSeat({
    required int livestreamId,
    required int toSeatNo,
    int? fromSeatNo,
  }) async {
    if (seatSwitchLoading.value) return null;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (currentUserId == 0) {
      Fluttertoast.showToast(msg: ('User not found').appTr);
      return null;
    }

    final oldSeatNo = fromSeatNo ?? currentUserSeatNo();

    if (oldSeatNo > 0) {
      final seatsData = await getAvailableSeats(livestreamId);
      if (seatsData != null) {
        _reconcileSelfSeatFromAvailableSeats(seatsData);
      }
    }

    final verifiedOldSeatNo = currentUserSeatNo();
    if (verifiedOldSeatNo == 0) {
      Fluttertoast.showToast(msg: ('Please join a seat first').appTr);
      return null;
    }

    final safeOldSeatNo = fromSeatNo ?? verifiedOldSeatNo;

    if (safeOldSeatNo == 0) {
      Fluttertoast.showToast(msg: ('Please join a seat first').appTr);
      return null;
    }

    if (safeOldSeatNo == toSeatNo) {
      Fluttertoast.showToast(msg: ('You are already on this seat').appTr);
      return null;
    }

    try {
      final ws = Get.find<WebsocketController>();

      /// Do not switch to locked seat.
      if (ws.isSeatLocked(toSeatNo)) {
        Fluttertoast.showToast(msg: ('This seat is locked').appTr);
        return null;
      }

      /// Do not switch to occupied seat.
      final occupiedByOther = websocketController.liveCallList.any((call) {
        final map = call is Map ? Map<String, dynamic>.from(call) : {};
        if (map.isEmpty) return false;

        final seatNo = int.tryParse(map['seat_no']?.toString() ?? '') ?? 0;
        final callerId = map['caller_id'];
        final userId = map['user'] is Map ? map['user']['id'] : map['user_id'];

        final status = (map['call_status'] ?? '').toString().toLowerCase();
        final accepted =
            status.isEmpty ||
                status == 'accepted' ||
                status == 'active' ||
                status == 'joined';

        return accepted &&
            seatNo == toSeatNo &&
            callerId.toString() != currentUserId.toString() &&
            userId.toString() != currentUserId.toString();
      });

      if (occupiedByOther) {
        Fluttertoast.showToast(msg: ('Seat already occupied').appTr);
        return null;
      }

      seatSwitchLoading.value = true;

      final body = {
        'user_id': currentUserId,
        'from_seat_no': safeOldSeatNo,
        'to_seat_no': toSeatNo,
      };

      final url = '$kMainUrl/livestream/$livestreamId/seat/switch';

      liveLog('📤 SEAT SWITCH URL => $url');
      liveLog('📤 SEAT SWITCH BODY => $body');

      final response = await dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 SEAT SWITCH STATUS => ${response.statusCode}');
      liveLog('📥 SEAT SWITCH RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        final callDataRaw = data['call_data'] ?? data['data'] ?? data['caller'];
        final callData = callDataRaw is Map
            ? <String, dynamic>{
          ...data,
          ...Map<String, dynamic>.from(callDataRaw),
        }
            : <String, dynamic>{
          ...data,
          'livestream_id': livestreamId,
          'caller_id': currentUserId,
          'user_id': currentUserId,
          'seat_no': toSeatNo,
          'my_seat_no': toSeatNo,
          'call_status': 'accepted',
        };

        /// Local instant update. Backend websocket `seat_switched` will sync again.
        /// Response root-e CP connection/base image thakle ekhanei sync korte hobe,
        /// tahole nijer device + sob viewer-er UI instantly stable thakbe.
        try {
          final ws = Get.find<WebsocketController>();
          ws.applySeatSwitch(
            userId: currentUserId,
            fromSeatNo: safeOldSeatNo,
            toSeatNo: toSeatNo,
            callData: callData,
          );
          ws.syncCpSeatConnectionsFromAnyPayload(
            data,
            source: 'local_seat_switch_response',
          );
        } catch (e) {
          liveLog('⚠️ Local applySeatSwitch skipped: $e');
        }

        return data;
      }

      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : ('Seat switch failed').appTr;

      Fluttertoast.showToast(msg: message);
      return null;
    } catch (e) {
      liveLog('❌ switchAudioSeat error: $e');
      Fluttertoast.showToast(msg: ('Seat switch failed').appTr);
      return null;
    } finally {
      seatSwitchLoading.value = false;
    }
  }

  /// ===================== SEAT LOCK APIs =====================
  /// Only broadcaster should call these from UI.
  /// Backend will broadcast action_type: seat_lock_toggle.
  final seatLockLoading = false.obs;

  Future<Map<String, dynamic>?> toggleSeatLock({
    required int livestreamId,
    required int seatNo,
  }) async {
    if (seatLockLoading.value) return null;
    if (!_ensureCanModerateCurrentLive('toggle_seat_lock')) return null;

    try {
      seatLockLoading.value = true;

      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/seat/$seatNo/lock-toggle',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        liveLog('✅ Seat lock toggle success: ${response.data}');

        /// Local instant update, websocket event ashlei abar sync hobe.
        final WebsocketController ws = Get.find();
        final data = response.data is Map ? response.data as Map : {};
        final lockedValue =
            data['is_locked'] ??
                data['locked'] ??
                data['seat']?['is_locked'] ??
                data['data']?['is_locked'];

        if (lockedValue != null) {
          ws.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked:
            lockedValue == true ||
                lockedValue == 1 ||
                lockedValue.toString() == '1' ||
                lockedValue.toString().toLowerCase() == 'yes' ||
                lockedValue.toString().toLowerCase() == 'locked' ||
                lockedValue.toString().toLowerCase() == 'true',
          );
        } else {
          /// If backend does not return new state, toggle local state.
          ws.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: !ws.isSeatLocked(seatNo),
          );
        }

        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
      } else {
        liveLog(
          '⚠️ Seat lock toggle failed: ${response.statusCode} ${response.data}',
        );
        Fluttertoast.showToast(msg: ('Seat lock failed').appTr);
        return null;
      }
    } catch (e) {
      liveLog('❌ Seat lock toggle error: $e');
      Fluttertoast.showToast(msg: ('Seat lock failed').appTr);
      return null;
    } finally {
      seatLockLoading.value = false;
    }
  }

  Future<Map<String, dynamic>?> lockSeat({
    required int livestreamId,
    required int seatNo,
  }) async {
    if (!_ensureCanModerateCurrentLive('lock_seat')) return null;
    try {
      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/seat/$seatNo/lock',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        Get.find<WebsocketController>().updateSeatLockStatus(
          seatNo: seatNo,
          isLocked: true,
        );
        liveLog('✅ Seat locked: $seatNo');
        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      liveLog('❌ lockSeat error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> unlockSeat({
    required int livestreamId,
    required int seatNo,
  }) async {
    if (!_ensureCanModerateCurrentLive('unlock_seat')) return null;
    try {
      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/seat/$seatNo/unlock',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        Get.find<WebsocketController>().updateSeatLockStatus(
          seatNo: seatNo,
          isLocked: false,
        );
        liveLog('✅ Seat unlocked: $seatNo');
        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      liveLog('❌ unlockSeat error: $e');
    }
    return null;
  }

  // Toggle user audio (mute/unmute)
  Future<Map<String, dynamic>?> toggleUserAudio(
      int streamId,
      int userId,
      ) async {
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId != currentUserId &&
        !_ensureCanModerateCurrentLive('toggle_user_audio_legacy')) {
      return null;
    }
    try {
      final response = await dio.post(
        kAudioToggleUrl(streamId, userId),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      liveLog('Error toggling user audio: $e');
      return null;
    }
  }

  // Toggle user video (mute/unmute)
  Future<Map<String, dynamic>?> toggleUserVideo(
      int streamId,
      int userId,
      ) async {
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId != currentUserId &&
        !_ensureCanModerateCurrentLive('toggle_user_video_legacy')) {
      return null;
    }
    try {
      final response = await dio.post(
        kVideoToggleUrl(streamId, userId),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      liveLog('Error toggling user video: $e');
      return null;
    }
  }

  RxList<int> selectedProfileIndices = <int>[].obs;

  // Select all items in the list
  void selectAll({required int totalItems}) {
    selectedProfileIndices.clear();
    for (int i = 0; i < totalItems; i++) {
      selectedProfileIndices.add(i);
    }
  }

  //Audio live image pick
  final audioImage = ''.obs;

  Future<void> audioimagePicker() async {
    final ImagePicker picker = ImagePicker();

    // Show a bottom sheet with Camera & Gallery options
    await Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text(
                ('Take Photo').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back(); // Close the bottom sheet
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 50,
                );
                if (photo != null) {
                  audioImage.value = photo.path;
                  liveLog("Camera image path: ${photo.path}");
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text(
                ('Choose from Gallery').appTr,
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Get.back(); // Close the bottom sheet
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 50,
                );
                if (photo != null) {
                  audioImage.value = photo.path;
                  liveLog("Gallery image path: ${photo.path}");
                }
              },
            ),
          ],
        ),
      ),
      backgroundColor: Color(0xff8A4CF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  // Missing methods from backup
  final startLiveTime = {}.obs;

  Future<void> liveTimeCase({
    required int streamId,
    required DateTime startTime,
  }) async {
    final data = {
      'stream_id': streamId,
      'start_time': startTime.toIso8601String(), // ✅ convert DateTime
    };

    try {
      final response = await dio.post(kLivestreamStartTime, data: data);

      liveLog("start time data $data");

      if (response.statusCode == 200) {
        startLiveTime.value = response.data;
        liveLog("Show Start time: ${response.data}");
      } else {
        liveLog("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      liveLog("Error fetching live time: $e");
    }
  }

  Future<Map<String, dynamic>> checkCanJoinLivestream(
      int streamId,
      int userId,
      ) async {
    try {
      final response = await dio.get(
        kCheckCanJoinUrl(streamId, userId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        return {
          'can_join': true,
          'message': response.data['message'] ?? 'Can join livestream',
        };
      } else {
        return {
          'can_join': false,
          'message': response.data['message'] ?? 'Cannot join livestream',
        };
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          return {
            'can_join': false,
            'message':
            e.response?.data['message'] ??
                'You are temporarily banned from this livestream',
            'remaining_minutes': e.response?.data['remaining_minutes'] ?? 0,
          };
        } else if (e.response?.statusCode == 500) {
          liveLog('Server Error (500): ${e.response?.data}');
          return {
            'can_join':
            true, // Allow join on server error to avoid blocking users
            'message': 'Server temporarily unavailable, proceeding with join',
          };
        } else {
          liveLog('HTTP Error ${e.response?.statusCode}: ${e.response?.data}');
          return {
            'can_join': true, // Allow join on other HTTP errors
            'message': 'Unable to verify join status, proceeding with join',
          };
        }
      }
      liveLog('Error checking join status: $e');
      return {
        'can_join': true, // Allow join on network/other errors
        'message': 'Unable to verify join status, proceeding with join',
      };
    }
  }

  // Room Extension Method
  Future<void> extendRoom(String livestreamId, int newSeatCount) async {
    try {
      final response = await dio.post(
        '$kDomainUrl/api/multi-live/$livestreamId/extend-room',
        data: {
          'new_seat_count': newSeatCount,
          'user_id': authController.userProfile.value.user?.id,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        liveLog("✅ Room extended successfully: ${response.data}");
      } else {
        throw Exception('Failed to extend room: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMessage =
            e.response!.data['message'] ?? 'Unknown error occurred';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  // Handle room extension WebSocket event

  // Make user guardian/administrator
  Future<Map<String, dynamic>?> makeGuardian(
      int livestreamId,
      int userId,
      ) async {
    if (!_ensureCanModerateCurrentLive('make_guardian')) {
      return {
        'success': false,
        'message': ('Only host or this room admin can do this').appTr,
      };
    }
    try {
      liveLog('Making user $userId guardian for livestream $livestreamId');

      final response = await dio.post(
        '$kMainUrl/livestream/$livestreamId/guardian/$userId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      liveLog('Make guardian response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        liveLog('Failed to make guardian: ${response.statusCode}');
        return {'success': false, 'message': 'Failed to make guardian'};
      }
    } on DioException catch (e) {
      liveLog('Error making guardian: $e');
      return {'success': false, 'message': 'Network error occurred'};
    } catch (e) {
      liveLog('Unexpected error making guardian: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// ===================== LIVE IMOGI / EMOJI API =====================
  /// Backend:
  /// GET  api/api/imogi_list
  /// POST /livestream/imogi/send
  ///
  /// This block is added without removing/changing any old function.
  String _imogiString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  int _imogiInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<Map<String, dynamic>> _extractImogiItemsFromCategory(
      Map<String, dynamic> category,
      ) {
    final rawItems =
        category['imogies'] ??
            category['imogi'] ??
            category['emojis'] ??
            category['emoji'] ??
            category['items'] ??
            category['data'] ??
            category['list'] ??
            <dynamic>[];

    final items = _asList(rawItems);

    return items
        .map((item) {
      final map = _asMap(item);
      return <String, dynamic>{
        ...map,
        'id': map['id'] ?? map['imogi_id'] ?? map['emoji_id'],
        'name': map['name'] ?? map['title'] ?? map['imogi_name'] ?? 'Imogi',
        'image':
        map['image'] ??
            map['icon'] ??
            map['imogi_image'] ??
            map['emoji_image'] ??
            map['url'] ??
            map['file'],
        'category_id': map['category_id'] ?? category['id'],
        'category_name': map['category_name'] ?? category['name'],
      };
    })
        .where((item) => item['id'] != null)
        .toList();
  }

  void _normalizeAndSetImogiData(dynamic rawResponse) {
    final root = _asMap(rawResponse);
    dynamic source =
        root['data'] ??
            root['categories'] ??
            root['category'] ??
            root['imogies'] ??
            root['emojis'] ??
            root['items'] ??
            rawResponse;

    final sourceList = _asList(source);

    final categories = <Map<String, dynamic>>[];
    final flatImogies = <Map<String, dynamic>>[];

    for (final item in sourceList) {
      final map = _asMap(item);

      final itemList = _extractImogiItemsFromCategory(map);
      final bool looksLikeCategory =
          itemList.isNotEmpty ||
              map.containsKey('imogies') ||
              map.containsKey('emojis') ||
              map.containsKey('items') ||
              map.containsKey('list');

      if (looksLikeCategory) {
        final category = <String, dynamic>{
          ...map,
          'id': map['id'] ?? map['category_id'] ?? categories.length,
          'name':
          map['name'] ?? map['title'] ?? map['category_name'] ?? 'Imogi',
          'image': map['image'] ?? map['icon'] ?? map['category_image'],
          'imogies': itemList,
        };

        categories.add(category);
        flatImogies.addAll(itemList);
      } else {
        flatImogies.add(<String, dynamic>{
          ...map,
          'id': map['id'] ?? map['imogi_id'] ?? map['emoji_id'],
          'name': map['name'] ?? map['title'] ?? map['imogi_name'] ?? 'Imogi',
          'image':
          map['image'] ??
              map['icon'] ??
              map['imogi_image'] ??
              map['emoji_image'] ??
              map['url'] ??
              map['file'],
          'category_id': map['category_id'] ?? 0,
          'category_name':
          map['category_name'] ?? map['category'] ?? ('All').appTr,
        });
      }
    }

    if (categories.isEmpty && flatImogies.isNotEmpty) {
      final grouped = <String, List<Map<String, dynamic>>>{};

      for (final imogi in flatImogies) {
        final key = _imogiString(
          imogi['category_id'] ?? imogi['category_name'],
          fallback: '0',
        );
        grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(imogi);
      }

      grouped.forEach((key, value) {
        final first = value.first;
        categories.add({
          'id': first['category_id'] ?? key,
          'name': first['category_name'] ?? 'Imogi',
          'image': first['category_image'] ?? first['image'],
          'imogies': value,
        });
      });
    }

    imogiCategoryList.assignAll(categories);
    imogiList.assignAll(flatImogies);
    if (selectedImogiCategoryIndex.value >= imogiCategoryList.length) {
      selectedImogiCategoryIndex.value = 0;
    }

    liveLog(
      '✅ Imogi normalized => categories:${imogiCategoryList.length} imogies:${imogiList.length}',
    );
  }

  Future<void> fetchImogiList() async {
    if (imogiLoading.value) return;

    try {
      imogiLoading.value = true;

      /// kMainUrl usually already contains /api.
      /// User backend route is api/api/imogi_list, so primary URL is /api/imogi_list.
      final urls = <String>[
        '$kMainUrl/api/imogi_list',
        '$kMainUrl/imogi_list',
        '$kBaseUrl/api/imogi_list',
        '$kBaseUrl/imogi_list',
      ];

      Response? response;

      for (final url in urls) {
        try {
          liveLog('📤 IMOGI LIST URL => $url');
          response = await dio.get(
            url,
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization':
                'Bearer ${authController.userProfile.value.token}',
              },
              validateStatus: (status) => true,
            ),
          );

          liveLog('📥 IMOGI LIST STATUS => ${response.statusCode}');
          liveLog('📥 IMOGI LIST RESPONSE => ${response.data}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            break;
          }
        } catch (e) {
          liveLog('⚠️ Imogi list URL failed: $url => $e');
        }
      }

      if (response == null ||
          !(response.statusCode == 200 || response.statusCode == 201)) {
        Fluttertoast.showToast(msg: ('Imogi list load failed').appTr);
        return;
      }

      _normalizeAndSetImogiData(response.data);
    } catch (e) {
      liveLog('❌ fetchImogiList error: $e');
      Fluttertoast.showToast(msg: ('Imogi list load failed').appTr);
    } finally {
      imogiLoading.value = false;
    }
  }

  List<Map<String, dynamic>> getImogiesByCategoryIndex(int index) {
    if (imogiCategoryList.isEmpty) return imogiList;

    final safeIndex = index.clamp(0, imogiCategoryList.length - 1).toInt();
    final category = imogiCategoryList[safeIndex];

    final list = category['imogies'];
    if (list is List) {
      return list.map((e) => _asMap(e)).toList();
    }

    return <Map<String, dynamic>>[];
  }

  bool isCurrentUserOnMicSeat() {
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId == 0) return false;

    final index = websocketController.liveCallList.indexWhere((call) {
      final seatNo = _imogiInt(call['seat_no']);
      final status = _imogiString(call['call_status']).toLowerCase();
      final callerId = call['caller_id'];
      final userId = call['user']?['id'] ?? call['User']?['id'];

      final bool accepted =
          status.isEmpty ||
              status == 'accepted' ||
              status == 'active' ||
              status == 'joined';

      return accepted &&
          seatNo >= 1 &&
          seatNo <= 20 &&
          (callerId.toString() == currentUserId.toString() ||
              userId.toString() == currentUserId.toString());
    });

    return index != -1;
  }

  Future<bool> sendLiveImogi({
    required int streamId,
    required int imogiId,
  }) async {
    if (imogiSending.value) return false;

    final senderId = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (senderId == 0 || streamId == 0 || imogiId == 0) {
      Fluttertoast.showToast(msg: ('Imogi data missing').appTr);
      return false;
    }

    /// User must be on a mic/seat. Host seat_no 1 also allowed.
    if (!isCurrentUserOnMicSeat()) {
      Fluttertoast.showToast(msg: ('Please join a seat first').appTr);
      return false;
    }

    try {
      imogiSending.value = true;

      final data = {
        'sender_id': senderId,
        'imogi_id': imogiId,
        'stream_id': streamId,
      };

      final url = '$kMainUrl/livestream/imogi/send';

      liveLog('📤 IMOGI SEND URL => $url');
      liveLog('📤 IMOGI SEND BODY => $data');

      final response = await dio.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 IMOGI SEND STATUS => ${response.statusCode}');
      liveLog('📥 IMOGI SEND RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : ('Imogi send failed').appTr,
      );
      return false;
    } catch (e) {
      liveLog('❌ sendLiveImogi error: $e');
      Fluttertoast.showToast(msg: ('Imogi send failed').appTr);
      return false;
    } finally {
      imogiSending.value = false;
    }
  }

  // Send emoji to livestream
  Future<void> sendEmoji(String emoji) async {
    try {
      final data = {
        "stream_id": streamId.value,
        "emoji": emoji,
        "user_id": authController.userProfile.value.user?.id,
      };

      final response = await dio.post(
        "${kBaseUrl}multi-live/send-emoji",
        data: data,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer ${authController.userProfile.value.token}",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        liveLog("✅ Emoji sent successfully: ${response.data}");
        // Hide emoji list after sending
        showEmoji.value = false;
      } else {
        liveLog(
          "⚠️ Failed to send emoji: ${response.statusCode} - ${response.data}",
        );
        Fluttertoast.showToast(msg: ("Failed to send emoji").appTr);
      }
    } on DioException catch (e) {
      liveLog("❌ Error sending emoji: $e");
      Fluttertoast.showToast(msg: ("Error sending emoji").appTr);
    }
  }

  ///--------------------------- Guardian assigned -----------
  final RxBool isMyGuardian = false.obs;
  final RxList<dynamic> guardianListData = <dynamic>[].obs;
  final RxBool guardianLoading = false.obs;

  /// userId => is room admin/guardian.
  /// This is the single realtime source for the seat Room Admin badge.
  /// It keeps working after seat switch, partial websocket snapshots,
  /// and remove admin events.
  final RxMap<int, bool> roomGuardianMap = <int, bool>{}.obs;

  bool isRoomGuardianUser(dynamic rawUserId) {
    final int id = int.tryParse(rawUserId?.toString() ?? '0') ?? 0;
    if (id <= 0) return false;
    return roomGuardianMap[id] == true;
  }

  bool hasRoomGuardianStatus(dynamic rawUserId) {
    final int id = int.tryParse(rawUserId?.toString() ?? '0') ?? 0;
    if (id <= 0) return false;
    return roomGuardianMap.containsKey(id);
  }

  final RxBool guardianNoticeVisible = false.obs;
  final RxString guardianNoticeText = ''.obs;
  Timer? _guardianNoticeTimer;

  void showGuardianNotice(String userName, {bool assigned = true}) {
    final String cleanName = userName.trim().isEmpty ? 'User' : userName.trim();
    guardianNoticeText.value = assigned
        ? '$cleanName has been set as room admin'
        : '$cleanName has been removed from room admin';
    guardianNoticeVisible.value = true;

    _guardianNoticeTimer?.cancel();
    _guardianNoticeTimer = Timer(const Duration(seconds: 5), () {
      guardianNoticeVisible.value = false;
    });
  }

  int _roomScopedLiveIdFromMap(Map map) {
    final livestream = _asMap(map['livestream']);
    final livestreamData = _asMap(map['livestreamdata']);
    final data = _asMap(map['data']);

    final candidates = <dynamic>[
      map['livestream_id'],
      map['stream_id'],
      map['live_id'],
      map['id'],
      livestream['livestream_id'],
      livestream['stream_id'],
      livestream['id'],
      livestreamData['livestream_id'],
      livestreamData['stream_id'],
      livestreamData['id'],
      data['livestream_id'],
      data['stream_id'],
      data['live_id'],
      data['id'],
    ];

    for (final value in candidates) {
      final id = _toInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  int _roomScopedOwnerIdFromMap(Map map) {
    final user = _asMap(map['user']);
    final host = _asMap(map['host']);
    final owner = _asMap(map['owner']);
    final livestream = _asMap(map['livestream']);
    final livestreamData = _asMap(map['livestreamdata']);
    final data = _asMap(map['data']);

    final candidates = <dynamic>[
      map['current_host_id'],
      map['owner_user_id'],
      map['host_id'],
      map['user_id'],
      livestream['current_host_id'],
      livestream['owner_user_id'],
      livestream['host_id'],
      livestream['user_id'],
      livestreamData['current_host_id'],
      livestreamData['owner_user_id'],
      livestreamData['host_id'],
      livestreamData['user_id'],
      data['current_host_id'],
      data['owner_user_id'],
      data['host_id'],
      data['user_id'],
      user['id'],
      user['user_id'],
      host['id'],
      host['user_id'],
      owner['id'],
      owner['user_id'],
    ];

    for (final value in candidates) {
      final id = _toInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  /// Current live room owner only. Old own-live cache is ignored when stream id differs.
  bool get isCurrentUserCurrentLiveOwner {
    final int myId = _myUserId;
    final int currentStreamId = streamId.value;
    if (myId <= 0 || currentStreamId <= 0) return false;

    final sources = <Map<String, dynamic>>[
      _asMap(createStreamData),
      _asMap(createStreamData['livestreamdata']),
      _asMap(createStreamData['livestream']),
      _asMap(createStreamData['data']),
    ];

    for (final source in sources) {
      if (source.isEmpty) continue;
      final int sourceStreamId = _roomScopedLiveIdFromMap(source);
      if (sourceStreamId > 0 && sourceStreamId != currentStreamId) continue;

      final int ownerId = _roomScopedOwnerIdFromMap(source);
      if (ownerId > 0) return ownerId == myId;
    }

    return false;
  }

  /// Host OR current room Guardian/Admin হলে live manage permission পাবে.
  /// Global/HomeController guardian flag use korbo na, karon eta onno live-e leak hoy.
  bool get canModerateLive {
    if (isCurrentUserCurrentLiveOwner) return true;
    if (isMyGuardian.value == true) return true;
    if (_myUserId > 0 && roomGuardianMap[_myUserId] == true) return true;
    return false;
  }

  bool _ensureCanModerateCurrentLive(String actionName) {
    if (canModerateLive == true) return true;

    liveLog(
      '⛔ Live control blocked => action=$actionName '
          'stream=${streamId.value} user=$_myUserId owner=$isCurrentUserCurrentLiveOwner '
          'guardian=${isMyGuardian.value}',
    );
    Fluttertoast.showToast(
      msg: ('Only host or this room admin can do this').appTr,
    );
    return false;
  }

  Map<String, String> get _guardianHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${authController.userProfile.value.token}',
  };

  int get _myUserId => authController.userProfile.value.user?.id?.toInt() ?? 0;

  bool _guardianBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;

    final text = value.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes';
  }

  int _guardianUserIdFromItem(dynamic raw) {
    if (raw is! Map) return 0;

    final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
    final Map<String, dynamic> user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'])
        : <String, dynamic>{};
    final Map<String, dynamic> caller = item['caller'] is Map
        ? Map<String, dynamic>.from(item['caller'])
        : <String, dynamic>{};
    final Map<String, dynamic> callerUser = caller['user'] is Map
        ? Map<String, dynamic>.from(caller['user'])
        : <String, dynamic>{};

    final candidates = <dynamic>[
      user['id'],
      user['user_id'],
      callerUser['id'],
      callerUser['user_id'],
      caller['user_id'],
      caller['caller_id'],
      caller['id'],
      item['user_id'],
      item['caller_id'],
      item['target_user_id'],
      item['guardian_user_id'],
      item['admin_user_id'],
      item['member_id'],
      item['id'],
    ];

    for (final value in candidates) {
      final id = int.tryParse(value?.toString() ?? '0') ?? 0;
      if (id > 0) return id;
    }

    return 0;
  }

  Map<String, dynamic>? _callerFromResponse(dynamic data) {
    if (data is Map && data['caller'] is Map) {
      return Map<String, dynamic>.from(data['caller']);
    }

    if (data is Map && data['data'] is Map && data['data']['caller'] is Map) {
      return Map<String, dynamic>.from(data['data']['caller']);
    }

    return null;
  }

  /// ===================== 1. LOCAL STATUS UPDATE =====================
  /// Guardian make/remove হলে local UI instant update হবে
  void applyGuardianLocalStatus({
    required int userId,
    required bool isGuardian,
    Map<String, dynamic>? caller,
  }) {
    try {
      roomGuardianMap[userId] = isGuardian;
      roomGuardianMap.refresh();

      if (_myUserId == userId) {
        isMyGuardian.value = isGuardian;

        try {
          homeController.isGuardianPermission.value = isGuardian;
          homeController.isGuardianData['is_guardian'] = isGuardian;
          homeController.isGuardianData['value'] = isGuardian ? 1 : 0;
          homeController.isGuardianData.refresh();
        } catch (_) {}
      }

      _updateGuardianInLiveCallList(
        userId: userId,
        isGuardian: isGuardian,
        caller: caller,
      );

      _updateGuardianInGuardianList(
        userId: userId,
        isGuardian: isGuardian,
        caller: caller,
      );

      guardianListData.refresh();
      websocketController.liveCallList.refresh();

      liveLog(
        '✅ Guardian local status updated => user=$userId guardian=$isGuardian',
      );
    } catch (e) {
      liveLog('❌ applyGuardianLocalStatus error: $e');
    }
  }

  /// ===================== 2. LIVE CALL LIST UPDATE =====================
  void _updateGuardianInLiveCallList({
    required int userId,
    required bool isGuardian,
    Map<String, dynamic>? caller,
  }) {
    for (int i = 0; i < websocketController.liveCallList.length; i++) {
      final item = websocketController.liveCallList[i];

      if (item is! Map) continue;

      final int callerId =
          int.tryParse(
            "${item['caller_id'] ?? item['user_id'] ?? item['user']?['id'] ?? 0}",
          ) ??
              0;

      if (callerId != userId) continue;

      final oldItem = Map<String, dynamic>.from(item);
      final updated = Map<String, dynamic>.from(oldItem);

      /// IMPORTANT: caller payload from set/remove admin can be partial.
      /// Preserve existing rich user data/frame, but explicitly overwrite
      /// guardian/admin flags so Remove Admin hides badge immediately.
      if (caller != null && caller.isNotEmpty) {
        final oldUser = oldItem['user'] is Map
            ? Map<String, dynamic>.from(oldItem['user'])
            : <String, dynamic>{};
        final newUser = caller['user'] is Map
            ? Map<String, dynamic>.from(caller['user'])
            : <String, dynamic>{};

        updated.addAll(caller);
        if (oldUser.isNotEmpty || newUser.isNotEmpty) {
          updated['user'] = {
            ...oldUser,
            ...newUser,
            'is_guardian': isGuardian ? 1 : 0,
            'is_admin': isGuardian ? 1 : 0,
            'room_admin': isGuardian ? 1 : 0,
          };
        }
      }

      updated['is_guardian'] = isGuardian ? 1 : 0;
      updated['is_admin'] = isGuardian ? 1 : 0;
      updated['room_admin'] = isGuardian ? 1 : 0;

      final nestedUser = updated['user'];
      if (nestedUser is Map) {
        updated['user'] = {
          ...Map<String, dynamic>.from(nestedUser),
          'is_guardian': isGuardian ? 1 : 0,
          'is_admin': isGuardian ? 1 : 0,
          'room_admin': isGuardian ? 1 : 0,
        };
      }

      websocketController.liveCallList[i] = updated;
    }
  }

  /// ===================== 3. GUARDIAN LIST UPDATE =====================
  void _updateGuardianInGuardianList({
    required int userId,
    required bool isGuardian,
    Map<String, dynamic>? caller,
  }) {
    if (isGuardian) {
      final bool exists = guardianListData.any((item) {
        return _guardianUserIdFromItem(item) == userId;
      });

      if (!exists) {
        guardianListData.add({
          'user_id': userId,
          'is_guardian': 1,
          if (caller != null) 'caller': caller,
        });
      }

      return;
    }

    guardianListData.removeWhere((item) {
      return _guardianUserIdFromItem(item) == userId;
    });
  }

  /// ===================== 4. MAKE GUARDIAN API =====================
  Future<bool> assignGuardian({
    required int streamId,
    required int userId,
    bool closeBottomSheet = true,
  }) async {
    if (!isCurrentUserCurrentLiveOwner) {
      Fluttertoast.showToast(msg: ('Only host can set room admin').appTr);
      return false;
    }
    if (streamId <= 0 || userId <= 0) {
      Fluttertoast.showToast(msg: ('Guardian data missing').appTr);
      return false;
    }

    try {
      guardianLoading.value = true;

      final response = await dio.post(
        kSetGuardian(streamId: streamId, userId: userId),
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (status) => true,
        ),
      );

      liveLog(
        '📤 SET GUARDIAN URL => ${kSetGuardian(streamId: streamId, userId: userId)}',
      );
      liveLog('📥 SET GUARDIAN STATUS => ${response.statusCode}');
      liveLog('📥 SET GUARDIAN RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final caller = _callerFromResponse(response.data);

        applyGuardianLocalStatus(
          userId: userId,
          isGuardian: true,
          caller: caller,
        );

        await refreshMyGuardianStatus(streamId: streamId, userId: userId);
        await fetchGuardianList(streamId: streamId);

        if (closeBottomSheet && Get.isBottomSheetOpen == true) {
          Get.back();
        }

        Fluttertoast.showToast(msg: ('Guardian assigned').appTr);
        return true;
      }

      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : ('Failed to set guardian').appTr,
      );

      return false;
    } on DioException catch (e) {
      liveLog('❌ assignGuardian Dio error: ${e.response?.data ?? e.message}');
      Fluttertoast.showToast(msg: ('Set guardian error').appTr);
      return false;
    } catch (e) {
      liveLog('❌ assignGuardian error: $e');
      Fluttertoast.showToast(msg: ('Set guardian error').appTr);
      return false;
    } finally {
      guardianLoading.value = false;
    }
  }

  /// ===================== 5. REMOVE GUARDIAN API =====================
  Future<bool> removeGuardianUser({
    required int streamId,
    required int userId,
    bool closeBottomSheet = true,
  }) async {
    if (!isCurrentUserCurrentLiveOwner) {
      Fluttertoast.showToast(msg: ('Only host can remove room admin').appTr);
      return false;
    }
    if (streamId <= 0 || userId <= 0) {
      Fluttertoast.showToast(msg: ('Guardian data missing').appTr);
      return false;
    }

    try {
      guardianLoading.value = true;

      final response = await dio.delete(
        kRemoveGuardian(streamId: streamId, userId: userId),
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (status) => true,
        ),
      );

      liveLog(
        '📤 REMOVE GUARDIAN URL => ${kRemoveGuardian(streamId: streamId, userId: userId)}',
      );
      liveLog('📥 REMOVE GUARDIAN STATUS => ${response.statusCode}');
      liveLog('📥 REMOVE GUARDIAN RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final caller = _callerFromResponse(response.data);

        applyGuardianLocalStatus(
          userId: userId,
          isGuardian: false,
          caller: caller,
        );

        await refreshMyGuardianStatus(streamId: streamId, userId: userId);
        await fetchGuardianList(streamId: streamId);

        if (closeBottomSheet && Get.isBottomSheetOpen == true) {
          Get.back();
        }

        Fluttertoast.showToast(msg: ('Guardian removed').appTr);
        return true;
      }

      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : ('Failed to remove guardian').appTr,
      );

      return false;
    } on DioException catch (e) {
      liveLog(
        '❌ removeGuardianUser Dio error: ${e.response?.data ?? e.message}',
      );
      Fluttertoast.showToast(msg: ('Remove guardian error').appTr);
      return false;
    } catch (e) {
      liveLog('❌ removeGuardianUser error: $e');
      Fluttertoast.showToast(msg: ('Remove guardian error').appTr);
      return false;
    } finally {
      guardianLoading.value = false;
    }
  }

  /// ===================== 6. GUARDIAN LIST API =====================
  List<dynamic> _guardianListFromResponse(dynamic data) {
    if (data is List) return List<dynamic>.from(data);

    if (data is Map) {
      final Map<String, dynamic> root = Map<String, dynamic>.from(data);
      final candidates = <dynamic>[
        root['guardians'],
        root['guardian_list'],
        root['guardianList'],
        root['room_admins'],
        root['roomAdmins'],
        root['admins'],
        root['data'],
        root['result'],
      ];

      for (final candidate in candidates) {
        if (candidate is List) return List<dynamic>.from(candidate);
        if (candidate is Map) {
          final Map<String, dynamic> nested = Map<String, dynamic>.from(
            candidate,
          );
          final nestedCandidates = <dynamic>[
            nested['guardians'],
            nested['guardian_list'],
            nested['guardianList'],
            nested['room_admins'],
            nested['roomAdmins'],
            nested['admins'],
            nested['data'],
            nested['items'],
            nested['list'],
          ];
          for (final nestedCandidate in nestedCandidates) {
            if (nestedCandidate is List)
              return List<dynamic>.from(nestedCandidate);
          }
        }
      }
    }

    return <dynamic>[];
  }

  Future<void> fetchGuardianList({required int streamId}) async {
    if (streamId <= 0) return;

    try {
      final response = await dio.get(
        kGuardianList(streamId: streamId),
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (status) => true,
        ),
      );

      liveLog('📤 GUARDIAN LIST URL => ${kGuardianList(streamId: streamId)}');
      liveLog('📥 GUARDIAN LIST STATUS => ${response.statusCode}');
      liveLog('📥 GUARDIAN LIST RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;

        final list = _guardianListFromResponse(data);
        guardianListData.assignAll(list);

        _syncGuardianMapFromList();
        _syncMyGuardianFromList();
        guardianListData.refresh();
      }
    } catch (e) {
      liveLog('❌ fetchGuardianList error: $e');
    }
  }

  /// ===================== 7. CHECK MY GUARDIAN STATUS API =====================
  Future<bool> refreshMyGuardianStatus({
    required int streamId,
    int? userId,
  }) async {
    final int targetUserId = userId ?? _myUserId;

    if (streamId <= 0 || targetUserId <= 0) return false;

    try {
      final response = await dio.get(
        kisGuardian(streamId: streamId, userId: targetUserId),
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (status) => true,
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final bool status = _extractGuardianStatusFromResponse(response.data);

        if (targetUserId == _myUserId) {
          applyGuardianLocalStatus(userId: targetUserId, isGuardian: status);
        }

        return status;
      }
    } catch (e) {
      liveLog('❌ refreshMyGuardianStatus error: $e');
    }

    return false;
  }

  bool _extractGuardianStatusFromResponse(dynamic data) {
    if (data is Map) {
      return _guardianBool(
        data['is_guardian'] ??
            data['guardian'] ??
            data['value'] ??
            data['status'] ??
            data['data']?['is_guardian'] ??
            data['data']?['guardian'] ??
            data['data']?['value'],
      );
    }

    return _guardianBool(data);
  }

  void _syncGuardianMapFromList() {
    final Map<int, bool> nextMap = <int, bool>{};

    for (final item in guardianListData) {
      final int id = _guardianUserIdFromItem(item);
      if (id > 0) {
        nextMap[id] = true;
      }
    }

    /// Mark every current seat user that is not in guardian list as false.
    /// This prevents an old cached Room Admin badge from staying visible
    /// after Remove Admin or after seat switch snapshots.
    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final int id =
            int.tryParse(
              "${raw['caller_id'] ?? raw['user_id'] ?? raw['user']?['id'] ?? 0}",
            ) ??
                0;
        if (id > 0 && nextMap[id] != true) {
          nextMap[id] = false;
        }
      }
    } catch (_) {}

    roomGuardianMap
      ..clear()
      ..addAll(nextMap);
    roomGuardianMap.refresh();
  }

  /// ===================== 8. CURRENT USER STATUS FROM LIST =====================
  void _syncMyGuardianFromList() {
    if (_myUserId <= 0) return;

    final bool exists = guardianListData.any((item) {
      return _guardianUserIdFromItem(item) == _myUserId;
    });

    isMyGuardian.value = exists;

    try {
      homeController.isGuardianPermission.value = exists;
      homeController.isGuardianData['is_guardian'] = exists;
      homeController.isGuardianData['value'] = exists ? 1 : 0;
      homeController.isGuardianData.refresh();
    } catch (_) {}
  }

  /// ===================== 9. WEBSOCKET GUARDIAN PAYLOAD APPLY =====================
  Future<void> applyGuardianFromSocket(Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        data['moderation_data'] ?? data['data'] ?? data,
      );

      final int userId =
          int.tryParse(
            '${payload['user_id'] ?? payload['caller_id'] ?? payload['target_user_id'] ?? payload['id'] ?? 0}',
          ) ??
              0;

      if (userId <= 0) return;

      final String action =
      (payload['action'] ??
          payload['moderation_action'] ??
          payload['type'] ??
          '')
          .toString()
          .toLowerCase();

      final bool isGuardian =
      action.contains('remove') || action.contains('unassign')
          ? false
          : action.contains('make') ||
          action.contains('set') ||
          action.contains('assign')
          ? true
          : _guardianBool(
        payload['is_guardian'] ?? payload['guardian'] ?? payload['value'],
      );

      Map<String, dynamic>? caller;
      if (payload['caller'] is Map) {
        caller = Map<String, dynamic>.from(payload['caller']);
      } else if (payload['caller_data'] is Map) {
        caller = Map<String, dynamic>.from(payload['caller_data']);
      } else if (payload['accepted_caller'] is Map) {
        caller = Map<String, dynamic>.from(payload['accepted_caller']);
      }

      applyGuardianLocalStatus(
        userId: userId,
        isGuardian: isGuardian,
        caller: caller,
      );

      final Map<String, dynamic> callerUser =
      caller != null && caller['user'] is Map
          ? Map<String, dynamic>.from(caller['user'])
          : <String, dynamic>{};
      final String noticeName =
      (payload['name'] ??
          payload['user_name'] ??
          callerUser['name'] ??
          ('User').appTr)
          .toString();
      showGuardianNotice(noticeName, assigned: isGuardian);

      liveLog(
        '✅ Guardian websocket applied => user=$userId guardian=$isGuardian',
      );
    } catch (e) {
      liveLog('❌ applyGuardianFromSocket error: $e');
    }
  }

  /// Current room guardian/admin state authoritative sync.
  /// Call this when a user enters/re-enters an audio room. Guardian/admin is
  /// persistent on backend until host removes it, so leaving the room must not
  /// make the user lose local permissions.
  Future<void> syncGuardianStateForRoom({
    required int streamId,
    int? userId,
  }) async {
    if (streamId <= 0) return;

    await fetchGuardianList(streamId: streamId);

    final int targetUserId = userId ?? _myUserId;
    if (targetUserId > 0) {
      await refreshMyGuardianStatus(streamId: streamId, userId: targetUserId);
    }
  }

  /// ===================== OLD FUNCTION NAME SUPPORT =====================
  /// আপনার UI তে আগের function name থাকলে error হবে না।

  Future<void> setGuardian({required int StreanId, required int UserId}) async {
    await assignGuardian(streamId: StreanId, userId: UserId);
  }

  Future<void> removeGuardian({
    required int StreanId,
    required int UserId,
  }) async {
    await removeGuardianUser(streamId: StreanId, userId: UserId);
  }

  Future<void> GuardianList({required int StreanId}) async {
    await fetchGuardianList(streamId: StreanId);
  }

  ///--------------------------- Agora Token Generate Error Test -----------

  Future<void> agoraTokenGenerateError() async {
    try {
      final response = await dio.post(
        kAgoraTokenGenerateErrorApi(
          applicationId: agoraTokenController.agoraToken['application_form_id'],
        ),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer ${authController.userProfile.value.token}",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // guardianListData.value = response.data['guardians'];
        liveLog("✅ Show Guardian List successfully: ${response.data}");

        // Hide emoji list after sending
      } else {
        liveLog(
          "⚠️ Failed to send emoji: ${response.statusCode} - ${response.data}",
        );
        Fluttertoast.showToast(msg: ("Failed to send emoji").appTr);
      }
    } on DioException catch (e) {
      liveLog("❌ Error sending emoji: $e");
      Fluttertoast.showToast(msg: ("Error sending emoji").appTr);
    }
  }

  /// ===================== VIDEO PK SYSTEM =====================
  /// Added safely for Video PK without removing old live/gift/seat/comment code.
  final RxBool pkModeActive = false.obs;
  final RxBool pkRequestLoading = false.obs;
  final RxBool pkWaitingForResponse = false.obs;
  final RxBool pkRequestPopupVisible = false.obs;
  final RxBool pkResultVisible = false.obs;
  final RxString pkResultText = ''.obs;

  /// PK premium UI states.
  final RxBool pkStartIntroVisible = false.obs;
  final RxString pkStartIntroText = 'PK START'.obs;
  final RxBool pkEndingCountdownVisible = false.obs;
  final RxString pkEndingCountdownText = ''.obs;

  final RxMap<String, dynamic> currentPkData = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> incomingPkRequest = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> pkResultData = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> _pkSenderLiveData = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> _pkReceiverLiveData = <String, dynamic>{}.obs;

  final RxInt currentPkId = 0.obs;
  final RxInt pkSenderLivestreamId = 0.obs;
  final RxInt pkReceiverLivestreamId = 0.obs;
  final RxInt pkSenderHostId = 0.obs;
  final RxInt pkReceiverHostId = 0.obs;
  final RxInt pkSenderScore = 0.obs;
  final RxInt pkReceiverScore = 0.obs;
  final Set<String> _processedPkGiftScoreEventKeys = <String>{};
  final RxInt pkSenderViewerCount = 0.obs;
  final RxInt pkReceiverViewerCount = 0.obs;
  final RxInt pkDurationSeconds = 300.obs;
  final RxInt pkRemainingSeconds = 0.obs;

  Timer? _pkTimer;

  /// Compatibility getter for PK widgets.
  RxBool get pkIsRunning => pkModeActive;

  /// Compatibility getter for PK widgets.
  Map<String, dynamic> get pkSenderLiveData => _pkSenderLiveData;

  /// Compatibility getter for PK widgets.
  Map<String, dynamic> get pkReceiverLiveData => _pkReceiverLiveData;

  String get pkFormattedRemainingTime {
    final int total = pkRemainingSeconds.value < 0
        ? 0
        : pkRemainingSeconds.value;
    final int minutes = total ~/ 60;
    final int seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get pkSenderProgress {
    final int sender = pkSenderScore.value;
    final int receiver = pkReceiverScore.value;
    final int total = sender + receiver;
    if (total <= 0) return 0.5;
    return sender / total;
  }

  bool get isCurrentUserPkSender {
    final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
    return uid > 0 && uid == pkSenderHostId.value;
  }

  bool get isCurrentUserPkReceiver {
    final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
    return uid > 0 && uid == pkReceiverHostId.value;
  }

  bool get isCurrentUserInPk =>
      isCurrentUserPkSender || isCurrentUserPkReceiver;

  void _startPkTimer({required int durationSeconds}) {
    _pkTimer?.cancel();

    pkDurationSeconds.value = durationSeconds <= 0 ? 300 : durationSeconds;
    pkRemainingSeconds.value = pkDurationSeconds.value;

    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!pkModeActive.value) {
        timer.cancel();
        return;
      }

      if (pkRemainingSeconds.value <= 0) {
        pkEndingCountdownVisible.value = false;
        pkEndingCountdownText.value = '';
        timer.cancel();
        if (isCurrentUserInPk && currentPkId.value > 0) {
          endPk(pkId: currentPkId.value);
        }
        return;
      }

      pkRemainingSeconds.value--;

      if (pkRemainingSeconds.value > 0 && pkRemainingSeconds.value <= 3) {
        pkEndingCountdownVisible.value = true;
        pkEndingCountdownText.value = pkRemainingSeconds.value.toString();
      } else {
        pkEndingCountdownVisible.value = false;
        pkEndingCountdownText.value = '';
      }
    });
  }

  void stopPkTimer() {
    _pkTimer?.cancel();
    _pkTimer = null;
  }

  void resetPkState({bool clearResult = true}) {
    stopPkTimer();

    pkModeActive.value = false;
    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;

    currentPkData.clear();
    currentPkData.refresh();

    incomingPkRequest.clear();
    incomingPkRequest.refresh();

    _pkSenderLiveData.clear();
    _pkReceiverLiveData.clear();

    currentPkId.value = 0;
    pkSenderLivestreamId.value = 0;
    pkReceiverLivestreamId.value = 0;
    pkSenderHostId.value = 0;
    pkReceiverHostId.value = 0;

    pkSenderScore.value = 0;
    pkReceiverScore.value = 0;
    _processedPkGiftScoreEventKeys.clear();
    pkSenderViewerCount.value = 0;
    pkReceiverViewerCount.value = 0;

    pkDurationSeconds.value = 300;
    pkRemainingSeconds.value = 0;

    pkStartIntroVisible.value = false;
    pkEndingCountdownVisible.value = false;
    pkEndingCountdownText.value = '';

    pkChannelName.value = '';
    pkSenderRoomId.value = '';
    pkReceiverRoomId.value = '';

    if (clearResult) {
      pkResultVisible.value = false;
      pkResultText.value = '';
      pkResultData.clear();
      pkResultData.refresh();
    }

    update();
  }

  Future<bool> sendPkRequest({
    required int senderLivestreamId,
    required int receiverLivestreamId,
    required int senderHostId,
    required int receiverHostId,
    Map<String, dynamic>? receiverLiveData,
  }) async {
    if (pkRequestLoading.value) return false;

    if (senderLivestreamId <= 0 ||
        receiverLivestreamId <= 0 ||
        senderHostId <= 0 ||
        receiverHostId <= 0) {
      Fluttertoast.showToast(msg: ('PK data missing').appTr);
      return false;
    }

    try {
      pkRequestLoading.value = true;

      if (receiverLiveData != null) {
        _pkReceiverLiveData.value = Map<String, dynamic>.from(receiverLiveData);
      }

      final body = {
        'sender_livestream_id': senderLivestreamId,
        'receiver_livestream_id': receiverLivestreamId,
        'sender_host_id': senderHostId,
        'receiver_host_id': receiverHostId,
      };

      liveLog('📤 PK REQUEST BODY => $body');

      final response = await dio.post(
        '$kMainUrl/pk/request',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 PK REQUEST STATUS => ${response.statusCode}');
      liveLog('📥 PK REQUEST RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        pkWaitingForResponse.value = true;

        final data = _asMap(
          response.data is Map ? response.data['data'] : null,
        );
        if (data.isNotEmpty) {
          currentPkId.value = _toInt(data['id']);
          pkSenderLivestreamId.value = _toInt(data['sender_livestream_id']);
          pkReceiverLivestreamId.value = _toInt(data['receiver_livestream_id']);
          pkSenderHostId.value = _toInt(data['sender_host_id']);
          pkReceiverHostId.value = _toInt(data['receiver_host_id']);
          final String pkChannel = _extractPkChannelFromMaps([data]);
          if (pkChannel.isNotEmpty) pkChannelName.value = pkChannel;
          currentPkData.value = data;
        }

        Fluttertoast.showToast(msg: ('PK request sent').appTr);
        return true;
      }

      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : ('PK request failed').appTr;
      Fluttertoast.showToast(msg: message);
      return false;
    } catch (e) {
      liveLog('❌ sendPkRequest error: $e');
      Fluttertoast.showToast(msg: ('PK request failed').appTr);
      return false;
    } finally {
      pkRequestLoading.value = false;
    }
  }

  Future<bool> respondPkRequest({
    required int pkId,
    required int receiverHostId,
    required String responseText,
  }) async {
    liveLog('================ PK RESPOND START ================');
    liveLog('📌 pkId => $pkId');
    liveLog('📌 receiverHostId => $receiverHostId');
    liveLog('📌 responseText => $responseText');
    liveLog('📌 API URL => $kMainUrl/pk/respond');
    liveLog('📌 User Token => ${authController.userProfile.value.token}');
    liveLog('📌 User ID => ${authController.userProfile.value.user?.id}');
    liveLog('📌 User Name => ${authController.userProfile.value.user?.name}');
    liveLog('==================================================');

    if (pkId <= 0 || receiverHostId <= 0) {
      liveLog('❌ PK request data missing');
      liveLog('❌ Invalid pkId => $pkId');
      liveLog('❌ Invalid receiverHostId => $receiverHostId');

      Fluttertoast.showToast(msg: ('PK request data missing').appTr);
      return false;
    }

    final Map<String, dynamic> requestBody = {
      'pk_id': pkId,
      'receiver_host_id': receiverHostId,
      'response': responseText,
    };

    final Map<String, dynamic> requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${authController.userProfile.value.token}',
    };

    try {
      liveLog('🚀 PK RESPOND REQUEST URL => $kMainUrl/pk/respond');
      liveLog('🚀 PK RESPOND REQUEST BODY => $requestBody');
      liveLog('🚀 PK RESPOND REQUEST HEADERS => $requestHeaders');

      final response = await dio.post(
        '$kMainUrl/pk/respond',
        data: requestBody,
        options: Options(
          headers: requestHeaders,
          validateStatus: (status) => true,
        ),
      );

      liveLog('================ PK RESPOND RESPONSE ================');
      liveLog('📥 STATUS CODE => ${response.statusCode}');
      liveLog('📥 STATUS MESSAGE => ${response.statusMessage}');
      liveLog('📥 RESPONSE DATA => ${response.data}');
      liveLog('📥 RESPONSE HEADERS => ${response.headers}');
      liveLog('📥 REAL URI => ${response.realUri}');
      liveLog('📥 REQUEST OPTIONS METHOD => ${response.requestOptions.method}');
      liveLog('📥 REQUEST OPTIONS PATH => ${response.requestOptions.path}');
      liveLog('📥 REQUEST OPTIONS DATA => ${response.requestOptions.data}');
      liveLog(
        '📥 REQUEST OPTIONS HEADERS => ${response.requestOptions.headers}',
      );
      liveLog('=====================================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        liveLog('✅ PK RESPOND SUCCESS');
        liveLog('✅ Popup hide kortesi');
        liveLog('✅ incomingPkRequest clear kortesi');

        pkRequestPopupVisible.value = false;
        incomingPkRequest.clear();

        liveLog('================ PK RESPOND END SUCCESS ================');
        return true;
      }

      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : ('PK response failed').appTr;

      Fluttertoast.showToast(msg: message);
      return false;
    } catch (e, stackTrace) {
      Fluttertoast.showToast(msg: ('PK response failed').appTr);
      return false;
    }
  }

  Future<bool> endPk({int? pkId}) async {
    final int targetPkId = pkId ?? currentPkId.value;
    if (targetPkId <= 0) return false;

    try {
      final response = await dio.post(
        '$kMainUrl/pk/end/$targetPkId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 PK END STATUS => ${response.statusCode}');
      liveLog('📥 PK END RESPONSE => ${response.data}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      liveLog('❌ endPk error: $e');
      return false;
    }
  }

  void handlePkRequestReceived(Map<String, dynamic> payload) {
    incomingPkRequest.value = Map<String, dynamic>.from(payload);
    currentPkId.value = _toInt(payload['pk_id'] ?? payload['data']?['id']);
    pkSenderLivestreamId.value = _toInt(
      payload['from_livestream_id'] ??
          payload['sender_livestream_id'] ??
          payload['data']?['sender_livestream_id'],
    );
    pkReceiverLivestreamId.value = _toInt(
      payload['livestream_id'] ??
          payload['receiver_livestream_id'] ??
          payload['data']?['receiver_livestream_id'],
    );
    pkSenderHostId.value = _toInt(
      payload['from_host_id'] ??
          payload['sender_host_id'] ??
          payload['data']?['sender_host_id'],
    );
    pkReceiverHostId.value = _toInt(
      payload['to_host_id'] ??
          payload['receiver_host_id'] ??
          payload['data']?['receiver_host_id'],
    );
    pkRequestPopupVisible.value = true;
  }

  void handlePkRequestSent(Map<String, dynamic> payload) {
    currentPkId.value = _toInt(payload['pk_id'] ?? payload['data']?['id']);
    pkSenderLivestreamId.value = _toInt(
      payload['livestream_id'] ??
          payload['sender_livestream_id'] ??
          payload['data']?['sender_livestream_id'],
    );
    pkReceiverLivestreamId.value = _toInt(
      payload['to_livestream_id'] ??
          payload['receiver_livestream_id'] ??
          payload['data']?['receiver_livestream_id'],
    );
    pkSenderHostId.value = _toInt(
      payload['from_host_id'] ??
          payload['sender_host_id'] ??
          payload['data']?['sender_host_id'],
    );
    pkReceiverHostId.value = _toInt(
      payload['to_host_id'] ??
          payload['receiver_host_id'] ??
          payload['data']?['receiver_host_id'],
    );
    pkWaitingForResponse.value = true;
  }

  void handlePkStarted(Map<String, dynamic> payload) {
    final nestedData = _asMap(payload['data']);
    final data = nestedData.isNotEmpty ? nestedData : payload;
    final mergedPayload = <String, dynamic>{...nestedData, ...payload};

    currentPkId.value = _toInt(payload['pk_id'] ?? data['id']);
    pkSenderLivestreamId.value = _toInt(
      payload['sender_livestream_id'] ?? data['sender_livestream_id'],
    );
    pkReceiverLivestreamId.value = _toInt(
      payload['receiver_livestream_id'] ?? data['receiver_livestream_id'],
    );
    pkSenderHostId.value = _toInt(
      payload['sender_host_id'] ?? data['sender_host_id'],
    );
    pkReceiverHostId.value = _toInt(
      payload['receiver_host_id'] ?? data['receiver_host_id'],
    );

    pkSenderScore.value = _toInt(
      payload['sender_score'] ?? data['sender_score'],
    );
    pkReceiverScore.value = _toInt(
      payload['receiver_score'] ?? data['receiver_score'],
    );

    final senderLive = _asMap(
      data['sender_livestream'] ?? payload['sender_livestream'],
    );
    final receiverLive = _asMap(
      data['receiver_livestream'] ?? payload['receiver_livestream'],
    );

    final String pkChannel = _extractPkChannelFromMaps([
      payload,
      data,
      senderLive,
      receiverLive,
    ]);
    if (pkChannel.isNotEmpty) pkChannelName.value = pkChannel;

    pkSenderRoomId.value =
        (payload['sender_room_id'] ?? data['sender_room_id'] ?? '').toString();
    pkReceiverRoomId.value =
        (payload['receiver_room_id'] ?? data['receiver_room_id'] ?? '')
            .toString();

    if (senderLive.isNotEmpty) _pkSenderLiveData.value = senderLive;
    if (receiverLive.isNotEmpty) _pkReceiverLiveData.value = receiverLive;

    currentPkData.value = {
      ...Map<String, dynamic>.from(mergedPayload),
      'channel_name': pkChannelName.value,
      'pk_channel_name': pkChannelName.value,
    };

    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;
    pkResultVisible.value = false;
    pkModeActive.value = true;

    pkStartIntroVisible.value = true;
    pkStartIntroText.value = 'PK START';
    Future.delayed(const Duration(seconds: 2), () {
      pkStartIntroVisible.value = false;
    });

    final int duration = _toInt(
      payload['duration_seconds'] ?? data['duration_seconds'],
    );
    _startPkTimer(durationSeconds: duration > 0 ? duration : 300);

    liveLog(
      '⚔️ PK started => pk=${currentPkId.value} sender=${pkSenderHostId.value} receiver=${pkReceiverHostId.value} channel=${pkChannelName.value}',
    );
  }

  void handlePkScoreUpdated(Map<String, dynamic> payload) {
    try {
      final Map<String, dynamic> nested = _asMap(payload['data']);
      final Map<String, dynamic> giftMap = _asMap(
        payload['gift'] ??
            payload['gift_data'] ??
            payload['gift_info'] ??
            payload['asset'],
      );
      final Map<String, dynamic> data = nested.isNotEmpty
          ? <String, dynamic>{...payload, ...nested}
          : Map<String, dynamic>.from(payload);

      final int incomingPkId = _toInt(data['pk_id'] ?? data['id']);
      if (incomingPkId > 0 && currentPkId.value == 0) {
        currentPkId.value = incomingPkId;
      }

      final String pkChannel = _extractPkChannelFromMaps([data, payload]);
      if (pkChannel.isNotEmpty && pkChannelName.value.trim().isEmpty) {
        pkChannelName.value = pkChannel;
      }

      final bool hasSenderScore =
          data.containsKey('sender_score') ||
              data.containsKey('pk_sender_score') ||
              data.containsKey('sender_total_score');
      final bool hasReceiverScore =
          data.containsKey('receiver_score') ||
              data.containsKey('pk_receiver_score') ||
              data.containsKey('receiver_total_score');

      if (hasSenderScore || hasReceiverScore) {
        final int senderScore = _toInt(
          data['sender_score'] ??
              data['pk_sender_score'] ??
              data['sender_total_score'] ??
              pkSenderScore.value,
        );
        final int receiverScore = _toInt(
          data['receiver_score'] ??
              data['pk_receiver_score'] ??
              data['receiver_total_score'] ??
              pkReceiverScore.value,
        );

        // Backend sometimes sends partial 0/0 while gift event is still processing.
        // Do not reset an existing PK score to zero from a partial event.
        if (!(senderScore == 0 &&
            receiverScore == 0 &&
            (pkSenderScore.value + pkReceiverScore.value) > 0)) {
          pkSenderScore.value = senderScore;
          pkReceiverScore.value = receiverScore;
        }

        liveLog(
          '📊 PK SCORE UPDATED => sender=${pkSenderScore.value} receiver=${pkReceiverScore.value} payload=$payload',
        );
        return;
      }

      /// ✅ Fallback for gift events where backend sends gift/coin but not scores.
      /// Progress bar will still move immediately based on receiver side.
      final int coin = _toInt(
        data['gift_coin'] ??
            data['gift_coins'] ??
            data['gift_price'] ??
            data['price'] ??
            data['coin'] ??
            data['coins'] ??
            data['amount'] ??
            data['diamond'] ??
            data['diamonds'] ??
            giftMap['gift_coin'] ??
            giftMap['coin'] ??
            giftMap['coins'] ??
            giftMap['price'] ??
            giftMap['diamond'],
      );
      if (coin <= 0) return;

      final String stableEventKey =
      (data['event_id'] ??
          data['gift_event_id'] ??
          data['gift_log_id'] ??
          data['transaction_id'] ??
          data['id'] ??
          '')
          .toString()
          .trim();
      if (stableEventKey.isNotEmpty) {
        final String scoreKey = 'pk_${currentPkId.value}_$stableEventKey';
        if (_processedPkGiftScoreEventKeys.contains(scoreKey)) {
          liveLog('ℹ️ Duplicate PK gift score ignored => $scoreKey');
          return;
        }
        _processedPkGiftScoreEventKeys.add(scoreKey);
        if (_processedPkGiftScoreEventKeys.length > 120) {
          _processedPkGiftScoreEventKeys.remove(
            _processedPkGiftScoreEventKeys.first,
          );
        }
      }

      final int receiverId = _toInt(
        data['receiver_id'] ??
            data['to_user_id'] ??
            data['receiver_user_id'] ??
            data['gift_receiver_id'] ??
            data['to_id'] ??
            data['host_id'] ??
            data['broadcaster_id'] ??
            _asMap(data['receiver'])['id'] ??
            _asMap(data['receiver_user'])['id'] ??
            _asMap(data['host'])['id'],
      );
      final int eventStreamId = _toInt(
        data['livestream_id'] ??
            data['stream_id'] ??
            data['live_stream_id'] ??
            data['receiver_livestream_id'] ??
            data['sender_livestream_id'],
      );

      final String side =
      (data['pk_side'] ?? data['side'] ?? data['receiver_side'] ?? '')
          .toString()
          .toLowerCase();

      final bool receiverIsSenderSide =
          side == 'sender' ||
              side == 'left' ||
              receiverId == pkSenderHostId.value ||
              eventStreamId == pkSenderLivestreamId.value;
      final bool receiverIsReceiverSide =
          side == 'receiver' ||
              side == 'right' ||
              receiverId == pkReceiverHostId.value ||
              eventStreamId == pkReceiverLivestreamId.value;

      if (receiverIsSenderSide && !receiverIsReceiverSide) {
        pkSenderScore.value = pkSenderScore.value + coin;
      } else if (receiverIsReceiverSide && !receiverIsSenderSide) {
        pkReceiverScore.value = pkReceiverScore.value + coin;
      } else {
        /// Unknown side: if gift is for current live stream, add to that stream's PK side.
        final int myStream = streamId.value;
        if (myStream > 0 && myStream == pkSenderLivestreamId.value) {
          pkSenderScore.value = pkSenderScore.value + coin;
        } else if (myStream > 0 && myStream == pkReceiverLivestreamId.value) {
          pkReceiverScore.value = pkReceiverScore.value + coin;
        }
      }

      liveLog(
        '📊 PK SCORE FALLBACK GIFT => +$coin sender=${pkSenderScore.value} '
            'receiver=${pkReceiverScore.value} receiverId=$receiverId stream=$eventStreamId payload=$payload',
      );
    } catch (e) {
      liveLog('⚠️ handlePkScoreUpdated failed => $e');
    }
  }

  void updatePkViewerCountFromEvent(Map<String, dynamic> payload) {
    final data = _asMap(payload['data']).isNotEmpty
        ? _asMap(payload['data'])
        : payload;

    final int eventStreamId = _toInt(
      data['livestream_id'] ??
          data['stream_id'] ??
          data['live_stream_id'] ??
          data['room_id'],
    );

    if (eventStreamId <= 0) return;

    int count = _toInt(
      data['viewer_count'] ??
          data['livestream_viewers_count'] ??
          data['total_viewers'] ??
          data['count'],
    );

    if (count <= 0) {
      // Fallback: local list size for current stream when backend does not send count.
      if (eventStreamId == streamId.value) {
        count = liveViewerList.length;
      }
    }

    if (count < 0) return;

    if (pkSenderLivestreamId.value > 0 &&
        eventStreamId == pkSenderLivestreamId.value) {
      pkSenderViewerCount.value = count;
    }

    if (pkReceiverLivestreamId.value > 0 &&
        eventStreamId == pkReceiverLivestreamId.value) {
      pkReceiverViewerCount.value = count;
    }

    update();
    liveLog(
      '👀 PK VIEWER COUNT UPDATED => stream=$eventStreamId count=$count sender=${pkSenderViewerCount.value} receiver=${pkReceiverViewerCount.value}',
    );
  }

  void handlePkRejected(Map<String, dynamic> payload) {
    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;
    incomingPkRequest.clear();

    Fluttertoast.showToast(
      msg: payload['message']?.toString() ?? ('PK request rejected').appTr,
    );
  }



  void _applyPkResult(
      Map<String, dynamic> payload, {
        String source = 'preview',
      }) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse('${value ?? 0}') ?? 0;
    }

    final nestedData = _asMap(payload['data']);

    dynamic pick(String key) {
      return payload[key] ?? nestedData[key];
    }

    final int myStreamId = toInt(streamId.value);

    final int senderStreamId = toInt(pick('sender_livestream_id'));
    final int receiverStreamId = toInt(pick('receiver_livestream_id'));

    final int senderScore = toInt(pick('sender_score'));
    final int receiverScore = toInt(pick('receiver_score'));

    int winnerStreamId = toInt(pick('winner_livestream_id'));
    int loserStreamId = toInt(pick('loser_livestream_id'));

    final String result = '${pick('result') ?? ''}'.toLowerCase();

    bool isDraw =
        pick('is_draw') == true ||
            pick('is_draw')?.toString() == '1' ||
            result == 'draw';

    // ✅ winner_livestream_id না থাকলে score/result দিয়ে winner বের করবো
    if (!isDraw && winnerStreamId == 0) {
      if (result == 'sender_win') {
        winnerStreamId = senderStreamId;
        loserStreamId = receiverStreamId;
      } else if (result == 'receiver_win') {
        winnerStreamId = receiverStreamId;
        loserStreamId = senderStreamId;
      } else if (senderScore > receiverScore) {
        winnerStreamId = senderStreamId;
        loserStreamId = receiverStreamId;
      } else if (receiverScore > senderScore) {
        winnerStreamId = receiverStreamId;
        loserStreamId = senderStreamId;
      } else {
        isDraw = true;
      }
    }

    String resultText;

    if (isDraw) {
      resultText = 'DRAW';
      liveLog(
        '🤝 PK DRAW [$source] => my=$myStreamId sender=$senderScore receiver=$receiverScore',
      );
    } else if (winnerStreamId > 0 && winnerStreamId == myStreamId) {
      resultText = 'WIN';
      liveLog(
        '🏆 PK WIN [$source] => my=$myStreamId winner=$winnerStreamId sender=$senderScore receiver=$receiverScore',
      );
    } else {
      resultText = 'LOSS';
      liveLog(
        '💔 PK LOSS [$source] => my=$myStreamId winner=$winnerStreamId sender=$senderScore receiver=$receiverScore',
      );
    }

    pkResultText.value = resultText;
    pkResultVisible.value = true;

    pkResultData.assignAll({
      ...payload,
      'sender_livestream_id': senderStreamId,
      'receiver_livestream_id': receiverStreamId,
      'sender_score': senderScore,
      'receiver_score': receiverScore,
      'winner_livestream_id': winnerStreamId,
      'loser_livestream_id': loserStreamId,
      'is_draw': isDraw ? 1 : 0,
      'result_text': resultText,
      'source': source,
    });

    update();
  }

  void handlePkResultPreview(
      Map<String, dynamic> payload, {
        bool isEnded = false,
      }) {
    final nestedData = _asMap(payload['data']);

    // ✅ Top-level payload + nested data merge করলাম
    // Top-level priority বেশি, কারণ winner_livestream_id/result সাধারণত top-level এ থাকে
    final merged = <String, dynamic>{...nestedData, ...payload};

    _applyPkResult(merged, source: isEnded ? 'ended' : 'preview');

    Future.delayed(Duration(seconds: isEnded ? 5 : 4), () {
      pkResultVisible.value = false;
    });
  }

  void handlePkEnded(Map<String, dynamic> payload) {
    stopPkTimer();

    final nestedData = _asMap(payload['data']);
    final data = <String, dynamic>{...nestedData, ...payload};

    // ✅ আগে result calculate/show হবে
    _applyPkResult(Map<String, dynamic>.from(data), source: 'ended');

    // ✅ IMPORTANT:
    // PK card/camera overlay যেন ended হওয়ার পর camera এর উপর না থাকে,
    // তাই running PK data সাথে সাথে clear করবো।
    pkModeActive.value = false;
    pkStartIntroVisible.value = false;
    pkEndingCountdownVisible.value = false;
    pkEndingCountdownText.value = '';
    pkWaitingForResponse.value = false;
    pkRequestPopupVisible.value = false;

    currentPkData.clear();
    currentPkData.refresh();

    incomingPkRequest.clear();
    incomingPkRequest.refresh();

    _pkSenderLiveData.clear();
    _pkReceiverLiveData.clear();

    currentPkId.value = 0;
    pkSenderLivestreamId.value = 0;
    pkReceiverLivestreamId.value = 0;
    pkSenderHostId.value = 0;
    pkReceiverHostId.value = 0;

    pkSenderScore.value = 0;
    pkReceiverScore.value = 0;
    _processedPkGiftScoreEventKeys.clear();
    pkSenderViewerCount.value = 0;
    pkReceiverViewerCount.value = 0;

    pkDurationSeconds.value = 300;
    pkRemainingSeconds.value = 0;
    pkChannelName.value = '';
    pkSenderRoomId.value = '';
    pkReceiverRoomId.value = '';

    update();

    // ✅ শুধু result overlay 5 sec থাকবে, PK card/data আর থাকবে না
    Future.delayed(const Duration(seconds: 5), () {
      pkResultVisible.value = false;
      pkResultText.value = '';
      pkResultData.clear();
      update();
    });
  }
}

class _GlobalLuckyWinBannerCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _GlobalLuckyWinBannerCard({required this.data, required this.onTap});

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _image(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    return ImageHelper.getImageUrl(raw);
  }

  String _number(dynamic value) {
    final double number = double.tryParse(value?.toString() ?? '') ?? 0;
    if (number % 1 == 0) return number.toInt().toString();
    return number.toStringAsFixed(1);
  }

  String _coins(dynamic value) {
    final int n = int.tryParse(value?.toString() ?? '') ?? 0;
    if (n >= 1000000) {
      final double v = n / 1000000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      final double v = n / 1000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}K';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final sender = _map(data['sender'] ?? data['user']);
    final gift = _map(data['gift']);
    final String senderName = (sender['name'] ?? sender['username'] ?? 'User')
        .toString();
    final String senderImage = _image(
      sender['profile_image'] ?? sender['avatar'] ?? sender['image'],
    );
    final String giftImage = _image(
      gift['show_image'] ?? gift['gift_image'] ?? gift['image'] ?? gift['icon'],
    );
    final String multiplier = _number(data['multiplier']);
    final String winCoin = _coins(
      data['win_amount'] ?? data['back_coin'] ?? data['win_coin'],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(begin: const Offset(1.12, 0), end: Offset.zero),
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        builder: (_, offset, child) => Transform.translate(
          offset: Offset(offset.dx * 180, 0),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: .94, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, scale, innerChild) =>
                Transform.scale(scale: scale, child: innerChild),
            child: child,
          ),
        ),
        child: Container(
          height: 68,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              colors: [Color(0xff6f0b8f), Color(0xffd21f7a), Color(0xffff8b00)],
            ),
            border: Border.all(color: const Color(0xffffec8a), width: 1.6),
            boxShadow: const [
              BoxShadow(
                color: Color(0xaa000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(color: Color(0x99ff8a00), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 7),
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xffffec74), Color(0xffff7200)],
                  ),
                  border: Border.all(color: Colors.white, width: 1.3),
                ),
                child: ClipOval(
                  child: senderImage.isEmpty
                      ? Container(
                    color: const Color(0xff516b7c),
                    child: const Icon(Icons.person, color: Colors.white),
                  )
                      : CachedNetworkImage(
                    imageUrl: senderImage,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    placeholder: (_, __) =>
                        Container(color: Colors.white10),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xff516b7c),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Lucky jackpot — tap to enter room',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xffffefb0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (giftImage.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: giftImage,
                  width: 42,
                  height: 42,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, __) => const SizedBox(width: 42),
                  errorWidget: (_, __, ___) => const SizedBox(width: 42),
                ),
              const SizedBox(width: 5),
              Text(
                'x$multiplier',
                style: const TextStyle(
                  color: Color(0xfffff07a),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 7),
              Container(
                height: 48,
                constraints: const BoxConstraints(minWidth: 88),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xffffd62a), Color(0xffd85a00)],
                  ),
                  border: Border.all(
                    color: const Color(0xfffff3a0),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '+$winCoin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 7),
            ],
          ),
        ),
      ),
    );
  }
}
