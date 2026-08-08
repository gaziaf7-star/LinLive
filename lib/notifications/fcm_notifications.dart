import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Response;

import '../app/localization/app_localizer.dart';

import '../app/modules/auth/controllers/auth_controller.dart';
import '../app/modules/messanger/server_functions/pushnotificationservces.dart';
import '../app/modules/messanger/views/chatpage_view.dart';
import '../app/modules/notification/views/panalNotification.dart';
import '../constants/name_constants.dart';
import '../firebase_options.dart';

Map<String, dynamic> notificationData = <String, dynamic>{};

final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
  'lin_live_general_notifications',
  'LIN LIVE notifications',
  description: 'Important updates, rewards, events and admin notifications',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
  'chat_messages',
  'Chat messages',
  description: 'New private message notifications',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

bool _localNotificationsReady = false;
bool _callNotificationsReady = false;
Map<String, dynamic>? _pendingNotificationOpen;

String _lastOpenedKey = '';
DateTime? _lastOpenedAt;

Future<void> notificationInitialization() async {
  await _initializeLocalNotificationsCore(requestPermission: true);

  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  final NotificationAppLaunchDetails? launchDetails =
  await _localNotifications.getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp == true) {
    final Map<String, dynamic> data = _decodePayload(
      launchDetails?.notificationResponse?.payload,
    );
    if (data.isNotEmpty) {
      _pendingNotificationOpen = data;
    }
  }
}

Future<void> _initializeLocalNotificationsCore({
  required bool requestPermission,
}) async {
  if (!_localNotificationsReady) {
    const AndroidInitializationSettings android =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final Map<String, dynamic> data = _decodePayload(response.payload);
        if (data.isNotEmpty) {
          unawaited(handleNotificationTap(data));
        }
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_generalChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);

    _localNotificationsReady = true;
  }

  if (requestPermission) {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
    _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}

Future<void> notificationCallInitialization() async {
  if (_callNotificationsReady) return;

  await AwesomeNotifications().initialize(
    null,
    <NotificationChannel>[
      NotificationChannel(
        channelGroupKey: 'Call notifications $kAppName',
        channelKey: 'CallingTaDoLive',
        channelName: 'Call notifications $kAppName',
        channelDescription: 'Incoming audio and video call notifications',
        defaultColor: const Color(0xFF9E28B4),
        ledColor: Colors.white,
        channelShowBadge: true,
        importance: NotificationImportance.Max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        locked: true,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
      ),
    ],
    channelGroups: <NotificationChannelGroup>[
      NotificationChannelGroup(
        channelGroupKey: 'Call notifications $kAppName',
        channelGroupName: 'Call notifications $kAppName',
      ),
    ],
    debug: false,
  );

  _callNotificationsReady = true;
}

@pragma('vm:entry-point')
Future<void> messageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  notificationData = _mergeRemoteMessage(message);
  debugPrint('📩 Background FCM Data: $notificationData');

  if (_isCallMessage(notificationData)) {
    await notificationCallInitialization();
    await sendCallNotification(notificationMessage: notificationData);
    return;
  }

  // Android/iOS shows notification+data messages automatically while the app
  // is in background or terminated. Data-only messages need a local push.
  if (message.notification == null) {
    await _initializeLocalNotificationsCore(requestPermission: false);
    await messageNotification(message: notificationData);
  }
}

void firebaseMessagingListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    notificationData = _mergeRemoteMessage(message);
    debugPrint('📩 Foreground FCM Data: $notificationData');

    if (_isCallMessage(notificationData)) {
      await notificationCallInitialization();
      await sendCallNotification(notificationMessage: notificationData);
      return;
    }

    await _initializeLocalNotificationsCore(requestPermission: false);
    await messageNotification(message: notificationData);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    notificationData = _mergeRemoteMessage(message);
    debugPrint('📲 Notification opened data: $notificationData');
    unawaited(handleNotificationTap(notificationData));
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
    debugPrint('🔄 FCM token refreshed: ${_maskToken(token)}');
  });
}

Future<void> handleInitialFirebaseMessage() async {
  final RemoteMessage? initialMessage =
  await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage == null) return;

  notificationData = _mergeRemoteMessage(initialMessage);
  await handleNotificationTap(notificationData);
}

Future<void> handlePendingNotificationAfterAppReady() async {
  final Map<String, dynamic>? data = _pendingNotificationOpen;
  _pendingNotificationOpen = null;
  if (data == null || data.isEmpty) return;

  await handleNotificationTap(data);
}

