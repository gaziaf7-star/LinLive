import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';

import '../../../services/agora_service.dart';
import 'livestream_controller.dart';
import '../socket/websocket_controller.dart';

/// Owns video-live remote media identity and minimized-renderer orchestration.
/// Agora engine/channel lifecycle and caller lifecycle remain with their
/// existing authoritative owners.
class LiveVideoSessionController extends GetxController {
  LiveVideoSessionController(this.livestreamController);

  final LivestreamController livestreamController;

  final RxBool isVideoLiveMinimized = false.obs;
  final RxMap<String, dynamic> minimizedVideoLiveSession =
      <String, dynamic>{}.obs;
  final RxSet<int> videoLiveRemoteUids = <int>{}.obs;
  final RxMap<int, bool> videoLiveRemoteVideoEnabled = <int, bool>{}.obs;
  final RxMap<int, int> videoCallerAgoraUidMap = <int, int>{}.obs;

  RtcEngineEventHandler? _minimizedVideoEventHandler;

  int get _minimizedLivestreamId =>
      int.tryParse('${minimizedVideoLiveSession['livestream_id'] ?? 0}') ?? 0;

  bool _acceptsMinimizedCallback() {
    final int livestreamId = _minimizedLivestreamId;
    return isVideoLiveMinimized.value &&
        livestreamId > 0 &&
        livestreamController.acceptsRoomMutation(livestreamId);
  }

  void syncVideoLiveRemoteUid(int uid, {required bool connected}) {
    if (uid <= 0) return;
    if (connected) {
      videoLiveRemoteUids.add(uid);
      videoLiveRemoteVideoEnabled[uid] ??= true;
    } else {
      videoLiveRemoteUids.remove(uid);
      videoLiveRemoteVideoEnabled.remove(uid);
      removeVideoCallerAgoraMappingByRemoteUid(uid);
    }
    videoLiveRemoteUids.refresh();
    videoLiveRemoteVideoEnabled.refresh();
  }

  void syncVideoLiveRemoteVideo(int uid, {required bool enabled}) {
    if (uid <= 0 || !videoLiveRemoteUids.contains(uid)) return;
    videoLiveRemoteVideoEnabled[uid] = enabled;
    videoLiveRemoteVideoEnabled.refresh();
  }

  void mapVideoCallerToAgoraUid({
    required int callerId,
    required int remoteUid,
  }) {
    if (callerId <= 0 || remoteUid <= 0) return;
    videoCallerAgoraUidMap[callerId] = remoteUid;
    videoCallerAgoraUidMap.refresh();
  }

  void syncVideoCallerAgoraMappingsFromCalls(Iterable<dynamic> calls) {
    final currentUserId =
        livestreamController.authController.userProfile.value.user?.id ?? 0;
    final callerIds = <int>{};
    for (final raw in calls) {
      if (raw is! Map) continue;
      final call = Map<String, dynamic>.from(raw);
      final status = '${call['call_status'] ?? call['status'] ?? ''}'
          .toLowerCase();
      final type = '${call['call_type'] ?? call['type'] ?? ''}'.toLowerCase();
      final videoOn =
          int.tryParse('${call['video_on'] ?? call['is_video_on'] ?? 1}') ?? 1;
      final acceptedStatus =
          status == 'accepted' ||
          status == 'joined' ||
          status == 'active' ||
          status == 'live' ||
          status == 'on_seat';
      if (!acceptedStatus ||
          !(type == 'video' || type == 'popular') ||
          videoOn == 0) {
        continue;
      }
      final user = call['user'] is Map
          ? Map<String, dynamic>.from(call['user'])
          : <String, dynamic>{};
      final callerId =
          int.tryParse(
            '${call['caller_id'] ?? call['user_id'] ?? user['id'] ?? 0}',
          ) ??
          0;
      if (callerId > 0 && callerId != currentUserId) callerIds.add(callerId);
    }

    final staleCallerIds = videoCallerAgoraUidMap.keys
        .where((callerId) {
          if (callerIds.contains(callerId)) return false;

          final int mappedUid = videoCallerAgoraUidMap[callerId] ?? 0;
          final bool mediaStillConnected =
              mappedUid > 0 &&
              videoLiveRemoteUids.any(
                (uid) =>
                    uid == mappedUid ||
                    uid == callerId ||
                    uid == callerId + 100000 ||
                    (callerId >= 100000 && uid == callerId - 100000),
              );

          // Reordered API/socket snapshots may temporarily omit an accepted
          // caller while Agora media is still flowing. Preserve the mapping.
          return !mediaStillConnected;
        })
        .toList(growable: false);
    if (staleCallerIds.isNotEmpty) {
      for (final callerId in staleCallerIds) {
        videoCallerAgoraUidMap.remove(callerId);
      }
      videoCallerAgoraUidMap.refresh();
    }

    final available = videoLiveRemoteUids.toSet();
    for (final callerId in callerIds) {
      final existing = videoCallerAgoraUidMap[callerId] ?? 0;
      if (existing > 0 && available.remove(existing)) continue;
      final equivalent = available.firstWhere(
        (uid) =>
            uid == callerId ||
            uid == callerId + 100000 ||
            (callerId >= 100000 && uid == callerId - 100000),
        orElse: () => 0,
      );
      if (equivalent > 0) {
        mapVideoCallerToAgoraUid(callerId: callerId, remoteUid: equivalent);
        available.remove(equivalent);
      }
    }

    final unmapped = callerIds
        .where(
          (id) => !videoLiveRemoteUids.contains(videoCallerAgoraUidMap[id]),
        )
        .toList();
    if (unmapped.length == 1 && available.length == 1) {
      mapVideoCallerToAgoraUid(
        callerId: unmapped.single,
        remoteUid: available.single,
      );
    }

    final engine = AgoraService().engine;
    if (engine != null) {
      for (final callerId in callerIds) {
        final remoteUid = videoCallerAgoraUidMap[callerId] ?? 0;
        if (remoteUid <= 0) continue;
        unawaited(engine.muteRemoteVideoStream(uid: remoteUid, mute: false));
        unawaited(engine.muteRemoteAudioStream(uid: remoteUid, mute: false));
      }
    }
  }

