import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../services/cp_invite_model.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class CpInviteController extends GetxController {
  final Dio _dio = Dio();

  final RxBool isLoading = false.obs;
  final RxInt processingRequestId = 0.obs;
  final RxString errorMessage = ''.obs;

  final RxList<CpInviteRequest> cpRequests = <CpInviteRequest>[].obs;
  final RxMap<String, dynamic> summary = <String, dynamic>{}.obs;

  // old code support rakhar jonno
  final RxMap<String, dynamic> CplistData = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCpInvites();
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

  Future<void> fetchCpInvites({bool showLoader = true}) async {
    try {
      if (showLoader) isLoading.value = true;
      errorMessage.value = '';

      final response = await _dio.get(
        kCpInviteList,
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data['status'] == true) {
        final data = response.data['data'] ?? {};
        final requestList = data['requests'] ?? [];

        CplistData.value = Map<String, dynamic>.from(response.data);
        summary.value = Map<String, dynamic>.from(data['summary'] ?? {});

        cpRequests.assignAll(
          List.from(requestList).map((e) => CpInviteRequest.fromJson(e)).toList(),
        );
      } else {
        errorMessage.value =
            response.data['message']?.toString() ?? 'CP invite load failed';
      }
    } catch (e) {
      errorMessage.value = e.toString();
      print('❌ CP invite fetch error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> cpAccept({required int id}) async {
    return _cpAction(
      id: id,
      url: kCpAccept(id: id),
      successMessage: 'CP request accepted successfully',
    );
  }

  Future<bool> cpReject({required int id}) async {
    return _cpAction(
      id: id,
      url: kCpReject(id: id),
      successMessage: 'CP request rejected successfully',
    );
  }

  Future<bool> _cpAction({
    required int id,
    required String url,
    required String successMessage,
  }) async {
    try {
      processingRequestId.value = id;

      final response = await _postOrGet(url);

      final bool success =
          response.statusCode == 200 && response.data['status'] == true;

      if (success) {
        Get.snackbar(
          ('Success').appTr,
          response.data['message']?.toString() ?? successMessage,
          snackPosition: SnackPosition.BOTTOM,
        );

        await fetchCpInvites(showLoader: false);
        return true;
      }

      Get.snackbar(
        ('Failed').appTr,
        response.data['message']?.toString() ?? ('Action failed').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    } catch (e) {
      print('❌ CP action error: $e');
      Get.snackbar(
        ('Error').appTr,
        ('Something went wrong').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      processingRequestId.value = 0;
    }
  }

  Future<Response> _postOrGet(String url) async {
    final postResponse = await _dio.post(
      url,
      options: _authOptions,
    );

    // Laravel route jodi GET hoy, tahole POST e 405 ashte pare
    if (postResponse.statusCode == 405) {
      return _dio.get(
        url,
        options: _authOptions,
      );
    }

    return postResponse;
  }
}