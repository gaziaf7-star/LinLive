import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../small_text_widgets.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final Color? textColor;
  final Color? backgroundColor;
  final double? height;
  final double? width;
  final VoidCallback? onTap;
  const CustomButton({
    super.key,
    required this.text,
    this.textColor,
    this.backgroundColor,
    this.height,
    this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? Get.height * 0.06,
        decoration: BoxDecoration(
            color: backgroundColor ?? Color(0xffDA5FF8),
            borderRadius: BorderRadius.circular(50)),
        child: Center(
          child: SmallTextStyle(
            color: textColor ?? Colors.white,
            text: text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
