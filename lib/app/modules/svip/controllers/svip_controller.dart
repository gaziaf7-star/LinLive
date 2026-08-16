import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../livestream/controllers/livestream_controller.dart';
import '../views/vipModel.dart';

/// Which tier of the VIP system a given [SvipController] / page instance is
/// responsible for. The backend returns every VIP and SVIP level from the
/// same `/vip/levels` endpoint, so the controller fetches everything once
/// and then keeps only the levels that belong to this mode.
enum VipSectionMode { vip, svip }

class SvipController extends GetxController {
  final VipSectionMode mode;

  SvipController({this.mode = VipSectionMode.vip});

  bool get isSvipMode => mode == VipSectionMode.svip;

  String get sectionLabel => isSvipMode ? 'SVIP' : 'VIP';

  final List<Map<String, String>> gridItems = [
    {'image': 'assets/svga/Frame/Vip frame 1.svga', 'text': 'Vip1 Frame'},
    {'image': 'assets/Svip/Svip.png', 'text': 'VIP Title'},
    {'image': 'assets/Svip/profile (2).png', 'text': 'VIP Badge'},
    {'image': 'assets/Svip/svip1.png', 'text': 'VIP Entry'},
    {'image': 'assets/Svip/frame.png', 'text': 'Colourful Profile'},
    {'image': 'assets/Svip/animal.png', 'text': 'Colourful Chat'},
  ];

  final List<Map<String, String>> gridItems2 = [
    {
      'image': 'assets/svip_exclusive_image/svipacount2.png',
      'text': 'Anti-comment Mute',
    },
    {
      'image': 'assets/svip_exclusive_image/svipLodo.png',
      'text': 'Anti-kick\nanti-ban',
    },
    {'image': 'assets/svip_exclusive_image/svipLodo.png', 'text': 'Anti-block'},
    {'image': 'assets/svip_exclusive_image/svipeye.png', 'text': 'Invisible'},
    {'image': 'assets/svip_exclusive_image/svip gift1.png', 'text': 'Vip Gift'},
    {
      'image': 'assets/svip_exclusive_image/svipimaogi.png',
      'text': 'Vip emoji ',
    },
    {
      'image': 'assets/svip_exclusive_image/SvipProfileBg.png',
      'text': 'GIF Profile Pic',
    },
    {
      'image': 'assets/svip_exclusive_image/SvipProfileBg.png',
      'text': 'VIP Set',
    },
    {
      'image': 'assets/svip_exclusive_image/SvipProfileBg.png',
      'text': 'Entry Banner',
    },
  ];

  final Dio _dio = Dio();

  final RxInt selectedTab = 0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isPackageLoading = false.obs;
  final RxBool isPurchaseLoading = false.obs;
  final RxBool isMyVipLoading = false.obs;
  final RxBool isSettingsLoading = false.obs;

  final RxList<VipLevel> vipLevels = <VipLevel>[].obs;
  final RxList<VipPackageItem> vipPackages = <VipPackageItem>[].obs;
  final Rxn<VipPurchaseInfo> currentVip = Rxn<VipPurchaseInfo>();
  final RxList<VipPurchaseInfo> vipHistory = <VipPurchaseInfo>[].obs;
  final RxMap<int, int> selectedPackageIds = <int, int>{}.obs;
  final Rxn<VipSettingsScreenData> settingsScreen =
  Rxn<VipSettingsScreenData>();
  final RxMap<String, bool> settingValues = <String, bool>{}.obs;
  final RxSet<String> savingSettingKeys = <String>{}.obs;

  final ScrollController scrollController = ScrollController();
  final RxBool showBottomCard = true.obs;
  double lastOffset = 0.0;

  int get signedInDatabaseUserId =>
      VipHelpers.toInt(authController.userProfile.value.user?.id);

