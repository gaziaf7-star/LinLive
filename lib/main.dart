import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get_storage/get_storage.dart';

import 'app/localization/app_localizer.dart';
import 'app/modules/home/views/home_view.dart';
import 'app/modules/livestream/controllers/roket_controller.dart';
import 'app/modules/messanger/server_functions/ChatPushNotificationService.dart';
import 'firebase_options.dart';
import 'app/modules/auth/controllers/auth_controller.dart';
import 'app/modules/auth/views/login_view.dart';
import 'app/modules/home/controllers/home_controller.dart';
import 'app/modules/livestream/controllers/agoraTokenController.dart';
import 'app/modules/livestream/controllers/livestream_controller.dart';
import 'app/modules/livestream/socket/websocket_controller.dart';

import 'app/services/account_block_service.dart';
import 'app/services/device_identity_service.dart';
import 'app/services/agora_service.dart';
import 'models/user_profile.dart';

import 'app/modules/livestream/controllers/audience_join_controller.dart';
import 'app/modules/livestream/widgets/GlobalLuckyBagBanner.dart';
import 'app/modules/livestream/widgets/GlobalLuckyWinBanner.dart';
import 'app/modules/livestream/widgets/GlobalRocketLaunchBanner.dart';
import 'app/modules/livestream/widgets/GlobalBigGiftBanner.dart';
import 'app/modules/livestream/widgets/minimized_video_live_window.dart';
import 'app/modules/messanger/views/audio_call_view.dart';
import 'app/modules/messanger/views/video_call_view.dart';
import 'app/modules/moments/controllers/moments_controller.dart';
import 'app/modules/myprofile/controllers/myprofile_controller.dart';
import 'app/modules/registersteps/controllers/registersteps_controller.dart';
import 'app/modules/store/controllers/store1_controller.dart';
import 'app/routes/app_pages.dart';
import 'background_service/background_main.dart';
import 'notifications/fcm_notifications.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await GetStorage.init();
      final AppLanguageController languageController =
          Get.isRegistered<AppLanguageController>()
          ? Get.find<AppLanguageController>()
          : Get.put(AppLanguageController(), permanent: true);
      await languageController.initialize();

      HttpOverrides.global = MyHttpOverrides();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('❌ Flutter framework error: ${details.exceptionAsString()}');
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('❌ Platform dispatcher error: $error');
        debugPrint('$stack');
        return true;
      };

      await _safeInitializeFirebase();
      await _requestPermissions();

      // Configure once at app start. The actual microphone foreground service
      // starts only while a live room is active.
      await _safeInitializeBackgroundService();

      await _safeInitNotifications();

      FirebaseMessaging.onBackgroundMessage(messageHandler);

      firebaseMessagingListener();
      notificationCallInitialization();

      await _registerControllersSafely();
      await ChatPushNotificationService.instance.initialize();
      _configureForAndroidDevice();

      runApp(const MyApp());
    },
    (Object error, StackTrace stack) {
      debugPrint('❌ Uncaught zone error: $error');
      debugPrint('$stack');
    },
  );
}

Future<void> _safeInitializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('✅ Firebase initialized');
  } catch (e, s) {
    debugPrint('❌ Firebase initialize error: $e');
    debugPrint('$s');
  }
}

Future<void> _safeInitNotifications() async {
  try {
    await notificationInitialization();
    debugPrint('✅ Notification initialized');
  } catch (e, s) {
    debugPrint('❌ Notification initialize error: $e');
    debugPrint('$s');
  }
}

Future<void> _safeInitializeBackgroundService() async {
  try {
    await initializeBackgroundService();
    debugPrint('✅ Live background audio service configured');
  } catch (e, s) {
    debugPrint('❌ Live background audio service configure error: $e');
    debugPrint('$s');
  }
}

T _putIfAbsent<T>(T Function() builder, {bool permanent = true}) {
  if (Get.isRegistered<T>()) {
    return Get.find<T>();
  }

  return Get.put<T>(builder(), permanent: permanent);
}

