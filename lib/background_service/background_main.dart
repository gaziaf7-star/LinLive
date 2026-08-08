import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterBackgroundService service = FlutterBackgroundService();

const String kLinLiveForegroundChannelId = 'linlive_live_audio';
const String kLinLiveForegroundChannelName = 'LIN LIVE AUDIO';
const int kLinLiveForegroundNotificationId = 888;

/// One shared future prevents two callers from configuring the same service
/// at the same time.
Future<void>? _configurationFuture;

/// One shared future prevents concurrent startService() requests.
Future<void>? _startFuture;

/// Configure once from main().
Future<void> initializeBackgroundService() {
  return _configurationFuture ??= _configureBackgroundService();
}

Future<void> _configureBackgroundService() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kLinLiveForegroundChannelId,
    kLinLiveForegroundChannelName,
    description: 'Keeps Lin Live audio rooms and calls active in background.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  await notifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: kLinLiveForegroundChannelId,
      initialNotificationTitle: 'Lin Live audio room',
      initialNotificationContent: 'Live audio is active',
      foregroundServiceNotificationId: kLinLiveForegroundNotificationId,
      foregroundServiceTypes: const <AndroidForegroundType>[
        AndroidForegroundType.mediaPlayback,
        AndroidForegroundType.microphone,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  debugPrint('✅ Background audio service configured once');
}

Future<bool> _safeIsServiceRunning() async {
  try {
    return await service.isRunning();
  } catch (error) {
    debugPrint('⚠️ Background service running check failed: $error');
    return false;
  }
}

Future<void> _ensureServiceStarted() async {
  if (await _safeIsServiceRunning()) return;

  final Future<void>? existingStart = _startFuture;
  if (existingStart != null) {
    await existingStart;
    return;
  }

  final Future<void> operation = _startServiceInternal();
  _startFuture = operation;

  try {
    await operation;
  } finally {
    if (identical(_startFuture, operation)) {
      _startFuture = null;
    }
  }
}

