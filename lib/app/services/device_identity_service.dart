import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';

import '../../apis/api_endpoints.dart';

typedef DeviceTokenProvider = String? Function();

/// Creates and reuses one stable installation UUID.
///
/// The UUID is not an authentication secret. It is persisted separately from
/// the login profile so normal logout does not create a new physical-device ID.
class DeviceIdentityService extends GetxService {
  static DeviceIdentityService get to => Get.find<DeviceIdentityService>();

  static const String _stableIdKey = 'lin_live_stable_device_id';
  static const String _deviceSessionKey = 'lin_live_device_session';
  static const String _appVersion =
  String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  final RxString stableDeviceId = ''.obs;
  final RxMap<String, dynamic> deviceSession = <String, dynamic>{}.obs;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  bool _initialized = false;
  Future<void>? _initializeFuture;
  Future<String?>? _fcmTokenFuture;

  String _deviceName = '';
  String _devicePlatform = '';
  String _deviceModel = '';
  String _osVersion = '';
  String _fcmToken = '';

  bool get isInitialized => _initialized;

  int get deviceDatabaseId =>
      int.tryParse('${deviceSession['device_id'] ?? 0}') ?? 0;

  int get loginId =>
      int.tryParse('${deviceSession['login_id'] ?? 0}') ?? 0;

  String get realtimeChannel {
    final String fromServer =
    _clean(deviceSession['channel'] ?? deviceSession['private_channel']);
    if (fromServer.isEmpty) return '';
    return fromServer.startsWith('private-')
        ? fromServer.substring('private-'.length)
        : fromServer;
  }

  String get privateRealtimeChannel {
    final String channel = realtimeChannel;
    return channel.isEmpty ? '' : 'private-$channel';
  }

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    final SharedPreferences preferences =
    await SharedPreferences.getInstance();

    String savedId = preferences.getString(_stableIdKey)?.trim().toLowerCase() ?? '';
    if (!_looksLikeUuid(savedId)) {
      savedId = _uuidV4();
      await preferences.setString(_stableIdKey, savedId);
    }
    stableDeviceId.value = savedId;

    final String savedSession =
        preferences.getString(_deviceSessionKey)?.trim() ?? '';
    if (savedSession.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(savedSession);
        if (decoded is Map) {
          deviceSession.assignAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        await preferences.remove(_deviceSessionKey);
      }
    }

    await _loadDeviceMetadata();
    unawaited(_loadFcmToken());
    _initialized = true;