Future<void> _registerControllersSafely() async {
  try {
    final DeviceIdentityService deviceIdentity =
        _putIfAbsent<DeviceIdentityService>(() => DeviceIdentityService());
    await deviceIdentity.initialize();

    _putIfAbsent<AccountBlockService>(() => AccountBlockService());
    _putIfAbsent<AuthController>(() => AuthController());
    _putIfAbsent<RegisterstepsController>(() => RegisterstepsController());
    _putIfAbsent<AgoraTokenController>(() => AgoraTokenController());
    _putIfAbsent<RocketController>(() => RocketController());
    _putIfAbsent<WebsocketController>(() => WebsocketController());
    _putIfAbsent<LivestreamController>(() => LivestreamController());
    _putIfAbsent<ConnectivityController>(() => ConnectivityController());
    _putIfAbsent<HomeController>(() => HomeController());
    _putIfAbsent<MyprofileController>(() => MyprofileController());
    _putIfAbsent<MomentsController>(() => MomentsController());

    _configureAccountBlockService();

    debugPrint('✅ Core controllers and stable device identity ready');
  } catch (e, s) {
    debugPrint('❌ Controller register error: $e');
    debugPrint('$s');
  }
}

void _configureAccountBlockService() {
  if (!Get.isRegistered<AccountBlockService>() ||
      !Get.isRegistered<DeviceIdentityService>() ||
      !Get.isRegistered<AuthController>() ||
      !Get.isRegistered<WebsocketController>() ||
      !Get.isRegistered<LivestreamController>()) {
    return;
  }

  final AccountBlockService service = Get.find<AccountBlockService>();

  service.configure(
    remoteLogout: () async {
      final AuthController auth = Get.find<AuthController>();
      final String token =
          auth.userProfile.value.token?.toString().trim() ?? '';
      if (token.isEmpty) return;

      final Dio dio = Dio();
      auth.configureProtectedDio(dio);
      await DeviceIdentityService.to.notifyBackendLogout(
        dio: dio,
        token: token,
      );
    },
    cleanupLiveSession: () async {
      final WebsocketController websocket = Get.find<WebsocketController>();
      final LivestreamController livestream = Get.find<LivestreamController>();

      try {
        livestream.stopLivePresenceHeartbeat();
      } catch (_) {}
      try {
        livestream.stopPingUpdate();
      } catch (_) {}
      try {
        livestream.resetPkState(clearResult: true);
      } catch (_) {}
      try {
        livestream.clearPkAgoraSession();
      } catch (_) {}
      try {
        livestream.clearViewerLocal();
      } catch (_) {}

      final int streamId = websocket.streamID.value > 0
          ? websocket.streamID.value
          : livestream.streamId.value;

      if (streamId > 0) {
        try {
          await websocket.liveCleanupService.forceExitLiveRoom(
            streamId: streamId,
            reason: 'forced_logout',
            goBottomNav: false,
          );
        } catch (error) {
          debugPrint('⚠️ Forced live cleanup skipped: $error');
        }
      }

      final AgoraService agora = AgoraService();
      try {
        await agora.engine?.muteLocalAudioStream(true);
      } catch (_) {}
      try {
        await agora.engine?.muteLocalVideoStream(true);
      } catch (_) {}
      try {
        await agora.engine?.stopPreview();
      } catch (_) {}
      try {
        await agora.leaveChannel();
      } catch (_) {}
      try {
        await stopLiveForegroundService();
      } catch (_) {}

      await websocket.shutdownAuthenticatedRealtimeForLogout();
    },
    clearLocalSession: () async {
      final AuthController auth = Get.find<AuthController>();

      try {
        // IMPORTANT: Never call preferences.clear() here.
        // DeviceIdentityService stores the stable physical-device UUID in the
        // same SharedPreferences database. Clearing everything generated a new
        // UUID after restart and allowed a blocked phone to appear as a new
        // device. Only the authenticated profile/session keys are removed.
        await auth.preferences.setString('profile', '');
      } catch (error) {
        debugPrint('⚠️ Profile storage clear skipped: $error');
      }

      await DeviceIdentityService.to.clearDeviceSession();

      auth.userProfile.value = UserProfile();
      auth.userProfile.refresh();
    },
    startRealtime: (int databaseUserId) async {
      final WebsocketController websocket = Get.find<WebsocketController>();

      websocket.resumeUnifiedLiveStreamReconnectAfterForeground();
      await websocket.tryToConnectToUnifiedLiveStreamEventWs(force: false);
      await websocket.ensureRechargeRealtimeSubscription();
      await websocket.ensureAccountBlockRealtimeSubscription();
      await websocket.ensureDeviceBlockRealtimeSubscription();
    },
    goToLogin:
        (
          String message,
          String? unblockAt,
          String? reason,
          bool blockedByAdmin,
          bool blockedDevice,
        ) async {
          try {
            if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
              Get.back();
            }
          } catch (_) {}

          Get.offAll(
            () => const LoginView(),
            arguments: <String, dynamic>{
              'account_blocked': blockedByAdmin,
              'device_blocked': blockedDevice,
              if (message.trim().isNotEmpty) 'message': message.trim(),
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
              if (unblockAt != null && unblockAt.trim().isNotEmpty)
                'unblock_at': unblockAt.trim(),
            },
          );

          if ((blockedByAdmin || blockedDevice) && message.trim().isNotEmpty) {
            unawaited(
              _showForceBlockedPopup(
                message: message.trim(),
                reason: reason,
                unblockAt: unblockAt,
                deviceBlocked: blockedDevice,
              ),
            );
          }
        },
  );

  final int currentUserId =
      Get.find<AuthController>().userProfile.value.user?.id?.toInt() ?? 0;
  if (currentUserId > 0) {
    unawaited(service.startAuthenticatedSession(databaseUserId: currentUserId));
  }
}

