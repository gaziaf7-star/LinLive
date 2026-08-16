import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/roket_controller.dart';

class RocketLaunchOverlay extends StatefulWidget {
  const RocketLaunchOverlay({
    super.key,
    required this.livestreamId,
  });

  final int livestreamId;

  @override
  State<RocketLaunchOverlay> createState() => _RocketLaunchOverlayState();
}

class _RocketLaunchOverlayState extends State<RocketLaunchOverlay> {
  late final RocketController controller;
  String _lastVisibleEventKey = '';

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<RocketController>()
        ? Get.find<RocketController>()
        : Get.put(RocketController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.livestreamId > 0) {
        controller.bindLivestream(widget.livestreamId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant RocketLaunchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.livestreamId > 0 && widget.livestreamId != oldWidget.livestreamId) {
      controller.bindLivestream(widget.livestreamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.roomLaunchVisible.value || controller.roomLaunchData.isEmpty) {
        return const SizedBox.shrink();
      }

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(controller.roomLaunchData);
      final int eventLivestreamId = _livestreamId(data);
      // The controller is synchronously bound from the authoritative active
      // room before it accepts a launch. The widget argument can briefly still
      // be 0/old while AudioLiveView is completing its reactive room setup.
      if (eventLivestreamId <= 0 ||
          eventLivestreamId != controller.currentLivestreamId.value) {
        return const SizedBox.shrink();
      }

      final String eventKey = <dynamic>[
        data['event_id'],
        data['launch_event_id'],
        data['session_id'],
        data['level_id'],
        data['level_no'],
        data['timestamp'],
      ].map((dynamic e) => e?.toString() ?? '').join('|');

      if (_lastVisibleEventKey != eventKey) {
        _lastVisibleEventKey = eventKey;
        debugPrint(
          '[ROCKET_LAUNCH][OVERLAY_VISIBLE] '
          'event_id=${data['event_id'] ?? data['launch_event_id'] ?? ''}',
        );
      }

      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: RepaintBoundary(
            child: _RocketLaunchScene(
              key: ValueKey<String>('rocket_launch_$eventKey'),
              data: data,
              onFinished: controller.finishRoomLaunch,
            ),
          ),
        ),
      );
    });
  }

  int _livestreamId(Map<String, dynamic> data) {
    final Map<String, dynamic> live = data['livestream'] is Map
        ? Map<String, dynamic>.from(data['livestream'])
        : <String, dynamic>{};
    return int.tryParse(
      '${data['livestream_id'] ?? data['stream_id'] ?? data['live_stream_id'] ?? live['id'] ?? 0}',
    ) ??
        0;
  }
}

class _RocketLaunchScene extends StatefulWidget {
  const _RocketLaunchScene({
    super.key,
    required this.data,
    required this.onFinished,
  });

  final Map<String, dynamic> data;
  final VoidCallback onFinished;

  @override
  State<_RocketLaunchScene> createState() => _RocketLaunchSceneState();
}

