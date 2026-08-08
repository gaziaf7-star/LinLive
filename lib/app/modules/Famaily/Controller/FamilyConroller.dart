import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../constants/constants.dart';
import '../Models/family_models.dart';
import '../Repository/family_repository.dart';

enum FamilyPageStatus { idle, loading, success, empty, error }

class FamilyController extends GetxController {
  late final FamilyRepository _repo;

  final myFamily = Rxn<FamilyModel>();
  final selectedFamily = Rxn<FamilyModel>();

  final familyList = <FamilyModel>[].obs;
  final rankingList = <FamilyModel>[].obs;
  final requests = <FamilyRequestModel>[].obs;
  final ownRequests = <FamilyRequestModel>[].obs;
  final levels = <FamilyLevelModel>[].obs;
  final badges = <FamilyBadgeModel>[].obs;
  final announcements = <FamilyAnnouncementModel>[].obs;
  final coinLogs = <FamilyCoinLogModel>[].obs;

  final Rx<FamilyPageStatus> homeStatus = FamilyPageStatus.idle.obs;
  final Rx<FamilyPageStatus> listStatus = FamilyPageStatus.idle.obs;
  final Rx<FamilyPageStatus> rankingStatus = FamilyPageStatus.idle.obs;
  final Rx<FamilyPageStatus> requestStatus = FamilyPageStatus.idle.obs;
  final Rx<FamilyPageStatus> detailStatus = FamilyPageStatus.idle.obs;

  final isActionLoading = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = ''.obs;
  final search = ''.obs;
  final sort = 'ranking'.obs;
  final page = 1.obs;
  final hasMore = true.obs;

  Timer? _searchDebounce;
  Timer? _realtimeTimer;

  // Foreground-only fast sync. This is intentionally adaptive so the family
  // home feels realtime without continuously hitting every endpoint.
  static const Duration _realtimeTickInterval = Duration(seconds: 2);
  static const Duration _homeRealtimeInterval = Duration(seconds: 4);
  static const Duration _rankingRealtimeInterval = Duration(seconds: 10);
  static const Duration _requestRealtimeInterval = Duration(seconds: 6);

  bool _realtimePaused = false;
  bool _realtimeTickInProgress = false;

  DateTime? _lastHomeRealtimeAt;
  DateTime? _lastRankingRealtimeAt;
  DateTime? _lastRequestRealtimeAt;

  Future<void>? _homeLoadFuture;
  Future<void>? _rankingLoadFuture;
  final Map<String, Future<void>> _requestLoadFutures =
  <String, Future<void>>{};

  @override
  void onInit() {
    super.onInit();
    _repo = FamilyRepository(tokenProvider: _token);
    debounce<String>(search, (_) => loadFamilyList(refresh: true), time: const Duration(milliseconds: 450));
    loadHome();
    loadFamilyList(refresh: true);
    loadRanking();
  }

