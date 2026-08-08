import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomOutlinedButton extends StatelessWidget {
  final String text;
  final double? width;
  final VoidCallback onPressed;
  const CustomOutlinedButton({
    super.key,
    required this.text,
    this.width,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? Get.width * 0.8,
      child: ElevatedButton(
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.black.withOpacity(0.4))),
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                  color: Colors.purple.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 15),
            ),
          )),
    );
  }
}
