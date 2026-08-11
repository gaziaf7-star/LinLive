import 'package:dio/dio.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns viewer membership API orchestration and duplicate request bookkeeping.
/// Viewer collections remain exposed by LivestreamController and are mediated
/// by its single LiveViewerStateManager instance during this phase.
class LiveViewerController extends GetxController {
  LiveViewerController(this.livestreamController);

  final LivestreamController livestreamController;
  final Map<String, Future<Map<String, dynamic>?>> _viewerAddInFlight = {};
  final Set<String> _addedViewerRooms = <String>{};
  final Set<String> _viewerRemoveInFlight = <String>{};

  Future<Map<String, dynamic>?> tryToAddViewer({
    required int streamId,
    required int viewerId,
    bool syncState = true,
    bool activateRoom = true,
  }) {
    final roomKey = '$streamId:$viewerId';
    if (_addedViewerRooms.contains(roomKey)) {
      liveLog('Duplicate addViewer skipped for active room => $roomKey');
      return Future<Map<String, dynamic>?>.value(
        livestreamController.createData.isEmpty
            ? <String, dynamic>{'livestream_id': streamId}
            : Map<String, dynamic>.from(livestreamController.createData),
      );
    }

    final key = roomKey;
    final running = _viewerAddInFlight[key];
    if (running != null) {
      liveLog('♻️ Duplicate addViewer joined existing request => $key');
      return running;
    }

    final future = _performAddViewer(
      streamId: streamId,
      viewerId: viewerId,
      syncState: syncState,
      activateRoom: activateRoom,
    );
    _viewerAddInFlight[key] = future;
    future.whenComplete(() => _viewerAddInFlight.remove(key));
    return future;
  }

  Future<Map<String, dynamic>?> _performAddViewer({
    required int streamId,
    required int viewerId,
    required bool syncState,
    required bool activateRoom,
  }) async {
    try {
      final response = await livestreamController.dio.get(
        addViewer(streamId, viewerId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _addedViewerRooms.add('$streamId:$viewerId');
        if (activateRoom) {
          livestreamController.websocketController.prepareViewerRejoin(
            livestreamId: streamId,
            viewerId: viewerId,
          );
        }
        // Viewer join must always remove previous room owner role from this device.
        // Otherwise: own live -> other live -> sit on seat can still show Host/Admin.
        livestreamController.isHost.value = false;
        livestreamController.isBroadcaster.value = false;
        final responseMap = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        livestreamController.createData.value = responseMap;

        final addedViewer = responseMap['viewer'] ?? responseMap['viewer_data'];
        if (addedViewer != null) {
          livestreamController.addOrUpdateViewerLocal(addedViewer, force: true);
        }

        if (syncState && activateRoom) {
          await livestreamController.applyLivestreamState(responseMap);
        } else if (activateRoom) {
          final int sid = streamId > 0
              ? streamId
              : livestreamController.toIntForViewer(
                  responseMap['livestream_id'] ??
                      responseMap['stream_id'] ??
                      responseMap['id'],
                );
          if (sid > 0) {
            livestreamController.streamId.value = sid;
            livestreamController.websocketController.streamID.value = sid;
          }
        }

        final int joinedStreamId = streamId > 0
            ? streamId
            : livestreamController.toIntForViewer(
                responseMap['livestream_id'] ??
                    responseMap['stream_id'] ??
                    responseMap['id'],
              );
        if (joinedStreamId > 0 && activateRoom) {
          livestreamController.streamId.value = joinedStreamId;
          livestreamController.websocketController.streamID.value =
              joinedStreamId;

          livestreamController.ensureViewerPresenceAfterAdd(joinedStreamId);
        }
        return responseMap;
      }

      liveLog('⚠️ Failed to add viewer: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      liveLog('❌ Add viewer error: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      liveLog('❌ Unexpected add viewer error: $e');
      return null;
    }
  }

  Future<void> tryToRemoveViewer({
    required int streamId,
    required int viewerId,
  }) async {
    final roomKey = '$streamId:$viewerId';
    final pendingAdd = _viewerAddInFlight[roomKey];
    if (pendingAdd != null) {
      await pendingAdd;
    }
    if (streamId <= 0 ||
        viewerId <= 0 ||
        _viewerRemoveInFlight.contains(roomKey) ||
        !_addedViewerRooms.contains(roomKey)) {
      liveLog('Duplicate/inapplicable removeViewer skipped => $roomKey');
      return;
    }
    _viewerRemoveInFlight.add(roomKey);
    try {
      liveLog(
        '📤 tryToRemoveViewer request => streamId=$streamId viewerId=$viewerId',
      );

      final response = await livestreamController.dio.get(
        removeViewer(streamId, viewerId),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        livestreamController.removeData.value = response.data;

        /// Backend response-er removed_viewer theke real user id nibo.
        /// viewer row id diye clear korle wrong match/404 dite pare.
        final removedViewer = response.data['removed_viewer'];
        final realUserId = removedViewer is Map
            ? (removedViewer['user']?['id'] ??
                  removedViewer['viewer_id'] ??
                  removedViewer['user_id'] ??
                  viewerId)
            : viewerId;

        liveLog(
          "✅ Viewer removed stream: ${removedViewer is Map ? removedViewer['livestream_id'] : streamId}",
        );
        liveLog("🧹 Clear local viewer data for realUserId=$realUserId");

        livestreamController.viewerState.removeByUserId(realUserId);
        livestreamController.websocketController.clearSpecificUserStreamData(
          userId: realUserId.toString(),
          rejectCallIfInCallList: false,
        );
      } else {
        liveLog(
          "⚠️ Failed to remove viewer: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      /// 404 can happen if backend already removed viewer by websocket/another call.
      /// Treat it as already removed, not fatal.
      if (e.response?.statusCode == 404) {
        liveLog("ℹ️ Viewer already removed / not found: ${e.response?.data}");
        livestreamController.viewerState.removeByUserId(viewerId);
        livestreamController.websocketController.clearSpecificUserStreamData(
          userId: viewerId.toString(),
          rejectCallIfInCallList: false,
        );
        return;
      }

      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    } finally {
      _viewerRemoveInFlight.remove(roomKey);
      _addedViewerRooms.remove(roomKey);
    }
  }

  Future<void> tryToGetViewerList({required int streamId}) async {
    try {
      final response = await livestreamController.dio.get(
        getViewerList(streamId),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!livestreamController.acceptsRoomMutation(streamId)) {
          liveLog('Late legacy viewer list ignored => stream=$streamId');
          return;
        }
        livestreamController.viewerList.value = response.data;
        liveLog("✅ Viewer list fetched successfully: ${response.data}");
      } else {
        liveLog(
          "⚠️ Failed to fetch viewer list: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      liveLog("❌ Unexpected Error: $e");
    }
  }
}
