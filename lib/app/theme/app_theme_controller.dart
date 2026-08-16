import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../apis/api_endpoints.dart';
import '../modules/auth/controllers/auth_controller.dart';
import 'app_theme_model.dart';
import 'app_theme_image_cache.dart';

class AppThemeController extends GetxController {
  AppThemeController({Dio? dio, GetStorage? storage})
    : _dio = dio ?? Dio(),
      _storage = storage ?? GetStorage();

  static const String _cacheKey = 'app_theme_v1';
  final Dio _dio;
  final GetStorage _storage;
  final Rxn<AppThemeModel> theme = Rxn<AppThemeModel>();
  Future<void>? _refreshing;
  Worker? _authWorker;
  AuthController? _configuredAuth;
  String _lastRequestedTokenSignature = '';
  final Stopwatch _startupClock = Stopwatch()..start();
  bool _cachedThemeRestored = false;

  @override
  void onInit() {
    super.onInit();
    _restoreCachedTheme();
    unawaited(_initializeAuthenticatedRefresh());
  }

  Future<void> _initializeAuthenticatedRefresh() async {
    final AuthController? auth = await _waitForAuthController();
    if (auth == null) {
      if (kDebugMode) {
        debugPrint('[APP_THEME] auth_not_ready; cached theme retained');
      }
      return;
    }

    await auth.initialize();
    _configureAuthenticatedClient(auth);
    _authWorker ??= ever(auth.userProfile, (_) {
      final String token = _normalizedToken(auth.userProfile.value.token);
      if (token.isEmpty || _tokenSignature(token) == _lastRequestedTokenSignature) {
        return;
      }
      unawaited(refreshTheme());
    });

    if (_normalizedToken(auth.userProfile.value.token).isNotEmpty) {
      await refreshTheme();
    } else if (kDebugMode) {
      debugPrint('[APP_THEME] token_present=false; network refresh deferred');
    }
  }

