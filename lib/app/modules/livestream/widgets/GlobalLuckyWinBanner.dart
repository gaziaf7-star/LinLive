import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/global_live_banner_queue_controller.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/red_packet_controller.dart';
import '../socket/websocket_controller.dart';
import 'global_banner_layout.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

void _globalLuckyBagDebugPrint(String title, dynamic data) {
  try {
    final String text = data is String
        ? data
        : const JsonEncoder.withIndent('  ').convert(data);

    debugPrint('');
    debugPrint('================ $title ================');

    const int chunkSize = 800;
    for (int index = 0; index < text.length; index += chunkSize) {
      final int end = index + chunkSize < text.length
          ? index + chunkSize
          : text.length;
      debugPrint(text.substring(index, end));
    }

    debugPrint('================ END $title ================');
    debugPrint('');
  } catch (error) {
    debugPrint('GLOBAL LUCKY BAG DEBUG ERROR [$title] => $error');
    debugPrint(data?.toString() ?? 'null');
  }
}

class GlobalLuckyBagBanner extends StatelessWidget {
  const GlobalLuckyBagBanner({
    super.key,
    this.topPadding = 8,
    this.left = 25,
    this.right = 25,
    this.bannerAssetPath = 'assets/flaticons/redpoketbanner.png',
    this.bannerImageUrl,
    this.onOpenLive,
  });

