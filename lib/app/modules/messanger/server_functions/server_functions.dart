import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../auth/controllers/auth_controller.dart';

Future<String> getAgoraServerToken(
    {required String channelName, required int uid}) async {
  var dio = Dio();
  try {
    // Response response = await dio.get(url);
    Response response = await dio.get(
      "kAgoraRtcTokenRetrieveUrl(channelName: channelName, uid: uid, role: 1,)",
    );
    return response.data['rtcToken'];
  } catch (e) {
    return '';
  }
}

//game

Future<String> getGame(
    {required String token, required String package_id}) async {
  var dio = Dio();
  try {
    // Response response = await dio.get(url);
    Response response = await dio.get(
      ' kGame(token: token, package_id: package_id, )',
    );
    return response.data['rtcToken'];
  } catch (e) {
    return '';
  }
}

void registerFCMDevice({required String fcmDeviceToken}) async {
  final AuthController authController = Get.find();

  var dio = Dio();
  Response response;
  var formData = FormData.fromMap({
    'token': fcmDeviceToken,
  });
  response = await dio.post(
    'kFCMDeviceCreateUrl',
    data: formData,
    options: Options(headers: {
      'accept': '*/*',
      'Authorization': 'Token ${authController.userProfile.value.token}',
    }),
  );
}

Future<String?> getFCMDeviceToken() async {
  return await FirebaseMessaging.instance.getToken();
}

void onFCMDeviceTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((fcmDeviceToken) {
    updateFCMDeviceToken(fcmDeviceToken: fcmDeviceToken);
  }).onError((err) {});
}

void updateFCMDeviceToken({required String fcmDeviceToken}) async {
  final AuthController authController = Get.find();

  var dio = Dio();
  Response response;
  var formData = FormData.fromMap({
    'token': fcmDeviceToken,
  });
  response = await dio.put(
    'kFCMUserTokenUpdateUrl',
    data: formData,
    options: Options(headers: {
      'accept': '*/*',
      'Authorization': 'Token ${authController.userProfile.value.token}',
    }),
  );
  // print("Bego(updateFCMDeviceToken) ${response.data}");
}

void updateFCMPeerDevice({required int peerUid}) async {
  final AuthController authController = Get.find();

  var dio = Dio();
  Response response;
  var formData = FormData.fromMap({
    'peer_user_id': peerUid,
  });
  response = await dio.put(
    'kFCMPeerDeviceUpdateUrl',
    data: formData,
    options: Options(headers: {
      'accept': '*/*',
      'Authorization': 'Token ${authController.userProfile.value.token}',
    }),
  );
  // print("Bego(updatePeerDevice) ${response.data}");
}

void notifyUser(
    {required String title,
    required String body,
    required int receiverUid}) async {
  final AuthController authController = Get.find();

  var dio = Dio();
  Response response;
  var formData = FormData.fromMap({
    'title': title,
    'message': body,
    'image': authController.userProfile.value.user!.profileImage!,
    'receiver_uid': receiverUid,
  });
  response = await dio.post(
    'kFCMSinglePushCreate',
    data: formData,
    options: Options(headers: {
      'accept': '*/*',
      'Authorization': 'Token ${authController.userProfile.value.token}',
    }),
  );
  // print("Bego(notifyUser) ${response.data}");
}

void notifyUserWithCall(
    {required String body,
    required int receiverUid,
    required String callType}) async {
  final AuthController authController = Get.find();

  var dio = Dio();
  Response response;
  var formData = FormData.fromMap({
    'title': "",
    'message': body,
    'image': authController.userProfile.value.user!.profileImage!,
    'receiver_uid': receiverUid,
    'call_type': callType,
  });

  response = await dio.post(
    'kFCMSinglePushForCallingCreate',
    data: formData,
    options: Options(headers: {
      'accept': '*/*',
      'Authorization': 'Token ${authController.userProfile.value.token}',
    }),
  );
  print('push');
  print(response.data);
  print(response.statusCode);
  // print("Bego(notifyUserWithCall) ${response.data}");
}
