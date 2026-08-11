import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns host-local livestream music state and playback orchestration.
///
/// The Agora engine is supplied by the existing media owner; this controller
/// never creates, joins, or disposes an engine/channel.
class LiveMusicController extends GetxController {
  LiveMusicController(this.owner);

  final LivestreamController owner;

  final selectedMusicPath = ''.obs;
  final liveMusicName = ''.obs;
  final liveMusicStatus = 'stopped'.obs;
  final musicLoading = false.obs;
  final isMusicPlayerSheetOpen = false.obs;
  final musicPositionMs = 0.obs;
  final musicDurationMs = 0.obs;
  final musicVolume = 65.obs;
  final musicRepeat = true.obs;
  final musicSeeking = false.obs;
  final recentLiveMusics = <Map<String, String>>[].obs;
  Timer? _musicProgressTimer;
  bool _musicActionRunning = false;
  int _musicOperationSequence = 0;

  bool _isOperationCurrent(int operation, int roomGeneration) =>
      operation == _musicOperationSequence &&
      roomGeneration == owner.roomSessionGeneration;

  double get liveMusicProgress {
    final duration = musicDurationMs.value;
    if (duration <= 0) return 0;
    return (musicPositionMs.value / duration).clamp(0.0, 1.0);
  }

  String formatMusicTime(int milliseconds) {
    final totalSeconds = (milliseconds < 0 ? 0 : milliseconds) ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isLiveMusicPlaying =>
      liveMusicStatus.value == 'playing' ||
      liveMusicStatus.value == 'resumed' ||
      liveMusicStatus.value == 'changed';

  void resetMusicState({bool clearRecent = false}) {
    _musicOperationSequence++;
    _stopMusicProgressTracking(reset: true);
    selectedMusicPath.value = '';
    liveMusicName.value = '';
    liveMusicStatus.value = 'stopped';
    musicLoading.value = false;
    musicActionRunning.value = false;
    _musicActionRunning = false;
    musicSeeking.value = false;
    isMusicPlayerSheetOpen.value = false;
    if (clearRecent) recentLiveMusics.clear();
  }

  Future<void> keepMusicPublishingWhenMicMuted(
    RtcEngine engine, {
    required bool micMuted,
  }) async {
    try {
      /// Host-er audio track publish active thakbe, kintu mic signal 0 kore dibo.
      /// muteLocalAudioStream(true) dile Agora music mixing publish-o bondho hoye jete pare.
      await engine.enableAudio();
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      await engine.adjustRecordingSignalVolume(micMuted ? 0 : 100);

      /// Local playout + audience publish volume stable rakha.
      await engine.adjustAudioMixingVolume(80);
      await engine.adjustAudioMixingPlayoutVolume(80);
      await engine.adjustAudioMixingPublishVolume(80);

      liveLog('🎙️ Mic muted=$micMuted, music still publishing to audience');
    } catch (e) {
      liveLog('⚠️ keepMusicPublishingWhenMicMuted failed: $e');
    }
  }

  Future<void> sendMusicEvent({
    required int livestreamId,
    required int hostId,
    required String status,
    String? musicName,
  }) async {
    if (livestreamId <= 0 || hostId <= 0) return;
    if (!owner.ensureCanModerateCurrentLive('music_$status')) return;

    try {
      final response = await owner.dio.post(
        '$kMainUrl/livestream/$livestreamId/music-control',
        data: {
          'host_id': hostId,
          'music_status': status,
          'music_name': musicName,
          'music_position': musicPositionMs.value,
          'music_duration': musicDurationMs.value,
          'music_volume': musicVolume.value,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        liveLog('✅ Music event sent: ${response.data}');
      } else {
        liveLog(
          '⚠️ Music event failed: ${response.statusCode} ${response.data}',
        );
      }
    } catch (e) {
      // Local Agora playback must not stop only because websocket/API failed.
      liveLog('❌ Music event error: $e');
    }
  }

  Future<void> pickAndPlayLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!owner.ensureCanModerateCurrentLive('pick_music')) return;
    if (rtcEngine == null) {
      Fluttertoast.showToast(msg: ('Audio engine not ready').appTr);
      return;
    }
    if (_musicActionRunning) return;
    final roomGeneration = owner.roomSessionGeneration;

    try {
      _musicActionRunning = true;
      musicLoading.value = true;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;
      if (roomGeneration != owner.roomSessionGeneration) return;
      final file = result.files.single;
      final path = file.path?.trim() ?? '';

      if (path.isEmpty || !File(path).existsSync()) {
        Fluttertoast.showToast(msg: ('Music file not found').appTr);
        return;
      }

      final name = file.name.trim().isNotEmpty
          ? file.name.trim()
          : ('Music').appTr;
      await startLiveMusic(
        rtcEngine: rtcEngine,
        path: path,
        name: name,
        status: liveMusicStatus.value == 'stopped' ? 'playing' : 'changed',
      );
    } catch (e, st) {
      liveLog('❌ Pick/play music error: $e\n$st');
      Fluttertoast.showToast(msg: ('Music play failed').appTr);
    } finally {
      if (roomGeneration == owner.roomSessionGeneration) {
        musicLoading.value = false;
        _musicActionRunning = false;
      }
    }
  }