  final double topPadding;
  final double left;
  final double right;
  final String bannerAssetPath;
  final String? bannerImageUrl;
  final void Function(int livestreamId, Map<String, dynamic> packet)? onOpenLive;

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.toInt() ??
        0;
  }

  String _safeText(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  String _senderName(Map<String, dynamic> packet) {
    final sender = packet['sender'];
    if (sender is Map) {
      return _safeText(
        sender['name'] ?? sender['username'] ?? sender['full_name'],
        'Someone',
      );
    }

    return _safeText(
      packet['sender_name'] ?? packet['name'] ?? packet['username'],
      'Someone',
    );
  }

  String _senderImage(Map<String, dynamic> packet) {
    final sender = packet['sender'];
    dynamic raw;

    if (sender is Map) {
      raw = sender['profile_image_url'] ??
          sender['profile_image'] ??
          sender['image_url'] ??
          sender['avatar'] ??
          sender['image'];
    } else {
      raw = packet['profile_image_url'] ??
          packet['profile_image'] ??
          packet['sender_image'] ??
          packet['image_url'] ??
          packet['avatar'];
    }

    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    return ImageHelper.getImageUrl(text);
  }

  int _amount(Map<String, dynamic> packet) {
    return _safeInt(
      packet['amount'] ??
          packet['coins'] ??
          packet['coin'] ??
          packet['total_coins'] ??
          packet['total_coin'],
    );
  }

  int _livestreamId(Map<String, dynamic> packet) {
    return _safeInt(
      packet['livestream_id'] ??
          packet['live_stream_id'] ??
          packet['stream_id'] ??
          packet['room_id'],
    );
  }

  int _packetId(Map<String, dynamic> packet) {
    return _safeInt(packet['id'] ?? packet['red_packet_id'] ?? packet['packet_id']);
  }

  int _fastestOpenSeconds(Map<String, dynamic> packet) {
    final candidates = <int>[
      _safeInt(packet['unlock_after_seconds']),
      _safeInt(packet['open_after_seconds']),
      _safeInt(packet['unlock_after']),
      _safeInt(packet['open_after']),
    ].where((e) => e > 0).toList()
      ..sort();

    return candidates.isNotEmpty ? candidates.first : 30;
  }

  String _coinLine(int amount) {
    if (amount <= 0) return ('Lucky Bag').appTr;
    return '${_compactNumber(amount)} coins Lucky Bag';
  }

  String _compactNumber(int value) {
    if (value >= 1000000000) {
      final result = value / 1000000000;
      return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      final result = value / 1000000;
      return '${result.toStringAsFixed(result >= 10 ? 0 : 1)}M';
    }
    if (value >= 100000) {
      final result = value / 1000;
      return '${result.toStringAsFixed(0)}K';
    }
    return value.toString();
  }

  void _openLuckyBagRoom({
    required RedPacketController controller,
    required int livestreamId,
    required Map<String, dynamic> packet,
  }) {
    _globalLuckyBagDebugPrint('GLOBAL LUCKY BAG BANNER TAP', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'target_livestream_id': livestreamId,
      'packet': packet,
    });

    if (livestreamId <= 0) {
      Fluttertoast.showToast(
        msg: ('Live room not found').appTr,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
      return;
    }

    final int fastOpenAfter = _fastestOpenSeconds(packet);
    final seededPacket = <String, dynamic>{
      ...packet,
      'id': _packetId(packet),
      'red_packet_id': _packetId(packet),
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'open_after_seconds': fastOpenAfter,
      'unlock_after_seconds': fastOpenAfter,
      'event_received_at_ms':
      packet['event_received_at_ms'] ?? DateTime.now().millisecondsSinceEpoch,
    };

    _globalLuckyBagDebugPrint('GLOBAL LUCKY BAG SEEDED PACKET', <String, dynamic>{
      'local_time': DateTime.now().toIso8601String(),
      'local_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      'fast_open_after_seconds': fastOpenAfter,
      'seeded_packet': seededPacket,
    });

    try {
      if (Get.isRegistered<WebsocketController>()) {
        final ws = Get.find<WebsocketController>();
        ws.currentRedPacket.value = seededPacket;
        ws.redPacketVisible.value = true;
        ws.currentRedPacket.refresh();
      }
    } catch (_) {}

    if (onOpenLive != null) {
      onOpenLive!(livestreamId, seededPacket);
      return;
    }

    Fluttertoast.showToast(
      msg: ('Please connect live room open function').appTr,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  String _eventId(Map<String, dynamic> packet) {
    final int packetId = _packetId(packet);
    if (packetId > 0) return 'lucky_bag_$packetId';

    final dynamic sender = packet['sender'];
    final dynamic senderId = sender is Map
        ? (sender['id'] ?? sender['user_id'])
        : (packet['sender_id'] ?? packet['user_id']);

    return 'lucky_bag_${<dynamic>[
      packet['event_id'],
      packet['red_packet_event_id'],
      packet['livestream_id'],
      packet['stream_id'],
      senderId,
      _amount(packet),
      packet['timestamp'],
      packet['created_at'],
      packet['event_received_at_ms'],
    ].map((dynamic value) => value?.toString() ?? '').join('|')}';
  }

  int _displaySeconds(
      Map<String, dynamic> packet,
      int controllerSeconds,
      ) {
    final int payloadSeconds = _safeInt(
      packet['banner_seconds'] ??
          packet['display_seconds'] ??
          packet['duration_seconds'],
    );

    if (payloadSeconds > 0) return payloadSeconds.clamp(3, 15).toInt();
    if (controllerSeconds > 0) return controllerSeconds.clamp(3, 15).toInt();
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final RedPacketController controller =
        Get.find<LivestreamController>().redPacketController;
    final GlobalLiveBannerQueueController queue = globalLiveBannerQueue();

    return Obx(() {
      final bool sourceVisible = controller.globalLuckyBagBannerVisible.value;
      final Map<String, dynamic> sourcePacket =
      Map<String, dynamic>.from(controller.globalLuckyBagData);
      final int sourceSeconds =
      controller.globalLuckyBagBannerSeconds.value.clamp(0, 999).toInt();

      if (sourceVisible && sourcePacket.isNotEmpty) {
        final String sourceId = _eventId(sourcePacket);
        if (!queue.hasSeen(sourceId)) {
          final int displaySeconds =
          _displaySeconds(sourcePacket, sourceSeconds);
          Future<void>.microtask(() {
            queue.enqueue(
              id: sourceId,
              type: GlobalLiveBannerType.luckyBag,
              payload: <String, dynamic>{
                ...sourcePacket,
                '_queue_display_seconds': displaySeconds,
              },
              displaySeconds: displaySeconds,
            );
          });
        }
      }

      final GlobalLiveBannerItem? item =
      queue.activeItem(GlobalLiveBannerType.luckyBag);
      if (item == null) return const SizedBox.shrink();

      final int slot = queue.slotOf(item.id);
      if (slot < 0) return const SizedBox.shrink();

      final Map<String, dynamic> packet =
      Map<String, dynamic>.from(item.payload);
      final String senderName = _senderName(packet);
      final String senderImage = _senderImage(packet);
      final int amount = _amount(packet);
      final int livestreamId = _livestreamId(packet);

      bool sourceStillMatches() {
        final Map<String, dynamic> current =
        Map<String, dynamic>.from(controller.globalLuckyBagData);
        return current.isNotEmpty && _eventId(current) == item.id;
      }

      void finishItem() {
        queue.finish(item.id);
        if (sourceStillMatches()) {
          controller.hideGlobalLuckyBagBanner();
        }
      }

      void openItem() {
        queue.finish(item.id);
        if (sourceStillMatches()) {
          controller.hideGlobalLuckyBagBanner();
        }

        _openLuckyBagRoom(
          controller: controller,
          livestreamId: livestreamId,
          packet: packet,
        );
      }

      return AnimatedPositioned(
        key: ValueKey<String>('lucky_bag_position_${item.id}'),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        top: MediaQuery.of(context).padding.top +
            globalLuckyBannerTopOffset(context) +
            globalBannerSlotOffset(context, slot),
        left: left,
        right: right,
        child: Material(
          color: Colors.transparent,
          child: Dismissible(
            key: ValueKey<String>('lucky_bag_dismiss_${item.id}'),
            direction: DismissDirection.up,
            resizeDuration: const Duration(milliseconds: 220),
            onDismissed: (_) => finishItem(),
            child: _QueuedLuckyBagMotion(
              key: ValueKey<String>(item.id),
              displaySeconds: item.displaySeconds,
              senderName: senderName,
              senderImage: senderImage,
              coinLine: _coinLine(amount),
              bannerAssetPath: bannerAssetPath,
              bannerImageUrl: bannerImageUrl,
              onTap: openItem,
              onCompleted: finishItem,
            ),
          ),
        ),
      );
    });
  }
}


