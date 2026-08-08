import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;

import 'device_identity_service.dart';

typedef AccountBlockAsyncCallback = Future<void> Function();
typedef AccountBlockRealtimeStart = Future<void> Function(int databaseUserId);
typedef AccountBlockRemoteLogout = Future<void> Function();
typedef AccountBlockLoginNavigation = Future<void> Function(
    String message,
    String? unblockAt,
    String? reason,
    bool blockedByAdmin,
    bool blockedDevice,
    );

/// One force-logout coordinator for account blocks, device blocks, manual
/// logout, Agora cleanup, local-session cleanup and login navigation.
class AccountBlockService extends GetxService {
  static AccountBlockService get to => Get.find<AccountBlockService>();

  final RxBool forceLogoutInProgress = false.obs;
  final RxString lastMessage = ''.obs;
  final RxnString lastUnblockAt = RxnString();
  final RxnString lastReason = RxnString();
  final RxBool lastWasDeviceBlock = false.obs;

  AccountBlockAsyncCallback? _cleanupLiveSession;
  AccountBlockAsyncCallback? _clearLocalSession;
  AccountBlockRealtimeStart? _startRealtime;
  AccountBlockLoginNavigation? _goToLogin;
  AccountBlockRemoteLogout? _remoteLogout;

  bool _handlingForceLogout = false;
  int _authenticatedDatabaseUserId = 0;

  bool get handlingForceLogout => _handlingForceLogout;
  int get authenticatedDatabaseUserId => _authenticatedDatabaseUserId;

  void configure({
    required AccountBlockAsyncCallback cleanupLiveSession,
    required AccountBlockAsyncCallback clearLocalSession,
    required AccountBlockRealtimeStart startRealtime,
    required AccountBlockLoginNavigation goToLogin,
    AccountBlockRemoteLogout? remoteLogout,
  }) {
    _cleanupLiveSession = cleanupLiveSession;
    _clearLocalSession = clearLocalSession;
    _startRealtime = startRealtime;
    _goToLogin = goToLogin;
    _remoteLogout = remoteLogout;
  }

  /// Installs both the stable-device header interceptor and the global
  /// account/device force-logout response interceptor.
  void configureDio(
      Dio dio, {
        DeviceTokenProvider? tokenProvider,
      }) {
    if (Get.isRegistered<DeviceIdentityService>()) {
      DeviceIdentityService.to.configureDio(
        dio,
        tokenProvider: tokenProvider,
      );
    }

    final bool alreadyAdded = dio.interceptors.any(
          (Interceptor interceptor) => interceptor is AccountBlockedInterceptor,
    );
    if (!alreadyAdded) {
      dio.interceptors.add(AccountBlockedInterceptor(this));
    }
  }

  Future<void> startAuthenticatedSession({
    required int databaseUserId,
  }) async {
    if (databaseUserId <= 0) return;

    final bool newSession = _authenticatedDatabaseUserId != databaseUserId;
    _authenticatedDatabaseUserId = databaseUserId;

    if (newSession || _handlingForceLogout) {
      _handlingForceLogout = false;
      forceLogoutInProgress.value = false;
      lastMessage.value = '';
      lastUnblockAt.value = null;
      lastReason.value = null;
      lastWasDeviceBlock.value = false;
    }

    final AccountBlockRealtimeStart? starter = _startRealtime;
    if (starter == null) return;

    unawaited(_startRealtimeSafely(starter, databaseUserId));
  }

  Future<void> _startRealtimeSafely(
      AccountBlockRealtimeStart starter,
      int databaseUserId,
      ) async {
    try {
      await starter(databaseUserId);
    } catch (error, stack) {
      debugPrint('⚠️ Authenticated realtime start deferred: $error');
      debugPrint('$stack');
    }
  }

  Future<void> forceLogoutFromPayload(
      dynamic raw, {
        bool assumeDeviceBlocked = false,
      }) async {
    final Map<String, dynamic> payload = _flattenPayload(raw);
    final _BlockKind detected = _blockKind(payload);
    final _BlockKind kind = detected == _BlockKind.none && assumeDeviceBlocked
        ? _BlockKind.device
        : detected;
    if (kind == _BlockKind.none) return;

    if (kind == _BlockKind.device &&
        Get.isRegistered<DeviceIdentityService>() &&
        !DeviceIdentityService.to.payloadTargetsCurrentDevice(payload)) {
      debugPrint('ℹ️ Device block ignored: payload targets another device');
      return;
    }

    final String fallback = kind == _BlockKind.device
        ? 'This device has been blocked by the administrator.'
        : 'Your account has been blocked by the administrator.';

    await forceLogout(
      message: _cleanText(payload['message']).isNotEmpty
          ? _cleanText(payload['message'])
          : fallback,
      unblockAt: _nullableText(payload['unblock_at']),
      reason: _nullableText(payload['reason']),
      deviceBlocked: kind == _BlockKind.device,
    );
  }

