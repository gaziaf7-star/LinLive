import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

class NotificationController extends GetxController {
  NotificationController({Dio? dio}) : dio = dio ?? Dio();

  final Dio dio;

  final RxList<Map<String, dynamic>> notificationListData =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isRefreshing = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  bool _requestRunning = false;

  final GetStorage _storage = GetStorage();
  static const String _hiddenNotificationIdsKey =
      'hidden_notification_ids';

  Set<int> get _hiddenNotificationIds {
    final dynamic raw = _storage.read<dynamic>(_hiddenNotificationIdsKey);
    if (raw is! List) return <int>{};

    return raw
        .map<int>(_toInt)
        .where((int id) => id > 0)
        .toSet();
  }

  int get unreadCount => notificationListData.where((item) {
    return !_truthy(item['is_read']);
  }).length;

  @override
  void onInit() {
    super.onInit();
    showNotificationData();
  }

  Future<void> showNotificationData({bool refresh = false}) async {
    if (_requestRunning) return;
    _requestRunning = true;

    if (refresh) {
      isRefreshing.value = true;
    } else if (notificationListData.isEmpty) {
      isLoading.value = true;
    }

    hasError.value = false;
    errorMessage.value = '';

    try {
      final String token =
          authController.userProfile.value.token?.toString().trim() ?? '';

      if (token.isEmpty) {
        throw StateError('Login token is unavailable');
      }

      final Response<dynamic> response = await dio.get(
        kNotificationList,
        queryParameters: <String, dynamic>{
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final Map<String, dynamic> body = _asMap(response.data);
      final bool success = _truthy(body['status'] ?? body['success']);

      if (response.statusCode == 200 && success) {
        final List<dynamic> rawList = _extractList(
          body['giftsr_data'] ??
              body['data'] ??
              body['notifications'] ??
              body,
        );

        final Set<int> hiddenIds = _hiddenNotificationIds;

        final List<Map<String, dynamic>> normalized = rawList
            .map<Map<String, dynamic>>(_asMap)
            .where((Map<String, dynamic> item) => item.isNotEmpty)
            .where((Map<String, dynamic> item) {
          final int id = _toInt(
            item['id'] ?? item['notification_id'],
          );
          return id <= 0 || !hiddenIds.contains(id);
        })
            .toList();

        notificationListData.assignAll(normalized);
        debugPrint(
          '✅ Notifications loaded: ${notificationListData.length}, unread: $unreadCount',
        );
      } else {
        throw StateError(
          body['message']?.toString().trim().isNotEmpty == true
              ? body['message'].toString()
              : 'Failed to load notifications',
        );
      }
    } on DioException catch (error) {
      hasError.value = true;
      errorMessage.value = _dioMessage(error);
      debugPrint('❌ Notification API error: ${error.message}');
    } catch (error, stackTrace) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Bad state: ', '');
      debugPrint('❌ Notification load error: $error');
      debugPrint('$stackTrace');
    } finally {
      _requestRunning = false;
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> refreshNotifications() async {
    await showNotificationData(refresh: true);
  }

  Future<void> markAsRead(int notificationId) async {
    if (notificationId <= 0) return;

    final int index = notificationListData.indexWhere(
          (Map<String, dynamic> item) =>
      _toInt(item['id'] ?? item['notification_id']) == notificationId,
    );

    if (index != -1 && _truthy(notificationListData[index]['is_read'])) {
      return;
    }

    // Optimistic update keeps the UI instant, Facebook-style.
    Map<String, dynamic>? previous;
    if (index != -1) {
      previous = Map<String, dynamic>.from(notificationListData[index]);
      final Map<String, dynamic> updated =
      Map<String, dynamic>.from(notificationListData[index]);
      updated['is_read'] = true;
      updated['read_at'] = DateTime.now().toIso8601String();
      notificationListData[index] = updated;
      notificationListData.refresh();
    }

    try {
      final String token =
          authController.userProfile.value.token?.toString().trim() ?? '';

      final Response<dynamic> response = await dio.post(
        '$kMarkNotificationRead/$notificationId',
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw StateError('Failed to mark notification as read');
      }
    } catch (error) {
      if (index != -1 && previous != null) {
        notificationListData[index] = previous;
        notificationListData.refresh();
      }
      debugPrint('❌ Mark notification read error: $error');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    if (notificationId <= 0) return;

    final int index = notificationListData.indexWhere(
          (Map<String, dynamic> item) =>
      _toInt(item['id'] ?? item['notification_id']) == notificationId,
    );

    if (index == -1) return;

    final Map<String, dynamic> removedNotification =
    Map<String, dynamic>.from(notificationListData[index]);

    // Remove instantly so the UI feels responsive.
    notificationListData.removeAt(index);
    notificationListData.refresh();

    try {
      final Set<int> hiddenIds = _hiddenNotificationIds
        ..add(notificationId);

      await _storage.write(
        _hiddenNotificationIdsKey,
        hiddenIds.toList(growable: false),
      );

      Get.snackbar(
        'Deleted',
        'Notification removed successfully',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (error) {
      // Restore the item if local persistence fails.
      final int safeIndex = index.clamp(
        0,
        notificationListData.length,
      );
      notificationListData.insert(
        safeIndex,
        removedNotification,
      );
      notificationListData.refresh();

      debugPrint('❌ Delete notification error: $error');

      Get.snackbar(
        'Error',
        'Failed to remove notification',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> markAllVisibleAsRead() async {
    final List<int> unreadIds = notificationListData
        .where((Map<String, dynamic> item) => !_truthy(item['is_read']))
        .map<int>((Map<String, dynamic> item) =>
        _toInt(item['id'] ?? item['notification_id']))
        .where((int id) => id > 0)
        .toList();

    for (final int id in unreadIds) {
      await markAsRead(id);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _extractList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);

    final Map<String, dynamic> map = _asMap(value);
    for (final String key in <String>[
      'data',
      'notifications',
      'records',
      'items',
      'giftsr_data',
    ]) {
      final dynamic nested = map[key];
      if (nested is List) return List<dynamic>.from(nested);
      if (nested is Map && nested['data'] is List) {
        return List<dynamic>.from(nested['data']);
      }
    }

    return <dynamic>[];
  }

  String _dioMessage(DioException error) {
    final Map<String, dynamic> body = _asMap(error.response?.data);
    final String serverMessage =
        body['message']?.toString().trim() ?? body['error']?.toString().trim() ?? '';
    if (serverMessage.isNotEmpty) return serverMessage;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Please check your internet connection.';
      default:
        return 'Failed to load notifications.';
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'read' ||
        text == 'success';
  }
}
