import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/global_live_banner_queue_controller.dart';
import 'global_banner_layout.dart';

class GlobalBigGiftBanner extends StatelessWidget {
  const GlobalBigGiftBanner({super.key, this.onOpenLive});

  static const String _backgroundAsset =
      'assets/audio_live/broadcast_gift_1781905442_6a35b82260a4d.webp';

  final void Function(int livestreamId, Map<String, dynamic> data)? onOpenLive;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _image(dynamic value) {
    final raw = _text(value);
    return raw.isEmpty ? '' : ImageHelper.getImageUrl(raw);
  }

  String _coinText(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')} Coins';

  @override
  Widget build(BuildContext context) {
    final GlobalLiveBannerQueueController queue = globalLiveBannerQueue();
    return Obx(() {
      final item = queue.activeItem(GlobalLiveBannerType.bigGift);
      if (item == null) return const SizedBox.shrink();
      final slot = queue.slotOf(item.id);
      if (slot < 0) return const SizedBox.shrink();

      final data = Map<String, dynamic>.from(item.payload);
      final sender = _map(data['sender']);
      final gift = _map(data['gift']);
      final unitCoin = _int(
        data['unit_coin'] ?? data['unit_gift_coin'] ?? gift['coin'],
      );
      final quantity = _int(data['quantity']).clamp(1, 1000);
      final value = _int(
        data['batch_total'] ??
            data['gift_value'] ??
            (unitCoin > 0 ? unitCoin * quantity : 0),
      );
      if (value < 100000) {
        Future<void>.microtask(() => queue.finish(item.id));
        return const SizedBox.shrink();
      }

      void finish() => queue.finish(item.id);

      return AnimatedPositioned(
        key: ValueKey<String>('big_gift_position_${item.id}'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        top: MediaQuery.of(context).padding.top +
            globalBannerTopOffset(context) +
            globalBannerSlotOffset(context, slot) +
            10.0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: ValueKey<String>('big_gift_dismiss_${item.id}'),
            direction: DismissDirection.up,
            resizeDuration: const Duration(milliseconds: 220),
            onDismissed: (_) => finish(),
            child: SizedBox(
              height: globalBigGiftBannerHeight(context),
              child: _BigGiftMotion(
                key: ValueKey<String>(item.id),
                displaySeconds: item.displaySeconds,
                senderName: _text(
                  sender['name'] ?? sender['username'],
                  'Someone',
                ),
                senderImage: _image(
                  sender['profile_image'] ??
                      sender['profile_image_url'] ??
                      sender['avatar'] ??
                      sender['image'],
                ),
                giftImage: _image(
                  gift['show_image'] ??
                      gift['gift_image'] ??
                      gift['image'] ??
                      gift['icon'],
                ),
                giftName: _text(gift['name'] ?? gift['gift_name'], 'gift'),
                coinText: _coinText(value),
                onTap: () {
                  final livestreamId = _int(
                    data['livestream_id'] ?? data['stream_id'],
                  );
                  finish();
                  onOpenLive?.call(livestreamId, data);
                },
                onCompleted: finish,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _BigGiftMotion extends StatefulWidget {
  const _BigGiftMotion({
    super.key,
    required this.displaySeconds,
    required this.senderName,
    required this.senderImage,
    required this.giftImage,
    required this.giftName,
    required this.coinText,
    required this.onTap,
    required this.onCompleted,
  });

  final int displaySeconds;
  final String senderName;
  final String senderImage;
  final String giftImage;
  final String giftName;
  final String coinText;
  final VoidCallback onTap;
  final VoidCallback onCompleted;

  @override
  State<_BigGiftMotion> createState() => _BigGiftMotionState();
}

class _BigGiftMotionState extends State<_BigGiftMotion>
    with SingleTickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 560);
  static const _exitDuration = Duration(milliseconds: 560);
  late final AnimationController _controller;
  late final Duration _totalDuration;
  late final ValueNotifier<int> _secondsLeft;
  bool _completed = false;
  bool _sizeLogged = false;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(
      milliseconds:
      _enterDuration.inMilliseconds +
          Duration(seconds: widget.displaySeconds).inMilliseconds +
          _exitDuration.inMilliseconds,
    );
    _secondsLeft = ValueNotifier<int>(widget.displaySeconds);
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addListener(_updateCountdown)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
  }

  void _updateCountdown() {
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final displayElapsedMs = math.max(
      0,
      elapsed.inMilliseconds - _enterDuration.inMilliseconds,
    );
    final remainingMs = math.max(
      0,
      Duration(seconds: widget.displaySeconds).inMilliseconds -
          displayElapsedMs,
    );
    final next = (remainingMs / Duration.millisecondsPerSecond).ceil();
    if (_secondsLeft.value != next) _secondsLeft.value = next;
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    widget.onCompleted();
  }

  double _x(double progress, double width, double screenWidth) {
    final enter = _enterDuration.inMilliseconds / _totalDuration.inMilliseconds;
    final stay =
        Duration(seconds: widget.displaySeconds).inMilliseconds /
            _totalDuration.inMilliseconds;
    final exitStart = enter + stay;
    final hold = (screenWidth - width) / 2;
    if (progress <= enter) {
      final t = Curves.easeOutCubic.transform((progress / enter).clamp(0, 1));
      return screenWidth + 22 + (hold - screenWidth - 22) * t;
    }
    if (progress <= exitStart) return hold;
    final t = Curves.easeInCubic.transform(
      ((progress - exitStart) / (1 - exitStart)).clamp(0, 1),
    );
    return hold + (-width - 22 - hold) * t;
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCountdown);
    _controller.dispose();
    _secondsLeft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final requestedHeight = globalBigGiftBannerHeight(context);
        final screenWidth = constraints.maxWidth;
        final bool compact = screenWidth < 370;
        final double width = globalBigGiftBannerWidth(screenWidth);
        if (!_sizeLogged) {
          _sizeLogged = true;
          final parentMaxHeight = constraints.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final box = this.context.findRenderObject();
            final renderedHeight = box is RenderBox ? box.size.height : -1.0;
            debugPrint(
              '[BIG_GIFT_UI][SIZE] width=$width '
                  'height=$renderedHeight requested_height=$requestedHeight '
                  'parent_max_height=$parentMaxHeight '
                  'requested_width=$width',
            );
          });
        }
        return AnimatedBuilder(
          animation: _controller,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: width,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: _BigGiftCard(
                  senderName: widget.senderName,
                  senderImage: widget.senderImage,
                  giftImage: widget.giftImage,
                  giftName: widget.giftName,
                  coinText: widget.coinText,
                  secondsLeft: _secondsLeft,
                  compact: compact,
                ),
              ),
            ),
          ),
          builder: (_, child) => Transform.translate(
            offset: Offset(_x(_controller.value, width, screenWidth), 0),
            child: child,
          ),
        );
      },
    );
  }
}

