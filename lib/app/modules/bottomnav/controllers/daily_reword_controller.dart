import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;

import '../../auth/controllers/auth_controller.dart';

class DailyRewardController extends GetxController {
  DailyRewardController({Dio? dio}) : _dio = dio ?? Dio();

  static const String rewardsEndpoint =
      'https://linlive.fr/api/daily-rewards';

  // Change only this URL if your backend claim route has a different name.
  static const String claimEndpoint =
      'https://linlive.fr/api/daily-rewards/claim';

  final Dio _dio;

  final Rxn<DailyRewardData> rewardData = Rxn<DailyRewardData>();
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool isClaiming = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString actionMessage = ''.obs;

  Future<bool>? _activeFetch;
  DateTime? _lastFetchedAt;

  bool get hasData => rewardData.value?.days.isNotEmpty == true;

  int get currentDay =>
      (rewardData.value?.currentDay ?? 1).clamp(1, 7).toInt();

  bool get canClaim => rewardData.value?.canClaim ?? true;

  Future<bool> fetchDailyRewards({bool force = false}) {
    final active = _activeFetch;
    if (active != null) return active;

    final data = rewardData.value;
    final lastFetchedAt = _lastFetchedAt;
    if (!force &&
        data != null &&
        lastFetchedAt != null &&
        DateTime.now().difference(lastFetchedAt) <
            const Duration(seconds: 20)) {
      return Future<bool>.value(true);
    }

    final request = _fetchDailyRewards(force: force);
    _activeFetch = request;
    return request.whenComplete(() => _activeFetch = null);
  }

  Future<bool> _fetchDailyRewards({required bool force}) async {
    final bool firstLoad = rewardData.value == null;
    if (firstLoad) {
      isLoading.value = true;
    } else {
      isRefreshing.value = true;
    }

    errorMessage.value = '';

    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        rewardsEndpoint,
        options: _requestOptions(),
      );

      if (response.statusCode != 200) {
        errorMessage.value =
            _readMessage(response.data, fallback: 'Daily reward load failed');
        return false;
      }

      final Map<String, dynamic> root = _asMap(response.data);
      if (root['status'] == false) {
        errorMessage.value =
            _readMessage(root, fallback: 'Daily reward load failed');
        return false;
      }

      final Map<String, dynamic> rawData = _asMap(root['data']);
      final DailyRewardData parsed = DailyRewardData.fromJson(
        rawData,
        root: root,
      );

      if (parsed.days.isEmpty) {
        errorMessage.value = 'No active daily rewards found';
        return false;
      }