class _RocketLaunchSceneState extends State<_RocketLaunchScene>
    with TickerProviderStateMixin {
  static const int _countdownStart = 7;
  static const Duration _flightDuration = Duration(milliseconds: 1750);
  static const Duration _rewardVisibleDuration = Duration(milliseconds: 6800);

  late final AnimationController _flightController;
  late final AnimationController _ambientController;
  late final Animation<double> _flightCurve;
  late final RocketController _rocketController;

  /// A fresh player is created only when playback starts. Reusing a fixed
  /// playerId across several rocket overlays made Android point to an already
  /// disposed native player. Calling stop() before the first play also caused:
  /// "Player has not yet been created or has already been disposed."
  AudioPlayer? _launchSoundPlayer;
  bool _launchSoundNativeReady = false;
  bool _sceneDisposed = false;

  Worker? _rankingWorker;
  Future<ByteData>? _soundAssetWarmup;

  Timer? _countdownTimer;
  Timer? _launchDelayTimer;
  Timer? _rewardTimer;
  Timer? _finishTimer;

  int _countdown = _countdownStart;
  bool _launchStarted = false;
  bool _showRewardBoard = false;
  bool _finished = false;
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    _rocketController = Get.isRegistered<RocketController>()
        ? Get.find<RocketController>()
        : Get.put(RocketController(), permanent: true);
    _flightController = AnimationController(
      vsync: this,
      duration: _flightDuration,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _flightCurve = CurvedAnimation(
      parent: _flightController,
      curve: Curves.easeInCubic,
    );

    // Warm the bundled audio bytes before the first frame. Sound playback is
    // started with the countdown, not after the countdown/rocket launch.
    _soundAssetWarmup = rootBundle.load('assets/Pk/roketSound.mp3');

    // The compact realtime launch payload may receive ranking/profile data a
    // moment later from RocketController.fetchRanking(). Rebuild only this
    // isolated overlay when TOP1 data arrives.
    _rankingWorker = ever(
      _rocketController.ranking,
          (_) {
        if (!mounted) return;
        setState(() {});
        unawaited(_precacheTopProfile());
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_precacheLaunchAssets());
      _startCountdown();
    });
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  String _text(dynamic value, [String fallback = '']) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _url(dynamic value) {
    final String raw = _text(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  Map<String, dynamic> get _level {
    return _map(widget.data['level'] ?? widget.data['rocket_level']);
  }

  String get _rocketImage {
    final Map<String, dynamic> level = _level;
    return _url(
      widget.data['rocket_image'] ??
          widget.data['rocket_image_url'] ??
          widget.data['image'] ??
          level['rocket_image'] ??
          level['rocket_image_url'] ??
          level['image'] ??
          level['show_image'],
    );
  }

  String get _launchAnimationUrl {
    final Map<String, dynamic> level = _level;
    return _url(
      widget.data['launch_animation'] ??
          widget.data['launch_animation_url'] ??
          widget.data['animation'] ??
          widget.data['animation_url'] ??
          level['launch_animation'] ??
          level['launch_animation_url'] ??
          level['animation'] ??
          level['animation_url'],
    );
  }

  String get _launchSoundUrl {
    final Map<String, dynamic> level = _level;
    final String raw = _text(
      widget.data['launch_sound'] ??
          widget.data['launch_sound_url'] ??
          widget.data['sound'] ??
          widget.data['sound_url'] ??
          level['launch_sound'] ??
          level['launch_sound_url'] ??
          level['sound'] ??
          level['sound_url'],
    );
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '';
  }

  Map<String, dynamic> _topOneUser() {
    Map<String, dynamic> userFrom(dynamic raw) {
      final Map<String, dynamic> row = _map(raw);
      if (row.isEmpty) return <String, dynamic>{};
      final Map<String, dynamic> nested = _map(
        row['user'] ??
            row['winner'] ??
            row['sender'] ??
            row['gifter'] ??
            row['gift_sender'] ??
            row['top_user'] ??
            row['top1_user'] ??
            row['contributor'] ??
            row['member'] ??
            row['profile'] ??
            row['broadcaster'] ??
            row['host'],
      );
      if (nested.isNotEmpty) return <String, dynamic>{...row, ...nested};
      return row;
    }

    // Current-session ranking is the safest source for the real TOP1 user.
    // The launch payload can be compact, therefore also read nested payloads
    // and the already-bound RocketController ranking snapshot.
    final Map<String, dynamic> dataMap = _map(widget.data['data']);
    final Map<String, dynamic> launchMap = _map(
      widget.data['launch'] ?? widget.data['rocket_launch'],
    );
    final Map<String, dynamic> rocketMap = _map(widget.data['rocket']);
    final Map<String, dynamic> stateMap = _map(
      widget.data['rocket_state'] ?? widget.data['state'],
    );
    final Map<String, dynamic> sessionMap = _map(widget.data['session']);
    final Map<String, dynamic> lastLaunchMap =
    _map(_rocketController.lastLaunch);

    final List<Map<String, dynamic>> ranking = _list(
      widget.data['ranking'] ??
          widget.data['contributors'] ??
          widget.data['top_contributors'] ??
          widget.data['top_gifters'] ??
          dataMap['ranking'] ??
          dataMap['contributors'] ??
          launchMap['ranking'] ??
          launchMap['contributors'] ??
          rocketMap['ranking'] ??
          stateMap['ranking'] ??
          sessionMap['ranking'] ??
          lastLaunchMap['ranking'],
    );

    if (ranking.isEmpty && _rocketController.ranking.isNotEmpty) {
      ranking.addAll(
        _rocketController.ranking
            .map((Map<String, dynamic> row) =>
        Map<String, dynamic>.from(row)),
      );
    }

    if (ranking.isNotEmpty) {
      ranking.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        final int ar = _int(a['rank'] ?? a['position'] ?? a['ranking'] ?? 999999);
        final int br = _int(b['rank'] ?? b['position'] ?? b['ranking'] ?? 999999);
        if (ar != br) return ar.compareTo(br);
        final int ac = _int(
          a['contribution_coins'] ?? a['total_coins'] ?? a['coins'],
        );
        final int bc = _int(
          b['contribution_coins'] ?? b['total_coins'] ?? b['coins'],
        );
        return bc.compareTo(ac);
      });
      final Map<String, dynamic> top = userFrom(ranking.first);
      if (top.isNotEmpty) return top;
    }

    // Some backends send a direct top contributor instead of ranking=[].
    for (final dynamic raw in <dynamic>[
      widget.data['top1_user'],
      widget.data['top_user'],
      widget.data['top_contributor'],
      widget.data['top_gifter'],
      widget.data['top_sender'],
      widget.data['highest_contributor'],
      widget.data['sender'],
      widget.data['gifter'],
      widget.data['gift_sender'],
      dataMap['top1_user'],
      dataMap['top_user'],
      dataMap['top_gifter'],
      dataMap['sender'],
      launchMap['top1_user'],
      launchMap['top_contributor'],
      launchMap['top_gifter'],
      launchMap['sender'],
      rocketMap['top1_user'],
      stateMap['top1_user'],
      sessionMap['top1_user'],
      lastLaunchMap['top1_user'],
      lastLaunchMap['top_gifter'],
    ]) {
      final Map<String, dynamic> top = userFrom(raw);
      if (top.isNotEmpty) return top;
    }

    // Launch reward result may already contain TOP1 winner details.
    final Map<String, dynamic> rewardRoot = _map(
      widget.data['reward_results'] ??
          widget.data['winner_results'] ??
          widget.data['reward_result'],
    );

    final dynamic topRaw = rewardRoot['top1'] ??
        rewardRoot['top_1'] ??
        widget.data['top1'] ??
        widget.data['top_1'] ??
        widget.data['top_one'];
    if (topRaw is List && topRaw.isNotEmpty) {
      final Map<String, dynamic> top = userFrom(topRaw.first);
      if (top.isNotEmpty) return top;
    }
    if (topRaw is Map) {
      final Map<String, dynamic> top = userFrom(topRaw);
      if (top.isNotEmpty) return top;
    }

    final List<Map<String, dynamic>> winners = _list(
      rewardRoot['winners'] ??
          rewardRoot['items'] ??
          widget.data['winners'] ??
          widget.data['reward_winners'],
    );
    for (final Map<String, dynamic> winner in winners) {
      final String slot = _text(
        winner['slot'] ?? winner['rank_title'] ?? winner['title'],
      ).toUpperCase();
      final int rank = _int(winner['rank'] ?? winner['position']);
      if (slot == 'TOP1' || slot == 'TOP 1' || rank == 1) {
        final Map<String, dynamic> top = userFrom(winner);
        if (top.isNotEmpty) return top;
      }
    }

    final Map<String, dynamic> room = _map(
      widget.data['livestream'] ?? widget.data['room'],
    );
    return userFrom(
      widget.data['owner'] ??
          widget.data['host'] ??
          widget.data['user'] ??
          room['user'] ??
          room['owner'] ??
          room['host'],
    );
  }

  String _topProfileImage(Map<String, dynamic> topUser) {
    return _url(
      topUser['profile_image'] ??
          topUser['profile_image_url'] ??
          topUser['profileImage'] ??
          topUser['profileImageUrl'] ??
          topUser['profile_photo_url'] ??
          topUser['profile_photo_path'] ??
          topUser['profile_picture'] ??
          topUser['profile_picture_url'] ??
          topUser['user_image'] ??
          topUser['user_image_url'] ??
          topUser['picture'] ??
          topUser['picture_url'] ??
          topUser['avatar'] ??
          topUser['avatar_url'] ??
          topUser['image'] ??
          topUser['image_url'] ??
          topUser['photo'] ??
          topUser['photo_url'],
    );
  }

  String _topName(Map<String, dynamic> topUser) {
    return _text(
      topUser['name'] ??
          topUser['username'] ??
          topUser['user_name'] ??
          topUser['full_name'] ??
          topUser['display_name'] ??
          topUser['nickname'] ??
          topUser['nick_name'],
      'TOP 1',
    );
  }

  Future<void> _precacheLaunchAssets() async {
    final String rocket = _rocketImage;
    if (rocket.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(rocket), context);
      } catch (_) {}
    }
    await _precacheTopProfile();
  }

  Future<void> _precacheTopProfile() async {
    if (!mounted) return;
    final String profile = _topProfileImage(_topOneUser());
    if (profile.isEmpty) return;
    try {
      await precacheImage(CachedNetworkImageProvider(profile), context);
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _countdownStart;

    // Reference timing: rocket sound starts as soon as the full-screen rocket
    // scene appears. It must not wait until countdown reaches 1.
    unawaited(_playLaunchSound());

    if (mounted) setState(() {});

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted || _launchStarted) {
        timer.cancel();
        return;
      }

      final int next = _countdown - 1;
      if (next <= 1) {
        timer.cancel();
        setState(() => _countdown = 1);
        _launchDelayTimer?.cancel();
        _launchDelayTimer = Timer(
          const Duration(milliseconds: 520),
          _startRocketLaunch,
        );
        return;
      }

      setState(() => _countdown = next);
    });
  }

  Future<void> _prepareRocketAudioContext(AudioPlayer player) async {
    await player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: <AVAudioSessionOptions>{
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    );
  }

  Future<void> _playSoundUsingFreshPlayer() async {
    if (_sceneDisposed) return;

    /// Do not use a fixed playerId. Audioplayers will generate a unique native
    /// player id, so a previous overlay cannot invalidate this scene's player.
    final AudioPlayer player = AudioPlayer();
    _launchSoundPlayer = player;
    _launchSoundNativeReady = false;

    await _prepareRocketAudioContext(player);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    await player.setVolume(1.0);

    /// Most importantly: do NOT call stop() before play(). On Android the
    /// native player does not exist yet at that point.
    await player.play(
      AssetSource('Pk/roketSound.mp3'),
      volume: 1.0,
      mode: PlayerMode.mediaPlayer,
    );

    _launchSoundNativeReady = true;
  }

  Future<void> _playLaunchSound() async {
    if (_soundPlayed || _sceneDisposed) return;
    _soundPlayed = true;

    try {
      /// rootBundle keys include assets/, AssetSource paths are relative to it.
      await (_soundAssetWarmup ??
          rootBundle.load('assets/Pk/roketSound.mp3'));

      await _playSoundUsingFreshPlayer();
      debugPrint('✅ Rocket sound started exactly with rocket overlay');
    } catch (error, stackTrace) {
      debugPrint('ROCKET SOUND ERROR => $error');
      debugPrintStack(stackTrace: stackTrace);

      /// A failed player may not have a native Android object, so do not call
      /// stop/release on it. Drop it and retry with another unique player.
      _launchSoundPlayer = null;
      _launchSoundNativeReady = false;

      try {
        if (_sceneDisposed) return;
        await _playSoundUsingFreshPlayer();
        debugPrint('✅ Rocket sound retry started with fresh player');
      } catch (retryError, retryStack) {
        debugPrint('ROCKET SOUND RETRY ERROR => $retryError');
        debugPrintStack(stackTrace: retryStack);
        _launchSoundPlayer = null;
        _launchSoundNativeReady = false;
      }
    }
  }

  Future<void> _disposeLaunchSoundSafely() async {
    final AudioPlayer? player = _launchSoundPlayer;
    _launchSoundPlayer = null;

    /// dispose() internally calls release/stop. Only call it after play()
    /// successfully created the native Android player.
    if (player == null || !_launchSoundNativeReady) return;
    _launchSoundNativeReady = false;

    try {
      await player.dispose();
    } catch (error) {
      debugPrint('⚠️ Rocket sound dispose ignored safely => $error');
    }
  }

  void _startRocketLaunch() {
    if (_launchStarted || !mounted) return;
    setState(() => _launchStarted = true);
    _flightController.forward(from: 0);

    _rewardTimer?.cancel();
    _rewardTimer = Timer(const Duration(milliseconds: 1850), _showRewardsNow);
  }

  void _showRewardsNow() {
    if (!mounted || _showRewardBoard) return;
    setState(() => _showRewardBoard = true);

    _finishTimer?.cancel();
    _finishTimer = Timer(_rewardVisibleDuration, _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _countdownTimer?.cancel();
    _launchDelayTimer?.cancel();
    _rewardTimer?.cancel();
    _finishTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _sceneDisposed = true;
    _countdownTimer?.cancel();
    _launchDelayTimer?.cancel();
    _rewardTimer?.cancel();
    _finishTimer?.cancel();
    _rankingWorker?.dispose();
    _ambientController.dispose();
    _flightController.dispose();

    /// All platform exceptions are caught inside the async cleanup method.
    unawaited(_disposeLaunchSoundSafely());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> topUser = _topOneUser();
    final String topProfile = _topProfileImage(topUser);
    final String topName = _topName(topUser);
    final Map<String, dynamic> level = _level;
    final int levelNo = _int(
      widget.data['level_no'] ?? level['level_no'] ?? level['level'] ?? level['id'],
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _showRewardBoard ? 0 : 1,
          child: Container(
            color: Colors.black.withOpacity(.16),
          ),
        ),
        if (!_showRewardBoard)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              final double height = constraints.maxHeight;
              final double safeTop = MediaQuery.paddingOf(context).top;
              /// The reference video uses a rocket that fills almost the
              /// complete lower screen. Keep it large on small and large phones.
              final double rocketWidth =
              (width * 1.08).clamp(350.0, 650.0).toDouble();
              final double rocketHeight =
              (height * .82).clamp(540.0, 920.0).toDouble();

              return Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: <Widget>[
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _RocketLaunchEnergyPainter(
                        animation: _ambientController,
                        intensity: _launchStarted ? 1 : .78,
                        launching: _launchStarted,
                      ),
                    ),
                  ),

                  // Rocket stays below the countdown. In the previous layout it
                  // was painted after the number and covered it visually.
                  AnimatedBuilder(
                    animation: _flightController,
                    builder: (BuildContext context, Widget? child) {
                      final double t = _flightCurve.value;
                      final double y =
                      _launchStarted ? -(height * .88 * t) : 0;
                      final double scale = _launchStarted
                          ? 1 +
                          (.12 *
                              (1 - (t - .28).abs())
                                  .clamp(0.0, 1.0)
                                  .toDouble())
                          : 1;
                      final double opacity = t < .82
                          ? 1
                          : (1 - ((t - .82) / .18))
                          .clamp(0.0, 1.0)
                          .toDouble();

                      return Transform.translate(
                        offset: Offset(0, y),
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(opacity: opacity, child: child),
                        ),
                      );
                    },
                    child: Align(
                      alignment: const Alignment(0, .84),
                      child: SizedBox(
                        width: rocketWidth,
                        height: rocketHeight,
                        child: RepaintBoundary(
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: <Widget>[
                              if (_launchStarted)
                                _RocketMedia(
                                  animationUrl: _launchAnimationUrl,
                                  rocketImageUrl: _rocketImage,
                                  onMediaFinished: () {},
                                )
                              else
                                _StaticRocketImage(
                                  rocketImageUrl: _rocketImage,
                                ),
                              if (_launchStarted)
                                const Positioned(
                                  bottom: 6,
                                  child: _RocketEngineFlame(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Countdown is painted ABOVE the rocket, matching the
                  // provided reference video.
                  Positioned(
                    top: height * .275,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: _launchStarted ? 0 : 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            reverseDuration:
                            const Duration(milliseconds: 260),

                            /// IMPORTANT:
                            /// AnimatedSwitcher applies switchInCurve to the
                            /// animation passed into transitionBuilder.
                            /// easeOutBack can temporarily return values above
                            /// 1.0. Feeding that overshoot into FadeTransition
                            /// caused:
                            /// "parametric value ... is outside of [0, 1]".
                            ///
                            /// Keep the base animation strictly inside 0..1.
                            /// The visual overshoot is applied only to scale,
                            /// where values above 1.0 are valid.
                            switchInCurve: Curves.linear,
                            switchOutCurve: Curves.linear,
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              final Animation<double> fade = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );

                              final Animation<double> scale =
                              Tween<double>(
                                begin: .68,
                                end: 1,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                  reverseCurve: Curves.easeInCubic,
                                ),
                              );

                              return FadeTransition(
                                opacity: fade,
                                child: ScaleTransition(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: _BigRocketCountdownNumber(
                              key: ValueKey<int>(_countdown),
                              value: _countdown,
                              fontSize: (width * .285)
                                  .clamp(108.0, 168.0)
                                  .toDouble(),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            levelNo > 0
                                ? 'ROCKET LV.$levelNo'
                                : 'ROCKET READY',
                            style: const TextStyle(
                              color: Color(0xffe8fdff),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.35,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Color(0xff00eaff),
                                  blurRadius: 16,
                                ),
                                Shadow(
                                  color: Color(0xff006dff),
                                  blurRadius: 22,
                                ),
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 9,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // TOP1 profile remains visible throughout launch and updates
                  // smoothly when the ranking hydration request completes.
                  Positioned(
                    top: safeTop + 8,
                    left: 10,
                    right: 10,
                    child: AnimatedBuilder(
                      animation: _ambientController,
                      builder: (BuildContext context, Widget? child) {
                        final double wave =
                        math.sin(_ambientController.value * math.pi * 2);
                        return Transform.translate(
                          offset: Offset(0, wave * 2.5),
                          child: Transform.scale(
                            scale: 1 + (wave * .008),
                            child: child,
                          ),
                        );
                      },
                      child: _TopOneRocketProfile(
                        profileUrl: topProfile,
                        name: topName,
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        else
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: .90, end: 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (_, double scale, Widget? child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: _RocketRewardBoard(data: widget.data),
            ),
          ),
      ],
    );
  }
}

class _BigRocketCountdownNumber extends StatelessWidget {
  const _BigRocketCountdownNumber({
    super.key,
    required this.value,
    required this.fontSize,
  });

  final int value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = TextStyle(
      fontSize: fontSize,
      height: .80,
      fontWeight: FontWeight.w900,
      letterSpacing: -5,
    );

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          /// Wide cyan glow, like the reference number sitting inside the
          /// rocket's blue electric field.
          Text(
            '$value',
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 18
                ..color = const Color(0x9900dfff),
              shadows: const <Shadow>[
                Shadow(color: Color(0xff00eaff), blurRadius: 30),
                Shadow(color: Color(0xff006dff), blurRadius: 42),
              ],
            ),
          ),
          /// Clean dark separator keeps every digit sharp over a bright rocket.
          Text(
            '$value',
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 10
                ..color = const Color(0xff15336f),
              shadows: const <Shadow>[
                Shadow(
                  color: Colors.black87,
                  blurRadius: 11,
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),
          /// Bright white/gold HD border.
          Text(
            '$value',
            textAlign: TextAlign.center,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5
                ..color = const Color(0xfffffff2),
              shadows: const <Shadow>[
                Shadow(color: Color(0xffffc400), blurRadius: 18),
              ],
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[0, .28, .68, 1],
              colors: <Color>[
                Color(0xffffffff),
                Color(0xfffff891),
                Color(0xffffc400),
                Color(0xffff7900),
              ],
            ).createShader(bounds),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: base.copyWith(color: Colors.white),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: const Alignment(-.18, -.55),
                child: Container(
                  width: fontSize * .22,
                  height: fontSize * .055,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.white.withOpacity(.78),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.white, blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopOneRocketProfile extends StatelessWidget {
  const _TopOneRocketProfile({
    required this.profileUrl,
    required this.name,
  });

  final String profileUrl;

  /// Kept only to generate a useful fallback initial when profile image is
  /// unavailable. The name itself is intentionally not rendered.
  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.trim().isEmpty
        ? '1'
        : name.trim().characters.first.toUpperCase();

    return RepaintBoundary(
      child: SizedBox(
        height: 154,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            const Positioned(
              top: 21,
              child: CustomPaint(
                size: Size(310, 126),
                painter: _RocketTopWingPainter(),
              ),
            ),
            Positioned(
              top: 3,
              child: Icon(
                Icons.workspace_premium_rounded,
                color: const Color(0xffffdf58),
                size: 36,
                shadows: <Shadow>[
                  Shadow(
                    color: const Color(0xffff9d00).withOpacity(.95),
                    blurRadius: 15,
                  ),
                  const Shadow(
                    color: Color(0xff00e5ff),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 28,
              child: Container(
                width: 112,
                height: 112,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: <Color>[
                      Color(0xfffff3a0),
                      Color(0xffffb700),
                      Color(0xffff6f00),
                      Color(0xfffff6b3),
                      Color(0xffffb700),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xfffff7c7),
                    width: 2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0xaaff9d00),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: Color(0x7700e5ff),
                      blurRadius: 34,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xff08233b),
                  ),
                  child: ClipOval(
                    child: profileUrl.isEmpty
                        ? Container(
                      color: const Color(0xff183b61),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          shadows: <Shadow>[
                            Shadow(
                              color: Color(0xff00dfff),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                    )
                        : CachedNetworkImage(
                      imageUrl: profileUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: 420,
                      memCacheHeight: 420,
                      filterQuality: FilterQuality.high,
                      placeholder: (_, __) => const ColoredBox(
                        color: Color(0xff183b61),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xffffcf45),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xff183b61),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RocketTopWingPainter extends CustomPainter {
  const _RocketTopWingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, 54);
    final Rect shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Paint gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xfffff5ae),
          Color(0xffffcf35),
          Color(0xffff8a00),
          Color(0xffa94700),
        ],
      ).createShader(shaderRect)
      ..style = PaintingStyle.fill;

    final Paint highlight = Paint()
      ..color = const Color(0xfffff5c4).withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    Path wing(bool left) {
      final double s = left ? -1 : 1;
      final Path p = Path()
        ..moveTo(center.dx + (s * 42), center.dy + 4)
        ..cubicTo(
          center.dx + (s * 77),
          center.dy - 20,
          center.dx + (s * 118),
          center.dy - 16,
          center.dx + (s * 146),
          center.dy - 42,
        )
        ..cubicTo(
          center.dx + (s * 139),
          center.dy - 5,
          center.dx + (s * 119),
          center.dy + 19,
          center.dx + (s * 93),
          center.dy + 28,
        )
        ..cubicTo(
          center.dx + (s * 122),
          center.dy + 27,
          center.dx + (s * 139),
          center.dy + 20,
          center.dx + (s * 153),
          center.dy + 10,
        )
        ..cubicTo(
          center.dx + (s * 139),
          center.dy + 48,
          center.dx + (s * 100),
          center.dy + 59,
          center.dx + (s * 55),
          center.dy + 45,
        )
        ..close();
      return p;
    }

    final Path left = wing(true);
    final Path right = wing(false);
    canvas.drawPath(left, gold);
    canvas.drawPath(right, gold);

    for (int i = 0; i < 5; i++) {
      final double y = center.dy - 22 + (i * 14);
      final double length = 64 + (i * 7);
      canvas.drawLine(
        Offset(center.dx - 48, y),
        Offset(center.dx - length, y - 16 + (i * 2)),
        highlight,
      );
      canvas.drawLine(
        Offset(center.dx + 48, y),
        Offset(center.dx + length, y - 16 + (i * 2)),
        highlight,
      );
    }

    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xffffd54f).withOpacity(.42),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: 92),
      );
    canvas.drawCircle(center, 92, glow);
  }

  @override
  bool shouldRepaint(covariant _RocketTopWingPainter oldDelegate) => false;
}

class _StaticRocketImage extends StatelessWidget {
  const _StaticRocketImage({required this.rocketImageUrl});

  final String rocketImageUrl;

  @override
  Widget build(BuildContext context) {
    if (rocketImageUrl.isEmpty) {
      return const Icon(
        Icons.rocket_launch_rounded,
        color: Colors.white,
        size: 190,
        shadows: <Shadow>[
          Shadow(color: Color(0xff00e5ff), blurRadius: 26),
        ],
      );
    }

    return CachedNetworkImage(
      imageUrl: rocketImageUrl,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: 1400,
      filterQuality: FilterQuality.high,
      placeholder: (_, __) => const Icon(
        Icons.rocket_launch_rounded,
        color: Colors.white,
        size: 190,
      ),
      errorWidget: (_, __, ___) => const Icon(
        Icons.rocket_launch_rounded,
        color: Colors.white,
        size: 190,
      ),
    );
  }
}

class _RocketEngineFlame extends StatefulWidget {
  const _RocketEngineFlame();

  @override
  State<_RocketEngineFlame> createState() => _RocketEngineFlameState();
}

class _RocketEngineFlameState extends State<_RocketEngineFlame> {
  bool _large = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted) setState(() => _large = !_large);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 85),
      width: _large ? 56 : 44,
      height: _large ? 130 : 108,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
          bottom: Radius.circular(50),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xffffffff),
            Color(0xff55f4ff),
            Color(0xff1b9dff),
            Color(0x001b9dff),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xff4bf4ff), blurRadius: 28, spreadRadius: 4),
        ],
      ),
    );
  }
}

class _RocketLaunchEnergyPainter extends CustomPainter {
  _RocketLaunchEnergyPainter({
    required this.animation,
    required this.intensity,
    required this.launching,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double intensity;
  final bool launching;

  double _noise(int seed) {
    final double value = math.sin(seed * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  void _drawLightning(
      Canvas canvas,
      Size size, {
        required double baseX,
        required double startY,
        required double endY,
        required int seed,
        required double direction,
        required double alpha,
      }) {
    final Path path = Path()..moveTo(baseX, startY);
    const int points = 10;

    for (int i = 1; i <= points; i++) {
      final double progress = i / points;
      final double y = startY + ((endY - startY) * progress);
      final double spread =
          (10 + (_noise(seed + i) * 35)) * direction;
      final double centerPull =
          (size.width * .5 - baseX) * progress * .22;
      path.lineTo(baseX + spread + centerPull, y);
    }

    final Paint outer = Paint()
      ..color = const Color(0xff008cff).withOpacity(alpha * .45)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(path, outer);

    final Paint core = Paint()
      ..color = const Color(0xffd9ffff).withOpacity(alpha)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawPath(path, core);
  }

  void _drawCoin(
      Canvas canvas, {
        required Offset center,
        required double radius,
        required double rotation,
        required double opacity,
      }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final Rect coinRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2,
      height: radius * .72,
    );

    final Paint glow = Paint()
      ..color = const Color(0xffffb300).withOpacity(opacity * .45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(coinRect.inflate(radius * .45), glow);

    final Paint coin = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xfffff4a8),
          Color(0xffffc400),
          Color(0xffff7a00),
        ],
      ).createShader(coinRect);
    canvas.drawOval(coinRect, coin);

    final Paint edge = Paint()
      ..color = const Color(0xfffff4c3).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawOval(coinRect, edge);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animation.value;
    final Rect full = Offset.zero & size;
    final double pulse =
        .82 + (math.sin(t * math.pi * 2) * .10);

    /// Deep, clear blue full-screen tint matching the uploaded reference.
    final Paint backdrop = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xff03165c).withOpacity(.46 * intensity),
          const Color(0xff041b65).withOpacity(.34 * intensity),
          const Color(0xff031444).withOpacity(.45 * intensity),
          const Color(0xff010817).withOpacity(.68 * intensity),
        ],
      ).createShader(full);
    canvas.drawRect(full, backdrop);

    /// Large blue planet/energy halo behind the rocket.
    final Offset haloCenter = Offset(size.width * .5, size.height * .47);
    final Paint halo = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xffd7ffff).withOpacity(.17 * intensity * pulse),
          const Color(0xff00dfff).withOpacity(.25 * intensity * pulse),
          const Color(0xff005eff).withOpacity(.18 * intensity),
          Colors.transparent,
        ],
        stops: const <double>[0, .25, .60, 1],
      ).createShader(
        Rect.fromCircle(
          center: haloCenter,
          radius: size.width * .76,
        ),
      );
    canvas.drawCircle(haloCenter, size.width * .76, halo);

    /// Dense vertical neon rails across the entire page.
    for (int i = 0; i < 46; i++) {
      final double x = size.width * _noise(i + 3);
      final double speed = .30 + (_noise(i + 90) * 1.10);
      final double length = 100 + (_noise(i + 170) * 350);
      final double y =
          ((t * size.height * speed) +
              (_noise(i + 44) * size.height * 1.5)) %
              (size.height + length) -
              length;
      final double alpha =
          (.07 + (_noise(i + 210) * .34)) * intensity;
      final double railWidth = .65 + (_noise(i + 260) * 2.5);

      final Paint rail = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            const Color(0xffb7ffff).withOpacity(alpha),
            const Color(0xff00d9ff).withOpacity(alpha),
            const Color(0xff2169ff).withOpacity(alpha * .9),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromLTWH(x, y, railWidth + 3, length),
        )
        ..strokeWidth = railWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + length),
        rail,
      );
    }

    /// Bright central launch corridor.
    final Paint beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          const Color(0xffaaffff)
              .withOpacity(.12 * intensity * pulse),
          const Color(0xff00eaff)
              .withOpacity(.38 * intensity * pulse),
          const Color(0xff006dff)
              .withOpacity(.25 * intensity * pulse),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(
          size.width * .15,
          0,
          size.width * .70,
          size.height,
        ),
      );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .15,
        0,
        size.width * .70,
        size.height,
      ),
      beam,
    );

    /// White/cyan exhaust pillars visible from the first countdown frame.
    final double engineY = size.height * .72;
    for (int i = -2; i <= 2; i++) {
      final double x =
          size.width * .5 + (i * size.width * .085);
      final double pillarWidth =
          size.width * (i == 0 ? .085 : .055);
      final double sway =
          math.sin((t * math.pi * 2) + i) * 10;
      final Rect rect = Rect.fromLTWH(
        x - (pillarWidth / 2),
        engineY + sway,
        pillarWidth,
        size.height - engineY + 80,
      );

      final Paint exhaust = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xffffffff)
                .withOpacity(.92 * intensity),
            const Color(0xffb8ffff)
                .withOpacity(.88 * intensity),
            const Color(0xff00dfff)
                .withOpacity(.62 * intensity),
            const Color(0xff006dff)
                .withOpacity(.18 * intensity),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          4,
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(pillarWidth),
        ),
        exhaust,
      );
    }

    /// Floating blue stars.
    for (int i = 0; i < 55; i++) {
      final double x = size.width * _noise(i + 400);
      final double speed =
          .22 + (_noise(i + 470) * .82);
      final double y = size.height -
          (((t * size.height * speed) +
              (_noise(i + 520) * size.height)) %
              size.height);
      final double radius =
          .65 + (_noise(i + 590) * 2.5);
      final Color color = i.isEven
          ? const Color(0xffb9ffff)
          : const Color(0xff4b9cff);
      final Paint particle = Paint()
        ..color = color.withOpacity(
          (.15 + (_noise(i + 630) * .56)) *
              intensity,
        )
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          2.2,
        );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        particle,
      );
    }

    /// Gold coins flow upward around the rocket, matching the video.
    for (int i = 0; i < 24; i++) {
      final double lane =
          .08 + (_noise(i + 800) * .84);
      final double speed =
          .28 + (_noise(i + 840) * .75);
      final double y = size.height -
          (((t * size.height * speed) +
              (_noise(i + 880) * size.height * 1.25)) %
              (size.height * 1.18));
      final double radius =
          5 + (_noise(i + 920) * 8);
      final double visibility =
          .35 + (_noise(i + 960) * .55);

      _drawCoin(
        canvas,
        center: Offset(size.width * lane, y),
        radius: radius,
        rotation:
        (t * math.pi * 3) + (_noise(i + 990) * math.pi),
        opacity: visibility * intensity,
      );
    }

    /// Repeated launch-pad rings.
    final Offset pad =
    Offset(size.width * .5, size.height * .80);
    for (int i = 0; i < 5; i++) {
      final double local = (t + (i * .19)) % 1;
      final double radius =
          size.width * (.15 + (.44 * local));
      final Paint ring = Paint()
        ..color = const Color(0xffa7ffff)
            .withOpacity((1 - local) * .46 * intensity)
        ..strokeWidth = 1.2 + ((1 - local) * 2.4)
        ..style = PaintingStyle.stroke
        ..maskFilter =
        const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawOval(
        Rect.fromCenter(
          center: pad,
          width: radius * 2,
          height: radius * .34,
        ),
        ring,
      );
    }

    /// Electric bolts stay visible during countdown and intensify on launch.
    final double boltAlpha =
        (launching ? .98 : .62) * intensity;
    _drawLightning(
      canvas,
      size,
      baseX: size.width * .06,
      startY: size.height * .22,
      endY: size.height * .94,
      seed: 1200 + (t * 100).floor(),
      direction: 1,
      alpha: boltAlpha,
    );
    _drawLightning(
      canvas,
      size,
      baseX: size.width * .94,
      startY: size.height * .17,
      endY: size.height * .91,
      seed: 1400 + (t * 100).floor(),
      direction: -1,
      alpha: boltAlpha,
    );

    if (launching) {
      final double flash =
          (math.sin(t * math.pi * 4).abs() * .13) + .05;
      canvas.drawRect(
        full,
        Paint()
          ..color = const Color(0xffc5ffff)
              .withOpacity(flash * intensity),
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant _RocketLaunchEnergyPainter oldDelegate,
      ) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.launching != launching;
  }
}

