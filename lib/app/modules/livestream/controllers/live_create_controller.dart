import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../../apis/api_endpoints.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import '../../../services/agora_service.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns live-creation request orchestration while shared room/session state
/// remains in [LivestreamController] during this incremental refactor.
class LiveCreateController extends GetxController {
  LiveCreateController(this.livestreamController);

  final LivestreamController livestreamController;

  Future<bool> tryToCreateLivestream({
    required String streamTitle,
    String anousment = '',
    required String streamType,
    required int userId,
    int? seatCountValue,
    int roomLayout = 0,
    int roomTheme = 0,
    int roomBackground = -1,
    File? streamImageFile,
    String? roomPassword,
    int? roomLock,
    int? lockComent,
    int? hiddenRoom,
    int? screenRecords,
    int? screenshort,
  }) async {
    final Stopwatch createStopwatch = Stopwatch()..start();
    void timing(String label) {
      if (kDebugMode) {
        debugPrint('$label=${createStopwatch.elapsedMilliseconds}ms');
      }
    }

    timing('create_validation_done');

    liveLog('==================================================');
    liveLog('🚀 CREATE LIVE STREAM PROCESS STARTED');
    liveLog('==================================================');

    if (livestreamController.isCreatingLive.value) {
      liveLog('⚠️ Live stream creation already in progress.');
      return false;
    }

    livestreamController.isCreatingLive.value = true;
    debugPrint('LIVE_CREATE_START => type=$streamType');

    // ✅ FIX: audience joins already warm up the Agora engine in the
    // background the instant a join starts (_warmAudioEngineForFastJoin),
    // so by the time the room actually needs it, engine creation is already
    // done. The create/host flow never did this — the engine only started
    // initializing once the whole create+token round trip finished and
    // AudioLiveView mounted, adding that full engine-startup cost onto the
    // critical path. This fires the identical, already-idempotent warmup in
    // parallel with the create API call below, only for audio rooms (video
    // rooms configure their engine differently and must not get an
    // audio-only warmup).
    if (streamType.trim().toLowerCase() == 'audio') {
      Future.microtask(() async {
        try {
          await AgoraService().initializeAudioEngine();
        } catch (e) {
          liveLog('⚠️ Agora audio warmup (create flow) skipped safely => $e');
        }
      });
    }

    final selectedSeatCount =
        seatCountValue ?? livestreamController.seatCount.value;

    final safeStreamTitle = streamTitle.trim().isEmpty
        ? 'Live'
        : streamTitle.trim();

    final safeAnnouncement = anousment.trim();

    final String pickedImagePath =
        streamImageFile?.path ?? livestreamController.audioImage.value.trim();

    final String createLiveUrl = createLiveStream(userId);

    final data = <String, dynamic>{
      'stream_bte': safeStreamTitle,
      'stream_title': safeAnnouncement,
      'announcement': safeAnnouncement,
      'anousment': safeAnnouncement,
      'title': safeStreamTitle,
      'stream_coins': 0,
      'stream_type': streamType,
      'seat_count': selectedSeatCount,
      'gifts_coins': 0,
      'room_layout': roomLayout.toString(),
      'room_theme': roomTheme.toString(),
      'room_background': roomBackground.toString(),
      if (roomPassword != null && roomPassword.trim().isNotEmpty)
        'room_password': roomPassword.trim(),
    };

    try {
      liveLog('📌 Live create information:');
      liveLog('➡️ API URL: $createLiveUrl');
      liveLog('➡️ User ID: $userId');
      liveLog('➡️ Stream title: $safeStreamTitle');
      liveLog('➡️ Announcement: $safeAnnouncement');
      liveLog('➡️ Stream type: $streamType');
      liveLog('➡️ Seat count: $selectedSeatCount');
      liveLog('➡️ Room layout: $roomLayout');
      liveLog('➡️ Room theme: $roomTheme');
      liveLog('➡️ Room background: $roomBackground');
      liveLog(
        '➡️ Password provided: '
            '${roomPassword != null && roomPassword.trim().isNotEmpty}',
      );
      liveLog('➡️ Selected image path: $pickedImagePath');

      dynamic requestData;
      late Options requestOptions;

      final bool pathIsNotEmpty = pickedImagePath.trim().isNotEmpty;
      final File selectedImageFile = File(pickedImagePath);

      final bool imageExists = pathIsNotEmpty
          ? await selectedImageFile.exists()
          : false;

      final bool hasPickedFile = pathIsNotEmpty && imageExists;

      liveLog('🖼️ Image path is not empty: $pathIsNotEmpty');
      liveLog('🖼️ Image file exists: $imageExists');
      liveLog('🖼️ Will upload image: $hasPickedFile');

      if (hasPickedFile) {
        final int imageSize = await selectedImageFile.length();

        final String imageName = pickedImagePath
            .split(Platform.pathSeparator)
            .last;

        liveLog('📁 Image name: $imageName');
        liveLog('📁 Image size: $imageSize bytes');
        liveLog('📦 Request type: multipart/form-data');

        requestData = FormData.fromMap({
          ...data,
          'stream_image': await MultipartFile.fromFile(
            pickedImagePath,
            filename: imageName,
          ),
        });

        requestOptions = Options(
          headers: {
            'Accept': 'application/json',
            'Authorization':
            'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        );
      } else {
        liveLog('📦 Request type: application/json');

        if (pathIsNotEmpty && !imageExists) {
          liveLog('⚠️ Selected image was not found at path: $pickedImagePath');
        }

        requestData = data;

        requestOptions = Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
            'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        );
      }

      liveLog('📤 REQUEST DATA:');

      data.forEach((key, value) {
        if (key == 'room_password') {
          liveLog('➡️ $key: ********');
        } else {
          liveLog('➡️ $key: $value');
        }
      });

      liveLog('⏳ Sending create live API request...');

      timing('create_api_start');
      final response = await livestreamController.dio.post(
        createLiveUrl,
        data: requestData,
        options: requestOptions,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = ((sent / total) * 100).toStringAsFixed(1);
            liveLog('📤 Upload progress: $progress% ($sent/$total bytes)');
          }
        },
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = ((received / total) * 100).toStringAsFixed(1);

            liveLog(
              '📥 Response progress: $progress% '
                  '($received/$total bytes)',
            );
          }
        },
      );
      timing('create_api_done');
      if (kDebugMode) {
        debugPrint('[LIVE_CREATE][API_DONE] status=${response.statusCode}');
      }

