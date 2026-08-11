import 'package:flutter/material.dart';
import 'package:get/get.dart';


import '../app/modules/livestream/controllers/livestream_controller.dart';
import '../app/modules/livestream/socket/websocket_controller.dart';
import '../constants/layout_constant.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CallRejectionWidget extends StatelessWidget {
  final bool isBroadcaster;
  final int streamId;
  final int userId;
  final bool isUserInCallerList;
  final String streamType;

  const CallRejectionWidget({
    super.key,
    required this.isBroadcaster,
    required this.streamId,
    required this.userId,
    required this.isUserInCallerList,
    required this.streamType,
  });

  @override
  Widget build(BuildContext context) {
    final LivestreamController controller = Get.find<LivestreamController>();

    if (isBroadcaster) {
      // Broadcaster can see caller list with options
      return _buildBroadcasterView(controller);
    } else if (isUserInCallerList) {
      // User is in caller list, show cancel button
      return _buildCallerCancelButton(controller);
    } else {
      // User is just a viewer, show nothing
      return const SizedBox.shrink();
    }
  }

  Widget _buildBroadcasterView(LivestreamController controller) {
    return InkWell(
      onTap: () => _showCallerListBottomSheet(controller),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Image.asset(
          'assets/audio_live/managecalls.png',
          height: kHeight * 0.03,
          width: kHeight * 0.03,
        ),
      ),
    );
  }

  Widget _buildCallerCancelButton(LivestreamController controller) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        onPressed: () => _cancelCall(controller),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Icon(
          Icons.call_end,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showCallerListBottomSheet(LivestreamController controller) {
    final WebsocketController websocketController =
        Get.find<WebsocketController>();

    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Obx(() {
          final liveCallers = websocketController.liveCallList;
          final pendingCallers = websocketController.pendingCall;

          // Filter out the broadcaster from caller lists
          final filteredLiveCallers = liveCallers.where((caller) {
            final callerId = caller['caller_id'] ??
                caller['user']?['id'] ??
                caller['User']?['id'];
            return callerId !=
                userId; // Don't show broadcaster in their own caller list
          }).toList();

          final filteredPendingCallers = pendingCallers.where((caller) {
            final callerId = caller['caller_id'] ??
                caller['user']?['id'] ??
                caller['User']?['id'];
            return callerId !=
                userId; // Don't show broadcaster in their own caller list
          }).toList();

          final totalCallers = [
            ...filteredLiveCallers,
            ...filteredPendingCallers
          ];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ('Caller List (${totalCallers.length})').appTr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (totalCallers.isEmpty)
                 Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        ('No callers in the list').appTr,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: totalCallers.length,
                    itemBuilder: (context, index) {
                      final caller = totalCallers[index];
                      final isLiveCaller = index < filteredLiveCallers.length;
                      return _buildCallerItem(controller, caller, isLiveCaller);
                    },
                  ),
                ),
              const SizedBox(height: 20),
            ],
          );
        }),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildCallerItem(LivestreamController controller,
      Map<String, dynamic> caller, bool isLiveCaller) {
    final user = caller['user'] ?? caller['User'];
    final userName = user?['name'] ?? ('Unknown User').appTr;
    final userId = caller['caller_id'] ?? user?['id'] ?? 0;
    final callStatus = caller['call_status'] ?? 'unknown';

    // Properly convert to boolean, handling string values from API
    final audioOn = _convertToBool(caller['audio_on']) ?? true;
    final videoOn = _convertToBool(caller['video_on']) ?? true;

    final profileImage = user?['profile_image'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: profileImage != null && profileImage.isNotEmpty
                    ? NetworkImage(profileImage)
                    : null,
                child: profileImage == null || profileImage.isEmpty
                    ? Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : ('U').appTr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isLiveCaller ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ('ID: $userId • ${isLiveCaller ? 'Live' : 'Pending'}').appTr,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (callStatus != 'unknown')
                  Text(
                    ('Status: $callStatus').appTr,
                    style: TextStyle(
                      color: isLiveCaller ? Colors.green : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio toggle button
              IconButton(
                onPressed: () => _toggleAudio(controller, caller),
                icon: Icon(audioOn ? Icons.mic : Icons.mic_off),
                style: IconButton.styleFrom(
                  backgroundColor:
                      audioOn ? Colors.green[100] : Colors.red[100],
                  foregroundColor: audioOn ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              // Video toggle button
              streamType != 'audio'
                  ? IconButton(
                      onPressed: () => _toggleVideo(controller, caller),
                      icon: Icon(videoOn ? Icons.videocam : Icons.videocam_off),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            videoOn ? Colors.blue[100] : Colors.red[100],
                        foregroundColor: videoOn ? Colors.blue : Colors.red,
                      ),
                    )
                  : Container(),
              const SizedBox(width: 8),
              // Cancel call button
              IconButton(
                onPressed: () => _cancelUserCall(controller, caller),
                icon: const Icon(Icons.call_end),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Method for CALLER to cancel their own call
  /// Uses the current user's ID (userId) to cancel their own call request
  void _cancelCall(LivestreamController controller) {
    Get.dialog(
      AlertDialog(
        title:  Text(('Cancel Call').appTr),
        content:  Text(('Are you sure you want to cancel your call?').appTr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:  Text(('No').appTr),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.tryToRejectCall(
                streamId: streamId,
                userId: userId,
              );
              Get.snackbar(
                ('Call Cancelled').appTr,
                ('Your call has been cancelled successfully').appTr,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child:  Text(('Yes').appTr),
          ),
        ],
      ),
    );
  }

  /// Method for BROADCASTER to cancel other users' calls
  /// Uses the caller's ID from the caller data to reject their call
  void _cancelUserCall(
      LivestreamController controller, Map<String, dynamic> caller) {
    final user = caller['user'] ?? caller['User'];
    final userName = user?['name'] ?? 'Unknown User';
    final callerId = caller['caller_id'] ?? user?['id'] ?? 0;

    Get.dialog(
      AlertDialog(
        title:  Text(('Cancel User Call').appTr),
        content: Text(('Are you sure you want to cancel $userName\'s call?').appTr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:  Text(('No').appTr),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.tryToRejectCall(
                streamId: streamId,
                userId: callerId,
              );
              Get.snackbar(
                ('Call Cancelled').appTr,
                ('$userName\'s call has been cancelled').appTr,
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            },
            child:  Text(('Yes').appTr),
          ),
        ],
      ),
    );
  }

  void _toggleAudio(
      LivestreamController controller, Map<String, dynamic> caller) {
    final user = caller['user'] ?? caller['User'];
    final userName = user?['name'] ?? ('Unknown User').appTr;
    final currentAudioState = _convertToBool(caller['audio_on']) ?? true;

    // TODO: Implement actual audio toggle API call
    // For now, just show feedback
    Get.snackbar(
      ('Audio ${currentAudioState ? 'Muted' : 'Unmuted'}').appTr,
      ('Audio ${currentAudioState ? 'muted' : 'unmuted'} for $userName').appTr,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _toggleVideo(
      LivestreamController controller, Map<String, dynamic> caller) {
    final user = caller['user'] ?? caller['User'];
    final userName = user?['name'] ?? ('Unknown User').appTr;
    final currentVideoState = _convertToBool(caller['video_on']) ?? true;

    // TODO: Implement actual video toggle API call
    // For now, just show feedback
    Get.snackbar(
      ('Video ${currentVideoState ? 'Disabled' : 'Enabled'}').appTr,
      ('Video ${currentVideoState ? 'disabled' : 'enabled'} for $userName').appTr,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  /// Helper method to safely convert various types to boolean
  bool? _convertToBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true' || lowerValue == '1') return true;
      if (lowerValue == 'false' || lowerValue == '0') return false;
    }
    if (value is int) {
      return value != 0;
    }
    return null;
  }
}
