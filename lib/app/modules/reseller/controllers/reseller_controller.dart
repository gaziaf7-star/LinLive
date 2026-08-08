import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../appmenu/views/appmenu_view.dart';
import '../views/transaction_success_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ResellerController extends GetxController {
  ///----------------------------button active ---------------------
  var isButtonEnabled = false.obs;
  var isTradeButton = false.obs;

  @override
  void onInit() {
    super.onInit();

    searchController.addListener(() {
      checkFields();
    });

    tradingIdController.addListener(() {
      checkTradingFeild();
    });
    amount.addListener(() {
      checkFields();
    });

    tradingAmount.addListener(() {
      checkTradingFeild();
    });
  }

  void checkFields() {
    if (searchController.text.isNotEmpty && amount.text.isNotEmpty) {
      isButtonEnabled.value = true;
    } else {
      isButtonEnabled.value = false;
    }
  }

  ///---------------------Trading Button ----------------------
  void checkTradingFeild() {
    if (tradingIdController.text.isNotEmpty && tradingAmount.text.isNotEmpty) {
      isTradeButton.value = true;
    } else {
      isTradeButton.value = false;
    }
  }

  ///--------------------post create reseller Coin transfer  --------------------

  final isLoading = false.obs;
  final dio = Dio();
  final searchController = TextEditingController();
  final amount = TextEditingController();

  final resellerTranferBalancrData = {}.obs;

  ///-------------------- post create reseller Coin transfer--------------------
  Future<void> resellerBaanceTransfer() async {
    final data = {
      'user_id': searchController.text,
      'amount': amount.text,
    };
    print('blance transfer data $data');
    print(kResellerRecharge);
    print(authController.userProfile.value.token);
    try {
      isLoading.value = true;

      final response = await dio.post(
        kResellerRecharge,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        isLoading.value = false;
        resellerTranferBalancrData.value = response.data;
        Get.to(TransactionSuccessView());
        Fluttertoast.showToast(
          msg: ("Balance transfer Success").appTr,
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

  ///------------- Reseller Trading Transfer balance -------------------

  final tradingIdController = TextEditingController();
  final tradingAmount = TextEditingController();

  final resellerTraningCoinData = {}.obs;

  Future<void> resellerTradingBalanceTransfer() async {
    final data = {
      'user_id': tradingIdController.text,
      'amount': tradingAmount.text,
    };
    try {
      isLoading.value = true;

      ///------------------print section -------------
      print(data);
      print(kResellerCoinTrading);
      print(authController.userProfile.value.token);
      final response = await dio.post(
        kResellerCoinTrading,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      if (response.statusCode == 200) {
        isLoading.value = false;
        resellerTraningCoinData.value = response.data;

        print(response.data);
        Fluttertoast.showToast(
          msg: ("Trading balance transfer Success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        Get.offAll(AppmenuView(), transition: Transition.rightToLeft);
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
}
