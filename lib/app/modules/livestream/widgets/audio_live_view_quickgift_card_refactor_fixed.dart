import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/livestream_controller.dart';

/// Fixed Lucky Combo button.
/// No pulse/zoom animation is used, so rapid taps stay responsive and stable.
/// Every tap is accepted and queued by LivestreamController.
class QuickGiftRocketCard extends StatelessWidget {
  final LivestreamController liveController;

  const QuickGiftRocketCard({
    super.key,
    required this.liveController,
  });

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _giftImage() {
    final gift = _map(liveController.quickGiftData['gift']);
    final raw = (gift['show_image'] ??
        gift['gift_image'] ??
        gift['image'] ??
        gift['icon'] ??
        gift['thumbnail'] ??
        '')
        .toString()
        .trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';
    return ImageHelper.getImageUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!liveController.quickGiftVisible.value) {
        return const SizedBox.shrink();
      }

      final int seconds =
      liveController.quickGiftCountdown.value.clamp(0, 7).toInt();
      final int combo = liveController.quickGiftComboCount.value <= 0
          ? 1
          : liveController.quickGiftComboCount.value;
      final String image = _giftImage();

      return Positioned(
        right: 14,
        bottom: 82,
        child: SafeArea(
          top: false,
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: liveController.sendQuickGiftAgain,
              child: SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: CircularProgressIndicator(
                        value: seconds / 7,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withOpacity(.36),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xfffff39a),
                        ),
                      ),
                    ),
                    Container(
                      width: 94,
                      height: 94,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-.25, -.30),
                          radius: 1.1,
                          colors: [
                            Color(0xffff8448),
                            Color(0xffff563b),
                            Color(0xffef3b2d),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white,
                          width: 3.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xaa000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Color(0x99ff6b35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 8,
                            right: 12,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(.24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.75),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$seconds',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          if (image.isNotEmpty)
                            Positioned(
                              left: 8,
                              top: 8,
                              child: CachedNetworkImage(
                                imageUrl: image,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                useOldImageOnUrlChange: true,
                                placeholder: (_, __) =>
                                const SizedBox(width: 28, height: 28),
                                errorWidget: (_, __, ___) =>
                                const SizedBox(width: 28, height: 28),
                              ),
                            ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 7),
                              Text(
                                'x$combo',
                                key: ValueKey<int>(combo),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xaa9b210d),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Combo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xaa9b210d),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      );
    });
  }
}
