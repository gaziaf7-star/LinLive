import 'package:flutter/material.dart';

class ButtonWithIcon extends StatelessWidget {
  final double height;
  final double width;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final IconData icone;

  final Color textColor;
  final String buttonText;
  final VoidCallback onPressed;
  final double? fontSize;

  const ButtonWithIcon(
      {super.key,
        required this.height,
        required this.width,
        required this.backgroundColor,
        required this.borderColor,
        required this.textColor,
        required this.buttonText,
        required this.onPressed,
        this.fontSize,
        required this.iconColor,
        required this.icone});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: backgroundColor, // Customize text color here
          padding: EdgeInsets.zero, // Remove default padding
          side: BorderSide(
              color: borderColor,
              width: 2.0), // Customize border color and width
        ),
        onPressed: onPressed,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Icon(
                icone,
                color: iconColor,
              ),
              Text(
                buttonText,
                style: TextStyle(
                  fontSize: fontSize ?? 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
