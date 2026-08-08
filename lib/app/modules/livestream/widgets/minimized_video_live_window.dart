import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../../../services/agora_service.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/websocket_controller.dart';
import '../views/popular_live_view.dart';

class MinimizedVideoLiveWindow extends StatefulWidget {
  const MinimizedVideoLiveWindow({super.key});

  @override
  State<MinimizedVideoLiveWindow> createState() =>
      _MinimizedVideoLiveWindowState();
}

class _MinimizedVideoLiveWindowState extends State<MinimizedVideoLiveWindow> {
  Offset? _position;

  LivestreamController? get _liveController =>
      Get.isRegistered<LivestreamController>()
      ? Get.find<LivestreamController>()
      : null;

  void _restore() {
    final live = _liveController;
    if (live == null || live.minimizedVideoLiveSession.isEmpty) return;
    final session = Map<String, dynamic>.from(live.minimizedVideoLiveSession);
    final arguments = session['arguments'] is Map
        ? Map<String, dynamic>.from(session['arguments'] as Map)
        : <String, dynamic>{};
    arguments['restore_minimized_video_live'] = true;
    live.beginVideoLiveRestore();
    Get.to(
      () => PopularLiveView(
        channelName: '${session['channel_name'] ?? ''}',
        isBroadcaster: session['is_broadcaster'] == true,
        token: '${session['token'] ?? ''}',
      ),
      arguments: arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveController;
    if (live == null) return const SizedBox.shrink();

    return Obx(() {
      if (!live.isVideoLiveMinimized.value ||
          live.minimizedVideoLiveSession.isEmpty) {
        return const SizedBox.shrink();
      }
      final media = MediaQuery.of(context);
      const width = 152.0;
      const height = 214.0;
      final safeBottom = media.padding.bottom + 76;
      final defaultPosition = Offset(
        media.size.width - width - 12,
        media.size.height - height - safeBottom,
      );
      final position = _position ?? defaultPosition;
      final maxX = media.size.width - width - 8;
      final maxY = media.size.height - height - safeBottom;
      final safePosition = Offset(
        position.dx.clamp(8.0, maxX),
        position.dy.clamp(media.padding.top + 8, maxY),
      );

      return Positioned(
        left: safePosition.dx,
        top: safePosition.dy,
        width: width,
        height: height,
        child: GestureDetector(
          onTap: _restore,
          onPanUpdate: (details) {
            setState(() => _position = safePosition + details.delta);
          },
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: _VideoSurface(liveController: live),
          ),
        ),
      );
    });
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.liveController});

  final LivestreamController liveController;

  @override
  Widget build(BuildContext context) {
    final engine = AgoraService().engine;
    final session = liveController.minimizedVideoLiveSession;
    final channelName = '${session['channel_name'] ?? ''}';
    if (engine == null || channelName.isEmpty) {
      return const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white70, size: 34),
      );
    }

    final mappedRemoteUids = liveController.videoCallerAgoraUidMap.values
        .where(liveController.videoLiveRemoteUids.contains)
        .toList();
    if (mappedRemoteUids.isEmpty && session['is_broadcaster'] != true) {
      mappedRemoteUids.addAll(liveController.videoLiveRemoteUids);
    }
    final remoteUid = mappedRemoteUids.isEmpty ? 0 : mappedRemoteUids.last;
    final remoteEnabled =
        remoteUid > 0 &&
        (liveController.videoLiveRemoteVideoEnabled[remoteUid] ?? true);
    final audioCallers = Get.isRegistered<WebsocketController>()
        ? Get.find<WebsocketController>().liveCallList
              .where((raw) {
                if (raw is! Map) return false;
                final status = '${raw['call_status'] ?? raw['status'] ?? ''}'
                    .toLowerCase();
                final type = '${raw['call_type'] ?? raw['type'] ?? ''}'
                    .toLowerCase();
                return status == 'accepted' && type == 'audio';
              })
              .toList(growable: false)
        : <dynamic>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        _LocalVideo(engine: engine),
        if (remoteUid > 0)
          Positioned(
            right: 7,
            bottom: 7,
            width: 54,
            height: 76,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: remoteEnabled
                    ? AgoraVideoView(
                        key: ValueKey('mini-remote-$channelName-$remoteUid'),
                        controller: VideoViewController.remote(
                          rtcEngine: engine,
                          canvas: VideoCanvas(
                            uid: remoteUid,
                            renderMode: RenderModeType.renderModeHidden,
                          ),
                          connection: RtcConnection(channelId: channelName),
                        ),
                      )
                    : const ColoredBox(
                        color: Color(0xffeeeeee),
                        child: Center(
                          child: Icon(
                            Icons.videocam_off_rounded,
                            color: Color(0xff777777),
                            size: 26,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        if (audioCallers.isNotEmpty)
          Positioned(
            left: 7,
            bottom: 7,
            child: _MiniAudioCaller(call: audioCallers.first),
          ),
      ],
    );
  }
}

class _MiniAudioCaller extends StatelessWidget {
  const _MiniAudioCaller({required this.call});

  final dynamic call;

  @override
  Widget build(BuildContext context) {
    final map = call is Map
        ? Map<String, dynamic>.from(call as Map)
        : <String, dynamic>{};
    final user = map['user'] is Map
        ? Map<String, dynamic>.from(map['user'] as Map)
        : <String, dynamic>{};
    final image = ImageHelper.getImageUrl(
      '${user['profile_image'] ?? map['profile_image'] ?? ''}',
    );
    final name = '${user['name'] ?? map['name'] ?? 'Caller'}';
    final muted =
        map['audio_on'] == 0 || map['is_muted'] == true || map['is_muted'] == 1;

    return Container(
      width: 88,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xffeeeeee),
            backgroundImage: image.isNotEmpty
                ? CachedNetworkImageProvider(image)
                : null,
            child: image.isEmpty
                ? const Icon(Icons.person, size: 16, color: Color(0xff777777))
                : null,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff222222),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            size: 12,
            color: muted ? const Color(0xffe74c3c) : const Color(0xff20c997),
          ),
        ],
      ),
    );
  }
}

class _LocalVideo extends StatelessWidget {
  const _LocalVideo({required this.engine});

  final RtcEngine engine;

  @override
  Widget build(BuildContext context) {
    return AgoraVideoView(
      key: const ValueKey('minimized-local-video'),
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
        ),
      ),
    );
  }
}
