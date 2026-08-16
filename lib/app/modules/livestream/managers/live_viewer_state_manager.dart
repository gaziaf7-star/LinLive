import 'package:get/get.dart';

/// Authoritative live viewer state.
///
/// User identity must come from viewer_id/user_id/user.id.
/// Never use livestream_viewers.id as the primary user identity.
class LiveViewerStateManager {
  LiveViewerStateManager(this.target, {this.excludedUserId});

  final RxList<dynamic> target;
  final int Function()? excludedUserId;
  int _revision = 0;
  final Map<int, int> _lastTransitionRevision = <int, int>{};
  final Set<int> _absentUserIds = <int>{};
  final List<int> _lastBlockedRestoreUserIds = <int>[];

  List<int> get lastBlockedRestoreUserIds =>
      List<int>.unmodifiable(_lastBlockedRestoreUserIds);

  /// Capture this immediately before starting an asynchronous snapshot request.
  /// A later replacement will preserve every join/leave received after it.
  int beginSnapshot() => _revision;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  int userIdOf(dynamic raw) {
    final item = _map(raw);
    final user = _map(item['user']);
    final viewer = _map(item['viewer']);

    return _toInt(
      item['viewer_id'] ??
          item['user_id'] ??
          item['caller_id'] ??
          user['id'] ??
          user['user_id'] ??
          viewer['viewer_id'] ??
          viewer['user_id'] ??
          viewer['id'],
    );
  }

  bool containsUser(dynamic rawUserId) {
    final userId = _toInt(rawUserId);
    return userId > 0 && target.any((item) => userIdOf(item) == userId);
  }

  bool _isExcluded(int userId) =>
      userId > 0 && userId == (excludedUserId?.call() ?? 0);

  bool _isActive(Map<String, dynamic> item) {
    if (!item.containsKey('is_active')) return true;

    final value = item['is_active'];
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;

    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'active';
  }

  bool _usable(dynamic value) {
    if (value == null) return false;
    if (value is Map || value is List) return true;

    final text = value.toString().trim().toLowerCase();
    return text.isNotEmpty && text != 'null';
  }

  Map<String, dynamic> _merge(
    Map<String, dynamic> oldValue,
    Map<String, dynamic> newValue,
  ) {
    final result = <String, dynamic>{...oldValue};

    for (final entry in newValue.entries) {
      if (_usable(entry.value)) result[entry.key] = entry.value;
    }

    final oldUser = _map(oldValue['user']);
    final newUser = _map(newValue['user']);

    if (oldUser.isNotEmpty || newUser.isNotEmpty) {
      final mergedUser = <String, dynamic>{...oldUser};

      for (final entry in newUser.entries) {
        if (_usable(entry.value)) mergedUser[entry.key] = entry.value;
      }

      result['user'] = mergedUser;
    }

    return result;
  }

  void addOrUpdate(dynamic raw, {bool force = false}) {
    final item = _map(raw);
    final userId = userIdOf(item);

    if (userId <= 0 || _isExcluded(userId)) {
      if (_isExcluded(userId)) {
        target.removeWhere((e) => userIdOf(e) == userId);
        target.refresh();
      }
      return;
    }

    if (!_isActive(item) && !force) {
      removeByUserId(userId);
      return;
    }

    _revision++;
    _lastTransitionRevision[userId] = _revision;
    _absentUserIds.remove(userId);

    final index = target.indexWhere((e) => userIdOf(e) == userId);

    if (index < 0) {
      target.add(item);
    } else {
      target[index] = _merge(_map(target[index]), item);
    }

    _deduplicate();
    target.refresh();
  }

  void removeByUserId(dynamic rawUserId) {
    final userId = _toInt(rawUserId);
    if (userId <= 0) return;

    _revision++;
    _lastTransitionRevision[userId] = _revision;
    _absentUserIds.add(userId);
    target.removeWhere((e) => userIdOf(e) == userId);
    target.refresh();
  }

  int replaceAll(dynamic rawList, {int? snapshotRevision}) {
    final list = rawList is List ? rawList : const <dynamic>[];
    final Map<int, Map<String, dynamic>> unique = {};
    _lastBlockedRestoreUserIds.clear();

    for (final raw in list) {
      final item = _map(raw);
      final userId = userIdOf(item);

      if (userId <= 0 || _isExcluded(userId) || !_isActive(item)) continue;
      if (_absentUserIds.contains(userId)) {
        _lastBlockedRestoreUserIds.add(userId);
        continue;
      }

      final existing = unique[userId];
      unique[userId] = existing == null ? item : _merge(existing, item);
    }

    int protectedTransitions = 0;
    if (snapshotRevision != null) {
      final current = <int, Map<String, dynamic>>{};
      for (final raw in target) {
        final item = _map(raw);
        final userId = userIdOf(item);
        if (userId > 0 && !_isExcluded(userId)) current[userId] = item;
      }

      for (final entry in _lastTransitionRevision.entries) {
        if (entry.value <= snapshotRevision) continue;
        protectedTransitions++;
        final newerLocalValue = current[entry.key];
        if (newerLocalValue == null) {
          unique.remove(entry.key);
        } else {
          unique[entry.key] = newerLocalValue;
        }
      }
    }

    target.assignAll(unique.values.toList(growable: false));
    target.refresh();
    return protectedTransitions;
  }

  void applyState(dynamic rawState) {
    final state = _map(rawState);
    final live = _map(state['livestream']);

    final bool hasList =
        state.containsKey('viewers') ||
        state.containsKey('livestream_viewers') ||
        live.containsKey('viewers') ||
        live.containsKey('livestream_viewers');

    if (!hasList) return;

    replaceAll(
      state['viewers'] ??
          state['livestream_viewers'] ??
          live['viewers'] ??
          live['livestream_viewers'],
    );
  }

  void clear() {
    _revision++;
    _lastTransitionRevision.clear();
    _absentUserIds.clear();
    _lastBlockedRestoreUserIds.clear();
    target.clear();
    target.refresh();
  }

  bool removeExcludedUser() {
    final userId = excludedUserId?.call() ?? 0;
    if (userId <= 0) return false;
    final before = target.length;
    target.removeWhere((item) => userIdOf(item) == userId);
    if (target.length == before) return false;
    target.refresh();
    return true;
  }

  void _deduplicate() {
    final Map<int, Map<String, dynamic>> unique = {};

    for (final raw in target) {
      final item = _map(raw);
      final userId = userIdOf(item);
      if (userId <= 0 || _isExcluded(userId)) continue;

      final existing = unique[userId];
      unique[userId] = existing == null ? item : _merge(existing, item);
    }

    target.assignAll(unique.values.toList(growable: false));
  }
}
