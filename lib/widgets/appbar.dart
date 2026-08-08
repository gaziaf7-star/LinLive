import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/modules/auth/controllers/auth_controller.dart';
import '../constants/color_constants.dart';
import 'big_text_widgets.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onDrawerPressed;
  final Color backgroundColor;
  final Color titleColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onDrawerPressed,
    this.backgroundColor = Colors.blue,
    this.titleColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    AuthController authController = Get.find();
    return AppBar(
      title: LargeTextStyle(
        color: Colors.white,
        text: title,
        fontSize: 28,
      ),
      backgroundColor: kPrimaryColor,
      elevation: 4.0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