  bool get hasActiveVipMembership {
    final current = currentVip.value;
    return current != null && current.isActive;
  }

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    loadVipSystem();
  }

  void changeTab(int index) {
    if (index < 0 || index >= vipLevels.length) return;
    selectedTab.value = index;
    final level = vipLevels[index];
    final packages = packagesForLevel(level.id);
    if (packages.isNotEmpty && selectedPackageIds[level.id] == null) {
      selectedPackageIds[level.id] = packages.first.id;
      selectedPackageIds.refresh();
    }
    precacheCurrentLevelSvga();
  }

  void _onScroll() {
    final currentOffset = scrollController.offset;
    if (currentOffset > lastOffset && currentOffset - lastOffset > 5) {
      showBottomCard.value = false;
    } else if (currentOffset < lastOffset && lastOffset - currentOffset > 5) {
      showBottomCard.value = true;
    }
    lastOffset = currentOffset;
  }

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer ${authController.userProfile.value.token}',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return List<dynamic>.from(body);
    if (body is Map && body['data'] is List) {
      return List<dynamic>.from(body['data']);
    }
    if (body is Map && body['levels'] is List) {
      return List<dynamic>.from(body['levels']);
    }
    if (body is Map && body['vip_levels'] is List) {
      return List<dynamic>.from(body['vip_levels']);
    }
    if (body is Map && body['packages'] is List) {
      return List<dynamic>.from(body['packages']);
    }
    if (body is Map && body['history'] is List) {
      return List<dynamic>.from(body['history']);
    }
    return <dynamic>[];
  }

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data']);
    }
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    return <String, dynamic>{};
  }

  String _errorMessage(dynamic error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }
    return fallback;
  }

  void showMessage(String message, {Color color = Colors.black87}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  Future<void> loadVipSystem() async {
    final userId = signedInDatabaseUserId;
    await Future.wait([
      fetchVipLevels(),
      if (userId > 0) fetchMyCurrentVip(silent: true, userId: userId),
    ]);
    _selectFirstPackageForAllLevels();
    precacheCurrentLevelSvga();
  }

  Future<void> refreshVipSystem() => loadVipSystem();

  Future<void> fetchVipLevels() async {
    try {
      isLoading.value = true;
      isPackageLoading.value = true;
      final response = await _dio.get(
        kVipLevelsUrl,
        options: Options(headers: const {'Accept': 'application/json'}),
      );

      final list =
      _extractList(response.data)
          .map(VipLevel.fromJson)
          .where(
            (item) =>
        item.id > 0 && item.status && item.isSvipTier == isSvipMode,
      )
          .toList()
        ..sort((a, b) {
          final orderA = a.sortOrder > 0 ? a.sortOrder : a.levelNo;
          final orderB = b.sortOrder > 0 ? b.sortOrder : b.levelNo;
          return orderA.compareTo(orderB);
        });

      vipLevels.assignAll(list);
      unawaited(_precacheAllLevelsMedia());

      final nestedPackages = <VipPackageItem>[];
      for (final level in list) {
        for (final package in level.packages) {
          if (package.id <= 0 || package.vipId != level.id || !package.status) {
            continue;
          }
          nestedPackages.add(package);
        }
      }
      nestedPackages.sort(_comparePackages);
      vipPackages.assignAll(nestedPackages);

      if (vipPackages.isEmpty && vipLevels.isNotEmpty) {
        await fetchVipPackagesFallback();
      }

      if (selectedTab.value >= vipLevels.length) selectedTab.value = 0;
      _removeInvalidSelections();
      _selectFirstPackageForAllLevels();
    } catch (e) {
      log('VIP level load failed: $e');
      showMessage(
        _errorMessage(e, ('VIP level load failed').appTr),
        color: Colors.red,
      );
    } finally {
      isLoading.value = false;
      isPackageLoading.value = false;
    }
  }

  int _comparePackages(VipPackageItem a, VipPackageItem b) {
    final vipCompare = a.vipId.compareTo(b.vipId);
    if (vipCompare != 0) return vipCompare;
    final orderA = a.sortOrder > 0 ? a.sortOrder : a.day;
    final orderB = b.sortOrder > 0 ? b.sortOrder : b.day;
    return orderA.compareTo(orderB);
  }

  Future<void> fetchVipPackagesFallback() async {
    try {
      final response = await _dio.get(
        kVipPackagesUrl,
        options: Options(headers: const {'Accept': 'application/json'}),
      );

      final list =
      _extractList(response.data)
          .map(VipPackageItem.fromJson)
          .where(
            (item) =>
        item.id > 0 &&
            item.vipId > 0 &&
            item.status &&
            vipLevels.any((level) => level.id == item.vipId),
      )
          .toList()
        ..sort(_comparePackages);

      vipPackages.assignAll(list);
    } catch (e) {
      log('VIP fallback package load failed: $e');
      showMessage(
        _errorMessage(e, ('VIP package load failed').appTr),
        color: Colors.red,
      );
    }
  }

  Future<void> fetchVipPackages() async {
    isPackageLoading.value = true;
    try {
      await fetchVipPackagesFallback();
      _removeInvalidSelections();
      _selectFirstPackageForAllLevels();
    } finally {
      isPackageLoading.value = false;
    }
  }

  Future<void> fetchMyCurrentVip({
    bool silent = false,
    required int userId,
  }) async {
    if (userId <= 0) return;
    try {
      isMyVipLoading.value = true;
      final response = await _dio.get(
        kVipMyCurrentUrl(userId),
        options: Options(headers: _authHeaders),
      );

      final data = response.data is Map ? response.data['data'] : null;
      if (data == null) {
        currentVip.value = null;
        settingsScreen.value = null;
        settingValues.clear();
      } else {
        _applyCurrentVip(VipPurchaseInfo.fromJson(data));
      }
    } catch (e) {
      if (!silent) {
        showMessage(_errorMessage(e, 'My VIP load failed'), color: Colors.red);
      }
    } finally {
      isMyVipLoading.value = false;
    }
  }

  Future<void> reloadCurrentUserVip({bool silent = false}) async {
    final userId = signedInDatabaseUserId;
    if (userId <= 0) return;
    await fetchMyCurrentVip(silent: silent, userId: userId);
  }

  void _applyCurrentVip(VipPurchaseInfo info) {
    currentVip.value = info;
    settingsScreen.value = info.settingsScreen;

    final values = <String, bool>{
      ...info.settingsScreen.values,
      ..._permissionValuesFromRaw(info.raw),
    };

    settingValues.assignAll(values);
  }

  Map<String, bool> _permissionValuesFromRaw(Map<String, dynamic> raw) {
    final values = <String, bool>{};

    final permissionSettings = VipHelpers.asMap(raw['permission_settings']);
    for (final entry in permissionSettings.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      values[key] = VipHelpers.toBool(entry.value);
    }

    final screen = VipHelpers.asMap(raw['settings_screen']);
    final permissionSwitches = VipHelpers.asList(screen['permission_switches']);

    for (final item in permissionSwitches) {
      final map = VipHelpers.asMap(item);
      final key = VipHelpers.firstStr(map, ['key', 'name']).trim();
      if (key.isEmpty) continue;
      values[key] = VipHelpers.toBool(
        map['value'],
        fallback: values[key] ?? false,
      );
    }

    return values;
  }

  List<Map<String, dynamic>> get permissionSwitchItems {
    final current = currentVip.value;
    if (current == null) return const <Map<String, dynamic>>[];

    final screen = VipHelpers.asMap(current.raw['settings_screen']);
    final rawItems = VipHelpers.asList(screen['permission_switches']);
    final result = <Map<String, dynamic>>[];

    for (final rawItem in rawItems) {
      final item = VipHelpers.asMap(rawItem);
      final key = VipHelpers.firstStr(item, ['key', 'name']).trim();
      if (key.isEmpty) continue;

      result.add(<String, dynamic>{
        ...item,
        'key': key,
        'label': VipHelpers.firstStr(item, [
          'label',
          'title',
        ], fallback: key.replaceAll('_', ' ')),
        'description': VipHelpers.firstStr(item, [
          'description',
          'subtitle',
          'text',
        ]),
        'icon': VipHelpers.toStr(item['icon']),
        'value': settingValue(key),
      });
    }

    return result;
  }

  Set<String> get _availablePermissionSettingKeys {
    final keys = <String>{};

    for (final item in permissionSwitchItems) {
      final key = VipHelpers.toStr(item['key']).trim();
      if (key.isNotEmpty) keys.add(key);
    }

    final current = currentVip.value;
    if (current != null) {
      final permissionSettings = VipHelpers.asMap(
        current.raw['permission_settings'],
      );
      for (final key in permissionSettings.keys) {
        final clean = key.toString().trim();
        if (clean.isNotEmpty) keys.add(clean);
      }
    }

    return keys;
  }

  Future<void> fetchMyVipHistory() async {
    try {
      final response = await _dio.get(
        kVipMyHistoryUrl,
        options: Options(headers: _authHeaders),
      );

      final list = _extractList(
        response.data,
      ).map(VipPurchaseInfo.fromJson).toList();
      vipHistory.assignAll(list);
    } catch (e) {
      showMessage(
        _errorMessage(e, ('VIP history load failed').appTr),
        color: Colors.red,
      );
    }
  }

  Future<bool> purchaseSelectedPackage() async {
    final level = selectedLevel;
    if (level == null) {
      showMessage(('Please select a VIP level').appTr, color: Colors.red);
      return false;
    }

    final package = selectedPackageForLevel(level.id);
    if (package == null || package.id <= 0) {
      showMessage(('Please select a VIP package').appTr, color: Colors.red);
      return false;
    }

    if (package.vipId != level.id) {
      showMessage(
        ('VIP package mapping is invalid. Please refresh and try again.').appTr,
        color: Colors.red,
      );
      return false;
    }

    return purchasePackage(package.id, vipId: package.vipId);
  }

  Future<bool> purchasePackage(int packageId, {int? vipId}) async {
    if (isPurchaseLoading.value) return false;

    final package = vipPackages.firstWhereOrNull(
          (item) => item.id == packageId && (vipId == null || item.vipId == vipId),
    );
    if (package == null || package.vipId <= 0) {
      showMessage(
        ('VIP package mapping is invalid. Please refresh and try again.').appTr,
        color: Colors.red,
      );
      return false;
    }

    try {
      isPurchaseLoading.value = true;
      final response = await _dio.post(
        kVipPurchaseUrl,
        data: {'package_id': package.id, 'vip_id': package.vipId},
        options: Options(headers: _authHeaders),
      );

      final body = response.data;
      final message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'VIP purchased successfully';
      final data = _extractDataMap(body);
      if (data.isNotEmpty) {
        _applyCurrentVip(VipPurchaseInfo.fromJson(data));
      }

      showMessage(message, color: Colors.green);
      await Future.wait([
        reloadCurrentUserVip(silent: true),
        fetchMyVipHistory(),
        reloadBackpackOnce(),
      ]);
      return true;
    } catch (e) {
      showMessage(
        _errorMessage(e, ('VIP purchase failed').appTr),
        color: Colors.red,
      );
      return false;
    } finally {
      isPurchaseLoading.value = false;
    }
  }

  Future<void> reloadBackpackOnce() async {
    try {
      await _dio.get(kBackPackList, options: Options(headers: _authHeaders));
    } catch (e) {
      log('Backpack refresh after VIP change failed: $e');
    }
  }

  bool settingValue(String key) {
    if (settingValues.containsKey(key)) return settingValues[key] ?? false;
    final current = currentVip.value;
    if (key == 'is_enabled') return current?.isEnabled ?? false;
    if (current == null) return false;
    return VipHelpers.toBool(current.settings[key]);
  }

  bool isSettingSaving(String key) => savingSettingKeys.contains(key);

  Future<bool> updateVipSetting({
    required String key,
    required bool value,
  }) async {
    const coreSupportedKeys = <String>{
      'is_enabled',
      'hide_visitor_records',
      'hide_online_status',
      'avoid_disturbing',
    };

    final bool isSupported =
        coreSupportedKeys.contains(key) ||
            _availablePermissionSettingKeys.contains(key);

    if (!isSupported ||
        isSettingsLoading.value ||
        savingSettingKeys.contains(key)) {
      return false;
    }

    final previous = settingValue(key);
    savingSettingKeys.add(key);
    savingSettingKeys.refresh();
    settingValues[key] = value;
    settingValues.refresh();

    try {
      isSettingsLoading.value = true;
      final response = await _dio.post(
        kVipSettingsUrl,
        data: {'key': key, 'value': value},
        options: Options(headers: _authHeaders),
      );

      final body = response.data;
      final data = _extractDataMap(body);
      final applied = _applySettingsResponse(data);
      if (!applied) {
        await reloadCurrentUserVip(silent: true);
      }
      if (Get.isRegistered<LivestreamController>()) {
        Get.find<LivestreamController>().patchCurrentVipSetting(key, value);
      }

      final message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'VIP setting updated successfully';
      showMessage(message, color: Colors.green);
      await reloadBackpackOnce();
      return true;
    } catch (e) {
      settingValues[key] = previous;
      settingValues.refresh();
      showMessage(
        _errorMessage(e, ('VIP setting update failed').appTr),
        color: Colors.red,
      );
      return false;
    } finally {
      savingSettingKeys.remove(key);
      savingSettingKeys.refresh();
      isSettingsLoading.value = false;
    }
  }

  bool _applySettingsResponse(Map<String, dynamic> data) {
    if (data.isEmpty) return false;

    Map<String, dynamic> source = data;
    final nestedCurrent = data['current_vip'];
    if (nestedCurrent is Map) {
      source = Map<String, dynamic>.from(nestedCurrent);
    }

    final hasCurrentVipShape =
        source.containsKey('vip_id') ||
            source.containsKey('vip_level') ||
            source.containsKey('package_id');
    if (hasCurrentVipShape) {
      _applyCurrentVip(VipPurchaseInfo.fromJson(source));
      return true;
    }

    final settings = VipHelpers.asMap(source['settings'] ?? data['settings']);
    final screenRaw = source['settings_screen'] ?? data['settings_screen'];
    if (screenRaw != null || settings.isNotEmpty) {
      final screen = VipSettingsScreenData.fromJson(
        screenRaw,
        fallbackSettings: <String, dynamic>{...settingValues, ...settings},
        fallbackMasterValue: settingValue('is_enabled'),
      );
      settingsScreen.value = screen;

      final mergedValues = <String, bool>{
        ...screen.values,
        ..._permissionValuesFromRaw(<String, dynamic>{
          ...data,
          ...source,
          if (screenRaw != null) 'settings_screen': screenRaw,
        }),
      };

      // Preserve existing permission values if this lightweight response
      // does not include permission_settings/permission_switches.
      for (final entry in settingValues.entries) {
        if (_availablePermissionSettingKeys.contains(entry.key) &&
            !mergedValues.containsKey(entry.key)) {
          mergedValues[entry.key] = entry.value;
        }
      }

      settingValues.assignAll(mergedValues);
      return true;
    }

    return false;
  }

  VipLevel? get selectedLevel {
    if (vipLevels.isEmpty) return null;
    final index = selectedTab.value.clamp(0, vipLevels.length - 1);
    return vipLevels[index];
  }

  VipLevel? levelByNumber(int levelNo) {
    return vipLevels.firstWhereOrNull((item) => item.levelNo == levelNo);
  }

  List<VipPackageItem> packagesForLevel(int vipId) {
    final list =
    vipPackages.where((item) => item.vipId == vipId && item.status).toList()
      ..sort(_comparePackages);
    return list;
  }

  VipPackageItem? selectedPackageForLevel(int vipId) {
    final selectedId = selectedPackageIds[vipId];
    final packages = packagesForLevel(vipId);
    if (packages.isEmpty) return null;
    return packages.firstWhereOrNull((item) => item.id == selectedId) ??
        packages.first;
  }

  void selectPackage({required int vipId, required int packageId}) {
    final exactPackage = vipPackages.firstWhereOrNull(
          (item) => item.vipId == vipId && item.id == packageId && item.status,
    );
    if (exactPackage == null) return;
    selectedPackageIds[vipId] = exactPackage.id;
    selectedPackageIds.refresh();
  }

  bool isCurrentVipLevel(VipLevel level) {
    final current = currentVip.value;
    if (current == null) return false;
    return current.isActive && current.vipId == level.id;
  }

  String remainingText() {
    final current = currentVip.value;
    if (current == null || !current.isActive) return 'No active VIP';
    if (current.remainingDays > 0) return '${current.remainingDays} days left';
    if (current.expiresAt.isNotEmpty) return 'Expires: ${current.expiresAt}';
    return ('Active').appTr;
  }

  void _removeInvalidSelections() {
    final valid = <int, int>{};
    selectedPackageIds.forEach((vipId, packageId) {
      final exists = vipPackages.any(
            (item) => item.vipId == vipId && item.id == packageId && item.status,
      );
      if (exists) valid[vipId] = packageId;
    });
    selectedPackageIds.assignAll(valid);
  }

  void _selectFirstPackageForAllLevels() {
    for (final level in vipLevels) {
      final packages = packagesForLevel(level.id);
      if (packages.isNotEmpty && selectedPackageIds[level.id] == null) {
        selectedPackageIds[level.id] = packages.first.id;
      }
    }
    selectedPackageIds.refresh();
  }

  void precacheCurrentLevelSvga() {
    try {
      final level = selectedLevel;
      if (level == null) return;
      final urls = <String>[];
      for (final url in [
        level.frameUrl,
        level.badgeImageUrl,
        level.titleImageUrl,
        level.entryBannerImageUrl,
        level.profileCardImageUrl,
        level.nameImageUrl,
        level.chatBubbleImageUrl,
        ...level.allAssets.map((e) => e.playUrl),
      ]) {
        if (VipHelpers.ext(url) == 'svga') urls.add(url);
      }
      if (urls.isNotEmpty) {
        SVGAPrecacheManager.shared.precache(urls);
      }
    } catch (_) {}
  }

  /// Warms both the SVGA cache and the disk image cache for every level
  /// that was fetched — not just the one currently selected — so switching
  /// tabs feels instant instead of triggering a fresh network fetch each
  /// time. Runs in the background and never blocks the UI.
  Future<void> _precacheAllLevelsMedia() async {
    try {
      final svgaUrls = <String>{};
      final rasterUrls = <String>{};

      void bucket(String url) {
        final clean = url.trim();
        if (clean.isEmpty) return;
        if (VipHelpers.ext(clean) == 'svga') {
          svgaUrls.add(clean);
        } else {
          rasterUrls.add(clean);
        }
      }

      for (final level in vipLevels) {
        for (final url in [
          level.frameUrl,
          level.frameShowImageUrl,
          level.badgeImageUrl,
          level.badgeImageShowImageUrl,
          level.titleImageUrl,
          level.titleImageShowImageUrl,
          level.entryBannerImageUrl,
          level.entryBannerImageShowImageUrl,
          level.profileCardImageUrl,
          level.profileCardImageShowImageUrl,
          level.nameImageUrl,
          level.nameImageShowImageUrl,
          level.chatBubbleImageUrl,
          level.chatBubbleImageShowImageUrl,
          ...level.allAssets.map((e) => e.playUrl),
          ...level.allAssets.map((e) => e.previewUrl),
        ]) {
          bucket(url);
        }
      }

      if (svgaUrls.isNotEmpty) {
        SVGAPrecacheManager.shared.precache(svgaUrls.toList());
      }

      // Raster images (png/webp "show" thumbnails) are fetched one at a
      // time into the same disk cache CachedNetworkImage reads from, so
      // by the time the user taps a tab the network round trip is already
      // done. Each fetch is isolated so one bad URL can't stop the rest.
      for (final url in rasterUrls) {
        unawaited(_prefetchRasterImage(url));
      }
    } catch (_) {}
  }

  Future<void> _prefetchRasterImage(String url) async {
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (_) {}
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}