      rewardData.value = parsed;
      _lastFetchedAt = DateTime.now();
      return true;
    } on DioException catch (error, stackTrace) {
      debugPrint('Daily reward Dio error: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage.value = _dioErrorMessage(error);
      return false;
    } catch (error, stackTrace) {
      debugPrint('Daily reward parse error: $error');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage.value = 'Could not load daily rewards';
      return false;
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<bool> claimToday() async {
    if (isClaiming.value || !canClaim) return false;

    isClaiming.value = true;
    actionMessage.value = '';

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        claimEndpoint,
        data: <String, dynamic>{'day': currentDay},
        options: _requestOptions(),
      );

      final Map<String, dynamic> root = _asMap(response.data);
      final bool explicitFailure =
          root['status'] == false || root['success'] == false;
      final bool success = !explicitFailure &&
          (response.statusCode == 200 ||
              response.statusCode == 201 ||
              root['status'] == true ||
              root['success'] == true);

      actionMessage.value = _readMessage(
        root,
        fallback: success ? 'Daily reward claimed' : 'Reward claim failed',
      );

      if (!success) return false;

      await fetchDailyRewards(force: true);
      return true;
    } on DioException catch (error, stackTrace) {
      debugPrint('Daily reward claim Dio error: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      actionMessage.value = _dioErrorMessage(
        error,
        fallback: 'Reward claim failed',
      );
      return false;
    } catch (error, stackTrace) {
      debugPrint('Daily reward claim error: $error');
      debugPrintStack(stackTrace: stackTrace);
      actionMessage.value = 'Reward claim failed';
      return false;
    } finally {
      isClaiming.value = false;
    }
  }

  Options _requestOptions() {
    final String token = _authToken();
    return Options(
      headers: <String, dynamic>{
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      sendTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (int? status) => status != null && status < 500,
    );
  }

  String _authToken() {
    try {
      if (!Get.isRegistered<AuthController>()) return '';
      final dynamic token =
          Get.find<AuthController>().userProfile.value.token;
      final String value = token?.toString().trim() ?? '';
      return value.toLowerCase() == 'null' ? '' : value;
    } catch (_) {
      return '';
    }
  }

  String _dioErrorMessage(
      DioException error, {
        String fallback = 'Could not load daily rewards',
      }) {
    final String serverMessage = _readMessage(error.response?.data);
    if (serverMessage.isNotEmpty) return serverMessage;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Daily reward request timed out';
      case DioExceptionType.connectionError:
        return 'Please check your internet connection';
      default:
        return fallback;
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    dynamic source = value;
    if (source is String) {
      try {
        source = jsonDecode(source);
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    if (source is Map) {
      return source.map<String, dynamic>(
            (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  static String _readMessage(dynamic value, {String fallback = ''}) {
    final Map<String, dynamic> map = _asMap(value);
    final dynamic raw = map['message'] ?? map['error'] ?? map['msg'];
    final String text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }
}

class DailyRewardData {
  const DailyRewardData({
    required this.title,
    required this.subtitle,
    required this.days,
    required this.currentDay,
    required this.canClaim,
    required this.claimedToday,
    required this.buttonText,
  });

  factory DailyRewardData.fromJson(
      Map<String, dynamic> json, {
        Map<String, dynamic>? root,
      }) {
    final List<DailyRewardDay> parsedDays = _asList(json['days'])
        .map(DailyRewardDay.fromJson)
        .where((DailyRewardDay day) => day.rewards.isNotEmpty)
        .toList()
      ..sort((DailyRewardDay a, DailyRewardDay b) => a.day.compareTo(b.day));

    final int currentDay = _toInt(
      json['current_day'] ??
          json['next_claim_day'] ??
          json['streak_day'] ??
          root?['current_day'],
      fallback: 1,
    ).clamp(1, 7).toInt();

    final bool claimedToday = _toBool(
      json['claimed_today'] ??
          json['is_claimed_today'] ??
          root?['claimed_today'],
    );

    final dynamic rawCanClaim =
        json['can_claim'] ?? root?['can_claim'];
    final bool canClaim = rawCanClaim == null
        ? !claimedToday
        : _toBool(rawCanClaim);

    return DailyRewardData(
      title: _text(json['title'], fallback: 'Daily Reward'),
      subtitle: _text(
        json['subtitle'],
        fallback: 'Sign in for 7 days for rich rewards',
      ),
      days: parsedDays,
      currentDay: currentDay,
      canClaim: canClaim,
      claimedToday: claimedToday,
      buttonText: _text(
        json['button_text'],
        fallback: claimedToday ? 'Claimed Today' : 'Sign In',
      ),
    );
  }

  final String title;
  final String subtitle;
  final List<DailyRewardDay> days;
  final int currentDay;
  final bool canClaim;
  final bool claimedToday;
  final String buttonText;
}

class DailyRewardDay {
  const DailyRewardDay({
    required this.day,
    required this.title,
    required this.isBigReward,
    required this.maxActive,
    required this.rewards,
  });

  factory DailyRewardDay.fromJson(dynamic value) {
    final Map<String, dynamic> json = _asMap(value);
    final int maxActive = _toInt(json['max_active']);
    final List<DailyRewardItem> allRewards = _asList(json['rewards'])
        .map(DailyRewardItem.fromJson)
        .where((DailyRewardItem reward) => reward.isActive)
        .toList();

    final List<DailyRewardItem> visibleRewards = maxActive > 0
        ? allRewards.take(maxActive).toList(growable: false)
        : allRewards;

    final int day = _toInt(json['day'], fallback: 1);
    return DailyRewardDay(
      day: day,
      title: _text(json['title'], fallback: 'Day $day'),
      isBigReward: _toBool(json['is_big_reward']),
      maxActive: maxActive,
      rewards: visibleRewards,
    );
  }

  final int day;
  final String title;
  final bool isBigReward;
  final int maxActive;
  final List<DailyRewardItem> rewards;
}

class DailyRewardItem {
  const DailyRewardItem({
    required this.id,
    required this.day,
    required this.title,
    required this.rewardType,
    required this.icon,
    required this.iconUrl,
    required this.image,
    required this.imageUrl,
    required this.isSvga,
    required this.svgaUrl,
    required this.value,
    required this.expiryDays,
    required this.expiryLabel,
    required this.isActive,
  });

  factory DailyRewardItem.fromJson(dynamic value) {
    final Map<String, dynamic> json = _asMap(value);
    final String iconUrl = _text(json['icon_url']);
    final String imageUrl = _text(json['image_url']);
    final String image = _text(json['image']);
    final String svgaUrl = _text(json['svga_url']);
    final String icon = _text(json['icon']);

    // Backend-generated PNG preview gets first priority. This prevents
    // SVGA/WEBP media from rendering inside the compact daily reward cards.
    final String media = imageUrl.isNotEmpty
        ? imageUrl
        : image.isNotEmpty
        ? image
        : iconUrl.isNotEmpty
        ? iconUrl
        : icon.isNotEmpty
        ? icon
        : svgaUrl;

    return DailyRewardItem(
      id: _toInt(json['id']),
      day: _toInt(json['day']),
      title: _text(json['title'], fallback: 'Reward'),
      rewardType: _text(json['reward_type'], fallback: 'reward'),
      icon: icon,
      iconUrl: iconUrl,
      image: image,
      imageUrl: imageUrl,
      isSvga: media.toLowerCase().split('?').first.endsWith('.svga'),
      svgaUrl: svgaUrl,
      value: _toInt(json['value']),
      expiryDays: json['expiry_days'] == null
          ? null
          : _toInt(json['expiry_days']),
      expiryLabel: _text(json['expiry_label']),
      isActive: json['is_active'] == null
          ? true
          : _toBool(json['is_active']),
    );
  }

  final int id;
  final int day;
  final String title;
  final String rewardType;
  final String icon;
  final String iconUrl;
  final String image;
  final String imageUrl;
  final bool isSvga;
  final String svgaUrl;
  final int value;
  final int? expiryDays;
  final String expiryLabel;
  final bool isActive;

  String get mediaUrl {
    if (imageUrl.isNotEmpty) return imageUrl;
    if (image.isNotEmpty) return image;
    if (iconUrl.isNotEmpty) return iconUrl;
    if (icon.isNotEmpty) return icon;
    return svgaUrl;
  }

  String get bottomLabel {
    if (expiryLabel.isNotEmpty) return expiryLabel;
    if (rewardType.toLowerCase() == 'coin' && value > 0) {
      return _compactNumber(value);
    }
    if (expiryDays != null && expiryDays! > 0) {
      return 'x$expiryDays Days';
    }
    return title;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map<String, dynamic>(
          (dynamic key, dynamic item) =>
          MapEntry<String, dynamic>(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

String _text(dynamic value, {String fallback = ''}) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final String text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes' || text == 'active';
}

String _compactNumber(int value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final double shortValue = value / 1000;
    final String text = shortValue == shortValue.roundToDouble()
        ? shortValue.toStringAsFixed(0)
        : shortValue.toStringAsFixed(1);
    return '${text}K';
  }
  return value.toString();
}
