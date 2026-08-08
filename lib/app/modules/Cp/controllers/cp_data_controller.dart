import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CpDataController extends GetxController {
  final Dio _dio = Dio();

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxList<CpRequestModel> requests = <CpRequestModel>[].obs;

  final RxBool isLevelLoading = false.obs;
  final RxString levelErrorMessage = ''.obs;
  final RxList<CpLevelModel> cpLevels = <CpLevelModel>[].obs;
  final Rxn<CpCurrentLevelModel> cpCurrentLevel = Rxn<CpCurrentLevelModel>();

  final RxBool isProfileAssetsLoading = false.obs;
  final RxString profileAssetsErrorMessage = ''.obs;
  final RxList<CpBadgeModel> cpBadges = <CpBadgeModel>[].obs;
  final RxList<CpThemeModel> cpThemes = <CpThemeModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchCpData();
    fetchCpLevelData(showLoader: false);
    fetchCpProfileAssets(showLoader: false);
  }

  Options get _authOptions {
    return Options(
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${authController.userProfile.value.token}',
      },
    );
  }

  Future<void> fetchCpData({bool showLoader = true}) async {
    try {
      if (showLoader) isLoading.value = true;
      errorMessage.value = '';

      final response = await _dio.get(
        kCpInviteList,
        options: _authOptions,
      );

      final body = response.data;

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final data = _asMap(body['data']);
        final list = data['requests'] is List ? data['requests'] as List : [];

        requests.assignAll(
          list.map((e) => CpRequestModel.fromJson(e)).toList(),
        );
      } else {
        errorMessage.value =
            _toStr(body is Map ? body['message'] : 'CP data load failed');
      }
    } catch (e) {
      errorMessage.value = e.toString();
      debugPrint('❌ CP data error: $e');
    } finally {
      isLoading.value = false;
    }
  }


  Future<void> fetchCpLevelData({bool showLoader = true}) async {
    try {
      if (showLoader) isLevelLoading.value = true;
      levelErrorMessage.value = '';

      await Future.wait([
        fetchCpLevelList(showLoader: false),
        fetchCpCurrentLevel(showLoader: false),
      ]);
    } catch (e) {
      levelErrorMessage.value = e.toString();
      debugPrint('❌ CP level data error: $e');
    } finally {
      if (showLoader) isLevelLoading.value = false;
    }
  }

  Future<void> fetchCpLevelList({bool showLoader = true}) async {
    try {
      if (showLoader) isLevelLoading.value = true;
      levelErrorMessage.value = '';

      final response = await _dio.get(
        kCpLevelList,
        options: _authOptions,
      );

      final body = response.data;

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final list = body['data'] is List ? body['data'] as List : [];
        final levels = list.map((e) => CpLevelModel.fromJson(e)).toList();
        levels.sort((a, b) => a.levelNo.compareTo(b.levelNo));
        cpLevels.assignAll(levels);
      } else {
        levelErrorMessage.value =
            _toStr(body is Map ? body['message'] : 'CP level list load failed');
      }
    } catch (e) {
      levelErrorMessage.value = e.toString();
      debugPrint('❌ CP level list error: $e');
    } finally {
      if (showLoader) isLevelLoading.value = false;
    }
  }

  Future<void> fetchCpCurrentLevel({bool showLoader = true}) async {
    try {
      if (showLoader) isLevelLoading.value = true;
      levelErrorMessage.value = '';

      final response = await _dio.get(
        kCpCurrentLevelList,
        options: _authOptions,
      );

      final body = response.data;

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        cpCurrentLevel.value = CpCurrentLevelModel.fromJson(body['data']);
      } else {
        levelErrorMessage.value = _toStr(
          body is Map ? body['message'] : 'Current CP level load failed',
        );
      }
    } catch (e) {
      levelErrorMessage.value = e.toString();
      debugPrint('❌ Current CP level error: $e');
    } finally {
      if (showLoader) isLevelLoading.value = false;
    }
  }


  Future<void> fetchCpProfileAssets({bool showLoader = true}) async {
    try {
      if (showLoader) isProfileAssetsLoading.value = true;
      profileAssetsErrorMessage.value = '';

      await Future.wait([
        fetchCpBadgeList(showLoader: false),
        fetchCpThemeList(showLoader: false),
      ]);
    } catch (e) {
      profileAssetsErrorMessage.value = e.toString();
      debugPrint('❌ CP profile assets error: $e');
    } finally {
      if (showLoader) isProfileAssetsLoading.value = false;
    }
  }

  Future<void> fetchCpBadgeList({bool showLoader = true}) async {
    try {
      if (showLoader) isProfileAssetsLoading.value = true;
      profileAssetsErrorMessage.value = '';

      final response = await _dio.get(
        kCpBaseList,
        options: _authOptions,
      );

      final body = response.data;

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final list = body['data'] is List ? body['data'] as List : [];
        final badges = list.map((e) => CpBadgeModel.fromJson(e)).toList();

        badges.sort((a, b) {
          final sort = a.sortOrder.compareTo(b.sortOrder);
          if (sort != 0) return sort;
          return a.id.compareTo(b.id);
        });

        cpBadges.assignAll(badges);
      } else {
        profileAssetsErrorMessage.value = _toStr(
          body is Map ? body['message'] : 'CP badge list load failed',
        );
      }
    } catch (e) {
      profileAssetsErrorMessage.value = e.toString();
      debugPrint('❌ CP badge list error: $e');
    } finally {
      if (showLoader) isProfileAssetsLoading.value = false;
    }
  }

  Future<void> fetchCpThemeList({bool showLoader = true}) async {
    try {
      if (showLoader) isProfileAssetsLoading.value = true;
      profileAssetsErrorMessage.value = '';

      final response = await _dio.get(
        kCpThemeList,
        options: _authOptions,
      );

      final body = response.data;

      if (response.statusCode == 200 && body is Map && body['status'] == true) {
        final list = body['data'] is List ? body['data'] as List : [];
        final themes = list.map((e) => CpThemeModel.fromJson(e)).toList();

        themes.sort((a, b) {
          final sort = a.sortOrder.compareTo(b.sortOrder);
          if (sort != 0) return sort;
          return a.id.compareTo(b.id);
        });

        cpThemes.assignAll(themes);
      } else {
        profileAssetsErrorMessage.value = _toStr(
          body is Map ? body['message'] : 'CP theme list load failed',
        );
      }
    } catch (e) {
      profileAssetsErrorMessage.value = e.toString();
      debugPrint('❌ CP theme list error: $e');
    } finally {
      if (showLoader) isProfileAssetsLoading.value = false;
    }
  }

  CpRequestModel? get acceptedCp {
    for (final item in requests) {
      if (item.status.toLowerCase() == 'accepted') {
        return item;
      }
    }
    return null;
  }
}


