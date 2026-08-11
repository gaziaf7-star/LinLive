import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/image_helper.dart';
import '../../../localization/app_localizer.dart';
import '../endLive/endLive.dart';
import '../utils/live_performance_config.dart';
import '../views/audio_live_view.dart';
import '../views/multi_live_view.dart';
import '../views/popular_live_view.dart';
import 'livestream_controller.dart';

/// Owns persistent-owner-room lookup, rejoin/reopen, host preparation, leave,
/// and close business orchestration. Active-session identity, generic create,
/// full cleanup, Agora engine lifecycle, and realtime routing remain delegated.
class LivePermanentRoomController extends GetxController {
  LivePermanentRoomController(this.livestreamController);

  final LivestreamController livestreamController;
  Dio get dio => livestreamController.dio;

  int _permanentActionSerial = 0;

  bool _actionIsCurrent(int serial, int generation) =>
      serial == _permanentActionSerial &&
      generation == livestreamController.roomSessionGeneration;

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _intOf(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  final isPermanentRoomActionLoading = false.obs;

  /// True only while the current owner is permanently closing the room.
  /// WebSocket uses this flag to avoid routing the same device to Bottomnav
  /// before the REST close response opens the Endlive summary page.
  final isOwnerClosingPermanentRoom = false.obs;

  final lastPermanentRoomActionData = <String, dynamic>{}.obs;

  String resolvePermanentRoomChannel(
    dynamic payload, {
    int fallbackOwnerId = 0,
  }) {
    final root = _mapOf(payload);
    final data = _mapOf(root['data']);
    final live = {
      ..._mapOf(data['livestreamdata']),
      ..._mapOf(data['livestream']),
      ..._mapOf(root['livestreamdata']),
      ..._mapOf(root['livestream']),
    };

    // One permanent room must always use one stable Agora channel.
    // Existing production rooms already use owner/room_id (for example 100558).
    // Some rejoin responses returned live_<livestreamId>; preferring that value
    // split host and audience into different Agora channels.
    final candidates = <dynamic>[
      live['room_id'],
      live['channel_name'],
      root['room_id'],
      root['channel_name'],
      live['owner_user_id'],
      live['user_id'],
      fallbackOwnerId,
      root['agora_channel_name'],
      root['audience_join_agora_channel'],
      data['agora_channel_name'],
      live['agora_channel'],
      root['agora_channel'],
    ];

    for (final raw in candidates) {
      final value = raw?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null' && value != '0') {
        return value;
      }
    }

    return '';
  }

  Map<String, dynamic> _normalizePermanentRoomResponse(
    dynamic responseData, {
    Map<String, dynamic>? fallbackLiveData,
  }) {
    final root = _mapOf(responseData);
    final nestedData = _mapOf(root['data']);
    final responseLive = {
      ...?fallbackLiveData,
      ..._mapOf(nestedData['livestreamdata']),
      ..._mapOf(nestedData['livestream']),
      ..._mapOf(root['livestreamdata']),
      ..._mapOf(root['livestream']),
    };

    if (responseLive.isNotEmpty) {
      root['livestreamdata'] = responseLive;
    }

    return root;
  }

  Map<String, dynamic> normalizeCreateResponse(dynamic responseData) =>
      _normalizePermanentRoomResponse(responseData);

  Map<String, dynamic> mapCreateValue(dynamic value) => _mapOf(value);

