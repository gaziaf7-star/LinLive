import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import 'agora_service.dart';
import 'package:get/get.dart';

import '../modules/bottomnav/views/bottomnav_view.dart';
import '../modules/livestream/controllers/livestream_controller.dart';
import '../modules/livestream/socket/websocket_controller.dart';

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

  Future<void> leaveBeforeJoining({
    required int oldStreamId,
    required int targetStreamId,
    required int userId,
    required int generation,
    required bool wasBroadcaster,
    required bool wasPermanentRoom,
    required bool isBannerNavigation,
  }) async {
    if (isBannerNavigation) {
      debugPrint(
        'BANNER_SWITCH_START source=$oldStreamId target=$targetStreamId '
        'generation=$generation user=$userId '
        'sourceRole=${wasBroadcaster ? 'broadcaster' : 'viewer'} '
        'targetRole=audience seat=0 calls=${websocketController.liveCallList.length}',
      );
      debugPrint('SOURCE_LEAVE_START source=$oldStreamId target=$targetStreamId');
    }
    websocketController.beginRoomTransition(
      generation: generation,
      oldStreamId: oldStreamId,
    );

    livestreamController.stopPingUpdate();
    livestreamController.stopLivePresenceHeartbeat();

    final bool wasSeatUser = websocketController.liveCallList.any((raw) {
      if (raw is! Map) return false;
      final user = raw['user'] is Map ? raw['user'] as Map : const {};
      final id =
          int.tryParse(
            '${raw['caller_id'] ?? raw['user_id'] ?? user['id'] ?? 0}',
          ) ??
          0;
      return id == userId;
    });
    if (isBannerNavigation) {
      debugPrint(
        'SOURCE_EXIT_MODE source=$oldStreamId '
        'role=${wasBroadcaster
            ? 'host'
            : wasSeatUser
            ? 'seat'
            : 'audience'} '
        'action=${wasBroadcaster
            ? 'close_live'
            : wasSeatUser
            ? 'release_seat'
            : 'leave_viewer'}',
      );
    }

    Future<void> timed(String stage, Future<void> Function() operation) async {
      final stopwatch = Stopwatch()..start();
      if (isBannerNavigation) debugPrint('${stage}_START');
      await operation();
      if (isBannerNavigation) {
        debugPrint('${stage}_DONE elapsed=${stopwatch.elapsedMilliseconds}ms');
      }
    }

    Future<void> exitBackend() async {
      if (oldStreamId <= 0) return;
      if (wasBroadcaster) {
        if (wasPermanentRoom) {
          await livestreamController.closePermanentRoom(
            livestreamId: oldStreamId,
            navigateToEnd: false,
          );
        } else {
          await livestreamController.tryToRemoveLivestream(
            streamId: oldStreamId,
            navigateToEnd: false,
          );
        }
      } else if (userId > 0) {
        await Future.wait<void>([
          if (wasSeatUser)
            livestreamController
                .tryToRejectCall(streamId: oldStreamId, userId: userId)
                .then<void>((_) {}),
          livestreamController.tryToRemoveViewer(
            streamId: oldStreamId,
            viewerId: userId,
          ),
        ]);
      }
    }

    final backendExit = timed('SOURCE_BACKEND_EXIT', exitBackend);
    final presenceExit = timed('SOURCE_PRESENCE_EXIT', () async {
      if (oldStreamId > 0) {
        await livestreamController.markUserOffline(
          livestreamId: oldStreamId,
          role: wasBroadcaster
              ? 'host'
              : wasSeatUser
              ? 'caller'
              : 'viewer',
        );
      }
    });
    final socketDetach = timed('SOURCE_SOCKET_DETACH', () async {
      if (oldStreamId > 0) {
        await websocketController.leaveVideoRoomState(
          livestreamId: oldStreamId,
        );
      }
    });
    final agoraLeave = timed(
      'SOURCE_AGORA_LEAVE',
      () => AgoraService().leaveChannel(),
    );

    // The generation boundary above already rejects Room A. Reset against the
    // source id only; target compatibility state must not become active until
    // this complete leave barrier returns.
    livestreamController.clearMinimizedVideoLiveSession();
    if (oldStreamId > 0) {
      livestreamController.resetLocalLiveStateForNewStream(
        newStreamId: oldStreamId,
        source: 'leave_before_banner_join',
        force: true,
      );
      websocketController.resetAudioRoomStateForStream(
        newStreamId: oldStreamId,
        force: true,
      );
    }

    await Future.wait<void>([
      backendExit,
      presenceExit,
      socketDetach,
      agoraLeave,
    ]);
    if (isBannerNavigation) {
      debugPrint(
        'SOURCE_ROOM_CLEANUP_DONE source=$oldStreamId target=$targetStreamId '
        'generation=$generation user=$userId',
      );
    }

    if (isBannerNavigation) {
      debugPrint(
        'SOURCE_AGORA_LEFT source=$oldStreamId target=$targetStreamId '
        'generation=$generation user=$userId',
      );
    }
    if (isBannerNavigation) {
      debugPrint(
        'SOURCE_CALL_SEAT_CLEARED source=$oldStreamId target=$targetStreamId '
        'generation=$generation user=$userId seat=0 '
        'calls=${websocketController.liveCallList.length}',
      );
    }

    // Keep the target inactive until access checks and token generation complete.
    livestreamController.streamId.value = 0;
    websocketController.streamID.value = 0;
    websocketController.activeAudioStreamId.value = 0;
    livestreamController.isHost.value = false;
    livestreamController.isBroadcaster.value = false;
    livestreamController.broadcasterId.value = 0;
    livestreamController.createStreamData.clear();
    livestreamController.createStreamData.refresh();
    livestreamController.clearViewerLocal();
    livestreamController.viewerList.clear();
    livestreamController.callList.clear();
    livestreamController.videoCallerAgoraUidMap.clear();
    livestreamController.videoCallerAgoraUidMap.refresh();
    websocketController.liveCallList.clear();
    websocketController.pendingCall.clear();
    websocketController.audioMutedUserMap.clear();
    websocketController.liveCallList.refresh();
    websocketController.pendingCall.refresh();
    websocketController.audioMutedUserMap.refresh();
    if (isBannerNavigation) {
      debugPrint('SOURCE_LOCAL_RESET_DONE source=$oldStreamId');
      debugPrint(
        'SOURCE_LEAVE_COMPLETE source=$oldStreamId target=$targetStreamId '
        'generation=$generation stream=${livestreamController.streamId.value} '
        'host=${livestreamController.isHost.value} '
        'broadcaster=${livestreamController.isBroadcaster.value} '
        'calls=${websocketController.liveCallList.length}',
      );
    }
  }

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
      livestreamController.liveYoutubeController.resetYoutubeState();
      livestreamController.liveEmojiController.resetRoomEmojiState();
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
