import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns livestream caller request/list/accept/reject REST orchestration.
/// WebsocketController remains the authoritative pending/accepted collection,
/// while LivestreamController retains narrow Agora and presence bridges.
class LiveCallController extends GetxController {
  LiveCallController(this.livestreamController);

  final LivestreamController livestreamController;

  final RxMap<String, dynamic> callersData = <String, dynamic>{}.obs;
  final RxBool seatJoinLoading = false.obs;
  final RxInt pendingSeatNo = 0.obs;
  final RxList<dynamic> callList = <dynamic>[].obs;

  final Map<String, Future<bool>> _acceptCallTransitions =
  <String, Future<bool>>{};
  final Map<String, Future<bool>> _rejectCallTransitions =
  <String, Future<bool>>{};
  final Set<int> _locallyDepartedCallers = <int>{};
  bool _callListFetchRunning = false;
  int _callListFetchStreamId = 0;
  int _callListFetchGeneration = 0;
  DateTime? _lastCallListFetchAt;

  bool isCallerLocallyDeparted(int userId) =>
      _locallyDepartedCallers.contains(userId);

  void clearDepartedCallerGuard(int userId) {
    if (userId > 0) _locallyDepartedCallers.remove(userId);
  }

  /// Clears compatibility state owned by the previous room. A target-room
  /// snapshot is authoritative and may repopulate these values afterwards.
  ///
  /// ✅ FIX (stale old seat reappears after fast leave+rejoin): this used to
  /// unconditionally clear _locallyDepartedCallers, including the CURRENT
  /// user's own just-set "I deliberately left my seat" guard (see
  /// _performRejectCall below). That guard exists specifically to protect
  /// against a server response that still reflects the old seat assignment
  /// for a brief window after leaving (server-side seat release lagging
  /// behind the client's own reject call) — applyFetchedCallList checks it
  /// to filter such a stale row out. Wiping it on every room-session reset,
  /// even a rejoin of the very room the guard was protecting, meant the
  /// very next warmLiveRoomStateFast() REST fetch on rejoin had nothing
  /// left to filter the stale row with, so it reappeared and blocked
  /// taking a new seat. Every other user's guard is still cleared exactly
  /// as before — only the current device's own logged-in user is preserved.
  void resetRoomSessionState() {
    callersData.clear();
    callList.clear();
    final int selfId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
            0;
    final bool selfWasDeparted =
        selfId > 0 && _locallyDepartedCallers.contains(selfId);
    _locallyDepartedCallers.clear();
    if (selfWasDeparted) _locallyDepartedCallers.add(selfId);
    _acceptCallTransitions.clear();
    _rejectCallTransitions.clear();
    _callListFetchRunning = false;
    _callListFetchStreamId = 0;
    _callListFetchGeneration++;
    _lastCallListFetchAt = null;
  }