class CpLevelModel {
  final int id;
  final int levelNo;
  final String title;
  final int requiredCoins;
  final int status;

  CpLevelModel({
    required this.id,
    required this.levelNo,
    required this.title,
    required this.requiredCoins,
    required this.status,
  });

  factory CpLevelModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpLevelModel(
      id: _toInt(map['id']),
      levelNo: _toInt(map['level_no']),
      title: _toStr(map['title']).isEmpty
          ? 'CP Level ${_toInt(map['level_no'])}'
          : _toStr(map['title']),
      requiredCoins: _toInt(map['required_coins']),
      status: _toInt(map['status']),
    );
  }

  String get shortCoins => cpCompactNumber(requiredCoins);
}

class CpCurrentLevelModel {
  final int coins;
  final CpLevelModel? currentLevel;
  final CpLevelModel? nextLevel;
  final double progressPercent;
  final int needMoreCoins;
  final bool isMaxLevel;

  CpCurrentLevelModel({
    required this.coins,
    required this.currentLevel,
    required this.nextLevel,
    required this.progressPercent,
    required this.needMoreCoins,
    required this.isMaxLevel,
  });

  factory CpCurrentLevelModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpCurrentLevelModel(
      coins: _toInt(map['coins']),
      currentLevel: map['current_level'] == null
          ? null
          : CpLevelModel.fromJson(map['current_level']),
      nextLevel:
      map['next_level'] == null ? null : CpLevelModel.fromJson(map['next_level']),
      progressPercent: _toDouble(map['progress_percent']).clamp(0.0, 100.0).toDouble(),
      needMoreCoins: _toInt(map['need_more_coins']),
      isMaxLevel: _toBool(map['is_max_level']),
    );
  }

  int get currentLevelNo => currentLevel?.levelNo ?? 0;

  String get currentLevelTitle => currentLevel?.title ?? 'Love Level 0';

  String get nextLevelTitle {
    if (isMaxLevel) return 'Max Level Reached';
    return nextLevel?.title ?? 'Next Level';
  }

  int get targetCoins {
    if (isMaxLevel) return coins;
    return nextLevel?.requiredCoins ?? 0;
  }

  double get progressValue => (progressPercent / 100).clamp(0.0, 1.0).toDouble();
}


