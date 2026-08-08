import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class InviteController extends GetxController with WidgetsBindingObserver {
  InviteController({Dio? dio})
      : _dio = dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

  final Dio _dio;

  final inviteHomeLoading = false.obs;
  final rewardListLoading = false.obs;
  final friendsLoading = false.obs;
  final rewardHistoryLoading = false.obs;
  final applyCodeLoading = false.obs;
  final validateCodeLoading = false.obs;

  final inviteHome = InviteHome.empty().obs;
  final rewardSetting = InviteSetting.empty().obs;
  final rewardMilestones = <InviteMilestone>[].obs;
  final friends = <InviteFriend>[].obs;
  final rewardLogs = <InviteRewardLog>[].obs;

  final codeController = TextEditingController();

  Timer? _liveRefreshTimer;
  bool _silentRefreshRunning = false;

  int _friendsPage = 1;
  int _rewardPage = 1;
  bool hasMoreFriends = true;
  bool hasMoreRewards = true;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    refreshInviteSystem(silent: false);
    _startLiveRefresh();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    codeController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLiveSnapshot();
    }
  }

  void _startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _refreshLiveSnapshot(),
    );
  }

  Future<void> _refreshLiveSnapshot() async {
    if (!isLoggedIn || _silentRefreshRunning) return;
    _silentRefreshRunning = true;
    try {
      await fetchInviteHome(silent: true);
    } finally {
      _silentRefreshRunning = false;
    }
  }

  String get _domain {
    final raw = kDomainUrl.toString().trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  String get _apiBase => '$_domain/api';

  String get _token {
    try {
      return authController.userProfile.value.token?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get isLoggedIn => _token.trim().isNotEmpty;

  Map<String, String> get _publicHeaders => {
    'Accept': 'application/json',
  };

  Options _publicOptions() => Options(headers: _publicHeaders);

  Options _authOptions() {
    return Options(
      headers: {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        if (isLoggedIn) 'Authorization': 'Bearer $_token',
      },
    );
  }

  String get inviteCode {
    final fromHome = inviteHome.value.inviteCode.trim();
    if (fromHome.isNotEmpty) return fromHome;

    try {
      final dynamic user = authController.userProfile.value.user;
      final code = user?.refferCode ?? user?.reffer_code ?? user?.referCode;
      return code?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String get inviteLink {
    final fromHome = inviteHome.value.inviteLink.trim();
    if (fromHome.isNotEmpty) return fromHome;

    final code = inviteCode.trim();
    final baseUrl = activeSetting.inviteBaseUrl.trim().isNotEmpty
        ? activeSetting.inviteBaseUrl.trim()
        : '$_domain/invite';
    if (code.isEmpty) return baseUrl;
    return '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/$code';
  }

  InviteSetting get activeSetting {
    if (inviteHome.value.setting.title.trim().isNotEmpty) {
      return inviteHome.value.setting;
    }
    return rewardSetting.value;
  }

  List<InviteMilestone> get activeMilestones {
    if (inviteHome.value.milestones.isNotEmpty) return inviteHome.value.milestones;
    return rewardMilestones;
  }

  InviteMilestone? get nextMilestone {
    final InviteMilestone? apiNext = inviteHome.value.nextMilestone;

    if (apiNext != null && !isMilestoneCompleted(apiNext)) {
      return apiNext;
    }

    for (final milestone in activeMilestones) {
      if (!isMilestoneCompleted(milestone)) return milestone;
    }

    if (apiNext != null) return apiNext;
    return activeMilestones.isNotEmpty ? activeMilestones.last : null;
  }

  /// Current invite count used by the progress UI.
  ///
  /// Some backend responses update reward coins immediately but return a stale
  /// `remaining_friends` value inside `next_milestone`. To keep the progress bar
  /// accurate, we derive the live count from both milestone data and invite stats
  /// and use the highest safe value.
  int achievedFriendsFor(InviteMilestone milestone) {
    if (milestone.friendsCount <= 0) return 0;

    final InviteStats stats = inviteHome.value.stats;
    final int apiDone = milestone.apiCompletedFriends;

    final int liveDone = math.max(
      stats.totalInvites,
      stats.completedFriends,
    );

    return math.max(apiDone, liveDone).clamp(0, milestone.friendsCount).toInt();
  }

  int remainingFriendsFor(InviteMilestone milestone) {
    if (milestone.friendsCount <= 0) return 0;
    return (milestone.friendsCount - achievedFriendsFor(milestone))
        .clamp(0, milestone.friendsCount)
        .toInt();
  }

  double progressFor(InviteMilestone milestone) {
    if (milestone.friendsCount <= 0) return 0.0;
    return (achievedFriendsFor(milestone) / milestone.friendsCount)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool isMilestoneCompleted(InviteMilestone milestone) {
    return milestone.completed ||
        (milestone.friendsCount > 0 &&
            achievedFriendsFor(milestone) >= milestone.friendsCount);
  }

  Future<void> refreshInviteSystem({bool silent = false}) async {
    if (!silent) {
      inviteHomeLoading.value = true;
      rewardListLoading.value = true;
    }

    await Future.wait([
      fetchRewardList(silent: true),
      if (isLoggedIn) fetchInviteHome(silent: true),
    ]);

    if (!silent) {
      inviteHomeLoading.value = false;
      rewardListLoading.value = false;
    }
  }

  Future<void> fetchRewardList({bool silent = false}) async {
    if (!silent) rewardListLoading.value = true;
    try {
      final response = await _dio.get(
        '$_apiBase/invite/reward-list',
        options: _publicOptions(),
      );

      final body = _asMap(response.data);
      final data = _asMap(body['data'] ?? body);
      rewardSetting.value = InviteSetting.fromJson(_asMap(data['setting']));
      rewardMilestones.assignAll(
        _extractList(data, keys: ['milestones', 'rewards'])
            .map((item) => InviteMilestone.fromJson(_asMap(item)))
            .toList(),
      );
    } on DioException catch (e) {
      if (!silent) _toast(message: _dioMessage(e, 'Invite reward load failed'));
    } catch (_) {
      if (!silent) _toast(message: ('Invite reward load failed').appTr);
    } finally {
      if (!silent) rewardListLoading.value = false;
    }
  }

  Future<void> fetchInviteHome({bool silent = false}) async {
    if (!isLoggedIn) return;
    if (!silent) inviteHomeLoading.value = true;
    try {
      final response = await _dio.get(
        '$_apiBase/invite/home',
        queryParameters: {
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: _authOptions(),
      );

      final body = _asMap(response.data);
      final data = _asMap(body['data'] ?? body);
      inviteHome.value = InviteHome.fromJson(data);
      inviteHome.refresh();

      final InviteStats stats = inviteHome.value.stats;
      await _syncAuthWalletValues(
        coins: stats.walletCoins,
        earnedCoins: stats.earnedCoins,
      );
    } on DioException catch (e) {
      if (!silent) _toast(message: _dioMessage(e, 'Invite home load failed'));
    } catch (_) {
      if (!silent) _toast(message: ('Invite home load failed').appTr);
    } finally {
      if (!silent) inviteHomeLoading.value = false;
    }
  }

  Future<bool> validateInviteCode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      _toast(message: ('Please enter invite code').appTr);
      return false;
    }

    validateCodeLoading.value = true;
    try {
      final response = await _dio.get(
        '$_apiBase/invite/validate-code/${Uri.encodeComponent(cleanCode)}',
        options: _publicOptions(),
      );

      final body = _asMap(response.data);
      final data = _asMap(body['data']);
      final success = _truthy(
        data['valid'] ?? body['valid'] ?? body['success'],
      );
      _toast(
        message: body['message']?.toString() ??
            (success ? ('Invite code is valid').appTr : ('Invite code is invalid').appTr),
        backgroundColor: success ? Colors.green : Colors.red,
      );
      return success;
    } on DioException catch (e) {
      _toast(message: _dioMessage(e, 'Invite code is invalid'), backgroundColor: Colors.red);
      return false;
    } catch (_) {
      _toast(message: ('Invite code is invalid').appTr, backgroundColor: Colors.red);
      return false;
    } finally {
      validateCodeLoading.value = false;
    }
  }

  Future<void> _syncAuthWalletFromPayload(dynamic rawPayload) async {
    final Map<String, dynamic> root = _asMap(rawPayload);
    final Map<String, dynamic> data = _asMap(root['data']);
    final Map<String, dynamic> user = _asMap(
      data['user'] ?? root['user'] ?? data['auth_user'] ?? root['auth_user'],
    );
    final Map<String, dynamic> wallet = _asMap(
      data['wallet'] ?? root['wallet'] ?? data['balance'] ?? root['balance'],
    );

    final dynamic coinsRaw = user['coins'] ??
        wallet['coins'] ??
        data['coins'] ??
        data['new_coins'] ??
        root['coins'] ??
        root['new_coins'];

    final dynamic earnedCoinsRaw = user['earned_coins'] ??
        wallet['earned_coins'] ??
        data['earned_coins'] ??
        data['new_earned_coins'] ??
        root['earned_coins'] ??
        root['new_earned_coins'];

    await _syncAuthWalletValues(
      coins: coinsRaw == null ? null : _toInt(coinsRaw),
      earnedCoins: earnedCoinsRaw == null ? null : _toInt(earnedCoinsRaw),
    );
  }

  Future<void> _syncAuthWalletValues({int? coins, int? earnedCoins}) async {
    final dynamic authUser = authController.userProfile.value.user;
    if (authUser == null) return;

    bool changed = false;

    if (coins != null && authUser.coins?.toString() != coins.toString()) {
      authUser.coins = coins.toString();
      changed = true;
    }

    if (earnedCoins != null &&
        authUser.earnedCoins?.toString() != earnedCoins.toString()) {
      authUser.earnedCoins = earnedCoins.toString();
      changed = true;
    }

    if (!changed) return;

    authController.userProfile.refresh();

    // Persist the refreshed wallet so reopening the page/app does not show
    // the old coin amount from local storage.
    try {
      await authController.preferences.setString(
        'profile',
        jsonEncode(authController.userProfile.value.toJson()),
      );
    } catch (_) {
      // Preferences may still be initializing; in-memory profile is already
      // refreshed, so the visible balance remains correct.
    }
  }

  Future<bool> applyInviteCode({String? code}) async {
    if (!isLoggedIn) {
      _toast(message: ('Please login first').appTr, backgroundColor: Colors.red);
      return false;
    }

    final cleanCode = (code ?? codeController.text).trim();
    if (cleanCode.isEmpty) {
      _toast(message: ('Please enter invite code').appTr, backgroundColor: Colors.red);
      return false;
    }

    if (applyCodeLoading.value) return false;

    applyCodeLoading.value = true;
    try {
      final response = await _dio.post(
        '$_apiBase/invite/apply-code',
        data: {
          'code': cleanCode,
          // Backward-compatible names for older backend versions.
          'invite_code': cleanCode,
          'reffer_by': cleanCode,
        },
        options: _authOptions(),
      );

      final body = _asMap(response.data);
      final data = _asMap(body['data']);
      final success = _truthy(
        body['success'] ??
            data['success'] ??
            (response.statusCode == 200 || response.statusCode == 201),
      );

      if (!success) {
        _toast(
          message: body['message']?.toString() ??
              data['message']?.toString() ??
              ('Invite code apply failed').appTr,
          backgroundColor: Colors.red,
        );
        return false;
      }

      // The backend is the source of truth for rewards. When it returns the
      // refreshed wallet/user values, update the app profile immediately.
      await _syncAuthWalletFromPayload(body);

      codeController.clear();
      await fetchInviteHome(silent: true);

      final InviteStats stats = inviteHome.value.stats;
      await _syncAuthWalletValues(
        coins: stats.walletCoins,
        earnedCoins: stats.earnedCoins,
      );

      final int rewardCoins = _toInt(
        data['invite_reward_coins'] ??
            data['reward_coins'] ??
            data['signup_reward_coins'] ??
            body['invite_reward_coins'] ??
            body['reward_coins'] ??
            body['signup_reward_coins'],
      );

      final String successMessage = body['message']?.toString().trim().isNotEmpty == true
          ? body['message'].toString()
          : rewardCoins > 0
          ? 'Invite code applied successfully. +$rewardCoins coins'
          : 'Invite code applied successfully';

      _toast(
        message: successMessage,
        backgroundColor: Colors.green,
      );

      return true;
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, 'Invite code apply failed'),
        backgroundColor: Colors.red,
      );
      return false;
    } catch (e) {
      debugPrint('Invite code apply error: $e');
      _toast(message: ('Invite code apply failed').appTr, backgroundColor: Colors.red);
      return false;
    } finally {
      applyCodeLoading.value = false;
    }
  }

  Future<void> fetchMyFriends({bool refresh = true, int perPage = 20}) async {
    if (!isLoggedIn) {
      friends.clear();
      return;
    }

    if (refresh) {
      _friendsPage = 1;
      hasMoreFriends = true;
    } else if (!hasMoreFriends) {
      return;
    }

    friendsLoading.value = true;
    try {
      final response = await _dio.get(
        '$_apiBase/invite/my-friends',
        queryParameters: {
          'page': _friendsPage,
          'per_page': perPage,
        },
        options: _authOptions(),
      );

      final body = _asMap(response.data);
      final data = body['data'] ?? body;
      final list = _extractList(data, keys: [
        'data',
        'friends',
        'records',
        'invite_records',
        'invited_friends',
      ]).map((item) => InviteFriend.fromJson(_asMap(item))).toList();

      if (refresh) {
        friends.assignAll(list);
      } else {
        friends.addAll(list);
      }

      hasMoreFriends = _hasMore(data, currentPage: _friendsPage, receivedCount: list.length, perPage: perPage);
      if (hasMoreFriends) _friendsPage++;
    } on DioException catch (e) {
      _toast(message: _dioMessage(e, 'Friends load failed'), backgroundColor: Colors.red);
    } catch (_) {
      _toast(message: ('Friends load failed').appTr, backgroundColor: Colors.red);
    } finally {
      friendsLoading.value = false;
    }
  }

  Future<void> fetchMyRewards({bool refresh = true, int perPage = 20}) async {
    if (!isLoggedIn) {
      rewardLogs.clear();
      return;
    }

    if (refresh) {
      _rewardPage = 1;
      hasMoreRewards = true;
    } else if (!hasMoreRewards) {
      return;
    }

    rewardHistoryLoading.value = true;
    try {
      final response = await _dio.get(
        '$_apiBase/invite/my-rewards',
        queryParameters: {
          'page': _rewardPage,
          'per_page': perPage,
        },
        options: _authOptions(),
      );

      final body = _asMap(response.data);
      final data = body['data'] ?? body;
      final list = _extractList(data, keys: [
        'data',
        'logs',
        'reward_logs',
        'records',
        'rewards',
      ]).map((item) => InviteRewardLog.fromJson(_asMap(item))).toList();

      if (refresh) {
        rewardLogs.assignAll(list);
      } else {
        rewardLogs.addAll(list);
      }

      hasMoreRewards = _hasMore(data, currentPage: _rewardPage, receivedCount: list.length, perPage: perPage);
      if (hasMoreRewards) _rewardPage++;
    } on DioException catch (e) {
      _toast(message: _dioMessage(e, 'Reward history load failed'), backgroundColor: Colors.red);
    } catch (_) {
      _toast(message: ('Reward history load failed').appTr, backgroundColor: Colors.red);
    } finally {
      rewardHistoryLoading.value = false;
    }
  }

  Future<void> copyInviteLink() async {
    final link = inviteLink.trim();
    if (link.isEmpty) {
      _toast(message: ('Invite link not ready').appTr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    _toast(message: ('Invite link copied').appTr, backgroundColor: Colors.green);
  }

  Future<void> copyInviteCode() async {
    final code = inviteCode.trim();
    if (code.isEmpty) {
      _toast(message: ('Invite code not ready').appTr);
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    _toast(message: ('Invite code copied').appTr, backgroundColor: Colors.green);
  }


  String get inviteShareMessage {
    final code = inviteCode.trim();
    final link = inviteLink.trim();
    var message = activeSetting.shareText.trim();

    if (message.isEmpty) {
      message = 'Join LIN LIVE using my invite link and earn rewards!'.appTr;
    }

    message = message
        .replaceAll('{invite_code}', code)
        .replaceAll('{referral_code}', code)
        .replaceAll('{invite_link}', link)
        .replaceAll('{referral_link}', link);

    if (code.isNotEmpty && !message.contains(code)) {
      message = '$message\n${'Invite Code'.appTr}: $code';
    }
    if (link.isNotEmpty && !message.contains(link)) {
      message = '$message\n$link';
    }

    return message.trim();
  }

  Future<void> shareInviteToWhatsApp() async {
    final message = inviteShareMessage;
    if (message.isEmpty) {
      _toast(message: ('Invite link not ready').appTr);
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await Clipboard.setData(ClipboardData(text: message));
        _toast(message: ('Invite message copied').appTr);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      _toast(message: ('Invite message copied').appTr);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<dynamic> _extractList(dynamic value, {List<String> keys = const []}) {
    if (value is List) return List<dynamic>.from(value);

    final map = _asMap(value);
    for (final key in keys) {
      final found = map[key];
      if (found is List) return List<dynamic>.from(found);
      if (found is Map && found['data'] is List) {
        return List<dynamic>.from(found['data']);
      }
    }

    final data = map['data'];
    if (data is List) return List<dynamic>.from(data);
    if (data is Map && data['data'] is List) return List<dynamic>.from(data['data']);

    return <dynamic>[];
  }

  bool _hasMore(dynamic value, {required int currentPage, required int receivedCount, required int perPage}) {
    final map = _asMap(value);
    final pageMap = map['data'] is Map ? _asMap(map['data']) : map;

    final lastPage = _toInt(pageMap['last_page'] ?? pageMap['lastPage']);
    if (lastPage > 0) return currentPage < lastPage;

    final nextPageUrl = pageMap['next_page_url'] ?? pageMap['nextPageUrl'];
    if (nextPageUrl != null && nextPageUrl.toString().isNotEmpty) return true;

    return receivedCount >= perPage;
  }

  String _dioMessage(DioException e, String fallback) {
    final data = e.response?.data;
    final map = _asMap(data);
    final message = map['message'] ?? map['error'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
    return fallback.appTr;
  }

  void _toast({required String message, Color backgroundColor = Colors.black87}) {
    Fluttertoast.showToast(
      msg: message.appTr,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  static bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'completed' || s == 'success';
  }
}

class InviteHome {
  InviteHome({
    required this.setting,
    required this.inviteCode,
    required this.inviteLink,
    required this.stats,
    required this.milestones,
    required this.nextMilestone,
  });

  final InviteSetting setting;
  final String inviteCode;
  final String inviteLink;
  final InviteStats stats;
  final List<InviteMilestone> milestones;
  final InviteMilestone? nextMilestone;

  factory InviteHome.empty() => InviteHome(
    setting: InviteSetting.empty(),
    inviteCode: '',
    inviteLink: '',
    stats: InviteStats.empty(),
    milestones: <InviteMilestone>[],
    nextMilestone: null,
  );

  factory InviteHome.fromJson(Map<String, dynamic> json) {
    final milestones = InviteModelHelper.extractList(json, keys: ['milestones', 'rewards'])
        .map((item) => InviteMilestone.fromJson(InviteModelHelper.asMap(item)))
        .toList();

    final progressMap = InviteModelHelper.asMap(json['progress']);
    final nextRaw = json['next_milestone'] ??
        json['nextMilestone'] ??
        progressMap['next_milestone'] ??
        progressMap['nextMilestone'];

    return InviteHome(
      setting: InviteSetting.fromJson(InviteModelHelper.asMap(json['setting'])),
      inviteCode: InviteModelHelper.str(json['invite_code'] ?? json['reffer_code'] ?? json['referral_code'] ?? json['code']),
      inviteLink: InviteModelHelper.str(json['invite_link'] ?? json['referral_link'] ?? json['link']),
      stats: InviteStats.fromJson(
        InviteModelHelper.asMap(
          json['stats'] ??
              json['invite_stats'] ??
              json['summary'] ??
              json['progress'],
        ),
      ),
      milestones: milestones,
      nextMilestone: nextRaw == null ? null : InviteMilestone.fromJson(InviteModelHelper.asMap(nextRaw)),
    );
  }
}

class InviteSetting {
  InviteSetting({
    required this.title,
    required this.subtitle,
    required this.howItWorksTitle,
    required this.inviteBaseUrl,
    required this.shareText,
    required this.signupRewardCoins,
    required this.firstLiveRewardCoins,
    required this.milestoneTrigger,
    required this.rewardWallet,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String howItWorksTitle;
  final String inviteBaseUrl;
  final String shareText;
  final int signupRewardCoins;
  final int firstLiveRewardCoins;
  final String milestoneTrigger;
  final String rewardWallet;
  final int status;

  factory InviteSetting.empty() => InviteSetting(
    title: 'Invite Friends. Earn Rewards.',
    subtitle: 'The more friends you invite, the more you earn!',
    howItWorksTitle: 'How It Works',
    inviteBaseUrl: '',
    shareText: 'Join LIN LIVE using my invite link and earn rewards!',
    signupRewardCoins: 0,
    firstLiveRewardCoins: 0,
    milestoneTrigger: 'first_live',
    rewardWallet: 'earned_coins',
    status: 1,
  );

  factory InviteSetting.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return InviteSetting.empty();
    final fallback = InviteSetting.empty();
    return InviteSetting(
      title: InviteModelHelper.str(json['title'], fallback.title),
      subtitle: InviteModelHelper.str(json['subtitle'], fallback.subtitle),
      howItWorksTitle: InviteModelHelper.str(json['how_it_works_title'], fallback.howItWorksTitle),
      inviteBaseUrl: InviteModelHelper.str(json['invite_base_url']),
      shareText: InviteModelHelper.str(json['share_text'], fallback.shareText),
      signupRewardCoins: InviteModelHelper.toInt(json['signup_reward_coins']),
      firstLiveRewardCoins: InviteModelHelper.toInt(json['first_live_reward_coins']),
      milestoneTrigger: InviteModelHelper.str(json['milestone_trigger'], fallback.milestoneTrigger),
      rewardWallet: InviteModelHelper.str(json['reward_wallet'], fallback.rewardWallet),
      status: InviteModelHelper.toInt(json['status'], fallback.status),
    );
  }
}

class InviteStats {
  InviteStats({
    required this.totalInvites,
    required this.completedFriends,
    required this.totalRewardCoins,
    required this.pendingFriends,
    required this.walletCoins,
    required this.earnedCoins,
  });

  final int totalInvites;
  final int completedFriends;
  final int totalRewardCoins;
  final int pendingFriends;
  final int? walletCoins;
  final int? earnedCoins;

  factory InviteStats.empty() => InviteStats(
    totalInvites: 0,
    completedFriends: 0,
    totalRewardCoins: 0,
    pendingFriends: 0,
    walletCoins: null,
    earnedCoins: null,
  );

  factory InviteStats.fromJson(Map<String, dynamic> json) {
    final int totalInvites = InviteModelHelper.toInt(
      json['total_joined_friends'] ??
          json['total_invites'] ??
          json['total_friends'] ??
          json['invited_friends_count'] ??
          json['invites_count'] ??
          json['invited_count'] ??
          json['successful_invites'] ??
          json['successful_invites_count'] ??
          json['referral_count'] ??
          json['friends_count'],
    );

    final int completedFriends = InviteModelHelper.toInt(
      json['total_live_friends'] ??
          json['completed_friends'] ??
          json['first_live_friends'] ??
          json['qualified_friends'] ??
          json['completed_invites'] ??
          json['qualified_invites'] ??
          json['first_live_count'] ??
          json['first_live_completed_count'],
    );

    final dynamic pendingRaw = json['pending_friends'] ??
        json['pending_invites'] ??
        json['remaining_invites'];

    final int pendingFriends = pendingRaw == null
        ? (totalInvites - completedFriends).clamp(0, totalInvites).toInt()
        : InviteModelHelper.toInt(pendingRaw);

    return InviteStats(
      totalInvites: totalInvites,
      completedFriends: completedFriends,
      totalRewardCoins: InviteModelHelper.toInt(
        json['total_reward_coins'] ??
            json['total_rewards'] ??
            json['reward_coins'],
      ),
      pendingFriends: pendingFriends,
      walletCoins: json.containsKey('coins')
          ? InviteModelHelper.toInt(json['coins'])
          : null,
      earnedCoins: json.containsKey('earned_coins')
          ? InviteModelHelper.toInt(json['earned_coins'])
          : null,
    );
  }
}

class InviteMilestone {
  InviteMilestone({
    required this.id,
    required this.title,
    required this.friendsCount,
    required this.rewardCoins,
    required this.iconImageUrl,
    required this.completed,
    required this.remainingFriends,
    required this.currentFriends,
  });

  final int id;
  final String title;
  final int friendsCount;
  final int rewardCoins;
  final String iconImageUrl;
  final bool completed;
  final int remainingFriends;
  final int currentFriends;

  int get apiCompletedFriends {
    if (friendsCount <= 0) return 0;

    if (currentFriends > 0) {
      return currentFriends.clamp(0, friendsCount).toInt();
    }

    if (completed) return friendsCount;

    if (remainingFriends > 0 && remainingFriends <= friendsCount) {
      return (friendsCount - remainingFriends).clamp(0, friendsCount).toInt();
    }

    return 0;
  }

  factory InviteMilestone.fromJson(Map<String, dynamic> json) {
    final int target = InviteModelHelper.toInt(
      json['friends_count'] ??
          json['friends'] ??
          json['required_friends'] ??
          json['required_invites'] ??
          json['invite_count'] ??
          json['target_count'] ??
          json['required_count'] ??
          json['friend_count'] ??
          json['invite_target'] ??
          json['milestone_count'] ??
          json['target'],
    );

    final int current = InviteModelHelper.toInt(
      json['current_friends'] ??
          json['completed_friends'] ??
          json['current_invites'] ??
          json['completed_invites'] ??
          json['progress_count'] ??
          json['achieved_count'] ??
          json['progress'] ??
          json['done_count'],
    );

    int remaining = InviteModelHelper.toInt(
      json['remaining_friends'] ??
          json['remaining'] ??
          json['remaining_invites'] ??
          json['need_more_friends'] ??
          json['need_more_invites'],
    );

    if (remaining <= 0 && target > 0 && current > 0) {
      remaining = (target - current).clamp(0, target).toInt();
    }

    final bool completed = InviteModelHelper.truthy(
      json['completed'] ??
          json['is_completed'] ??
          json['status_completed'] ??
          json['claimed'] ??
          json['is_claimed'] ??
          json['status'],
    );

    return InviteMilestone(
      id: InviteModelHelper.toInt(json['id'] ?? json['milestone_id']),
      title: InviteModelHelper.str(
        json['title'] ?? json['name'],
        '$target Friends',
      ),
      friendsCount: target,
      rewardCoins: InviteModelHelper.toInt(
        json['reward_coins'] ??
            json['coins'] ??
            json['reward'] ??
            json['coin_reward'] ??
            json['reward_amount'] ??
            json['coin_amount'],
      ),
      iconImageUrl: InviteModelHelper.str(
        json['icon_image_url'] ??
            json['icon_url'] ??
            json['image_url'] ??
            json['image'],
      ),
      completed: completed,
      remainingFriends: completed ? 0 : remaining,
      currentFriends: completed ? target : current,
    );
  }
}

class InviteFriend {
  InviteFriend({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.profileImage,
    required this.createdAt,
    required this.firstLiveAt,
    required this.status,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String profileImage;
  final String createdAt;
  final String firstLiveAt;
  final String status;

  bool get firstLiveDone => firstLiveAt.trim().isNotEmpty || status.toLowerCase().contains('complete');

  factory InviteFriend.fromJson(Map<String, dynamic> json) {
    final user = InviteModelHelper.asMap(
      json['invited_user'] ?? json['user'] ?? json['friend'] ?? json['receiver'],
    );
    final source = user.isNotEmpty ? user : json;

    return InviteFriend(
      id: InviteModelHelper.toInt(source['id'] ?? source['user_id'] ?? json['invited_user_id']),
      name: InviteModelHelper.str(source['name'] ?? source['full_name'] ?? source['display_name'], 'Unknown User'),
      username: InviteModelHelper.str(source['username'] ?? source['user_name'] ?? source['unique_id']),
      email: InviteModelHelper.str(source['email'] ?? source['phone']),
      profileImage: InviteModelHelper.str(source['profile_image_url'] ?? source['profile_image'] ?? source['image']),
      createdAt: InviteModelHelper.str(json['created_at'] ?? json['joined_at'] ?? source['created_at']),
      firstLiveAt: InviteModelHelper.str(json['first_live_at'] ?? source['first_live_at']),
      status: InviteModelHelper.str(json['status'] ?? json['reward_status']),
    );
  }
}

class InviteRewardLog {
  InviteRewardLog({
    required this.id,
    required this.type,
    required this.title,
    required this.coins,
    required this.wallet,
    required this.createdAt,
    required this.friendName,
  });

  final int id;
  final String type;
  final String title;
  final int coins;
  final String wallet;
  final String createdAt;
  final String friendName;

  factory InviteRewardLog.fromJson(Map<String, dynamic> json) {
    final user = InviteModelHelper.asMap(
      json['invited_user'] ?? json['user'] ?? json['friend'],
    );

    final type = InviteModelHelper.str(json['reward_type'] ?? json['type'] ?? json['trigger'], 'reward');

    return InviteRewardLog(
      id: InviteModelHelper.toInt(json['id']),
      type: type,
      title: InviteModelHelper.str(json['title'] ?? json['message'], _typeTitle(type)),
      coins: InviteModelHelper.toInt(json['coins'] ?? json['reward_coins'] ?? json['amount']),
      wallet: InviteModelHelper.str(json['wallet'] ?? json['reward_wallet']),
      createdAt: InviteModelHelper.str(json['created_at'] ?? json['date']),
      friendName: InviteModelHelper.str(user['name'] ?? user['username'] ?? json['friend_name']),
    );
  }

  static String _typeTitle(String type) {
    final clean = type.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return 'Invite Reward';
    return clean.split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}

class InviteModelHelper {
  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static List<dynamic> extractList(dynamic value, {List<String> keys = const []}) {
    if (value is List) return List<dynamic>.from(value);
    final map = asMap(value);
    for (final key in keys) {
      final found = map[key];
      if (found is List) return List<dynamic>.from(found);
      if (found is Map && found['data'] is List) return List<dynamic>.from(found['data']);
    }
    if (map['data'] is List) return List<dynamic>.from(map['data']);
    if (map['data'] is Map && map['data']['data'] is List) {
      return List<dynamic>.from(map['data']['data']);
    }
    return <dynamic>[];
  }

  static String str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.trim().isEmpty || text == 'null' ? fallback : text;
  }

  static int toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'completed' || s == 'success';
  }
}
