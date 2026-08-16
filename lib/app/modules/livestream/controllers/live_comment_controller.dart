import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';
import '../socket/websocket_controller.dart';

/// Owns REST orchestration for comments in the active livestream room.
/// WebSocketController remains the temporary authoritative realtime feed.
class LiveCommentController extends GetxController {
  LiveCommentController(this.owner);

  final LivestreamController owner;

  final commentSending = false.obs;
  final commentCleaning = false.obs;
  int _sendRequestSequence = 0;
  int _cleanRequestSequence = 0;

  RxList<dynamic> get commentsList => owner.websocketController.commentsList;

  Future<void> tryToAddComment({required String comment}) async {
    final int userId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    final int targetStreamId = owner.streamId.value;
    final int roomGeneration = owner.roomSessionGeneration;
    final int requestSequence = ++_sendRequestSequence;

    liveLog('[COMMENT][CONTROLLER_ENTER] room=$targetStreamId user=$userId');
    if (comment.trim().isEmpty) {
      liveLog('[COMMENT][UI_BLOCKED] reason=empty');
      return;
    }
    if (targetStreamId <= 0 || userId <= 0) {
      liveLog('[COMMENT][UI_BLOCKED] reason=no_stream');
      Fluttertoast.showToast(msg: ('Live room not ready').appTr);
      return;
    }

    try {
      commentSending.value = true;
      final url = addComment(targetStreamId, userId);

      liveLog('Comment URL: $url');
      liveLog('Comment user: $userId stream: $targetStreamId');
      liveLog('[COMMENT][API_START]');

      final response = await owner.dio.post(
        url,
        data: {'comment': comment},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      liveLog('[COMMENT][API_DONE] status=${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (roomGeneration == owner.roomSessionGeneration &&
            owner.acceptsRoomMutation(targetStreamId)) {
          owner.websocketController.addSentCommentLocally(
            livestreamId: targetStreamId,
            userId: userId,
            comment: comment,
            user: owner.authController.userProfile.value.user?.toJson() ??
                <String, dynamic>{'id': userId},
          );
          liveLog('Comment added successfully');
        } else {
          liveLog(
            'Ignored stale comment response => stream:$targetStreamId '
            'generation:$roomGeneration/${owner.roomSessionGeneration}',
          );
        }
      } else {
        liveLog('Comment failed: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        liveLog('Comment server error: ${e.response!.statusCode}');
        liveLog('Comment error data: ${e.response!.data}');
      } else {
        liveLog('Comment network error: ${e.message}');
      }
    } catch (e) {
      liveLog('Unexpected comment error: $e');
    } finally {
      if (requestSequence == _sendRequestSequence) {
        commentSending.value = false;
      }
    }
  }

  Future<bool> cleanLiveComments() async {
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

    final int roomGeneration = owner.roomSessionGeneration;
    final int requestSequence = ++_cleanRequestSequence;
    final String url = '$kMainUrl/livestream/$sid/comments/clear/$uid';
    final data = <String, dynamic>{
      'action_type': 'clear_live_comments',
      'livestream_id': sid,
      'clear_comments': true,
      'comments': [],
      'comment_list': [],
      'live_comments': [],
    };

    try {
      commentCleaning.value = true;
      // Existing settings screens use this shared loading indicator while the
      // clean action is pending. Keep it synchronized for compatibility.
      owner.roomSettingsLoading.value = true;

      final response = await owner.dio.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
          validateStatus: (_) => true,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (requestSequence == _cleanRequestSequence &&
            roomGeneration == owner.roomSessionGeneration &&
            owner.acceptsRoomMutation(sid)) {
          owner.websocketController.clearLiveCommentsLocal(
            livestreamId: sid,
            source: 'clean_api_success_host',
          );
          Fluttertoast.showToast(msg: ('Chat cleaned').appTr);
        } else {
          liveLog(
            'Ignored stale clean-chat response => stream:$sid '
            'generation:$roomGeneration/${owner.roomSessionGeneration}',
          );
        }
        return true;
      }

      Fluttertoast.showToast(msg: ('Clean chat failed').appTr);
      return false;
    } catch (e, st) {
      liveLog('Clean-live-comments error => $e\n$st');
      Fluttertoast.showToast(msg: ('Clean chat failed').appTr);
      return false;
    } finally {
      if (requestSequence == _cleanRequestSequence) {
        commentCleaning.value = false;
        if (roomGeneration == owner.roomSessionGeneration ||
            !owner.roomEditLoading.value) {
          owner.roomSettingsLoading.value = false;
        }
      }
    }
  }
}
