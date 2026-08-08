import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../../constants/constants.dart';
import 'livestream_controller.dart';

class RenderStreamVideoController extends GetxController {
  final activeCallList = <Widget>[].obs;
  LivestreamController liveController = Get.find();

  Future<List<Widget>> getRenderViews({
    required List<dynamic> listActiveCalls,
    required bool muted,
    required bool videoDisabled,
    required String chanelName,
    required bool isBroadcaster,
    required int broadcasterId,
    required RtcEngine engine,
  }) async {
    List<Widget> renderViews = [];

    if (listActiveCalls.isEmpty) {
      return renderViews;
    }

    for (var activeCallData in listActiveCalls) {
      int uid;
      try {
        uid = int.parse(activeCallData['id']?.toString() ?? '0');
      } catch (e) {
        print('Error parsing uid: $e');

        continue;
      }

      if (uid == broadcasterId) {
        if (isBroadcaster) {
          renderViews.add(
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: uid),
              ),
            ),
          );
        } else {
          renderViews.add(
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: engine,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: chanelName),
              ),
            ),
          );
        }
      } else {
        try {
          if (uid == authController.userProfile.value.user!.id!) {
            await engine.setClientRole(
              role: ClientRoleType.clientRoleBroadcaster,
            );
            renderViews.add(
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: uid),
                ),
              ),
            );
          } else {
            renderViews.add(
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: uid),
                  connection: RtcConnection(channelId: chanelName),
                ),
              ),
            );
          }
        } catch (e) {
          print('Error handling user view: $e');
          continue;
        }
      }
    }

    return renderViews;
  }

  @override
  void onClose() {
    activeCallList.clear();
    super.onClose();
  }
}