class _RocketRewardBoard extends StatelessWidget {
  const _RocketRewardBoard({required this.data});

  final Map<String, dynamic> data;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  String _text(dynamic value, [String fallback = '']) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ??
        double.tryParse(value?.toString() ?? '')?.toInt() ??
        0;
  }

  String _image(dynamic value) {
    final String raw = _text(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  String _groupKey(dynamic value, {int rank = 0}) {
    String key = _text(value).toLowerCase().replaceAll(' ', '');
    key = key.replaceAll('-', '').replaceAll('_', '');

    if (key == 'top1' || key == '1' || rank == 1) return 'top1';
    if (key == 'top2' || key == '2' || rank == 2) return 'top2';
    if (key == 'top3' || key == '3' || rank == 3) return 'top3';
    if (key == 'inroom' || key == 'room' || key == 'in') return 'in_room';
    return key;
  }

  int _launchId(Map<String, dynamic> row) {
    return _int(
      row['launch_id'] ??
          row['rocket_launch_id'] ??
          _map(row['launch'])['id'] ??
          _map(row['rocket_launch'])['id'],
    );
  }

  int _sessionId(Map<String, dynamic> row) {
    return _int(
      row['session_id'] ??
          _map(row['launch'])['session_id'] ??
          _map(row['rocket_launch'])['session_id'],
    );
  }

  int _levelId(Map<String, dynamic> row) {
    final Map<String, dynamic> level = _map(
      row['level'] ?? row['rocket_level'],
    );
    return _int(
      row['rocket_level_id'] ??
          row['level_id'] ??
          level['id'] ??
          level['rocket_level_id'],
    );
  }

  bool _sameLaunch(
      Map<String, dynamic> a,
      Map<String, dynamic> b,
      ) {
    if (a.isEmpty || b.isEmpty) return false;

    final int aLaunch = _launchId(a);
    final int bLaunch = _launchId(b);
    if (aLaunch > 0 && bLaunch > 0) return aLaunch == bLaunch;

    final int aSession = _sessionId(a);
    final int bSession = _sessionId(b);
    final int aLevel = _levelId(a);
    final int bLevel = _levelId(b);

    return aSession > 0 &&
        bSession > 0 &&
        aSession == bSession &&
        (aLevel <= 0 || bLevel <= 0 || aLevel == bLevel);
  }

  bool _hasWinnerDetails(Map<String, dynamic> row) {
    return _list(row['winners']).isNotEmpty ||
        _list(row['reward_logs']).isNotEmpty ||
        _list(row['delivered_reward_logs']).isNotEmpty ||
        _map(row['reward_results']).isNotEmpty;
  }

  Map<String, dynamic> _resolvedLaunch() {
    final Map<String, dynamic> root = Map<String, dynamic>.from(data);
    final Map<String, dynamic> nestedData = _map(root['data']);
    final Map<String, dynamic> nestedLaunch = _map(
      root['launch'] ??
          root['rocket_launch'] ??
          root['last_launch'] ??
          root['latest_launch'] ??
          nestedData['launch'] ??
          nestedData['rocket_launch'] ??
          nestedData['last_launch'] ??
          nestedData['latest_launch'],
    );

    Map<String, dynamic> resolved = <String, dynamic>{
      ...root,
      ...nestedData,
      ...nestedLaunch,
    };

    if (Get.isRegistered<RocketController>()) {
      final RocketController controller = Get.find<RocketController>();
      final Map<String, dynamic> latest =
      Map<String, dynamic>.from(controller.lastLaunch);

      if (latest.isNotEmpty &&
          (_sameLaunch(resolved, latest) ||
              (!_hasWinnerDetails(resolved) &&
                  _levelId(resolved) > 0 &&
                  _levelId(resolved) == _levelId(latest)))) {
        resolved = <String, dynamic>{
          ...resolved,
          ...latest,
          'event_id': resolved['event_id'] ?? latest['event_id'],
          'livestream_id':
          resolved['livestream_id'] ?? latest['livestream_id'],
          'level': latest['level'] ??
              latest['rocket_level'] ??
              resolved['level'] ??
              resolved['rocket_level'],
        };
      }
    }

    return resolved;
  }

  Map<String, dynamic> _userFrom(dynamic raw) {
    final Map<String, dynamic> row = _map(raw);
    if (row.isEmpty) return <String, dynamic>{};

    final Map<String, dynamic> nested = _map(
      row['user'] ??
          row['winner'] ??
          row['receiver'] ??
          row['member'] ??
          row['profile'],
    );

    return nested.isEmpty
        ? row
        : <String, dynamic>{...row, ...nested};
  }

  int _userId(Map<String, dynamic> row) {
    final Map<String, dynamic> user = _userFrom(row);
    return _int(
      row['user_id'] ??
          row['winner_user_id'] ??
          row['receiver_id'] ??
          user['id'] ??
          user['user_id'],
    );
  }

  Map<String, dynamic> _normalizeReward(Map<String, dynamic> raw) {
    final Map<String, dynamic> reward = _map(
      raw['reward'] ??
          raw['rocket_reward'] ??
          raw['gift'] ??
          raw['asset'] ??
          raw['vip_package'],
    );
    final Map<String, dynamic> reference = _map(
      reward['reference'] ?? raw['reference'],
    );

    return <String, dynamic>{
      ...reward,
      ...raw,
      'reference': reference,
      'title': raw['reward_title'] ??
          raw['title'] ??
          reward['title'] ??
          reward['name'],
      'image': raw['reward_image'] ??
          raw['image'] ??
          raw['show_image'] ??
          reward['image'] ??
          reward['show_image'] ??
          reward['badge_image'] ??
          reference['asset'] ??
          reference['image'],
      'amount': raw['amount'] ??
          raw['quantity'] ??
          reward['amount'] ??
          reward['quantity'],
      'duration_days': raw['duration_days'] ??
          raw['days'] ??
          reward['duration_days'] ??
          reward['days'],
      'reward_type': raw['reward_type'] ??
          raw['type'] ??
          reward['reward_type'] ??
          reward['type'],
    };
  }

  List<Map<String, dynamic>> _configuredRewardsFor(
      Map<String, dynamic> launch,
      String key,
      ) {
    final Map<String, dynamic> level = _map(
      launch['level'] ?? launch['rocket_level'],
    );
    final Map<String, dynamic> levelRewards = _map(
      level['rewards'] ??
          launch['level_rewards'] ??
          launch['rewards'] ??
          launch['reward_setup'],
    );

    final dynamic raw = key == 'in_room'
        ? levelRewards['in_room'] ??
        levelRewards['inRoom'] ??
        levelRewards['room']
        : levelRewards[key] ??
        levelRewards[key.replaceAll('top', 'top_')];

    return _list(raw)
        .map(_normalizeReward)
        .toList(growable: false);
  }

  List<_RocketRewardWinnerGroup> _winnerGroups(
      Map<String, dynamic> launch,
      ) {
    final List<Map<String, dynamic>> winners = _list(
      launch['winners'] ??
          launch['winner_rows'] ??
          launch['reward_winners'],
    );

    List<Map<String, dynamic>> logs = _list(
      launch['delivered_reward_logs'],
    );
    if (logs.isEmpty) {
      logs = _list(
        launch['reward_logs'] ??
            launch['rewards_logs'] ??
            launch['reward_results'],
      ).where((Map<String, dynamic> row) {
        final String status = _text(row['status']).toLowerCase();
        return status.isEmpty ||
            status == 'delivered' ||
            status == 'success' ||
            status == 'received' ||
            status == 'completed';
      }).toList(growable: false);
    }

    final List<_RocketRewardWinnerGroup> output =
    <_RocketRewardWinnerGroup>[];
    const List<String> order = <String>[
      'top1',
      'top2',
      'top3',
      'in_room',
    ];

    for (final String group in order) {
      final List<Map<String, dynamic>> groupWinners = winners.where(
            (Map<String, dynamic> row) {
          return _groupKey(
            row['winner_group'] ??
                row['group'] ??
                row['slot'] ??
                row['rank_title'],
            rank: _int(row['rank'] ?? row['position']),
          ) ==
              group;
        },
      ).toList(growable: true);

      final List<Map<String, dynamic>> groupLogs = logs.where(
            (Map<String, dynamic> row) {
          return _groupKey(
            row['winner_group'] ??
                row['group'] ??
                row['slot'] ??
                row['rank_title'],
            rank: _int(row['rank'] ?? row['position']),
          ) ==
              group;
        },
      ).toList(growable: false);

      if (groupWinners.isEmpty && groupLogs.isNotEmpty) {
        final Set<int> added = <int>{};
        for (final Map<String, dynamic> log in groupLogs) {
          final int uid = _userId(log);
          if (uid > 0 && !added.add(uid)) continue;
          groupWinners.add(log);
        }
      }

      if (groupWinners.isEmpty &&
          group != 'in_room' &&
          Get.isRegistered<RocketController>()) {
        final RocketController controller = Get.find<RocketController>();
        final int wantedRank = group == 'top1'
            ? 1
            : group == 'top2'
            ? 2
            : 3;

        for (final Map<String, dynamic> row in controller.ranking) {
          final int rank = _int(row['rank'] ?? row['position']);
          if (rank == wantedRank) {
            groupWinners.add(Map<String, dynamic>.from(row));
            break;
          }
        }
      }

      final List<Map<String, dynamic>> configured =
      _configuredRewardsFor(launch, group);

      for (final Map<String, dynamic> winnerRaw in groupWinners) {
        final Map<String, dynamic> winner = _userFrom(winnerRaw);
        final int uid = _userId(winnerRaw);

        List<Map<String, dynamic>> winnerRewards = groupLogs.where(
              (Map<String, dynamic> row) {
            final int logUid = _userId(row);
            if (uid <= 0 || logUid <= 0) return true;
            return uid == logUid;
          },
        ).map(_normalizeReward).toList(growable: false);

        if (winnerRewards.isEmpty) {
          winnerRewards = configured;
        }

        output.add(
          _RocketRewardWinnerGroup(
            group: group,
            rank: group == 'top1'
                ? 1
                : group == 'top2'
                ? 2
                : group == 'top3'
                ? 3
                : 0,
            user: winner,
            rewards: winnerRewards,
          ),
        );
      }
    }

    return output;
  }

  Map<String, dynamic> _highlightReward(
      List<_RocketRewardWinnerGroup> groups,
      ) {
    for (final _RocketRewardWinnerGroup group in groups) {
      if (group.rewards.isNotEmpty) return group.rewards.first;
    }
    return <String, dynamic>{};
  }

  String _compactAmount(int value) {
    if (value >= 1000000000) {
      final double amount = value / 1000000000;
      return '${amount.toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      final double amount = value / 1000000;
      return '${amount.toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final double amount = value / 1000;
      return '${amount.toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _rewardAmountText(Map<String, dynamic> item) {
    final String type = _text(
      item['reward_type'] ?? item['type'],
    ).toLowerCase();
    final int amount = _int(
      item['amount'] ?? item['quantity'] ?? item['coin'] ?? item['coins'],
    );
    final int days = _int(
      item['duration_days'] ?? item['days'] ?? item['validity'],
    );

    if (days > 0 &&
        (type.contains('asset') ||
            type.contains('frame') ||
            type.contains('vip') ||
            type.contains('title') ||
            type.contains('badge'))) {
      return 'X $days Days';
    }

    if (amount > 0) {
      return type.contains('coin')
          ? _compactAmount(amount)
          : 'X ${_compactAmount(amount)}';
    }

    return days > 0 ? 'X $days Days' : 'X 1';
  }

  String _rewardTitle(Map<String, dynamic> item) {
    return _text(
      item['reward_title'] ??
          item['title'] ??
          item['name'] ??
          item['reward_name'] ??
          item['reward_type'],
      'Reward',
    );
  }

  String _rewardImage(Map<String, dynamic> item) {
    final Map<String, dynamic> reward = _map(item['reward']);
    final Map<String, dynamic> reference = _map(
      item['reference'] ?? reward['reference'],
    );
    return _image(
      item['reward_image'] ??
          item['image'] ??
          item['show_image'] ??
          item['badge_image'] ??
          reward['image'] ??
          reward['show_image'] ??
          reference['asset'] ??
          reference['image'],
    );
  }

  Color _groupBadgeColor(String group) {
    switch (group) {
      case 'top1':
        return const Color(0xffffcf4a);
      case 'top2':
        return const Color(0xffc7ecff);
      case 'top3':
        return const Color(0xffffb58f);
      default:
        return const Color(0xff78eff7);
    }
  }

  String _groupLabel(String group) {
    switch (group) {
      case 'top1':
        return 'TOP1';
      case 'top2':
        return 'TOP2';
      case 'top3':
        return 'TOP3';
      default:
        return 'IN ROOM';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> launch = _resolvedLaunch();
    final List<_RocketRewardWinnerGroup> groups = _winnerGroups(launch);
    final Map<String, dynamic> highlight = _highlightReward(groups);

    final int distinctReceived = groups
        .map((_RocketRewardWinnerGroup row) {
      return _int(row.user['id'] ?? row.user['user_id']);
    })
        .where((int id) => id > 0)
        .toSet()
        .length;
    final Map<String, dynamic> rewardSummary =
    _map(launch['reward_summary']);
    final int explicitReceived = _int(
      launch['rewarded_user_count'] ??
          launch['winner_count'] ??
          launch['received_count'] ??
          rewardSummary['delivered'],
    );
    final int receivedCount = explicitReceived > 0
        ? explicitReceived
        : (distinctReceived > 0 ? distinctReceived : groups.length);

    final int levelNo = _int(
      launch['level_no'] ??
          _map(launch['level'])['level_no'] ??
          _map(launch['rocket_level'])['level_no'],
    );

    final Size size = MediaQuery.of(context).size;
    final double width = math.min(size.width * .95, 540.0).toDouble();
    final double height =
    (size.height * .76).clamp(500.0, 720.0).toDouble();
    final bool compact = width < 390;

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            Positioned.fill(
              top: 25,
              child: CustomPaint(
                painter: const _RocketRewardDialogPainter(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 18,
                    compact ? 54 : 60,
                    compact ? 12 : 18,
                    compact ? 14 : 18,
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Spacer(),
                          Text(
                            levelNo > 0
                                ? 'ROCKET LV.$levelNo REWARD'
                                : 'ROCKET REWARD',
                            style: TextStyle(
                              color: const Color(0xffd8ffff),
                              fontSize: compact ? 12 : 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                              shadows: const <Shadow>[
                                Shadow(
                                  color: Color(0xff00dce8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: compact ? 25 : 29,
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 6 : 8),
                      Text(
                        'You\'ve got rewards below',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (highlight.isNotEmpty) ...<Widget>[
                        SizedBox(height: compact ? 9 : 12),
                        _featuredRewardCard(
                          highlight,
                          compact: compact,
                        ),
                      ],
                      SizedBox(height: compact ? 8 : 11),
                      Text(
                        '◆ $receivedCount person${receivedCount == 1 ? '' : 's'} received reward ◆',
                        style: TextStyle(
                          color: const Color(0xffd2f8fa),
                          fontSize: compact ? 11.2 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 11),
                      Expanded(
                        child: groups.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xffffd55d),
                                size: 56,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No reward was delivered',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: compact ? 13 : 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 6),
                          itemCount: groups.length,
                          separatorBuilder: (_, __) => Divider(
                            height: compact ? 10 : 14,
                            color: const Color(0xff6be5e9)
                                .withOpacity(.20),
                          ),
                          itemBuilder: (_, int index) {
                            return _winnerRewardRow(
                              groups[index],
                              compact: compact,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: CustomPaint(
                painter: const _RocketRewardRibbonPainter(),
                child: SizedBox(
                  width: compact ? 220 : 260,
                  height: compact ? 58 : 64,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.rocket_launch_rounded,
                            color: Color(0xffffdd58),
                            size: 25,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Reward',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 25 : 29,
                              fontWeight: FontWeight.w900,
                              shadows: const <Shadow>[
                                Shadow(color: Colors.black87, blurRadius: 6),
                                Shadow(
                                  color: Color(0xff00e8ee),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featuredRewardCard(
      Map<String, dynamic> item, {
        required bool compact,
      }) {
    final String image = _rewardImage(item);
    return SizedBox(
      width: compact ? 92 : 104,
      height: compact ? 118 : 132,
      child: CustomPaint(
        painter: const _RocketRewardCardPainter(featured: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
          child: Column(
            children: <Widget>[
              Expanded(
                child: image.isEmpty
                    ? const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xffffd85d),
                  size: 48,
                )
                    : CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  filterQuality: FilterQuality.high,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xffffd85d),
                    size: 44,
                  ),
                ),
              ),
              Text(
                _rewardTitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 9.2 : 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              _rewardAmountStrip(item, compact: compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _winnerRewardRow(
      _RocketRewardWinnerGroup row, {
        required bool compact,
      }) {
    final String name = _text(
      row.user['name'] ??
          row.user['username'] ??
          row.user['user_name'],
      'User',
    );
    final String avatar = _image(
      row.user['profile_image'] ??
          row.user['avatar'] ??
          row.user['image'],
    );
    final double avatarSize = compact ? 52 : 60;

    return SizedBox(
      height: compact ? 112 : 126,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: compact ? 103 : 122,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: <Color>[
                        _groupBadgeColor(row.group),
                        const Color(0xff25d8e0),
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _groupBadgeColor(row.group).withOpacity(.38),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatar.isEmpty
                        ? Container(
                      color: const Color(0xff174b55),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white70,
                      ),
                    )
                        : CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      memCacheWidth: 320,
                      memCacheHeight: 320,
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xff174b55),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 11.5 : 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: _groupBadgeColor(row.group),
                  ),
                  child: Text(
                    _groupLabel(row.group),
                    style: TextStyle(
                      color: const Color(0xff443100),
                      fontSize: compact ? 9.2 : 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: row.rewards.isEmpty
                ? Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xff063e47).withOpacity(.45),
                border: Border.all(
                  color: const Color(0xff54dce3).withOpacity(.22),
                ),
              ),
              child: const Text(
                'No reward',
                style: TextStyle(color: Colors.white38),
              ),
            )
                : ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: row.rewards.length,
              separatorBuilder: (_, __) =>
                  SizedBox(width: compact ? 7 : 9),
              itemBuilder: (_, int index) {
                return _miniRewardCard(
                  row.rewards[index],
                  compact: compact,
                  featured: row.group == 'top1' && index == 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniRewardCard(
      Map<String, dynamic> item, {
        required bool compact,
        required bool featured,
      }) {
    final String image = _rewardImage(item);
    return SizedBox(
      width: compact ? 79 : 90,
      child: CustomPaint(
        painter: _RocketRewardCardPainter(featured: featured),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
          child: Column(
            children: <Widget>[
              Expanded(
                child: image.isEmpty
                    ? Icon(
                  Icons.card_giftcard_rounded,
                  color: featured
                      ? const Color(0xffffdb59)
                      : const Color(0xffa6f8ff),
                  size: compact ? 36 : 42,
                )
                    : CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  filterQuality: FilterQuality.high,
                  errorWidget: (_, __, ___) => Icon(
                    Icons.card_giftcard_rounded,
                    color: featured
                        ? const Color(0xffffdb59)
                        : const Color(0xffa6f8ff),
                    size: compact ? 34 : 40,
                  ),
                ),
              ),
              Text(
                _rewardTitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 8.4 : 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              _rewardAmountStrip(item, compact: compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardAmountStrip(
      Map<String, dynamic> item, {
        required bool compact,
      }) {
    final String type = _text(
      item['reward_type'] ?? item['type'],
    ).toLowerCase();

    return Container(
      width: double.infinity,
      height: compact ? 20 : 23,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xff0a909b),
            Color(0xff075d69),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (type.contains('coin')) ...<Widget>[
            Icon(
              Icons.monetization_on_rounded,
              color: const Color(0xffffd247),
              size: compact ? 11 : 13,
            ),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              _rewardAmountText(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 9 : 10.2,
                fontWeight: FontWeight.w900,
                shadows: const <Shadow>[
                  Shadow(color: Colors.black54, blurRadius: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RocketRewardWinnerGroup {
  const _RocketRewardWinnerGroup({
    required this.group,
    required this.rank,
    required this.user,
    required this.rewards,
  });

  final String group;
  final int rank;
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> rewards;
}

class _RocketRewardDialogPainter extends CustomPainter {
  const _RocketRewardDialogPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect body = RRect.fromRectAndRadius(
      rect.deflate(5),
      const Radius.circular(18),
    );

    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xf20c7a7a),
          Color(0xf20a565e),
          Color(0xf205303b),
        ],
      ).createShader(rect);
    canvas.drawRRect(body, fill);

    final Paint glow = Paint()
      ..color = const Color(0xff49f4f4).withOpacity(.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(body, glow);

    final Paint border = Paint()
      ..color = const Color(0xff7affff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(body, border);

    final Paint inner = Paint()
      ..color = const Color(0xff1eb7bd).withOpacity(.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(body.deflate(6), inner);

    final Paint accent = Paint()
      ..color = const Color(0xff70ffff)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;

    const double cut = 28;
    canvas.drawLine(
      const Offset(6, 58),
      const Offset(6, 18),
      accent,
    );
    canvas.drawLine(
      const Offset(6, 18),
      const Offset(cut, 6),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - 6, 58),
      Offset(size.width - 6, 18),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - 6, 18),
      Offset(size.width - cut, 6),
      accent,
    );
    canvas.drawLine(
      Offset(6, size.height - 58),
      Offset(6, size.height - 18),
      accent,
    );
    canvas.drawLine(
      Offset(6, size.height - 18),
      Offset(cut, size.height - 6),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - 6, size.height - 58),
      Offset(size.width - 6, size.height - 18),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - 6, size.height - 18),
      Offset(size.width - cut, size.height - 6),
      accent,
    );
  }

  @override
  bool shouldRepaint(
      covariant _RocketRewardDialogPainter oldDelegate,
      ) =>
      false;
}

class _RocketRewardRibbonPainter extends CustomPainter {
  const _RocketRewardRibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width * .10, 4)
      ..lineTo(size.width * .90, 4)
      ..lineTo(size.width, size.height * .48)
      ..lineTo(size.width * .88, size.height - 4)
      ..lineTo(size.width * .12, size.height - 4)
      ..lineTo(0, size.height * .48)
      ..close();

    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xff18a9aa),
          Color(0xff08636d),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    final Paint border = Paint()
      ..color = const Color(0xff7affff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(
      covariant _RocketRewardRibbonPainter oldDelegate,
      ) =>
      false;
}

class _RocketRewardCardPainter extends CustomPainter {
  const _RocketRewardCardPainter({
    this.featured = false,
  });

  final bool featured;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(8, 1)
      ..lineTo(size.width - 8, 1)
      ..lineTo(size.width - 1, 9)
      ..lineTo(size.width - 1, size.height - 9)
      ..lineTo(size.width - 8, size.height - 1)
      ..lineTo(8, size.height - 1)
      ..lineTo(1, size.height - 9)
      ..lineTo(1, 9)
      ..close();

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: featured
            ? const <Color>[
          Color(0xff5c4805),
          Color(0xff153f46),
        ]
            : const <Color>[
          Color(0xff0a5260),
          Color(0xff062e3b),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    final Paint border = Paint()
      ..color = featured
          ? const Color(0xffffd94f)
          : const Color(0xff57eaf0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = featured ? 1.6 : 1.1;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(
      covariant _RocketRewardCardPainter oldDelegate,
      ) =>
      oldDelegate.featured != featured;
}

class _RocketMedia extends StatefulWidget {
  const _RocketMedia({
    required this.animationUrl,
    required this.rocketImageUrl,
    required this.onMediaFinished,
  });

  final String animationUrl;
  final String rocketImageUrl;
  final VoidCallback onMediaFinished;

  @override
  State<_RocketMedia> createState() => _RocketMediaState();
}

class _RocketMediaState extends State<_RocketMedia> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _done = false;

  bool get _isSvga =>
      widget.animationUrl.toLowerCase().split('?').first.endsWith('.svga');
  bool get _isMp4 {
    final String clean = widget.animationUrl.toLowerCase().split('?').first;
    return clean.endsWith('.mp4') || clean.endsWith('.mov') || clean.endsWith('.m4v');
  }

  @override
  void initState() {
    super.initState();
    if (_isMp4 && widget.animationUrl.isNotEmpty) {
      _prepareVideo();
    }
  }

  void _doneOnce() {
    if (_done) return;
    _done = true;
    widget.onMediaFinished();
  }

  Future<void> _prepareVideo() async {
    try {
      final VideoPlayerController controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.animationUrl));
      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(() {
        if (!controller.value.isInitialized) return;
        if (controller.value.position >= controller.value.duration &&
            controller.value.duration > Duration.zero) {
          _doneOnce();
        }
      });
      await controller.play();
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvga && widget.animationUrl.isNotEmpty) {
      return SVGAEasyPlayer(
        resUrl: widget.animationUrl,
        fit: BoxFit.contain,
        loops: 1,
        isMute: true,
        useCache: true,
        onFinished: _doneOnce,
      );
    }

    if (_isMp4 && _videoReady && _videoController != null) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    if (widget.rocketImageUrl.isNotEmpty) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: .82, end: 1.06),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: CachedNetworkImage(
          imageUrl: widget.rocketImageUrl,
          fit: BoxFit.contain,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          memCacheWidth: 1400,
          filterQuality: FilterQuality.high,
          placeholder: (_, __) => const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 140,
          ),
          errorWidget: (_, __, ___) => const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 140,
          ),
        ),
      );
    }

    return const Icon(
      Icons.rocket_launch_rounded,
      color: Colors.white,
      size: 150,
      shadows: <Shadow>[
        Shadow(color: Color(0xffff9800), blurRadius: 25),
      ],
    );
  }
}
