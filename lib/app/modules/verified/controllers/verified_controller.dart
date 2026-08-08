import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../Agency/views/agency_view.dart';
import '../../Agency/views/createAgency.dart';
import '../views/verifySuccess.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class VerifiedController extends GetxController {
  final whatsappNumber = TextEditingController();
  final selectedHostType = ''.obs;
  final isValid = false.obs;

  @override
  void onInit() {
    super.onInit();
    whatsappNumber.addListener(_validateForm);
  }

  void selectHostType(String value) {
    selectedHostType.value = value;
    _validateForm();
  }

  void _validateForm() {
    isValid.value = whatsappNumber.text.trim().isNotEmpty &&
        selectedHostType.value.isNotEmpty;
  }

  @override
  void onClose() {
    super.onClose();
  }

  final isLoading = false.obs;
  final dio = Dio();

  ///---------------------------- host create ---------------
  final hostVerifyData = {}.obs;

  Future<void> hostVerifyPost({required String agencyId}) async {
    final data = {
      'agency_id': agencyId,
      'whatsapp_number': whatsappNumber.text,
      'host_type': selectedHostType.value,
    };
    print('Verify data$data');
    try {
      isLoading.value = true;
      print(data);
      print(authController.userProfile.value.token);
      print(kJoinAgency);
      final response = await dio.post(
        kJoinAgency,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        isLoading.value = false;
        hostVerifyData.value = response.data;

        Get.to(HostVerifySuccessPage(), transition: Transition.rightToLeft);
        Fluttertoast.showToast(
          msg: ("Host Verify success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
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

  ///------------------------------  host apply to join agency --------------------
  final joinAgencyData = {}.obs;

  Future<void> agencyJoinPost({required int agencyId}) async {
    final data = {
      'agency_id': agencyId,
    };

    try {
      isLoading.value = true;

      final response = await dio.post(
        kJoinAgency,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        isLoading.value = false;
        joinAgencyData.value = response.data;
        print(response.data);
        Fluttertoast.showToast(
          msg: ("join success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        // Get.offAll(VerifyPage4(), transition: Transition.rightToLeft);
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

  /// ---- new agency list---------------
  final newAgencyList = [].obs;
  final agencySingleData = {}.obs;

  Future<void> showNewAgenctList() async {
    try {

      isLoading.value = true;

      final response = await dio.get(
        kNewAgencyList,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      isLoading.value = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Check if data exists
        if (response.data?['data']?['agencies'] == null) {

          return;
        }

        final agencies = response.data['data']['agencies'] as List;
        newAgencyList.value = agencies;

        // Empty check করার পর navigation
        if (newAgencyList.isEmpty) {
          // Empty হলে single data clear করে দিন
          agencySingleData.value = {};

          Get.to(
            () => Createagency(),
            transition: Transition.rightToLeft,
          );

        } else {
          // List এ data থাকলে first item নিন
          agencySingleData.value = newAgencyList[0];

          Get.to(
            () => AgencyView(),
            transition: Transition.rightToLeft,
          );

        }
      } else {
        isLoading.value = false;

      }
    } on DioException catch (e) {
      isLoading.value = false;
      print('Agency API Error: ${e.response?.data ?? e.message}');

      final errorMsg = e.response?.data?['message'] ?? 'Network error occurred';

    } catch (e) {
      isLoading.value = false;
      print('Unexpected error: $e');
      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
