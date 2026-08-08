
import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../controllers/global_live_banner_queue_controller.dart';
import '../controllers/livestream_controller.dart';


class GlobalLuckyWinBanner extends StatelessWidget {
  const GlobalLuckyWinBanner({
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
    return ImageHelper.getImageUrl(raw);
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _multiplier(dynamic value) {
    final double number = _double(value);
    if (number % 1 == 0) return number.toInt().toString();
    return number.toStringAsFixed(1);
  }

  String _compactCoin(dynamic value) {
    final int number = int.tryParse(value?.toString() ?? '') ?? 0;
    if (number >= 1000000000) {
      final double v = number / 1000000000;
      return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}B';
    }
    if (number >= 1000000) {
      final double v = number / 1000000;
      return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      final double v = number / 1000;
      return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}K';
    }
    return '$number';
  }

  String _eventId(Map<String, dynamic> data) {
    final double multiplier = _double(data['multiplier']);
    final int winAmount = int.tryParse(
      '${data['win_amount'] ?? data['back_coin'] ?? data['win_coin'] ?? 0}',
    ) ??
        0;

    return 'lucky_win_${<dynamic>[
      data['event_id'],
      data['result_event_id'],
      data['lucky_event_id'],
      data['livestream_id'],
      data['sender_id'],
      data['gift_id'],
      multiplier,
      winAmount,
      data['timestamp'],
      data['created_at'],
    ].map((dynamic value) => value?.toString() ?? '').join('|')}';
  }

  int _displaySeconds(Map<String, dynamic> data) {
    final int seconds = int.tryParse(
      '${data['banner_seconds'] ?? data['display_seconds'] ?? data['duration_seconds'] ?? 5}',
    ) ??
        5;
    return seconds.clamp(3, 15).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final LivestreamController controller = Get.find<LivestreamController>();
    final GlobalLiveBannerQueueController queue = globalLiveBannerQueue();

    return Obx(() {
      final bool sourceVisible = controller.globalLuckyWinBannerVisible.value;
      final Map<String, dynamic> sourceData =
      Map<String, dynamic>.from(controller.globalLuckyWinData);

      final double sourceMultiplier = _double(sourceData['multiplier']);
      final int sourceWinAmount = int.tryParse(
        '${sourceData['win_amount'] ?? sourceData['back_coin'] ?? sourceData['win_coin'] ?? 0}',
      ) ??
          0;

      if (sourceVisible &&
          sourceData.isNotEmpty &&
          sourceMultiplier >= 5 &&
          sourceWinAmount > 0) {
        final String sourceId = _eventId(sourceData);
        if (!queue.hasSeen(sourceId)) {
          Future<void>.microtask(() {
            queue.enqueue(
              id: sourceId,
              type: GlobalLiveBannerType.luckyWin,
              payload: sourceData,
              displaySeconds: _displaySeconds(sourceData),
            );
          });
        }
      }

      final GlobalLiveBannerItem? item =
      queue.activeItem(GlobalLiveBannerType.luckyWin);
      if (item == null) return const SizedBox.shrink();

      final Map<String, dynamic> data =
      Map<String, dynamic>.from(item.payload);
      final double multiplierNumber = _double(data['multiplier']);
      final int winAmount = int.tryParse(
        '${data['win_amount'] ?? data['back_coin'] ?? data['win_coin'] ?? 0}',
      ) ??
          0;

      if (multiplierNumber < 5 || winAmount <= 0) {
        Future<void>.microtask(() => queue.finish(item.id));
        return const SizedBox.shrink();
      }

      final int slot = queue.slotOf(item.id);
      if (slot < 0) return const SizedBox.shrink();

      final Map<String, dynamic> sender = _map(data['sender'] ?? data['user']);
      final Map<String, dynamic> gift = _map(data['gift']);
      final String senderName = _text(
        sender['name'] ?? sender['username'] ?? data['sender_name'],
        'Lucky Winner',
      );
      final String senderImage = _image(
        sender['profile_image'] ?? sender['avatar'] ?? sender['image'],
      );
      final String giftImage = _image(
        gift['show_image'] ?? gift['gift_image'] ?? gift['image'] ?? gift['icon'],
      );
      final String multiplier = _multiplier(multiplierNumber);
      final String winCoins = _compactCoin(winAmount);

      void finishItem() {
        queue.finish(item.id);

        final Map<String, dynamic> current =
        Map<String, dynamic>.from(controller.globalLuckyWinData);
        if (current.isNotEmpty && _eventId(current) == item.id) {
          controller.hideGlobalLuckyWinBanner();
        }
      }

      return AnimatedPositioned(
        key: ValueKey<String>('lucky_win_position_${item.id}'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        top: MediaQuery.of(context).padding.top + 7 + (slot * 150),
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: ValueKey<String>('lucky_win_dismiss_${item.id}'),
            direction: DismissDirection.up,
            resizeDuration: const Duration(milliseconds: 220),
            onDismissed: (_) => finishItem(),
            child: SizedBox(
              height: 146,
              child: _RightStayLeftLuckyBanner(
                key: ValueKey<String>(item.id),
                senderName: senderName,
                senderImage: senderImage,
                giftImage: giftImage,
                multiplier: multiplier,
                winCoins: winCoins,
                displaySeconds: item.displaySeconds,
                onTap: () {
                  final int livestreamId = int.tryParse(
                    '${data['livestream_id'] ?? data['stream_id'] ?? data['live_stream_id'] ?? data['live_id'] ?? 0}',
                  ) ??
                      0;

                  finishItem();

                  if (onOpenLive != null) {
                    onOpenLive!(livestreamId, data);
                    return;
                  }

                  controller.openGlobalLuckyWinRoom(data);
                },
                onCompleted: finishItem,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _RightStayLeftLuckyBanner extends StatefulWidget {
  const _RightStayLeftLuckyBanner({
    super.key,
    required this.senderName,
    required this.senderImage,
    required this.giftImage,
    required this.multiplier,
    required this.winCoins,
    required this.displaySeconds,
    required this.onTap,
    required this.onCompleted,
  });

  final String senderName;
  final String senderImage;
  final String giftImage;
  final String multiplier;
  final String winCoins;
  final int displaySeconds;
  final VoidCallback onTap;
  final VoidCallback onCompleted;

  @override
  State<_RightStayLeftLuckyBanner> createState() =>
      _RightStayLeftLuckyBannerState();
}

class _RightStayLeftLuckyBannerState
    extends State<_RightStayLeftLuckyBanner>
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
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishBanner();
      }
    });

    _moveController.forward();

    // Countdown starts only after the banner has fully entered and stopped.
    _countdownStartTimer = Timer(_enterDuration, () {
      if (!mounted) return;
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsLeft <= 1) {
          timer.cancel();
          return;
        }

        setState(() => _secondsLeft--);
      });
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
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool compact = screenWidth < 370;
        final double bannerWidth = math.min(
          math.max(screenWidth * (compact ? .965 : .92), 300),
          620,
        );
        final double holdX = (screenWidth - bannerWidth) / 2;
        final double startX = screenWidth + 22;
        final double endX = -bannerWidth - 22;

        return AnimatedBuilder(
          animation: _moveController,
          builder: (context, child) {
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
                child: _LuckyBannerCard(
                  compact: compact,
                  senderName: widget.senderName,
                  senderImage: widget.senderImage,
                  giftImage: widget.giftImage,
                  multiplier: widget.multiplier,
                  winCoins: widget.winCoins,
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

class _LuckyBannerCard extends StatelessWidget {
  const _LuckyBannerCard({
    required this.compact,
    required this.senderName,
    required this.senderImage,
    required this.giftImage,
    required this.multiplier,
    required this.winCoins,
    required this.secondsLeft,
  });

  static const String _backgroundAsset =
      'assets/audio_live/broadcast_gift_1781905442_6a35b82260a4d.webp';

  final bool compact;
  final String senderName;
  final String senderImage;
  final String giftImage;
  final String multiplier;
  final String winCoins;
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final double cardHeight = compact ? 124 : 140;
    final double avatarSize = compact ? 43 : 49;

    return Container(
      height: cardHeight,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_backgroundAsset),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
              left: compact ? 8 : 12,
              right: compact ? 8 : 12,
            ),
            child: Row(
              children: <Widget>[
                // Profile-ta background image-er vitore ektu right side-e.
                SizedBox(width: compact ? 18 : 28),
                Transform.translate(
                  offset: Offset(0, compact ? -3 : -5),
                  child: _WinnerAvatar(
                    imageUrl: senderImage,
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
                        senderName,
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
                        'Won ${multiplier}X  •  +$winCoins coins',
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
                // Countdown আর GO-এর নিচে নয়; multiplier/gun-এর বাঁ পাশে বড় করে।
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
                Text(
                  'x$multiplier',
                  style: TextStyle(
                    color: const Color(0xfffff16f),
                    fontSize: compact ? 17 : 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.black87, blurRadius: 5),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 2 : 4),
                Transform.translate(
                  offset: Offset(0, compact ? -3 : -5),
                  child: Container(
                    height: compact ? 43 : 49,
                    constraints: BoxConstraints(minWidth: compact ? 48 : 57),
                    padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10),
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
                // GO button-ta right edge theke ektu left side-e.
                SizedBox(width: compact ? 24 : 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerAvatar extends StatelessWidget {
  const _WinnerAvatar({
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

class _LuckySparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withOpacity(.34);
    const List<Offset> points = <Offset>[
      Offset(.28, .22),
      Offset(.42, .72),
      Offset(.64, .20),
      Offset(.78, .70),
      Offset(.90, .30),
    ];
    for (final Offset point in points) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        1.35,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
