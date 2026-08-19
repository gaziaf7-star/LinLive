import 'dart:async';
import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/safe_network_image.dart';
import '../../../../widgets/tasksLiveView.dart';
import '../../../services/agora_service.dart';
import '../../auth/views/profile_view.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../myprofile/views/ProfileConribution.dart';
import '../controllers/livestream_action_controller.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/audience_join_controller.dart';
import '../socket/websocket_controller.dart';
import '../helper_functions/call_list_helper.dart';
import '../utils/battery_optimizer.dart';
import '../widgets/AnimatedProgressBar.dart';
import '../widgets/CustomPartyRoom.dart';
import '../widgets/LiveProfile_AppBar.dart';
import '../widgets/Live_view _imageCard.dart';
import '../widgets/entry_animation.dart';
import '../widgets/gifts_animation.dart';
import '../widgets/live_comments.dart';
import '../widgets/live_viewer_list.dart';
import '../widgets/pk_live_widgets.dart';
import '../widgets/RedPacketLiveOverlay.dart';
import '../widgets/rocket_launch_overlay.dart';
import '../widgets/towVsTowPk.dart';
import '../widgets/write_comments.dart';
import '../videofilter/professional_video_effects_sheet.dart';
import '../videofilter/video_effect_models.dart';
import '../videofilter/video_effects_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

part 'videoliveSection/popular_live_helpers.dart';
part 'videoliveSection/popular_live_speaking_mute.dart';
part 'videoliveSection/popular_live_ui_drag.dart';
part 'videoliveSection/popular_live_video_lease.dart';
part 'videoliveSection/popular_live_agora_safety.dart';
part 'videoliveSection/popular_live_lifecycle.dart';
part 'videoliveSection/popular_live_caller_video.dart';
part 'videoliveSection/popular_live_pk_battle.dart';
part 'videoliveSection/popular_live_filter_gift.dart';

class PopularLiveView extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;
  final String token;
  final Map<String, dynamic>? roomData;

  const PopularLiveView({
    super.key,
    required this.channelName,
    required this.isBroadcaster,
    required this.token,
    this.roomData,
  });

  @override
  State<PopularLiveView> createState() => _PopularLiveViewState();
}

/// Persistent normal/Lucky gift repaint island for video/PK rooms.
class _PopularGiftOverlayHost extends StatelessWidget {
  const _PopularGiftOverlayHost({required this.controller});

  final WebsocketController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Obx(() {
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            controller.giftsData,
          );
          final bool active = controller.isGiftAnimationShowing.value;

          return IgnorePointer(
            ignoring: true,
            child: GiftAnimationWidget(
              key: const ValueKey('persistent_popular_gift_overlay'),
              giftData: data,
              isActive: active,
            ),
          );
        }),
      ),
    );
  }
}

