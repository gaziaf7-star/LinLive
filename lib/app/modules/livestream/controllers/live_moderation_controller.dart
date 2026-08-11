import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns livestream user administration and guardian/room-admin state.
/// Realtime caller/viewer collections and Agora media execution remain in
/// their existing authoritative owners.
class LiveModerationController extends GetxController {
  LiveModerationController(this.livestreamController);

  final LivestreamController livestreamController;

  final RxBool isMyGuardian = false.obs;
  final RxList<dynamic> guardianListData = <dynamic>[].obs;
  final RxBool guardianLoading = false.obs;
  final RxMap<int, bool> roomGuardianMap = <int, bool>{}.obs;
  final RxBool guardianNoticeVisible = false.obs;
  final RxString guardianNoticeText = ''.obs;
  Timer? _guardianNoticeTimer;

  int get _myUserId =>
      livestreamController.authController.userProfile.value.user?.id?.toInt() ??
      0;

  Map<String, String> get _guardianHeaders => <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization':
        'Bearer ${livestreamController.authController.userProfile.value.token}',
  };

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  int _toInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  bool isRoomGuardianUser(dynamic rawUserId) {
    final id = _toInt(rawUserId);
    return id > 0 && roomGuardianMap[id] == true;
  }

  bool hasRoomGuardianStatus(dynamic rawUserId) {
    final id = _toInt(rawUserId);
    return id > 0 && roomGuardianMap.containsKey(id);
  }

  void showGuardianNotice(String userName, {bool assigned = true}) {
    final cleanName = userName.trim().isEmpty ? 'User' : userName.trim();
    guardianNoticeText.value = assigned
        ? '$cleanName has been set as room admin'
        : '$cleanName has been removed from room admin';
    guardianNoticeVisible.value = true;
    _guardianNoticeTimer?.cancel();
    _guardianNoticeTimer = Timer(const Duration(seconds: 5), () {
      guardianNoticeVisible.value = false;
    });
  }

  int _roomLiveId(Map<dynamic, dynamic> map) {
    final livestream = _asMap(map['livestream']);
    final livestreamData = _asMap(map['livestreamdata']);
    final data = _asMap(map['data']);
    for (final value in <dynamic>[
      map['livestream_id'],
      map['stream_id'],
      map['live_id'],
      map['id'],
      livestream['livestream_id'],
      livestream['stream_id'],
      livestream['id'],
      livestreamData['livestream_id'],
      livestreamData['stream_id'],
      livestreamData['id'],
      data['livestream_id'],
      data['stream_id'],
      data['live_id'],
      data['id'],
    ]) {
      final id = _toInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  int _roomOwnerId(Map<dynamic, dynamic> map) {
    final user = _asMap(map['user']);
    final host = _asMap(map['host']);
    final owner = _asMap(map['owner']);
    final livestream = _asMap(map['livestream']);
    final livestreamData = _asMap(map['livestreamdata']);
    final data = _asMap(map['data']);
    for (final value in <dynamic>[
      map['current_host_id'],
      map['owner_user_id'],
      map['host_id'],
      map['user_id'],
      livestream['current_host_id'],
      livestream['owner_user_id'],
      livestream['host_id'],
      livestream['user_id'],
      livestreamData['current_host_id'],
      livestreamData['owner_user_id'],
      livestreamData['host_id'],
      livestreamData['user_id'],
      data['current_host_id'],
      data['owner_user_id'],
      data['host_id'],
      data['user_id'],
      user['id'],
      user['user_id'],
      host['id'],
      host['user_id'],
      owner['id'],
      owner['user_id'],
    ]) {
      final id = _toInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  bool get isCurrentUserCurrentLiveOwner {
    final currentStreamId = livestreamController.streamId.value;
    if (_myUserId <= 0 || currentStreamId <= 0) return false;
    final create = _asMap(livestreamController.createStreamData);
    for (final source in <Map<String, dynamic>>[
      create,
      _asMap(create['livestreamdata']),
      _asMap(create['livestream']),
      _asMap(create['data']),
    ]) {
      if (source.isEmpty) continue;
      final sourceStreamId = _roomLiveId(source);
      if (sourceStreamId > 0 && sourceStreamId != currentStreamId) continue;
      final ownerId = _roomOwnerId(source);
      if (ownerId > 0) return ownerId == _myUserId;
    }
    return false;
  }

  bool get canModerateLive =>
      isCurrentUserCurrentLiveOwner ||
      isMyGuardian.value ||
      (_myUserId > 0 && roomGuardianMap[_myUserId] == true);

  bool ensureCanModerateCurrentLive(String actionName) {
    if (canModerateLive) return true;
    liveLog(
      'Live control blocked => action=$actionName '
      'stream=${livestreamController.streamId.value} user=$_myUserId',
    );
    Fluttertoast.showToast(
      msg: ('Only host or this room admin can do this').appTr,
    );
    return false;
  }

  Future<Map<String, dynamic>?> addToRoomBlacklist(
    int livestreamId,
    int userId, {
    String reason = 'room_blacklist',
  }) async {
    if (!ensureCanModerateCurrentLive('room_blacklist')) return null;
    try {
      final response = await livestreamController.dio.post(
        '$kMainUrl/livestream/$livestreamId/room-blacklist',
        data: <String, dynamic>{'user_id': userId, 'reason': reason},
        options: Options(headers: _guardianHeaders),
      );
      if (response.statusCode != 200) return null;
      if (!livestreamController.acceptsRoomMutation(livestreamId)) return null;
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : null;
    } catch (e) {
      liveLog('Error adding user to room blacklist: $e');
      return null;
    }
  }

  Future<bool> kickOutUser(int userId) async {
    if (!ensureCanModerateCurrentLive('kick_user')) return false;
    final sid = livestreamController.streamId.value;
    try {
      final response = await livestreamController.dio.post(
        kKickOutUrl(sid, userId),
        data: <String, dynamic>{'user_id': userId},
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (_) => true,
        ),
      );
      if (response.statusCode == 200) {
        return livestreamController.acceptsRoomMutation(sid);
      }
      if (response.statusCode == 403) {
        Get.snackbar(
          ('Permission Denied').appTr,
          ('Only livestream creator or admin can kick users').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else if (response.statusCode == 404) {
        Get.snackbar(
          ('Error').appTr,
          ('Livestream not found').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          ('Error').appTr,
          ('Failed to kick out user. Please try again.').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return false;
    } catch (e) {
      liveLog('Error kicking out user: $e');
      return false;
    }
  }

  int _guardianUserId(dynamic raw) {
    if (raw is! Map) return 0;
    final item = Map<String, dynamic>.from(raw);
    final user = _asMap(item['user']);
    final caller = _asMap(item['caller']);
    final callerUser = _asMap(caller['user']);
    for (final value in <dynamic>[
      user['id'],
      user['user_id'],
      callerUser['id'],
      callerUser['user_id'],
      caller['user_id'],
      caller['caller_id'],
      caller['id'],
      item['user_id'],
      item['caller_id'],
      item['target_user_id'],
      item['guardian_user_id'],
      item['admin_user_id'],
      item['member_id'],
      item['id'],
    ]) {
      final id = _toInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  Map<String, dynamic>? _callerFromResponse(dynamic data) {
    final root = _asMap(data);
    if (root['caller'] is Map) return _asMap(root['caller']);
    final nested = _asMap(root['data']);
    return nested['caller'] is Map ? _asMap(nested['caller']) : null;
  }

  void applyGuardianLocalStatus({
    required int userId,
    required bool isGuardian,
    Map<String, dynamic>? caller,
  }) {
    roomGuardianMap[userId] = isGuardian;
    roomGuardianMap.refresh();
    if (_myUserId == userId) {
      isMyGuardian.value = isGuardian;
      livestreamController.applyGuardianHomeState(isGuardian);
    }
    _updateGuardianInLiveCalls(userId, isGuardian, caller);
    _updateGuardianList(userId, isGuardian, caller);
    guardianListData.refresh();
    livestreamController.websocketController.liveCallList.refresh();
  }

  void _updateGuardianInLiveCalls(
    int userId,
    bool isGuardian,
    Map<String, dynamic>? caller,
  ) {
    final calls = livestreamController.websocketController.liveCallList;
    for (var i = 0; i < calls.length; i++) {
      if (calls[i] is! Map) continue;
      final old = Map<String, dynamic>.from(calls[i]);
      final id = _toInt(
        old['caller_id'] ?? old['user_id'] ?? old['user']?['id'],
      );
      if (id != userId) continue;
      final updated = <String, dynamic>{...old, ...?caller};
      final oldUser = _asMap(old['user']);
      final newUser = _asMap(caller?['user']);
      updated['user'] = <String, dynamic>{
        ...oldUser,
        ...newUser,
        'is_guardian': isGuardian ? 1 : 0,
        'is_admin': isGuardian ? 1 : 0,
        'room_admin': isGuardian ? 1 : 0,
      };
      updated['is_guardian'] = isGuardian ? 1 : 0;
      updated['is_admin'] = isGuardian ? 1 : 0;
      updated['room_admin'] = isGuardian ? 1 : 0;
      calls[i] = updated;
    }
  }

  void _updateGuardianList(
    int userId,
    bool isGuardian,
    Map<String, dynamic>? caller,
  ) {
    if (isGuardian) {
      if (!guardianListData.any((item) => _guardianUserId(item) == userId)) {
        final item = <String, dynamic>{'user_id': userId, 'is_guardian': 1};
        if (caller != null) item['caller'] = caller;
        guardianListData.add(item);
      }
    } else {
      guardianListData.removeWhere((item) => _guardianUserId(item) == userId);
    }
  }

  Future<bool> assignGuardian({
    required int streamId,
    required int userId,
    bool closeBottomSheet = true,
  }) => _setGuardian(
    streamId: streamId,
    userId: userId,
    assign: true,
    closeBottomSheet: closeBottomSheet,
  );

  Future<bool> removeGuardianUser({
    required int streamId,
    required int userId,
    bool closeBottomSheet = true,
  }) => _setGuardian(
    streamId: streamId,
    userId: userId,
    assign: false,
    closeBottomSheet: closeBottomSheet,
  );

  Future<bool> _setGuardian({
    required int streamId,
    required int userId,
    required bool assign,
    required bool closeBottomSheet,
  }) async {
    if (!isCurrentUserCurrentLiveOwner) {
      Fluttertoast.showToast(
        msg:
            (assign
                    ? 'Only host can set room admin'
                    : 'Only host can remove room admin')
                .appTr,
      );
      return false;
    }
    if (streamId <= 0 || userId <= 0 || guardianLoading.value) return false;
    guardianLoading.value = true;
    try {
      final url = assign
          ? kSetGuardian(streamId: streamId, userId: userId)
          : kRemoveGuardian(streamId: streamId, userId: userId);
      final response = assign
          ? await livestreamController.dio.post(
              url,
              options: Options(
                headers: _guardianHeaders,
                validateStatus: (_) => true,
              ),
            )
          : await livestreamController.dio.delete(
              url,
              options: Options(
                headers: _guardianHeaders,
                validateStatus: (_) => true,
              ),
            );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }
      if (!livestreamController.acceptsRoomMutation(streamId)) return false;
      applyGuardianLocalStatus(
        userId: userId,
        isGuardian: assign,
        caller: _callerFromResponse(response.data),
      );
      await refreshMyGuardianStatus(streamId: streamId, userId: userId);
      await fetchGuardianList(streamId: streamId);
      if (closeBottomSheet && Get.isBottomSheetOpen == true) Get.back();
      Fluttertoast.showToast(
        msg: (assign ? 'Guardian assigned' : 'Guardian removed').appTr,
      );
      return true;
    } catch (e) {
      liveLog('Guardian update failed: $e');
      return false;
    } finally {
      guardianLoading.value = false;
    }
  }

  List<dynamic> _guardianListFromResponse(dynamic data) {
    if (data is List) return List<dynamic>.from(data);
    final root = _asMap(data);
    for (final candidate in <dynamic>[
      root['guardians'],
      root['guardian_list'],
      root['guardianList'],
      root['room_admins'],
      root['roomAdmins'],
      root['admins'],
      root['data'],
      root['result'],
    ]) {
      if (candidate is List) return List<dynamic>.from(candidate);
      final nested = _asMap(candidate);
      for (final item in <dynamic>[
        nested['guardians'],
        nested['guardian_list'],
        nested['guardianList'],
        nested['room_admins'],
        nested['roomAdmins'],
        nested['admins'],
        nested['data'],
        nested['items'],
        nested['list'],
      ]) {
        if (item is List) return List<dynamic>.from(item);
      }
    }
    return <dynamic>[];
  }

  Future<void> fetchGuardianList({required int streamId}) async {
    if (streamId <= 0) return;
    try {
      final response = await livestreamController.dio.get(
        kGuardianList(streamId: streamId),
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (_) => true,
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) return;
      if (!livestreamController.acceptsRoomMutation(streamId)) return;
      guardianListData.assignAll(_guardianListFromResponse(response.data));
      _syncGuardianMapFromList();
      _syncMyGuardianFromList();
    } catch (e) {
      liveLog('Guardian list fetch failed: $e');
    }
  }

  Future<bool> refreshMyGuardianStatus({
    required int streamId,
    int? userId,
  }) async {
    final targetUserId = userId ?? _myUserId;
    if (streamId <= 0 || targetUserId <= 0) return false;
    try {
      final response = await livestreamController.dio.get(
        kisGuardian(streamId: streamId, userId: targetUserId),
        options: Options(
          headers: _guardianHeaders,
          validateStatus: (_) => true,
        ),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }
      if (!livestreamController.acceptsRoomMutation(streamId)) return false;
      final root = _asMap(response.data);
      final nested = _asMap(root['data']);
      final status = _truthy(
        root['is_guardian'] ??
            root['guardian'] ??
            root['value'] ??
            root['status'] ??
            nested['is_guardian'] ??
            nested['guardian'] ??
            nested['value'] ??
            response.data,
      );
      if (targetUserId == _myUserId) {
        applyGuardianLocalStatus(userId: targetUserId, isGuardian: status);
      }
      return status;
    } catch (e) {
      liveLog('Guardian status fetch failed: $e');
      return false;
    }
  }

  void _syncGuardianMapFromList() {
    final next = <int, bool>{};
    for (final item in guardianListData) {
      final id = _guardianUserId(item);
      if (id > 0) next[id] = true;
    }
    for (final raw in livestreamController.websocketController.liveCallList) {
      if (raw is! Map) continue;
      final id = _toInt(
        raw['caller_id'] ?? raw['user_id'] ?? raw['user']?['id'],
      );
      if (id > 0 && next[id] != true) next[id] = false;
    }
    roomGuardianMap.assignAll(next);
  }

  void _syncMyGuardianFromList() {
    if (_myUserId <= 0) return;
    final exists = guardianListData.any(
      (item) => _guardianUserId(item) == _myUserId,
    );
    isMyGuardian.value = exists;
    livestreamController.applyGuardianHomeState(exists);
  }

  Future<void> applyGuardianFromSocket(Map<String, dynamic> data) async {
    final payload = _asMap(data['moderation_data'] ?? data['data'] ?? data);
    final userId = _toInt(
      payload['user_id'] ??
          payload['caller_id'] ??
          payload['target_user_id'] ??
          payload['id'],
    );
    if (userId <= 0) return;
    final action =
        (payload['action'] ??
                payload['moderation_action'] ??
                payload['type'] ??
                '')
            .toString()
            .toLowerCase();
    final assigned = action.contains('remove') || action.contains('unassign')
        ? false
        : action.contains('make') ||
              action.contains('set') ||
              action.contains('assign')
        ? true
        : _truthy(
            payload['is_guardian'] ?? payload['guardian'] ?? payload['value'],
          );
    final caller = _asMap(
      payload['caller'] ?? payload['caller_data'] ?? payload['accepted_caller'],
    );
    applyGuardianLocalStatus(
      userId: userId,
      isGuardian: assigned,
      caller: caller.isEmpty ? null : caller,
    );
    final callerUser = _asMap(caller['user']);
    showGuardianNotice(
      (payload['name'] ?? payload['user_name'] ?? callerUser['name'] ?? 'User')
          .toString(),
      assigned: assigned,
    );
  }

  Future<void> syncGuardianStateForRoom({
    required int streamId,
    int? userId,
  }) async {
    if (streamId <= 0) return;
    await fetchGuardianList(streamId: streamId);
    final target = userId ?? _myUserId;
    if (target > 0) {
      await refreshMyGuardianStatus(streamId: streamId, userId: target);
    }
  }

  @override
  void onClose() {
    _guardianNoticeTimer?.cancel();
    super.onClose();
  }
}
