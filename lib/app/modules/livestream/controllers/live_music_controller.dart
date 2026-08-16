import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final localMusics = <Map<String, dynamic>>[].obs;
  final musicPlaylist = <Map<String, dynamic>>[].obs;
  final currentMusicIndex = (-1).obs;
  final localMusicLoading = false.obs;
  final localMusicPermissionDenied = false.obs;
  static const MethodChannel _localAudioChannel =
      MethodChannel('ezilive/local_audio');
  Timer? _musicProgressTimer;
  bool _musicActionRunning = false;
  int _musicOperationSequence = 0;
  bool _handlingCompletion = false;

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

  Future<void> loadLocalMusics({bool force = false}) async {
    if (localMusicLoading.value || (localMusics.isNotEmpty && !force)) return;
    localMusicLoading.value = true;
    localMusicPermissionDenied.value = false;
    try {
      PermissionStatus permission;
      if (Platform.isAndroid) {
        permission = await Permission.audio.request();
        if (permission.isDenied || permission.isPermanentlyDenied) {
          // permission_handler maps audio to the correct platform permission;
          // older Android versions may expose it through storage instead.
          permission = await Permission.storage.request();
        }
        if (!permission.isGranted) {
          localMusicPermissionDenied.value = true;
          return;
        }
      }
      final raw = await _localAudioChannel.invokeListMethod<dynamic>('getAudioFiles');
      final unique = <String, Map<String, dynamic>>{};
      for (final item in raw ?? const <dynamic>[]) {
        if (item is! Map) continue;
        final song = Map<String, dynamic>.from(item);
        final path = (song['path'] ?? '').toString().trim();
        if (path.isEmpty) continue;
        unique[path] = song;
      }
      localMusics.assignAll(unique.values);
    } on PlatformException catch (e) {
      localMusicPermissionDenied.value = e.code == 'permission_denied';
      liveLog('Local music query failed: $e');
    } finally {
      localMusicLoading.value = false;
    }
  }

  Future<void> selectLocalMusic({
    required RtcEngine? rtcEngine,
    required Map<String, dynamic> music,
  }) async {
    if (rtcEngine == null) return;
    final path = (music['path'] ?? '').toString();
    if (path.isEmpty) return;
    final existing = musicPlaylist.indexWhere((e) => e['path'] == path);
    if (existing < 0) musicPlaylist.add(Map<String, dynamic>.from(music));
    currentMusicIndex.value = existing < 0 ? musicPlaylist.length - 1 : existing;
    await _playPlaylistIndex(rtcEngine, currentMusicIndex.value);
  }

  Future<void> _playPlaylistIndex(RtcEngine rtcEngine, int index) async {
    if (index < 0 || index >= musicPlaylist.length) return;
    currentMusicIndex.value = index;
    final music = musicPlaylist[index];
    await startLiveMusic(
      rtcEngine: rtcEngine,
      path: (music['path'] ?? '').toString(),
      name: (music['title'] ?? music['name'] ?? 'Unknown Music').toString(),
      status: liveMusicStatus.value == 'stopped' ? 'playing' : 'changed',
    );
  }

  Future<void> playNextLiveMusic({required RtcEngine? rtcEngine}) async {
    if (rtcEngine == null || musicPlaylist.isEmpty) return;
    final next = currentMusicIndex.value + 1;
    if (next < musicPlaylist.length) {
      await _playPlaylistIndex(rtcEngine, next);
    } else if (musicRepeat.value) {
      await _playPlaylistIndex(rtcEngine, 0);
    } else {
      await stopLiveMusic(rtcEngine: rtcEngine);
    }
  }

  Future<void> playPreviousLiveMusic({required RtcEngine? rtcEngine}) async {
    if (rtcEngine == null || musicPlaylist.isEmpty) return;
    final previous = currentMusicIndex.value - 1;
    await _playPlaylistIndex(rtcEngine, previous >= 0 ? previous : musicPlaylist.length - 1);
  }

  Future<void> playPlaylistMusic({required RtcEngine? rtcEngine, required int index}) async {
    if (rtcEngine != null) await _playPlaylistIndex(rtcEngine, index);
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
      final volume = musicVolume.value.clamp(0, 100);
      await engine.adjustAudioMixingVolume(volume);
      await engine.adjustAudioMixingPlayoutVolume(volume);
      await engine.adjustAudioMixingPublishVolume(volume);

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
        // Queue completion owns repeat/auto-next; Agora must finish this file.
        cycle: 1,
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
          final duration = musicDurationMs.value;
          if (duration > 0 && position >= duration - 500 && !_handlingCompletion) {
            _handlingCompletion = true;
            try {
              await playNextLiveMusic(rtcEngine: rtcEngine);
            } finally {
              _handlingCompletion = false;
            }
          }
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
      await rtcEngine?.adjustAudioMixingPlayoutVolume(safeVolume);
      await rtcEngine?.adjustAudioMixingPublishVolume(safeVolume);
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