  Future<void> tryToCallLivestream({
    required int streamId,
    int? seatNO,
    int? totalSeats,
    required int callerId,
    required String callType,
  }) async {
    if (seatJoinLoading.value) return;
    seatJoinLoading.value = true;
    pendingSeatNo.value = seatNO ?? 0;

    try {
      final targetSeatNo =
          await livestreamController.resolveCallJoinSeatNo(
            livestreamId: streamId,
            callerId: callerId,
            callType: callType,
            requestedSeatNo: seatNO,
            requestedTotalSeats: totalSeats,
          ) ??
              0;
      if (targetSeatNo <= 0) return;

      debugPrint('OUTGOING_CALL_REQUEST_START');
      final canJoinResult = await checkCanJoinLivestream(streamId, callerId);
      if (canJoinResult['can_join'] != true) {
        Fluttertoast.showToast(
          msg:
          (canJoinResult['message'] ??
              ('You can not join this seat right now').appTr)
              .toString(),
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      if (!livestreamController.acceptsRoomMutation(streamId)) {
        liveLog('Superseded call request stopped => stream=$streamId');
        return;
      }

      final response = await livestreamController.dio.post(
        callLiveStream,
        data: <String, dynamic>{
          'livestream_id': streamId,
          'caller_id': callerId,
          'call_type': callType,
          'seat_no': targetSeatNo,
        },
        options: Options(
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!livestreamController.acceptsRoomMutation(streamId)) {
          liveLog('Late call request response ignored => stream=$streamId');
          return;
        }
        callersData.value = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : <String, dynamic>{};
        debugPrint('OUTGOING_CALL_REQUEST_SUCCESS');
        livestreamController.applySuccessfulCallJoin(
          responseData: response.data,
          streamId: streamId,
          callerId: callerId,
          seatNo: targetSeatNo,
          callType: callType,
        );
      } else {
        debugPrint('OUTGOING_CALL_REQUEST_FAILED');
        Fluttertoast.showToast(
          msg: ('Seat join failed. Please try again.').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        if (response.statusCode == 409 || response.statusCode == 422) {
          await tryToGetCallList(streamId: streamId, force: true);
        }
      }
    } on DioException catch (e) {
      debugPrint('OUTGOING_CALL_REQUEST_FAILED');
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Seat join failed').toString()
          : (e.message ?? 'Seat join failed').toString();
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint('OUTGOING_CALL_REQUEST_FAILED');
      liveLog('Call request failed: $e');
      Fluttertoast.showToast(
        msg: ('Seat join failed. Please try again.').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      seatJoinLoading.value = false;
      pendingSeatNo.value = 0;
    }
  }

  Future<Map<String, dynamic>> checkCanJoinLivestream(
      int streamId,
      int userId,
      ) async {
    try {
      final response = await livestreamController.dio.get(
        kCheckCanJoinUrl(streamId, userId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
            'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> root = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{};
        final Map<String, dynamic> data = root['data'] is Map
            ? Map<String, dynamic>.from(root['data'] as Map)
            : <String, dynamic>{};
        final dynamic rawCanJoin =
            root['can_join'] ?? data['can_join'] ?? root['success'] ?? true;
        final bool canJoin =
            rawCanJoin == true ||
                rawCanJoin == 1 ||
                rawCanJoin.toString().toLowerCase() == 'true' ||
                rawCanJoin.toString() == '1';
        return <String, dynamic>{
          ...root,
          'can_join': canJoin,
          'message':
          root['message'] ??
              data['message'] ??
              (canJoin ? 'Can join livestream' : 'Cannot join livestream'),
          // Preserve the untouched bootstrap envelope for RTC token/channel
          // discovery without flattening or dropping backend fields.
          '_bootstrap_response': root,
        };
      }
      final Map<String, dynamic> root = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      return <String, dynamic>{
        ...root,
        'can_join': false,
        'message': root['message'] ?? 'Cannot join livestream',
        '_bootstrap_response': root,
      };
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          return <String, dynamic>{
            'can_join': false,
            'message':
            e.response?.data['message'] ??
                'You are temporarily banned from this livestream',
            'remaining_minutes': e.response?.data['remaining_minutes'] ?? 0,
          };
        }
        if (e.response?.statusCode == 500) {
          return <String, dynamic>{
            'can_join': true,
            'message': 'Server temporarily unavailable, proceeding with join',
          };
        }
        return <String, dynamic>{
          'can_join': true,
          'message': 'Unable to verify join status, proceeding with join',
        };
      }
      return <String, dynamic>{
        'can_join': true,
        'message': 'Unable to verify join status, proceeding with join',
      };
    }
  }

  Future<void> tryToGetCallList({
    required int streamId,
    bool force = false,
  }) async {
    if (streamId <= 0) return;
    if (_callListFetchRunning && _callListFetchStreamId == streamId) return;
    final now = DateTime.now();
    if (!force &&
        _lastCallListFetchAt != null &&
        now.difference(_lastCallListFetchAt!).inMilliseconds < 1200) {
      return;
    }

    final int requestGeneration = ++_callListFetchGeneration;
    _callListFetchRunning = true;
    _callListFetchStreamId = streamId;
    _lastCallListFetchAt = now;
    try {
      final response = await livestreamController.dio.get(
        getCallList(streamId),
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
        if (requestGeneration != _callListFetchGeneration) {
          liveLog('Superseded call list response ignored => stream=$streamId');
          return;
        }
        if (!livestreamController.acceptsRoomMutation(streamId)) {
          liveLog('Late call list ignored => stream=$streamId');
          return;
        }
        final raw = response.data;
        final list = raw is List
            ? raw
            : raw is Map && raw['data'] is List
            ? raw['data'] as List
            : raw is Map && raw['callers'] is List
            ? raw['callers'] as List
            : <dynamic>[];
        callList.assignAll(list);
        livestreamController.applyFetchedCallList(
          streamId: streamId,
          calls: list,
        );
      }
    } catch (e) {
      liveLog('Call list fetch failed safely: $e');
    } finally {
      if (requestGeneration == _callListFetchGeneration) {
        _callListFetchRunning = false;
        _callListFetchStreamId = 0;
      }
    }
  }

  Future<bool> tryToAcceptCall({
    required int streamId,
    required int userId,
  }) async {
    if (streamId <= 0 || userId <= 0) return false;
    final key = '$streamId:$userId';
    final existing = _acceptCallTransitions[key];
    if (existing != null) return existing;
    final transition = _performAcceptCall(streamId: streamId, userId: userId);
    _acceptCallTransitions[key] = transition;
    try {
      return await transition;
    } finally {
      _acceptCallTransitions.remove(key);
    }
  }

  Future<bool> _performAcceptCall({
    required int streamId,
    required int userId,
  }) async {
    Map<String, dynamic>? pendingCall;
    for (final raw in livestreamController.websocketController.pendingCall) {
      if (raw is! Map) continue;
      final candidate = Map<String, dynamic>.from(raw);
      if (livestreamController.callIdentity(candidate) == userId.toString()) {
        pendingCall = candidate;
        break;
      }
    }
    clearDepartedCallerGuard(userId);
    try {
      final response = await livestreamController.dio.get(
        acceptCall(streamId, userId),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
            'Bearer ${livestreamController.authController.userProfile.value.token}',
          },
        ),
      );
      final responseData = response.data;
      final explicitSuccess = responseData is Map
          ? responseData['success']
          : null;
      final accepted =
          (response.statusCode == 200 || response.statusCode == 201) &&
              explicitSuccess != false &&
              explicitSuccess?.toString().toLowerCase() != 'false';
      if (!accepted) {
        _showAcceptFailure(responseData);
        return false;
      }
      if (!livestreamController.acceptsRoomMutation(streamId)) {
        liveLog('Late call accept ignored => stream=$streamId user=$userId');
        return false;
      }
      await livestreamController.applyAcceptedCallResponse(
        streamId: streamId,
        userId: userId,
        pendingCall: pendingCall,
      );
      return true;
    } on DioException catch (e) {
      _showAcceptFailure(e.response?.data, error: e.message);
      return false;
    } catch (e) {
      _showAcceptFailure(null, error: e);
      return false;
    }
  }

  void _showAcceptFailure(dynamic responseData, {Object? error}) {
    dynamic backendMessage;
    if (responseData is Map) {
      backendMessage = responseData['message'] ?? responseData['error'];
      final nested = responseData['data'];
      if (backendMessage == null && nested is Map) {
        backendMessage = nested['message'] ?? nested['error'];
      }
    }
    var message = 'Unable to accept the call. Please try again.';
    for (final candidate in <dynamic>[backendMessage, error]) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        message = text;
        break;
      }
    }
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  Future<bool> tryToRejectCall({
    required int streamId,
    required int userId,
  }) async {
    if (streamId <= 0 || userId <= 0) return false;
    final key = '$streamId:$userId';
    final existing = _rejectCallTransitions[key];
    if (existing != null) return existing;
    final transition = _performRejectCall(streamId: streamId, userId: userId);
    _rejectCallTransitions[key] = transition;
    try {
      return await transition;
    } finally {
      _rejectCallTransitions.remove(key);
    }
  }

  Future<bool> _performRejectCall({
    required int streamId,
    required int userId,
  }) async {
    try {
      final response = await livestreamController.dio.get(
        rejectCall(streamId, userId),
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
        return false;
      }
      if (!livestreamController.acceptsRoomMutation(streamId)) {
        liveLog('Late call reject ignored => stream=$streamId user=$userId');
        return false;
      }
      _locallyDepartedCallers.add(userId);
      await livestreamController.applyRejectedCallResponse(
        streamId: streamId,
        userId: userId,
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        liveLog(
          'Reject call failed safely: ${e.response?.statusCode ?? e.message}',
        );
      }
      return false;
    } catch (e) {
      liveLog('Reject call failed safely: $e');
      return false;
    }
  }
}