class _QueuedLuckyBagMotion extends StatefulWidget {
  const _QueuedLuckyBagMotion({
    super.key,
    required this.displaySeconds,
    required this.senderName,
    required this.senderImage,
    required this.coinLine,
    required this.bannerAssetPath,
    required this.bannerImageUrl,
    required this.onTap,
    required this.onCompleted,
  });

  final int displaySeconds;
  final String senderName;
  final String senderImage;
  final String coinLine;
  final String bannerAssetPath;
  final String? bannerImageUrl;
  final VoidCallback onTap;
  final VoidCallback onCompleted;

  @override
  State<_QueuedLuckyBagMotion> createState() => _QueuedLuckyBagMotionState();
}

class _QueuedLuckyBagMotionState extends State<_QueuedLuckyBagMotion>
    with SingleTickerProviderStateMixin {
  static const Duration _enterDuration = Duration(milliseconds: 560);
  static const Duration _exitDuration = Duration(milliseconds: 560);

  late final Duration _stayDuration;
  late final Duration _totalDuration;
  late final AnimationController _moveController;
  late int _secondsLeft;
  Timer? _countdownStartTimer;
  Timer? _countdownTimer;
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
    required double width,
  }) {
    final double enterPart =
        _enterDuration.inMilliseconds / _totalDuration.inMilliseconds;
    final double stayPart =
        _stayDuration.inMilliseconds / _totalDuration.inMilliseconds;
    final double exitStart = enterPart + stayPart;

    if (progress <= enterPart) {
      final double local = (progress / enterPart).clamp(0.0, 1.0);
      final double eased = Curves.easeOutCubic.transform(local);
      return (width + 22) * (1 - eased);
    }

    if (progress <= exitStart) return 0;

    final double local =
    ((progress - exitStart) / (1 - exitStart)).clamp(0.0, 1.0);
    final double eased = Curves.easeInCubic.transform(local);
    return (-width - 22) * eased;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double bannerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 20;
        final double bannerHeight =
        (bannerWidth * 0.205).clamp(58.0, 72.0).toDouble();

        return AnimatedBuilder(
          animation: _moveController,
          builder: (BuildContext context, Widget? child) {
            return Transform.translate(
              offset: Offset(
                _positionForProgress(
                  progress: _moveController.value,
                  width: bannerWidth,
                ),
                0,
              ),
              child: child,
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTap,
            child: SizedBox(
              height: (globalLuckyVisibleBannerHeight(context) - 10.0)
                  .clamp(48.0, double.infinity),
              width: bannerWidth,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: <Widget>[
                  _LuckyBagBannerBackground(
                    assetPath: widget.bannerAssetPath,
                    imageUrl: widget.bannerImageUrl,
                  ),
                  _LuckyBagAvatarPositioned(
                    imageUrl: widget.senderImage,
                    bannerWidth: bannerWidth,
                    bannerHeight: bannerHeight,
                  ),
                  _LuckyBagTextPositioned(
                    senderName: widget.senderName,
                    coinLine: widget.coinLine,
                    bannerWidth: bannerWidth,
                    bannerHeight: bannerHeight,
                  ),
                  _LuckyBagSecondsPositioned(
                    seconds: _secondsLeft,
                    bannerWidth: bannerWidth,
                    bannerHeight: bannerHeight,
                  ),
                  _LuckyBagGoPositioned(
                    bannerWidth: bannerWidth,
                    bannerHeight: bannerHeight,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LuckyBagBannerBackground extends StatelessWidget {
  const _LuckyBagBannerBackground({
    required this.assetPath,
    required this.imageUrl,
  });

  final String assetPath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';

    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Image.asset(
      assetPath,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _LuckyBagAvatarPositioned extends StatelessWidget {
  const _LuckyBagAvatarPositioned({
    required this.imageUrl,
    required this.bannerWidth,
    required this.bannerHeight,
  });

  final String imageUrl;
  final double bannerWidth;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    final double size = (bannerHeight * 0.48).clamp(30.0, 36.0).toDouble();
    final double left = bannerWidth * 0.082;
    final double top = (bannerHeight - size) / 2;

    return Positioned(
      left: left,
      top: top + 4.0,
      child: SizedBox(
        height: size,
        width: size,
        child: ClipOval(
          child: imageUrl.isEmpty
              ? Container(
            color: Colors.black.withOpacity(0.10),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          )
              : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black.withOpacity(0.10),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuckyBagTextPositioned extends StatelessWidget {
  const _LuckyBagTextPositioned({
    required this.senderName,
    required this.coinLine,
    required this.bannerWidth,
    required this.bannerHeight,
  });

  final String senderName;
  final String coinLine;
  final double bannerWidth;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    final double left = bannerWidth * 0.198;
    final double right = bannerWidth * 0.415;


    return Positioned(
      left: left,
      right: right,
      top: kHeight*0.052,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: (bannerHeight * 0.185).clamp(11.8, 14.0).toDouble(),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(height: bannerHeight * 0.061),
          Text(
            coinLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: (bannerHeight * 0.158).clamp(10.5, 12.2).toDouble(),
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LuckyBagSecondsPositioned extends StatelessWidget {
  const _LuckyBagSecondsPositioned({
    required this.seconds,
    required this.bannerWidth,
    required this.bannerHeight,
  });

  final int seconds;
  final double bannerWidth;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    final double size = (bannerHeight * 0.44).clamp(30.0, 35.0).toDouble();
    final double goWidth = (bannerWidth * 0.118).clamp(46.0, 56.0).toDouble();
    final double goRight = bannerWidth * 0.025;
    final double right = goRight + goWidth + (bannerWidth * 0.102);
    final double top = (bannerHeight - size) / 2;

    return Positioned(
      right: kHeight*0.15,
      top: kHeight*0.05,
      child: Container(
        height: size,
        width: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xffef4028),
          border: Border.all(color: Colors.white, width: 1.8),
        ),
        child: Text(
          '$seconds',
          maxLines: 1,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: seconds > 99 ? size * 0.32 : size * 0.44,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _LuckyBagGoPositioned extends StatelessWidget {
  const _LuckyBagGoPositioned({
    required this.bannerWidth,
    required this.bannerHeight,
  });

  final double bannerWidth;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    final double height = (bannerHeight * 0.325).clamp(23.0, 28.0).toDouble();
    final double width = (bannerWidth * 0.098).clamp(38.0, 47.0).toDouble();
    final double right = bannerWidth * 0.005;
    final double top = (bannerHeight - height) / 2;

    return Positioned(
      right: -kHeight*0.015,
      top: top + 4.0,
      child: Container(
        height: height,
        width: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xffffcf2e),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          ('Go').appTr,
          style: GoogleFonts.poppins(
            color: const Color(0xff442300),
            fontSize: (bannerHeight * 0.145).clamp(9.8, 11.4).toDouble(),
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
