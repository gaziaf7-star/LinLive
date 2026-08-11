import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/global_live_banner_queue_controller.dart';

class GlobalBigGiftBanner extends StatelessWidget {
  const GlobalBigGiftBanner({super.key, this.onOpenLive});

  static const String _backgroundAsset =
      'assets/audio_live/bigGiftBannerImage-removebg-preview.png';

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

  String _compactCoins(int value) {
    if (value >= 1000000) {
      final number = value / 1000000;
      return '${number == number.roundToDouble() ? number.toInt() : number.toStringAsFixed(1)}M';
    }
    final number = value / 1000;
    return '${number == number.roundToDouble() ? number.toInt() : number.toStringAsFixed(1)}K';
  }

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
      final value = _int(data['gift_value']);
      if (value < 100000) {
        Future<void>.microtask(() => queue.finish(item.id));
        return const SizedBox.shrink();
      }

      void finish() => queue.finish(item.id);

      return AnimatedPositioned(
        key: ValueKey<String>('big_gift_position_${item.id}'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        top: MediaQuery.of(context).padding.top + 7 + (slot * 150),
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
              height: 146,
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
                coinText: _compactCoins(value),
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
    required this.coinText,
    required this.onTap,
    required this.onCompleted,
  });

  final int displaySeconds;
  final String senderName;
  final String senderImage;
  final String giftImage;
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
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(
      milliseconds:
          _enterDuration.inMilliseconds +
          Duration(seconds: widget.displaySeconds).inMilliseconds +
          _exitDuration.inMilliseconds,
    );
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..forward();
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final double width = math.min(
          math.max(screenWidth * .92, 300.0),
          620.0,
        );
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
                  coinText: widget.coinText,
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
    required this.coinText,
  });

  final String senderName;
  final String senderImage;
  final String giftImage;
  final String coinText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage(GlobalBigGiftBanner._backgroundAsset),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(46, 38, 50, 34),
            child: Row(
              children: [
                _RoundImage(url: senderImage, size: 48, fallback: Icons.person),
                const SizedBox(width: 9),
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
                        'sent a $coinText gift',
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
                  size: 52,
                  fallback: Icons.card_giftcard,
                ),
              ],
            ),
          ),
        ],
      ),
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
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? placeholder
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