class CpBadgeModel {
  final int id;
  final String name;
  final String slug;
  final String type;
  final int price;
  final int durationDays;
  final String badgeLevel;
  final String animation;
  final String badgeImage;
  final String badgeImageUrl;
  final String backgroundImage;
  final String backgroundImageUrl;
  final String primaryColor;
  final String secondaryColor;
  final String description;
  final int sortOrder;
  final int status;
  final String createdAt;
  final String updatedAt;

  CpBadgeModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.price,
    required this.durationDays,
    required this.badgeLevel,
    required this.animation,
    required this.badgeImage,
    required this.badgeImageUrl,
    required this.backgroundImage,
    required this.backgroundImageUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.description,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CpBadgeModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpBadgeModel(
      id: _toInt(map['id']),
      name: _toStr(map['name']),
      slug: _toStr(map['slug']),
      type: _toStr(map['type']),
      price: _toInt(map['price']),
      durationDays: _toInt(map['duration_days']),
      badgeLevel: _toStr(map['badge_level']),
      animation: _toStr(map['animation']),
      badgeImage: _toStr(map['badge_image']),
      badgeImageUrl: _toStr(map['badge_image_url']),
      backgroundImage: _toStr(map['background_image']),
      backgroundImageUrl: _toStr(map['background_image_url']),
      primaryColor: _toStr(map['primary_color']).isEmpty
          ? '#ff5d96'
          : _toStr(map['primary_color']),
      secondaryColor: _toStr(map['secondary_color']).isEmpty
          ? '#7c4dff'
          : _toStr(map['secondary_color']),
      description: _toStr(map['description']),
      sortOrder: _toInt(map['sort_order']),
      status: _toInt(map['status']),
      createdAt: _toStr(map['created_at']),
      updatedAt: _toStr(map['updated_at']),
    );
  }

  String get displayName {
    final source = name.isNotEmpty ? name : slug;
    if (source.isEmpty) return 'CP Badge';
    return source
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .map((word) {
      final clean = word.trim();
      return clean[0].toUpperCase() + clean.substring(1);
    }).join(' ');
  }

  String get bestImageUrl {
    if (badgeImageUrl.isNotEmpty) return badgeImageUrl;
    return badgeImage;
  }

  String get bestBackgroundUrl {
    if (backgroundImageUrl.isNotEmpty) return backgroundImageUrl;
    return backgroundImage;
  }

  String get levelText => badgeLevel.isEmpty ? 'CP Badge' : badgeLevel;

  String get priceText => price <= 0 ? 'Free' : '${cpCompactNumber(price)} Coins';

  String get durationText {
    if (durationDays <= 0) return 'Lifetime';
    if (durationDays == 1) return '1 Day';
    return ('$durationDays Days').appTr;
  }
}