    debugPrint(
      '✅ Device identity ready => uuid=${_masked(stableDeviceId.value)} '
          'platform=$_devicePlatform model=$_deviceModel',
    );
  }

  Future<String> getStableDeviceId() async {
    await initialize();
    return stableDeviceId.value;
  }

  Future<Map<String, String>> headers({
    String? token,
  }) async {
    await initialize();
    final String deviceId = stableDeviceId.value;
    final String cleanToken = _clean(token);
    final String fcmToken = await _loadFcmToken() ?? '';

    return <String, String>{
      'Accept': 'application/json',
      'X-Device-Id': deviceId,
      if (_deviceName.isNotEmpty) 'X-Device-Name': _deviceName,
      if (_devicePlatform.isNotEmpty) 'X-Device-Platform': _devicePlatform,
      if (_deviceModel.isNotEmpty) 'X-Device-Model': _deviceModel,
      if (_osVersion.isNotEmpty) 'X-OS-Version': _osVersion,
      'X-App-Version': _appVersion,
      if (fcmToken.isNotEmpty) 'X-FCM-Token': fcmToken,
      if (cleanToken.isNotEmpty) 'Authorization': 'Bearer $cleanToken',
    };
  }

  void configureDio(
      Dio dio, {
        DeviceTokenProvider? tokenProvider,
      }) {
    DeviceHeadersInterceptor? existing;

    for (final Interceptor interceptor in dio.interceptors) {
      if (interceptor is DeviceHeadersInterceptor) {
        existing = interceptor;
        break;
      }
    }

    if (existing != null) {
      existing.updateTokenProvider(tokenProvider);
      return;
    }

    dio.interceptors.insert(
      0,
      DeviceHeadersInterceptor(
        service: this,
        tokenProvider: tokenProvider,
      ),
    );
  }

  /// Verifies that a successful login/register response belongs to this exact
  /// installation before the app accepts the authenticated session.
  ///
  /// This prevents a missing/stale device header from silently creating a
  /// different device record and bypassing an existing device ban.
  Future<Map<String, dynamic>> requireValidAuthDeviceSession(
      dynamic raw,
      ) async {
    await initialize();

    final Map<String, dynamic> root = _map(raw);
    final Map<String, dynamic> data = _map(root['data']);
    final Map<String, dynamic> session = _map(
      root['device_session'] ?? data['device_session'],
    );

    if (session.isEmpty) {
      throw const DeviceSessionValidationException(
        'Device session is missing from the login response. '
            'Please update the backend and try again.',
      );
    }

    final String localUuid = stableDeviceId.value.trim().toLowerCase();
    final String responseUuid = _clean(
      session['device_uuid'] ??
          session['uuid'] ??
          session['stable_device_id'],
    ).toLowerCase();

    if (responseUuid.isEmpty) {
      throw const DeviceSessionValidationException(
        'The server did not return the device UUID. Login was stopped for security.',
      );
    }

    if (responseUuid != localUuid) {
      debugPrint(
        '❌ Device UUID mismatch => local=${_masked(localUuid)} '
            'server=${_masked(responseUuid)}',
      );
      throw const DeviceSessionValidationException(
        'Device verification failed. Please restart the app and try again.',
      );
    }

    final bool blocked = _truthy(
      session['is_blocked'] ??
          root['is_blocked'] ??
          data['is_blocked'],
    );

    if (blocked) {
      final Map<String, dynamic> payload = <String, dynamic>{
        ...root,
        ...data,
        'action_type': 'device_blocked',
        'force_logout': true,
        'device_id': session['device_id'],
        'device_uuid': responseUuid,
        'reason': root['reason'] ?? data['reason'] ?? session['reason'],
        'message': root['message'] ??
            data['message'] ??
            session['message'] ??
            'This device has been blocked by the administrator.',
      };
      throw DeviceBlockedLoginException(payload);
    }

    await saveDeviceSession(session);
    return session;
  }

  Future<void> saveDeviceSessionFromResponse(dynamic raw) async {
    await requireValidAuthDeviceSession(raw);
  }

  Future<void> saveDeviceSession(Map<String, dynamic> session) async {
    await initialize();
    final Map<String, dynamic> cleanSession =
    Map<String, dynamic>.from(session);
    deviceSession.assignAll(cleanSession);

    final SharedPreferences preferences =
    await SharedPreferences.getInstance();
    await preferences.setString(
      _deviceSessionKey,
      jsonEncode(cleanSession),
    );
  }

  Future<void> clearDeviceSession() async {
    deviceSession.clear();
    final SharedPreferences preferences =
    await SharedPreferences.getInstance();
    await preferences.remove(_deviceSessionKey);
  }

  Future<Map<String, dynamic>?> checkStartupStatus({
    required Dio dio,
    required String token,
  }) async {
    final String cleanToken = token.trim();
    if (cleanToken.isEmpty) return null;

    try {
      final Response<dynamic> response = await dio.get(
        kDeviceStatusUrl,
        options: Options(
          headers: await headers(token: cleanToken),
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        await saveDeviceSessionFromResponse(response.data);
        return _map(response.data);
      }
    } on DioException catch (error) {
      debugPrint(
        '⚠️ Device status check deferred => '
            '${error.response?.statusCode ?? error.type}',
      );
    } catch (error) {
      debugPrint('⚠️ Device status check deferred => $error');
    }
    return null;
  }

  Future<void> notifyBackendLogout({
    required Dio dio,
    required String token,
  }) async {
    final String cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    try {
      await dio.post(
        kDeviceLogoutUrl,
        options: Options(
          headers: await headers(token: cleanToken),
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );
    } catch (error) {
      debugPrint('⚠️ Remote logout failed safely => $error');
    }
  }

  bool payloadTargetsCurrentDevice(dynamic raw) {
    final Map<String, dynamic> payload = _flatten(raw);
    final String eventUuid = _clean(
      payload['device_uuid'] ?? payload['device_id_uuid'],
    ).toLowerCase();

    if (eventUuid.isEmpty) {
      final int eventDeviceId =
          int.tryParse('${payload['device_id'] ?? 0}') ?? 0;
      return eventDeviceId <= 0 ||
          deviceDatabaseId <= 0 ||
          eventDeviceId == deviceDatabaseId;
    }

    return eventUuid == stableDeviceId.value.toLowerCase();
  }

  Future<void> refreshFcmToken() async {
    _fcmToken = '';
    _fcmTokenFuture = null;
    await _loadFcmToken();
  }

  Future<void> _loadDeviceMetadata() async {
    _devicePlatform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : Platform.operatingSystem;

    _osVersion = Platform.operatingSystemVersion.trim();

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await _deviceInfo.androidInfo;
        _deviceName = '${info.manufacturer} ${info.model}'.trim();
        _deviceModel = info.model.trim();
        _osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await _deviceInfo.iosInfo;
        _deviceName = info.name.trim();
        _deviceModel = info.utsname.machine.trim();
        _osVersion = '${info.systemName} ${info.systemVersion}'.trim();
      } else {
        _deviceName = Platform.localHostname.trim();
        _deviceModel = Platform.operatingSystem;
      }
    } catch (error) {
      debugPrint('⚠️ Device metadata fallback used => $error');
      _deviceName = Platform.localHostname.trim();
      _deviceModel = Platform.operatingSystem;
    }
  }

  Future<String?> _loadFcmToken() {
    if (_fcmToken.isNotEmpty) {
      return Future<String?>.value(_fcmToken);
    }

    return _fcmTokenFuture ??= () async {
      try {
        final String token =
            (await FirebaseMessaging.instance.getToken())?.trim() ?? '';
        _fcmToken = token;
        return token.isEmpty ? null : token;
      } catch (_) {
        return null;
      } finally {
        _fcmTokenFuture = null;
      }
    }();
  }

  String _uuidV4() {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List(16);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex =
    bytes.map((int value) => value.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value);
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    final Map<String, dynamic> root = _map(raw);
    final Map<String, dynamic> data = _map(root['data']);
    final Map<String, dynamic> nested = _map(data['data']);
    return <String, dynamic>{...root, ...data, ...nested};
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final dynamic decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String _clean(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;

    final String text = _clean(value).toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'blocked';
  }

  String _masked(String value) {
    if (value.length < 12) return value;
    return '${value.substring(0, 8)}…${value.substring(value.length - 4)}';
  }
}


