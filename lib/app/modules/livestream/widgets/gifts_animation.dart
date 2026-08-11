import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/image_helper.dart';
import '../socket/websocket_controller.dart';
import 'LiveView_Circle_Container.dart';

class GiftAnimationWidget extends StatefulWidget {
  final dynamic giftData;

  /// Keep this widget mounted for the whole live-room lifetime.
  /// isActive only controls the normal on-page gift content; the Lucky queue
  /// uses one persistent root overlay and must survive rapid Combo taps.
  final bool isActive;

  const GiftAnimationWidget({
    Key? key,
    required this.giftData,
    this.isActive = true,
  }) : super(key: key);

  @override
  State<GiftAnimationWidget> createState() => _GiftAnimationWidgetState();
}

class _GiftAnimationWidgetState extends State<GiftAnimationWidget>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  AudioPlayer? _audioPlayer;
  AudioPlayer? _bigWinAudioPlayer;
  bool _isDisposed = false;
  bool _isPlayingAudio = false;
  bool _isClosing = false;
  Timer? _luckyGiftHideTimer;
  Timer? _normalGiftSafetyTimer;

  AnimationController? _luckyPulseController;
  Animation<double>? _luckyPulseAnimation;
  // The visible Lucky flight is rendered by the permanent canvas layer.
  // A lightweight timer releases the next outer queue item; a second animation
  // controller/ticker per tap only wasted frames and caused rapid-combo jank.
  Timer? _luckyQueueReleaseTimer;
  List<_LuckyFountainParticle> _luckyParticles = const [];

  late final AnimationController _coinCounterController;
  late final AnimationController _luckyWinOrbController;
  Animation<int> _coinCounterAnimation = const AlwaysStoppedAnimation<int>(0);
  double _shownMultiplier = 0;
  int _shownWinAmount = 0;
  String _lastLuckyResultKey = '';
  String _lastReceiverTargetLogKey = '';
  String _lastBigWinSoundKey = '';
  String _currentLuckyAnimationKey = '';
  int _luckyRunToken = 0;

  int _stableLuckySenderId = 0;
  String _stableLuckySenderName = '';
  String _stableLuckySenderProfileUrl = '';
  String _stableLuckyGiftUrl = '';

  /// One persistent root overlay renders every rapid Lucky tap.
  /// We never create one OverlayEntry/AnimationController per tap; that old
  /// pattern caused memory pressure, frame drops and crashes during Combo spam.
  /// One permanent in-room animation layer. It stays mounted while the room
  /// is open, so rapid taps never create/remove OverlayEntry objects.
  final GlobalKey<_LuckyGiftFlightQueueLayerState> _luckyFlightLayerKey =
  GlobalKey<_LuckyGiftFlightQueueLayerState>();
  final List<_LuckyFlightRequest> _pendingLuckyFlightRequests =
  <_LuckyFlightRequest>[];
  bool _luckyFlightFlushScheduled = false;
  int _luckyFlightSerial = 0;

  /// One physical tap can arrive through optimistic local data, gift_sent and
  /// lucky_gift_result updates. Keep one short-lived key per physical tap so
  /// those copies create only ONE sender-to-center image.
  final Map<String, int> _recentLuckyTapLaunches = <String, int>{};

  /// Sender-side optimistic taps are later echoed as gift_sent events with a
  /// different event_id. Store one pending echo token per local tap; each
  /// matching WebSocket echo consumes exactly one token instead of launching
  /// a duplicate animation.
  final Map<String, List<int>> _pendingLuckyLocalEchoes =
  <String, List<int>>{};

  String _lastGlobalLuckyBannerKey = '';

  static OverlayEntry? _globalLuckyResultBannerEntry;
  static Timer? _globalLuckyResultBannerTimer;

  /// Receiver seat/profile coordinates are stable during one flight.
  /// Resolving RenderBox/BuildContext every animation frame caused heavy jank
  /// during rapid Combo taps, so targets are cached once per queued flight.
  List<Offset> _cachedLuckyReceiverTargets = const <Offset>[];
  Offset? _cachedLuckySenderSource;

  ui.Image? _luckyParticleImage;
  ImageStream? _luckyParticleImageStream;
  ImageStreamListener? _luckyParticleImageListener;
  bool _luckyParticleImageRequested = false;
  String _luckyParticleImageUrl = '';

  static const double _mainLuckyGiftSize = 112.0;
  static const double _mainLuckyGiftYOffset = 60.0;
  /// This controller is only the queue-release clock. The visible image flight
  /// runs independently for 720ms, therefore the next queued tap can start
  /// almost immediately without cutting the previous image.
  static const int _luckyFlightMs = 105;
  static const int _luckySerialGapMs = 0;

  static const int _luckyStartDelayMs = 10;
  static const int _luckyEndDelayMs = 10;

  /// Keep the sender profile/name card visible between Combo taps.
  /// Every new tap resets this idle timer, while only Times/Coin values update.
  static const int _luckyCardIdleHideMs = 7000;

  /// Target slightly below avatar center, so the image visibly enters inside
  /// the lower part of the receiver profile before becoming fully hidden.
  static const double _luckyProfileIntakeYOffset =
      _GiftAnimationGeometry.profileIntakeYOffset;

  /// A single Combo tap must launch only that tap's quantity. Cumulative
  /// combo_count/combo_total are deliberately ignored, otherwise tap 10 would
  /// incorrectly launch ten new images instead of one.
  int get _luckySendCount {
    /// UX rule: a single Combo tap launches exactly one visible gift image.
    /// Multiple taps are already queued one-by-one by the controller.
    /// So even if backend quantity fields contain cumulative values,
    /// this overlay must draw only one physical flying gift per tap.
    return 1;
  }

  Duration get _luckyDuration {
    final count = _luckySendCount;
    final totalMs = _luckyStartDelayMs +
        _luckyFlightMs +
        ((count - 1) * _luckySerialGapMs) +
        _luckyEndDelayMs;
    return Duration(milliseconds: totalMs);
  }

  void _onLuckySpreadStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || _isDisposed) return;

    // Finish exactly one queued physical tap, then let WebsocketController
    // mount the next tap into this same persistent card immediately.
    Future.microtask(() {
      if (mounted && !_isDisposed) {
        _closeGiftAnimation();
      }
    });
  }


  void _scheduleLuckyQueueRelease() {
    _luckyQueueReleaseTimer?.cancel();
    _luckyQueueReleaseTimer = Timer(_luckyDuration, () {
      if (mounted && !_isDisposed) {
        _closeGiftAnimation();
      }
    });
  }

  void _scheduleLuckyReceiverTargetRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_isLuckyGift) return;

      final targets = _receiverProfileTargetsForLucky();
      final senderSource = _senderProfileSourceForLucky();

      bool targetsChanged =
          targets.length != _cachedLuckyReceiverTargets.length;
      if (!targetsChanged) {
        for (int i = 0; i < targets.length; i++) {
          if ((targets[i] - _cachedLuckyReceiverTargets[i]).distance > 4.0) {
            targetsChanged = true;
            break;
          }
        }
      }

      final bool senderChanged = senderSource != null &&
          (_cachedLuckySenderSource == null ||
              (senderSource - _cachedLuckySenderSource!).distance > 4.0);

      if (targetsChanged) {
        _cachedLuckyReceiverTargets = List<Offset>.unmodifiable(targets);
      }
      if (senderChanged && senderSource != null) {
        _cachedLuckySenderSource = senderSource;
      }
      // These values are consumed only when the next flight request is made.
      // No visible widget depends on them directly, so setState() here rebuilt
      // the whole gift overlay for no visual reason.
    });
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _isLuckyResultOnlyPayload(Map<String, dynamic> data) {
    final String action = (data['action_type'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (data['optimistic_local'] == true) return false;

    return action == 'lucky_gift_result' ||
        action == 'lucky_gift_card' ||
        action.contains('lucky_gift_result') ||
        action.contains('lucky_result');
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  String _luckyEchoFingerprint(Map<String, dynamic> data) {
    final Map<String, dynamic> gift = _mapOf(data['gift']).isNotEmpty
        ? _mapOf(data['gift'])
        : _mapOf(data['gift_data']);
    final String stream = _firstNonEmpty(<dynamic>[
      data['livestream_id'],
      data['stream_id'],
      data['live_id'],
    ]);
    final String sender = _firstNonEmpty(<dynamic>[
      data['sender_id'],
      data['user_id'],
      _mapOf(data['sender'])['id'],
      _mapOf(data['sender'])['user_id'],
    ]);
    final String giftId = _firstNonEmpty(<dynamic>[
      data['gift_id'],
      data['gift_list_id'],
      gift['id'],
      gift['gift_id'],
    ]);
    if (sender.isEmpty || giftId.isEmpty) return '';
    return '$stream|$sender|$giftId';
  }

  bool _hasPhysicalTapSerial(Map<String, dynamic> data) {
    return _firstNonEmpty(<dynamic>[
      data['gift_animation_serial'],
      data['animation_queue_serial'],
      data['animation_serial'],
      data['tap_serial'],
      data['send_serial'],
      data['combo_count'],
      data['comboCount'],
      data['combo_total'],
    ]).isNotEmpty;
  }

  void _registerPendingLocalEcho(Map<String, dynamic> data) {
    final String fingerprint = _luckyEchoFingerprint(data);
    if (fingerprint.isEmpty) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<int> pending = _pendingLuckyLocalEchoes.putIfAbsent(
      fingerprint,
          () => <int>[],
    );
    pending.removeWhere((int time) => now - time > 3500);
    pending.add(now);
    if (pending.length > 40) {
      pending.removeRange(0, pending.length - 40);
    }
  }

  bool _consumePendingLocalEcho(Map<String, dynamic> data) {
    final String action = (data['action_type'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (!action.contains('gift_sent') && action != 'gift') return false;
    if (_hasPhysicalTapSerial(data)) return false;

    final String fingerprint = _luckyEchoFingerprint(data);
    if (fingerprint.isEmpty) return false;
    final List<int>? pending = _pendingLuckyLocalEchoes[fingerprint];
    if (pending == null || pending.isEmpty) return false;

    final int now = DateTime.now().millisecondsSinceEpoch;
    pending.removeWhere((int time) => now - time > 3500);
    if (pending.isEmpty) {
      _pendingLuckyLocalEchoes.remove(fingerprint);
      return false;
    }

    pending.removeAt(0);
    if (pending.isEmpty) _pendingLuckyLocalEchoes.remove(fingerprint);
    return true;
  }

  /// Stable identity for one real button tap.
  /// Receiver lists are intentionally NOT included: the same tap can be
  /// normalized with a slightly different receiver order by API/WebSocket.
  String _physicalLuckyTapKeyFromMap(Map<String, dynamic> data) {
    final Map<String, dynamic> gift = _mapOf(data['gift']).isNotEmpty
        ? _mapOf(data['gift'])
        : _mapOf(data['gift_data']);

    final String stream = _firstNonEmpty(<dynamic>[
      data['livestream_id'],
      data['stream_id'],
      data['live_id'],
    ]);
    final String sender = _firstNonEmpty(<dynamic>[
      data['sender_id'],
      data['user_id'],
      _mapOf(data['sender'])['id'],
      _mapOf(data['sender'])['user_id'],
    ]);
    final String giftId = _firstNonEmpty(<dynamic>[
      data['gift_id'],
      data['gift_list_id'],
      gift['id'],
      gift['gift_id'],
    ]);

    // A confirmed result is only for WIN/times UI. It must never launch a
    // second physical gift image after gift_sent/optimistic animation, even if
    // the normalized result still carries an animation serial.
    if (_isLuckyResultOnlyPayload(data)) return '';

    // The app-generated serial is the best identity and survives normal data
    // merges. One tap has one serial even when there are many receivers.
    final String serial = _firstNonEmpty(<dynamic>[
      data['gift_animation_serial'],
      data['animation_queue_serial'],
      data['animation_serial'],
      data['tap_serial'],
      data['send_serial'],
      data['combo_count'],
      data['comboCount'],
      data['combo_total'],
    ]);
    if (serial.isNotEmpty) {
      return 'tap|$stream|$sender|$giftId|$serial';
    }

    final String action = (data['action_type'] ?? data['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String eventId = _firstNonEmpty(<dynamic>[
      data['gift_event_id'],
      data['gift_send_id'],
      data['gift_transaction_id'],
      data['transaction_id'],
      data['event_id'],
    ]);

    if (eventId.isNotEmpty &&
        (data['optimistic_local'] == true ||
            action.contains('gift_sent') ||
            action == 'gift')) {
      return 'send|$stream|$sender|$giftId|$eventId';
    }

    // Last fallback for older payloads. Modern fast Combo payloads already
    // carry event_id or animation serial, so separate rapid taps remain unique.
    final String timestamp = _firstNonEmpty(<dynamic>[data['timestamp']]);
    if (timestamp.isEmpty) return '';
    return 'fallback|$stream|$sender|$giftId|$timestamp';
  }

  bool _reserveLuckyTapLaunch(String tapKey) {
    if (tapKey.isEmpty) return false;
    final int now = DateTime.now().millisecondsSinceEpoch;

    _recentLuckyTapLaunches.removeWhere(
          (_, int createdAt) => now - createdAt > 30000,
    );

    if (_recentLuckyTapLaunches.containsKey(tapKey)) return false;
    _recentLuckyTapLaunches[tapKey] = now;

    if (_recentLuckyTapLaunches.length > 400) {
      final List<MapEntry<String, int>> entries =
      _recentLuckyTapLaunches.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in entries.take(_recentLuckyTapLaunches.length - 320)) {
        _recentLuckyTapLaunches.remove(entry.key);
      }
    }
    return true;
  }

  void _scheduleIndependentLuckyFlight([
    Map<String, dynamic>? sourceData,
  ]) {
    final Map<String, dynamic> snapshot = Map<String, dynamic>.from(
      sourceData ?? _rootGiftData,
    );
    // A sender-side gift_sent echo is not a new tap. Consume one local token
    // and stop before creating a second flight request.
    if (_consumePendingLocalEcho(snapshot)) return;

    final String tapKey = _physicalLuckyTapKeyFromMap(snapshot);

    // Reserve before the post-frame delay. This blocks two callbacks scheduled
    // by initState + didUpdateWidget for the same physical tap.
    if (!_reserveLuckyTapLaunch(tapKey)) return;

    final String action = (snapshot['action_type'] ?? snapshot['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final bool looksLocal = snapshot['optimistic_local'] == true ||
        (_hasPhysicalTapSerial(snapshot) &&
            !action.contains('gift_sent') &&
            !_isLuckyResultOnlyPayload(snapshot));
    if (looksLocal) {
      _registerPendingLocalEcho(snapshot);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_isLuckyGift) return;

      Future<void>.delayed(const Duration(milliseconds: 18), () {
        if (!mounted || _isDisposed || !_isLuckyGift) return;
        _spawnIndependentLuckyFlight(tapKey: tapKey);
      });
    });
  }

  void _spawnIndependentLuckyFlight({required String tapKey}) {
    final String imageUrl = _luckyGiftUrl.trim();
    if (imageUrl.isEmpty || _isLuckyImageSvga || !mounted || _isDisposed) {
      return;
    }

    List<Offset> targets = _cachedLuckyReceiverTargets;
    if (targets.isEmpty) {
      targets = _receiverProfileTargetsForLucky();
      if (targets.isNotEmpty) {
        _cachedLuckyReceiverTargets = List<Offset>.unmodifiable(targets);
      }
    }

    final Size screen = MediaQuery.of(context).size;
    final Offset resolvedSenderSource = _cachedLuckySenderSource ??
        _senderProfileSourceForLucky() ??
        Offset(screen.width * .50, screen.height * .22);
    _cachedLuckySenderSource = resolvedSenderSource;

    final List<Offset> safeTargets = targets.isNotEmpty
        ? List<Offset>.unmodifiable(targets)
        : <Offset>[Offset(screen.width * .50, screen.height * .22)];

    if (_pendingLuckyFlightRequests.length >= 240) return;

    final int serial = ++_luckyFlightSerial;
    final List<String> receiverProfileUrls = List<String>.generate(
      safeTargets.length,
          (int index) => _receiverProfileUrlForIndex(index),
      growable: false,
    );

    // Exactly one request per physical tap. This one image travels from the
    // sender to the middle, then fans out to all selected receivers together.
    _pendingLuckyFlightRequests.add(
      _LuckyFlightRequest(
        tapKey: tapKey,
        serial: serial,
        imageUrl: imageUrl,
        screenSize: screen,
        senderSource: resolvedSenderSource,
        senderProfileUrl: _cardSenderProfileUrl,
        receiverTargets: safeTargets,
        receiverProfileUrls: receiverProfileUrls,
        multiplier: _resultMultiplier,
        winAmount: _resultWinAmount,
      ),
    );

    _ensureLuckyFlightLayer();
    _scheduleLuckyFlightFlush();
  }

  void _ensureLuckyFlightLayer() {
    if (!mounted || _isDisposed) return;

    // The queue layer is a permanent child of this widget. During the first
    // frame its State may not exist yet, so simply retry the lightweight flush
    // after layout instead of inserting/removing a root OverlayEntry.
    if (_luckyFlightLayerKey.currentState == null &&
        _pendingLuckyFlightRequests.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _scheduleLuckyFlightFlush();
        }
      });
    }
  }

  void _scheduleLuckyFlightFlush() {
    if (_luckyFlightFlushScheduled || _isDisposed) return;
    _luckyFlightFlushScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _luckyFlightFlushScheduled = false;
      if (_isDisposed) return;

      final _LuckyGiftFlightQueueLayerState? layer =
          _luckyFlightLayerKey.currentState;

      if (layer == null) {
        if (_pendingLuckyFlightRequests.isNotEmpty) {
          _ensureLuckyFlightLayer();
          Future<void>.delayed(
            const Duration(milliseconds: 16),
            _scheduleLuckyFlightFlush,
          );
        }
        return;
      }

      if (_pendingLuckyFlightRequests.isEmpty) return;

      final List<_LuckyFlightRequest> batch =
      List<_LuckyFlightRequest>.from(_pendingLuckyFlightRequests);
      _pendingLuckyFlightRequests.clear();
      layer.enqueueAll(batch);
    });
  }

  void _pushLuckyResultToFlightLayer({
    required double multiplier,
    required int winAmount,
  }) {
    // Loss payloads can be normalized to 1x while winAmount is zero.
    // Never show a fake WIN circle for those payloads.
    if (_isDisposed || multiplier <= 0 || winAmount <= 0) return;

    _ensureLuckyFlightLayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !mounted) return;
      final Size size = MediaQuery.of(context).size;
      _luckyFlightLayerKey.currentState?.showResult(
        multiplier: multiplier,
        winAmount: winAmount,
        screenSize: size,
      );
    });
  }

  void _removeAllIndependentLuckyFlights() {
    _pendingLuckyFlightRequests.clear();
    _recentLuckyTapLaunches.clear();
    _pendingLuckyLocalEchoes.clear();
    _luckyFlightFlushScheduled = false;

    try {
      _luckyFlightLayerKey.currentState?.clearImmediately();
    } catch (_) {}
  }


  void _showGlobalLuckyResultBanner({
    required double multiplier,
    required int winAmount,
    required String resultKey,
  }) {
    if (multiplier < 5 || winAmount <= 0 || _isDisposed) return;
    if (_lastGlobalLuckyBannerKey == resultKey) return;
    _lastGlobalLuckyBannerKey = resultKey;

    final BuildContext overlayContext = Get.overlayContext ?? context;
    final OverlayState overlay = Overlay.of(overlayContext, rootOverlay: true);

    _globalLuckyResultBannerTimer?.cancel();
    try {
      _globalLuckyResultBannerEntry?.remove();
    } catch (_) {}
    _globalLuckyResultBannerEntry = null;

    final String senderName = _cardSenderName;
    final String senderImage = _cardSenderProfileUrl;
    final String giftImage = _cardLuckyGiftUrl;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (bannerContext) {
        return Positioned(
          top: MediaQuery.of(bannerContext).padding.top + 6,
          left: 7,
          right: 7,
          child: Material(
            color: Colors.transparent,
            child: _LuckyGlobalResultBanner(
              senderName: senderName,
              senderImage: senderImage,
              giftImage: giftImage,
              multiplier: multiplier,
              winAmount: winAmount,
              onClose: () {
                try {
                  entry.remove();
                } catch (_) {}
                if (identical(_globalLuckyResultBannerEntry, entry)) {
                  _globalLuckyResultBannerEntry = null;
                }
              },
            ),
          ),
        );
      },
    );

    _globalLuckyResultBannerEntry = entry;
    overlay.insert(entry);
    _globalLuckyResultBannerTimer = Timer(const Duration(seconds: 5), () {
      try {
        entry.remove();
      } catch (_) {}
      if (identical(_globalLuckyResultBannerEntry, entry)) {
        _globalLuckyResultBannerEntry = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _coinCounterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _luckyWinOrbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
    _currentLuckyAnimationKey = _isLuckyGift
        ? _physicalLuckyTapKeyFromMap(_rootGiftData)
        : _luckyAnimationKeyFromMap(_rootGiftData);

    if (_isLuckyGift) {
      _captureStableLuckyCardData(force: true);
      _scheduleLuckyQueueRelease();
    } else if (_hasNormalGiftMedia) {
      _restartNormalGiftSafetyTimer();
    } else {
      /// An incomplete optimistic payload must never occupy FIFO for seconds.
      /// Close it immediately and let the confirmed/next valid gift mount.
      Future.microtask(() {
        if (mounted && !_isDisposed) {
          _closeGiftAnimation();
        }
      });
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      // Agora already owns the live-room audio pipeline. Creating/stopping a
      // new AudioPlayer for every Lucky Combo tap caused OpenSLES contention
      // and native crashes on some devices. Normal/SVGA gifts keep their audio.
      if (mounted && !_isDisposed && !_isPlayingAudio && !_isLuckyGift) {
        _playGiftAudio();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_isLuckyGift) return;

      _syncLuckyResult();
      _scheduleLuckyReceiverTargetRefresh();
      _scheduleIndependentLuckyFlight(_rootGiftData);

      _restartLuckyGiftHideTimer();
    });
  }

  void _restartLuckyGiftHideTimer() {
    if (!_isLuckyGift || _isDisposed) return;

    _luckyGiftHideTimer?.cancel();

    // The flying image and the fixed result card have separate lifetimes.
    // Do not remove the card when a single flight finishes. Keep it until the
    // user stops tapping Combo for 7 seconds (or until a long batch finishes).
    final int holdMs = math.max(
      _luckyCardIdleHideMs,
      _luckyDuration.inMilliseconds + 450,
    ).toInt();

    _luckyGiftHideTimer = Timer(Duration(milliseconds: holdMs), () {
      if (mounted && !_isDisposed) {
        _closeGiftAnimation();
      }
    });
  }

  void _queueLuckyResultSyncIfNeeded() {
    if (!_isLuckyGift || _isDisposed || !_hasLuckyResultData) return;

    final multiplier = _resultMultiplier;
    final winAmount = _resultWinAmount;
    final root = _rootGiftData;
    final resultKey = '${root['lucky_result_serial'] ?? root['result_event_id'] ?? root['timestamp'] ?? ''}_${multiplier}_$winAmount';

    if (resultKey == _lastLuckyResultKey &&
        multiplier == _shownMultiplier &&
        winAmount == _shownWinAmount) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _syncLuckyResult();
      }
    });
  }

  String _cleanKeyPart(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return '';
    return text;
  }

  String _luckyAnimationKeyFromMap(Map<String, dynamic> data) {
    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    String firstKey(List<dynamic> values) {
      for (final value in values) {
        final part = _cleanKeyPart(value);
        if (part.isNotEmpty) return part;
      }
      return '';
    }

    final gift = asMap(data['gift']);
    final receiverIds = data['animation_receiver_ids'] ??
        data['receiver_ids_for_animation'] ??
        data['all_receiver_ids'] ??
        data['receiver_ids'] ??
        data['receivers'] ??
        data['receiver_id'];
    final receiverSeats = data['animation_receiver_seat_nos'] ??
        data['receiver_seats_for_animation'] ??
        data['receiver_seat_nos'] ??
        data['receiver_seat_no'] ??
        data['seat_no'];

    final String senderKey =
    _cleanKeyPart(data['sender_id'] ?? data['user_id']);
    final String giftKey = _cleanKeyPart(gift['id'] ?? gift['gift_id']);
    final String receiverKey = _cleanKeyPart(receiverIds);
    final String seatKey = _cleanKeyPart(receiverSeats);

    // Combo count is cumulative and changes exactly once per user tap. Use it
    // only as the animation serial, never as the number of flying images.
    final String comboSerial = firstKey(<dynamic>[
      data['combo_count'],
      data['comboCount'],
      data['combo_total'],
      data['combo'],
      data['tap_serial'],
      data['send_serial'],
    ]);

    if (comboSerial.isNotEmpty) {
      return 'combo|$senderKey|$giftKey|$comboSerial|$receiverKey|$seatKey';
    }

    final String eventSerial = firstKey(<dynamic>[
      data['gift_animation_serial'],
      data['animation_serial'],
      data['gift_event_id'],
      data['lucky_event_id'],
      data['event_id'],
    ]);

    if (eventSerial.isNotEmpty) {
      return 'event|$eventSerial|$senderKey|$giftKey|$receiverKey|$seatKey';
    }

    final String perTapQuantity = firstKey(<dynamic>[
      data['quantity'],
      data['qty'],
      data['gift_quantity'],
      data['gift_qty'],
      data['send_quantity'],
      data['selected_quantity'],
    ]);

    final String timestamp = _cleanKeyPart(data['timestamp']);
    return <String>[
      'fallback',
      timestamp,
      senderKey,
      giftKey,
      perTapQuantity,
      receiverKey,
      seatKey,
    ].where((part) => part.isNotEmpty).join('|');
  }

  void _resetLuckyResultUiForNewGift() {
    // Keep the previous visible values until the new result arrives. This makes
    // the sender card completely fixed; only Times and Coin switch smoothly.
    _lastLuckyResultKey = '';
    _lastBigWinSoundKey = '';
    _coinCounterController.stop();
    _coinCounterAnimation = AlwaysStoppedAnimation<int>(_shownWinAmount);
  }

  void _restartLuckyVisualAnimationForNewGift() {
    if (!_isLuckyGift || _isDisposed) return;

    _luckyRunToken++;
    _isClosing = false;
    _luckyGiftHideTimer?.cancel();
    _lastReceiverTargetLogKey = '';
    _resetLuckyResultUiForNewGift();

    _captureStableLuckyCardData();
    _scheduleLuckyReceiverTargetRefresh();
    _scheduleIndependentLuckyFlight(_rootGiftData);
    _scheduleLuckyQueueRelease();

    // Never restart the full overlay fade for every Combo tap. The card stays
    // in exactly the same position while the flying gift restarts once.
    if (_controller.value < 1.0 && !_controller.isAnimating) {
      _controller.forward();
    }
    _loadLuckyParticleImage();
    _restartLuckyGiftHideTimer();

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant GiftAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldData = oldWidget.giftData is Map
        ? Map<String, dynamic>.from(oldWidget.giftData as Map)
        : <String, dynamic>{};
    final newData = widget.giftData is Map
        ? Map<String, dynamic>.from(widget.giftData as Map)
        : <String, dynamic>{};

    final bool currentIsLucky = _isLuckyGift;
    final oldAnimationKey = currentIsLucky
        ? _physicalLuckyTapKeyFromMap(oldData)
        : _luckyAnimationKeyFromMap(oldData);
    final newAnimationKey = currentIsLucky
        ? _physicalLuckyTapKeyFromMap(newData)
        : _luckyAnimationKeyFromMap(newData);

    final bool newGiftArrived = newAnimationKey.isNotEmpty &&
        newAnimationKey != oldAnimationKey &&
        newAnimationKey != _currentLuckyAnimationKey;

    if (newGiftArrived) {
      _currentLuckyAnimationKey = newAnimationKey;
      _isClosing = false;

      if (_isLuckyGift) {
        // Lucky/Combo uses one persistent card. A tap restarts only the single
        // gift flight; avatar, name and card position never rebuild/fade away.
        _captureStableLuckyCardData();
        _restartLuckyVisualAnimationForNewGift();
      } else {
        // Invalidate an older close/reverse callback before mounting the next
        // FIFO item. Repeated sends of the same SVGA URL are distinct taps.
        _luckyRunToken++;
        _normalGiftSafetyTimer?.cancel();
        _isClosing = false;

        if (!_hasNormalGiftMedia) {
          Future.microtask(() {
            if (mounted && !_isDisposed) {
              _closeGiftAnimation();
            }
          });
          return;
        }

        _controller
          ..reset()
          ..forward();

        _restartNormalGiftSafetyTimer();

        // Normal gift must also restart instantly when user sends again while
        // another gift widget is still mounted. Without this, the new gift can
        // wait until the old animation finishes and feels late.
        _isPlayingAudio = false;
        Future.microtask(() {
          if (mounted && !_isDisposed) {
            _precacheCurrentGiftMedia();
            _playGiftAudio();
          }
        });
      }
    }

    final oldKey = '${oldData['lucky_result_serial'] ?? oldData['result_event_id'] ?? ''}_${oldData['multiplier'] ?? ''}_${oldData['win_amount'] ?? oldData['back_coin'] ?? ''}';
    final newKey = '${newData['lucky_result_serial'] ?? newData['result_event_id'] ?? ''}_${newData['multiplier'] ?? ''}_${newData['win_amount'] ?? newData['back_coin'] ?? ''}';

    if (oldKey != newKey || newGiftArrived) {
      _syncLuckyResult();
      _restartLuckyGiftHideTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadLuckyParticleImage();
    _precacheCurrentGiftMedia();

    /// Preload the local Lucky Times frame once so 10x/15x result appears
    /// immediately without a first-use image decode pause.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      try {
        precacheImage(
          const AssetImage('assets/new/luckytime.png'),
          context,
        );
      } catch (_) {}
    });
  }

  void _precacheCurrentGiftMedia() {
    final String mediaUrl = (_isLuckyGift ? _luckyGiftUrl : _giftUrl).trim();
    if (mediaUrl.isEmpty || mediaUrl.toLowerCase().endsWith('.svga')) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      try {
        precacheImage(CachedNetworkImageProvider(mediaUrl), context);
      } catch (_) {}
    });
  }

  void _disposeLuckyParticleImageStreamOnly() {
    final ImageStream? particleStream = _luckyParticleImageStream;
    final ImageStreamListener? particleListener = _luckyParticleImageListener;
    if (particleStream != null && particleListener != null) {
      particleStream.removeListener(particleListener);
    }
    _luckyParticleImageStream = null;
    _luckyParticleImageListener = null;
  }

  void _loadLuckyParticleImage() {
    final String imageUrl = _luckyGiftUrl.trim();

    if (!_isLuckyGift ||
        _isLuckyImageSvga ||
        imageUrl.isEmpty) {
      return;
    }

    if (_luckyParticleImageRequested && _luckyParticleImageUrl == imageUrl) {
      return;
    }

    _disposeLuckyParticleImageStreamOnly();
    _luckyParticleImageRequested = true;
    _luckyParticleImageUrl = imageUrl;
    _luckyParticleImage = null;

    final ImageStream stream = CachedNetworkImageProvider(imageUrl).resolve(
      createLocalImageConfiguration(context),
    );

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
          (ImageInfo imageInfo, bool synchronousCall) {
        if (!mounted || _isDisposed || _luckyParticleImageUrl != imageUrl) return;

        setState(() {
          _luckyParticleImage = imageInfo.image;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        debugPrint('Lucky particle image load failed: $error');
        _luckyParticleImageRequested = false;
      },
    );

    _luckyParticleImageStream = stream;
    _luckyParticleImageListener = listener;
    stream.addListener(listener);
  }

  dynamic get _gift {
    try {
      return widget.giftData['gift'];
    } catch (_) {
      return {};
    }
  }

  String get _giftImage {
    try {
      return (_gift['gift_image'] ??
          _gift['image'] ??
          _gift['show_image'] ??
          '')
          .toString();
    } catch (_) {
      return '';
    }
  }

  String get _luckyGiftImage {
    try {
      return (_gift['show_image'] ??
          _gift['image'] ??
          _gift['thumbnail'] ??
          _gift['icon'] ??
          _gift['gift_image'] ??
          '')
          .toString();
    } catch (_) {
      return '';
    }
  }

  String get _giftUrl => ImageHelper.getImageUrl(_giftImage);

  String get _luckyGiftUrl => ImageHelper.getImageUrl(_luckyGiftImage);

  bool get _hasNormalGiftMedia {
    final String url = _giftUrl.trim();
    return url.isNotEmpty &&
        url.toLowerCase() != 'null' &&
        url != 'file:///';
  }

  bool get _isSvga => _giftImage.toLowerCase().endsWith('.svga');

  bool get _isLuckyImageSvga =>
      _luckyGiftImage.toLowerCase().endsWith('.svga');

  bool get _isLuckyGift {
    try {
      final dynamic gift = _gift;
      final dynamic root = widget.giftData;

      String value(dynamic data) {
        if (data == null) return '';
        return data.toString().trim().toLowerCase();
      }

      bool isTrue(dynamic data) {
        final v = value(data);
        return data == true ||
            v == '1' ||
            v == 'true' ||
            v == 'yes' ||
            v == 'lucky';
      }

      bool hasUsefulValue(dynamic data) {
        final v = value(data);
        return v.isNotEmpty &&
            v != 'null' &&
            v != '0' &&
            v != '0.0' &&
            v != 'false';
      }

      dynamic rootValue(String key) => root is Map ? root[key] : null;

      final String giftCategory = value(
        gift['category'] ??
            gift['gift_category'] ??
            gift['type'] ??
            gift['gift_type'],
      );

      final String rootCategory = value(
        rootValue('category') ??
            rootValue('gift_category') ??
            rootValue('gift_type') ??
            rootValue('type') ??
            rootValue('action_type'),
      );

      final String giftName = value(gift['name'] ?? gift['gift_name']);

      return giftCategory.contains('lucky') ||
          rootCategory.contains('lucky') ||
          giftName.contains('lucky') ||
          isTrue(gift['is_lucky']) ||
          isTrue(gift['is_lucky_gift']) ||
          isTrue(gift['lucky']) ||
          isTrue(rootValue('is_lucky')) ||
          isTrue(rootValue('is_lucky_gift')) ||
          isTrue(rootValue('lucky')) ||
          hasUsefulValue(gift['lucky_ratio']) ||
          hasUsefulValue(gift['lucky_coin']) ||
          hasUsefulValue(gift['back_coin']) ||
          hasUsefulValue(rootValue('lucky_ratio')) ||
          hasUsefulValue(rootValue('lucky_coin')) ||
          hasUsefulValue(rootValue('back_coin')) ||
          rootValue('lucky_result') is Map ||
          rootValue('lucky_results') is List;
    } catch (_) {
      return false;
    }
  }

  bool get _hasExternalAudio {
    try {
      final audioPath = _gift['audio'];
      return audioPath != null &&
          audioPath.toString().trim().isNotEmpty &&
          _isPlayableAudioUrl(audioPath.toString().trim());
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> get _rootGiftData {
    try {
      if (widget.giftData is Map<String, dynamic>) {
        return Map<String, dynamic>.from(widget.giftData);
      }
      if (widget.giftData is Map) {
        return Map<String, dynamic>.from(widget.giftData as Map);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Map<String, dynamic> get _senderMap {
    final root = _rootGiftData;
    for (final raw in <dynamic>[
      root['sender'],
      root['user'],
      root['sender_user'],
      root['from_user'],
    ]) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  String get _senderName {
    final sender = _senderMap;
    final text = (sender['name'] ??
        sender['username'] ??
        _rootGiftData['sender_name'] ??
        'User')
        .toString()
        .trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? 'User' : text;
  }

  String get _senderProfileUrl {
    final sender = _senderMap;
    final raw = (sender['profile_image'] ??
        sender['avatar'] ??
        sender['image'] ??
        sender['photo'] ??
        _rootGiftData['sender_profile_image'] ??
        '')
        .toString()
        .trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    return ImageHelper.getImageUrl(raw);
  }

  String _receiverProfileUrlForIndex(int index) {
    final root = _rootGiftData;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    Map<String, dynamic> receiver = <String, dynamic>{};
    final dynamic receiversRaw =
        root['receivers'] ??
            root['selected_receivers'] ??
            root['receiver_users'] ??
            root['to_users'];

    if (receiversRaw is List && receiversRaw.isNotEmpty) {
      final int safeIndex = index.clamp(0, receiversRaw.length - 1).toInt();
      receiver = asMap(receiversRaw[safeIndex]);
      if (receiver['user'] is Map) {
        receiver = <String, dynamic>{
          ...receiver,
          ...asMap(receiver['user']),
        };
      }
    }

    if (receiver.isEmpty) {
      receiver = asMap(
        root['receiver'] ??
            root['receiver_user'] ??
            root['to_user'] ??
            root['target_user'] ??
            root['host'] ??
            root['broadcaster'],
      );
      if (receiver['user'] is Map) {
        receiver = <String, dynamic>{
          ...receiver,
          ...asMap(receiver['user']),
        };
      }
    }

    final String raw = (
        receiver['profile_image_url'] ??
            receiver['profile_image'] ??
            receiver['avatar'] ??
            receiver['image_url'] ??
            receiver['image'] ??
            receiver['photo'] ??
            root['receiver_profile_image'] ??
            root['to_user_profile_image'] ??
            ''
    ).toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  int get _senderId {
    final sender = _senderMap;
    return _asInt(
      sender['id'] ??
          sender['user_id'] ??
          _rootGiftData['sender_id'] ??
          _rootGiftData['user_id'],
    );
  }

  void _captureStableLuckyCardData({bool force = false}) {
    final int incomingSenderId = _senderId;
    final bool senderChanged = incomingSenderId > 0 &&
        _stableLuckySenderId > 0 &&
        incomingSenderId != _stableLuckySenderId;
    final bool replaceAll = force || senderChanged || _stableLuckySenderName.isEmpty;

    final String incomingName = _senderName.trim();
    final String incomingProfile = _senderProfileUrl.trim();
    final String incomingGift = _luckyGiftUrl.trim();

    if (replaceAll) {
      if (incomingSenderId > 0) _stableLuckySenderId = incomingSenderId;
      if (incomingName.isNotEmpty && incomingName != 'User') {
        _stableLuckySenderName = incomingName;
      }
      if (incomingProfile.isNotEmpty) {
        _stableLuckySenderProfileUrl = incomingProfile;
      }
      if (incomingGift.isNotEmpty) {
        _stableLuckyGiftUrl = incomingGift;
      }
      return;
    }

    if (_stableLuckySenderId == 0 && incomingSenderId > 0) {
      _stableLuckySenderId = incomingSenderId;
    }
    if (_stableLuckySenderName.isEmpty && incomingName.isNotEmpty) {
      _stableLuckySenderName = incomingName;
    }
    if (_stableLuckySenderProfileUrl.isEmpty && incomingProfile.isNotEmpty) {
      _stableLuckySenderProfileUrl = incomingProfile;
    }
    if (_stableLuckyGiftUrl.isEmpty && incomingGift.isNotEmpty) {
      _stableLuckyGiftUrl = incomingGift;
    }
  }

  String get _cardSenderName =>
      _stableLuckySenderName.isNotEmpty ? _stableLuckySenderName : _senderName;

  String get _cardSenderProfileUrl => _stableLuckySenderProfileUrl.isNotEmpty
      ? _stableLuckySenderProfileUrl
      : _senderProfileUrl;

  String get _cardLuckyGiftUrl =>
      _stableLuckyGiftUrl.isNotEmpty ? _stableLuckyGiftUrl : _luckyGiftUrl;

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<int> _intListFromAny(dynamic value) {
    final ids = <int>[];
    final seen = <int>{};

    void add(dynamic raw) {
      if (raw == null) return;

      if (raw is Iterable) {
        for (final item in raw) {
          add(item);
        }
        return;
      }

      if (raw is Map) {
        for (final key in [
          'id',
          'user_id',
          'caller_id',
          'viewer_id',
          'receiver_id',
          'receiver_user_id',
          'target_user_id',
          'to_user_id',
        ]) {
          add(raw[key]);
        }
        return;
      }

      final text = raw.toString().trim();
      if (text.isEmpty || text == 'null') return;

      if (text.contains(',')) {
        for (final part in text.split(',')) {
          add(part);
        }
        return;
      }

      final id = _asInt(text);
      if (id > 0 && seen.add(id)) ids.add(id);
    }

    add(value);
    return ids;
  }

  List<int> _seatListFromAny(dynamic value) {
    final seats = <int>[];
    final seen = <int>{};

    void add(dynamic raw) {
      if (raw == null) return;

      if (raw is Iterable) {
        for (final item in raw) {
          add(item);
        }
        return;
      }

      if (raw is Map) {
        for (final key in [
          'seat_no',
          'seat',
          'seat_number',
          'receiver_seat',
          'receiver_seat_no',
          'receiver_seat_number',
          'to_seat',
          'to_seat_no',
        ]) {
          add(raw[key]);
        }
        return;
      }

      final text = raw.toString().trim();
      if (text.isEmpty || text == 'null') return;

      if (text.contains(',')) {
        for (final part in text.split(',')) {
          add(part);
        }
        return;
      }

      final seat = _asInt(text);
      if (seat > 0 && seen.add(seat)) seats.add(seat);
    }

    add(value);
    return seats;
  }

  List<int> get _receiverUserIds {
    final root = _rootGiftData;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final receiver = asMap(root['receiver']);
    final toUser = asMap(root['to_user']);
    final targetUser = asMap(root['target_user']);

    final ids = <int>[];
    final seen = <int>{};

    void addAll(dynamic value) {
      for (final id in _intListFromAny(value)) {
        if (id > 0 && seen.add(id)) ids.add(id);
      }
    }

    // Multi receiver list must come first. Otherwise only the last/single
    // receiver_id was being selected and self receiver was missed.
    addAll(root['receivers']);
    addAll(root['receiver_ids']);
    addAll(root['receiverIds']);
    addAll(root['receiver_id_list']);
    addAll(root['receiver_ids_for_animation']);
    addAll(root['animation_receiver_ids']);
    addAll(root['lucky_receiver_ids']);
    addAll(root['all_receiver_ids']);
    addAll(root['receiver_user_ids']);
    addAll(root['to_user_ids']);
    addAll(root['target_user_ids']);
    addAll(root['selected_receiver_ids']);
    addAll(root['selected_receivers']);

    addAll(root['receiver_id']);
    addAll(root['receiver_user_id']);
    addAll(root['to_user_id']);
    addAll(root['target_user_id']);
    addAll(root['gift_receiver_id']);
    addAll(receiver);
    addAll(toUser);
    addAll(targetUser);

    return ids;
  }

  int get _receiverUserId => _receiverUserIds.isNotEmpty ? _receiverUserIds.first : 0;

  List<int> get _receiverSeatNos {
    final root = _rootGiftData;

    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final receiver = asMap(root['receiver']);
    final toUser = asMap(root['to_user']);
    final targetUser = asMap(root['target_user']);
    final sender = asMap(root['sender']);
    final user = asMap(root['user']);

    final seats = <int>[];
    final seen = <int>{};

    void addAll(dynamic value) {
      for (final seat in _seatListFromAny(value)) {
        if (seat > 0 && seen.add(seat)) seats.add(seat);
      }
    }

    addAll(root['receiver_seats']);
    addAll(root['receiver_seat_nos']);
    addAll(root['receiver_seat_numbers']);
    addAll(root['animation_receiver_seats']);
    addAll(root['animation_receiver_seat_nos']);
    addAll(root['receiver_seats_for_animation']);
    addAll(root['to_seats']);
    addAll(root['to_seat_nos']);
    addAll(root['selected_receiver_seats']);

    addAll(root['receiver_seat']);
    addAll(root['receiver_seat_no']);
    addAll(root['receiver_seat_number']);
    addAll(root['to_seat']);
    addAll(root['to_seat_no']);
    addAll(root['seat_no']);
    addAll(root['seat']);
    addAll(receiver);
    addAll(toUser);
    addAll(targetUser);

    // Self-gift fallback: many payloads do not include receiver seat,
    // but may include sender/from/current seat. Add it only when receiver
    // and sender are the same user.
    final int senderId = _asInt(root['sender_id'] ?? root['user_id'] ?? sender['id'] ?? sender['user_id'] ?? user['id'] ?? user['user_id']);
    if (senderId > 0 && _receiverUserIds.contains(senderId)) {
      addAll(root['sender_seat']);
      addAll(root['sender_seat_no']);
      addAll(root['sender_seat_number']);
      addAll(root['from_seat']);
      addAll(root['from_seat_no']);
      addAll(sender);
      addAll(user);
    }

    return seats;
  }

  int get _receiverSeatNo => _receiverSeatNos.isNotEmpty ? _receiverSeatNos.first : 0;

  List<int> get _senderSeatNos {
    final root = _rootGiftData;
    final sender = _senderMap;
    final user = root['user'] is Map
        ? Map<String, dynamic>.from(root['user'] as Map)
        : <String, dynamic>{};

    final seats = <int>[];
    final seen = <int>{};

    void addAll(dynamic value) {
      for (final seat in _seatListFromAny(value)) {
        if (seat > 0 && seen.add(seat)) seats.add(seat);
      }
    }

    addAll(root['sender_seats']);
    addAll(root['sender_seat_nos']);
    addAll(root['sender_seat_numbers']);
    addAll(root['sender_seat']);
    addAll(root['sender_seat_no']);
    addAll(root['sender_seat_number']);
    addAll(root['from_seat']);
    addAll(root['from_seat_no']);
    addAll(root['from_seat_number']);
    addAll(sender);
    addAll(user);

    return seats;
  }

  Offset _fallbackAudioSeatPosition(int seatNo, Size size) {
    final Map<int, Offset> fixed = <int, Offset>{
      1: Offset(size.width * .50, size.height * .20),
      2: Offset(size.width * .11, size.height * .46),
      3: Offset(size.width * .37, size.height * .46),
      4: Offset(size.width * .63, size.height * .46),
      5: Offset(size.width * .89, size.height * .46),
      6: Offset(size.width * .11, size.height * .73),
      7: Offset(size.width * .37, size.height * .73),
      8: Offset(size.width * .63, size.height * .73),
      9: Offset(size.width * .89, size.height * .73),
    };

    final Offset? exact = fixed[seatNo];
    if (exact != null) return exact;

    final int index = ((seatNo - 1).clamp(0, 19) as num).toInt();
    final int col = index % 5;
    final int row = index ~/ 5;
    return Offset(
      size.width * (.10 + (col * .20)),
      size.height * (.20 + (row * .18)),
    );
  }

  Offset? _senderProfileSourceForLucky() {
    try {
      final int senderId = _senderId;
      if (senderId > 0) {
        final Offset? byUser =
        LiveViewCircle_container.luckyProfileCenterForUser(
          userId: senderId,
          relativeTo: context,
        );
        if (byUser != null) return byUser;
      }

      for (final int seatNo in _senderSeatNos) {
        final Offset? bySeat =
        LiveViewCircle_container.luckyProfileCenterForSeat(
          seatNo: seatNo,
          relativeTo: context,
        );
        if (bySeat != null) return bySeat;
      }

      if (_senderSeatNos.isNotEmpty) {
        return _fallbackAudioSeatPosition(
          _senderSeatNos.first,
          MediaQuery.of(context).size,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Lucky sender profile source error: $e');
    }
    return null;
  }


  List<Offset> _receiverProfileTargetsForLucky() {
    try {
      final userIds = _receiverUserIds;
      final seatNos = _receiverSeatNos;
      final targets = <Offset>[];
      final targetKeys = <String>{};

      void addTarget(Offset? target) {
        if (target == null) return;
        final key = '${target.dx.toStringAsFixed(1)}_${target.dy.toStringAsFixed(1)}';
        if (targetKeys.add(key)) targets.add(target);
      }

      final List<Offset> cachedTargets =
      LiveViewCircle_container.luckyProfileCentersForTargets(
        userIds: userIds,
        seatNos: seatNos,
        relativeTo: context,
      );
      for (final Offset target in cachedTargets) {
        addTarget(target);
      }

      /// Audience-side fallback: sometimes the result websocket arrives before
      /// every receiver BuildContext is registered on late audience devices.
      /// If ids/seats are present but target context is still missing, use a
      /// light approximate audio-seat position so the animation is still visible
      /// going toward the correct seat area instead of disappearing.
      if (targets.isEmpty && seatNos.isNotEmpty) {
        final Size size = MediaQuery.of(context).size;
        for (final int seatNo in seatNos) {
          addTarget(_fallbackAudioSeatPosition(seatNo, size));
        }
      }

      final String logKey =
          '${userIds.join(',')}_${seatNos.join(',')}_${targets.length}';
      if (_lastReceiverTargetLogKey != logKey) {
        _lastReceiverTargetLogKey = logKey;
        // Target debug output intentionally disabled in production. Printing
        // large receiver lists during Combo animation blocks the UI thread.
      }

      return targets;
    } catch (e) {
      debugPrint('⚠️ Lucky receiver targets error: $e');
      return const <Offset>[];
    }
  }

  Offset? _receiverProfileTargetForLucky() {
    final targets = _receiverProfileTargetsForLucky();
    return targets.isEmpty ? null : targets.first;
  }

  double get _resultMultiplier {
    final root = _rootGiftData;
    final result = root['lucky_result'] is Map
        ? Map<String, dynamic>.from(root['lucky_result'] as Map)
        : <String, dynamic>{};

    return _asDouble(
      root['multiplier'] ??
          root['multiple'] ??
          root['gun'] ??
          root['x'] ??
          result['multiplier'] ??
          result['multiple'] ??
          result['gun'] ??
          result['x'],
    );
  }

  int get _resultWinAmount {
    final root = _rootGiftData;
    final result = root['lucky_result'] is Map
        ? Map<String, dynamic>.from(root['lucky_result'] as Map)
        : <String, dynamic>{};

    return _asInt(
      root['win_amount'] ??
          root['back_coin'] ??
          root['win_coin'] ??
          root['bonus_coin'] ??
          result['win_amount'] ??
          result['back_coin'] ??
          result['win_coin'] ??
          result['bonus_coin'],
    );
  }

  bool get _hasLuckyResultData {
    final root = _rootGiftData;
    final result = root['lucky_result'] is Map
        ? Map<String, dynamic>.from(root['lucky_result'] as Map)
        : <String, dynamic>{};

    return root['lucky_result_serial'] != null ||
        root['result_event_id'] != null ||
        root['win_amount'] != null ||
        root['back_coin'] != null ||
        root['win_coin'] != null ||
        root['multiplier'] != null ||
        root['multiple'] != null ||
        root['gun'] != null ||
        result.isNotEmpty;
  }

  double get _displayMultiplier {
    final liveMultiplier = _resultMultiplier;
    if (liveMultiplier > 0) return liveMultiplier;
    if (_shownMultiplier > 0) return _shownMultiplier;
    if (_hasLuckyResultData) return 1;
    return 0;
  }

  int get _displayCoinBack {
    final liveAmount = _resultWinAmount;

    if (_coinCounterController.isAnimating) {
      return _coinCounterAnimation.value;
    }
    if (_shownWinAmount > 0) return _shownWinAmount;
    return liveAmount;
  }

  String _formatTimes(double multiplier) {
    if (multiplier <= 0) return '';
    final String number = multiplier % 1 == 0
        ? multiplier.toInt().toString()
        : multiplier.toStringAsFixed(1);
    return multiplier == 1 ? '$number Time' : '$number Times';
  }

  String _formatTimesNumber(double multiplier) {
    if (multiplier <= 0) return '';
    if (multiplier % 1 == 0) return '${multiplier.toInt()}';
    return multiplier.toStringAsFixed(1);
  }

  String _formatCoin(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _bigWinAudioPath() {
    final root = _rootGiftData;
    final gift = _gift is Map
        ? Map<String, dynamic>.from(_gift as Map)
        : <String, dynamic>{};
    final result = root['lucky_result'] is Map
        ? Map<String, dynamic>.from(root['lucky_result'] as Map)
        : <String, dynamic>{};

    final audio = root['big_win_audio'] ??
        root['lucky_big_win_audio'] ??
        root['top_card_audio'] ??
        root['jackpot_audio'] ??
        root['result_audio'] ??
        result['big_win_audio'] ??
        result['top_card_audio'] ??
        result['jackpot_audio'] ??
        gift['big_win_audio'] ??
        gift['lucky_big_win_audio'] ??
        gift['top_card_audio'] ??
        gift['jackpot_audio'];

    return audio?.toString().trim() ?? '';
  }

  bool _isBigLuckyTopCardResult(double multiplier, int winAmount) {
    final root = _rootGiftData;
    final result = root['lucky_result'] is Map
        ? Map<String, dynamic>.from(root['lucky_result'] as Map)
        : <String, dynamic>{};
    final winType = (root['win_type'] ?? result['win_type'] ?? '').toString().toLowerCase();

    return multiplier >= 50 ||
        winType.contains('big') ||
        winType.contains('jackpot') ||
        root['is_big_win'] == true ||
        root['is_jackpot'] == true ||
        result['is_big_win'] == true ||
        result['is_jackpot'] == true;
  }

  Future<void> _playLuckyBigWinSound() async {
    if (_isDisposed) return;

    try {
      _bigWinAudioPlayer ??= AudioPlayer();
      await _bigWinAudioPlayer!.stop();
      await _bigWinAudioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _bigWinAudioPlayer!.setVolume(1.0);

      // User-selected local asset for 50 Times / 100 Times top-card sound.
      // pubspec.yaml must include:
      // assets:
      //   - assets/audio_live/freesound_community-coin-dropped-81172.mp3
      await _bigWinAudioPlayer!.play(
        AssetSource('audio_live/freesound_community-coin-dropped-81172.mp3'),
      );
    } catch (e) {
      debugPrint('⚠️ Lucky big win asset sound skipped: $e');
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void _playBigWinTopCardSoundIfNeeded({
    required double multiplier,
    required int winAmount,
    required String resultKey,
  }) {
    if (!_isBigLuckyTopCardResult(multiplier, winAmount)) return;
    if (_lastBigWinSoundKey == resultKey) return;

    _lastBigWinSoundKey = resultKey;
    Future.microtask(_playLuckyBigWinSound);
  }

  void _syncLuckyResult({bool animate = true}) {
    if (!_isLuckyGift || _isDisposed) return;

    final multiplier = _resultMultiplier;
    final winAmount = _resultWinAmount;
    final root = _rootGiftData;
    final resultKey = '${root['lucky_result_serial'] ?? root['result_event_id'] ?? root['timestamp'] ?? ''}_${multiplier}_$winAmount';

    if (resultKey == _lastLuckyResultKey &&
        multiplier == _shownMultiplier &&
        winAmount == _shownWinAmount) {
      return;
    }

    _lastLuckyResultKey = resultKey;
    _shownMultiplier = multiplier;
    _shownWinAmount = winAmount;
    _restartLuckyGiftHideTimer();
    _pushLuckyResultToFlightLayer(
      multiplier: multiplier,
      winAmount: winAmount,
    );
    // Heavy center win-circle disabled for smooth Combo performance.
    // The global 5x+ banner still shows from the root-level banner system.
    // App-wide 5x+ banner is emitted once by LivestreamController from
    // the confirmed API/WebSocket result. Keeping it out of this room widget
    // prevents duplicate banners when the same event is echoed to the sender.
    // Do not start a second audioplayers engine inside an active Agora room.
    // The visual WIN/global banner remains; avoiding per-result audio keeps the
    // microphone/playout pipeline stable during rapid Lucky gifts.

    _coinCounterController.stop();

    if (winAmount <= 0) {
      _coinCounterAnimation = const AlwaysStoppedAnimation<int>(0);
      if (mounted) setState(() {});
      return;
    }

    // No large room result card is rendered anymore, so do not spend frames
    // animating an invisible coin counter. Keep the latest value directly.
    _coinCounterAnimation = AlwaysStoppedAnimation<int>(winAmount);
    if (mounted) setState(() {});
  }


  void _restartLuckyWinOrbAnimation({required int winAmount}) {
    if (winAmount <= 0 || _isDisposed) return;
    try {
      _luckyWinOrbController.stop();
      _luckyWinOrbController.forward(from: 0);
    } catch (_) {}
  }

  bool get _hasVisibleLuckyWinOrb {
    if (_shownWinAmount <= 0) return false;
    final double value = _luckyWinOrbController.value;
    return _luckyWinOrbController.isAnimating || (value > 0 && value < 1);
  }

  bool _isPlayableAudioUrl(String rawPath) {
    final clean = rawPath.toLowerCase().split('?').first;
    return clean.endsWith('.mp3') ||
        clean.endsWith('.wav') ||
        clean.endsWith('.m4a') ||
        clean.endsWith('.aac') ||
        clean.endsWith('.ogg') ||
        clean.endsWith('.opus');
  }

  int _declaredGiftDurationMs({int fallback = 0}) {
    try {
      final dynamic millisecondValue =
          _gift['animation_duration_ms'] ?? _gift['duration_ms'];
      if (millisecondValue != null) {
        final int parsed =
            num.tryParse(millisecondValue.toString())?.round() ?? fallback;
        return parsed;
      }

      final dynamic genericValue = _gift['duration'];
      if (genericValue != null) {
        final num? parsed = num.tryParse(genericValue.toString());
        if (parsed == null) return fallback;

        // Generic duration values such as 5/7 normally mean seconds.
        if (parsed > 0 && parsed <= 60) {
          return (parsed * 1000).round();
        }
        return parsed.round();
      }
    } catch (_) {}
    return fallback;
  }

  int _getImageFallbackDurationMs() {
    final int declared = _declaredGiftDurationMs(fallback: 1600);
    return declared.clamp(900, 8000).toInt();
  }

  int _normalGiftSafetyDurationMs() {
    if (!_hasNormalGiftMedia) return 180;

    final int declared = _declaredGiftDurationMs(fallback: 0);

    if (_isSvga) {
      // onFinished normally advances immediately. This timer is only a deadlock
      // guard for a corrupted/network-failed player and never shortens a normal
      // valid animation.
      final int expected = declared > 0 ? declared + 3500 : 20000;
      return expected.clamp(8000, 60000).toInt();
    }

    return (_getImageFallbackDurationMs() + 1800).clamp(2500, 12000).toInt();
  }

  void _restartNormalGiftSafetyTimer() {
    if (_isLuckyGift || _isDisposed) return;

    _normalGiftSafetyTimer?.cancel();
    final int runToken = _luckyRunToken;
    _normalGiftSafetyTimer = Timer(
      Duration(milliseconds: _normalGiftSafetyDurationMs()),
          () {
        if (!mounted ||
            _isDisposed ||
            runToken != _luckyRunToken ||
            _isClosing) {
          return;
        }

        debugPrint(
          '⚠️ Normal gift safety finish => ${_normalAnimationInstanceKey}',
        );
        _closeGiftAnimation();
      },
    );
  }

  String get _normalAnimationInstanceKey {
    final Map<String, dynamic> root = _rootGiftData;
    return _firstNonEmpty(<dynamic>[
      root['client_event_id'],
      root['client_request_id'],
      root['gift_animation_serial'],
      root['animation_queue_serial'],
      root['animation_serial'],
      root['event_id'],
      root['source_event_id'],
      root['timestamp'],
      '${_giftUrl}_${root.hashCode}',
    ]);
  }

  List<_LuckyFountainParticle> _createLuckyParticles() {
    final random = math.Random(20260712);
    final particles = <_LuckyFountainParticle>[];
    final int totalCopies = _luckySendCount;
    final int totalDurationMs = math.max(1, _luckyDuration.inMilliseconds);
    final double lifeTime = _luckyFlightMs / totalDurationMs;

    for (int serial = 0; serial < totalCopies; serial++) {
      final double startTime =
          (_luckyStartDelayMs + (serial * _luckySerialGapMs)) /
              totalDurationMs;

      particles.add(
        _LuckyFountainParticle(
          startTime: startTime.clamp(0.0, .98).toDouble(),
          lifeTime: lifeTime.clamp(.02, 1.0).toDouble(),
          targetX: random.nextDouble(),
          targetY: random.nextDouble(),
          size: 76.0 + (random.nextDouble() * 8.0),
          archHeight: 0.0,
          bend: 0.0,
          sway: 0.18 + (random.nextDouble() * 0.22),
          phase: random.nextDouble() * math.pi * 2,
          rotation: -0.035 + (random.nextDouble() * 0.070),
          startOffsetX: ((serial % 3) - 1) * 4.0,
          startOffsetY: ((serial % 2) * 3.0) - 1.5,
          exitSpread: -0.018 + (random.nextDouble() * 0.036),
        ),
      );
    }

    return particles;
  }

  Future<void> _closeGiftAnimation() async {
    if (!mounted || _isDisposed || _isClosing) return;

    _normalGiftSafetyTimer?.cancel();
    _normalGiftSafetyTimer = null;
    _luckyGiftHideTimer?.cancel();
    _luckyGiftHideTimer = null;

    /// Lucky mode keeps the single horizontal result card mounted. Only the
    /// current flight finishes here; WebsocketController either mounts the next
    /// queued tap in the same widget or hides the card after 7 idle seconds.
    if (_isLuckyGift) {
      _isClosing = true;
      try {
        if (Get.isRegistered<WebsocketController>()) {
          Get.find<WebsocketController>().hideGiftAnimation();
        }
      } catch (e) {
        debugPrint('⚠️ Lucky flight finish skipped: $e');
      }
      return;
    }

    _isClosing = true;
    final int closeToken = _luckyRunToken;

    try {
      await _controller.reverse();
    } catch (_) {}

    // If another gift arrives while reverse animation is running, do not hide
    // the new animation.
    if (!mounted || _isDisposed || closeToken != _luckyRunToken || !_isClosing) {
      return;
    }

    try {
      if (Get.isRegistered<WebsocketController>()) {
        Get.find<WebsocketController>().hideGiftAnimation();
      }
    } catch (e) {
      debugPrint('⚠️ hideGiftAnimation skipped: $e');
    }
  }

  Future<void> _playGiftAudio() async {
    if (_isDisposed || _isPlayingAudio) {
      debugPrint('⚠️ Already playing or disposed');
      return;
    }

    _isPlayingAudio = true;

    try {
      final Map<String, dynamic> safeGift = _gift is Map
          ? Map<String, dynamic>.from(_gift as Map)
          : <String, dynamic>{};
      final audioPath = safeGift['audio'] ??
          safeGift['gift_audio'] ??
          safeGift['sound'] ??
          safeGift['audio_url'] ??
          safeGift['sound_url'] ??
          safeGift['gift_sound'];

      if (audioPath == null || audioPath.toString().trim().isEmpty) {
        _isPlayingAudio = false;
        return;
      }

      final String audioText = audioPath.toString().trim();
      if (!_isPlayableAudioUrl(audioText)) {
        debugPrint('⚠️ Invalid gift audio skipped: $audioText');
        _isPlayingAudio = false;
        return;
      }

      final String rawUrl = audioText.startsWith('http')
          ? audioText
          : '$kAudioUrl/$audioText';

      debugPrint('🔊 Gift audio URL: $rawUrl');

      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.release);
      await _audioPlayer!.setVolume(1.0);

      _audioPlayer!.onPlayerStateChanged.listen((PlayerState state) {
        debugPrint('🎵 Player State: $state');

        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _isPlayingAudio = false;
        }
      });

      await _audioPlayer!.play(UrlSource(rawUrl));
      debugPrint('✅ Gift audio play command executed');
    } catch (e, stack) {
      debugPrint('❌ Gift audio error: $e');
      debugPrint('📍 Stack: $stack');
      _isPlayingAudio = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isPlayingAudio = false;
    _luckyGiftHideTimer?.cancel();
    _luckyGiftHideTimer = null;
    _normalGiftSafetyTimer?.cancel();
    _normalGiftSafetyTimer = null;
    _luckyQueueReleaseTimer?.cancel();
    _luckyQueueReleaseTimer = null;

    _removeAllIndependentLuckyFlights();
    _disposeLuckyParticleImageStreamOnly();
    _luckyParticleImage = null;
    _luckyParticleImageUrl = '';

    final AudioPlayer? player = _audioPlayer;
    final AudioPlayer? bigWinPlayer = _bigWinAudioPlayer;
    _audioPlayer = null;
    _bigWinAudioPlayer = null;

    player?.stop().then((_) {
      player.dispose();
    });
    bigWinPlayer?.stop().then((_) {
      bigWinPlayer.dispose();
    });

    _luckyPulseController?.dispose();
    _luckyPulseController = null;
    _luckyWinOrbController.dispose();
    _coinCounterController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: IgnorePointer(
        ignoring: true,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              /// Permanent Lucky queue. This remains mounted even when
              /// isGiftAnimationShowing becomes false between Combo taps.
              Positioned.fill(
                child: RepaintBoundary(
                  child: _LuckyGiftFlightQueueLayer(
                    key: _luckyFlightLayerKey,
                    onQueueEmpty: () {},
                  ),
                ),
              ),

              /// Normal/SVGA gifts still respect the controller visibility.
              if (widget.isActive && !_isLuckyGift)
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: Center(
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: _buildNormalGiftContent(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuckyGiftSpreadScene(Size pageSize) {
    // Lucky flying gifts are rendered by the single root queue layer.
    // The old large bottom result card and heavy center WIN circle are removed
    // so repeated taps stay smooth and the receiver-side compact badge is clear.
    return const SizedBox.shrink();
  }

  Widget _buildLuckySerialFallback({
    required Size pageSize,
    required double timeline,
    required List<Offset> receiverTargets,
  }) {
    if (_luckyParticles.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Offset> targets = receiverTargets.isNotEmpty
        ? receiverTargets
        : <Offset>[
      Offset(
        pageSize.width / 2,
        pageSize.height * .30,
      ),
    ];

    final List<Widget> flyingGifts = <Widget>[];

    /// Lucky card-এর gift image position থেকে animation শুরু হবে।
    final Offset start =
    _GiftAnimationGeometry.cardGiftLaunchPoint(pageSize);

    for (
    int particleIndex = 0;
    particleIndex < _luckyParticles.length;
    particleIndex++
    ) {
      final _LuckyFountainParticle particle =
      _luckyParticles[particleIndex];

      if (timeline < particle.startTime) continue;

      final double progress =
      ((timeline - particle.startTime) / particle.lifeTime)
          .clamp(0.0, 1.0)
          .toDouble();

      if (progress >= 1.0) continue;

      final double eased =
      Curves.easeInOutCubic.transform(progress);

      for (
      int targetIndex = 0;
      targetIndex < targets.length;
      targetIndex++
      ) {
        final Offset rawTarget = targets[targetIndex];

        final Offset target = Offset(
          rawTarget.dx,
          (rawTarget.dy + _luckyProfileIntakeYOffset)
              .clamp(0.0, pageSize.height)
              .toDouble(),
        );

        final double x =
            ui.lerpDouble(start.dx, target.dx, eased) ??
                start.dx;

        final double targetCurve =
            ((targetIndex % 3) - 1) * 5.0;

        final double y =
            (ui.lerpDouble(start.dy, target.dy, eased) ??
                start.dy) -
                (math.sin(eased * math.pi) *
                    (22.0 + targetCurve.abs()));

        final double intake = progress > .68
            ? ((progress - .68) / .32)
            .clamp(0.0, 1.0)
            .toDouble()
            : 0.0;

        final double scale =
        (1.0 - (intake * .86))
            .clamp(.14, 1.0)
            .toDouble();

        final double opacity =
        (1.0 - intake)
            .clamp(0.0, 1.0)
            .toDouble();

        flyingGifts.add(
          Positioned(
            left: x - 40,
            top: y - 40,
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: CachedNetworkImage(
                    imageUrl: _luckyGiftUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholderFadeInDuration:
                    Duration.zero,
                    useOldImageOnUrlChange: true,
                    placeholder: (_, __) =>
                    const SizedBox.shrink(),
                    errorWidget: (_, __, ___) =>
                    const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (flyingGifts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: flyingGifts,
      ),
    );
  }


  Widget _buildLuckyWinOrb(Size pageSize) {
    if (!_hasVisibleLuckyWinOrb) return const SizedBox.shrink();

    final double multiplier = _displayMultiplier <= 0 ? 1 : _displayMultiplier;
    final int coin = _displayCoinBack;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _luckyWinOrbController,
          builder: (context, _) {
            final double t = _luckyWinOrbController.value.clamp(0.0, 1.0);
            final double appear = (t / .14).clamp(0.0, 1.0).toDouble();
            final double settle = Curves.easeOutBack.transform(appear);
            final double burst = t <= .72
                ? 0.0
                : ((t - .72) / .28).clamp(0.0, 1.0).toDouble();
            final double fadeOut = t <= .90
                ? 1.0
                : (1.0 - ((t - .90) / .10).clamp(0.0, 1.0)).toDouble();
            final double orbScale = (0.76 + (settle * .24) + (burst * .12))
                .clamp(.72, 1.18)
                .toDouble();
            final double orbOpacity = (appear * fadeOut).clamp(0.0, 1.0).toDouble();
            final double burstDistance = Curves.easeOut.transform(burst) * 120.0;
            final double shellOpacity = (1.0 - burst).clamp(0.0, 1.0) * orbOpacity;

            final List<Widget> burstCoins = <Widget>[];
            const List<double> angles = <double>[
              -1.15, -0.78, -0.42, -0.12, 0.18, 0.52, 0.84, 1.16,
            ];
            for (int i = 0; i < angles.length; i++) {
              final double a = angles[i];
              final double dx = math.cos(a) * burstDistance;
              final double dy = math.sin(a) * burstDistance - (burst * 26.0);
              burstCoins.add(
                Positioned(
                  left: (pageSize.width / 2) - 18 + dx,
                  top: (pageSize.height * .42) - 18 + dy,
                  child: Opacity(
                    opacity: (burst * (1.0 - burst) * 2.2).clamp(0.0, 1.0) * orbOpacity,
                    child: Transform.rotate(
                      angle: burst * math.pi * (i.isEven ? 1.0 : -1.0),
                      child: const Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xffffd451),
                        size: 30,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                ...burstCoins,
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -pageSize.height * .08),
                    child: Opacity(
                      opacity: orbOpacity,
                      child: Transform.scale(
                        scale: orbScale,
                        child: SizedBox(
                          width: 235,
                          height: 235,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffffc64d).withOpacity(.24 * shellOpacity),
                                      blurRadius: 42,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xffff7a00).withOpacity(.38 * shellOpacity),
                                      blurRadius: 36,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 188,
                                height: 188,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xffffef9a).withOpacity(.96 * shellOpacity),
                                    width: 5,
                                  ),
                                  gradient: const RadialGradient(
                                    center: Alignment(-.08, -.20),
                                    radius: 1.08,
                                    colors: [
                                      Color(0xfff29d52),
                                      Color(0xffbf4616),
                                      Color(0xff701105),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xffffdd68).withOpacity(.50 * shellOpacity),
                                      blurRadius: 24,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 202,
                                height: 202,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xffffcf55).withOpacity(.38 * shellOpacity),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'WIN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(color: Colors.black54, blurRadius: 6),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Color(0xffffd451),
                                    size: 26,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCoin(coin),
                                    style: const TextStyle(
                                      color: Color(0xfffff1c2),
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(color: Colors.black54, blurRadius: 5),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      color: Colors.black.withOpacity(.24),
                                      border: Border.all(
                                        color: const Color(0xffffd97d),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      'x${_formatTimesNumber(multiplier)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLuckyResultHud(Size pageSize, double timeline) {
    final double multiplier = _displayMultiplier;
    final int coin = _displayCoinBack;

    /// Do not show an empty 0-coin result card while the backend result is
    /// pending or when the tap did not return any coin.
    if (coin <= 0 || multiplier <= 0) {
      return const SizedBox.shrink();
    }

    // Show the sender card immediately on the first tap. It remains fixed
    // above the Combo panel even before the lucky result reaches the socket.
    final double cardWidth = (pageSize.width - 18).clamp(300.0, 540.0);
    const double cardHeight = _GiftAnimationGeometry.cardHeight;
    const double cardBottom = _GiftAnimationGeometry.cardBottom;
    final double cardLeft = (pageSize.width - cardWidth) / 2;
    final double cardTop = (pageSize.height - cardBottom - cardHeight)
        .clamp(8.0, pageSize.height - cardHeight - 8.0)
        .toDouble();

    return Positioned(
      left: cardLeft,
      top: cardTop,
      width: cardWidth,
      height: cardHeight,
      child: IgnorePointer(
        ignoring: true,
        child: RepaintBoundary(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xfff5be47),
                  Color(0xffd48710),
                  Color(0xffb35d06),
                ],
              ),
              border: Border.all(
                color: const Color(0xffffef9a),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 16,
                  offset: Offset(0, 7),
                ),
                BoxShadow(
                  color: Color(0x99FFB000),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(.24),
                          Colors.transparent,
                          Colors.black.withOpacity(.16),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 6),
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xfffff6b0), Color(0xffff8a00)],
                        ),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _cardSenderProfileUrl.isEmpty
                            ? Container(
                          color: const Color(0xff6f8b9b),
                          alignment: Alignment.center,
                          child: Text(
                            _cardSenderName.isEmpty
                                ? 'U'
                                : _cardSenderName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 25,
                            ),
                          ),
                        )
                            : CachedNetworkImage(
                          imageUrl: _cardSenderProfileUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          placeholder: (_, __) =>
                              Container(color: Colors.white12),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xff6f8b9b),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 4,
                      child: Text(
                        _cardSenderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: _cardLuckyGiftUrl.isEmpty
                          ? const Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xfffff0a4),
                        size: 36,
                      )
                          : CachedNetworkImage(
                        imageUrl: _cardLuckyGiftUrl,
                        fit: BoxFit.contain,
                        fadeInDuration: Duration.zero,
                        placeholder: (_, __) =>
                        const SizedBox.shrink(),
                        errorWidget: (_, __, ___) =>
                        const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        'x${_formatTimesNumber(multiplier <= 0 ? 1 : multiplier)}',
                        key: ValueKey<String>(
                          'multiplier_${_formatTimesNumber(multiplier)}',
                        ),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xfffff08c),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          shadows: [
                            Shadow(
                              color: Color(0xff8c3b00),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                            Shadow(
                              color: Color(0xffffd400),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 52,
                      constraints: const BoxConstraints(minWidth: 98),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xffffd22e),
                            Color(0xffdf6d00),
                            Color(0xff9f3500),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xffffef83),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 7,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Text(
                          '+${_formatCoin(coin)}',
                          key: ValueKey<int>(coin),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(
                                color: Color(0xff6d2300),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildLuckyGiftContent() {
    if (_luckyGiftUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isLuckyImageSvga) {
      return SVGAEasyPlayer(
        key: ValueKey('lucky_main_$_luckyGiftUrl'),
        resUrl: _luckyGiftUrl,
        fit: BoxFit.contain,
        loops: 0,
        isMute: _hasExternalAudio,
        useCache: true,
        onFinished: () {
          debugPrint(
            '✅ Lucky SVGA finished; waiting for serial lucky gift finish',
          );
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: _luckyGiftUrl,
      width: _mainLuckyGiftSize,
      height: _mainLuckyGiftSize,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      filterQuality: FilterQuality.medium,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }


  Widget _buildNormalGiftContent() {
    if (!_hasNormalGiftMedia) {
      return const SizedBox.shrink();
    }

    if (_isSvga) {
      return SVGAEasyPlayer(
        key: ValueKey(
          'normal_svga_${_giftUrl}_$_normalAnimationInstanceKey',
        ),
        resUrl: _giftUrl,
        fit: BoxFit.contain,
        loops: 0,
        isMute: _hasExternalAudio,
        useCache: true,
        onFinished: () {
          if (_isClosing || _isDisposed) return;
          debugPrint('✅ Normal SVGA full animation finished');
          _closeGiftAnimation();
        },
      );
    }

    return _StaticGiftImage(
      key: ValueKey(
        'static_gift_${_giftUrl}_$_normalAnimationInstanceKey',
      ),
      imageUrl: _giftUrl,
      durationMs: _getImageFallbackDurationMs(),
      onFinished: _closeGiftAnimation,
    );
  }
}


class _LuckyGlobalResultBanner extends StatelessWidget {
  final String senderName;
  final String senderImage;
  final String giftImage;
  final double multiplier;
  final int winAmount;
  final VoidCallback onClose;

  const _LuckyGlobalResultBanner({
    required this.senderName,
    required this.senderImage,
    required this.giftImage,
    required this.multiplier,
    required this.winAmount,
    required this.onClose,
  });

  String _formatTimes(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  String _formatCoin(int value) {
    if (value >= 1000000) {
      final double n = value / 1000000;
      return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final double n = value / 1000;
      return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}K';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      builder: (_, slide, child) => Transform.translate(
        offset: Offset(MediaQuery.of(context).size.width * slide, 0),
        child: child,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Container(
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xff16a6ff),
                Color(0xff42d4ff),
                Color(0xffffcc35),
                Color(0xffff9d12),
              ],
              stops: [0, .46, .78, 1],
            ),
            border: Border.all(
              color: const Color(0xfffff0a0),
              width: 1.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
              BoxShadow(
                color: Color(0x88ffbf27),
                blurRadius: 18,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(.26),
                        Colors.transparent,
                        Colors.black.withOpacity(.12),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 6),
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xffffef88), Color(0xffff8900)],
                      ),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: ClipOval(
                      child: senderImage.isEmpty
                          ? Container(
                        color: const Color(0xff52788c),
                        alignment: Alignment.center,
                        child: Text(
                          senderName.isEmpty
                              ? 'U'
                              : senderName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      )
                          : CachedNetworkImage(
                        imageUrl: senderImage,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        placeholder: (_, __) =>
                            Container(color: Colors.white12),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xff52788c),
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
                          senderName.isEmpty ? 'Lucky Winner' : senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                        ),
                        Text(
                          '+${_formatCoin(winAmount)} coin reward',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xfffff6c8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (giftImage.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: giftImage,
                      width: 38,
                      height: 38,
                      fit: BoxFit.contain,
                      fadeInDuration: Duration.zero,
                      placeholder: (_, __) =>
                      const SizedBox(width: 38, height: 38),
                      errorWidget: (_, __, ___) =>
                      const SizedBox(width: 38, height: 38),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    'x${_formatTimes(multiplier)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    height: 39,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xfffff077), Color(0xffffb20f)],
                      ),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Text(
                      'Go',
                      style: TextStyle(
                        color: Color(0xff6d3b00),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _LuckyFlightRequest {
  const _LuckyFlightRequest({
    required this.tapKey,
    required this.serial,
    required this.imageUrl,
    required this.screenSize,
    required this.senderSource,
    required this.senderProfileUrl,
    required this.receiverTargets,
    required this.receiverProfileUrls,
    required this.multiplier,
    required this.winAmount,
  });

  final String tapKey;
  final int serial;
  final String imageUrl;
  final Size screenSize;
  final Offset senderSource;
  final String senderProfileUrl;
  final List<Offset> receiverTargets;
  final List<String> receiverProfileUrls;
  final double multiplier;
  final int winAmount;
}

class _LuckyQueuedFlight {
  const _LuckyQueuedFlight({
    required this.request,
    required this.launchAtMs,
    required this.arriveCenterAtMs,
    required this.dispatchAtMs,
    required this.finishAtMs,
  });

  final _LuckyFlightRequest request;
  final int launchAtMs;
  final int arriveCenterAtMs;
  final int dispatchAtMs;
  final int finishAtMs;
}

class _LuckyReceiverSummary {
  const _LuckyReceiverSummary({
    required this.keyValue,
    required this.target,
    required this.receiverProfileUrl,
    required this.giftImageUrl,
    required this.count,
    required this.updatedAtMs,
    required this.visibleUntilMs,
  });

  final String keyValue;
  final Offset target;
  final String receiverProfileUrl;
  final String giftImageUrl;
  final int count;
  final int updatedAtMs;
  final int visibleUntilMs;

  _LuckyReceiverSummary copyWith({
    int? count,
    int? updatedAtMs,
    int? visibleUntilMs,
  }) {
    return _LuckyReceiverSummary(
      keyValue: keyValue,
      target: target,
      receiverProfileUrl: receiverProfileUrl,
      giftImageUrl: giftImageUrl,
      count: count ?? this.count,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      visibleUntilMs: visibleUntilMs ?? this.visibleUntilMs,
    );
  }
}

/// High-performance Lucky Combo animation layer.
///
/// The layer is permanently mounted inside AudioLiveView:
/// - one AnimationController/ticker for the room
/// - one incoming image for each physical tap
/// - the image grows from sender profile to page middle
/// - after a short hold it fans out to every selected receiver
/// - cards and render queue are strictly bounded
class _LuckyGiftFlightQueueLayer extends StatefulWidget {
  const _LuckyGiftFlightQueueLayer({
    super.key,
    required this.onQueueEmpty,
  });

  final VoidCallback onQueueEmpty;

  @override
  State<_LuckyGiftFlightQueueLayer> createState() =>
      _LuckyGiftFlightQueueLayerState();
}

class _LuckyGiftFlightQueueLayerState
    extends State<_LuckyGiftFlightQueueLayer>
    with SingleTickerProviderStateMixin {
  static const int _senderToCenterMs = 520;
  static const int _minimumCenterHoldMs = 300;
  static const int _centerToReceiverMs = 620;
  static const int _arrivalGapMs = 64;

  static const int _maxPaintedIncomingItems = 4;
  static const int _maxPaintedWaitingItems = 4;
  static const int _maxPaintedOutgoingItems = 1;

  /// Rapid Combo back-pressure. Fifty fast taps must not leave twenty seconds
  /// of old animations running after the user has stopped tapping. Every tap
  /// still updates the receiver xCount, but only a short rolling window is
  /// kept as visible flights. The newest tap replaces the last waiting slot.
  static const int _maxFutureVisualFlights = 10;

  /// Active + waiting visual items are strictly bounded for low-RAM devices.
  static const int _hardQueueSafetyLimit = 18;

  /// Larger Lucky gift image from sender profile -> center -> receiver profile.
  /// Canvas rendering keeps this size increase lightweight and smooth.
  static const double _smallSize = 52.0;
  static const double _largeSize = 118.0;
  static const double _receiverEndSize = 46.0;

  late final AnimationController _ticker;
  final List<_LuckyQueuedFlight> _flights = <_LuckyQueuedFlight>[];
  final Map<String, _LuckyReceiverSummary> _receiverCards =
  <String, _LuckyReceiverSummary>{};

  /// Second guard at the queue boundary. It protects against two async flushes
  /// carrying the same tap request in the same frame.
  final Map<String, int> _acceptedTapKeys = <String, int>{};

  /// Moving gifts use one decoded image and one CustomPainter canvas.
  /// Eight receivers therefore do not create eight CachedNetworkImage widgets
  /// on every frame. This removes the main-thread pressure that caused large
  /// skipped-frame bursts and native process crashes on busy audio rooms.
  final Map<String, ui.Image> _decodedFlightImages = <String, ui.Image>{};
  final Map<String, ImageStream> _flightImageStreams = <String, ImageStream>{};
  final Map<String, ImageStreamListener> _flightImageListeners =
  <String, ImageStreamListener>{};

  /// Receiver cards contain CachedNetworkImage widgets. Recreating those cards
  /// on every animation tick caused unnecessary widget reconciliation. Cache
  /// the exact Widget instances and rebuild them only when a tap changes the
  /// card count or when a card expires.
  List<Widget> _cachedReceiverCardWidgets = const <Widget>[];
  Size _cachedReceiverCardScreen = Size.zero;

  /// Adaptive visual cadence. Small/normal fan-out uses a higher cadence for
  /// visibly smoother movement, while very large receiver groups automatically
  /// reduce paint frequency to protect low-RAM/low-GPU devices.
  int _lastVisualTickMs = 0;

  int get _visualFrameIntervalMs {
    int maxTargets = 0;
    for (final flight in _flights) {
      if (flight.request.receiverTargets.length > maxTargets) {
        maxTargets = flight.request.receiverTargets.length;
      }
    }
    if (maxTargets >= 80) return 50; // 20 FPS for very large fan-out
    if (maxTargets >= 40) return 40; // 25 FPS
    if (maxTargets >= 20) return 32; // ~31 FPS
    if (maxTargets >= 9) return 25;  // 40 FPS
    return 20;                       // 50 FPS for 1-8 receivers
  }

  int _nextArrivalAtMs = 0;
  int _nextDispatchAtMs = 0;
  bool _emptyCallbackScheduled = false;

  double _resultMultiplier = 0;
  int _resultWinAmount = 0;
  Size _resultScreenSize = Size.zero;
  int _resultStartedAtMs = 0;
  int _resultVisibleUntilMs = 0;

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
  }

  void _ensureTickerRunning() {
    if (!_ticker.isAnimating) {
      _ticker.repeat();
    }
  }

  int _dispatchGapForBacklog(int backlog) {
    if (backlog >= 14) return 96;
    if (backlog >= 10) return 112;
    if (backlog >= 7) return 135;
    if (backlog >= 4) return 175;
    return 225;
  }

  int _futureVisualFlightCount(int now) {
    int count = 0;
    for (final _LuckyQueuedFlight flight in _flights) {
      if (now < flight.launchAtMs) count++;
    }
    return count;
  }

  int _lastFutureVisualFlightIndex(int now) {
    for (int i = _flights.length - 1; i >= 0; i--) {
      if (now < _flights[i].launchAtMs) return i;
    }
    return -1;
  }

  String _receiverKey({
    required Offset target,
    required String profileUrl,
    required String giftUrl,
  }) {
    return '${target.dx.toStringAsFixed(1)}|'
        '${target.dy.toStringAsFixed(1)}|$profileUrl|$giftUrl';
  }

  void _bumpReceiverCards(
      _LuckyFlightRequest request, {
        required int now,
        required int visibleUntilMs,
      }) {
    final int cardCount = math.min(4, request.receiverTargets.length);
    for (int i = 0; i < cardCount; i++) {
      final Offset target = request.receiverTargets[i];
      final String profile = i < request.receiverProfileUrls.length
          ? request.receiverProfileUrls[i]
          : '';
      final String key = _receiverKey(
        target: target,
        profileUrl: profile,
        giftUrl: request.imageUrl,
      );
      final _LuckyReceiverSummary? old = _receiverCards[key];
      _receiverCards[key] = _LuckyReceiverSummary(
        keyValue: key,
        target: target,
        receiverProfileUrl: profile,
        giftImageUrl: request.imageUrl,
        count: (old?.count ?? 0) + 1,
        updatedAtMs: now,
        visibleUntilMs: math.max(
          old?.visibleUntilMs ?? 0,
          visibleUntilMs,
        ).toInt(),
      );
    }
  }

  void _ensureFlightImageLoaded(String rawUrl) {
    final String url = rawUrl.trim();
    if (url.isEmpty ||
        _decodedFlightImages.containsKey(url) ||
        _flightImageStreams.containsKey(url)) {
      return;
    }

    try {
      final ImageStream stream = CachedNetworkImageProvider(url).resolve(
        const ImageConfiguration(),
      );

      late final ImageStreamListener listener;
      listener = ImageStreamListener(
            (ImageInfo info, bool synchronousCall) {
          if (!mounted) return;
          _decodedFlightImages[url] = info.image;

          final ImageStream? savedStream = _flightImageStreams.remove(url);
          final ImageStreamListener? savedListener =
          _flightImageListeners.remove(url);
          if (savedStream != null && savedListener != null) {
            savedStream.removeListener(savedListener);
          }

          // Keep a small room-local cache. Gift thumbnails are already managed
          // by Flutter's global ImageCache; this map only stores active handles.
          if (_decodedFlightImages.length > 12) {
            final String oldest = _decodedFlightImages.keys.first;
            if (oldest != url) _decodedFlightImages.remove(oldest);
          }

          setState(() {});
        },
        onError: (Object error, StackTrace? stackTrace) {
          final ImageStream? savedStream = _flightImageStreams.remove(url);
          final ImageStreamListener? savedListener =
          _flightImageListeners.remove(url);
          if (savedStream != null && savedListener != null) {
            savedStream.removeListener(savedListener);
          }
        },
      );

      _flightImageStreams[url] = stream;
      _flightImageListeners[url] = listener;
      stream.addListener(listener);
    } catch (_) {}
  }

  void enqueueAll(List<_LuckyFlightRequest> requests) {
    if (requests.isEmpty || !mounted) return;

    final int now = _nowMs;
    _acceptedTapKeys.removeWhere((_, int time) => now - time > 30000);

    for (final _LuckyFlightRequest request in requests) {
      _ensureFlightImageLoaded(request.imageUrl);
    }

    setState(() {
      for (final _LuckyFlightRequest request in requests) {
        if (request.tapKey.isEmpty ||
            _acceptedTapKeys.containsKey(request.tapKey)) {
          continue;
        }
        _acceptedTapKeys[request.tapKey] = now;

        // Count every real tap immediately, even when the visual backlog is
        // compressed. This keeps x50 accurate without drawing 50 long flights.
        _bumpReceiverCards(
          request,
          now: now,
          visibleUntilMs: now + 2400,
        );

        if (request.multiplier > 0 && request.winAmount > 0) {
          _setResultWithoutSetState(
            multiplier: request.multiplier,
            winAmount: request.winAmount,
            screenSize: request.screenSize,
            now: now,
          );
        }

        final int futureCount = _futureVisualFlightCount(now);
        if (futureCount >= _maxFutureVisualFlights) {
          // Replace the latest waiting visual slot with the newest tap. Network,
          // balance and count processing are untouched; only stale visual work
          // is collapsed so animation stops shortly after tapping stops.
          final int replaceIndex = _lastFutureVisualFlightIndex(now);
          if (replaceIndex >= 0) {
            final _LuckyQueuedFlight oldFlight = _flights[replaceIndex];
            _flights[replaceIndex] = _LuckyQueuedFlight(
              request: request,
              launchAtMs: oldFlight.launchAtMs,
              arriveCenterAtMs: oldFlight.arriveCenterAtMs,
              dispatchAtMs: oldFlight.dispatchAtMs,
              finishAtMs: oldFlight.finishAtMs,
            );
          }
          continue;
        }

        if (_flights.length >= _hardQueueSafetyLimit) {
          final int replaceIndex = _lastFutureVisualFlightIndex(now);
          if (replaceIndex >= 0) {
            final _LuckyQueuedFlight oldFlight = _flights[replaceIndex];
            _flights[replaceIndex] = _LuckyQueuedFlight(
              request: request,
              launchAtMs: oldFlight.launchAtMs,
              arriveCenterAtMs: oldFlight.arriveCenterAtMs,
              dispatchAtMs: oldFlight.dispatchAtMs,
              finishAtMs: oldFlight.finishAtMs,
            );
          }
          continue;
        }

        final int launchAt = math.max(now, _nextArrivalAtMs).toInt();
        final int arriveAt = launchAt + _senderToCenterMs;
        final int earliestDispatch = arriveAt + _minimumCenterHoldMs;
        final int dispatchAt =
        math.max(earliestDispatch, _nextDispatchAtMs).toInt();
        final int finishAt = dispatchAt + _centerToReceiverMs;

        _flights.add(
          _LuckyQueuedFlight(
            request: request,
            launchAtMs: launchAt,
            arriveCenterAtMs: arriveAt,
            dispatchAtMs: dispatchAt,
            finishAtMs: finishAt,
          ),
        );

        _nextArrivalAtMs = launchAt + _arrivalGapMs;
        _nextDispatchAtMs =
            dispatchAt + _dispatchGapForBacklog(_flights.length);
      }

      if (_receiverCards.isNotEmpty) {
        final Size screen = _flights.isNotEmpty
            ? _flights.last.request.screenSize
            : _cachedReceiverCardScreen;
        if (screen.width > 0 && screen.height > 0) {
          _refreshReceiverCardWidgetCache(now, screen);
        }
      }
    });

    _ensureTickerRunning();
  }

  void showResult({
    required double multiplier,
    required int winAmount,
    required Size screenSize,
  }) {
    if (!mounted || multiplier <= 0 || winAmount <= 0) return;
    final int now = _nowMs;
    setState(() {
      _setResultWithoutSetState(
        multiplier: multiplier,
        winAmount: winAmount,
        screenSize: screenSize,
        now: now,
      );
    });
    _ensureTickerRunning();
  }

  void _setResultWithoutSetState({
    required double multiplier,
    required int winAmount,
    required Size screenSize,
    required int now,
  }) {
    _resultMultiplier = multiplier;
    _resultWinAmount = winAmount;
    _resultScreenSize = screenSize;
    _resultStartedAtMs = now;
    _resultVisibleUntilMs = now + 1850;
  }

  void clearImmediately() {
    _flights.clear();
    _receiverCards.clear();
    _cachedReceiverCardWidgets = const <Widget>[];
    _cachedReceiverCardScreen = Size.zero;
    _acceptedTapKeys.clear();
    _nextArrivalAtMs = 0;
    _nextDispatchAtMs = 0;
    _resultVisibleUntilMs = 0;
    _lastVisualTickMs = 0;
    _ticker.stop(canceled: false);
  }

  void _onTick() {
    if (!mounted) return;

    final int now = _nowMs;
    if (_lastVisualTickMs != 0 &&
        now - _lastVisualTickMs < _visualFrameIntervalMs) {
      return;
    }
    _lastVisualTickMs = now;

    final int beforeFlights = _flights.length;
    final int beforeCards = _receiverCards.length;

    _flights.removeWhere((flight) => now >= flight.finishAtMs);
    _receiverCards.removeWhere(
          (_, summary) => now >= summary.visibleUntilMs,
    );

    if (beforeCards != _receiverCards.length) {
      final Size screen = _flights.isNotEmpty
          ? _flights.last.request.screenSize
          : _cachedReceiverCardScreen;
      if (_receiverCards.isEmpty) {
        _cachedReceiverCardWidgets = const <Widget>[];
      } else if (screen.width > 0 && screen.height > 0) {
        _refreshReceiverCardWidgetCache(now, screen);
      }
    }

    final bool resultVisible = now < _resultVisibleUntilMs;
    final bool hasVisuals =
        _flights.isNotEmpty || _receiverCards.isNotEmpty || resultVisible;

    if (!hasVisuals) {
      _nextArrivalAtMs = 0;
      _nextDispatchAtMs = 0;
      _ticker.stop(canceled: false);

      if (!_emptyCallbackScheduled) {
        _emptyCallbackScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _emptyCallbackScheduled = false;
          if (mounted &&
              _flights.isEmpty &&
              _receiverCards.isEmpty &&
              _nowMs >= _resultVisibleUntilMs) {
            widget.onQueueEmpty();
          }
        });
      }
    }

    if (mounted &&
        (beforeFlights != _flights.length ||
            beforeCards != _receiverCards.length ||
            hasVisuals)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final MapEntry<String, ImageStream> entry
    in _flightImageStreams.entries) {
      final ImageStreamListener? listener = _flightImageListeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
    }
    _flightImageStreams.clear();
    _flightImageListeners.clear();
    _decodedFlightImages.clear();

    _ticker
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  Offset _middle(Size screenSize) {
    return Offset(
      screenSize.width * .50,
      screenSize.height * .55,
    );
  }

  Offset _quadraticPoint({
    required Offset start,
    required Offset control,
    required Offset end,
    required double t,
  }) {
    final double u = 1.0 - t;
    return Offset(
      (u * u * start.dx) + (2 * u * t * control.dx) + (t * t * end.dx),
      (u * u * start.dy) + (2 * u * t * control.dy) + (t * t * end.dy),
    );
  }

  double _lerp(double begin, double end, double t) =>
      begin + ((end - begin) * t);

  _LuckyFlightFrame _incomingFrame(
      _LuckyQueuedFlight flight,
      int now,
      int waitingVisualIndex,
      ) {
    final _LuckyFlightRequest request = flight.request;
    final Offset source = request.senderSource;
    final Offset center = _middle(request.screenSize);

    if (now < flight.launchAtMs) {
      return const _LuckyFlightFrame(
        position: Offset.zero,
        size: 0,
        opacity: 0,
      );
    }

    if (now < flight.arriveCenterAtMs) {
      final double raw = ((now - flight.launchAtMs) /
          math.max(1, flight.arriveCenterAtMs - flight.launchAtMs))
          .clamp(0.0, 1.0)
          .toDouble();
      final double eased = Curves.easeInOutCubic.transform(raw);

      // Rain-like soft fall: it leaves the sender profile small and grows
      // continuously while moving toward the center.
      final Offset control = Offset(
        (source.dx + center.dx) / 2,
        source.dy + ((center.dy - source.dy) * .60),
      );

      return _LuckyFlightFrame(
        position: _quadraticPoint(
          start: source,
          control: control,
          end: center,
          t: eased,
        ),
        size: _lerp(_smallSize, _largeSize, eased),
        opacity: (raw / .07).clamp(0.0, 1.0).toDouble(),
      );
    }

    final double stackX = ((waitingVisualIndex % 4) - 1.5) * 3.4;
    final double stackY = -(waitingVisualIndex ~/ 4) * 3.2;
    return _LuckyFlightFrame(
      position: center + Offset(stackX, stackY),
      size: _largeSize,
      opacity: 1,
    );
  }

  _LuckyFlightFrame _outgoingFrame({
    required _LuckyQueuedFlight flight,
    required int targetIndex,
    required int now,
  }) {
    final _LuckyFlightRequest request = flight.request;
    final Offset center = _middle(request.screenSize);
    final Offset rawTarget = request.receiverTargets[targetIndex];
    final Offset target = Offset(
      rawTarget.dx,
      (rawTarget.dy + _GiftAnimationGeometry.profileIntakeYOffset)
          .clamp(0.0, request.screenSize.height)
          .toDouble(),
    );

    final double raw = ((now - flight.dispatchAtMs) /
        math.max(1, flight.finishAtMs - flight.dispatchAtMs))
        .clamp(0.0, 1.0)
        .toDouble();
    final double eased = Curves.easeInOutCubic.transform(raw);
    final double sideBend =
        ((targetIndex % 5) - 2) * (request.screenSize.width * .010);
    final Offset control = Offset(
      (center.dx + target.dx) / 2 + sideBend,
      center.dy + ((target.dy - center.dy) * .54),
    );

    final double fade = raw <= .88
        ? 1.0
        : (1.0 - ((raw - .88) / .12)).clamp(0.0, 1.0).toDouble();

    return _LuckyFlightFrame(
      position: _quadraticPoint(
        start: center,
        control: control,
        end: target,
        t: eased,
      ),
      size: _lerp(_largeSize, _receiverEndSize, eased),
      opacity: fade,
    );
  }

  List<_LuckyReceiverSummary> _receiverSummaries(int now) {
    final List<_LuckyReceiverSummary> list = _receiverCards.values
        .where((summary) => now < summary.visibleUntilMs)
        .toList(growable: false);
    list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return list.take(4).toList(growable: false);
  }

  void _refreshReceiverCardWidgetCache(int now, Size screen) {
    _cachedReceiverCardScreen = screen;
    final List<_LuckyReceiverSummary> summaries = _receiverSummaries(now);
    _cachedReceiverCardWidgets = List<Widget>.generate(
      summaries.length,
          (int index) => _buildLeftReceiverCard(
        summaries[index],
        index,
        screen,
      ),
      growable: false,
    );
  }

  Widget _networkCircle(String url, double size) {
    if (url.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xff526071),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.person, color: Colors.white, size: size * .55),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => SizedBox.square(dimension: size),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xff526071),
          child: Icon(Icons.person, color: Colors.white, size: size * .55),
        ),
      ),
    );
  }

  Widget _buildLeftReceiverCard(
      _LuckyReceiverSummary summary,
      int index,
      Size screen,
      ) {
    final double top = math.max(72.0, screen.height * .105) + (index * 38.0);
    final double width = (screen.width * .38).clamp(126.0, 158.0).toDouble();

    return Positioned(
      left: 5,
      top: top,
      child: RepaintBoundary(
        child: Container(
          width: width,
          height: 34,
          padding: const EdgeInsets.fromLTRB(3, 3, 7, 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: <Color>[
                const Color(0xff12c979).withOpacity(.96),
                const Color(0xff1ed88d).withOpacity(.78),
                const Color(0xff1ed88d).withOpacity(.16),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(.24),
              width: .7,
            ),
          ),
          child: Row(
            children: <Widget>[
              _networkCircle(summary.receiverProfileUrl, 28),
              const SizedBox(width: 6),
              CachedNetworkImage(
                imageUrl: summary.giftImageUrl,
                width: 25,
                height: 25,
                fit: BoxFit.contain,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                useOldImageOnUrlChange: true,
                filterQuality: FilterQuality.low,
                placeholder: (_, __) =>
                const SizedBox(width: 25, height: 25),
                errorWidget: (_, __, ___) =>
                const SizedBox(width: 25, height: 25),
              ),
              const Spacer(),
              Text(
                'x${summary.count}',
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xffffe44f),
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black45, blurRadius: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCoin(int value) {
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}K';
    }
    return '$value';
  }

  String _formatMultiplier(double value) =>
      value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1);

  Widget _buildCenterResult(int now) {
    if (now >= _resultVisibleUntilMs ||
        _resultScreenSize.isEmpty ||
        _resultMultiplier <= 0 ||
        _resultWinAmount <= 0) {
      return const SizedBox.shrink();
    }

    final int total = math.max(1, _resultVisibleUntilMs - _resultStartedAtMs);
    final double t = ((now - _resultStartedAtMs) / total)
        .clamp(0.0, 1.0)
        .toDouble();

    /// Fast reveal: the local asset is already precached and becomes visible
    /// almost instantly when the confirmed Lucky multiplier arrives.
    final double appear = (t / .045).clamp(0.0, 1.0).toDouble();
    final double fade = t < .84
        ? 1.0
        : (1.0 - ((t - .84) / .16)).clamp(0.0, 1.0).toDouble();

    const double frameWidth = 214.0;
    const double frameHeight = 238.0;

    return Positioned(
      left: (_resultScreenSize.width - frameWidth) / 2,
      top: (_resultScreenSize.height * .45) - (frameHeight / 2),
      child: Opacity(
        opacity: appear * fade,
        child: Transform.scale(
          scale: .88 + (.12 * Curves.easeOutBack.transform(appear)),
          child: RepaintBoundary(
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  const Positioned.fill(
                    child: Image(
                      image: AssetImage('assets/new/luckytime.png'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),

                  /// Multiplier is placed inside the blue center of the supplied
                  /// Lucky Times frame. The image already contains the "Times"
                  /// label, so only the live x-value changes.
                  Positioned(
                    top: 78,
                    left: 28,
                    right: 28,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'x${_formatMultiplier(_resultMultiplier)}',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          shadows: <Shadow>[
                            Shadow(
                              color: Color(0xff073f70),
                              blurRadius: 2,
                              offset: Offset(0, 3),
                            ),
                            Shadow(
                              color: Color(0xffffc400),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _LuckyFlightPaintItem? _paintItem({
    required String url,
    required _LuckyFlightFrame frame,
  }) {
    final ui.Image? image = _decodedFlightImages[url.trim()];
    if (image == null ||
        frame.size <= 0 ||
        frame.opacity <= 0 ||
        url.trim().isEmpty) {
      return null;
    }

    return _LuckyFlightPaintItem(
      image: image,
      position: frame.position,
      size: frame.size,
      opacity: frame.opacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int now = _nowMs;
    final bool resultVisible = now < _resultVisibleUntilMs;
    final bool hasReceiverCards = _cachedReceiverCardWidgets.isNotEmpty;

    if (_flights.isEmpty && !resultVisible && !hasReceiverCards) {
      return const SizedBox.shrink();
    }

    // Classify the bounded queue in one pass. The previous three where().toList()
    // traversals allocated three lists on every visual frame.
    final List<_LuckyQueuedFlight> incoming = <_LuckyQueuedFlight>[];
    final List<_LuckyQueuedFlight> waiting = <_LuckyQueuedFlight>[];
    final List<_LuckyQueuedFlight> outgoing = <_LuckyQueuedFlight>[];

    for (final _LuckyQueuedFlight flight in _flights) {
      if (now < flight.launchAtMs || now >= flight.finishAtMs) continue;
      if (now < flight.arriveCenterAtMs) {
        incoming.add(flight);
      } else if (now < flight.dispatchAtMs) {
        waiting.add(flight);
      } else {
        outgoing.add(flight);
      }
    }

    final List<_LuckyQueuedFlight> visibleIncoming =
    incoming.length <= _maxPaintedIncomingItems
        ? incoming
        : incoming.sublist(incoming.length - _maxPaintedIncomingItems);
    final List<_LuckyQueuedFlight> visibleWaiting =
    waiting.length <= _maxPaintedWaitingItems
        ? waiting
        : waiting.sublist(waiting.length - _maxPaintedWaitingItems);
    final List<_LuckyQueuedFlight> visibleOutgoing =
    outgoing.length <= _maxPaintedOutgoingItems
        ? outgoing
        : outgoing.sublist(0, _maxPaintedOutgoingItems);

    final Map<_LuckyQueuedFlight, int> waitingIndex =
    <_LuckyQueuedFlight, int>{};
    for (int i = 0; i < visibleWaiting.length; i++) {
      waitingIndex[visibleWaiting[i]] = i;
    }

    final Size screen = _flights.isNotEmpty
        ? _flights.last.request.screenSize
        : _resultScreenSize;

    final List<_LuckyFlightPaintItem> paintItems = <_LuckyFlightPaintItem>[];

    for (final _LuckyQueuedFlight flight in visibleIncoming) {
      final _LuckyFlightPaintItem? item = _paintItem(
        url: flight.request.imageUrl,
        frame: _incomingFrame(flight, now, 0),
      );
      if (item != null) paintItems.add(item);
    }

    for (final _LuckyQueuedFlight flight in visibleWaiting) {
      final _LuckyFlightPaintItem? item = _paintItem(
        url: flight.request.imageUrl,
        frame: _incomingFrame(
          flight,
          now,
          waitingIndex[flight] ?? 0,
        ),
      );
      if (item != null) paintItems.add(item);
    }

    for (final _LuckyQueuedFlight flight in visibleOutgoing) {
      for (int i = 0; i < flight.request.receiverTargets.length; i++) {
        final _LuckyFlightPaintItem? item = _paintItem(
          url: flight.request.imageUrl,
          frame: _outgoingFrame(
            flight: flight,
            targetIndex: i,
            now: now,
          ),
        );
        if (item != null) paintItems.add(item);
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        /// Cached cards are painted first, so every flying gift stays above
        /// them without rebuilding network-image widgets on every ticker frame.
        ..._cachedReceiverCardWidgets,

        if (paintItems.isNotEmpty)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: false,
                willChange: true,
                painter: _LuckyFlightCanvasPainter(items: paintItems),
              ),
            ),
          ),

        _buildCenterResult(now),
      ],
    );
  }
}

class _LuckyFlightPaintItem {
  const _LuckyFlightPaintItem({
    required this.image,
    required this.position,
    required this.size,
    required this.opacity,
  });

  final ui.Image image;
  final Offset position;
  final double size;
  final double opacity;
}

class _LuckyFlightCanvasPainter extends CustomPainter {
  const _LuckyFlightCanvasPainter({required this.items});

  final List<_LuckyFlightPaintItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.low;

    for (final _LuckyFlightPaintItem item in items) {
      final ui.Image image = item.image;
      final double imageWidth = image.width.toDouble();
      final double imageHeight = image.height.toDouble();
      if (imageWidth <= 0 || imageHeight <= 0) continue;

      final double aspect = imageWidth / imageHeight;
      final double drawWidth = aspect >= 1 ? item.size : item.size * aspect;
      final double drawHeight = aspect >= 1 ? item.size / aspect : item.size;

      paint.color = Color.fromRGBO(
        255,
        255,
        255,
        item.opacity.clamp(0.0, 1.0).toDouble(),
      );

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, imageWidth, imageHeight),
        Rect.fromCenter(
          center: item.position,
          width: drawWidth,
          height: drawHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LuckyFlightCanvasPainter oldDelegate) => true;
}

class _LuckyFlightFrame {
  const _LuckyFlightFrame({
    required this.position,
    required this.size,
    required this.opacity,
  });

  final Offset position;
  final double size;
  final double opacity;
}

class _LuckyFountainParticle {
  final double startTime;
  final double lifeTime;
  final double targetX;
  final double targetY;
  final double size;
  final double archHeight;
  final double bend;
  final double sway;
  final double phase;
  final double rotation;
  final double startOffsetX;
  final double startOffsetY;
  final double exitSpread;

  const _LuckyFountainParticle({
    required this.startTime,
    required this.lifeTime,
    required this.targetX,
    required this.targetY,
    required this.size,
    required this.archHeight,
    required this.bend,
    required this.sway,
    required this.phase,
    required this.rotation,
    required this.startOffsetX,
    required this.startOffsetY,
    required this.exitSpread,
  });
}

class _GiftAnimationGeometry {
  static const double profileIntakeYOffset = 17.0;
  static const double cardBottom = 236.0;
  static const double cardHeight = 64.0;

  static Offset cardGiftLaunchPoint(Size size) {
    final double cardWidth = (size.width - 18).clamp(300.0, 540.0);
    final double cardLeft = (size.width - cardWidth) / 2;
    return Offset(
      cardLeft + (cardWidth * .72),
      size.height - cardBottom - (cardHeight / 2),
    );
  }
}

class _LuckyVideoFountainPainter extends CustomPainter {
  final ui.Image image;
  final List<_LuckyFountainParticle> particles;
  final double timeline;
  final double mainGiftSize;
  final double mainGiftYOffset;
  final List<Offset> receiverTargets;

  const _LuckyVideoFountainPainter({
    required this.image,
    required this.particles,
    required this.timeline,
    required this.mainGiftSize,
    required this.mainGiftYOffset,
    required this.receiverTargets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double centerX = size.width / 2;
    final double centerY = (size.height / 2) + mainGiftYOffset;
    final Rect sourceRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final Paint paint = Paint()..filterQuality = FilterQuality.low;

    Offset launchPoint(int index, _LuckyFountainParticle particle) {
      final Offset cardPoint =
      _GiftAnimationGeometry.cardGiftLaunchPoint(size);
      return Offset(
        (cardPoint.dx + particle.startOffsetX)
            .clamp(size.width * .04, size.width * .96)
            .toDouble(),
        (cardPoint.dy + particle.startOffsetY)
            .clamp(size.height * .05, size.height * .94)
            .toDouble(),
      );
    }

    for (int particleIndex = 0;
    particleIndex < particles.length;
    particleIndex++) {
      final _LuckyFountainParticle particle = particles[particleIndex];
      if (timeline < particle.startTime) continue;

      final double rawProgress =
          (timeline - particle.startTime) / particle.lifeTime;
      final double progress = rawProgress.clamp(0.0, 1.0).toDouble();
      if (progress >= 1.0) continue;

      final Offset start = launchPoint(particleIndex, particle);
      final List<Offset?> targets = receiverTargets.isEmpty
          ? const <Offset?>[null]
          : receiverTargets.map<Offset?>((target) => target).toList();

      // One send starts from the Times badge once, then fans out to every
      // selected receiver at the same moment. Combo sends repeat serially.
      for (int targetIndex = 0; targetIndex < targets.length; targetIndex++) {
        final Offset? target = targets[targetIndex];

        late final double endX;
        late final double endY;
        if (target != null) {
          final double angle = particle.phase +
              (particle.targetX * math.pi * 2) +
              (targetIndex * .42);
          final double radius = 1.5 + (particle.targetY * 5.0);
          endX = (target.dx + math.cos(angle) * radius)
              .clamp(0.0, size.width)
              .toDouble();
          endY = (target.dy +
              _GiftAnimationGeometry.profileIntakeYOffset +
              math.sin(angle) * radius)
              .clamp(0.0, size.height)
              .toDouble();
        } else {
          final double fallbackAngle =
              particle.phase + (particleIndex * .36);
          endX = (centerX +
              math.cos(fallbackAngle) * (mainGiftSize * .62))
              .clamp(0.0, size.width)
              .toDouble();
          endY = (centerY +
              math.sin(fallbackAngle) * (mainGiftSize * .46))
              .clamp(0.0, size.height)
              .toDouble();
        }

        final double eased = Curves.easeInOutCubic.transform(progress);
        final double inverse = 1.0 - eased;

        final double receiverFan = ((targetIndex % 5) - 2.0) * 4.0;
        final double controlX = ((start.dx + endX) / 2) +
            receiverFan +
            (particle.exitSpread * (target == null ? 34.0 : 18.0));
        final double controlY = ((start.dy + endY) / 2) -
            (24.0 + (particle.targetY * 14.0));

        double x = (inverse * inverse * start.dx) +
            (2 * inverse * eased * controlX) +
            (eased * eased * endX);
        double y = (inverse * inverse * start.dy) +
            (2 * inverse * eased * controlY) +
            (eased * eased * endY);

        x += math.sin((eased * math.pi * 2.0) +
            particle.phase +
            targetIndex) *
            (particle.sway * .60);
        y += math.sin((eased * math.pi * 1.10) + particle.phase) * 1.6;

        double particleScale = 0.40 +
            (Curves.easeOutCubic.transform(
                (progress / 0.12).clamp(0.0, 1.0).toDouble()) *
                0.68);
        if (progress > .18) {
          particleScale += math.sin(progress * math.pi) * 0.10;
        }

        double opacity = progress < .08
            ? (progress / .08).clamp(0.0, 1.0).toDouble()
            : 1.0;

        if (target != null) {
          final double intake = progress > 0.70
              ? ((progress - 0.70) / 0.30)
              .clamp(0.0, 1.0)
              .toDouble()
              : 0.0;
          particleScale *=
              (1.0 - (intake * 0.86)).clamp(0.12, 1.0).toDouble();
          opacity *=
              (1.0 - (intake * 1.0)).clamp(0.0, 1.0).toDouble();
        } else if (progress > .88) {
          opacity *=
              ((1.0 - progress) / 0.12).clamp(0.0, 1.0).toDouble();
        }

        final double dimension = particle.size * particleScale;
        final double imageAspect = image.width / image.height;
        final double drawWidth =
        imageAspect >= 1.0 ? dimension : dimension * imageAspect;
        final double drawHeight =
        imageAspect >= 1.0 ? dimension / imageAspect : dimension;

        paint.color = Color.fromRGBO(255, 255, 255, opacity);

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(particle.rotation * progress);
        canvas.translate(-x, -y);

        final Rect destinationRect = Rect.fromCenter(
          center: Offset(x, y),
          width: drawWidth,
          height: drawHeight,
        );

        canvas.drawImageRect(image, sourceRect, destinationRect, paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LuckyVideoFountainPainter oldDelegate) {
    return oldDelegate.timeline != timeline ||
        oldDelegate.image != image ||
        oldDelegate.particles != particles ||
        oldDelegate.mainGiftSize != mainGiftSize ||
        oldDelegate.mainGiftYOffset != mainGiftYOffset ||
        oldDelegate.receiverTargets.length != receiverTargets.length ||
        oldDelegate.receiverTargets != receiverTargets;
  }
}


class _StaticGiftImage extends StatefulWidget {
  final String imageUrl;
  final int durationMs;
  final VoidCallback onFinished;

  const _StaticGiftImage({
    Key? key,
    required this.imageUrl,
    required this.durationMs,
    required this.onFinished,
  }) : super(key: key);

  @override
  State<_StaticGiftImage> createState() => _StaticGiftImageState();
}

class _StaticGiftImageState extends State<_StaticGiftImage> {
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
    _precache();
  }

  @override
  void didUpdateWidget(covariant _StaticGiftImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.durationMs != widget.durationMs) {
      _startHideTimer();
      _precache();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(milliseconds: widget.durationMs), () {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  void _precache() {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String url = widget.imageUrl.trim();
    if (url.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: false,
        filterQuality: FilterQuality.medium,
        placeholder: (context, value) {
          // Show an instant lightweight pulse while the network/cache image is
          // resolving. This removes the blank delay on the sender device.
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: .82, end: 1.0),
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.10),
                      border: Border.all(
                        color: Colors.white.withOpacity(.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.16),
                          blurRadius: 22,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          );
        },
        errorWidget: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