  String _token() {
    try {
      final dynamic profile = authController.userProfile.value;
      final dynamic token = profile.token;
      return token?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static const int familyCreateCost = 200000;

  bool get hasFamily => myFamily.value != null;

  int get currentUserId {
    try {
      final dynamic profile = authController.userProfile.value;

      if (profile is Map) {
        final dynamic user = profile['user'] ?? profile['data'];
        if (user is Map) {
          return FamilyParse.toInt(
            user['id'] ?? user['user_id'] ?? profile['id'] ?? profile['user_id'],
          );
        }
        return FamilyParse.toInt(profile['id'] ?? profile['user_id']);
      }

      final dynamic user = _safeRead(() => profile.user);
      if (user is Map) {
        return FamilyParse.toInt(user['id'] ?? user['user_id']);
      }

      return FamilyParse.toInt(
        _safeRead(() => user.id) ??
            _safeRead(() => user.userId) ??
            _safeRead(() => user.user_id) ??
            _safeRead(() => profile.id) ??
            _safeRead(() => profile.userId) ??
            _safeRead(() => profile.user_id),
      );
    } catch (_) {
      return 0;
    }
  }

  String get currentFamilyRole {
    final family = myFamily.value;
    if (family == null) return '';

    final directRole = family.myRole.trim().toLowerCase();
    if (directRole.isNotEmpty) return directRole;

    final uid = currentUserId;
    if (uid <= 0) return '';

    for (final member in family.members) {
      if (member.userId == uid) {
        return member.role.trim().toLowerCase();
      }
    }

    return '';
  }

  bool get isOwner {
    final family = myFamily.value;
    if (family == null) return false;

    final role = currentFamilyRole;
    if (role == 'owner') return true;

    final uid = currentUserId;
    return uid > 0 && family.ownerId > 0 && uid == family.ownerId;
  }

  bool get isAdmin {
    final role = currentFamilyRole;
    return isOwner || role == 'admin';
  }

  bool get canManageFamily => isAdmin;
  bool get canEditFamily => canManageFamily;
  bool get canManageRequests => canManageFamily;
  bool get canChangeRoles => canManageFamily;

  bool canManageMember(FamilyMemberModel member) {
    if (!canManageFamily) return false;
    if (member.role.trim().toLowerCase() == 'owner') return false;
    final uid = currentUserId;
    if (uid > 0 && member.userId == uid) return false;
    return member.id > 0;
  }

  bool canKickFamilyMember(FamilyMemberModel member) => canManageMember(member);

  double get userAvailableCoins {
    try {
      final dynamic profile = authController.userProfile.value;

      if (profile is Map) {
        final dynamic user = profile['user'] ?? profile['data'];
        if (user is Map) {
          return FamilyParse.toDouble(
            user['coins'] ?? user['balance'] ?? user['coin'] ?? user['wallet'] ?? profile['coins'] ?? profile['balance'],
          );
        }
        return FamilyParse.toDouble(profile['coins'] ?? profile['balance'] ?? profile['coin'] ?? profile['wallet']);
      }

      final dynamic user = _safeRead(() => profile.user);

      if (user is Map) {
        return FamilyParse.toDouble(user['coins'] ?? user['balance'] ?? user['coin'] ?? user['wallet']);
      }

      final dynamic value =
          _safeRead(() => user.coins) ??
              _safeRead(() => user.balance) ??
              _safeRead(() => user.coin) ??
              _safeRead(() => user.wallet) ??
              _safeRead(() => profile.coins) ??
              _safeRead(() => profile.balance) ??
              _safeRead(() => profile.coin) ??
              _safeRead(() => profile.wallet);

      return FamilyParse.toDouble(value);
    } catch (_) {
      return 0;
    }
  }

  bool get canCreateFamily => !hasFamily && userAvailableCoins >= familyCreateCost;

  dynamic _safeRead(dynamic Function() reader) {
    try {
      return reader();
    } catch (_) {
      return null;
    }
  }

  Future<void> loadHome({bool silent = false}) async {
    final running = _homeLoadFuture;
    if (running != null) {
      await running;
      return;
    }

    final Future<void> request = _safeRun(
      loadingStatus: homeStatus,
      silent: silent,
      task: () async {
        final data = await _repo.myFamily();

        // Rxn assignment immediately rebuilds every Obx that reads myFamily.
        myFamily.value = data;

        if (data != null) {
          announcements.assignAll(data.announcements);
          if (data.id > 0 && announcements.isEmpty) {
            unawaited(loadAnnouncements(data.id, silent: true));
          }
        } else {
          announcements.clear();
        }

        homeStatus.value =
        data == null ? FamilyPageStatus.empty : FamilyPageStatus.success;
      },
    );

    _homeLoadFuture = request;
    try {
      await request;
    } finally {
      if (identical(_homeLoadFuture, request)) {
        _homeLoadFuture = null;
      }
    }
  }

  Future<void> refreshAll() async {
    if (isRefreshing.value) return;

    isRefreshing.value = true;
    try {
      await Future.wait([
        loadHome(silent: true),
        loadFamilyList(refresh: true, silent: true),
        loadRanking(silent: true),
      ]);

      final now = DateTime.now();
      _lastHomeRealtimeAt = now;
      _lastRankingRealtimeAt = now;

      final familyId = myFamily.value?.id ?? 0;
      if (familyId > 0 && canManageRequests) {
        await loadRequests(familyId: familyId, silent: true);
        _lastRequestRealtimeAt = DateTime.now();
      }
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> loadFamilyList({bool refresh = false, bool silent = false}) async {
    if (refresh) {
      page.value = 1;
      hasMore.value = true;
    }
    if (!hasMore.value && !refresh) return;

    await _safeRun(
      loadingStatus: listStatus,
      silent: silent || (!refresh && familyList.isNotEmpty),
      task: () async {
        final list = await _repo.familyList(
          search: search.value,
          sort: sort.value,
          page: page.value,
          perPage: 20,
        );
        if (refresh) familyList.clear();
        familyList.addAll(list);
        hasMore.value = list.length >= 20;
        if (hasMore.value) page.value++;
        listStatus.value = familyList.isEmpty ? FamilyPageStatus.empty : FamilyPageStatus.success;
      },
    );
  }

  Future<void> loadRanking({bool silent = false}) async {
    final running = _rankingLoadFuture;
    if (running != null) {
      await running;
      return;
    }

    final Future<void> request = _safeRun(
      loadingStatus: rankingStatus,
      silent: silent,
      task: () async {
        final list = await _repo.ranking(perPage: 50);
        rankingList.assignAll(list);
        rankingStatus.value = rankingList.isEmpty
            ? FamilyPageStatus.empty
            : FamilyPageStatus.success;
      },
    );

    _rankingLoadFuture = request;
    try {
      await request;
    } finally {
      if (identical(_rankingLoadFuture, request)) {
        _rankingLoadFuture = null;
      }
    }
  }

  Future<void> loadFamilyDetail(int familyId, {bool silent = false}) async {
    await _safeRun(
      loadingStatus: detailStatus,
      silent: silent,
      task: () async {
        selectedFamily.value = await _repo.familyDetail(familyId);
        detailStatus.value = FamilyPageStatus.success;
      },
    );
  }

  Future<void> loadRequests({
    int? familyId,
    String status = 'pending',
    bool silent = false,
  }) async {
    final String requestKey = '${familyId ?? 0}:$status';
    final running = _requestLoadFutures[requestKey];

    if (running != null) {
      await running;
      return;
    }

    final Future<void> request = _safeRun(
      loadingStatus: requestStatus,
      silent: silent,
      task: () async {
        final list = await _repo.requestList(
          familyId: familyId,
          status: status,
        );

        if (familyId == null) {
          ownRequests.assignAll(list);
        } else {
          requests.assignAll(list);
        }

        requestStatus.value = list.isEmpty
            ? FamilyPageStatus.empty
            : FamilyPageStatus.success;
      },
    );

    _requestLoadFutures[requestKey] = request;
    try {
      await request;
    } finally {
      if (identical(_requestLoadFutures[requestKey], request)) {
        _requestLoadFutures.remove(requestKey);
      }
    }
  }

  Future<bool> joinFamily(int familyId, {String message = ''}) async {
    return _action(() async {
      await _repo.joinFamily(familyId, message: message);
      await Future.wait([loadFamilyList(refresh: true, silent: true), loadFamilyDetail(familyId, silent: true), loadHome(silent: true)]);
      _snack('Success', 'Family join request sent successfully.');
    });
  }

  Future<bool> leaveFamily() async {
    return _action(() async {
      await _repo.leaveFamily();
      myFamily.value = null;
      await loadFamilyList(refresh: true, silent: true);
      _snack('Success', 'You left the family successfully.');
    });
  }

  Future<bool> createFamily({
    required String name,
    String familyCode = '',
    String description = '',
    String notice = '',
    String joinType = 'approval',
    String country = '',
    File? logo,
    File? cover,
  }) async {
    await _printCreatePayload(
      name: name,
      familyCode: familyCode,
      description: description,
      notice: notice,
      joinType: joinType,
      country: country,
      logo: logo,
      cover: cover,
    );

    if (hasFamily) {
      _snack('Family Exists', 'You already have a family. Leave your current family before creating a new one.', isError: true);
      return false;
    }

    if (userAvailableCoins < familyCreateCost) {
      _snack('Not Enough Coins', 'You need 200,000 coins to create a family.', isError: true);
      return false;
    }

    return _action(() async {
      final created = await _repo.createFamily(
        name: name,
        familyCode: familyCode,
        description: description,
        notice: notice,
        joinType: joinType,
        country: country,
        logo: logo,
        cover: cover,
      );
      myFamily.value = created;

      await Future.wait([
        loadHome(silent: true),
        loadFamilyList(refresh: true, silent: true),
      ]);
      _snack('Success', 'Family created successfully.');
    });
  }

  Future<bool> updateFamily({
    required int familyId,
    required String name,
    String familyCode = '',
    String description = '',
    String notice = '',
    String joinType = 'approval',
    String country = '',
    File? logo,
    File? cover,
  }) async {
    if (!canEditFamily) {
      _snack('Permission Denied', 'Only family owner/admin can edit family information.', isError: true);
      return false;
    }

    return _action(() async {
      final updated = await _repo.updateFamily(
        familyId: familyId,
        name: name,
        familyCode: familyCode,
        description: description,
        notice: notice,
        joinType: joinType,
        country: country,
        logo: logo,
        cover: cover,
      );
      myFamily.value = updated;
      selectedFamily.value = updated;
      await Future.wait([
        loadHome(silent: true),
        loadFamilyList(refresh: true, silent: true),
        loadRanking(silent: true),
      ]);
      _snack('Success', 'Family updated successfully.');
    });
  }

  Future<bool> acceptRequest(int requestId) async {
    if (!canManageRequests) {
      _snack('Permission Denied', 'Only family owner/admin can accept requests.', isError: true);
      return false;
    }

    return _action(() async {
      await _repo.acceptRequest(requestId);
      requests.removeWhere((e) => e.id == requestId);
      await Future.wait([
        loadHome(silent: true),
        loadFamilyList(refresh: true, silent: true),
        loadRanking(silent: true),
      ]);
      _snack('Accepted', 'Member request accepted.');
    });
  }

  Future<bool> rejectRequest(int requestId) async {
    if (!canManageRequests) {
      _snack('Permission Denied', 'Only family owner/admin can reject requests.', isError: true);
      return false;
    }

    return _action(() async {
      await _repo.rejectRequest(requestId);
      requests.removeWhere((e) => e.id == requestId);
      _snack('Rejected', 'Member request rejected.');
    });
  }

  Future<bool> cancelRequest(int requestId) async {
    return _action(() async {
      await _repo.cancelRequest(requestId);
      ownRequests.removeWhere((e) => e.id == requestId);
      await loadFamilyList(refresh: true, silent: true);
      _snack('Cancelled', 'Pending request cancelled.');
    });
  }

  Future<bool> kickMember(int memberId) async {
    if (!canManageFamily) {
      _snack('Permission Denied', 'Only family owner/admin can kick members.', isError: true);
      return false;
    }

    if (memberId <= 0) {
      _snack('Invalid Member', 'Member information is missing. Please refresh and try again.', isError: true);
      return false;
    }

    return _action(() async {
      await _repo.kickMember(memberId);
      await Future.wait([
        loadHome(silent: true),
        loadRanking(silent: true),
      ]);
      _snack('Removed', 'Member removed successfully.');
    });
  }

  Future<bool> changeRole(int memberId, String role) async {
    if (!canChangeRoles) {
      _snack('Permission Denied', 'Only family owner/admin can change member roles.', isError: true);
      return false;
    }

    if (role != 'admin' && role != 'member') {
      _snack('Invalid Role', 'Role must be admin or member.', isError: true);
      return false;
    }

    return _action(() async {
      await _repo.changeMemberRole(memberId, role);
      await loadHome(silent: true);
      _snack('Updated', 'Member role updated.');
    });
  }

  Future<void> loadLevels() async {
    await _safeRun(task: () async => levels.assignAll(await _repo.levelList()));
  }

  Future<void> loadBadges() async {
    await _safeRun(task: () async => badges.assignAll(await _repo.badgeList()));
  }

  Future<void> loadAnnouncements(int familyId, {bool silent = false}) async {
    await _safeRun(silent: silent, task: () async => announcements.assignAll(await _repo.announcements(familyId)));
  }

  Future<void> loadCoinLogs() async {
    await _safeRun(task: () async => coinLogs.assignAll(await _repo.coinLogs()));
  }

  Future<bool> contribute({required int points, int coins = 0, required String actionType, String note = ''}) async {
    return _action(() async {
      await _repo.contribute(points: points, coins: coins, actionType: actionType, note: note);
      await loadHome(silent: true);
    }, showSuccess: false);
  }

  void updateSearch(String value) => search.value = value;

  void changeSort(String value) {
    if (sort.value == value) return;
    sort.value = value;
    loadFamilyList(refresh: true);
  }

  /// Fast foreground sync for the family system.
  ///
  /// The provided backend files do not expose a family WebSocket event, so this
  /// uses lightweight adaptive polling:
  /// - home/stat/contributor data: every 4 seconds
  /// - owner/admin requests: every 6 seconds
  /// - ranking: every 10 seconds
  ///
  /// Only one tick and one request per endpoint can run at a time.
  void startRealtime({bool forceImmediate = true}) {
    _realtimePaused = false;
    _realtimeTimer?.cancel();

    if (forceImmediate) {
      unawaited(syncRealtimeNow(force: true));
    }

    _realtimeTimer = Timer.periodic(
      _realtimeTickInterval,
          (_) => unawaited(syncRealtimeNow()),
    );
  }

  void pauseRealtime() {
    _realtimePaused = true;
  }

  void resumeRealtime() {
    _realtimePaused = false;

    if (_realtimeTimer == null || !_realtimeTimer!.isActive) {
      startRealtime(forceImmediate: false);
    }

    unawaited(syncRealtimeNow(force: true));
  }

  Future<void> syncRealtimeNow({bool force = false}) async {
    if (_realtimePaused || _realtimeTickInProgress) return;
    if (_token().trim().isEmpty) return;

    _realtimeTickInProgress = true;

    try {
      final now = DateTime.now();

      final bool homeDue = force ||
          _lastHomeRealtimeAt == null ||
          now.difference(_lastHomeRealtimeAt!) >= _homeRealtimeInterval;

      if (homeDue) {
        _lastHomeRealtimeAt = now;
        await loadHome(silent: true);
      }

      final List<Future<void>> secondaryTasks = <Future<void>>[];

      final bool rankingDue = force ||
          _lastRankingRealtimeAt == null ||
          now.difference(_lastRankingRealtimeAt!) >=
              _rankingRealtimeInterval;

      if (rankingDue) {
        _lastRankingRealtimeAt = now;
        secondaryTasks.add(loadRanking(silent: true));
      }

      final int familyId = myFamily.value?.id ?? 0;
      final bool requestDue = force ||
          _lastRequestRealtimeAt == null ||
          now.difference(_lastRequestRealtimeAt!) >=
              _requestRealtimeInterval;

      if (familyId > 0 && canManageRequests && requestDue) {
        _lastRequestRealtimeAt = now;
        secondaryTasks.add(
          loadRequests(
            familyId: familyId,
            silent: true,
          ),
        );
      }

      if (secondaryTasks.isNotEmpty) {
        await Future.wait(secondaryTasks);
      }
    } finally {
      _realtimeTickInProgress = false;
    }
  }

  void stopRealtime() {
    _realtimePaused = true;
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  Future<void> _safeRun({
    Rx<FamilyPageStatus>? loadingStatus,
    bool silent = false,
    required Future<void> Function() task,
  }) async {
    try {
      if (!silent) {
        errorMessage.value = '';
      }

      if (!silent && loadingStatus != null) {
        loadingStatus.value = FamilyPageStatus.loading;
      }

      await task();
    } on FamilyApiException catch (e) {
      // A temporary silent realtime failure must not replace already visible
      // family data with an error screen.
      if (!silent) {
        errorMessage.value = e.message;
        if (loadingStatus != null) {
          loadingStatus.value = FamilyPageStatus.error;
        }
        _snack('Error', e.message, isError: true);
      } else if (kDebugMode) {
        debugPrint('Family silent sync API error: ${e.message}');
      }
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('FamilyController error: $e\n$s');
      }

      if (!silent) {
        errorMessage.value = 'Something went wrong. Please try again.';
        if (loadingStatus != null) {
          loadingStatus.value = FamilyPageStatus.error;
        }
        _snack('Error', errorMessage.value, isError: true);
      }
    }
  }

  Future<void> _printCreatePayload({
    required String name,
    required String familyCode,
    required String description,
    required String notice,
    required String joinType,
    required String country,
    File? logo,
    File? cover,
  }) async {
    final logoInfo = await _fileInfo(logo);
    final coverInfo = await _fileInfo(cover);

    debugPrint('================ CREATE FAMILY CONTROLLER PAYLOAD ================');
    debugPrint('name: $name');
    debugPrint('family_code: $familyCode');
    debugPrint('description: $description');
    debugPrint('notice: $notice');
    debugPrint('join_type: $joinType');
    debugPrint('country: $country');
    debugPrint('has_family: $hasFamily');
    debugPrint('current_user_id: $currentUserId');
    debugPrint('user_available_coins: $userAvailableCoins');
    debugPrint('create_cost: $familyCreateCost');
    debugPrint('can_create_family: $canCreateFamily');
    debugPrint('logo: $logoInfo');
    debugPrint('cover: $coverInfo');
    debugPrint('==================================================================');
  }

  Future<String> _fileInfo(File? file) async {
    if (file == null) return 'NULL';

    try {
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      return 'path=${file.path}, exists=$exists, size_bytes=$size';
    } catch (e) {
      return 'path=${file.path}, read_error=$e';
    }
  }

  Future<bool> _action(Future<void> Function() task, {bool showSuccess = true}) async {
    if (isActionLoading.value) return false;
    isActionLoading.value = true;
    try {
      await task();
      return true;
    } on FamilyApiException catch (e) {
      _snack('Error', e.message, isError: true);
      return false;
    } catch (e, s) {
      if (kDebugMode) debugPrint('Family action error: $e\n$s');
      _snack('Error', 'Action failed. Please try again.', isError: true);
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  void _snack(String title, String message, {bool isError = false}) {
    final text = title.trim().isEmpty ? message : '$title: $message';
    debugPrint('[FAMILY_TOAST] ${isError ? 'ERROR' : 'SUCCESS'} => $text');

    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _realtimeTimer?.cancel();
    _requestLoadFutures.clear();
    super.onClose();
  }
}

/// Backward compatible with your current typo class name/file name.
class Familyconroller extends FamilyController {}
