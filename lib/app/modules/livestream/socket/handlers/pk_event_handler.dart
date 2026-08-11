part of '../websocket_controller.dart';

extension PkEventHandler on WebsocketController {
  int _pkToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> _pkAsMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  void _handlePkRequestReceived(Map<String, dynamic> payload) {
    final data = _pkAsMap(payload['data']);
    final source = data.isNotEmpty ? {...payload, ...data} : payload;
    final pkId = _pkToInt(source['pk_id'] ?? source['id']);
    final receiverHostId = _pkToInt(
      source['to_host_id'] ?? source['receiver_host_id'],
    );
    final fromHostId = _pkToInt(
      source['from_host_id'] ?? source['sender_host_id'],
    );
    final fromLivestreamId = _pkToInt(
      source['from_livestream_id'] ?? source['sender_livestream_id'],
    );

    final currentUserId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (receiverHostId != 0 &&
        currentUserId != 0 &&
        receiverHostId != currentUserId) {
      return;
    }

    if (pkId <= 0) return;

    if (Get.isDialogOpen == true) {
      Get.back();
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.pinkAccent),
            SizedBox(width: 8),
            Text(('PK Request').appTr),
          ],
        ),
        content: Text(
          payload['message']?.toString() ??
              ('Host $fromHostId wants to start PK with you.\nLive ID: $fromLivestreamId')
                  .appTr,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (Get.isDialogOpen == true) Get.back();
              await livestreamController.respondPkRequest(
                pkId: pkId,
                receiverHostId: receiverHostId == 0
                    ? currentUserId
                    : receiverHostId,
                responseText: 'rejected',
              );
            },
            child: Text(('Reject').appTr, style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Get.isDialogOpen == true) Get.back();
              await livestreamController.respondPkRequest(
                pkId: pkId,
                receiverHostId: receiverHostId == 0
                    ? currentUserId
                    : receiverHostId,
                responseText: 'accepted',
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            child: Text(
              ('Accept').appTr,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showPkWaitingToast(Map<String, dynamic> payload) {
    Fluttertoast.showToast(
      msg:
          payload['message']?.toString() ??
          ('Waiting for host to accept PK request...').appTr,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }
}
