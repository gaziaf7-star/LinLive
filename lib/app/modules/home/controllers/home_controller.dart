import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../accountInfornation/views/account_infornation_view.dart';
import '../../appmenu/views/appmenu_view.dart';
import '../../appmenu/views/widgets/Flower.dart';
import '../../appmenu/views/widgets/FlowingList.dart';
import '../../appmenu/views/widgets/game_test.dart';
import '../../auth/views/profile_view.dart';
import '../../auth/views/userProfileVisit.dart';
import '../../Famaily/view/my_family_api_page.dart';
import '../../livestream/controllers/livestream_controller.dart';
import '../../livestream/widgets/audioText.dart';
import '../../livestream/widgets/write_comments.dart';
import '../../messanger/views/chatpage_view.dart';
import '../../verified/views/verified_view.dart';
import '../../verified/views/widgets/pending_status_page.dart';
import '../views/widgets/unicId.dart';
import '../widgets/manage_popup.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

part '../views/live_profile_bottom_sheet.dart';
class HomeController extends GetxController {
  final _dio = Dio();
  LivestreamController get livestreamController =>
      Get.find<LivestreamController>();
  // Filtered streams
  var filteredStreams = <Map<String, dynamic>>[].obs;
  @override
  void onInit() {
    super.onInit();
    showBannerList();
    baseList();
    Future.microtask(() async {
      await getLivestreamList();
    });
  }

  ///---------------------Active frame -----------------------

  final box = GetStorage();
  final activeFrameData = <String, dynamic>{}.obs;

