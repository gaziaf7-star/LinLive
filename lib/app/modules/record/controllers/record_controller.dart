import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RecordController extends GetxController {
  final dio = Dio();
  final currentMonthLiveRecord = {}.obs;
  final isLoading = false.obs;

  void getCurrentMonthLiveRecord() async {
    isLoading.value = true;
    try {
      print(kCurrentMonthLiveRecord);
      final response = await dio.get(
        kCurrentMonthLiveRecord,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      isLoading.value = false;
      if (response.statusCode == 200 && response.data != null) {
        currentMonthLiveRecord.value = response.data;
        print('Current Live Data $currentMonthLiveRecord');
      } else {
        isLoading.value = false;
        Fluttertoast.showToast(
          msg: ("No data found!").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioError catch (e) {
      isLoading.value = false;
      // Dio specific error
      Fluttertoast.showToast(
        msg: e.response?.data['message'] ?? ("Network error! Try again.").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      // Other errors
      Fluttertoast.showToast(
        msg: ("Something went wrong!").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  final sessionWiseLiveRecord = {}.obs;

  void getSessionWiseLiveRecord() async {
    isLoading.value = true;
    try {
      final response = await dio.get(
        kSessionWiseLiveRecord,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        sessionWiseLiveRecord.value = response.data;
        print('Current Live Data $sessionWiseLiveRecord');
        isLoading.value = false;
      } else {
        Fluttertoast.showToast(
          msg: ("No data found!").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioError catch (e) {
      isLoading.value = false;
      // Dio specific error
      Fluttertoast.showToast(
        msg: e.response?.data['message'] ?? ("Network error! Try again.").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      // Other errors
      Fluttertoast.showToast(
        msg: ("Something went wrong!").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  final filteredSessionWiseLiveRecord = [].obs;

  void getFilteredSessionWiseLiveRecord() async {
    try {
      // 🗓️ বর্তমান মাসের প্রথম ও শেষ তারিখ বের করা
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // 🧩 তারিখ ফরম্যাট করা (yyyy-MM-dd)
      String formatDate(DateTime date) {
        return "${date.year.toString().padLeft(4, '0')}-"
            "${date.month.toString().padLeft(2, '0')}-"
            "${date.day.toString().padLeft(2, '0')}";
      }

      final data = {
        "start_date": formatDate(firstDayOfMonth),
        "end_date": formatDate(lastDayOfMonth),
      };

      print('📅 Sending Filter Dates: $data');

      final response = await dio.post(
        kDateWiseFilterLiveRecord,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        filteredSessionWiseLiveRecord.value = response.data['data'];
        print('✅ Filter Live Data: $filteredSessionWiseLiveRecord');
      } else {
        Fluttertoast.showToast(
          msg: ("No data found!").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioError catch (e) {
      Fluttertoast.showToast(
        msg: e.response?.data['message'] ?? ("Network error! Try again.").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: ("Something went wrong!").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

//user record
  final rewordData = {}.obs;
  void getLiveReword() async {
    isLoading.value = true;
    try {
      print(kLiveReword);
      final response = await dio.get(
        kLiveReword,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );
      isLoading.value = false;
      if (response.statusCode == 200 && response.data != null) {
        rewordData.value = response.data;
        print('Current Live Data Reword $rewordData');
      } else {
        isLoading.value = false;
        Fluttertoast.showToast(
          msg: ("No data found!").appTr,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } on DioError catch (e) {
      isLoading.value = false;
      // Dio specific error
      Fluttertoast.showToast(
        msg: e.response?.data['message'] ?? ("Network error! Try again.").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      isLoading.value = false;
      // Other errors
      Fluttertoast.showToast(
        msg: ("Something went wrong!").appTr,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  void onInit() {
    getLiveReword();
    getCurrentMonthLiveRecord();
    getSessionWiseLiveRecord();
    getFilteredSessionWiseLiveRecord();

    // TODO: implement onInit
    super.onInit();
  }
}