  Future<bool> _openPermanentRoomAsHost({
    required Map<String, dynamic> responseMap,
    required int userId,
    bool preserveExistingMute = false,
    String? requestedStreamType,
    int? requestedSeatCount,
    int? requestedRoomLayout,
    int? requestedRoomTheme,
    int? requestedRoomBackground,
  }) async {
    final live = _mapOf(responseMap['livestreamdata']);
    final int livestreamId = _intOf(live['id'] ?? live['livestream_id']);
    final String channelName = resolvePermanentRoomChannel(
      responseMap,
      fallbackOwnerId: userId,
    );

    if (livestreamId <= 0 || channelName.isEmpty) {
      Get.snackbar(
        ('Room Error').appTr,
        ('Permanent room ID or Agora channel is missing.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    bool mutedFromFields(dynamic audioOn, dynamic mutedRaw) {
      final String audio = audioOn?.toString().trim().toLowerCase() ?? '';
      final String muted = mutedRaw?.toString().trim().toLowerCase() ?? '';

      if (audio == '0' ||
          audio == 'false' ||
          audio == 'off' ||
          audio == 'mute' ||
          audio == 'muted') {
        return true;
      }
      if (audio == '1' ||
          audio == 'true' ||
          audio == 'on' ||
          audio == 'unmute' ||
          audio == 'unmuted') {
        return false;
      }
      return muted == '1' ||
          muted == 'true' ||
          muted == 'yes' ||
          muted == 'mute' ||
          muted == 'muted';
    }

    bool responseHostMuted = false;
    final dynamic originalCallersRaw = live['livestream_callers'];
    if (originalCallersRaw is List) {
      for (final raw in originalCallersRaw) {
        final Map<String, dynamic> call = _mapOf(raw);
        final Map<String, dynamic> callUser = _mapOf(call['user']);
        final int callerId = _intOf(
          call['caller_id'] ?? call['user_id'] ?? callUser['id'],
        );
        final bool isHostRow =
            callerId == userId ||
            call['is_broadcaster'] == true ||
            call['is_broadcaster'] == 1 ||
            call['is_broadcaster']?.toString() == '1';
        if (!isHostRow) continue;

        responseHostMuted = mutedFromFields(
          call['audio_on'] ??
              call['is_audio_on'] ??
              callUser['audio_on'] ??
              callUser['is_audio_on'],
          call['is_muted'] ??
              call['muted'] ??
              call['is_muted_by_host'] ??
              callUser['is_muted'] ??
              callUser['muted'],
        );
        break;
      }
    }

    final bool localHostMuted =
        livestreamController.mute.value == true ||
        livestreamController.websocketController.audioMutedUserMap[userId] ==
            true;

    /// The server may mark an offline host row audio_on=0 simply because the
    /// host left the Agora channel. That is not always a manual mute. For a
    /// same-app permanent-room rejoin, the persistent local controller state is
    /// the safe source of the user's actual mute choice.
    final bool hostStartsMuted = preserveExistingMute && localHostMuted;
    final int restoredAudioOn = hostStartsMuted ? 0 : 1;

    live['id'] = livestreamId;
    live['livestream_id'] = livestreamId;
    live['room_id'] = channelName;
    live['channel_name'] = channelName;
    live['agora_channel'] = channelName;
    live['host_online'] = true;
    live['room_status'] = 'active';

    // A closed/left room can contain an offline broadcaster row with
    // audio_on=0. Fresh create starts unmuted; same-session rejoin uses the
    // preserved local manual mute choice resolved above.
    final dynamic callersRaw = live['livestream_callers'];
    if (callersRaw is List) {
      live['livestream_callers'] = callersRaw.map((raw) {
        final call = _mapOf(raw);
        final callUser = _mapOf(call['user']);
        final callerId = _intOf(
          call['caller_id'] ?? call['user_id'] ?? callUser['id'],
        );
        if (callerId == userId ||
            call['is_broadcaster'] == true ||
            call['is_broadcaster'] == 1) {
          call['caller_id'] = userId;
          call['seat_no'] = 1;
          call['call_status'] = 'accepted';
          call['is_broadcaster'] = true;
          call['audio_on'] = restoredAudioOn;
          call['is_audio_on'] = restoredAudioOn;
          call['is_muted'] = hostStartsMuted ? 1 : 0;
          call['is_muted_by_host'] = 0;
          call['is_active'] = 1;
        }
        return call;
      }).toList();
    }

    responseMap['livestreamdata'] = live;
    responseMap['agora_channel_name'] = channelName;
    responseMap['room_id'] = channelName;
    responseMap['channel_name'] = channelName;

    final String backgroundRaw =
        (live['room_background_image'] ??
                live['background_image'] ??
                live['stream_image'] ??
                '')
            .toString()
            .trim();
    final BuildContext? prefetchContext = Get.context;
    if (backgroundRaw.isNotEmpty &&
        backgroundRaw != 'null' &&
        prefetchContext != null) {
      final String backgroundUrl = ImageHelper.getImageUrl(backgroundRaw);
      if (backgroundUrl.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(
            backgroundUrl,
            cacheKey: backgroundUrl,
            maxWidth: 1080,
            maxHeight: 1920,
          ),
          prefetchContext,
        ).ignore();
      }
    }

    /// Clear old room-scoped lists first, then restore this room's host mute.
    /// Doing it in the opposite order made resetAudioRoomStateForStream() erase
    /// the rejoin mute state and produced an unmuted icon with a silent Agora mic.
    livestreamController.websocketController.resetAudioRoomStateForStream(
      newStreamId: livestreamId,
      force: true,
    );

    livestreamController.mute.value = hostStartsMuted;
    livestreamController.isMuted.value = hostStartsMuted;
    livestreamController.isAudioEnabled.value = !hostStartsMuted;
    livestreamController.websocketController.audioMutedUserMap[userId] =
        hostStartsMuted;
    livestreamController.websocketController.audioMutedUserMap.refresh();

    liveLog(
      '🎙️ Permanent room host mute restored => stream=$livestreamId '
      'rejoin=$preserveExistingMute local=$localHostMuted '
      'response=$responseHostMuted muted=$hostStartsMuted',
    );
    livestreamController.createStreamData.value = responseMap;
    livestreamController.isHost.value = true;
    livestreamController.isBroadcaster.value = true;
    livestreamController.streamId.value = livestreamId;
    livestreamController.websocketController.streamID.value = livestreamId;
    livestreamController.activateRoomSession(
      streamId: livestreamId,
      generation: livestreamController.roomSessionGeneration,
    );

    livestreamController.liveMusicController.resetMusicState();
    livestreamController.liveYoutubeController.resetYoutubeState();

    livestreamController.websocketController.liveCallList.clear();
    dynamic broadcasterCall = responseMap['broadcaster_call_data'];
    if (broadcasterCall == null && live['livestream_callers'] is List) {
      final callers = List<dynamic>.from(live['livestream_callers']);
      for (final raw in callers) {
        final call = _mapOf(raw);
        final callerId = _intOf(
          call['caller_id'] ?? call['user_id'] ?? _mapOf(call['user'])['id'],
        );
        if (callerId == userId ||
            call['is_broadcaster'] == true ||
            call['is_broadcaster'] == 1) {
          broadcasterCall = raw;
          break;
        }
      }
    }
    if (broadcasterCall != null) {
      final normalizedBroadcaster = _mapOf(broadcasterCall);
      normalizedBroadcaster['caller_id'] = userId;
      normalizedBroadcaster['seat_no'] = 1;
      normalizedBroadcaster['call_status'] = 'accepted';
      normalizedBroadcaster['is_broadcaster'] = true;
      normalizedBroadcaster['audio_on'] = restoredAudioOn;
      normalizedBroadcaster['is_audio_on'] = restoredAudioOn;
      normalizedBroadcaster['is_muted'] = hostStartsMuted ? 1 : 0;
      normalizedBroadcaster['is_muted_by_host'] = 0;
      normalizedBroadcaster['is_active'] = 1;
      livestreamController.websocketController.liveCallList.add(
        normalizedBroadcaster,
      );
      responseMap['broadcaster_call_data'] = normalizedBroadcaster;
    }

    final createdAt = (live['start_time'] ?? live['created_at'])?.toString();
    livestreamController.liveTimeCase(
      streamId: livestreamId,
      startTime: DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
    );

    final tokenReady = await livestreamController.agoraTokenController
        .tryToGenerateBroadcasterToken(
          isBroadcaster: true,
          userId: userId,
          channelName: channelName,
          streamId: livestreamId.toString(),
        );

    final token = livestreamController.agoraTokenController.getTokenString();
    if (!tokenReady || token.isEmpty) {
      Get.snackbar(
        ('Token Error').appTr,
        ('Could not generate the Agora broadcaster token.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    livestreamController.saveNormalLiveAgoraSession(
      channelName: channelName,
      token: token,
      isBroadcaster: true,
    );

    final String streamType =
        (requestedStreamType ?? live['stream_type'] ?? 'audio')
            .toString()
            .toLowerCase();
    final int safeSeatCount = requestedSeatCount ?? _intOf(live['seat_count']);
    final int safeLayout = requestedRoomLayout ?? _intOf(live['room_layout']);
    final int safeTheme = requestedRoomTheme ?? _intOf(live['room_theme']);
    final int safeBackground =
        requestedRoomBackground ?? _intOf(live['room_background'] ?? -1);

    if (kDebugMode) {
      debugPrint('create_navigation=${DateTime.now().microsecondsSinceEpoch}');
    }
    if (streamType == 'audio') {
      livestreamController.clearMinimizedVideoLiveSession();
      // await AgoraService().prepareAudioOnlyMode(
      //   reason: 'open_audio_room',
      // );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      Get.to(
        () => AudioLiveView(
          channelName: channelName,
          isBroadcaster: true,
          token: token,
          seatCount: safeSeatCount > 0
              ? safeSeatCount
              : livestreamController.seatCount.value,
          roomLayout: safeLayout,
          roomTheme: safeTheme,
          roomBackground: safeBackground,
        ),
        arguments: responseMap,
      );
    } else if (streamType == 'multi') {
      Get.to(
        () => MultiLiveView(
          channelName: channelName,
          isBroadcaster: true,
          token: token,
          seatCount: safeSeatCount > 0
              ? safeSeatCount
              : livestreamController.seatCount.value,
        ),
        arguments: responseMap,
      );
    } else if (streamType == 'popular' || streamType == 'video') {
      Get.to(
        () => PopularLiveView(
          channelName: channelName,
          isBroadcaster: true,
          token: token,
        ),
        arguments: responseMap,
      );
    } else {
      Get.snackbar(
        ('Unsupported Room').appTr,
        ('This permanent-room rejoin flow supports audio, multi and popular rooms.')
            .appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  Future<bool> openCreatedRoomAsHost({
    required Map<String, dynamic> responseMap,
    required int userId,
    String? requestedStreamType,
    int? requestedSeatCount,
    int? requestedRoomLayout,
    int? requestedRoomTheme,
    int? requestedRoomBackground,
  }) => _openPermanentRoomAsHost(
    responseMap: responseMap,
    userId: userId,
    requestedStreamType: requestedStreamType,
    requestedSeatCount: requestedSeatCount,
    requestedRoomLayout: requestedRoomLayout,
    requestedRoomTheme: requestedRoomTheme,
    requestedRoomBackground: requestedRoomBackground,
  );

  Future<Map<String, dynamic>?> getMyPermanentRoom({
    required int userId,
    bool showNotFound = false,
  }) async {
    try {
      final response = await dio.get(
        kMyPermanentRoomUrl(userId),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }

      if (showNotFound) {
        Get.snackbar(('Room').appTr, ('Permanent room not found.').appTr);
      }
    } on DioException catch (e) {
      if (showNotFound && e.response?.statusCode != 404) {
        Get.snackbar(('Room Error').appTr, '${e.response?.data ?? e.message}');
      }
    } catch (e) {
      if (showNotFound) Get.snackbar(('Room Error').appTr, '$e');
    }
    return null;
  }

  Future<bool> _restartClosedPermanentRoom({
    required int userId,
    Map<String, dynamic>? fallbackLiveData,
  }) async {
    final live = _mapOf(fallbackLiveData);
    final title = (live['stream_bte'] ?? live['title'] ?? 'Live Room')
        .toString()
        .trim();
    final announcement =
        (live['anousment'] ??
                live['announcement'] ??
                live['stream_title'] ??
                '')
            .toString()
            .trim();

    liveLog('♻️ Closed permanent room will be reopened through create API');

    return livestreamController.tryToCreateLivestream(
      streamTitle: title.isEmpty ? 'Live Room' : title,
      anousment: announcement,
      streamType: (live['stream_type'] ?? 'audio').toString(),
      userId: userId,
      seatCountValue: _intOf(live['seat_count']) > 0
          ? _intOf(live['seat_count'])
          : livestreamController.seatCount.value,
      roomLayout: _intOf(live['room_layout']),
      roomTheme: _intOf(live['room_theme']),
      roomBackground: live.containsKey('room_background')
          ? _intOf(live['room_background'])
          : -1,
      roomPassword: live['room_password']?.toString(),
    );
  }

  Future<bool> rejoinPermanentRoom({
    required int livestreamId,
    Map<String, dynamic>? fallbackLiveData,
  }) async {
    if (isPermanentRoomActionLoading.value || livestreamId <= 0) return false;

    final int userId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
        0;
    if (userId <= 0) return false;

    final int actionSerial = ++_permanentActionSerial;
    final int actionGeneration = livestreamController.roomSessionGeneration;
    isPermanentRoomActionLoading.value = true;
    try {
      final response = await dio.post(
        kJoinPermanentRoomUrl(livestreamId),
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        // A room explicitly closed by its owner cannot use the join endpoint.
        // Reopen the same permanent room through the create API instead.
        if (response.statusCode == 409 || response.statusCode == 410) {
          if (!_actionIsCurrent(actionSerial, actionGeneration)) return false;
          return _restartClosedPermanentRoom(
            userId: userId,
            fallbackLiveData: fallbackLiveData,
          );
        }

        Get.snackbar(
          ('Rejoin Failed').appTr,
          ('Could not rejoin this permanent room.').appTr,
        );
        return false;
      }

      final responseMap = _normalizePermanentRoomResponse(
        response.data,
        fallbackLiveData: fallbackLiveData,
      );
      if (!_actionIsCurrent(actionSerial, actionGeneration)) return false;
      lastPermanentRoomActionData.value = responseMap;

      return _openPermanentRoomAsHost(
        responseMap: responseMap,
        userId: userId,
        preserveExistingMute: true,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 || e.response?.statusCode == 410) {
        if (!_actionIsCurrent(actionSerial, actionGeneration)) return false;
        return _restartClosedPermanentRoom(
          userId: userId,
          fallbackLiveData: fallbackLiveData,
        );
      }

      final message = e.response?.data is Map
          ? '${e.response?.data['message'] ?? 'Permanent room rejoin failed'}'
          : 'Permanent room rejoin failed';
      Get.snackbar(
        ('Rejoin Failed').appTr,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e) {
      Get.snackbar(
        ('Rejoin Failed').appTr,
        '$e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      if (actionSerial == _permanentActionSerial) {
        isPermanentRoomActionLoading.value = false;
      }
    }
  }

  Future<bool> leavePermanentRoom({required int livestreamId}) async {
    final int userId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
        0;
    if (livestreamId <= 0 || userId <= 0) return false;

    try {
      final response = await dio.post(
        kHostLeavePermanentRoomUrl(livestreamId),
        data: {'user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );
      if (response.data is Map) {
        lastPermanentRoomActionData.value = Map<String, dynamic>.from(
          response.data as Map,
        );
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      liveLog('⚠️ Permanent host leave API failed safely: $e');
      return false;
    }
  }

  Future<bool> closePermanentRoom({
    required int livestreamId,
    bool navigateToEnd = true,
  }) async {
    if (isPermanentRoomActionLoading.value) return false;

    final int userId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
        0;

    if (livestreamId <= 0 || userId <= 0) {
      Get.snackbar(
        ('Close Failed').appTr,
        ('Invalid room or user information.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final int actionSerial = ++_permanentActionSerial;
    final int actionGeneration = livestreamController.roomSessionGeneration;
    isPermanentRoomActionLoading.value = true;
    isOwnerClosingPermanentRoom.value = true;

    try {
      final response = await dio.post(
        kOwnerClosePermanentRoomUrl(livestreamId),
        data: {'owner_user_id': userId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final responseMap = _mapOf(response.data);
        Get.snackbar(
          ('Close Failed').appTr,
          '${responseMap['message'] ?? 'Only the room owner can close this room.'}',
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }

      final Map<String, dynamic> rawResult = _mapOf(response.data);
      final Map<String, dynamic> rawLiveData = _mapOf(
        rawResult['livestream_data'],
      );
      final Map<String, dynamic> rawEndData = _mapOf(
        rawResult['end_live_data'],
      );

      Map<String, dynamic> fallbackUser = <String, dynamic>{};
      try {
        final dynamic profileUser =
            livestreamController.authController.userProfile.value.user;
        fallbackUser = _mapOf(profileUser?.toJson());
      } catch (_) {
        fallbackUser = <String, dynamic>{};
      }

      final Map<String, dynamic> responseUser = _mapOf(
        rawLiveData['user'] ?? rawLiveData['User'] ?? rawResult['user'],
      );

      final Map<String, dynamic> safeUser = {...fallbackUser, ...responseUser};

      final Map<String, dynamic> safeLiveData = {
        ...rawLiveData,
        'id': rawLiveData['id'] ?? rawLiveData['livestream_id'] ?? livestreamId,
        'livestream_id':
            rawLiveData['livestream_id'] ?? rawLiveData['id'] ?? livestreamId,
        'user': safeUser,
        'live_duration_seconds':
            rawLiveData['live_duration_seconds'] ??
            rawEndData['live_duration_seconds'] ??
            livestreamController.elapsed.value,
      };

      final Map<String, dynamic> safeEndData = {
        ...rawEndData,
        'livestream_id': rawEndData['livestream_id'] ?? livestreamId,
        'gift_amount':
            rawEndData['gift_amount'] ??
            rawResult['gift_amount'] ??
            livestreamController.totalGiftCoins.value,
        'audience':
            rawEndData['audience'] ??
            rawResult['audience'] ??
            rawResult['viewer_count'] ??
            0,
      };

      final Map<String, dynamic> safeResult = {
        ...rawResult,
        'success': rawResult['success'] ?? true,
        'livestream_id': rawResult['livestream_id'] ?? livestreamId,
        'livestream_data': safeLiveData,
        'end_live_data': safeEndData,
        'new_followers': rawResult['new_followers'] ?? 0,
      };

      lastPermanentRoomActionData.value = safeResult;

      if (_actionIsCurrent(actionSerial, actionGeneration)) {
        livestreamController.stopPingUpdate();
        livestreamController.stopLivePresenceHeartbeat();
        livestreamController.stopLive();
        livestreamController.isHost.value = false;
        livestreamController.isBroadcaster.value = false;
        livestreamController.websocketController.streamID.value = 0;
        livestreamController.websocketController.activeAudioStreamId.value = 0;

        if (navigateToEnd) {
          /// The owner-close WebSocket event can arrive before this REST response.
          /// WebSocket now skips its Bottomnav redirect while the flag above is true.
          /// A small microtask keeps GetX navigation deterministic.
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!_actionIsCurrent(actionSerial, actionGeneration)) return true;

          Get.offAll(
            () => const Endlive(),
            arguments: safeResult,
            transition: Transition.cupertino,
          );
        }
      }

      return true;
    } on DioException catch (e) {
      final responseMap = _mapOf(e.response?.data);
      final message = '${responseMap['message'] ?? 'Room close failed'}';

      Get.snackbar(
        ('Close Failed').appTr,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } catch (e, st) {
      liveLog('❌ Permanent room close error => $e');
      liveLog('$st');

      Get.snackbar(
        ('Close Failed').appTr,
        ('Room close failed. Please try again.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      if (actionSerial == _permanentActionSerial) {
        isPermanentRoomActionLoading.value = false;
      }

      /// Keep the protection alive briefly so a delayed live_ended socket
      /// event cannot replace Endlive with Bottomnav.
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (actionSerial == _permanentActionSerial) {
          isOwnerClosingPermanentRoom.value = false;
        }
      });
    }
  }
}
