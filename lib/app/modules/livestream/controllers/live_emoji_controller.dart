import 'package:dio/dio.dart' as dio;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../localization/app_localizer.dart';
import '../utils/live_performance_config.dart';
import 'livestream_controller.dart';

/// Owns the livestream animated imogi catalog and send orchestration.
///
/// Received animation queues remain WebSocket-owned because the existing
/// widgets observe those realtime collections directly.
class LiveEmojiController extends GetxController {
  LiveEmojiController(this.owner);

  final LivestreamController owner;

  final imogiLoading = false.obs;
  final imogiSending = false.obs;
  final selectedImogiCategoryIndex = 0.obs;
  final imogiCategoryList = <Map<String, dynamic>>[].obs;
  final imogiList = <Map<String, dynamic>>[].obs;

  int _sendOperation = 0;

  String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic value) {
    if (value is List) return value;
    if (value is Iterable) return value.toList();
    return <dynamic>[];
  }

  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> category) {
    final rawItems =
        category['imogies'] ??
        category['imogi'] ??
        category['emojis'] ??
        category['emoji'] ??
        category['items'] ??
        category['data'] ??
        category['list'] ??
        <dynamic>[];

    return _list(rawItems)
        .map((item) {
          final map = _map(item);
          return <String, dynamic>{
            ...map,
            'id': map['id'] ?? map['imogi_id'] ?? map['emoji_id'],
            'name': map['name'] ?? map['title'] ?? map['imogi_name'] ?? 'Imogi',
            'image':
                map['image'] ??
                map['icon'] ??
                map['imogi_image'] ??
                map['emoji_image'] ??
                map['url'] ??
                map['file'],
            'category_id': map['category_id'] ?? category['id'],
            'category_name': map['category_name'] ?? category['name'],
          };
        })
        .where((item) => item['id'] != null)
        .toList();
  }

  void _normalizeAndSetData(dynamic rawResponse) {
    final root = _map(rawResponse);
    final source =
        root['data'] ??
        root['categories'] ??
        root['category'] ??
        root['imogies'] ??
        root['emojis'] ??
        root['items'] ??
        rawResponse;

    final categories = <Map<String, dynamic>>[];
    final flatImogies = <Map<String, dynamic>>[];

    for (final item in _list(source)) {
      final map = _map(item);
      final itemList = _extractItems(map);
      final looksLikeCategory =
          itemList.isNotEmpty ||
          map.containsKey('imogies') ||
          map.containsKey('emojis') ||
          map.containsKey('items') ||
          map.containsKey('list');

      if (looksLikeCategory) {
        categories.add(<String, dynamic>{
          ...map,
          'id': map['id'] ?? map['category_id'] ?? categories.length,
          'name':
              map['name'] ?? map['title'] ?? map['category_name'] ?? 'Imogi',
          'image': map['image'] ?? map['icon'] ?? map['category_image'],
          'imogies': itemList,
        });
        flatImogies.addAll(itemList);
      } else {
        flatImogies.add(<String, dynamic>{
          ...map,
          'id': map['id'] ?? map['imogi_id'] ?? map['emoji_id'],
          'name': map['name'] ?? map['title'] ?? map['imogi_name'] ?? 'Imogi',
          'image':
              map['image'] ??
              map['icon'] ??
              map['imogi_image'] ??
              map['emoji_image'] ??
              map['url'] ??
              map['file'],
          'category_id': map['category_id'] ?? 0,
          'category_name':
              map['category_name'] ?? map['category'] ?? ('All').appTr,
        });
      }
    }

    if (categories.isEmpty && flatImogies.isNotEmpty) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final imogi in flatImogies) {
        final key = _string(
          imogi['category_id'] ?? imogi['category_name'],
          fallback: '0',
        );
        grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(imogi);
      }

      grouped.forEach((key, value) {
        final first = value.first;
        categories.add(<String, dynamic>{
          'id': first['category_id'] ?? key,
          'name': first['category_name'] ?? 'Imogi',
          'image': first['category_image'] ?? first['image'],
          'imogies': value,
        });
      });
    }

    imogiCategoryList.assignAll(categories);
    imogiList.assignAll(flatImogies);
    if (selectedImogiCategoryIndex.value >= imogiCategoryList.length) {
      selectedImogiCategoryIndex.value = 0;
    }
    liveLog(
      '✅ Imogi normalized => categories:${imogiCategoryList.length} '
      'imogies:${imogiList.length}',
    );
  }

  Future<void> fetchImogiList() async {
    if (imogiLoading.value) return;

    try {
      imogiLoading.value = true;
      final urls = <String>[
        '$kMainUrl/api/imogi_list',
        '$kMainUrl/imogi_list',
        '$kBaseUrl/api/imogi_list',
        '$kBaseUrl/imogi_list',
      ];

      dio.Response? response;
      for (final url in urls) {
        try {
          liveLog('📤 IMOGI LIST URL => $url');
          response = await owner.dio.get(
            url,
            options: dio.Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization':
                    'Bearer ${owner.authController.userProfile.value.token}',
              },
              validateStatus: (status) => true,
            ),
          );
          liveLog('📥 IMOGI LIST STATUS => ${response.statusCode}');
          liveLog('📥 IMOGI LIST RESPONSE => ${response.data}');
          if (response.statusCode == 200 || response.statusCode == 201) break;
        } catch (e) {
          liveLog('⚠️ Imogi list URL failed: $url => $e');
        }
      }

      if (response == null ||
          !(response.statusCode == 200 || response.statusCode == 201)) {
        Fluttertoast.showToast(msg: ('Imogi list load failed').appTr);
        return;
      }
      _normalizeAndSetData(response.data);
    } catch (e) {
      liveLog('❌ fetchImogiList error: $e');
      Fluttertoast.showToast(msg: ('Imogi list load failed').appTr);
    } finally {
      imogiLoading.value = false;
    }
  }

  List<Map<String, dynamic>> getImogiesByCategoryIndex(int index) {
    if (imogiCategoryList.isEmpty) return imogiList;
    final safeIndex = index.clamp(0, imogiCategoryList.length - 1).toInt();
    final list = imogiCategoryList[safeIndex]['imogies'];
    if (list is List) return list.map(_map).toList();
    return <Map<String, dynamic>>[];
  }

  bool isCurrentUserOnMicSeat() {
    final currentUserId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (currentUserId == 0) return false;

    return owner.websocketController.liveCallList.indexWhere((call) {
          final seatNo = _int(call['seat_no']);
          final status = _string(call['call_status']).toLowerCase();
          final callerId = call['caller_id'];
          final user = _map(call['user'] ?? call['User']);
          final userId = user['id'];
          final accepted =
              status.isEmpty ||
              status == 'accepted' ||
              status == 'active' ||
              status == 'joined';
          return accepted &&
              seatNo >= 1 &&
              seatNo <= 20 &&
              (callerId.toString() == currentUserId.toString() ||
                  userId.toString() == currentUserId.toString());
        }) !=
        -1;
  }

  bool _isVipImogi(int imogiId) {
    for (final item in imogiList) {
      if (_int(item['id'] ?? item['imogi_id'] ?? item['emoji_id']) != imogiId) {
        continue;
      }
      final category = _string(
        item['category'] ??
            item['category_name'] ??
            item['type'] ??
            item['group'],
      ).toLowerCase();
      final raw = item['is_vip'] ?? item['vip_only'] ?? item['requires_vip'];
      return category.contains('vip') ||
          raw == true ||
          raw == 1 ||
          raw?.toString().toLowerCase() == 'true' ||
          raw?.toString() == '1';
    }
    return false;
  }

  Future<bool> sendLiveImogi({
    required int streamId,
    required int imogiId,
  }) async {
    if (imogiSending.value) return false;
    final senderId =
        owner.authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (senderId == 0 || streamId == 0 || imogiId == 0) {
      Fluttertoast.showToast(msg: ('Imogi data missing').appTr);
      return false;
    }
    if (_isVipImogi(imogiId) && !owner.currentVipPrivileges.vipEmoji) {
      Fluttertoast.showToast(msg: ('Activate VIP to use VIP Emoji').appTr);
      return false;
    }
    if (!isCurrentUserOnMicSeat()) {
      Fluttertoast.showToast(msg: ('Please join a seat first').appTr);
      return false;
    }

    final operation = ++_sendOperation;
    final roomGeneration = owner.roomSessionGeneration;
    try {
      imogiSending.value = true;
      final data = {
        'sender_id': senderId,
        'imogi_id': imogiId,
        'stream_id': streamId,
      };
      final url = '$kMainUrl/livestream/imogi/send';
      liveLog('📤 IMOGI SEND URL => $url');
      liveLog('📤 IMOGI SEND BODY => $data');

      final response = await owner.dio.post(
        url,
        data: data,
        options: dio.Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization':
                'Bearer ${owner.authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );
      if (operation != _sendOperation ||
          roomGeneration != owner.roomSessionGeneration ||
          !owner.acceptsRoomMutation(streamId)) {
        return false;
      }

      liveLog('📥 IMOGI SEND STATUS => ${response.statusCode}');
      liveLog('📥 IMOGI SEND RESPONSE => ${response.data}');
      if (response.statusCode == 200 || response.statusCode == 201) return true;

      Fluttertoast.showToast(
        msg: response.data is Map && response.data['message'] != null
            ? response.data['message'].toString()
            : ('Imogi send failed').appTr,
      );
      return false;
    } catch (e) {
      if (operation == _sendOperation &&
          roomGeneration == owner.roomSessionGeneration) {
        liveLog('❌ sendLiveImogi error: $e');
        Fluttertoast.showToast(msg: ('Imogi send failed').appTr);
      }
      return false;
    } finally {
      if (operation == _sendOperation &&
          roomGeneration == owner.roomSessionGeneration) {
        imogiSending.value = false;
      }
    }
  }

  void resetRoomEmojiState() {
    _sendOperation++;
    imogiSending.value = false;
    selectedImogiCategoryIndex.value = 0;
  }
}
