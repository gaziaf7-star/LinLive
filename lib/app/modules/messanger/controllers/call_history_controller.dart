import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../auth/controllers/auth_controller.dart';

class CallHistoryController extends GetxController {
  final callHistoryLoading = false.obs;
  final List<dynamic> callHistories = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }

  void loadCallHistoryList() async {
    callHistoryLoading.value = true;
    final AuthController authController = Get.find();
    var dio = Dio();
    try {
      final response = await dio.get(
        kCallHistoryListUrl,
        options: Options(headers: {
          'accept': '*/*',
          'Authorization': 'Token ${authController.userProfile.value}',
        }),
      );
      int? statusCode = response.statusCode;
      callHistoryLoading.value = false;
      if (statusCode == 200) {
        dynamic data = response.data['call_histories'];
        callHistories.clear();
        callHistories.addAll(data);
      }
    } catch (e) {
      callHistoryLoading.value = false;
    }
  }

  void createCallHistory({
    required String type,
    required int receiverUid,
    required String callType,
  }) async {
    final AuthController authController = Get.find();

    dynamic data = {
      'type': type,
      'receiver_uid': receiverUid,
      'call_type': callType,
    };
    var dio = Dio();
    try {
      final response = await dio.post(
        'kCallHistoryCreateUrl',
        data: data,
        options: Options(headers: {
          'accept': '*/*',
          'Authorization': 'Token ${authController.userProfile.value.token}',
        }),
      );
      int? statusCode = response.statusCode;
      // if (statusCode == 201) {}
    } catch (e) {
      // Nothing
    }
  }


}
