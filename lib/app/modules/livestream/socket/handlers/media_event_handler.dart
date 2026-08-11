part of '../websocket_controller.dart';

extension MediaEventHandler on WebsocketController {
  void _handleUnifiedLiveMusic(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload;

    final livestreamId = data['livestream_id'] ?? payload['livestream_id'];
    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ live_music ignored: not current stream => $livestreamId');
      return;
    }

    final status = (data['music_status'] ?? data['status'] ?? 'stopped')
        .toString()
        .toLowerCase();
    final name = (data['music_name'] ?? data['name'] ?? '').toString();
    final hostId = int.tryParse((data['host_id'] ?? 0).toString()) ?? 0;

    liveMusicStatus.value = status;
    liveMusicName.value = status == 'stopped' ? '' : name;
    liveMusicHostId.value = hostId;
    liveMusicPositionMs.value =
        int.tryParse(
          (data['music_position'] ?? data['position'] ?? 0).toString(),
        ) ??
        0;
    liveMusicDurationMs.value =
        int.tryParse(
          (data['music_duration'] ?? data['duration'] ?? 0).toString(),
        ) ??
        0;
    liveMusicVolume.value =
        int.tryParse(
          (data['music_volume'] ?? data['volume'] ?? 65).toString(),
        ) ??
        65;

    if (status == 'stopped') {
      liveMusicPositionMs.value = 0;
      liveMusicDurationMs.value = 0;
    }

    liveLog('✅ Live music updated => status:$status name:$name host:$hostId');
  }

  void _handleUnifiedLiveYoutube(Map<String, dynamic> payload) {
    liveLog('▶️ LIVE YOUTUBE RAW PAYLOAD => $payload');

    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'])
        : payload;

    final livestreamId = data['livestream_id'] ?? payload['livestream_id'];
    if (livestreamId != null && !_isCurrentStream(livestreamId)) {
      liveLog('⛔ live_youtube ignored: not current stream => $livestreamId');
      return;
    }

    final status = (data['youtube_status'] ?? data['status'] ?? 'stopped')
        .toString()
        .toLowerCase();
    final url = (data['youtube_url'] ?? data['url'] ?? '').toString();
    final videoId =
        (data['youtube_video_id'] ??
                livestreamController.extractYoutubeVideoId(url))
            .toString();
    final hostId = int.tryParse((data['host_id'] ?? 0).toString()) ?? 0;

    if (status == 'stopped' || videoId.isEmpty) {
      liveYoutubeStatus.value = 'stopped';
      liveYoutubeUrl.value = '';
      liveYoutubeVideoId.value = '';
      liveYoutubeHostId.value = hostId;
    } else {
      liveYoutubeStatus.value = status;
      liveYoutubeUrl.value = url;
      liveYoutubeVideoId.value = videoId;
      liveYoutubeHostId.value = hostId;
    }

    liveLog(
      '✅ Live YouTube updated => status:$status video:${liveYoutubeVideoId.value} host:$hostId',
    );
  }
}
