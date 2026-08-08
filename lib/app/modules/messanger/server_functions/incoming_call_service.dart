import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../livestream/controllers/agoraTokenController.dart';
import '../views/audio_call_view.dart';
import '../views/video_call_view.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class IncomingCallService {
  static final IncomingCallService instance = IncomingCallService._internal();

  IncomingCallService._internal();

  static String? currentCallUuid;

  static void init() {
    FlutterCallkitIncoming.onEvent.listen((callEvent) async {
      if (callEvent == null) return;

      final String eventName = callEvent.eventName;

      Map<String, dynamic> body = <String, dynamic>{};
      Map<String, dynamic> extra = <String, dynamic>{};

      try {
        body = Map<String, dynamic>.from(
          FlutterCallkitIncoming.callActionBody(callEvent),
        );

        if (body['extra'] is Map) {
          extra = Map<String, dynamic>.from(body['extra']);
        } else {
          extra = Map<String, dynamic>.from(body);
        }
      } catch (e) {
        debugPrint('⚠️ CallKit body parse error: $e');
      }

      debugPrint('📞 CallKit Event: $eventName');
      debugPrint('📞 Body: $body');
      debugPrint('📞 Extra: $extra');

      if (eventName == 'actionCallAccept') {
        await _onAccept(extra);
      } else if (eventName == 'actionCallDecline') {
        await _onReject(extra);
      } else if (eventName == 'actionCallEnded') {
        await _onReject(extra);
      } else if (eventName == 'actionCallTimeout') {
        await _onReject(extra);
      }
    });
  }

  static Future<void> showIncomingCall({
    required String callerId,
    required String callerName,
    required String callerImage,
    required String receiverId,
    required String channelName,
    required String callType,
    required String callId,
  }) async {
    final String uuid = const Uuid().v4();
    currentCallUuid = uuid;

    final params = CallKitParams(
      id: uuid,
      nameCaller: callerName,
      appName: 'Lin Live',
      avatar: callerImage,
      handle: callerName,
      type: callType == 'video' ? 1 : 0,
      duration: 30000,

      // ✅ textAccept / textDecline remove করা হয়েছে,
      // কারণ আপনার package version এ এগুলো নেই।

      missedCallNotification:  NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: ('Missed call').appTr,
      ),

      extra: {
        'call_id': callId,
        'caller_id': callerId,
        'receiver_id': receiverId,
        'caller_name': callerName,
        'caller_image': callerImage,
        'channel_name': channelName,
        'call_type': callType,
      },

      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#111111',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
        isShowFullLockedScreen: true,
      ),

      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static Future<void> _onAccept(Map<String, dynamic> extra) async {
    final String callType = extra['call_type']?.toString() ?? 'audio';
    final String channelName = extra['channel_name']?.toString() ?? '';
    final String callerId = extra['caller_id']?.toString() ?? '';
    final String receiverId = extra['receiver_id']?.toString() ?? '';

    if (channelName.isEmpty) {
      debugPrint('❌ channelName empty');
      return;
    }

    final int myUserId = int.tryParse(receiverId) ?? 0;

    if (myUserId == 0) {
      debugPrint('❌ receiver_id empty');
      return;
    }

    final agoraTokenController = Get.find<AgoraTokenController>();

    await agoraTokenController.tryToGenerateBroadcasterToken(
      isBroadcaster: true,
      userId: myUserId,
      channelName: channelName,
      streamId: channelName,
    );

    final token = agoraTokenController.agoraToken['token'];

    if (token == null || token.toString().isEmpty) {
      debugPrint('❌ Accept token empty');
      return;
    }

    final callerData = {
      'User Data': {
        'id': callerId,
        'name': extra['caller_name'] ?? 'User',
        'profile_image': extra['caller_image'] ?? '',
      },
      'profile_image': extra['caller_image'] ?? '',
      'peeredUserName': extra['caller_name'] ?? 'User',
      'caller_name': extra['caller_name'] ?? 'User',
      'caller_image': extra['caller_image'] ?? '',
      'call_type': callType,
      'channel_name': channelName,
    };

    if (callType == 'video') {
      Get.to(
            () => VideoCallView(
          channelName: channelName,
          isBroadcaster: false,
          token: token.toString(),
          profile: null,
          isOutGoingCall: false,
        ),
        arguments: callerData,
      );
    } else {
      Get.to(
            () => AudioCallView(
          channelName: channelName,
          isBroadcaster: false,
          token: token.toString(),
          profile: null,
          isOutGoingCall: false,
        ),
        arguments: callerData,
      );
    }
  }

  static Future<void> _onReject(Map<String, dynamic> extra) async {
    debugPrint('📴 Call rejected/ended: $extra');

    if (currentCallUuid != null) {
      await FlutterCallkitIncoming.endCall(currentCallUuid!);
      currentCallUuid = null;
    }
  }

  static Future<void> endCurrentCall() async {
    if (currentCallUuid != null) {
      await FlutterCallkitIncoming.endCall(currentCallUuid!);
      currentCallUuid = null;
    }
  }
}