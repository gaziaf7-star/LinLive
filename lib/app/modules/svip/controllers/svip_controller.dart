import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../views/vipModel.dart';

class SvipController extends GetxController {
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
    {
      'image': 'assets/svip_exclusive_image/svipLodo.png',
      'text': 'Anti-block',
    },
    {
      'image': 'assets/svip_exclusive_image/svipeye.png',
      'text': 'Invisible',
    },
    {
      'image': 'assets/svip_exclusive_image/svip gift1.png',
      'text': 'Vip Gift',
    },
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
    'Authorization':
    'Bearer ${authController.userProfile.value.token}',
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

      final list = _extractList(response.data)
          .map(VipLevel.fromJson)
          .where((item) => item.id > 0 && item.status)
          .toList()
        ..sort((a, b) {
          final orderA = a.sortOrder > 0 ? a.sortOrder : a.levelNo;
          final orderB = b.sortOrder > 0 ? b.sortOrder : b.levelNo;
          return orderA.compareTo(orderB);
        });

      vipLevels.assignAll(list);

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

      final list = _extractList(response.data)
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
        showMessage(
          _errorMessage(e, 'My VIP load failed'),
          color: Colors.red,
        );
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
    settingValues.assignAll(info.settingsScreen.values);
  }

  Future<void> fetchMyVipHistory() async {
    try {
      final response = await _dio.get(
        kVipMyHistoryUrl,
        options: Options(headers: _authHeaders),
      );

      final list = _extractList(response.data)
          .map(VipPurchaseInfo.fromJson)
          .toList();
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
          (item) =>
      item.id == packageId && (vipId == null || item.vipId == vipId),
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
        data: {
          'package_id': package.id,
          'vip_id': package.vipId,
        },
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
      await _dio.get(
        kBackPackList,
        options: Options(headers: _authHeaders),
      );
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
    const supportedKeys = <String>{
      'is_enabled',
      'hide_visitor_records',
      'hide_online_status',
      'avoid_disturbing',
    };
    if (!supportedKeys.contains(key) ||
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

    final hasCurrentVipShape = source.containsKey('vip_id') ||
        source.containsKey('vip_level') ||
        source.containsKey('package_id');
    if (hasCurrentVipShape) {
      _applyCurrentVip(VipPurchaseInfo.fromJson(source));
      return true;
    }

    final settings = VipHelpers.asMap(
      source['settings'] ?? data['settings'],
    );
    final screenRaw = source['settings_screen'] ?? data['settings_screen'];
    if (screenRaw != null || settings.isNotEmpty) {
      final screen = VipSettingsScreenData.fromJson(
        screenRaw,
        fallbackSettings: <String, dynamic>{
          ...settingValues,
          ...settings,
        },
        fallbackMasterValue: settingValue('is_enabled'),
      );
      settingsScreen.value = screen;
      settingValues.assignAll(screen.values);
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
    final list = vipPackages
        .where((item) => item.vipId == vipId && item.status)
        .toList()
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
        ...level.allAssets.map((e) => e.playUrl),
      ]) {
        if (VipHelpers.ext(url) == 'svga') urls.add(url);
      }
      if (urls.isNotEmpty) {
        SVGAPrecacheManager.shared.precache(urls);
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