class CpThemeModel {
  final int id;
  final String name;
  final String slug;
  final String type;
  final int price;
  final int durationDays;
  final String image;
  final String imageUrl;
  final String themeImage;
  final String themeImageUrl;
  final String backgroundImage;
  final String backgroundImageUrl;
  final String primaryColor;
  final String secondaryColor;
  final String description;
  final int sortOrder;
  final int status;
  final String createdAt;
  final String updatedAt;

  CpThemeModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.price,
    required this.durationDays,
    required this.image,
    required this.imageUrl,
    required this.themeImage,
    required this.themeImageUrl,
    required this.backgroundImage,
    required this.backgroundImageUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.description,
    required this.sortOrder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CpThemeModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpThemeModel(
      id: _toInt(map['id']),
      name: _toStr(map['name']),
      slug: _toStr(map['slug']),
      type: _toStr(map['type']),
      price: _toInt(map['price']),
      durationDays: _toInt(map['duration_days']),
      image: _toStr(map['image']),
      imageUrl: _toStr(map['image_url']),
      themeImage: _toStr(map['theme_image']),
      themeImageUrl: _toStr(map['theme_image_url']),
      backgroundImage: _toStr(map['background_image']),
      backgroundImageUrl: _toStr(map['background_image_url']),
      primaryColor: _toStr(map['primary_color']).isEmpty
          ? '#ff5d96'
          : _toStr(map['primary_color']),
      secondaryColor: _toStr(map['secondary_color']).isEmpty
          ? '#7c4dff'
          : _toStr(map['secondary_color']),
      description: _toStr(map['description']),
      sortOrder: _toInt(map['sort_order']),
      status: _toInt(map['status']),
      createdAt: _toStr(map['created_at']),
      updatedAt: _toStr(map['updated_at']),
    );
  }

  String get displayName {
    final source = name.isNotEmpty ? name : slug;
    if (source.isEmpty) return 'CP Theme';
    return source
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .map((word) {
      final clean = word.trim();
      return clean[0].toUpperCase() + clean.substring(1);
    }).join(' ');
  }

  String get bestImageUrl {
    if (themeImageUrl.isNotEmpty) return themeImageUrl;
    if (imageUrl.isNotEmpty) return imageUrl;
    if (backgroundImageUrl.isNotEmpty) return backgroundImageUrl;
    if (themeImage.isNotEmpty) return themeImage;
    if (image.isNotEmpty) return image;
    return backgroundImage;
  }

  String get priceText => price <= 0 ? 'Free Theme' : '${cpCompactNumber(price)} Coins';

  String get durationText {
    if (durationDays <= 0) return 'Lifetime';
    if (durationDays == 1) return '1 Day';
    return ('$durationDays Days').appTr;
  }
}

class CpRequestModel {
  final int id;
  final String requestNo;
  final String direction;
  final bool isSender;
  final bool isReceiver;
  final int senderId;
  final int receiverId;
  final CpUserModel sender;
  final CpUserModel receiver;
  final CpGiftModel? gift;
  final int giftListId;
  final String type;
  final int quantity;
  final int coin;
  final String message;
  final String status;
  final String statusText;
  final bool canAccept;
  final bool canReject;
  final bool canCancel;
  final String createdAt;
  final String createdDate;
  final String createdTime;
  final String? acceptedAt;
  final String? cancelledAt;

  CpRequestModel({
    required this.id,
    required this.requestNo,
    required this.direction,
    required this.isSender,
    required this.isReceiver,
    required this.senderId,
    required this.receiverId,
    required this.sender,
    required this.receiver,
    required this.gift,
    required this.giftListId,
    required this.type,
    required this.quantity,
    required this.coin,
    required this.message,
    required this.status,
    required this.statusText,
    required this.canAccept,
    required this.canReject,
    required this.canCancel,
    required this.createdAt,
    required this.createdDate,
    required this.createdTime,
    required this.acceptedAt,
    required this.cancelledAt,
  });

