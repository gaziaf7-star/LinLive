import 'package:flutter/material.dart';

const Color kAppColor1 = Color(0xFFAC0422);
const Color kAppColor2 = Color(0xFFF81889);
const Color kAppbarColor = Color(0xFFF82897);

Widget gradientGlowImage({
  required String image,
  double? height,
  double? width,
  BoxFit fit = BoxFit.contain,
}) {
  return Image.asset(
    image,
    height: height,
    width: width,
    fit: fit,
  );
}