  Future<AuthController?> _waitForAuthController() async {
    for (int attempt = 0; attempt < 60; attempt++) {
      if (Get.isRegistered<AuthController>()) {
        return Get.find<AuthController>();
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  void _configureAuthenticatedClient(AuthController auth) {
    if (identical(_configuredAuth, auth)) return;
    auth.configureProtectedDio(_dio);
    _configuredAuth = auth;
  }

  void _restoreCachedTheme() {
    final cached = _storage.read<dynamic>(_cacheKey);
    if (cached is! Map) return;
    final restored = AppThemeModel.fromJson(Map<String, dynamic>.from(cached));
    if (restored.hasAnyImage) {
      _cachedThemeRestored = true;
      theme.value = restored;
      if (kDebugMode) {
        debugPrint(
          '[APP_THEME_STARTUP] cached_json_ready=${_startupClock.elapsedMilliseconds}ms',
        );
      }
      // Resolves from disk immediately when present and warms Flutter's source
      // cache without delaying the first frame.
      AppThemeImageCache.warm(restored.imageUrls);
    }
  }

  Future<void> refreshTheme() => _refreshing ??= _fetch().whenComplete(() {
    _refreshing = null;
  });

  Future<void> prepareThemeForFirstFrame(BuildContext context) async {
    if (theme.value == null) await refreshTheme();
    final AppThemeModel? readyTheme = theme.value;
    if (readyTheme == null || !readyTheme.hasAnyImage) return;
    await AppThemeImageCache.prepareForFirstFrame(context, readyTheme.imageUrls);
    if (kDebugMode) {
      debugPrint(
        '[APP_THEME_STARTUP] cached_images_ready=${_startupClock.elapsedMilliseconds}ms '
        'source=${_cachedThemeRestored ? 'disk' : 'network'}',
      );
    }
  }

  int get startupElapsedMilliseconds => _startupClock.elapsedMilliseconds;

  Future<void> _fetch() async {
    try {
      final AuthController? auth = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>()
          : null;
      if (auth == null) return;
      await auth.initialize();
      _configureAuthenticatedClient(auth);

      final String token = _normalizedToken(auth.userProfile.value.token);
      if (token.isEmpty) {
        if (kDebugMode) {
          debugPrint('[APP_THEME] token_present=false; request skipped');
        }
        return;
      }
      _lastRequestedTokenSignature = _tokenSignature(token);
      final String authorization = 'Bearer $token';
      if (kDebugMode) {
        debugPrint('[APP_THEME] token_present=true');
        debugPrint('[APP_THEME] token_length=${token.length}');
        debugPrint('[APP_THEME] auth_header_present=true');
        debugPrint('[APP_THEME] auth_scheme=Bearer');
        debugPrint('[APP_THEME] request_start url=$kMainUrl/app_theme');
      }
      final Response<dynamic> response = await _dio.get<dynamic>(
        '$kMainUrl/app_theme',
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': authorization,
          },
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );
      final Map<String, dynamic> body = _asMap(response.data);
      if (kDebugMode) {
        debugPrint('[APP_THEME] status_code=${response.statusCode}');
      }
      if (response.statusCode != 200 ||
          body['status'] != true ||
          body['success'] != true) {
        if (kDebugMode) {
          debugPrint(
            'App theme request rejected: status=${response.statusCode} '
            'message=${body['message']}',
          );
        }
        return;
      }
      final Map<String, dynamic> data = _asMap(body['data']);
      if (data.isEmpty) return;
      final latest = AppThemeModel.fromJson(data);
      if (!latest.hasAnyImage) return;
      if (kDebugMode) debugPrint('[APP_THEME] parse_success');

      final AppThemeModel? current = theme.value;
      final List<String> changedUrls = latest.changedUrlsFrom(current);

      // Valid server state is the UI source of truth. Disk/network image cache
      // warming is an optimization and must never gate reactive publication.
      theme.value = latest;
      if (kDebugMode) {
        debugPrint('[APP_THEME] publish_theme');
        debugPrint(
          '[APP_THEME_STARTUP] network_theme_ready=${_startupClock.elapsedMilliseconds}ms',
        );

      }

      try {
        await _storage.write(_cacheKey, latest.toJson());
      } catch (error) {
        if (kDebugMode) debugPrint('APP_THEME storage error: $error');
      }

      if (changedUrls.isNotEmpty) {
        unawaited(
          AppThemeImageCache.cacheAll(changedUrls).catchError((Object error) {
            if (kDebugMode) {
              debugPrint('APP_THEME cache batch error: $error');
            }
          }),
        );
      } else if (current != null && latest.hasSameUrls(current)) {
        AppThemeImageCache.warm(latest.imageUrls);
      }
    } on DioException catch (error) {
      // Cached/local visuals remain active when the refresh is unavailable.
      if (kDebugMode) {
        debugPrint(
          'App theme network error: ${error.response?.statusCode} '
          '${error.message}',
        );
      }
    } on FormatException catch (error) {
      // Invalid server data must never affect navigation or page rendering.
      if (kDebugMode) debugPrint('APP_THEME format error: $error');
    } catch (error, stackTrace) {
      // A malformed payload must leave the last valid theme untouched.
      if (kDebugMode) {
        debugPrint('APP_THEME unexpected error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  String _normalizedToken(dynamic value) {
    String token = value?.toString().trim() ?? '';
    if (token.isEmpty ||
        token.toLowerCase() == 'null' ||
        token.toLowerCase() == 'undefined' ||
        token == '0') {
      return '';
    }
    token = token.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    ).trim();
    return token;
  }

  String _tokenSignature(String token) => '${token.length}:${token.hashCode}';

  @override
  void onClose() {
    _authWorker?.dispose();
    _authWorker = null;
    super.onClose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    dynamic decoded = value;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    if (decoded is! Map) return <String, dynamic>{};
    return decoded.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }

}
