import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/global_live_banner_queue_controller.dart';
import 'global_banner_layout.dart';
import '../controllers/roket_controller.dart';

/// Global Rocket banner.
///
/// The visual design, size, position, movement and countdown are intentionally
/// identical to GlobalLuckyWinBanner. Only the displayed information comes
/// from the Rocket launch payload.
class GlobalRocketLaunchBanner extends StatelessWidget {
  const GlobalRocketLaunchBanner({
    super.key,
    this.onOpenLive,
  });

  final void Function(int livestreamId, Map<String, dynamic> data)? onOpenLive;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _text(dynamic value, [String fallback = '']) {
    final String result = value?.toString().trim() ?? '';
    if (result.isEmpty || result.toLowerCase() == 'null') return fallback;
    return result;
  }

  String _image(dynamic value) {
    final String raw = _text(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _firstUsableMap(List<dynamic> values) {
    for (final dynamic value in values) {
      final Map<String, dynamic> map = _map(value);
      if (map.isNotEmpty) return map;
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _rocketOwner(
      Map<String, dynamic> data,
      Map<String, dynamic> nestedData,
      Map<String, dynamic> launch,
      Map<String, dynamic> room,
      ) {
    final Map<String, dynamic> owner = _firstUsableMap(<dynamic>[
      data['owner'],
      data['user'],
      data['host'],
      data['broadcaster'],
      data['receiver'],
      data['sender'],
      data['top1_user'],
      data['top_user'],
      nestedData['owner'],
      nestedData['user'],
      nestedData['host'],
      nestedData['broadcaster'],
      nestedData['receiver'],
      nestedData['sender'],
      launch['owner'],
      launch['user'],
      launch['host'],
      launch['broadcaster'],
      room['owner'],
      room['user'],
      room['host'],
      room['broadcaster'],
    ]);

    if (owner['user'] is Map) {
      return <String, dynamic>{
        ...owner,
        ..._map(owner['user']),
      };
    }

    if (owner['profile'] is Map) {
      return <String, dynamic>{
        ...owner,
        ..._map(owner['profile']),
      };
    }

    return owner;
  }

  String _eventId(Map<String, dynamic> data) {
    final Map<String, dynamic> nestedData = _map(data['data']);
    final Map<String, dynamic> launch = _map(
      data['launch'] ??
          data['rocket_launch'] ??
          nestedData['launch'] ??
          nestedData['rocket_launch'],
    );
    final Map<String, dynamic> room = _map(
      data['livestream'] ??
          data['room'] ??
          nestedData['livestream'] ??
          nestedData['room'] ??
          launch['livestream'] ??
          launch['room'],
    );

    final int livestreamId = _int(
      data['livestream_id'] ??
          data['stream_id'] ??
          data['live_stream_id'] ??
          data['live_id'] ??
          nestedData['livestream_id'] ??
          launch['livestream_id'] ??
          room['livestream_id'] ??
          room['stream_id'] ??
          room['id'],
    );

    return 'rocket_${<dynamic>[
      data['event_id'],
      data['launch_event_id'],
      data['rocket_event_id'],
      nestedData['event_id'],
      launch['event_id'],
      livestreamId,
      data['session_id'],
      data['level_no'],
      data['rocket_level_no'],
      data['timestamp'],
      data['created_at'],
    ].map((dynamic value) => value?.toString() ?? '').join('|')}';
  }

  int _displaySeconds(Map<String, dynamic> data) {
    final Map<String, dynamic> nestedData = _map(data['data']);
    final int seconds = _int(
      data['banner_seconds'] ??
          data['display_seconds'] ??
          data['duration_seconds'] ??
          nestedData['banner_seconds'] ??
          5,
    );
    return (seconds <= 0 ? 5 : seconds).clamp(3, 15).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final RocketController controller = Get.find<RocketController>();
    final GlobalLiveBannerQueueController queue = globalLiveBannerQueue();

    return Obx(() {
      final bool sourceVisible = controller.globalLaunchBannerVisible.value;
      final Map<String, dynamic> sourceData =
      Map<String, dynamic>.from(controller.globalLaunchData);

      if (sourceVisible && sourceData.isNotEmpty) {
        final String sourceId = _eventId(sourceData);
        if (!queue.hasSeen(sourceId)) {
          Future<void>.microtask(() {
            queue.enqueue(
              id: sourceId,
              type: GlobalLiveBannerType.rocket,
              payload: sourceData,
              displaySeconds: _displaySeconds(sourceData),
            );
          });
        }
      }

      final GlobalLiveBannerItem? item =
      queue.activeItem(GlobalLiveBannerType.rocket);
      if (item == null) return const SizedBox.shrink();

      final int slot = queue.slotOf(item.id);
      if (slot < 0) return const SizedBox.shrink();

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(item.payload);
      final Map<String, dynamic> nestedData = _map(data['data']);
      final Map<String, dynamic> launch = _map(
        data['launch'] ??
            data['rocket_launch'] ??
            nestedData['launch'] ??
            nestedData['rocket_launch'],
      );
      final Map<String, dynamic> rocket = _map(
        data['rocket'] ?? nestedData['rocket'] ?? launch['rocket'],
      );
      final Map<String, dynamic> level = _map(
        data['level'] ??
            data['rocket_level'] ??
            nestedData['level'] ??
            nestedData['rocket_level'] ??
            launch['level'] ??
            launch['rocket_level'] ??
            rocket['level'],
      );
      final Map<String, dynamic> room = _map(
        data['livestream'] ??
            data['room'] ??
            nestedData['livestream'] ??
            nestedData['room'] ??
            launch['livestream'] ??
            launch['room'],
      );
      final Map<String, dynamic> owner =
      _rocketOwner(data, nestedData, launch, room);

      final String ownerName = _text(
        owner['name'] ??
            owner['username'] ??
            owner['user_name'] ??
            owner['full_name'] ??
            data['owner_name'] ??
            data['host_name'] ??
            data['sender_name'],
        'Rocket Launcher',
      );

      final String ownerImage = _image(
        owner['profile_image'] ??
            owner['profile_image_url'] ??
            owner['profileImage'] ??
            owner['profileImageUrl'] ??
            owner['avatar'] ??
            owner['avatar_url'] ??
            owner['image'] ??
            owner['image_url'] ??
            data['profile_image'] ??
            data['owner_profile_image'] ??
            data['host_profile_image'],
      );

      final String rocketImage = _image(
        data['rocket_image'] ??
            data['rocket_image_url'] ??
            data['image'] ??
            nestedData['rocket_image'] ??
            nestedData['rocket_image_url'] ??
            launch['rocket_image'] ??
            launch['rocket_image_url'] ??
            rocket['rocket_image'] ??
            rocket['rocket_image_url'] ??
            rocket['image'] ??
            level['rocket_image'] ??
            level['rocket_image_url'] ??
            level['image'] ??
            level['show_image'],
      );

      final String roomTitle = _text(
        data['stream_title'] ??
            data['room_title'] ??
            nestedData['stream_title'] ??
            nestedData['room_title'] ??
            launch['stream_title'] ??
            room['stream_title'] ??
            room['stream_bte'] ??
            room['title'] ??
            room['name'],
        'LIN LIVE Room',
      );

      final int levelNo = _int(
        data['level_no'] ??
            data['rocket_level_no'] ??
            nestedData['level_no'] ??
            launch['level_no'] ??
            rocket['level_no'] ??
            level['level_no'] ??
            level['level'] ??
            level['id'],
      );

      final int livestreamId = _int(
        data['livestream_id'] ??
            data['stream_id'] ??
            data['live_stream_id'] ??
            data['live_id'] ??
            nestedData['livestream_id'] ??
            launch['livestream_id'] ??
            room['livestream_id'] ??
            room['stream_id'] ??
            room['id'],
      );

      bool sourceStillMatches() {
        final Map<String, dynamic> current =
        Map<String, dynamic>.from(controller.globalLaunchData);
        return current.isNotEmpty && _eventId(current) == item.id;
      }

      void completeItem() {
        queue.finish(item.id);
        if (sourceStillMatches()) {
          controller.finishGlobalLaunchBanner();
        }
      }

      void tapItem() {
        queue.finish(item.id);
        if (sourceStillMatches()) {
          controller.hideGlobalLaunchBanner();
        }

        if (onOpenLive != null) {
          onOpenLive!(livestreamId, data);
        }
      }

      return AnimatedPositioned(
        key: ValueKey<String>('rocket_position_${item.id}'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        top: MediaQuery.of(context).padding.top +
            globalBannerTopOffset(context) +
            globalBannerSlotOffset(context, slot),
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: ValueKey<String>('rocket_dismiss_${item.id}'),
            direction: DismissDirection.up,
            resizeDuration: const Duration(milliseconds: 220),
            onDismissed: (_) => completeItem(),
            child: SizedBox(
              height: globalBigGiftBannerHeight(context),
              child: _RightStayLeftRocketBanner(
                key: ValueKey<String>(item.id),
                ownerName: ownerName,
                ownerImage: ownerImage,
                rocketImage: rocketImage,
                roomTitle: roomTitle,
                levelNo: levelNo,
                displaySeconds: item.displaySeconds,
                onTap: tapItem,
                onCompleted: completeItem,
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Same enter -> stay -> exit timing used by GlobalLuckyWinBanner.
class _RightStayLeftRocketBanner extends StatefulWidget {
  const _RightStayLeftRocketBanner({
    super.key,
    required this.ownerName,
    required this.ownerImage,
    required this.rocketImage,
    required this.roomTitle,
    required this.levelNo,
    required this.displaySeconds,
    required this.onTap,
    required this.onCompleted,
  });

  final String ownerName;
  final String ownerImage;
  final String rocketImage;
  final String roomTitle;
  final int levelNo;
  final int displaySeconds;
  final VoidCallback onTap;
  final VoidCallback onCompleted;

  @override
  State<_RightStayLeftRocketBanner> createState() =>
      _RightStayLeftRocketBannerState();
}

class _RightStayLeftRocketBannerState
    extends State<_RightStayLeftRocketBanner>
    with SingleTickerProviderStateMixin {
  static const Duration _enterDuration = Duration(milliseconds: 560);
  static const Duration _exitDuration = Duration(milliseconds: 560);

  late final Duration _stayDuration;
  late final Duration _totalDuration;
  late final AnimationController _moveController;
  Timer? _countdownStartTimer;
  Timer? _countdownTimer;
  late int _secondsLeft;
  bool _completionSent = false;

  @override
  void initState() {
    super.initState();

    _secondsLeft = widget.displaySeconds;
    _stayDuration = Duration(seconds: widget.displaySeconds);
    _totalDuration = Duration(
      milliseconds: _enterDuration.inMilliseconds +
          _stayDuration.inMilliseconds +
          _exitDuration.inMilliseconds,
    );

    _moveController = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _finishBanner();
      }
    });

    _moveController.forward();

    _countdownStartTimer = Timer(_enterDuration, () {
      if (!mounted) return;

      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
            (Timer timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          if (_secondsLeft <= 1) {
            timer.cancel();
            return;
          }

          setState(() => _secondsLeft--);
        },
      );
    });
  }

  void _finishBanner() {
    if (_completionSent) return;
    _completionSent = true;
    _countdownStartTimer?.cancel();
    _countdownTimer?.cancel();
    widget.onCompleted();
  }

  @override
  void dispose() {
    _countdownStartTimer?.cancel();
    _countdownTimer?.cancel();
    _moveController.dispose();
    super.dispose();
  }

  double _positionForProgress({
    required double progress,
    required double startX,
    required double holdX,
    required double endX,
  }) {
    final double enterPart =
        _enterDuration.inMilliseconds / _totalDuration.inMilliseconds;
    final double stayPart =
        _stayDuration.inMilliseconds / _totalDuration.inMilliseconds;
    final double exitStart = enterPart + stayPart;

    if (progress <= enterPart) {
      final double local = (progress / enterPart).clamp(0.0, 1.0);
      final double eased = Curves.easeOutCubic.transform(local);
      return startX + ((holdX - startX) * eased);
    }

    if (progress <= exitStart) {
      return holdX;
    }

    final double local =
    ((progress - exitStart) / (1 - exitStart)).clamp(0.0, 1.0);
    final double eased = Curves.easeInCubic.transform(local);
    return holdX + ((endX - holdX) * eased);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool compact = screenWidth < 370;
        final double bannerWidth = globalBigGiftBannerWidth(screenWidth);
        final double holdX = (screenWidth - bannerWidth) / 2;
        final double startX = screenWidth + 22;
        final double endX = -bannerWidth - 22;

        return AnimatedBuilder(
          animation: _moveController,
          builder: (BuildContext context, Widget? child) {
            final double x = _positionForProgress(
              progress: _moveController.value,
              startX: startX,
              holdX: holdX,
              endX: endX,
            );

            return Transform.translate(
              offset: Offset(x, 0),
              child: child,
            );
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: bannerWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: _RocketLuckyStyleBannerCard(
                  compact: compact,
                  ownerName: widget.ownerName,
                  ownerImage: widget.ownerImage,
                  rocketImage: widget.rocketImage,
                  roomTitle: widget.roomTitle,
                  levelNo: widget.levelNo,
                  secondsLeft: _secondsLeft,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pixel-matched to the Lucky banner card:
/// - same background asset
/// - same height
/// - same avatar size
/// - same text positions
/// - same countdown position
/// - same GO button size
class _RocketLuckyStyleBannerCard extends StatelessWidget {
  const _RocketLuckyStyleBannerCard({
    required this.compact,
    required this.ownerName,
    required this.ownerImage,
    required this.rocketImage,
    required this.roomTitle,
    required this.levelNo,
    required this.secondsLeft,
  });

  static const String _backgroundAsset =
      'assets/audio_live/gift_float_default.svga';

  final bool compact;
  final String ownerName;
  final String ownerImage;
  final String rocketImage;
  final String roomTitle;
  final int levelNo;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final double cardHeight = globalBigGiftBannerHeight(context);
    final double avatarSize = compact ? 43 : 49;
    final double rocketSize = compact ? 43 : 49;

    return SizedBox(
      height: cardHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          const _RocketBannerSvgaBackground(),
          Padding(
            padding: EdgeInsets.only(
              left: compact ? 8 : 12,
              right: compact ? 8 : 12,
            ),
            child: Row(
              children: <Widget>[
                SizedBox(width: compact ? 18 : 28),
                Transform.translate(
                  offset: Offset(0, compact ? -3 : -5),
                  child: _RocketOwnerAvatar(
                    imageUrl: ownerImage,
                    size: avatarSize,
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 12.5 : 14.5,
                          fontWeight: FontWeight.w900,
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black87, blurRadius: 5),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        levelNo > 0
                            ? 'Rocket LV.$levelNo launched  •  $roomTitle'
                            : 'Rocket launched  •  $roomTitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xfffff1b2),
                          fontSize: compact ? 9.2 : 10.8,
                          fontWeight: FontWeight.w800,
                          shadows: const <Shadow>[
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: compact ? 28 : 34,
                  alignment: Alignment.center,
                  child: Text(
                    '$secondsLeft',
                    maxLines: 1,
                    style: TextStyle(
                      color: const Color(0xfffff4a6),
                      fontSize: compact ? 22 : 27,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: compact ? 1 : 3),
                Transform.translate(
                  offset: Offset(0, compact ? -3 : -5),
                  child: SizedBox(
                    width: rocketSize,
                    height: rocketSize,
                    child: rocketImage.isEmpty
                        ? const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xfffff16f),
                      size: 35,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black87, blurRadius: 5),
                      ],
                    )
                        : CachedNetworkImage(
                      imageUrl: rocketImage,
                      fit: BoxFit.contain,
                      fadeInDuration: Duration.zero,
                      filterQuality: FilterQuality.high,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.rocket_launch_rounded,
                        color: Color(0xfffff16f),
                        size: 35,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 2 : 4),
                Transform.translate(
                  offset: Offset(0, compact ? -3 : -5),
                  child: Container(
                    height: compact ? 43 : 49,
                    constraints: BoxConstraints(
                      minWidth: compact ? 48 : 57,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 7 : 10,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xffffef67),
                          Color(0xffff8a00),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xfffff6b7),
                        width: 1.2,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Colors.black38, blurRadius: 5),
                      ],
                    ),
                    child: Text(
                      'GO',
                      style: TextStyle(
                        color: const Color(0xff6b1a00),
                        fontSize: compact ? 12.5 : 14.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 24 : 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RocketBannerSvgaBackground extends StatefulWidget {
  const _RocketBannerSvgaBackground();

  static MovieEntity? _cachedMovie;
  static final Future<MovieEntity?> _loadingFuture = _loadMovie();

  static Future<MovieEntity?> _loadMovie() async {
    try {
      final movie = await SVGAParser.shared.decodeFromAssets(
        _RocketLuckyStyleBannerCard._backgroundAsset,
      );
      movie.autorelease = false;
      return _cachedMovie = movie;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Rocket global banner SVGA failed to load: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  @override
  State<_RocketBannerSvgaBackground> createState() =>
      _RocketBannerSvgaBackgroundState();
}

class _RocketBannerSvgaBackgroundState
    extends State<_RocketBannerSvgaBackground>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this)..isMute = true;
    _attachMovie();
  }

  Future<void> _attachMovie() async {
    final movie =
        _RocketBannerSvgaBackground._cachedMovie ??
        await _RocketBannerSvgaBackground._loadingFuture;
    if (!mounted || movie == null) return;
    _controller.videoItem = movie;
    _controller.repeat();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _ready
          ? SVGAImage(
              _controller,
              fit: BoxFit.fill,
              allowDrawingOverflow: false,
              preferredSize: Size(
                MediaQuery.sizeOf(context).width,
                globalBigGiftBannerHeight(context),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _RocketOwnerAvatar extends StatelessWidget {
  const _RocketOwnerAvatar({
    required this.imageUrl,
    required this.size,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: <Color>[Color(0xfffff18a), Color(0xffff7700)],
        ),
        border: Border.all(color: Colors.white, width: 1.15),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 6),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isEmpty
            ? Container(
          color: const Color(0xff4c536b),
          child: const Icon(Icons.person, color: Colors.white),
        )
            : CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          filterQuality: FilterQuality.high,
          placeholder: (_, __) => Container(color: Colors.white12),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xff4c536b),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