Future<void> _startServiceInternal() async {
  if (await _safeIsServiceRunning()) return;

  try {
    await service.startService();
  } catch (error, stackTrace) {
    debugPrint('❌ Background service start failed: $error');
    debugPrint('$stackTrace');
    return;
  }

  // Wait briefly until the background isolate is ready to receive events.
  for (int attempt = 0; attempt < 20; attempt++) {
    if (await _safeIsServiceRunning()) {
      debugPrint('✅ Background audio service started');
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  debugPrint('⚠️ Background audio service did not report running in time');
}

/// Call this only while the app is still foreground and the user is entering
/// an audio room/call. Do not call it from paused/inactive lifecycle callbacks.
Future<void> startLiveForegroundService({
  String title = 'Lin Live audio room running',
  String content = 'Live audio is active. Tap to return.',
}) async {
  await initializeBackgroundService();
  await _ensureServiceStarted();

  if (!await _safeIsServiceRunning()) return;

  service.invoke('liveAudioStart', <String, dynamic>{
    'title': title,
    'content': content,
  });
}

/// Call only on real room exit/end/logout.
Future<void> stopLiveForegroundService() async {
  if (!await _safeIsServiceRunning()) return;
  service.invoke('liveAudioStop');
}

/// This updates an already-running service. It never starts the service.
Future<void> updateLiveForegroundService({
  required String title,
  required String content,
}) async {
  if (!await _safeIsServiceRunning()) return;

  service.invoke('liveAudioUpdate', <String, dynamic>{
    'title': title,
    'content': content,
  });
}

Future<void> stopCallRingSafely() async {
  if (!await _safeIsServiceRunning()) return;
  service.invoke('stopCallRing');
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  int peeredUserId = 0;
  String? peeredUserImage;
  String? peeredUserName;
  String? peeredUserCallType;

  bool isLiveAudioRunning = false;
  bool isCallRinging = false;

  AudioPlayer? ringPlayer;
  Timer? statusTimer;

  Future<void> setForegroundInfo({
    required String title,
    required String content,
  }) async {
    if (service is! AndroidServiceInstance) return;

    try {
      await service.setAsForegroundService();
      await service.setForegroundNotificationInfo(
        title: title,
        content: content,
      );
    } catch (error) {
      debugPrint('⚠️ Foreground notification update failed: $error');
    }
  }

  void ensureStatusTimer() {
    if (statusTimer?.isActive == true) return;

    statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isLiveAudioRunning && !isCallRinging) return;

      service.invoke('update', <String, dynamic>{
        'peeredUserId': peeredUserId,
        'peeredUserImage': peeredUserImage,
        'peeredUserName': peeredUserName,
        'peeredUserCallType': peeredUserCallType,
        'ringing_state': ringPlayer?.state.name ?? 'stopped',
        'live_audio_running': isLiveAudioRunning,
        'call_ringing': isCallRinging,
      });
    });
  }

  Future<AudioPlayer> getRingPlayer() async {
    final AudioPlayer? current = ringPlayer;
    if (current != null) return current;

    final AudioPlayer created = AudioPlayer(
      playerId: 'linlive_call_ring',
    );
    ringPlayer = created;
    return created;
  }

  Future<void> stopAndReleaseRingPlayer() async {
    final AudioPlayer? player = ringPlayer;
    ringPlayer = null;

    if (player == null) return;

    try {
      await player.stop();
    } catch (_) {}

    try {
      await player.release();
    } catch (_) {}
  }

  Future<void> stopServiceIfIdle() async {
    if (isLiveAudioRunning || isCallRinging) return;

    statusTimer?.cancel();
    statusTimer = null;

    await stopAndReleaseRingPlayer();

    try {
      service.stopSelf();
    } catch (error) {
      debugPrint('⚠️ Background service stop failed: $error');
    }
  }

  service.on('liveAudioStart').listen((Map<String, dynamic>? event) async {
    isLiveAudioRunning = true;
    ensureStatusTimer();

    await setForegroundInfo(
      title: event?['title']?.toString() ??
          'Lin Live audio room running',
      content: event?['content']?.toString() ??
          'Live audio is active. Tap to return.',
    );
  });

  service.on('liveAudioUpdate').listen((Map<String, dynamic>? event) async {
    if (!isLiveAudioRunning) return;

    await setForegroundInfo(
      title: event?['title']?.toString() ??
          'Lin Live audio room running',
      content: event?['content']?.toString() ??
          'Live audio is active. Tap to return.',
    );
  });

  service.on('liveAudioStop').listen((Map<String, dynamic>? event) async {
    isLiveAudioRunning = false;
    await stopServiceIfIdle();
  });

  service.on('playCallRing').listen((Map<String, dynamic>? event) async {
    if (event == null) return;

    isCallRinging = true;
    ensureStatusTimer();

    peeredUserId = int.tryParse('${event['peeredUserId'] ?? 0}') ?? 0;
    peeredUserImage = event['peeredUserImage']?.toString();
    peeredUserName = event['peeredUserName']?.toString();
    peeredUserCallType = event['peeredUserCallType']?.toString();

    await setForegroundInfo(
      title: peeredUserName == null || peeredUserName!.trim().isEmpty
          ? 'Incoming Lin Live call'
          : 'Incoming call from $peeredUserName',
      content: 'Tap to answer the call',
    );

    try {
      final AudioPlayer player = await getRingPlayer();

      await player.stop();
      await player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const <AVAudioSessionOptions>{
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource('facebook_call_ringtone.mp3'),
      );
    } catch (error) {
      debugPrint('⚠️ Background call ringtone failed: $error');
    }
  });

  service.on('stopCallRing').listen((Map<String, dynamic>? event) async {
    isCallRinging = false;

    final AudioPlayer? player = ringPlayer;
    if (player != null) {
      try {
        await player.stop();
        await player.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }

    if (isLiveAudioRunning) {
      await setForegroundInfo(
        title: 'Lin Live audio room running',
        content: 'Live audio is active. Tap to return.',
      );
    } else {
      await stopServiceIfIdle();
    }
  });

  service.on('stopService').listen((Map<String, dynamic>? event) async {
    isLiveAudioRunning = false;
    isCallRinging = false;
    await stopServiceIfIdle();
  });
}
