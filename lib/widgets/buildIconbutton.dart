import 'package:flutter/material.dart';


import '../constants/color_constants.dart';
import '../constants/layout_constant.dart';

class topIconbutton extends StatelessWidget {
  Icon icon;
  Color colour;
  final VoidCallback? onPressed;

  topIconbutton({
    required this.icon,
    required this.colour,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      iconSize: kHeight * 0.021,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: BorderSide(
              color: kAppColor,
            )),
        backgroundColor: kAppColor,

      ),
      color: colour,
      onPressed: onPressed,
      icon: icon,
    );
  }
}
