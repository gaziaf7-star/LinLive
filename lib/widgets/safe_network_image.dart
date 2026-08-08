import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const String kNetworkImagePlaceholder = 'assets/audio_live/linemptyimage.PNG';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final Alignment alignment;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.alignment = Alignment.center,
  });

  Widget _placeholder() {
    return Image.asset(
      kNetworkImagePlaceholder,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return _placeholder();
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }
}

/// Full-screen live backgrounds must never use the profile-image placeholder.
/// Loading and errors remain transparent so the room's existing color/gradient
/// layer stays stable behind the image.
class SafeLiveBackgroundImage extends StatelessWidget {
  const SafeLiveBackgroundImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
  });

  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';
    final Uri? uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return const SizedBox.expand();
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const SizedBox.expand(),
      errorWidget: (_, __, ___) => const SizedBox.expand(),
    );
  }
}
