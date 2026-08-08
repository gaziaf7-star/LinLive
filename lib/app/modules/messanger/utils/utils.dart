// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';
// import 'package:provider/provider.dart';
// import 'package:right_tune/app/firebase_helper/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/instance_manager.dart';

import '../../auth/controllers/auth_controller.dart';
import '../firebase_helper/firebase_helper.dart';
import '../server_functions/server_functions.dart';

// // String Token =
// //     "007eJxTYDinEvC4ryxn8Wxmuz1SBqk+gQum/O8+EXPwwaSNbilfpn5SYDAxNzYzM04zTjEzMDIxTzKzTEmxtDBONTFKMkpMTTI0fHtONDlXQTxZKZORiZEBAkF8Foak1PR8BgYAieIgHw=="; //'<Your Token>'

void cancelCall(
    {required BuildContext context,
    required String msg,
    required dynamic profile}) {
  final AuthController authController = Get.find();
  notifyUser(
      title: profile['full_name'],
      body: '${profile['full_name']} called you',
      receiverUid: authController.userProfile.value.user!.id!.toInt());

  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      fontSize: 16.0);
  // FireBaseHelper().updateCallStatus(context, "");
  FireBaseHelper().updateCallStatus(
      context: context,
      uid: authController.userProfile.value.user!.id!.toInt(),
      isChatWith: "");
}

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> buildShowSnackBar(
    BuildContext context, String msg) {
  return ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      msg,
      style: const TextStyle(fontSize: 16),
    ),
  ));
}

String getChatId({required int uid, required int peeredUserId}) {
  return uid < peeredUserId ? '$uid-$peeredUserId' : '$peeredUserId-$uid';
}
