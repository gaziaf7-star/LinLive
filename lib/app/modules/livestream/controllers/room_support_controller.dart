import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;

import '../../../../apis/api_endpoints.dart';
import '../../auth/controllers/auth_controller.dart';
import 'livestream_controller.dart';

class RoomSupportActionResult {
  const RoomSupportActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class RoomSupportController extends GetxController {
  RoomSupportController({required this.livestreamId});

  static const int maxPartners = 10;

  final int livestreamId;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  final RxBool loading = false.obs;
  final RxBool silentLoading = false.obs;
  final RxBool partnerActionLoading = false.obs;
  final RxInt removingSupportPartnerId = 0.obs;
  final RxInt countdownSeconds = 0.obs;
  final RxInt rankingPeriodIndex = 0.obs;
  final RxString error = ''.obs;
  final RxMap<String, dynamic> data = <String, dynamic>{}.obs;

  Timer? _countdownTimer;
  Timer? _realtimeRefreshTimer;
  bool _loadRunning = false;
  DateTime? _lastLoadAt;

  AuthController get _authController => Get.find<AuthController>();

  @override
  void onInit() {
    super.onInit();

    try {
      _authController.configureProtectedDio(_dio);
    } catch (_) {}

    load();
    _startRealtimeRefresh();
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _realtimeRefreshTimer?.cancel();
    _dio.close(force: true);
    super.onClose();
  }

  Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> list(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return <Map<String, dynamic>>[];
  }

  int safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;

    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? fallback;
  }

