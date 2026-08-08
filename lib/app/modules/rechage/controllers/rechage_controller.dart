import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RechageController extends GetxController {
  final dio = Dio();
  final isLoading = false.obs;
  final rechargeOffer = [].obs;

  Future getPopularList() async {
    isLoading.value = true;
    final data = await dio.get(kRechargeList);
    rechargeOffer.value = data.data['data'];
    isLoading.value = false;
  }

  ///--------------------------Reseller list show ----------------------------

  final resellerListData = [].obs;

  Future showResellerList() async {
    final data = await dio.get(kReselerList);
    resellerListData.value = data.data['Reseller'];
  }

  ///-------------------- recharge offer
  final rechargeOfferList = [].obs;

  Future showRechargeOffer() async {
    try {
      final response = await dio.get(kRechargeList);

      if (response.statusCode == 200 && response.data['data'] != null) {
        rechargeOfferList.value = response.data['data'];
        print('recharge Offer $rechargeOfferList');
      } else {
        Fluttertoast.showToast(
          msg: ("No data found!").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioError catch (e) {
      // Dio specific error
      Fluttertoast.showToast(
        msg: e.response?.data['message'] ?? ("Network error! Try again.").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      // Other errors
      Fluttertoast.showToast(
        msg: ("Something went wrong!").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
}