  factory CpRequestModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpRequestModel(
      id: _toInt(map['id']),
      requestNo: _toStr(map['request_no']),
      direction: _toStr(map['direction']),
      isSender: _toBool(map['is_sender']),
      isReceiver: _toBool(map['is_receiver']),
      senderId: _toInt(map['sender_id']),
      receiverId: _toInt(map['receiver_id']),
      sender: CpUserModel.fromJson(map['sender']),
      receiver: CpUserModel.fromJson(map['receiver']),
      gift: map['gift'] == null ? null : CpGiftModel.fromJson(map['gift']),
      giftListId: _toInt(map['gift_list_id']),
      type: _toStr(map['type']),
      quantity: _toInt(map['quantity']),
      coin: _toInt(map['coin']),
      message: _toStr(map['message']),
      status: _toStr(map['status']),
      statusText: _toStr(map['status_text']),
      canAccept: _toBool(map['can_accept']),
      canReject: _toBool(map['can_reject']),
      canCancel: _toBool(map['can_cancel']),
      createdAt: _toStr(map['created_at']),
      createdDate: _toStr(map['created_date']),
      createdTime: _toStr(map['created_time']),
      acceptedAt: map['accepted_at']?.toString(),
      cancelledAt: map['cancelled_at']?.toString(),
    );
  }

  CpUserModel get me {
    if (isReceiver) return receiver;
    return sender;
  }

  CpUserModel get partner {
    if (isReceiver) return sender;
    return receiver;
  }

  DateTime get cpStartDate {
    return _parseDate(acceptedAt) ?? _parseDate(createdAt) ?? DateTime.now();
  }

  DateTime get pureStartDate {
    final d = cpStartDate;
    return DateTime(d.year, d.month, d.day);
  }

  int get daysTogether {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(pureStartDate).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  int get monthsTogether {
    return math.max(0, daysTogether ~/ 30);
  }

  int get hoursTogether {
    return daysTogether * 24;
  }

  int get minutesTogether {
    return hoursTogether * 60;
  }

  DateTime get nextAnniversaryDate {
    final now = DateTime.now();
    DateTime next = DateTime(now.year, cpStartDate.month, cpStartDate.day);

    if (!next.isAfter(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, cpStartDate.month, cpStartDate.day);
    }

    return next;
  }

  int get daysLeftForAnniversary {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(
      nextAnniversaryDate.year,
      nextAnniversaryDate.month,
      nextAnniversaryDate.day,
    );

    return next.difference(today).inDays;
  }

  String get coupleId {
    if (requestNo.isNotEmpty) {
      return requestNo.replaceAll('REQ-', 'CP-');
    }
    return 'CP-${cpStartDate.year}-$id';
  }

  String get sinceFullDate => DateFormat('dd MMM yyyy').format(cpStartDate);

  String get anniversaryShort => DateFormat('dd MMM').format(cpStartDate);

  String get nextAnniversaryText =>
      DateFormat('dd MMM yyyy').format(nextAnniversaryDate);

  String get togetherTitle {
    final pName = partner.name.isEmpty ? 'Partner': partner.name;
    return 'You & $pName';
  }
}

class CpUserModel {
  final int id;
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String profileImage;

  CpUserModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImage,
  });

  factory CpUserModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpUserModel(
      id: _toInt(map['id']),
      userId: _toInt(map['user_id']),
      name: _toStr(map['name']),
      email: _toStr(map['email']),
      phone: _toStr(map['phone']),
      profileImage: _toStr(map['profile_image']),
    );
  }
}

class CpGiftModel {
  final int id;
  final String name;
  final String image;
  final int coin;

  CpGiftModel({
    required this.id,
    required this.name,
    required this.image,
    required this.coin,
  });