  bool truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final String text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'admin' ||
        text == 'guardian' ||
        text == 'owner' ||
        text == 'host';
  }

  String firstText(Iterable<dynamic> values, {String fallback = ''}) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  Map<String, dynamic> get week => map(data['week']);
  Map<String, dynamic> get current => map(data['current']);
  Map<String, dynamic> get rewardPreview => map(current['reward_preview']);
  Map<String, dynamic> get progress => map(current['progress']);
  Map<String, dynamic> get nextLevel => map(current['next_level']);
  List<Map<String, dynamic>> get partners => list(data['partners']).take(maxPartners).toList();
  List<Map<String, dynamic>> get rewards => list(data['rewards']);
  List<Map<String, dynamic>> get rules => list(data['rules']);

  int get partnerCount => partners.length;
  bool get partnerLimitReached => partnerCount >= maxPartners;

  bool get backendPartnerWindowOpen {
    final dynamic raw = week['can_add_partner'];
    if (raw == null) return true;
    return truthy(raw);
  }

  bool get canManagePartners {
    final Map<String, dynamic> currentData = current;
    final Map<String, dynamic> root = Map<String, dynamic>.from(data);

    if (truthy(
      currentData['can_manage_partners'] ??
          currentData['is_owner'] ??
          currentData['is_admin'] ??
          currentData['is_guardian'] ??
          currentData['room_admin'] ??
          root['can_manage_partners'] ??
          root['is_owner'] ??
          root['is_admin'] ??
          root['is_guardian'] ??
          root['room_admin'],
    )) {
      return true;
    }

    final Set<String> myIds = _myUserIds();
    final Map<String, dynamic> owner = map(
      currentData['owner'] ?? currentData['user'] ?? root['owner'],
    );

    final Set<String> ownerIds = <String>{
      '${currentData['owner_id'] ?? ''}'.trim(),
      '${currentData['host_id'] ?? ''}'.trim(),
      '${root['owner_id'] ?? ''}'.trim(),
      '${root['host_id'] ?? ''}'.trim(),
      '${owner['id'] ?? ''}'.trim(),
      '${owner['user_id'] ?? ''}'.trim(),
      '${owner['unique_id'] ?? ''}'.trim(),
    }..removeWhere((String value) {
      return value.isEmpty || value == '0' || value == 'null';
    });

    if (ownerIds.any(myIds.contains)) return true;

    try {
      if (Get.isRegistered<LivestreamController>()) {
        final LivestreamController live = Get.find<LivestreamController>();
        final bool sameRoom = live.streamId.value == livestreamId;
        if (sameRoom && live.canModerateLive) return true;
      }
    } catch (_) {}

    final Map<String, dynamic> user = authUserMap();
    final String role = firstText(<dynamic>[
      user['role'],
      user['user_role'],
      user['account_type'],
      user['type'],
    ]).toLowerCase();

    return truthy(user['is_admin']) ||
        truthy(user['is_guardian']) ||
        role == 'admin' ||
        role == 'room_admin' ||
        role == 'guardian';
  }

  bool get canAddPartner {
    return canManagePartners &&
        backendPartnerWindowOpen &&
        !partnerLimitReached &&
        !partnerActionLoading.value;
  }

  Map<String, dynamic> authUserMap() {
    try {
      final dynamic user = _authController.userProfile.value.user;
      if (user == null) return <String, dynamic>{};

      try {
        final dynamic raw = user.toJson();
        if (raw is Map) return Map<String, dynamic>.from(raw);
      } catch (_) {}

      final Map<String, dynamic> result = <String, dynamic>{};
      try {
        result['id'] = user.id;
      } catch (_) {}
      try {
        result['user_id'] = user.userId;
      } catch (_) {}
      try {
        result['unique_id'] = user.uniqueId;
      } catch (_) {}
      try {
        result['name'] = user.name;
      } catch (_) {}
      try {
        result['profile_image'] = user.profileImage;
      } catch (_) {}
      try {
        result['is_admin'] = user.isAdmin;
      } catch (_) {}
      return result;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Set<String> _myUserIds() {
    final Map<String, dynamic> user = authUserMap();
    final Set<String> ids = <String>{};
    for (final String key in const <String>[
      'id',
      'user_id',
      'unique_id',
      'uid',
    ]) {
      final String value = user[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != '0' && value != 'null') ids.add(value);
    }
    return ids;
  }

  void _startRealtimeRefresh() {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (livestreamId > 0) load(silent: true);
    });
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    countdownSeconds.value = seconds < 0 ? 0 : seconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (countdownSeconds.value <= 0) {
        timer.cancel();
        return;
      }
      countdownSeconds.value--;
    });
  }

  String get countdownText {
    final Duration duration = Duration(
      seconds: countdownSeconds.value.clamp(0, 999999999).toInt(),
    );
    final int days = duration.inDays;
    final int hours = duration.inHours % 24;
    final int minutes = duration.inMinutes % 60;
    final int seconds = duration.inSeconds % 60;

    return '${days} Day '
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> load({bool silent = false, bool force = false}) async {
    if (livestreamId <= 0) return;

    if (_loadRunning) {
      if (!force) return;
      for (int attempt = 0; attempt < 20 && _loadRunning; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_loadRunning) return;
    }

    final DateTime now = DateTime.now();
    if (!force && silent &&
        _lastLoadAt != null &&
        now.difference(_lastLoadAt!) < const Duration(seconds: 15)) {
      return;
    }

    _loadRunning = true;
    _lastLoadAt = now;

    if (silent) {
      silentLoading.value = true;
    } else {
      loading.value = true;
    }
    error.value = '';

    try {
      final String token =
          _authController.userProfile.value.token?.toString().trim() ?? '';

      final Response<dynamic> response = await _dio.get<dynamic>(
        '$kMainUrl/room-support',
        queryParameters: <String, dynamic>{
          'livestream_id': livestreamId,
        },
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          validateStatus: (int? code) => code != null && code < 500,
        ),
      );

      final Map<String, dynamic> body = _decodeMap(response.data);
      final int statusCode = response.statusCode ?? 0;

      if (statusCode >= 200 && statusCode < 300 && body.isNotEmpty) {
        data.assignAll(body);
        _startCountdown(safeInt(map(body['week'])['countdown_seconds']));
        debugPrint(
          '✅ Room Support loaded => stream=$livestreamId '
              'partners=${partners.length}/$maxPartners canManage=$canManagePartners',
        );
      } else {
        error.value = _apiMessage(
          response.data,
          'Room Support load failed',
        );
      }
    } on DioException catch (e) {
      error.value = _apiMessage(e.response?.data, 'Room Support load failed');
      debugPrint(
        '❌ Room Support Dio error => ${e.response?.statusCode} ${e.message}',
      );
    } catch (e, stackTrace) {
      error.value = 'Room Support load failed';
      debugPrint('❌ Room Support error => $e\n$stackTrace');
    } finally {
      _loadRunning = false;
      loading.value = false;
      silentLoading.value = false;
    }
  }

  Future<RoomSupportActionResult> addPartner(int partnerId) async {
    if (!canManagePartners) {
      return const RoomSupportActionResult(
        success: false,
        message: 'Only the host or room admin can add partners.',
      );
    }

    if (!backendPartnerWindowOpen) {
      return const RoomSupportActionResult(
        success: false,
        message: 'Partner adding is closed for this week.',
      );
    }

    if (partnerLimitReached) {
      return const RoomSupportActionResult(
        success: false,
        message: 'You can add a maximum of 10 partners.',
      );
    }

    if (partnerId <= 0) {
      return const RoomSupportActionResult(
        success: false,
        message: 'Please enter a valid Partner ID.',
      );
    }

    final bool duplicate = partners.any((Map<String, dynamic> item) {
      return partnerIdOf(item) == partnerId;
    });
    if (duplicate) {
      return const RoomSupportActionResult(
        success: false,
        message: 'This user is already added as a partner.',
      );
    }

    return _action(
      action: 'add_partner',
      partnerId: partnerId,
    );
  }

  Future<RoomSupportActionResult> removePartner(
      Map<String, dynamic> item,
      ) async {
    if (!canManagePartners) {
      return const RoomSupportActionResult(
        success: false,
        message: 'Only the host or room admin can remove partners.',
      );
    }

    return _action(
      action: 'remove_partner',
      partnerId: partnerIdOf(item),
      supportPartnerId: supportPartnerIdOf(item),
    );
  }

  Future<RoomSupportActionResult> _action({
    required String action,
    int partnerId = 0,
    int supportPartnerId = 0,
  }) async {
    if (partnerActionLoading.value) {
      return const RoomSupportActionResult(
        success: false,
        message: 'Please wait for the current request to finish.',
      );
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'action': action,
      'livestream_id': livestreamId,
    };

    if (action == 'add_partner') {
      payload['partner_id'] = partnerId;
    } else if (action == 'remove_partner') {
      if (supportPartnerId > 0) {
        payload['support_partner_id'] = supportPartnerId;
      } else {
        final int ownerId = _ownerId();
        if (ownerId > 0) payload['owner_id'] = ownerId;
        if (partnerId > 0) payload['partner_id'] = partnerId;
      }
    }

    partnerActionLoading.value = true;
    removingSupportPartnerId.value =
    action == 'remove_partner' ? supportPartnerId : 0;

    try {
      final String token =
          _authController.userProfile.value.token?.toString().trim() ?? '';

      final Response<dynamic> response = await _dio.post<dynamic>(
        '$kMainUrl/room-support/action',
        data: payload,
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
          validateStatus: (int? code) => code != null && code < 500,
        ),
      );

      final Map<String, dynamic> body = _decodeMap(response.data);
      final int statusCode = response.statusCode ?? 0;
      final bool success = statusCode >= 200 &&
          statusCode < 300 &&
          body['success'] != false &&
          body['status'] != false;

      if (!success) {
        return RoomSupportActionResult(
          success: false,
          message: _apiMessage(
            response.data,
            action == 'add_partner'
                ? 'Partner add failed'
                : 'Partner remove failed',
          ),
        );
      }

      await load(force: true);
      return RoomSupportActionResult(
        success: true,
        message: _apiMessage(
          response.data,
          action == 'add_partner'
              ? 'Partner added successfully'
              : 'Partner removed successfully',
        ),
      );
    } on DioException catch (e) {
      return RoomSupportActionResult(
        success: false,
        message: _apiMessage(
          e.response?.data,
          'Room Support action failed',
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Room Support action error => $e\n$stackTrace');
      return const RoomSupportActionResult(
        success: false,
        message: 'Something went wrong',
      );
    } finally {
      partnerActionLoading.value = false;
      removingSupportPartnerId.value = 0;
    }
  }

  Map<String, dynamic> partnerUser(Map<String, dynamic> item) {
    for (final String key in const <String>[
      'partner',
      'user',
      'partner_user',
      'profile',
    ]) {
      final Map<String, dynamic> value = map(item[key]);
      if (value.isNotEmpty) return value;
    }
    return <String, dynamic>{};
  }

  int partnerIdOf(Map<String, dynamic> item) {
    final Map<String, dynamic> user = partnerUser(item);
    return safeInt(item['partner_id'] ?? item['user_id'] ?? user['id']);
  }

  int supportPartnerIdOf(Map<String, dynamic> item) {
    final int explicit = safeInt(
      item['support_partner_id'] ??
          item['room_support_partner_id'] ??
          item['pivot_id'],
    );
    if (explicit > 0) return explicit;
    if (partnerUser(item).isNotEmpty) return safeInt(item['id']);
    return 0;
  }

  String partnerName(Map<String, dynamic> item) {
    final Map<String, dynamic> user = partnerUser(item);
    return firstText(<dynamic>[
      user['name'],
      user['username'],
      item['partner_name'],
      item['name'],
      item['title'],
    ], fallback: 'User');
  }

  String partnerPublicId(Map<String, dynamic> item) {
    final Map<String, dynamic> user = partnerUser(item);
    return firstText(<dynamic>[
      user['user_id'],
      user['unique_id'],
      user['uid'],
      item['public_user_id'],
      item['partner_user_id'],
      item['unique_id'],
      item['partner_id'],
      user['id'],
    ], fallback: '—');
  }

  String partnerImage(Map<String, dynamic> item) {
    final Map<String, dynamic> user = partnerUser(item);
    return firstText(<dynamic>[
      user['profile_image'],
      user['avatar'],
      user['image'],
      item['profile_image'],
      item['avatar'],
    ]);
  }

  int partnerCoins(Map<String, dynamic> item) {
    final Map<String, dynamic> user = partnerUser(item);
    final Map<String, dynamic> itemProgress = map(item['progress']);
    return safeInt(
      item['partner_coins'] ??
          item['support_coins'] ??
          item['weekly_coins'] ??
          item['current_coins'] ??
          item['coins'] ??
          item['total_coins'] ??
          user['partner_coins'] ??
          user['support_coins'] ??
          user['weekly_coins'] ??
          itemProgress['current'] ??
          itemProgress['coins'],
    );
  }

  int partnerTarget(Map<String, dynamic> item) {
    final Map<String, dynamic> user = partnerUser(item);
    final Map<String, dynamic> itemProgress = map(item['progress']);
    return safeInt(
      item['partner_target'] ??
          item['target_coins'] ??
          item['coin_target'] ??
          item['weekly_target'] ??
          item['required_coins'] ??
          item['goal_coins'] ??
          item['target'] ??
          user['partner_target'] ??
          user['target_coins'] ??
          user['weekly_target'] ??
          itemProgress['target'] ??
          itemProgress['max'],
    );
  }

  int partnerPercent(Map<String, dynamic> item) {
    final Map<String, dynamic> itemProgress = map(item['progress']);
    final int direct = safeInt(
      item['progress_percent'] ??
          item['partner_percent'] ??
          item['percent'] ??
          itemProgress['percent'],
      fallback: -1,
    );
    if (direct >= 0) return direct.clamp(0, 100).toInt();

    final int coins = partnerCoins(item);
    final int target = partnerTarget(item);
    if (target <= 0) return 0;
    return ((coins / target) * 100).round().clamp(0, 100).toInt();
  }

  List<Map<String, dynamic>> get targetLevels {
    return List<Map<String, dynamic>>.generate(maxPartners, (int index) {
      final int level = index + 1;
      final int roomCoinTarget = level * 1000000;
      final int totalReward = level * 150000;
      final int ownerReward = level * 100000;
      final int partnerPool = level * 50000;
      return <String, dynamic>{
        'level_no': level,
        'room_visitors': level * 20,
        'room_coin_target': roomCoinTarget,
        'total_reward': totalReward,
        'owner_reward': ownerReward,
        'partner_pool': partnerPool,
        'number_of_partners': level,
        'reward_per_partner': 50000,
      };
    });
  }

  Map<String, int> get targetGrandTotal {
    int visitors = 0;
    int roomCoins = 0;
    int totalReward = 0;
    int ownerReward = 0;
    int partnerPool = 0;
    int partnersTotal = 0;
    int rewardPerPartnerTotal = 0;

    for (final Map<String, dynamic> row in targetLevels) {
      visitors += safeInt(row['room_visitors']);
      roomCoins += safeInt(row['room_coin_target']);
      totalReward += safeInt(row['total_reward']);
      ownerReward += safeInt(row['owner_reward']);
      partnerPool += safeInt(row['partner_pool']);
      partnersTotal += safeInt(row['number_of_partners']);
      rewardPerPartnerTotal += safeInt(row['reward_per_partner']);
    }

    return <String, int>{
      'visitors': visitors,
      'room_coins': roomCoins,
      'total_reward': totalReward,
      'owner_reward': ownerReward,
      'partner_pool': partnerPool,
      'partners': partnersTotal,
      'reward_per_partner': rewardPerPartnerTotal,
    };
  }

  List<String> get displayRules {
    final List<String> fromApi = rules
        .map((Map<String, dynamic> item) {
      return firstText(<dynamic>[
        item['title'],
        item['text'],
        item['rule'],
      ]);
    })
        .where((String text) => text.isNotEmpty)
        .toList(growable: false);

    if (fromApi.isNotEmpty) return fromApi;

    return const <String>[
      'Weekly Room Visitors and Weekly Room Coins are counted from Monday 00:00 to Sunday 23:59 (UTC +5:30).',
      'Reaching a Room Level requires meeting both the Room Visitors and Room Coins targets at the same time.',
      'Room Owners must add Room Partners from Monday 00:00 to Tuesday 24:00 (UTC +5:30); otherwise the reward expires.',
      'Rewards are calculated and sent every Monday.',
      'Each user can receive only 1 reward per week, based on the highest target reached as Owner or Partner.',
      'Cheating and violations are prohibited. Confirmed violations cancel all rewards.',
      'This activity is independent of Google and Apple Inc.',
    ];
  }

  List<Map<String, dynamic>> get rankingItems {
    for (final String key in const <String>[
      'ranking',
      'rankings',
      'top_users',
      'room_ranking',
    ]) {
      final List<Map<String, dynamic>> items = list(data[key]);
      if (items.isNotEmpty) return _removeCurrentUserFromRanking(items);
    }

    final List<Map<String, dynamic>> fallback =
    rewards.isNotEmpty ? rewards : partners;
    return _removeCurrentUserFromRanking(fallback);
  }

  List<Map<String, dynamic>> _removeCurrentUserFromRanking(
      List<Map<String, dynamic>> items,
      ) {
    final Set<String> myIds = _myUserIds();
    for (final dynamic value in <dynamic>[
      current['owner_id'],
      current['user_id'],
      current['public_user_id'],
    ]) {
      final String id = value?.toString().trim() ?? '';
      if (id.isNotEmpty && id != '0' && id != 'null') myIds.add(id);
    }

    if (myIds.isEmpty) return items;
    return items.where((Map<String, dynamic> row) {
      final String id = rankingUserId(row);
      return id.isEmpty || !myIds.contains(id);
    }).toList(growable: false);
  }

  String rankingUserId(Map<String, dynamic> row) {
    final Map<String, dynamic> user = map(
      row['user'] ?? row['partner'] ?? row['owner'],
    );
    return firstText(<dynamic>[
      user['id'],
      user['user_id'],
      user['unique_id'],
      row['user_id'],
      row['owner_id'],
      row['partner_id'],
    ]);
  }

  int _ownerId() {
    final Map<String, dynamic> currentData = current;
    final Map<String, dynamic> owner = map(
      currentData['owner'] ?? currentData['user'] ?? data['owner'],
    );
    return safeInt(
      currentData['owner_id'] ??
          data['owner_id'] ??
          owner['id'] ??
          owner['user_id'],
    );
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    dynamic currentValue = value;
    for (int index = 0; index < 2; index++) {
      if (currentValue is Map) {
        return Map<String, dynamic>.from(currentValue);
      }
      if (currentValue is! String) return <String, dynamic>{};
      final String text = currentValue.trim();
      if (text.isEmpty) return <String, dynamic>{};
      try {
        currentValue = jsonDecode(text);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return currentValue is Map
        ? Map<String, dynamic>.from(currentValue)
        : <String, dynamic>{};
  }

  String _apiMessage(dynamic raw, String fallback) {
    final Map<String, dynamic> root = _decodeMap(raw);
    final Map<String, dynamic> nested = map(root['data']);
    final String message = firstText(<dynamic>[
      root['message'],
      nested['message'],
      root['error'],
      nested['error'],
    ]);
    if (message.isNotEmpty) return message;

    final dynamic errors = root['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final dynamic first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }

    return fallback;
  }
}