  void removeVideoCallerAgoraMappingByRemoteUid(int remoteUid) {
    videoCallerAgoraUidMap.removeWhere((_, uid) => uid == remoteUid);
    videoCallerAgoraUidMap.refresh();
  }

  void minimizeVideoLiveSession({
    required int livestreamId,
    required String channelName,
    required String token,
    required bool isBroadcaster,
    required Map<String, dynamic> arguments,
    bool activateImmediately = true,
  }) {
    minimizedVideoLiveSession.assignAll(<String, dynamic>{
      'livestream_id': livestreamId,
      'channel_name': channelName,
      'token': token,
      'is_broadcaster': isBroadcaster,
      'arguments': Map<String, dynamic>.from(arguments),
    });
    isVideoLiveMinimized.value = activateImmediately;
    if (activateImmediately) _bindMinimizedVideoEvents();
  }

  void activateMinimizedVideoLiveRenderer() {
    if (minimizedVideoLiveSession.isEmpty) return;
    isVideoLiveMinimized.value = true;
    _bindMinimizedVideoEvents();
  }

  void _bindMinimizedVideoEvents() {
    final engine = AgoraService().engine;
    if (engine == null) return;
    _unregisterMinimizedVideoHandler(engine);

    final int handlerLivestreamId = _minimizedLivestreamId;
    if (handlerLivestreamId <= 0 ||
        !livestreamController.acceptsRoomMutation(handlerLivestreamId)) {
      return;
    }

    _minimizedVideoEventHandler = RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        if (!_acceptsMinimizedCallback() ||
            _minimizedLivestreamId != handlerLivestreamId) {
          return;
        }
        syncVideoLiveRemoteUid(remoteUid, connected: true);
        try {
          if (Get.isRegistered<WebsocketController>()) {
            syncVideoCallerAgoraMappingsFromCalls(
              Get.find<WebsocketController>().liveCallList,
            );
          }
        } catch (_) {}
        unawaited(engine.muteRemoteVideoStream(uid: remoteUid, mute: false));
        unawaited(engine.muteRemoteAudioStream(uid: remoteUid, mute: false));
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (!_acceptsMinimizedCallback() ||
            _minimizedLivestreamId != handlerLivestreamId) {
          return;
        }
        syncVideoLiveRemoteUid(remoteUid, connected: false);
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
            if (!_acceptsMinimizedCallback() ||
                _minimizedLivestreamId != handlerLivestreamId) {
              return;
            }
            final enabled =
                state == RemoteVideoState.remoteVideoStateStarting ||
                state == RemoteVideoState.remoteVideoStateDecoding;
            syncVideoLiveRemoteVideo(remoteUid, enabled: enabled);
          },
    );
    engine.registerEventHandler(_minimizedVideoEventHandler!);
  }

  void _unregisterMinimizedVideoHandler([RtcEngine? engine]) {
    final handler = _minimizedVideoEventHandler;
    _minimizedVideoEventHandler = null;
    final currentEngine = engine ?? AgoraService().engine;
    if (currentEngine != null && handler != null) {
      try {
        currentEngine.unregisterEventHandler(handler);
      } catch (_) {}
    }
  }

  void beginVideoLiveRestore() {
    _unregisterMinimizedVideoHandler();
    isVideoLiveMinimized.value = false;
  }

  void clearVideoSessionState() {
    beginVideoLiveRestore();
    minimizedVideoLiveSession.clear();
    videoLiveRemoteUids.clear();
    videoLiveRemoteVideoEnabled.clear();
    videoCallerAgoraUidMap.clear();
  }

  void clearMinimizedVideoLiveSession() => clearVideoSessionState();

  @override
  void onClose() {
    clearVideoSessionState();
    super.onClose();
  }
}
