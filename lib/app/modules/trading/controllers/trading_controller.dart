import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class TradingController extends GetxController {
  final dio = Dio();

  ///---------------- Percentage ----------------
  final persentanseData = {}.obs;
  final persentense = 0.0.obs;

  RxString calculatedAmount = '0'.obs;

  ///---------------- Button Active ----------------
  final isButtonActive = false.obs;

  ///---------------- Loading ----------------
  final isLoading = false.obs;
  final rechargeHistoryLoading = false.obs;

  ///---------------- Text Controller ----------------
  final searchController = TextEditingController();
  final amount = TextEditingController();

  ///---------------- Data ----------------
  final coinTradingData = {}.obs;

  /// Recharge history API response
  final rechargeSummary = {}.obs;
  final tradingListData = <dynamic>[].obs;
  final paginationData = {}.obs;

  @override
  void onInit() {
    super.onInit();

    searchController.addListener(chackFeild);
    amount.addListener(chackFeild);

    coinTradingPersentense();
  }

  @override
  void onClose() {
    searchController.dispose();
    amount.dispose();
    super.onClose();
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String safeText(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  ///---------------- Percentage API ----------------
  Future<void> coinTradingPersentense() async {
    try {
      print('🔄 API Call Started');
      print('📍 Endpoint: $coinPersentense');

      final response = await dio.get(
        coinPersentense,
      );

      print('✅ Response Status Code: ${response.statusCode}');
      print('📦 Full Response Data: ${response.data}');

      if (response.statusCode == 200) {
        if (response.data != null) {
          if (response.data.containsKey('coin_trad_persent')) {
            persentanseData.value = response.data;

            final percentValue = response.data['coin_trad_persent'];

            if (percentValue is String) {
              persentense.value = double.tryParse(percentValue) ?? 0.0;
            } else if (percentValue is int) {
              persentense.value = percentValue.toDouble();
            } else if (percentValue is double) {
              persentense.value = percentValue;
            } else {
              persentense.value = 0.0;
            }

            print('💰 Converted Percentage Value: ${persentense.value}');
          } else {
            print('❌ Key "coin_trad_persent" not found');
          }
        }
      } else {
        Fluttertoast.showToast(
          msg: ("Your credentials don't match.").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error occurred: $e');
      print('📍 Stack Trace: $stackTrace');
    }
  }

  ///---------------- Calculate Percentage ----------------
  void calculatePercentage(String value) {
    if (value.isEmpty) {
      calculatedAmount.value = '';
      return;
    }

    try {
      final inputAmount = double.parse(value);

      if (persentense.value <= 0 || persentense.value > 100) {
        print('⚠️ Invalid percentage: ${persentense.value}');
        calculatedAmount.value = '';
        return;
      }

      final userPercentage = persentense.value;
      final userAmount = inputAmount * (userPercentage / 100);

      calculatedAmount.value = '💎 ${userAmount.toStringAsFixed(0)}';

      final adminPercentage = 100 - userPercentage;
      final adminAmount = inputAmount * (adminPercentage / 100);

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📥 Input Amount: $inputAmount');
      print('👤 User gets: $userPercentage% = ${userAmount.toStringAsFixed(0)}');
      print('👨‍💼 Admin gets: $adminPercentage% = ${adminAmount.toStringAsFixed(0)}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      calculatedAmount.value = '';
      print('❌ Calculation error: $e');
    }
  }

  void chackFeild() {
    if (searchController.text.trim().isNotEmpty &&
        amount.text.trim().isNotEmpty) {
      isButtonActive.value = true;
    } else {
      isButtonActive.value = false;
    }
  }

  ///---------------- Coin Trading Post ----------------
  Future<void> coinTrading({required String userid}) async {
    try {
      isLoading.value = true;

      print('Trading URL: ${kCoinTradingPost(userId: userid, amount: amount.text)}');
      print('Token: ${authController.userProfile.value.token}');

      final response = await dio.get(
        kCoinTradingPost(userId: userid, amount: amount.text),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        coinTradingData.value = response.data;

        Fluttertoast.showToast(
          msg: response.data['message']?.toString() ?? ("Coin Trading Success").appTr,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        amount.clear();

        await showTradingList();

        Get.back();
      } else {
        Fluttertoast.showToast(
          msg: ("Your credentials don't match.").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('Coin trading Dio error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ?? ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Coin trading error: $e');

      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  ///---------------- Recharge / Trading History ----------------
  Future<void> showTradingList() async {
    try {
      rechargeHistoryLoading.value = true;

      final response = await dio.get(
        kCoinTradingGet,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      print('========== RECHARGE HISTORY ==========');
      print('Status Code: ${response.statusCode}');
      print('Response: ${response.data}');
      print('=====================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final summary = response.data['summary'];
        final data = response.data['data'];
        final pagination = response.data['pagination'];

        if (summary is Map) {
          rechargeSummary.value = Map<String, dynamic>.from(summary);
        } else {
          rechargeSummary.clear();
        }

        if (data is List) {
          tradingListData.value = data;
        } else {
          tradingListData.clear();
        }

        if (pagination is Map) {
          paginationData.value = Map<String, dynamic>.from(pagination);
        } else {
          paginationData.clear();
        }
      } else {
        Fluttertoast.showToast(
          msg: response.data['message']?.toString() ??
              ('Recharge history load failed').appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('Recharge history Dio error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ('Recharge history load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Recharge history error: $e');

      Fluttertoast.showToast(
        msg: ('Recharge history load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      rechargeHistoryLoading.value = false;
    }
  }
}