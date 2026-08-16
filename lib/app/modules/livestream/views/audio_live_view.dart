import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/modules/livestream/controllers/livestream_controller.dart';
import 'package:meetlivepro/app/modules/livestream/socket/websocket_controller.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/audience_join_controller.dart';
import 'package:meetlivepro/app/modules/livestream/widgets/audioText.dart';
import 'package:meetlivepro/app/modules/livestream/widgets/entry_animation.dart';
import 'package:meetlivepro/app/modules/livestream/widgets/luckyGiftoverlay.dart';
import 'package:meetlivepro/app/services/agora_service.dart';
import 'package:meetlivepro/constants/constants.dart';
import 'package:meetlivepro/widgets/after/CastomText.dart';
import 'package:meetlivepro/widgets/live_viewers_list.dart';
import 'package:meetlivepro/widgets/safe_network_image.dart';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/tasksLiveView.dart';
import '../../moments/controllers/moments_controller.dart';
import '../../ranking/views/allrank.dart';
import '../utils/audio_room_performance_layers.dart';
import '../utils/battery_optimizer.dart';
import '../utils/vip_privileges.dart';
import '../endLive/endLive.dart';

import '../widgets/GlobalLuckyBagBanner.dart';
import '../widgets/GlobalLuckyWinBanner.dart';
import '../widgets/LiveProfile_AppBar.dart';
import '../widgets/LiveView_Circle_Container.dart';
import '../widgets/live_room_setting_page.dart';
import '../widgets/speaking_wave.dart';

import '../widgets/RedPacketLiveOverlay.dart';

import '../widgets/audioRocketBottom.dart';
import '../widgets/rocket_launch_overlay.dart';
import '../widgets/audio_live_view_quickgift_card_refactor_fixed.dart';
import '../widgets/audio_room_right_image_slider.dart';

import '../widgets/gifts_animation.dart';
import '../widgets/live_imogi_animation_overlay.dart';
import '../widgets/musicplayerBottomSheet.dart';

import '../widgets/live_comments.dart';
import '../widgets/live_youtube_player_section.dart';
import '../widgets/roomsettingpage.dart';
import '../widgets/write_comments.dart';
import 'package:meetlivepro/app/modules/livestream/utils/live_performance_config.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class AudioLiveView extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;
  final int? seatCount;
  final String token;
  final int roomLayout;
  final int roomTheme;
  final int roomBackground;
  final Map<String, dynamic>? roomData;

  const AudioLiveView({
    super.key,
    required this.channelName,
    this.seatCount,
    required this.isBroadcaster,
    required this.token,
    this.roomLayout = 0,
    this.roomTheme = 0,
    this.roomBackground = -1,
    this.roomData,
  });

  @override
  State<AudioLiveView> createState() => _AudioLiveViewState();
}

class _SmoothMiniMusicDisc extends StatefulWidget {
  final double size;
  final bool playing;

  const _SmoothMiniMusicDisc({required this.size, required this.playing});

  @override
  State<_SmoothMiniMusicDisc> createState() => _SmoothMiniMusicDiscState();
}

class _SmoothMiniMusicDiscState extends State<_SmoothMiniMusicDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    if (widget.playing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _SmoothMiniMusicDisc oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.playing && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!widget.playing && _rotationController.isAnimating) {
      _rotationController.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(.40),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFFFF2D75).withOpacity(.30),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: widget.size,
              height: widget.size,
              padding: EdgeInsets.all(widget.size * .07),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFF090D19),
                    Color(0xFF30384D),
                    Color(0xFF111827),
                    Color(0xFF495066),
                    Color(0xFF090D19),
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(.24),
                    width: 1,
                  ),
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFF111827),
                      Color(0xFF252D43),
                      Color(0xFF0B1020),
                      Color(0xFF111827),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: widget.size * .43,
                    height: widget.size * .43,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFF7A00),
                          Color(0xFFFF2D75),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Colors.white,
                      size: widget.size * .25,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: widget.size * .10,
            height: widget.size * .10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B1020),
              border: Border.all(
                color: Colors.white.withOpacity(.55),
                width: .8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioSeatPoint {
  final double x;
  final double y;

  const _AudioSeatPoint(this.x, this.y);
}

/// Lucky/normal gift repaint island. Only the two gift observables are read
/// here, so a gift tick never rebuilds AudioLiveView's seats, comments, app bar,
/// Agora widgets or background.
class _AudioGiftOverlayHost extends StatelessWidget {
  const _AudioGiftOverlayHost({required this.controller});

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
              key: const ValueKey('persistent_live_gift_overlay'),
              giftData: data,
              isActive: active,
            ),
          );
        }),
      ),
    );
  }
}