class _PopularLiveViewState extends State<PopularLiveView>
    with WidgetsBindingObserver {
  LivestreamController liveController = Get.find();

  /// Keep old `livestreamController` usages safe without creating another controller.
  LivestreamController get livestreamController => liveController;
  LiveStreamActionController actionController = Get.put(
    LiveStreamActionController(),
  );
  final WebsocketController websocketController =
  Get.isRegistered<WebsocketController>()
      ? Get.find<WebsocketController>()
      : Get.put<WebsocketController>(
    WebsocketController(),
    permanent: true,
  );
  AnimatedProgressBarController animatedProgressBarController = Get.put(
    AnimatedProgressBarController(),
  );
  final AgoraService _agoraService = AgoraService();
  late final VideoEffectsController _liveVideoEffectsController;

  // ✅ FIX: video config here is otherwise fixed/adaptive-by-network only and
  // never reacts to battery/thermal state, which is a real contributor to a
  // phone running hot and stuttering on long streams. This minimal guard
  // only steps in at genuinely critical battery (pauses local video, the
  // single biggest power/heat saver) and restores it once battery recovers.
  final BatteryOptimizer _batteryGuardOptimizer = BatteryOptimizer();
  Timer? _batteryGuardTimer;
  bool _batteryGuardVideoDisabled = false;


  late final dynamic streamData;

  final streamInfo = {}.obs;
  final broadcasterData = {}.obs;
  String? _currentToken;

  /// Agora prepare guard.
  /// Fixes AgoraRtcException(-8) when opening another live while old channel
  /// is still active in the shared Agora engine.
  bool _prepareForLiveInProgress = false;

  /// Video live safe lifecycle flags.
  /// Host normal back/minimize/route change-e live end/remove hobe na.
  bool _isLiveMinimized = false;
  bool _isLiveExiting = false;
  bool _isHostLeavingRoomOnly = false;
  bool _videoExitCleanupStarted = false;
  bool _isVideoAppInBackground = false;
  Future<void>? _audienceExitCleanupFuture;
  RtcEngineEventHandler? _agoraEventHandler;
  final Set<int> _joinedRemoteUids = <int>{};
  final Set<int> _offlineRemoteUids = <int>{};
  final Set<int> _remoteVideoReadyUids = <int>{};
  final Set<String> _loggedVideoLayoutKeys = <String>{};
  final Map<String, Widget> _stableVideoRenderers = <String, Widget>{};
  // ✅ FIX (GPU driver crash, libGLES_mali.so SIGABRT): see _pkVideoForHost.
  // Caches PK battle video widgets by video-source identity only (channel +
  // local/remote uid), so a score/viewer-count update (which happens very
  // often during an active PK battle) does not recreate the underlying
  // AgoraVideoView/VideoViewController — mirrors the existing
  // _stableVideoRenderers pattern used elsewhere in this file.
  final Map<String, Widget> _stablePkVideoRenderers = <String, Widget>{};
  final Map<int, Timer> _remoteOfflineGraceTimers = <int, Timer>{};
  Worker? _videoCallListWorker;
  Future<void>? _remoteSubscriptionReconcileFuture;

  /// Accepted video/audio callers are cached while their real Agora media is
  /// still connected. Backend/API snapshots can briefly omit a caller after a
  /// 2-4 minute presence timeout even though both users still see/hear each
  /// other. The cache repairs that weak snapshot instead of hiding the seat.
  final Map<int, Map<String, dynamic>> _activeVideoCallLeaseCache =
  <int, Map<String, dynamic>>{};
  final Map<int, int> _activeVideoCallLeaseSeenAtMs = <int, int>{};
  Timer? _videoCallLeaseKeepAliveTimer;
  bool _videoCallLeaseRepairScheduled = false;
  static const int _videoCallOfflineGraceMs = 8000;

  /// Prevent duplicate camera toggle requests from caller cards.
  final Set<int> _videoToggleUsersInFlight = <int>{};

  String _lastSyncedPkChannel = '';
  bool _pkSyncScheduled = false;

  /// Agora speaking wave state.
  /// Backend chara Agora volume indication diye detect hobe ke kotha bolse.
  final Set<int> _speakingUserIds = <int>{};
  final Map<int, Timer> _speakingOffTimers = <int, Timer>{};
  static const int _speakingVolumeThreshold = 18;

  /// PK Agora channel state. Keeps old normal live safe and prevents repeated join.
  final RxSet<int> _pkRemoteUids = <int>{}.obs;
  String _activeAgoraChannel = '';
  String _lastPkJoinKey = '';
  bool _pkJoinInProgress = false;
  bool _normalReturnInProgress = false;
  bool _wasInPkChannel = false;

  /// Video room presence lease. Audio live already starts this heartbeat, but
  /// video live previously relied only on Agora. The backend therefore removed
  /// an active caller after its 120-second presence timeout while media kept
  /// flowing. This state keeps the video viewer/caller/host lease alive.


  final addComments = TextEditingController();

  // ✅ BATTERY OPTIMIZATION: Debounce setState calls to reduce UI updates
  Timer? _uiUpdateTimer;
  bool _needsUIUpdate = false;
  //sawip
  double _uiOffset = 0.0; // UI-র বর্তমান পজিশন
  bool _isUIVisible = true; // UI কি দেখা যাচ্ছে কি না


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoExitCleanupStarted) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(_enterVideoLiveSystemUi());
      _isVideoAppInBackground = false;
      liveController.setLivePresenceBackgroundMode(false);
      _ensureVideoPresenceHeartbeat(source: 'app_resumed');
      unawaited(_restoreVideoMediaAfterResume());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isVideoAppInBackground = true;
      liveController.setLivePresenceBackgroundMode(true);
    }
  }



  // ------------------------- timer ---------------

  @override
  void initState() {
    super.initState();
    _liveVideoEffectsController = VideoEffectsController(
      agoraService: _agoraService,
    );
    unawaited(_enterVideoLiveSystemUi());
    streamData = widget.roomData != null
        ? Map<String, dynamic>.from(widget.roomData!)
        : Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments)
        : <String, dynamic>{};
    WidgetsBinding.instance.addObserver(this);
    // Enable wake lock to keep screen on during live streaming
    WakelockPlus.enable();
    _startBatteryVideoGuard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.isRegistered<AudienceJoinController>()) {
        Get.find<AudienceJoinController>().markTargetRouteReady(
          streamId: _safeStreamId(),
        );
      }
      if (!kDebugMode) return;
      final String prefix = widget.isBroadcaster ? 'create' : 'join';
      debugPrint(
        '${prefix}_first_ui_ready=${DateTime.now().microsecondsSinceEpoch}',
      );
    });
    _currentToken = widget.token;
    final Map<String, dynamic> initArgs = streamData;
    final bool initLooksPk =
        initArgs['is_pk'] == 1 ||
            initArgs['is_pk'] == true ||
            initArgs['is_pk_room'] == true ||
            initArgs['stream_type']?.toString().toLowerCase() == 'pk' ||
            (initArgs['pk_id'] != null && initArgs['pk_id'].toString() != '0');
    final String normalChannelForReturn =
    (initArgs['normal_room_id'] ??
        initArgs['normal_channel_name'] ??
        initArgs['normal_agora_channel'] ??
        '')
        .toString()
        .trim();
    if (!initLooksPk || normalChannelForReturn.isNotEmpty) {
      liveController.saveNormalLiveAgoraSession(
        channelName: normalChannelForReturn.isNotEmpty
            ? normalChannelForReturn
            : widget.channelName,
        token: widget.token,
        isBroadcaster: widget.isBroadcaster,
      );
    }
    _bootstrapPkStateFromArguments(source: 'init_state_arguments');
    _videoCallListWorker = ever<List<dynamic>>(
      websocketController.liveCallList,
          (_) {
        _syncActiveVideoCallLeaseCache();
        _scheduleActiveVideoCallLeaseRepair(source: 'call_list_changed');
        _reconcileRemoteCallerSubscriptions();
        _ensureVideoPresenceHeartbeat(source: 'call_list_changed');
      },
    );

    _videoCallLeaseKeepAliveTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) {
        if (!mounted || _videoExitCleanupStarted || _isLiveExiting) return;
        _syncActiveVideoCallLeaseCache();
        _scheduleActiveVideoCallLeaseRepair(source: 'lease_keep_alive');
        _ensureVideoPresenceHeartbeat(source: 'lease_keep_alive');
        _reconcileRemoteCallerSubscriptions();
      },
    );
    String? createdAt;

    // প্রথমে createData থেকে check করি
    createdAt = liveController.createData['viewer']?['created_at'];

    // যদি createData থেকে না পাই, তাহলে arguments থেকে check করি
    if (createdAt == null) {
      createdAt = streamData['created_at'];
    }

    // যদি এখনো না পাই, তাহলে current time use করি
    if (createdAt != null) {
      liveController.startLive(createdAt);
    } else {
      // Fallback: current time দিয়ে timer start করি
      liveController.startLive(DateTime.now().toIso8601String());
    }

    final bool restoringMinimizedVideo =
        initArgs['restore_minimized_video_live'] == true;
    if (restoringMinimizedVideo) {
      unawaited(_restoreExistingVideoLiveSession());
    } else {
      prepareForLive();
    }
    if (widget.isBroadcaster) {
      liveController.isBroadcaster.value = true;
      setLiveStreamDataAsBroadcaster();
      websocketController.tryToConnectToUnifiedLiveStreamEventWs(force: false);
    } else {
      setLiveStreamDataAsAudience();
    }

    /// Initial call list refresh. Accept event late holeo UI sync thakbe.
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (_videoExitCleanupStarted || !mounted) return;
      try {
        final streamId = streamInfo['id'] ?? streamData?['id'];
        if (streamId != null) {
          await liveController.tryToGetCallList(streamId: streamId);
          websocketController.liveCallList.refresh();
          _ensureVideoPresenceHeartbeat(source: 'initial_call_list_refresh');
          if (mounted) _scheduleUIUpdate();
        }
      } catch (e) {
        print('❌ Popular call list initial refresh failed: $e');
      }
    });
    // Setup red packet callbacks
    _setupRedPacketCallbacks();
  }

  /// Open the exact same professional filter system used before going live.
  /// Presets / Beauty / Make up / Filter all continue to operate directly on
  /// the shared Agora engine, so changes are visible in the active broadcast.

  @override
  void dispose() {
    _liveVideoEffectsController.dispose();
    unawaited(_restoreSystemUiAfterVideoLive());
    WidgetsBinding.instance.removeObserver(this);
    if (_isLiveMinimized) {
      final handler = _agoraEventHandler;
      _agoraEventHandler = null;
      final engine = _agoraService.engine;
      if (handler != null && engine != null) {
        try {
          engine.unregisterEventHandler(handler);
        } catch (_) {}
      }
    }
    _videoCallListWorker?.dispose();
    _videoCallListWorker = null;
    _videoCallLeaseKeepAliveTimer?.cancel();
    _videoCallLeaseKeepAliveTimer = null;
    _activeVideoCallLeaseCache.clear();
    _activeVideoCallLeaseSeenAtMs.clear();
    // ✅ BATTERY OPTIMIZATION: Cancel UI update timer to prevent memory leaks
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
    _batteryGuardTimer?.cancel();
    _batteryGuardTimer = null;

    for (final timer in _speakingOffTimers.values) {
      timer.cancel();
    }
    _speakingOffTimers.clear();
    _speakingUserIds.clear();
    _pkRemoteUids.clear();
    _joinedRemoteUids.clear();
    _offlineRemoteUids.clear();
    for (final timer in _remoteOfflineGraceTimers.values) {
      timer.cancel();
    }
    _remoteOfflineGraceTimers.clear();
    _stableVideoRenderers.clear();
    _stablePkVideoRenderers.clear();

    // Disable wake lock to restore normal screen behavior
    WakelockPlus.disable();

    // Route disposal is not a live exit. Backend/Agora cleanup is performed
    // only by the explicit Keep/Exit dialog's true Exit methods.
    print(
      '✅ Video live route disposed without implicit cleanup '
          '=> minimized=$_isLiveMinimized actuallyLeaving=$_videoExitCleanupStarted',
    );

    websocketController.clearRedPacketCallbacks();
    super.dispose();
  }

  //for live stream end
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _showVideoLiveCloseOptions();
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: broadcasterData.isEmpty
              ? Stack(
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: SafeLiveBackgroundImage(
                  imageUrl: _popularBackgroundImageUrl(),
                  fit: BoxFit.cover,
                  height: kHeight,
                  width: kWeight,
                  memCacheWidth: 720,
                  memCacheHeight: 1280,
                  maxWidthDiskCache: 1080,
                  maxHeightDiskCache: 1920,
                ),
              ),
              // Image.asset(
              //   'assets/audio_live/1136.jpg',
              //   fit: BoxFit.cover,
              //   height: kHeight,
              //   width: kWeight,
              // ),
              // SpinKitChasingDots(size: 40, color: kPrimaryColor),
            ],
          )
              : Container(
            child: Stack(
              children: [
                // ✅ PK running হলে background camera hide করে premium gradient দেখাবো.
                // ✅ Normal popular live হলে old camera/background exactly same থাকবে.
                Obx(() {
                  if (!liveController.pkIsRunning.value) {
                    return const SizedBox.shrink();
                  }
                  return _premiumPkGradientBackground();
                }),

                Obx(() {
                  if (liveController.pkIsRunning.value) {
                    return const SizedBox.shrink();
                  }
                  return _broadcastView();
                }),

                Obx(() {
                  if (liveController.pkIsRunning.value) {
                    return const SizedBox.shrink();
                  }
                  // ✅ Normal popular/video live camera must stay clear.
                  // আগে এখানে black opacity 0.4 ছিল, তাই camera halka black/dark দেখাচ্ছিল।
                  // PK overlay untouched আছে; শুধু normal camera overlay remove করা হলো।
                  return const SizedBox.shrink();
                }),

                _pkAgoraSyncWatcher(),

                Positioned(
                  top: kHeight * 0.12,
                  left: 0,
                  right: 0,
                  child: Obx(() {
                    if (!liveController.pkIsRunning.value)
                      return const SizedBox.shrink();
                    return _buildRealPkVideoOverlay();
                  }),
                ),

                _buildPkStartIntroOverlay(),
                _buildPkBigCountdownOverlay(),
                _buildPkResultPreviewOverlay(),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  left: _uiOffset,
                  right: -_uiOffset,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            SizedBox(height: kHeight * 0.015),
                            //Live view Part one start
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  //fast row start
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      // ==== Left fixed Stack ====
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Main Container (Background + Info + Follow Button)
                                          Container(
                                            padding: EdgeInsets.only(
                                              right: Get.width * 0.02,
                                            ),
                                            margin: EdgeInsets.all(
                                              Get.width * 0.005,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(
                                                15,
                                              ),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(
                                                    0xff0e0e0e,
                                                  ).withOpacity(.5),
                                                  Color(
                                                    0xff0e0e0e,
                                                  ).withOpacity(.5),
                                                ],
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width:
                                                  Get.width * 0.13,
                                                ), // profile এর জায়গা
                                                Column(
                                                  spacing: 2,
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                                  children: [
                                                    _safeUserMap(
                                                      broadcasterData,
                                                    ).isNotEmpty
                                                        ? Text(
                                                      (() {
                                                        final name =
                                                            _safeUserMap(
                                                              broadcasterData,
                                                            )['name'] ??
                                                                '';
                                                        // ৬ অক্ষরের বেশি হলে শেষে ... দেখাবে
                                                        return name.length >
                                                            8
                                                            ? '${name.substring(0, 8)}...'
                                                            : name;
                                                      })(),
                                                      style: GoogleFonts.poppins(
                                                        color: Colors
                                                            .white,
                                                        fontSize:
                                                        (Get.height *
                                                            0.013)
                                                            .clamp(
                                                          9.0,
                                                          13.0,
                                                        ),
                                                        fontWeight:
                                                        FontWeight
                                                            .w500,
                                                      ),
                                                    )
                                                        : const SizedBox(),
                                                    (_safeUserMap(
                                                      broadcasterData,
                                                    )['user_id'] !=
                                                        null)
                                                        ? Text(
                                                      ('Uid : ${_safeUserMap(broadcasterData)['user_id']}')
                                                          .appTr,
                                                      style: GoogleFonts.poppins(
                                                        color: Colors
                                                            .white,
                                                        fontSize:
                                                        (Get.height *
                                                            0.012)
                                                            .clamp(
                                                          9.0,
                                                          14.0,
                                                        ),
                                                        fontWeight:
                                                        FontWeight
                                                            .w500,
                                                      ),
                                                    )
                                                        : const SizedBox(),
                                                  ],
                                                ),
                                                SizedBox(
                                                  width:
                                                  Get.width * 0.015,
                                                ),

                                                Obx(() {
                                                  if (_safeUserId(
                                                    broadcasterData,
                                                  ) ==
                                                      authController
                                                          .userProfile
                                                          .value
                                                          .user
                                                          ?.id) {
                                                    return const SizedBox();
                                                  }

                                                  return AnimatedSwitcher(
                                                    duration:
                                                    const Duration(
                                                      milliseconds:
                                                      300,
                                                    ),
                                                    child:
                                                    momentsController
                                                        .isFollowing1
                                                        .value
                                                        ? Container()
                                                        : InkWell(
                                                      key: const ValueKey(
                                                        'follow',
                                                      ),
                                                      onTap: () {
                                                        momentsController.followCreate(
                                                          userId:
                                                          '${_safeUserId(broadcasterData)}',
                                                        );
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.symmetric(
                                                          vertical:
                                                          Get.height *
                                                              0.007,
                                                          horizontal:
                                                          Get.width *
                                                              0.03,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                          BorderRadius.circular(
                                                            30,
                                                          ),
                                                          gradient: const LinearGradient(
                                                            colors: [
                                                              Color(
                                                                0xff1b07ca,
                                                              ),
                                                              Color(
                                                                0xff0724dd,
                                                              ),
                                                            ],
                                                            begin:
                                                            Alignment.topCenter,
                                                            end: Alignment
                                                                .bottomCenter,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          ('Follow')
                                                              .appTr,
                                                          style: GoogleFonts.lato(
                                                            fontWeight:
                                                            FontWeight.w600,
                                                            fontSize:
                                                            (Get.height *
                                                                0.006)
                                                                .clamp(
                                                              9.0,
                                                              14.0,
                                                            ),
                                                            color:
                                                            Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),

                                          // Profile + Fame Overlay
                                          Positioned(
                                            left: -kWeight * 0.048,
                                            top: -Get.height * 0.03,
                                            child: GestureDetector(
                                              onTap: () {
                                                homeController.liveVisitProfile(
                                                  userId:
                                                  '${_safeUserId(broadcasterData)}',
                                                  seatData:
                                                  websocketController
                                                      .liveCallList
                                                      .isNotEmpty
                                                      ? websocketController
                                                      .liveCallList
                                                      .first
                                                      : broadcasterData,
                                                );
                                              },
                                              child: Obx(() {
                                                double size =
                                                    Get.height * 0.055;
                                                final user = _safeUserMap(
                                                  broadcasterData,
                                                );
                                                final frameData =
                                                user['asset_purchase_history'];
                                                // Safe convert
                                                final agencyIdRaw =
                                                user['agencyId'];
                                                final int agencyId =
                                                    int.tryParse(
                                                      agencyIdRaw
                                                          ?.toString() ??
                                                          '0',
                                                    ) ??
                                                        0;

                                                return SizedBox(
                                                  height: kHeight * 0.1,
                                                  width: kHeight * 0.11,
                                                  child: Stack(
                                                    alignment:
                                                    Alignment.center,
                                                    children: [
                                                      if (_isUserSpeaking(
                                                        user['id'],
                                                      ) &&
                                                          !_isUserMuted(
                                                            user['id'],
                                                          ))
                                                        SpeakingWave(
                                                          size:
                                                          size * 0.92,
                                                        ),

                                                      // ---------------- PROFILE IMAGE ----------------
                                                      ClipOval(
                                                        child: CachedNetworkImage(
                                                          imageUrl:
                                                          ImageHelper.getImageUrl(
                                                            "${user['profile_image']}",
                                                          ),
                                                          fit: BoxFit
                                                              .cover,
                                                          height:
                                                          size * 0.7,
                                                          width:
                                                          size * 0.7,
                                                        ),
                                                      ),

                                                      // ---------------- AGENCY FRAME (if agencyId > 0) ----------------
                                                      if (agencyId > 0)
                                                        SVGAEasyPlayer(
                                                          key: const ValueKey(
                                                            'video-host-agency-frame',
                                                          ),
                                                          assetsName:
                                                          'assets/svga/Frame/Agency frame.svga',
                                                          fit: BoxFit
                                                              .cover,
                                                        )
                                                      // ---------------- NORMAL FRAME (if no agency frame) --------------
                                                      else if (frameData !=
                                                          null &&
                                                          frameData['asset'] !=
                                                              null &&
                                                          frameData['asset']['asset'] !=
                                                              null)
                                                      // Check if the asset path ends with .svga
                                                        (frameData['asset']['asset']
                                                            .toString()
                                                            .endsWith(
                                                          '.svga',
                                                        ))
                                                            ? SizedBox(
                                                          height:
                                                          kHeight *
                                                              0.055,
                                                          width:
                                                          kHeight *
                                                              0.055,
                                                          child: SVGAEasyPlayer(
                                                            key:
                                                            ValueKey<
                                                                String
                                                            >(
                                                              'video-host-frame-${frameData['asset']['asset']}',
                                                            ),
                                                            resUrl:
                                                            '$kDomainUrl/${frameData['asset']['asset']}',
                                                            fit: BoxFit
                                                                .cover,
                                                          ),
                                                        )
                                                            : CachedNetworkImage(
                                                          imageUrl:
                                                          "$kDomainUrl/${frameData['asset']['asset']}",
                                                          height:
                                                          kHeight *
                                                              0.055,
                                                          width:
                                                          kHeight *
                                                              0.055,
                                                          fit: BoxFit
                                                              .cover,
                                                          placeholder:
                                                              (
                                                              context,
                                                              url,
                                                              ) => Container(
                                                            height:
                                                            kHeight *
                                                                0.12,
                                                            width:
                                                            kHeight *
                                                                0.12,
                                                            decoration: BoxDecoration(
                                                              color: kAppColor.withOpacity(
                                                                .02,
                                                              ),
                                                              borderRadius: BorderRadius.circular(
                                                                12,
                                                              ),
                                                            ),
                                                          ),
                                                          errorWidget:
                                                              (
                                                              context,
                                                              url,
                                                              error,
                                                              ) => Container(
                                                            height:
                                                            kHeight *
                                                                0.12,
                                                            width:
                                                            kHeight *
                                                                0.12,
                                                            decoration: BoxDecoration(
                                                              color: Colors.transparent,
                                                              borderRadius: BorderRadius.circular(
                                                                12,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons.broken_image,
                                                              size: 40,
                                                              color: kAppColor.withOpacity(
                                                                .2,
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      // ---------------- NOTHING (no frame) ----------------
                                                      else
                                                        SizedBox(
                                                          height:
                                                          kHeight *
                                                              0.03,
                                                          width:
                                                          kHeight *
                                                              0.03,
                                                        ),

                                                      if (_isUserMuted(
                                                        user['id'],
                                                      ))
                                                        Positioned(
                                                          right:
                                                          kHeight *
                                                              0.018,
                                                          bottom:
                                                          kHeight *
                                                              0.020,
                                                          child: _SmallMuteBadge(
                                                            fontSize:
                                                            kHeight *
                                                                0.007,
                                                            iconSize:
                                                            kHeight *
                                                                0.008,
                                                            compact: true,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // SizedBox(
                                      //   width: kWeight * 0.004,
                                      // ),
                                      // InkWell(
                                      //   onTap: () {
                                      //     final coming = true;
                                      //     if (coming) {
                                      //       Fluttertoast.showToast(
                                      //         msg: "Coming Soon!",
                                      //         toastLength:
                                      //         Toast.LENGTH_SHORT,
                                      //         // or LENGTH_LONG
                                      //         gravity: ToastGravity.BOTTOM,
                                      //         // where the toast will appear
                                      //         backgroundColor: kAppColor,
                                      //         textColor: Colors.white,
                                      //         fontSize: 16.0,
                                      //       );
                                      //     }
                                      //   },
                                      //   child: SizedBox(
                                      //     height: kHeight * 0.045,
                                      //     width: kHeight * 0.045,
                                      //     child: Stack(
                                      //       alignment: Alignment.center,
                                      //       children: [
                                      //         // ---------------- PROFILE IMAGE ----------------
                                      //         ClipRRect(
                                      //           borderRadius:
                                      //           BorderRadius.circular(
                                      //               100),
                                      //           child: Image.asset(
                                      //             'assets/flaticons/boy.png',
                                      //             height: kHeight * 0.03,
                                      //             width: kHeight * 0.03,
                                      //             fit: BoxFit.cover,
                                      //           ),
                                      //         ),
                                      //
                                      //         Image.asset(
                                      //           "assets/audio_live/gradian.png",
                                      //           height: kHeight * 0.06,
                                      //           width: kHeight * 0.06,
                                      //           fit: BoxFit.cover,
                                      //         ),
                                      //
                                      //         // ---------------- NOTHING (no frame) ----------------
                                      //       ],
                                      //     ),
                                      //   ),
                                      // ),
                                      SizedBox(width: kWeight * 0.004),
                                      // ==== Right viewers + close ==== (Flexible so it won’t overflow)
                                      Flexible(
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                          children: [
                                            SizedBox(
                                              width: Get.width * 0.22,
                                              height: Get.height * 0.04,
                                              child: Obx(() {
                                                // Filter list একবারেই বের করো
                                                final filteredList =
                                                livestreamController
                                                    .liveViewerList
                                                    .where(
                                                      (viewer) =>
                                                  _safeUserId(
                                                    viewer,
                                                  ) !=
                                                      _safeUserId(
                                                        broadcasterData,
                                                      ),
                                                )
                                                    .toList();

                                                if (filteredList
                                                    .isEmpty) {
                                                  return const SizedBox(); // কিছু না দেখানোর জন্য (empty state)
                                                }

                                                return ListView.builder(
                                                  scrollDirection:
                                                  Axis.horizontal,
                                                  itemCount:
                                                  filteredList.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final data =
                                                    filteredList[index];
                                                    return LiveProfile(
                                                      data: data,
                                                    );
                                                  },
                                                );
                                              }),
                                            ),
                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    /// *********** All Viewer List Bottom sheet ***********
                                                    final filteredList =
                                                    livestreamController
                                                        .liveViewerList
                                                        .where(
                                                          (viewer) =>
                                                      _safeUserId(
                                                        viewer,
                                                      ) !=
                                                          _safeUserId(
                                                            broadcasterData,
                                                          ),
                                                    )
                                                        .toList();

                                                    Get.bottomSheet(
                                                      LiveViewerList(
                                                        filteredList:
                                                        filteredList,
                                                      ),
                                                      isScrollControlled:
                                                      true,
                                                    );
                                                  },
                                                  child: Container(

                                                    child: ClipRRect(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        100,
                                                      ),
                                                      child: Container(
                                                        height:
                                                        Get.height *
                                                            0.035,
                                                        width:
                                                        Get.height *
                                                            0.035,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Color(
                                                                0xff040303,
                                                              ).withOpacity(.4),
                                                              Color(
                                                                0xff0e0e0e,
                                                              ).withOpacity(.4),
                                                            ],
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Obx(() {
                                                            final filteredCount = livestreamController
                                                                .liveViewerList
                                                                .where(
                                                                  (
                                                                  viewer,
                                                                  ) =>
                                                              _safeUserId(
                                                                viewer,
                                                              ) !=
                                                                  _safeUserId(
                                                                    broadcasterData,
                                                                  ),
                                                            )
                                                                .length;
                                                            return Text(
                                                              '$filteredCount+',
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                FontWeight.w500,
                                                              ),
                                                            );
                                                          }),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                (broadcasterData !=
                                                    null &&
                                                    widget
                                                        .isBroadcaster)
                                                    ? GestureDetector(
                                                  onTap: () async {
                                                    await _showVideoLiveCloseOptions();
                                                  },
                                                  child: Container(

                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                        20,
                                                      ),
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Color(
                                                            0xff031ecf,
                                                          ),
                                                          Color(
                                                            0xff091dd1,
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    height:
                                                    Get.height *
                                                        0.035,
                                                    width:
                                                    Get.height *
                                                        0.035,
                                                    child: Icon(
                                                      Icons
                                                          .close_rounded,
                                                      color: Colors
                                                          .white,
                                                      size:
                                                      Get.height *
                                                          0.02,
                                                    ),
                                                  ),
                                                )
                                                    : IconButton(
                                                  style: IconButton.styleFrom(
                                                    backgroundColor:
                                                    Colors
                                                        .grey[100],
                                                    padding:
                                                    EdgeInsets.all(
                                                      4,
                                                    ),
                                                    // ভিতরের space ছোট করা
                                                    minimumSize: Size(
                                                      28,
                                                      28,
                                                    ), // button এর overall size ছোট করা
                                                  ),
                                                  onPressed: () async {
                                                    if (mounted) {
                                                      await Navigator.of(
                                                        context,
                                                      ).maybePop();
                                                    }
                                                  },
                                                  icon: Icon(
                                                    Icons.close,
                                                    color:
                                                    kAppColor,
                                                    size:
                                                    18, // icon টার সাইজ ছোট
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: kWeight * 0.01,
                                                ),
                                              ],
                                            ),

                                            ///------------- viewer list show

                                            // Nothing will be shown if broadcasterData is null
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: kHeight * 0.006),

                                  ///---------- timer -------------
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 1.0,
                                      top: 5,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Get.to(
                                              Profileconribution(),
                                              transition:
                                              Transition.rightToLeft,
                                            );
                                          },
                                          child: Obx(() {
                                            return TaskLiveProfile(
                                              text: (() {
                                                final int coins =
                                                _safeCurrentGiftCoins();
                                                return _formatShortCoins(
                                                  coins,
                                                );
                                              })(),
                                              seccondtext: 'Receive: ',
                                            );
                                          }),
                                        ),
                                        _safeUserId(broadcasterData) ==
                                            authController
                                                .userProfile
                                                .value
                                                .user!
                                                .id
                                            ? Container(
                                          padding:
                                          EdgeInsets.symmetric(
                                            horizontal:
                                            kWeight * 0.03,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(
                                              15,
                                            ),
                                            gradient:
                                            LinearGradient(
                                              colors: [
                                                Color(
                                                  0xff0e0e0e,
                                                ).withOpacity(.4),
                                                Color(
                                                  0xff0e0e0e,
                                                ).withOpacity(.4),
                                              ],
                                            ),
                                          ),
                                          child: Obx(
                                                () => Castontext(
                                              fontSize:
                                              kHeight * 0.015,
                                              textColor:
                                              liveController
                                                  .isLive
                                                  .value
                                                  ? const Color(
                                                0xffffffff,
                                              ) // Live active = green
                                                  : const Color(
                                                0xff808080,
                                              ), // Inactive = gray
                                              text:
                                              liveController
                                                  .pkIsRunning
                                                  .value
                                                  ? liveController
                                                  .pkFormattedRemainingTime
                                                  : liveController
                                                  .formattedTime,
                                            ),
                                          ),
                                        )
                                            : const SizedBox.shrink(),
                                        GestureDetector(
                                          onTap: () {
                                            // Get.to(RankingView(),
                                            //     transition: Transition.rightToLeft);
                                          },
                                          child: Container(

                                            padding:
                                            EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(
                                                15,
                                              ),
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(
                                                    0xff0e0e0e,
                                                  ).withOpacity(.4),
                                                  Color(
                                                    0xff0e0e0e,
                                                  ).withOpacity(.4),
                                                ],
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize:
                                              MainAxisSize.min,
                                              children: [
                                                Text(
                                                  ('Current:').appTr,
                                                  style:
                                                  GoogleFonts.roboto(
                                                    color: Colors
                                                        .white,
                                                    fontWeight:
                                                    FontWeight
                                                        .w400,
                                                    fontSize:
                                                    kHeight *
                                                        0.012,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Obx(() {
                                                  final int coins =
                                                  _safeCurrentGiftCoins();
                                                  final String
                                                  displayText =
                                                  _formatShortCoins(
                                                    coins,
                                                  );

                                                  // 🔹 UI return
                                                  return Text(
                                                    displayText,
                                                    style: TextStyle(
                                                      color:
                                                      Colors.white,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                      fontSize:
                                                      kHeight *
                                                          0.014,
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ///----- noble part ----------
                                  // InkWell(
                                  //   onTap: () {},
                                  //   child: Container(
                                  //       width: kWeight * 0.25,
                                  //       margin: EdgeInsets.symmetric(
                                  //           vertical: 10, horizontal: 10),
                                  //       padding: EdgeInsets.symmetric(
                                  //           vertical: 3, horizontal: 8),
                                  //       decoration: BoxDecoration(
                                  //         borderRadius:
                                  //         BorderRadius.circular(30),
                                  //         gradient: LinearGradient(colors: [
                                  //           Color(0xff8c61e1),
                                  //           Color(0xff5815dc)
                                  //         ]),
                                  //       ),
                                  //       child: Row(
                                  //         children: [
                                  //           Image(
                                  //             image: AssetImage(
                                  //                 'assets/flaticons/crown.png'),
                                  //             height: kHeight * 0.03,
                                  //           ),
                                  //           Text(
                                  //             (' Noble').appTr,
                                  //             style: GoogleFonts.poppins(
                                  //                 fontWeight:
                                  //                 FontWeight.w600,
                                  //                 color: Colors.white,
                                  //                 fontSize:
                                  //                 kWeight * 0.029),
                                  //           ),
                                  //         ],
                                  //       )),
                                  // ),
                                ],
                              ),
                            ),

                            ///---------------- Call part ----------
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  right: 9,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: LiveCommentsSection(
                                        broadcasterData: broadcasterData,
                                        streamType: 'popular',
                                      ),
                                    ),

                                    //container  text end
                                    const SizedBox(width: 5),
                                    SizedBox(
                                      width: kWeight * 0.18,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: kHeight * 0.32,
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                right: kWeight * 0.03,
                                              ),
                                              child:
                                              _safeUserId(
                                                broadcasterData,
                                              ) ==
                                                  authController
                                                      .userProfile
                                                      .value
                                                      .user!
                                                      .id
                                                  ? Container()
                                                  : Align(
                                                alignment: Alignment
                                                    .bottomRight,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    final bool
                                                    pkRunningForAudienceCall =
                                                        liveController
                                                            .pkIsRunning
                                                            .value ||
                                                            liveController
                                                                .currentPkId
                                                                .value >
                                                                0;
                                                    if (pkRunningForAudienceCall &&
                                                        !widget
                                                            .isBroadcaster) {
                                                      Fluttertoast.showToast(
                                                        msg: ('PK is running. Call option is disabled during PK.')
                                                            .appTr,
                                                        toastLength:
                                                        Toast
                                                            .LENGTH_SHORT,
                                                        gravity:
                                                        ToastGravity
                                                            .BOTTOM,
                                                        backgroundColor:
                                                        Colors
                                                            .black87,
                                                        textColor:
                                                        Colors
                                                            .white,
                                                        fontSize:
                                                        13.0,
                                                      );
                                                      return;
                                                    }

                                                    websocketController
                                                        .tryToConnectToCallListWs();
                                                    if (livestreamController
                                                        .isBroadcaster
                                                        .value) {
                                                      // ✅ Broadcaster হলে BottomSheet
                                                    } else {
                                                      Get.bottomSheet(
                                                        SafeArea(
                                                          top:
                                                          false,
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: const BorderRadius.only(
                                                                topLeft: Radius.circular(
                                                                  32,
                                                                ),
                                                                topRight: Radius.circular(
                                                                  32,
                                                                ),
                                                              ),
                                                              color:
                                                              Colors.white,
                                                              border: Border.all(
                                                                color: const Color(
                                                                  0xFFE8E1E4,
                                                                ),
                                                              ),
                                                              boxShadow: const [
                                                                BoxShadow(
                                                                  color: Color(
                                                                    0x26000000,
                                                                  ),
                                                                  blurRadius: 18,
                                                                  offset: Offset(
                                                                    0,
                                                                    -4,
                                                                  ),
                                                                ),
                                                              ],
                                                              gradient: LinearGradient(
                                                                begin:
                                                                Alignment.topLeft,
                                                                end:
                                                                Alignment.bottomRight,
                                                                colors: [
                                                                  Colors.white,
                                                                  Colors.white,
                                                                ],
                                                              ),
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius: const BorderRadius.only(
                                                                topLeft: Radius.circular(
                                                                  32,
                                                                ),
                                                                topRight: Radius.circular(
                                                                  32,
                                                                ),
                                                              ),
                                                              child: BackdropFilter(
                                                                filter: ImageFilter.blur(
                                                                  sigmaX: 24,
                                                                  sigmaY: 24,
                                                                ),
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const SizedBox(
                                                                      height: 16,
                                                                    ),

                                                                    // Handle bar
                                                                    Container(
                                                                      width: 40,
                                                                      height: 4,
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.grey.shade300,
                                                                        borderRadius: BorderRadius.circular(
                                                                          2,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 20,
                                                                    ),

                                                                    // Premium badge
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal: 14,
                                                                        vertical: 5,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(
                                                                          0xFFFFF6F8,
                                                                        ),
                                                                        borderRadius: BorderRadius.circular(
                                                                          20,
                                                                        ),
                                                                        border: Border.all(
                                                                          color: const Color(
                                                                            0xFFF1DDE3,
                                                                          ),
                                                                          width: 1,
                                                                        ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.star_rounded,
                                                                            color: Color(
                                                                              0xFFFFD700,
                                                                            ),
                                                                            size: 13,
                                                                          ),
                                                                          const SizedBox(
                                                                            width: 5,
                                                                          ),
                                                                          Text(
                                                                            ("Premium Live Call").appTr,
                                                                            style: GoogleFonts.poppins(
                                                                              fontSize: 11,
                                                                              color: const Color(
                                                                                0xFF4B4045,
                                                                              ),
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 14,
                                                                    ),

                                                                    // Title
                                                                    Text(
                                                                      ("Join Live Stream").appTr,
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 16,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: const Color(
                                                                          0xFF241D20,
                                                                        ),
                                                                        letterSpacing: 0.3,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 4,
                                                                    ),

                                                                    // Subtitle
                                                                    Text(
                                                                      ("Choose your preferred call type").appTr,
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 12,
                                                                        color: const Color(
                                                                          0xFF746A6F,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 20,
                                                                    ),

                                                                    // Divider
                                                                    Divider(
                                                                      color: const Color(
                                                                        0xFFE8E1E4,
                                                                      ),
                                                                      thickness: 0.5,
                                                                      height: 1,
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 24,
                                                                    ),

                                                                    // Buttons
                                                                    Padding(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal: 20,
                                                                      ),
                                                                      child: Row(
                                                                        children: [
                                                                          // Video Call Button
                                                                          Expanded(
                                                                            child: _GlassCallButton(
                                                                              label: ("Video Call").appTr,
                                                                              icon: Icons.videocam_rounded,
                                                                              gradientColors: const [
                                                                                Color(
                                                                                  0xFFFF5F6D,
                                                                                ),
                                                                                Color(
                                                                                  0xFFFF8C42,
                                                                                ),
                                                                                Color(
                                                                                  0xFFFFC371,
                                                                                ),
                                                                              ],
                                                                              shadowColor: const Color(
                                                                                0xFFFF5F6D,
                                                                              ),
                                                                              onTap: () {
                                                                                final int safeTotalSeats = _safeInt(
                                                                                  broadcasterData['seat_count'] ??
                                                                                      streamInfo['seat_count'] ??
                                                                                      liveController.seatCount.value,
                                                                                  fallback:
                                                                                  liveController.seatCount.value >
                                                                                      0
                                                                                      ? liveController.seatCount.value
                                                                                      : 5,
                                                                                );

                                                                                livestreamController.tryToCallLivestream(
                                                                                  streamId: _safeStreamId(),
                                                                                  callerId: authController.userProfile.value.user!.id!.toInt(),
                                                                                  callType: 'video',
                                                                                  totalSeats: safeTotalSeats,
                                                                                );
                                                                                Get.back();
                                                                              },
                                                                            ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width: 12,
                                                                          ),

                                                                          // Voice Call Button
                                                                          Expanded(
                                                                            child: _GlassCallButton(
                                                                              label: ("Audio Call").appTr,
                                                                              icon: Icons.mic_rounded,
                                                                              gradientColors: const [
                                                                                Color(
                                                                                  0xFF667EEA,
                                                                                ),
                                                                                Color(
                                                                                  0xFF7F5FC5,
                                                                                ),
                                                                                Color(
                                                                                  0xFF764BA2,
                                                                                ),
                                                                              ],
                                                                              shadowColor: const Color(
                                                                                0xFF667EEA,
                                                                              ),
                                                                              onTap: () {
                                                                                final int safeTotalSeats = _safeInt(
                                                                                  broadcasterData['seat_count'] ??
                                                                                      streamInfo['seat_count'] ??
                                                                                      liveController.seatCount.value,
                                                                                  fallback:
                                                                                  liveController.seatCount.value >
                                                                                      0
                                                                                      ? liveController.seatCount.value
                                                                                      : 9,
                                                                                );

                                                                                livestreamController.tryToCallLivestream(
                                                                                  streamId: _safeStreamId(),
                                                                                  callerId: authController.userProfile.value.user!.id!.toInt(),
                                                                                  callType: 'audio',
                                                                                  totalSeats: safeTotalSeats,
                                                                                );
                                                                                Get.back();
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height:
                                                                      kHeight *
                                                                          0.05,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        backgroundColor:
                                                        Colors
                                                            .white,
                                                        isScrollControlled:
                                                        true,
                                                      );
                                                    }
                                                  },
                                                  child: LiveViewsecond_Image(
                                                    image:
                                                    'assets/flaticons/link (1).png',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: kHeight * 0.06),
                          ],
                        ),

                        //Pk
                        Obx(() {
                          if (!livestreamController.showPkView.value)
                            return const SizedBox();
                          return Positioned(
                            top: Get.height * 0.15,
                            left: 0,
                            right: 0,
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        // 🔵 Left side (Player A)
                                        Container(
                                          width: Get.width * 0.5,
                                          height: Get.height * 0.15,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            const BorderRadius.only(
                                              topLeft:
                                              Radius.circular(20),
                                            ),
                                            gradient:
                                            const LinearGradient(
                                              begin:
                                              Alignment.topLeft,
                                              end: Alignment
                                                  .bottomRight,
                                              colors: [
                                                Color(0xff2196F3),
                                                Color(0xff673AB7),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.25),
                                                blurRadius: 10,
                                                offset: const Offset(
                                                  0,
                                                  5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: Get.height * 0.04,
                                              ),
                                              // Player avatar
                                              Container(
                                                padding:
                                                const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 3,
                                                  ),
                                                  gradient:
                                                  const LinearGradient(
                                                    colors: [
                                                      Colors
                                                          .blueAccent,
                                                      Colors
                                                          .purpleAccent,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(
                                                        0.2,
                                                      ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                                    height:
                                                    Get.height * 0.05,
                                                    width:
                                                    Get.height * 0.05,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                ("Md Abdul").appTr,
                                                style:
                                                GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontSize:
                                                  Get.height *
                                                      0.014,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 🔴 Right side (Player B)
                                        Container(
                                          width: Get.width * 0.5,
                                          height: Get.height * 0.15,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            const BorderRadius.only(
                                              topRight:
                                              Radius.circular(20),
                                            ),
                                            gradient:
                                            const LinearGradient(
                                              begin:
                                              Alignment.topLeft,
                                              end: Alignment
                                                  .bottomRight,
                                              colors: [
                                                Color(0xffE91E63),
                                                Color(0xff6A1B9A),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.25),
                                                blurRadius: 10,
                                                offset: const Offset(
                                                  0,
                                                  5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: Get.height * 0.04,
                                              ),
                                              // Player avatar
                                              Container(
                                                padding:
                                                const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 3,
                                                  ),
                                                  gradient:
                                                  const LinearGradient(
                                                    colors: [
                                                      Colors
                                                          .blueAccent,
                                                      Colors
                                                          .purpleAccent,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(
                                                        0.2,
                                                      ),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl:
                                                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
                                                    height:
                                                    Get.height * 0.05,
                                                    width:
                                                    Get.height * 0.05,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                ("Md Abdul").appTr,
                                                style:
                                                GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontSize:
                                                  Get.height *
                                                      0.014,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedProgressBar(
                                      controller:
                                      animatedProgressBarController,
                                    ),
                                  ],
                                ),

                                // 🆚 VS text overlay
                                Positioned(
                                  top: 40,
                                  left: 215,
                                  right: 0,
                                  child: Text(
                                    ("VS").appTr,
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: Get.height * 0.08,
                                      color: Colors.white.withOpacity(
                                        0.3,
                                      ),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),

                                // 📊 Bottom bar

                                // ⏱ Timer + Exit
                                Positioned(
                                  top: 5,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(width: 40),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(30),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              ("PK ").appTr,
                                              style: GoogleFonts.poppins(
                                                color:
                                                Colors.yellowAccent,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "05:00",
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight:
                                                FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.exit_to_app,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          Get.defaultDialog(
                                            title: ("Exit").appTr,
                                            middleText:
                                            ("Are you sure you want to exit?")
                                                .appTr,
                                            textCancel: ("No").appTr,
                                            textConfirm: ("Yes").appTr,
                                            confirmTextColor:
                                            Colors.white,
                                            onConfirm: () {
                                              Get.back();
                                              livestreamController
                                                  .hidePk();
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        Obx(() {
                          if (!livestreamController.showPkView.value)
                            return const SizedBox();
                          return Positioned(
                            top: Get.height * 0.155,
                            left: 0,
                            right: 0,
                            child: towVsTowPk(
                              animatedProgressBarController:
                              animatedProgressBarController,
                              livestreamController: livestreamController,
                            ),
                          );
                        }),
                        Obx(() {
                          if (!livestreamController.showPkRoom.value)
                            return SizedBox();
                          return Positioned(
                            top: Get.height * 0.155,
                            left: 0,
                            right: 0,
                            child: CustomPartyRoom(
                              livestreamController: livestreamController,
                              animatedProgressBarController:
                              animatedProgressBarController,
                            ),
                          );
                        }),
                        Obx(() {
                          final newUser =
                              websocketController.newJoinedUserData;

                          if (websocketController
                              .newViewersJoinded
                              .value) {
                            final hasEntry =
                                newUser?['user']?['entry_histories']?['asset']?['asset'] !=
                                    null;

                            if (hasEntry) {
                              // ✅ SVGA আছে → onFinished callback দিয়ে hide হবে
                              return Positioned.fill(
                                child: EntryAnimation(
                                  data: newUser,
                                  // onFinished: () {
                                  //   websocketController.newViewersJoinded.value = false;
                                  // },
                                ),
                              );
                            }

                            // ✅ SVGA নেই → slide animation → 3s পরে hide
                            Future.delayed(
                              const Duration(seconds: 3),
                                  () {
                                if (websocketController
                                    .newViewersJoinded
                                    .value) {
                                  websocketController
                                      .newViewersJoinded
                                      .value =
                                  false;
                                }
                              },
                            );

                            return Positioned(
                              left: 12,
                              top: Get.height * 0.5,
                              child: SizedBox(
                                width: Get.width * 0.9,
                                // ✅ FIX: height was unset, leaving it
                                // unbounded (0 to Infinity) — EntryAnimation's
                                // internal Material/InkWell-based content
                                // tried to expand to fill that infinite
                                // space, which Flutter cannot lay out,
                                // causing a 'hasSize: is not true' crash.
                                height: Get.height * 0.15,
                                child: EntryAnimation(
                                  data: newUser,
                                  // onFinished: () {
                                  //   websocketController.newViewersJoinded.value = false;
                                  // },
                                ),
                              ),
                            );
                          }

                          return const SizedBox();
                        }),
                        Obx(
                              () => livestreamController.showMiniScene.value
                              ? Positioned(
                            top: 60,
                            right: 10,
                            child: AnimatedOpacity(
                              opacity:
                              livestreamController
                                  .showMiniScene
                                  .value
                                  ? 1
                                  : 0,
                              duration: const Duration(
                                milliseconds: 300,
                              ),
                              child: Container(
                                width: Get.width * 0.5,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    0.95,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      ("🎁 Mini Scene").appTr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ("This is a small overlay above live.")
                                          .appTr,
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: () {
                                        livestreamController
                                            .showMiniScene
                                            .value =
                                        false;
                                      },
                                      child: Text(("Close").appTr),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isUIVisible)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 60,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _handleDragUpdate,
                      onHorizontalDragEnd: _handleDragEnd,
                      onTap: () {
                        setState(() {
                          _uiOffset = 0;
                          _isUIVisible = true;
                        });
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),

                /// Lucky Bag / Red Packet overlay.
                /// Root Stack-e rakha, tai draggable video UI-r sathe move korbe na.
                /// AudioLiveView-er moto same shared overlay + same top-left position.
                RedPacketLiveOverlay(
                  key: ValueKey<String>(
                    'video-red-packet-${_safeStreamId()}',
                  ),
                  livestreamId: _safeStreamId(),
                ),

                /// Persistent full-screen gift layer.
                /// AudioLiveView-er layering-er moto red packet-er pore gift,
                /// tar pore rocket overlay thakbe.
                _PopularGiftOverlayHost(controller: websocketController),

                RocketLaunchOverlay(livestreamId: _safeStreamId()),

                ///------------- bottom part -------
                _agoraService.engine != null
                    ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kWeight * 0.0,
                    ),
                    child: Row(
                      children: [
                        // WriteCommentSection takes most of the space
                        Expanded(
                          child: WriteCommentSection(
                            rtcEngine: _agoraService.engine!,
                            streamType: 'popular',
                            broadcasterData: broadcasterData,
                            onVideoFilterTap:
                            widget.isBroadcaster ? _openLiveFilterSheet : null,
                            videoPkButton: widget.isBroadcaster
                                ? Obx(() => _buildBottomPkLauncher())
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : Container(
                  color: Colors
                      .transparent, // Optional: blank red bar if engine null
                  height: 60, // adjust height if needed
                ),
                _agoraService.engine == null
                    ? const Center(
                  child: CircularProgressIndicator(),
                ) // Show loading
                    : Container(),

                //Live view bottom part end
              ],
            ),
          ),
        ),

        // body parameter শেষ
      ),
    );
  }

  bool muted = false, videoDisabled = false, loudSpeaker = false;

}

class SpeakingWave extends StatefulWidget {
  final double size;

  const SpeakingWave({super.key, required this.size});

  @override
  State<SpeakingWave> createState() => _SpeakingWaveState();
}

class _SpeakingWaveState extends State<SpeakingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: .88,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(
      begin: .85,
      end: .25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              height: widget.size,
              width: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(_opacity.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(_opacity.value * .45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PkGridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = .55;

    const double gap = 18;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpeakingCardWave extends StatefulWidget {
  final double borderRadius;

  const SpeakingCardWave({super.key, required this.borderRadius});

  @override
  State<SpeakingCardWave> createState() => _SpeakingCardWaveState();
}

class _SpeakingCardWaveState extends State<SpeakingCardWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _spread;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..repeat(reverse: true);

    _spread = Tween<double>(
      begin: 1.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(
      begin: .70,
      end: .22,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: Colors.greenAccent.withOpacity(_opacity.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(_opacity.value * .55),
                  blurRadius: 18,
                  spreadRadius: _spread.value,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SmallMuteBadge extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final bool compact;

  const _SmallMuteBadge({
    required this.fontSize,
    required this.iconSize,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.65), width: .6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off, color: Colors.white, size: iconSize),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              ('Mute').appTr,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassCallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _GlassCallButton({
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: kHeight * 0.062,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glass shine overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kHeight * 0.031,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: kHeight * 0.016,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}