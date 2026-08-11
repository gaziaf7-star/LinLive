import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';
import '../socket/websocket_controller.dart';

/// Owns seat availability and seat-lock REST orchestration.
/// Occupants/callers and locked-seat realtime state remain in their existing
/// authoritative owners during this incremental phase.
class LiveSeatController extends GetxController {
  LiveSeatController(this.livestreamController);

  final LivestreamController livestreamController;
  final RxBool seatSwitchLoading = false.obs;

  int currentUserSeatNo({bool ignorePresence = false}) {
    final currentUserId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
        0;

    if (currentUserId == 0) return 0;

    if (!ignorePresence &&
        (livestreamController.currentPresenceRole.toLowerCase() == 'viewer' ||
            livestreamController.currentPresenceIsOnSeat == false)) {
      return 0;
    }

    for (final call in livestreamController.websocketController.liveCallList) {
      final map = call is Map ? Map<String, dynamic>.from(call) : {};
      if (map.isEmpty) continue;

      final callerId = map['caller_id'];
      final userId = map['user'] is Map ? map['user']['id'] : map['user_id'];
      final seatNo = int.tryParse(map['seat_no']?.toString() ?? '') ?? 0;

      final status = (map['call_status'] ?? '').toString().toLowerCase();
      final accepted =
          status.isEmpty ||
          status == 'accepted' ||
          status == 'active' ||
          status == 'joined';

      if (accepted &&
          seatNo > 0 &&
          (callerId.toString() == currentUserId.toString() ||
              userId.toString() == currentUserId.toString())) {
        return seatNo;
      }
    }

    return 0;
  }

  bool isSeatOccupied(int seatNo) {
    return livestreamController.websocketController.liveCallList.any((call) {
      final map = call is Map ? Map<String, dynamic>.from(call) : {};
      if (map.isEmpty) return false;

      final currentSeat = int.tryParse(map['seat_no']?.toString() ?? '') ?? 0;
      final status = (map['call_status'] ?? '').toString().toLowerCase();

      final accepted =
          status.isEmpty ||
          status == 'accepted' ||
          status == 'active' ||
          status == 'joined';

      return accepted && currentSeat == seatNo;
    });
  }

  Future<Map<String, dynamic>?> switchAudioSeat({
    required int livestreamId,
    required int toSeatNo,
    int? fromSeatNo,
  }) async {
    if (seatSwitchLoading.value) return null;

    final currentUserId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
        0;

    if (currentUserId == 0) {
      Fluttertoast.showToast(msg: ('User not found').appTr);
      return null;
    }

    final oldSeatNo = fromSeatNo ?? currentUserSeatNo();

    if (oldSeatNo > 0) {
      final seatsData = await getAvailableSeats(livestreamId);
      if (seatsData != null) {
        livestreamController.reconcileSelfSeatFromAvailableSeats(seatsData);
      }
    }

    final verifiedOldSeatNo = currentUserSeatNo();
    if (verifiedOldSeatNo == 0) {
      Fluttertoast.showToast(msg: ('Please join a seat first').appTr);
      return null;
    }

    final safeOldSeatNo = fromSeatNo ?? verifiedOldSeatNo;

    if (safeOldSeatNo == 0) {
      Fluttertoast.showToast(msg: ('Please join a seat first').appTr);
      return null;
    }

    if (safeOldSeatNo == toSeatNo) {
      Fluttertoast.showToast(msg: ('You are already on this seat').appTr);
      return null;
    }

    try {
      final ws = Get.find<WebsocketController>();

      /// Do not switch to locked seat.
      if (ws.isSeatLocked(toSeatNo)) {
        Fluttertoast.showToast(msg: ('This seat is locked').appTr);
        return null;
      }

      /// Do not switch to occupied seat.
      final occupiedByOther = livestreamController
          .websocketController
          .liveCallList
          .any((call) {
            final map = call is Map ? Map<String, dynamic>.from(call) : {};
            if (map.isEmpty) return false;

            final seatNo = int.tryParse(map['seat_no']?.toString() ?? '') ?? 0;
            final callerId = map['caller_id'];
            final userId = map['user'] is Map
                ? map['user']['id']
                : map['user_id'];

            final status = (map['call_status'] ?? '').toString().toLowerCase();
            final accepted =
                status.isEmpty ||
                status == 'accepted' ||
                status == 'active' ||
                status == 'joined';

            return accepted &&
                seatNo == toSeatNo &&
                callerId.toString() != currentUserId.toString() &&
                userId.toString() != currentUserId.toString();
          });

      if (occupiedByOther) {
        Fluttertoast.showToast(msg: ('Seat already occupied').appTr);
        return null;
      }

      seatSwitchLoading.value = true;

      final body = {
        'user_id': currentUserId,
        'from_seat_no': safeOldSeatNo,
        'to_seat_no': toSeatNo,
      };

      final url = '$kMainUrl/livestream/$livestreamId/seat/switch';

      liveLog('📤 SEAT SWITCH URL => $url');
      liveLog('📤 SEAT SWITCH BODY => $body');

      final response = await livestreamController.dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      liveLog('📥 SEAT SWITCH STATUS => ${response.statusCode}');
      liveLog('📥 SEAT SWITCH RESPONSE => ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!livestreamController.acceptsRoomMutation(livestreamId)) {
          liveLog('Late seat switch response ignored => stream=$livestreamId');
          return null;
        }
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};

        final callDataRaw = data['call_data'] ?? data['data'] ?? data['caller'];
        final callData = callDataRaw is Map
            ? <String, dynamic>{
                ...data,
                ...Map<String, dynamic>.from(callDataRaw),
              }
            : <String, dynamic>{
                ...data,
                'livestream_id': livestreamId,
                'caller_id': currentUserId,
                'user_id': currentUserId,
                'seat_no': toSeatNo,
                'my_seat_no': toSeatNo,
                'call_status': 'accepted',
              };

        /// Local instant update. Backend websocket `seat_switched` will sync again.
        /// Response root-e CP connection/base image thakle ekhanei sync korte hobe,
        /// tahole nijer device + sob viewer-er UI instantly stable thakbe.
        livestreamController.applySuccessfulSeatSwitch(
          currentUserId: currentUserId,
          fromSeatNo: safeOldSeatNo,
          toSeatNo: toSeatNo,
          callData: callData,
          responseData: data,
        );

        return data;
      }

