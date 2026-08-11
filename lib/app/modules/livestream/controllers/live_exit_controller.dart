import 'package:dio/dio.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

import '../../../../apis/api_endpoints.dart';
import '../endLive/endLive.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns normal host livestream removal orchestration.
///
/// LiveCleanupService remains authoritative for full room transitions, Agora
/// leave, presence coordination, session invalidation, and forced cleanup.
class LiveExitController extends GetxController {
  LiveExitController(this.livestreamController);

  final LivestreamController livestreamController;
  final Set<int> _removingLivestreams = <int>{};

  Future<void> tryToRemoveViewer({
    required int streamId,
    required int viewerId,
  }) => livestreamController.liveViewerController.tryToRemoveViewer(
    streamId: streamId,
    viewerId: viewerId,
  );

  Future<void> tryToRemoveLivestream({
    required int streamId,
    bool navigateToEnd = true,
  }) async {
    if (streamId <= 0 || !_removingLivestreams.add(streamId)) {
      liveLog('Duplicate/inapplicable removeLiveStream skipped => $streamId');
      return;
    }
    try {
      livestreamController.isLoading.value = true;
      liveLog('live stream removed');

      final response = await livestreamController.dio.post(
        removeLiveStream(streamId),
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization":
                "Bearer ${livestreamController.authController.userProfile.value.token}",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ Timer বন্ধ করুন
        livestreamController.stopLive();

        livestreamController.isLoading.value = false;

        // ✅ GetX warning fix - () => widget format use করুন
        if (navigateToEnd) {
          Get.offAll(
            () => Endlive(),
            arguments: response.data,
            transition: Transition.cupertino,
          );
        }
      } else {
        livestreamController.isLoading.value = false;
        liveLog(
          "⚠️ Failed to create live stream: ${response.statusCode} - ${response.data}",
        );
      }
    } on DioException catch (e) {
      livestreamController.isLoading.value = false;
      if (e.response != null) {
        liveLog(
          "❌ Server Error: ${e.response!.statusCode} - ${e.response!.data}",
        );
      } else {
        livestreamController.isLoading.value = false;
        liveLog("❌ Network Error: ${e.message}");
      }
    } catch (e) {
      livestreamController.isLoading.value = false;
      liveLog("❌ Unexpected Error: $e");
    }
  }
}
