import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetlivepro/app/modules/livestream/socket/websocket_controller.dart';
import 'package:meetlivepro/app/modules/livestream/managers/live_viewer_state_manager.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../services/agora_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../messanger/views/audio_call_view.dart';
import '../../messanger/views/video_call_view.dart';
import '../endLive/endLive.dart';
import '../utils/LiveTestingLogger.dart';
import 'agoraTokenController.dart';
import 'live_create_controller.dart';
import 'live_call_controller.dart';
import 'live_banner_controller.dart';
import 'live_comment_controller.dart';
import 'live_exit_controller.dart';
import 'live_emoji_controller.dart';
import 'live_gift_controller.dart';
import 'live_lucky_gift_controller.dart';
import 'live_moderation_controller.dart';
import 'live_music_controller.dart';
import 'live_permanent_room_controller.dart';
import 'live_pk_controller.dart';
import 'live_presence_controller.dart';
import 'live_room_settings_controller.dart';
import 'live_session_controller.dart';
import 'live_seat_controller.dart';
import 'live_video_session_controller.dart';
import 'live_viewer_controller.dart';
import 'live_youtube_controller.dart';
import 'red_packet_controller.dart';
import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class LivestreamController extends GetxController {
  late final LiveCreateController liveCreateController = LiveCreateController(
    this,
  );
  late final LiveExitController liveExitController = LiveExitController(this);
  late final LiveEmojiController liveEmojiController = LiveEmojiController(
    this,
  );
  late final LiveViewerController liveViewerController = LiveViewerController(
    this,
  );
  late final LiveSeatController liveSeatController = LiveSeatController(this);
  late final LiveGiftController liveGiftController = LiveGiftController(this);
  late final LiveLuckyGiftController liveLuckyGiftController =
      LiveLuckyGiftController(this);
  late final LiveCallController liveCallController = LiveCallController(this);
  LiveBannerController get liveBannerController => globalLiveBannerQueue();
  late final LiveCommentController liveCommentController =
      LiveCommentController(this);
  late final LiveModerationController liveModerationController =
      LiveModerationController(this);
  late final LiveMusicController liveMusicController = LiveMusicController(
    this,
  );
  late final LivePermanentRoomController livePermanentRoomController =
      LivePermanentRoomController(this);
  late final LivePkController livePkController = LivePkController(this);
  late final LivePresenceController livePresenceController =
      LivePresenceController(this);
  late final LiveRoomSettingsController liveRoomSettingsController =
      LiveRoomSettingsController(this);
  late final LiveSessionController liveSessionController =
      LiveSessionController(this);
  late final LiveVideoSessionController liveVideoSessionController =
      LiveVideoSessionController(this);
  late final LiveYoutubeController liveYoutubeController =
      LiveYoutubeController(this);

  int get roomSessionGeneration => liveSessionController.generation;
  bool get roomTransitionInProgress =>
      liveSessionController.transitionInProgress;

  int beginRoomTransition({required int targetStreamId}) =>
      liveSessionController.beginRoomTransition(targetStreamId: targetStreamId);

  void activateRoomSession({required int streamId, required int generation}) =>
      liveSessionController.activateRoomSession(
        streamId: streamId,
        generation: generation,
      );

  bool acceptsRoomMutation(int streamId) =>
      liveSessionController.acceptsRoomMutation(streamId);

  bool isRoomSessionCurrent({required int streamId, required int generation}) =>
      liveSessionController.isRoomSessionCurrent(
        streamId: streamId,
        generation: generation,
      );

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

  RxMap<String, dynamic> get luckyGiftOverlayData =>
      liveLuckyGiftController.luckyGiftOverlayData;
  RxBool get luckyGiftOverlayVisible =>
      liveLuckyGiftController.luckyGiftOverlayVisible;
  RxList<Map<String, dynamic>> get luckyGiftTickerQueue =>
      liveLuckyGiftController.luckyGiftTickerQueue;
  RxBool get luckyGiftCoinRainVisible =>
      liveLuckyGiftController.luckyGiftCoinRainVisible;

  /// App-wide Lucky Win banner state. This lives in MyApp.builder, so it stays
  /// visible on Home, Messages, Profile, Games and every live-room route.
  RxMap<String, dynamic> get globalLuckyWinData =>
      liveBannerController.globalLuckyWinData;
  RxBool get globalLuckyWinBannerVisible =>
      liveBannerController.globalLuckyWinBannerVisible;
  RxInt get globalLuckyWinBannerSeconds =>
      liveBannerController.globalLuckyWinBannerSeconds;

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
  }) => redPacketController.showGlobalLuckyBagBanner(packet, seconds: seconds);

  void hideGlobalLuckyBagBanner() =>
      redPacketController.hideGlobalLuckyBagBanner();

  Map<String, dynamic> extractRedPacketFromEvent(dynamic payload) =>
      redPacketController.extractRedPacketFromEvent(payload);

  bool redPacketEventIsGlobal(dynamic payload, Map<String, dynamic> packet) =>
      redPacketController.redPacketEventIsGlobal(payload, packet);

  void handleRedPacketSentForGlobalBanner(dynamic payload) =>
      redPacketController.handleRedPacketSentForGlobalBanner(payload);

  final RxBool showMiniScene = false.obs;
  RxBool get isVideoLiveMinimized =>
      liveVideoSessionController.isVideoLiveMinimized;
  RxMap<String, dynamic> get minimizedVideoLiveSession =>
      liveVideoSessionController.minimizedVideoLiveSession;
  RxSet<int> get videoLiveRemoteUids =>
      liveVideoSessionController.videoLiveRemoteUids;
  RxMap<int, bool> get videoLiveRemoteVideoEnabled =>
      liveVideoSessionController.videoLiveRemoteVideoEnabled;
  RxMap<int, int> get videoCallerAgoraUidMap =>
      liveVideoSessionController.videoCallerAgoraUidMap;

  void syncVideoLiveRemoteUid(int uid, {required bool connected}) =>
      liveVideoSessionController.syncVideoLiveRemoteUid(
        uid,
        connected: connected,
      );

  void syncVideoLiveRemoteVideo(int uid, {required bool enabled}) =>
      liveVideoSessionController.syncVideoLiveRemoteVideo(
        uid,
        enabled: enabled,
      );

  void mapVideoCallerToAgoraUid({
    required int callerId,
    required int remoteUid,
  }) => liveVideoSessionController.mapVideoCallerToAgoraUid(
    callerId: callerId,
    remoteUid: remoteUid,
  );

  void syncVideoCallerAgoraMappingsFromCalls(Iterable<dynamic> calls) =>
      liveVideoSessionController.syncVideoCallerAgoraMappingsFromCalls(calls);

  void minimizeVideoLiveSession({
    required int livestreamId,
    required String channelName,
    required String token,
    required bool isBroadcaster,
    required Map<String, dynamic> arguments,
    bool activateImmediately = true,
  }) => liveVideoSessionController.minimizeVideoLiveSession(
    livestreamId: livestreamId,
    channelName: channelName,
    token: token,
    isBroadcaster: isBroadcaster,
    arguments: arguments,
    activateImmediately: activateImmediately,
  );

  void activateMinimizedVideoLiveRenderer() =>
      liveVideoSessionController.activateMinimizedVideoLiveRenderer();

  void beginVideoLiveRestore() =>
      liveVideoSessionController.beginVideoLiveRestore();

  void clearMinimizedVideoLiveSession() =>
      liveVideoSessionController.clearMinimizedVideoLiveSession();

  final dio = Dio();
  final AuthController authController = Get.find();
  final isLock = true.obs;
  final audienscMute = false.obs;

  /// ===================== LIVE MUSIC / AUDIO MIXING =====================
  RxString get selectedMusicPath => liveMusicController.selectedMusicPath;
  RxString get liveMusicName => liveMusicController.liveMusicName;
  RxString get liveMusicStatus => liveMusicController.liveMusicStatus;
  RxBool get musicLoading => liveMusicController.musicLoading;
  RxBool get isMusicPlayerSheetOpen =>
      liveMusicController.isMusicPlayerSheetOpen;
  RxInt get musicPositionMs => liveMusicController.musicPositionMs;
  RxInt get musicDurationMs => liveMusicController.musicDurationMs;
  RxInt get musicVolume => liveMusicController.musicVolume;
  RxBool get musicRepeat => liveMusicController.musicRepeat;
  RxBool get musicSeeking => liveMusicController.musicSeeking;
  RxList<Map<String, String>> get recentLiveMusics =>
      liveMusicController.recentLiveMusics;
  RxBool get musicActionRunning => liveMusicController.musicActionRunning;
  double get liveMusicProgress => liveMusicController.liveMusicProgress;
  String formatMusicTime(int milliseconds) =>
      liveMusicController.formatMusicTime(milliseconds);

  /// ===================== LIVE YOUTUBE CONTROL =====================
  /// YouTube video locally play hobe sob audience app-e.
  /// Host mute/music mute er sathe YouTube sound relation nai.
  RxString get liveYoutubeStatus => liveYoutubeController.liveYoutubeStatus;
  RxString get liveYoutubeUrl => liveYoutubeController.liveYoutubeUrl;
  RxString get liveYoutubeVideoId => liveYoutubeController.liveYoutubeVideoId;
  RxBool get youtubeLoading => liveYoutubeController.youtubeLoading;

  bool get isLiveMusicPlaying => liveMusicController.isLiveMusicPlaying;

  AgoraTokenController agoraTokenController = Get.find();

  /// ===================== LIVE IMOGI / EMOJI =====================
  RxBool get imogiLoading => liveEmojiController.imogiLoading;
  RxBool get imogiSending => liveEmojiController.imogiSending;
  RxInt get selectedImogiCategoryIndex =>
      liveEmojiController.selectedImogiCategoryIndex;
  RxList<Map<String, dynamic>> get imogiCategoryList =>
      liveEmojiController.imogiCategoryList;
  RxList<Map<String, dynamic>> get imogiList => liveEmojiController.imogiList;
  RxBool get quickGiftVisible => liveGiftController.quickGiftVisible;
  RxBool get quickGiftSending => liveGiftController.quickGiftSending;
  RxInt get quickGiftCountdown => liveGiftController.quickGiftCountdown;
  RxInt get quickGiftComboCount => liveGiftController.quickGiftComboCount;
  RxMap<String, dynamic> get quickGiftData => liveGiftController.quickGiftData;
  RxInt get quickGiftPendingCount => liveGiftController.quickGiftPendingCount;
  void showQuickGiftButton({
    required int receiverId,
    required int giftId,
    required int giftPrice,
    Map<String, dynamic>? gift,
    List<int>? receiverIds,
  }) => liveGiftController.showQuickGiftButton(
    receiverId: receiverId,
    giftId: giftId,
    giftPrice: giftPrice,
    gift: gift,
    receiverIds: receiverIds,
  );

  Future<void> sendQuickGiftAgain() => liveGiftController.sendQuickGiftAgain();

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

  RxBool get isBroadcaster => liveSessionController.isBroadcaster;
  RxBool get isHost => liveSessionController.isHost;
  RxInt get streamId => liveSessionController.streamId;
  RxInt get broadcasterId => liveSessionController.broadcasterId;
  //for live stream start
  //generate token
  final getTokens = {}.obs;
  WebsocketController get websocketController =>
      Get.find<WebsocketController>();

  int get currentPresenceStreamId =>
      livePresenceController.currentPresenceStreamId;
  String get currentPresenceRole => livePresenceController.currentPresenceRole;
  bool get currentPresenceIsOnSeat =>
      livePresenceController.currentPresenceIsOnSeat;
  int? get currentPresenceSeatNo =>
      livePresenceController.currentPresenceSeatNo;
  Map<String, dynamic> get livePresenceDebugSnapshot =>
      livePresenceController.livePresenceDebugSnapshot;

  Future<void> sendPresenceHeartbeatOnce({
    int? livestreamId,
    String? role,
    bool? isOnSeat,
    int? seatNo,
  }) => livePresenceController.sendPresenceHeartbeatOnce(
    livestreamId: livestreamId,
    role: role,
    isOnSeat: isOnSeat,
    seatNo: seatNo,
  );

  void startLivePresenceHeartbeat({
    required int livestreamId,
    required String role,
    bool isOnSeat = false,
    int? seatNo,
    Duration? interval,
    bool backgroundMode = false,
  }) => livePresenceController.startLivePresenceHeartbeat(
    livestreamId: livestreamId,
    role: role,
    isOnSeat: isOnSeat,
    seatNo: seatNo,
    interval: interval,
    backgroundMode: backgroundMode,
  );

  void setLivePresenceBackgroundMode(bool enabled) =>
      livePresenceController.setLivePresenceBackgroundMode(enabled);

  void updateLivePresenceRole({
    required String role,
    bool? isOnSeat,
    int? seatNo,
  }) => livePresenceController.updateLivePresenceRole(
    role: role,
    isOnSeat: isOnSeat,
    seatNo: seatNo,
  );

  void stopLivePresenceHeartbeat() =>
      livePresenceController.stopLivePresenceHeartbeat();

  Future<void> markUserOffline({
    int? livestreamId,
    String? role,
    int? seatNo,
  }) => livePresenceController.markUserOffline(
    livestreamId: livestreamId,
    role: role,
    seatNo: seatNo,
  );

  Future<Map<String, dynamic>?> fetchPresenceWithLiveState({
    int? livestreamId,
  }) => livePresenceController.fetchPresenceWithLiveState(
    livestreamId: livestreamId,
  );

  /// ===================== NORMAL / PK AGORA SESSION =====================
  /// PK start hole normal live channel/token save kore rakha hobe.
  /// PK end hole abar normal live channel e fire jawa jabe.
  String _normalAgoraChannelName = '';
  String _normalAgoraToken = '';
  bool _normalAgoraWasBroadcaster = false;

  RxString get pkChannelName => livePkController.pkChannelName;
  RxString get pkSenderRoomId => livePkController.pkSenderRoomId;
  RxString get pkReceiverRoomId => livePkController.pkReceiverRoomId;
  RxBool get pkAgoraJoining => livePkController.pkAgoraJoining;

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
      'Normal Agora session saved => channel=$channelName broadcaster=$isBroadcaster',
    );
  }

  void clearPkAgoraSession() => livePkController.clearPkAgoraSession();

  void syncPkStateFromLiveData(
    Map<String, dynamic> raw, {
    String source = 'initial_pk_state',
  }) => livePkController.syncPkStateFromLiveData(raw, source: source);
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

    livePresenceController.setPresenceState(
      role: 'viewer',
      isOnSeat: false,
      seatNo: null,
    );

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
      livePresenceController.setPresenceState(
        role: 'caller',
        isOnSeat: true,
        seatNo: localSeat,
      );

      await sendPresenceHeartbeatOnce(
        livestreamId: currentPresenceStreamId,
        role: 'caller',
        isOnSeat: true,
        seatNo: localSeat,
      );

      if (currentPresenceStreamId > 0) {
        await tryToGetCallList(streamId: currentPresenceStreamId);
      }
    });
  }

  void reconcileSelfSeatFromAvailableSeats(Map<String, dynamic> seatsData) =>
      _reconcileSelfSeatFromAvailableSeats(seatsData);

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
    final int stateStreamId = livestream.isNotEmpty
        ? _toInt(livestream['id'] ?? livestream['livestream_id'])
        : _toInt(state['livestream_id'] ?? state['stream_id'] ?? state['id']);
    if (stateStreamId > 0 && !acceptsRoomMutation(stateStreamId)) {
      liveLog(
        'Late room snapshot ignored => event=$stateStreamId '
        'active=${liveSessionController.activeSessionStreamId} '
        'generation=${liveSessionController.generation}',
      );
      return;
    }

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

    final int sid = stateStreamId;

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
      role: role ?? currentPresenceRole,
      isOnSeat: isOnSeat ?? currentPresenceIsOnSeat,
      seatNo: seatNo ?? currentPresenceSeatNo,
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

  void lastPingUpdate({required int id}) =>
      livePresenceController.lastPingUpdate(id: id);

  void stopPingUpdate() => livePresenceController.stopPingUpdate();

  void updatePingInterval(Duration newInterval) =>
      livePresenceController.updatePingInterval(newInterval);
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

  int toIntForViewer(dynamic value) => _toInt(value);

  void ensureViewerPresenceAfterAdd(int joinedStreamId) {
    livePresenceController.ensureViewerPresenceAfterAdd(joinedStreamId);
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
      if (!acceptsRoomMutation(streamId)) {
        liveLog('Late viewer list ignored => stream=$streamId');
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

      // A target snapshot can race the successful add-viewer response and omit
      // self briefly. Preserve only an already-confirmed current-room self row;
      // subsequent API/socket events still reconcile by user ID.
      final int selfUserId = authController.userProfile.value.user?.id?.toInt() ?? 0;
      dynamic confirmedSelfViewer;
      if (selfUserId > 0) {
        for (final viewer in liveViewerList) {
          if (_toInt(_viewerUserId(viewer)) == selfUserId) {
            confirmedSelfViewer = viewer;
            break;
          }
        }
      }

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
      if (confirmedSelfViewer != null &&
          !liveViewerList.any(
            (viewer) => _toInt(_viewerUserId(viewer)) == selfUserId,
          )) {
        addOrUpdateViewerLocal(confirmedSelfViewer, force: true);
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
  }) => redPacketController.sendRedPacket(
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
  }) => redPacketController.getLivestreamRedPackets(
    livestreamId: livestreamId,
    status: status,
    perPage: perPage,
  );

  //create live stream
  final createStreamData = {}.obs;
  final isCreatingLive = false.obs;
  RxBool get isOwnerClosingPermanentRoom =>
      livePermanentRoomController.isOwnerClosingPermanentRoom;

  Map<String, dynamic> normalizeCreateResponse(dynamic responseData) =>
      livePermanentRoomController.normalizeCreateResponse(responseData);

  Map<String, dynamic> mapCreateValue(dynamic value) =>
      livePermanentRoomController.mapCreateValue(value);

  Future<bool> openCreatedRoomAsHost({
    required Map<String, dynamic> responseMap,
    required int userId,
    String? requestedStreamType,
    int? requestedSeatCount,
    int? requestedRoomLayout,
    int? requestedRoomTheme,
    int? requestedRoomBackground,
  }) => livePermanentRoomController.openCreatedRoomAsHost(
    responseMap: responseMap,
    userId: userId,
    requestedStreamType: requestedStreamType,
    requestedSeatCount: requestedSeatCount,
    requestedRoomLayout: requestedRoomLayout,
    requestedRoomTheme: requestedRoomTheme,
    requestedRoomBackground: requestedRoomBackground,
  );

  Future<Map<String, dynamic>?> getMyPermanentRoom({
    required int userId,
    bool showNotFound = false,
  }) => livePermanentRoomController.getMyPermanentRoom(
    userId: userId,
    showNotFound: showNotFound,
  );

  Future<bool> rejoinPermanentRoom({
    required int livestreamId,
    Map<String, dynamic>? fallbackLiveData,
  }) => livePermanentRoomController.rejoinPermanentRoom(
    livestreamId: livestreamId,
    fallbackLiveData: fallbackLiveData,
  );

  Future<bool> leavePermanentRoom({required int livestreamId}) =>
      livePermanentRoomController.leavePermanentRoom(
        livestreamId: livestreamId,
      );

  Future<bool> closePermanentRoom({
    required int livestreamId,
    bool navigateToEnd = true,
  }) => livePermanentRoomController.closePermanentRoom(
    livestreamId: livestreamId,
    navigateToEnd: navigateToEnd,
  );

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
  }) => liveCreateController.tryToCreateLivestream(
    streamTitle: streamTitle,
    anousment: anousment,
    streamType: streamType,
    userId: userId,
    seatCountValue: seatCountValue,
    roomLayout: roomLayout,
    roomTheme: roomTheme,
    roomBackground: roomBackground,
    streamImageFile: streamImageFile,
    roomPassword: roomPassword,
    roomLock: roomLock,
    lockComent: lockComent,
    hiddenRoom: hiddenRoom,
    screenRecords: screenRecords,
    screenshort: screenshort,
  );

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
  Future<void> tryToRemoveLivestream({
    required int streamId,
    bool navigateToEnd = true,
  }) => liveExitController.tryToRemoveLivestream(
    streamId: streamId,
    navigateToEnd: navigateToEnd,
  );

  // add viewer
  final createData = {}.obs;
  Future<Map<String, dynamic>?> tryToAddViewer({
    required int streamId,
    required int viewerId,
    bool syncState = true,
    bool activateRoom = true,
  }) => liveViewerController.tryToAddViewer(
    streamId: streamId,
    viewerId: viewerId,
    syncState: syncState,
    activateRoom: activateRoom,
  );

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
    livePresenceController.stopPingUpdate();
    livePresenceController.stopLivePresenceHeartbeat();
    livePkController.stopPkTimer();
    liveMusicController.resetMusicState();
    liveGiftController.disposeGiftState();
    redPacketController.disposeRedPacketState();
    liveBannerController.resetLuckyPresentation();
    liveYoutubeController.resetYoutubeState();
    liveVideoSessionController.clearVideoSessionState();

    super.onClose();
  }
  //------------------------- live time ------------------

  final removeData = {}.obs;
  // remove viewer
  Future<void> tryToRemoveViewer({
    required int streamId,
    required int viewerId,
  }) => liveExitController.tryToRemoveViewer(
    streamId: streamId,
    viewerId: viewerId,
  );

  // get viewer list
  final viewerList = [].obs;

  Future<void> tryToGetViewerList({required int streamId}) =>
      liveViewerController.tryToGetViewerList(streamId: streamId);

  // call live stream
  RxMap<String, dynamic> get callersData => liveCallController.callersData;

  void clearDepartedCallerGuard(int userId) {
    liveCallController.clearDepartedCallerGuard(userId);
  }

  /// Prevents rapid multi-tap/double API calls while seat request is already running.
  RxBool get seatJoinLoading => liveCallController.seatJoinLoading;

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
  }) => liveCallController.tryToCallLivestream(
    streamId: streamId,
    seatNO: seatNO,
    totalSeats: totalSeats,
    callerId: callerId,
    callType: callType,
  );

  Future<int?> resolveCallJoinSeatNo({
    required int livestreamId,
    required int callerId,
    required String callType,
    int? requestedSeatNo,
    int? requestedTotalSeats,
  }) => _resolveJoinSeatNo(
    livestreamId: livestreamId,
    callerId: callerId,
    callType: callType,
    requestedSeatNo: requestedSeatNo,
    requestedTotalSeats: requestedTotalSeats,
  );

  void applySuccessfulCallJoin({
    required dynamic responseData,
    required int streamId,
    required int callerId,
    required int seatNo,
    required String callType,
  }) {
    final appliedImmediately = _applyAcceptedSeatFromCallResponse(
      responseData: responseData,
      streamId: streamId,
      callerId: callerId,
      seatNo: seatNo,
      callType: callType,
    );
    liveLog(
      'SEAT REQUEST OK | stream=$streamId | user=$callerId | '
      'seat=$seatNo | immediate=$appliedImmediately',
    );
    _scheduleSeatJoinReconciliation(
      streamId: streamId,
      callerId: callerId,
      seatNo: seatNo,
      callType: callType,
    );
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
      call['seat_no'] ?? call['seatNo'] ?? call['seat'] ?? call['seat_number'],
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

    if (normalized['user'] is! Map || (normalized['user'] as Map).isEmpty) {
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

  bool _hasAcceptedSeatLocally({required int streamId, required int callerId}) {
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

  bool _shouldPreserveAcceptedCallFromWeakSnapshot(Map<String, dynamic> call) {
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
    if (callerId <= 0 || liveCallController.isCallerLocallyDeparted(callerId)) {
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
  RxList<dynamic> get callList => liveCallController.callList;
  final selectIndex = 0.obs;
  Future<void> tryToGetCallList({required int streamId, bool force = false}) =>
      liveCallController.tryToGetCallList(streamId: streamId, force: force);

  void applyFetchedCallList({
    required int streamId,
    required List<dynamic> calls,
  }) {
    final bool isAudioRoom =
        websocketController.activeAudioStreamId.value == streamId;
    final safeList = calls
        .where((rawCall) {
          if (!isAudioRoom || rawCall is! Map) return true;
          final type = (rawCall['call_type'] ?? rawCall['type'] ?? 'audio')
              .toString()
              .trim()
              .toLowerCase();
          return type != 'video' && type != 'popular';
        })
        .toList(growable: false);
    callList.assignAll(safeList);
    final filtered = safeList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isAcceptedCaller)
        .where((call) {
          final id = int.tryParse(_callIdentity(call)) ?? 0;
          return !liveCallController.isCallerLocallyDeparted(id);
        })
        .toList();
    _mergeAcceptedCallListSafely(filtered);
  }

  // accept call
  Future<bool> tryToAcceptCall({required int streamId, required int userId}) =>
      liveCallController.tryToAcceptCall(streamId: streamId, userId: userId);

  Future<void> applyAcceptedCallResponse({
    required int streamId,
    required int userId,
    Map<String, dynamic>? pendingCall,
  }) async {
    Map<String, dynamic>? acceptedCall = pendingCall;

    if (acceptedCall != null) {
      acceptedCall['call_status'] = 'accepted';
      acceptedCall['status'] = 'accepted';
      final index = websocketController.liveCallList.indexWhere((raw) {
        return raw is Map &&
            _callIdentity(Map<String, dynamic>.from(raw)) == userId.toString();
      });
      if (index == -1) {
        websocketController.liveCallList.add(acceptedCall);
      } else {
        websocketController.liveCallList[index] = _mergeCallPreservingUser(
          Map<String, dynamic>.from(websocketController.liveCallList[index]),
          acceptedCall,
        );
      }
      websocketController.liveCallList.refresh();
    }

    websocketController.pendingCall.removeWhere((call) {
      final callerId = call['caller_id']?.toString();
      final callUserId = call['user']?['id']?.toString();
      return callerId == userId.toString() || callUserId == userId.toString();
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
        await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
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
      }
    }

    if (currentUserId == userId) {
      dynamic currentCall;
      for (final item in websocketController.liveCallList) {
        if (item is! Map) continue;
        final callerId = item['caller_id']?.toString();
        final callUserId = item['user']?['id']?.toString();
        if (callerId == userId.toString() || callUserId == userId.toString()) {
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
  }

  String callIdentity(Map<String, dynamic> call) => _callIdentity(call);

  // reject call / leave seat
  Future<bool> tryToRejectCall({required int streamId, required int userId}) =>
      liveCallController.tryToRejectCall(streamId: streamId, userId: userId);

  Future<void> applyRejectedCallResponse({
    required int streamId,
    required int userId,
  }) async {
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId == userId) {
      await websocketController.deactivateLocalCallerMediaForLeave(userId);
      websocketController.audioMutedUserMap[userId] = true;
      websocketController.audioMutedUserMap.refresh();
      mute.value = true;
      isMuted.value = true;
      isAudioEnabled.value = false;
    }

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

  Future<void> tryToAddComment({required String comment}) =>
      liveCommentController.tryToAddComment(comment: comment);
  RxList<Map<String, dynamic>> get giftList => liveGiftController.giftList;
  RxList<Map<String, dynamic>> get giftHistory =>
      liveGiftController.giftHistory;
  RxInt get totalGiftCoins => liveGiftController.totalGiftCoins;
  RxInt get giftReceiverID => liveGiftController.giftReceiverID;
  RxInt get selectedSeatNo => liveGiftController.selectedSeatNo;

  bool get isPkCommentGiftActive => livePkController.isPkCommentGiftActive;
  int get currentPkOpponentLivestreamId =>
      livePkController.currentPkOpponentLivestreamId;
  Map<String, dynamic> pkCommentGiftMetaBody() =>
      livePkController.pkCommentGiftMetaBody();
  // Controller এ list রাখুন
  RxList<int> get selectedReceiverIds => liveGiftController.selectedReceiverIds;

  // onTap এ ID add/remove করুন
  void toggleProfileSelection(int index, int userId) {
    liveGiftController.toggleProfileSelection(index, userId);
  }

  Future<Map<String, dynamic>?> tryToSendGift({
    required int receiverId,
    required int giftId,
    required int giftPrice,
    List<int>? receiverIdsOverride,
    bool dispatchLocalAnimation = true,
    String? clientEventId,
    Map<String, dynamic>? localGift,
  }) => liveGiftController.tryToSendGift(
    receiverId: receiverId,
    giftId: giftId,
    giftPrice: giftPrice,
    receiverIdsOverride: receiverIdsOverride,
    dispatchLocalAnimation: dispatchLocalAnimation,
    clientEventId: clientEventId,
    localGift: localGift,
  );

  /// Gift coins are stream-aware. Same stream restore keeps coins;
  /// new stream hard resets so old live coins/time cannot carry over.

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
      liveGiftController.activateGiftRoom(newStreamId);

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
    liveGiftController.activateGiftRoom(newStreamId);

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
    liveCallController.resetRoomSessionState();
    createData.clear();
    removeData.clear();
    broadcasterId.value = 0;
    liveGiftController.resetGiftRoomState(streamId: newStreamId);
    liveEmojiController.resetRoomEmojiState();

    // Reset volatile room totals only for a genuinely different/new stream.
    liveLuckyGiftController.resetRoomLuckyState();
    selectedGiftSendingId.value = 0;

    // Timer must restart from the new stream created_at/start_time.
    resetLiveTimerForNewStream(newStreamId: newStreamId, source: source);

    // Music/Youtube local state belongs to a single room only.
    liveMusicController.resetMusicState();
    liveYoutubeController.resetYoutubeState();

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
  RxInt get selectedGiftCategoryIndex =>
      liveGiftController.selectedGiftCategoryIndex;
  RxInt get selectedGiftSendingId => liveGiftController.selectedGiftSendingId;
  RxMap<String, dynamic> get luckyGiftResult =>
      liveLuckyGiftController.luckyGiftResult;
  RxBool get luckyGiftResultVisible =>
      liveLuckyGiftController.luckyGiftResultVisible;

  String giftCategoryOf(Map<String, dynamic> gift) {
    return liveGiftController.giftCategoryOf(gift);
  }

  List<String> get giftCategories {
    return liveGiftController.giftCategories;
  }

  List<Map<String, dynamic>> giftsByCategoryIndex(int index) {
    return liveGiftController.giftsByCategoryIndex(index);
  }

  void showGlobalLuckyWinBannerFromPayload(Map<String, dynamic> payload) =>
      liveBannerController.showGlobalLuckyWinBannerFromPayload(payload);

  void hideGlobalLuckyWinBanner({bool showNext = true}) =>
      liveBannerController.hideGlobalLuckyWinBanner(showNext: showNext);

  Future<void> openGlobalLuckyWinRoom(Map<String, dynamic> raw) =>
      liveBannerController.openGlobalLuckyWinRoom(raw);

  void showLuckyGiftResult(Map<String, dynamic> data) =>
      liveLuckyGiftController.showLuckyGiftResult(data);

  void showLuckyGiftVideoStyleResult(Map<String, dynamic> payload) =>
      liveLuckyGiftController.showLuckyGiftVideoStyleResult(payload);

  Future<void> fetchGiftList() async {
    return liveGiftController.fetchGiftList();
  }

  // Fetch gift history for current livestream
  Future<void> fetchGiftHistory() async {
    return liveGiftController.fetchGiftHistory();
  }

  void syncLiveGiftCoinsFromPayload(
    Map<String, dynamic> payload, {
    String source = 'payload',
  }) {
    liveGiftController.syncLiveGiftCoinsFromPayload(payload, source: source);
  }

  // Fetch total gift coins for current livestream
  Future<void> fetchTotalGiftCoins() async {
    return liveGiftController.fetchTotalGiftCoins();
  }

  @override
  void onInit() {
    authController.configureProtectedDio(dio);
    globalLiveBannerQueue();

    if (!Get.isRegistered<LiveCreateController>()) {
      Get.put<LiveCreateController>(liveCreateController);
    }
    if (!Get.isRegistered<LiveSessionController>()) {
      Get.put<LiveSessionController>(liveSessionController);
    }
    if (!Get.isRegistered<LiveVideoSessionController>()) {
      Get.put<LiveVideoSessionController>(liveVideoSessionController);
    }
    if (!Get.isRegistered<LiveExitController>()) {
      Get.put<LiveExitController>(liveExitController);
    }
    if (!Get.isRegistered<LiveEmojiController>()) {
      Get.put<LiveEmojiController>(liveEmojiController);
    }
    if (!Get.isRegistered<LiveViewerController>()) {
      Get.put<LiveViewerController>(liveViewerController);
    }

    if (!Get.isRegistered<LiveSeatController>()) {
      Get.put<LiveSeatController>(liveSeatController);
    }
    if (!Get.isRegistered<LiveGiftController>()) {
      Get.put<LiveGiftController>(liveGiftController);
    }
    if (!Get.isRegistered<LiveLuckyGiftController>()) {
      Get.put<LiveLuckyGiftController>(liveLuckyGiftController);
    }
    if (!Get.isRegistered<LiveCallController>()) {
      Get.put<LiveCallController>(liveCallController);
    }
    if (!Get.isRegistered<LiveCommentController>()) {
      Get.put<LiveCommentController>(liveCommentController);
    }
    if (!Get.isRegistered<LiveModerationController>()) {
      Get.put<LiveModerationController>(liveModerationController);
    }
    if (!Get.isRegistered<LiveMusicController>()) {
      Get.put<LiveMusicController>(liveMusicController);
    }
    if (!Get.isRegistered<LivePermanentRoomController>()) {
      Get.put<LivePermanentRoomController>(livePermanentRoomController);
    }
    if (!Get.isRegistered<LiveYoutubeController>()) {
      Get.put<LiveYoutubeController>(liveYoutubeController);
    }
    if (!Get.isRegistered<LivePresenceController>()) {
      Get.put<LivePresenceController>(livePresenceController);
    }

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

  RxInt get selectedGiftId => liveGiftController.selectedGiftId;

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
  }) => liveMusicController.keepMusicPublishingWhenMicMuted(
    engine,
    micMuted: micMuted,
  );

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
  }) => liveModerationController.addToRoomBlacklist(
    livestreamId,
    userId,
    reason: reason,
  );

  // Kick out user from livestream
  Future<bool> kickOutUser(int userId) =>
      liveModerationController.kickOutUser(userId);

  // Get available seats for livestream
  final availableSeatsData = {}.obs;

  /// ✅ STEP 3A PERFORMANCE: available seats API is called from room open,
  /// resume, safety sync and room settings. A very small cache + in-flight
  /// guard prevents 3-5 duplicate HTTP calls in the same second while keeping
  /// realtime seat updates controlled by WebSocket.
  Future<Map<String, dynamic>?> getAvailableSeats(int livestreamId) =>
      liveSeatController.getAvailableSeats(livestreamId);

  Future<void> pickAndPlayLiveMusic({required RtcEngine? rtcEngine}) =>
      liveMusicController.pickAndPlayLiveMusic(rtcEngine: rtcEngine);

  Future<void> playRecentLiveMusic({
    required RtcEngine? rtcEngine,
    required Map<String, String> music,
  }) => liveMusicController.playRecentLiveMusic(
    rtcEngine: rtcEngine,
    music: music,
  );

  Future<void> seekLiveMusic({
    required RtcEngine? rtcEngine,
    required int positionMs,
  }) => liveMusicController.seekLiveMusic(
    rtcEngine: rtcEngine,
    positionMs: positionMs,
  );

  Future<void> setLiveMusicVolume({
    required RtcEngine? rtcEngine,
    required int volume,
  }) => liveMusicController.setLiveMusicVolume(
    rtcEngine: rtcEngine,
    volume: volume,
  );

  Future<void> toggleLiveMusicRepeat({required RtcEngine? rtcEngine}) =>
      liveMusicController.toggleLiveMusicRepeat(rtcEngine: rtcEngine);

  Future<void> pauseLiveMusic({required RtcEngine? rtcEngine}) =>
      liveMusicController.pauseLiveMusic(rtcEngine: rtcEngine);

  Future<void> resumeLiveMusic({required RtcEngine? rtcEngine}) =>
      liveMusicController.resumeLiveMusic(rtcEngine: rtcEngine);

  Future<void> stopLiveMusic({required RtcEngine? rtcEngine}) =>
      liveMusicController.stopLiveMusic(rtcEngine: rtcEngine);

  /// ===================== LIVE YOUTUBE APIs =====================
  String extractYoutubeVideoId(String url) =>
      liveYoutubeController.extractYoutubeVideoId(url);

  Future<void> playOrChangeYoutube(String url) =>
      liveYoutubeController.playOrChangeYoutube(url);

  Future<void> pauseYoutube() => liveYoutubeController.pauseYoutube();

  Future<void> resumeYoutube() => liveYoutubeController.resumeYoutube();

  Future<void> stopYoutube() => liveYoutubeController.stopYoutube();

  Future<Map<String, dynamic>?> fetchYoutubeState(int livestreamId) =>
      liveYoutubeController.fetchYoutubeState(livestreamId);

  RxBool get roomEditLoading => liveRoomSettingsController.roomEditLoading;
  RxBool get roomSettingsLoading =>
      liveRoomSettingsController.roomSettingsLoading;
  RxBool get liveRoomLocked => liveRoomSettingsController.liveRoomLocked;
  RxBool get liveCommentLocked => liveRoomSettingsController.liveCommentLocked;
  RxBool get liveHiddenRoom => liveRoomSettingsController.liveHiddenRoom;
  RxBool get liveScreenRecordBlocked =>
      liveRoomSettingsController.liveScreenRecordBlocked;
  RxBool get liveScreenshotBlocked =>
      liveRoomSettingsController.liveScreenshotBlocked;

  void syncRoomSafetyFromCurrentLiveData({
    String source = 'current_live_data',
  }) => liveRoomSettingsController.syncRoomSafetyFromCurrentLiveData(
    source: source,
  );

  void applyRoomSafetySettingsFromPayload(
    Map<String, dynamic> payload, {
    String source = 'unknown',
  }) => liveRoomSettingsController.applyRoomSafetySettingsFromPayload(
    payload,
    source: source,
  );

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
  }) => liveRoomSettingsController.editLiveStreamRoom(
    livestreamId: livestreamId,
    userId: userId,
    seatCount: seatCount,
    roomLayout: roomLayout,
    roomTheme: roomTheme,
    roomBackground: roomBackground,
    streamTitle: streamTitle,
    streamAnnouncement: streamAnnouncement,
    streamImageFile: streamImageFile,
    roomPassword: roomPassword,
    roomLock: roomLock,
    lockComent: lockComent,
    hiddenRoom: hiddenRoom,
    screenRecords: screenRecords,
    screenshort: screenshort,
  );

  Future<bool> cleanLiveComments() => liveCommentController.cleanLiveComments();
  Future<bool> setRoomPasswordLock({
    required bool lock,
    String roomPassword = '',
  }) => liveRoomSettingsController.setRoomPasswordLock(
    lock: lock,
    roomPassword: roomPassword,
  );

  Future<bool> setLiveCommentLock(bool lock) =>
      liveRoomSettingsController.setLiveCommentLock(lock);

  Future<bool> setHiddenRoom(bool hide) =>
      liveRoomSettingsController.setHiddenRoom(hide);

  Future<bool> setScreenRecordBlock(bool block) =>
      liveRoomSettingsController.setScreenRecordBlock(block);

  Future<bool> setScreenshotBlock(bool block) =>
      liveRoomSettingsController.setScreenshotBlock(block);

  /// ===================== SEAT SWITCH API =====================
  RxBool get seatSwitchLoading => liveSeatController.seatSwitchLoading;

  int currentUserSeatNo({bool ignorePresence = false}) =>
      liveSeatController.currentUserSeatNo(ignorePresence: ignorePresence);

  bool isSeatOccupied(int seatNo) => liveSeatController.isSeatOccupied(seatNo);

  Future<Map<String, dynamic>?> switchAudioSeat({
    required int livestreamId,
    required int toSeatNo,
    int? fromSeatNo,
  }) => liveSeatController.switchAudioSeat(
    livestreamId: livestreamId,
    toSeatNo: toSeatNo,
    fromSeatNo: fromSeatNo,
  );

  void applySuccessfulSeatSwitch({
    required int currentUserId,
    required int fromSeatNo,
    required int toSeatNo,
    required Map<String, dynamic> callData,
    required Map<String, dynamic> responseData,
  }) {
    try {
      final ws = Get.find<WebsocketController>();
      ws.applySeatSwitch(
        userId: currentUserId,
        fromSeatNo: fromSeatNo,
        toSeatNo: toSeatNo,
        callData: callData,
      );
      ws.syncCpSeatConnectionsFromAnyPayload(
        responseData,
        source: 'local_seat_switch_response',
      );
    } catch (e) {
      liveLog('⚠️ Local applySeatSwitch skipped: $e');
    }
  }

  /// ===================== SEAT LOCK APIs =====================
  /// Only broadcaster should call these from UI.
  /// Backend will broadcast action_type: seat_lock_toggle.
  final seatLockLoading = false.obs;

  Future<Map<String, dynamic>?> toggleSeatLock({
    required int livestreamId,
    required int seatNo,
  }) => liveSeatController.toggleSeatLock(
    livestreamId: livestreamId,
    seatNo: seatNo,
  );

  Future<Map<String, dynamic>?> lockSeat({
    required int livestreamId,
    required int seatNo,
  }) => liveSeatController.lockSeat(livestreamId: livestreamId, seatNo: seatNo);

  Future<Map<String, dynamic>?> unlockSeat({
    required int livestreamId,
    required int seatNo,
  }) =>
      liveSeatController.unlockSeat(livestreamId: livestreamId, seatNo: seatNo);

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
  ) => liveCallController.checkCanJoinLivestream(streamId, userId);

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

  /// ===================== LIVE IMOGI / EMOJI API =====================
  Future<void> fetchImogiList() => liveEmojiController.fetchImogiList();

  List<Map<String, dynamic>> getImogiesByCategoryIndex(int index) =>
      liveEmojiController.getImogiesByCategoryIndex(index);

  Future<bool> sendLiveImogi({required int streamId, required int imogiId}) =>
      liveEmojiController.sendLiveImogi(streamId: streamId, imogiId: imogiId);

  ///--------------------------- Guardian assigned -----------
  RxBool get isMyGuardian => liveModerationController.isMyGuardian;
  RxList<dynamic> get guardianListData =>
      liveModerationController.guardianListData;
  RxBool get guardianLoading => liveModerationController.guardianLoading;
  RxMap<int, bool> get roomGuardianMap =>
      liveModerationController.roomGuardianMap;
  RxBool get guardianNoticeVisible =>
      liveModerationController.guardianNoticeVisible;
  RxString get guardianNoticeText =>
      liveModerationController.guardianNoticeText;

  bool isRoomGuardianUser(dynamic rawUserId) =>
      liveModerationController.isRoomGuardianUser(rawUserId);

  bool hasRoomGuardianStatus(dynamic rawUserId) =>
      liveModerationController.hasRoomGuardianStatus(rawUserId);

  void showGuardianNotice(String userName, {bool assigned = true}) =>
      liveModerationController.showGuardianNotice(userName, assigned: assigned);

  void applyGuardianHomeState(bool isGuardian) {
    try {
      homeController.isGuardianPermission.value = isGuardian;
      homeController.isGuardianData['is_guardian'] = isGuardian;
      homeController.isGuardianData['value'] = isGuardian ? 1 : 0;
      homeController.isGuardianData.refresh();
    } catch (_) {}
  }

  bool get isCurrentUserCurrentLiveOwner =>
      liveModerationController.isCurrentUserCurrentLiveOwner;

  bool get canModerateLive => liveModerationController.canModerateLive;

  bool canModerateSeatAction(String actionName) =>
      liveModerationController.ensureCanModerateCurrentLive(actionName);

  bool _ensureCanModerateCurrentLive(String actionName) =>
      liveModerationController.ensureCanModerateCurrentLive(actionName);

  bool ensureCanModerateCurrentLive(String actionName) =>
      _ensureCanModerateCurrentLive(actionName);

  Future<bool> assignGuardian({
    required int streamId,
    required int userId,
    bool closeBottomSheet = true,
  }) => liveModerationController.assignGuardian(
    streamId: streamId,
    userId: userId,
    closeBottomSheet: closeBottomSheet,
  );

  Future<bool> removeGuardianUser({
    required int streamId,
    required int userId,
    bool closeBottomSheet = true,
  }) => liveModerationController.removeGuardianUser(
    streamId: streamId,
    userId: userId,
    closeBottomSheet: closeBottomSheet,
  );

  void applyGuardianLocalStatus({
    required int userId,
    required bool isGuardian,
    Map<String, dynamic>? caller,
  }) => liveModerationController.applyGuardianLocalStatus(
    userId: userId,
    isGuardian: isGuardian,
    caller: caller,
  );

  Future<void> fetchGuardianList({required int streamId}) =>
      liveModerationController.fetchGuardianList(streamId: streamId);

  Future<bool> refreshMyGuardianStatus({required int streamId, int? userId}) =>
      liveModerationController.refreshMyGuardianStatus(
        streamId: streamId,
        userId: userId,
      );

  Future<void> applyGuardianFromSocket(Map<String, dynamic> data) =>
      liveModerationController.applyGuardianFromSocket(data);

  Future<void> syncGuardianStateForRoom({required int streamId, int? userId}) =>
      liveModerationController.syncGuardianStateForRoom(
        streamId: streamId,
        userId: userId,
      );

  Future<void> GuardianList({required int StreanId}) =>
      liveModerationController.fetchGuardianList(streamId: StreanId);

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

  /// PK compatibility facade. Authoritative state and implementation live in
  /// [LivePkController].
  RxBool get pkModeActive => livePkController.pkModeActive;
  RxBool get pkRequestLoading => livePkController.pkRequestLoading;
  RxBool get pkWaitingForResponse => livePkController.pkWaitingForResponse;
  RxBool get pkRequestPopupVisible => livePkController.pkRequestPopupVisible;
  RxBool get pkResultVisible => livePkController.pkResultVisible;
  RxString get pkResultText => livePkController.pkResultText;
  RxBool get pkStartIntroVisible => livePkController.pkStartIntroVisible;
  RxString get pkStartIntroText => livePkController.pkStartIntroText;
  RxBool get pkEndingCountdownVisible =>
      livePkController.pkEndingCountdownVisible;
  RxString get pkEndingCountdownText => livePkController.pkEndingCountdownText;
  RxMap<String, dynamic> get currentPkData => livePkController.currentPkData;
  RxMap<String, dynamic> get incomingPkRequest =>
      livePkController.incomingPkRequest;
  RxMap<String, dynamic> get pkResultData => livePkController.pkResultData;
  RxInt get currentPkId => livePkController.currentPkId;
  RxInt get pkSenderLivestreamId => livePkController.pkSenderLivestreamId;
  RxInt get pkReceiverLivestreamId => livePkController.pkReceiverLivestreamId;
  RxInt get pkSenderHostId => livePkController.pkSenderHostId;
  RxInt get pkReceiverHostId => livePkController.pkReceiverHostId;
  RxInt get pkSenderScore => livePkController.pkSenderScore;
  RxInt get pkReceiverScore => livePkController.pkReceiverScore;
  RxInt get pkSenderViewerCount => livePkController.pkSenderViewerCount;
  RxInt get pkReceiverViewerCount => livePkController.pkReceiverViewerCount;
  RxInt get pkDurationSeconds => livePkController.pkDurationSeconds;
  RxInt get pkRemainingSeconds => livePkController.pkRemainingSeconds;
  RxBool get pkIsRunning => livePkController.pkIsRunning;
  Map<String, dynamic> get pkSenderLiveData =>
      livePkController.pkSenderLiveData;
  Map<String, dynamic> get pkReceiverLiveData =>
      livePkController.pkReceiverLiveData;
  String get pkFormattedRemainingTime =>
      livePkController.pkFormattedRemainingTime;
  double get pkSenderProgress => livePkController.pkSenderProgress;
  bool get isCurrentUserPkSender => livePkController.isCurrentUserPkSender;
  bool get isCurrentUserPkReceiver => livePkController.isCurrentUserPkReceiver;
  bool get isCurrentUserInPk => livePkController.isCurrentUserInPk;

  void stopPkTimer() => livePkController.stopPkTimer();
  void resetPkState({bool clearResult = true}) =>
      livePkController.resetPkState(clearResult: clearResult);

  Future<bool> sendPkRequest({
    required int senderLivestreamId,
    required int receiverLivestreamId,
    required int senderHostId,
    required int receiverHostId,
    Map<String, dynamic>? receiverLiveData,
  }) => livePkController.sendPkRequest(
    senderLivestreamId: senderLivestreamId,
    receiverLivestreamId: receiverLivestreamId,
    senderHostId: senderHostId,
    receiverHostId: receiverHostId,
    receiverLiveData: receiverLiveData,
  );

  Future<bool> respondPkRequest({
    required int pkId,
    required int receiverHostId,
    required String responseText,
  }) => livePkController.respondPkRequest(
    pkId: pkId,
    receiverHostId: receiverHostId,
    responseText: responseText,
  );

  Future<bool> endPk({int? pkId}) => livePkController.endPk(pkId: pkId);
  void handlePkRequestReceived(Map<String, dynamic> payload) =>
      livePkController.handlePkRequestReceived(payload);
  void handlePkRequestSent(Map<String, dynamic> payload) =>
      livePkController.handlePkRequestSent(payload);
  void handlePkStarted(Map<String, dynamic> payload) =>
      livePkController.handlePkStarted(payload);
  void handlePkScoreUpdated(Map<String, dynamic> payload) =>
      livePkController.handlePkScoreUpdated(payload);
  void updatePkViewerCountFromEvent(Map<String, dynamic> payload) =>
      livePkController.updatePkViewerCountFromEvent(payload);
  void handlePkRejected(Map<String, dynamic> payload) =>
      livePkController.handlePkRejected(payload);
  void handlePkResultPreview(
    Map<String, dynamic> payload, {
    bool isEnded = false,
  }) => livePkController.handlePkResultPreview(payload, isEnded: isEnded);
  void handlePkEnded(Map<String, dynamic> payload) =>
      livePkController.handlePkEnded(payload);
}
