import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

class OfficialMessageController extends GetxController {
  final isLoading = false.obs;
  final noticeList = [].obs;

  final _dio = Dio();

  Future<void> fetchNotice() async {
    isLoading.value = true;

    try {
      isLoading.value = true;

      final response = await _dio.get(
        kNoticsUrl,
        options: Options(headers: {
          'Accept': 'application/json',
          'Authorization': 'Token ${authController.userProfile.value.token}',
        }),
      );
      if (response.statusCode == 200) {
        noticeList.value.clear();
        noticeList.addAll(response.data);
      }
      ;
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
    }
  }

  final recharageMessageList = [].obs;
  Future<void> fetchRecharge() async {
    isLoading.value = true;
    try {
      isLoading.value = true;

      final response = await _dio.get(
        kRechargeListUrl,
        options: Options(headers: {
          'Accept': 'application/json',
          'Authorization': 'Token ${authController.userProfile.value.token}',
        }),
      );
      print('recharge message');
      print(response.data);
      if (response.statusCode == 200) {
        recharageMessageList.clear();
        recharageMessageList.addAll(response.data);
      }

      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
    }
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onInit() {
    // TODO: implement onInit
    fetchNotice();
    super.onInit();
  }
}
