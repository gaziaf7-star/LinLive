import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../bottomnav/views/bottomnav_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class Store1Controller extends GetxController {
  final dio = Dio();
  final isLoading = false.obs;
  final isFollowingLoading = false.obs;
  final followActionLoadingIds = <int>{}.obs;

  final buyData = {}.obs;

  /// Follower/Following lists
  final followerList = <dynamic>[].obs;
  final filteredFollowerList = <dynamic>[].obs;
  final followingList = <dynamic>[].obs;
  final filteredFollowingList = <dynamic>[].obs;

  /// Current user already follows these user ids.
  final followingUserIds = <int>{}.obs;

  /// Fast local counts. App menu can still use auth profile counts,
  /// but list pages update instantly from these values.
  final totalFollowerCount = 0.obs;
  final totalFollowingCount = 0.obs;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer ${authController.userProfile.value.token}',
    'Accept': 'application/json',
  };

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<dynamic> _extractFollowData(dynamic body) {
    if (body is List) return List<dynamic>.from(body);

    if (body is Map) {
      final map = Map<String, dynamic>.from(body);

      final directKeys = [
        'follow_data',
        'data',
        'followers',
        'following',
        'list',
        'users',
      ];

      for (final key in directKeys) {
        final value = map[key];
        if (value is List) return List<dynamic>.from(value);
        if (value is Map && value['data'] is List) {
          return List<dynamic>.from(value['data']);
        }
      }
    }

    return <dynamic>[];
  }

  int _extractCount(dynamic body, List<String> keys, int fallback) {
    if (body is! Map) return fallback;
    final map = Map<String, dynamic>.from(body);

    for (final key in keys) {
      final value = _safeInt(map[key]);
      if (value > 0) return value;
    }

    final data = map['data'];
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      for (final key in keys) {
        final value = _safeInt(nested[key]);
        if (value > 0) return value;
      }
    }

    return fallback;
  }

  Map<String, dynamic> followerUser(dynamic item) {
    final map = _safeMap(item);
    return _safeMap(
      map['user'] ??
          map['follower'] ??
          map['follower_user'] ??
          map['from_user'] ??
          map['profile'] ??
          map,
    );
  }

  Map<String, dynamic> followingUser(dynamic item) {
    final map = _safeMap(item);
    return _safeMap(
      map['following'] ??
          map['following_user'] ??
          map['to_user'] ??
          map['user'] ??
          map['profile'] ??
          map,
    );
  }

  int userIdFromUserMap(Map<String, dynamic> user) {
    return _safeInt(
      user['id'] ??
          user['user_id'] ??
          user['uid'] ??
          user['unique_id'] ??
          user['profile_id'],
    );
  }

  int userIdFromFollowerItem(dynamic item) => userIdFromUserMap(followerUser(item));
  int userIdFromFollowingItem(dynamic item) => userIdFromUserMap(followingUser(item));

  String userName(Map<String, dynamic> user) {
    final name = (user['name'] ?? user['full_name'] ?? user['username'] ?? ('Unknown').appTr)
        .toString()
        .trim();
    return name.isEmpty || name.toLowerCase() == 'null' ? 'Unknown': name;
  }

  String userImage(Map<String, dynamic> user) {
    return (user['profile_image'] ?? user['avatar'] ?? user['image'] ?? '').toString();
  }

  String userCountry(Map<String, dynamic> user) {
    return (user['country'] ?? '').toString();
  }

  int userLevel(Map<String, dynamic> user) {
    return _safeInt(user['level'] ?? user['user_level'] ?? user['lv']);
  }

  bool isFollowingFlagFromItem(dynamic item) {
    final map = _safeMap(item);
    return _truthy(
      map['is_following'] ??
          map['is_followed'] ??
          map['followed'] ??
          map['following_status'] ??
          map['already_following'],
    );
  }

  bool isUserFollowing(int userId, {dynamic item}) {
    if (userId <= 0) return false;
    if (followingUserIds.contains(userId)) return true;
    if (item != null && isFollowingFlagFromItem(item)) return true;
    return false;
  }

  void _syncFollowingIdsFromList() {
    final ids = <int>{};
    for (final item in followingList) {
      final id = userIdFromFollowingItem(item);
      if (id > 0) ids.add(id);
    }
    followingUserIds
      ..clear()
      ..addAll(ids);
    followingUserIds.refresh();
  }

  void _applySearchSnapshots() {
    filteredFollowerList.assignAll(followerList);
    filteredFollowingList.assignAll(followingList);
  }

  void _toast({
    required String message,
    Color color = Colors.black87,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 13.0,
    );
  }

  String _dioMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return fallback;
  }

  Future buyFream({required int asset_id}) async {
    isLoading.value = true;

    final data = {
      'asset_id': asset_id,
    };

    try {
      final response = await dio.post(
        kFreamPersecs,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        buyData.value = response.data;
        Get.to(
          BottomnavView(),
          transition: Transition.rightToLeft,
        );

        _toast(message: ('Frame Buy Success').appTr, color: Colors.green);
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      Get.snackbar(
        ('Failed').appTr,
        ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshFollowPages({bool silent = true}) async {
    await Future.wait([
      showFollowerList(silent: silent),
      showFollowingList(silent: silent),
    ]);
  }

  Future showFollowerList({bool silent = false}) async {
    isLoading.value = true;
    try {
      final response = await dio.get(
        kFollowerList,
        options: Options(headers: _authHeaders),
      );

      final list = _extractFollowData(response.data);
      followerList.assignAll(list);
      filteredFollowerList.assignAll(list);
      totalFollowerCount.value = _extractCount(
        response.data,
        const ['total_followers', 'followers_count', 'follower_count', 'total'],
        list.length,
      );
    } on DioException catch (e) {
      if (!silent) {
        _toast(message: _dioMessage(e, 'Follower list load failed'), color: Colors.red);
      }
    } catch (_) {
      if (!silent) {
        _toast(message: ('Follower list load failed').appTr, color: Colors.red);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future showFollowingList({bool silent = false}) async {
    isFollowingLoading.value = true;
    try {
      final response = await dio.get(
        kFollowingList,
        options: Options(headers: _authHeaders),
      );

      final list = _extractFollowData(response.data);
      followingList.assignAll(list);
      filteredFollowingList.assignAll(list);
      totalFollowingCount.value = _extractCount(
        response.data,
        const ['total_following', 'followings_count', 'following_count', 'total'],
        list.length,
      );
      _syncFollowingIdsFromList();
    } on DioException catch (e) {
      if (!silent) {
        _toast(message: _dioMessage(e, 'Following list load failed'), color: Colors.red);
      }
    } catch (_) {
      if (!silent) {
        _toast(message: ('Following list load failed').appTr, color: Colors.red);
      }
    } finally {
      isFollowingLoading.value = false;
    }
  }

  void searchByUserId(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) {
      filteredFollowerList.assignAll(followerList);
      return;
    }

    filteredFollowerList.assignAll(
      followerList.where((item) {
        final user = followerUser(item);
        final userId = (user['user_id'] ?? user['id'] ?? '').toString().toLowerCase();
        final name = userName(user).toLowerCase();
        return userId.contains(text) || name.contains(text);
      }).toList(),
    );
  }

  void searchByFollowing(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) {
      filteredFollowingList.assignAll(followingList);
      return;
    }

    filteredFollowingList.assignAll(
      followingList.where((item) {
        final user = followingUser(item);
        final userId = (user['user_id'] ?? user['id'] ?? '').toString().toLowerCase();
        final name = userName(user).toLowerCase();
        return userId.contains(text) || name.contains(text);
      }).toList(),
    );
  }

  Future<bool> followUserFast({
    required int userId,
    Map<String, dynamic>? userData,
  }) async {
    if (userId <= 0 || followActionLoadingIds.contains(userId)) return false;

    final bool wasFollowing = followingUserIds.contains(userId);
    followingUserIds.add(userId);
    followingUserIds.refresh();
    totalFollowingCount.value = mathMaxInt(0, totalFollowingCount.value + (wasFollowing ? 0 : 1));

    followActionLoadingIds.add(userId);
    followActionLoadingIds.refresh();

    try {
      final response = await dio.post(
        kFollowCteate,
        data: {'following_id': userId.toString()},
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _toast(message: ('Follow Success').appTr, color: Colors.green);
        await showFollowingList(silent: true);
        return true;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException catch (e) {
      if (!wasFollowing) {
        followingUserIds.remove(userId);
        followingUserIds.refresh();
        totalFollowingCount.value = mathMaxInt(0, totalFollowingCount.value - 1);
      }
      _toast(message: _dioMessage(e, ('Follow failed').appTr), color: Colors.red);
      return false;
    } catch (_) {
      if (!wasFollowing) {
        followingUserIds.remove(userId);
        followingUserIds.refresh();
        totalFollowingCount.value = mathMaxInt(0, totalFollowingCount.value - 1);
      }
      _toast(message: ('Follow failed').appTr, color: Colors.red);
      return false;
    } finally {
      followActionLoadingIds.remove(userId);
      followActionLoadingIds.refresh();
    }
  }

  Future<bool> unfollowUserFast({
    required int userId,
    bool removeFromFollowingList = false,
  }) async {
    if (userId <= 0 || followActionLoadingIds.contains(userId)) return false;

    final bool wasFollowing = followingUserIds.contains(userId);
    final oldFollowingList = List<dynamic>.from(followingList);
    final oldFilteredFollowingList = List<dynamic>.from(filteredFollowingList);

    followingUserIds.remove(userId);
    followingUserIds.refresh();
    totalFollowingCount.value = mathMaxInt(0, totalFollowingCount.value - (wasFollowing ? 1 : 0));

    if (removeFromFollowingList) {
      followingList.removeWhere((item) => userIdFromFollowingItem(item) == userId);
      filteredFollowingList.removeWhere((item) => userIdFromFollowingItem(item) == userId);
    }

    followActionLoadingIds.add(userId);
    followActionLoadingIds.refresh();

    try {
      final response = await dio.get(
        unFollowUrl(userId),
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _toast(message: ('Unfollow Success').appTr, color: Colors.green);
        await showFollowingList(silent: true);
        return true;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException catch (e) {
      if (wasFollowing) {
        followingUserIds.add(userId);
        followingUserIds.refresh();
        totalFollowingCount.value = mathMaxInt(0, totalFollowingCount.value + 1);
      }
      if (removeFromFollowingList) {
        followingList.assignAll(oldFollowingList);
        filteredFollowingList.assignAll(oldFilteredFollowingList);
      }
      _toast(message: _dioMessage(e, ('Unfollow failed').appTr), color: Colors.red);
      return false;
    } catch (_) {
      if (wasFollowing) {
        followingUserIds.add(userId);
        followingUserIds.refresh();
        totalFollowingCount.value = mathMaxInt(0, totalFollowingCount.value + 1);
      }
      if (removeFromFollowingList) {
        followingList.assignAll(oldFollowingList);
        filteredFollowingList.assignAll(oldFilteredFollowingList);
      }
      _toast(message: ('Unfollow failed').appTr, color: Colors.red);
      return false;
    } finally {
      followActionLoadingIds.remove(userId);
      followActionLoadingIds.refresh();
    }
  }

  Future<void> toggleFollowUser({
    required int userId,
    required bool currentlyFollowing,
    bool removeFromFollowingList = false,
    Map<String, dynamic>? userData,
  }) async {
    if (currentlyFollowing) {
      await unfollowUserFast(
        userId: userId,
        removeFromFollowingList: removeFromFollowingList,
      );
    } else {
      await followUserFast(userId: userId, userData: userData);
    }
  }

  int mathMaxInt(int a, int b) => a > b ? a : b;
}
