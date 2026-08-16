import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../bottomnav/views/bottomnav_view.dart';
import '../../store/views/store_tabber_view/insafientBaalnce.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class StoreController extends GetxController {
  final isColor = false.obs;
  final _dio = Dio();

  final isLoading = false.obs;

  final assetList = <dynamic>[].obs;

  /// Medal/Achievement page uses Store API items whose type is Badge.
  /// Kept as baseAssetList so the existing Medal page contract stays unchanged.
  final baseAssetList = <dynamic>[].obs;

  bool _isBaseAsset(dynamic rawItem) {
    if (rawItem is! Map) return false;

    final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
    final String type = (item['type'] ?? '').toString().trim().toLowerCase();

    return type == 'badge';
  }

  void _syncBaseAssetList() {
    baseAssetList.assignAll(assetList.where(_isBaseAsset));
  }

  Future getAssetList() async {
    try {
      isLoading.value = true;

      final response = await _dio.get(
        kAssetListUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      final dynamic body = response.data;
      final dynamic rawAssets = body is Map ? body['assets'] : null;

      if (rawAssets is List) {
        assetList.assignAll(rawAssets);
      } else {
        assetList.clear();
      }

      _syncBaseAssetList();
      return assetList;
    } finally {
      isLoading.value = false;
    }
  }

  ///----------------------asset sending ----------------------

  void onTap() {
    print('Select Id ${selectId.value}');
  }

  final sendingData = {}.obs;
  final selectId = ''.obs;
  final selectReceverId = ''.obs;

  final sendingUserId = ''.obs;
  Future<void> sendingAsset({required String userId}) async {
    final data = {
      'asset_id': selectId.value,
      'receiver_id': userId,
    };

    try {
      isLoading.value = true;
      sendingUserId.value = userId;

      print("========== ASSET SEND REQUEST ==========");
      print("API URL: $kAssetSending");
      print("Request Data: $data");
      print("Token: ${authController.userProfile.value.token}");
      print("=======================================");

      final response = await _dio.post(
        kAssetSending,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      print("========== ASSET SEND RESPONSE ==========");
      print("Status Code: ${response.statusCode}");
      print("Response Data: ${response.data}");
      print("========================================");

      if (response.statusCode == 200) {
        sendingData.value = response.data;

        Fluttertoast.showToast(
          msg: response.data['message'] ?? ("Asset sent successfully").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        Get.offAll(() => BottomnavView(), transition: Transition.rightToLeft);
      } else {
        Fluttertoast.showToast(
          msg: ("Unable to send asset").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } on DioException catch (e) {
      print("========== ASSET SEND ERROR ==========");
      print("Status Code: ${e.response?.statusCode}");
      print("Error Data: ${e.response?.data}");
      print("Request Data: ${e.requestOptions.data}");
      print("=====================================");

      Fluttertoast.showToast(
        msg: e.response?.data?['message'] ?? ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print("========== UNKNOWN SEND ERROR ==========");
      print(e);
      print("======================================");

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      isLoading.value = false;
      sendingUserId.value = '';
    }
  }
  ///------------------------ freme purchase ----------------------
  final purchaseData = {}.obs;


  Future<void> purchaseAsset({required String purchaseId}) async {
    final data = {'asset_id': purchaseId};

    try {
      isLoading.value = true;

      print("========== PURCHASE REQUEST START ==========");
      print("API URL: $kAssetPurchase");
      print("Request Data: $data");
      print("Token: ${authController.userProfile.value.token}");
      print("===========================================");

      final response = await _dio.post(
        kAssetPurchase,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      print("========== PURCHASE RESPONSE ==========");
      print("Status Code: ${response.statusCode}");
      print("Response Data: ${response.data}");
      print("======================================");

      if (response.statusCode == 200) {
        purchaseData.value = response.data;

        Fluttertoast.showToast(
          msg: ("Purchase Success").appTr,
        );

        Get.back();
      }
    } on DioException catch (e) {
      print("========== DIO ERROR ==========");
      print("Error Status: ${e.response?.statusCode}");
      print("Error Data: ${e.response?.data}");
      print("==============================");

      final statusCode = e.response?.statusCode;
      final errorData = e.response?.data;

      if (statusCode == 400 && errorData != null) {
        Get.back();
        final userCoins = errorData['data']?['user_coins'] ?? 0;
        final assetPrice = errorData['data']?['asset_price'] ?? 0;

        showInsufficientCoinsDialog(
          userCoins: userCoins,
          assetPrice: assetPrice,
        );

      } else {
        Fluttertoast.showToast(
          msg: ("Something went wrong").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print("========== UNKNOWN ERROR ==========");
      print(e);
      print("=================================");

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      isLoading.value = false;
    }
  }
  ///------------------- show backpack list ------------------

  final backpackList = <dynamic>[].obs;

  /// Current VIP summary returned by /back_pack.
  final currentVip = <String, dynamic>{}.obs;

  /// Full VIP level information extracted from the current purchase history.
  final currentVipDetails = <String, dynamic>{}.obs;

  /// Virtual cards for VIP Frame, VIP Title, VIP Badge, Entry Banner and
  /// Profile Card. These are not normal asset-history rows, so they are built
  /// from current_vip -> vip details.
  final vipBaseItems = <Map<String, dynamic>>[].obs;

  final vipBaseSavingKeys = <String>{}.obs;

  bool get hasCurrentVip =>
      _mapBool(currentVip['is_active']) &&
          _mapInt(currentVip['vip_id']) > 0;

  bool get currentVipEnabled =>
      hasCurrentVip && _mapBool(currentVip['is_enabled'], fallback: true);

  String get currentVipTitle {
    final value = _cleanMapString(currentVip['title']);
    if (value.isNotEmpty) return value;
    final detailTitle = _cleanMapString(currentVipDetails['title']);
    return detailTitle.isEmpty ? 'VIP' : detailTitle;
  }

  String get currentVipExpiresAt =>
      _cleanMapString(currentVip['expires_at']);

  Future<void> showBackPackList({bool showLoader = true}) async {
    try {
      if (showLoader) isLoading.value = true;

      final response = await _dio.get(
        kBackPackList,
        options: Options(
          headers: {
            'Authorization':
            'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      final body = _asStringMap(response.data);
      final rawHistories = body['asset_histories'];

      if (rawHistories is List) {
        backpackList.assignAll(rawHistories);
      } else if (rawHistories is Map) {
        backpackList.assignAll(rawHistories.values.toList());
      } else {
        backpackList.clear();
      }

      currentVip.assignAll(_asStringMap(body['current_vip']));
      currentVipDetails.assignAll(
        _extractCurrentVipDetails(
          histories: backpackList,
          currentVipMap: currentVip,
        ),
      );
      vipBaseItems.assignAll(_buildVipBaseItems());

      print('Backpack list length: ${backpackList.length}');
      print('VIP base list length: ${vipBaseItems.length}');
    } on DioException catch (e, s) {
      print('Error fetching backpack list: ${e.response?.data ?? e.message}');
      print(s);
      rethrow;
    } catch (e, s) {
      print('Error fetching backpack list: $e');
      print(s);
      rethrow;
    } finally {
      if (showLoader) isLoading.value = false;
    }
  }

  Map<String, dynamic> _extractCurrentVipDetails({
    required Iterable<dynamic> histories,
    required Map<String, dynamic> currentVipMap,
  }) {
    final currentVipId = _mapInt(currentVipMap['vip_id']);

    for (final rawItem in histories) {
      final item = _asStringMap(rawItem);
      final user = _asStringMap(item['user']);
      final purchase = _asStringMap(
        user['vip_purchase_history'] ??
            item['vip_purchase_history'] ??
            item['current_vip_purchase'],
      );

      final directVip = _asStringMap(
        purchase['vip'] ??
            purchase['vip_level'] ??
            item['vip'] ??
            item['vip_level'],
      );

      if (directVip.isNotEmpty) {
        final vipId = _mapInt(directVip['id'] ?? directVip['vip_id']);
        if (currentVipId <= 0 || vipId == currentVipId) return directVip;
      }

      final package = _asStringMap(purchase['package']);
      final packageVip = _asStringMap(
        package['vip_vvip'] ??
            package['vip'] ??
            package['vip_level'],
      );

      if (packageVip.isNotEmpty) {
        final vipId = _mapInt(packageVip['id'] ?? packageVip['vip_id']);
        if (currentVipId <= 0 || vipId == currentVipId) return packageVip;
      }
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _buildVipBaseItems() {
    if (!hasCurrentVip || currentVipDetails.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final expiresAt = currentVipExpiresAt;
    final vipId = _mapInt(currentVip['vip_id']);
    final membershipActive = currentVipEnabled;

    final definitions = <Map<String, dynamic>>[
      {
        'feature_key': 'vip_frame',
        'name': 'VIP Frame',
        'asset': currentVipDetails['frame'],
        'show_image': currentVipDetails['frame_show_image'] ??
            currentVipDetails['frame_show_image_url'],
        'icon': 'frame',
      },
      {
        'feature_key': 'vip_title',
        'name': 'VIP Title',
        'asset': currentVipDetails['title_image'],
        'show_image': currentVipDetails['title_image_show_image'] ??
            currentVipDetails['title_image_show_image_url'],
        'icon': 'title',
      },
      {
        'feature_key': 'vip_badge',
        'name': 'VIP Badge',
        'asset': currentVipDetails['badge_image'],
        'show_image': currentVipDetails['badge_image_show_image'] ??
            currentVipDetails['badge_image_show_image_url'],
        'icon': 'badge',
      },
      {
        'feature_key': 'vip_entry_banner',
        'name': 'VIP Entry Banner',
        'asset': currentVipDetails['entry_banner_image'],
        'show_image': currentVipDetails['entry_banner_image_show_image'] ??
            currentVipDetails['entry_banner_image_show_image_url'],
        'icon': 'entry',
      },
      {
        'feature_key': 'vip_profile_card',
        'name': 'VIP Profile Card',
        'asset': currentVipDetails['profile_card_image'],
        'show_image': currentVipDetails['profile_card_image_show_image'] ??
            currentVipDetails['profile_card_image_show_image_url'],
        'icon': 'profile',
      },
    ];

    return definitions
        .where((item) {
      return _cleanMapString(item['asset']).isNotEmpty ||
          _cleanMapString(item['show_image']).isNotEmpty;
    })
        .map(
          (item) => <String, dynamic>{
        ...item,
        'id': 'vip_${item['feature_key']}',
        'vip_id': vipId,
        'type': 'VIP Base',
        'is_vip_base': true,
        'is_vip_managed': true,
        'can_activate': true,
        'status': membershipActive ? 'Active' : 'Inactive',
        'expires_at': expiresAt,
      },
    )
        .toList();
  }

  bool vipBaseItemEnabled(String featureKey) {
    if (!hasCurrentVip) return false;

    final settingsSources = <Map<String, dynamic>>[
      _asStringMap(currentVip['base_settings']),
      _asStringMap(currentVip['settings']),
      _asStringMap(currentVipDetails['base_settings']),
      _asStringMap(currentVipDetails['user_settings']),
    ];

    for (final source in settingsSources) {
      for (final candidate in _vipBaseSettingCandidates(featureKey)) {
        if (source.containsKey(candidate)) {
          return _mapBool(source[candidate]);
        }
      }
    }

    // Current backend response has one VIP master switch. Until an individual
    // feature setting is returned, every VIP base card follows that switch.
    return currentVipEnabled;
  }

  bool isVipBaseSaving(String featureKey) =>
      vipBaseSavingKeys.contains(featureKey) ||
          vipBaseSavingKeys.contains('is_enabled');

  Future<bool> toggleVipBaseItem({
    required String featureKey,
    required bool value,
  }) async {
    if (!hasCurrentVip || isVipBaseSaving(featureKey)) return false;

    String? serverSettingKey;
    final settingsSources = <Map<String, dynamic>>[
      _asStringMap(currentVip['base_settings']),
      _asStringMap(currentVip['settings']),
      _asStringMap(currentVipDetails['base_settings']),
      _asStringMap(currentVipDetails['user_settings']),
    ];

    for (final source in settingsSources) {
      for (final candidate in _vipBaseSettingCandidates(featureKey)) {
        if (source.containsKey(candidate)) {
          serverSettingKey = candidate;
          break;
        }
      }
      if (serverSettingKey != null) break;
    }

    // The supplied API currently exposes only current_vip.is_enabled.
    // Therefore VIP base items use the real persistent master switch. If the
    // backend later returns per-feature keys, this method automatically sends
    // the exact feature key instead.
    return _updateVipSetting(
      settingKey: serverSettingKey ?? 'is_enabled',
      savingKey: featureKey,
      value: value,
    );
  }

  Future<bool> toggleVipMembership(bool value) {
    return _updateVipSetting(
      settingKey: 'is_enabled',
      savingKey: 'is_enabled',
      value: value,
    );
  }

  Future<bool> _updateVipSetting({
    required String settingKey,
    required String savingKey,
    required bool value,
  }) async {
    if (vipBaseSavingKeys.contains(savingKey)) return false;

    vipBaseSavingKeys.add(savingKey);
    vipBaseSavingKeys.refresh();

    try {
      final response = await _dio.post(
        kVipSettingsUrl,
        data: {
          'key': settingKey,
          'value': value,
        },
        options: Options(
          headers: {
            'Authorization':
            'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      final body = _asStringMap(response.data);


      await showBackPackList(showLoader: false);
      try {
        await homeController.showActiveFrame();
      } catch (_) {}
      return true;
    } on DioException catch (e) {
      Fluttertoast.showToast(
        msg: _dioMessage(e, ('VIP setting update failed').appTr),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14,
      );
      return false;
    } catch (_) {
      Fluttertoast.showToast(
        msg: ('VIP setting update failed').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14,
      );
      return false;
    } finally {
      vipBaseSavingKeys.remove(savingKey);
      vipBaseSavingKeys.refresh();
    }
  }

  ///---------------backpack sending ---------------------

  final backPackSendData = {}.obs;
  final backPackAssetId = ''.obs;
  final backPackReceverId = ''.obs;

  Future<void> sendingAssetBackPack({required String userId}) async {
    final data = {'asset_id': backPackAssetId.value, 'receiver_id': userId};
    try {
      isLoading.value = true;

      ///------------------print section -------------
      print(data);
      print(kBackPackSending);
      print(authController.userProfile.value.token);
      final response = await _dio.post(
        kBackPackSending,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        isLoading.value = false;
        sendingData.value = response.data;
        print(response.data);
        Fluttertoast.showToast(
          msg: ("sending Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        Get.offAll(BottomnavView(), transition: Transition.rightToLeft);
      } else {
        isLoading.value = false;
        Fluttertoast.showToast(
          msg: ("Your credentials doesn't match.").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print(e);
      isLoading.value = false;
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  ///------------------------backpack active ----------------------

  final activeBackPackData = {}.obs;

  Future<void> activeBackPackPost({required String backPackId}) async {
    final data = {
      'asset_id': backPackId,
    };
    try {
      isLoading.value = true;

      ///------------------print section -------------
      print(data);
      print(kBackPackActive);
      print(authController.userProfile.value.token);
      final response = await _dio.post(
        kBackPackActive,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        isLoading.value = false;
        activeBackPackData.value = response.data;
        await homeController.showActiveFrame();
        await showBackPackList(showLoader: false);
        Fluttertoast.showToast(
          msg: (" Actived Success").appTr,

        );

      } else {
        isLoading.value = false;
        Fluttertoast.showToast(
          msg: ("Your credentials doesn't match.").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print(e);
      isLoading.value = false;
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  ///-----------back pack deactiveted--------------------

  final deActiveBackPackData = {}.obs;

  Future<void> deActiveBackPackPost({required String backPackId}) async {
    final data = {
      'asset_id': backPackId,
    };
    try {
      isLoading.value = true;

      ///------------------print section -------------
      print(' alamin data $data');
      print(kBackPackDeActive);
      print(authController.userProfile.value.token);
      final response = await _dio.post(
        kBackPackDeActive,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        isLoading.value = false;
        deActiveBackPackData.value = response.data;
        await homeController.showActiveFrame();
        await showBackPackList(showLoader: false);
        Fluttertoast.showToast(
          msg: ("Deactivated Success").appTr,

        );

      } else {
        isLoading.value = false;
        Fluttertoast.showToast(
          msg: ("Your credentials doesn't match.").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      print(e);
      isLoading.value = false;
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
}

Map<String, dynamic> _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _cleanMapString(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  return text.toLowerCase() == 'null' ? '' : text;
}

int _mapInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(_cleanMapString(value)) ?? 0;
}

bool _mapBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value == 1;

  final text = _cleanMapString(value).toLowerCase();
  if (const {'1', 'true', 'active', 'on', 'yes'}.contains(text)) return true;
  if (const {'0', 'false', 'inactive', 'off', 'no'}.contains(text)) {
    return false;
  }
  return fallback;
}

List<String> _vipBaseSettingCandidates(String featureKey) {
  switch (featureKey) {
    case 'vip_frame':
      return const ['vip_frame', 'vip_frame_enabled', 'frame_enabled'];
    case 'vip_title':
      return const ['vip_title', 'vip_title_enabled', 'title_enabled'];
    case 'vip_badge':
      return const ['vip_badge', 'vip_badge_enabled', 'badge_enabled'];
    case 'vip_entry_banner':
      return const [
        'vip_entry_banner',
        'vip_entry_banner_enabled',
        'entry_banner_enabled',
      ];
    case 'vip_profile_card':
      return const [
        'vip_profile_card',
        'vip_profile_card_enabled',
        'profile_card_enabled',
      ];
    default:
      return <String>[featureKey];
  }
}

String _dioMessage(DioException error, String fallback) {
  final data = error.response?.data;
  if (data is Map && data['message'] != null) {
    return data['message'].toString();
  }
  if (data is Map && data['error'] != null) {
    return data['error'].toString();
  }
  return fallback;
}