Future<void> messageNotification({required Map message}) async {
  final Map<String, dynamic> data = Map<String, dynamic>.from(message);
  final bool isChat = _isChatMessage(data);

  final String chatId = _firstText(data, <String>['chat_id', 'chatId']);
  if (isChat && chatId.isNotEmpty && ChatNotificationState.isOpen(chatId)) {
    return;
  }

  final String title = isChat
      ? _firstText(
    data,
    <String>['sender_name', 'senderName', 'title'],
    fallback: kAppName,
  )
      : _firstText(
    data,
    <String>['title', 'notification_title', 'subject'],
    fallback: kAppName,
  );

  final String body = _firstText(
    data,
    <String>['message', 'text', 'body', 'preview', 'notification_body'],
    fallback: isChat ? 'New message'.appTr : 'You have a new notification'.appTr,
  );

  final int unreadCount = _safeInt(data['unread_count']);
  final int notificationId = _notificationId(data);
  final String? imageUrl = _firstNullableText(
    data,
    <String>[
      'image_url',
      'image',
      'notification_image',
      'picture',
      'large_icon',
    ],
  );

  final AndroidBitmap<Object>? picture =
  await _downloadAndroidBitmap(imageUrl);

  final StyleInformation styleInformation = picture != null
      ? BigPictureStyleInformation(
    picture,
    contentTitle: title,
    summaryText: body,
    hideExpandedLargeIcon: false,
  )
      : BigTextStyleInformation(
    body,
    contentTitle: title,
    summaryText: isChat ? 'Messages'.appTr : kAppName,
  );

  final AndroidNotificationDetails android = AndroidNotificationDetails(
    isChat ? _chatChannel.id : _generalChannel.id,
    isChat ? _chatChannel.name : _generalChannel.name,
    channelDescription:
    isChat ? _chatChannel.description : _generalChannel.description,
    channelShowBadge: true,
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
    onlyAlertOnce: false,
    visibility: NotificationVisibility.public,
    category: isChat
        ? AndroidNotificationCategory.message
        : AndroidNotificationCategory.social,
    number: unreadCount > 0 ? unreadCount : null,
    styleInformation: styleInformation,
    groupKey: isChat ? 'lin_live_chat_group' : 'lin_live_general_group',
    ticker: body,
  );

  final DarwinNotificationDetails ios = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    threadIdentifier: isChat ? 'chat_messages' : 'lin_live_general',
    subtitle: isChat ? null : kAppName,
  );

  await _localNotifications.show(
    notificationId,
    title,
    body,
    NotificationDetails(android: android, iOS: ios),
    payload: jsonEncode(_stringMap(data)),
  );

  FlutterBackgroundService().invoke('stopCallRing');
}

Future<void> handleNotificationTap(Map<String, dynamic> rawData) async {
  final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
  if (data.isEmpty || _isCallMessage(data)) return;

  final String openKey = _notificationOpenKey(data);
  final DateTime now = DateTime.now();
  if (openKey.isNotEmpty &&
      openKey == _lastOpenedKey &&
      _lastOpenedAt != null &&
      now.difference(_lastOpenedAt!).inSeconds < 3) {
    return;
  }

  _lastOpenedKey = openKey;
  _lastOpenedAt = now;

  if (_isChatMessage(data)) {
    await openChatFromNotification(data);
    return;
  }

  await openGeneralNotification(data);
}

