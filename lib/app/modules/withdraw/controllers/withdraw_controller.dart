import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:meetlivepro/apis/api_endpoints.dart';
import 'package:meetlivepro/constants/constants.dart';

import '../../appmenu/views/appmenu_view.dart';
import '../views/exchangeSucessPage.dart';
import '../withdraw_account-add.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WithdrawController extends GetxController {
  final dio = Dio();

  final double dollarToTakaRate = 121.5;

  /// =========================================================
  /// RECEIVE COIN TO DOLLAR SETTING FROM ADMIN API
  /// API example:
  /// {
  ///   "conversion_status": "on",
  ///   "is_conversion_active": true,
  ///   "receive_coins": 100000,
  ///   "dollar": 2,
  ///   "rate_text": "100000 receive coins = $2"
  /// }
  /// =========================================================

  final RxBool dollarSettingLoading = false.obs;
  final RxMap<String, dynamic> dollarConversionSetting = <String, dynamic>{}.obs;

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  bool get isDollarConversionActive {
    final status =
    dollarConversionSetting['conversion_status']?.toString().toLowerCase();

    final active = dollarConversionSetting['is_conversion_active'];

    return status == 'on' ||
        active == true ||
        active?.toString().toLowerCase() == 'true';
  }

  int get dollarReceiveCoins {
    return _toInt(dollarConversionSetting['receive_coins']);
  }

  double get dollarAmount {
    return _toDouble(dollarConversionSetting['dollar']);
  }

  String get dollarRateText {
    final text = dollarConversionSetting['rate_text']?.toString();

    if (text != null && text.trim().isNotEmpty) {
      return text;
    }

    if (dollarReceiveCoins > 0 && dollarAmount > 0) {
      return '$dollarReceiveCoins receive coins = \$${dollarAmount.toStringAsFixed(2)}';
    }

    return 'Dollar rate loading...';
  }

  int get userEarnedCoins {
    return int.tryParse(
      authController.userProfile.value.user?.earnedCoins?.toString() ?? '0',
    ) ??
        0;
  }

  double calculateDollarFromEarnedCoins(int coins) {
    if (!isDollarConversionActive) return 0.0;
    if (coins <= 0) return 0.0;
    if (dollarReceiveCoins <= 0 || dollarAmount <= 0) return 0.0;

    return (coins / dollarReceiveCoins) * dollarAmount;
  }

  String get earnedDollar {
    final dollar = calculateDollarFromEarnedCoins(userEarnedCoins);
    return '\$${dollar.toStringAsFixed(2)}';
  }

  String get earnedTaka {
    final dollar = calculateDollarFromEarnedCoins(userEarnedCoins);
    final taka = dollar * dollarToTakaRate;
    return '৳${taka.toStringAsFixed(2)}';
  }

  ///---------------------- withdraw variables create----------------
  final number = TextEditingController();
  final selectMethode = ''.obs;
  final selectedWithdrawMethodId = 0.obs;

  final amount = TextEditingController();

  ///---------------------- withdraw to trading variables create----------------
  final tradeAmount = TextEditingController();

  ///---------------------- exchange Amount variables create----------------
  final exchangeAmount = TextEditingController();

  ///--------------------data store -------------
  final withdrawData = {}.obs;
  final withdrawToTradeData = {}.obs;
  final exchangeCoinData = {}.obs;

  //----------loading ----------
  final isLoading = false.obs;

  ///----------------------- validation variables ------------
  RxBool isFormFilled = false.obs;
  RxBool isTradeFormFilled = false.obs;

  ///----------withdraw validateForm -----------
  void validateForm() {
    isFormFilled.value = number.text.trim().isNotEmpty &&
        selectMethode.value.trim().isNotEmpty &&
        amount.text.trim().isNotEmpty;
  }

  ///------------withdraw to trading validateTradeForm---------------
  void validateTradeForm() {
    isTradeFormFilled.value = tradeAmount.text.trim().isNotEmpty;
  }

  @override
  void onInit() {
    super.onInit();

    number.addListener(validateForm);
    amount.addListener(validateForm);
    tradeAmount.addListener(validateTradeForm);

    ever(selectMethode, (_) => validateForm());

    exchangeDoler();
  }

  @override
  void onClose() {
    number.dispose();
    amount.dispose();
    tradeAmount.dispose();
    exchangeAmount.dispose();
    super.onClose();
  }

  ///-------------- Add withdraw account ---------------
  Future<void> withdrawPost() async {
    if (selectMethode.value.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: ("Please select withdraw method").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (selectedWithdrawMethodId.value == 0) {
      Fluttertoast.showToast(
        msg: ("Invalid withdraw method").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (number.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: ("Please enter account number").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final data = {
      'method_account': number.text.trim(),
      'method_name': selectMethode.value.trim(),
      'method_id': selectedWithdrawMethodId.value,
    };

    try {
      isLoading.value = true;

      print("========== ADD WITHDRAW ACCOUNT ==========");
      print("Request Data: $data");
      print("Selected Method Name: ${selectMethode.value}");
      print("Selected Method ID: ${selectedWithdrawMethodId.value}");
      print("==========================================");

      final response = await dio.post(
        kWithdrawUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        withdrawData.value = response.data;
        print("Withdraw account response: ${response.data}");

        await getWithdrawList();

        Fluttertoast.showToast(
          msg: response.data['message']?.toString() ?? ("Withdraw Method success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        number.clear();
        selectMethode.value = '';
        selectedWithdrawMethodId.value = 0;

        Get.offAll(() => WithdrawAccount(), transition: Transition.rightToLeft);
      } else {
        Fluttertoast.showToast(
          msg: ("Your credentials doesn't match.").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } on DioException catch (e) {
      print("Withdraw account Dio Error: ${e.response?.data}");

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ?? ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } catch (e) {
      print("Withdraw account Error: $e");

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      isLoading.value = false;
    }
  }

  ///---------------- Withdraw list ------------------
  final withDrawList = [].obs;

  Future<void> getWithdrawList() async {
    try {
      final data = await dio.get(
        kgetWithdrawList,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (data.statusCode == 200 || data.statusCode == 201) {
        withDrawList.value = data.data['data'] ?? [];
        print('Withdraw data $withDrawList');
      }
    } on DioException catch (e) {
      print("Withdraw list Dio error: ${e.response?.data}");
    } catch (e) {
      print("Withdraw list error: $e");
    }
  }

  ///---------------- Withdraw method list ------------------
  final withdrawMethodeList = [].obs;

  Future<void> getWithdrawMethodeList() async {
    try {
      final data = await dio.get(
        kWithdrawMethodeList,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (data.statusCode == 200 || data.statusCode == 201) {
        withdrawMethodeList.value = data.data['data'] ?? [];

        print("========== WITHDRAW METHOD LIST ==========");
        print("Withdraw method data: $withdrawMethodeList");
        print("Total method: ${withdrawMethodeList.length}");

        for (var item in withdrawMethodeList) {
          print(
            "Method => id: ${item['id']} | name: ${item['name']} | min: ${item['minimum_coin']} | max: ${item['maximum_coin']}",
          );
        }

        print("==========================================");
      }
    } on DioException catch (e) {
      print("Withdraw method Dio error: ${e.response?.data}");

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ("Withdraw method load failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print("Withdraw method error: $e");

      Fluttertoast.showToast(
        msg: ("Withdraw method load failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  final resellerList = [].obs;
  final resellerLoading = false.obs;

  Future<void> getResellerList() async {
    try {
      resellerLoading.value = true;

      print('🟣 ========== RESELLER LIST API START ==========');
      print('🌐 URL: $kResellerList');
      print('🔑 Token: ${authController.userProfile.value.token}');

      final response = await dio.get(
        kResellerList,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      print('📡 Reseller Status Code: ${response.statusCode}');
      print('📄 Reseller Full Response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        resellerList.value = response.data['data'] ?? [];

        print('✅ Reseller list count: ${resellerList.length}');
        print('✅ Reseller list data: $resellerList');

        for (var item in resellerList) {
          print(
            '👤 Reseller => id: ${item['id']} | user_id: ${item['user_id']} | name: ${item['name']} | image: ${item['profile_image']}',
          );
        }
      }
    } on DioException catch (e) {
      print('❌ Reseller Dio Error: ${e.response?.data}');
      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ("Reseller list load failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('❌ Reseller General Error: $e');
      Fluttertoast.showToast(
        msg: ("Reseller list load failed").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      resellerLoading.value = false;
      print('🟣 ========== RESELLER LIST API END ==========');
    }
  }

  ///---------------------- withdraw post create -------------
  final RxString receivedType = 'admin'.obs;
  final RxnInt selectedResellerId = RxnInt();

  final WithdrawData = {}.obs;

  Future<void> withdrawSubmit({
    required int methodId,
    required String selectedReceivedType,
    int? resellerId,
  }) async {
    print('🔵 ========== WITHDRAW SUBMIT START ==========');
    print('🟡 Method ID: $methodId');
    print('🟡 Selected Received Type: $selectedReceivedType');
    print('🟡 Selected Reseller ID: $resellerId');
    print('🟡 Controller Selected Reseller ID: ${selectedResellerId.value}');
    print('🟡 Amount Text: ${amount.text}');

    if (methodId == 0) {
      Fluttertoast.showToast(
        msg: ("Please select withdraw method").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (amount.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: ("Please enter amount").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final int? parsedAmount = int.tryParse(amount.text.trim());

    if (parsedAmount == null) {
      Fluttertoast.showToast(
        msg: ("Invalid amount format").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final List<int> allowedAmounts = [
      200000,
      500000,
      1000000,
      2000000,
      4000000,
      6000000,
      8000000,
      10000000,
      15000000,
      20000000,
      35000000,
      50000000,
    ];

    if (!allowedAmounts.contains(parsedAmount)) {
      Fluttertoast.showToast(
        msg: ("Invalid amount").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (selectedReceivedType == 'reseller' && resellerId == null) {
      print('❌ Reseller selected but resellerId is NULL');

      Fluttertoast.showToast(
        msg: ("Please select reseller").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final Map<String, dynamic> data = {
      'method_id': methodId,
      'amount': parsedAmount,
      'received_type': selectedReceivedType,
    };

    if (selectedReceivedType == 'reseller') {
      data['reseller_id'] = resellerId;
    }

    print('📦 Final Request Data: $data');

    final token = authController.userProfile.value.token;

    if (token == null || token.toString().isEmpty) {
      Fluttertoast.showToast(
        msg: ("Authentication failed. Please login again").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;

      final response = await dio.post(
        kpostWithdraw,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      print('📡 Withdraw Response Status Code: ${response.statusCode}');
      print('📄 Withdraw Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        WithdrawData.value = response.data;

        Fluttertoast.showToast(
          msg: response.data['message']?.toString() ??
              ("Withdraw request success").appTr,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        amount.clear();
        selectedResellerId.value = null;
        receivedType.value = 'admin';

        Get.back();
      } else {
        Fluttertoast.showToast(
          msg: ("Withdraw request failed").appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (dioError) {
      print('❌ DIO ERROR: ${dioError.response?.data}');
      print('❌ DIO STATUS: ${dioError.response?.statusCode}');
      print('❌ DIO REQUEST DATA: ${dioError.requestOptions.data}');

      String errorMessage = ("Something went wrong").appTr;

      if (dioError.response?.data is Map) {
        errorMessage = dioError.response?.data['message']?.toString() ??
            dioError.response?.data['error']?.toString() ??
            errorMessage;
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      print('❌ GENERAL ERROR: $e');

      Fluttertoast.showToast(
        msg: ("Unexpected error: $e").appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      isLoading.value = false;
    }

    print('🔵 ========== WITHDRAW SUBMIT END ==========\n');
  }

  //--------------------Withdraw to trading -------------
  Future<void> withdrawToTradePost() async {
    final data = {
      'amount': tradeAmount.text,
    };

    try {
      isLoading.value = true;

      print(data);
      print(kWithdrawUrl);
      print(authController.userProfile.value.token);

      final response = await dio.post(
        kWithdrawToTradeUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200) {
        withdrawToTradeData.value = response.data;
        print(response.data);

        Fluttertoast.showToast(
          msg: ("withdraw to Trade success").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        Get.offAll(() => AppmenuView(), transition: Transition.rightToLeft);
      } else {
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

      Fluttertoast.showToast(
        msg: ("Something went wrong").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      isLoading.value = false;
    }
  }

  ///------------------------ Exchange Coin Professional ----------------

  final RxBool exchangeLoading = false.obs;
  final RxBool exchangeHistoryLoading = false.obs;

  final RxMap<String, dynamic> exchangeSettingList = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> exchangeCurrentBalance = <String, dynamic>{}.obs;
  final RxList<dynamic> exchangeHistoryList = <dynamic>[].obs;

  final RxInt previewReceiveCoins = 0.obs;

  int get settingEarnedCoins {
    return _toInt(
      exchangeSettingList['setting_earned_coins'] ??
          exchangeSettingList['earned_coins'] ??
          2,
    );
  }

  int get settingCoins {
    return _toInt(
      exchangeSettingList['setting_coins'] ??
          exchangeSettingList['coins'] ??
          1,
    );
  }

  int get currentEarnedCoins {
    return _toInt(
      exchangeCurrentBalance['earned_coins'] ??
          authController.userProfile.value.user?.earnedCoins ??
          0,
    );
  }

  int get currentCoins {
    return _toInt(
      exchangeCurrentBalance['coins'] ??
          authController.userProfile.value.user?.coins ??
          0,
    );
  }

  String get exchangeRateText {
    return '$settingEarnedCoins Receive Coins = $settingCoins Coins';
  }

  int calculateReceiveCoinsByAmount(String value) {
    final int amount = int.tryParse(value.trim()) ?? 0;

    if (amount <= 0) return 0;
    if (settingEarnedCoins <= 0) return 0;

    return ((amount / settingEarnedCoins) * settingCoins).floor();
  }

  void updateExchangePreview(String value) {
    previewReceiveCoins.value = calculateReceiveCoinsByAmount(value);
  }

  ///------------------ Exchange setting ----------------
  Future<void> exchangeSetting() async {
    try {
      final response = await dio.get(
        kexchangeSetting,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];

        if (data is Map<String, dynamic>) {
          exchangeSettingList.value = data;
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          exchangeSettingList.value = Map<String, dynamic>.from(data.first);
        }

        updateExchangePreview(exchangeAmount.text);
      }
    } on DioException catch (e) {
      print('Exchange setting Dio Error: ${e.response?.data}');
      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ('Exchange setting load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Exchange setting Error: $e');
      Fluttertoast.showToast(
        msg: ('Exchange setting load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  ///------------------ Exchange history ----------------
  Future<void> exchangeHistory() async {
    try {
      exchangeHistoryLoading.value = true;

      final response = await dio.get(
        kexchangeHistoryList,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final balance = response.data['current_balance'];
        final history = response.data['data'];

        if (balance is Map<String, dynamic>) {
          exchangeCurrentBalance.value = balance;
        }

        if (history is List) {
          exchangeHistoryList.value = history;
        } else {
          exchangeHistoryList.clear();
        }

        if (exchangeSettingList.isEmpty &&
            exchangeHistoryList.isNotEmpty &&
            exchangeHistoryList.first is Map) {
          final first = Map<String, dynamic>.from(exchangeHistoryList.first);

          exchangeSettingList.value = {
            'setting_earned_coins': first['setting_earned_coins'],
            'setting_coins': first['setting_coins'],
          };
        }

        updateExchangePreview(exchangeAmount.text);
      }
    } on DioException catch (e) {
      print('Exchange history Dio Error: ${e.response?.data}');
      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ('Exchange history load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Exchange history Error: $e');
      Fluttertoast.showToast(
        msg: ('Exchange history load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      exchangeHistoryLoading.value = false;
    }
  }

  ///------------------ Exchange submit ----------------
  Future<void> exchangeCoin() async {
    final int amount = int.tryParse(exchangeAmount.text.trim()) ?? 0;

    if (amount <= 0) {
      Fluttertoast.showToast(
        msg: ('Please enter valid amount').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (amount > currentEarnedCoins) {
      Fluttertoast.showToast(
        msg: ('Insufficient receive coin balance').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final int receiveCoins = calculateReceiveCoinsByAmount(exchangeAmount.text);

    if (receiveCoins <= 0) {
      Fluttertoast.showToast(
        msg: ('Exchange amount is too low').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final data = {
      'amount': amount,
    };

    try {
      exchangeLoading.value = true;

      final response = await dio.post(
        kExchangeCoinUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        exchangeCoinData.value = response.data;

        exchangeAmount.clear();
        previewReceiveCoins.value = 0;

        await exchangeHistory();

        Get.back();

        Get.to(
              () => ExchangeSuccessPage(
            exchangedAmount: amount,
            receivedCoins: receiveCoins,
            message: response.data['message']?.toString() ??
                'Coin exchange success',
          ),
          transition: Transition.rightToLeftWithFade,
          duration: const Duration(milliseconds: 350),
        );
      } else {
        Fluttertoast.showToast(
          msg: ('Exchange failed').appTr,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on DioException catch (e) {
      print('Exchange submit Dio Error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      print('Exchange submit Error: $e');

      Fluttertoast.showToast(
        msg: ('Something went wrong').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      exchangeLoading.value = false;
    }
  }

  ///------------------ Receive Coin To Dollar API ----------------
  Future<void> exchangeDoler() async {
    try {
      dollarSettingLoading.value = true;

      final response = await dio.get(
        kexchangeDoller,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];

        if (data is Map<String, dynamic>) {
          dollarConversionSetting.value = data;
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          dollarConversionSetting.value = Map<String, dynamic>.from(data.first);
        }

        print('✅ Dollar conversion setting: $dollarConversionSetting');
        print('✅ User earned coins: $userEarnedCoins');
        print('✅ Earned dollar: $earnedDollar');
      }
    } on DioException catch (e) {
      print('Dollar setting Dio Error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ??
            ('Dollar setting load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('Dollar setting Error: $e');

      Fluttertoast.showToast(
        msg: ('Dollar setting load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      dollarSettingLoading.value = false;
    }
  }


  //my level List \
// ======================= MY LEVEL =======================

  final RxBool myLevelLoading = false.obs;
  final RxList<dynamic> mylevellist = <dynamic>[].obs;

  int _toLevelInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _toLevelString(dynamic value) {
    return value?.toString() ?? '';
  }

  /// User coin দিয়ে level progress হবে
  /// coins না পেলে earnedCoins use করবে
  int get myLevelCoins {
    final user = authController.userProfile.value.user;

    final coins = _toLevelInt(user?.coins);
    final earnedCoins = _toLevelInt(user?.earnedCoins);

    if (coins > 0) return coins;
    return earnedCoins;
  }

  /// API থেকে আসা level list coins অনুযায়ী ascending sort
  List<Map<String, dynamic>> get sortedLevelList {
    final list = mylevellist
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    list.sort((a, b) {
      final ac = _toLevelInt(a['coins']);
      final bc = _toLevelInt(b['coins']);

      if (ac == 0 && bc == 0) return 0;
      if (ac == 0) return 1;
      if (bc == 0) return -1;

      return ac.compareTo(bc);
    });

    return list;
  }

  /// Current level detect
  Map<String, dynamic>? get currentLevelData {
    final levels = sortedLevelList;
    if (levels.isEmpty) return null;

    final userCoins = myLevelCoins;

    Map<String, dynamic>? current;

    for (final level in levels) {
      final needCoins = _toLevelInt(level['coins']);

      if (needCoins > 0 && userCoins >= needCoins) {
        current = level;
      }
    }

    return current ?? levels.first;
  }

  /// Next level detect
  Map<String, dynamic>? get nextLevelData {
    final levels = sortedLevelList;
    if (levels.isEmpty) return null;

    final userCoins = myLevelCoins;

    for (final level in levels) {
      final needCoins = _toLevelInt(level['coins']);

      if (needCoins > 0 && userCoins < needCoins) {
        return level;
      }
    }

    return null;
  }

  int get currentLevelStart {
    return _toLevelInt(currentLevelData?['start']);
  }

  int get currentLevelEnd {
    return _toLevelInt(currentLevelData?['end']);
  }

  int get currentLevelNeedCoins {
    return _toLevelInt(currentLevelData?['coins']);
  }

  int get nextLevelNeedCoins {
    return _toLevelInt(nextLevelData?['coins']);
  }

  double get myLevelProgress {
    final userCoins = myLevelCoins;

    final nextNeed = nextLevelNeedCoins;
    final currentNeed = currentLevelNeedCoins;

    if (nextNeed <= 0) return 1.0;

    if (currentNeed <= 0 || currentLevelData == sortedLevelList.first) {
      return (userCoins / nextNeed).clamp(0.0, 1.0);
    }

    final gap = nextNeed - currentNeed;
    if (gap <= 0) return 1.0;

    return ((userCoins - currentNeed) / gap).clamp(0.0, 1.0);
  }

  int get remainingCoinsForNextLevel {
    final nextNeed = nextLevelNeedCoins;
    if (nextNeed <= 0) return 0;

    final remain = nextNeed - myLevelCoins;
    return remain < 0 ? 0 : remain;
  }

  String formatLevelCoins(dynamic value) {
    final n = _toLevelInt(value);

    if (n >= 1000000000) {
      return '${(n / 1000000000).toStringAsFixed(1)}B';
    }

    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }

    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }

    return n.toString();
  }

  /// Image full url বানাবে
  /// এখানে kBaseUrl না থাকলে তোমার domain বসাও.
  /// Example: https://yourdomain.com/
  String levelImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';

    final p = path.trim();

    if (p.startsWith('http://') || p.startsWith('https://')) {
      return p;
    }

    // তোমার project এ যদি image base url আলাদা থাকে তাহলে এখানে replace করো
    // Example: final base = 'https://linlive.fr/';
    final base = kBaseUrl;

    final cleanBase = base.endsWith('/') ? base : '$base/';
    final cleanPath = p.startsWith('/') ? p.substring(1) : p;

    return '$cleanBase$cleanPath';
  }

  List<String> levelItems(Map<String, dynamic>? level) {
    final items = level?['items'];

    if (items is List) {
      return items.map((e) => e.toString()).toList();
    }

    return [];
  }

  Future<void> myLevelList() async {
    try {
      myLevelLoading.value = true;

      final response = await dio.get(
        kmylevel,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];

        if (data is List) {
          mylevellist.value = data;
        } else {
          mylevellist.clear();
        }

        print('✅ My Level List Count: ${mylevellist.length}');
        print('✅ My Coins: $myLevelCoins');
        print('✅ Current Level: $currentLevelStart - $currentLevelEnd');
        print('✅ Next Need Coins: $nextLevelNeedCoins');
        print('✅ Progress: $myLevelProgress');
      }
    } on DioException catch (e) {
      print('My level Dio Error: ${e.response?.data}');

      Fluttertoast.showToast(
        msg: e.response?.data?['message']?.toString() ?? ('Level load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print('My level Error: $e');

      Fluttertoast.showToast(
        msg: ('Level load failed').appTr,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      myLevelLoading.value = false;
    }
  }

}