

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../../constants/constants.dart';

class AgoraRenewalToken {
  const AgoraRenewalToken({
    required this.token,
    this.expiresInSeconds,
  });

  final String token;
  final int? expiresInSeconds;
}

typedef AgoraFreshTokenProvider = Future<AgoraRenewalToken> Function();

enum _AgoraLifecycleState { idle, initializing, ready, disposing }


enum AgoraLutFilter {
  none,
  natural,
  warm,
  saturated,
  fresh,
  cool,
  rosy,
  studio,
  cinematic,
}

double _lutClamp(double value) {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

List<double> _transformLutColor(
    String filterName,
    double r,
    double g,
    double b,
    ) {
  double rr = r;
  double gg = g;
  double bb = b;

  final double luma = (r * .2126) + (g * .7152) + (b * .0722);

  switch (filterName) {
    case 'warm':
      rr = r * 1.08 + .015;
      gg = g * 1.01;
      bb = b * .90;
      break;
    case 'saturated':
      rr = luma + (r - luma) * 1.32;
      gg = luma + (g - luma) * 1.32;
      bb = luma + (b - luma) * 1.32;
      break;
    case 'fresh':
      rr = r * 1.01 + .015;
      gg = g * 1.045 + .010;
      bb = b * 1.055 + .012;
      break;
    case 'cool':
      rr = r * .94;
      gg = g * 1.01;
      bb = b * 1.10 + .01;
      break;
    case 'rosy':
      rr = r * 1.08 + .015;
      gg = g * .98;
      bb = b * 1.02 + .006;
      break;
    case 'studio':
      rr = (r - .5) * 1.10 + .5;
      gg = (g - .5) * 1.10 + .5;
      bb = (b - .5) * 1.10 + .5;
      break;
    case 'cinematic':
      rr = r * 1.04 + g * .015;
      gg = g * .99 + b * .018;
      bb = b * .96 + g * .025;
      break;
    case 'natural':
    default:
      rr = (r - .5) * 1.025 + .5;
      gg = (g - .5) * 1.025 + .5;
      bb = (b - .5) * 1.025 + .5;
      break;
  }

  return <double>[
    _lutClamp(rr),
    _lutClamp(gg),
    _lutClamp(bb),
  ];
}

String _buildAgoraCubeLut(String filterName) {
  const int size = 32;
  final StringBuffer buffer = StringBuffer('LUT_3D_SIZE 32\n');

  // Standard .cube ordering: red changes fastest, then green, then blue.
  for (int b = 0; b < size; b++) {
    for (int g = 0; g < size; g++) {
      for (int r = 0; r < size; r++) {
        final double rf = r / (size - 1);
        final double gf = g / (size - 1);
        final double bf = b / (size - 1);
        final values = _transformLutColor(filterName, rf, gf, bf);
        buffer
          ..write(values[0].toStringAsFixed(8))
          ..write(' ')
          ..write(values[1].toStringAsFixed(8))
          ..write(' ')
          ..write(values[2].toStringAsFixed(8))
          ..write('\n');
      }
    }
  }

  return buffer.toString();
}

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInitializing = false;
  _AgoraLifecycleState _lifecycleState = _AgoraLifecycleState.idle;
  Future<void> _lifecycleQueue = Future<void>.value();
  int _engineGeneration = 0;
  int? _releasedGeneration;
  bool _audioOnlyInitialized = false;
  bool _isFrontCamera =
  true; // Track camera direction (true = front, false = back)

  // =================== LIVE PERFORMANCE GUARDS ===================
  // These prevent repeated Agora SDK calls from build/resume/event loops.
  ClientRoleType? _lastClientRole;
  bool? _lastLocalAudioMuted;
  bool? _lastLocalVideoMuted;
  bool? _lastLocalVideoEnabled;
  String? _joinedChannelId;
  int? _joinedUid;
  bool _isJoiningChannel = false;
  bool _isPreviewStarted = false;

  // =================== CONTINUOUS TOKEN RENEWAL ===================
  // This state belongs to the singleton engine, not to a live page. Therefore
  // token renewal keeps working while a live page is minimized/disposed.
  RtcEngineEventHandler? _tokenEventHandler;
  int? _tokenEventHandlerGeneration;
  Timer? _tokenRefreshTimer;
  Timer? _tokenRetryTimer;
  AgoraFreshTokenProvider? _freshTokenProvider;
  String? _tokenChannelId;
  int? _tokenUid;
  String? _currentAgoraToken;
  int? _tokenExpiresInSeconds;
  DateTime? _nextTokenRefreshAt;
  bool _tokenRefreshRunning = false;
  int _tokenRefreshGeneration = 0;
  int _tokenRetryAttempt = 0;

  /// Android/Agora audio-focus recovery guard. WhatsApp, phone calls and

  bool _audioInterruptionRecoveryRunning = false;
  DateTime? _lastAudioInterruptionRecoveryAt;

  // Queued effects to apply once engine is ready
  BeautyOptions? _queuedBeauty;
  bool _queuedBeautyEnabled = false;
  ColorEnhanceOptions? _queuedColor;
  bool _queuedColorEnabled = false;
  final Map<AgoraLutFilter, String> _generatedLutPaths = <AgoraLutFilter, String>{};
  AgoraLutFilter _activeLutFilter = AgoraLutFilter.none;
  double _activeLutStrength = 0;

  // final String appId = "4d68656dc95447fc97b709a5321482bd";

  // Getters
  RtcEngine? get engine => _engine;
  bool isCurrentEngineInstance(RtcEngine candidate) =>
      identical(_engine, candidate) &&
          _isInitialized &&
          _lifecycleState == _AgoraLifecycleState.ready;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isFrontCamera => _isFrontCamera;
  bool get isAudioOnlyInitialized => _audioOnlyInitialized;
  String? get currentAgoraToken => _currentAgoraToken;
  DateTime? get nextAgoraTokenRefreshAt => _nextTokenRefreshAt;
  bool get isAgoraTokenRenewalConfigured =>
      _freshTokenProvider != null &&
          _tokenChannelId != null &&
          _tokenUid != null;

  Future<T> _serializeLifecycle<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _lifecycleQueue = _lifecycleQueue
        .then<void>((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    })
        .catchError((Object error, StackTrace stackTrace) {
      debugPrint('Agora lifecycle queue recovered from error: $error');
    });
    return completer.future;
  }

  bool _isCurrentEngine(RtcEngine engine, int generation) {
    return identical(_engine, engine) &&
        _engineGeneration == generation &&
        _lifecycleState != _AgoraLifecycleState.disposing;
  }

  void _clearChannelState() {
    _joinedChannelId = null;
    _joinedUid = null;
    _lastClientRole = null;
    _lastLocalAudioMuted = null;
    _lastLocalVideoMuted = null;
    _lastLocalVideoEnabled = null;
  }

  Duration _calculateTokenRefreshDelay(int? expiresInSeconds) {
    final int safeExpires = expiresInSeconds ?? 3600;

    // Renew at least five minutes before expiry. For very short test tokens,
    // renew at roughly 70% of their lifetime while keeping a 30-second floor.
    if (safeExpires <= 600) {
      final int seconds =
      (safeExpires * 0.7).round().clamp(30, 420).toInt();
      return Duration(seconds: seconds);
    }

    final int seconds = (safeExpires - 300).clamp(300, 86400).toInt();
    return Duration(seconds: seconds);
  }

  bool _tokenConnectionMatches(RtcConnection connection) {
    final String eventChannel = connection.channelId?.trim() ?? '';
    final String configuredChannel = _tokenChannelId?.trim() ?? '';
    return eventChannel.isEmpty ||
        configuredChannel.isEmpty ||
        eventChannel == configuredChannel;
  }

  void _registerTokenEventHandler(RtcEngine engine, int generation) {
    if (_tokenEventHandler != null &&
        _tokenEventHandlerGeneration == generation) {
      return;
    }

    final RtcEngineEventHandler handler = RtcEngineEventHandler(
      onTokenPrivilegeWillExpire: (
          RtcConnection connection,
          String token,
          ) {
        if (!_isCurrentEngine(engine, generation) ||
            !_tokenConnectionMatches(connection)) {
          return;
        }
        debugPrint(
          '⚠️ Agora token will expire: channel=${connection.channelId}',
        );
        unawaited(
          requestAgoraTokenRefresh(
            reason: 'token_will_expire',
            force: true,
          ),
        );
      },
      onRequestToken: (RtcConnection connection) {
        if (!_isCurrentEngine(engine, generation) ||
            !_tokenConnectionMatches(connection)) {
          return;
        }
        debugPrint(
          '🚨 Agora SDK requested token: channel=${connection.channelId}',
        );
        unawaited(
          requestAgoraTokenRefresh(
            reason: 'sdk_requested_token',
            force: true,
          ),
        );
      },
      onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
          ) {
        if (!_isCurrentEngine(engine, generation) ||
            !_tokenConnectionMatches(connection)) {
          return;
        }

        final String reasonText = reason.toString().toLowerCase();
        final bool tokenProblem = reasonText.contains('token') &&
            (reasonText.contains('expired') ||
                reasonText.contains('invalid'));
        if (tokenProblem) {
          unawaited(
            requestAgoraTokenRefresh(
              reason: 'connection_token_problem',
              force: true,
            ),
          );
        }
      },
    );

    _tokenEventHandler = handler;
    _tokenEventHandlerGeneration = generation;
    engine.registerEventHandler(handler);
    debugPrint('✅ Agora continuous token event handler registered');
  }

  void configureAgoraTokenRenewal({
    required String channelId,
    required int uid,
    required String initialToken,
    required AgoraFreshTokenProvider fetchFreshToken,
    int? expiresInSeconds,
  }) {
    final String safeChannel = channelId.trim();
    final String safeToken = initialToken.trim();
    if (safeChannel.isEmpty || uid <= 0 || safeToken.isEmpty) {
      debugPrint('⚠️ Agora token renewal configuration skipped');
      return;
    }

    final bool sameActiveSession =
        _tokenChannelId == safeChannel && _tokenUid == uid;
    if (!sameActiveSession) {
      _tokenRefreshGeneration++;
      _tokenRefreshRunning = false;
    }

    _tokenChannelId = safeChannel;
    _tokenUid = uid;
    _freshTokenProvider = fetchFreshToken;
    _tokenExpiresInSeconds = expiresInSeconds ?? _tokenExpiresInSeconds ?? 3600;

    // A minimized room may already have a newer renewed token. Do not replace
    // it with the old token carried by the reopened route.
    if (!sameActiveSession || (_currentAgoraToken?.isEmpty ?? true)) {
      _currentAgoraToken = safeToken;
    }

    _tokenRetryAttempt = 0;
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;

    if (_joinedChannelId == safeChannel && _joinedUid == uid) {
      _scheduleNextTokenRefresh(reason: 'renewal_configured');
    }

    debugPrint(
      '✅ Agora continuous token renewal configured: '
          'channel=$safeChannel uid=$uid expires=${_tokenExpiresInSeconds}s',
    );
  }

  void _scheduleNextTokenRefresh({required String reason}) {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;

    if (_freshTokenProvider == null ||
        _tokenChannelId == null ||
        _tokenUid == null ||
        _joinedChannelId != _tokenChannelId ||
        _joinedUid != _tokenUid) {
      _nextTokenRefreshAt = null;
      return;
    }

    final Duration delay =
    _calculateTokenRefreshDelay(_tokenExpiresInSeconds);
    _nextTokenRefreshAt = DateTime.now().add(delay);
    _tokenRefreshTimer = Timer(delay, () {
      unawaited(
        requestAgoraTokenRefresh(
          reason: 'safety_timer',
          force: true,
        ),
      );
    });

    debugPrint(
      '🔐 Agora token refresh scheduled in ${delay.inSeconds}s '
          '[$reason]',
    );
  }

  void _scheduleTokenRetry({required String reason}) {
    _tokenRetryTimer?.cancel();

    const List<int> retrySeconds = <int>[3, 8, 15, 30, 60];
    final int index =
    _tokenRetryAttempt.clamp(0, retrySeconds.length - 1).toInt();
    final Duration delay = Duration(seconds: retrySeconds[index]);
    _tokenRetryAttempt++;

    _tokenRetryTimer = Timer(delay, () {
      unawaited(
        requestAgoraTokenRefresh(
          reason: '${reason}_retry_$_tokenRetryAttempt',
          force: true,
        ),
      );
    });

    debugPrint(
      '⏳ Agora token refresh retry in ${delay.inSeconds}s [$reason]',
    );
  }

  Future<bool> requestAgoraTokenRefresh({
    required String reason,
    bool force = false,
  }) async {
    if (_tokenRefreshRunning ||
        _freshTokenProvider == null ||
        _tokenChannelId == null ||
        _tokenUid == null ||
        _joinedChannelId != _tokenChannelId ||
        _joinedUid != _tokenUid) {
      return false;
    }

    final DateTime? nextRefresh = _nextTokenRefreshAt;
    if (!force &&
        nextRefresh != null &&
        DateTime.now().add(const Duration(minutes: 2)).isBefore(nextRefresh)) {
      return false;
    }

    final String expectedChannel = _tokenChannelId!;
    final int expectedUid = _tokenUid!;
    final int refreshGeneration = _tokenRefreshGeneration;
    final AgoraFreshTokenProvider provider = _freshTokenProvider!;

    _tokenRefreshRunning = true;
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;

    try {
      debugPrint('🔄 Agora token refresh started [$reason]');
      final AgoraRenewalToken result = await provider();
      final String newToken = result.token.trim();
      if (newToken.isEmpty) {
        throw StateError('Backend returned an empty Agora token');
      }

      // The user may switch rooms while the network request is running.
      if (_tokenRefreshGeneration != refreshGeneration ||
          _tokenChannelId != expectedChannel ||
          _tokenUid != expectedUid ||
          _joinedChannelId != expectedChannel ||
          _joinedUid != expectedUid) {
        debugPrint('🛡️ Stale Agora token response ignored [$reason]');
        return false;
      }

      await _serializeLifecycle<void>(() async {
        final RtcEngine? currentEngine = _engine;
        final int generation = _engineGeneration;
        if (currentEngine == null ||
            !_isInitialized ||
            !_isCurrentEngine(currentEngine, generation) ||
            _joinedChannelId != expectedChannel ||
            _joinedUid != expectedUid) {
          throw StateError('Agora session changed before renewToken');
        }

        await currentEngine.renewToken(newToken);
        if (!_isCurrentEngine(currentEngine, generation)) {
          throw StateError('Agora engine changed after renewToken');
        }
      });

      _currentAgoraToken = newToken;
      _tokenExpiresInSeconds =
          result.expiresInSeconds ?? _tokenExpiresInSeconds ?? 3600;
      _tokenRetryAttempt = 0;
      _tokenRetryTimer?.cancel();
      _tokenRetryTimer = null;
      _scheduleNextTokenRefresh(reason: 'renew_success');

      debugPrint(
        '✅ Agora token renewed without leaving channel '
            '[$reason] channel=$expectedChannel uid=$expectedUid',
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Agora token renewal failed [$reason]: $error\n$stackTrace',
      );
      if (_tokenRefreshGeneration == refreshGeneration &&
          _freshTokenProvider != null &&
          _tokenChannelId == expectedChannel &&
          _tokenUid == expectedUid &&
          _joinedChannelId == expectedChannel &&
          _joinedUid == expectedUid) {
        _scheduleTokenRetry(reason: reason);
      }
      return false;
    } finally {
      if (_tokenRefreshGeneration == refreshGeneration) {
        _tokenRefreshRunning = false;
      }
    }
  }

  Future<bool> refreshAgoraTokenIfDue({
    String reason = 'app_resumed',
  }) {
    return requestAgoraTokenRefresh(reason: reason, force: false);
  }

  void stopAgoraTokenRenewal({bool clearCurrentToken = true}) {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;
    _freshTokenProvider = null;
    _tokenChannelId = null;
    _tokenUid = null;
    _tokenExpiresInSeconds = null;
    _nextTokenRefreshAt = null;
    _tokenRetryAttempt = 0;
    _tokenRefreshGeneration++;
    _tokenRefreshRunning = false;
    if (clearCurrentToken) {
      _currentAgoraToken = null;
    }
  }

  Future<void> _releaseEngineOnce(RtcEngine engine, int generation) async {
    if (_releasedGeneration == generation) return;
    _releasedGeneration = generation;

    if (_tokenEventHandler != null &&
        _tokenEventHandlerGeneration == generation) {
      try {
        engine.unregisterEventHandler(_tokenEventHandler!);
      } catch (error) {
        debugPrint('Agora token handler unregister ignored: $error');
      }
      _tokenEventHandler = null;
      _tokenEventHandlerGeneration = null;
    }

    await engine.release();
  }

  /// Audio-live warm initialization.
  /// Use this before audience/host enters an audio room so navigation does not
  /// wait for video encoder setup. Video live can still call initializeEngine().
  Future<bool> initializeAudioEngine() {
    return _serializeLifecycle<bool>(_initializeAudioEngineLocked);
  }

  Future<bool> _initializeAudioEngineLocked() async {
    if (_isInitialized && _engine != null) {
      debugPrint('Agora audio engine already initialized');
      return true;
    }

    RtcEngine? initializingEngine;
    int? generation;
    try {
      _isInitializing = true;
      _lifecycleState = _AgoraLifecycleState.initializing;
      initializingEngine = createAgoraRtcEngine();
      generation = ++_engineGeneration;
      _releasedGeneration = null;
      _engine = initializingEngine;
      await initializingEngine.initialize(RtcEngineContext(appId: appId));
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      _registerTokenEventHandler(initializingEngine, generation);

      // Audio room does not need video encoder/camera setup. This removes the
      // enableVideo -> disableVideo cost from the join path.
      await initializingEngine.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting,
      );
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      await initializingEngine.disableVideo();
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      await initializingEngine.enableAudio();
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      await initializingEngine.enableAudioVolumeIndication(
        interval: 600,
        smooth: 3,
        reportVad: true,
      );
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      await initializingEngine.setParameters(
        '{"che.audio.low_power_mode": true}',
      );
      if (!_isCurrentEngine(initializingEngine, generation)) return false;

      _isInitialized = true;
      _audioOnlyInitialized = true;
      _lastLocalVideoEnabled = false;
      _lastLocalVideoMuted = true;
      _isInitializing = false;
      _lifecycleState = _AgoraLifecycleState.ready;

      debugPrint('Agora audio engine warm initialized successfully');
      await _applyQueuedEffects();
      return true;
    } catch (e) {
      debugPrint('Error initializing Agora audio engine: $e');
      if (initializingEngine != null &&
          generation != null &&
          identical(_engine, initializingEngine)) {
        _engine = null;
        _engineGeneration++;
        try {
          await _releaseEngineOnce(initializingEngine, generation);
        } catch (releaseError) {
          debugPrint(
            'Agora failed audio engine release ignored: $releaseError',
          );
        }
        _isInitialized = false;
        _audioOnlyInitialized = false;
        _isInitializing = false;
        _lifecycleState = _AgoraLifecycleState.idle;
      }
      return false;
    }
  }

  // Initialize the engine (singleton pattern)
  Future<bool> initializeEngine() {
    return _serializeLifecycle<bool>(_initializeEngineLocked);
  }

  Future<bool> _initializeEngineLocked() async {
    // If already initialized, make sure video mode is ready for video live.
    if (_isInitialized && _engine != null) {
      if (_audioOnlyInitialized) {
        final RtcEngine? currentEngine = _engine;
        if (currentEngine == null) return false;
        final int generation = _engineGeneration;
        try {
          await currentEngine.enableVideo();
          if (!_isCurrentEngine(currentEngine, generation)) return false;
          await currentEngine.setVideoEncoderConfiguration(
            const VideoEncoderConfiguration(
              dimensions: VideoDimensions(width: 540, height: 960),
              frameRate: 15,
              bitrate: 0,
              orientationMode: OrientationMode.orientationModeAdaptive,
              degradationPreference: DegradationPreference.maintainBalanced,
            ),
          );
          if (!_isCurrentEngine(currentEngine, generation)) return false;
          _audioOnlyInitialized = false;
          _lastLocalVideoEnabled = null;
          debugPrint('Agora engine upgraded from audio warmup to video mode');
        } catch (e) {
          debugPrint('Agora video upgrade failed safely: $e');
        }
      }
      print('Agora engine already initialized');
      return true;
    }

    RtcEngine? initializingEngine;
    int? generation;
    try {
      _isInitializing = true;
      _lifecycleState = _AgoraLifecycleState.initializing;

      // Defer camera/microphone permission requests until user actually enters a live session.
      // No permission prompt or camera usage at app start.

      // Create and initialize engine
      initializingEngine = createAgoraRtcEngine();
      generation = ++_engineGeneration;
      _releasedGeneration = null;
      _engine = initializingEngine;
      await initializingEngine.initialize(RtcEngineContext(appId: appId));
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      _registerTokenEventHandler(initializingEngine, generation);

      // Configure video settings
      await initializingEngine.enableVideo();
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      await initializingEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 540, height: 960),
          frameRate: 15,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainBalanced,
        ),
      );
      if (!_isCurrentEngine(initializingEngine, generation)) return false;
      debugPrint('VIDEO_ENCODER_BALANCED');

      // Do NOT start preview automatically; preview will start only when entering a live session.

      _isInitialized = true;
      _audioOnlyInitialized = false;
      _isInitializing = false;
      _lifecycleState = _AgoraLifecycleState.ready;

      print('Agora engine initialized successfully');
      // Apply any queued effects selected before engine init
      await _applyQueuedEffects();
      return true;
    } catch (e) {
      print('Error initializing Agora engine: $e');
      if (initializingEngine != null &&
          generation != null &&
          identical(_engine, initializingEngine)) {
        _engine = null;
        _engineGeneration++;
        try {
          await _releaseEngineOnce(initializingEngine, generation);
        } catch (releaseError) {
          debugPrint(
            'Agora failed video engine release ignored: $releaseError',
          );
        }
        _isInitialized = false;
        _audioOnlyInitialized = false;
        _isInitializing = false;
        _lifecycleState = _AgoraLifecycleState.idle;
      }
      return false;
    }
  }

  // Stop preview (useful when switching between screens)
  Future<void> stopPreview() async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine != null && _isInitialized && _isPreviewStarted) {
      await currentEngine.stopPreview();
      _isPreviewStarted = false;
      print('Agora preview stopped');
    }
  }

  // Start preview (useful when switching between screens)
  Future<void> startPreview() async {
    // Preview should only be started explicitly from live screens,
    // and only after permissions are granted and user opted in.
    final RtcEngine? currentEngine = _engine;
    if (currentEngine != null && _isInitialized && !_isPreviewStarted) {
      await currentEngine.startPreview();
      _isPreviewStarted = true;
      debugPrint('CAMERA_PREVIEW_READY');
    }
  }

  Future<void> applyNaturalLowLightEnhancement() async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine == null || !_isInitialized) return;
    try {
      await currentEngine.setLowlightEnhanceOptions(
        enabled: true,
        options: const LowlightEnhanceOptions(
          mode: LowLightEnhanceMode.lowLightEnhanceAuto,
          level: LowLightEnhanceLevel.lowLightEnhanceLevelFast,
        ),
      );
      await currentEngine.setVideoDenoiserOptions(
        enabled: true,
        options: const VideoDenoiserOptions(
          mode: VideoDenoiserMode.videoDenoiserAuto,
          level: VideoDenoiserLevel.videoDenoiserLevelFast,
        ),
      );
      await currentEngine.setColorEnhanceOptions(
        enabled: true,
        options: const ColorEnhanceOptions(
          strengthLevel: 0.25,
          skinProtectLevel: 0.35,
        ),
      );
      debugPrint('CAMERA_LOW_LIGHT_APPLIED');
    } catch (_) {
      debugPrint('CAMERA_LOW_LIGHT_UNSUPPORTED');
    }
  }

  // Join channel for live streaming
  Future<void> joinChannel(String channelName, int uid) {
    return joinChannelWithOptions(
      token: '',
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> joinChannelWithOptions({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
    bool force = false,
  }) {
    return _serializeLifecycle<void>(() async {
      final RtcEngine? currentEngine = _engine;
      final int generation = _engineGeneration;
      if (currentEngine == null || !_isInitialized) return;
      if (!force && _joinedChannelId == channelId && _joinedUid == uid) {
        if (token.trim().isNotEmpty && (_currentAgoraToken?.isEmpty ?? true)) {
          _currentAgoraToken = token.trim();
        }
        _scheduleNextTokenRefresh(reason: 'join_already_active');
        debugPrint('Agora already joined channel=$channelId uid=$uid');
        return;
      }

      await currentEngine.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        options: options,
      );
      if (!_isCurrentEngine(currentEngine, generation)) return;
      _joinedChannelId = channelId;
      _joinedUid = uid;
      if (token.trim().isNotEmpty) {
        _currentAgoraToken = token.trim();
      }
      _scheduleNextTokenRefresh(reason: 'join_channel');
      debugPrint('Agora joined channel=$channelId uid=$uid');
    });
  }

  // Leave channel
  Future<void> leaveChannel() {
    return _serializeLifecycle<void>(() async {
      final RtcEngine? currentEngine = _engine;
      final int generation = _engineGeneration;
      if (currentEngine == null || !_isInitialized) {
        stopAgoraTokenRenewal();
        _clearChannelState();
        return;
      }
      if (_joinedChannelId == null && _joinedUid == null) {
        stopAgoraTokenRenewal();
        return;
      }

      try {
        await currentEngine.leaveChannel();
        debugPrint('Left channel');
      } finally {
        if (_isCurrentEngine(currentEngine, generation)) {
          stopAgoraTokenRenewal();
          _clearChannelState();
        }
      }
    });
  }

  // Dispose the engine (call this when app is closing)
  Future<void> dispose() {
    return _serializeLifecycle<void>(() async {
      final RtcEngine? currentEngine = _engine;
      final int generation = _engineGeneration;
      if (currentEngine == null) return;

      _lifecycleState = _AgoraLifecycleState.disposing;
      stopAgoraTokenRenewal();
      _engine = null;
      _engineGeneration++;
      _isInitialized = false;
      _audioOnlyInitialized = false;
      _isInitializing = false;
      _isJoiningChannel = false;
      _isPreviewStarted = false;
      _clearChannelState();

      try {
        await currentEngine.leaveChannel();
      } catch (error) {
        debugPrint('Agora dispose leave ignored: $error');
      }
      try {
        await _releaseEngineOnce(currentEngine, generation);
      } finally {
        _lifecycleState = _AgoraLifecycleState.idle;
      }
      print('Agora engine disposed');
    });
  }

  // Toggle audio
  Future<void> toggleAudio(bool enabled) async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine != null && _isInitialized) {
      if (enabled) {
        await currentEngine.enableAudio();
        await currentEngine.muteLocalAudioStream(false);
      } else {
        await currentEngine.muteLocalAudioStream(true);
      }
      print('Audio ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  // Toggle video
  Future<void> toggleVideo(bool enabled) async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine != null && _isInitialized) {
      if (enabled) {
        await currentEngine.enableLocalVideo(true);
        await currentEngine.muteLocalVideoStream(false);
      } else {
        await currentEngine.muteLocalVideoStream(true);
      }
      print('Video ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  Future<void> flipCamera() async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine != null && _isInitialized) {
      try {
        // Switch camera direction
        await currentEngine.switchCamera();
        if (!_isCurrentEngine(currentEngine, generation)) return;

        // Update the camera state
        _isFrontCamera = !_isFrontCamera;

        print('Camera flipped to ${_isFrontCamera ? 'front' : 'back'} camera');
      } catch (e) {
        print('Error flipping camera: $e');
      }
    } else {
      print('Cannot flip camera: Engine not initialized');
    }
  }

  Future<void> enableVideo(bool enabled) async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine != null && _isInitialized) {
      if (enabled) {
        await currentEngine.enableLocalVideo(true);
        await currentEngine.muteLocalVideoStream(false);
      } else {
        await currentEngine.muteLocalVideoStream(true);
      }
      print('Video ${enabled ? 'enabled' : 'disabled'}');
    }
  }

  // =================== VIDEO EFFECTS / BEAUTY HELPERS ===================
  /// Preset types to make choosing filters easy (Bigo-like)
  static const _defaultBeauty = BeautyOptions(
    lighteningContrastLevel: LighteningContrastLevel.lighteningContrastLow,
    lighteningLevel: 0.3,
    smoothnessLevel: 0.4,
    rednessLevel: 0.2,
    sharpnessLevel: 0.2,
  );

  Future<void> disableAllVideoEffects() async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine == null || !_isInitialized) {
      // Queue disable so it applies when engine becomes ready
      _queuedBeauty = _defaultBeauty;
      _queuedBeautyEnabled = false;
      _queuedColor = const ColorEnhanceOptions();
      _queuedColorEnabled = false;
      debugPrint('🔧 Queued disable effects (engine not ready)');
      return;
    }
    try {
      await currentEngine.setBeautyEffectOptions(
        enabled: false,
        options: _defaultBeauty,
      );
      // Guard these APIs for SDK versions; catch if unsupported.
      try {
        await currentEngine.setColorEnhanceOptions(
          enabled: false,
          options: const ColorEnhanceOptions(),
        );
      } catch (_) {}
      debugPrint('🔧 Agora effects disabled');
    } catch (e) {
      debugPrint('Agora disable effects error: $e');
    }
  }

  Future<void> setBeautyNatural() async {
    await _applyBeauty(
      const BeautyOptions(
        lighteningContrastLevel: LighteningContrastLevel.lighteningContrastLow,
        lighteningLevel: 0.35,
        smoothnessLevel: 0.45,
        rednessLevel: 0.20,
        sharpnessLevel: 0.25,
      ),
    );
  }

  Future<void> setBeautySmooth() async {
    await _applyBeauty(
      const BeautyOptions(
        lighteningContrastLevel:
        LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.45,
        smoothnessLevel: 0.70,
        rednessLevel: 0.18,
        sharpnessLevel: 0.20,
      ),
    );
  }

  Future<void> setBeautyGlossy() async {
    await _applyBeauty(
      const BeautyOptions(
        lighteningContrastLevel: LighteningContrastLevel.lighteningContrastHigh,
        lighteningLevel: 0.60,
        smoothnessLevel: 0.60,
        rednessLevel: 0.35,
        sharpnessLevel: 0.30,
      ),
    );
  }

  Future<void> setBeautyRosy() async {
    await _applyBeauty(
      const BeautyOptions(
        lighteningContrastLevel:
        LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.40,
        smoothnessLevel: 0.55,
        rednessLevel: 0.60,
        sharpnessLevel: 0.25,
      ),
    );
  }

  /// Blemish/acne softening preset (approximation using smoothing)
  Future<void> setBeautyBlemish() async {
    await _applyBeauty(
      const BeautyOptions(
        lighteningContrastLevel:
        LighteningContrastLevel.lighteningContrastNormal,
        lighteningLevel: 0.50,
        smoothnessLevel: 0.80,
        rednessLevel: 0.22,
        sharpnessLevel: 0.35,
      ),
    );
  }

  Future<void> setBeautyHD() async {
    await _applyBeauty(
      const BeautyOptions(
        lighteningContrastLevel: LighteningContrastLevel.lighteningContrastHigh,
        lighteningLevel: 0.50,
        smoothnessLevel: 0.50,
        rednessLevel: 0.20,
        sharpnessLevel: 0.70,
      ),
    );
  }

  /// Custom beauty with sliders
  Future<void> setBeautyCustom({
    LighteningContrastLevel contrast =
        LighteningContrastLevel.lighteningContrastNormal,
    double lightening = 0.4,
    double smoothness = 0.5,
    double redness = 0.2,
    double sharpness = 0.2,
  }) async {
    await _applyBeauty(
      BeautyOptions(
        lighteningContrastLevel: contrast,
        lighteningLevel: lightening.clamp(0.0, 1.0),
        smoothnessLevel: smoothness.clamp(0.0, 1.0),
        rednessLevel: redness.clamp(0.0, 1.0),
        sharpnessLevel: sharpness.clamp(0.0, 1.0),
      ),
    );
  }

  Future<void> _applyBeauty(BeautyOptions options) async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine == null || !_isInitialized) {
      _queuedBeauty = options;
      _queuedBeautyEnabled = true;
      debugPrint('🎨 Queued beauty preset: $options');
      return;
    }
    try {
      await currentEngine.setBeautyEffectOptions(
        enabled: true,
        options: options,
      );
      debugPrint('🎨 Applied beauty: $options');
    } catch (e) {
      debugPrint('Agora beauty apply error: $e');
    }
  }

  // Optional extra tweaks
  Future<void> setColorEnhance({
    double strength = 0.4,
    double skinProtect = 0.3,
  }) async {
    final RtcEngine? currentEngine = _engine;
    if (currentEngine == null || !_isInitialized) {
      _queuedColor = ColorEnhanceOptions(
        strengthLevel: strength.clamp(0.0, 1.0),
        skinProtectLevel: skinProtect.clamp(0.0, 1.0),
      );
      _queuedColorEnabled = true;
      debugPrint(
        '🌈 Queued color enhance: strength=$strength, skin=$skinProtect',
      );
      return;
    }
    try {
      await currentEngine.setColorEnhanceOptions(
        enabled: true,
        options: ColorEnhanceOptions(
          strengthLevel: strength.clamp(0.0, 1.0),
          skinProtectLevel: skinProtect.clamp(0.0, 1.0),
        ),
      );
      debugPrint('🌈 Color enhance set: strength=$strength, skin=$skinProtect');
    } catch (e) {
      debugPrint('Agora color enhance error: $e');
    }
  }

  Future<void> _applyQueuedEffects() async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;
    try {
      if (_queuedBeauty != null) {
        await currentEngine.setBeautyEffectOptions(
          enabled: _queuedBeautyEnabled,
          options: _queuedBeauty!,
        );
        if (!_isCurrentEngine(currentEngine, generation)) return;
        debugPrint('✅ Applied queued beauty');
      }

      if (_queuedColor != null) {
        await currentEngine.setColorEnhanceOptions(
          enabled: _queuedColorEnabled,
          options: _queuedColor!,
        );
        if (!_isCurrentEngine(currentEngine, generation)) return;
        debugPrint('✅ Applied queued color enhance');
      }

      // Clear queue
      _queuedBeauty = null;
      _queuedColor = null;
      _queuedBeautyEnabled = false;
      _queuedColorEnabled = false;
    } catch (e) {
      debugPrint('Error applying queued effects: $e');
    }
  }


  // =================== FAST VIDEO PREVIEW ===================
  /// Makes the camera visible as early as possible. Heavy enhancement work is
  /// intentionally not performed here, so the UI does not wait for beauty,
  /// denoise or LUT generation before showing the first preview frame.
  Future<bool> prepareVideoPreviewFast() async {
    final bool initialized = await initializeEngine();
    if (!initialized) return false;

    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return false;

    try {
      await currentEngine.enableVideo();
      if (!_isCurrentEngine(currentEngine, generation)) return false;
      await currentEngine.enableLocalVideo(true);
      if (!_isCurrentEngine(currentEngine, generation)) return false;
      await currentEngine.muteLocalVideoStream(false);
      if (!_isCurrentEngine(currentEngine, generation)) return false;

      _lastLocalVideoEnabled = true;
      _lastLocalVideoMuted = false;

      await startPreview();
      return _isCurrentEngine(currentEngine, generation);
    } catch (error) {
      debugPrint('FAST_CAMERA_PREVIEW_FAILED => $error');
      return false;
    }
  }

  /// Applies the encoder tuning after preview has already become visible.
  /// Keeping this separate removes unnecessary work from the first-frame path.
  Future<void> configureVideoQualityAfterPreview() async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;

    try {
      await currentEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 540, height: 960),
          frameRate: 15,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainBalanced,
        ),
      );
      if (!_isCurrentEngine(currentEngine, generation)) return;

      try {
        await currentEngine.setParameters(
          '{"che.video.hardware_encoding":true,'
              '"che.video.enableAdaptiveBitrate":true,'
              '"rtc.video.dynamic_switch":true}',
        );
      } catch (error) {
        debugPrint('VIDEO_FAST_PARAMETERS_SKIPPED => $error');
      }
    } catch (error) {
      debugPrint('VIDEO_QUALITY_POST_PREVIEW_SKIPPED => $error');
    }
  }

  // =================== PROFESSIONAL VIDEO LOOKS ===================
  Future<String> _ensureGeneratedLut(AgoraLutFilter filter) async {
    final String? cached = _generatedLutPaths[filter];
    if (cached != null && File(cached).existsSync()) return cached;

    final String filePath =
        '${Directory.systemTemp.path}/linlive_${filter.name}_32.cube';
    final File file = File(filePath);

    if (!file.existsSync() || await file.length() < 10000) {
      final String cube = await compute(_buildAgoraCubeLut, filter.name);
      await file.writeAsString(cube, flush: true);
    }

    _generatedLutPaths[filter] = filePath;
    return filePath;
  }

  Future<void> _applyLutFilter(
      AgoraLutFilter filter, {
        required double strength,
      }) async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;

    if (filter == AgoraLutFilter.none || strength <= .001) {
      try {
        await currentEngine.setFilterEffectOptions(
          enabled: false,
          options: const FilterEffectOptions(),
        );
        if (!_isCurrentEngine(currentEngine, generation)) return;
      } catch (error) {
        debugPrint('AGORA_LUT_DISABLE_SKIPPED => $error');
      }
      _activeLutFilter = AgoraLutFilter.none;
      _activeLutStrength = 0;
      return;
    }

    if (_activeLutFilter == filter &&
        (_activeLutStrength - strength).abs() < .005) {
      return;
    }

    try {
      final String path = await _ensureGeneratedLut(filter);
      if (!_isCurrentEngine(currentEngine, generation)) return;

      await currentEngine.setFilterEffectOptions(
        enabled: true,
        options: FilterEffectOptions(
          path: path,
          strength: strength.clamp(0.0, 1.0).toDouble(),
        ),
      );
      if (!_isCurrentEngine(currentEngine, generation)) return;

      _activeLutFilter = filter;
      _activeLutStrength = strength;
      debugPrint(
        'AGORA_LUT_APPLIED => ${filter.name} '
            'strength=${strength.toStringAsFixed(2)}',
      );
    } catch (error) {
      // Some builds/devices do not ship or support Agora Clear Vision LUT.
      // Keep the look functional by falling back to color enhancement.
      debugPrint('AGORA_LUT_FALLBACK => ${filter.name}: $error');
      final double fallbackStrength = switch (filter) {
        AgoraLutFilter.saturated => .50,
        AgoraLutFilter.fresh => .38,
        AgoraLutFilter.studio => .42,
        AgoraLutFilter.cinematic => .46,
        _ => .30,
      };
      await setColorEnhance(
        strength: fallbackStrength,
        skinProtect: .48,
      );
    }
  }

  Future<void> setEnhancementQuality({
    bool lowLight = true,
    bool denoise = true,
  }) async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;

    try {
      await currentEngine.setLowlightEnhanceOptions(
        enabled: lowLight,
        options: const LowlightEnhanceOptions(
          mode: LowLightEnhanceMode.lowLightEnhanceAuto,
          level: LowLightEnhanceLevel.lowLightEnhanceLevelFast,
        ),
      );
      if (!_isCurrentEngine(currentEngine, generation)) return;
    } catch (error) {
      debugPrint('LOW_LIGHT_OPTION_SKIPPED => $error');
    }

    try {
      await currentEngine.setVideoDenoiserOptions(
        enabled: denoise,
        options: const VideoDenoiserOptions(
          mode: VideoDenoiserMode.videoDenoiserAuto,
          level: VideoDenoiserLevel.videoDenoiserLevelFast,
        ),
      );
    } catch (error) {
      debugPrint('VIDEO_DENOISER_OPTION_SKIPPED => $error');
    }
  }

  Future<void> applyProfessionalVideoLook({
    required double lightening,
    required double smoothness,
    required double redness,
    required double sharpness,
    required double colorStrength,
    required double skinProtect,
    required AgoraLutFilter filter,
    required double filterStrength,
    bool lowLight = true,
    bool denoise = true,
  }) async {
    // These SDK effects are applied to the primary camera source, therefore the
    // same processed frames continue into the published broadcaster stream.
    await setBeautyCustom(
      contrast: LighteningContrastLevel.lighteningContrastNormal,
      lightening: lightening,
      smoothness: smoothness,
      redness: redness,
      sharpness: sharpness,
    );

    await setColorEnhance(
      strength: colorStrength,
      skinProtect: skinProtect,
    );

    await _applyLutFilter(
      filter,
      strength: filterStrength,
    );

    await setEnhancementQuality(
      lowLight: lowLight,
      denoise: denoise,
    );
  }

  Future<void> resetProfessionalVideoEffects() async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;

    await disableAllVideoEffects();
    await _applyLutFilter(AgoraLutFilter.none, strength: 0);

    if (currentEngine == null || !_isInitialized) return;

    try {
      await currentEngine.setLowlightEnhanceOptions(
        enabled: false,
        options: const LowlightEnhanceOptions(),
      );
      if (!_isCurrentEngine(currentEngine, generation)) return;
    } catch (_) {}

    try {
      await currentEngine.setVideoDenoiserOptions(
        enabled: false,
        options: const VideoDenoiserOptions(),
      );
    } catch (_) {}
  }

  // =================== SAFE LIVE HELPERS ===================
  /// Use this instead of calling engine.setClientRole repeatedly from UI/build.
  Future<void> setClientRoleSafe(ClientRoleType role) async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;
    if (_lastClientRole == role) return;

    try {
      await currentEngine.setClientRole(role: role);
      if (!_isCurrentEngine(currentEngine, generation)) return;
      _lastClientRole = role;
      debugPrint('✅ Agora role set safely: $role');
    } catch (e) {
      debugPrint('❌ Agora setClientRoleSafe error: $e');
    }
  }

  Future<void> muteLocalAudioSafe(bool mute) async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;
    if (_lastLocalAudioMuted == mute) return;

    try {
      await currentEngine.muteLocalAudioStream(mute);
      if (!_isCurrentEngine(currentEngine, generation)) return;
      _lastLocalAudioMuted = mute;
    } catch (e) {
      debugPrint('❌ Agora muteLocalAudioSafe error: $e');
    }
  }

  Future<void> enableLocalVideoSafe(bool enabled) async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;
    if (_lastLocalVideoEnabled == enabled) return;

    try {
      await currentEngine.enableLocalVideo(enabled);
      if (!_isCurrentEngine(currentEngine, generation)) return;
      _lastLocalVideoEnabled = enabled;
    } catch (e) {
      debugPrint('❌ Agora enableLocalVideoSafe error: $e');
    }
  }

  Future<void> muteLocalVideoSafe(bool mute) async {
    final RtcEngine? currentEngine = _engine;
    final int generation = _engineGeneration;
    if (currentEngine == null || !_isInitialized) return;
    if (_lastLocalVideoMuted == mute) return;

    try {
      await currentEngine.muteLocalVideoStream(mute);
      if (!_isCurrentEngine(currentEngine, generation)) return;
      _lastLocalVideoMuted = mute;
    } catch (e) {
      debugPrint('❌ Agora muteLocalVideoSafe error: $e');
    }
  }

  /// Prevent duplicate joinChannel calls when page rebuilds/resumes.
  Future<void> joinChannelSafe({
    required String token,
    required String channelId,
    required int uid,
    required ClientRoleType role,
    bool force = false,
    bool? publishCameraTrack,
    bool? publishMicrophoneTrack,
    bool autoSubscribeAudio = true,
    bool autoSubscribeVideo = true,
  }) {
    return _serializeLifecycle<void>(() async {
      final RtcEngine? currentEngine = _engine;
      final int generation = _engineGeneration;
      if (currentEngine == null || !_isInitialized) return;

      if (_isJoiningChannel) {
        debugPrint('⏳ Agora join already running, skip');
        return;
      }

      final bool isBroadcaster = role == ClientRoleType.clientRoleBroadcaster;
      final bool cameraEnabled = publishCameraTrack ?? isBroadcaster;

      if (!force && _joinedChannelId == channelId && _joinedUid == uid) {
        await setClientRoleSafe(role);
        if (isBroadcaster) {
          await enableLocalVideoSafe(cameraEnabled);
          await muteLocalAudioSafe(!(publishMicrophoneTrack ?? true));
          await muteLocalVideoSafe(!cameraEnabled);
        } else {
          await enableLocalVideoSafe(false);
          await muteLocalAudioSafe(true);
          await muteLocalVideoSafe(true);
        }
        if (token.trim().isNotEmpty && (_currentAgoraToken?.isEmpty ?? true)) {
          _currentAgoraToken = token.trim();
        }
        _scheduleNextTokenRefresh(reason: 'safe_join_already_active');
        debugPrint('✅ Agora already joined same channel, skip join');
        return;
      }

      _isJoiningChannel = true;

      try {
        if (_joinedChannelId != null &&
            (_joinedChannelId != channelId || _joinedUid != uid || force)) {
          await currentEngine.leaveChannel();
          if (!_isCurrentEngine(currentEngine, generation)) return;
          final bool renewalPreparedForTarget =
              _tokenChannelId == channelId && _tokenUid == uid;
          if (!renewalPreparedForTarget) {
            stopAgoraTokenRenewal();
          }
          _joinedChannelId = null;
          _joinedUid = null;
          _lastClientRole = null;
          _lastLocalAudioMuted = null;
          _lastLocalVideoMuted = null;
          _lastLocalVideoEnabled = null;
        }

        await currentEngine.enableAudio();
        if (!_isCurrentEngine(currentEngine, generation)) return;
        if (cameraEnabled) {
          await currentEngine.enableVideo();
        } else {
          await currentEngine.disableVideo();
        }
        if (!_isCurrentEngine(currentEngine, generation)) return;
        await currentEngine.setClientRole(role: role);
        if (!_isCurrentEngine(currentEngine, generation)) return;

        if (isBroadcaster) {
          await currentEngine.enableLocalVideo(cameraEnabled);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          await currentEngine.muteLocalVideoStream(!cameraEnabled);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          await currentEngine.muteLocalAudioStream(
            !(publishMicrophoneTrack ?? true),
          );
          if (!_isCurrentEngine(currentEngine, generation)) return;
          _lastLocalVideoEnabled = cameraEnabled;
          _lastLocalVideoMuted = !cameraEnabled;
          _lastLocalAudioMuted = !(publishMicrophoneTrack ?? true);
        } else {
          await currentEngine.enableLocalVideo(false);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          await currentEngine.muteLocalVideoStream(true);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          await currentEngine.muteLocalAudioStream(true);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          _lastLocalVideoEnabled = false;
          _lastLocalVideoMuted = true;
          _lastLocalAudioMuted = true;
        }

        await currentEngine.joinChannel(
          token: token,
          channelId: channelId,
          uid: uid,
          options: ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
            clientRoleType: role,
            publishCameraTrack: cameraEnabled,
            publishMicrophoneTrack: publishMicrophoneTrack ?? isBroadcaster,
            autoSubscribeAudio: autoSubscribeAudio,
            autoSubscribeVideo: autoSubscribeVideo,
          ),
        );
        if (!_isCurrentEngine(currentEngine, generation)) return;

        _joinedChannelId = channelId;
        _joinedUid = uid;
        _lastClientRole = role;
        if (token.trim().isNotEmpty) {
          _currentAgoraToken = token.trim();
        }
        _scheduleNextTokenRefresh(reason: 'safe_join_channel');
        debugPrint(
          '✅ Agora joined safely: channel=$channelId uid=$uid role=$role',
        );
      } catch (e) {
        debugPrint('❌ Agora joinChannelSafe error: $e');
      } finally {
        _isJoiningChannel = false;
      }
    });
  }

  /// Restores Agora microphone capture after another calling app temporarily
  /// owns Android audio focus.
  ///
  /// A normal `enableAudio()` call is sometimes not enough because the Agora
  /// channel remains connected while the native recording device is stale.
  /// `hardRestartAudioDevice=true` briefly restarts only Agora's audio module,
  /// then reapplies role + publish options + the user's real mute state.
  Future<void> recoverAudioAfterInterruption({
    required ClientRoleType role,
    required bool publishMicrophoneTrack,
    required bool microphoneMuted,
    bool hardRestartAudioDevice = false,
    bool forceSpeakerphone = true,
    String reason = 'app_resume',
  }) {
    return _serializeLifecycle<void>(() async {
      final RtcEngine? currentEngine = _engine;
      final int generation = _engineGeneration;
      if (currentEngine == null || !_isInitialized) {
        debugPrint(
          '⚠️ Agora interruption recovery skipped: engine not ready [$reason]',
        );
        return;
      }

      final DateTime now = DateTime.now();
      final DateTime? last = _lastAudioInterruptionRecoveryAt;
      if (_audioInterruptionRecoveryRunning) {
        debugPrint('🛡️ Agora interruption recovery already running [$reason]');
        return;
      }
      if (!hardRestartAudioDevice &&
          last != null &&
          now.difference(last).inMilliseconds < 350) {
        debugPrint('🛡️ Agora soft recovery throttled [$reason]');
        return;
      }

      _audioInterruptionRecoveryRunning = true;
      _lastAudioInterruptionRecoveryAt = now;

      try {
        // Cached values describe what we asked Agora to do before the external
        // call; they do not prove that Android is still capturing audio now.
        _lastClientRole = null;
        _lastLocalAudioMuted = null;

        if (hardRestartAudioDevice) {
          try {
            await currentEngine.disableAudio();
            if (!_isCurrentEngine(currentEngine, generation)) return;
            await Future<void>.delayed(const Duration(milliseconds: 140));
          } catch (error) {
            debugPrint(
              '⚠️ Agora disableAudio ignored during recovery [$reason]: $error',
            );
          }
        }

        await currentEngine.enableAudio();
        if (!_isCurrentEngine(currentEngine, generation)) return;

        // Explicitly reopen local recording. This is important after WhatsApp,
        // a GSM call or Google Meet releases the microphone.
        await currentEngine.enableLocalAudio(true);
        if (!_isCurrentEngine(currentEngine, generation)) return;

        await currentEngine.setClientRole(role: role);
        if (!_isCurrentEngine(currentEngine, generation)) return;

        try {
          await currentEngine.updateChannelMediaOptions(
            ChannelMediaOptions(
              clientRoleType: role,
              publishMicrophoneTrack: publishMicrophoneTrack,
              autoSubscribeAudio: true,
            ),
          );
          if (!_isCurrentEngine(currentEngine, generation)) return;
        } catch (error) {
          debugPrint(
            '⚠️ Agora recovery media options ignored [$reason]: $error',
          );
        }

        if (publishMicrophoneTrack) {
          // Keep the track published even when the user is manually muted.
          // Recording volume 0 preserves host music/audio mixing publication.
          await currentEngine.muteLocalAudioStream(false);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          await currentEngine.adjustRecordingSignalVolume(
            microphoneMuted ? 0 : 100,
          );
        } else {
          await currentEngine.muteLocalAudioStream(true);
          if (!_isCurrentEngine(currentEngine, generation)) return;
          await currentEngine.adjustRecordingSignalVolume(0);
        }
        if (!_isCurrentEngine(currentEngine, generation)) return;

        try {
          await currentEngine.enableAudioVolumeIndication(
            interval: 600,
            smooth: 3,
            reportVad: true,
          );
        } catch (error) {
          debugPrint(
            '⚠️ Agora recovery volume indication ignored [$reason]: $error',
          );
        }

        if (forceSpeakerphone) {
          try {
            await currentEngine.setDefaultAudioRouteToSpeakerphone(true);
            await currentEngine.setEnableSpeakerphone(true);
          } catch (error) {
            debugPrint(
              '⚠️ Agora recovery speaker route ignored [$reason]: $error',
            );
          }
        }

        _lastClientRole = role;
        _lastLocalAudioMuted = publishMicrophoneTrack
            ? false
            : true;

        debugPrint(
          '✅ Agora audio recovered after interruption '
              '[$reason] publishMic=$publishMicrophoneTrack muted=$microphoneMuted '
              'hardRestart=$hardRestartAudioDevice',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '❌ Agora interruption recovery failed [$reason]: '
              '$error\n$stackTrace',
        );
      } finally {
        _audioInterruptionRecoveryRunning = false;
      }
    });
  }

  Future<void> joinPkChannelSafe({
    required String token,
    required String channelId,
    required int uid,
    required bool isBroadcaster,
    bool force = true,
  }) async {
    await joinChannelSafe(
      token: token,
      channelId: channelId,
      uid: uid,
      role: isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
      force: force,
      publishCameraTrack: isBroadcaster,
      publishMicrophoneTrack: isBroadcaster,
      autoSubscribeAudio: true,
      autoSubscribeVideo: true,
    );
  }

  bool get isJoinedChannel => _joinedChannelId != null;
  String? get joinedChannelId => _joinedChannelId;
  int? get joinedUid => _joinedUid;
}
