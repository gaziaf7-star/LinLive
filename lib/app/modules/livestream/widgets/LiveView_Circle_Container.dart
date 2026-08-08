import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/auth/controllers/auth_controller.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/livestream_controller.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/websocket_controller.dart';
import 'package:meetlivepro/widgets/after/CastomText.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import 'audioText.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveViewCircleSeatReactive extends StatelessWidget {
  final int seatNo;
  final Map initialData;

  const LiveViewCircleSeatReactive({
    super.key,
    required this.seatNo,
    required this.initialData,
  });

  WebsocketController get _websocketController => Get.find<WebsocketController>();

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  bool _isAcceptedSeatCall(Map<String, dynamic> call) {
    final status = (call['call_status'] ?? call['status'] ?? 'accepted')
        .toString()
        .toLowerCase()
        .trim();
    return status.isEmpty ||
        status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'on_seat';
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    if (value is Map) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    final text = value.toString().trim().toLowerCase();
    return text.isNotEmpty && text != 'null' && text != '{}' && text != '[]';
  }

  /// The join-seat API can return the accepted seat inside a top-level
  /// `caller` object, while websocket/call-list payloads usually return the
  /// caller row directly. Normalize both shapes before comparing/merging.
  Map<String, dynamic> _normalizeSeatPayload(dynamic raw) {
    final root = _asMap(raw);
    if (root.isEmpty) return <String, dynamic>{};

    final caller = _asMap(root['caller']);
    final callerSeat = _safeInt(
      caller['seat_no'] ?? caller['seat'] ?? caller['seat_number'] ?? caller['seatNo'],
    );
    final rootSeat = _safeInt(
      root['seat_no'] ?? root['seat'] ?? root['seat_number'] ?? root['seatNo'],
    );

    if (caller.isNotEmpty && callerSeat > 0 && rootSeat <= 0) {
      final normalized = <String, dynamic>{...caller};

      // Keep useful room-level values without replacing caller/user data.
      for (final key in const <String>[
        'host_id',
        'room_lock',
        'is_room_locked',
        'room_locked',
        'lock_coment',
        'lock_comment',
        'hidden_room',
        'screenshort',
        'screenshot',
        'screen_records',
        'screen_record',
        'stream_coins',
        'gifts_coins',
      ]) {
        if (root.containsKey(key) && !normalized.containsKey(key)) {
          normalized[key] = root[key];
        }
      }
      return normalized;
    }

    return root;
  }

  Map<String, dynamic> _mergeNestedMap(
      dynamic oldValue,
      dynamic newValue,
      ) {
    final oldMap = _asMap(oldValue);
    final newMap = _asMap(newValue);
    if (oldMap.isEmpty) return newMap;
    if (newMap.isEmpty) return oldMap;

    final merged = <String, dynamic>{...oldMap, ...newMap};

    // A partial websocket payload often contains the user but omits frame
    // fields. Never let null/empty values erase the rich API snapshot.
    for (final key in const <String>[
      'name',
      'user_name',
      'profile_image',
      'avatar',
      'level',
      'asset_purchase_histories',
      'assetPurchaseHistories',
      'asset_purchase_history',
      'assetPurchaseHistory',
      'profile_frame_history',
      'profileFrameHistory',
      'profile_frame_data',
      'profileFrameData',
      'active_profile_frame',
      'activeProfileFrame',
      'selected_frame',
      'selectedFrame',
      'current_frame',
      'currentFrame',
      'active_frame',
      'activeFrame',
      'avatar_frame',
      'avatarFrame',
      'profile_frame',
      'profileFrame',
      'profile_frame_url',
      'profile_frame_image',
      'frame',
      'frame_data',
      'frameData',
      'frame_url',
      'frame_image',
    ]) {
      if (!_hasValue(merged[key]) && _hasValue(oldMap[key])) {
        merged[key] = oldMap[key];
      }
    }

    return merged;
  }

  Map<String, dynamic> _mergeSeatPayloads(
      Map<String, dynamic> oldSeat,
      Map<String, dynamic> newSeat,
      ) {
    if (oldSeat.isEmpty) return newSeat;
    if (newSeat.isEmpty) return oldSeat;

    final merged = <String, dynamic>{...oldSeat, ...newSeat};
    merged['user'] = _mergeNestedMap(oldSeat['user'], newSeat['user']);

    // Some payloads put a user-like object under `caller`; preserve it too.
    if (oldSeat['caller'] is Map || newSeat['caller'] is Map) {
      merged['caller'] = _mergeNestedMap(oldSeat['caller'], newSeat['caller']);
    }

    // Preserve root-level visual fields when the new event is partial.
    for (final key in const <String>[
      'asset_purchase_histories',
      'assetPurchaseHistories',
      'asset_purchase_history',
      'assetPurchaseHistory',
      'profile_frame_history',
      'profileFrameHistory',
      'profile_frame',
      'profileFrame',
      'profile_frame_url',
      'profile_frame_image',
      'frame',
      'frame_data',
      'frameData',
      'frame_url',
      'frame_image',
    ]) {
      if (!_hasValue(merged[key]) && _hasValue(oldSeat[key])) {
        merged[key] = oldSeat[key];
      }
    }

    return merged;
  }

  Map<String, dynamic> _currentSeatData() {
    /// Keep initialData only as the rich half of the merge. The live call list
    /// still decides whether the seat is currently occupied, so a user who
    /// leaves will not remain visible as stale data.
    final Map<String, dynamic> initial = _normalizeSeatPayload(initialData);

    for (final raw in _websocketController.liveCallList) {
      if (raw is! Map) continue;
      final item = _normalizeSeatPayload(raw);
      if (!_isAcceptedSeatCall(item)) continue;

      final int itemSeat = _safeInt(
        item['seat_no'] ?? item['seat'] ?? item['seat_number'] ?? item['seatNo'],
      );
      if (itemSeat == seatNo) {
        return _mergeSeatPayloads(initial, item);
      }
    }

    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      /// Listen only to seat-related states. This makes each seat rebuild alone
      /// instead of forcing the whole AudioLiveView page to rebuild.
      _websocketController.liveCallList.length;
      _websocketController.lockedSeatMap[seatNo];
      _websocketController.audioMutedUserMap.length;
      _websocketController.liveImogiAnimations.length;

      return RepaintBoundary(
        child: LiveViewCircle_container(
          key: ValueKey('audio_seat_$seatNo'),
          data: _currentSeatData(),
          seatNo: seatNo,
        ),
      );
    });
  }
}

class LiveViewCircle_container extends StatelessWidget {
  final int seatNo;
  final Map data;

  LiveViewCircle_container({
    super.key,
    required this.data,
    required this.seatNo,
  });

  final LivestreamController livestreamController = Get.find();
  final WebsocketController websocketController = Get.find();
  final AuthController authController = Get.find();

  /// Keeps the last rich user profile for each live-seat user.
  /// Guardian/admin websocket payload can be partial and may not include
  /// asset_purchase_history/frame, so we merge from this cache to avoid
  /// the profile frame disappearing after Set Admin/Remove Admin.
  static final Map<int, Map<String, dynamic>> _seatUserVisualCache =
  <int, Map<String, dynamic>>{};


  /// Lucky Gift particle target registry.
  /// GiftAnimationWidget uses this to move small gift images into the
  /// receiver user's seated profile/avatar.
  ///
  /// We store BuildContext instead of GlobalKey to avoid duplicate GlobalKey
  /// crashes when old/new AudioLiveView routes overlap during transitions.
  static final Map<int, BuildContext> _luckyReceiverProfileContexts =
  <int, BuildContext>{};

  static final Map<int, BuildContext> _luckyReceiverSeatContexts =
  <int, BuildContext>{};

  // Cached global avatar centers. Lucky animation can resolve 100 receivers
  // with one relative RenderBox lookup instead of 100 findRenderObject calls.
  static final Map<int, Offset> _luckyReceiverProfileGlobalCenters =
  <int, Offset>{};
  static final Map<int, Offset> _luckyReceiverSeatGlobalCenters =
  <int, Offset>{};

