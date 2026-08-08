import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart' hide Response;
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../bottomnav/views/bottomnav_view.dart';

class AccountInfornationController extends GetxController {
  final Dio dio = Dio();

  final List<String> nationalIdentity = <String>[
    'Nagad Payment',
    'Bkash Payment',
  ];

  final RxList<int> selectedProfileIndices = <int>[].obs;

  void toggleProfileSelection(int index) {
    if (selectedProfileIndices.contains(index)) {
      selectedProfileIndices.remove(index);
    } else {
      selectedProfileIndices.add(index);
    }
  }

  /// Legacy/manual recharge package list.
  ///
  /// The Google Play CoinTopUp page does not use this method. It loads secure
  /// Play products from GET /google-play/products and displays Google Play's
  /// localized ProductDetails.price.
  final RxList<dynamic> coinTopUpListData = <dynamic>[].obs;
  final RxInt selectIndex = 0.obs;
  final RxString selectId = ''.obs;

  Future<void> showCoinTopUpList() async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        kTopUpCoinList,
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Authorization':
            'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      final dynamic responseData = response.data;
      if (responseData is Map) {
        final dynamic rows = responseData['data'];
        coinTopUpListData.assignAll(
          rows is List ? rows : const <dynamic>[],
        );
      } else {
        coinTopUpListData.clear();
      }
    } on DioException catch (error) {
      coinTopUpListData.clear();
      debugPrint(
        'showCoinTopUpList failed: '
            '${error.response?.statusCode} ${error.response?.data}',
      );
      rethrow;
    } catch (error) {
      coinTopUpListData.clear();
      debugPrint('showCoinTopUpList failed: $error');
      rethrow;
    }
  }

  /// Legacy/manual recharge request.
  ///
  /// Do not call this method from the Google Play Store recharge page for
  /// digital coin purchases. Google Play purchases must go through
  /// GooglePlayRechargeService and POST /google-play/verify.
  final RxBool isLoading = false.obs;
  final RxString selectMethod = ''.obs;
  final RxMap<String, dynamic> coinTopUpData =
      <String, dynamic>{}.obs;

  Future<void> coinTopUpPost() async {
    if (selectId.value.trim().isEmpty) {
      _showToast(
        ('Please select a coin package.').appTr,
        Colors.red,
      );
      return;
    }

    if (selectMethod.value.trim().isEmpty) {
      _showToast(
        ('Please select a payment method.').appTr,
        Colors.red,
      );
      return;
    }

    final Map<String, dynamic> requestData = <String, dynamic>{
      'coins_store_id': selectId.value.trim(),
      'tnx_method': selectMethod.value.trim(),
    };

    try {
      isLoading.value = true;

      // Never print the user's bearer token or payment payload in production.
      final Response<dynamic> response = await dio.post<dynamic>(
        kTopUpCoinPost,
        data: requestData,
        options: Options(
          headers: <String, dynamic>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization':
            'Bearer ${authController.userProfile.value.token}',
          },
          validateStatus: (int? status) =>
          status != null && status < 500,
        ),
      );

      final Map<String, dynamic> body = _asMap(response.data);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] != false) {
        coinTopUpData.assignAll(body);

        _showToast(
          _message(body, ('Coin top-up successful.').appTr),
          Colors.green,
        );

        Get.offAll(
              () => BottomnavView(),
          transition: Transition.rightToLeft,
        );
        return;
      }

      _showToast(
        _message(
          body,
          ('Unable to complete the recharge request.').appTr,
        ),
        Colors.red,
      );
    } on DioException catch (error) {
      _showToast(
        _message(
          _asMap(error.response?.data),
          ('Something went wrong.').appTr,
        ),
        Colors.red,
      );
    } catch (error) {
      debugPrint('coinTopUpPost failed: $error');
      _showToast(
        ('Something went wrong.').appTr,
        Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _message(
      Map<String, dynamic> body,
      String fallback,
      ) {
    final dynamic value =
        body['message'] ?? body['error'] ?? body['errors'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }

    if (value is Map && value.isNotEmpty) {
      final dynamic first = value.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
      return first.toString();
    }

    return fallback;
  }

  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 16,
    );
  }
}