  Future<void> forceLogout({
    required String message,
    String? unblockAt,
    String? reason,
    bool deviceBlocked = false,
  }) async {
    if (_handlingForceLogout) return;

    _handlingForceLogout = true;
    forceLogoutInProgress.value = true;
    lastMessage.value = message;
    lastUnblockAt.value = unblockAt;
    lastReason.value = reason;
    lastWasDeviceBlock.value = deviceBlocked;

    try {
      await _safeRun(_cleanupLiveSession, 'authenticated live cleanup');
      await _safeRun(_clearLocalSession, 'authenticated session clear');

      _authenticatedDatabaseUserId = 0;

      final AccountBlockLoginNavigation? navigator = _goToLogin;
      if (navigator != null) {
        await navigator(
          message,
          unblockAt,
          reason,
          !deviceBlocked,
          deviceBlocked,
        );
      }

      // The login navigation callback shows one centered, non-dismissible
      // account/device block popup. Do not show a second bottom toast.
    } finally {
      // Remain locked until a genuinely successful new login starts a new
      // authenticated session.
      forceLogoutInProgress.value = false;
    }
  }

  Future<void> logoutManually() async {
    if (_handlingForceLogout) return;
    _handlingForceLogout = true;
    forceLogoutInProgress.value = true;

    try {
      await _safeRun(_remoteLogout, 'remote device logout');
      await _safeRun(_cleanupLiveSession, 'manual live cleanup');
      await _safeRun(_clearLocalSession, 'manual session clear');
      _authenticatedDatabaseUserId = 0;

      final AccountBlockLoginNavigation? navigator = _goToLogin;
      if (navigator != null) {
        await navigator('', null, null, false, false);
      }
    } finally {
      forceLogoutInProgress.value = false;
    }
  }

  Future<void> _safeRun(
      AccountBlockAsyncCallback? callback,
      String label,
      ) async {
    if (callback == null) return;
    try {
      await callback();
    } catch (error, stack) {
      debugPrint('⚠️ $label failed safely: $error');
      debugPrint('$stack');
    }
  }

  bool isBlockedHttpResponse({
    required int? statusCode,
    required dynamic body,
  }) {
    final Map<String, dynamic> payload = _flattenPayload(body);

    if (statusCode == 423) {
      return true;
    }

    if (statusCode != 401 && statusCode != 403) {
      return false;
    }

    return _blockKind(payload) != _BlockKind.none;
  }

  bool isDeviceIdRequired({
    required int? statusCode,
    required dynamic body,
  }) {
    if (statusCode != 422) return false;
    final Map<String, dynamic> payload = _flattenPayload(body);
    return _cleanText(payload['action_type']).toLowerCase() ==
        'device_id_required';
  }

  Map<String, dynamic> _flattenPayload(dynamic raw) {
    Map<String, dynamic> mapOf(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final Map<String, dynamic> root = mapOf(raw);
    if (root.isEmpty) return <String, dynamic>{};

    final Map<String, dynamic> data = mapOf(root['data']);
    final Map<String, dynamic> nested = mapOf(data['data']);

    return <String, dynamic>{
      ...root,
      ...data,
      ...nested,
    };
  }

  _BlockKind _blockKind(Map<String, dynamic> payload) {
    final String action = _cleanText(
      payload['action_type'] ?? payload['action'] ?? payload['type'],
    ).toLowerCase();
    final String status = _cleanText(payload['status']).toLowerCase();
    final String message = _cleanText(
      payload['message'] ?? payload['error'],
    ).toLowerCase();

    if (action == 'device_blocked' ||
        message.contains('device has been blocked') ||
        message.contains('device is blocked') ||
        message.contains('device blocked')) {
      return _BlockKind.device;
    }

    if (action == 'account_blocked' ||
        status == 'block' ||
        status == 'blocked' ||
        message.contains('account has been blocked') ||
        message.contains('account is blocked') ||
        message.contains('account blocked')) {
      return _BlockKind.account;
    }

    if (_truthy(payload['force_logout'])) {
      return payload.containsKey('device_uuid') ||
          payload.containsKey('device_id')
          ? _BlockKind.device
          : _BlockKind.account;
    }

    return _BlockKind.none;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final String text = _cleanText(value).toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on';
  }

  String _cleanText(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String? _nullableText(dynamic value) {
    final String text = _cleanText(value);
    return text.isEmpty ? null : text;
  }
}

enum _BlockKind {
  none,
  account,
  device,
}

/// Handles account/device blocks in both onResponse and onError because many
/// existing calls use validateStatus(status < 500).
class AccountBlockedInterceptor extends Interceptor {
  AccountBlockedInterceptor(this.service);

  final AccountBlockService service;

  @override
  void onResponse(
      Response<dynamic> response,
      ResponseInterceptorHandler handler,
      ) {
    if (service.isBlockedHttpResponse(
      statusCode: response.statusCode,
      body: response.data,
    )) {
      unawaited(
        service.forceLogoutFromPayload(
          response.data,
          assumeDeviceBlocked: response.statusCode == 423,
        ),
      );
    }
    handler.next(response);
  }

  @override
  void onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) {
    if (service.isBlockedHttpResponse(
      statusCode: err.response?.statusCode,
      body: err.response?.data,
    )) {
      unawaited(
        service.forceLogoutFromPayload(
          err.response?.data,
          assumeDeviceBlocked: err.response?.statusCode == 423,
        ),
      );
    }
    handler.next(err);
  }
}
