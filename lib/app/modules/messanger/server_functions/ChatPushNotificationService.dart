import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../localization/app_localizer.dart';
import '../../auth/controllers/auth_controller.dart';


/// Saves this device's FCM token with the current LinLive user ID.
/// The Firebase Cloud Function reads these documents and sends chat pushes.
class ChatPushNotificationService {
  ChatPushNotificationService._();

  static final ChatPushNotificationService instance =
  ChatPushNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  Timer? _syncTimer;
  Worker? _localeWorker;

  String _lastSignature = '';
  bool _initialized = false;
  bool _syncing = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.setAutoInitEnabled(true);

    // Foreground messages are displayed by flutter_local_notifications.
    // This prevents iOS from showing the same message twice.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((_) {
      unawaited(syncNow(force: true));
    });

    if (Get.isRegistered<AppLanguageController>()) {
      _localeWorker?.dispose();
      _localeWorker = ever<String>(
        AppLanguageController.to.currentLocaleKey,
            (_) => unawaited(syncNow(force: true)),
      );
    }

    // Auth data may be loaded after main.dart. Keep checking so the token is
    // attached as soon as the Laravel user profile becomes available.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 12),
          (_) => unawaited(syncNow()),
    );

    await syncNow(force: true);
  }

  Future<void> syncNow({bool force = false}) async {
    if (_syncing) return;

    final String userId = _currentUserId();
    if (userId.isEmpty) return;

    _syncing = true;
    try {
      final String token = (await _messaging.getToken())?.trim() ?? '';
      if (token.isEmpty) return;

      final String locale = Get.isRegistered<AppLanguageController>()
          ? AppLanguageController.to.localeKey
          : 'en';
      final String signature = '$userId|$token|$locale';

      if (!force && signature == _lastSignature) return;

      await _firestore
          .collection('user_push_tokens')
          .doc(_tokenDocumentId(token))
          .set(
        {
          'userId': userId,
          'token': token,
          'locale': locale,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _lastSignature = signature;
      debugPrint('✅ Chat FCM token synced for user $userId');
    } catch (e, stack) {
      debugPrint('❌ Chat FCM token sync failed: $e');
      debugPrint('$stack');
    } finally {
      _syncing = false;
    }
  }

  /// Call this from your logout method before clearing the auth profile.
  Future<void> removeCurrentToken() async {
    try {
      final String token = (await _messaging.getToken())?.trim() ?? '';
      if (token.isEmpty) return;

      await _firestore
          .collection('user_push_tokens')
          .doc(_tokenDocumentId(token))
          .delete();
      _lastSignature = '';
    } catch (e) {
      debugPrint('⚠️ Chat FCM token remove failed: $e');
    }
  }

  String _currentUserId() {
    try {
      if (!Get.isRegistered<AuthController>()) return '';
      final dynamic id =
          Get.find<AuthController>().userProfile.value.user?.id;
      final String text = id?.toString().trim() ?? '';
      if (text.isEmpty || text == '0' || text.toLowerCase() == 'null') {
        return '';
      }
      return text;
    } catch (_) {
      return '';
    }
  }

  String _tokenDocumentId(String token) {
    return base64Url.encode(utf8.encode(token)).replaceAll('=', '');
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    _localeWorker?.dispose();
    await _tokenRefreshSubscription?.cancel();
    _initialized = false;
  }
}
