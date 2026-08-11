import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns active-room configuration and its single edit API implementation.
class LiveRoomSettingsController extends GetxController {
  LiveRoomSettingsController(this.owner);

  final LivestreamController owner;
  int _editRequestSequence = 0;

  /// ===================== LIVE ROOM REALTIME EDIT =====================
  /// Backend route:
  /// POST /livestream/{id}/edit/{userId}
  /// Expected event: action_type = live_stream_updated
  final roomEditLoading = false.obs;

  /// ===================== ROOM SETTINGS / SAFETY STATE =====================
  /// These values are updated from edit API response and realtime events.
  /// 1 = enabled/blocked/hidden/locked, 0 = disabled/allowed/show/unlocked.
  final roomSettingsLoading = false.obs;
  final liveRoomLocked = false.obs;
  final liveCommentLocked = false.obs;
  final liveHiddenRoom = false.obs;
  final liveScreenRecordBlocked = false.obs;
  final liveScreenshotBlocked = false.obs;

  static const MethodChannel _screenSecurityChannel = MethodChannel(
    'linlive/screen_security',
  );

  int _firstIntFromMap(
    Map<String, dynamic> map,
    List<String> keys, {
    int defaultValue = 0,
  }) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] != null) {
        return _toInt(map[key]);
      }
    }
    return defaultValue;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is double) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on' ||
        text == 'locked' ||
        text == 'hidden' ||
        text == 'blocked' ||
        text == 'enabled';
  }

  Future<void> _setNativeScreenSecure(bool enable) async {
    try {
      await _screenSecurityChannel.invokeMethod(enable ? 'enable' : 'disable');
      liveLog("🛡️ SCREEN SECURE NATIVE ${enable ? 'ENABLED' : 'DISABLED'}");
    } on MissingPluginException catch (e) {
      liveLog('⚠️ SCREEN SECURE native channel missing => $e');
    } catch (e) {
      liveLog('❌ SCREEN SECURE ERROR => $e');
    }
  }

  Map<String, dynamic> _currentLiveMapForRoomSettings() {
    final raw = owner.createStreamData['livestreamdata'] is Map
        ? Map<String, dynamic>.from(owner.createStreamData['livestreamdata'])
        : owner.createStreamData['livestream'] is Map
        ? Map<String, dynamic>.from(owner.createStreamData['livestream'])
        : <String, dynamic>{};

    final int sid = owner.streamId.value > 0
        ? owner.streamId.value
        : owner.websocketController.streamID.value;
    final int cachedSid = _toInt(
      raw['id'] ?? raw['livestream_id'] ?? raw['stream_id'],
    );

    if (sid > 0 && cachedSid > 0 && sid != cachedSid) {
      liveLog(
        '🧹 Ignored stale room settings cache => current:$sid cached:$cachedSid',
      );
      return <String, dynamic>{};
    }

    return raw;
  }

  void syncRoomSafetyFromCurrentLiveData({
    String source = 'current_live_data',
  }) {
    final current = _currentLiveMapForRoomSettings();
    if (current.isEmpty) return;
    applyRoomSafetySettingsFromPayload(current, source: source);
  }

  void applyRoomSafetySettingsFromPayload(
    Map<String, dynamic> payload, {
    String source = 'unknown',
  }) {
    try {
      final Map<String, dynamic> data = payload['data'] is Map
          ? Map<String, dynamic>.from(payload['data'])
          : <String, dynamic>{};

      final Map<String, dynamic> live = payload['livestreamdata'] is Map
          ? Map<String, dynamic>.from(payload['livestreamdata'])
          : payload['livestream'] is Map
          ? Map<String, dynamic>.from(payload['livestream'])
          : <String, dynamic>{};

      final merged = <String, dynamic>{...payload, ...data, ...live};

      int readSetting(List<String> keys, bool current) {
        for (final key in keys) {
          if (merged.containsKey(key) && merged[key] != null) {
            return _truthy(merged[key]) ? 1 : 0;
          }
        }
        return current ? 1 : 0;
      }

      final int roomLock = readSetting([
        'room_lock',
        'is_room_locked',
        'room_locked',
      ], liveRoomLocked.value);
      final int commentLock = readSetting([
        'lock_coment',
        'comment_locked',
        'is_comment_locked',
      ], liveCommentLocked.value);
      final int hiddenRoom = readSetting([
        'hidden_room',
        'is_hidden_room',
        'room_hidden',
      ], liveHiddenRoom.value);
      final int screenRecord = readSetting([
        'screen_records',
        'screen_record_enabled',
      ], liveScreenRecordBlocked.value);
      final int screenShort = readSetting([
        'screenshort',
        'screenshot_enabled',
      ], liveScreenshotBlocked.value);

      liveRoomLocked.value = roomLock == 1;
      liveCommentLocked.value = commentLock == 1;
      liveHiddenRoom.value = hiddenRoom == 1;
      liveScreenRecordBlocked.value = screenRecord == 1;
      liveScreenshotBlocked.value = screenShort == 1;

      if (owner.createStreamData['livestreamdata'] is Map) {
        final current = Map<String, dynamic>.from(
          owner.createStreamData['livestreamdata'],
        );
        owner.createStreamData['livestreamdata'] = {
          ...current,
          'room_lock': roomLock,
          'is_room_locked': roomLock,
          'room_locked': roomLock,
          'lock_coment': commentLock,
          'comment_locked': commentLock,
          'is_comment_locked': commentLock,
          'hidden_room': hiddenRoom,
          'is_hidden_room': hiddenRoom,
          'room_hidden': hiddenRoom,
          'screen_records': screenRecord,
          'screen_record_enabled': screenRecord,
          'screenshort': screenShort,
          'screenshot_enabled': screenShort,
        };
        owner.createStreamData.refresh();
      }

      final bool shouldBlockScreen = screenRecord == 1 || screenShort == 1;
      _setNativeScreenSecure(shouldBlockScreen);

      if (commentLock == 1) {
        FocusManager.instance.primaryFocus?.unfocus();
      }

      liveLog(
        '🔒 ROOM SAFETY SETTINGS APPLIED => source:$source '
        'room_lock:$roomLock lock_coment:$commentLock hidden_room:$hiddenRoom '
        'screen_records:$screenRecord screenshort:$screenShort',
      );
    } catch (e, st) {
      liveLog('❌ applyRoomSafetySettingsFromPayload error => $e\n$st');
    }
  }

  Future<Map<String, dynamic>?> editLiveStreamRoom({
    required int livestreamId,
    required int userId,
    required int seatCount,
    required int roomLayout,
    required int roomTheme,
    required int roomBackground,
    String? streamTitle,
    String? streamAnnouncement,
    File? streamImageFile,
    String? roomPassword,
    int? roomLock,
    int? lockComent,
    int? hiddenRoom,
    int? screenRecords,
    int? screenshort,
  }) async {
    if (livestreamId == 0 || userId == 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return null;
    }
    if (!owner.ensureCanModerateCurrentLive('edit_room')) return null;

    final int requestSequence = ++_editRequestSequence;
    final int roomGeneration = owner.roomSessionGeneration;

    try {
      roomEditLoading.value = true;

      /// Backend edit API create live-er moto sob key must chay.
      /// Existing value na pele safe default pathabo, nullable pathabo na.
      final rawCurrentLive = owner.createStreamData['livestreamdata'] is Map
          ? Map<String, dynamic>.from(owner.createStreamData['livestreamdata'])
          : owner.createStreamData['livestream'] is Map
          ? Map<String, dynamic>.from(owner.createStreamData['livestream'])
          : <String, dynamic>{};

      final int currentLiveId = _toInt(
        rawCurrentLive['id'] ?? rawCurrentLive['livestream_id'],
      );

      /// HARD ROOM ISOLATION:
      /// owner.createStreamData is a controller-level cache. If user edited room A and
      /// then opened room B, this cache can still contain room A for a short time.
      /// Never use title/announcement/image/password from that cache unless the
      /// cached livestream id is the same room we are editing now.
      final bool currentLiveBelongsToThisRoom =
          rawCurrentLive.isNotEmpty && currentLiveId == livestreamId;
      final currentLive = currentLiveBelongsToThisRoom
          ? rawCurrentLive
          : <String, dynamic>{};

      if (!currentLiveBelongsToThisRoom) {
        liveLog(
          '🧹 Ignored stale owner.createStreamData while editing room => '
          'editing:$livestreamId cached:$currentLiveId',
        );
      }

      final String safeStreamTitle =
          (streamTitle ??
                  currentLive['stream_bte'] ??
                  currentLive['title'] ??
                  'Live')
              .toString()
              .trim()
              .isEmpty
          ? 'Live'
          : (streamTitle ??
                    currentLive['stream_bte'] ??
                    currentLive['title'] ??
                    'Live')
                .toString()
                .trim();

      final String safeAnnouncement =
          (streamAnnouncement ??
                  currentLive['stream_title'] ??
                  currentLive['announcement'] ??
                  currentLive['anousment'] ??
                  '')
              .toString()
              .trim();

      final String safeStreamImage =
          (currentLive['stream_image'] ??
                  currentLive['image'] ??
                  currentLive['cover_image'] ??
                  currentLive['thumbnail'] ??
                  '')
              .toString()
              .trim();

      final String safeRoomPassword =
          (roomPassword ??
                  currentLive['room_password'] ??
                  currentLive['stream_password'] ??
                  currentLive['password'] ??
                  '')
              .toString()
              .trim();

      final int streamCoins =
          int.tryParse((currentLive['stream_coins'] ?? 0).toString()) ?? 0;

      final int giftsCoins =
          int.tryParse((currentLive['gifts_coins'] ?? 0).toString()) ?? 0;

      final String streamType =
          (currentLive['stream_type'] ?? 'audio').toString().trim().isEmpty
          ? 'audio'
          : (currentLive['stream_type'] ?? 'audio').toString();

      final int finalRoomLock =
          roomLock ??
          _firstIntFromMap(currentLive, [
            'room_lock',
            'is_room_locked',
            'room_locked',
          ], defaultValue: safeRoomPassword.isNotEmpty ? 1 : 0);

      final int finalLockComent =
          lockComent ??
          _firstIntFromMap(currentLive, [
            'lock_coment',
            'comment_locked',
            'is_comment_locked',
          ]);

      final int finalHiddenRoom =
          hiddenRoom ??
          _firstIntFromMap(currentLive, [
            'hidden_room',
            'is_hidden_room',
            'room_hidden',
          ]);

      final int finalScreenRecords =
          screenRecords ??
          _firstIntFromMap(currentLive, [
            'screen_records',
            'screen_record_enabled',
          ]);

      final int finalScreenshort =
          screenshort ??
          _firstIntFromMap(currentLive, ['screenshort', 'screenshot_enabled']);

      final data = <String, dynamic>{
        'seat_count': seatCount,

        /// stream_bte/title = live title, stream_title = announcement
        'stream_bte': safeStreamTitle,
        'stream_title': safeAnnouncement,
        'announcement': safeAnnouncement,
        'anousment': safeAnnouncement,
        'title': safeStreamTitle,
        'stream_coins': streamCoins,
        'gifts_coins': giftsCoins,
        'room_layout': roomLayout.toString(),
        'stream_type': streamType,
        'room_theme': roomTheme.toString(),
        'room_background': roomBackground.toString(),
        'room_password': safeRoomPassword,
        'stream_password': safeRoomPassword,
        'password': safeRoomPassword,

        /// Room settings: 1 = lock/hide/block, 0 = unlock/show/allow.
        'room_lock': finalRoomLock,
        'is_room_locked': finalRoomLock,
        'room_locked': finalRoomLock,
        'has_room_password': finalRoomLock == 1 && safeRoomPassword.isNotEmpty
            ? 1
            : 0,
        'lock_coment': finalLockComent,
        'comment_locked': finalLockComent,
        'is_comment_locked': finalLockComent,
        'hidden_room': finalHiddenRoom,
        'is_hidden_room': finalHiddenRoom,
        'room_hidden': finalHiddenRoom,
        'screen_records': finalScreenRecords,
        'screen_record_enabled': finalScreenRecords,
        'screenshort': finalScreenshort,
        'screenshot_enabled': finalScreenshort,

        /// Only preserve an existing stream image when the cached live data
        /// belongs to this same livestream. Otherwise room A image could be sent
        /// while editing room B. Picked file still uploads below.
        if (currentLiveBelongsToThisRoom && safeStreamImage.isNotEmpty)
          'stream_image': safeStreamImage,
      };

      dynamic requestData = data;
      final pickedImagePath = streamImageFile?.path ?? '';
      if (pickedImagePath.isNotEmpty && File(pickedImagePath).existsSync()) {
        requestData = FormData.fromMap({
          ...data,
          "stream_image": await MultipartFile.fromFile(
            pickedImagePath,
            filename: pickedImagePath.split(Platform.pathSeparator).last,
          ),
        });
      }

      final url = '$kMainUrl/livestream/$livestreamId/edit/$userId';
      liveLog('📤 LIVE ROOM EDIT URL => $url');
      liveLog('📤 LIVE ROOM EDIT BODY => $data');

      final response = await owner.dio.post(
        url,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': requestData is FormData
                ? 'multipart/form-data'
                : 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },

          /// 422 response-o print korbo, DioException-e hide hobe na.
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 LIVE ROOM EDIT STATUS => ${response.statusCode}');
      liveLog('📥 LIVE ROOM EDIT RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        if (requestSequence != _editRequestSequence ||
            roomGeneration != owner.roomSessionGeneration ||
            !owner.acceptsRoomMutation(livestreamId)) {
          liveLog(
            'Ignored stale room edit response => stream:$livestreamId '
            'generation:$roomGeneration current:${owner.roomSessionGeneration}',
          );
          return body;
        }

        final liveData = body['livestreamdata'] is Map
            ? Map<String, dynamic>.from(body['livestreamdata'])
            : body['livestream'] is Map
            ? Map<String, dynamic>.from(body['livestream'])
            : <String, dynamic>{};

        final String responseStreamImage = (liveData['stream_image'] ?? '')
            .toString()
            .trim();
        final String finalStreamImage = responseStreamImage.isNotEmpty
            ? responseStreamImage
            : (currentLiveBelongsToThisRoom ? safeStreamImage : '');

        if (liveData.isNotEmpty) {
          owner.createStreamData['livestreamdata'] = {
            ...liveData,
            'id': livestreamId,
            'livestream_id': livestreamId,
            'stream_bte': safeStreamTitle,
            'stream_title': safeAnnouncement,
            'announcement': safeAnnouncement,
            'anousment': safeAnnouncement,
            'title': safeStreamTitle,
            'stream_image': finalStreamImage,
            'room_password': safeRoomPassword,
            'stream_password': safeRoomPassword,
            'password': safeRoomPassword,
            'seat_count': seatCount,
            'room_layout': roomLayout.toString(),
            'room_theme': roomTheme.toString(),
            'room_background': roomBackground.toString(),
            'room_lock': finalRoomLock,
            'is_room_locked': finalRoomLock,
            'room_locked': finalRoomLock,
            'has_room_password':
                finalRoomLock == 1 && safeRoomPassword.isNotEmpty ? 1 : 0,
            'lock_coment': finalLockComent,
            'comment_locked': finalLockComent,
            'is_comment_locked': finalLockComent,
            'hidden_room': finalHiddenRoom,
            'is_hidden_room': finalHiddenRoom,
            'room_hidden': finalHiddenRoom,
            'screen_records': finalScreenRecords,
            'screen_record_enabled': finalScreenRecords,
            'screenshort': finalScreenshort,
            'screenshot_enabled': finalScreenshort,
          };
        } else {
          /// Response-e livestreamdata na thakleo local value sync thakbe.
          owner.createStreamData['livestreamdata'] = {
            ...currentLive,
            ...data,
            'id': livestreamId,
          };
        }
        owner.createStreamData.refresh();

        applyRoomSafetySettingsFromPayload({
          ...body,
          ...data,
          'livestreamdata': owner.createStreamData['livestreamdata'],
        }, source: 'edit_api_success_local');

        /// Host-er screen-e instantly update. Audience websocket event pabe.
        owner.websocketController.updateLiveRoomSettings(
          livestreamId: livestreamId,
          seatCount: seatCount,
          roomLayout: roomLayout,
          roomTheme: roomTheme,
          roomBackground: roomBackground,
          streamTitle: safeStreamTitle,
          streamAnnouncement: safeAnnouncement,
          streamImage: finalStreamImage,
          streamPassword: safeRoomPassword,
        );

        liveLog(
          '✅ Live room edited locally => title:$safeStreamTitle announcement:$safeAnnouncement seats:$seatCount layout:$roomLayout theme:$roomTheme bg:$roomBackground',
        );
        Fluttertoast.showToast(msg: ('Room updated').appTr);
        return body;
      }

      liveLog(
        '⚠️ Live room edit failed: ${response.statusCode} ${response.data}',
      );
      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : ('Room update failed').appTr,
      );
      return null;
    } catch (e) {
      liveLog('❌ Live room edit error: $e');
      Fluttertoast.showToast(msg: ('Room update failed').appTr);
      return null;
    } finally {
      if (requestSequence == _editRequestSequence) {
        roomEditLoading.value = false;
      }
    }
  }

  Future<bool> updateRoomSettingsByEditApi({
    int? roomLock,
    String? roomPassword,
    int? lockComent,
    int? hiddenRoom,
    int? screenRecords,
    int? screenshort,
  }) async {
    final int sid = owner.streamId.value > 0
        ? owner.streamId.value
        : owner.websocketController.streamID.value > 0
        ? owner.websocketController.streamID.value
        : owner.websocketController.activeAudioStreamId.value;

    final int uid =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (sid <= 0 || uid <= 0) {
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return false;
    }
    if (!owner.ensureCanModerateCurrentLive('update_room_settings'))
      return false;

    final currentLive = _currentLiveMapForRoomSettings();

    final int seatCount = owner.websocketController.liveRoomSeatCount.value > 0
        ? owner.websocketController.liveRoomSeatCount.value
        : _toInt(currentLive['seat_count']) > 0
        ? _toInt(currentLive['seat_count'])
        : 9;

    final int roomLayout = owner.websocketController.liveRoomLayout.value != 0
        ? owner.websocketController.liveRoomLayout.value
        : _toInt(currentLive['room_layout']);

    final int roomTheme = owner.websocketController.liveRoomTheme.value != 0
        ? owner.websocketController.liveRoomTheme.value
        : _toInt(currentLive['room_theme']);

    final int roomBackground =
        owner.websocketController.liveRoomBackground.value != -1
        ? owner.websocketController.liveRoomBackground.value
        : currentLive.containsKey('room_background')
        ? _toInt(currentLive['room_background'])
        : -1;

    final String title =
        owner.websocketController.liveRoomTitle.value.trim().isNotEmpty
        ? owner.websocketController.liveRoomTitle.value.trim()
        : (currentLive['stream_bte'] ?? currentLive['title'] ?? 'Live')
              .toString();

    final String announcement =
        owner.websocketController.liveRoomAnnouncement.value.trim().isNotEmpty
        ? owner.websocketController.liveRoomAnnouncement.value.trim()
        : (currentLive['stream_title'] ??
                  currentLive['announcement'] ??
                  currentLive['anousment'] ??
                  '')
              .toString();

    liveLog(
      '🔒 UPDATE ROOM SETTINGS BY EDIT API => '
      'stream:$sid user:$uid roomLock:$roomLock lockComent:$lockComent '
      'hiddenRoom:$hiddenRoom screenRecords:$screenRecords screenshort:$screenshort',
    );

    try {
      roomSettingsLoading.value = true;
      final result = await editLiveStreamRoom(
        livestreamId: sid,
        userId: uid,
        seatCount: seatCount,
        roomLayout: roomLayout,
        roomTheme: roomTheme,
        roomBackground: roomBackground,
        streamTitle: title,
        streamAnnouncement: announcement,
        roomPassword: roomPassword,
        roomLock: roomLock,
        lockComent: lockComent,
        hiddenRoom: hiddenRoom,
        screenRecords: screenRecords,
        screenshort: screenshort,
      );

      final bool ok = result != null && result['success'] != false;
      liveLog('🔒 ROOM SETTINGS API RESULT => success:$ok response:$result');
      return ok;
    } finally {
      roomSettingsLoading.value = false;
    }
  }

  Future<bool> setRoomPasswordLock({
    required bool lock,
    String roomPassword = '',
  }) => updateRoomSettingsByEditApi(
    roomLock: lock ? 1 : 0,
    roomPassword: lock ? roomPassword : '',
  );

  Future<bool> setLiveCommentLock(bool lock) =>
      updateRoomSettingsByEditApi(lockComent: lock ? 1 : 0);

  Future<bool> setHiddenRoom(bool hide) =>
      updateRoomSettingsByEditApi(hiddenRoom: hide ? 1 : 0);

  Future<bool> setScreenRecordBlock(bool block) =>
      updateRoomSettingsByEditApi(screenRecords: block ? 1 : 0);

  Future<bool> setScreenshotBlock(bool block) =>
      updateRoomSettingsByEditApi(screenshort: block ? 1 : 0);

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}