Future<void> _showForceBlockedPopup({
  required String message,
  required bool deviceBlocked,
  String? reason,
  String? unblockAt,
}) async {
  // Let Get.offAll fully remove Bottomnav/Firestore widgets before opening
  // the popup. This prevents the popup from being attached to the old route.
  await Future<void>.delayed(const Duration(milliseconds: 350));

  if (Get.overlayContext == null) {
    debugPrint('⚠️ Block popup skipped: overlay context is unavailable');
    return;
  }

  // Never stack two force-block popups.
  try {
    if (Get.isDialogOpen == true) {
      return;
    }
  } catch (_) {}

  final String safeMessage = message.trim().isEmpty
      ? (deviceBlocked
            ? 'This device has been blocked by the administrator.'
            : 'Your account has been blocked by the administrator.')
      : message.trim();
  final String safeReason = reason?.trim() ?? '';
  final String safeUnblockAt = unblockAt?.trim() ?? '';

  await Get.dialog<void>(
    PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xffffd8dd), width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(.20),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xffffeaed),
                  border: Border.all(
                    color: const Color(0xffffcbd1),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  deviceBlocked
                      ? Icons.phonelink_erase_rounded
                      : Icons.person_off_rounded,
                  size: 36,
                  color: const Color(0xffd42f40),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                deviceBlocked ? 'Device Blocked' : 'Account Blocked',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff20222b),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                safeMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff646874),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (safeReason.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff5f6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xffffd9dd)),
                  ),
                  child: Text(
                    'Reason: $safeReason',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xff8f2632),
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (safeUnblockAt.isNotEmpty) ...<Widget>[
                const SizedBox(height: 11),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xff858994),
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Unblock time: $safeUnblockAt',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xff777b87),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    if (Get.isDialogOpen == true) {
                      Get.back<void>();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffd42f40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(.52),
  );
}

