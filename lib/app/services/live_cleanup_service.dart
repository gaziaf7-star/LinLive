import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import 'agora_service.dart';
import 'package:get/get.dart';

import '../modules/bottomnav/views/bottomnav_view.dart';
import '../modules/livestream/controllers/livestream_controller.dart';
import '../modules/livestream/controllers/websocket_controller.dart';

/// Central cleanup for every live exit path.
/// Prevents duplicated Get.back, snackbar crash, ghost Agora channel, and stale lists.
class LiveCleanupService {
  LiveCleanupService({
    required this.websocketController,
    required this.livestreamController,
    required this.engineProvider,
  });

  final WebsocketController websocketController;
  final LivestreamController livestreamController;
  final RtcEngine? Function() engineProvider;
  bool _cleaning = false;

  Future<void> forceExitLiveRoom({
    required int streamId,
    String reason = 'live_end',
    bool goBottomNav = true,
  }) async {
    if (_cleaning) return;
    _cleaning = true;

    try {
      websocketController.streamID.value = 0;
      websocketController.activeAudioStreamId.value = 0;
      livestreamController.streamId.value = 0;
      livestreamController.isBroadcaster.value = false;
      livestreamController.isHost.value = false;
      livestreamController.mute.value = false;
      livestreamController.liveMusicStatus.value = 'stopped';
      livestreamController.liveYoutubeStatus.value = 'stopped';
      livestreamController.liveYoutubeUrl.value = '';
      livestreamController.liveYoutubeVideoId.value = '';
      livestreamController.liveViewerList.clear();
      livestreamController.liveViewerList.refresh();

      websocketController.liveCallList.clear();
      websocketController.pendingCall.clear();
      websocketController.commentsList.clear();
      websocketController.giftMessagesList.clear();
      websocketController.liveCallList.refresh();
      websocketController.pendingCall.refresh();
      websocketController.commentsList.refresh();
      websocketController.giftMessagesList.refresh();
      websocketController.liveMusicStatus.value = 'stopped';
      websocketController.liveYoutubeStatus.value = 'stopped';
      websocketController.liveYoutubeUrl.value = '';
      websocketController.liveYoutubeVideoId.value = '';
      websocketController.newViewersJoinded.value = false;
      websocketController.newJoinedUserData.value = <String, dynamic>{};
      websocketController.audioMutedUserMap.clear();
      websocketController.audioMutedUserMap.refresh();

      try {
        livestreamController.stopLivePresenceHeartbeat();
      } catch (_) {}
      try {
        livestreamController.stopLive();
      } catch (_) {}
      try {
        await AgoraService().leaveChannel();
      } catch (e) {
        debugPrint('leaveChannel skipped: $e');
      }

      _safeCloseOverlay();

      if (goBottomNav) {
        Future.microtask(() {
          if (Get.currentRoute != '/BottomnavView') {
            Get.offAll(
              () => BottomnavView(),
              transition: Transition.cupertino,
              duration: const Duration(milliseconds: 280),
            );
          }
        });
      }
    } finally {
      Future.delayed(
        const Duration(milliseconds: 700),
        () => _cleaning = false,
      );
    }
  }

  void _safeCloseOverlay() {
    try {
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
        final context = Get.overlayContext;
        if (context != null &&
            Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (e) {
      debugPrint('safe overlay close skipped: $e');
    }
  }
}