  Future<void> playRecentLiveMusic({
    required RtcEngine? rtcEngine,
    required Map<String, String> music,
  }) async {
    if (!owner.ensureCanModerateCurrentLive('play_recent_music')) return;
    if (rtcEngine == null || _musicActionRunning) return;
    final path = music['path']?.trim() ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      recentLiveMusics.removeWhere((item) => item['path'] == path);
      Fluttertoast.showToast(
        msg: ('This music file is no longer available').appTr,
      );
      return;
    }

    _musicActionRunning = true;
    musicLoading.value = true;
    final roomGeneration = owner.roomSessionGeneration;
    try {
      await startLiveMusic(
        rtcEngine: rtcEngine,
        path: path,
        name: music['name']?.trim().isNotEmpty == true
            ? music['name']!.trim()
            : ('Music').appTr,
        status: liveMusicStatus.value == 'stopped' ? 'playing' : 'changed',
      );
    } finally {
      if (roomGeneration == owner.roomSessionGeneration) {
        musicLoading.value = false;
        _musicActionRunning = false;
      }
    }
  }

  void _rememberLiveMusic(String path, String name) {
    recentLiveMusics.removeWhere((item) => item['path'] == path);
    recentLiveMusics.insert(0, {'path': path, 'name': name});
    if (recentLiveMusics.length > 8) {
      recentLiveMusics.removeRange(8, recentLiveMusics.length);
    }
  }

  int _safeMusicValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  /// ================= PROFESSIONAL LIVE MUSIC STATE =================

  final RxBool musicActionRunning = false.obs;

  Future<void> _loadAudioMixingDuration(RtcEngine rtcEngine) async {
    try {
      /// Agora 6.x:
      /// getAudioMixingDuration() kono path receive kore na.
      final int duration = _safeMusicValue(
        await rtcEngine.getAudioMixingDuration(),
      );

      musicDurationMs.value = duration > 0 ? duration : 0;

      liveLog('🎵 Music duration => ${musicDurationMs.value} ms');
    } catch (e) {
      musicDurationMs.value = 0;
      liveLog('⚠️ Music duration unavailable => $e');
    }
  }

  Future<void> startLiveMusic({
    required RtcEngine rtcEngine,
    required String path,
    required String name,
    String status = 'playing',
  }) async {
    if (!owner.ensureCanModerateCurrentLive('start_music')) return;
    if (musicActionRunning.value) return;

    final cleanPath = path.trim();
    final cleanName = name.trim().isEmpty ? 'Unknown Music' : name.trim();

    if (cleanPath.isEmpty) {
      Fluttertoast.showToast(msg: ('Music file path is empty').appTr);
      return;
    }

    final file = File(cleanPath);

    if (!await file.exists()) {
      Fluttertoast.showToast(msg: ('Music file not found').appTr);
      return;
    }

    final operation = ++_musicOperationSequence;
    final roomGeneration = owner.roomSessionGeneration;
    if (!_isOperationCurrent(operation, roomGeneration)) return;

    musicActionRunning.value = true;
    musicLoading.value = true;

    try {
      /// Music start hole YouTube stop hobe.
      if (owner.liveYoutubeStatus.value != 'stopped') {
        await owner.stopYoutube();
      }

      _stopMusicProgressTracking(reset: true);

      /// Old mixing safely stop.
      try {
        await rtcEngine.stopAudioMixing();
      } catch (_) {}

      await rtcEngine.startAudioMixing(
        filePath: cleanPath,
        loopback: false,
        cycle: musicRepeat.value ? -1 : 1,
        startPos: 0,
      );

      if (!_isOperationCurrent(operation, roomGeneration)) return;

      /// Local + audience volume.
      await rtcEngine.adjustAudioMixingVolume(musicVolume.value.clamp(0, 100));

      try {
        await rtcEngine.adjustAudioMixingPlayoutVolume(
          musicVolume.value.clamp(0, 100),
        );
      } catch (e) {
        liveLog('⚠️ Mixing playout volume unsupported/failed => $e');
      }

      try {
        await rtcEngine.adjustAudioMixingPublishVolume(
          musicVolume.value.clamp(0, 100),
        );
      } catch (e) {
        liveLog('⚠️ Mixing publish volume unsupported/failed => $e');
      }

      /// Mic mute thakleo music publish cholbe.
      await keepMusicPublishingWhenMicMuted(
        rtcEngine,
        micMuted: owner.mute.value,
      );

      selectedMusicPath.value = cleanPath;
      liveMusicName.value = cleanName;

      liveMusicStatus.value = status == 'changed' ? 'changed' : 'playing';

      musicPositionMs.value = 0;

      _rememberLiveMusic(cleanPath, cleanName);

      /// IMPORTANT FIX:
      /// path argument remove kora hoyeche.
      await _loadAudioMixingDuration(rtcEngine);
      if (!_isOperationCurrent(operation, roomGeneration)) return;

      _startMusicProgressTracking(
        rtcEngine,
        operation: operation,
        roomGeneration: roomGeneration,
      );

      final sid = owner.streamId.value;
      final hostId =
          owner.authController.userProfile.value.user?.id?.toInt() ?? 0;

      if (sid > 0 && hostId > 0) {
        await sendMusicEvent(
          livestreamId: sid,
          hostId: hostId,
          status: status == 'changed' ? 'changed' : 'playing',
          musicName: cleanName,
        );
      }

      Fluttertoast.showToast(msg: ('Music started').appTr);
    } catch (e, st) {
      if (_isOperationCurrent(operation, roomGeneration)) {
        _stopMusicProgressTracking(reset: true);
        selectedMusicPath.value = '';
        liveMusicName.value = '';
        liveMusicStatus.value = 'stopped';
      }

      liveLog('❌ startLiveMusic error => $e');
      liveLog('$st');

      Fluttertoast.showToast(msg: ('Music start failed').appTr);
    } finally {
      if (_isOperationCurrent(operation, roomGeneration)) {
        musicLoading.value = false;
        musicActionRunning.value = false;
      }
    }
  }

  void _startMusicProgressTracking(
    RtcEngine rtcEngine, {
    int? operation,
    int? roomGeneration,
  }) {
    final trackedOperation = operation ?? _musicOperationSequence;
    final trackedRoomGeneration = roomGeneration ?? owner.roomSessionGeneration;
    _musicProgressTimer?.cancel();
    _musicProgressTimer = Timer.periodic(const Duration(milliseconds: 700), (
      _,
    ) async {
      if (!_isOperationCurrent(trackedOperation, trackedRoomGeneration)) {
        _stopMusicProgressTracking();
        return;
      }
      if (!isLiveMusicPlaying || musicSeeking.value) return;
      try {
        final position = await rtcEngine.getAudioMixingCurrentPosition();
        if (_isOperationCurrent(trackedOperation, trackedRoomGeneration) &&
            position >= 0) {
          musicPositionMs.value = position;
        }
      } catch (_) {}
    });
  }

  void _stopMusicProgressTracking({bool reset = false}) {
    _musicProgressTimer?.cancel();
    _musicProgressTimer = null;
    if (reset) {
      musicPositionMs.value = 0;
      musicDurationMs.value = 0;
    }
  }

  Future<void> seekLiveMusic({
    required RtcEngine? rtcEngine,
    required int positionMs,
  }) async {
    if (rtcEngine == null || selectedMusicPath.value.isEmpty) return;
    final max = musicDurationMs.value > 0 ? musicDurationMs.value : positionMs;
    final safePosition = positionMs.clamp(0, max).toInt();
    final operation = _musicOperationSequence;
    final roomGeneration = owner.roomSessionGeneration;
    musicSeeking.value = true;
    try {
      await rtcEngine.setAudioMixingPosition(safePosition);
      if (_isOperationCurrent(operation, roomGeneration)) {
        musicPositionMs.value = safePosition;
      }
    } catch (e) {
      liveLog('❌ seekLiveMusic error: $e');
    } finally {
      musicSeeking.value = false;
    }
  }

  Future<void> setLiveMusicVolume({
    required RtcEngine? rtcEngine,
    required int volume,
  }) async {
    final safeVolume = volume.clamp(0, 100).toInt();
    musicVolume.value = safeVolume;
    try {
      await rtcEngine?.adjustAudioMixingVolume(safeVolume);
    } catch (e) {
      liveLog('❌ setLiveMusicVolume error: $e');
    }
  }

  Future<void> toggleLiveMusicRepeat({required RtcEngine? rtcEngine}) async {
    musicRepeat.toggle();
    final path = selectedMusicPath.value;
    final name = liveMusicName.value;
    if (rtcEngine != null && path.isNotEmpty && File(path).existsSync()) {
      final oldPosition = musicPositionMs.value;
      await startLiveMusic(
        rtcEngine: rtcEngine,
        path: path,
        name: name,
        status: 'changed',
      );
      if (oldPosition > 0) {
        await seekLiveMusic(rtcEngine: rtcEngine, positionMs: oldPosition);
      }
    }
  }

  Future<void> pauseLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!owner.ensureCanModerateCurrentLive('pause_music')) return;
    if (rtcEngine == null || liveMusicStatus.value == 'paused') return;
    final operation = _musicOperationSequence;
    final roomGeneration = owner.roomSessionGeneration;
    try {
      await rtcEngine.pauseAudioMixing();
      if (!_isOperationCurrent(operation, roomGeneration)) return;
      liveMusicStatus.value = 'paused';
      await sendMusicEvent(
        livestreamId: owner.streamId.value,
        hostId: owner.authController.userProfile.value.user?.id?.toInt() ?? 0,
        status: 'paused',
        musicName: liveMusicName.value,
      );
    } catch (e) {
      liveLog('❌ pauseLiveMusic error: $e');
    }
  }

  Future<void> resumeLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!owner.ensureCanModerateCurrentLive('resume_music')) return;
    if (rtcEngine == null || selectedMusicPath.value.isEmpty) return;
    final operation = _musicOperationSequence;
    final roomGeneration = owner.roomSessionGeneration;
    try {
      await rtcEngine.resumeAudioMixing();
      await keepMusicPublishingWhenMicMuted(
        rtcEngine,
        micMuted: owner.mute.value,
      );
      await rtcEngine.adjustAudioMixingVolume(musicVolume.value);
      if (!_isOperationCurrent(operation, roomGeneration)) return;
      liveMusicStatus.value = 'resumed';
      _startMusicProgressTracking(
        rtcEngine,
        operation: operation,
        roomGeneration: roomGeneration,
      );

      await sendMusicEvent(
        livestreamId: owner.streamId.value,
        hostId: owner.authController.userProfile.value.user?.id?.toInt() ?? 0,
        status: 'resumed',
        musicName: liveMusicName.value,
      );
    } catch (e) {
      liveLog('❌ resumeLiveMusic error: $e');
    }
  }

  Future<void> stopLiveMusic({required RtcEngine? rtcEngine}) async {
    if (!owner.ensureCanModerateCurrentLive('stop_music')) return;
    if (_musicActionRunning) return;
    _musicActionRunning = true;
    _musicOperationSequence++;
    final livestreamId = owner.streamId.value;
    final hostId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    try {
      await rtcEngine?.stopAudioMixing();
      _stopMusicProgressTracking(reset: true);
      selectedMusicPath.value = '';
      liveMusicName.value = '';
      liveMusicStatus.value = 'stopped';

      await sendMusicEvent(
        livestreamId: livestreamId,
        hostId: hostId,
        status: 'stopped',
        musicName: null,
      );
    } catch (e) {
      liveLog('❌ stopLiveMusic error: $e');
    } finally {
      _musicActionRunning = false;
    }
  }

  @override
  void onClose() {
    resetMusicState();
    super.onClose();
  }
}
