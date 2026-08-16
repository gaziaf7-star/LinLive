import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A long-lived cache dedicated to the small, frequently rendered app theme.
class AppThemeImageCache {
  AppThemeImageCache._();

  static final CacheManager manager = CacheManager(
    Config(
      'appThemeImagesV1',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 32,
    ),
  );

  static Future<void> cacheAll(Iterable<String> urls) async {
    await Future.wait<void>(urls.toSet().map(_cacheOne), eagerError: false);
  }

  static Future<void> _cacheOne(String url) async {
    try {
      final file = await manager
          .getSingleFile(url, key: url)
          .timeout(const Duration(seconds: 15));
      if (!await file.exists() || await file.length() <= 0) {
        throw StateError('downloaded cache file is empty');
      }

    } catch (error) {
      // Isolate failures: CachedNetworkImage can still request this URL and its
      // widget-level errorBuilder will retain the local asset fallback.
      if (kDebugMode) debugPrint('APP_THEME cache failure: $url $error');
    }
  }

  static void warm(Iterable<String> urls) {
    unawaited(cacheAll(urls).catchError((Object error) {
      if (kDebugMode) debugPrint('APP_THEME warm failure: $error');
    }));
  }

  static Future<void> prepareForFirstFrame(
    BuildContext context,
    Iterable<String> urls,
  ) async {
    await Future.wait<void>(
      urls.toSet().map((String url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(
              url,
              cacheManager: manager,
              cacheKey: url,
            ),
            context,
          ).timeout(const Duration(seconds: 4));
        } catch (error) {
          if (kDebugMode) {
            debugPrint('APP_THEME first-frame image fallback: $error');
          }
        }
      }),
      eagerError: false,
    );
  }
}