  Future<void> showActiveFrame() async {
    try {
      final response = await Dio().get(
        kFrameActive,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          responseType: ResponseType.plain,
        ),
      );

      Map<String, dynamic> frameMap = {};

      final responseString = response.data.toString().trim();

      if (responseString.startsWith('{') || responseString.startsWith('[')) {
        // decode JSON
        final decoded = json.decode(responseString);

        if (decoded is Map) {
          // 🔹 normalize active_asset_ids
          final activeAsset = decoded['active_asset_ids'];
          if (activeAsset == null || activeAsset is String) {
            decoded['active_asset_ids'] = {};
          }
          frameMap = Map<String, dynamic>.from(decoded);
        }
      } else {}

      if (frameMap.isNotEmpty) {
        activeFrameData.value = frameMap;
        box.write('activeFrameData', frameMap);
      } else if (box.hasData('activeFrameData')) {
        // 🔹 fallback: normalize active_asset_ids
        final stored = Map<String, dynamic>.from(box.read('activeFrameData'));
        if (stored['active_asset_ids'] == null ||
            stored['active_asset_ids'] is String) {
          stored['active_asset_ids'] = {};
        }
        activeFrameData.value = stored;
      }
    } catch (e, st) {
      if (box.hasData('activeFrameData')) {
        final stored = Map<String, dynamic>.from(box.read('activeFrameData'));
        if (stored['active_asset_ids'] == null ||
            stored['active_asset_ids'] is String) {
          stored['active_asset_ids'] = {};
        }
        activeFrameData.value = stored;
      }
    }
  }


  void updateActiveFrame(Map<String, dynamic> newFrame) {
    activeFrameData.value = newFrame;
    box.write("activeFrameData", newFrame); // save locally
  }

  void clearActiveFrame() {
    activeFrameData.value = {};
    box.remove("activeFrameData");
  }

  ///------------------Earniing data ------------------------
  final dio = Dio();

  final earningData = {}.obs;

  Future showEarningData() async {
    final data = await dio.get(
      kEarningPost,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
          // Correct Bearer Token usage
        },
      ),
    );
    earningData.value = data.data;
    Get.to(AccountInformationView(), transition: Transition.rightToLeft);
  }
  //user block///------------------part
  // ================= API ENDPOINTS ADD/FIX =================
  // Add these in api_endpoints.dart

  // ================= HOME CONTROLLER ADD/FIX =================
  // Paste these inside HomeController class.
  // Replace old userBlock() and userUnBlock() methods.

  final blockedUserList = [].obs;
  final blockListLoading = false.obs;
  final RxSet<int> blockLoadingIds = <int>{}.obs;
  final RxSet<int> unblockLoadingIds = <int>{}.obs;

  final reportHostLoading = false.obs;
  final myReportList = [].obs;
  final allReportList = [].obs;

  Map<String, String> get _authHeaders => {
    'Authorization': 'Bearer ${authController.userProfile.value.token}',
    'Accept': 'application/json',
  };

  String _dioMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return fallback;
  }

  void _toast({
    required String message,
    Color backgroundColor = Colors.black87,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  List<dynamic> _extractBlockedList(dynamic body) {
    if (body is List) {
      return List<dynamic>.from(body);
    }

    if (body is Map) {
      final dynamic data = body['data'];

      /// Backend paginated response:
      /// { data: { data: [ ... ] } }
      if (data is Map && data['data'] is List) {
        return List<dynamic>.from(data['data']);
      }

      /// Simple response:
      /// { data: [ ... ] }
      if (data is List) {
        return List<dynamic>.from(data);
      }

      /// Optional fallback keys
      if (body['blocked_users'] is List) {
        return List<dynamic>.from(body['blocked_users']);
      }

      if (body['blockedUserList'] is List) {
        return List<dynamic>.from(body['blockedUserList']);
      }
    }

    return <dynamic>[];
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _isBlockedItemForUser(dynamic item, int userId) {
    if (item is! Map) return false;

    final Map<String, dynamic> root = Map<String, dynamic>.from(item);

    final dynamic blockedRaw =
        root['blocked_user'] ?? root['user'] ?? root['blocked'];

    if (blockedRaw is Map) {
      final Map<String, dynamic> blocked =
      Map<String, dynamic>.from(blockedRaw);

      final int blockedUserId = _safeInt(
        blocked['id'] ??
            blocked['user_id'] ??
            blocked['blocked_id'] ??
            root['blocked_id'],
      );

      return blockedUserId == userId;
    }

    final int blockedUserId = _safeInt(
      root['blocked_id'] ?? root['id'] ?? root['user_id'],
    );

    return blockedUserId == userId;
  }

  Future<void> getBlockedUserList({bool silent = false}) async {
    try {
      blockListLoading.value = true;

      final response = await dio.get(
        kUserBlockList,
        options: Options(
          headers: {
            ..._authHeaders,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final list = _extractBlockedList(response.data);

      blockedUserList.assignAll(list);
      blockedUserList.refresh();
    } on DioException catch (e) {
      if (!silent) {
        _toast(
          message: _dioMessage(e, 'Block list load failed'),
          backgroundColor: Colors.red,
        );
      }
    } catch (_) {
      if (!silent) {
        _toast(
          message: ('Something went wrong').appTr,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      blockListLoading.value = false;
    }
  }

  Future<void> userBlock({required int userId}) async {
    if (userId <= 0 || blockLoadingIds.contains(userId)) return;

    try {
      blockLoadingIds.add(userId);
      blockLoadingIds.refresh();

      final response = await dio.post(
        kUserBlock(userId),
        options: Options(
          headers: {
            ..._authHeaders,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _toast(
          message: data is Map && data['message'] != null
              ? data['message'].toString()
              : ('User blocked successfully').appTr,
          backgroundColor: Colors.green,
        );

        await getBlockedUserList(silent: true);
        return;
      }

      _toast(
        message: data is Map && data['message'] != null
            ? data['message'].toString()
            : ('Block failed').appTr,
        backgroundColor: Colors.red,
      );
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, ('Block failed').appTr),
        backgroundColor: Colors.red,
      );
    } catch (_) {
      _toast(
        message: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
      );
    } finally {
      blockLoadingIds.remove(userId);
      blockLoadingIds.refresh();
    }
  }

  Future<void> userUnBlock({required int userId}) async {
    if (userId <= 0 || unblockLoadingIds.contains(userId)) return;

    try {
      unblockLoadingIds.add(userId);
      unblockLoadingIds.refresh();

      final response = await dio.post(
        kUserUnBlock(userId),
        options: Options(
          headers: {
            ..._authHeaders,
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data;

      if (response.statusCode == 200 || response.statusCode == 201) {
        /// Realtime local remove
        blockedUserList.removeWhere(
              (item) => _isBlockedItemForUser(item, userId),
        );
        blockedUserList.refresh();

        _toast(
          message: data is Map && data['message'] != null
              ? data['message'].toString()
              : ('User unblocked successfully').appTr,
          backgroundColor: Colors.green,
        );

        /// Backend sync
        await getBlockedUserList(silent: true);
        return;
      }

      _toast(
        message: data is Map && data['message'] != null
            ? data['message'].toString()
            : ('Unblock failed').appTr,
        backgroundColor: Colors.red,
      );
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, ('Unblock failed').appTr),
        backgroundColor: Colors.red,
      );
    } catch (_) {
      _toast(
        message: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
      );
    } finally {
      unblockLoadingIds.remove(userId);
      unblockLoadingIds.refresh();
    }
  }

  Future<void> reportHost({
    required int livestreamId,
    required int hostId,
    required String reason,
    required String description,
  }) async {
    if (reportHostLoading.value) return;

    if (livestreamId <= 0) {
      _toast(
        message: ('Live room information missing. Please re-enter the room and try again.').appTr,
        backgroundColor: Colors.red,
      );
      return;
    }

    if (hostId <= 0) {
      _toast(
        message: ('Invalid user').appTr,
        backgroundColor: Colors.red,
      );
      return;
    }

    final String cleanReason = reason.trim().isEmpty ? 'other' : reason.trim();
    final String cleanDescription = description.trim();

    if (cleanDescription.length < 5) {
      _toast(
        message: ('Please write a short description').appTr,
        backgroundColor: Colors.red,
      );
      return;
    }

    try {
      reportHostLoading.value = true;

      final Map<String, dynamic> payload = {
        'livestream_id': livestreamId,
        'host_id': hostId,
        'user_id': hostId,
        'reported_user_id': hostId,
        'reason': cleanReason,
        'description': cleanDescription,
      };

      final response = await dio.post(
        kReportHost,
        data: payload,
        options: Options(
          headers: {
            ..._authHeaders,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (Get.isDialogOpen == true) {
          Get.back();
        }

        _toast(
          message: data is Map && data['message'] != null
              ? data['message'].toString()
              : ('Report submitted successfully').appTr,
          backgroundColor: Colors.green,
        );
        return;
      }

      String errorMessage = 'Report submit failed';

      if (data is Map) {
        if (data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (data['errors'] is Map) {
          final errors = Map<String, dynamic>.from(data['errors']);
          if (errors.isNotEmpty) {
            final first = errors.values.first;
            if (first is List && first.isNotEmpty) {
              errorMessage = first.first.toString();
            } else {
              errorMessage = first.toString();
            }
          }
        }
      }

      _toast(
        message: errorMessage,
        backgroundColor: Colors.red,
      );
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, 'Report submit failed'),
        backgroundColor: Colors.red,
      );
    } catch (_) {
      _toast(message: ('Something went wrong').appTr, backgroundColor: Colors.red);
    } finally {
      reportHostLoading.value = false;
    }
  }

  Future<void> getMySubmittedReports() async {
    try {
      final response = await dio.get(
        kMySubmittedReports,
        options: Options(headers: _authHeaders),
      );

      final data = response.data;
      if (data is Map && data['data'] is List) {
        myReportList.value = data['data'];
      } else if (data is List) {
        myReportList.value = data;
      } else {
        myReportList.clear();
      }
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, 'Report list load failed'),
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> getAllLivestreamReports() async {
    try {
      final response = await dio.get(
        kAllLivestreamReports,
        options: Options(headers: _authHeaders),
      );

      final data = response.data;
      if (data is Map && data['data'] is List) {
        allReportList.value = data['data'];
      } else if (data is List) {
        allReportList.value = data;
      } else {
        allReportList.clear();
      }
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, 'All report list load failed'),
        backgroundColor: Colors.red,
      );
    }
  }

  ///----------------------------------- user List Data ------------------------
  final allUserData = [].obs;
  final searchController = TextEditingController();

  Future showAllUserData() async {
    try {
      final data = await dio.get(kAllUserList);
      final body = data.data;

      if (body is Map && body['data'] is List) {
        allUserData.value = body['data'];
      } else if (body is List) {
        allUserData.value = body;
      } else {
        allUserData.clear();
      }

      // User list contains host country in many APIs. After it loads,
      // re-sort live list so selected country cards come first smoothly.
      if (showingLiveStreamList.isNotEmpty) {
        _sortLiveStreamList();
      }

      debugPrint('✅ All user data loaded => ${allUserData.length}');
    } catch (e) {
      debugPrint('❌ All user data load failed => $e');
    }
  }

  final traderListData = [].obs;

  Future showAllTraderData() async {
    final data = await dio.get(
      kCoinTradingGet,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${authController.userProfile.value.token}',
          // Correct Bearer Token usage
        },
      ),
    );
    traderListData.value = data.data['trade_history'];
    print(traderListData);
  }

  final withdrawRequestList = [].obs;
  final withdrawHistoryList = [].obs;

  final withdrawRequestLoading = false.obs;
  final withdrawHistoryLoading = false.obs;

  final RxSet<int> acceptLoadingIds = <int>{}.obs;
  final RxSet<int> rejectLoadingIds = <int>{}.obs;

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is Map && responseData['data'] is List) {
      return List<dynamic>.from(responseData['data']);
    }

    if (responseData is Map && responseData['history'] is List) {
      return List<dynamic>.from(responseData['history']);
    }

    if (responseData is Map && responseData['withdraw_history'] is List) {
      return List<dynamic>.from(responseData['withdraw_history']);
    }

    if (responseData is List) {
      return List<dynamic>.from(responseData);
    }

    return <dynamic>[];
  }

  String _statusText(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';

    if (status == 'accept' || status == 'accepted' || status == 'approve' || status == 'approved') {
      return 'Accepted';
    }

    if (status == 'reject' || status == 'rejected' || status == 'decline' || status == 'declined') {
      return 'Rejected';
    }

    return ('Pending').appTr;
  }

  Future<void> showWithdrawRequest() async {
    try {
      withdrawRequestLoading.value = true;

      final response = await dio.get(
        kWithdrawRequest,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _extractList(response.data);

        withdrawRequestList.value = list.where((item) {
          if (item is! Map) return false;
          final status = _statusText(item['status']);
          return status.toLowerCase() == 'pending';
        }).toList();

        print('✅ Withdraw pending request list: $withdrawRequestList');
      } else {
        Fluttertoast.showToast(
          msg: ("Withdraw request load failed").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('❌ Withdraw request list Dio error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ("Withdraw request load failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ Withdraw request list error: $e');

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      withdrawRequestLoading.value = false;
    }
  }

  Future<void> showWithdrawHistory() async {
    try {
      withdrawHistoryLoading.value = true;

      final response = await dio.get(
        kWithdrawRequest,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final list = _extractList(response.data);

        withdrawHistoryList.value = list.where((item) {
          if (item is! Map) return false;
          final status = _statusText(item['status']);
          return status.toLowerCase() == 'accepted' ||
              status.toLowerCase() == 'rejected';
        }).toList();

        print('✅ Withdraw history list: $withdrawHistoryList');
      } else {
        Fluttertoast.showToast(
          msg: ("Withdraw history load failed").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('❌ Withdraw history Dio error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ("Withdraw history load failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ Withdraw history error: $e');

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      withdrawHistoryLoading.value = false;
    }
  }

  Future<void> refreshWithdrawAll() async {
    await Future.wait([
      showWithdrawRequest(),
      showWithdrawHistory(),
    ]);
  }

  Future<void> showWithdrawRequestAccept({required int ID}) async {
    if (acceptLoadingIds.contains(ID) || rejectLoadingIds.contains(ID)) {
      return;
    }

    try {
      acceptLoadingIds.add(ID);
      acceptLoadingIds.refresh();

      final oldItem = withdrawRequestList.firstWhereOrNull(
            (item) => item is Map && item['id'].toString() == ID.toString(),
      );

      final response = await dio.post(
        kWithdrawRequestAccept(id: ID),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        withdrawRequestList.removeWhere(
              (item) => item is Map && item['id'].toString() == ID.toString(),
        );
        withdrawRequestList.refresh();

        if (oldItem is Map) {
          final historyItem = Map<String, dynamic>.from(oldItem);
          historyItem['status'] = 'Accepted';
          historyItem['action_status'] = 'Accepted';
          historyItem['updated_at'] = DateTime.now().toIso8601String();

          withdrawHistoryList.insert(0, historyItem);
          withdrawHistoryList.refresh();
        }

        Fluttertoast.showToast(
          msg: response.data['message']?.toString() ??
              ("Withdraw request accepted").appTr,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        await showWithdrawHistory();
      } else {
        Fluttertoast.showToast(
          msg: ("Accept failed").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('❌ Accept Dio error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ?? ("Accept failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ Accept error: $e');

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      acceptLoadingIds.remove(ID);
      acceptLoadingIds.refresh();
    }
  }

  Future<void> showWithdrawRequestReject({required int ID}) async {
    if (acceptLoadingIds.contains(ID) || rejectLoadingIds.contains(ID)) {
      return;
    }

    try {
      rejectLoadingIds.add(ID);
      rejectLoadingIds.refresh();

      final oldItem = withdrawRequestList.firstWhereOrNull(
            (item) => item is Map && item['id'].toString() == ID.toString(),
      );

      final response = await dio.post(
        kWithdrawRequestReject(id: ID),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        withdrawRequestList.removeWhere(
              (item) => item is Map && item['id'].toString() == ID.toString(),
        );
        withdrawRequestList.refresh();

        if (oldItem is Map) {
          final historyItem = Map<String, dynamic>.from(oldItem);
          historyItem['status'] = 'Rejected';
          historyItem['action_status'] = 'Rejected';
          historyItem['updated_at'] = DateTime.now().toIso8601String();

          withdrawHistoryList.insert(0, historyItem);
          withdrawHistoryList.refresh();
        }

        Fluttertoast.showToast(
          msg: response.data['message']?.toString() ??
              ("Withdraw request rejected").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );

        await showWithdrawHistory();
      } else {
        Fluttertoast.showToast(
          msg: ("Reject failed").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('❌ Reject Dio error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ?? ("Reject failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ Reject error: $e');


    } finally {
      rejectLoadingIds.remove(ID);
      rejectLoadingIds.refresh();
    }
  }

  //---------------------- Showing live stream list

  final isLoading = false.obs;
  final isLoadingMoreLive = false.obs;
  final RxList<dynamic> showingLiveStreamList = <dynamic>[].obs;

  final liveCurrentPage = 1.obs;
  final liveLastPage = 1.obs;
  final livePerPage = 10.obs;
  final liveHasMore = true.obs;

  bool get canLoadMoreLive =>
      liveHasMore.value && !isLoading.value && !isLoadingMoreLive.value;

  /// Professional live country sorter/filter.
  /// Important: livestream list response sometimes does NOT include country
  /// inside the live object. So we resolve country from:
  /// 1) live object fields
  /// 2) broadcaster/caller user object inside livestream_callers
  /// 3) allUserData user list by host id/user_id
  /// Then selected country live cards come first, other country lives stay below.
  final RxString selectedLiveCountryName = 'Global'.obs;
  final RxString selectedLiveCountryFlag = '🌐'.obs;
  final RxInt selectedLiveCountryMatchCount = 0.obs;

  /// UI te only available live countries show korar jonno.
  /// Format: {'name': 'Bangladesh', 'key': 'bangladesh', 'flag': '🇧🇩', 'count': '4'}
  final RxList<Map<String, String>> availableLiveCountryOptions =
      <Map<String, String>>[].obs;

  String _cleanLiveText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null' || text == '0') return '';
    return text;
  }

  String _normalizeLiveCountry(dynamic value) {
    String text = _cleanLiveText(value).toLowerCase();
    if (text.isEmpty) return '';

    text = text
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const aliases = {
      'usa': 'united states',
      'us': 'united states',
      'u s a': 'united states',
      'america': 'united states',
      'united states of america': 'united states',
      'uk': 'united kingdom',
      'u k': 'united kingdom',
      'england': 'united kingdom',
      'uae': 'united arab emirates',
      'u a e': 'united arab emirates',
      'ksa': 'saudi arabia',
      'saudia': 'saudi arabia',
      'bd': 'bangladesh',
    };

    return aliases[text] ?? text;
  }


  String _countryDisplayName(String normalizedCountry) {
    final text = normalizedCountry.trim().toLowerCase();
    if (text.isEmpty) return '';

    const names = {
      'bangladesh': 'Bangladesh',
      'india': 'India',
      'iraq': 'Iraq',
      'pakistan': 'Pakistan',
      'united states': 'United States',
      'united kingdom': 'United Kingdom',
      'united arab emirates': 'United Arab Emirates',
      'saudi arabia': 'Saudi Arabia',
      'nepal': 'Nepal',
      'sri lanka': 'Sri Lanka',
      'indonesia': 'Indonesia',
      'malaysia': 'Malaysia',
      'philippines': 'Philippines',
      'singapore': 'Singapore',
      'qatar': 'Qatar',
      'kuwait': 'Kuwait',
      'oman': 'Oman',
      'bahrain': 'Bahrain',
      'turkey': 'Turkey',
      'egypt': 'Egypt',
      'morocco': 'Morocco',
      'canada': 'Canada',
      'australia': 'Australia',
    };

    if (names.containsKey(text)) return names[text]!;

    return text
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.substring(0, 1).toUpperCase() + e.substring(1))
        .join(' ');
  }

  String _countryFlag(String normalizedCountry) {
    final text = normalizedCountry.trim().toLowerCase();

    const flags = {
      'bangladesh': '🇧🇩',
      'india': '🇮🇳',
      'iraq': '🇮🇶',
      'pakistan': '🇵🇰',
      'united states': '🇺🇸',
      'united kingdom': '🇬🇧',
      'united arab emirates': '🇦🇪',
      'saudi arabia': '🇸🇦',
      'nepal': '🇳🇵',
      'sri lanka': '🇱🇰',
      'indonesia': '🇮🇩',
      'malaysia': '🇲🇾',
      'philippines': '🇵🇭',
      'singapore': '🇸🇬',
      'qatar': '🇶🇦',
      'kuwait': '🇰🇼',
      'oman': '🇴🇲',
      'bahrain': '🇧🇭',
      'turkey': '🇹🇷',
      'egypt': '🇪🇬',
      'morocco': '🇲🇦',
      'canada': '🇨🇦',
      'australia': '🇦🇺',
    };

    return flags[text] ?? '🌍';
  }

  void _refreshAvailableLiveCountries(List<dynamic> liveList) {
    final Map<String, int> counts = {};

    for (final raw in liveList) {
      if (raw is! Map) continue;

      final country = _countryOfLive(raw);
      if (country.isEmpty) continue;

      counts[country] = (counts[country] ?? 0) + 1;
    }

    final options = counts.entries.map((entry) {
      return {
        'key': entry.key,
        'name': _countryDisplayName(entry.key),
        'flag': _countryFlag(entry.key),
        'count': entry.value.toString(),
      };
    }).toList();

    options.sort((a, b) {
      final countA = int.tryParse(a['count'] ?? '0') ?? 0;
      final countB = int.tryParse(b['count'] ?? '0') ?? 0;
      if (countA != countB) return countB.compareTo(countA);
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });

    availableLiveCountryOptions.assignAll(options);

  }

  Map<String, dynamic> _liveAsMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _countryFromMap(Map<String, dynamic> map) {
    return _normalizeLiveCountry(
      map['country'] ??
          map['country_name'] ??
          map['stream_country'] ??
          map['permisioncountry'] ??
          map['permission_country'] ??
          map['location_country'] ??
          map['host_country'] ??
          map['countryName'],
    );
  }

  Map<String, dynamic> _broadcasterUserFromLive(Map<String, dynamic> item) {
    if (item['user'] is Map) return _liveAsMap(item['user']);
    if (item['User'] is Map) return _liveAsMap(item['User']);
    if (item['sender_host'] is Map) return _liveAsMap(item['sender_host']);
    if (item['receiver_host'] is Map) return _liveAsMap(item['receiver_host']);

    final callers = item['livestream_callers'];
    if (callers is List && callers.isNotEmpty) {
      for (final rawCaller in callers) {
        if (rawCaller is! Map) continue;
        final caller = _liveAsMap(rawCaller);
        final bool isBroadcaster = caller['is_broadcaster'] == true ||
            caller['is_broadcaster'] == 1 ||
            caller['is_broadcaster']?.toString() == '1' ||
            caller['caller_id']?.toString() == item['user_id']?.toString();

        if (isBroadcaster) {
          if (caller['user'] is Map) return _liveAsMap(caller['user']);
          if (caller['User'] is Map) return _liveAsMap(caller['User']);
          return caller;
        }
      }

      final first = callers.first;
      if (first is Map) {
        final caller = _liveAsMap(first);
        if (caller['user'] is Map) return _liveAsMap(caller['user']);
        if (caller['User'] is Map) return _liveAsMap(caller['User']);
      }
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _findUserFromAllUserData(Map<String, dynamic> liveItem) {
    final Map<String, dynamic> liveUser = _broadcasterUserFromLive(liveItem);

    final String hostDbId = _cleanLiveText(
      liveItem['user_id'] ?? liveItem['host_id'] ?? liveItem['broadcaster_id'],
    );
    final String roomId = _cleanLiveText(liveItem['room_id']);
    final String nestedDbId = _cleanLiveText(liveUser['id']);
    final String nestedPublicId = _cleanLiveText(liveUser['user_id']);

    for (final rawUser in allUserData) {
      if (rawUser is! Map) continue;
      final user = _liveAsMap(rawUser);

      final String id = _cleanLiveText(user['id']);
      final String publicId = _cleanLiveText(user['user_id']);
      final String uniqueId = _cleanLiveText(user['unique_id']);

      if (hostDbId.isNotEmpty && id == hostDbId) return user;
      if (roomId.isNotEmpty && id == roomId) return user;
      if (nestedDbId.isNotEmpty && id == nestedDbId) return user;
      if (nestedPublicId.isNotEmpty && publicId == nestedPublicId) return user;
      if (nestedPublicId.isNotEmpty && uniqueId == nestedPublicId) return user;
    }

    return <String, dynamic>{};
  }

  String _countryOfLive(dynamic raw) {
    if (raw is! Map) return '';

    final item = _liveAsMap(raw);

    // 1) Direct live fields.
    final directCountry = _countryFromMap(item);
    if (directCountry.isNotEmpty) return directCountry;

    // 2) Broadcaster user object from live response.
    final liveUser = _broadcasterUserFromLive(item);
    final liveUserCountry = _countryFromMap(liveUser);
    if (liveUserCountry.isNotEmpty) return liveUserCountry;

    // 3) Full user list lookup. This fixes your current API response where
    // livestream_callers.user does not include country.
    final listUser = _findUserFromAllUserData(item);
    final listUserCountry = _countryFromMap(listUser);
    if (listUserCountry.isNotEmpty) return listUserCountry;

    // 4) Current logged-in user fallback only for own live.
    final myUser = authController.userProfile.value.user;
    final myId = _cleanLiveText(myUser?.id);
    final hostId = _cleanLiveText(item['user_id']);
    if (myId.isNotEmpty && hostId == myId) {
      return _normalizeLiveCountry(myUser?.country);
    }

    return '';
  }

  bool _isSelectedCountryLive(dynamic raw) {
    final selected = _normalizeLiveCountry(selectedLiveCountryName.value);

    if (selected.isEmpty || selected == 'global' || selected == 'all') {
      return false;
    }

    final liveCountry = _countryOfLive(raw);
    if (liveCountry.isEmpty) return false;

    return liveCountry == selected ||
        liveCountry.contains(selected) ||
        selected.contains(liveCountry);
  }

  void changeLiveCountry({
    required String name,
    required String flagEmoji,
  }) {
    final cleanName = name.trim().isEmpty ? 'Global' : name.trim();
    final normalized = _normalizeLiveCountry(cleanName);

    if (normalized.isEmpty || normalized == 'global' || normalized == 'all') {
      selectedLiveCountryName.value = 'Global';
      selectedLiveCountryFlag.value = '🌐';
    } else {
      selectedLiveCountryName.value = _countryDisplayName(normalized);
      selectedLiveCountryFlag.value = flagEmoji.trim().isEmpty
          ? _countryFlag(normalized)
          : flagEmoji.trim();
    }

    debugPrint(
      '🌍 Selected live country => ${selectedLiveCountryFlag.value} ${selectedLiveCountryName.value}',
    );

    _sortLiveStreamList();
  }

  int _liveIdOf(dynamic raw) {
    if (raw is! Map) return 0;
    return int.tryParse(
      (raw['id'] ?? raw['livestream_id'] ?? raw['stream_id'] ?? '0')
          .toString(),
    ) ??
        0;
  }

  bool _isOwnActiveLive(dynamic raw) {
    if (raw is! Map) return false;
    final myId =
        livestreamController.authController.userProfile.value.user?.id
            ?.toInt() ??
            0;
    final hostId =
        int.tryParse(
          (raw['user_id'] ??
              raw['host_id'] ??
              raw['broadcaster_id'] ??
              raw['user']?['id'] ??
              '0')
              .toString(),
        ) ??
            0;
    final liveId = _liveIdOf(raw);
    return myId > 0 &&
        hostId == myId &&
        liveId == livestreamController.streamId.value;
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _liveUniqueKey(dynamic raw) {
    if (raw is! Map) return raw.hashCode.toString();

    final item = Map<String, dynamic>.from(raw);
    final id = item['id'] ?? item['livestream_id'] ?? item['stream_id'];
    if (id != null && id.toString().trim().isNotEmpty && id.toString() != '0') {
      return 'live_${id.toString()}';
    }

    final roomId = item['room_id'] ?? item['user_id'] ?? item['owner_user_id'];
    if (roomId != null && roomId.toString().trim().isNotEmpty) {
      return 'room_${roomId.toString()}';
    }

    return raw.hashCode.toString();
  }


  bool _homeHasRealUserMap(dynamic value) {
    if (value is! Map) return false;
    final user = Map<String, dynamic>.from(value);
    return _cleanLiveText(user['name']).isNotEmpty ||
        _cleanLiveText(user['username']).isNotEmpty ||
        _cleanLiveText(user['profile_image']).isNotEmpty ||
        _cleanLiveText(user['image']).isNotEmpty;
  }

  bool _homeBadLiveImage(dynamic value) {
    final url = _cleanLiveText(value).toLowerCase();
    return url.isEmpty ||
        url.contains('photosbulk.com') ||
        url.contains('hijab-girl-pic_108.webp');
  }

  Map<String, dynamic> _mergeLiveItemKeepingRichData(dynamic oldRaw, dynamic newRaw) {
    if (oldRaw is! Map || newRaw is! Map) {
      return newRaw is Map ? Map<String, dynamic>.from(newRaw) : <String, dynamic>{};
    }

    final oldItem = Map<String, dynamic>.from(oldRaw);
    final newItem = Map<String, dynamic>.from(newRaw);
    final merged = <String, dynamic>{...oldItem, ...newItem};

    if (!_homeHasRealUserMap(newItem['user']) && _homeHasRealUserMap(oldItem['user'])) {
      merged['user'] = oldItem['user'];
    }
    if (!_homeHasRealUserMap(newItem['User']) && _homeHasRealUserMap(oldItem['User'])) {
      merged['User'] = oldItem['User'];
    }

    for (final key in ['stream_bte', 'name', 'title']) {
      if (_cleanLiveText(merged[key]).isEmpty && _cleanLiveText(oldItem[key]).isNotEmpty) {
        merged[key] = oldItem[key];
      }
    }

    for (final key in ['stream_image', 'stream_img', 'image', 'cover_image', 'profile_image']) {
      if (_homeBadLiveImage(merged[key]) && !_homeBadLiveImage(oldItem[key])) {
        merged[key] = oldItem[key];
      }
    }

    return merged;
  }

  List<dynamic> _mergeLiveListsUnique({
    required List<dynamic> oldList,
    required List<dynamic> newList,
    required bool append,
  }) {
    final Map<String, dynamic> merged = <String, dynamic>{};

    void putLiveItem(dynamic item) {
      final key = _liveUniqueKey(item);
      if (merged.containsKey(key)) {
        merged[key] = _mergeLiveItemKeepingRichData(merged[key], item);
      } else {
        merged[key] = item;
      }
    }

    if (append) {
      for (final oldItem in oldList) {
        putLiveItem(oldItem);
      }
    }

    for (final newItem in newList) {
      putLiveItem(newItem);
    }

    return merged.values.toList();
  }

  void _updateLivePagination(dynamic body, int requestedPage, int perPage) {
    if (body is Map && body['pagination'] is Map) {
      final pagination = Map<String, dynamic>.from(body['pagination']);

      liveCurrentPage.value =
          int.tryParse('${pagination['current_page'] ?? requestedPage}') ??
              requestedPage;
      liveLastPage.value =
          int.tryParse('${pagination['last_page'] ?? liveCurrentPage.value}') ??
              liveCurrentPage.value;
      livePerPage.value =
          int.tryParse('${pagination['per_page'] ?? perPage}') ?? perPage;

      final dynamic hasMoreValue = pagination['has_more'];
      if (hasMoreValue is bool) {
        liveHasMore.value = hasMoreValue;
      } else {
        final nextPage = pagination['next_page'];
        liveHasMore.value = nextPage != null &&
            nextPage.toString().trim().isNotEmpty &&
            nextPage.toString() != 'null';
      }
      return;
    }

    // Laravel default paginate response support.
    if (body is Map && body['current_page'] != null) {
      liveCurrentPage.value =
          int.tryParse('${body['current_page'] ?? requestedPage}') ??
              requestedPage;
      liveLastPage.value =
          int.tryParse('${body['last_page'] ?? liveCurrentPage.value}') ??
              liveCurrentPage.value;
      livePerPage.value = int.tryParse('${body['per_page'] ?? perPage}') ?? perPage;
      liveHasMore.value = liveCurrentPage.value < liveLastPage.value;
      return;
    }

    // Old API fallback.
    liveCurrentPage.value = requestedPage;
    liveLastPage.value = requestedPage;
    livePerPage.value = perPage;
    liveHasMore.value = false;
  }

  List<dynamic> _extractLiveList(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['data'] is List) {
        return List<dynamic>.from(body['data']);
      }

      // Laravel paginate sometimes: {data:[...], current_page:...}
      if (body['livestreams'] is List) {
        return List<dynamic>.from(body['livestreams']);
      }

      print("⚠️ Live response data list not found");
      return <dynamic>[];
    }

    if (body is List) {
      return List<dynamic>.from(body);
    }

    print("⚠️ Response body is not Map or List");
    return <dynamic>[];
  }

  void _applyLivestreamListSafely(
      List<dynamic> serverList, {
        bool append = false,
      }) {
    final List<dynamic> merged = _mergeLiveListsUnique(
      oldList: showingLiveStreamList,
      newList: serverList,
      append: append,
    );

    // If host left/minimized room and backend temporarily omits own live because
    // heartbeat/list query lags, keep the local host card until a new live replaces it.
    if (!append) {
      final localHost = showingLiveStreamList.firstWhereOrNull(_isOwnActiveLive);
      if (localHost != null) {
        final localId = _liveIdOf(localHost);
        final exists = merged.any((item) => _liveIdOf(item) == localId);
        if (!exists) {
          merged.insert(0, localHost);
          print('✅ Local host live card preserved in list => $localId');
        }
      }
    }

    showingLiveStreamList.assignAll(merged);
  }

  Future<void> getLivestreamList({
    int page = 1,
    int perPage = 10,
    bool refresh = true,
  }) async {
    if (refresh) {
      isLoading.value = true;
      liveHasMore.value = true;
    } else {
      if (!canLoadMoreLive) return;
      isLoadingMoreLive.value = true;
    }

    try {
      final response = await _dio.get(
        getLiveStreamList,
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200) {
        final dynamic body = response.data;
        final List<dynamic> liveList = _extractLiveList(body);

        _updateLivePagination(body, page, perPage);

        _applyLivestreamListSafely(
          liveList,
          append: !refresh && page > 1,
        );

        _sortLiveStreamList();

      } else {
        print("❌ Live list status code: ${response.statusCode}");
      }
    } on DioException catch (e, stackTrace) {
      if (e.response != null) {
        print("========== ERROR RESPONSE INFO ==========");
        print("Response Status Code: ${e.response?.statusCode}");
        print("Response Status Message: ${e.response?.statusMessage}");
        print("Response Headers: ${e.response?.headers}");
        print("Response Data: ${e.response?.data}");
      } else {
        print("No response received from server.");
      }

      print("========== STACKTRACE ==========");
      print(stackTrace);
    } catch (e, stackTrace) {
      print("========== UNKNOWN ERROR GET LIVESTREAM LIST ==========");
      print("Error: $e");
      print("Error Runtime Type: ${e.runtimeType}");
      print("StackTrace: $stackTrace");
    } finally {
      isLoading.value = false;
      isLoadingMoreLive.value = false;
      print("========== GET LIVESTREAM LIST END ==========");
    }
  }

  Future<void> refreshLivestreamList() async {
    await getLivestreamList(page: 1, perPage: livePerPage.value, refresh: true);
  }

  Future<void> loadMoreLivestreamList() async {
    if (!canLoadMoreLive) return;
    await getLivestreamList(
      page: liveCurrentPage.value + 1,
      perPage: livePerPage.value,
      refresh: false,
    );
  }

  void _sortLiveStreamList() {
    if (showingLiveStreamList.isEmpty) return;

    final List<dynamic> originalList = List.from(showingLiveStreamList);
    int adminOrderOf(dynamic raw) {
      if (raw is! Map) return 999999;

      final item = Map<String, dynamic>.from(raw);
      final value = item['display_order'] ??
          item['sort_order'] ??
          item['show_no'] ??
          item['sl_no'];

      final int order = int.tryParse('$value') ?? 0;
      return order > 0 ? order : 999999;
    }

    // PK room item থেকে sender/receiver normal live card-এর মধ্যে PK meta merge করবো.
    // All live list-এ PK room আলাদা card হবে না; Host A and Host B দুইজনই card থাকবে.
    final Map<String, Map<String, dynamic>> pkMetaByLiveId = {};

    for (final raw in originalList) {
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);

      final bool isPkRoom =
          item['is_pk_room'] == true ||
              item['stream_type']?.toString().toLowerCase() == 'pk';

      if (!isPkRoom) continue;

      final String senderId = '${item['sender_livestream_id'] ?? ''}';
      final String receiverId = '${item['receiver_livestream_id'] ?? ''}';

      final Map<String, dynamic> meta = {
        'is_pk': 1,
        'is_pk_room': false,
        'pk_id': item['pk_id'],
        'pk_status': item['pk_status'],
        'pk_channel': item['pk_channel'] ?? item['pk_channel_name'],
        'pk_channel_name': item['pk_channel_name'] ?? item['pk_channel'],
        'pk_start_time': item['pk_start_time'],
        'duration_seconds': item['duration_seconds'],
        'remaining_seconds': item['remaining_seconds'],
        'remaining_time': item['remaining_time'],

        'sender_livestream_id': item['sender_livestream_id'],
        'receiver_livestream_id': item['receiver_livestream_id'],
        'pk_sender_livestream_id': item['sender_livestream_id'],
        'pk_receiver_livestream_id': item['receiver_livestream_id'],

        'sender_host_id': item['sender_host_id'],
        'receiver_host_id': item['receiver_host_id'],
        'sender_host': item['sender_host'],
        'receiver_host': item['receiver_host'],
        'sender_livestream': item['sender_livestream'],
        'receiver_livestream': item['receiver_livestream'],

        'sender_score': item['sender_score'] ?? 0,
        'receiver_score': item['receiver_score'] ?? 0,
        'total_score': item['total_score'] ?? 0,
        'sender_score_percent': item['sender_score_percent'] ?? 50,
        'receiver_score_percent': item['receiver_score_percent'] ?? 50,

        'pk_room_data': item,
      };

      if (senderId.isNotEmpty && senderId != 'null' && senderId != '0') {
        pkMetaByLiveId[senderId] = meta;
      }

      if (receiverId.isNotEmpty && receiverId != 'null' && receiverId != '0') {
        pkMetaByLiveId[receiverId] = meta;
      }
    }

    final Set<String> seenLiveIds = {};
    final List<dynamic> sortedList = [];

    for (final raw in originalList) {
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);

      final bool isPkRoom =
          item['is_pk_room'] == true ||
              item['stream_type']?.toString().toLowerCase() == 'pk';

      // All list এ separate PK room card hide থাকবে.
      // Host A/Host B normal live card থাকবে, কিন্তু তাদের মধ্যে PK meta থাকবে.
      if (isPkRoom) continue;

      final String liveId =
          '${item['id'] ?? item['livestream_id'] ?? item['stream_id'] ?? ''}';

      if (liveId.isEmpty || liveId == '0' || liveId == 'null') continue;
      if (seenLiveIds.contains(liveId)) continue;

      seenLiveIds.add(liveId);

      final pkMeta = pkMetaByLiveId[liveId];

      if (pkMeta != null) {
        sortedList.add({
          ...item,
          ...pkMeta,
          'original_stream_type': item['stream_type'],
          'stream_type': item['stream_type'],
          'pk_status': pkMeta['pk_status'] ?? 'running',
        });
      } else {
        sortedList.add({...item, 'is_pk': 0});
      }
    }

    // Cache resolved country into each live map for UI/debug.
    for (int i = 0; i < sortedList.length; i++) {
      final raw = sortedList[i];
      if (raw is Map) {
        final item = Map<String, dynamic>.from(raw);
        final resolvedCountry = _countryOfLive(item);
        if (resolvedCountry.isNotEmpty) {
          item['resolved_country'] = resolvedCountry;
        }
        sortedList[i] = item;
      }
    }

    _refreshAvailableLiveCountries(sortedList);

    sortedList.sort((a, b) {
      /*
      |----------------------------------------------------------------------
      | PERFECT ADMIN ORDER FIRST
      |----------------------------------------------------------------------
      | Admin panel e jeta Show No 1,2,3... diben, app e sheta first/second/third
      | hobe. Ekhane country/official/PK/gift sorting admin order override korte
      | parbe na.
      |
      | Duita live-er admin order na thakle/null hole old sorting niche same thakbe.
      |----------------------------------------------------------------------
      */
      final int adminOrderA = adminOrderOf(a);
      final int adminOrderB = adminOrderOf(b);

      if (adminOrderA != adminOrderB) {
        return adminOrderA.compareTo(adminOrderB);
      }

      final bool aCountryMatch = _isSelectedCountryLive(a);
      final bool bCountryMatch = _isSelectedCountryLive(b);

      // Selected country live cards show first.
      if (aCountryMatch && !bCountryMatch) return -1;
      if (!aCountryMatch && bCountryMatch) return 1;

      bool aIsOfficial = (a['stream_bte'] ?? '')
          .toString()
          .toLowerCase()
          .contains('official room');
      bool bIsOfficial = (b['stream_bte'] ?? '')
          .toString()
          .toLowerCase()
          .contains('official room');

      if (aIsOfficial && !bIsOfficial) return -1;
      if (!aIsOfficial && bIsOfficial) return 1;

      String streamTypeA = a['stream_type']?.toString().toLowerCase() ?? '';
      String streamTypeB = b['stream_type']?.toString().toLowerCase() ?? '';

      final bool aIsPk =
          (a['pk_id'] != null && '${a['pk_id']}' != '0') ||
              a['pk_status']?.toString().toLowerCase() == 'running';
      final bool bIsPk =
          (b['pk_id'] != null && '${b['pk_id']}' != '0') ||
              b['pk_status']?.toString().toLowerCase() == 'running';

      int priorityA = aIsPk ? 0 : _getStreamTypePriority(streamTypeA);
      int priorityB = bIsPk ? 0 : _getStreamTypePriority(streamTypeB);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      int giftsCoinsA = _parseGiftsCoins(a['gifts_coins'] ?? a['total_score']);
      int giftsCoinsB = _parseGiftsCoins(b['gifts_coins'] ?? b['total_score']);

      return giftsCoinsB.compareTo(giftsCoinsA);
    });

    final int matchCount = sortedList.where(_isSelectedCountryLive).length;
    selectedLiveCountryMatchCount.value = matchCount;

    showingLiveStreamList.assignAll(sortedList);


    if (sortedList.isNotEmpty) {
      final preview = sortedList.take(8).map((item) {
        if (item is! Map) return 'unknown';
        final name = item['stream_bte'] ?? item['user']?['name'] ?? 'Live';
        final country = item['resolved_country'] ?? _countryOfLive(item);
        final order = item['display_order'] ??
            item['sort_order'] ??
            item['show_no'] ??
            item['sl_no'] ??
            'null';
        return '$name => show_no=$order => $country';
      }).join(' | ');
    }
  }

  // Get priority for stream types (lower number = higher priority)
  int _getStreamTypePriority(String streamType) {
    switch (streamType) {
      case 'pk':
        return 0; // PK Battle সবার আগে
      case 'popular':
        return 1;
      case 'audio':
        return 3;
      default:
        return 2;
    }
  }
  // Parse gifts_coins value safely

  int _parseGiftsCoins(dynamic giftsCoins) {
    if (giftsCoins == null) return 0;

    if (giftsCoins is int) return giftsCoins;
    if (giftsCoins is double) return giftsCoins.toInt();
    if (giftsCoins is String) {
      return int.tryParse(giftsCoins) ?? 0;
    }

    return 0;
  }

  // Method to add new stream and auto sort
  void addLiveStream(dynamic streamData) {
    showingLiveStreamList.add(streamData);
    _sortLiveStreamList();
  }

  // Method to remove stream and auto sort
  void removeLiveStream(dynamic streamData) {
    showingLiveStreamList.remove(streamData);
    _sortLiveStreamList();
  }

  // Method to update stream data and auto sort
  void updateLiveStream(int index, dynamic streamData) {
    if (index >= 0 && index < showingLiveStreamList.length) {
      showingLiveStreamList[index] = streamData;
      _sortLiveStreamList();
    }
  }

  // Method to manually trigger sorting
  void sortLiveStreamList() {
    _sortLiveStreamList();
  }

  //alamin code popular here

  final popularList = [].obs;

  Future getPopularList() async {
    isLoading.value = true;
    final data = await _dio.get(kPopularUrl);
    popularList.value = data.data;
    isLoading.value = false;
  }

  // live stream post create

  final streamController = ''.obs;
  final discriptionController = TextEditingController();
  final rtcTokenController = ''.obs;
  final streamCoinController = ''.obs;
  final streamTypeController = ''.obs;
  final giftsCoinController = ''.obs;
  final streamPurposeController = ''.obs;
  final streamImageController = ''.obs;

  //notification ----------------

  ///----------------------- comment data show  ---------------------
  final agencyList = [].obs;

  Future showingAgencyList() async {
    print(kAgencyListUrl);
    isLoading.value = true;
    try {
      final response = await _dio.get(
        kAgencyListUrl,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        agencyList.value = response.data['data'];
        isLoading.value = false;
      } else {
        isLoading.value = false;
        print('❌ Unexpected status code: ${response.statusCode}');
        Get.snackbar(
          ('Failed').appTr,
          ("Server returned status: ${response.statusCode}").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on DioException catch (e) {
      isLoading.value = false;
      if (e.response != null) {
        Fluttertoast.showToast(
          msg: ("Error ${e.response!.statusCode}: ${e.response!.statusMessage}").appTr,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        print('   - No response received (network/connection issue)');
        Fluttertoast.showToast(
          msg: ("Network error: ${e.message}").appTr,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      isLoading.value = false;
      print('❌ Unexpected error: $e');
      Fluttertoast.showToast(
        msg: ("Unexpected error: $e").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  final profileBaseList = <dynamic>[].obs;

  bool _baseListRequestRunning = false;

  Future<void> baseList() async {
    if (_baseListRequestRunning) {
      debugPrint('ℹ️ Base list request already running');
      return;
    }

    _baseListRequestRunning = true;

    try {
      final String? token = await _waitForBaseListAuthToken();

      if (token == null) {
        debugPrint(
          '⚠️ Base list cancelled: saved auth profile/token was not restored',
        );
        return;
      }

      debugPrint('========== GET BASE LIST ==========');
      debugPrint('URL: $kBaseList');
      debugPrint('Token available: yes');

      final Response<dynamic> response = await _dio.get<dynamic>(
        kBaseList,
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (int? status) =>
          status != null && status < 500,
        ),
      );

      final int statusCode = response.statusCode ?? 0;

      debugPrint('Base list HTTP status: $statusCode');
      debugPrint(
        'Base list response type: ${response.data.runtimeType}',
      );

      if (statusCode == 401 ||
          statusCode == 403 ||
          statusCode == 419) {
        profileBaseList.clear();
        debugPrint(
          '🔐 Base list unauthorized: token invalid or expired',
        );
        return;
      }

      if (statusCode < 200 || statusCode >= 300) {
        profileBaseList.clear();
        debugPrint('❌ Base list HTTP error: $statusCode');
        debugPrint(
          'Response: ${_baseListResponsePreview(response.data)}',
        );
        return;
      }

      dynamic body = _decodeBaseListValue(response.data);

      if (body == null) {
        profileBaseList.clear();
        debugPrint('⚠️ Base list response is empty');
        return;
      }

      dynamic data = body;

      if (body is Map) {
        if (body.containsKey('data')) {
          data = body['data'];
        } else if (body.containsKey('result')) {
          data = body['result'];
        } else if (body.containsKey('items')) {
          data = body['items'];
        } else if (body.containsKey('base_list')) {
          data = body['base_list'];
        }
      }

      data = _decodeBaseListValue(data);

      // Laravel pagination বা nested API response:
      // {"data":{"data":[...]}}
      if (data is Map && data.containsKey('data')) {
        data = _decodeBaseListValue(data['data']);
      }

      if (data is List) {
        profileBaseList.assignAll(data);
        debugPrint(
          '✅ Base list loaded: ${profileBaseList.length} items',
        );
        return;
      }

      // Backend single object পাঠালে এটিকেও list হিসেবে রাখবে।
      if (data is Map) {
        profileBaseList.assignAll(<dynamic>[
          Map<String, dynamic>.from(data),
        ]);
        debugPrint('✅ Base list loaded: single item');
        return;
      }

      profileBaseList.clear();
      debugPrint(
        '❌ Base list invalid final type: ${data.runtimeType}',
      );
      debugPrint(
        'Response: ${_baseListResponsePreview(data)}',
      );
    } on DioException catch (error, stackTrace) {
      profileBaseList.clear();
      debugPrint('❌ Base list Dio error: ${error.message}');
      debugPrint('Status: ${error.response?.statusCode}');
      debugPrint(
        'Response: ${_baseListResponsePreview(error.response?.data)}',
      );
      debugPrint('$stackTrace');
    } catch (error, stackTrace) {
      profileBaseList.clear();
      debugPrint('❌ Base list unexpected error: $error');
      debugPrint('$stackTrace');
    } finally {
      _baseListRequestRunning = false;
      debugPrint('========== GET BASE LIST END ==========');
    }
  }

  /// HomeController app startup-এ AuthController-এর profile restore হওয়ার
  /// আগেই তৈরি হয়। তাই saved token পাওয়া পর্যন্ত অল্প সময় অপেক্ষা করা হয়।
  Future<String?> _waitForBaseListAuthToken() async {
    for (int attempt = 1; attempt <= 60; attempt++) {
      final String token =
          authController.userProfile.value.token?.toString().trim() ?? '';

      final int userId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;

      final String normalizedToken = token.toLowerCase();

      final bool validToken =
          token.isNotEmpty &&
              normalizedToken != 'null' &&
              normalizedToken != 'undefined' &&
              normalizedToken != '0';

      if (validToken && userId > 0) {
        debugPrint(
          '✅ Auth token restored for base list (attempt $attempt)',
        );
        return token;
      }

      if (attempt == 1) {
        debugPrint(
          '⏳ Base list waiting for saved auth profile...',
        );
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );
    }

    return null;
  }

  /// Map/List সরাসরি return করবে।
  /// JSON String বা double-encoded JSON String হলে decode করবে।
  dynamic _decodeBaseListValue(dynamic value) {
    dynamic currentValue = value;

    for (int attempt = 0; attempt < 2; attempt++) {
      if (currentValue is! String) {
        return currentValue;
      }

      final String text = currentValue.trim();

      if (text.isEmpty) {
        return null;
      }

      try {
        currentValue = jsonDecode(text);
      } on FormatException {
        debugPrint('❌ Base list response is not valid JSON');
        debugPrint(
          'Raw response: ${_baseListResponsePreview(text)}',
        );
        return null;
      }
    }

    return currentValue;
  }

  /// বড় HTML/error response পুরোটা print না করে প্রথম অংশ দেখাবে।
  String _baseListResponsePreview(dynamic value) {
    final String text = value?.toString() ?? 'null';

    if (text.length <= 500) {
      return text;
    }

    return '${text.substring(0, 500)}...';
  }

  final isGuardianData = {}.obs;

  ///--------------------------------- Agency List Data ---------------------
  final agencyListData = {}.obs;
  ///-------------------------------- profile visite api-------------

  final profileVisitor = {}.obs;

  void visitProfile({required String userId}) async {
    final data = {'user_id': userId};
    try {
      print(kProfileVisitor);
      print(data);
      final response = await dio.post(
        kProfileVisitor,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        profileVisitor.value = response.data;

        Get.to(
          userProfileVisit(),
          arguments: response.data,
          transition: Transition.rightToLeft,
        );
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print(e);
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  final liveProfileVisitor = {}.obs;

  // ✅ Live bottom sheet CP/Family cache
  // Profile visitor response-e data thakle ekhane save hobe,
  // family na thakle userFamily API diye load kore bottom sheet update hobe.
  final RxMap<int, Map<String, dynamic>> liveProfileCpCache =
      <int, Map<String, dynamic>>{}.obs;
  final RxMap<int, Map<String, dynamic>> liveProfileFamilyCache =
      <int, Map<String, dynamic>>{}.obs;
  final RxSet<int> liveProfileCpLoadingIds = <int>{}.obs;
  final RxSet<int> liveProfileFamilyLoadingIds = <int>{}.obs;


  /// ===================== LIVE PROFILE FOLLOW + MENTION =====================
  /// Bottom live profile sheet should update instantly, not after re-opening.
  final RxSet<int> liveFollowLoadingIds = <int>{}.obs;

  bool isLiveFollowing(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'yes' ||
        text == 'y' ||
        text == '1' ||
        text == 'true' ||
        text == 'follow' ||
        text == 'followed' ||
        text == 'following';
  }

  int _safeLiveInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? fallback;
  }

  void _applyLiveProfileFollowState({
    required int targetUserId,
    required bool following,
    int followerDelta = 0,
  }) {
    if (targetUserId <= 0) return;

    try {
      final root = Map<String, dynamic>.from(liveProfileVisitor.value);
      final user = Map<String, dynamic>.from(root['User Data'] ?? {});
      final currentId = _safeLiveInt(user['id'] ?? user['user_id']);

      if (currentId == targetUserId) {
        final oldFollowers = _safeLiveInt(user['total_followers']);
        user['follow_status'] = following ? 'yes' : 'no';
        user['is_following'] = following ? 1 : 0;
        user['total_followers'] = (oldFollowers + followerDelta).clamp(0, 999999999);
        root['User Data'] = user;
        liveProfileVisitor.value = root;
        liveProfileVisitor.refresh();
      }
    } catch (e) {
      debugPrint('⚠️ live profile follow state patch skipped => $e');
    }
  }

  Future<void> toggleLiveProfileFollow(Map<String, dynamic> user) async {
    final int targetUserId = _safeLiveInt(user['id'] ?? user['user_id']);
    if (targetUserId <= 0 || liveFollowLoadingIds.contains(targetUserId)) return;

    final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (myId > 0 && myId == targetUserId) return;

    final bool wasFollowing = isLiveFollowing(user['follow_status'] ?? user['is_following']);
    final bool nextFollowing = !wasFollowing;
    final int delta = nextFollowing ? 1 : -1;

    liveFollowLoadingIds.add(targetUserId);
    liveFollowLoadingIds.refresh();

    // Optimistic realtime UI update.
    user['follow_status'] = nextFollowing ? 'yes' : 'no';
    user['is_following'] = nextFollowing ? 1 : 0;
    user['total_followers'] = (_safeLiveInt(user['total_followers']) + delta).clamp(0, 999999999);
    _applyLiveProfileFollowState(
      targetUserId: targetUserId,
      following: nextFollowing,
      followerDelta: delta,
    );

    try {
      if (nextFollowing) {
        momentsController.followCreate(userId: '$targetUserId');
      } else {
        momentsController.unFollowCreate(id: targetUserId);
      }
    } catch (e) {
      // Rollback if API fails.
      user['follow_status'] = wasFollowing ? 'yes' : 'no';
      user['is_following'] = wasFollowing ? 1 : 0;
      user['total_followers'] = (_safeLiveInt(user['total_followers']) - delta).clamp(0, 999999999);
      _applyLiveProfileFollowState(
        targetUserId: targetUserId,
        following: wasFollowing,
        followerDelta: -delta,
      );
      Fluttertoast.showToast(
        msg: ('Follow update failed. Please try again.').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      liveFollowLoadingIds.remove(targetUserId);
      liveFollowLoadingIds.refresh();
    }
  }

  void mentionLiveProfileUserFromSheet(Map<String, dynamic> user) {
    final int targetUserId = _safeLiveInt(user['id'] ?? user['user_id']);
    if (targetUserId <= 0) return;

    // Profile @ tap should be one-tap direct insert.
    // No second option sheet / no mention picker. Close profile sheet first,
    // then write @Name into the live comment TextField behind it.
    if (Get.isBottomSheetOpen == true) {
      Get.back();
    }

    Future.delayed(const Duration(milliseconds: 120), () {
      final bool inserted = WriteCommentSection.insertMentionToActiveInput(user);

      if (!inserted) {
        Fluttertoast.showToast(
          msg: ('Open the live comment box first, then tap mention again.').appTr,
          backgroundColor: Colors.black87,
          textColor: Colors.white,
        );
      }
    });
  }

  // Method to check if current user is the broadcaster
  bool get isBroadcaster {
    if (liveProfileVisitor.isEmpty ||
        authController.userProfile.value.user == null) {
      return false;
    }

    // Check if liveProfileVisitor and user data exist (API returns 'User Data' key)
    if (liveProfileVisitor['User Data'] == null ||
        liveProfileVisitor['User Data']['id'] == null) {
      return false;
    }

    final currentUserId = authController.userProfile.value.user!.id.toString();
    final profileUserId = liveProfileVisitor['User Data']['id'].toString();

    return currentUserId == profileUserId;
  }

  bool _guardianValueTrue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  int _profileTargetId(dynamic value) {
    if (value is Map && value['User Data'] is Map) {
      final user = Map<String, dynamic>.from(value['User Data']);
      return int.tryParse('${user['id'] ?? user['user_id'] ?? 0}') ?? 0;
    }
    if (value is Map && value['user'] is Map) {
      final user = Map<String, dynamic>.from(value['user']);
      return int.tryParse('${user['id'] ?? user['user_id'] ?? 0}') ?? 0;
    }
    if (value is Map) {
      return int.tryParse('${value['id'] ?? value['user_id'] ?? 0}') ?? 0;
    }
    return 0;
  }

  bool isTargetRoomAdminNow(int targetUserId, {dynamic userDataPopup}) {
    if (targetUserId <= 0) return false;

    // 1) Strongest source: global guardian map.
    // It also stores false after remove, so removed admin badge will not return after seat switch.
    try {
      if (livestreamController.roomGuardianMap.containsKey(targetUserId)) {
        return livestreamController.roomGuardianMap[targetUserId] == true;
      }
    } catch (_) {}

    // 2) Current live call/seat list.
    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;

        final Map<String, dynamic> user = raw['user'] is Map
            ? Map<String, dynamic>.from(raw['user'])
            : <String, dynamic>{};

        final int uid = int.tryParse(
          '${raw['caller_id'] ?? raw['user_id'] ?? user['id'] ?? user['user_id'] ?? 0}',
        ) ??
            0;

        if (uid == targetUserId) {
          return _guardianValueTrue(
            raw['is_guardian'] ??
                raw['guardian'] ??
                user['is_guardian'] ??
                user['guardian'],
          );
        }
      }
    } catch (_) {}

    // 3) Guardian list API cache.
    try {
      for (final raw in livestreamController.guardianListData) {
        if (raw is! Map) continue;

        final Map<String, dynamic> user = raw['user'] is Map
            ? Map<String, dynamic>.from(raw['user'])
            : <String, dynamic>{};

        final int uid = int.tryParse(
          '${raw['user_id'] ?? raw['caller_id'] ?? user['id'] ?? user['user_id'] ?? 0}',
        ) ??
            0;

        if (uid == targetUserId) return true;
      }
    } catch (_) {}

    // 4) Profile response / bottom-sheet data.
    final Map<String, dynamic> root = userDataPopup is Map
        ? Map<String, dynamic>.from(userDataPopup)
        : Map<String, dynamic>.from(liveProfileVisitor.value);

    final Map<String, dynamic> user = root['User Data'] is Map
        ? Map<String, dynamic>.from(root['User Data'])
        : root['user'] is Map
        ? Map<String, dynamic>.from(root['user'])
        : <String, dynamic>{};

    final int profileId = _profileTargetId(root);

    if (profileId == targetUserId) {
      return _guardianValueTrue(
        root['is_guardian'] ??
            root['guardian'] ??
            user['is_guardian'] ??
            user['guardian'],
      );
    }

    return false;
  }
  void syncTargetGuardianSnapshot({
    required int targetUserId,
    dynamic userDataPopup,
  }) {
    final bool targetIsGuardian = isTargetRoomAdminNow(
      targetUserId,
      userDataPopup: userDataPopup,
    );

    isGuardianData.value = {
      ...Map<String, dynamic>.from(isGuardianData),
      'target_user_id': targetUserId,
      'is_guardian': targetIsGuardian,
      'value': targetIsGuardian ? 1 : 0,
    };

    try {
      livestreamController.roomGuardianMap[targetUserId] = targetIsGuardian;
      livestreamController.roomGuardianMap.refresh();
    } catch (_) {}
  }


  // Method to show manage popup for broadcasters
  void showManagePopup({required userDataPopup}) {
    if (liveProfileVisitor.isEmpty) return;

    final userData = userDataPopup['User Data'] ?? {};
    final userName = userData['name'] ?? ('Unknown User').appTr;
    final userAvatar = userData['profile_image'] ?? userData['avatar'] ?? userData['image'] ?? '';
    final userId = userData['id'].toString();
    final int targetUserIdInt = int.tryParse(userId) ?? 0;

    // ✅ Manage popup open করার আগে target user Room Admin কিনা sync করি।
    // আগে current user guardian status use হচ্ছিল, তাই Remove Admin option ঠিকমতো আসত না।
    syncTargetGuardianSnapshot(
      targetUserId: targetUserIdInt,
      userDataPopup: userDataPopup,
    );

    Get.bottomSheet(
      ManagePopup(
        userAllData: userDataPopup,
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
        livestreamId: livestreamController.streamId.value,
        hostId: targetUserIdInt,
        isHostProfile: true,
        onSendGifts: () {
          Get.back();
        },
        onViewProfile: () {
          Get.back();
          Get.to(
            ProfileView(),
            arguments: liveProfileVisitor.value,
            transition: Transition.rightToLeft,
          );
        },
        onLeaveMic: () async {
          Get.back();

          try {
            // Get current user ID and stream ID
            final userId = liveProfileVisitor.value['User Data']['id'];
            final streamId = livestreamController.streamId.value;

            if (userId == null || streamId == 0) {
              Get.snackbar(('Error').appTr, ('Invalid user or stream data').appTr);
              return;
            }

            // Show confirmation dialog
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: Text(('Leave Mic').appTr),
                content: Text(('Are you sure you want to leave the mic?').appTr),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(('Cancel').appTr),
                  ),
                  TextButton(
                    onPressed: () {
                      livestreamController.tryToRejectCall(
                        streamId: streamId,
                        userId: userId,
                      );
                      Get.back(result: true);
                    },
                    child: Text(('Leave').appTr, style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );

            if (confirmed == true) {}
          } catch (e) {
            print('Error leaving mic: $e');
            Get.snackbar(
              ('Error').appTr,
              ('An error occurred while leaving mic').appTr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        onMuteMic: () async {
          Get.back();
          final targetUserId = liveProfileVisitor.value['User Data']['id'];

          try {
            livestreamController.toggleSpecificUserAudio(targetUserId);
          } catch (e) {
            Get.snackbar(
              ('Error').appTr,
              ('An error occurred: $e').appTr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        onCameraOnOff: () async {
          Get.back();
          final targetUserId = liveProfileVisitor.value['User Data']['id'];

          try {
            livestreamController.toggleSpecificUserVideo(targetUserId);
          } catch (e) {
            Get.snackbar(
              ('Error').appTr,
              ('An error occurred: $e').appTr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        onKickOut: () async {
          Get.back();
          final int targetUserId = int.tryParse(
            '${liveProfileVisitor.value['User Data']?['id'] ?? 0}',
          ) ?? 0;

          final int myUserId = authController.userProfile.value.user?.id?.toInt() ?? 0;
          final bool currentUserIsHost =
              livestreamController.isCurrentUserCurrentLiveOwner ||
                  livestreamController.isBroadcaster.value == true;
          final bool currentUserIsRoomAdmin = !currentUserIsHost &&
              (livestreamController.isMyGuardian.value == true ||
                  livestreamController.roomGuardianMap[myUserId] == true);

          syncTargetGuardianSnapshot(
            targetUserId: targetUserId,
            userDataPopup: liveProfileVisitor.value,
          );

          if (currentUserIsRoomAdmin && isTargetRoomAdminNow(
            targetUserId,
            userDataPopup: liveProfileVisitor.value,
          )) {
            Get.snackbar(
              ('Permission denied').appTr,
              'Room Admin cannot kick another Room Admin.',
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
            return;
          }

          // Show confirmation dialog
          final confirmed = await Get.dialog<bool>(
            AlertDialog(
              title: Text(('Kick Out User').appTr),
              content: Text(
                ('Are you sure you want to kick out this user? They will be unable to rejoin for 15 minutes.').appTr,
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text(('Cancel').appTr),
                ),
                TextButton(
                  onPressed: () => Get.back(result: true),
                  child: Text(('Kick Out').appTr, style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              final success = await livestreamController.kickOutUser(
                targetUserId,
              );

              if (success) {
                Get.snackbar(
                  ('Success').appTr,
                  ('User has been kicked out successfully').appTr,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  ('Error').appTr,
                  ('Failed to kick out user').appTr,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            } catch (e) {
              Get.snackbar(
                ('Error').appTr,
                ('An error occurred: $e').appTr,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            }
          }
        },
        onSetAdministrator: () async {
          try {
            // ✅ Only host/broadcaster can make/remove guardian.
            // Guardian cannot make another admin.
            if (livestreamController.isBroadcaster.value != true) {
              Get.snackbar(
                ('Permission denied').appTr,
                ('Only host can set or remove admin.').appTr,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
              return;
            }

            final int targetUserId = int.tryParse(
              '${liveProfileVisitor.value['User Data']?['id'] ?? 0}',
            ) ?? 0;
            final int streamId = livestreamController.streamId.value;

            if (targetUserId <= 0 || streamId == 0) {
              Get.snackbar(('Error').appTr, ('Invalid user or stream data').appTr);
              return;
            }

            // ✅ Target user-er current Room Admin status check.
            // Current user guardian status use korle Remove Admin option wrong hoy.
            syncTargetGuardianSnapshot(
              targetUserId: targetUserId,
              userDataPopup: liveProfileVisitor.value,
            );

            final bool alreadyGuardian = isTargetRoomAdminNow(
              targetUserId,
              userDataPopup: liveProfileVisitor.value,
            );

            if (Get.isBottomSheetOpen == true) {
              Get.back();
            }

            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: Text(alreadyGuardian ? ('Remove Room Admin').appTr: ('Set Room Admin').appTr),
                content: Text(
                  alreadyGuardian
                      ? ('Are you sure you want to remove this user from Room Admin? The badge will disappear for everyone.').appTr: ('Are you sure you want to make this user Room Admin? They will have moderation privileges in this room.').appTr,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child:  Text(('Cancel').appTr),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(
                      alreadyGuardian ? ('Remove Admin').appTr: ('Set Room Admin').appTr,
                      style: TextStyle(color: alreadyGuardian ? Colors.red : Colors.blue),
                    ),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;

            final bool ok = alreadyGuardian
                ? await livestreamController.removeGuardianUser(
              streamId: streamId,
              userId: targetUserId,
              closeBottomSheet: false,
            )
                : await livestreamController.assignGuardian(
              streamId: streamId,
              userId: targetUserId,
              closeBottomSheet: false,
            );

            if (ok) {
              // ✅ Local UI + next Manage popup title instant update.
              syncTargetGuardianSnapshot(
                targetUserId: targetUserId,
                userDataPopup: liveProfileVisitor.value,
              );

              final String targetName = liveProfileVisitor.value['User Data']?['name']?.toString() ?? ('User').appTr;
              livestreamController.showGuardianNotice(
                targetName,
                assigned: !alreadyGuardian,
              );
            }
          } catch (e) {
            print('Error setting administrator: $e');
            Get.snackbar(
              ('Error').appTr,
              ('An error occurred while setting administrator').appTr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        onAddToRoomBlacklist: () async {
          Get.back();

          try {
            // Get current user ID and stream ID
            final userId = liveProfileVisitor.value['User Data']['user_id'];
            final streamId = livestreamController.streamId.value;

            if (userId == null || streamId == 0) {
              Get.snackbar(('Error').appTr, ('Invalid user or stream data').appTr);
              return;
            }

            // Show confirmation dialog
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: Text(('Add to Room Blacklist').appTr),
                content: Text(
                  ('Are you sure you want to add this user to the room blacklist? They will be banned from this room.').appTr,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(('Cancel').appTr),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(
                      ('Add to Blacklist').appTr,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              final result = await livestreamController.addToRoomBlacklist(
                streamId,
                userId,
                reason: 'room_blacklist',
              );

              if (result != null && result['success'] == true) {
                Get.snackbar(
                  ('Success').appTr,
                  ('User added to room blacklist successfully').appTr,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  ('Error').appTr,
                  result?['message'] ?? ('Failed to add user to room blacklist').appTr,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            }
          } catch (e) {
            print('Error adding to room blacklist: $e');
            Get.snackbar(
              ('Error').appTr,
              ('An error occurred while adding to room blacklist').appTr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        onAddToPersonalBlacklist: () async {
          Get.back();

          try {
            // Get current user ID
            final userId = liveProfileVisitor.value['User Data']['user_id'];

            if (userId == null) {
              Get.snackbar(('Error').appTr, ('Invalid user data').appTr);
              return;
            }

            // Show confirmation dialog
            final confirmed = await Get.dialog<bool>(
              AlertDialog(
                title: Text(('Add to Personal Blacklist').appTr),
                content: Text(
                  ('Are you sure you want to block this user? You will not see their messages or interactions.').appTr,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: Text(('Cancel').appTr),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: Text(
                      ('Block User').appTr,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              final response = await _dio.post(
                '$kMainUrl/user_block',
                data: {'user_id': userId},
                options: Options(
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization':
                    'Bearer ${authController.userProfile.value.token}',
                  },
                ),
              );

              if (response.statusCode == 200 &&
                  response.data['status'] == true) {
                Get.snackbar(
                  ('Success').appTr,
                  ('User blocked successfully').appTr,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  ('Error').appTr,
                  response.data['message'] ?? ('Failed to block user').appTr,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            }
          } catch (e) {
            print('Error blocking user: $e');
            Get.snackbar(
              ('Error').appTr,
              ('An error occurred while blocking user').appTr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        },
        guardianList: () async {
          final streamId = livestreamController.streamId.value;
          livestreamController.GuardianList(StreanId: streamId);
          Get.bottomSheet(
            Container(
              height: Get.height * 0.5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  // 🔹 Drag Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Text(
                    ("Guardian List").appTr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Obx(() {
                    return Expanded(
                      child: livestreamController.guardianListData.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/no_guardians.png',
                              // এখানে তোমার empty image path
                              height: 100,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              ("No Guardians").appTr,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        itemCount:
                        livestreamController.guardianListData.length,
                        itemBuilder: (context, index) {
                          final guardian = livestreamController
                              .guardianListData[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100,
                            ),
                            child: Row(
                              children: [
                                // Profile Image
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: ImageHelper.getImageUrl(
                                      guardian['user']['profile_image'],
                                    ),
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Name & Level
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guardian['user']['name'] ??
                                          ('Unknown').appTr,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      ("Level: ${guardian['user']['level'] ?? 0}").appTr,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            isScrollControlled: true,
          );
        },
      ),
    );
  }

  //room password
  final rooPassword = TextEditingController();
  final RxBool roomPasswordVerifyLoading = false.obs;

  Future<String?> showRoomPasswordDialog() async {
    rooPassword.clear();

    final String? result = await Get.dialog<String>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff20d6dc),
                        Color(0xff4a50d9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff4a50d9).withOpacity(.24),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ('Room Password').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ('This room is locked. Enter password to join.').appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: rooPassword,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 7,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.black26,
                      letterSpacing: 7,
                    ),
                    filled: true,
                    fillColor: const Color(0xfff2f2f2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xff4a50d9),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Obx(() {
                  final bool loading = roomPasswordVerifyLoading.value;

                  return Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: loading ? null : () => Get.back(result: null),
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xffeeeeee),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              ('Cancel').appTr,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: loading
                              ? null
                              : () {
                            final String password = rooPassword.text.trim();
                            print('🔐 ROOM JOIN PASSWORD TEXTFIELD => $password');

                            if (password.length < 4) {
                              Fluttertoast.showToast(
                                msg: ('Enter room password').appTr,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                              return;
                            }

                            FocusManager.instance.primaryFocus?.unfocus();
                            Get.back(result: password);
                          },
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xff20d6dc),
                                  Color(0xff4a50d9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: loading
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Text(
                              ('Confirm').appTr,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    return result;
  }



  Future<bool> verifyRoomPassword({
    required int userId,
    required int streamId,
    required String password,
  }) async {
    final data = {
      'room_password': password,
    };

    final String url = roomConfirmPassword(userId, streamId);

    print('========== VERIFY ROOM PASSWORD API START ==========');
    print('🔐 VERIFY ROOM PASSWORD URL => $url');
    print('🔐 VERIFY ROOM PASSWORD BODY => $data');
    print('🔐 VERIFY ROOM PASSWORD USER_ID => $userId');
    print('🔐 VERIFY ROOM PASSWORD STREAM_ID => $streamId');

    try {
      roomPasswordVerifyLoading.value = true;

      final response = await dio.post(
        url,
        data: data,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (status) => true,
        ),
      );

      print('🔐 VERIFY ROOM PASSWORD STATUS => ${response.statusCode}');
      print('🔐 VERIFY ROOM PASSWORD RESPONSE => ${response.data}');

      final dynamic body = response.data;
      final Map<String, dynamic> map = body is Map<String, dynamic>
          ? body
          : body is Map
          ? Map<String, dynamic>.from(body)
          : <String, dynamic>{};

      final bool success = (response.statusCode == 200 || response.statusCode == 201) &&
          _asBool(
            map['success'] ??
                map['status'] ??
                map['verified'] ??
                map['can_join'] ??
                map['match'] ??
                map['data']?['success'] ??
                map['data']?['status'] ??
                map['data']?['verified'] ??
                map['data']?['can_join'] ??
                false,
          );

      if (success) {
        Fluttertoast.showToast(
          msg: ('Room unlocked').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 13.0,
        );
        print('✅ VERIFY ROOM PASSWORD SUCCESS');
        print('========== VERIFY ROOM PASSWORD API END ==========');
        return true;
      }

      Fluttertoast.showToast(
        msg: '${map['message'] ?? 'Wrong room password'}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 13.0,
      );
      print('❌ VERIFY ROOM PASSWORD FAILED');
      print('========== VERIFY ROOM PASSWORD API END ==========');
      return false;
    } on DioException catch (e, st) {
      print('❌ VERIFY ROOM PASSWORD DIO ERROR => ${e.message}');
      print('❌ VERIFY ROOM PASSWORD RESPONSE => ${e.response?.data}');
      print(st);
      Fluttertoast.showToast(
        msg: ('Password verify failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    } catch (e, st) {
      print('❌ VERIFY ROOM PASSWORD UNKNOWN ERROR => $e');
      print(st);
      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return false;
    } finally {
      roomPasswordVerifyLoading.value = false;
    }
  }
  void liveVisitProfile({
    required String userId,
    required dynamic seatData,
  }) async {
    try {
      final data = {'user_id': userId};

      print(kProfileVisitor);

      final response = await dio.post(
        kProfileVisitor,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        liveProfileVisitor.value = response.data;

        final Map<String, dynamic> liveProfileRoot =
        response.data is Map ? Map<String, dynamic>.from(response.data) : <String, dynamic>{};
        final Map<String, dynamic> liveProfileUser =
        liveProfileRoot['User Data'] is Map
            ? Map<String, dynamic>.from(liveProfileRoot['User Data'])
            : <String, dynamic>{};
        final int liveProfileUserId = _safeLiveInt(
          liveProfileUser['id'] ?? liveProfileUser['user_id'] ?? userId,
        );
        if (liveProfileUserId > 0) {
          fetchUserCurrentVip(userId: liveProfileUserId, silent: true);

          final Map<String, dynamic> localCp = _extractProfileCpMap(
            user: liveProfileUser,
            root: liveProfileRoot,
          );
          if (localCp.isNotEmpty) {
            liveProfileCpCache[liveProfileUserId] = localCp;
            liveProfileCpCache.refresh();
          }

          fetchLiveProfileCp(userId: liveProfileUserId, force: localCp.isEmpty);

          final Map<String, dynamic> localFamily = _extractProfileFamilyMap(
            user: liveProfileUser,
            root: liveProfileRoot,
          );
          if (localFamily.isNotEmpty) {
            liveProfileFamilyCache[liveProfileUserId] = localFamily;
            liveProfileFamilyCache.refresh();
          }

          fetchLiveProfileFamily(userId: liveProfileUserId, force: localFamily.isEmpty);
        }

        showLiveProfileBottomSheet();
      } else {
        Get.snackbar(
          ('Failed').appTr,
          ("Your credentials doesn't match.").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print(e);
      Get.snackbar(
        ('Failed').appTr,
        ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// ===================== HOME CP ACTIVE COUPLES =====================
  /// Home CP shortcut card uses this dedicated API:
  /// GET /api/cp-active-couples
  ///
  /// Response can be either:
  /// [ {...}, {...} ]
  /// or { "data": [ {...}, {...} ] }
  final RxList<dynamic> cpActiveCouples = <dynamic>[].obs;
  final RxBool cpActiveCouplesLoading = false.obs;

  Map<String, dynamic> _cpSafeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  bool _cpHasRealUser(dynamic value) {
    final Map<String, dynamic> user = _cpSafeMap(value);
    if (user.isEmpty) return false;

    final int id = int.tryParse(
      '${user['id'] ?? user['user_id'] ?? 0}',
    ) ??
        0;
    final String name = (user['name'] ?? '').toString().trim();

    return id > 0 &&
        name.isNotEmpty &&
        name.toLowerCase() != 'n/a' &&
        name.toLowerCase() != 'null';
  }

  Future<void> loadCpActiveCouples({
    bool silent = true,
    bool force = false,
  }) async {
    if (cpActiveCouplesLoading.value) return;
    if (!force && cpActiveCouples.isNotEmpty) return;

    try {
      cpActiveCouplesLoading.value = true;

      final response = await _dio.get(
        '$kMainUrl/cp-active-couples',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization':
            'Bearer ${authController.userProfile.value.token}',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        if (!silent) {
          _toast(
            message: ('CP couples load failed').appTr,
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      final dynamic body = response.data;
      final dynamic rawList =
      body is Map && body['data'] is List ? body['data'] : body;

      final List<dynamic> list =
      rawList is List ? List<dynamic>.from(rawList) : <dynamic>[];

      // Keep only real active couples with both users available.
      // Deleted-user rows such as user_1=null / N/A are intentionally hidden
      // from the compact Home card so the UI always shows a proper couple.
      final List<dynamic> clean = list.where((raw) {
        final Map<String, dynamic> item = _cpSafeMap(raw);
        return _cpHasRealUser(item['user_1']) &&
            _cpHasRealUser(item['user_2']);
      }).toList();

      cpActiveCouples.assignAll(clean);
      cpActiveCouples.refresh();

      debugPrint(
        '✅ CP active couples loaded => ${cpActiveCouples.length} '
            '(raw=${list.length})',
      );
    } on DioException catch (e) {
      debugPrint(
        '❌ CP active couples Dio error => '
            '${e.response?.statusCode} | ${e.response?.data ?? e.message}',
      );

      if (!silent) {
        _toast(
          message: _dioMessage(e, ('CP couples load failed').appTr),
          backgroundColor: Colors.red,
        );
      }
    } catch (e, st) {
      debugPrint('❌ CP active couples error => $e');
      debugPrint('$st');

      if (!silent) {
        _toast(
          message: ('CP couples load failed').appTr,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      cpActiveCouplesLoading.value = false;
    }
  }

  ///----------------------- show banner ---------------------

  var bannerLstData = <dynamic>[].obs;

  String _cleanBannerText(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  Map<String, dynamic> _normalizeBanner(dynamic raw) {
    final Map<String, dynamic> map = raw is Map
        ? Map<String, dynamic>.from(raw.map((key, value) => MapEntry(key.toString(), value)))
        : <String, dynamic>{};

    map['image'] = _cleanBannerText(map['image']);
    map['phone'] = _cleanBannerText(map['phone']);
    map['link'] = _cleanBannerText(map['link']);
    map['title'] = _cleanBannerText(map['title']);

    return map;
  }

  bool _isValidBanner(dynamic raw) {
    final Map<String, dynamic> banner = _normalizeBanner(raw);
    final String image = banner['image']?.toString() ?? '';
    final String status = banner['status']?.toString() ?? '1';

    if (status == '0' || status.toLowerCase() == 'false') return false;
    if (image.isEmpty || image.startsWith('file:///')) return false;
    return true;
  }

  Future<void> showBannerList() async {
    try {
      final response = await _dio.get(kBannerList);

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        final dynamic rawData = responseData is Map ? responseData['data'] : responseData;
        final List allData = rawData is List ? rawData : <dynamic>[];

        final List<Map<String, dynamic>> validBanners = allData
            .where(_isValidBanner)
            .map<Map<String, dynamic>>(_normalizeBanner)
            .toList();

        bannerLstData.assignAll(validBanners);
        bannerLstData.refresh();

        debugPrint('✅ Banner list loaded => ${validBanners.length}');
      } else {
        debugPrint('Failed to load banner data: ${response.statusCode}');
        debugPrint('Response body: ${jsonEncode(response.data)}');
      }
    } catch (e) {
      debugPrint('Error fetching banner list: $e');

      // Network problem হলে old banner clear করবো না, নাহলে UI flicker করে empty হয়ে যায়.
      if (bannerLstData.isEmpty) {
        bannerLstData.value = [];
      }
    }
  }

  Uri? _safeUri(String rawLink) {
    String link = rawLink.trim();
    if (link.isEmpty) return null;

    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      link = 'https://$link';
    }

    return Uri.tryParse(link);
  }

  Future<void> openBannerLink(String link) async {
    try {
      final Uri? uri = _safeUri(link);
      if (uri == null) {
        Fluttertoast.showToast(
          msg: ('Invalid link').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 12.0,
        );
        return;
      }

      // App এর ভিতরে smooth browser open হবে.
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );

      // কোনো device/version এ in-app WebView fail করলে external browser fallback.
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        Fluttertoast.showToast(
          msg: ('Could not open link').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 12.0,
        );
      }
    } catch (e) {
      debugPrint('Banner link open error: $e');
      Fluttertoast.showToast(
        msg: ('Could not open link').appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 12.0,
      );
    }
  }

  Future<void> openBannerAction(dynamic banner) async {
    if (banner is! Map) return;

    final Map<String, dynamic> data = _normalizeBanner(banner);
    final String link = data['link']?.toString() ?? '';
    final String phone = data['phone']?.toString() ?? '';

    if (link.isNotEmpty) {
      await openBannerLink(link);
      return;
    }

    if (phone.isNotEmpty) {
      await openWhatsApp(phone);
      return;
    }

    Fluttertoast.showToast(
      msg: ('No link or WhatsApp number found').appTr,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  Future<void> openWhatsApp(String phone) async {
    try {
      String number = phone.trim();

      number = number.replaceAll('+', '');
      number = number.replaceAll(' ', '');
      number = number.replaceAll('-', '');
      number = number.replaceAll('(', '');
      number = number.replaceAll(')', '');

      if (number.isEmpty) {
        debugPrint('WhatsApp number empty');
        return;
      }

      final Uri whatsappUrl = Uri.parse('https://wa.me/$number');

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(
          msg: ('Could not open WhatsApp').appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 12.0,
        );
      }
    } catch (e) {
      debugPrint('WhatsApp open error: $e');
    }
  }

  var hostStatusData = {}.obs;

  Future<void> showHostStatusList() async {
    try {
      final response = await _dio.get(
        kHostStatus,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        if (response.data['Host Request'] == null ||
            response.data['Host Request'] == Null) {
          Get.to(VerifiedView(), transition: Transition.rightToLeft);
        } else {
          hostStatusData.value = response.data['Host Request'];
          Get.to(
            HostCertificationPage(verificationData: hostStatusData),
            transition: Transition.rightToLeft,
          );
        }
      } else {
        print("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      bannerLstData.value = []; // Set empty list on error
    }
  }
  final RxMap<String, dynamic> agencyUnderHost =
      <String, dynamic>{}.obs;

  final RxBool agencyUnderHostLoading = false.obs;
  final RxString agencyUnderHostError = ''.obs;

  bool get hasAcceptedAgency {
    if (agencyUnderHost.isEmpty) {
      return false;
    }

    final String requestStatus = agencyUnderHost['status']
        ?.toString()
        .trim()
        .toLowerCase() ??
        '';

    final dynamic agency = agencyUnderHost['agency'];

    return requestStatus == 'accepted' &&
        agency is Map &&
        agency.isNotEmpty;
  }

  Map<String, dynamic> get acceptedAgencyData {
    final dynamic agency = agencyUnderHost['agency'];

    if (agency is Map<String, dynamic>) {
      return agency;
    }

    if (agency is Map) {
      return Map<String, dynamic>.from(agency);
    }

    return <String, dynamic>{};
  }

  Future<void> agencyUnderHostList() async {
    try {
      agencyUnderHostLoading.value = true;
      agencyUnderHostError.value = '';

      final String token =
          authController.userProfile.value.token?.toString() ?? '';

      if (token.isEmpty) {
        debugPrint('❌ Host status token empty');
        agencyUnderHost.clear();
        return;
      }

      final response = await _dio.get(
        kHostStatus,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint('========================================');
      debugPrint('Host status code => ${response.statusCode}');
      debugPrint('Host status response => ${response.data}');
      debugPrint('========================================');

      if (response.statusCode == 200) {
        final dynamic responseBody = response.data;
        final dynamic hostRequest = responseBody?['Host Request'];

        if (responseBody?['status'] == true &&
            hostRequest != null &&
            hostRequest is Map) {
          agencyUnderHost.assignAll(
            Map<String, dynamic>.from(hostRequest),
          );

          debugPrint(
            '✅ Stored host request => ${agencyUnderHost.value}',
          );

          debugPrint(
            '✅ Accepted agency => ${acceptedAgencyData['name']}',
          );
        } else {
          agencyUnderHost.clear();
          debugPrint('⚠️ Host Request পাওয়া যায়নি');
        }
      } else {
        agencyUnderHost.clear();

        agencyUnderHostError.value =
        'Request failed: ${response.statusCode}';
      }
    } on DioException catch (e) {
      agencyUnderHost.clear();

      agencyUnderHostError.value =
          e.response?.data?['message']?.toString() ??
              e.message ??
              'Agency data load failed';

      debugPrint(
        '❌ Host status Dio error => '
            '${e.response?.statusCode} | ${e.response?.data}',
      );
    } catch (e, stackTrace) {
      agencyUnderHost.clear();
      agencyUnderHostError.value = e.toString();

      debugPrint('❌ Host status error => $e');
      debugPrint('❌ StackTrace => $stackTrace');
    } finally {
      agencyUnderHostLoading.value = false;
    }
  }

  //is Guardian

  final RxBool isGuardianPermission = false.obs;

  bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().toLowerCase().trim();
    return text == '1' || text == 'true' || text == 'yes';
  }

  //is guardian ki nah
  Future isGuardianBoll({required int StreamId, required int userId}) async {
    print(kisGuardian(streamId: StreamId, userId: userId));
    isLoading.value = true;
    try {
      final response = await _dio.get(
        kisGuardian(streamId: StreamId, userId: userId),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 200) {
        isGuardianData.value = Map<String, dynamic>.from(response.data ?? {});
        isGuardianPermission.value = _asBool(
          response.data['is_guardian'] ?? response.data['value'],
        );

        try {
          livestreamController.applyGuardianLocalStatus(
            userId: userId,
            isGuardian: isGuardianPermission.value,
          );
        } catch (_) {
          try {
            livestreamController.isMyGuardian.value = isGuardianPermission.value;
          } catch (_) {}
        }

        isLoading.value = false;
      } else {
        isLoading.value = false;
        print('❌ Unexpected status code: ${response.statusCode}');
        Get.snackbar(
          ('Failed').appTr,
          ("Server returned status: ${response.statusCode}").appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on DioException catch (e) {
      isLoading.value = false;
      if (e.response != null) {
        Fluttertoast.showToast(
          msg: ("Error ${e.response!.statusCode}: ${e.response!.statusMessage}").appTr,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        print('   - No response received (network/connection issue)');
        Fluttertoast.showToast(
          msg: ("Network error: ${e.message}").appTr,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      isLoading.value = false;
      print('❌ Unexpected error: $e');
      Fluttertoast.showToast(
        msg: ("Unexpected error: $e").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }


//----------------- refresh
// Future<void> fetchAllData() async {
//   try {
//     isLoading.value = true;
//
//     await Future.wait([
//       showEarningData(),
//       getLivestreamList(),
//
//     ]);
//   } catch (e) {
//     print("Error refreshing data: $e");
//   } finally {
//     isLoading.value = false;
//   }
// }


  ///---------------------- VIP Full System ----------------------------------
  /// Paste these inside HomeController class if you want VIP data in HomeController.
  /// The SvipController screen already uses the same API directly.

  final vipLevelList = <dynamic>[].obs;
  final vipPackageList = <dynamic>[].obs;
  final vipCurrentData = Rxn<Map<String, dynamic>>();
  final vipHistoryList = <dynamic>[].obs;

  final vipLevelLoading = false.obs;
  final vipPackageLoading = false.obs;
  final vipPurchaseLoading = false.obs;
  final vipCurrentLoading = false.obs;

  List<dynamic> _vipExtractList(dynamic body) {
    if (body is List) return List<dynamic>.from(body);
    if (body is Map && body['data'] is List) return List<dynamic>.from(body['data']);
    if (body is Map && body['levels'] is List) return List<dynamic>.from(body['levels']);
    if (body is Map && body['vip_levels'] is List) return List<dynamic>.from(body['vip_levels']);
    if (body is Map && body['packages'] is List) return List<dynamic>.from(body['packages']);
    if (body is Map && body['history'] is List) return List<dynamic>.from(body['history']);
    return <dynamic>[];
  }

  Map<String, dynamic> _vipExtractMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  /// ===================== USER CURRENT VIP CACHE =====================
  /// যেকোনো user id দিয়ে current VIP fetch + local cache.
  /// Profile / live profile / bottom sheet সব জায়গায় এটা use করলে smooth হবে।
  final RxMap<int, Map<String, dynamic>> userCurrentVipCache =
      <int, Map<String, dynamic>>{}.obs;
  final RxSet<int> userCurrentVipLoadingIds = <int>{}.obs;

  String _currentVipCacheKey(int userId) => 'current_vip_user_$userId';

  DateTime? _parseVipDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  bool _isVipActiveMap(dynamic value) {
    if (value is! Map) return false;
    final map = Map<String, dynamic>.from(value);
    final text = (map['status'] ?? '').toString().trim().toLowerCase();
    final activeRaw = map['is_active'];

    final bool active = activeRaw == true ||
        activeRaw == 1 ||
        activeRaw?.toString().trim().toLowerCase() == 'true' ||
        text == 'active';

    if (!active || map['vip_level'] is! Map) {
      return false;
    }

    final expiresAt = _parseVipDate(map['expires_at']);
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      return false;
    }

    return true;
  }

  Map<String, dynamic>? currentVipForUser(int userId) {
    if (userId <= 0) return null;

    final cached = userCurrentVipCache[userId];
    if (_isVipActiveMap(cached)) return cached;

    final stored = box.read(_currentVipCacheKey(userId));
    if (_isVipActiveMap(stored)) {
      final map = Map<String, dynamic>.from(stored as Map);
      userCurrentVipCache[userId] = map;
      userCurrentVipCache.refresh();
      return map;
    }

    return null;
  }

  Future<Map<String, dynamic>?> fetchUserCurrentVip({
    required int userId,
    bool force = false,
    bool silent = true,
  }) async {
    if (userId <= 0) return null;

    if (!force) {
      final cached = currentVipForUser(userId);
      if (cached != null) return cached;
    }

    if (userCurrentVipLoadingIds.contains(userId)) {
      return currentVipForUser(userId);
    }

    try {
      userCurrentVipLoadingIds.add(userId);
      userCurrentVipLoadingIds.refresh();

      final response = await dio.get(
        kVipMyCurrentUrl(userId),
        options: Options(
          headers: _authHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint('========== USER CURRENT VIP API ==========' );
      debugPrint('VIP user id => $userId');
      debugPrint('VIP status => ${response.statusCode}');
      debugPrint('VIP response => ${response.data}');
      debugPrint('=========================================' );

      final body = response.data;
      final dynamic rawData = body is Map ? body['data'] : null;

      if (rawData is Map && _isVipActiveMap(rawData)) {
        final map = Map<String, dynamic>.from(rawData);
        userCurrentVipCache[userId] = map;
        userCurrentVipCache.refresh();
        box.write(_currentVipCacheKey(userId), map);

        final myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
        if (myId == userId) {
          vipCurrentData.value = map;
        }

        return map;
      }

      userCurrentVipCache.remove(userId);
      userCurrentVipCache.refresh();
      box.remove(_currentVipCacheKey(userId));

      final myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
      if (myId == userId) {
        vipCurrentData.value = null;
      }

      return null;
    } on DioException catch (e) {
      if (!silent) {
        _toast(
          message: _dioMessage(e, ('Current VIP load failed').appTr),
          backgroundColor: Colors.red,
        );
      }
      return currentVipForUser(userId);
    } catch (e) {
      debugPrint('❌ Current VIP load failed => $e');
      if (!silent) {
        _toast(message: ('Current VIP load failed').appTr, backgroundColor: Colors.red);
      }
      return currentVipForUser(userId);
    } finally {
      userCurrentVipLoadingIds.remove(userId);
      userCurrentVipLoadingIds.refresh();
    }
  }

  String vipTitleForUser(int userId) {
    final vip = currentVipForUser(userId);
    if (vip == null) return '';
    final level = vip['vip_level'];
    if (level is Map) {
      return (level['title'] ?? level['name'] ?? vip['vip_type'] ?? '')
          .toString()
          .trim();
    }
    return (vip['vip_type'] ?? '').toString().trim();
  }

  Future<void> showVipLevels({String? type}) async {
    try {
      vipLevelLoading.value = true;

      final response = await dio.get(
        kVipLevelsUrl,
        queryParameters: {
          if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      vipLevelList.assignAll(_vipExtractList(response.data));
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, ('VIP level load failed').appTr),
        backgroundColor: Colors.red,
      );
    } catch (_) {
      _toast(message: ('VIP level load failed').appTr, backgroundColor: Colors.red);
    } finally {
      vipLevelLoading.value = false;
    }
  }

  Future<void> showVipPackages() async {
    try {
      vipPackageLoading.value = true;

      final response = await dio.get(
        kVipPackagesUrl,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      vipPackageList.assignAll(_vipExtractList(response.data));
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, ('VIP package load failed').appTr),
        backgroundColor: Colors.red,
      );
    } catch (_) {
      _toast(message: ('VIP package load failed').appTr, backgroundColor: Colors.red);
    } finally {
      vipPackageLoading.value = false;
    }
  }

  Future<void> showMyCurrentVip({bool silent = false, required int id}) async {
    try {
      vipCurrentLoading.value = true;
      vipCurrentData.value = await fetchUserCurrentVip(
        userId: id,
        force: true,
        silent: silent,
      );
    } finally {
      vipCurrentLoading.value = false;
    }
  }

  Future<void> showMyVipHistory() async {
    try {
      final response = await dio.get(
        kVipMyHistoryUrl,
        options: Options(headers: _authHeaders),
      );

      vipHistoryList.assignAll(_vipExtractList(response.data));
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, ('VIP history load failed').appTr),
        backgroundColor: Colors.red,
      );
    } catch (_) {
      _toast(message: ('VIP history load failed').appTr, backgroundColor: Colors.red);
    }
  }

  Future<void> refreshVipData() async {
    await Future.wait([
      showVipLevels(),
      showVipPackages(),
      showMyCurrentVip(silent: true, id:  int.parse(authController.userProfile.value.user!.id.toString())),
    ]);
  }

  Future<bool> purchaseVipPackage({required int packageId}) async {
    if (packageId <= 0 || vipPurchaseLoading.value) return false;

    try {
      vipPurchaseLoading.value = true;

      final response = await dio.post(
        kVipPurchaseUrl,
        data: {'package_id': packageId},
        options: Options(headers: _authHeaders),
      );

      final body = response.data;
      final message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'VIP purchased successfully';

      if (body is Map && body['data'] != null) {
        vipCurrentData.value = _vipExtractMap(body['data']);
      }

      _toast(message: message, backgroundColor: Colors.green);

      await Future.wait([
        showMyCurrentVip(silent: true, id: int.parse(authController.userProfile.value.user!.id.toString())),
        showMyVipHistory(),
      ]);

      return true;
    } on DioException catch (e) {
      _toast(
        message: _dioMessage(e, ('VIP purchase failed').appTr),
        backgroundColor: Colors.red,
      );
      return false;
    } catch (_) {
      _toast(message: ('VIP purchase failed').appTr, backgroundColor: Colors.red);
      return false;
    } finally {
      vipPurchaseLoading.value = false;
    }
  }

  // ✅ Live profile CP API loader
  // Profile page-er moto CP partner data bottom sheet-e real vabe show korar jonno.
  Future<void> fetchLiveProfileCp({
    required int userId,
    bool force = false,
  }) async {
    if (userId <= 0) return;
    if (!force && liveProfileCpCache[userId] != null) return;
    if (liveProfileCpLoadingIds.contains(userId)) return;

    try {
      liveProfileCpLoadingIds.add(userId);
      liveProfileCpLoadingIds.refresh();

      final response = await dio.post(
        kProfileVisitor,
        data: {'user_id': '$userId'},
        options: Options(
          headers: _authHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final Map<String, dynamic> root = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{'data': response.data};

      final Map<String, dynamic> user = root['User Data'] is Map
          ? Map<String, dynamic>.from(root['User Data'] as Map)
          : <String, dynamic>{};

      final Map<String, dynamic> cp = _extractProfileCpMap(
        user: user,
        root: root,
      );

      if (cp.isNotEmpty) {
        liveProfileCpCache[userId] = cp;
        liveProfileCpCache.refresh();
      }
    } catch (e) {
      debugPrint('Live profile CP load failed => $e');
    } finally {
      liveProfileCpLoadingIds.remove(userId);
      liveProfileCpLoadingIds.refresh();
    }
  }

  // ✅ Live profile family API loader
  // CP/Family card bottom sheet-e real family show korar jonno.
  Future<void> fetchLiveProfileFamily({
    required int userId,
    bool force = false,
  }) async {
    if (userId <= 0) return;
    if (!force && liveProfileFamilyCache[userId] != null) return;
    if (liveProfileFamilyLoadingIds.contains(userId)) return;

    try {
      liveProfileFamilyLoadingIds.add(userId);
      liveProfileFamilyLoadingIds.refresh();

      final response = await dio.get(
        userFamily(id: '$userId'),
        options: Options(
          headers: _authHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final Map<String, dynamic> family = _extractProfileFamilyMap(
        user: <String, dynamic>{},
        root: response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : <String, dynamic>{'data': response.data},
      );

      if (family.isNotEmpty) {
        liveProfileFamilyCache[userId] = family;
        liveProfileFamilyCache.refresh();
      }
    } catch (e) {
      debugPrint('Live profile family load failed => $e');
    } finally {
      liveProfileFamilyLoadingIds.remove(userId);
      liveProfileFamilyLoadingIds.refresh();
    }
  }
}