  factory CpGiftModel.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpGiftModel(
      id: _toInt(map['id']),
      name: _toStr(map['name']),
      image: _toStr(map['image']),
      coin: _toInt(map['coin']),
    );
  }
}

class CpImage extends StatelessWidget {
  const CpImage({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.iconSize = 28,
  });

  final String imageUrl;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _fallback();
    }

    return Image.network(
      _fixImageUrl(imageUrl),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xffffe0ef),
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xffff5d96),
        size: iconSize,
      ),
    );
  }

  String _fixImageUrl(String url) {
    final clean = url.trim();

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    if (clean.startsWith('/')) {
      return 'https://linlive.fr$clean';
    }

    return 'https://linlive.fr/$clean';
  }
}

class CpNoAcceptedView extends StatelessWidget {
  const CpNoAcceptedView({
    super.key,
    required this.title,
    required this.onRefresh,
  });

  final String title;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffff8fb),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xff201d27),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 120),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xfffff4fb),
                      Color(0xffffd7ec),
                      Color(0xfff2ddff),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(.15),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(.70),
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: Color(0xffff5d96),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                     Text(
                      ('No Accepted CP Yet').appTr,
                      style: TextStyle(
                        color: Color(0xff201d27),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ('Accepted CP request hole ei page e profile, love counter, anniversary sob auto show hobe.').appTr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xff201d27).withOpacity(.62),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: onRefresh,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xffff7cab),
                              Color(0xffff4f8f),
                            ],
                          ),
                        ),
                        child:  Center(
                          child: Text(
                            ('Refresh').appTr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CpLoadingPage extends StatelessWidget {
  const CpLoadingPage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffff8fb),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Row(
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xff201d27),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CpShimmerBox.circle(size: 108),
                  SizedBox(width: 18),
                  CpShimmerBox.circle(size: 108),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const CpShimmerBox(width: 170, height: 24, radius: 12),
            const SizedBox(height: 12),
            const CpShimmerBox(width: 230, height: 14, radius: 12),
            const SizedBox(height: 26),
            const CpShimmerBox(width: double.infinity, height: 84, radius: 18),
            const SizedBox(height: 14),
            const CpShimmerBox(width: double.infinity, height: 130, radius: 20),
            const SizedBox(height: 14),
            const CpShimmerBox(width: double.infinity, height: 140, radius: 20),
          ],
        ),
      ),
    );
  }
}

class CpShimmerBox extends StatelessWidget {
  const CpShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 16,
  }) : isCircle = false;

  const CpShimmerBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        radius = size,
        isCircle = true;

  final double width;
  final double height;
  final double radius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    return CpPremiumShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xffffd9ec),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class CpPremiumShimmer extends StatefulWidget {
  const CpPremiumShimmer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CpPremiumShimmer> createState() => _CpPremiumShimmerState();
}

class _CpPremiumShimmerState extends State<CpPremiumShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
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
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final x = _controller.value * 2 - 1;

            return LinearGradient(
              begin: Alignment(-1 + x, 0),
              end: Alignment(1 + x, 0),
              colors: [
                const Color(0xffffd9ec),
                Colors.white.withOpacity(.90),
                const Color(0xffffc7e2),
              ],
              stops: const [.25, .50, .75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

String _toStr(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

bool _toBool(dynamic value) {
  if (value == true) return true;
  if (value == false) return false;
  if (value == 1) return true;
  if (value == 0) return false;

  final text = value.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  try {
    return DateTime.parse(value.replaceAll(' ', 'T'));
  } catch (_) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(value);
    } catch (_) {
      return null;
    }
  }
}

String cpCompactNumber(int value) {
  if (value >= 1000000) {
    final n = value / 1000000;
    return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}M';
  }

  if (value >= 1000) {
    final n = value / 1000;
    return '${n.toStringAsFixed(n >= 10 ? 0 : 1)}K';
  }

  return value.toString();
}