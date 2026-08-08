import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';

class CoinshopController extends GetxController {
  final isLoading = false.obs;
  final _dio = Dio();

  final vipList = [].obs;
  Future getVipList() async {
    isLoading.value = true;
    final data = await _dio.get(kVipListUrl);
    isLoading.value = false;
    vipList.value = data.data['data'];
    isLoading.value = false;
  }

  final coinShopList = [].obs;
  Future coinStoreList() async {
    isLoading.value = true;

    final data = await _dio.get(kCoinShopList);

    isLoading.value = false;

    coinShopList.value = data.data['data'];

    isLoading.value = false;
  }
}
