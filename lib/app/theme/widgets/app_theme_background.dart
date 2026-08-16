import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme_image_cache.dart';

class AppThemeBackground extends StatelessWidget {
  const AppThemeBackground({
    super.key,
    required this.imageUrl,
    required this.child,
  });

  final String? imageUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double topHeight = (size.height * 0.48)
        .clamp(size.height * 0.45, size.height * 0.50)
        .toDouble();
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: size.width,
                height: topHeight,
                child: CachedNetworkImage(
                  key: ValueKey<String>(imageUrl!),
                  imageUrl: imageUrl!,
                  cacheManager: AppThemeImageCache.manager,
                  cacheKey: imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, _) => const ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(),
                  ),
                  errorWidget: (_, url, error) {
                    if (kDebugMode) {
                      debugPrint('Theme background image failed: $url $error');
                    }
                    return const ColoredBox(
                      color: Colors.white,
                      child: SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          if (imageUrl != null)
            Positioned(
              top: topHeight * 0.80,
              left: 0,
              right: 0,
              height: topHeight * 0.20,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x80FFFFFF),
                      Colors.white,
                    ],
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
