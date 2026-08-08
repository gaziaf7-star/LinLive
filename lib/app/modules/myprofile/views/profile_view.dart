import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ProfileView extends GetView {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:  Text(('ProfileView').appTr),
        centerTitle: true,
      ),
      body:  Center(
        child: Text(
          ('ProfileView is working').appTr,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