      liveLog('==================================================');
      liveLog('✅ CREATE LIVE API RESPONSE RECEIVED');
      liveLog('==================================================');
      liveLog('📥 Status code: ${response.statusCode}');
      liveLog('📥 Status message: ${response.statusMessage}');
      liveLog('📥 Response headers: ${response.headers.map}');
      liveLog('📥 Response data type: ${response.data.runtimeType}');
      if (kDebugMode) {
        liveLog('📥 Create response received');
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        liveLog('❌ Invalid create live response status.');
        liveLog('❌ Expected status: 200 or 201');
        liveLog('❌ Received status: ${response.statusCode}');
        liveLog('❌ Create response rejected by status');

        Get.snackbar(
          ('Error').appTr,
          ('Failed to create live stream. '
              'Status code: ${response.statusCode}')
              .appTr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        return false;
      }

      liveLog('🔄 Normalizing permanent room response...');

      final responseMap = livestreamController.normalizeCreateResponse(
        response.data,
      );

      liveLog('✅ Normalized response keys: ${responseMap.keys.toList()}');

      final live = livestreamController.mapCreateValue(
        responseMap['livestreamdata'],
      );

      liveLog('📺 Original livestream data: $live');

      if (live.isEmpty) {
        liveLog('⚠️ livestreamdata is empty after normalization.');
      }

      live['stream_bte'] = (live['stream_bte'] ?? safeStreamTitle).toString();

      live['title'] = (live['title'] ?? safeStreamTitle).toString();

      live['stream_title'] = (live['stream_title'] ?? safeAnnouncement)
          .toString();

      live['announcement'] = (live['announcement'] ?? safeAnnouncement)
          .toString();

      live['anousment'] = (live['anousment'] ?? safeAnnouncement).toString();

      live['stream_image'] = (live['stream_image'] ?? '').toString();

      responseMap['livestreamdata'] = live;

      liveLog('📺 Final livestream data: $live');
      liveLog('📺 Final response prepared; sensitive values not logged');

      liveLog('🚪 Opening permanent room as host...');
      liveLog('➡️ Requested user ID: $userId');
      liveLog('➡️ Requested stream type: $streamType');
      liveLog('➡️ Requested seat count: $selectedSeatCount');
      liveLog('➡️ Requested room layout: $roomLayout');
      liveLog('➡️ Requested room theme: $roomTheme');
      liveLog('➡️ Requested room background: $roomBackground');

      final opened = await livestreamController.openCreatedRoomAsHost(
        responseMap: responseMap,
        userId: userId,
        requestedStreamType: streamType,
        requestedSeatCount: selectedSeatCount,
        requestedRoomLayout: roomLayout,
        requestedRoomTheme: roomTheme,
        requestedRoomBackground: roomBackground,
      );

      liveLog('==================================================');

      if (opened) {
        debugPrint('LIVE_CREATE_SUCCESS => type=$streamType');
      } else {
        debugPrint('LIVE_CREATE_FAILED => type=$streamType');
        liveLog('❌ LIVE ROOM COULD NOT BE OPENED');
        liveLog('❌ _openPermanentRoomAsHost returned false.');
      }

      liveLog('==================================================');

      return opened;
    } on DioException catch (e, stackTrace) {
      debugPrint('LIVE_CREATE_FAILED => type=$streamType');
      liveLog('==================================================');
      liveLog('❌ DIO CREATE LIVE ERROR');
      liveLog('==================================================');

      liveLog('❌ Dio error type: ${e.type}');
      liveLog('❌ Dio error message: ${e.message}');
      liveLog('❌ Dio error object: ${e.error}');

      liveLog('❌ Request method: ${e.requestOptions.method}');
      liveLog('❌ Request URI: ${e.requestOptions.uri}');
      liveLog('❌ Request base URL: ${e.requestOptions.baseUrl}');
      liveLog('❌ Request path: ${e.requestOptions.path}');
      liveLog(
        '❌ Request content type: '
            '${e.requestOptions.contentType}',
      );

      final safeHeaders = Map<String, dynamic>.from(e.requestOptions.headers);

      if (safeHeaders.containsKey('Authorization')) {
        safeHeaders['Authorization'] = 'Bearer ********';
      }

      liveLog('❌ Request headers: $safeHeaders');

      if (e.requestOptions.data is FormData) {
        final formData = e.requestOptions.data as FormData;

        liveLog('❌ Multipart fields:');

        for (final field in formData.fields) {
          if (field.key == 'room_password') {
            liveLog('   ${field.key}: ********');
          } else {
            liveLog('   ${field.key}: ${field.value}');
          }
        }

        liveLog(
          '❌ Multipart files: '
              '${formData.files.map((file) {
            return {'field': file.key, 'filename': file.value.filename, 'contentType': file.value.contentType.toString()};
          }).toList()}',
        );
      } else {
        liveLog('❌ Request data: ${e.requestOptions.data}');
      }

      liveLog('❌ Response status code: ${e.response?.statusCode}');
      liveLog('❌ Response status message: ${e.response?.statusMessage}');
      liveLog('❌ Response headers: ${e.response?.headers.map}');
      liveLog(
        '❌ Response data type: '
            '${e.response?.data.runtimeType}',
      );
      liveLog('❌ Create error response received');
      liveLog('❌ Stack trace:\n$stackTrace');
      liveLog('==================================================');

      String message = 'Please check your internet connection and try again.';

      final dynamic errorData = e.response?.data;

      if (errorData is Map) {
        message =
            (errorData['message'] ??
                errorData['error'] ??
                errorData['errors'] ??
                'Server error occurred.')
                .toString();
      } else if (errorData != null) {
        message = errorData.toString();
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = e.message!;
      }

      Get.snackbar(
        ('Live Error').appTr,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('LIVE_CREATE_FAILED => type=$streamType');
      liveLog('==================================================');
      liveLog('❌ UNEXPECTED CREATE LIVE ERROR');
      liveLog('==================================================');
      liveLog('❌ Error type: ${e.runtimeType}');
      liveLog('❌ Error details: $e');
      liveLog('❌ Stack trace:\n$stackTrace');
      liveLog('==================================================');

      Get.snackbar(
        ('Error').appTr,
        ('An unexpected error occurred: $e').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      return false;
    } finally {
      livestreamController.isCreatingLive.value = false;
      timing('create_first_ready');

      liveLog('🔓 livestreamController.isCreatingLive reset to false');
      liveLog('🏁 CREATE LIVE STREAM PROCESS FINISHED');
      liveLog('==================================================');
    }
  }
}