class _AudioLiveViewState extends State<AudioLiveView>
    with WidgetsBindingObserver {
  LivestreamController liveController = Get.find();
  final WebsocketController websocketController =
  Get.isRegistered<WebsocketController>()
      ? Get.find<WebsocketController>()
      : Get.put<WebsocketController>(WebsocketController(), permanent: true);

  final AgoraService _agoraService = AgoraService();
  late final dynamic streamData;
  String? _currentToken;

  /// CP base image is now a fixed local asset.
  /// Ei asset sob device-e same CP connection place-e instantly show hobe.
  static const String _localCpBaseAsset = 'assets/flaticons/cpbase.png';

  /// CP base images/assets are pre-cached once per room/session so the image
  /// appears instantly on every realtime seat switch.
  final Set<String> _cpBaseImagePrecached = <String>{};

  bool _isLiveMinimized = false;
  bool _isLiveExiting = false;
  bool _backNavigationPending = false;

  /// Host normal back/exit hole live active thakbe.
  /// Dispose e offline/remove/end API call block korar jonno ei flag.
  bool _isHostLeavingRoomOnly = false;

  /// Agora channel join state.
  /// Important: when host leaves room UI but live stays active, we call
  /// leaveChannel(). In that case activeAudioStreamId may still be the same,
  /// but Agora is no longer joined. Without this flag the page can skip full
  /// join and mic/wave will stop working.
  bool _agoraChannelJoined = false;
  bool _audioJoinReady = false;
  Timer? _audioJoinLoadingFallbackTimer;

  /// Nijer entry nijer screen-e ek room-e ekbar show korar guard.
  /// Host create/open and viewer join duita flow-e duplicate entry prevent kore.
  int _selfEntryShownForStreamId = 0;

  /// Prevent overlapping prepare/join flows.
  bool _prepareForLiveRunning = false;
  bool _hostInitialAudioStateApplied = false;

  /// Prevent several heavy room-state APIs from running together when a user
  /// opens a live room. Join should feel instant; full snapshot can warm up
  /// safely after the first frame.
  bool _lateJoinStateSyncRunning = false;
  DateTime? _lastLateJoinStateSyncAt;

  bool _audienceLeaveRequested = false;

  /// Presence lifecycle state. Background/minimize hole offline call hobe na.
  bool _isAppInBackground = false;

  /// Prevent duplicate lifecycle callbacks from running two full room recovery
  /// flows at the same time and applying out-of-order snapshots.
  bool _resumeRecoveryRunning = false;

  /// WhatsApp/GSM/Google Meet can keep the Agora channel connected but release
  /// or replace Android's microphone recording device. These fields remember
  /// the interruption and run two small post-resume recovery passes.
  DateTime? _audioInterruptionStartedAt;
  Timer? _postResumeAudioRecoveryTimer;
  Timer? _postResumeAudioRecoveryConfirmTimer;

  /// Agora can report join success before Android fully re-attaches the local
  /// recording device after a leave/rejoin. Two short confirmation passes keep
  /// the real published microphone state equal to the UI/backend mute state.
  Timer? _postJoinMicRestoreTimer;
  Timer? _postJoinMicRestoreConfirmTimer;
  bool _audioInterruptionRecoveryRunning = false;

  ClientRoleType? _lastAppliedAgoraRole;
  bool _agoraRoleChangeRunning = false;

  /// Global Agora lifecycle guard for the singleton Agora engine.
  /// Multiple AudioLiveView instances can exist for a few frames during GetX
  /// navigation/minimize/reopen. Without a global session guard, old handlers
  /// still print old stream ids and re-publish mic for old rooms.
  static int _globalAgoraJoinSession = 0;
  static int _globalAgoraJoinedStreamId = 0;
  static bool _globalAgoraJoinRunning = false;
  static ClientRoleType? _globalLastAppliedAgoraRole;
  static DateTime? _globalLastRoleAppliedAt;
  static RtcEngineEventHandler? _globalAudioRtcHandler;

  int _localAgoraSessionId = 0;
  int _localAgoraStreamId = 0;
  DateTime? _lastMicPublishAt;

  Future<void> _applyAgoraRoleOnce(
      ClientRoleType role, {
        String source = 'unknown',
      }) async {
    final engine = _agoraService.engine;
    if (engine == null) return;

    final now = DateTime.now();
    final lastGlobalAt = _globalLastRoleAppliedAt;
    if (_lastAppliedAgoraRole == role && _globalLastAppliedAgoraRole == role)
      return;
    if (_globalLastAppliedAgoraRole == role &&
        lastGlobalAt != null &&
        now.difference(lastGlobalAt).inMilliseconds < 700) {
      liveLog('🛡️ Agora duplicate role skipped => $role source=$source');
      return;
    }
    if (_agoraRoleChangeRunning) return;

    _agoraRoleChangeRunning = true;

    try {
      await engine.setClientRole(role: role);
      _lastAppliedAgoraRole = role;
      _globalLastAppliedAgoraRole = role;
      _globalLastRoleAppliedAt = DateTime.now();
      liveLog('✅ Agora role applied once => $role source=$source');
    } catch (e) {
      liveLog('⚠️ Agora role change ignored => $e source=$source');
    } finally {
      _agoraRoleChangeRunning = false;
    }
  }

  bool _isActiveAgoraSession({
    required int sessionId,
    required int streamId,
    String source = 'callback',
  }) {
    if (!mounted || _isLiveExiting) return false;

    final int currentArgStreamId = _currentStreamIdFromArgs();
    final bool valid =
        streamId > 0 &&
            sessionId == _globalAgoraJoinSession &&
            sessionId == _localAgoraSessionId &&
            streamId == _localAgoraStreamId &&
            (currentArgStreamId <= 0 || currentArgStreamId == streamId);

    if (!valid) {
      liveLog(
        '⛔ Old Agora $source ignored => '
            'eventStream=$streamId local=$_localAgoraStreamId '
            'session=$sessionId global=$_globalAgoraJoinSession currentArg=$currentArgStreamId',
      );
    }

    return valid;
  }

  void _setGlobalAgoraJoinedStream(int streamId) {
    _globalAgoraJoinedStreamId = streamId > 0 ? streamId : 0;
    websocketController.activeAudioStreamId.value = _globalAgoraJoinedStreamId;
  }

  void _clearGlobalAgoraJoinedStream({int? streamId}) {
    if (streamId == null ||
        streamId <= 0 ||
        _globalAgoraJoinedStreamId == streamId) {
      _globalAgoraJoinedStreamId = 0;
      websocketController.activeAudioStreamId.value = 0;
    }
  }

  /// Agora speaking wave state.
  /// Backend chara Agora volume indication diye detect hobe ke kotha bolse.
  final Set<int> _speakingUserIds = <int>{};
  final Map<int, int> _speakingUntilMs = <int, int>{};
  Timer? _speakingExpiryTimer;
  static const int _speakingStartVolumeThreshold = 8;
  static const int _speakingStopVolumeThreshold = 4;
  static const int _speakingSilenceHoldMs = 1200;

  int _normalizeAgoraUid(int uid) {
    /// Agora local user-er jonno kichu case-e uid 0 aste pare.
    /// Tokhon current logged-in user id use korbo.
    if (uid == 0) {
      return authController.userProfile.value.user?.id?.toInt() ?? 0;
    }
    return uid;
  }

  bool _isUserSpeaking(dynamic userId) {
    final id = int.tryParse(userId?.toString() ?? '') ?? 0;
    return id != 0 && _speakingUserIds.contains(id);
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? fallback;
  }

  int _liveIdFromMap(Map map) {
    final nestedLive = map['livestream'];
    final nestedLiveData = map['livestreamdata'];
    final candidates = <dynamic>[
      map['livestream_id'],
      map['stream_id'],
      map['live_id'],
      map['id'],
      nestedLive is Map ? nestedLive['livestream_id'] : null,
      nestedLive is Map ? nestedLive['stream_id'] : null,
      nestedLive is Map ? nestedLive['id'] : null,
      nestedLiveData is Map ? nestedLiveData['livestream_id'] : null,
      nestedLiveData is Map ? nestedLiveData['stream_id'] : null,
      nestedLiveData is Map ? nestedLiveData['id'] : null,
    ];

    for (final value in candidates) {
      final id = _safeInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  bool _mapBelongsToCurrentStream(Map map) {
    final current = _currentStreamIdFromArgs();
    if (current <= 0) return true;

    final rowStream = _liveIdFromMap(map);
    return rowStream <= 0 || rowStream == current;
  }

  int _ownerUserIdFromLiveMap(Map map) {
    final user = _safeMap(map['user']);
    final host = _safeMap(map['host']);
    final owner = _safeMap(map['owner']);
    final livestream = _safeMap(map['livestream']);
    final livestreamData = _safeMap(map['livestreamdata']);
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
      user['id'],
      user['user_id'],
      host['id'],
      host['user_id'],
      owner['id'],
      owner['user_id'],
    ];

    for (final value in candidates) {
      final id = _safeInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  Map<String, dynamic> _ownerUserFromLiveMap(Map map) {
    for (final raw in [
      map['user'],
      map['host'],
      map['owner'],
      _safeMap(map['livestream'])['user'],
      _safeMap(map['livestream'])['host'],
      _safeMap(map['livestreamdata'])['user'],
      _safeMap(map['livestreamdata'])['host'],
    ]) {
      final user = _safeMap(raw);
      if (user.isNotEmpty && (user['id'] != null || user['name'] != null)) {
        return user;
      }
    }
    return <String, dynamic>{};
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'muted' ||
        text == 'locked';
  }

  bool _falsey(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value == false;
    if (value is num) return value.toInt() == 0;
    final text = value.toString().trim().toLowerCase();
    return text == '0' ||
        text == 'false' ||
        text == 'no' ||
        text == 'unmuted' ||
        text == 'unlocked';
  }

  bool? _muteStateFromAudioFields({dynamic audioOn, dynamic mutedRaw}) {
    /// mutedRaw true/1/muted = muted. mutedRaw false/0/unmuted = unmuted.
    /// Explicit mute state wins over stale audio_on from backend snapshots.
    if (mutedRaw != null) {
      if (_truthy(mutedRaw)) return true;
      if (_falsey(mutedRaw)) return false;
    }

    if (audioOn != null) {
      if (_falsey(audioOn)) return true;
      if (_truthy(audioOn)) return false;
    }

    return null;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  num _safeNum(dynamic value, {num fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value;
    if (value is bool) return value ? 1 : 0;

    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;

    return num.tryParse(text) ?? fallback;
  }

  /// Game icon show rule:
  /// broadcaster/host user coins > 0 hole show hobe,
  /// coins 0/null/empty hole hide thakbe.
  final coinValue =
      num.tryParse(
        authController.userProfile.value.user?.levelCoins?.toString() ?? '0',
      ) ??
          0;

  String _safeLower(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  /// Profile frame UI te Entry Care asset show kora jabe na.
  /// Entry Care sudhu entry animation er jonno.
  /// Profile frame/Avatar frame thakle sudhu tokhon profile frame show hobe.
  Map<String, dynamic> _frameMap(dynamic value) {
    if (value == null) return <String, dynamic>{};

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text.toLowerCase() == 'null')
        return <String, dynamic>{};
      return <String, dynamic>{'asset': text, 'asset_type': 'profile_frame'};
    }

    if (value is List) {
      Map<String, dynamic> firstUsable = <String, dynamic>{};
      for (final item in value) {
        final itemMap = _frameMap(item);
        if (itemMap.isEmpty || !_frameMapHasUsableAsset(itemMap)) continue;
        firstUsable = itemMap;
        final status = _safeLower(
          itemMap['status'] ??
              itemMap['purchase_status'] ??
              itemMap['is_active'],
        );
        if (_truthy(itemMap['is_active']) ||
            status == 'active' ||
            status == 'using' ||
            status == 'selected') {
          return itemMap;
        }
      }
      return firstUsable;
    }

    final map = _safeMap(value);
    if (map.isEmpty) return <String, dynamic>{};

    for (final key in const [
      'profile_frame',
      'profileFrame',
      'profile_frame_data',
      'profileFrameData',
      'profile_frame_history',
      'active_profile_frame',
      'activeProfileFrame',
      'active_frame',
      'activeFrame',
      'selected_frame',
      'selectedFrame',
      'current_frame',
      'currentFrame',
      'avatar_frame',
      'avatarFrame',
      'avatar_frame_history',
      'avatarFrameHistory',
      'frame_data',
      'frameData',
      'user_frame',
      'userFrame',
      'asset_purchase_history',
      'asset_purchase_histories',
      'asset_purchase_history2',
    ]) {
      if (map[key] != null) {
        final nested = _frameMap(map[key]);
        if (nested.isNotEmpty && _frameMapHasUsableAsset(nested)) return nested;
      }
    }

    return map;
  }

  bool _frameMapHasUsableAsset(Map<String, dynamic> frameData) {
    if (frameData.isEmpty) return false;
    final asset = _safeMap(frameData['asset']);
    final assetPath =
        (asset['asset'] ??
            asset['asset_path'] ??
            asset['image'] ??
            asset['image_url'] ??
            asset['frame_image'] ??
            asset['frame_url'] ??
            asset['profile_frame_image'] ??
            asset['profile_frame_url'] ??
            asset['avatar_frame_image'] ??
            asset['avatar_frame_url'] ??
            asset['file'] ??
            asset['file_url'] ??
            asset['url'] ??
            asset['full_url'] ??
            asset['path'] ??
            frameData['asset_path'] ??
            frameData['asset'] ??
            frameData['image'] ??
            frameData['image_url'] ??
            frameData['frame_image'] ??
            frameData['frame_url'] ??
            frameData['profile_frame_image'] ??
            frameData['profile_frame_url'] ??
            frameData['avatar_frame_image'] ??
            frameData['avatar_frame_url'] ??
            frameData['file'] ??
            frameData['file_url'] ??
            frameData['url'] ??
            frameData['full_url'] ??
            frameData['path'] ??
            frameData['svga'])
            ?.toString()
            .trim() ??
            '';

    return assetPath.isNotEmpty && assetPath.toLowerCase() != 'null';
  }

  bool _isProfileFrameAsset(dynamic history) {
    final frameData = _frameMap(history);
    if (!_frameMapHasUsableAsset(frameData)) return false;

    final asset = _safeMap(frameData['asset']);
    final assetType = _safeLower(asset['type'] ?? frameData['asset_type']);
    final historyType = _safeLower(
      frameData['type'] ?? frameData['history_type'],
    );
    final assetName = _safeLower(asset['name'] ?? frameData['name']);

    if (assetType == 'entry care' ||
        historyType == 'entry care' ||
        assetType.contains('entry') ||
        historyType.contains('entry') ||
        assetName.contains('entry')) {
      return false;
    }

    return true;
  }

  String _profileFrameAssetPath(dynamic history) {
    final frameData = _frameMap(history);
    final asset = _safeMap(frameData['asset']);
    return (asset['asset'] ??
        asset['image'] ??
        asset['file'] ??
        asset['url'] ??
        frameData['asset_path'] ??
        frameData['asset'] ??
        frameData['image'] ??
        frameData['file'] ??
        frameData['url'] ??
        frameData['path'])
        ?.toString()
        .trim() ??
        '';
  }

  dynamic _firstProfileFrameFromUser(Map<String, dynamic> user) {
    final candidates = <dynamic>[
      user['profile_frame_history'],
      user['asset_purchase_history'],
      user['asset_purchase_histories'],
      user['asset_purchase_history2'],
      user['profile_frame_data'],
      user['profileFrameData'],
      user['active_profile_frame'],
      user['activeProfileFrame'],
      user['active_frame'],
      user['activeFrame'],
      user['selected_frame'],
      user['selectedFrame'],
      user['current_frame'],
      user['currentFrame'],
      user['avatar_frame'],
      user['avatarFrame'],
      user['avatar_frame_history'],
      user['avatarFrameHistory'],
      user['profile_frame'],
      user['profileFrame'],
      user['profile_frame_url'],
      user['profile_frame_image'],
      user['frame'],
      user['frame_data'],
      user['frameData'],
      user['frame_url'],
      user['frame_image'],
    ];

    for (final candidate in candidates) {
      if (_isProfileFrameAsset(candidate)) return candidate;
    }

    return null;
  }

  Map<String, dynamic> _mergeVisualFieldsIntoUser(
      Map<String, dynamic> root,
      Map<String, dynamic> user,
      ) {
    final merged = Map<String, dynamic>.from(user);

    for (final key in const [
      'asset_purchase_histories',
      'assetPurchaseHistories',
      'asset_purchase_history',
      'assetPurchaseHistory',
      'asset_purchase_history2',
      'entry_histories',
      'entryHistories',
      'entry_history',
      'entryHistory',
      'active_entry',
      'activeEntry',
      'selected_entry',
      'selectedEntry',
      'entry_care',
      'entryCare',
      'profile_frame_history',
      'profileFrameHistory',
      'profile_frame_data',
      'profileFrameData',
      'active_profile_frame',
      'activeProfileFrame',
      'selected_frame',
      'selectedFrame',
      'current_frame',
      'currentFrame',
      'active_frame',
      'activeFrame',
      'avatar_frame',
      'avatarFrame',
      'avatar_frame_history',
      'avatarFrameHistory',
      'profile_frame',
      'profileFrame',
      'profile_frame_url',
      'profile_frame_image',
      'frame',
      'frame_data',
      'frameData',
      'frame_url',
      'frame_image',
    ]) {
      final value = root[key];
      if (value == null ||
          value.toString().trim().isEmpty ||
          value.toString() == 'null') {
        continue;
      }

      final current = merged[key];
      if (current == null ||
          current.toString().trim().isEmpty ||
          current.toString() == 'null') {
        merged[key] = value;
      }
    }

    return merged;
  }

  void _mergeNonEmptyUserMap(
      Map<String, dynamic> target,
      Map<String, dynamic> source,
      ) {
    if (source.isEmpty) return;
    source.forEach((key, value) {
      if (value == null ||
          value.toString().trim().isEmpty ||
          value.toString() == 'null') {
        return;
      }

      final current = target[key];
      if (current == null ||
          current.toString().trim().isEmpty ||
          current.toString() == 'null') {
        target[key] = value;
      }
    });
  }

  Map<String, dynamic> _hostVisualUserMap() {
    final int hostId = _hostUserIdFromSnapshot();
    final merged = <String, dynamic>{};

    void addUser(dynamic rawUser, {Map<String, dynamic>? root}) {
      final user = _safeMap(rawUser);
      if (user.isEmpty) return;
      final normalized = root == null
          ? user
          : _mergeVisualFieldsIntoUser(root, user);
      final uid = _safeInt(normalized['id'] ?? normalized['user_id']);
      if (hostId > 0 && uid > 0 && uid != hostId) return;
      _mergeNonEmptyUserMap(merged, normalized);
    }

    final broadcaster = _safeMap(broadcasterData);
    final stream = _safeMap(streamInfo);
    final streamArg = _safeMap(streamData);
    final liveData = _safeMap(streamData?['livestreamdata']);
    final live = _safeMap(streamData?['livestream']);

    addUser(broadcaster['user'], root: broadcaster);
    addUser(broadcaster['host'], root: broadcaster);
    addUser(stream['user'], root: stream);
    addUser(stream['host'], root: stream);
    addUser(liveData['user'], root: liveData);
    addUser(liveData['host'], root: liveData);
    addUser(live['user'], root: live);
    addUser(live['host'], root: live);
    addUser(streamArg['user'], root: streamArg);
    addUser(streamArg['host'], root: streamArg);

    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final user = row['user'] is Map
            ? Map<String, dynamic>.from(row['user'])
            : row['caller'] is Map
            ? Map<String, dynamic>.from(row['caller'])
            : <String, dynamic>{};
        addUser(user, root: row);
      }
    } catch (_) {}

    final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (hostId > 0 && myId == hostId) {
      final dynamic authUser = authController.userProfile.value.user;
      try {
        final dynamic json = (authUser as dynamic).toJson();
        if (json is Map) addUser(Map<String, dynamic>.from(json));
      } catch (_) {}
    }

    return merged;
  }

  bool _mapSaysMuted(Map<String, dynamic> map) {
    if (map.isEmpty) return false;

    if (_truthy(map['host_is_muted']) ||
        _truthy(map['is_muted']) ||
        _truthy(map['is_muted_by_host']) ||
        _truthy(map['muted'])) {
      return true;
    }

    if (map.containsKey('host_audio_on') && _falsey(map['host_audio_on'])) {
      return true;
    }

    if (map.containsKey('audio_on') && _falsey(map['audio_on'])) {
      return true;
    }

    if (map.containsKey('is_audio_on') && _falsey(map['is_audio_on'])) {
      return true;
    }

    return false;
  }

  int _hostUserIdFromSnapshot() {
    // Host id must come from the current live owner fields only.
    // Do not use broadcasterData.caller_id because audience mode used to seed
    // broadcasterData from the first seated caller, which made callers show Host.
    for (final source in [
      _safeMap(streamInfo),
      _safeMap(streamData),
      _safeMap(streamData?['livestream']),
      _safeMap(streamData?['livestreamdata']),
      _safeMap(broadcasterData),
    ]) {
      final id = _ownerUserIdFromLiveMap(source);
      if (id > 0) return id;
    }

    return 0;
  }

  bool get _isCurrentUserLiveOwner {
    final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (myId <= 0) return false;

    final int hostId = _hostUserIdFromSnapshot();
    return hostId > 0 && hostId == myId;
  }

  /// Widget argument can be stale when user leaves own live and opens another live.
  /// So broadcaster/host permission is trusted only when current room owner id matches me.
  bool get _effectiveBroadcaster =>
      widget.isBroadcaster && _isCurrentUserLiveOwner;

  /// Current room management: owner or this-room admin/guardian only.
  bool get _canManageCurrentRoom {
    if (_effectiveBroadcaster) return true;
    try {
      final dynamic live = liveController;
      if (live.canModerateLive == true) return true;
    } catch (_) {}
    return false;
  }

  bool _trustedSnapshotSaysHostMuted(int userId) {
    final hostId = _hostUserIdFromSnapshot();
    if (hostId <= 0 || hostId != userId) return false;

    final snapshots = <Map<String, dynamic>>[
      _safeMap(streamInfo),
      _safeMap(streamInfo['livestream']),
      _safeMap(streamData),
      _safeMap(streamData?['livestream']),
      _safeMap(streamData?['livestreamdata']),
      _safeMap(broadcasterData),
    ];

    for (final map in snapshots) {
      if (_mapSaysMuted(map)) return true;

      final callers = map['livestream_callers'];
      if (callers is List) {
        for (final rawCaller in callers) {
          final caller = _safeMap(rawCaller);
          final callerId = _safeInt(
            caller['caller_id'] ?? caller['user_id'] ?? caller['user']?['id'],
          );
          final isBroadcaster = _truthy(caller['is_broadcaster']);
          if (callerId == userId || isBroadcaster) {
            if (_mapSaysMuted(caller)) return true;
          }
        }
      }
    }

    return false;
  }

  bool _isUserMuted(dynamic userId) {
    final id = int.tryParse(userId?.toString() ?? '') ?? 0;
    if (id == 0) return false;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    /// ✅ Real-time/local state must win over old snapshots.
    /// Room edit/background/music payload can contain stale caller.audio_on/is_muted.
    /// If we check those snapshots first, the mic-off icon stays forever even after
    /// backend + websocket say unmuted.
    if (id == currentUserId) {
      return liveController.mute.value == true;
    }

    if (websocketController.audioMutedUserMap.containsKey(id)) {
      return websocketController.audioMutedUserMap[id] == true;
    }

    /// Seat/call list theke current accepted caller mute state check.
    final index = websocketController.liveCallList.indexWhere((call) {
      if (call is! Map) return false;
      final callerId = call['caller_id'];
      final uid = call['user']?['id'] ?? callerId;
      return uid.toString() == id.toString();
    });

    if (index != -1) {
      final call = Map<String, dynamic>.from(
        websocketController.liveCallList[index],
      );
      return _mapSaysMuted(call);
    }

    /// Fallback only: snapshot use korbo only jokhon realtime/local state nai.
    return _trustedSnapshotSaysHostMuted(id);
  }

  String _formatCoins(dynamic raw) {
    final coins = _safeInt(raw);
    if (coins >= 1000000) {
      final value = coins / 1000000;
      return value % 1 == 0
          ? '${value.toInt()}M'
          : '${value.toStringAsFixed(1)}M';
    }
    if (coins >= 1000) {
      final value = coins / 1000;
      return value % 1 == 0
          ? '${value.toInt()}k'
          : '${value.toStringAsFixed(1)}k';
    }
    return coins.toString();
  }

  int _coinFromMap(Map<String, dynamic> map) {
    final keys = [
      'total_gift_coins',
      'received_coins',
      'stream_coins',
      'gifts_coins',
      'gift_amount',
      'total_coins',
    ];

    for (final key in keys) {
      if (map.containsKey(key)) {
        final value = _safeInt(map[key]);
        if (value > 0) return value;
      }
    }

    final nestedLive = _safeMap(
      map['livestream'] ?? map['livestreamdata'] ?? map['data'],
    );
    if (nestedLive.isNotEmpty) {
      final nestedValue = _coinFromMap(nestedLive);
      if (nestedValue > 0) return nestedValue;
    }

    return 0;
  }

  int _currentRoomReceivedCoins() {
    /// Controller live total is the best source after addViewer/live-list sync.
    final controllerCoins = _safeInt(liveController.totalGiftCoins.value);
    if (controllerCoins > 0) return controllerCoins;

    for (final map in [
      _safeMap(streamInfo),
      _safeMap(streamData),
      _safeMap(streamData?['livestreamdata']),
      _safeMap(broadcasterData),
    ]) {
      final value = _coinFromMap(map);
      if (value > 0) return value;
    }

    if (websocketController.liveCallList.isNotEmpty) {
      final firstCall = _safeMap(websocketController.liveCallList.first);
      final value = _safeInt(firstCall['earn_coins']);
      if (value > 0) return value;
    }

    return 0;
  }

  int _coinFromUserMap(Map<String, dynamic> user) {
    final keys = [
      'earnedCoins',
      'earned_coins',
      'earnCoin',
      'earn_coins',
      'received_coins',
      'receive_coins',
      'gifts_coins',
    ];
    for (final key in keys) {
      if (user.containsKey(key)) {
        final value = _safeInt(user[key]);
        if (value > 0) return value;
      }
    }
    return 0;
  }

  int _hostReceiveCoins() {
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    final hostId = _hostUserIdFromSnapshot();

    final hostMaps = <Map<String, dynamic>>[
      _safeMap(broadcasterData['user']),
      _safeMap(broadcasterData['host']),
      _safeMap(streamInfo['user']),
      _safeMap(streamInfo['host']),
      _safeMap(streamInfo['livestream']?['user']),
      _safeMap(streamData?['user']),
      _safeMap(streamData?['host']),
      _safeMap(streamData?['livestreamdata']?['user']),
    ];

    for (final call in websocketController.liveCallList) {
      final map = _safeMap(call);
      final user = _safeMap(map['user']);
      final uid = _safeInt(map['caller_id'] ?? map['user_id'] ?? user['id']);
      final isBroadcaster = _truthy(map['is_broadcaster']);
      if (isBroadcaster || (hostId > 0 && uid == hostId)) {
        hostMaps.add(user);
        hostMaps.add(map);
      }
    }

    for (final user in hostMaps) {
      final value = _coinFromUserMap(user);
      if (value > 0) return value;
    }

    /// Host nijer profile dekhar somoy profile earned coin fallback.
    /// IMPORTANT: User model-er sob project-e same getter thake na.
    /// Tai direct profileUser?.earnCoin / giftsCoins use korle compile error hoy.
    /// Dynamic safe reader use korchi, jate current model break na hoy.
    if (hostId <= 0 || hostId == currentUserId) {
      final dynamic profileUser = authController.userProfile.value.user;
      final value = _safeInt(
        _readUserCoinField(profileUser, const [
          'earnedCoins',
          'earned_coins',
          'earnCoin',
          'earn_coin',
          'earn_coins',
          'giftsCoins',
          'gifts_coins',
          'received_coins',
          'receive_coins',
        ]),
      );
      if (value > 0) return value;
    }

    return 0;
  }

  dynamic _readUserCoinField(dynamic user, List<String> keys) {
    if (user == null) return null;

    if (user is Map) {
      for (final key in keys) {
        if (user.containsKey(key) && user[key] != null) return user[key];
      }
    }

    try {
      final dynamic json = user.toJson();
      if (json is Map) {
        for (final key in keys) {
          if (json.containsKey(key) && json[key] != null) return json[key];
        }
      }
    } catch (_) {}

    for (final key in keys) {
      try {
        switch (key) {
          case 'earnedCoins':
            return (user as dynamic).earnedCoins;
          case 'earned_coins':
            return (user as dynamic).earned_coins;
          case 'earnCoin':
            return (user as dynamic).earnCoin;
          case 'earn_coin':
            return (user as dynamic).earn_coin;
          case 'earn_coins':
            return (user as dynamic).earn_coins;
          case 'giftsCoins':
            return (user as dynamic).giftsCoins;
          case 'gifts_coins':
            return (user as dynamic).gifts_coins;
          case 'received_coins':
            return (user as dynamic).received_coins;
          case 'receive_coins':
            return (user as dynamic).receive_coins;
        }
      } catch (_) {}
    }

    return null;
  }

  void _setSpeakingStatus({required int uid, required bool isSpeaking}) {
    final userId = _normalizeAgoraUid(uid);
    if (userId == 0) return;

    final bool alreadySpeaking = _speakingUserIds.contains(userId);

    /// Muted user kotha bolleo wave show korbe na.
    if (isSpeaking && _isUserMuted(userId)) {
      isSpeaking = false;
    }

    if (isSpeaking) {
      _speakingUntilMs[userId] =
          DateTime.now().millisecondsSinceEpoch + _speakingSilenceHoldMs;
      _ensureSpeakingExpiryTimer();

      if (!alreadySpeaking) {
        _speakingUserIds.add(userId);
        _updateLiveCallSpeakingStatus(userId: userId, isSpeaking: true);
      }
    } else {
      _speakingUntilMs.remove(userId);

      if (alreadySpeaking) {
        _speakingUserIds.remove(userId);
        _updateLiveCallSpeakingStatus(userId: userId, isSpeaking: false);
      }
    }
  }

  /// Fast-on/slow-off speaking detection for Agora's 600 ms volume samples.
  /// A meaningful first sample starts immediately. Once active, lower voice
  /// energy keeps the wave alive and silence is handled by the single shared
  /// expiry timer instead of toggling false on every quiet callback.
  void _handleSpeakingVolumeSample({required int uid, required int volume}) {
    final int userId = _normalizeAgoraUid(uid);
    if (userId == 0) return;
    // Audience members are presence-only. Keep VAD state bounded to accepted
    // publishers represented by the canonical caller/seat collection.
    if (websocketController.canonicalSeatForUser(userId) <= 0) return;

    final bool alreadySpeaking = _speakingUserIds.contains(userId);
    final int threshold = alreadySpeaking
        ? _speakingStopVolumeThreshold
        : _speakingStartVolumeThreshold;

    if (volume >= threshold) {
      _setSpeakingStatus(uid: userId, isSpeaking: true);
    }
    // A quiet sample intentionally does not force false. The existing single
    // expiry timer stops the wave only after sustained silence.
  }

  void _ensureSpeakingExpiryTimer() {
    if (_speakingExpiryTimer?.isActive == true) return;
    _speakingExpiryTimer = Timer.periodic(const Duration(milliseconds: 250), (
        timer,
        ) {
      if (!mounted || _speakingUntilMs.isEmpty) {
        timer.cancel();
        _speakingExpiryTimer = null;
        return;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final expired = _speakingUntilMs.entries
          .where((entry) => entry.value <= nowMs)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final userId in expired) {
        _setSpeakingStatus(uid: userId, isSpeaking: false);
      }
    });
  }

  void _updateLiveCallSpeakingStatus({
    required int userId,
    required bool isSpeaking,
  }) {
    websocketController.setSpeakingUser(userId, isSpeaking);
    final index = websocketController.liveCallList.indexWhere((call) {
      final callerId = call['caller_id'];
      final uid = call['user']?['id'] ?? callerId;
      return uid.toString() == userId.toString();
    });

    if (index != -1) {
      // Preserve the flag in room snapshots, but the per-user Rx map above
      // updates only the affected seat instead of refreshing the entire list.
      websocketController.liveCallList[index]['is_speaking'] = isSpeaking;
    }
  }

  int get _currentLiveStreamId {
    final value =
        streamInfo['id'] ??
            streamData?['livestreamdata']?['id'] ??
            streamData?['livestream_id'] ??
            streamData?['id'];
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  bool get _hasLiveRoomRealtimeUpdate {
    final id = _currentLiveStreamId;
    if (id == 0 || websocketController.liveRoomUpdateStreamId.value != id) {
      return false;
    }

    /*
    |--------------------------------------------------------------------------
    | Ignore freshly-cleared room edit cache
    |--------------------------------------------------------------------------
    | resetAudioRoomStateForStream() clears the websocket room cache when moving
    | from room A to room B. During that small window liveRoomUpdateStreamId is
    | already the new stream id, but the values are still empty/default
    | (seat=0, background=-1, title=''). If AudioLiveView trusts that empty cache,
    | the real room_background from Get.arguments is ignored and the UI falls back
    | to theme/gradient instead of the selected background image.
    |--------------------------------------------------------------------------
    */
    return websocketController.liveRoomSeatCount.value > 0 ||
        websocketController.liveRoomBackground.value != -1 ||
        websocketController.liveRoomTitle.value.trim().isNotEmpty ||
        websocketController.liveRoomAnnouncement.value.trim().isNotEmpty ||
        websocketController.liveRoomStreamImage.value.trim().isNotEmpty ||
        websocketController.liveRoomPassword.value.trim().isNotEmpty;
  }

  int get _roomLayoutFromOwnData {
    final value =
        streamInfo['room_layout'] ??
            broadcasterData['room_layout'] ??
            streamData?['livestreamdata']?['room_layout'] ??
            streamData?['room_layout'] ??
            widget.roomLayout;
    return int.tryParse(value.toString()) ?? widget.roomLayout;
  }

  int get _roomThemeFromOwnData {
    final value =
        streamInfo['room_theme'] ??
            broadcasterData['room_theme'] ??
            streamData?['livestreamdata']?['room_theme'] ??
            streamData?['room_theme'] ??
            widget.roomTheme;
    return int.tryParse(value.toString()) ?? widget.roomTheme;
  }

  int get _roomBackgroundFromOwnData {
    final value =
        streamInfo['room_background'] ??
            broadcasterData['room_background'] ??
            streamData?['livestreamdata']?['room_background'] ??
            streamData?['room_background'] ??
            widget.roomBackground;
    return int.tryParse(value.toString()) ?? widget.roomBackground;
  }

  int get liveRoomLayout {
    if (_hasLiveRoomRealtimeUpdate) {
      return websocketController.liveRoomLayout.value;
    }

    return _roomLayoutFromOwnData;
  }

  int get liveRoomTheme {
    if (_hasLiveRoomRealtimeUpdate) {
      return websocketController.liveRoomTheme.value;
    }

    return _roomThemeFromOwnData;
  }

  int get liveRoomBackground {
    if (_hasLiveRoomRealtimeUpdate) {
      return websocketController.liveRoomBackground.value;
    }

    return _roomBackgroundFromOwnData;
  }

  final streamInfo = {}.obs;
  final broadcasterData = {}.obs;

  OverlayEntry? _miniLiveOverlay;
  Offset _miniBubbleOffset = Offset.zero;
  bool _miniBubbleDragging = false;
  bool _seatLockSyncScheduled = false;

  Offset _musicPanelOffset = Offset.zero;
  bool _musicPanelDragging = false;
  bool _musicPanelExpanded = false;
  final ValueNotifier<Offset> _musicMiniOffset =
  ValueNotifier<Offset>(Offset.zero);
  bool _musicMiniDragging = false;

  YoutubePlayerController? _youtubeController;
  String _loadedYoutubeVideoId = '';
  String _lastYoutubeStatus = 'stopped';

  final addComments = TextEditingController();

  // Battery Optimization Variables
  final BatteryOptimizer _batteryOptimizer = BatteryOptimizer();
  PerformanceLevel _currentPerformanceLevel = PerformanceLevel.high;
  Timer? _batteryCheckTimer;
  Timer? _uiUpdateTimer;

  /// Safety realtime sync: jodi viewer_joined websocket late/miss hoy,
  /// host/viewer list backend live state theke abar force sync hobe.
  Timer? _viewerSafetySyncTimer;
  int _viewerSafetySyncTick = 0;

  /// Same default theme gradients as GotoAudioLiveView.
  final List<List<Color>> themeGradients = const [
    [Color(0xff7BB9E9), Color(0xff6B72CF), Color(0xff5B2AB5)],
    [Color(0xfff6eee6), Color(0xffd7b98d), Color(0xff7b4a1d)],
    [Color(0xff6b203c), Color(0xff973d8f), Color(0xff2b124c)],
    [Color(0xffa8f5d0), Color(0xff55b97b), Color(0xff135c44)],
  ];

  bool _isSupportedAudioSeatCount(int count) {
    return count == 9 || count == 12 || count == 15 || count == 20;
  }

  int _normalizeAudioSeatCount(dynamic value, {int fallback = 9}) {
    final parsed = _safeInt(value, fallback: 0);
    if (_isSupportedAudioSeatCount(parsed)) return parsed;

    final safeFallback = _safeInt(fallback, fallback: 9);
    if (_isSupportedAudioSeatCount(safeFallback)) return safeFallback;

    /// Audio seat renderer has positions only for 9/12/15/20.
    /// Banner Lucky Bag payload can miss room data and widget.seatCount becomes
    /// 6. If we keep 6, _seatPositions returns empty and all seats disappear.
    return 9;
  }

  int get _roomSeatCountFromOwnData {
    final value =
        streamInfo['seat_count'] ??
            streamInfo['total_seats'] ??
            broadcasterData['seat_count'] ??
            broadcasterData['total_seats'] ??
            streamData?['livestreamdata']?['seat_count'] ??
            streamData?['livestreamdata']?['total_seats'] ??
            streamData?['livestream']?['seat_count'] ??
            streamData?['livestream']?['total_seats'] ??
            streamData?['seat_count'] ??
            streamData?['total_seats'] ??
            widget.seatCount;

    return _normalizeAudioSeatCount(value, fallback: 9);
  }

  int get liveSeatCount {
    if (_hasLiveRoomRealtimeUpdate &&
        websocketController.liveRoomSeatCount.value > 0) {
      return websocketController.liveRoomSeatCount.value;
    }

    return _roomSeatCountFromOwnData;
  }

  int get safeLiveLayout {
    if (liveSeatCount == 9) {
      return liveRoomLayout.clamp(0, 3).toInt();
    }
    if (liveSeatCount == 12) {
      return liveRoomLayout.clamp(0, 4).toInt();
    }
    return 0;
  }

  List<Color> get _roomGradient {
    final list = liveController.themeList;

    /// room_theme database ID thakle API list theke oi ID-r index ber kore
    /// local gradient apply kora hobe. API-te color field na thakle eta safest.
    final themeIndex = list.indexWhere((item) {
      if (item is Map && item['id'] != null) {
        return item['id'].toString() == liveRoomTheme.toString();
      }
      return false;
    });

    final index = themeIndex >= 0
        ? themeIndex % themeGradients.length
        : liveRoomTheme.abs() % themeGradients.length;

    return themeGradients[index];
  }

  String? _imageUrlById(List<dynamic> list, int id) {
    if (id == -1) return null;

    final item = list.firstWhere((element) {
      if (element is Map && element['id'] != null) {
        return element['id'].toString() == id.toString();
      }
      return false;
    }, orElse: () => null);

    if (item is Map && item['image'] != null) {
      return ImageHelper.getImageUrl(item['image'].toString());
    }

    return null;
  }

  String? get _roomBackgroundImageUrl {
    final int backgroundId = liveRoomBackground;
    if (backgroundId == -1) return null;

    final String? fromBackgroundList = _imageUrlById(
      liveController.backgroundList,
      backgroundId,
    );
    if (fromBackgroundList != null && fromBackgroundList.trim().isNotEmpty) {
      return fromBackgroundList;
    }

    // Some backend snapshots may send a direct background path instead of only
    // an ID. Use it only when it looks like a real image path/URL, never when it
    // is just a numeric ID such as "19".
    String? directImage(dynamic raw) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty || value.toLowerCase() == 'null') return null;
      final lower = value.toLowerCase();
      final bool looksLikeImage =
          lower.startsWith('http://') ||
              lower.startsWith('https://') ||
              lower.contains('/') ||
              lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.webp') ||
              lower.endsWith('.gif');
      if (!looksLikeImage) return null;
      return ImageHelper.getImageUrl(value);
    }

    return directImage(streamInfo['room_background_image']) ??
        directImage(streamInfo['background_image']) ??
        directImage(streamInfo['background']) ??
        directImage(broadcasterData['room_background_image']) ??
        directImage(broadcasterData['background_image']) ??
        directImage(broadcasterData['background']) ??
        directImage(streamData?['livestreamdata']?['room_background_image']) ??
        directImage(streamData?['livestreamdata']?['background_image']) ??
        directImage(streamData?['livestreamdata']?['background']) ??
        directImage(streamData?['room_background_image']) ??
        directImage(streamData?['background_image']) ??
        directImage(streamData?['background']);
  }

  String _cleanLiveText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _firstLiveText(List<dynamic> values) {
    for (final value in values) {
      final text = _cleanLiveText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String get _roomTitleFromOwnData {
    // Audio live top header must show the ROOM/STREAM title, not host name.
    // stream_title is the main backend field; old aliases stay as fallbacks.
    return _firstLiveText([
      streamInfo['stream_title'],
      streamInfo['stream_bte'],
      streamInfo['title'],
      streamData?['livestreamdata']?['stream_title'],
      streamData?['livestreamdata']?['stream_bte'],
      streamData?['livestreamdata']?['title'],
      streamData?['livestream']?['stream_title'],
      streamData?['livestream']?['stream_bte'],
      streamData?['livestream']?['title'],
      streamData?['stream_title'],
      streamData?['stream_bte'],
      streamData?['title'],
      broadcasterData['stream_title'],
      broadcasterData['stream_bte'],
      broadcasterData['title'],
    ]);
  }

  String get _roomAnnouncementFromOwnData {
    return _firstLiveText([
      streamInfo['announcement'],
      streamInfo['anousment'],
      streamInfo['stream_title'],
      streamData?['livestreamdata']?['announcement'],
      streamData?['livestreamdata']?['anousment'],
      streamData?['livestreamdata']?['stream_title'],
      streamData?['announcement'],
      streamData?['anousment'],
      streamData?['stream_title'],
      broadcasterData['announcement'],
      broadcasterData['anousment'],
      broadcasterData['stream_title'],
    ]);
  }

  String get _roomImageFromOwnData {
    // Audio live top header must show the ROOM/STREAM image, not host profile.
    return _firstLiveText([
      streamInfo['stream_image_url'],
      streamInfo['stream_image'],
      streamInfo['image'],
      streamInfo['cover_image'],
      streamInfo['thumbnail'],
      streamData?['livestreamdata']?['stream_image_url'],
      streamData?['livestreamdata']?['stream_image'],
      streamData?['livestreamdata']?['image'],
      streamData?['livestreamdata']?['cover_image'],
      streamData?['livestreamdata']?['thumbnail'],
      streamData?['livestream']?['stream_image_url'],
      streamData?['livestream']?['stream_image'],
      streamData?['stream_image_url'],
      streamData?['stream_image'],
      broadcasterData['stream_image_url'],
      broadcasterData['stream_image'],
      broadcasterData['image'],
    ]);
  }

  String get _roomPasswordFromOwnData {
    return _firstLiveText([
      streamInfo['room_password'],
      streamInfo['stream_password'],
      streamInfo['password'],
      streamData?['livestreamdata']?['room_password'],
      streamData?['livestreamdata']?['stream_password'],
      streamData?['livestreamdata']?['password'],
      streamData?['room_password'],
      streamData?['stream_password'],
      streamData?['password'],
      broadcasterData['room_password'],
      broadcasterData['stream_password'],
      broadcasterData['password'],
    ]);
  }

  String get liveRoomTitleText {
    if (_hasLiveRoomRealtimeUpdate &&
        websocketController.liveRoomTitle.value.trim().isNotEmpty) {
      return websocketController.liveRoomTitle.value.trim();
    }

    final user = _safeMap(broadcasterData['user']);
    return _firstLiveText([_roomTitleFromOwnData, user['name']]);
  }

  String get liveRoomAnnouncementText {
    if (_hasLiveRoomRealtimeUpdate &&
        websocketController.liveRoomAnnouncement.value.trim().isNotEmpty) {
      return websocketController.liveRoomAnnouncement.value.trim();
    }

    return _roomAnnouncementFromOwnData;
  }

  String get liveRoomCoverImageUrl {
    final raw = _firstLiveText([
      _hasLiveRoomRealtimeUpdate
          ? websocketController.liveRoomStreamImage.value
          : '',
      _roomImageFromOwnData,
    ]);

    if (raw.isEmpty) return _hostProfileImageUrl;
    return ImageHelper.getImageUrl(raw);
  }

  String get _hostProfileImageUrl {
    final Map<String, dynamic> user = _safeMap(broadcasterData['user']);
    final Map<String, dynamic> streamUser = _safeMap(streamInfo['user']);
    final Map<String, dynamic> liveDataUser = _safeMap(
      _safeMap(streamData?['livestreamdata'])['user'],
    );
    final Map<String, dynamic> streamDataUser = _safeMap(streamData?['user']);

    final String raw = _firstLiveText([
      user['profile_image'],
      user['avatar'],
      streamUser['profile_image'],
      streamUser['avatar'],
      liveDataUser['profile_image'],
      liveDataUser['avatar'],
      streamDataUser['profile_image'],
      streamDataUser['avatar'],
    ]);

    if (raw.isEmpty) return '';

    return ImageHelper.getImageUrl(raw);
  }

  Widget _hostProfileFallbackImage({
    required double height,
    required double width,
    double? iconSize,
  }) {
    final fallback = _hostProfileImageUrl;
    return SafeNetworkImage(
      imageUrl: fallback,
      height: height,
      width: width,
      fit: BoxFit.cover,
      memCacheWidth: (width * 3).round().clamp(64, 480),
      memCacheHeight: (height * 3).round().clamp(64, 480),
      maxWidthDiskCache: 640,
      maxHeightDiskCache: 640,
    );
  }

  Widget _roomBackgroundWidget() {
    final bgImage = _roomBackgroundImageUrl;

    if (bgImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          SafeLiveBackgroundImage(
            key: ValueKey<String>('audio-room-background-$bgImage'),
            imageUrl: bgImage,
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            memCacheHeight: 1920,
            maxWidthDiskCache: 1440,
            maxHeightDiskCache: 2560,
          ),
          ColoredBox(color: Colors.black.withOpacity(.18)),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _roomGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  void setLiveStreamDataAsBroadcaster() {
    streamInfo.value = streamData['livestreamdata'] ?? {};

    broadcasterData.value = {
      ..._safeMap(streamData['broadcaster_call_data']),
      ..._safeMap(streamData['livestreamdata']),
    };
    // liveController.lastPingUpdate(id: streamInfo['id']);
    // Battery Optimization: Use optimized ping interval

    final pingInterval = _batteryOptimizer.getOptimizedPingInterval(
      _currentPerformanceLevel,
    );
    liveController.updatePingInterval(pingInterval);
    liveController.lastPingUpdate(id: streamInfo['id']);

    ///------------- time
    final int currentStreamId =
        int.tryParse(
          (streamInfo['id'] ?? streamInfo['livestream_id']).toString(),
        ) ??
            0;
    final String createdAt =
    (streamData['livestreamdata']?['start_time'] ??
        streamData['livestreamdata']?['created_at'] ??
        broadcasterData['start_time'] ??
        broadcasterData['created_at'] ??
        DateTime.now().toIso8601String())
        .toString();

    if (currentStreamId > 0) {
      liveController.startLive(
        createdAt,
        liveStreamId: currentStreamId,
        forceRestart: !liveController.isTimerRunningForStream(currentStreamId),
      );
    } else if (!liveController.isLive.value) {
      liveController.startLive(createdAt);
    }

    /// Host nijer room create/open korle nijer premium/normal entry nijer
    /// screen-eo dekhbe. Eta route ready hoyar por run kori, jate UI smooth thake.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_effectiveBroadcaster || _isLiveExiting) return;
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted || !_effectiveBroadcaster || _isLiveExiting) return;
        _showSelfEntryForCurrentRoom(source: 'host_live_open');
      });
    });
  }

  void setLiveStreamDataAsAudience() {
    final data = _safeMap(streamData);
    final liveData = _safeMap(data['livestreamdata']).isNotEmpty
        ? _safeMap(data['livestreamdata'])
        : _safeMap(data['livestream']).isNotEmpty
        ? _safeMap(data['livestream'])
        : data;

    final callers = data['livestream_callers'] is List
        ? List<dynamic>.from(data['livestream_callers'])
        : liveData['livestream_callers'] is List
        ? List<dynamic>.from(liveData['livestream_callers'])
        : <dynamic>[];

    final int ownerId = _ownerUserIdFromLiveMap({...data, ...liveData});

    Map<String, dynamic> hostCaller = <String, dynamic>{};
    for (final raw in callers) {
      final call = _safeMap(raw);
      if (call.isEmpty) continue;

      final bool isCurrentRoom = _mapBelongsToCurrentStream(call);
      final bool belongsToOwner =
          ownerId > 0 && _callBelongsToUser(call, ownerId);
      final bool broadcasterFlag =
          _truthy(call['is_broadcaster']) || _truthy(call['current_room_host']);

      if (isCurrentRoom && (belongsToOwner || broadcasterFlag)) {
        hostCaller = call;
        break;
      }
    }

    final ownerUser = _ownerUserFromLiveMap({...data, ...liveData});
    final hostCallerUser = _safeMap(hostCaller['user']);

    final mergedHostData = <String, dynamic>{...liveData, ...hostCaller};

    if (hostCallerUser.isNotEmpty) {
      mergedHostData['user'] = hostCallerUser;
    } else if (ownerUser.isNotEmpty) {
      mergedHostData['user'] = ownerUser;
    }

    if (ownerId > 0) {
      mergedHostData['user_id'] = ownerId;
      mergedHostData['host_id'] ??= ownerId;
      mergedHostData['owner_user_id'] ??= ownerId;
    }

    // Important: do not seed host view from first caller. A normal caller/admin
    // in another live must never become the visual Host.
    broadcasterData.value = mergedHostData;
    streamInfo.value = liveData.isNotEmpty ? liveData : data;
  }

  Future<void> _resumeSameAudioStreamForRestore(
      RtcEngine engine,
      int currentStreamIdForAgora,
      ) async {
    liveLog(
      '♻️ Same audio stream restore detected, skip full Agora prepare: $currentStreamIdForAgora',
    );

    final int restoreSessionId = ++_globalAgoraJoinSession;
    _localAgoraSessionId = restoreSessionId;
    _localAgoraStreamId = currentStreamIdForAgora;
    _setGlobalAgoraJoinedStream(currentStreamIdForAgora);

    try {
      final oldHandler = _globalAudioRtcHandler;
      if (oldHandler != null) {
        engine.unregisterEventHandler(oldHandler);
      }
    } catch (e) {
      liveLog('⚠️ Old Agora restore handler unregister ignored: $e');
    }

    final restoreHandler = RtcEngineEventHandler(
      onAudioVolumeIndication:
          (
          RtcConnection connection,
          List<AudioVolumeInfo> speakers,
          int speakerNumber,
          int totalVolume,
          ) {
        if (!_agoraService.isCurrentEngineInstance(engine)) return;
        if (!_isActiveAgoraSession(
          sessionId: restoreSessionId,
          streamId: currentStreamIdForAgora,
          source: 'restore_volume',
        )) {
          return;
        }

        bool localSpeakingSeen = false;
        for (final speaker in speakers) {
          final int uid = _normalizeAgoraUid(speaker.uid ?? 0);
          final int volume = speaker.volume ?? 0;
          if (uid == 0) continue;
          _handleSpeakingVolumeSample(uid: uid, volume: volume);
          if (uid ==
              (authController.userProfile.value.user?.id?.toInt() ?? 0)) {
            localSpeakingSeen = true;
          }
        }

        if (_effectiveBroadcaster && !localSpeakingSeen) {
          final int myId =
              authController.userProfile.value.user?.id?.toInt() ?? 0;
          if (myId > 0) {
            _handleSpeakingVolumeSample(uid: myId, volume: totalVolume);
          }
        }
      },
      onError: (ErrorCodeType err, String msg) {
        if (!_agoraService.isCurrentEngineInstance(engine)) return;
        if (!_isActiveAgoraSession(
          sessionId: restoreSessionId,
          streamId: currentStreamIdForAgora,
          source: 'restore_error',
        )) {
          return;
        }
        liveLog('⚠️ Agora restore Error: $err | Message: $msg');
      },
    );
    _globalAudioRtcHandler = restoreHandler;
    engine.registerEventHandler(restoreHandler);

    await engine.enableAudio();
    await engine.enableAudioVolumeIndication(
      interval: 600,
      smooth: 3,
      reportVad: true,
    );

    if (_effectiveBroadcaster) {
      await _applyAgoraRoleOnce(
        ClientRoleType.clientRoleBroadcaster,
        source: 'restore_host',
      );
      try {
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
          ),
        );
      } catch (e) {
        liveLog('⚠️ Restore host media options ignored: $e');
      }
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      await engine.adjustRecordingSignalVolume(
        liveController.mute.value ? 0 : 100,
      );
    } else {
      final bool isOnSeatNow = _shouldPublishCurrentUserMicrophone();
      final role = isOnSeatNow
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;
      await _applyAgoraRoleOnce(role, source: 'restore_audience');
      try {
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            clientRoleType: role,
            publishMicrophoneTrack: isOnSeatNow,
            autoSubscribeAudio: true,
          ),
        );
      } catch (e) {
        liveLog('⚠️ Restore audience media options ignored: $e');
      }
      await engine.muteLocalAudioStream(!isOnSeatNow);
      await engine.adjustRecordingSignalVolume(isOnSeatNow ? 100 : 0);
    }

    // Ensure remote seated users are audible again after route restore.
    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final uid =
            int.tryParse(
              (raw['caller_id'] ??
                  raw['user_id'] ??
                  (raw['user'] is Map ? raw['user']['id'] : null))
                  ?.toString() ??
                  '',
            ) ??
                0;
        if (uid > 0) {
          await engine.muteRemoteAudioStream(uid: uid, mute: false);
        }
      }
    } catch (e) {
      liveLog('⚠️ Restore remote audio unmute ignored: $e');
    }

    try {
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      await engine.setEnableSpeakerphone(true);
    } catch (_) {}

    _scheduleUIUpdate();
    liveLog('✅ Same audio stream restored without rejoin');
  }

  Future<bool> _ensureLiveMicrophonePermission() async {
    try {
      PermissionStatus status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      }

      status = await Permission.microphone.request();

      if (status.isGranted) {
        await Future.delayed(const Duration(milliseconds: 250));
        return true;
      }

      Fluttertoast.showToast(
        msg: ('Please allow microphone permission for audio live').appTr,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 12.0,
      );

      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }

      return false;
    } catch (e) {
      liveLog('⚠️ Microphone permission check failed: $e');
      return true;
    }
  }

  bool _presenceSaysCurrentUserIsCaller() {
    try {
      return liveController.currentPresenceRole == 'caller' &&
          liveController.currentPresenceIsOnSeat;
    } catch (_) {
      return false;
    }
  }

  /// Do not trust only the freshly fetched caller list after app resume.
  /// A delayed API snapshot can briefly omit the current caller even though the
  /// presence heartbeat still correctly says caller/on-seat.
  bool _shouldPublishCurrentUserMicrophone() {
    return _effectiveBroadcaster ||
        _isCurrentUserOnAnySeat() ||
        _presenceSaysCurrentUserIsCaller();
  }

  bool _currentMicrophoneShouldStayMuted() {
    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    return liveController.mute.value == true ||
        (currentUserId > 0 &&
            websocketController.audioMutedUserMap[currentUserId] == true);
  }

  Future<void> _recoverAudioAfterExternalCall({
    required String reason,
    bool hardRestartAudioDevice = false,
  }) async {
    if (_isLiveExiting || _audioInterruptionRecoveryRunning) return;

    final RtcEngine? engine = _agoraService.engine;
    if (engine == null) {
      liveLog('⚠️ Audio interruption recovery needs Agora prepare => $reason');
      await prepareForLive();
      return;
    }

    final bool shouldPublishMic = _shouldPublishCurrentUserMicrophone();
    if (shouldPublishMic) {
      final bool micReady = await _ensureLiveMicrophonePermission();
      if (!micReady) return;
    }

    _audioInterruptionRecoveryRunning = true;
    try {
      final ClientRoleType role = shouldPublishMic
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;
      final bool keepMuted = shouldPublishMic
          ? _currentMicrophoneShouldStayMuted()
          : true;

      await _agoraService.recoverAudioAfterInterruption(
        role: role,
        publishMicrophoneTrack: shouldPublishMic,
        microphoneMuted: keepMuted,
        hardRestartAudioDevice: hardRestartAudioDevice && shouldPublishMic,
        reason: reason,
      );

      // Keep AudioLiveView's role dedupe cache aligned with the role that the
      // recovery method just applied directly to Agora.
      _lastAppliedAgoraRole = role;
      _globalLastAppliedAgoraRole = role;
      _globalLastRoleAppliedAt = DateTime.now();
      _lastMicPublishAt = null;

      final int currentUserId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (currentUserId > 0 && shouldPublishMic) {
        websocketController.audioMutedUserMap[currentUserId] = keepMuted;
        websocketController.audioMutedUserMap.refresh();
        liveController.mute.value = keepMuted;
      }

      // Remote playout can also be paused by the competing calling app.
      try {
        await engine.muteAllRemoteAudioStreams(false);
        await engine.adjustPlaybackSignalVolume(
          liveController.isBroadSpeakerMuted.value ? 0 : 100,
        );
      } catch (error) {
        liveLog('⚠️ Remote audio restore ignored [$reason]: $error');
      }

      liveLog(
        '✅ Audio focus/microphone recovered => $reason '
            'publishMic=$shouldPublishMic muted=$keepMuted '
            'hard=$hardRestartAudioDevice',
      );
    } catch (error, stackTrace) {
      liveLog(
        '❌ Audio focus/microphone recovery failed => '
            '$reason $error\n$stackTrace',
      );
    } finally {
      _audioInterruptionRecoveryRunning = false;
    }
  }

  void _schedulePostResumeAudioRecovery(Duration interruptionDuration) {
    _postResumeAudioRecoveryTimer?.cancel();
    _postResumeAudioRecoveryConfirmTimer?.cancel();

    final bool hardRestart = interruptionDuration.inMilliseconds >= 700;

    // Recover before slow room/list APIs. This makes a seated caller audible as
    // soon as WhatsApp/Meet releases the microphone.
    unawaited(
      _recoverAudioAfterExternalCall(
        reason: 'lifecycle_resume_immediate',
        hardRestartAudioDevice: hardRestart,
      ),
    );

    // Some Android devices release telecom/VoIP audio focus a little after the
    // Flutter resumed callback. Reapply publish state after that release.
    _postResumeAudioRecoveryTimer = Timer(
      const Duration(milliseconds: 750),
          () => unawaited(
        _recoverAudioAfterExternalCall(
          reason: 'lifecycle_resume_750ms',
          hardRestartAudioDevice: false,
        ),
      ),
    );

    _postResumeAudioRecoveryConfirmTimer = Timer(
      const Duration(milliseconds: 1800),
          () => unawaited(
        _recoverAudioAfterExternalCall(
          reason: 'lifecycle_resume_1800ms',
          hardRestartAudioDevice: false,
        ),
      ),
    );
  }

  Future<void> _forcePublishLocalMic(
      RtcEngine engine, {
        required String reason,
      }) async {
    final bool shouldPublishMic = _shouldPublishCurrentUserMicrophone();

    if (!shouldPublishMic) return;

    final int currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    /// ✅ IMPORTANT:
    /// Seat join/resume er somoy mic track publish korte hobe, but user-er
    /// manual mute state remove kora jabe na. Age ekhane mute=false kore deya
    /// hocchilo, tai host mute thaka obosthay seat e bosle mute icon/state
    /// chole jeto.
    final bool keepMuted = _effectiveBroadcaster
        ? liveController.mute.value == true
        : (liveController.mute.value == true ||
        (currentUserId > 0 &&
            websocketController.audioMutedUserMap[currentUserId] ==
                true));

    if (currentUserId > 0) {
      websocketController.audioMutedUserMap[currentUserId] = keepMuted;
      websocketController.audioMutedUserMap.refresh();
    }
    liveController.mute.value = keepMuted;

    final int activeStreamId = _currentStreamIdFromArgs();
    if (_localAgoraStreamId > 0 &&
        activeStreamId > 0 &&
        _localAgoraStreamId != activeStreamId) {
      liveLog(
        '⛔ Mic publish skipped for old stream => local=$_localAgoraStreamId current=$activeStreamId reason=$reason',
      );
      return;
    }

    final now = DateTime.now();
    final last = _lastMicPublishAt;
    if (last != null && now.difference(last).inMilliseconds < 650) {
      liveLog('🛡️ Duplicate mic publish skipped => $reason');
      return;
    }
    _lastMicPublishAt = now;

    try {
      await engine.enableAudio();
      await engine.enableLocalAudio(true);
      await _applyAgoraRoleOnce(
        ClientRoleType.clientRoleBroadcaster,
        source: 'force_publish_$reason',
      );

      try {
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishMicrophoneTrack: true,
            autoSubscribeAudio: true,
          ),
        );
      } catch (e) {
        liveLog('⚠️ force publish media options ignored [$reason]: $e');
      }

      /// Track publish on thakbe. Manual mute hole volume 0, unmute hole 100.
      /// Eta host music/audio-mixing ke unnecessarily bondho kore na.
      await engine.muteLocalAudioStream(false);
      await engine.adjustRecordingSignalVolume(keepMuted ? 0 : 100);
      await engine.enableAudioVolumeIndication(
        interval: 600,
        smooth: 3,
        reportVad: true,
      );

      liveLog(
        '✅ Local microphone publish forced => $reason muted_preserved:$keepMuted',
      );
    } catch (e) {
      liveLog('⚠️ force publish local mic failed [$reason]: $e');
    }
  }

  void _schedulePostJoinMicRestore(
      RtcEngine engine, {
        required int sessionId,
        required int streamId,
      }) {
    _postJoinMicRestoreTimer?.cancel();
    _postJoinMicRestoreConfirmTimer?.cancel();

    if (!_shouldPublishCurrentUserMicrophone()) return;

    Future<void> runPass(String reason) async {
      if (!_agoraService.isCurrentEngineInstance(engine)) return;
      if (!_isActiveAgoraSession(
        sessionId: sessionId,
        streamId: streamId,
        source: reason,
      )) {
        return;
      }
      await _forcePublishLocalMic(engine, reason: reason);
    }

    _postJoinMicRestoreTimer = Timer(
      const Duration(milliseconds: 850),
          () => unawaited(runPass('post_join_mic_restore_850ms')),
    );
    _postJoinMicRestoreConfirmTimer = Timer(
      const Duration(milliseconds: 1750),
          () => unawaited(runPass('post_join_mic_restore_1750ms')),
    );
  }

  void _setAudioJoinReady(bool ready) {
    if (_audioJoinReady == ready) return;
    if (!mounted) {
      _audioJoinReady = ready;
      return;
    }
    setState(() => _audioJoinReady = ready);
  }

  void _startAudioJoinLoadingFallback() {
    _audioJoinLoadingFallbackTimer?.cancel();
    _audioJoinLoadingFallbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_audioJoinReady) {
        _setAudioJoinReady(true);
      }
    });
  }

  void _configureContinuousAgoraTokenRenewal(int streamId) {
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    final String channelName = widget.channelName.trim();
    if (streamId <= 0 || userId <= 0 || channelName.isEmpty) {
      liveLog('⚠️ Agora token renewal skipped: invalid room/user/channel');
      return;
    }

    final String? serviceToken =
    _agoraService.joinedChannelId == channelName &&
        _agoraService.joinedUid == userId
        ? _agoraService.currentAgoraToken
        : null;
    final String initialToken = (serviceToken?.trim().isNotEmpty ?? false)
        ? serviceToken!.trim()
        : ((_currentToken?.trim().isNotEmpty ?? false)
        ? _currentToken!.trim()
        : widget.token.trim());

    if (initialToken.isEmpty) {
      liveLog('⚠️ Agora token renewal skipped: initial token empty');
      return;
    }
    _currentToken = initialToken;

    final tokenController = liveController.agoraTokenController;
    int initialExpiresIn = 3600;
    try {
      final Map<String, dynamic> currentPayload = Map<String, dynamic>.from(
        tokenController.agoraToken,
      );
      final String responseChannel = tokenController
          .getChannelNameStringFrom(currentPayload)
          .trim();
      final int responseUid = tokenController.getUidIntFrom(currentPayload);
      if ((responseChannel.isEmpty || responseChannel == channelName) &&
          (responseUid == 0 || responseUid == userId)) {
        initialExpiresIn = tokenController.getExpiresInSecondsFrom(
          currentPayload,
          fallback: 3600,
        );
      }
    } catch (_) {}

    _agoraService.configureAgoraTokenRenewal(
      channelId: channelName,
      uid: userId,
      initialToken: initialToken,
      expiresInSeconds: initialExpiresIn,
      fetchFreshToken: () async {
        final bool needsBroadcasterToken =
            _effectiveBroadcaster || _shouldPublishCurrentUserMicrophone();
        final int currentPkId = liveController.currentPkId.value;

        final Map<String, dynamic>? payload = await tokenController
            .requestAgoraToken(
          isBroadcaster: needsBroadcasterToken,
          userId: userId,
          channelName: channelName,
          streamId: streamId.toString(),
          pkId: liveController.pkIsRunning.value && currentPkId > 0
              ? currentPkId
              : null,
          forceRefresh: true,
        );

        if (payload == null) {
          throw StateError('Fresh Agora token API returned no data');
        }

        final String freshToken = tokenController
            .getTokenStringFrom(payload)
            .trim();
        final String responseChannel = tokenController
            .getChannelNameStringFrom(payload)
            .trim();
        final int responseUid = tokenController.getUidIntFrom(payload);

        if (freshToken.isEmpty) {
          throw StateError('Fresh Agora token is empty');
        }
        if (responseChannel.isNotEmpty && responseChannel != channelName) {
          throw StateError(
            'Agora renewal channel mismatch: '
                '$responseChannel != $channelName',
          );
        }
        if (responseUid > 0 && responseUid != userId) {
          throw StateError(
            'Agora renewal uid mismatch: $responseUid != $userId',
          );
        }

        _currentToken = freshToken;
        return AgoraRenewalToken(
          token: freshToken,
          expiresInSeconds: tokenController.getExpiresInSecondsFrom(
            payload,
            fallback: 3600,
          ),
        );
      },
    );
  }

  Future<void> prepareForLive() async {
    if (_prepareForLiveRunning) {
      liveLog('🛡️ Duplicate prepareForLive skipped');
      return;
    }

    _prepareForLiveRunning = true;
    _setAudioJoinReady(false);
    _startAudioJoinLoadingFallback();

    try {
      if (_effectiveBroadcaster && !_hostInitialAudioStateApplied) {
        _hostInitialAudioStateApplied = true;
        final int myId =
            authController.userProfile.value.user?.id?.toInt() ?? 0;

        /// Never force a permanent-room rejoin to unmuted here.
        /// The controller already restored the authoritative previous mute
        /// state from the rejoin response/local room session. Forcing false
        /// caused the icon to show unmuted while Agora still had a silent track.
        final bool keepMuted =
            liveController.mute.value == true ||
                (myId > 0 && websocketController.audioMutedUserMap[myId] == true);

        liveController.mute.value = keepMuted;
        liveController.isMuted.value = keepMuted;
        liveController.isAudioEnabled.value = !keepMuted;
        if (myId > 0) {
          websocketController.audioMutedUserMap[myId] = keepMuted;
          websocketController.audioMutedUserMap.refresh();
        }

        liveLog(
          '🎙️ Host initial mute preserved => stream=${_currentStreamIdFromArgs()} muted=$keepMuted',
        );
      }
      if (_effectiveBroadcaster) {
        final bool micReady = await _ensureLiveMicrophonePermission();
        if (!micReady) {
          liveLog('⛔ Audio live join stopped: microphone permission denied');
          return;
        }

        /// Do not reset host mute here. Snapshot/backend or previous UI state may
        /// already say host is muted.
      }

      // 🔹 1. Initialize Agora Engine (if not already)
      if (!_agoraService.isInitialized || _agoraService.engine == null) {
        bool initialized = await _agoraService.initializeAudioEngine();
        if (!initialized) {
          liveLog("Failed to initialize Agora engine");
          return;
        }
      }

      final engine = _agoraService.engine;
      if (engine == null) {
        liveLog("Engine is null after initialization");
        return;
      }

      final int currentStreamIdForAgora = _currentStreamIdFromArgs();
      final bool isSameStreamRestore =
          currentStreamIdForAgora > 0 &&
              websocketController.activeAudioStreamId.value ==
                  currentStreamIdForAgora &&
              (_agoraChannelJoined ||
                  _globalAgoraJoinedStreamId == currentStreamIdForAgora) &&
              !_isLiveExiting;

      if (isSameStreamRestore) {
        _configureContinuousAgoraTokenRenewal(currentStreamIdForAgora);
        await _resumeSameAudioStreamForRestore(engine, currentStreamIdForAgora);
        _setAudioJoinReady(true);
        return;
      }

      if (_globalAgoraJoinRunning) {
        liveLog(
          '🛡️ Agora prepare skipped; another join is running '
              'globalStream=$_globalAgoraJoinedStreamId requested=$currentStreamIdForAgora',
        );
        return;
      }
      _globalAgoraJoinRunning = true;

      /// Room switch/new live create fix:
      /// Agora engine singleton old channel-e joined thakle new channel join korleo
      /// voice/wave/viewer state mix hoye jay. Tai every new stream join-er age
      /// old channel clean leave + media reset.
      final int previousActiveStreamId =
          websocketController.activeAudioStreamId.value;
      final bool shouldLeavePreviousChannel =
          _agoraChannelJoined ||
              (previousActiveStreamId > 0 &&
                  previousActiveStreamId != currentStreamIdForAgora);

      if (shouldLeavePreviousChannel) {
        try {
          await engine.muteLocalAudioStream(true);
          await _agoraService.leaveChannel();
          _agoraChannelJoined = false;
          _clearGlobalAgoraJoinedStream(streamId: previousActiveStreamId);
          await Future.delayed(const Duration(milliseconds: 80));
          liveLog('✅ Agora old audio channel left before new stream join');
        } catch (e) {
          liveLog('⚠️ Agora pre-join leave ignored: $e');
        }
      }

      _configureContinuousAgoraTokenRenewal(currentStreamIdForAgora);

      _speakingExpiryTimer?.cancel();
      _speakingExpiryTimer = null;
      _speakingUntilMs.clear();
      _speakingUserIds.clear();

      liveLog("🎧 Configuring Agora for low-heat audio live...");

      // Audio warm-up already applied the invariant engine configuration.
      // Reapply it only when this singleton was previously configured for video.
      if (!_agoraService.isAudioOnlyInitialized) {
        await engine.setChannelProfile(
          ChannelProfileType.channelProfileLiveBroadcasting,
        );
        await engine.disableVideo();
        await engine.enableAudio();
        await engine.enableAudioVolumeIndication(
          interval: 600,
          smooth: 3,
          reportVad: true,
        );
        await engine.setParameters('{"che.audio.low_power_mode": true}');
      }

      // 🔹 4. Set optimized audio profile based on performance level or battery
      final audioConfig = _batteryOptimizer.getOptimizedAudioConfig(
        _currentPerformanceLevel,
      );

      await engine.setAudioProfile(
        profile:
        audioConfig['profile'] ??
            AudioProfileType.audioProfileSpeechStandard,
        scenario:
        audioConfig['scenario'] ??
            AudioScenarioType.audioScenarioGameStreaming,
      );

      // 🔹 5. Extra optimization for low battery or heat
      if (_currentPerformanceLevel == PerformanceLevel.critical) {
        // Lower quality audio to reduce CPU and heat
        await engine.setAudioProfile(
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioDefault,
        );

        // Reduce CPU usage by disabling expensive audio processing
        await engine.setParameters('{"che.audio.enable.agc": false}');
        await engine.setParameters('{"che.audio.enable.aec": false}');
        await engine.setParameters(
          '{"che.audio.enable.ns": true}',
        ); // keep noise suppression
      } else {
        // Normal / balanced mode
        await engine.setParameters('{"che.audio.enable.agc": true}');
        await engine.setParameters('{"che.audio.enable.aec": true}');
        await engine.setParameters('{"che.audio.enable.ns": true}');
      }

      // 🔹 6. Enable hardware acceleration if available
      await engine.setParameters('{"che.audio.hardware_encoding": true}');
      await engine.setParameters('{"che.audio.hardware_decoding": true}');

      // 🔹 7. Set client role (broadcaster vs audience)
      if (_effectiveBroadcaster) {
        await _applyAgoraRoleOnce(
          ClientRoleType.clientRoleBroadcaster,
          source: 'prepare_host',
        );

        /// Host mute korle local audio stream bondho korbo na,
        /// only mic recording volume 0/100 korbo. Tahole music mixing audience pabe.
        await engine.enableLocalAudio(true);
        await engine.muteLocalAudioStream(false);
        await engine.adjustRecordingSignalVolume(
          liveController.mute.value ? 0 : 100,
        );
        await engine.adjustAudioMixingVolume(65);
      } else {
        await _applyAgoraRoleOnce(
          ClientRoleType.clientRoleAudience,
          source: 'prepare_audience',
        );
        await engine.muteLocalAudioStream(
          true,
        ); // Audience shouldn’t send audio
      }

      // 🔹 8. Register event handlers once for the latest Agora session.
      // Old AudioLiveView handlers are unregistered and also guarded by session id,
      // so stale stream callbacks (6871/6889) cannot mutate the new stream (6926).
      final int agoraSessionId = ++_globalAgoraJoinSession;
      _localAgoraSessionId = agoraSessionId;
      _localAgoraStreamId = currentStreamIdForAgora;

      try {
        final oldHandler = _globalAudioRtcHandler;
        if (oldHandler != null) {
          engine.unregisterEventHandler(oldHandler);
        }
      } catch (e) {
        liveLog('⚠️ Old Agora handler unregister ignored: $e');
      }

      final audioRtcHandler = RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          if (!_isActiveAgoraSession(
            sessionId: agoraSessionId,
            streamId: currentStreamIdForAgora,
            source: 'join_success',
          )) {
            return;
          }

          _agoraChannelJoined = true;
          _setGlobalAgoraJoinedStream(currentStreamIdForAgora);
          _setAudioJoinReady(true);
          if (kDebugMode) {
            final String prefix = _effectiveBroadcaster ? 'create' : 'join';
            debugPrint(
              '${prefix}_agora_join_success=${DateTime.now().microsecondsSinceEpoch}',
            );
            debugPrint(
              '${prefix}_first_audio_ready=${DateTime.now().microsecondsSinceEpoch}',
            );
          }

          liveLog(
            '✅ Joined Agora channel => ${widget.channelName} '
                'stream=$currentStreamIdForAgora '
                'broadcaster=${_effectiveBroadcaster}',
          );

          if (_effectiveBroadcaster) {
            await _forcePublishLocalMic(
              engine,
              reason: 'on_join_channel_success',
            );
            _schedulePostJoinMicRestore(
              engine,
              sessionId: agoraSessionId,
              streamId: currentStreamIdForAgora,
            );
          }

          _scheduleUIUpdate();
          try {
            await engine.setDefaultAudioRouteToSpeakerphone(true);
            await engine.setEnableSpeakerphone(true);
          } catch (_) {}
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          if (!_isActiveAgoraSession(
            sessionId: agoraSessionId,
            streamId: currentStreamIdForAgora,
            source: 'user_joined',
          )) {
            return;
          }
          liveLog("👤 Remote user joined: $remoteUid");
          _scheduleUIUpdate();
          engine.muteRemoteAudioStream(uid: remoteUid, mute: false);
        },
        onUserOffline:
            (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
            ) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          if (!_isActiveAgoraSession(
            sessionId: agoraSessionId,
            streamId: currentStreamIdForAgora,
            source: 'user_offline',
          )) {
            return;
          }
          final uid = _normalizeAgoraUid(remoteUid);
          liveLog("🚫 Remote user left: $uid");
          _clearRemoteUserFromUi(uid);
        },
        onAudioVolumeIndication:
            (
            RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume,
            ) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          if (!_isActiveAgoraSession(
            sessionId: agoraSessionId,
            streamId: currentStreamIdForAgora,
            source: 'volume',
          )) {
            return;
          }

          bool localSpeakingSeen = false;
          final int myId =
              authController.userProfile.value.user?.id?.toInt() ?? 0;

          for (final speaker in speakers) {
            int uid = _normalizeAgoraUid(speaker.uid ?? 0);
            final int volume = speaker.volume ?? 0;

            if (uid == 0 && myId > 0) {
              uid = myId;
            }
            if (uid == 0) continue;

            if (uid == myId) localSpeakingSeen = true;

            _handleSpeakingVolumeSample(uid: uid, volume: volume);
          }

          if ((_effectiveBroadcaster || _isCurrentUserOnAnySeat()) &&
              myId > 0 &&
              !localSpeakingSeen) {
            _handleSpeakingVolumeSample(uid: myId, volume: totalVolume);
          }
        },
        onError: (ErrorCodeType err, String msg) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          if (!_isActiveAgoraSession(
            sessionId: agoraSessionId,
            streamId: currentStreamIdForAgora,
            source: 'error',
          )) {
            return;
          }
          liveLog("⚠️ Agora Error: $err | Message: $msg");
          if (_effectiveBroadcaster) {
            livestreamController.agoraTokenGenerateError();
          }
        },
      );
      _globalAudioRtcHandler = audioRtcHandler;
      engine.registerEventHandler(audioRtcHandler);

      // 🔹 9. Join channel
      int userId = authController.userProfile.value.user!.id!.toInt();
      liveLog(
        '🎙️ Agora join request => channel=${widget.channelName} '
            'uid=$userId broadcaster=${_effectiveBroadcaster}',
      );

      if (_globalAgoraJoinedStreamId == currentStreamIdForAgora &&
          _agoraChannelJoined) {
        liveLog(
          '🛡️ Agora join skipped; already joined stream=$currentStreamIdForAgora',
        );
      } else {
        if (kDebugMode) {
          final String prefix = _effectiveBroadcaster ? 'create' : 'join';
          debugPrint(
            '${prefix}_agora_join_start=${DateTime.now().microsecondsSinceEpoch}',
          );
        }
        await _agoraService.joinChannelWithOptions(
          token: (_currentToken?.trim().isNotEmpty ?? false)
              ? _currentToken!.trim()
              : widget.token,
          channelId: widget.channelName,
          uid: userId,
          options: ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: _effectiveBroadcaster
                ? ClientRoleType.clientRoleBroadcaster
                : ClientRoleType.clientRoleAudience,
            publishMicrophoneTrack: _effectiveBroadcaster,
            publishCameraTrack: false,
            autoSubscribeAudio: true,
            autoSubscribeVideo: false,
          ),
        );
      }

      if (mounted && !_audioJoinReady) {
        // joinChannel() returned successfully; onJoinChannelSuccess will still
        // refine state, but the user should not see a stuck loading overlay.
        _setAudioJoinReady(true);
      }

      // 🔹 10. Debounced UI refresh
      _scheduleUIUpdate();

      liveLog("🚀 Agora audio live ready (low-heat mode active)");
    } finally {
      _globalAgoraJoinRunning = false;
      _prepareForLiveRunning = false;
    }
  }

  bool _isCurrentUserOnAnySeat() {
    try {
      final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (myId == 0) return false;

      final dynamic rawList = liveController.callList;
      final List callers = rawList is List
          ? rawList
          : (rawList?.toList() ?? []);

      for (final dynamic item in callers) {
        if (item == null) continue;

        dynamic userId;
        dynamic status;

        if (item is Map) {
          userId =
              item['user_id'] ??
                  item['caller_id'] ??
                  item['id'] ??
                  item['user']?['id'] ??
                  item['caller']?['id'];
          status = item['status'] ?? item['call_status'] ?? item['state'];
        } else {
          try {
            userId = item.userId ?? item.user_id ?? item.callerId ?? item.id;
          } catch (_) {}
          try {
            status = item.status ?? item.callStatus;
          } catch (_) {}
        }

        final int uid = int.tryParse(userId?.toString() ?? '') ?? 0;
        final String st = (status ?? '').toString().toLowerCase();

        if (uid == myId &&
            (st.isEmpty ||
                st == 'accepted' ||
                st == 'active' ||
                st == 'joined')) {
          return true;
        }
      }
    } catch (e) {
      liveLog('⚠️ _isCurrentUserOnAnySeat liveController check failed: $e');
    }

    /// Fallback: websocket liveCallList is often updated first when a viewer
    /// becomes a speaker. Without this, the client can stay audience/muted
    /// until the user taps mute/unmute manually.
    try {
      final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (myId == 0) return false;

      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final call = Map<String, dynamic>.from(raw);
        final uid =
            int.tryParse(
              (call['caller_id'] ??
                  call['user_id'] ??
                  (call['user'] is Map ? call['user']['id'] : null) ??
                  (call['caller'] is Map ? call['caller']['id'] : null))
                  ?.toString() ??
                  '0',
            ) ??
                0;
        final st =
        (call['call_status'] ??
            call['status'] ??
            call['state'] ??
            'accepted')
            .toString()
            .toLowerCase();
        if (uid == myId &&
            (st.isEmpty ||
                st == 'accepted' ||
                st == 'active' ||
                st == 'joined' ||
                st == 'on_seat')) {
          return true;
        }
      }
    } catch (e) {
      liveLog('⚠️ _isCurrentUserOnAnySeat websocket fallback failed: $e');
    }

    return false;
  }

  int _currentStreamIdFromArgs() {
    final value =
        streamData?['livestreamdata']?['id'] ??
            streamData?['livestream_id'] ??
            streamData?['id'] ??
            streamInfo['id'];
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _viewerUserId(dynamic viewer) {
    if (viewer is! Map) return 0;
    final user = viewer['user'] is Map
        ? Map<String, dynamic>.from(viewer['user'])
        : <String, dynamic>{};
    return int.tryParse(
      (viewer['viewer_id'] ??
          viewer['user_id'] ??
          viewer['caller_id'] ??
          user['id'] ??
          user['user_id'])
          .toString(),
    ) ??
        0;
  }

  bool _viewerIsActiveForCurrentRoom(dynamic viewer) {
    if (viewer is! Map) return false;
    if (VipPrivileges.from(viewer).invisible &&
        !liveController.canModerateLive) {
      return false;
    }
    final currentSid = _currentStreamIdFromArgs();
    final itemSid =
        int.tryParse(
          (viewer['livestream_id'] ??
              viewer['stream_id'] ??
              viewer['live_id'] ??
              '')
              .toString(),
        ) ??
            0;
    if (currentSid > 0 && itemSid > 0 && itemSid != currentSid) return false;

    final activeRaw = viewer['is_active'];
    final active =
        activeRaw == null ||
            activeRaw == true ||
            activeRaw == 1 ||
            activeRaw.toString() == '1' ||
            activeRaw.toString().toLowerCase() == 'true';
    if (!active) return false;

    return _viewerUserId(viewer) > 0;
  }

  Map<String, dynamic> _viewerUserMapForProfile(dynamic viewer) {
    if (viewer is! Map) return <String, dynamic>{};
    if (viewer['user'] is Map) return Map<String, dynamic>.from(viewer['user']);
    if (viewer['User'] is Map) return Map<String, dynamic>.from(viewer['User']);
    return Map<String, dynamic>.from(viewer);
  }

  int _seatSafeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _callUserIdSafe(Map<String, dynamic> call) {
    final user = call['user'] is Map
        ? Map<String, dynamic>.from(call['user'])
        : <String, dynamic>{};
    final caller = call['caller'] is Map
        ? Map<String, dynamic>.from(call['caller'])
        : <String, dynamic>{};
    final viewer = call['viewer'] is Map
        ? Map<String, dynamic>.from(call['viewer'])
        : <String, dynamic>{};

    // IMPORTANT: call['id'] can be database row id. Use it only as last fallback.
    return _seatSafeInt(
      call['caller_id'] ??
          call['user_id'] ??
          user['id'] ??
          user['user_id'] ??
          caller['id'] ??
          caller['user_id'] ??
          viewer['id'] ??
          viewer['user_id'] ??
          call['id'],
    );
  }

  int? _callSeatNoSafe(Map<String, dynamic> call) {
    final v =
        call['seat_no'] ??
            call['seat'] ??
            call['seat_number'] ??
            call['seatNo'];
    final seat = _seatSafeInt(v);
    return seat > 0 && seat < 100 ? seat : null;
  }

  bool _callLooksAccepted(Map<String, dynamic> call) {
    final status =
    (call['status'] ??
        call['call_status'] ??
        call['state'] ??
        call['type'] ??
        '')
        .toString()
        .toLowerCase()
        .trim();

    if (status.isEmpty) return _callSeatNoSafe(call) != null;
    return status == 'accepted' ||
        status == 'active' ||
        status == 'joined' ||
        status == 'speaking' ||
        status == 'caller';
  }

  Map<String, dynamic>? _currentUserCallData() {
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId == 0) return null;

    Map<String, dynamic>? findInList(dynamic listLike) {
      final List list = listLike is List
          ? listLike
          : (listLike?.toList() ?? []);
      for (final rawCall in list) {
        if (rawCall is! Map) continue;
        final call = Map<String, dynamic>.from(rawCall);
        if (_callUserIdSafe(call) != currentUserId) continue;
        if (!_callLooksAccepted(call)) continue;
        return call;
      }
      return null;
    }

    // Websocket list normally updates first.
    final fromWs = findInList(websocketController.liveCallList);
    if (fromWs != null) return fromWs;

    // Controller list can hold the row when page is restored/re-opened.
    try {
      final fromController = findInList(liveController.callList);
      if (fromController != null) return fromController;
    } catch (_) {}

    return null;
  }

  Future<void> _forceCurrentUserToAudienceBecauseSeatLost({
    String reason = '',
  }) async {
    if (_effectiveBroadcaster) return;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId == 0) return;

    bool sameCurrentUser(dynamic call) {
      if (call is! Map) return false;
      final callerId = call['caller_id'];
      final userId = call['user_id'];
      final directId = call['id'];
      final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
      final nestedCallerId = call['caller'] is Map
          ? call['caller']['id']
          : null;

      return callerId.toString() == currentUserId.toString() ||
          userId.toString() == currentUserId.toString() ||
          directId.toString() == currentUserId.toString() ||
          nestedUserId.toString() == currentUserId.toString() ||
          nestedCallerId.toString() == currentUserId.toString();
    }

    try {
      final int beforeSeatLostCount = websocketController.liveCallList.length;
      websocketController.printSeatTrace(
        'view_force_audience_start',
        streamId: _currentStreamIdFromArgs(),
        userId: currentUserId,
        status: 'seat_missing',
        reason: reason,
        beforeCount: beforeSeatLostCount,
      );
      websocketController.liveCallList.removeWhere(sameCurrentUser);
      websocketController.liveCallList.refresh();
      try {
        websocketController.pendingCall.removeWhere(sameCurrentUser);
        websocketController.pendingCall.refresh();
      } catch (_) {}

      liveController.mute.value = false;

      final engine = _agoraService.engine;
      if (engine != null) {
        try {
          await engine.muteLocalAudioStream(true);
        } catch (_) {}
        try {
          await engine.adjustRecordingSignalVolume(0);
        } catch (_) {}
        try {
          await engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              clientRoleType: ClientRoleType.clientRoleAudience,
              publishMicrophoneTrack: false,
              autoSubscribeAudio: true,
            ),
          );
        } catch (e) {
          liveLog('⚠️ Seat lost media options update ignored: $e');
        }
        try {
          await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
        } catch (e) {
          liveLog('⚠️ Seat lost set audience role ignored: $e');
        }
      }

      if (mounted) setState(() {});
      websocketController.printSeatTrace(
        'view_force_audience_applied',
        streamId: _currentStreamIdFromArgs(),
        userId: currentUserId,
        status: 'audience',
        reason: reason,
        beforeCount: beforeSeatLostCount,
        afterCount: websocketController.liveCallList.length,
      );
    } catch (e) {
      liveLog('⚠️ _forceCurrentUserToAudienceBecauseSeatLost failed: $e');
    }
  }

  void _startAudioLivePresenceHeartbeat() {
    final sid = _currentStreamIdFromArgs();
    if (sid == 0) return;

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId == 0) return;

    final myCall = _currentUserCallData();
    final bool isOnSeat = _effectiveBroadcaster || myCall != null;

    final String role = _effectiveBroadcaster
        ? 'host'
        : isOnSeat
        ? 'caller'
        : 'viewer';

    final int? seatNo = _effectiveBroadcaster
        ? 1
        : (myCall == null ? null : _callSeatNoSafe(myCall));

    websocketController.printSeatTrace(
      'view_presence_start',
      streamId: sid,
      userId: currentUserId,
      seatNo: seatNo,
      status: role,
      note: 'isOnSeat=$isOnSeat',
    );
    liveController.startLivePresenceHeartbeat(
      livestreamId: sid,
      role: role,
      isOnSeat: isOnSeat,
      seatNo: seatNo,
    );
  }

  Future<void> _syncAudioLivePresenceAfterResume() async {
    final sid = _currentStreamIdFromArgs();
    if (sid == 0) return;

    _startAudioLivePresenceHeartbeat();

    try {
      final myCall = _currentUserCallData();
      final bool isOnSeat = _effectiveBroadcaster || myCall != null;
      await liveController.sendPresenceHeartbeatOnce(
        livestreamId: sid,
        role: _effectiveBroadcaster
            ? 'host'
            : isOnSeat
            ? 'caller'
            : 'viewer',
        isOnSeat: isOnSeat,
        seatNo: _effectiveBroadcaster
            ? 1
            : (myCall == null ? null : _callSeatNoSafe(myCall)),
      );

      await liveController.refreshLiveRoomRealtimeState(streamId: sid);
      await _loadInitialSeatLocks();
      await _loadYoutubeStateFromServer();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      liveLog('❌ Audio live presence resume sync failed safely: $e');

      /// 409 usually means backend already removed this caller seat while
      /// network/heartbeat was down. Do not keep publishing mic as broadcaster
      /// when server says current user is no longer on any seat.
      final text = e.toString();
      if (text.contains('409')) {
        try {
          await liveController.tryToGetCallList(streamId: sid);
          await liveController.getAvailableSeats(sid);
        } catch (refreshError) {
          liveLog('⚠️ Seat conflict refresh failed safely: $refreshError');
        }

        if (!_effectiveBroadcaster && !_isCurrentUserOnAnySeat()) {
          await _forceCurrentUserToAudienceBecauseSeatLost(
            reason: 'heartbeat_409_conflict',
          );
        }
      }
    }
  }

  Future<void> _markAudioLiveOfflineForExplicitExit() async {
    final sid = _currentStreamIdFromArgs();
    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (sid == 0 || currentUserId == 0) return;

    final myCall = _currentUserCallData();

    await liveController.markUserOffline(
      livestreamId: sid,
      role: _effectiveBroadcaster
          ? 'host'
          : myCall != null
          ? 'caller'
          : 'viewer',
      seatNo: myCall == null || myCall['seat_no'] == null
          ? null
          : int.tryParse(myCall['seat_no'].toString()),
    );
  }

  void _seedCurrentRoomCallList() {
    final seeded = <dynamic>[];

    if (_effectiveBroadcaster && broadcasterData.isNotEmpty) {
      seeded.add(Map<String, dynamic>.from(broadcasterData));
    } else {
      final callers = streamData?['livestream_callers'];
      if (callers is List) {
        seeded.addAll(
          callers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      } else if (broadcasterData.isNotEmpty) {
        seeded.add(Map<String, dynamic>.from(broadcasterData));
      }
    }

    if (seeded.isNotEmpty) {
      websocketController.mergeLiveCallListPreservingProfiles(
        seeded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        source: 'audio_seed_current_room',
      );

      /// Seed last known mic state from current room data.
      /// Late audience join korle host jodi already mute thake, audience side-e
      /// host mute icon preserve thakbe and seat join/leave event eta reset korbe na.
      for (final raw in seeded) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final rawUserId = item['user'] is Map
            ? item['user']['id']
            : (item['user_id'] ?? item['caller_id'] ?? item['id']);
        final int uid = int.tryParse(rawUserId?.toString() ?? '0') ?? 0;
        if (uid <= 0) continue;

        final audioOn =
            item['audio_on'] ??
                item['is_audio_on'] ??
                (item['user'] is Map ? item['user']['audio_on'] : null) ??
                (item['user'] is Map ? item['user']['is_audio_on'] : null);
        final muted =
            item['is_muted'] ??
                item['muted'] ??
                item['is_muted_by_host'] ??
                (item['user'] is Map ? item['user']['is_muted'] : null);

        final seededMuteState = _muteStateFromAudioFields(
          audioOn: audioOn,
          mutedRaw: muted,
        );

        if (seededMuteState != null) {
          websocketController.audioMutedUserMap[uid] = seededMuteState;
        } else {
          /// ✅ Fresh live/seat without explicit backend mute must be unmuted.
          /// This blocks stale mute icon from older controller state.
          websocketController.audioMutedUserMap.putIfAbsent(uid, () => false);
        }
      }

      websocketController.liveCallList.refresh();
      websocketController.audioMutedUserMap.refresh();
      liveLog('✅ Current room call list seeded: ${seeded.length}');
    }
  }

  void _syncInitialMusicStateFromStream() {
    final musicStatus =
        streamData?['livestreamdata']?['music_status'] ??
            streamData?['music_status'];
    final musicName =
        streamData?['livestreamdata']?['music_name'] ??
            streamData?['music_name'];
    final hostId =
        streamData?['livestreamdata']?['user_id'] ??
            streamData?['user_id'] ??
            broadcasterData['user']?['id'];

    if (musicStatus != null &&
        musicStatus.toString().isNotEmpty &&
        musicStatus.toString() != 'stopped' &&
        musicName != null &&
        musicName.toString().trim().isNotEmpty) {
      websocketController.liveMusicStatus.value = musicStatus.toString();
      websocketController.liveMusicName.value = musicName.toString();
      websocketController.liveMusicHostId.value =
          int.tryParse(hostId?.toString() ?? '0') ?? 0;
      websocketController.liveMusicPositionMs.value =
          int.tryParse(
            (streamData?['livestreamdata']?['music_position'] ??
                streamData?['music_position'] ??
                0)
                .toString(),
          ) ??
              0;
      websocketController.liveMusicDurationMs.value =
          int.tryParse(
            (streamData?['livestreamdata']?['music_duration'] ??
                streamData?['music_duration'] ??
                0)
                .toString(),
          ) ??
              0;
      websocketController.liveMusicVolume.value =
          int.tryParse(
            (streamData?['livestreamdata']?['music_volume'] ??
                streamData?['music_volume'] ??
                65)
                .toString(),
          ) ??
              65;

      if (!_effectiveBroadcaster) {
        liveLog('🎵 Initial live music state synced for audience: $musicName');
      }
    }
  }

  void _syncInitialYoutubeStateFromStream() {
    final youtubeStatus =
        streamData?['livestreamdata']?['youtube_status'] ??
            streamData?['youtube_status'];
    final youtubeUrl =
        streamData?['livestreamdata']?['youtube_url'] ??
            streamData?['youtube_url'];
    final youtubeVideoId =
        streamData?['livestreamdata']?['youtube_video_id'] ??
            streamData?['youtube_video_id'];
    final hostId =
        streamData?['livestreamdata']?['user_id'] ??
            streamData?['user_id'] ??
            broadcasterData['user']?['id'];

    final status = youtubeStatus?.toString() ?? 'stopped';
    final url = youtubeUrl?.toString() ?? '';
    final videoId = youtubeVideoId?.toString().isNotEmpty == true
        ? youtubeVideoId.toString()
        : liveController.extractYoutubeVideoId(url);

    if (status != 'stopped' && videoId.isNotEmpty) {
      websocketController.liveYoutubeStatus.value = status;
      websocketController.liveYoutubeUrl.value = url;
      websocketController.liveYoutubeVideoId.value = videoId;
      websocketController.liveYoutubeHostId.value =
          int.tryParse(hostId?.toString() ?? '0') ?? 0;

      if (!_effectiveBroadcaster) {
        liveLog('▶️ Initial YouTube state synced for audience: $videoId');
      }
    }
  }

  Future<void> _loadYoutubeStateFromServer() async {
    final sid = _currentStreamIdFromArgs();
    if (sid == 0) return;

    final data = await liveController.fetchYoutubeState(sid);
    if (data == null) {
      websocketController.liveYoutubeStatus.value = 'stopped';
      websocketController.liveYoutubeUrl.value = '';
      websocketController.liveYoutubeVideoId.value = '';
      _disposeYoutubeController();
      return;
    }

    final status = (data['youtube_status'] ?? 'stopped')
        .toString()
        .toLowerCase();
    final url = (data['youtube_url'] ?? '').toString();
    final videoId =
    (data['youtube_video_id'] ?? liveController.extractYoutubeVideoId(url))
        .toString();

    if (status != 'stopped' && videoId.isNotEmpty) {
      websocketController.liveYoutubeStatus.value = status;
      websocketController.liveYoutubeUrl.value = url;
      websocketController.liveYoutubeVideoId.value = videoId;
      websocketController.liveYoutubeHostId.value =
          int.tryParse((data['host_id'] ?? 0).toString()) ?? 0;
    } else {
      websocketController.liveYoutubeStatus.value = 'stopped';
      websocketController.liveYoutubeUrl.value = '';
      websocketController.liveYoutubeVideoId.value = '';
      _disposeYoutubeController();
      liveLog('▶️ YouTube state stopped/empty, local player cleared');
    }
  }

  bool get _isYoutubeActiveForSeatLayout {
    final status = _effectiveBroadcaster
        ? liveController.liveYoutubeStatus.value
        : websocketController.liveYoutubeStatus.value;
    final videoId = _effectiveBroadcaster
        ? liveController.liveYoutubeVideoId.value
        : websocketController.liveYoutubeVideoId.value;

    return (liveSeatCount == 9 || liveSeatCount == 12) &&
        status != 'stopped' &&
        videoId.trim().isNotEmpty;
  }

  YoutubePlayerController? _ensureYoutubeController({
    required String videoId,
    required String status,
  }) {
    if (videoId.trim().isEmpty || status == 'stopped') {
      _disposeYoutubeController();
      return null;
    }

    final normalizedStatus = status.toLowerCase().trim();
    final shouldPlay =
        normalizedStatus == 'playing' ||
            normalizedStatus == 'resumed' ||
            normalizedStatus == 'changed';

    if (_youtubeController == null || _loadedYoutubeVideoId != videoId) {
      _disposeYoutubeController();
      _loadedYoutubeVideoId = videoId;

      /// youtube_player_flutter Android WebView Errors[152] int/String crash fix.
      /// iframe package use korle video play smooth hoy and crash kom hoy.
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: shouldPlay,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: false,
          strictRelatedVideos: true,
          playsInline: true,
        ),
      );

      _lastYoutubeStatus = '';
    }

    final controller = _youtubeController;
    if (controller == null) return null;

    if (_lastYoutubeStatus != normalizedStatus) {
      _lastYoutubeStatus = normalizedStatus;
      _applyYoutubeStatusSafely(
        controller: controller,
        status: normalizedStatus,
      );
    }

    return controller;
  }

  void _applyYoutubeStatusSafely({
    required YoutubePlayerController controller,
    required String status,
  }) {
    final shouldPlay =
        status == 'playing' || status == 'resumed' || status == 'changed';

    void apply() {
      if (!mounted || _youtubeController != controller) return;

      try {
        controller.unMute();
        if (shouldPlay) {
          controller.playVideo();
        } else if (status == 'paused') {
          controller.pauseVideo();
        }
      } catch (e) {
        liveLog('⚠️ YouTube apply status ignored: $e');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    Future.delayed(const Duration(milliseconds: 450), apply);
    Future.delayed(const Duration(milliseconds: 1100), apply);
    Future.delayed(const Duration(milliseconds: 1800), apply);
  }

  void _disposeYoutubeController() {
    try {
      _youtubeController?.close();
    } catch (_) {}
    _youtubeController = null;
    _loadedYoutubeVideoId = '';
    _lastYoutubeStatus = 'stopped';
  }

  bool _snapshotHasFreshRoomState(Map<String, dynamic> map) {
    bool hasAnyKey(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        if (source.containsKey(key) && source[key] != null) return true;
      }
      return false;
    }

    const trustedKeys = [
      'locked_seats',
      'lockedSeats',
      'locked_seat_numbers',
      'lockedSeatNumbers',
      'host_audio_on',
      'host_is_muted',
      'audio_on',
      'is_muted',
      'total_gift_coins',
      'received_coins',
      'stream_coins',
      'gifts_coins',
      'livestream_callers',
    ];

    if (hasAnyKey(map, trustedKeys)) return true;

    final nestedLive =
        map['livestream'] ?? map['livestreamdata'] ?? map['data'];
    if (nestedLive is Map) {
      return hasAnyKey(Map<String, dynamic>.from(nestedLive), trustedKeys);
    }

    return false;
  }

  void _syncRoomSnapshotIfFresh(dynamic raw, {required String source}) {
    if (raw is! Map || raw.isEmpty) return;

    final map = Map<String, dynamic>.from(raw);

    /// Old navigation args often contain stale broadcaster/caller data.
    /// They were overwriting the fresh addViewer/live-list snapshot:
    /// - locked_seats [4,8] became fake seat [1]
    /// - host muted true became false
    /// - gift coin total disappeared/zero
    /// So init/broadcaster snapshots are applied only when they carry trusted
    /// root-level room state.
    final bool isOldInitSource =
        source.startsWith('audio_init_args_') ||
            source.startsWith('audio_stream_info_') ||
            source.startsWith('audio_broadcaster_data_');

    if (isOldInitSource && !_snapshotHasFreshRoomState(map)) {
      liveLog('⏭️ Stale room snapshot skipped => $source');
      return;
    }

    websocketController.syncRoomSnapshotForLateJoin(map, source: source);
  }

  Future<void> _syncLateJoinFullRoomState({String reason = 'manual'}) async {
    if (_lateJoinStateSyncRunning) {
      liveLog('♻️ Late join state sync skipped; already running => $reason');
      return;
    }

    final now = DateTime.now();
    final last = _lastLateJoinStateSyncAt;
    if (last != null && now.difference(last).inMilliseconds < 2500) {
      liveLog('♻️ Late join state sync throttled => $reason');
      return;
    }

    _lateJoinStateSyncRunning = true;
    _lastLateJoinStateSyncAt = now;

    try {
      final int sid = _currentStreamIdFromArgs();
      if (sid <= 0) return;

      websocketController.printSeatTrace(
        'late_join_sync_start',
        streamId: sid,
        userId: authController.userProfile.value.user?.id?.toInt(),
        reason: reason,
        beforeCount: websocketController.liveCallList.length,
      );
      websocketController.streamID.value = sid;
      websocketController.activeAudioStreamId.value = sid;

      /// 1) Apply only trusted/fresh navigation response.
      /// Stale init args must not override addViewer/current backend snapshot.
      _syncRoomSnapshotIfFresh(streamData, source: 'audio_init_args_$reason');

      _syncRoomSnapshotIfFresh(streamInfo, source: 'audio_stream_info_$reason');

      _syncRoomSnapshotIfFresh(
        broadcasterData,
        source: 'audio_broadcaster_data_$reason',
      );

      /// 2) Hydrate occupied seats first. This endpoint is the authoritative
      /// caller/seat snapshot for a newly joined viewer. Ancillary room state
      /// runs concurrently and must never delay avatar/seat visibility.
      await liveController.tryToGetCallList(streamId: sid, force: true);
      if (!mounted || _currentStreamIdFromArgs() != sid) return;

      final Future<void> ancillaryState = Future.wait<void>(<Future<void>>[
        _loadInitialSeatLocks(),
        websocketController.fetchInitialGiftTotal(streamId: sid),
        liveController.syncGuardianStateForRoom(streamId: sid),
      ]);

      /// 3) Tell backend this viewer joined/resumed so backend can broadcast current state.
      final currentCall = _currentUserCallData();
      final bool selfOnSeat = _effectiveBroadcaster || currentCall != null;

      await liveController.refreshLiveRoomRealtimeState(
        streamId: sid,
        role: _effectiveBroadcaster
            ? 'host'
            : selfOnSeat
            ? 'caller'
            : 'viewer',
        isOnSeat: selfOnSeat,
        seatNo: _effectiveBroadcaster
            ? 1
            : currentCall?['seat_no'] == null
            ? null
            : int.tryParse(currentCall?['seat_no'].toString() ?? ''),
      );
      await ancillaryState;

      websocketController.printSeatTrace(
        'late_join_sync_done',
        streamId: sid,
        userId: authController.userProfile.value.user?.id?.toInt(),
        reason: reason,
        afterCount: websocketController.liveCallList.length,
      );
    } catch (e) {
      websocketController.printSeatTrace(
        'late_join_sync_error',
        streamId: _currentStreamIdFromArgs(),
        userId: authController.userProfile.value.user?.id?.toInt(),
        reason: reason,
        error: e,
      );
    } finally {
      _lateJoinStateSyncRunning = false;
    }
  }

  Map<String, dynamic> _authUserEntryMap() {
    final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
    final dynamic profileUser = authController.userProfile.value.user;
    final userMap = <String, dynamic>{};

    try {
      final dynamic json = profileUser?.toJson();
      if (json is Map) {
        userMap.addAll(Map<String, dynamic>.from(json));
      }
    } catch (_) {}

    userMap['id'] ??= uid;
    userMap['user_id'] ??= uid;
    userMap['name'] ??= profileUser?.name ?? ('User').appTr;
    userMap['level'] ??= profileUser?.level ?? 0;
    userMap['gender'] ??= profileUser?.gender;
    userMap['profile_image'] ??= profileUser?.profileImage;
    userMap['is_online'] ??= true;

    return userMap;
  }

  void _showEntryAnimationDirect(Map<String, dynamic> entryData) {
    // Self entry must use the shared websocket helper.
    // It keeps the existing entry animation and also adds the current user's
    // JOINED activity to commentsList for LiveCommentsSection.
    final int selfUserId = _safeInt(
      entryData['user_id'] ?? entryData['viewer_id'] ?? entryData['id'],
    );

    try {
      websocketController.showEntryAnimationForViewer(
        entryData: Map<String, dynamic>.from(entryData),
        userId: selfUserId,
      );
      return;
    } catch (e) {
      liveLog(
        '⚠️ Shared self entry helper failed, direct animation fallback => $e',
      );
    }

    // Last-resort fallback: keep old local animation behavior.
    try {
      websocketController.newViewerAction.value = 'join';
      websocketController.newJoinedUserData
        ..clear()
        ..addAll(Map<String, dynamic>.from(entryData));
      websocketController.newJoinedUserData.refresh();
      websocketController.newViewersJoinded.value = true;
    } catch (e) {
      liveLog('⚠️ Direct self entry fallback failed => $e');
    }
  }

  void _showSelfEntryForCurrentRoom({String source = 'self_entry'}) {
    try {
      final int sid = _currentStreamIdFromArgs();
      final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (sid <= 0 || uid <= 0) return;

      if (_selfEntryShownForStreamId == sid) {
        liveLog('🛡️ Self entry already shown/skipped => $source stream:$sid');
        return;
      }

      Map<String, dynamic> userMap = _effectiveBroadcaster
          ? _hostVisualUserMap()
          : <String, dynamic>{};

      if (userMap.isEmpty) {
        userMap = _authUserEntryMap();
      } else {
        final authUserMap = _authUserEntryMap();
        _mergeNonEmptyUserMap(userMap, authUserMap);
      }

      userMap['id'] ??= uid;
      userMap['user_id'] ??= uid;
      userMap['is_online'] ??= true;

      final entryData = <String, dynamic>{
        'id': uid,
        'livestream_id': sid,
        'stream_id': sid,
        'viewer_id': uid,
        'user_id': uid,
        'is_active': true,
        'is_self_entry': true,
        'entry_source': source,
        'user': userMap,
      };

      _selfEntryShownForStreamId = sid;
      if (!_effectiveBroadcaster) {
        liveController.addOrUpdateViewerLocal(entryData, force: true);
      }
      _showEntryAnimationDirect(entryData);

      liveLog('✅ Self entry shown => $source stream:$sid user:$uid');
    } catch (e) {
      liveLog('⚠️ Self entry show skipped [$source] => $e');
    }
  }

  /// ✅ Self entry/viewer local fallback after addViewer API.
  /// Backend sometimes updates DB but does not echo viewer_joined back to the same device.
  /// This makes the joining user see his own entry animation immediately and keeps
  /// local viewer list synced until websocket/live-state arrives.
  void _showSelfEntryAfterViewerAdd(Map<String, dynamic>? addViewerResponse) {
    try {
      final int sid = _currentStreamIdFromArgs();
      final int uid = authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (sid <= 0 || uid <= 0) return;

      if (_selfEntryShownForStreamId == sid) {
        return;
      }

      Map<String, dynamic> asMap(dynamic v) {
        if (v is Map<String, dynamic>) return Map<String, dynamic>.from(v);
        if (v is Map) return Map<String, dynamic>.from(v);
        return <String, dynamic>{};
      }

      final Map<String, dynamic> response = addViewerResponse == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(addViewerResponse);

      Map<String, dynamic> viewerData = asMap(response['viewer_data']);
      if (viewerData.isEmpty) viewerData = asMap(response['viewer']);
      if (viewerData.isEmpty) viewerData = asMap(response['data']);
      if (viewerData['viewer'] is Map && viewerData['viewer_id'] == null) {
        viewerData = asMap(viewerData['viewer']);
      }

      Map<String, dynamic> userMap = asMap(viewerData['user']);
      final authUserMap = _authUserEntryMap();
      _mergeNonEmptyUserMap(userMap, authUserMap);

      userMap['id'] ??= uid;
      userMap['user_id'] ??= uid;
      userMap['is_online'] ??= true;

      viewerData['id'] ??= uid;
      viewerData['livestream_id'] = sid;
      viewerData['stream_id'] = sid;
      viewerData['viewer_id'] = uid;
      viewerData['user_id'] = uid;
      viewerData['is_active'] = true;
      viewerData['user'] = userMap;

      liveController.addOrUpdateViewerLocal(viewerData, force: true);
      _selfEntryShownForStreamId = sid;

      _showEntryAnimationDirect(viewerData);

      liveLog(
        '✅ Self viewer add fallback synced + entry shown => stream:$sid user:$uid',
      );
    } catch (e) {
      liveLog('⚠️ Self viewer entry fallback skipped => $e');
    }
  }

  /// ✅ Viewer list safety sync.
  /// Jodi viewer_joined event miss hoy (Pusher delay/drop), host/viewer UI backend
  /// authoritative live state diye sync hobe. Eta short window e chole, permanent
  /// heavy polling na.
  void _startViewerSafetySync({String reason = 'open'}) {
    _viewerSafetySyncTimer?.cancel();
    _audioJoinLoadingFallbackTimer?.cancel();
    _viewerSafetySyncTick = 0;

    final int sid = _currentStreamIdFromArgs();
    if (sid <= 0) return;

    // Server pressure fix: short safety sync only. Do not poll heavily forever.
    _viewerSafetySyncTimer = Timer.periodic(const Duration(seconds: 8), (
        timer,
        ) {
      if (!mounted || _isLiveExiting || _isLiveMinimized) {
        timer.cancel();
        return;
      }

      _viewerSafetySyncTick++;
      websocketController.printSeatTrace(
        'viewer_safety_tick',
        streamId: sid,
        userId: authController.userProfile.value.user?.id?.toInt(),
        reason: '${reason}_$_viewerSafetySyncTick',
      );
      _syncLateJoinFullRoomState(
        reason: 'viewer_safety_${reason}_$_viewerSafetySyncTick',
      );

      if (_viewerSafetySyncTick >= 2) {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Decode the small speaking animation once while the room initializes.
    // This is intentionally fire-and-forget and never delays joining Agora.
    unawaited(SpeakingWave.preload());
    unawaited(EntryAnimation.preloadVipEffect());
    streamData = widget.roomData != null
        ? Map<String, dynamic>.from(widget.roomData!)
        : Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments)
        : <String, dynamic>{};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.isRegistered<AudienceJoinController>()) {
        Get.find<AudienceJoinController>().markTargetRouteReady(
          streamId: _currentStreamIdFromArgs(),
        );
      }
      if (!kDebugMode) return;
      final String prefix = _effectiveBroadcaster ? 'create' : 'join';
      debugPrint(
        '${prefix}_first_ui_ready=${DateTime.now().microsecondsSinceEpoch}',
      );
    });

    // Platform calls and dependency registration must never run from build().
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!Get.isRegistered<MomentsController>()) {
      Get.put(MomentsController());
    }
    debugPrint('Current Livestream ID: ${_currentStreamIdFromArgs()}');
    // Enable wake lock to keep screen on during live streaming
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    _currentToken = widget.token;

    /// New live/open room start hole old room-er locked seats clear kore dibo.
    /// Same stream restore hole lock/frame/name state preserve thakbe.
    final int initStreamId = _currentStreamIdFromArgs();
    if (initStreamId > 0 &&
        websocketController.activeAudioStreamId.value != initStreamId) {
      websocketController.lockedSeatMap.clear();
      websocketController.lockedSeatMap.refresh();
    }

    liveLog(
      '🎨 AudioLiveView Room Data => '
          'seatCount: $liveSeatCount, layout: $liveRoomLayout, '
          'theme: $liveRoomTheme, background: $liveRoomBackground',
    );

    /// Theme/background API list load kore ID match korbe.
    liveController.showTheme();
    liveController.showBackground();

    // Initialize battery monitoring
    _initializeBatteryMonitoring();

    /// New live open/create hole previous room-er coin, PK, gift, viewer cache
    /// ekhanei clear kore dibo. Agora active stream id ekhono old thakbe,
    /// tai prepareForLive() bujhte parbe eta room switch kina.
    final int localResetStreamId = _currentStreamIdFromArgs();
    if (localResetStreamId > 0) {
      liveController.resetLocalLiveStateForNewStream(
        newStreamId: localResetStreamId,
        source: 'audio_live_init_before_agora',
      );
    }

    // Keep controller room snapshot equal to the room currently opened.
    // This prevents old own-live permission from leaking, and also lets
    // controller API guards verify the current room owner/admin correctly.
    try {
      liveController.createStreamData.value = _safeMap(streamData);
      liveController.createStreamData.refresh();
    } catch (_) {}

    // Mute state is controlled by backend/websocket/user toggle.
    // For a new live/opened room, resetAudioRoomStateForStream() clears stale
    // mute state. Same-room restore still preserves the user's actual mute.

    if (_effectiveBroadcaster) {
      liveController.isBroadcaster.value = true;
      setLiveStreamDataAsBroadcaster();
    } else {
      setLiveStreamDataAsAudience();
    }

    /// New room hole old room-er entry/comment/gift/seat/call data clear.
    /// Same room minimize theke back korle clear hobe na.
    final int currentStreamId = _currentStreamIdFromArgs();
    websocketController.resetAudioRoomStateForStream(
      newStreamId: currentStreamId,
    );
    liveController.setCanonicalViewerHost(
      hostUserId: _hostUserIdFromSnapshot(),
      roomId: currentStreamId,
      source: 'local',
    );

    /// Reset-er por current room-er broadcaster/caller seats abar seed.
    _seedCurrentRoomCallList();

    /// Late audience join korle DB theke current music/youtube status show.
    _syncInitialMusicStateFromStream();

    /// Initial values also seed websocket room edit state so host edit sheet and UI stay synced.
    final initialStreamId = _currentLiveStreamId;
    if (initialStreamId != 0) {
      final int initialSeatCount = _roomSeatCountFromOwnData;
      final int initialLayout = _roomLayoutFromOwnData;
      final int initialTheme = _roomThemeFromOwnData;
      final int initialBackground = _roomBackgroundFromOwnData;

      websocketController.updateLiveRoomSettings(
        livestreamId: initialStreamId,
        seatCount: initialSeatCount,
        roomLayout: initialLayout,
        roomTheme: initialTheme,
        roomBackground: initialBackground,
        streamTitle: _roomTitleFromOwnData,
        streamAnnouncement: _roomAnnouncementFromOwnData,
        streamImage: _roomImageFromOwnData,
        streamPassword: _roomPasswordFromOwnData,
      );
      liveLog(
        '🎨 Initial live room realtime values synced => '
            'stream:$initialStreamId theme:$initialTheme bg:$initialBackground',
      );
    }
    _syncInitialYoutubeStateFromStream();

    /// Start Agora only after current-room reset/seed is complete. Previously
    /// prepareForLive raced resetAudioRoomStateForStream(), so a rejoin could
    /// publish using one mute state and then let the UI reset to another state.
    prepareForLive();

    /// Late join/viewer der jonno current room full state sync.
    /// Lock/mute/gift coin old websocket event notun audience pabe na, tai open hole snapshot load must.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLateJoinFullRoomState(reason: 'post_frame_once');
      _loadYoutubeStateFromServer();
    });
    // Broadcaster ke viewer hisebe add korbo na. Audience join korle only viewer add hobe.
    // Ete host-er nijer profile viewer list-e dhukbe na, ar broadcaster side-e list clean thakbe.
    final int sidForViewer = _currentStreamIdFromArgs();
    final int currentUidForViewer =
        authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (!_effectiveBroadcaster && sidForViewer > 0 && currentUidForViewer > 0) {
      final args = _safeMap(streamData);
      final bool viewerAlreadyAdded = _truthy(args['audience_viewer_added']);
      final preAddedResponse = _safeMap(args['audience_viewer_response']);

      if (viewerAlreadyAdded) {
        _showSelfEntryAfterViewerAdd(preAddedResponse);
        _syncLateJoinFullRoomState(reason: 'viewer_pre_added');
        _startViewerSafetySync(reason: 'audience_join');
      } else {
        liveController
            .tryToAddViewer(
          streamId: sidForViewer,
          viewerId: currentUidForViewer,
        )
            .then((response) {
          _showSelfEntryAfterViewerAdd(response);
          _syncLateJoinFullRoomState(reason: 'after_viewer_add');
          _startViewerSafetySync(reason: 'audience_join');
        });
      }
    } else if (_effectiveBroadcaster && sidForViewer > 0) {
      // Host live create/open korar sathe sathe latest viewer/caller/list/gift/lock sync.
      // Nijer entry nijer screen-e show hobe; guard duplicate prevent korbe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_effectiveBroadcaster || _isLiveExiting) return;
        Future.delayed(const Duration(milliseconds: 520), () {
          if (!mounted || !_effectiveBroadcaster || _isLiveExiting) return;
          _showSelfEntryForCurrentRoom(source: 'host_open_init_guard');
        });
      });
      _syncLateJoinFullRoomState(reason: 'host_open');
      _startViewerSafetySync(reason: 'host_open');
    }

    /// Start presence heartbeat after current room + initial call list seed.
    /// API fail hole crash korbe na; controller internally catches errors.
    _startAudioLivePresenceHeartbeat();
  }

  void getActiveBroadcasterAudio({required List<dynamic> listActive}) async {
    final engine = _agoraService.engine;
    if (engine == null) return;

    final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (myId <= 0) return;

    bool meOnSeat = _effectiveBroadcaster;

    for (final activeCallData in listActive) {
      if (activeCallData is! Map) continue;

      final dynamic uidRaw = activeCallData['user'] is Map
          ? activeCallData['user']['id']
          : (activeCallData['caller_id'] ??
          activeCallData['user_id'] ??
          activeCallData['viewer_id'] ??
          activeCallData['id']);

      final int uid = int.tryParse(uidRaw?.toString() ?? '') ?? 0;
      final String status =
      (activeCallData['call_status'] ??
          activeCallData['status'] ??
          'accepted')
          .toString()
          .toLowerCase()
          .trim();

      final bool accepted =
          status == 'accepted' ||
              status == 'joined' ||
              status == 'active' ||
              status == 'live' ||
              status == 'on_seat';

      if (uid == myId && accepted) {
        meOnSeat = true;
        break;
      }
    }

    if (meOnSeat) {
      await _applyAgoraRoleOnce(
        ClientRoleType.clientRoleBroadcaster,
        source: 'getActiveBroadcasterAudio_safe',
      );
      await _forcePublishLocalMic(engine, reason: 'active_seat_detected');
    }
  }

  void removeBroadcaster() async {
    await _applyAgoraRoleOnce(
      ClientRoleType.clientRoleAudience,
      source: 'removeBroadcaster',
    );

    try {
      await _agoraService.engine?.muteLocalAudioStream(true);
    } catch (e) {
      liveLog('⚠️ removeBroadcaster mute ignored: $e');
    }
  }

  void _clearRemoteUserFromUi(int userId) {
    if (userId == 0) return;

    _setSpeakingStatus(uid: userId, isSpeaking: false);

    // Agora onUserOffline minimize/network switch/call change-er somoy temporary fire korte pare.
    // Tai ekhane seat/caller data clear korbo na. Real seat leave/remove event or API sync
    // liveCallList update korbe. Eta fix kore: minimize kore back ashle seated audience vanish hobe na.
    if (mounted) {
      _scheduleUIUpdate();
    }

    liveLog(
      'ℹ️ Remote user Agora offline only, seat kept until backend/event confirms: $userId',
    );
  }

  Future<void> _leaveAudienceRoomAndSeat({bool navigateBack = false}) async {
    if (_audienceLeaveRequested) return;
    _audienceLeaveRequested = true;

    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    final int streamIdValue = _currentStreamIdFromArgs();

    if (userId <= 0 || streamIdValue <= 0) {
      _audienceLeaveRequested = false;
      liveLog(
        '⚠️ audience leave skipped: userId=$userId streamId=$streamIdValue',
      );
      return;
    }

    bool sameUser(dynamic raw) {
      if (raw is! Map) return false;
      final nested = raw['user'] is Map ? raw['user']['id'] : null;
      final uid =
          raw['caller_id'] ?? raw['user_id'] ?? raw['viewer_id'] ?? nested;
      return uid?.toString() == userId.toString();
    }

    // IMPORTANT: read seat state before clearing local lists.
    final bool wasInSeat =
        websocketController.liveCallList.any(sameUser) ||
            liveController.callList.any(sameUser);

    try {
      if (wasInSeat) {
        await liveController.tryToRejectCall(
          streamId: streamIdValue,
          userId: userId,
        );
        liveLog('✅ Audience seat cleared before room exit: $userId');
      }

      await liveController.tryToRemoveViewer(
        streamId: streamIdValue,
        viewerId: userId,
      );

      // ✅ FIX (stale old seat after fast leave+rejoin, can't take a new
      // seat, seated user shows as empty): clearSpecificUserStreamData is
      // async and removes this user's own row from
      // websocketController.liveCallList — the SAME list _currentUserAlreadyOnMic()
      // (in LiveView_Circle_Container.dart) and switchAudioSeat's
      // occupied-seat check (in live_seat_controller.dart) both read to
      // decide "is this user already seated" / "is this seat free". It was
      // previously called without awaiting it, so this whole leave flow
      // (and therefore the point where the user is free to navigate back
      // in and tap a seat) could finish before that removal had actually
      // happened. A fast rejoin then saw the stale old-seat row still
      // present: their profile kept showing on the old seat, and any new
      // seat tap got routed through "switch" logic (which also gets
      // confused by the stale row) instead of a fresh seat request.
      await websocketController.clearSpecificUserStreamData(
        userId: userId.toString(),
        rejectCallIfInCallList: false,
        removeAcceptedCall: true,
        closePopupIfOpen: false,
        removeViewer: true,
        reason: 'audience_full_room_exit',
      );

      // ✅ FIX (fast rejoin shows me still on my old seat): clearSpecificUserStreamData
      // above only clears this user's row from websocketController.liveCallList.
      // _currentUserCallData() — which the UI uses to decide "is the current
      // user on a seat" for seat-grid rendering, mic publishing, and presence
      // heartbeat — also falls back to checking liveController.callList (a
      // separate list, populated from the room's REST snapshot) when the
      // websocket list doesn't have a match. That fallback list was never
      // being cleared on exit, so a fast rejoin could still find this user's
      // pre-leave accepted-seat row sitting in it and incorrectly treat them
      // as still seated — until something else (like refreshing the outer
      // room list, which re-fetches and overwrites this list) happened to
      // clear it first. Removing this user's own row here closes that gap.
      try {
        liveController.callList.removeWhere(sameUser);
      } catch (e) {
        liveLog('⚠️ callList self-row cleanup skipped safely: $e');
      }

      liveController.updateLivePresenceRole(
        role: 'viewer',
        isOnSeat: false,
        seatNo: null,
      );
      liveController.stopLivePresenceHeartbeat();

      // ✅ FIX: previously streamID/streamId only ever got reset to 0 (and
      // only activeAudioStreamId at that) after the async Agora
      // leaveChannel() call below finished. dispose() cannot await, so it
      // calls this whole function fire-and-forget — if the user re-tapped
      // the SAME room quickly (before that async cleanup finished),
      // joinAsAudience's "already in this room" early-return guard saw
      // stale-but-still-matching stream ids together with
      // AgoraService().isJoinedChannel still true, and silently no-op'd the
      // rejoin (viewer list/seat/entry then showed nothing until something
      // else — like browsing away and back — happened to give the async
      // cleanup enough time to finish first). Clearing the stream-id
      // trackers synchronously here, right before the slow async call,
      // closes that window: a rejoin attempted mid-cleanup no longer
      // matches, regardless of how long the Agora-side leave takes.
      // Guarded so a newer session that already moved on is never
      // clobbered.
      if (websocketController.streamID.value == streamIdValue) {
        websocketController.streamID.value = 0;
      }
      if (liveController.streamId.value == streamIdValue) {
        liveController.streamId.value = 0;
      }
      if (websocketController.activeAudioStreamId.value == streamIdValue) {
        websocketController.activeAudioStreamId.value = 0;
      }

      try {
        await _agoraService.leaveChannel();
      } catch (e) {
        liveLog('⚠️ Agora leave audience ignored: $e');
      }

      _agoraChannelJoined = false;
      websocketController.activeAudioStreamId.value = 0;

      if (navigateBack && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      liveLog('❌ Audience full room exit failed: $e$st');
    } finally {
      // Keep true while route is closing; reset only when staying on page.
      if (!navigateBack && mounted) {
        _audienceLeaveRequested = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    liveLog('📱 AudioLiveView lifecycle changed: $state');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isAppInBackground = true;
      _audioInterruptionStartedAt ??= DateTime.now();

      /// BIGO-style background/minimize:
      /// - live leave/offline/viewer_remove/caller_left hobe na
      /// - Agora channel keep thakbe
      /// - heartbeat slow interval e cholbe
      /// - websocket reconnect spam pause thakbe
      try {
        liveController.setLivePresenceBackgroundMode(true);
      } catch (e) {
        liveLog('⚠️ Background heartbeat mode failed safely: $e');
      }

      try {
        websocketController.pauseUnifiedLiveStreamReconnectForBackground();
      } catch (e) {
        liveLog('⚠️ WS background pause failed safely: $e');
      }

      liveLog('✅ Audio live kept active in background/minimize');
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isAppInBackground = false;

      unawaited(
        _agoraService.refreshAgoraTokenIfDue(reason: 'audio_live_resumed'),
      );

      final DateTime now = DateTime.now();
      final DateTime? interruptedAt = _audioInterruptionStartedAt;
      final Duration interruptionDuration = interruptedAt == null
          ? Duration.zero
          : now.difference(interruptedAt);
      _audioInterruptionStartedAt = null;

      _schedulePostResumeAudioRecovery(interruptionDuration);

      try {
        liveController.setLivePresenceBackgroundMode(false);
      } catch (e) {
        liveLog('⚠️ Foreground heartbeat mode failed safely: $e');
      }

      try {
        websocketController.resumeUnifiedLiveStreamReconnectAfterForeground();
      } catch (e) {
        liveLog('⚠️ WS foreground resume failed safely: $e');
      }

      _recoverLiveRoomAfterResume();
      _syncAudioLivePresenceAfterResume();
    }
  }

  Future<void> _recoverLiveRoomAfterResume() async {
    if (_isLiveExiting || _resumeRecoveryRunning) return;

    _resumeRecoveryRunning = true;

    try {
      websocketController.printSeatTrace(
        'resume_recovery_start',
        streamId: _currentStreamIdFromArgs(),
        userId: authController.userProfile.value.user?.id?.toInt(),
        status: liveController.currentPresenceRole,
        seatNo: liveController.currentPresenceSeatNo,
      );

      websocketController.tryToConnectToUnifiedLiveStreamEventWs(force: false);

      final int sid =
          int.tryParse(streamInfo['id']?.toString() ?? '') ??
              liveController.streamId.value;

      if (sid != 0) {
        await liveController.tryToGetCallList(streamId: sid);
        websocketController.printSeatTrace(
          'resume_call_list_loaded',
          streamId: sid,
          userId: authController.userProfile.value.user?.id?.toInt(),
          status: liveController.currentPresenceRole,
          seatNo: liveController.currentPresenceSeatNo,
        );
        await liveController.showLiveViewerListList(streamId: sid);
        await liveController.getAvailableSeats(sid);
        await liveController.fetchYoutubeState(sid);
        await _loadInitialSeatLocks();
        await _loadYoutubeStateFromServer();

        /*
        |--------------------------------------------------------------------------
        | Do not demote caller from a single resume snapshot
        |--------------------------------------------------------------------------
        | Background timers and API snapshots may arrive late. If the user was a
        | caller before backgrounding, repair caller heartbeat and verify twice.
        |--------------------------------------------------------------------------
        */
        if (!_effectiveBroadcaster && !_isCurrentUserOnAnySeat()) {
          final int rememberedSeat = liveController.currentPresenceSeatNo ?? 0;

          if (liveController.currentPresenceRole == 'caller' &&
              rememberedSeat > 0) {
            liveController.updateLivePresenceRole(
              role: 'caller',
              isOnSeat: true,
              seatNo: rememberedSeat,
            );

            await liveController.sendPresenceHeartbeatOnce(
              livestreamId: sid,
              role: 'caller',
              isOnSeat: true,
              seatNo: rememberedSeat,
            );

            await Future.delayed(const Duration(seconds: 2));
            await liveController.tryToGetCallList(streamId: sid);

            if (!_isCurrentUserOnAnySeat()) {
              await Future.delayed(const Duration(seconds: 3));
              await liveController.tryToGetCallList(streamId: sid);
            }
          }
        }
      }

      final engine = _agoraService.engine;
      if (engine != null) {
        /// IMPORTANT:
        /// App resume/network recover er somoy engine already joined thakte pare.
        /// Joined engine e abar setChannelProfile() call korle Agora -8 error dey.
        /// Tai recover e channel profile set korbo na; eta prepareForLive()/join options e already set ase.
        final bool resumeAsBroadcaster =
            _effectiveBroadcaster ||
                _isCurrentUserOnAnySeat() ||
                liveController.currentPresenceRole == 'caller';

        await _applyAgoraRoleOnce(
          resumeAsBroadcaster
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          source: 'resume_recovery',
        );

        try {
          /// Host/caller mute korleo audio track open thakbe, mic volume 0/100 diye control.
          final bool isOnSeatNow = _shouldPublishCurrentUserMicrophone();
          final role = isOnSeatNow
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience;
          try {
            await engine.updateChannelMediaOptions(
              ChannelMediaOptions(
                clientRoleType: role,
                publishMicrophoneTrack: isOnSeatNow,
                autoSubscribeAudio: true,
              ),
            );
          } catch (e) {
            liveLog('⚠️ Agora resume media options ignored: $e');
          }
          await engine.enableAudio();
          await engine.enableAudioVolumeIndication(
            interval: 600,
            smooth: 3,
            reportVad: true,
          );
          await engine.muteLocalAudioStream(!isOnSeatNow);
          await engine.adjustRecordingSignalVolume(
            (isOnSeatNow && !liveController.mute.value) ? 100 : 0,
          );
          for (final raw in websocketController.liveCallList) {
            if (raw is! Map) continue;
            final uid =
                int.tryParse(
                  (raw['caller_id'] ??
                      raw['user_id'] ??
                      (raw['user'] is Map ? raw['user']['id'] : null))
                      ?.toString() ??
                      '',
                ) ??
                    0;
            if (uid > 0) {
              await engine.muteRemoteAudioStream(uid: uid, mute: false);
            }
          }
        } catch (e) {
          liveLog('⚠️ Agora resume mic/audio state ignored: $e');
        }

        // The fresh API snapshot is now applied. Reconfirm the caller role and
        // microphone publication using both seat list and presence state.
        await _recoverAudioAfterExternalCall(
          reason: 'resume_after_room_state_sync',
          hardRestartAudioDevice: false,
        );

        if (liveController.isLiveMusicPlaying) {
          try {
            await engine.adjustAudioMixingVolume(80);
            await engine.adjustAudioMixingPlayoutVolume(80);
            await engine.adjustAudioMixingPublishVolume(80);
          } catch (e) {
            liveLog('⚠️ Agora resume music volume ignored: $e');
          }
        }
      } else {
        liveLog('⚠️ Agora engine null on resume, preparing live again...');
        await prepareForLive();
      }

      if (mounted) setState(() {});
      liveLog('✅ Audio live room recovered after resume');
    } catch (e, st) {
      liveLog('❌ Audio live room recover failed: $e\n$st');
    } finally {
      _resumeRecoveryRunning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _musicMiniOffset.dispose();
    // Battery Optimization: Cancel timers
    _batteryCheckTimer?.cancel();
    _uiUpdateTimer?.cancel();
    _viewerSafetySyncTimer?.cancel();
    _audioJoinLoadingFallbackTimer?.cancel();
    _postResumeAudioRecoveryTimer?.cancel();
    _postResumeAudioRecoveryConfirmTimer?.cancel();
    _postJoinMicRestoreTimer?.cancel();
    _postJoinMicRestoreConfirmTimer?.cancel();

    _speakingExpiryTimer?.cancel();
    _speakingExpiryTimer = null;
    _speakingUntilMs.clear();
    _speakingUserIds.clear();

    // Disable wake lock to restore normal screen behavior
    WakelockPlus.disable();

    /// Minimize korle live active thakbe.
    /// Tai ping stop, viewer remove, Agora leave korbo na.
    if (_isHostLeavingRoomOnly) {
      /// Host normal leave/back/mini-close.
      /// Live active thakbe, tai backend offline/remove/end API call korbo na.
      _miniLiveOverlay?.remove();
      _miniLiveOverlay = null;
      liveController.stopPingUpdate();
      liveController.stopLivePresenceHeartbeat();
      liveController.isBroadcaster.value = false;
      liveLog('✅ Host dispose skipped offline/end: live kept active');
    } else if (_isLiveExiting) {
      _miniLiveOverlay?.remove();
      _miniLiveOverlay = null;
      liveController.isBroadcaster.value = false;
      liveController.stopPingUpdate();
      liveController.stopLivePresenceHeartbeat();
      liveController.stopLive();

      /// Explicit exit/end only: backend offline/remove/end korte parbe.
      _markAudioLiveOfflineForExplicitExit();

      if (!_effectiveBroadcaster) {
        /// Fire-and-forget because dispose cannot await.
        _leaveAudienceRoomAndSeat();
      } else {
        _agoraService.leaveChannel();
        _agoraChannelJoined = false;
        _clearGlobalAgoraJoinedStream(streamId: _localAgoraStreamId);
      }
    } else {
      /// Background/minimize/unexpected dispose: live session keep.
      /// Offline API call, viewer remove, list clear, Agora leave korbo na.
      liveLog(
        '✅ Audio live dispose without explicit exit/background: keeping live session',
      );
    }

    _disposeYoutubeController();

    super.dispose();
  }

  Future<void> _minimizeLiveRoom() async {
    _isLiveMinimized = true;

    _showMiniLiveBubble();

    if (mounted) {
      Navigator.of(context).pop();
    }

    Fluttertoast.showToast(
      msg: ('Live minimized').appTr,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  /// Host normal exit/back/mini close: keep live active.
  /// Important: This function does NOT call tryToRemoveLivestream(),
  /// does NOT broadcast live_ended, and does NOT remove live from list.
  Future<void> _leaveHostRoomOnlyKeepLive({bool navigateBack = true}) async {
    if (_isLiveExiting) return;

    _isLiveExiting = false;
    _isHostLeavingRoomOnly = true;
    _isLiveMinimized = false;
    _postJoinMicRestoreTimer?.cancel();
    _postJoinMicRestoreConfirmTimer?.cancel();

    try {
      debugPrint(
        '[LIVE_LEAVE][START] room=${_currentStreamIdFromArgs()} '
            'remove_livestream=false',
      );
      _miniLiveOverlay?.remove();
      _miniLiveOverlay = null;

      /// Host nijer device theke Agora channel leave korbe only.
      /// Audience/live list active thakbe.
      try {
        await _agoraService.engine?.muteLocalAudioStream(true);
        await _agoraService.leaveChannel();
        _agoraChannelJoined = false;
        _clearGlobalAgoraJoinedStream(streamId: _localAgoraStreamId);
      } catch (e) {
        liveLog('⚠️ host leaveChannel ignored: $e');
      }

      /// Room remains active, but this device must stop host heartbeat.
      /// Backend will keep the permanent room listed with host_online=false.
      liveController.stopPingUpdate();
      liveController.stopLivePresenceHeartbeat();
      await liveController.leavePermanentRoom(
        livestreamId: _currentStreamIdFromArgs(),
      );
      if (kDebugMode) {
        debugPrint(
          '[LIVE_SESSION][SOFT_LEAVE] room=${_currentStreamIdFromArgs()} '
              'backend_room_preserved=true',
        );
      }
      liveController.isBroadcaster.value = false;

      if (mounted && navigateBack) {
        Get.back();
      }

      liveLog('✅ Host left room only, live kept active');
      debugPrint(
        '[LIVE_LEAVE][SUCCESS] room=${_currentStreamIdFromArgs()} '
            'remove_livestream=false',
      );
    } catch (e) {
      liveLog('❌ Host leave room only error: $e');
      Fluttertoast.showToast(msg: ('Exit failed').appTr);
    } finally {
      Future.delayed(const Duration(milliseconds: 1200), () {
        _isLiveExiting = false;
      });
    }
  }

  Future<void> _exitLiveRoomNow() async {
    if (_isLiveExiting) return;

    _isLiveExiting = true;
    _isHostLeavingRoomOnly = false;
    _isLiveMinimized = false;

    try {
      _miniLiveOverlay?.remove();
      _miniLiveOverlay = null;

      final int closingRoomId = _currentStreamIdFromArgs();
      if (_effectiveBroadcaster) {
        final bool closed = await liveController.closePermanentRoom(
          livestreamId: closingRoomId,
          navigateToEnd: false,
          deferLocalCleanup: true,
        );
        if (!closed) return;

        await liveController.stopLiveMusic(rtcEngine: _agoraService.engine);
        await liveController.stopYoutube();
        try {
          await _agoraService.leaveChannel();
          _agoraChannelJoined = false;
          _clearGlobalAgoraJoinedStream(streamId: _localAgoraStreamId);
        } catch (e) {
          liveLog('⚠️ leaveChannel after close ignored: $e');
        }
        liveController.livePermanentRoomController.completeDeferredCloseCleanup(
          closingRoomId,
        );
        debugPrint('[LIVE_CLOSE][SUCCESS] room=$closingRoomId');
        Get.offAll(
              () => const Endlive(),
          arguments: liveController
              .livePermanentRoomController
              .lastPermanentRoomActionData
              .value,
          transition: Transition.cupertino,
        );
        return;
      }

      /// Local cleanup first. Duplicate leaveChannel ignored.
      try {
        await _agoraService.leaveChannel();
        _agoraChannelJoined = false;
        _clearGlobalAgoraJoinedStream(streamId: _localAgoraStreamId);
      } catch (e) {
        liveLog('⚠️ leaveChannel ignored: $e');
      }

      liveController.isBroadcaster.value = false;
      liveController.stopPingUpdate();
      liveController.stopLivePresenceHeartbeat();
      await _markAudioLiveOfflineForExplicitExit();

      await _leaveAudienceRoomAndSeat(navigateBack: true);
    } catch (e) {
      liveLog('❌ Exit live error: $e');
      Fluttertoast.showToast(msg: ('Exit failed').appTr);
    } finally {
      /// Keep true for this frame because controller may be removing route now.
      Future.delayed(const Duration(milliseconds: 1200), () {
        _isLiveExiting = false;
      });
    }
  }

  /// Mini bubble: bottom-er upor choto profile + close.
  /// Drag/drop kore user jekhane khushi sorate parbe.
  /// Profile click korle abar audio live room open hobe.
  void _showMiniLiveBubble() {
    _miniLiveOverlay?.remove();
    _miniLiveOverlay = null;

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    if (_miniBubbleOffset == Offset.zero) {
      _miniBubbleOffset = Offset(
        screenSize.width - 88,
        screenSize.height - 170,
      );
    }

    final user = broadcasterData['user'] is Map ? broadcasterData['user'] : {};
    final profile = ImageHelper.getImageUrl('${user['profile_image'] ?? ''}');

    _miniLiveOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: _miniBubbleOffset.dx,
          top: _miniBubbleOffset.dy,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onPanStart: (_) {
                    _miniBubbleDragging = true;
                  },
                  onPanUpdate: (details) {
                    final maxX = MediaQuery.of(context).size.width - 76;
                    final maxY = MediaQuery.of(context).size.height - 130;

                    _miniBubbleOffset = Offset(
                      (_miniBubbleOffset.dx + details.delta.dx).clamp(
                        8.0,
                        maxX,
                      ),
                      (_miniBubbleOffset.dy + details.delta.dy).clamp(
                        70.0,
                        maxY,
                      ),
                    );

                    _miniLiveOverlay?.markNeedsBuild();
                  },
                  onPanEnd: (_) {
                    Future.delayed(const Duration(milliseconds: 90), () {
                      _miniBubbleDragging = false;
                    });
                  },
                  onTap: () {
                    if (_miniBubbleDragging) return;

                    _miniLiveOverlay?.remove();
                    _miniLiveOverlay = null;

                    Get.to(
                          () => AudioLiveView(
                        channelName: widget.channelName,
                        isBroadcaster: _effectiveBroadcaster,
                        token:
                        (_agoraService.currentAgoraToken
                            ?.trim()
                            .isNotEmpty ??
                            false)
                            ? _agoraService.currentAgoraToken!.trim()
                            : ((_currentToken?.trim().isNotEmpty ?? false)
                            ? _currentToken!.trim()
                            : widget.token),
                        seatCount: widget.seatCount,
                        roomLayout: widget.roomLayout,
                        roomTheme: widget.roomTheme,
                        roomBackground: widget.roomBackground,
                      ),
                      arguments: streamData,
                      transition: Transition.rightToLeft,
                    );
                  },
                  child: Container(
                    height: 62,
                    width: 62,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xffff6dc8),
                          Color(0xff7b35f2),
                          Color(0xff35d4ff),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: profile,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.white,
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),

                /// Mini close button => live end/leave.
                Positioned(
                  right: -5,
                  top: -5,
                  child: GestureDetector(
                    onTap: () async {
                      _miniLiveOverlay?.remove();
                      _miniLiveOverlay = null;
                      if (_effectiveBroadcaster) {
                        await _leaveHostRoomOnlyKeepLive();
                      } else {
                        await _exitLiveRoomNow();
                      }
                    },
                    child: Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.18),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    height: 18,
                    width: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xff7BD55A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(_miniLiveOverlay!);
  }

  void _closeCurrentSheetSafely() {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  Future<String?> _showBroadcasterRoomExitChoice() {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          ('Room Options').appTr,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          ('Leave Room keeps the permanent room active. Close Room ends it for everyone.')
              .appTr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(('Cancel').appTr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('leave'),
            child: Text(
              ('Leave Room').appTr,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('close'),
            child: Text(
              ('Close Room').appTr,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showLiveMinimizeExitPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Live Control',
      barrierColor: Colors.black.withOpacity(
        0.10,
      ), // background almost same thakbe
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, anim1, anim2) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: kWeight * 0.72,
                padding: EdgeInsets.symmetric(
                  horizontal: kWeight * 0.045,
                  vertical: kHeight * 0.022,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _centerLiveActionButton(
                      title: ('Minimize').appTr,
                      icon: Icons.open_in_full_rounded,
                      bg: const Color(0xffffd719),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _minimizeLiveRoom();
                      },
                    ),

                    SizedBox(height: kHeight * 0.08),

                    _centerLiveActionButton(
                      title: _effectiveBroadcaster
                          ? ('Room Options').appTr
                          : ('Exit').appTr,
                      icon: Icons.exit_to_app_rounded,
                      bg: const Color(0xffffd719),
                      iconColor: Colors.white,
                      onTap: () async {
                        Navigator.of(dialogContext).pop();

                        if (_effectiveBroadcaster) {
                          final choice = await _showBroadcasterRoomExitChoice();
                          if (choice == 'leave') {
                            await _leaveHostRoomOnlyKeepLive();
                          } else if (choice == 'close') {
                            await _exitLiveRoomNow();
                          }
                          return;
                        }

                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (alertContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            title: Text(
                              ('Leave Live').appTr,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            content: Text(
                              ('Are you sure you want to leave this live?')
                                  .appTr,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(alertContext).pop(false),
                                child: Text(('Cancel').appTr),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(alertContext).pop(true),
                                child: Text(
                                  ('Exit').appTr,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await _exitLiveRoomNow();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _centerLiveActionButton({
    required String title,
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            height: kWeight * 0.17,
            width: kWeight * 0.17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bg.withOpacity(1), kAppColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: bg.withOpacity(0.45),
                  blurRadius: 22,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: kWeight * 0.1),
          ),
          SizedBox(height: kHeight * 0.008),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: kHeight * 0.019,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveControlButton({
    required String title,
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: kHeight * 0.055,
            width: kHeight * 0.055,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withOpacity(.15)),
            ),
            child: Icon(icon, color: iconColor, size: kHeight * 0.025),
          ),
          SizedBox(height: kHeight * 0.006),
          Text(
            title,
            style: GoogleFonts.roboto(
              color: iconColor,
              fontSize: kHeight * 0.011,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  int _luckySafeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _luckySafeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  String _luckyFirstText(List<dynamic> values) {
    for (final value in values) {
      final text = _luckySafeText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _openGlobalLuckyBagRoom(int livestreamId, Map<String, dynamic> packet) {
    if (livestreamId <= 0) {
      Fluttertoast.showToast(
        msg: ('Live room not found').appTr,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
      return;
    }

    final sender = packet['sender'] is Map
        ? Map<String, dynamic>.from(packet['sender'])
        : <String, dynamic>{};

    final int ownerId = _luckySafeInt(
      packet['owner_user_id'] ??
          packet['user_id'] ??
          packet['sender_id'] ??
          sender['id'] ??
          sender['user_id'],
    );

    final String channelName = _luckyFirstText([
      packet['room_id'],
      packet['channel_name'],
      packet['agora_channel'],
      packet['agora_channel_name'],
      packet['live_channel'],
      ownerId,
    ]);

    if (channelName.isEmpty) {
      Fluttertoast.showToast(
        msg: ('Live room data missing').appTr,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
      return;
    }

    final delayCandidates = <int>[
      _luckySafeInt(packet['unlock_after_seconds']),
      _luckySafeInt(packet['open_after_seconds']),
      _luckySafeInt(packet['unlock_after']),
      _luckySafeInt(packet['open_after']),
    ].where((e) => e > 0).toList()..sort();
    final int safeOpenAfter = delayCandidates.isNotEmpty
        ? delayCandidates.first
        : 30;

    final Map<String, dynamic> liveData = <String, dynamic>{
      ...packet,
      'id': livestreamId,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'room_id': channelName,
      'channel_name': channelName,
      'agora_channel': channelName,
      'agora_channel_name': channelName,
      'owner_user_id': ownerId,
      'user_id': ownerId,
      // Use the fastest valid unlock delay from the banner packet.
      // Backend/event can send open_after_seconds=30 and unlock_after_seconds=3;
      // the UI must follow 3 seconds, not overwrite it back to 30.
      'open_after_seconds': safeOpenAfter,
      'unlock_after_seconds': safeOpenAfter,
      'event_received_at_ms':
      packet['event_received_at_ms'] ??
          DateTime.now().millisecondsSinceEpoch,
      'stream_type': _luckySafeText(packet['stream_type']).isEmpty
          ? 'audio'
          : _luckySafeText(packet['stream_type']),
      if (sender.isNotEmpty) 'user': sender,
      if (sender.isNotEmpty) 'User': sender,
    };

    /// ✅ Make the Lucky Bag available instantly in the target room. The global
    /// websocket event can be ignored by current-stream guard while the user is
    /// outside the room, so seed it manually before/without navigation.
    try {
      websocketController.currentRedPacket.value = Map<String, dynamic>.from(
        liveData,
      );
      websocketController.redPacketVisible.value = true;
      websocketController.currentRedPacket.refresh();
    } catch (_) {}

    final int currentStreamId = _currentStreamIdFromArgs();
    final bool alreadyInSameRoom =
        currentStreamId == livestreamId ||
            liveController.streamId.value == livestreamId ||
            websocketController.streamID.value == livestreamId ||
            websocketController.activeAudioStreamId.value == livestreamId;

    if (alreadyInSameRoom) {
      Fluttertoast.showToast(
        msg: ('Lucky Bag is ready').appTr,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
      return;
    }

    final AudienceJoinController joinController =
    Get.isRegistered<AudienceJoinController>()
        ? Get.find<AudienceJoinController>()
        : Get.put(AudienceJoinController());

    joinController.joinAsAudience(channelName: channelName, data: liveData);
  }

  //for live stream end
  @override
  Widget build(BuildContext context) {
    String fullName = broadcasterData['user']['name'];

    String shortName;

    List parts = fullName.split(' ');

    if (parts.length > 1) {
      // প্রথম অংশ (emoji + নাম)
      shortName = parts[0] + '..';
    } else {
      shortName = fullName;
    }
    return WillPopScope(
      onWillPop: () async {
        if (_backNavigationPending || _isLiveExiting || !mounted) return false;
        _backNavigationPending = true;
        try {
          // ✅ Entry/SVGA animation finish hole kono Navigator.pop/Get.back call ashle
          // leave room popup show korbe na. Entry overlay inline widget, route/dialog na.
          if (websocketController.newViewersJoinded.value == true) {
            websocketController.hideEntryAnimation();
            return false;
          }

          if (_effectiveBroadcaster) {
            final choice = await _showBroadcasterRoomExitChoice();
            if (choice == 'leave') {
              await _leaveHostRoomOnlyKeepLive(navigateBack: false);
              return true;
            } else if (choice == 'close') {
              await _exitLiveRoomNow();
            }
          } else {
            final bool? exitLive = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                title: Text(
                  ('Leave Live').appTr,
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  ('Are you sure you want to leave this live?').appTr,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(
                      ('No').appTr,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      ('Yes').appTr,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (exitLive == true) await _exitLiveRoomNow();
          }

          /// Navigation manually handle kora hocche.
          /// true return korle system route pop kore Navigator history empty crash dite pare.
          return false;
        } finally {
          _backNavigationPending = false;
        }
      },
      child: Scaffold(
        backgroundColor: Color(0xffa19597),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Keep only the background layer reactive. This guarantees that
            // the temporary Room Background sidebar preview appears instantly
            // on the Audio room while the rest of the live UI does not rebuild.
            Obx(() {
              widget.roomBackground; // stable fallback dependency
              websocketController.liveRoomUpdateStreamId.value;
              websocketController.liveRoomBackground.value;
              return AudioRoomReactiveBackground(
                childBuilder: _roomBackgroundWidget,
              );
            }),
            Positioned(
              top: kHeight * 0.09,
              bottom: kHeight * 0.115,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // -------------------- Receive   coin ---------------
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Get.to(
                              Allrank(),
                              transition: Transition.rightToLeft,
                            );
                          },
                          child: Obx(
                                () => TaskLiveProfile(
                              text: _formatCoins(_hostReceiveCoins()),
                              seccondtext: 'Receive : ',
                            ),
                          ),
                        ),
                        broadcasterData['user']['id'] ==
                            authController.userProfile.value.user!.id
                            ? Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: kWeight * 0.03,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Color(0xff0c0c0c).withOpacity(0.4),
                          ),
                          child: Obx(
                                () => Castontext(
                              fontSize: kHeight * 0.015,
                              textColor: liveController.isLive.value
                                  ? const Color(
                                0xff00ff00,
                              ) // Live active = green
                                  : const Color(
                                0xff808080,
                              ), // Inactive = gray
                              text: liveController.formattedTime,
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
                            margin: EdgeInsets.only(right: kWeight * 0.04),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(

                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xff0c0c0c).withOpacity(.4),
                                  Color(0xff0c0c0c).withOpacity(.4),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ('Current:').appTr,
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                    fontSize: kHeight * 0.012,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Obx(
                                      () => Text(
                                    _formatCoins(_currentRoomReceivedCoins()),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: kHeight * 0.014,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // _canManageCurrentRoom
                        //     ? InkWell(
                        //   onTap: () {
                        //     Get.to(RoomSettingsPage());
                        //   },
                        //   child: Container(
                        //     padding: EdgeInsets.symmetric(
                        //       vertical: 6,
                        //       horizontal: 6,
                        //     ),
                        //     decoration: BoxDecoration(
                        //       borderRadius: BorderRadius.circular(10),
                        //       color: Colors.black45,
                        //     ),
                        //     child: Row(
                        //       children: [
                        //         Text(
                        //           ('Setting').appTr,
                        //           style: GoogleFonts.poppins(
                        //             color: Colors.white,
                        //             fontSize: kHeight * 0.015,
                        //           ),
                        //         ),
                        //         SizedBox(width: 7),
                        //         Icon(
                        //           Icons.settings,
                        //           color: Colors.white,
                        //           size: kHeight * 0.017,
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // )
                        //     : SizedBox.shrink(),
                      ],
                    ),
                  ),
                  SizedBox(height: kHeight * 0.01),

                  ///---------------------------- YouTube + Audio set Section -----------------
                  LiveYoutubePlayerSection(
                    isBroadcaster: _canManageCurrentRoom,
                    liveSeatCount: liveSeatCount,
                    liveController: liveController,
                    websocketController: websocketController,
                  ),
                  Obx(
                        () => SizedBox(
                      height: _isYoutubeActiveForSeatLayout
                          ? kHeight * 0.01
                          : kHeight * 0.02,
                    ),
                  ),
                  _reactiveAudioSeatBoard(),
                  SizedBox(height: kHeight * 0.004),

                  /// Comment timeline is in the same vertical flow as the seat board.
                  /// Therefore 9/12/15/20 seats automatically consume their own
                  /// height first, and comments start immediately below the last row.
                  Expanded(
                    child: AudioRoomLayerBoundary(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: LiveCommentsSection(
                                broadcasterData: broadcasterData,
                                streamType: 'audio',
                              ),
                            ),
                            SizedBox(width: kWeight * 0.025),
                            if (coinValue > 0)
                              SizedBox(
                                width: kHeight * 0.090,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    AudioRoomRightImageSlider(
                                      livestreamId:
                                      livestreamController.streamId.value,
                                    ),
                                    AudioRocketGameEntryButton(
                                      livestreamId:
                                      livestreamController.streamId.value,
                                      height: kHeight * 0.095,
                                      width: kHeight * 0.085,
                                    ),
                                    SizedBox(height: kHeight * 0.012),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Column(
              children: [
                //Live view Part one start
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      //fast row start
                      Padding(
                        padding: EdgeInsets.only(left: 3, top: kHeight * 0.037),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            /// ------------------- Profile Section Audio Live --------------
                            Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: kWeight * 0.02,
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Main Container (Background + Info + Follow Button)
                                      Container(
                                        padding: EdgeInsets.only(
                                            right: Get.width * 0.015,
                                            bottom: 3
                                        ),
                                        margin: EdgeInsets.only(

                                          left: Get.width * 0.01,
                                        ),
                                        // left gap profile এর জন্য
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(5),
                                            topLeft: Radius.circular(5),
                                            topRight: Radius.circular(25),
                                            bottomRight: Radius.circular(25),
                                          ),

                                          color: Color(
                                            0xff0e0c0c,
                                          ).withOpacity(0.4),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(width: Get.width * 0.12),
                                            // profile এর জায়গা
                                            Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Obx(
                                                      () =>
                                                      GradientShimmerTextaudio(
                                                        text:
                                                        liveRoomTitleText
                                                            .isNotEmpty
                                                            ? liveRoomTitleText
                                                            : ('Live Room')
                                                            .appTr,
                                                        fontSize:
                                                        kHeight * 0.018,
                                                        fontWeight:
                                                        FontWeight.w500,
                                                      ),
                                                ),
                                                Text(
                                                  ('Uid : ${broadcasterData['user']['user_id']}')
                                                      .appTr,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize:
                                                    (Get.height * 0.01)
                                                        .clamp(11.0, 13.0),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(width: Get.width * 0.03),
                                            Obx(() {
                                              if (broadcasterData?['user']?['id'] ==
                                                  authController
                                                      .userProfile
                                                      .value
                                                      .user
                                                      ?.id) {
                                                return const SizedBox();
                                              }

                                              return AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 300,
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
                                                    momentsController
                                                        .followCreate(
                                                      userId:
                                                      '${broadcasterData['user']?['id']}',
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                    EdgeInsets.symmetric(
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
                                                            0xff5002d5,
                                                          ),
                                                          Color(
                                                            0xff6a04b5,
                                                          ),
                                                        ],
                                                        begin: Alignment
                                                            .topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      ('Follow').appTr,
                                                      style: GoogleFonts.lato(
                                                        fontWeight:
                                                        FontWeight
                                                            .w600,
                                                        fontSize:
                                                        (Get.height *
                                                            0.008)
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
                                        left: -kWeight * 0.04,
                                        top: -kHeight * 0.026,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (websocketController
                                                .liveCallList
                                                .isNotEmpty) {
                                              Get.to(
                                                    () => LiveRoomSettingPage(
                                                  livestreamController: livestreamController,
                                                  websocketController: websocketController,
                                                  authController: authController,
                                                ),
                                                transition: Transition.rightToLeft,
                                                duration: const Duration(milliseconds: 180),
                                              );
                                            }
                                          },
                                          child: Obx(() {
                                            double size = Get.height * 0.055;
                                            final user = _hostVisualUserMap();
                                            final frameData =
                                            _firstProfileFrameFromUser(
                                              user,
                                            );
                                            final bool hasProfileFrame =
                                            _isProfileFrameAsset(frameData);
                                            final String frameAssetPath =
                                            _profileFrameAssetPath(
                                              frameData,
                                            );

                                            final profileImage = authController
                                                .userProfile
                                                .value
                                                .user
                                                ?.profileImage;

                                            return SizedBox(
                                              height: kHeight * 0.1,
                                              width: kHeight * 0.1,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  // ---------------- PROFILE IMAGE ----------------
                                                  ClipOval(
                                                    child: CachedNetworkImage(
                                                      // ROOM IMAGE: host profile replaced by stream image.
                                                      imageUrl:
                                                      liveRoomCoverImageUrl,
                                                      fit: BoxFit.cover,
                                                      height: size * 0.7,
                                                      width: size * 0.7,
                                                      placeholder: (context, url) =>
                                                          _hostProfileFallbackImage(
                                                            height: size * 0.7,
                                                            width: size * 0.7,
                                                            iconSize:
                                                            size * 0.28,
                                                          ),
                                                      errorWidget:
                                                          (
                                                          context,
                                                          url,
                                                          error,
                                                          ) =>
                                                          _hostProfileFallbackImage(
                                                            height:
                                                            size * 0.7,
                                                            width:
                                                            size * 0.7,
                                                            iconSize:
                                                            size * 0.28,
                                                          ),
                                                    ),
                                                  ),

                                                  // ---------------- AGENCY FRAME (if agencyId > 0) ----------------

                                                  // ---------------- NOTHING (no frame) ----------------
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            ///------------------------------ audio live Viewer List show ----------------
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                //viewers list here
                                SizedBox(
                                  // Viewer profile list beshi holeo horizontal scroll kore sob dekhabe.
                                  width: Get.width * 0.2,
                                  height: Get.height * 0.05,
                                  child: Obx(() {
                                    // ✅ Perfect viewer list: only current stream active viewers, no old-room ghost.
                                    final filteredList = livestreamController
                                        .liveViewerList
                                        .where(_viewerIsActiveForCurrentRoom)
                                        .where(
                                          (viewer) => _viewerUserId(viewer) > 0,
                                    )
                                        .toList();

                                    if (filteredList.isEmpty) {
                                      return const SizedBox(); // কিছু না দেখানোর জন্য (empty state)
                                    }

                                    return ListView.builder(
                                      padding: EdgeInsets.zero,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final data = filteredList[index];
                                        final userId = data is Map
                                            ? (data['user'] is Map
                                            ? data['user']['id']
                                            : (data['viewer_id'] ??
                                            data['user_id'] ??
                                            data['caller_id'] ??
                                            data['id']))
                                            : index;
                                        return LiveProfile(
                                          key: ValueKey(
                                            'live_profile_${userId ?? index}',
                                          ),
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
                                        Get.bottomSheet(
                                          Container(
                                            height: kHeight * 0.6,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(20),
                                              ),
                                              color: Colors.white,
                                            ),
                                            child: Column(
                                              children: [
                                                SizedBox(
                                                  height: kHeight * 0.01,
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: kWeight * 0.02,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      Center(
                                                        child: Castontext(
                                                          fontSize:
                                                          kHeight * 0.023,
                                                          fontWeight:
                                                          FontWeight.w600,
                                                          textColor: Colors
                                                              .black
                                                              .withOpacity(.7),
                                                          text:
                                                          ('All Viewer List')
                                                              .appTr,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        style: IconButton.styleFrom(
                                                          backgroundColor:
                                                          Colors.grey[100],
                                                          padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                          minimumSize:
                                                          const Size(
                                                            28,
                                                            28,
                                                          ),
                                                        ),
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        icon: Icon(
                                                          Icons.close,
                                                          color: kAppColor,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: kHeight * 0.004,
                                                ),

                                                /// 🔹 যদি Viewer না থাকে, তাহলে Center করে Empty Message দেখাও
                                                Expanded(
                                                  child: Obx(() {
                                                    final activeViewers =
                                                    livestreamController
                                                        .liveViewerList
                                                        .where(
                                                      _viewerIsActiveForCurrentRoom,
                                                    )
                                                        .where(
                                                          (viewer) =>
                                                      _viewerUserId(
                                                        viewer,
                                                      ) >
                                                          0,
                                                    )
                                                        .toList(
                                                      growable: false,
                                                    );
                                                    return activeViewers.isEmpty
                                                        ? Center(
                                                      child: Text(
                                                        ('No viewers yet 👀')
                                                            .appTr,
                                                        style: GoogleFonts.roboto(
                                                          fontSize:
                                                          kHeight *
                                                              0.016,
                                                          fontWeight:
                                                          FontWeight
                                                              .w400,
                                                          color: Colors
                                                              .grey[600],
                                                        ),
                                                      ),
                                                    )
                                                        : LiveViewersList(
                                                      viewerList:
                                                      activeViewers,
                                                      isBroadcaster: widget
                                                          .isBroadcaster,
                                                      onKickUser: (userId) {
                                                        livestreamController
                                                            .kickOutUser(
                                                          userId,
                                                        );
                                                      },
                                                      isFromPk: false,
                                                    );
                                                  }),
                                                ),
                                              ],
                                            ),
                                          ),
                                          isScrollControlled: true,
                                        );
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          left: Get.width * 0.01,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
                                          child: Container(
                                            height: Get.height * 0.035,
                                            width: Get.height * 0.05,
                                            decoration: BoxDecoration(
                                              color: Color(0xff0c0b0b).withOpacity(.6),
                                            ),
                                            child: Center(
                                              child: Obx(() {
                                                final filteredCount =
                                                    livestreamController
                                                        .liveViewerList
                                                        .where(
                                                      _viewerIsActiveForCurrentRoom,
                                                    )
                                                        .where(
                                                          (viewer) =>
                                                      _viewerUserId(
                                                        viewer,
                                                      ) >
                                                          0,
                                                    )
                                                        .length;

                                                return Text(
                                                  '👁️ $filteredCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Total gift count display
                                    InkWell(
                                      onTap: _showLiveMinimizeExitPanel,
                                      child: Container(
                                        decoration: BoxDecoration(color: Color(
                                            0xff6106ff),borderRadius: BorderRadius.circular(20)),

                                        margin: EdgeInsets.only(
                                          right: kWeight * 0.015,
                                          left: kWeight * 0.01,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                /// Comments now render directly under the dynamic seat board.
                /// Keep this transparent spacer only for the existing top profile layer.
                const Spacer(flex: 3),

                SizedBox(height: kHeight * 0.12),
                //Live view Part 2 end
              ],
            ),

            _liveMusicMiniPlayer(),

            ///Entry Animation - full screen like gift animation
            Obx(() {
              if (!websocketController.newViewersJoinded.value) {
                return const SizedBox.shrink();
              }

              final dynamic rawData = websocketController.newJoinedUserData;
              final Map<String, dynamic> data = rawData is Map<String, dynamic>
                  ? rawData
                  : rawData is Map
                  ? Map<String, dynamic>.from(rawData)
                  : <String, dynamic>{};

              final Map<String, dynamic> user =
              data['user'] is Map<String, dynamic>
                  ? data['user']
                  : data['user'] is Map
                  ? Map<String, dynamic>.from(data['user'])
                  : <String, dynamic>{};

              final String joinedUserId =
              (user['id'] ??
                  user['user_id'] ??
                  data['viewer_id'] ??
                  data['user_id'] ??
                  data['id'] ??
                  '')
                  .toString();

              // ✅ Host/viewer sobai nijer entry nijer screen-e dekhte parbe.
              // Age broadcaster self-entry hide kora hoto; ekhon condition remove.

              return Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: EntryAnimation(
                    key: ValueKey(
                      "entry_${joinedUserId}_${data['livestream_id'] ?? data['stream_id'] ?? ''}",
                    ),
                    data: websocketController.newJoinedUserData,
                    onFinished: () {
                      websocketController.hideEntryAnimation();
                    },
                  ),
                ),
              );
            }),

            QuickGiftRocketCard(liveController: liveController),

            /// Global Lucky Bag banner.
            /// Shows on top of this live room when any live room sends a global Lucky Bag.
            GlobalLuckyBagBanner(onOpenLive: _openGlobalLuckyBagRoom),

            /// Lucky Bag / Red Packet overlay.
            /// Shows top left countdown card, last 5 second open dialog,
            /// result popup and details sheet.
            RedPacketLiveOverlay(livestreamId: _currentStreamIdFromArgs()),

            /// Lucky coin rain must stay below the main gift animation,
            /// otherwise Times badge / Coin Back HUD can look hidden.
            Obx(
                  () => liveController.luckyGiftCoinRainVisible.value
                  ? const Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: LuckyCoinRainOverlay(),
                ),
              )
                  : const SizedBox.shrink(),
            ),

            /// Permanent isolated gift repaint island. Gift updates rebuild only
            /// this child, never the full live-room page.
            _AudioGiftOverlayHost(controller: websocketController),

            /// Rocket launch animation is isolated from the live-room page.
            /// Realtime updates rebuild only this overlay.
            RocketLaunchOverlay(livestreamId: _currentStreamIdFromArgs()),

            // 50x/100x uses the app-wide clickable OverlayEntry from
            // LivestreamController, so it remains visible on every page.
            Obx(() {
              if (!liveController.guardianNoticeVisible.value) {
                return const SizedBox.shrink();
              }

              return Positioned(
                top: kHeight * 0.078,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: true,
                  child: _GuardianMarqueeNotice(
                    text: liveController.guardianNoticeText.value,
                  ),
                ),
              );
            }),

            /// Live Imogi animation overlay.
            /// action_type: imogi_sent ashlei sobar screen-e show hobe.
            const Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: LiveImogiAnimationOverlay(),
              ),
            ),
            // AudioLiveView er vitore kono joining/loading overlay show korbo na.
            // Loading sudhu Home/live-list card-e show hobe.

            ///Live view bottom part end
            Align(
              alignment: Alignment.bottomCenter,
              child: _agoraService.engine != null
                  ? SafeArea(
                child: Container(
                  color: Colors.transparent, // 🔹 Background color red
                  child: WriteCommentSection(
                    rtcEngine: _agoraService.engine!,
                    streamType: 'audio',
                    broadcasterData: broadcasterData,
                  ),
                ),
              )
                  : Container(
                color: Colors
                    .transparent, // Optional: blank red bar if engine null
                height: 60, // adjust height if needed
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveYoutubePlayerSection() {
    return Obx(() {
      final String status = _effectiveBroadcaster
          ? liveController.liveYoutubeStatus.value
          : websocketController.liveYoutubeStatus.value;
      final String videoId = _effectiveBroadcaster
          ? liveController.liveYoutubeVideoId.value
          : websocketController.liveYoutubeVideoId.value;

      final bool visible = _isYoutubeActiveForSeatLayout;
      if (!visible) return const SizedBox.shrink();

      final controller = _ensureYoutubeController(
        videoId: videoId,
        status: status,
      );

      if (controller == null) return const SizedBox.shrink();

      final double playerHeight = liveSeatCount == 12
          ? kHeight * 0.255
          : kHeight * 0.265;

      return Container(
        width: double.infinity,
        height: playerHeight,
        margin: EdgeInsets.only(
          left: kWeight * 0.03,
          right: kWeight * 0.03,
          bottom: kHeight * 0.006,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
            ),

            /// Host control overlay. Audience only dekhe + shune.
            if (_effectiveBroadcaster)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _youtubeHostControlBar(status),
              ),
          ],
        ),
      );
    });
  }

  Widget _youtubeHostControlBar(String status) {
    final bool paused = status == 'paused';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.48),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _youtubeSmallButton(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            onTap: () async {
              if (paused) {
                await liveController.resumeYoutube();
              } else {
                await liveController.pauseYoutube();
              }
            },
          ),
          _youtubeSmallButton(
            icon: Icons.link_rounded,
            onTap: _showYoutubeLinkDialog,
          ),
          _youtubeSmallButton(
            icon: Icons.close_rounded,
            color: Colors.redAccent,
            onTap: () async {
              await liveController.stopYoutube();
              _disposeYoutubeController();
            },
          ),
        ],
      ),
    );
  }

  Widget _youtubeSmallButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 28,
        width: 32,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  void _showYoutubeLinkDialog() {
    final controller = TextEditingController(
      text: liveController.liveYoutubeUrl.value,
    );

    Get.dialog(
      AlertDialog(
        title: Text(('Play YouTube').appTr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: ('Paste YouTube link here').appTr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(('Cancel').appTr),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              Get.back();
              await liveController.playOrChangeYoutube(url);
            },
            child: Text(('Play').appTr),
          ),
        ],
      ),
    );
  }

  Widget _liveMusicMiniPlayer() {
    return Obx(() {
      final String status = _effectiveBroadcaster
          ? liveController.liveMusicStatus.value
          : websocketController.liveMusicStatus.value;

      final String name = _effectiveBroadcaster
          ? liveController.liveMusicName.value
          : websocketController.liveMusicName.value;

      final bool sheetOpen =
          _effectiveBroadcaster && liveController.isMusicPlayerSheetOpen.value;

      // Local Agora music can still be playing even when the backend music
      // event returns 403 or a stale room-state response says `stopped`.
      // For broadcaster/guardian, the local selected path and duration are
      // therefore also authoritative for the minimized player visibility.
      final bool localMusicActive =
          _canManageCurrentRoom &&
              (liveController.selectedMusicPath.value.trim().isNotEmpty ||
                  liveController.musicDurationMs.value > 0 ||
                  liveController.musicPositionMs.value > 0);

      final bool remoteMusicActive =
          status != 'stopped' && name.trim().isNotEmpty;

      final bool visible =
          (localMusicActive || remoteMusicActive) && !sheetOpen;

      if (!visible) return const SizedBox.shrink();

      final bool paused = status == 'paused' ||
          liveController.liveMusicStatus.value == 'paused';
      final String displayName = name.trim().isNotEmpty
          ? name.trim()
          : (liveController.liveMusicName.value.trim().isNotEmpty
          ? liveController.liveMusicName.value.trim()
          : 'Live room music');

      if (!_musicPanelExpanded) {
        const double iconSize = 48;
        final media = MediaQuery.of(context);
        final screen = media.size;
        final minX = 8.0;
        final maxX =
        math.max(minX, screen.width - iconSize - 8).toDouble();
        final minY = media.padding.top + 56;
        final bottomClearance = media.padding.bottom + kHeight * .125;
        final maxY = math
            .max(
          minY,
          screen.height - iconSize - bottomClearance,
        )
            .toDouble();
        if (_musicMiniOffset.value == Offset.zero) {
          _musicMiniOffset.value = Offset(maxX - 6, maxY - 8);
        } else {
          final current = _musicMiniOffset.value;
          final clamped = Offset(
            current.dx.clamp(minX, maxX).toDouble(),
            current.dy.clamp(minY, maxY).toDouble(),
          );
          if (clamped != current) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _musicMiniOffset.value = clamped;
            });
          }
        }

        return ValueListenableBuilder<Offset>(
          valueListenable: _musicMiniOffset,
          builder: (_, offset, child) => Positioned(
            left: offset.dx,
            top: offset.dy,
            child: child!,
          ),
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _canManageCurrentRoom
                  ? () {
                if (_musicMiniDragging) return;
                setState(() => _musicPanelExpanded = true);
              }
                  : null,
              onPanStart: (_) => _musicMiniDragging = true,
              onPanUpdate: (details) {
                final current = _musicMiniOffset.value;
                _musicMiniOffset.value = Offset(
                  (current.dx + details.delta.dx)
                      .clamp(minX, maxX)
                      .toDouble(),
                  (current.dy + details.delta.dy)
                      .clamp(minY, maxY)
                      .toDouble(),
                );
              },
              onPanEnd: (_) {
                Future<void>.delayed(const Duration(milliseconds: 80), () {
                  _musicMiniDragging = false;
                });
              },
              onPanCancel: () => _musicMiniDragging = false,
              child: Container(
                width: iconSize,
                height: iconSize,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xE6111111),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _SmoothMiniMusicDisc(size: 38, playing: !paused),
              ),
            ),
          ),
        );
      }

      final screen = MediaQuery.of(context).size;
      final double cardWidth = math.min(screen.width * .80, 380.0).toDouble();
      final double cardHeight =
      (kHeight * .125).clamp(105.0, 125.0).toDouble();

      // Always start fully inside the screen, above the bottom controls.
      if (_musicPanelOffset == Offset.zero) {
        _musicPanelOffset = Offset(
          (screen.width - cardWidth) / 2,
          screen.height -
              cardHeight -
              MediaQuery.of(context).padding.bottom -
              (kHeight * .115),
        );
      }

      final String shortName = displayName.length > 28
          ? '${displayName.substring(0, 28)}..'
          : displayName;

      return Positioned(
        left: _musicPanelOffset.dx,
        top: _musicPanelOffset.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: cardWidth,
            height: cardHeight,
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * 0.018,
              vertical: kHeight * 0.007,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0A0F2C).withOpacity(.92),
                  const Color(0xFF4A0C35).withOpacity(.92),
                  const Color(0xFFF80230).withOpacity(.88),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2D75).withOpacity(.45),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -22,
                  child: Container(
                    height: kHeight * 0.085,
                    width: kHeight * 0.085,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.08),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (_canManageCurrentRoom)
                                _musicIconButton(
                                  icon: Icons.skip_previous_rounded,
                                  onTap: () => liveController
                                      .liveMusicController
                                      .playPreviousLiveMusic(
                                    rtcEngine: _agoraService.engine,
                                  ),
                                ),
                              if (_canManageCurrentRoom)
                                _musicIconButton(
                                  icon: paused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  onTap: () async {
                                    if (_musicPanelDragging) return;

                                    if (paused) {
                                      await liveController.resumeLiveMusic(
                                        rtcEngine: _agoraService.engine,
                                      );
                                    } else {
                                      await liveController.pauseLiveMusic(
                                        rtcEngine: _agoraService.engine,
                                      );
                                    }
                                  },
                                ),

                              if (_canManageCurrentRoom)
                                _musicIconButton(
                                  icon: Icons.skip_next_rounded,
                                  onTap: () async {
                                    if (_musicPanelDragging) return;

                                    await liveController.liveMusicController
                                        .playNextLiveMusic(
                                      rtcEngine: _agoraService.engine,
                                    );
                                  },
                                ),

                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: kWeight * 0.012,
                                  vertical: kHeight * 0.003,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.18),
                                  ),
                                ),
                                child: Icon(
                                  Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: kHeight * 0.016,
                                ),
                              ),

                              if (_canManageCurrentRoom)
                                SizedBox(
                                  width: kWeight * .11,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 4,
                                      ),
                                      activeTrackColor:
                                      const Color(0xFFFFC400),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFFFFC400),
                                      overlayShape:
                                      SliderComponentShape.noOverlay,
                                    ),
                                    child: Slider(
                                      value: liveController.musicVolume.value
                                          .toDouble(),
                                      min: 0,
                                      max: 100,
                                      onChanged: (value) => liveController
                                          .setLiveMusicVolume(
                                        rtcEngine: _agoraService.engine,
                                        volume: value.round(),
                                      ),
                                    ),
                                  ),
                                ),

                              if (_canManageCurrentRoom)
                                _musicIconButton(
                                  icon: Icons.queue_music_rounded,
                                  onTap: () => LiveMusicPlayerSheet.show(
                                    rtcEngine: _agoraService.engine,
                                    showPlaylist: true,
                                  ),
                                ),

                              const Spacer(),

                              if (_canManageCurrentRoom)
                                _musicIconButton(
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  onTap: () {
                                    if (_musicPanelDragging) return;
                                    setState(
                                          () => _musicPanelExpanded = false,
                                    );
                                  },
                                ),

                              if (_canManageCurrentRoom)
                                _musicIconButton(
                                  icon: Icons.power_settings_new_rounded,
                                  color: const Color(0xFFFFD1D1),
                                  bgColor: const Color(0xFFFF1744),
                                  onTap: () async {
                                    if (_musicPanelDragging) return;

                                    await liveController.stopLiveMusic(
                                      rtcEngine: _agoraService.engine,
                                    );
                                    if (mounted) {
                                      setState(
                                            () => _musicPanelExpanded = false,
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),

                          SizedBox(height: kHeight * 0.007),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: LinearProgressIndicator(
                              value: _canManageCurrentRoom
                                  ? (liveController.musicDurationMs.value > 0
                                  ? liveController.liveMusicProgress
                                  : null)
                                  : (websocketController
                                  .liveMusicDurationMs
                                  .value >
                                  0
                                  ? (websocketController
                                  .liveMusicPositionMs
                                  .value /
                                  websocketController
                                      .liveMusicDurationMs
                                      .value)
                                  .clamp(0.0, 1.0)
                                  : null),
                              minHeight: 5,
                              backgroundColor: Colors.white.withOpacity(.18),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                paused
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFF00E5FF),
                              ),
                            ),
                          ),

                          SizedBox(height: kHeight * 0.005),

                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  shortName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: kHeight * 0.009,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(.35),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(width: kWeight * 0.01),

                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: kWeight * 0.018,
                                  vertical: kHeight * 0.003,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: paused
                                        ? [
                                      const Color(0xFFFFB300),
                                      const Color(0xFFFF6D00),
                                    ]
                                        : [
                                      const Color(0xFF00E5FF),
                                      const Color(0xFF00C853),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: paused
                                          ? const Color(
                                        0xFFFFB300,
                                      ).withOpacity(.35)
                                          : const Color(
                                        0xFF00E5FF,
                                      ).withOpacity(.35),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  paused ? ('Paused').appTr : ('Playing').appTr,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: kHeight * 0.0078,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _musicIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color bgColor = const Color(0x33FFFFFF),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 5),
        height: kHeight * 0.027,
        width: kHeight * 0.027,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: Colors.white.withOpacity(.20)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(.18),
              blurRadius: 8,
              spreadRadius: .5,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: kHeight * 0.019),
      ),
    );
  }

  Map<String, dynamic> _cpMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _cpTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'connected' ||
        text == 'cp' ||
        text == 'active';
  }

  List<int> _cpSeatListFromAny(dynamic value) {
    final seats = <int>[];

    void add(dynamic raw) {
      final int seat = _safeInt(raw);
      if (seat > 0 && !seats.contains(seat)) seats.add(seat);
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          add(
            map['seat_no'] ??
                map['seat'] ??
                map['seat_number'] ??
                map['seatNo'],
          );
        } else {
          add(item);
        }
        if (seats.length >= 2) break;
      }
    } else if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      add(map['seat_no'] ?? map['seat'] ?? map['seat_number'] ?? map['seatNo']);
      add(
        map['partner_seat_no'] ??
            map['cp_partner_seat_no'] ??
            map['other_seat_no'] ??
            map['to_seat_no'],
      );
    } else {
      add(value);
    }

    return seats.take(2).toList();
  }

  int _cpFirstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final int value = _safeInt(map[key]);
      if (value > 0) return value;
    }
    return 0;
  }

  List<int> _cpSeatPairFromMap(Map<String, dynamic> raw) {
    final map = <String, dynamic>{...raw};

    for (final key in ['cp_connection', 'connection', 'cp_data']) {
      final nested = _cpMap(raw[key]);
      if (nested.isNotEmpty) map.addAll(nested);
    }

    for (final key in [
      'cp_connection_pair',
      'cp_connected_seats',
      'connected_seats',
      'seat_pair',
      'pair',
      'seats',
    ]) {
      final pair = _cpSeatListFromAny(map[key]);
      if (pair.length >= 2) {
        pair.sort();
        return pair;
      }
    }

    final int seatOne = _cpFirstInt(map, [
      'seat_one',
      'seat_no',
      'seat',
      'seat_number',
      'seatNo',
      'my_seat_no',
      'current_user_seat_no',
      'user_seat_no',
      'sender_seat_no',
      'from_seat_no',
      'caller_seat_no',
    ]);

    final int seatTwo = _cpFirstInt(map, [
      'seat_two',
      'cp_partner_seat_no',
      'partner_seat_no',
      'partner_seat',
      'other_seat_no',
      'to_seat_no',
      'receiver_seat_no',
      'target_seat_no',
    ]);

    if (seatOne > 0 && seatTwo > 0 && seatOne != seatTwo) {
      final pair = [seatOne, seatTwo]..sort();
      return pair;
    }

    return <int>[];
  }

  void _collectCpPairsFromDynamic(
      dynamic value,
      Map<String, List<int>> pairs, {
        required int totalSeats,
      }) {
    if (value == null) return;

    if (value is Iterable) {
      for (final item in value) {
        _collectCpPairsFromDynamic(item, pairs, totalSeats: totalSeats);
      }
      return;
    }

    if (value is! Map) return;

    final map = Map<String, dynamic>.from(value);
    final bool hasCpFlag =
        _cpTruthy(map['has_cp_connection']) ||
            _cpTruthy(map['is_cp_connected']) ||
            _cpTruthy(map['cp_connected']) ||
            map['cp_connection'] is Map ||
            map['cp_connection_pair'] is Iterable ||
            map['cp_connected_seats'] is Iterable ||
            map['cp_partner_seat_no'] != null ||
            map['partner_seat_no'] != null ||
            (map['seat_one'] != null && map['seat_two'] != null);

    if (hasCpFlag) {
      final pair = _cpSeatPairFromMap(map);
      if (pair.length >= 2) {
        final int a = pair[0];
        final int b = pair[1];
        if (a > 0 &&
            b > 0 &&
            a <= totalSeats &&
            b <= totalSeats &&
            (a - b).abs() == 1 &&
            _seatHasVisibleCpUser(a) &&
            _seatHasVisibleCpUser(b)) {
          pairs['$a-$b'] = [a, b];
        }
      }
    }

    for (final key in [
      'cp_connections',
      'cp_seat_connections',
      'connections',
      'cp_connection_list',
      'livestream_callers',
      'callers',
      'seat_users',
      'seats',
    ]) {
      final nested = map[key];
      if (nested is Iterable || nested is Map) {
        _collectCpPairsFromDynamic(nested, pairs, totalSeats: totalSeats);
      }
    }
  }

  bool _seatHasVisibleCpUser(int seatNo) {
    if (seatNo <= 0) return false;

    if (seatNo == 1 &&
        _hostCurrentSeatNo() == 1 &&
        _hostUserIdFromSnapshot() > 0) {
      return true;
    }

    final Map row = userData(seatNo: seatNo);
    if (row.isEmpty) return false;

    final status = (row['call_status'] ?? row['status'] ?? 'accepted')
        .toString()
        .toLowerCase()
        .trim();

    if (status == 'left' ||
        status == 'rejected' ||
        status == 'canceled' ||
        status == 'cancelled') {
      return false;
    }

    final user = row['user'];
    return row['caller_id'] != null ||
        row['user_id'] != null ||
        (user is Map &&
            (user['id'] != null ||
                user['user_id'] != null ||
                user['name'] != null));
  }

  List<List<int>> _cpSeatPairsForUi({required int totalSeats}) {
    final Map<String, List<int>> pairs = <String, List<int>>{};

    try {
      _collectCpPairsFromDynamic(
        websocketController.cpSeatConnections,
        pairs,
        totalSeats: totalSeats,
      );
    } catch (_) {}

    try {
      _collectCpPairsFromDynamic(
        websocketController.liveCallList,
        pairs,
        totalSeats: totalSeats,
      );
    } catch (_) {}

    try {
      _collectCpPairsFromDynamic(streamInfo, pairs, totalSeats: totalSeats);
      _collectCpPairsFromDynamic(streamData, pairs, totalSeats: totalSeats);
    } catch (_) {}

    final list = pairs.values.toList()
      ..sort((a, b) => a.first.compareTo(b.first));

    return list;
  }

  String _cleanCpImagePath(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  bool _looksLikeCpImagePath(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;

    final lower = text.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('images/') ||
        lower.startsWith('/images/') ||
        lower.contains('/cp') ||
        lower.contains('/base') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.svga');
  }

  String _cpImageFromMap(Map<String, dynamic> raw, {int depth = 0}) {
    if (raw.isEmpty || depth > 3) return '';

    final directKeys = const [
      'cp_base_image_url',
      'cp_base_image',
      'cpBaseImageUrl',
      'cpBaseImage',
      'cp_image_url',
      'cp_image',
      'cpImageUrl',
      'cpImage',
      'base_image_url',
      'base_image',
      'baseImageUrl',
      'baseImage',
      'connection_image_url',
      'connection_image',
      'love_image_url',
      'love_image',
      'badge_image_url',
      'badge_image',
      'asset_url',
      'asset_path',
      'asset_image',
    ];

    for (final key in directKeys) {
      final value = _cleanCpImagePath(raw[key]);
      if (value.isNotEmpty && _looksLikeCpImagePath(value)) {
        return ImageHelper.getImageUrl(value);
      }
    }

    for (final entry in raw.entries) {
      final key = entry.key.toString().toLowerCase();
      if (!(key.contains('cp') ||
          key.contains('base') ||
          key.contains('connection'))) {
        continue;
      }
      if (!(key.contains('image') ||
          key.contains('url') ||
          key.contains('asset') ||
          key.contains('icon'))) {
        continue;
      }

      final value = _cleanCpImagePath(entry.value);
      if (value.isNotEmpty && _looksLikeCpImagePath(value)) {
        return ImageHelper.getImageUrl(value);
      }
    }

    for (final nestedKey in const [
      'raw',
      'cp_connection',
      'connection',
      'cp_data',
      'cp_base',
      'base',
      'cp',
      'asset',
      'badge',
      'image_data',
    ]) {
      final nested = _cpMap(raw[nestedKey]);
      if (nested.isEmpty) continue;
      final value = _cpImageFromMap(nested, depth: depth + 1);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  bool _cpPairMatches(Map<String, dynamic> map, int seatA, int seatB) {
    final pair = _cpSeatPairFromMap(map);
    if (pair.length < 2) return false;

    final wanted = [seatA, seatB]..sort();
    pair.sort();
    return pair[0] == wanted[0] && pair[1] == wanted[1];
  }

  String _cpBaseImageFromDynamic(
      dynamic value,
      int seatA,
      int seatB, {
        int depth = 0,
      }) {
    if (value == null || depth > 4) return '';

    if (value is Iterable) {
      for (final item in value) {
        final image = _cpBaseImageFromDynamic(
          item,
          seatA,
          seatB,
          depth: depth + 1,
        );
        if (image.isNotEmpty) return image;
      }
      return '';
    }

    if (value is! Map) return '';

    final map = Map<String, dynamic>.from(value);
    if (_cpPairMatches(map, seatA, seatB)) {
      final image = _cpImageFromMap(map);
      if (image.isNotEmpty) return image;
    }

    for (final key in const [
      'raw',
      'cp_connection',
      'cp_connections',
      'cp_seat_connections',
      'connections',
      'cp_connection_list',
      'livestream_callers',
      'callers',
      'seat_users',
      'seats',
      'data',
      'livestream',
      'livestreamdata',
      'live_stream',
    ]) {
      final nested = map[key];
      if (nested is Iterable || nested is Map) {
        final image = _cpBaseImageFromDynamic(
          nested,
          seatA,
          seatB,
          depth: depth + 1,
        );
        if (image.isNotEmpty) return image;
      }
    }

    return '';
  }

  String _cpBaseImageForPair(int seatA, int seatB) {
    for (final source in [
      websocketController.cpSeatConnections,
      websocketController.liveCallList,
      streamInfo,
      streamData,
    ]) {
      final image = _cpBaseImageFromDynamic(source, seatA, seatB);
      if (image.isNotEmpty) return image;
    }

    return '';
  }

  void _precacheCpBaseImage(BuildContext context, String imageUrl) {
    if (imageUrl.trim().isEmpty || _cpBaseImagePrecached.contains(imageUrl))
      return;

    _cpBaseImagePrecached.add(imageUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      ).catchError((_) {});
    });
  }

  void _precacheLocalCpBaseAsset(BuildContext context) {
    if (_cpBaseImagePrecached.contains(_localCpBaseAsset)) return;

    _cpBaseImagePrecached.add(_localCpBaseAsset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
        const AssetImage(_localCpBaseAsset),
        context,
      ).catchError((_) {});
    });
  }

  Widget _cpFallbackHeart(double heartSize) {
    return Container(
      height: heartSize,
      width: heartSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5FA2), Color(0xFFFF2D75), Color(0xFFA855F7)],
        ),
        border: Border.all(color: Colors.white.withOpacity(.90), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2D75).withOpacity(.48),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: heartSize * .58,
          ),
          Positioned(
            bottom: heartSize * .13,
            child: Text(
              ('CP').appTr,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: (heartSize * .18).clamp(6.0, 9.0).toDouble(),
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(.30), blurRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCpLoveConnectionWidgets({
    required BuildContext context,
    required List<_AudioSeatPoint> positions,
    required BoxConstraints constraints,
    required int totalSeats,
    required double seatSize,
  }) {
    final pairs = _cpSeatPairsForUi(totalSeats: totalSeats);
    if (pairs.isEmpty) return const <Widget>[];

    final double heartSize = (seatSize * 0.68)
        .clamp(kHeight * 0.032, kHeight * 0.052)
        .toDouble();

    return pairs.map((pair) {
      final int seatA = pair[0];
      final int seatB = pair[1];
      if (seatA <= 0 ||
          seatB <= 0 ||
          seatA > positions.length ||
          seatB > positions.length) {
        return const SizedBox.shrink();
      }

      final pointA = positions[seatA - 1];
      final pointB = positions[seatB - 1];
      final Offset center = Offset(
        constraints.maxWidth * ((pointA.x + pointB.x) / 2),
        constraints.maxHeight * ((pointA.y + pointB.y) / 2),
      );

      // CP pair thaklei always local gift asset show hobe.
      // Backend/network CP base image ignore kora holo, jate sob device-e
      // same asset instantly render hoy: assets/flaticons/gift.png
      _precacheLocalCpBaseAsset(context);

      final double displaySize = (seatSize * 1.20)
          .clamp(kHeight * 0.052, kHeight * 0.090)
          .toDouble();

      return Positioned(
        left: center.dx - displaySize / 2,
        top: center.dy - displaySize / 2,
        child: IgnorePointer(
          child: RepaintBoundary(
            child: Image.asset(
              _localCpBaseAsset,
              height: displaySize,
              width: displaySize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _cpFallbackHeart(heartSize),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _reactiveAudioSeatBoard() {
    /// Step 2B: Seat/Grid is now its own reactive layer.
    /// Seat join/leave, mute, lock, CP base, speaking-wave and YouTube compact
    /// changes rebuild only this board instead of rebuilding the full room page.
    return Obx(() {
      websocketController.liveCallList.length;
      websocketController.lockedSeatMap.length;
      websocketController.audioMutedUserMap.length;
      websocketController.cpSeatConnections.length;
      websocketController.liveRoomSeatCount.value;
      websocketController.liveRoomLayout.value;
      websocketController.liveYoutubeStatus.value;
      websocketController.liveYoutubeVideoId.value;
      liveController.liveYoutubeStatus.value;
      liveController.liveYoutubeVideoId.value;
      liveController.mute.value;
      final int hostUserId = _currentHostUserIdForSeat();
      if (hostUserId > 0) {
        websocketController.speakingUserMap[hostUserId];
      }

      return AudioRoomLayerBoundary(child: getAudioBroadcaster());
    });
  }

  Widget getAudioBroadcaster() {
    // Never call Agora role changing function from build().
    // Build/Obx can run many times per second and causes seat flicker/glitch.
    final totalSeats = liveSeatCount;
    final layout = safeLiveLayout;
    final bool youtubeCompact = _isYoutubeActiveForSeatLayout;

    final seatSize = youtubeCompact
        ? (totalSeats == 9 ? kHeight * 0.043 : kHeight * 0.038)
        : totalSeats == 9
        ? kHeight * 0.065
        : totalSeats == 12
        ? kHeight * 0.060
        : totalSeats == 15
        ? kHeight * 0.065
        : kHeight * 0.052;

    final positions = _seatPositions(count: totalSeats, layout: layout);
    final areaHeight = youtubeCompact
        ? (totalSeats == 9 ? kHeight * 0.215 : kHeight * 0.225)
        : totalSeats == 9
        ? kHeight * 0.345
        : totalSeats == 12
        ? kHeight * 0.360
        : totalSeats == 15
        ? kHeight * 0.340
        : kHeight * 0.365;

    return SizedBox(
      height: youtubeCompact
          ? (totalSeats == 9 ? kHeight * 0.235 : kHeight * 0.245)
          : totalSeats == 20
          ? kHeight * 0.390
          : kHeight * 0.370,
      width: double.infinity,
      child: Padding(
        /// Same responsive left/right width for 9/12/15/20 seats.
        padding: EdgeInsets.symmetric(horizontal: kWeight * 0.020),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            key: ValueKey('$totalSeats-$layout'),
            height: areaHeight,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...List.generate(positions.length, (index) {
                      final point = positions[index];
                      final isOwnerSeat = index == 0;
                      final seatNo = index + 1;
                      final slotWidth = seatSize * 2.12;
                      final slotHeight = seatSize * 2.18;
                      final ownerVisualSize = kHeight * 0.055;
                      return Positioned(
                        left: (constraints.maxWidth * point.x) - slotWidth / 2,
                        top: (constraints.maxHeight * point.y) - slotHeight / 2,
                        child: SizedBox(
                          height: slotHeight,
                          width: slotWidth,
                          child: Center(
                            child: isOwnerSeat
                                ? (_hostCurrentSeatNo() == 1
                                ? _broadcasterLayoutProfile(
                              ownerVisualSize,
                            )
                                : _reservedHostMainSeat(ownerVisualSize))
                                : LiveViewCircleSeatReactive(
                              initialData: userData(seatNo: seatNo),
                              seatNo: seatNo,
                            ),
                          ),
                        ),
                      );
                    }),

                    /// CP base overlay must be above seats and must listen directly
                    /// to cpSeatConnections, so every viewer updates immediately.
                    Obx(() {
                      websocketController.cpSeatConnections.length;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: _buildCpLoveConnectionWidgets(
                          context: context,
                          positions: positions,
                          constraints: constraints,
                          totalSeats: totalSeats,
                          seatSize: seatSize,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _emojiMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  dynamic _emojiPickFirst(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null &&
          value.toString().trim().isNotEmpty &&
          value.toString() != 'null') {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeHostImogiPayload(dynamic rawItem) {
    Map<String, dynamic> map = _emojiMap(rawItem);

    final innerData = _emojiMap(map['data']);
    if (innerData.isNotEmpty &&
        (innerData['action_type'] != null ||
            innerData['sender'] != null ||
            innerData['imogi'] != null ||
            innerData['emoji'] != null)) {
      map = innerData;
    }

    final innerPayload = _emojiMap(map['payload']);
    if (innerPayload.isNotEmpty &&
        (innerPayload['action_type'] != null ||
            innerPayload['sender'] != null ||
            innerPayload['imogi'] != null ||
            innerPayload['emoji'] != null)) {
      map = innerPayload;
    }

    return map;
  }

  Map<String, dynamic>? _activeHostImogiForUser(dynamic rawUserId) {
    final userId = rawUserId?.toString() ?? '';
    if (userId.isEmpty || userId == 'null') return null;

    for (final rawItem in websocketController.liveImogiAnimations.reversed) {
      final map = _normalizeHostImogiPayload(rawItem);

      final sender = _emojiMap(map['sender']);
      final user = _emojiMap(map['user']);

      final senderId =
          _emojiPickFirst(sender, ['id', 'user_id', 'caller_id']) ??
              _emojiPickFirst(user, ['id', 'user_id', 'caller_id']) ??
              _emojiPickFirst(map, [
                'sender_id',
                'user_id',
                'caller_id',
                'senderId',
                'userId',
                'id',
              ]);

      if (senderId.toString() == userId) {
        return map;
      }
    }

    return null;
  }

  String _safeHostImogiImage(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null' || raw == 'file:///') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  Widget _hostImogiOverlay(dynamic rawUserId, double size) {
    return Obx(() {
      final item = _activeHostImogiForUser(rawUserId);
      if (item == null) return const SizedBox.shrink();

      final imogi = _emojiMap(item['imogi']);
      final emoji = _emojiMap(item['emoji']);
      final giftLike = _emojiMap(item['gift']);

      final image = _safeHostImogiImage(
        _emojiPickFirst(imogi, [
          'image',
          'icon',
          'imogi_image',
          'emoji_image',
          'show_image',
          'url',
          'file',
        ]) ??
            _emojiPickFirst(emoji, [
              'image',
              'icon',
              'imogi_image',
              'emoji_image',
              'show_image',
              'url',
              'file',
            ]) ??
            _emojiPickFirst(giftLike, [
              'image',
              'icon',
              'imogi_image',
              'emoji_image',
              'show_image',
              'url',
              'file',
            ]) ??
            _emojiPickFirst(item, [
              'image',
              'icon',
              'imogi_image',
              'emoji_image',
              'show_image',
              'url',
              'file',
            ]),
      );

      if (image.isEmpty) return const SizedBox.shrink();

      /// Host emoji audience seat emoji-r moto profile-er center-e show korbe.
      /// Age top-e chole jacchilo, tai Positioned.fill + Center use kora holo.
      return Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(
                item['event_id']?.toString() ??
                    item['timestamp']?.toString() ??
                    image,
              ),
              tween: Tween<double>(begin: .45, end: 1.0),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    height: size * 1.5,
                    width: size * 1.5,
                    padding: EdgeInsets.all(size * 0.01),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(.14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    // ✅ FIX: previously ClipOval + BoxFit.cover cropped the
                    // emoji to fill a square box and then clipped the result
                    // to a circle, cutting off its edges/corners — this is
                    // why host emoji reactions showed cut off while regular
                    // seat emoji (which already used BoxFit.contain with no
                    // clip, see _seatImogiOverlay) displayed fully. Matching
                    // that same correct pattern here.
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }

  int _currentHostUserIdForSeat() {
    // Current room owner only. Never use first seated caller id as host id.
    for (final source in [
      _safeMap(streamInfo),
      _safeMap(streamData),
      _safeMap(streamData?['livestream']),
      _safeMap(streamData?['livestreamdata']),
      _safeMap(broadcasterData),
    ]) {
      final id = _ownerUserIdFromLiveMap(source);
      if (id > 0) return id;
    }
    return 0;
  }

  bool _callBelongsToUser(Map<String, dynamic> call, int userId) {
    if (userId <= 0) return false;
    final user = _safeMap(call['user']);
    final caller = _safeMap(call['caller']);
    final ids = [
      call['caller_id'],
      call['user_id'],
      call['viewer_id'],
      call['id'],
      user['id'],
      user['user_id'],
      caller['id'],
      caller['user_id'],
    ];
    return ids.any((value) => _safeInt(value) == userId);
  }

  bool _isAcceptedSeatCall(Map<String, dynamic> call) {
    final status = _safeLower(call['call_status'] ?? call['status']);
    if (status == 'left' ||
        status == 'rejected' ||
        status == 'reject' ||
        status == 'canceled' ||
        status == 'cancelled' ||
        status == 'ended') {
      return false;
    }
    final seat = _safeInt(
      call['seat_no'] ?? call['seat'] ?? call['seat_number'],
    );
    return seat > 0;
  }

  Map<String, dynamic> _hostSeatCallFromLiveState() {
    final int hostId = _currentHostUserIdForSeat();
    if (hostId <= 0) return <String, dynamic>{};

    for (final raw in websocketController.liveCallList) {
      final call = _safeMap(raw);
      if (call.isEmpty || !_isAcceptedSeatCall(call)) continue;
      final bool broadcasterCall =
          _mapBelongsToCurrentStream(call) &&
              (_truthy(call['is_broadcaster']) ||
                  _truthy(call['current_room_host']));
      if (_callBelongsToUser(call, hostId) || broadcasterCall) {
        return call;
      }
    }

    return <String, dynamic>{};
  }

  int _hostCurrentSeatNo() {
    final call = _hostSeatCallFromLiveState();
    if (call.isEmpty) return 1;
    final seat = _safeInt(
      call['seat_no'] ?? call['seat'] ?? call['seat_number'],
    );
    return seat > 0 ? seat : 1;
  }

  bool _isCurrentUserHostForSeat() {
    final int hostId = _currentHostUserIdForSeat();
    final int me = authController.userProfile.value.user?.id?.toInt() ?? 0;
    return hostId > 0 && me > 0 && hostId == me;
  }

  Future<void> _returnHostToMainSeat() async {
    final int streamId = liveController.streamId.value > 0
        ? liveController.streamId.value
        : websocketController.streamID.value;

    if (!_isCurrentUserHostForSeat()) {
      Fluttertoast.showToast(msg: ('This host seat is reserved').appTr);
      return;
    }

    if (streamId <= 0) {
      Fluttertoast.showToast(msg: ('Invalid live room').appTr);
      return;
    }

    final int currentSeat = _hostCurrentSeatNo();
    if (currentSeat == 1) {
      Fluttertoast.showToast(msg: ('Host is already on main seat').appTr);
      return;
    }

    await liveController.switchAudioSeat(
      livestreamId: streamId,
      fromSeatNo: currentSeat,
      toSeatNo: 1,
    );
  }

  Widget _reservedHostMainSeat(double size) {
    final bool canReturn = _isCurrentUserHostForSeat();

    return GestureDetector(
      onTap: canReturn
          ? _returnHostToMainSeat
          : () => Fluttertoast.showToast(msg: ('Host seat is reserved').appTr),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: size * 2,
              width: size * 2.18,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: size * 1.45,
                    width: size * 1.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.22),


                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/flaticons/hostmick.png',
                        height: size * .72,
                        width: size * .72,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.amber.withOpacity(.95),
                          size: size * .72,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ),
            // SizedBox(height: size * 0.01),
            SizedBox(
              width: size * 1.7,
              child: Text(
                canReturn ? ('Home').appTr : ('Reserved').appTr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: Colors.white.withOpacity(.85),
                  fontSize: kHeight * 0.013,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: size * 0.055),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _broadcasterLayoutProfile(double size) {
    final user = _hostVisualUserMap();

    if (user.isEmpty) {
      return CircleAvatar(
        radius: (kHeight * 0.09) / 2,
        backgroundColor: Colors.white.withOpacity(.35),
        child: Icon(Icons.person, color: Colors.white, size: kHeight * 0.025),
      );
    }

    final String rawProfileImage = _firstLiveText([
      user['profile_image'],
      user['avatar'],
      liveRoomCoverImageUrl,
    ]);
    final String profileImage = rawProfileImage.isEmpty
        ? liveRoomCoverImageUrl
        : ImageHelper.getImageUrl(rawProfileImage);

    final frameData = _firstProfileFrameFromUser(user);
    final bool hasProfileFrame = _isProfileFrameAsset(frameData);
    final String frameAssetPath = _profileFrameAssetPath(frameData);

    final String displayName = (user['name'] ?? ('Host').appTr).toString();
    final hostVip = VipPrivileges.from(<String, dynamic>{
      ...broadcasterData,
      'user': user,
    });
    final int currentHostUserId = _safeInt(
      user['id'] ?? user['user_id'] ?? _hostUserIdFromSnapshot(),
    );
    final int coins = websocketController.currentLiveGiftCoinsForUser(
      userId: currentHostUserId,
      livestreamId: _currentLiveStreamId,
    );

    /// Same exact profile image size as LiveViewCircle occupied seats.
    final double profileSize = kHeight * 0.09;
    final double frameSize = kHeight * 0.110;
    final double profileSlotSize = kHeight * 0.10;
    final double seatNameWidth = Get.width * 0.165;

    return GestureDetector(
      onTap: () {
        if (websocketController.liveCallList.isNotEmpty) {
          homeController.liveVisitProfile(
            userId: '${user['id']}',
            seatData: websocketController.liveCallList[0],
          );
        }
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// নিচের room owner profile-টি audience seat-এর একই মাপে থাকবে।
            Transform.translate(
              offset: Offset(0, kHeight * 0.014),
              child: SizedBox(
                height: profileSlotSize,
                width: profileSlotSize,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (_isUserSpeaking(user['id']) &&
                        !_isUserMuted(user['id']))
                      SpeakingWave(size: profileSize * 1.40),
                    if (hostVip.effectiveColorfulProfile)
                      IgnorePointer(
                        child: Container(
                          height: profileSize * 1.07,
                          width: profileSize * 1.07,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7B2CBF), Color(0xFFFFD76A)],
                            ),
                          ),
                        ),
                      ),

                    Builder(
                      builder: (hostProfileContext) {
                        final int luckyHostUserId = _safeInt(
                          user['id'] ??
                              user['user_id'] ??
                              broadcasterData['caller_id'] ??
                              broadcasterData['user_id'] ??
                              streamInfo['current_host_id'] ??
                              streamInfo['owner_user_id'] ??
                              streamInfo['host_id'],
                        );

                        LiveViewCircle_container.registerLuckyTargetContext(
                          userId: luckyHostUserId,
                          seatNo: 1,
                          context: hostProfileContext,
                        );

                        return Container(
                          height: profileSize,
                          width: profileSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.16),
                            border: Border.all(
                              color: _isUserMuted(user['id'])
                                  ? Colors.redAccent.withOpacity(.75)
                                  : Colors.white.withOpacity(.30),
                              width: _isUserMuted(user['id']) ? 1.4 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isUserMuted(user['id'])
                                    ? Colors.redAccent.withOpacity(.28)
                                    : Colors.black.withOpacity(.28),
                                blurRadius: _isUserMuted(user['id']) ? 12 : 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profileImage,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  _hostProfileFallbackImage(
                                    height: profileSize,
                                    width: profileSize,
                                    iconSize: kHeight * 0.025,
                                  ),
                              errorWidget: (context, url, error) =>
                                  _hostProfileFallbackImage(
                                    height: profileSize,
                                    width: profileSize,
                                    iconSize: kHeight * 0.025,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),

                    if (hasProfileFrame)
                      IgnorePointer(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          minHeight: frameSize,
                          maxHeight: frameSize,
                          minWidth: frameSize,
                          maxWidth: frameSize,
                          child: RepaintBoundary(
                            child:
                            frameAssetPath.toLowerCase().endsWith('.svga')
                                ? SizedBox(
                              height: frameSize,
                              width: frameSize,
                              child: SVGAEasyPlayer(
                                resUrl: ImageHelper.getImageUrl(
                                  frameAssetPath,
                                ),
                                fit: BoxFit.contain,
                                loops: null,
                                useCache: true,
                              ),
                            )
                                : CachedNetworkImage(
                              imageUrl: ImageHelper.getImageUrl(
                                frameAssetPath,
                              ),
                              height: frameSize,
                              width: frameSize,
                              fit: BoxFit.contain,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),

                    /// Host emoji audience seat-এর মতো profile-এর center-এ থাকবে।
                    _hostImogiOverlay(user['id'], kHeight * 0.085),

                    Positioned(
                      right: 2,
                      bottom: 3,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        child: _isUserMuted(user['id'])
                            ? Container(
                          key: ValueKey('owner_muted_${user['id']}'),
                          height: kHeight * 0.020,
                          width: kHeight * 0.020,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.96),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: .8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.30),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mic_off,
                            color: Colors.white,
                            size: kHeight * 0.012,
                          ),
                        )
                            : SizedBox(
                          key: ValueKey('owner_unmuted_${user['id']}'),
                          height: kHeight * 0.020,
                          width: kHeight * 0.020,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// Owner badge + owner name audience seat name-এর একই size।
            Transform.translate(
              offset: Offset(0, kHeight * 0.008),
              child: SizedBox(
                width: seatNameWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: kHeight * 0.017,
                        width: kHeight * 0.017,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xffFACC15), Color(0xffF97316)],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(.85),
                            width: .7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.20),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: kHeight * 0.0105,
                        ),
                      ),
                      SizedBox(width: kWeight * 0.004),
                      GradientShimmerTextaudio(
                        text: displayName,
                        fontSize: kHeight * 0.014,
                        fontWeight: FontWeight.w600,
                        visibleLetters: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// Audience seat-এর মতো name এবং coin-এর মাঝে একই fixed gap।
            SizedBox(height: kHeight * 0.012),

            /// Owner coin audience seat-এর exact size, position এবং scaling।
            Transform.translate(
              offset: Offset(0, -kHeight * 0.009),
              child: SizedBox(
                height: kHeight * 0.022,
                child: Center(
                  child: _safeInt(coins) > 0
                      ? Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kWeight * 0.012,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _isUserMuted(user['id'])
                          ? Colors.red.withOpacity(.22)
                          : Colors.black.withOpacity(.24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/diamond-removebg-preview.png',
                          height: kHeight * 0.012,
                        ),
                        SizedBox(width: kWeight * 0.004),
                        Text(
                          formatNumber(coins),
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.013,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AudioSeatPoint> _seatPositions({
    required int count,
    required int layout,
  }) {
    /// ================= 9 SEAT LAYOUTS =================
    /// Default: top 1, below 4 + 4.
    if (count == 9 && layout == 0) {
      return const [
        _AudioSeatPoint(.50, .14),
        _AudioSeatPoint(.11, .48),
        _AudioSeatPoint(.37, .48),
        _AudioSeatPoint(.63, .48),
        _AudioSeatPoint(.89, .48),
        _AudioSeatPoint(.11, .80),
        _AudioSeatPoint(.37, .80),
        _AudioSeatPoint(.63, .80),
        _AudioSeatPoint(.89, .80),
      ];
    }

    /// 9 layout 2: first line 5, second line 4.
    if (count == 9 && layout == 1) {
      return const [
        _AudioSeatPoint(.1, .2),
        _AudioSeatPoint(.31, .2),
        _AudioSeatPoint(.51, .2),
        _AudioSeatPoint(.71, .2),
        _AudioSeatPoint(.92, .2),
        _AudioSeatPoint(.18, .55),
        _AudioSeatPoint(.40, .55),
        _AudioSeatPoint(.62, .55),
        _AudioSeatPoint(.84, .55),
      ];
    }

    /// 9 layout 3: left/right 3 + 3, bottom 2, middle 1.
    if (count == 9 && layout == 2) {
      return const [
        _AudioSeatPoint(.50, .37),
        _AudioSeatPoint(.10, .15),
        _AudioSeatPoint(.10, .45),
        _AudioSeatPoint(.10, .75),
        _AudioSeatPoint(.90, .15),
        _AudioSeatPoint(.90, .45),
        _AudioSeatPoint(.90, .75),
        _AudioSeatPoint(.38, .75),
        _AudioSeatPoint(.66, .75),
      ];
    }

    /// 9 layout 4: round.
    if (count == 9 && layout == 3) {
      return const [
        _AudioSeatPoint(.50, .49),
        _AudioSeatPoint(.50, .1),
        _AudioSeatPoint(.79, .24),
        _AudioSeatPoint(.9, .50),
        _AudioSeatPoint(.79, .78),
        _AudioSeatPoint(.50, .90),
        _AudioSeatPoint(.21, .78),
        _AudioSeatPoint(.1, .50),
        _AudioSeatPoint(.21, .24),
      ];
    }

    /// ================= 12 SEAT LAYOUTS =================
    /// 12 layout 1: top 1, then 6, then 5.
    if (count == 12 && layout == 0) {
      return const [
        _AudioSeatPoint(.50, .095),
        _AudioSeatPoint(.08, .43),
        _AudioSeatPoint(.245, .43),
        _AudioSeatPoint(.415, .43),
        _AudioSeatPoint(.585, .43),
        _AudioSeatPoint(.755, .43),
        _AudioSeatPoint(.92, .43),
        _AudioSeatPoint(.12, .76),
        _AudioSeatPoint(.31, .76),
        _AudioSeatPoint(.50, .76),
        _AudioSeatPoint(.69, .76),
        _AudioSeatPoint(.88, .76),
      ];
    }

    /// 12 layout 2: 6 + 6.
    if (count == 12 && layout == 1) {
      return const [
        _AudioSeatPoint(.07, .15),
        _AudioSeatPoint(.25, .15),
        _AudioSeatPoint(.43, .15),
        _AudioSeatPoint(.60, .15),
        _AudioSeatPoint(.77, .15),
        _AudioSeatPoint(.93, .15),
        _AudioSeatPoint(.07, .50),
        _AudioSeatPoint(.24, .50),
        _AudioSeatPoint(.41, .50),
        _AudioSeatPoint(.59, .50),
        _AudioSeatPoint(.76, .50),
        _AudioSeatPoint(.93, .50),
      ];
    }

    /// 12 layout 3: owner center + left/right 4 + 4 + bottom 3.
    /// Bottom 3 seat left/right column-er last seat-er maj borabor aligned.
    if (count == 12 && layout == 2) {
      return const [
        /// Owner / host profile center
        _AudioSeatPoint(.50, .48),

        /// Left side 4 seats, equal gap
        _AudioSeatPoint(.10, .14),
        _AudioSeatPoint(.10, .40),
        _AudioSeatPoint(.10, .67),
        _AudioSeatPoint(.10, .93),

        /// Right side 4 seats, equal gap
        _AudioSeatPoint(.90, .14),
        _AudioSeatPoint(.90, .40),
        _AudioSeatPoint(.90, .67),
        _AudioSeatPoint(.90, .93),

        /// Bottom 3 seats: same y as side last seats, equal width/gap
        _AudioSeatPoint(.30, .93),
        _AudioSeatPoint(.50, .93),
        _AudioSeatPoint(.70, .93),
      ];
    }

    /// 12 layout 4: round with 2 middle.
    if (count == 12 && layout == 3) {
      return const [
        /// 12 round layout: 9-seat style perfect circle.
        /// 2 center seats + 10 outer seats with equal distance/gap.
        _AudioSeatPoint(.40, .52),
        _AudioSeatPoint(.60, .52),

        _AudioSeatPoint(.50, .14),
        _AudioSeatPoint(.73, .22),
        _AudioSeatPoint(.88, .40),
        _AudioSeatPoint(.88, .64),
        _AudioSeatPoint(.73, .82),
        _AudioSeatPoint(.50, .90),
        _AudioSeatPoint(.27, .82),
        _AudioSeatPoint(.12, .64),
        _AudioSeatPoint(.12, .40),
        _AudioSeatPoint(.27, .22),
      ];
    }

    /// 12 layout 5 / default: top 2, then 5, then 5.
    if (count == 12 && layout == 4) {
      return const [
        _AudioSeatPoint(.34, .105),
        _AudioSeatPoint(.66, .105),
        _AudioSeatPoint(.10, .46),
        _AudioSeatPoint(.30, .46),
        _AudioSeatPoint(.50, .46),
        _AudioSeatPoint(.70, .46),
        _AudioSeatPoint(.90, .46),
        _AudioSeatPoint(.10, .76),
        _AudioSeatPoint(.30, .76),
        _AudioSeatPoint(.50, .76),
        _AudioSeatPoint(.70, .76),
        _AudioSeatPoint(.90, .76),
      ];
    }

    /// ================= 15 SEAT DEFAULT =================
    /// 3 rows, 5 seats per row. Same size, equal horizontal gap.
    if (count == 15) {
      return const [
        _AudioSeatPoint(.10, .14),
        _AudioSeatPoint(.30, .14),
        _AudioSeatPoint(.50, .14),
        _AudioSeatPoint(.70, .14),
        _AudioSeatPoint(.90, .14),

        _AudioSeatPoint(.10, .49),
        _AudioSeatPoint(.30, .49),
        _AudioSeatPoint(.50, .49),
        _AudioSeatPoint(.70, .49),
        _AudioSeatPoint(.90, .49),

        _AudioSeatPoint(.10, .84),
        _AudioSeatPoint(.30, .84),
        _AudioSeatPoint(.50, .84),
        _AudioSeatPoint(.70, .84),
        _AudioSeatPoint(.90, .84),
      ];
    }

    /// ================= 20 SEAT DEFAULT =================
    /// 4 rows, 5 seats per row. Same size, equal horizontal/vertical gap.
    if (count == 20) {
      return const [
        _AudioSeatPoint(.10, .10),
        _AudioSeatPoint(.30, .10),
        _AudioSeatPoint(.50, .10),
        _AudioSeatPoint(.70, .10),
        _AudioSeatPoint(.90, .10),

        _AudioSeatPoint(.10, .39),
        _AudioSeatPoint(.30, .39),
        _AudioSeatPoint(.50, .39),
        _AudioSeatPoint(.70, .39),
        _AudioSeatPoint(.90, .39),

        _AudioSeatPoint(.10, .65),
        _AudioSeatPoint(.30, .65),
        _AudioSeatPoint(.50, .65),
        _AudioSeatPoint(.70, .65),
        _AudioSeatPoint(.90, .65),

        _AudioSeatPoint(.10, .91),
        _AudioSeatPoint(.30, .91),
        _AudioSeatPoint(.50, .91),
        _AudioSeatPoint(.70, .91),
        _AudioSeatPoint(.90, .91),
      ];
    }

    /// Defensive fallback: never return empty seats for bad/missing route
    /// data. Red packet banner join may temporarily pass 6 before backend
    /// seat snapshot arrives. Use 9-seat layout so room UI remains visible.
    return _seatPositions(count: 9, layout: 0);
  }

  bool _asBoolLocked(dynamic raw) {
    return raw == true ||
        raw == 1 ||
        raw.toString() == '1' ||
        raw.toString().toLowerCase() == 'yes' ||
        raw.toString().toLowerCase() == 'locked' ||
        raw.toString().toLowerCase() == 'true';
  }

  Future<void> _loadInitialSeatLocks() async {
    try {
      final streamId = int.tryParse(streamInfo['id']?.toString() ?? '') ?? 0;
      if (streamId == 0) {
        liveLog('⚠️ _loadInitialSeatLocks skipped: stream id missing');
        return;
      }

      final data = await liveController.getAvailableSeats(streamId);
      if (data == null) return;

      /// Banner Lucky Bag join can open the room with only packet data, so the
      /// first widget argument may say seatCount=6. The backend available-seat
      /// response is authoritative for current room seat count; apply it without
      /// resetting background/theme/title.
      final int backendSeatCount = _normalizeAudioSeatCount(
        data['total_seats'] ?? data['seat_count'] ?? data['seats_count'],
        fallback: liveSeatCount,
      );
      if (backendSeatCount != liveSeatCount ||
          !_isSupportedAudioSeatCount(liveSeatCount)) {
        websocketController.updateLiveRoomSettings(
          livestreamId: streamId,
          seatCount: backendSeatCount,
          roomLayout: liveRoomLayout,
          roomTheme: liveRoomTheme,
          roomBackground: liveRoomBackground,
          streamTitle: liveRoomTitleText,
          streamAnnouncement: liveRoomAnnouncementText,
          streamImage: _roomImageFromOwnData,
          streamPassword: _roomPasswordFromOwnData,
        );
        if (mounted) setState(() {});
        liveLog(
          '✅ Audio seat count repaired from available seats => $backendSeatCount',
        );
      }

      final Map<int, bool> locks = {};

      void addSeat(dynamic value, {bool locked = true}) {
        final seatNo = int.tryParse(value?.toString() ?? '') ?? 0;
        if (seatNo > 0) locks[seatNo] = locked;
      }

      void parseList(dynamic list) {
        if (list is! List) return;

        for (final item in list) {
          if (item is Map) {
            final seatNo =
                item['seat_no'] ??
                    item['seatNo'] ??
                    item['seat'] ??
                    item['no'] ??
                    item['number'];

            final rawLocked =
                item['is_locked'] ??
                    item['locked'] ??
                    item['lock'] ??
                    item['status'];

            if (seatNo != null && _asBoolLocked(rawLocked)) {
              addSeat(seatNo);
            }
          } else {
            addSeat(item);
          }
        }
      }

      /// Supported backend keys.
      /// Best: locked_seats: [2, 5] or locked_seats: [{seat_no:2,is_locked:true}]
      parseList(data['locked_seats']);
      parseList(data['lockedSeats']);
      parseList(data['locked_seat_numbers']);
      parseList(data['lockedSeatNumbers']);
      parseList(data['locks']);

      /// If backend returns all seats with status/is_locked.
      parseList(data['seats']);
      parseList(data['data']);

      final bool hasAuthoritativeLockKey =
          data is Map &&
              (data.containsKey('locked_seats') ||
                  data.containsKey('lockedSeats') ||
                  data.containsKey('locked_seat_numbers') ||
                  data.containsKey('lockedSeatNumbers') ||
                  data.containsKey('locks'));

      if (hasAuthoritativeLockKey && locks.isNotEmpty) {
        /// Server available-seats response is authoritative only when it returns
        /// real locked seats. If it returns locked_seats: [] during viewer leave,
        /// do NOT clear host manually locked seats. Explicit seat_unlocked event
        /// will unlock seats.
        final oldLockKeys = websocketController.lockedSeatMap.keys
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();

        for (final seatNo in oldLockKeys) {
          websocketController.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: false,
            source: 'audio_initial_available_seats_replace_clear',
          );
        }

        locks.forEach((seatNo, locked) {
          websocketController.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: locked,
            source: 'audio_initial_available_seats',
          );
        });

        liveLog('🔐 Initial locked seats REPLACED => ${locks.keys.toList()}');
      } else if (hasAuthoritativeLockKey && locks.isEmpty) {
        /// Backend clearly says no locked seats. Clear stale visual locks.
        /// Previous code kept old locks, causing a caller's old seat to show
        /// fake lock after that user left the live room.
        final oldLockKeys = websocketController.lockedSeatMap.keys
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();

        for (final seatNo in oldLockKeys) {
          websocketController.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: false,
            source: 'audio_available_seats_empty_clear_stale_locks',
          );
        }

        liveLog('🔓 Empty locked_seats cleared stale locks');
      } else if (locks.isNotEmpty) {
        locks.forEach((seatNo, locked) {
          websocketController.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: locked,
            source: 'audio_initial_available_seats',
          );
        });

        liveLog('🔐 Initial locked seats synced => ${locks.keys.toList()}');
      } else {
        /// Response has no trusted lock key. Do not clear current state.
        try {
          websocketController.syncSeatLocksFromAnyPayload(
            Map<String, dynamic>.from(data),
            allowUnlock: false,
            source: 'audio_available_seats_empty',
          );
        } catch (_) {}
        liveLog(
          'ℹ️ No authoritative locked seats found; keeping lock map: ${websocketController.lockedSeatMap.keys.toList()}',
        );
      }
    } catch (e) {
      liveLog('❌ Initial seat lock sync failed: $e');
    }
  }

  void _syncSeatLocksFromCallList() {
    /// Do NOT read `is_locked` from liveCallList.
    /// Backend call objects often return is_locked=yes for occupied seats,
    /// which made a user's old seat look locked after they left.
    /// Seat lock state must come only from:
    /// 1) lockedSeatMap realtime `seat_lock_toggle`
    /// 2) _loadInitialSeatLocks() available-seats response.
    return;
  }

  Map userData({required int seatNo}) {
    _syncSeatLocksFromCallList();

    var result = websocketController.liveCallList.firstWhere(
          (item) {
        if (item is! Map) return false;
        final itemSeat = item['seat_no'] ?? item['seat'] ?? item['seat_number'];
        final bool sameSeat = itemSeat.toString() == seatNo.toString();

        final user = item['user'];
        final hasUser =
            user is Map && (user['id'] != null || user['name'] != null);
        final hasCallerId =
            item['caller_id'] != null || item['user_id'] != null;
        final status = (item['call_status'] ?? item['status'] ?? 'accepted')
            .toString()
            .toLowerCase();

        return sameSeat &&
            (hasUser || hasCallerId) &&
            status != 'left' &&
            status != 'rejected' &&
            status != 'canceled' &&
            status != 'cancelled';
      },
      orElse: () {
        return {};
      },
    );

    return result is Map ? result : {};
  }

  // Battery Optimization Methods
  void _initializeBatteryMonitoring() {
    // ✅ STEP 3A: battery check was running every 10s. That is too frequent
    // for audio live rooms and adds unnecessary platform work/heat.
    if (_batteryCheckTimer != null) return;

    _batteryCheckTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      _checkBatteryLevel();
    });

    // Initial battery check
    _checkBatteryLevel();
  }

  Future<void> _checkBatteryLevel() async {
    try {
      final batteryLevel = await _batteryOptimizer.getCurrentBatteryLevel();
      final newPerformanceLevel = _batteryOptimizer.getPerformanceLevel(
        batteryLevel,
      );

      if (newPerformanceLevel != _currentPerformanceLevel) {
        _currentPerformanceLevel = newPerformanceLevel;
        await _applyPerformanceOptimizations();
        _scheduleUIUpdate();

        // Show battery warning if needed
        if (batteryLevel < 30) {
          _showBatteryWarning(batteryLevel);
        }
      }
    } catch (e) {
      liveLog('Error checking battery level: $e');
    }
  }

  Future<void> _applyPerformanceOptimizations() async {
    if (_agoraService.engine == null) return;

    final engine = _agoraService.engine!;
    final audioConfig = _batteryOptimizer.getOptimizedAudioConfig(
      _currentPerformanceLevel,
    );

    try {
      // Apply audio optimizations
      await engine.setAudioProfile(
        profile:
        audioConfig['profile'] ??
            AudioProfileType.audioProfileSpeechStandard,
        scenario:
        audioConfig['scenario'] ??
            AudioScenarioType.audioScenarioGameStreaming,
      );

      // ✅ FIX: BatteryOptimizer already computes a scaled-down video config
      // per performance level (getOptimizedVideoConfig/applyOptimizations),
      // but nothing in the app ever called it, so video encoding never
      // actually backed off on low battery/thermal pressure — this is a
      // large part of why the phone runs hot and stutters during long
      // streams. Only touch it when this device is actually publishing
      // video (camera seat/video call); audio-only participants don't
      // encode video so there is nothing to scale down for them.
      if (_effectiveBroadcaster || _shouldPublishCurrentUserMicrophone()) {
        try {
          await engine.setVideoEncoderConfiguration(
            _batteryOptimizer.getOptimizedVideoConfig(_currentPerformanceLevel),
          );
          if (_currentPerformanceLevel == PerformanceLevel.critical) {
            // Matches BatteryOptimizer.applyOptimizations: stop encoding
            // local video entirely to save maximum power at critical battery.
            await engine.enableLocalVideo(false);
          }
        } catch (e) {
          liveLog('Error applying performance video config: $e');
        }
      }

      // Update ping interval based on performance level
      final pingInterval = _batteryOptimizer.getOptimizedPingInterval(
        _currentPerformanceLevel,
      );
      liveController.updatePingInterval(pingInterval);

      liveLog(
        '🔋 Applied performance optimizations for level: $_currentPerformanceLevel',
      );
    } catch (e) {
      liveLog('Error applying performance optimizations: $e');
    }
  }

  void _scheduleUIUpdate() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && !_isLiveExiting) {
        setState(() {});
      }
    });
  }

  void _showBatteryWarning(int batteryLevel) {
    String message;
    if (batteryLevel < 15) {
      message = "🔴 Critical battery! Maximum power saving enabled";
    } else if (batteryLevel < 30) {
      message = "⚠️ Low battery! Switching to power saving mode";
    } else {
      return;
    }

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }
}

String formatNumber(dynamic number) {
  int value = int.tryParse(number.toString()) ?? 0;

  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  } else {
    return value.toString();
  }
}

class _GuardianMarqueeNotice extends StatefulWidget {
  final String text;

  const _GuardianMarqueeNotice({required this.text});

  @override
  State<_GuardianMarqueeNotice> createState() => _GuardianMarqueeNoticeState();
}

class _GuardianMarqueeNoticeState extends State<_GuardianMarqueeNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 34,
        width: Get.width * 0.86,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.46),
              kAppColor.withOpacity(0.72),
              Colors.black.withOpacity(0.46),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double start = Get.width * 0.78;
            final double end = -(Get.width * 0.90);
            final double dx = start + (end - start) * _controller.value;

            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 22,
                  width: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: Get.height * 0.0135,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}