Future<void> openChatFromNotification(Map<String, dynamic> data) async {
  final String senderId = _firstText(
    data,
    <String>['sender_id', 'senderId', 'user_id'],
  );
  if (senderId.isEmpty) return;

  for (int attempt = 0; attempt < 25; attempt++) {
    if (Get.context != null && Get.isRegistered<AuthController>()) {
      final String myId = Get.find<AuthController>()
          .userProfile
          .value
          .user
          ?.id
          ?.toString() ??
          '';

      if (myId.isNotEmpty && myId != '0') {
        if (senderId == myId) return;

        final String senderName = _firstText(
          data,
          <String>['sender_name', 'senderName'],
          fallback: 'Unknown'.appTr,
        );
        final String senderImage = _firstText(
          data,
          <String>['sender_image', 'senderImage', 'avatar'],
        );

        await Get.to(
              () => ChatPage(
            receiverId: senderId,
            receiverName: senderName,
            receiverImage: senderImage,
          ),
          transition: Transition.rightToLeftWithFade,
          duration: const Duration(milliseconds: 320),
          preventDuplicates: true,
        );
        return;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

Future<void> openGeneralNotification(Map<String, dynamic> data) async {
  for (int attempt = 0; attempt < 25; attempt++) {
    if (Get.context != null && Get.isRegistered<AuthController>()) {
      final AuthController auth = Get.find<AuthController>();
      final String token = auth.userProfile.value.token?.toString().trim() ?? '';
      final String userId = auth.userProfile.value.user?.id?.toString() ?? '';

      if (token.isNotEmpty && userId.isNotEmpty && userId != '0') {
        await Get.to(
              () => const Panalnotification(),
          transition: Transition.rightToLeftWithFade,
          duration: const Duration(milliseconds: 300),
          preventDuplicates: true,
        );
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

Future<void> sendCallNotification({
  required Map notificationMessage,
}) async {
  await notificationCallInitialization();

  notificationData = Map<String, dynamic>.from(notificationMessage);

  final bool isVideoCall =
      notificationMessage['type']?.toString().toLowerCase() == 'video';

  final String callerName =
  notificationMessage['caller_name']?.toString().trim().isNotEmpty == true
      ? notificationMessage['caller_name'].toString()
      : 'Unknown caller';

  final String? callerImage =
  notificationMessage['caller_image']?.toString().trim().isNotEmpty == true
      ? notificationMessage['caller_image'].toString()
      : null;

  final int notificationId =
      int.tryParse('${notificationMessage['call_id'] ?? ''}') ?? 1265478;

  final bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: notificationId,
      channelKey: 'CallingTaDoLive',
      title: '$kAppName Calling'.appTr,
      body: '${isVideoCall ? "Video" : "Audio"} call from $callerName',
      category: NotificationCategory.Call,
      notificationLayout: NotificationLayout.Default,
      wakeUpScreen: true,
      fullScreenIntent: true,
      displayOnBackground: true,
      displayOnForeground: true,
      locked: true,
      autoDismissible: false,
      showWhen: true,
      largeIcon: callerImage,
      payload: _stringMap(notificationData),
    ),
    actionButtons: <NotificationActionButton>[
      NotificationActionButton(
        key: 'Answer',
        label: 'Answer'.appTr,
        color: Colors.green,
        actionType: ActionType.Default,
        autoDismissible: true,
      ),
      NotificationActionButton(
        key: 'Cancel',
        label: 'Reject'.appTr,
        color: Colors.red,
        actionType: ActionType.DismissAction,
        isDangerousOption: true,
        autoDismissible: true,
      ),
    ],
  );
}

Map<String, dynamic> _mergeRemoteMessage(RemoteMessage message) {
  final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);

  final String title = message.notification?.title?.trim() ?? '';
  final String body = message.notification?.body?.trim() ?? '';

  if (title.isNotEmpty) data.putIfAbsent('title', () => title);
  if (body.isNotEmpty) {
    data.putIfAbsent('message', () => body);
    data.putIfAbsent('body', () => body);
  }

  if (message.messageId?.trim().isNotEmpty == true) {
    data.putIfAbsent('fcm_message_id', () => message.messageId!);
  }

  return data;
}

Future<AndroidBitmap<Object>?> _downloadAndroidBitmap(String? url) async {
  final String cleanUrl = url?.trim() ?? '';
  if (cleanUrl.isEmpty ||
      (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
    return null;
  }

  try {
    final Response<List<int>> response = await Dio().get<List<int>>(
      cleanUrl,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );

    final List<int>? bytes = response.data;
    if (bytes == null || bytes.isEmpty) return null;
    return ByteArrayAndroidBitmap(Uint8List.fromList(bytes));
  } catch (error) {
    debugPrint('⚠️ Notification image download skipped: $error');
    return null;
  }
}

Map<String, dynamic> _decodePayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    return <String, dynamic>{};
  }

  try {
    final dynamic decoded = jsonDecode(payload);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}

  return <String, dynamic>{};
}

bool _isCallMessage(Map<String, dynamic> data) {
  final String type = _firstText(
    data,
    <String>['notice_type', 'notification_type'],
  ).toLowerCase();
  return type == 'call_notice';
}

bool _isChatMessage(Map<String, dynamic> data) {
  final String type = _firstText(
    data,
    <String>['notice_type', 'notification_type', 'type'],
  ).toLowerCase();
  return type == 'chat_message' ||
      type == 'message' ||
      data.containsKey('chat_id') ||
      data.containsKey('chatId');
}

String _notificationOpenKey(Map<String, dynamic> data) {
  return _firstText(
    data,
    <String>[
      'notification_id',
      'message_id',
      'messageId',
      'fcm_message_id',
      'call_id',
    ],
    fallback: '${data.hashCode}',
  );
}

String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
      String fallback = '',
    }) {
  for (final String key in keys) {
    final String text = data[key]?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return fallback;
}

String? _firstNullableText(
    Map<String, dynamic> data,
    List<String> keys,
    ) {
  final String text = _firstText(data, keys);
  return text.isEmpty ? null : text;
}

int _safeInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _notificationId(Map<String, dynamic> data) {
  final int explicitId = _safeInt(
    data['notification_id'] ?? data['id'] ?? data['message_id'],
  );
  if (explicitId > 0) return explicitId & 0x7fffffff;

  final String stable = _firstText(
    data,
    <String>['message_id', 'messageId', 'fcm_message_id'],
  );
  if (stable.isNotEmpty) return stable.hashCode & 0x7fffffff;

  return Random().nextInt(0x7fffffff);
}

Map<String, String> _stringMap(Map<String, dynamic> data) {
  return data.map(
        (String key, dynamic value) =>
        MapEntry<String, String>(key, value?.toString() ?? ''),
  );
}

String _maskToken(String token) {
  if (token.length <= 16) return '***';
  return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
}