void _configureForAndroidDevice() {
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

Future<void> _requestPermissions() async {
  try {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    debugPrint(
      '📋 Notification permission status: ${settings.authorizationStatus}',
    );
  } catch (e) {
    debugPrint('❌ Notification permission error: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static bool _isHandlingCall = false;

  @override
  State<MyApp> createState() => _MyAppState();

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction action) async {
    final String buttonKey = action.buttonKeyPressed;

    debugPrint('🔔 Notification action pressed: $buttonKey');

    if (buttonKey == 'Answer') {
      if (_isHandlingCall) {
        debugPrint('⚠️ Duplicate call ignored');
        return;
      }

      _isHandlingCall = true;

      try {
        service.invoke('stopCallRing');

        if (action.id != null) {
          await AwesomeNotifications().dismiss(action.id!);
        }

        final Map<String, dynamic> data = Map<String, dynamic>.from(
          notificationData,
        );

        debugPrint('📞 Answer notification data: $data');

        final String callerIdStr = data['caller_id']?.toString() ?? '0';
        final String callType = data['type']?.toString() ?? 'audio';

        final int callerUserId = int.tryParse(callerIdStr) ?? 0;

        debugPrint(
          '📞 Answer pressed => callerId: $callerUserId, type: $callType',
        );

        if (callerUserId == 0) {
          debugPrint('❌ Invalid caller ID');
          return;
        }

        final AuthController authController = Get.find<AuthController>();

        final int myUserId =
            authController.userProfile.value.user?.id?.toInt() ?? 0;

        if (myUserId == 0) {
          debugPrint('❌ Current user ID empty');
          return;
        }

        final AgoraTokenController agoraTokenController =
            Get.find<AgoraTokenController>();

        await agoraTokenController.tryToGenerateBroadcasterToken(
          isBroadcaster: true,
          userId: myUserId,
          channelName: '$callerUserId',
          streamId: '$callerUserId',
        );

        final dynamic token = agoraTokenController.agoraToken['token'];

        if (token == null || token.toString().trim().isEmpty) {
          debugPrint('❌ Token empty');
          return;
        }

        debugPrint('✅ Receiver token ready');

        if (callType == 'video') {
          Get.to(
            () => VideoCallView(
              channelName: '$callerUserId',
              isBroadcaster: false,
              token: token.toString(),
              profile: null,
              isOutGoingCall: false,
            ),
            arguments: data,
          );
        } else {
          Get.to(
            () => AudioCallView(
              channelName: '$callerUserId',
              isBroadcaster: false,
              token: token.toString(),
              profile: null,
              isOutGoingCall: false,
            ),
            arguments: data,
          );
        }
      } catch (e, s) {
        debugPrint('❌ Error handling answer action: $e');
        debugPrint('$s');
      } finally {
        Future.delayed(const Duration(seconds: 3), () {
          _isHandlingCall = false;
        });
      }
    } else if (buttonKey == 'Cancel') {
      try {
        service.invoke('stopCallRing');

        if (action.id != null) {
          await AwesomeNotifications().dismiss(action.id!);
        }

        debugPrint('📵 Call Cancelled/Rejected');
      } catch (e, s) {
        debugPrint('❌ Error handling cancel action: $e');
        debugPrint('$s');
      } finally {
        _isHandlingCall = false;
      }
    }
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<ReceivedAction>? _actionStreamSubscription;
  bool subscribedActionStream = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(handleInitialFirebaseMessage());
      unawaited(ChatPushNotificationService.instance.syncNow(force: true));
    });

    listen();
    WidgetsBinding.instance.addObserver(this);

    if (!subscribedActionStream) {
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: MyApp.onActionReceivedMethod,
      );

      subscribedActionStream = true;
      debugPrint('✅ AwesomeNotifications listener set from main.dart');
    }
  }

  void listen() async {
    await _actionStreamSubscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    unawaited(_handleAppLifecycleForLiveAudio(state));
  }

  Future<void> _handleAppLifecycleForLiveAudio(AppLifecycleState state) async {
    try {
      final WebsocketController ws = Get.find<WebsocketController>();
      final LivestreamController live = Get.find<LivestreamController>();

      final int activeStreamId = <int>[
        ws.streamID.value,
        ws.activeAudioStreamId.value,
        live.streamId.value,
      ].firstWhere((int value) => value > 0, orElse: () => 0);

      final bool hasActiveLiveAudio = activeStreamId > 0 || live.isLive.value;

      if (state == AppLifecycleState.resumed) {
        debugPrint('✅ App foreground: keep live realtime/audio active');
        ws.resumeUnifiedLiveStreamReconnectAfterForeground();

        if (hasActiveLiveAudio) {
          await startLiveForegroundService(
            title: live.isBroadcaster.value
                ? 'Lin Live host room running'
                : 'Lin Live audio room running',
            content: live.isBroadcaster.value
                ? 'Your microphone and live audio are active.'
                : 'Live audio is active.',
          );
        }
        return;
      }

      if (hasActiveLiveAudio) {
        // Do not pause the room websocket and never change Agora's local mute
        // state here. A user who manually muted must remain muted.
        ws.resumeUnifiedLiveStreamReconnectAfterForeground();

        if (state == AppLifecycleState.inactive) {
          // Android 14+ requires microphone foreground services to be started
          // while the app still has a visible activity. Normally AudioLiveView
          // already starts it before joining; this is a safe fallback.
          await startLiveForegroundService(
            title: live.isBroadcaster.value
                ? 'Lin Live host room running'
                : 'Lin Live audio room running',
            content: live.isBroadcaster.value
                ? 'Your microphone and live audio stay active in background.'
                : 'Live audio stays active in background.',
          );
        } else {
          await updateLiveForegroundService(
            title: live.isBroadcaster.value
                ? 'Lin Live host room running'
                : 'Lin Live audio room running',
            content: live.isBroadcaster.value
                ? 'Your microphone and live audio stay active in background.'
                : 'Live audio stays active in background.',
          );
        }

        debugPrint('🎙️ App background: live audio session kept active');
      } else {
        debugPrint('⏸️ App background without live: pause websocket reconnect');
        ws.pauseUnifiedLiveStreamReconnectForBackground();
      }
    } catch (e, s) {
      debugPrint('⚠️ Live audio lifecycle handling skipped safely: $e');
      debugPrint('$s');
    }
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _safeText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// ✅ Global Lucky Bag banner click => open target live room from anywhere.
  void _openGlobalLuckyBagLiveRoom(
    int livestreamId,
    Map<String, dynamic> packet,
  ) {
    debugPrint(
      '🎁 Global Lucky Bag click => livestreamId=$livestreamId packetId=${packet['id']}',
    );

    if (livestreamId <= 0) {
      return;
    }

    final sender = packet['sender'] is Map
        ? Map<String, dynamic>.from(packet['sender'])
        : <String, dynamic>{};

    final int ownerId = _safeInt(
      packet['owner_user_id'] ??
          packet['user_id'] ??
          packet['sender_id'] ??
          sender['id'] ??
          sender['user_id'],
    );

    final String channelName = _firstText([
      packet['room_id'],
      packet['channel_name'],
      packet['agora_channel'],
      packet['agora_channel_name'],
      packet['live_channel'],
      ownerId,
    ]);

    if (channelName.isEmpty) {
      return;
    }

    final Map<String, dynamic> liveData = <String, dynamic>{
      ...packet,
      'id': livestreamId,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'room_id': channelName,
      'channel_name': channelName,
      'agora_channel': channelName,
      'agora_channel_name': channelName,
      'owner_user_id': ownerId,
      'user_id': ownerId,
      'stream_type': _safeText(packet['stream_type']).isEmpty
          ? 'audio'
          : _safeText(packet['stream_type']),
      if (sender.isNotEmpty) 'user': sender,
      if (sender.isNotEmpty) 'User': sender,
      'global_lucky_bag_packet': Map<String, dynamic>.from(packet),
      'global_banner_type': 'lucky_bag',
    };

    final AudienceJoinController joinController =
        Get.isRegistered<AudienceJoinController>()
        ? Get.find<AudienceJoinController>()
        : Get.put(AudienceJoinController());

    joinController.joinAsAudience(channelName: channelName, data: liveData);
  }

  /// Global Lucky Gift banner click => open the winning live room from any page.
  /// Uses the same AudienceJoinController path as Global Lucky Bag.
  void _openGlobalLuckyGiftLiveRoom(
    int livestreamId,
    Map<String, dynamic> result, {
    String bannerType = 'lucky',
  }) {
    debugPrint(
      '🍀 Global Lucky Gift click => livestreamId=$livestreamId '
      'event=${result['event_id'] ?? result['result_event_id']}',
    );

    if (livestreamId <= 0) return;

    try {
      final LivestreamController liveController =
          Get.find<LivestreamController>();

      if (liveController.streamId.value == livestreamId) {
        return;
      }

      final WebsocketController ws = Get.find<WebsocketController>();
      if (ws.streamID.value == livestreamId ||
          ws.activeAudioStreamId.value == livestreamId) {
        return;
      }
    } catch (_) {}

    Map<String, dynamic> cachedRoom = <String, dynamic>{};
    try {
      if (Get.isRegistered<HomeController>()) {
        final HomeController home = Get.find<HomeController>();
        final dynamic found = home.showingLiveStreamList.firstWhere((
          dynamic raw,
        ) {
          if (raw is! Map) return false;
          final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
          return _safeInt(
                item['livestream_id'] ??
                    item['stream_id'] ??
                    item['live_stream_id'] ??
                    item['id'],
              ) ==
              livestreamId;
        }, orElse: () => null);
        if (found is Map) {
          cachedRoom = Map<String, dynamic>.from(found);
        }
      }
    } catch (_) {}

    final Map<String, dynamic> broadcaster = result['broadcaster'] is Map
        ? Map<String, dynamic>.from(result['broadcaster'])
        : <String, dynamic>{};
    final Map<String, dynamic> cachedUser = cachedRoom['user'] is Map
        ? Map<String, dynamic>.from(cachedRoom['user'])
        : cachedRoom['User'] is Map
        ? Map<String, dynamic>.from(cachedRoom['User'])
        : <String, dynamic>{};

    final Map<String, dynamic> roomUser = <String, dynamic>{
      ...broadcaster,
      ...cachedUser,
    };

    final int ownerId = _safeInt(
      cachedRoom['owner_user_id'] ??
          cachedRoom['user_id'] ??
          result['owner_user_id'] ??
          result['host_id'] ??
          result['broadcaster_id'] ??
          roomUser['id'] ??
          roomUser['user_id'],
    );

    final Map<String, dynamic> liveData = <String, dynamic>{
      ...result,
      ...cachedRoom,
      'id': livestreamId,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      if (ownerId > 0) 'owner_user_id': ownerId,
      if (ownerId > 0) 'user_id': ownerId,
      if (roomUser.isNotEmpty) 'user': roomUser,
      if (roomUser.isNotEmpty) 'User': roomUser,
      'stream_type': _firstText([
        cachedRoom['stream_type'],
        result['stream_type'],
        'audio',
      ]),
      'global_lucky_event': Map<String, dynamic>.from(result),
      'global_banner_type': bannerType,
    };

    final String channelName = _firstText([
      cachedRoom['room_id'],
      cachedRoom['channel_name'],
      cachedRoom['agora_channel'],
      cachedRoom['agora_channel_name'],
      result['room_id'],
      result['channel_name'],
      result['agora_channel'],
      result['agora_channel_name'],
      roomUser['room_id'],
      ownerId,
    ]);

    if (channelName.isEmpty) return;

    final AudienceJoinController joinController =
        Get.isRegistered<AudienceJoinController>()
        ? Get.find<AudienceJoinController>()
        : Get.put(AudienceJoinController());

    joinController.joinAsAudience(channelName: channelName, data: liveData);
  }

  /// Global Rocket banner click => open the launched live room from any page.
  void _openGlobalRocketLiveRoom(int livestreamId, Map<String, dynamic> data) {
    debugPrint(
      '🚀 Global Rocket click => livestreamId=$livestreamId '
      'level=${data['level_no'] ?? data['level']}',
    );
    _openGlobalLuckyGiftLiveRoom(livestreamId, data, bannerType: 'rocket');
  }

  void _openGlobalBigGiftLiveRoom(
    int livestreamId,
    Map<String, dynamic> data,
  ) {
    _openGlobalLuckyGiftLiveRoom(
      livestreamId,
      data,
      bannerType: 'big_gift',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: ('Lin Live').appTr,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
      locale: AppLanguageController.to.currentLocale.value,
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
        Locale('ta', 'IN'),
        Locale('ml', 'IN'),
        Locale('tr', 'TR'),
        Locale('ne', 'NP'),
        Locale('es', 'ES'),
        Locale('ru', 'RU'),
        Locale('bn', 'BD'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
        Locale('ar', 'SA'),
        Locale('zh', 'TW'),
        Locale('zh', 'CN'),
      ],

      /// ✅ Global Lucky Bag banner must be here, not only Bottomnav.
      /// This makes banner visible on Home, Message, Me, Live room, and all routes.
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            GlobalLuckyBagBanner(onOpenLive: _openGlobalLuckyBagLiveRoom),
            GlobalLuckyWinBanner(onOpenLive: _openGlobalLuckyGiftLiveRoom),
            GlobalRocketLaunchBanner(onOpenLive: _openGlobalRocketLiveRoom),
            GlobalBigGiftBanner(onOpenLive: _openGlobalBigGiftLiveRoom),
            const MinimizedVideoLiveWindow(),
          ],
        );
      },

      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF9e28b4),
        ),
        primaryColor: const Color(0xFF9e28b4),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
    );
  }
}
