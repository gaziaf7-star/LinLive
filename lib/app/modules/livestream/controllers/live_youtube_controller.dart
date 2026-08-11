import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../localization/app_localizer.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns host-side livestream YouTube state and backend orchestration.
///
/// Player instances remain view-owned because their lifecycle is tied to the
/// widget tree. Audience realtime state remains WebSocket-owned.
class LiveYoutubeController extends GetxController {
  LiveYoutubeController(this.owner);

  final LivestreamController owner;

  final liveYoutubeStatus = 'stopped'.obs;
  final liveYoutubeUrl = ''.obs;
  final liveYoutubeVideoId = ''.obs;
  final youtubeLoading = false.obs;

  int _operationSequence = 0;

  bool _isCurrentOperation(int operation, int roomGeneration) =>
      operation == _operationSequence &&
      roomGeneration == owner.roomSessionGeneration;

  String extractYoutubeVideoId(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';

    final regExpList = <RegExp>[
      RegExp(r'(?:v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
    ];

    for (final reg in regExpList) {
      final match = reg.firstMatch(raw);
      if (match != null && match.groupCount >= 1) {
        return match.group(1) ?? '';
      }
    }

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) return raw;
    return '';
  }

  void resetYoutubeState() {
    _operationSequence++;
    liveYoutubeStatus.value = 'stopped';
    liveYoutubeUrl.value = '';
    liveYoutubeVideoId.value = '';
    youtubeLoading.value = false;
  }

  Future<void> sendYoutubeControl({
    required int livestreamId,
    required int hostId,
    required String status,
    String? youtubeUrl,
  }) async {
    if (livestreamId == 0 || hostId == 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return;
    }
    if (!owner.ensureCanModerateCurrentLive('youtube_$status')) return;

    final operation = ++_operationSequence;
    final roomGeneration = owner.roomSessionGeneration;
    try {
      youtubeLoading.value = true;
      final requestData = <String, dynamic>{
        'host_id': hostId,
        'youtube_status': status,
      };
      if (youtubeUrl != null) requestData['youtube_url'] = youtubeUrl;

      final response = await owner.dio.post(
        '$kMainUrl/livestream/$livestreamId/youtube-control',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );

      if (!_isCurrentOperation(operation, roomGeneration) ||
          !owner.acceptsRoomMutation(livestreamId)) {
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'] ?? response.data;
        final videoId =
            (data['youtube_video_id'] ??
                    (youtubeUrl == null
                        ? ''
                        : extractYoutubeVideoId(youtubeUrl)))
                .toString();
        final url = (data['youtube_url'] ?? youtubeUrl ?? liveYoutubeUrl.value)
            .toString();

        liveYoutubeStatus.value = status;
        liveYoutubeUrl.value = status == 'stopped' ? '' : url;
        liveYoutubeVideoId.value = status == 'stopped' ? '' : videoId;
        liveLog('✅ YouTube control sent: ${response.data}');
      } else {
        liveLog(
          '⚠️ YouTube control failed: ${response.statusCode} ${response.data}',
        );
        Fluttertoast.showToast(msg: ('YouTube control failed').appTr);
      }
    } catch (e) {
      if (_isCurrentOperation(operation, roomGeneration)) {
        liveLog('❌ YouTube control error: $e');
        Fluttertoast.showToast(msg: ('YouTube control failed').appTr);
      }
    } finally {
      if (_isCurrentOperation(operation, roomGeneration)) {
        youtubeLoading.value = false;
      }
    }
  }

  Future<void> playOrChangeYoutube(String url) async {
    final videoId = extractYoutubeVideoId(url);
    if (videoId.isEmpty) {
      Fluttertoast.showToast(msg: ('Invalid YouTube link').appTr);
      return;
    }

    final status = liveYoutubeStatus.value == 'stopped' ? 'playing' : 'changed';
    await sendYoutubeControl(
      livestreamId: owner.streamId.value,
      hostId: owner.authController.userProfile.value.user?.id?.toInt() ?? 0,
      status: status,
      youtubeUrl: url,
    );
  }

  Future<void> pauseYoutube() => sendYoutubeControl(
    livestreamId: owner.streamId.value,
    hostId: owner.authController.userProfile.value.user?.id?.toInt() ?? 0,
    status: 'paused',
    youtubeUrl: liveYoutubeUrl.value,
  );

  Future<void> resumeYoutube() => sendYoutubeControl(
    livestreamId: owner.streamId.value,
    hostId: owner.authController.userProfile.value.user?.id?.toInt() ?? 0,
    status: 'resumed',
    youtubeUrl: liveYoutubeUrl.value,
  );

  Future<void> stopYoutube() async {
    final livestreamId = owner.streamId.value;
    final hostId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    resetYoutubeState();
    await sendYoutubeControl(
      livestreamId: livestreamId,
      hostId: hostId,
      status: 'stopped',
    );
  }

  Future<Map<String, dynamic>?> fetchYoutubeState(int livestreamId) async {
    if (livestreamId == 0) return null;
    final operation = ++_operationSequence;
    final roomGeneration = owner.roomSessionGeneration;

    try {
      final response = await owner.dio.get(
        '$kMainUrl/livestream/$livestreamId/youtube-state',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );

      if (!_isCurrentOperation(operation, roomGeneration) ||
          !owner.acceptsRoomMutation(livestreamId)) {
        return null;
      }

      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        if (data is Map) {
          final status = (data['youtube_status'] ?? 'stopped')
              .toString()
              .toLowerCase();
          final url = (data['youtube_url'] ?? '').toString();
          final videoId =
              (data['youtube_video_id'] ?? extractYoutubeVideoId(url))
                  .toString();

          liveYoutubeStatus.value = status;
          liveYoutubeUrl.value = status == 'stopped' ? '' : url;
          liveYoutubeVideoId.value = status == 'stopped' ? '' : videoId;
          liveLog('✅ YouTube state fetched: $data');
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      if (_isCurrentOperation(operation, roomGeneration)) {
        liveLog('❌ YouTube state fetch error: $e');
      }
    }

    if (_isCurrentOperation(operation, roomGeneration) &&
        owner.acceptsRoomMutation(livestreamId)) {
      resetYoutubeState();
    }
    return null;
  }

  Future<void> stopYoutubeBecauseUnavailable() async {
    final livestreamId = owner.streamId.value;
    final hostId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    resetYoutubeState();

    if (livestreamId != 0 && hostId != 0) {
      await sendYoutubeControl(
        livestreamId: livestreamId,
        hostId: hostId,
        status: 'stopped',
      );
    }

    Fluttertoast.showToast(
      msg:
          ('This YouTube video cannot be played inside the app. Try another link.')
              .appTr,
    );
  }

  @override
  void onClose() {
    resetYoutubeState();
    super.onClose();
  }
}