class _BigGiftCard extends StatelessWidget {
  const _BigGiftCard({
    required this.senderName,
    required this.senderImage,
    required this.giftImage,
    required this.giftName,
    required this.coinText,
    required this.secondsLeft,
    required this.compact,
  });

  final String senderName;
  final String senderImage;
  final String giftImage;
  final String giftName;
  final String coinText;
  final ValueListenable<int> secondsLeft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: globalBigGiftBannerHeight(context),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Image.asset(
            GlobalBigGiftBanner._backgroundAsset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 58 : 64,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RoundImage(
                  url: senderImage,
                  size: compact ? 35 : 39,
                  fallback: Icons.person,
                ),
                SizedBox(width: compact ? 7 : 9),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                      Text(
                        'sent $giftName · $coinText',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xffffef9d),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundImage(
                  url: giftImage,
                  size: compact ? 42 : 44,
                  fallback: Icons.card_giftcard,
                ),
                const SizedBox(width: 5),
                ValueListenableBuilder<int>(
                  valueListenable: secondsLeft,
                  builder: (context, seconds, _) => Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .42),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Text(
                      '${seconds}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigGiftSvgaBackground extends StatefulWidget {
  const _BigGiftSvgaBackground();

  static MovieEntity? _cachedMovie;
  static final Future<MovieEntity?> _loadingFuture = _loadMovie();

  static Future<MovieEntity?> _loadMovie() async {
    try {
      final movie = await SVGAParser.shared.decodeFromAssets(
        GlobalBigGiftBanner._backgroundAsset,
      );
      movie.autorelease = false;
      return _cachedMovie = movie;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Big gift banner SVGA failed to load: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  @override
  State<_BigGiftSvgaBackground> createState() =>
      _BigGiftSvgaBackgroundState();
}

class _BigGiftSvgaBackgroundState extends State<_BigGiftSvgaBackground>
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
        _BigGiftSvgaBackground._cachedMovie ??
            await _BigGiftSvgaBackground._loadingFuture;
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

class _RoundImage extends StatelessWidget {
  const _RoundImage({
    required this.url,
    required this.size,
    required this.fallback,
  });

  final String url;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: Icon(fallback, color: Colors.white),
    );
    final isSvga = url.toLowerCase().split('?').first.endsWith('.svga');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? placeholder
            : isSvga
            ? SVGAEasyPlayer(
          key: ValueKey<String>('big_gift_icon_$url'),
          resUrl: url.startsWith('http://') || url.startsWith('https://')
              ? url
              : null,
          assetsName:
          url.startsWith('http://') || url.startsWith('https://')
              ? null
              : url,
          fit: BoxFit.cover,
        )
            : CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
              .round(),
          fadeInDuration: Duration.zero,
          placeholder: (context, url) => placeholder,
          errorWidget: (context, url, error) => placeholder,
        ),
      ),
    );
  }
}