  /// userId -> seatNo fallback.
  /// Multi-receiver/self-gift events sometimes come without receiver_seat_no.
  /// This map lets GiftAnimationWidget resolve self/receiver by user id first,
  /// then by the last registered seat for that user.
  static final Map<int, int> _luckyReceiverUserSeatNo = <int, int>{};

  static void _registerLuckyProfileContext(
      int userId,
      BuildContext context, {
        int? seatNo,
      }) {
    if (userId <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _luckyReceiverProfileContexts[userId] = context;
      try {
        final RenderObject? raw = context.findRenderObject();
        if (raw is RenderBox && raw.attached && raw.hasSize) {
          final Offset center = raw.localToGlobal(raw.size.center(Offset.zero));
          _luckyReceiverProfileGlobalCenters[userId] = center;
          if (seatNo != null && seatNo > 0) {
            _luckyReceiverSeatGlobalCenters[seatNo] = center;
          }
        }
      } catch (_) {}
      if (seatNo != null && seatNo > 0) {
        _luckyReceiverUserSeatNo[userId] = seatNo;
        _luckyReceiverSeatContexts[seatNo] = context;
      }
    });
  }

  static void _registerLuckySeatContext(int seatNo, BuildContext context) {
    if (seatNo <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _luckyReceiverSeatContexts[seatNo] = context;
      try {
        final RenderObject? raw = context.findRenderObject();
        if (raw is RenderBox && raw.attached && raw.hasSize) {
          _luckyReceiverSeatGlobalCenters[seatNo] =
              raw.localToGlobal(raw.size.center(Offset.zero));
        }
      } catch (_) {}
    });
  }

  /// Public bridge for special host/owner profile widgets outside this
  /// LiveViewCircle_container file. Seat 1 host profile is rendered by
  /// AudioLiveView, so it must register its profile center here too.
  static void registerLuckyTargetContext({
    required int userId,
    required int seatNo,
    required BuildContext context,
  }) {
    if (userId > 0) {
      _registerLuckyProfileContext(userId, context, seatNo: seatNo);
    }
    if (seatNo > 0) {
      _registerLuckySeatContext(seatNo, context);
    }
  }

  static Offset? _centerForContext({
    required BuildContext? seatContext,
    required BuildContext relativeTo,
  }) {
    try {
      if (seatContext == null) return null;

      final RenderObject? rawSeat = seatContext.findRenderObject();
      final RenderObject? rawTarget = relativeTo.findRenderObject();
      if (rawSeat is! RenderBox || rawTarget is! RenderBox) return null;
      if (!rawSeat.attached || !rawTarget.attached ||
          !rawSeat.hasSize || !rawTarget.hasSize) {
        return null;
      }

      final Offset globalCenter =
      rawSeat.localToGlobal(rawSeat.size.center(Offset.zero));
      return rawTarget.globalToLocal(globalCenter);
    } catch (_) {
      return null;
    }
  }

  static List<Offset> luckyProfileCentersForTargets({
    required List<int> userIds,
    required List<int> seatNos,
    required BuildContext relativeTo,
  }) {
    final RenderObject? relativeRaw = relativeTo.findRenderObject();
    if (relativeRaw is! RenderBox ||
        !relativeRaw.attached ||
        !relativeRaw.hasSize) {
      return const <Offset>[];
    }

    final List<Offset> result = <Offset>[];
    final Set<String> seen = <String>{};

    void addGlobal(Offset? global) {
      if (global == null) return;
      final Offset local = relativeRaw.globalToLocal(global);
      final String key =
          '${local.dx.toStringAsFixed(1)}_${local.dy.toStringAsFixed(1)}';
      if (seen.add(key)) result.add(local);
    }

    for (final int userId in userIds) {
      if (userId <= 0) continue;
      addGlobal(_luckyReceiverProfileGlobalCenters[userId]);
      if (!_luckyReceiverProfileGlobalCenters.containsKey(userId)) {
        final int? seatNo = _luckyReceiverUserSeatNo[userId];
        if (seatNo != null) addGlobal(_luckyReceiverSeatGlobalCenters[seatNo]);
      }
    }

    for (final int seatNo in seatNos) {
      if (seatNo > 0) addGlobal(_luckyReceiverSeatGlobalCenters[seatNo]);
    }

    return result;
  }

  static Offset? luckyProfileCenterForUser({
    required int userId,
    required BuildContext relativeTo,
  }) {
    if (userId <= 0) return null;

    final Offset? direct = _centerForContext(
      seatContext: _luckyReceiverProfileContexts[userId],
      relativeTo: relativeTo,
    );
    if (direct != null) return direct;

    // Fallback: when websocket gives only receiver_id and no seat_no,
    // use the last registered seat for this user. This fixes self-gift
    // and multi-user gift where one receiver was being missed.
    final int? seatNo = _luckyReceiverUserSeatNo[userId];
    if (seatNo != null && seatNo > 0) {
      return _centerForContext(
        seatContext: _luckyReceiverSeatContexts[seatNo],
        relativeTo: relativeTo,
      );
    }

    return null;
  }

  static Offset? luckyProfileCenterForSeat({
    required int seatNo,
    required BuildContext relativeTo,
  }) {
    if (seatNo <= 0) return null;
    return _centerForContext(
      seatContext: _luckyReceiverSeatContexts[seatNo],
      relativeTo: relativeTo,
    );
  }

  bool get isLockedSeat => websocketController.isSeatLocked(seatNo) || _seatLockedFromData();

  String _truncateName(String name, int maxLength) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength)}..';
  }

  bool _truthyLocal(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    return v == '1' ||
        v == 'true' ||
        v == 'yes' ||
        v == 'y' ||
        v == 'locked' ||
        v == 'lock' ||
        v == 'mute' ||
        v == 'muted';
  }

  bool _falseyLocal(dynamic value) {
    final v = value?.toString().toLowerCase().trim() ?? '';
    return v == '0' ||
        v == 'false' ||
        v == 'no' ||
        v == 'n' ||
        v == 'off' ||
        v == 'unlocked' ||
        v == 'unlock' ||
        v == 'unmute' ||
        v == 'unmuted';
  }

  bool _seatLockedFromData() {
    final lockValue = data['is_locked'] ??
        data['locked'] ??
        data['seat_locked'] ??
        data['lock_status'];
    return _truthyLocal(lockValue);
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return 0;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? 0;
  }

  int _liveIdFromMap(Map map) {
    final nestedLive = map['livestream'];
    final nestedLiveData = map['livestreamdata'];
    final candidates = <dynamic>[
      map['livestream_id'],
      map['stream_id'],
      map['live_id'],
      map['id'],
      nestedLive is Map ? nestedLive['livestream_id'] : null,
      nestedLive is Map ? nestedLive['stream_id'] : null,
      nestedLive is Map ? nestedLive['id'] : null,
      nestedLiveData is Map ? nestedLiveData['livestream_id'] : null,
      nestedLiveData is Map ? nestedLiveData['stream_id'] : null,
      nestedLiveData is Map ? nestedLiveData['id'] : null,
    ];

    for (final value in candidates) {
      final id = _safeInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  int _currentRoomStreamId() {
    final controllerLive = _toMap(livestreamController.createStreamData['livestreamdata']);
    final controllerLive2 = _toMap(livestreamController.createStreamData['livestream']);
    final candidates = <dynamic>[
      data['livestream_id'],
      data['stream_id'],
      data['live_id'],
      data['livestream'] is Map ? data['livestream']['id'] : null,
      data['livestream'] is Map ? data['livestream']['livestream_id'] : null,
      data['livestreamdata'] is Map ? data['livestreamdata']['id'] : null,
      data['livestreamdata'] is Map ? data['livestreamdata']['livestream_id'] : null,
      livestreamController.streamId.value,
      websocketController.streamID.value,
      websocketController.activeAudioStreamId.value,
      controllerLive['id'],
      controllerLive['livestream_id'],
      controllerLive2['id'],
      controllerLive2['livestream_id'],
    ];

    for (final value in candidates) {
      final id = _safeInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  bool _rowBelongsToCurrentRoom(Map map) {
    final currentStreamId = _currentRoomStreamId();
    if (currentStreamId <= 0) return true;

    final rowStreamId = _liveIdFromMap(map);
    return rowStreamId <= 0 || rowStreamId == currentStreamId;
  }

  String _safeLowerLocal(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'null' ? '' : text;
  }

  bool _hasMeaningfulValueLocal(dynamic value) {
    if (value == null) return false;
    if (value is Map) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    final text = value.toString().trim().toLowerCase();
    return text.isNotEmpty && text != 'null' && text != '{}' && text != '[]';
  }

  Map<String, dynamic> _frameMap(dynamic value) {
    if (value == null) return <String, dynamic>{};

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text.toLowerCase() == 'null') {
        return <String, dynamic>{};
      }
      return <String, dynamic>{
        'asset': text,
        'asset_type': 'profile_frame',
      };
    }

    if (value is List) {
      Map<String, dynamic> firstUsable = <String, dynamic>{};
      for (final item in value) {
        final itemMap = _frameMap(item);
        if (itemMap.isEmpty || !_frameMapHasUsableAsset(itemMap)) continue;
        firstUsable = itemMap;
        final status = _safeLowerLocal(
          itemMap['status'] ??
              itemMap['purchase_status'] ??
              itemMap['is_active'],
        );
        if (_truthyLocal(itemMap['is_active']) ||
            status == 'active' ||
            status == 'using' ||
            status == 'selected') {
          return itemMap;
        }
      }
      return firstUsable;
    }

    final map = _toMap(value);
    if (map.isEmpty) return <String, dynamic>{};

    // If this map already contains a usable asset, return it before walking
    // nested aliases. This directly supports the API shape:
    // asset_purchase_histories -> asset -> asset.
    if (_frameMapHasUsableAsset(map)) return map;

    for (final key in const <String>[
      'asset_purchase_histories',
      'assetPurchaseHistories',
      'asset_purchase_history',
      'assetPurchaseHistory',
      'profile_frame_history',
      'profileFrameHistory',
      'profile_frame_data',
      'profileFrameData',
      'active_profile_frame',
      'activeProfileFrame',
      'selected_frame',
      'selectedFrame',
      'current_frame',
      'currentFrame',
      'active_frame',
      'activeFrame',
      'avatar_frame',
      'avatarFrame',
      'profile_frame',
      'profileFrame',
      'frame',
      'frame_data',
      'frameData',
    ]) {
      final nestedValue = map[key];
      if (nestedValue == null) continue;
      final nested = _frameMap(nestedValue);
      if (nested.isNotEmpty && _frameMapHasUsableAsset(nested)) {
        return nested;
      }
    }

    return map;
  }

  String _assetPathFromMap(Map<String, dynamic> frameData) {
    if (frameData.isEmpty) return '';

    final asset = _toMap(frameData['asset']);
    final upperAsset = _toMap(frameData['Asset']);
    final package = _toMap(frameData['package']);
    final vip = _toMap(package['vip_vvip']);

    return (asset['asset'] ??
        asset['asset_path'] ??
        asset['image'] ??
        asset['image_url'] ??
        asset['frame_image'] ??
        asset['frame_url'] ??
        asset['profile_frame_image'] ??
        asset['profile_frame_url'] ??
        asset['avatar_frame_image'] ??
        asset['avatar_frame_url'] ??
        asset['file'] ??
        asset['file_url'] ??
        asset['url'] ??
        asset['full_url'] ??
        asset['path'] ??
        upperAsset['asset'] ??
        upperAsset['asset_path'] ??
        upperAsset['image'] ??
        upperAsset['url'] ??
        upperAsset['path'] ??
        vip['frame'] ??
        frameData['asset_path'] ??
        (frameData['asset'] is String ? frameData['asset'] : null) ??
        frameData['image'] ??
        frameData['image_url'] ??
        frameData['frame_image'] ??
        frameData['frame_url'] ??
        frameData['profile_frame_image'] ??
        frameData['profile_frame_url'] ??
        frameData['avatar_frame_image'] ??
        frameData['avatar_frame_url'] ??
        frameData['file'] ??
        frameData['file_url'] ??
        frameData['url'] ??
        frameData['full_url'] ??
        frameData['path'] ??
        frameData['svga'])
        ?.toString()
        .trim() ??
        '';
  }

  bool _frameMapHasUsableAsset(Map<String, dynamic> frameData) {
    final assetPath = _assetPathFromMap(frameData);
    return assetPath.isNotEmpty && assetPath.toLowerCase() != 'null';
  }

  bool _isProfileFrameAsset(dynamic history) {
    final frameData = _frameMap(history);
    if (!_frameMapHasUsableAsset(frameData)) return false;

    final asset = _toMap(frameData['asset']);
    final upperAsset = _toMap(frameData['Asset']);
    final assetType = _safeLowerLocal(
      asset['type'] ?? upperAsset['type'] ?? frameData['asset_type'],
    );
    final historyType = _safeLowerLocal(
      frameData['type'] ?? frameData['history_type'],
    );
    final assetName = _safeLowerLocal(
      asset['name'] ?? upperAsset['name'] ?? frameData['name'],
    );

    if (assetType == 'entry care' ||
        historyType == 'entry care' ||
        assetType.contains('entry') ||
        historyType.contains('entry') ||
        assetName.contains('entry')) {
      return false;
    }

    return true;
  }

  String _profileFrameAssetPath(dynamic history) {
    return _assetPathFromMap(_frameMap(history));
  }

  bool _isSvgaAssetPath(String path) {
    final cleanPath = path.split('?').first.split('#').first.toLowerCase();
    return cleanPath.endsWith('.svga');
  }

  dynamic _readNested(dynamic source, List<String> path) {
    dynamic current = source;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  int _seatUserId(Map seatData) {
    final directUser = seatData['user'] is Map ? seatData['user'] as Map : null;
    final nestedUser = seatData['caller'] is Map ? seatData['caller'] as Map : null;

    return _safeInt(directUser?['id'] ??
        directUser?['user_id'] ??
        nestedUser?['id'] ??
        nestedUser?['user_id'] ??
        seatData['user_id'] ??
        seatData['caller_id'] ??
        seatData['viewer_id'] ??
        seatData['id']);
  }

  bool _isAudioMuted(Map seatData) {
    final int userId = _seatUserId(seatData);
    if (userId > 0) {
      final dynamic direct = websocketController.audioMutedUserMap[userId] ??
          websocketController.audioMutedUserMap[int.parse(userId.toString())];

      if (direct != null) {
        return direct == true || _truthyLocal(direct);
      }
    }

    /// Some events save mute status inside caller/user/root payload.
    final audioOn = seatData['audio_on'] ??
        seatData['is_audio_on'] ??
        seatData['mic_on'] ??
        seatData['microphone_on'] ??
        _readNested(seatData, ['caller', 'audio_on']) ??
        _readNested(seatData, ['caller', 'is_audio_on']) ??
        _readNested(seatData, ['user', 'audio_on']) ??
        _readNested(seatData, ['user', 'is_audio_on']);

    final muted = seatData['is_muted'] ??
        seatData['muted'] ??
        seatData['is_mute'] ??
        seatData['mute'] ??
        seatData['is_muted_by_host'] ??
        seatData['mute_status'] ??
        _readNested(seatData, ['caller', 'is_muted']) ??
        _readNested(seatData, ['caller', 'muted']) ??
        _readNested(seatData, ['caller', 'is_mute']) ??
        _readNested(seatData, ['user', 'is_muted']) ??
        _readNested(seatData, ['user', 'muted']) ??
        _readNested(seatData, ['user', 'is_mute']);

    if (_falseyLocal(audioOn)) return true;
    if (_truthyLocal(muted)) return true;

    return false;
  }

  bool _isUserSpeaking(Map seatData) {
    final int userId = _seatUserId(seatData);

    /// If controller has a speaking map, use it safely without requiring a
    /// hard dependency on a specific variable name at compile time.
    try {
      final dynamic ws = websocketController;
      final dynamic speakingMap = ws.speakingUserMap ?? ws.liveSpeakingUserMap;
      if (userId > 0 && speakingMap != null) {
        final dynamic direct = speakingMap[userId] ?? speakingMap[userId.toString()];
        if (direct != null) return direct == true || _truthyLocal(direct);
      }
    } catch (_) {}

    return _truthyLocal(seatData['is_speaking'] ??
        seatData['speaking'] ??
        seatData['is_talking'] ??
        _readNested(seatData, ['caller', 'is_speaking']) ??
        _readNested(seatData, ['user', 'is_speaking']));
  }

  bool _hasRealUserInfo(Map<String, dynamic> user) {
    final name = (user['name'] ?? user['user_name'] ?? '').toString().trim();
    final image = (user['profile_image'] ?? user['avatar'] ?? '').toString().trim();
    final frame = _seatProfileFrameData(user);
    return name.isNotEmpty || image.isNotEmpty || _isProfileFrameAsset(frame);
  }

  bool _hasVisualFrame(Map<String, dynamic> user) {
    return _isProfileFrameAsset(_seatProfileFrameData(user));
  }

  bool _isRoomAdminUser(Map seatData, Map<String, dynamic> user) {
    final int uid = _seatUserId(seatData);

    /// Global guardian map wins over cached/partial seat payload.
    /// If host removes admin, this map stores false so the Room Admin badge
    /// hides for everyone immediately, even after seat switch.
    if (uid > 0) {
      try {
        if (livestreamController.hasRoomGuardianStatus(uid)) {
          return livestreamController.isRoomGuardianUser(uid);
        }
      } catch (_) {}
    }

    // Only trust room/caller row flags. Never trust nested user/app-level
    // admin flags because those can be global and can leak to another live room.
    if (_rowBelongsToCurrentRoom(seatData) &&
        (_truthyLocal(seatData['is_guardian']) ||
            _truthyLocal(seatData['is_admin']) ||
            _truthyLocal(seatData['room_admin']))) {
      return true;
    }

    final caller = seatData['caller'];
    if (caller is Map &&
        _rowBelongsToCurrentRoom(caller) &&
        (_truthyLocal(caller['is_guardian']) ||
            _truthyLocal(caller['is_admin']) ||
            _truthyLocal(caller['room_admin']))) {
      return true;
    }

    if (uid > 0) {
      try {
        for (final raw in websocketController.liveCallList) {
          if (raw is! Map) continue;
          final map = Map<String, dynamic>.from(raw);
          final mapUser = map['user'] is Map
              ? Map<String, dynamic>.from(map['user'])
              : <String, dynamic>{};
          final int itemId = _safeInt(map['caller_id'] ??
              map['user_id'] ??
              mapUser['id'] ??
              mapUser['user_id']);
          if (itemId == uid &&
              _rowBelongsToCurrentRoom(map) &&
              (_truthyLocal(map['is_guardian']) ||
                  _truthyLocal(map['is_admin']) ||
                  _truthyLocal(map['room_admin']))) {
            return true;
          }
        }
      } catch (_) {}
    }

    return false;
  }

  int _roomHostUserId() {
    final int currentStreamId = _currentRoomStreamId();
    final candidates = <dynamic>[
      data['owner_user_id'],
      data['current_host_id'],
      data['host_id'],
      data['stream_user_id'],
      data['livestream'] is Map ? data['livestream']['owner_user_id'] : null,
      data['livestream'] is Map ? data['livestream']['current_host_id'] : null,
      data['livestream'] is Map ? data['livestream']['host_id'] : null,
      data['livestream'] is Map ? data['livestream']['user_id'] : null,
      data['livestreamdata'] is Map ? data['livestreamdata']['owner_user_id'] : null,
      data['livestreamdata'] is Map ? data['livestreamdata']['current_host_id'] : null,
      data['livestreamdata'] is Map ? data['livestreamdata']['host_id'] : null,
      data['livestreamdata'] is Map ? data['livestreamdata']['user_id'] : null,
    ];

    try {
      final created = Map<String, dynamic>.from(livestreamController.createStreamData);
      final createdLive = _toMap(created['livestreamdata']);
      final createdLive2 = _toMap(created['livestream']);
      final int createdStreamId = _liveIdFromMap(created);

      // createStreamData is a controller-level cache. Use it only when it
      // belongs to the current room; otherwise old own-live host id leaks.
      if (currentStreamId <= 0 || createdStreamId <= 0 || createdStreamId == currentStreamId) {
        candidates.add(createdLive['current_host_id']);
        candidates.add(createdLive['owner_user_id']);
        candidates.add(createdLive['host_id']);
        candidates.add(createdLive['user_id']);
        candidates.add(createdLive2['current_host_id']);
        candidates.add(createdLive2['owner_user_id']);
        candidates.add(createdLive2['host_id']);
        candidates.add(createdLive2['user_id']);
      }
    } catch (_) {}

    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        if (!_rowBelongsToCurrentRoom(map)) continue;

        // Only current-room broadcaster flags can identify host. Avoid `host` or
        // app-level `is_host` flags because those can belong to another room.
        if (_truthyLocal(map['is_broadcaster']) ||
            _truthyLocal(map['current_room_host'])) {
          final user = map['user'] is Map ? Map<String, dynamic>.from(map['user']) : <String, dynamic>{};
          candidates.add(map['caller_id'] ?? map['user_id'] ?? user['id'] ?? user['user_id']);
        }
      }
    } catch (_) {}

    for (final value in candidates) {
      final id = _safeInt(value);
      if (id > 0) return id;
    }
    return 0;
  }

  bool _isHostSeatUser(Map seatData, Map<String, dynamic> user) {
    /// IMPORTANT:
    /// "Host" badge must mean current live room owner/broadcaster only.
    /// A user can have app-level host/user_type=host from another room, but if
    /// the current live owner sets him as room admin, his badge must show Admin,
    /// not Host. So we do NOT trust user-level host flags here.
    final int uid = _seatUserId(seatData);
    if (uid <= 0) return false;

    final int hostId = _roomHostUserId();
    if (hostId > 0) return hostId == uid;

    /// Fallback only when host id is missing: use broadcaster flag from the
    /// current seat/caller row, never from nested user profile data.
    final caller = seatData['caller'];
    final bool seatBroadcaster = _rowBelongsToCurrentRoom(seatData) &&
        (_truthyLocal(seatData['is_broadcaster']) ||
            _truthyLocal(seatData['current_room_host']) ||
            (caller is Map &&
                _rowBelongsToCurrentRoom(caller) &&
                (_truthyLocal(caller['is_broadcaster']) ||
                    _truthyLocal(caller['current_room_host']))));

    return seatBroadcaster;
  }



  Widget _roomAdminIcon() {
    return Container(
      height: kHeight * 0.017,
      width: kHeight * 0.017,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffFACC15), Color(0xffFB7185)],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(.80),
          width: .7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.20),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.admin_panel_settings_rounded,
        color: Colors.white,
        size: kHeight * 0.0105,
      ),
    );
  }

  Map<String, dynamic> _mergeUserInfo(
      Map<String, dynamic> oldUser,
      Map<String, dynamic> newUser,
      ) {
    final merged = <String, dynamic>{...oldUser, ...newUser};

    // Preserve rich visual fields when the latest snapshot is partial.
    for (final key in [
      'name',
      'user_name',
      'profile_image',
      'avatar',
      'level',
      'asset_purchase_histories',
      'assetPurchaseHistories',
      'asset_purchase_history',
      'assetPurchaseHistory',
      'asset_purchase_history2',
      'profile_frame_history',
      'profileFrameHistory',
      'profile_frame_data',
      'profileFrameData',
      'active_profile_frame',
      'activeProfileFrame',
      'selected_frame',
      'selectedFrame',
      'current_frame',
      'currentFrame',
      'frame',
      'frame_data',
      'frameData',
      'avatar_frame',
      'avatarFrame',
      'avatar_frame_history',
      'avatarFrameHistory',
      'profile_frame',
      'profileFrame',
      'profile_frame_url',
      'profile_frame_image',
      'frame_url',
      'frame_image',
      'active_frame',
      'activeFrame',
    ]) {
      final current = merged[key];
      final oldValue = oldUser[key];
      if (!_hasMeaningfulValueLocal(current) &&
          _hasMeaningfulValueLocal(oldValue)) {
        merged[key] = oldValue;
      }
    }

    return merged;
  }

  Map<String, dynamic> _findHydratedUserFromLiveState(dynamic fallbackId) {
    final idText = fallbackId?.toString() ?? '';
    if (idText.isEmpty || idText == 'null') return <String, dynamic>{};

    try {
      final dynamic ws = websocketController;
      final lists = [
        ws.liveCallList,
        ws.pendingCall,
      ];

      for (final list in lists) {
        if (list is Iterable) {
          for (final item in list) {
            if (item is! Map) continue;
            final itemRoot = Map<String, dynamic>.from(item);
            final itemUserBase = item['user'] is Map
                ? Map<String, dynamic>.from(item['user'])
                : item['caller'] is Map
                ? Map<String, dynamic>.from(item['caller'])
                : <String, dynamic>{};
            final itemUser = _mergeRootVisualIntoUser(itemRoot, itemUserBase);

            final itemIds = [
              item['caller_id'],
              item['user_id'],
              item['viewer_id'],
              item['id'],
              itemUser['id'],
              itemUser['user_id'],
            ];

            final matched = itemIds.any((v) => v?.toString() == idText);
            if (matched && itemUser.isNotEmpty && _hasRealUserInfo(itemUser)) {
              // Prefer the copy that still has frame/asset data. Partial
              // guardian payload may have only name/profile_image.
              if (_hasVisualFrame(itemUser)) return itemUser;
              final cachedId = _safeInt(itemUser['id'] ?? itemUser['user_id'] ?? idText);
              final cached = _seatUserVisualCache[cachedId];
              if (cached != null && _hasVisualFrame(cached)) {
                return _mergeUserInfo(cached, itemUser);
              }
              return itemUser;
            }
          }
        }
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Map<String, dynamic> _findHydratedUserFromHomeList(dynamic fallbackId) {
    final idText = fallbackId?.toString() ?? '';
    if (idText.isEmpty || idText == 'null') return <String, dynamic>{};

    try {
      final dynamic users = homeController.allUserData;
      if (users is Iterable) {
        for (final raw in users) {
          if (raw is! Map) continue;
          final user = Map<String, dynamic>.from(raw);
          final ids = [user['id'], user['user_id'], user['unique_id']];
          if (ids.any((v) => v?.toString() == idText) && _hasRealUserInfo(user)) {
            return user;
          }
        }
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  void _cacheSeatUserVisual(Map<String, dynamic> user) {
    final int id = _safeInt(user['id'] ?? user['user_id']);
    if (id <= 0) return;

    final existing = _seatUserVisualCache[id] ?? <String, dynamic>{};
    final merged = _mergeUserInfo(existing, user);

    // Do not overwrite a cached frame with a partial null frame.
    if (!_hasVisualFrame(merged) && _hasVisualFrame(existing)) {
      _seatUserVisualCache[id] = existing;
      return;
    }

    _seatUserVisualCache[id] = merged;
  }

  Map<String, dynamic> _mergeRootVisualIntoUser(
      Map<String, dynamic> root,
      Map<String, dynamic> user,
      ) {
    if (root.isEmpty) return user;

    final merged = Map<String, dynamic>.from(user);
    for (final key in const [
      'asset_purchase_histories',
      'assetPurchaseHistories',
      'asset_purchase_history',
      'assetPurchaseHistory',
      'asset_purchase_history2',
      'profile_frame_history',
      'profileFrameHistory',
      'profile_frame_data',
      'profileFrameData',
      'active_profile_frame',
      'activeProfileFrame',
      'selected_frame',
      'selectedFrame',
      'current_frame',
      'currentFrame',
      'active_frame',
      'activeFrame',
      'avatar_frame',
      'avatarFrame',
      'avatar_frame_history',
      'avatarFrameHistory',
      'profile_frame',
      'profileFrame',
      'profile_frame_url',
      'profile_frame_image',
      'frame',
      'frame_data',
      'frameData',
      'frame_url',
      'frame_image',
    ]) {
      final value = root[key];
      if (!_hasMeaningfulValueLocal(value)) continue;

      final current = merged[key];
      if (!_hasMeaningfulValueLocal(current)) {
        merged[key] = value;
      }
    }

    return merged;
  }


  Map<String, dynamic> _currentAuthUserVisualMap(int lookupInt) {
    final dynamic authUser = authController.userProfile.value.user;
    final int authId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (authUser == null || authId <= 0 || lookupInt != authId) {
      return <String, dynamic>{};
    }

    final map = <String, dynamic>{
      'id': authId,
      'user_id': authId,
    };

    try {
      final dynamic json = (authUser as dynamic).toJson();
      if (json is Map) {
        map.addAll(Map<String, dynamic>.from(json));
      }
    } catch (_) {}

    void put(String key, dynamic value) {
      if (value != null && value.toString().trim().isNotEmpty && value.toString() != 'null') {
        map[key] = value;
      }
    }

    try { put('name', (authUser as dynamic).name); } catch (_) {}
    try { put('profile_image', (authUser as dynamic).profileImage); } catch (_) {}
    try { put('avatar', (authUser as dynamic).avatar); } catch (_) {}
    try { put('level', (authUser as dynamic).level); } catch (_) {}
    try { put('asset_purchase_histories', (authUser as dynamic).assetPurchaseHistories); } catch (_) {}
    try { put('asset_purchase_history', (authUser as dynamic).assetPurchaseHistory); } catch (_) {}
    try { put('profile_frame_history', (authUser as dynamic).profileFrameHistory); } catch (_) {}
    try { put('profileFrame', (authUser as dynamic).profileFrame); } catch (_) {}
    try { put('profile_frame', (authUser as dynamic).profile_frame); } catch (_) {}
    try { put('active_frame', (authUser as dynamic).activeFrame); } catch (_) {}
    try { put('avatar_frame', (authUser as dynamic).avatarFrame); } catch (_) {}
    try { put('active_profile_frame', (authUser as dynamic).activeProfileFrame); } catch (_) {}
    try { put('selected_frame', (authUser as dynamic).selectedFrame); } catch (_) {}
    try { put('current_frame', (authUser as dynamic).currentFrame); } catch (_) {}
    try { put('frame', (authUser as dynamic).frame); } catch (_) {}
    try { put('frame_url', (authUser as dynamic).frameUrl); } catch (_) {}
    try { put('profile_frame_url', (authUser as dynamic).profileFrameUrl); } catch (_) {}

    return map;
  }

  dynamic _seatProfileFrameData(Map<String, dynamic> user) {
    final candidates = <dynamic>[
      user['profile_frame_history'],
      user['asset_purchase_history'],
      user['asset_purchase_histories'],
      user['asset_purchase_history2'],
      user['profile_frame_data'],
      user['profileFrameData'],
      user['active_profile_frame'],
      user['activeProfileFrame'],
      user['active_frame'],
      user['activeFrame'],
      user['selected_frame'],
      user['selectedFrame'],
      user['current_frame'],
      user['currentFrame'],
      user['avatar_frame'],
      user['avatarFrame'],
      user['avatar_frame_history'],
      user['avatarFrameHistory'],
      user['profile_frame'],
      user['profileFrame'],
      user['profile_frame_url'],
      user['profile_frame_image'],
      user['frame'],
      user['frame_data'],
      user['frameData'],
      user['frame_url'],
      user['frame_image'],
      data['profile_frame_history'],
      data['asset_purchase_history'],
      data['asset_purchase_histories'],
      data['asset_purchase_history2'],
      data['profile_frame_data'],
      data['profileFrameData'],
      data['active_profile_frame'],
      data['activeProfileFrame'],
      data['active_frame'],
      data['activeFrame'],
      data['selected_frame'],
      data['selectedFrame'],
      data['current_frame'],
      data['currentFrame'],
      data['avatar_frame'],
      data['avatarFrame'],
      data['avatar_frame_history'],
      data['avatarFrameHistory'],
      data['profile_frame'],
      data['profileFrame'],
      data['profile_frame_url'],
      data['profile_frame_image'],
      data['frame'],
      data['frame_data'],
      data['frameData'],
      data['frame_url'],
      data['frame_image'],
    ];

    for (final candidate in candidates) {
      if (_isProfileFrameAsset(candidate)) return candidate;
    }

    return null;
  }

  int _seatGiftCoins(Map<String, dynamic> user) {
    final int currentStreamId = _currentRoomStreamId();
    final ids = <int>{
      _seatUserId(data),
      _safeInt(data['caller_id']),
      _safeInt(data['user_id']),
      _safeInt(data['viewer_id']),
      _safeInt(user['id']),
      _safeInt(user['user_id']),
    }..removeWhere((id) => id <= 0);

    /// Read only this user's received gift coins for the currently open live.
    /// Do not fall back to earned_coins/earn_coins/gifts_coins because those
    /// can be lifetime account values and caused wrong coins under the seat.
    for (final int id in ids) {
      final int coins = websocketController.currentLiveGiftCoinsForUser(
        userId: id,
        livestreamId: currentStreamId,
      );
      if (coins > 0) return coins;
    }

    return 0;
  }

  Map<String, dynamic> _safeUserMap() {
    final fallbackId = data['caller_id'] ?? data['user_id'] ?? data['viewer_id'] ?? data['id'];

    final directUserBase = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : data['caller'] is Map
        ? Map<String, dynamic>.from(data['caller'])
        : <String, dynamic>{};
    final directUser = _mergeRootVisualIntoUser(_toMap(data), directUserBase);

    final fallbackUser = {
      'id': directUser['id'] ?? fallbackId,
      'user_id': directUser['user_id'] ?? fallbackId,
      'name': data['name'] ?? data['user_name'] ?? (fallbackId == null ? 'User' : 'User $fallbackId'),
      'profile_image': data['profile_image'] ?? data['avatar'] ?? '',
      'level': data['level'] ?? 0,
      'asset_purchase_histories': data['asset_purchase_histories'],
      'asset_purchase_history': data['asset_purchase_history'],
      'asset_purchase_history2': data['asset_purchase_history2'],
      'profile_frame_history': data['profile_frame_history'],
      'profile_frame': data['profile_frame'],
      'profileFrame': data['profileFrame'],
      'profile_frame_data': data['profile_frame_data'],
      'profileFrameData': data['profileFrameData'],
      'active_profile_frame': data['active_profile_frame'],
      'activeProfileFrame': data['activeProfileFrame'],
      'active_frame': data['active_frame'],
      'activeFrame': data['activeFrame'],
      'selected_frame': data['selected_frame'],
      'selectedFrame': data['selectedFrame'],
      'current_frame': data['current_frame'],
      'currentFrame': data['currentFrame'],
      'avatar_frame': data['avatar_frame'],
      'avatarFrame': data['avatarFrame'],
      'avatar_frame_history': data['avatar_frame_history'],
      'avatarFrameHistory': data['avatarFrameHistory'],
      'frame': data['frame'],
      'frame_data': data['frame_data'],
      'frameData': data['frameData'],
      'profile_frame_url': data['profile_frame_url'],
      'profile_frame_image': data['profile_frame_image'],
      'frame_url': data['frame_url'],
      'frame_image': data['frame_image'],
    };

    final lookupId = directUser['id'] ?? directUser['user_id'] ?? fallbackId;
    final int lookupInt = _safeInt(lookupId);

    final cachedUser = lookupInt > 0
        ? (_seatUserVisualCache[lookupInt] ?? <String, dynamic>{})
        : <String, dynamic>{};
    final hydratedUser = _findHydratedUserFromLiveState(lookupId);
    final homeUser = _findHydratedUserFromHomeList(lookupId);
    final authUser = _currentAuthUserVisualMap(lookupInt);

    final merged = _mergeUserInfo(
      _mergeUserInfo(
        _mergeUserInfo(
          _mergeUserInfo(
            _mergeUserInfo(Map<String, dynamic>.from(fallbackUser), cachedUser),
            homeUser,
          ),
          hydratedUser,
        ),
        authUser,
      ),
      directUser,
    );

    // If the latest user payload is partial after guardian/admin update,
    // keep cached/home visual data so profile frame does not disappear.
    if (!_hasVisualFrame(merged) && cachedUser.isNotEmpty) {
      final fixed = _mergeUserInfo(merged, cachedUser);
      _cacheSeatUserVisual(fixed);
      return fixed;
    }

    _cacheSeatUserVisual(merged);
    return merged;
  }


  bool _canManageSeatLock() {
    try {
      final dynamic live = livestreamController;
      return live.canModerateLive == true;
    } catch (_) {
      return false;
    }
  }


  bool _currentUserAlreadyOnMic() {
    final userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId <= 0) return false;

    try {
      return websocketController.liveCallList.any((raw) {
        if (raw is! Map) return false;
        final call = Map<String, dynamic>.from(raw);
        if (!_rowBelongsToCurrentRoom(call)) return false;

        final status = (call['call_status'] ?? call['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final bool accepted = status == 'accepted' ||
            status == 'joined' ||
            status == 'active' ||
            status == 'live' ||
            status == 'on_seat';
        if (!accepted) return false;

        final int activeSeatNo = _safeInt(
          call['seat_no'] ??
              call['seatNo'] ??
              call['seat'] ??
              call['seat_number'],
        );
        if (activeSeatNo <= 0) return false;

        final callerId = call['caller_id'] ?? call['user_id'];
        final callUserId = call['user'] is Map ? call['user']['id'] : null;
        final nestedCallerId =
        call['caller'] is Map ? call['caller']['id'] : null;
        return callerId.toString() == userId.toString() ||
            callUserId.toString() == userId.toString() ||
            nestedCallerId.toString() == userId.toString();
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _joinOrSwitchToThisSeat() async {
    final int streamId = livestreamController.streamId.value;
    final int userId = authController.userProfile.value.user?.id?.toInt() ?? 0;

    if (streamId <= 0 || userId <= 0) {
      Fluttertoast.showToast(msg: ('Invalid live room data').appTr);
      return;
    }

    if (isLockedSeat && !_canManageSeatLock()) {
      Fluttertoast.showToast(msg: ('This seat is locked').appTr);
      return;
    }

    try {
      final bool alreadyInMic = _currentUserAlreadyOnMic();

      if (alreadyInMic) {
        /// Already on a mic seat => switch smoothly to selected empty seat.
        await livestreamController.switchAudioSeat(
          livestreamId: streamId,
          toSeatNo: seatNo,
        );
      } else {
        /// Not on mic yet => request/join this seat.
        await livestreamController.tryToCallLivestream(
          streamId: streamId,
          callerId: userId,
          callType: 'audio',
          seatNO: seatNo,
        );
      }

      try {
        await livestreamController.tryToGetCallList(streamId: streamId, force: true);
        websocketController.liveCallList.refresh();
      } catch (e) {
        debugPrint('Seat join/switch refresh failed: $e');
      }
    } catch (e) {
      debugPrint('Seat join/switch failed: $e');
      Fluttertoast.showToast(msg: ('Seat action failed').appTr);
    }
  }

  Future<void> _handleSeatTap() async {
    final bool isBroadcaster = livestreamController.isBroadcaster.value;
    final bool canManageSeat = _canManageSeatLock();

    /// Occupied seat => show profile only.
    if (data.isNotEmpty) {
      final user = _safeUserMap();
      final userId = user['id'] ?? data['caller_id'] ?? data['user_id'] ?? data['id'];
      if (userId != null) {
        homeController.liveVisitProfile(
          userId: '$userId',
          seatData: data,
        );
      }
      return;
    }

    /// Host/Room Admin/Guardian:
    /// Empty seat click korle direct seat-e uthbe na.
    /// Bottom sheet theke Up/Switch seat + Lock/Unlock + Cancel option pabe.
    if (canManageSeat) {
      _showSeatOptionSheet();
      return;
    }

    /// Empty locked seat for normal audience.
    if (isLockedSeat) {
      Fluttertoast.showToast(msg: ('This seat is locked').appTr);
      return;
    }

    /// Normal audience can join/switch only unlocked empty seat directly.
    if (!isBroadcaster) {
      final availableSeats = await livestreamController.getAvailableSeats(
        livestreamController.streamId.value,
      );

      if (availableSeats != null) {
        try {
          websocketController.syncSeatLocksFromAnyPayload(
            Map<String, dynamic>.from(availableSeats),
            allowUnlock: false,
            source: 'available_seats_tap',
          );
        } catch (e) {
          debugPrint('Seat lock sync from availableSeats failed: $e');
        }
      }

      final List availableSeatList = availableSeats?['available_seats'] is List
          ? availableSeats!['available_seats'] as List
          : [];

      final List lockedSeatList = availableSeats?['locked_seats'] is List
          ? availableSeats!['locked_seats'] as List
          : [];

      final bool lockedFromApi = lockedSeatList
          .map((e) => e.toString())
          .contains(seatNo.toString());

      if (lockedFromApi || isLockedSeat) {
        websocketController.updateSeatLockStatus(
          seatNo: seatNo,
          isLocked: true,
          source: 'available_seats_tap_locked',
        );
        Fluttertoast.showToast(msg: ('This seat is locked').appTr);
        return;
      }

      if (availableSeatList.map((e) => e.toString()).contains(seatNo.toString())) {
        await _joinOrSwitchToThisSeat();
      } else {
        Fluttertoast.showToast(msg: ('Seat is not available').appTr);
      }
      return;
    }

    _showSeatOptionSheet();
  }

  void _showSeatOptionSheet() {
    if (!_canManageSeatLock()) return;

    final bool alreadyInMic = _currentUserAlreadyOnMic();

    Get.bottomSheet(
      Container(
        margin: EdgeInsets.symmetric(horizontal: kWeight * 0.025),
        height: kHeight * 0.31,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            SizedBox(height: kHeight * 0.015),
            _sheetItem(
              alreadyInMic ? ('Switch to this seat').appTr: ('Up seat').appTr,
                  () async {
                Get.back();
                await _joinOrSwitchToThisSeat();
              },
            ),
            Obx(
                  () {
                final locked = isLockedSeat;
                return _sheetItem(
                  locked ? ('Unlock seat').appTr: ('Lock seat').appTr,
                      () async {
                    Get.back();
                    final wasLocked = isLockedSeat;
                    await livestreamController.toggleSeatLock(
                      livestreamId: livestreamController.streamId.value,
                      seatNo: seatNo,
                    );

                    /// Keep UI stable immediately after host/admin action.
                    /// The websocket event/API refresh will confirm the same state.
                    websocketController.updateSeatLockStatus(
                      seatNo: seatNo,
                      isLocked: !wasLocked,
                      source: wasLocked ? 'manual_unlock_after_api' : 'manual_lock_after_api',
                    );
                  },
                );
              },
            ),
            _sheetItem(('Cancel').appTr, () => Get.back(), showBorder: false),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(String title, VoidCallback onTap, {bool showBorder = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: kHeight * 0.012),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(.3),
              width: 1,
            ),
          )
              : null,
        ),
        child: Castontext(
          fontWeight: FontWeight.w500,
          textColor: Colors.black.withOpacity(.9),
          fontSize: kHeight * 0.02,
          text: title,
        ),
      ),
    );
  }


  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  dynamic _pickFirst(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty && value.toString() != 'null') {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeImogiPayload(dynamic rawItem) {
    Map<String, dynamic> map = _toMap(rawItem);

    /// Some websocket handlers store payload inside data/payload.
    final innerData = _toMap(map['data']);
    if (innerData.isNotEmpty && (innerData['action_type'] != null || innerData['sender'] != null || innerData['imogi'] != null || innerData['emoji'] != null)) {
      map = innerData;
    }

    final innerPayload = _toMap(map['payload']);
    if (innerPayload.isNotEmpty && (innerPayload['action_type'] != null || innerPayload['sender'] != null || innerPayload['imogi'] != null || innerPayload['emoji'] != null)) {
      map = innerPayload;
    }

    return map;
  }

  Map<String, dynamic>? _activeImogiForUser(dynamic rawUserId) {
    final userId = rawUserId?.toString() ?? '';
    if (userId.isEmpty || userId == 'null') return null;

    for (final rawItem in websocketController.liveImogiAnimations.reversed) {
      final map = _normalizeImogiPayload(rawItem);

      final sender = _toMap(map['sender']);
      final user = _toMap(map['user']);

      final senderId = _pickFirst(sender, ['id', 'user_id', 'caller_id']) ??
          _pickFirst(user, ['id', 'user_id', 'caller_id']) ??
          _pickFirst(map, [
            'sender_id',
            'user_id',
            'caller_id',
            'senderId',
            'userId',
            'id',
          ]);

      if (senderId.toString() == userId) {
        return map;
      }
    }

    return null;
  }

  String _safeImogiImage(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null' || raw == 'file:///') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  Widget _seatImogiOverlay(dynamic rawUserId) {
    return Obx(() {
      final item = _activeImogiForUser(rawUserId);
      if (item == null) return const SizedBox.shrink();

      final imogi = _toMap(item['imogi']);
      final emoji = _toMap(item['emoji']);
      final giftLike = _toMap(item['gift']);

      final image = _safeImogiImage(
        _pickFirst(imogi, [
          'image',
          'icon',
          'imogi_image',
          'emoji_image',
          'show_image',
          'url',
          'file',
        ]) ??
            _pickFirst(emoji, [
              'image',
              'icon',
              'imogi_image',
              'emoji_image',
              'show_image',
              'url',
              'file',
            ]) ??
            _pickFirst(giftLike, [
              'image',
              'icon',
              'imogi_image',
              'emoji_image',
              'show_image',
              'url',
              'file',
            ]) ??
            _pickFirst(item, [
              'image',
              'icon',
              'imogi_image',
              'emoji_image',
              'show_image',
              'url',
              'file',
            ]),
      );

      if (image.isEmpty) return const SizedBox.shrink();

      return IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(item['event_id']?.toString() ??
              item['timestamp']?.toString() ??
              image),
          tween: Tween<double>(begin: .52, end: 1.0),
          duration: const Duration(milliseconds: 210),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                height: kHeight * 0.128,
                width: kHeight * 0.128,
                padding: EdgeInsets.all(kHeight * 0.003),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(.14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  memCacheWidth: 180,
                  memCacheHeight: 180,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _emptySeat() {
    return RepaintBoundary(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final bool locked = isLockedSeat;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: kHeight * 0.068,
                width: kHeight * 0.068,


                // Gradient Border
                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F2174).withOpacity(.2),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Color(0xFF4F2174).withOpacity(.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(-3, -3),
                    ),
                  ],
                ),

                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 3D Glass Body

                    color: Colors.white.withOpacity(.3),


                  ),

                  child: Stack(
                    alignment: Alignment.center,
                    children: [


                      // Seat Image
                      Image.asset(
                        locked
                            ? 'assets/newaudio/lockSet.png'
                            : 'assets/newaudio/audioSet.png',
                        height: locked ? kHeight * 0.045 : kHeight * 0.06,
                        width: locked ? kHeight * 0.045 : kHeight * 0.058,
                        fit: BoxFit.cover,

                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ],
                  ),
                ),
              );
            }),


            SizedBox(height: kHeight * 0.008),
            Obx(
                  () => Text(
                isLockedSeat ? ('Locked').appTr: ('Join').appTr,
                style: GoogleFonts.roboto(
                  fontSize: kHeight * 0.0105,
                  color: Colors.white.withOpacity(.85),
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _occupiedSeat() {
    return Obx(() {
      final user = _safeUserMap();
      final name = _truncateName('${user['name'] ?? ('User').appTr}', 8);
      final profile = ImageHelper.getImageUrl('${user['profile_image'] ?? ''}');
      // Debug log removed: this widget rebuilds often and was flooding console.
      final frameData = _seatProfileFrameData(user);
      final String frameAssetPath = _profileFrameAssetPath(frameData);
      final bool hasProfileFrame =
          frameAssetPath.isNotEmpty && _isProfileFrameAsset(frameData);
      final int giftCoins = _seatGiftCoins(user);
      final bool muted = _isAudioMuted(data);
      final bool isSpeaking = _isUserSpeaking(data);
      /// Gift receiver id usually matches caller_id/user_id from seat data.
      /// Prefer seat ids first, then nested user ids.
      final dynamic overlayUserId = data['caller_id'] ??
          data['user_id'] ??
          data['viewer_id'] ??
          user['id'] ??
          user['user_id'] ??
          data['id'];
      final int currentSeatUserId = _safeInt(overlayUserId);
      final bool isRoomAdmin = _isRoomAdminUser(data, user);
      final bool isHostSeatUser = _isHostSeatUser(data, user);

      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Profile image + frame একটু নিচে নামানো হয়েছে।
            /// Transform শুধু visual position বদলাবে, নিচের name layout নষ্ট করবে না।
            Transform.translate(
              offset: Offset(0, kHeight * 0.014),
              child: SizedBox(
                height: kHeight * 0.1,
                width: kHeight * 0.1,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (isSpeaking && !muted)
                      SpeakingWave(size: kHeight * 0.15),

                    Builder(
                      builder: (profileContext) {
                        // Register every possible id for this seated user.
                        // Some websocket payloads use `id`, some use `user_id`,
                        // and self-gift can arrive before receiver_seat_no is attached.
                        // Registering all candidates makes receiver profile targeting safe.
                        final Set<int> luckyTargetUserIds = <int>{
                          currentSeatUserId,
                          _seatUserId(data),
                          _safeInt(data['id']),
                          _safeInt(data['caller_id']),
                          _safeInt(data['user_id']),
                          _safeInt(data['viewer_id']),
                          _safeInt(user['id']),
                          _safeInt(user['user_id']),
                          _safeInt(user['caller_id']),
                        }..removeWhere((id) => id <= 0);

                        // Current logged-in host/self can arrive as receiver_id even
                        // when the seat payload is partial. Add it only when this
                        // profile already looks like the current user's seat.
                        final int authUserId =
                            authController.userProfile.value.user?.id?.toInt() ?? 0;
                        if (authUserId > 0 &&
                            (luckyTargetUserIds.contains(authUserId) ||
                                currentSeatUserId == authUserId ||
                                _seatUserId(data) == authUserId ||
                                _safeInt(user['id']) == authUserId ||
                                _safeInt(user['user_id']) == authUserId)) {
                          luckyTargetUserIds.add(authUserId);
                        }

                        for (final int luckyUserId in luckyTargetUserIds) {
                          LiveViewCircle_container._registerLuckyProfileContext(
                            luckyUserId,
                            profileContext,
                            seatNo: seatNo,
                          );
                        }

                        LiveViewCircle_container._registerLuckySeatContext(
                          seatNo,
                          profileContext,
                        );

                        return Container(
                          height: kHeight * 0.09,
                          width: kHeight * 0.09,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.16),
                            border: Border.all(
                              color: muted
                                  ? Colors.redAccent.withOpacity(.75)
                                  : Colors.white.withOpacity(.30),
                              width: muted ? 1.4 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: muted
                                    ? Colors.redAccent.withOpacity(.28)
                                    : Colors.black.withOpacity(.28),
                                blurRadius: muted ? 12 : 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              fit: BoxFit.cover,
                              imageUrl: profile,
                              placeholder: (context, url) => Container(
                                color: Colors.white.withOpacity(.15),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: kHeight * 0.025,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.white.withOpacity(.15),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: kHeight * 0.025,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (hasProfileFrame)
                      IgnorePointer(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          minHeight: kHeight * 0.115,
                          maxHeight: kHeight * 0.115,
                          minWidth: kHeight * 0.115,
                          maxWidth: kHeight * 0.115,
                          child: RepaintBoundary(
                            child: _isSvgaAssetPath(frameAssetPath)
                                ? SizedBox(
                              key: ValueKey<String>(
                                'seat_svga_frame_${currentSeatUserId}_$frameAssetPath',
                              ),
                              height: kHeight * 0.115,
                              width: kHeight * 0.115,
                              child: SVGAEasyPlayer(
                                resUrl: ImageHelper.getImageUrl(frameAssetPath),
                                fit: BoxFit.contain,
                                loops: null,
                                useCache: true,
                              ),
                            )
                                : CachedNetworkImage(
                              key: ValueKey<String>(
                                'seat_image_frame_${currentSeatUserId}_$frameAssetPath',
                              ),
                              imageUrl: ImageHelper.getImageUrl(frameAssetPath),
                              height: kHeight * 0.115,
                              width: kHeight * 0.115,
                              fit: BoxFit.contain,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 2,
                      bottom: 3,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        child: muted
                            ? Container(
                          key: ValueKey('muted_$overlayUserId'),
                          height: kHeight * 0.020,
                          width: kHeight * 0.020,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.96),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: .8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.30),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mic_off,
                            color: Colors.white,
                            size: kHeight * 0.012,
                          ),
                        )
                            : SizedBox(
                          key: ValueKey('unmuted_empty_$overlayUserId'),
                          height: kHeight * 0.020,
                          width: kHeight * 0.020,
                        ),
                      ),
                    ),
                    // Host switched to a lower seat hole avatar/profile er majkhane
                    // government icon show korbo na. Main host seat reserved icon
                    // AudioLiveView._reservedHostMainSeat() e thakbe only.
                    _seatImogiOverlay(overlayUserId),
                  ],
                ),
              ),
            ),

            /// Empty seat-এর Join text-এর একই horizontal level-এ name রাখা হয়েছে।
            /// Profile/frame নিচে নামলেও name আলাদাভাবে উপরে থাকবে।
            Transform.translate(
              offset: Offset(0, kHeight * 0.017),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isHostSeatUser && isRoomAdmin) ...[
                    _roomAdminIcon(),
                    SizedBox(width: kWeight * 0.004),
                  ],
                  GradientShimmerTextaudio(
                    text: name,
                    fontSize: kHeight * 0.014,
                    fontWeight: FontWeight.w600,
                    visibleLetters: isRoomAdmin && !isHostSeatUser ? 5 : 6,
                  ),
                ],
              ),
            ),
            // Text(
            //   name,
            //   maxLines: 1,
            //   overflow: TextOverflow.ellipsis,
            //   style: GoogleFonts.roboto(
            //     fontSize: kHeight * 0.011,
            //     color: muted
            //         ? Colors.white.withOpacity(.78)
            //         : Colors.white.withOpacity(.92),
            //     fontWeight: FontWeight.w600,
            //   ),
            //   textAlign: TextAlign.center,
            // ),
            /// Gift coin থাকুক বা না থাকুক একই জায়গা reserve থাকবে।
            /// তাই profile/name আর উপরে-নিচে নড়বে না।
            SizedBox(height: kHeight * 0.012),
            Transform.translate(
              offset: Offset(0, kHeight * 0.008),
              child: SizedBox(
                height: kHeight * 0.022,
                child: Center(
                  child: giftCoins > 0
                      ? Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kWeight * 0.012,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: muted
                          ? Colors.red.withOpacity(.22)
                          : Colors.black.withOpacity(.24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/diamond-removebg-preview.png',
                          height: kHeight * 0.012,
                        ),
                        SizedBox(width: kWeight * 0.004),
                        Text(
                          formatNumber(giftCoins),
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.013,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: InkWell(
        onTap: _handleSeatTap,
        borderRadius: BorderRadius.circular(50),
        child: SizedBox(
          width: Get.width * 0.165,
          child: data.isNotEmpty ? _occupiedSeat() : _emptySeat(),
        ),
      ),
    );
  }
}


class SpeakingWave extends StatefulWidget {
  final double size;

  const SpeakingWave({
    super.key,
    required this.size,
  });

  @override
  State<SpeakingWave> createState() => _SpeakingWaveState();
}

class _SpeakingWaveState extends State<SpeakingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: .88, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacity = Tween<double>(begin: .85, end: .25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              height: widget.size,
              width: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(_opacity.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(_opacity.value * .45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


String formatNumber(dynamic number) {
  int value = int.tryParse(number.toString()) ?? 0;

  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  } else {
    return value.toString();
  }
}
