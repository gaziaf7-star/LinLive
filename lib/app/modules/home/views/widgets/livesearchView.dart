import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/color_constants.dart';
import '../../../../../constants/image_helper.dart';
import '../../../../../constants/layout_constant.dart';
import '../../controllers/home_controller.dart';
import '../all_live_live_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveSearchView extends StatefulWidget {
  const LiveSearchView({super.key});

  @override
  State<LiveSearchView> createState() => _LiveSearchViewState();
}

class _LiveSearchViewState extends State<LiveSearchView>
    with SingleTickerProviderStateMixin {
  late final HomeController controller;
  late final TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _liveScrollController = ScrollController();
  final ScrollController _userScrollController = ScrollController();

  Timer? _searchDebounce;
  String _query = '';
  String _draftQuery = '';
  String _cachedUserKeyQuery = '';
  Set<String> _cachedUserKeys = <String>{};
  String _selectedCountryKey = 'all';
  String _selectedCountryName = 'All Country';
  String _selectedCountryFlag = '🌐';
  bool _searchAutoLoadingLive = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());
    _tabController = TabController(length: 2, vsync: this);
    _liveScrollController.addListener(_onLiveScroll);

    Future.microtask(() async {
      if (controller.allUserData.isEmpty) {
        await controller.showAllUserData();
      }
      if (controller.showingLiveStreamList.isEmpty) {
        await controller.refreshLivestreamList();
      }
      if (mounted) {
        _cachedUserKeyQuery = '';
        _cachedUserKeys = <String>{};
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _liveScrollController.dispose();
    _userScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onLiveScroll() {
    if (!_liveScrollController.hasClients) return;
    final position = _liveScrollController.position;
    if (position.pixels > position.maxScrollExtent - 420) {
      if (_query.trim().isEmpty && _selectedCountryKey == 'all') {
        controller.loadMoreLivestreamList();
      } else {
        _ensureSearchLoadedEnough(_query, countryKey: _selectedCountryKey);
      }
    }
  }

  void _onSearchChanged(String value) {
    // Typing er somoy heavy live filter / pagination run hobe na.
    // User smooth vabe type korbe, Search button press korle result update hobe.
    setState(() => _draftQuery = value);
  }

  Future<void> _runSearch([String? value]) async {
    final q = (value ?? _searchController.text).trim();
    _searchDebounce?.cancel();

    FocusScope.of(context).unfocus();

    setState(() {
      _draftQuery = q;
      _query = q;
      _cachedUserKeyQuery = '';
      _cachedUserKeys = <String>{};
      _searchGeneration++;
    });

    await _ensureSearchLoadedEnough(
      q,
      countryKey: _selectedCountryKey,
      forceDeepSearch: true,
    );
  }

  Future<void> _clearSearch() async {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _draftQuery = '';
      _query = '';
      _cachedUserKeyQuery = '';
      _cachedUserKeys = <String>{};
      _searchGeneration++;
    });
    await _ensureSearchLoadedEnough('', countryKey: _selectedCountryKey);
  }

  Future<void> _selectCountry(_CountryOption option) async {
    setState(() {
      _selectedCountryKey = option.key;
      _selectedCountryName = option.name;
      _selectedCountryFlag = option.flag;
    });
    await _ensureSearchLoadedEnough(_query, countryKey: option.key);
  }

  Future<void> _ensureSearchLoadedEnough(
      String query, {
        String countryKey = 'all',
        bool forceDeepSearch = false,
      }) async {
    final q = query.trim();
    final needCountry = countryKey.trim().isNotEmpty && countryKey != 'all';
    if (!needCountry && q.isEmpty) return;
    if (_searchAutoLoadingLive) return;
    if (!controller.liveHasMore.value && !controller.canLoadMoreLive) return;

    _searchAutoLoadingLive = true;
    final int generation = ++_searchGeneration;

    try {
      int guard = 0;
      final bool strictIdSearch = RegExp(r'^\d{3,}$').hasMatch(q);
      final int maxPageTry = forceDeepSearch ? (strictIdSearch ? 35 : 18) : (strictIdSearch ? 12 : 6);

      while (mounted &&
          generation == _searchGeneration &&
          guard < maxPageTry &&
          controller.canLoadMoreLive) {
        final int exactBefore = _liveResults(exactOnly: true).length;
        final int totalBefore = _liveResults().length;

        if (q.isNotEmpty && exactBefore > 0) break;
        if (q.isEmpty && needCountry && totalBefore >= 10) break;
        if (!forceDeepSearch && !strictIdSearch && q.isNotEmpty && totalBefore >= 12 && guard >= 2) break;

        await controller.loadMoreLivestreamList();
        guard++;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } finally {
      _searchAutoLoadingLive = false;
      if (mounted) setState(() {});
    }
  }

  String _safe(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z0-9\u0980-\u09ff ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeCountry(dynamic value) {
    var text = _normalize(_safe(value));
    if (text.isEmpty || text == 'add country') return '';
    const aliases = {
      'bd': 'bangladesh',
      'bangla desh': 'bangladesh',
      'india': 'india',
      'in': 'india',
      'pk': 'pakistan',
      'pak': 'pakistan',
      'uk': 'united kingdom',
      'u k': 'united kingdom',
      'england': 'united kingdom',
      'usa': 'united states',
      'us': 'united states',
      'america': 'united states',
      'united states of america': 'united states',
      'uae': 'united arab emirates',
      'saudia': 'saudi arabia',
      'ksa': 'saudi arabia',
      'oman': 'oman',
      'bahrain': 'bahrain',
      'turkiye': 'turkey',
      'hongkong': 'hong kong',
      'hk': 'hong kong',
    };
    return aliases[text] ?? text;
  }

  String _countryName(String key) {
    if (key == 'all') return ('All Country').appTr;
    const known = {
      'bangladesh': 'Bangladesh',
      'india': 'India',
      'pakistan': 'Pakistan',
      'united kingdom': 'United Kingdom',
      'united states': 'United States',
      'united arab emirates': 'United Arab Emirates',
      'saudi arabia': 'Saudi Arabia',
      'singapore': 'Singapore',
      'malaysia': 'Malaysia',
      'kuwait': 'Kuwait',
      'qatar': 'Qatar',
      'nepal': 'Nepal',
      'sri lanka': 'Sri Lanka',
      'iraq': 'Iraq',
      'oman': 'Oman',
      'bahrain': 'Bahrain',
      'turkey': 'Turkey',
      'canada': 'Canada',
      'australia': 'Australia',
      'germany': 'Germany',
      'france': 'France',
      'italy': 'Italy',
      'spain': 'Spain',
      'indonesia': 'Indonesia',
      'philippines': 'Philippines',
      'thailand': 'Thailand',
      'myanmar': 'Myanmar',
      'afghanistan': 'Afghanistan',
      'south africa': 'South Africa',
      'hong kong': 'Hong Kong',
    };
    if (known.containsKey(key)) return known[key]!;
    return key
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e.substring(0, 1).toUpperCase() + e.substring(1))
        .join(' ');
  }

  String _countryFlag(String key) {
    const flags = {
      'all': '🌐',
      'bangladesh': '🇧🇩',
      'india': '🇮🇳',
      'pakistan': '🇵🇰',
      'united kingdom': '🇬🇧',
      'united states': '🇺🇸',
      'united arab emirates': '🇦🇪',
      'saudi arabia': '🇸🇦',
      'singapore': '🇸🇬',
      'malaysia': '🇲🇾',
      'kuwait': '🇰🇼',
      'qatar': '🇶🇦',
      'nepal': '🇳🇵',
      'sri lanka': '🇱🇰',
      'iraq': '🇮🇶',
      'oman': '🇴🇲',
      'bahrain': '🇧🇭',
      'turkey': '🇹🇷',
      'canada': '🇨🇦',
      'australia': '🇦🇺',
      'germany': '🇩🇪',
      'france': '🇫🇷',
      'italy': '🇮🇹',
      'spain': '🇪🇸',
      'indonesia': '🇮🇩',
      'philippines': '🇵🇭',
      'thailand': '🇹🇭',
      'myanmar': '🇲🇲',
      'afghanistan': '🇦🇫',
      'south africa': '🇿🇦',
      'hong kong': '🇭🇰',
    };
    return flags[key] ?? '🌍';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _boolLike(dynamic value) {
    if (value == true || value == 1) return true;
    final text = _safe(value).toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }

  Map<String, dynamic> _liveUser(Map<String, dynamic> item) {
    final callers = item['livestream_callers'];
    if (callers is List && callers.isNotEmpty) {
      Map? broadcaster;
      for (final raw in callers) {
        if (raw is! Map) continue;
        final caller = _asMap(raw);
        final bool isBroadcaster = _boolLike(caller['is_broadcaster']) ||
            _safe(caller['caller_id']) == _safe(item['user_id']) ||
            _safe(caller['caller_id']) == _safe(item['owner_user_id']) ||
            _safe(caller['caller_id']) == _safe(item['current_host_id']);
        if (isBroadcaster) {
          broadcaster = caller;
          break;
        }
      }

      final Map first = broadcaster ??
          (callers.first is Map ? callers.first as Map : <String, dynamic>{});
      if (first['user'] is Map) return _asMap(first['user']);
      if (first['User'] is Map) return _asMap(first['User']);
      return _asMap(first);
    }

    if (item['user'] is Map) return _asMap(item['user']);
    if (item['User'] is Map) return _asMap(item['User']);
    if (item['sender_host'] is Map) return _asMap(item['sender_host']);
    if (item['receiver_host'] is Map) return _asMap(item['receiver_host']);
    if (item['host'] is Map) return _asMap(item['host']);
    if (item['broadcaster'] is Map) return _asMap(item['broadcaster']);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _allCallerUsers(Map<String, dynamic> item) {
    final callers = item['livestream_callers'];
    if (callers is! List) return <Map<String, dynamic>>[];
    final list = <Map<String, dynamic>>[];
    for (final raw in callers) {
      if (raw is! Map) continue;
      final caller = _asMap(raw);
      if (caller['user'] is Map) {
        list.add(_asMap(caller['user']));
      } else if (caller['User'] is Map) {
        list.add(_asMap(caller['User']));
      }
    }
    return list;
  }

  List<String> _callerSearchParts(Map<String, dynamic> item) {
    final callers = item['livestream_callers'];
    if (callers is! List) return <String>[];
    final parts = <String>[];

    for (final raw in callers) {
      if (raw is! Map) continue;
      final caller = _asMap(raw);
      final user = caller['user'] is Map
          ? _asMap(caller['user'])
          : caller['User'] is Map
          ? _asMap(caller['User'])
          : <String, dynamic>{};

      parts.addAll([
        _safe(caller['id']),
        _safe(caller['caller_id']),
        _safe(caller['user_id']),
        _safe(caller['seat_no']),
        _safe(caller['call_status']),
        _safe(caller['action']),
        _safe(user['id']),
        _safe(user['user_id']),
        _safe(user['unique_id']),
        _safe(user['name']),
        _safe(user['phone']),
        _safe(user['country']),
      ]);
    }
    return parts.where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> _findUserFromAllUsersByKeys(Iterable<String> keys) {
    final keySet = keys.map(_normalize).where((e) => e.isNotEmpty).toSet();
    if (keySet.isEmpty) return <String, dynamic>{};

    for (final rawUser in controller.allUserData) {
      final user = _asMap(rawUser);
      final userKeys = [
        user['id'],
        user['user_id'],
        user['unique_id'],
        user['phone'],
      ].map((e) => _normalize(_safe(e))).where((e) => e.isNotEmpty).toSet();
      if (userKeys.any(keySet.contains)) return user;
    }
    return <String, dynamic>{};
  }

  List<String> _liveParts(dynamic raw) {
    final item = _asMap(raw);
    final user = _liveUser(item);
    final parts = <String>[
      _safe(item['id']),
      _safe(item['livestream_id']),
      _safe(item['stream_id']),
      _safe(item['room_id']),
      _safe(item['channel_name']),
      _safe(item['channel_id']),
      _safe(item['title']),
      _safe(item['name']),
      _safe(item['live_title']),
      _safe(item['stream_title']),
      _safe(item['stream_name']),
      _safe(item['room_title']),
      _safe(item['room_name']),
      _safe(item['stream_type']),
      _safe(item['stream_bte']),
      _safe(item['live_bte']),
      _safe(item['bte']),
      _safe(item['bte_name']),
      _safe(item['country']),
      _safe(item['stream_country']),
      _safe(item['resolved_country']),
      _safe(item['anousment']),
      _safe(item['announcement']),
      _safe(item['user_id']),
      _safe(item['host_id']),
      _safe(item['broadcaster_id']),
      _safe(item['owner_user_id']),
      _safe(item['current_host_id']),
      _safe(user['id']),
      _safe(user['user_id']),
      _safe(user['unique_id']),
      _safe(user['name']),
      _safe(user['phone']),
      _safe(user['country']),
    ];
    parts.addAll(_callerSearchParts(item));

    final linkedUser = _findUserFromAllUsersByKeys([
      _safe(item['user_id']),
      _safe(item['owner_user_id']),
      _safe(item['current_host_id']),
      _safe(item['room_id']),
      _safe(user['id']),
      _safe(user['user_id']),
    ]);
    if (linkedUser.isNotEmpty) {
      parts.addAll([
        _safe(linkedUser['id']),
        _safe(linkedUser['user_id']),
        _safe(linkedUser['unique_id']),
        _safe(linkedUser['name']),
        _safe(linkedUser['phone']),
        _safe(linkedUser['country']),
      ]);
    }

    return parts.where((e) => e.isNotEmpty).toList();
  }

  String _liveSearchText(dynamic raw) => _normalize(_liveParts(raw).join(' '));

  Set<String> _queryUserKeys(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return <String>{};
    final parts = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final keys = <String>{};

    for (final raw in controller.allUserData) {
      final user = _asMap(raw);
      final text = _userSearchText(user);
      final exact = [
        user['id'],
        user['user_id'],
        user['unique_id'],
        user['phone'],
      ].map((e) => _normalize(_safe(e))).any((e) => e == q);

      if (exact || parts.every(text.contains)) {
        for (final field in [user['id'], user['user_id'], user['unique_id'], user['phone']]) {
          final key = _normalize(_safe(field));
          if (key.isNotEmpty) keys.add(key);
        }
      }
    }
    return keys;
  }

  Set<String> _queryUserKeysCached(String query) {
    final q = _normalize(query);
    if (_cachedUserKeyQuery == q) return _cachedUserKeys;
    _cachedUserKeyQuery = q;
    _cachedUserKeys = _queryUserKeys(q);
    return _cachedUserKeys;
  }

  bool _liveHasAnyUserKey(dynamic raw, Set<String> keys) {
    if (keys.isEmpty) return false;
    final parts = _liveParts(raw).map(_normalize).where((e) => e.isNotEmpty).toSet();
    return keys.any(parts.contains);
  }

  bool _liveMatchesQuery(dynamic raw, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    final normalizedQ = _normalize(q);
    final parts = normalizedQ.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final liveParts = _liveParts(raw).map(_normalize).where((e) => e.isNotEmpty).toList();

    // Exact live id / room id / stream_bte / host user id match hole direct live show hobe.
    if (liveParts.any((p) => p == normalizedQ || p.startsWith(normalizedQ))) return true;

    final text = liveParts.join(' ');
    if (parts.every(text.contains)) return true;

    final userKeys = _queryUserKeysCached(q);
    return _liveHasAnyUserKey(raw, userKeys);
  }

  int _liveScore(dynamic raw, String query) {
    final q = _normalize(query);
    if (q.isEmpty) return 0;
    final item = _asMap(raw);
    final user = _liveUser(item);
    final text = _liveSearchText(raw);
    final parts = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final searchableParts = _liveParts(raw).map(_normalize).toList();
    final callerParts = _callerSearchParts(item).map(_normalize).toList();

    int score = 0;
    bool exact(dynamic value) => _normalize(_safe(value)) == q;
    bool starts(dynamic value) => _normalize(_safe(value)).startsWith(q);
    bool contains(dynamic value) => _normalize(_safe(value)).contains(q);

    if (exact(item['id']) || exact(item['livestream_id']) || exact(item['stream_id'])) {
      score += 14000;
    }
    if (exact(item['room_id']) || exact(item['channel_name']) || exact(item['stream_bte'])) {
      score += 12000;
    }
    if (exact(item['user_id']) || exact(item['host_id']) || exact(item['owner_user_id']) ||
        exact(item['current_host_id']) || exact(user['id']) || exact(user['user_id'])) {
      score += 11000;
    }
    if (exact(user['unique_id']) || exact(user['phone'])) score += 9000;
    if (callerParts.contains(q)) score += 10500;
    if (_liveHasAnyUserKey(raw, _queryUserKeysCached(q))) score += 9500;

    for (final field in [
      item['title'],
      item['name'],
      item['live_title'],
      item['stream_bte'],
      item['stream_title'],
      item['stream_name'],
      item['room_name'],
      user['name'],
    ]) {
      if (starts(field)) score += 2500;
      if (contains(field)) score += 800;
    }

    for (final part in parts) {
      if (searchableParts.any((p) => p == part)) score += 500;
      if (searchableParts.any((p) => p.startsWith(part))) score += 220;
      if (text.contains(part)) score += 80;
    }

    final int showNo = int.tryParse(
      _safe(item['display_order'] ?? item['sort_order'] ?? item['show_no'] ?? item['sl_no']),
    ) ??
        999999;
    score += (999999 - showNo).clamp(0, 999999) ~/ 10000;
    return score;
  }

  String _userSearchText(dynamic raw) {
    final user = _asMap(raw);
    return _normalize([
      user['id'],
      user['user_id'],
      user['unique_id'],
      user['name'],
      user['phone'],
      user['email'],
      user['country'],
      user['user_type'],
      user['host_type'],
      user['agency_type'],
    ].map(_safe).where((e) => e.isNotEmpty).join(' '));
  }

  int _userScore(dynamic raw, String query) {
    final q = _normalize(query);
    if (q.isEmpty) return 0;
    final user = _asMap(raw);
    bool exact(dynamic value) => _normalize(_safe(value)) == q;
    bool starts(dynamic value) => _normalize(_safe(value)).startsWith(q);
    bool contains(dynamic value) => _normalize(_safe(value)).contains(q);

    int score = 0;
    if (exact(user['id']) || exact(user['user_id']) || exact(user['unique_id'])) score += 10000;
    if (exact(user['phone'])) score += 9000;
    if (starts(user['name'])) score += 3000;
    if (contains(user['name'])) score += 1000;

    final text = _userSearchText(raw);
    for (final part in q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty)) {
      if (text.contains(part)) score += 100;
    }
    return score;
  }

  String _liveCountryOf(dynamic raw) {
    final item = _asMap(raw);
    final direct = _normalizeCountry(
      item['resolved_country'] ??
          item['country'] ??
          item['country_name'] ??
          item['stream_country'] ??
          item['host_country'],
    );
    if (direct.isNotEmpty) return direct;

    final user = _liveUser(item);
    final userCountry = _normalizeCountry(user['country'] ?? user['country_name']);
    if (userCountry.isNotEmpty) return userCountry;

    for (final callerUser in _allCallerUsers(item)) {
      final country = _normalizeCountry(callerUser['country'] ?? callerUser['country_name']);
      if (country.isNotEmpty) return country;
    }

    final linkedUser = _findUserFromAllUsersByKeys([
      _safe(item['user_id']),
      _safe(item['owner_user_id']),
      _safe(item['current_host_id']),
      _safe(item['room_id']),
      _safe(user['id']),
      _safe(user['user_id']),
    ]);
    final linkedCountry = _normalizeCountry(linkedUser['country']);
    if (linkedCountry.isNotEmpty) return linkedCountry;

    return '';
  }

  bool _countryMatches(dynamic raw) {
    if (_selectedCountryKey == 'all') return true;
    final liveCountry = _liveCountryOf(raw);
    if (liveCountry.isEmpty) return false;
    return liveCountry == _selectedCountryKey ||
        liveCountry.contains(_selectedCountryKey) ||
        _selectedCountryKey.contains(liveCountry);
  }

  List<String> _allCountryKeys() {
    return const <String>[
      'bangladesh',
      'india',
      'pakistan',
      'united kingdom',
      'united states',
      'united arab emirates',
      'saudi arabia',
      'kuwait',
      'qatar',
      'oman',
      'bahrain',
      'singapore',
      'malaysia',
      'nepal',
      'sri lanka',
      'iraq',
      'turkey',
      'indonesia',
      'philippines',
      'thailand',
      'myanmar',
      'afghanistan',
      'hong kong',
      'canada',
      'australia',
      'germany',
      'france',
      'italy',
      'spain',
      'south africa',
    ];
  }

  List<_CountryOption> _countryOptions() {
    final counts = <String, int>{};
    for (final item in controller.showingLiveStreamList) {
      final key = _liveCountryOf(item);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (final rawOption in controller.availableLiveCountryOptions) {
      final key = _normalizeCountry(rawOption['key'] ?? rawOption['name']);
      if (key.isEmpty || key == 'global' || key == 'all') continue;
      counts.putIfAbsent(key, () => int.tryParse(_safe(rawOption['count'])) ?? 0);
    }

    for (final key in _allCountryKeys()) {
      counts.putIfAbsent(key, () => 0);
    }

    final options = <_CountryOption>[
      _CountryOption(
        key: 'all',
        name: 'All Country',
        flag: '🌐',
        count: controller.showingLiveStreamList.length,
      ),
    ];
    final rest = counts.entries.map((entry) {
      return _CountryOption(
        key: entry.key,
        name: _countryName(entry.key),
        flag: _countryFlag(entry.key),
        count: entry.value,
      );
    }).toList();
    rest.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.name.compareTo(b.name);
    });
    options.addAll(rest);
    return options;
  }

  List<dynamic> _liveResults({bool exactOnly = false}) {
    final q = _query.trim();
    final source = List<dynamic>.from(controller.showingLiveStreamList);
    final scored = <_ScoredLive>[];

    for (final item in source) {
      if (!_countryMatches(item)) continue;
      if (!_liveMatchesQuery(item, q)) continue;
      final score = _liveScore(item, q) + (_selectedCountryKey == 'all' ? 0 : 700);
      if (exactOnly && q.isNotEmpty && score < 8000) continue;
      scored.add(_ScoredLive(item, score));
    }

    if (q.isEmpty) {
      return scored.map((e) => e.item).toList();
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return _safe(_asMap(b.item)['id']).compareTo(_safe(_asMap(a.item)['id']));
    });
    return scored.map((e) => e.item).toList();
  }

  List<dynamic> _userResults() {
    final q = _query.trim();
    final source = List<dynamic>.from(controller.allUserData);
    if (q.isEmpty) return source.take(40).toList();

    final parts = _normalize(q).split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final scored = <_ScoredLive>[];
    for (final user in source) {
      final text = _userSearchText(user);
      if (!parts.every(text.contains)) continue;
      scored.add(_ScoredLive(user, _userScore(user, q)));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.item).take(100).toList();
  }

  String _imageUrl(dynamic raw) {
    final value = _safe(raw);
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return ImageHelper.getImageUrl(value);
  }

  int _gridCount(double width) {
    if (width >= 900) return 4;
    if (width >= 620) return 3;
    return 2;
  }

  double _gridRatio(double width) {
    if (width >= 900) return .82;
    if (width >= 620) return .80;
    return .76;
  }

  Widget _searchBar() {
    final bool hasAnyText = _draftQuery.trim().isNotEmpty || _query.trim().isNotEmpty;

    return Container(
      margin: EdgeInsets.fromLTRB(kWeight * 0.04, 12, kWeight * 0.04, 10),
      padding: const EdgeInsets.fromLTRB(12, 0, 7, 0),
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: kAppColor1, size: 23),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: ('Live name, BTE, room ID, user ID').appTr,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12.2,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _runSearch,
            ),
          ),
          if (hasAnyText)
            InkWell(
              key: const ValueKey('clear'),
              borderRadius: BorderRadius.circular(20),
              onTap: _clearSearch,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 20),
              ),
            ),
          const SizedBox(width: 4),
          Material(
            color: kAppColor1,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _runSearch(),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
                    const SizedBox(width: 4),
                    Text(
                      ('Search').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCountrySearchSheet() async {
    final allOptions = _countryOptions();
    String countryQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final normalizedQuery = _normalize(countryQuery);
            final filtered = normalizedQuery.isEmpty
                ? allOptions
                : allOptions.where((option) {
              final searchText = _normalize('${option.name} ${option.key} ${option.flag}');
              return searchText.contains(normalizedQuery);
            }).toList();

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * .72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      height: 5,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ('Select Country').appTr,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: kAppColor1, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: ('Search country name...').appTr,
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                                border: InputBorder.none,
                              ),
                              onChanged: (value) => setSheetState(() => countryQuery = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Text(
                          ('No country found').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                          : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          final selected = option.key == _selectedCountryKey;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                Navigator.pop(context);
                                await _selectCountry(option);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected ? kAppColor1.withOpacity(.09) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected ? kAppColor1.withOpacity(.35) : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(option.flag, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            option.name.appTr,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            option.key == 'all'
                                                ? ('Show all live streams').appTr: option.count > 0
                                                ? ('${option.count} loaded live room${option.count > 1 ? 's' : ''}').appTr
                                                : ('No loaded live yet').appTr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(Icons.check_circle_rounded, color: kAppColor1, size: 22)
                                    else
                                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 15),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _countrySelector() {
    return Obx(() {
      final options = _countryOptions();
      return SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: kWeight * 0.04),
          itemCount: options.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openCountrySearchSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.95)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountryFlag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        _selectedCountryKey == 'all' ? ('All Country').appTr: _selectedCountryName.appTr,
                        style: GoogleFonts.poppins(
                          color: kAppColor1,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.keyboard_arrow_down_rounded, color: kAppColor1, size: 18),
                    ],
                  ),
                ),
              );
            }

            final option = options[index - 1];
            final selected = option.key == _selectedCountryKey;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _selectCountry(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(selected ? .95 : .18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(option.flag, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      option.key == 'all'
                          ? ('All Country').appTr: '${option.name.appTr}${option.count > 0 ? ' (${option.count})' : ''}',
                      style: GoogleFonts.poppins(
                        color: selected ? kAppColor1 : Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _quickInfo(int liveCount, int userCount) {
    final q = _query.trim();
    final hasFilter = _selectedCountryKey != 'all';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: EdgeInsets.fromLTRB(kWeight * 0.04, 0, kWeight * 0.04, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Icon(hasFilter ? Icons.flag_rounded : q.isEmpty ? Icons.travel_explore_rounded : Icons.bolt_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasFilter
                  ? ('$_selectedCountryFlag $_selectedCountryName live rooms selected.').appTr: q.isEmpty
                  ? ('Type first, then press Search for fast live result.').appTr: ('Best matching live rooms show first.').appTr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(.90),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_searchAutoLoadingLive || controller.isLoadingMoreLive.value)
            _SearchShimmer(
              child: Container(
                height: 16,
                width: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            )
          else
            Text(
              ('$liveCount live • $userCount users').appTr,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.2, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  Widget _tabs(int liveCount, int userCount) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: kWeight * 0.04),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: kAppColor1,
        unselectedLabelColor: Colors.white,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(text: ('Live ($liveCount)').appTr),
          Tab(text: ('Users ($userCount)').appTr),
        ],
      ),
    );
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: kWeight * 0.10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kAppColor1.withOpacity(.08)),
              child: Icon(Icons.search_off_rounded, size: 38, color: kAppColor1.withOpacity(.85)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            ),
            if ((_query.trim().isNotEmpty || _selectedCountryKey != 'all') && controller.canLoadMoreLive) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAppColor1,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => _ensureSearchLoadedEnough(_query, countryKey: _selectedCountryKey),
                icon: const Icon(Icons.refresh_rounded),
                label:  Text(('Search more live pages').appTr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _liveLoadingShimmer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _gridCount(constraints.maxWidth);
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(kWeight * 0.035, 14, kWeight * 0.035, 24),
          itemCount: crossAxisCount * 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: _gridRatio(constraints.maxWidth),
          ),
          itemBuilder: (_, __) => const _LiveCardShimmer(),
        );
      },
    );
  }

  Widget _userLoadingShimmer() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(kWeight * 0.04, 14, kWeight * 0.04, 24),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _UserTileShimmer(),
    );
  }

  Widget _liveTab() {
    return Obx(() {
      final results = _liveResults();
      if (controller.isLoading.value && controller.showingLiveStreamList.isEmpty) {
        return _liveLoadingShimmer();
      }
      if (results.isEmpty) {
        return _emptyState(
          title: _selectedCountryKey == 'all' ? ('No live room found').appTr: ('No live stream').appTr,
          subtitle: _selectedCountryKey == 'all'
              ? ('Try live title, stream BTE, room ID, host name or user ID.').appTr: ('No live room found for $_selectedCountryName. Try Search more live pages.').appTr,
        );
      }

      return RefreshIndicator(
        color: kAppColor1,
        onRefresh: () async {
          await controller.refreshLivestreamList();
          await _ensureSearchLoadedEnough(_query, countryKey: _selectedCountryKey);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _gridCount(constraints.maxWidth);
            final bool showMoreLoader = controller.isLoadingMoreLive.value || _searchAutoLoadingLive;
            return GridView.builder(
              controller: _liveScrollController,
              padding: EdgeInsets.fromLTRB(kWeight * 0.035, 14, kWeight * 0.035, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: results.length + (showMoreLoader ? crossAxisCount : 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: _gridRatio(constraints.maxWidth),
              ),
              itemBuilder: (context, index) {
                if (index >= results.length) return const _LiveCardShimmer();
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: UserProfileCard(
                    key: ValueKey('${_safe(_asMap(results[index])['id'])}_$index'),
                    data: results[index],
                    index: index,
                    compact: true,
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }

  Widget _userTab() {
    return Obx(() {
      final results = _userResults();
      if (controller.allUserData.isEmpty && controller.isLoading.value) return _userLoadingShimmer();
      if (results.isEmpty) {
        return _emptyState(
          title: ('No user found').appTr,
          subtitle: ('Try name, user ID, unique ID or phone number.').appTr,
        );
      }
      return ListView.separated(
        controller: _userScrollController,
        padding: EdgeInsets.fromLTRB(kWeight * 0.04, 14, kWeight * 0.04, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = _asMap(results[index]);
          return _SearchUserTile(
            user: user,
            imageUrl: _imageUrl(user['profile_image'] ?? user['image']),
            onTap: () {
              final id = _safe(user['id']);
              if (id.isNotEmpty) controller.visitProfile(userId: id);
            },
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kAppColor1,
        surfaceTintColor: kAppColor1,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        title: Text(
          ('Search Live').appTr,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: kAppColor1,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(color: kAppColor1.withOpacity(.18), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    _searchBar(),
                    Obx(() {
                      final liveCount = _liveResults().length;
                      final userCount = _userResults().length;
                      return Column(
                        children: [
                          _countrySelector(),
                          const SizedBox(height: 8),
                          _quickInfo(liveCount, userCount),
                          _tabs(liveCount, userCount),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [_liveTab(), _userTab()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoredLive {
  final dynamic item;
  final int score;
  const _ScoredLive(this.item, this.score);
}

class _CountryOption {
  final String key;
  final String name;
  final String flag;
  final int count;
  const _CountryOption({required this.key, required this.name, required this.flag, required this.count});
}

class _SearchShimmer extends StatefulWidget {
  final Widget child;
  const _SearchShimmer({required this.child});

  @override
  State<_SearchShimmer> createState() => _SearchShimmerState();
}

class _SearchShimmerState extends State<_SearchShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                ((_controller.value - .35).clamp(0.0, 1.0)).toDouble(),
                (_controller.value.clamp(0.0, 1.0)).toDouble(),
                ((_controller.value + .35).clamp(0.0, 1.0)).toDouble(),
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _LiveCardShimmer extends StatelessWidget {
  const _LiveCardShimmer();

  @override
  Widget build(BuildContext context) {
    return _SearchShimmer(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
            ),
            Container(
              height: 12,
              margin: const EdgeInsets.fromLTRB(12, 2, 56, 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
            Container(
              height: 10,
              margin: const EdgeInsets.fromLTRB(12, 0, 86, 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTileShimmer extends StatelessWidget {
  const _UserTileShimmer();

  @override
  Widget build(BuildContext context) {
    return _SearchShimmer(
      child: Container(
        height: 78,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(height: 54, width: 54, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 13, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchUserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String imageUrl;
  final VoidCallback onTap;

  const _SearchUserTile({required this.user, required this.imageUrl, required this.onTap});

  String _safe(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final name = _safe(user['name']).isEmpty ? 'Unknown User': _safe(user['name']);
    final userId = _safe(user['user_id']).isEmpty ? _safe(user['id']) : _safe(user['user_id']);
    final uniqueId = _safe(user['unique_id']);
    final country = _safe(user['country']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'search_user_${_safe(user['id'])}',
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 54,
                    width: 54,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _avatarFallback(),
                    errorWidget: (_, __, ___) => _avatarFallback(),
                  )
                      : _avatarFallback(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ('ID: ${userId.isEmpty ? '---' : userId}${uniqueId.isNotEmpty ? '  •  $uniqueId' : ''}').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                    if (country.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kAppColor1.withOpacity(.09)),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: kAppColor1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      height: 54,
      width: 54,
      color: Colors.grey.shade200,
      child: const Icon(Icons.person_rounded),
    );
  }
}