class DeviceSessionValidationException implements Exception {
  const DeviceSessionValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceBlockedLoginException implements Exception {
  const DeviceBlockedLoginException(this.payload);

  final Map<String, dynamic> payload;

  @override
  String toString() =>
      payload['message']?.toString() ??
          'This device has been blocked by the administrator.';
}

class DeviceHeadersInterceptor extends Interceptor {
  DeviceHeadersInterceptor({
    required this.service,
    DeviceTokenProvider? tokenProvider,
  }) : _tokenProvider = tokenProvider;

  final DeviceIdentityService service;
  DeviceTokenProvider? _tokenProvider;

  void updateTokenProvider(DeviceTokenProvider? provider) {
    if (provider != null) _tokenProvider = provider;
  }

  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    try {
      final String token = _tokenProvider?.call()?.trim() ?? '';
      final Map<String, String> headers =
      await service.headers(token: token);

      headers.forEach((String key, String value) {
        final bool isDeviceHeader =
            key.toLowerCase().startsWith('x-device-') ||
                key.toLowerCase() == 'x-fcm-token';

        // Device identity must always win over stale request headers.
        if (isDeviceHeader || key == 'Accept') {
          options.headers[key] = value;
          return;
        }

        final dynamic existing = options.headers[key];
        if (existing == null || existing.toString().trim().isEmpty) {
          options.headers[key] = value;
        }
      });

      final String path = options.uri.path.toLowerCase();
      if (path.endsWith('/login') ||
          path.endsWith('/register') ||
          path.contains('google_login_postapi') ||
          path.contains('register_update')) {
        debugPrint(
          '🔐 Stable device attached => '
              '${service._masked(service.stableDeviceId.value)} '
              'path=${options.uri.path}',
        );
      }
    } catch (error) {
      debugPrint('⚠️ Device headers fallback => $error');
    }

    handler.next(options);
  }
}