      final message = response.data is Map && response.data['message'] != null
          ? response.data['message'].toString()
          : ('Seat switch failed').appTr;

      Fluttertoast.showToast(msg: message);
      return null;
    } catch (e) {
      liveLog('❌ switchAudioSeat error: $e');
      Fluttertoast.showToast(msg: ('Seat switch failed').appTr);
      return null;
    } finally {
      seatSwitchLoading.value = false;
    }
  }

  final Map<int, Map<String, dynamic>> _availableSeatsFastCache =
      <int, Map<String, dynamic>>{};
  final Map<int, DateTime> _availableSeatsFastCacheAt = <int, DateTime>{};
  final Map<int, Future<Map<String, dynamic>?>> _availableSeatsInFlight =
      <int, Future<Map<String, dynamic>?>>{};
  static const Duration _availableSeatsFastCacheTtl = Duration(
    milliseconds: 1800,
  );

  Future<Map<String, dynamic>?> getAvailableSeats(int livestreamId) async {
    if (livestreamId <= 0) return null;

    final now = DateTime.now();
    final cached = _availableSeatsFastCache[livestreamId];
    final cachedAt = _availableSeatsFastCacheAt[livestreamId];
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _availableSeatsFastCacheTtl) {
      if (livestreamController.acceptsRoomMutation(livestreamId)) {
        livestreamController.availableSeatsData.value = cached;
      }
      liveLog('⚡ Available seats cache hit => stream:$livestreamId');
      return cached;
    }

    final running = _availableSeatsInFlight[livestreamId];
    if (running != null) {
      liveLog(
        '♻️ Available seats API joined in-flight => stream:$livestreamId',
      );
      return running;
    }

    final future = _getAvailableSeatsFromNetwork(livestreamId);
    _availableSeatsInFlight[livestreamId] = future;

    try {
      final data = await future;
      if (data != null) {
        _availableSeatsFastCache[livestreamId] = Map<String, dynamic>.from(
          data,
        );
        _availableSeatsFastCacheAt[livestreamId] = DateTime.now();
      }
      return data;
    } finally {
      _availableSeatsInFlight.remove(livestreamId);
    }
  }

  Future<Map<String, dynamic>?> _getAvailableSeatsFromNetwork(
    int livestreamId,
  ) async {
    Future<Response> request(String url) {
      return livestreamController.dio.get(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );
    }

    try {
      /// New backend route.
      final primaryUrl = '$kMainUrl/livestream/$livestreamId/available-seats';

      /// Old route fallback, jodi server-e old endpoint thake.
      final fallbackUrl = '$kMainUrl/availableseats/$livestreamId';

      Response response;

      try {
        response = await request(primaryUrl);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          liveLog(
            'ℹ️ New available seats route not found, trying old route...',
          );
          response = await request(fallbackUrl);
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        if (!livestreamController.acceptsRoomMutation(livestreamId)) {
          liveLog('Late available seats ignored => stream=$livestreamId');
          return null;
        }
        livestreamController.availableSeatsData.value = response.data;
        liveLog("✅ Available seats fetched: ${response.data}");

        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        livestreamController.reconcileSelfSeatFromAvailableSeats(data);

        return data;
      } else {
        liveLog(
          "⚠️ Failed to fetch available seats: ${response.statusCode} - ${response.data}",
        );
        return null;
      }
    } catch (e) {
      liveLog("❌ Error fetching available seats: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleSeatLock({
    required int livestreamId,
    required int seatNo,
  }) async {
    if (livestreamController.seatLockLoading.value) return null;
    if (!livestreamController.canModerateSeatAction('toggle_seat_lock')) {
      return null;
    }

    try {
      livestreamController.seatLockLoading.value = true;

      final response = await livestreamController.dio.post(
        '$kMainUrl/livestream/$livestreamId/seat/$seatNo/lock-toggle',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        if (!livestreamController.acceptsRoomMutation(livestreamId)) {
          liveLog('Late seat lock response ignored => stream=$livestreamId');
          return null;
        }
        liveLog('✅ Seat lock toggle success: ${response.data}');

        /// Local instant update, websocket event ashlei abar sync hobe.
        final WebsocketController ws = Get.find();
        final data = response.data is Map ? response.data as Map : {};
        final lockedValue =
            data['is_locked'] ??
            data['locked'] ??
            data['seat']?['is_locked'] ??
            data['data']?['is_locked'];

        if (lockedValue != null) {
          ws.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked:
                lockedValue == true ||
                lockedValue == 1 ||
                lockedValue.toString() == '1' ||
                lockedValue.toString().toLowerCase() == 'yes' ||
                lockedValue.toString().toLowerCase() == 'locked' ||
                lockedValue.toString().toLowerCase() == 'true',
          );
        } else {
          /// If backend does not return new state, toggle local state.
          ws.updateSeatLockStatus(
            seatNo: seatNo,
            isLocked: !ws.isSeatLocked(seatNo),
          );
        }

        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
      } else {
        liveLog(
          '⚠️ Seat lock toggle failed: ${response.statusCode} ${response.data}',
        );
        Fluttertoast.showToast(msg: ('Seat lock failed').appTr);
        return null;
      }
    } catch (e) {
      liveLog('❌ Seat lock toggle error: $e');
      Fluttertoast.showToast(msg: ('Seat lock failed').appTr);
      return null;
    } finally {
      livestreamController.seatLockLoading.value = false;
    }
  }

  Future<Map<String, dynamic>?> lockSeat({
    required int livestreamId,
    required int seatNo,
  }) async {
    if (!livestreamController.canModerateSeatAction('lock_seat')) return null;
    try {
      final response = await livestreamController.dio.post(
        '$kMainUrl/livestream/$livestreamId/seat/$seatNo/lock',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        if (!livestreamController.acceptsRoomMutation(livestreamId)) {
          liveLog('Late seat lock response ignored => stream=$livestreamId');
          return null;
        }
        Get.find<WebsocketController>().updateSeatLockStatus(
          seatNo: seatNo,
          isLocked: true,
        );
        liveLog('✅ Seat locked: $seatNo');
        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      liveLog('❌ lockSeat error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> unlockSeat({
    required int livestreamId,
    required int seatNo,
  }) async {
    if (!livestreamController.canModerateSeatAction('unlock_seat')) return null;
    try {
      final response = await livestreamController.dio.post(
        '$kMainUrl/livestream/$livestreamId/seat/$seatNo/unlock',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        if (!livestreamController.acceptsRoomMutation(livestreamId)) {
          liveLog('Late seat unlock response ignored => stream=$livestreamId');
          return null;
        }
        Get.find<WebsocketController>().updateSeatLockStatus(
          seatNo: seatNo,
          isLocked: false,
        );
        liveLog('✅ Seat unlocked: $seatNo');
        return response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      liveLog('❌ unlockSeat error: $e');
    }
    return null;
  }
}
