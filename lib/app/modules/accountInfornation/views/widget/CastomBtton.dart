import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';

import '../../../../../constants/layout_constant.dart';

class CastomAppButton extends StatelessWidget {
  final String? buttonText;
  final VoidCallback? onPressed;
  final Color? fastColor;
  final Color? secondColor;
  final Widget? child; // 👉 নতুন যোগ করা হলো

  const CastomAppButton({
    super.key,
    this.buttonText,
    this.onPressed,
    this.fastColor,
    this.secondColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kWeight * 0.7,
      height: kHeight * 0.055,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                fastColor ?? kAppColor2,
                secondColor ?? kAppColor1,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Container(
            alignment: Alignment.center,
            child: child ??
                Text(
                  buttonText ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: kHeight * 0.018,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
