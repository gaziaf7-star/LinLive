import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AuthView extends GetView<AuthController> {
  const AuthView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(('AuthView').appTr),
        centerTitle: true,
      ),
      body:  Center(
        child: Text(
          ('AuthView is working').appTr,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
