import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../constants/constants.dart';
import 'livestream_controller.dart';
import '../socket/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveStreamActionController extends GetxController {
  final LivestreamController liveController = Get.find<LivestreamController>();
  final WebsocketController websocketController =
  Get.find<WebsocketController>();

  // Kick out user function
  Future<void> kickoutUser(int userId) async {
    try {
      // Call API to kick out user
      bool success = await liveController.kickOutUser(userId);

      if (success) {
        // Remove user from local lists
        websocketController.liveCallList.removeWhere((call) {
          if (call is! Map) return false;
          final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
          final callerId = call['caller_id'];
          final userIdField = call['user_id'];
          return nestedUserId.toString() == userId.toString() ||
              callerId.toString() == userId.toString() ||
              userIdField.toString() == userId.toString();
        });

        liveController.liveViewerList.removeWhere((viewer) {
          if (viewer is! Map) return false;
          final nestedUserId = viewer['user'] is Map ? viewer['user']['id'] : null;
          final viewerId = viewer['viewer_id'];
          final userIdField = viewer['user_id'];
          final directId = viewer['id'];
          return nestedUserId.toString() == userId.toString() ||
              viewerId.toString() == userId.toString() ||
              userIdField.toString() == userId.toString() ||
              directId.toString() == userId.toString();
        });

        Fluttertoast.showToast(
          msg: ("User has been kicked out successfully").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Failed to kick out user").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error kicking out user: $e');
      Fluttertoast.showToast(
        msg: ("Error occurred while kicking out user").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Toggle user audio (mute/unmute)
  Future<void> toggleUserAudio(int userId, bool mute) async {
    try {
      final result = await liveController.toggleUserAudio(
        websocketController.streamID.value,
        userId,
      );

      if (result != null && result['success'] == true) {
        final callIndex = websocketController.liveCallList.indexWhere((call) {
          if (call is! Map) return false;
          final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
          final callerId = call['caller_id'];
          final userIdField = call['user_id'];
          return nestedUserId.toString() == userId.toString() ||
              callerId.toString() == userId.toString() ||
              userIdField.toString() == userId.toString();
        });

        if (callIndex != -1) {
          // Ensure audio_on is stored as 1/0 format
          final audioOnValue = result['audio_on'];
          websocketController.liveCallList[callIndex]['audio_on'] =
          audioOnValue is bool ? (audioOnValue ? 1 : 0) : audioOnValue;
          websocketController.liveCallList.refresh();
        }

        Fluttertoast.showToast(
          msg: (result['audio_on'] == true || result['audio_on'].toString() == '1')
              ? ("User audio unmuted").appTr: ("User audio muted").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: (result['audio_on'] == true || result['audio_on'].toString() == '1')
              ? Colors.green
              : Colors.redAccent,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Failed to toggle user audio").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error toggling user audio: $e');
      Fluttertoast.showToast(
        msg: ("Error occurred while toggling audio").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Toggle user video (mute/unmute)
  Future<void> toggleUserVideo(int userId, bool mute) async {
    try {
      final result = await liveController.toggleUserVideo(
        websocketController.streamID.value,
        userId,
      );

      if (result != null && result['success'] == true) {
        final callIndex = websocketController.liveCallList.indexWhere((call) {
          if (call is! Map) return false;
          final nestedUserId = call['user'] is Map ? call['user']['id'] : null;
          final callerId = call['caller_id'];
          final userIdField = call['user_id'];
          return nestedUserId.toString() == userId.toString() ||
              callerId.toString() == userId.toString() ||
              userIdField.toString() == userId.toString();
        });

        if (callIndex != -1) {
          // Ensure video_on is stored as 1/0 format
          final videoOnValue = result['video_on'];
          websocketController.liveCallList[callIndex]['video_on'] =
          videoOnValue is bool ? (videoOnValue ? 1 : 0) : videoOnValue;
          websocketController.liveCallList.refresh();
        }

        Fluttertoast.showToast(
          msg: (result['video_on'] == true || result['video_on'].toString() == '1')
              ? ("User video unmuted").appTr: ("User video muted").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: (result['video_on'] == true || result['video_on'].toString() == '1')
              ? Colors.green
              : Colors.redAccent,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: ("Failed to toggle user video").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error toggling user video: $e');
      Fluttertoast.showToast(
        msg: ("Error occurred while toggling video").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
