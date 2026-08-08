import 'package:flutter/material.dart';

import 'CastomText.dart';

class CastomLiveButton extends StatelessWidget {
  final String text;
  final Gradient gradian; // Fully customizable gradient
  final VoidCallback? onPressed;

  const CastomLiveButton({
    super.key,
    required this.text,
    required this.gradian,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradian, // custom gradient here
          borderRadius: BorderRadius.circular(50),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          child: Center(
            child: Castontext(
              fontWeight: FontWeight.w600,
              textColor: Colors.white,
              text: text,
            ),
          ),
        ),
      ),
    );
  }
}
