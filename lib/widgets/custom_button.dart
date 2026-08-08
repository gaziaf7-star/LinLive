import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StylishButton extends StatelessWidget {
  final double height;
  final double width;

  final Color borderColor;
  final Color textColor;

  final String buttonText;
  final VoidCallback? onPressed;

  final double? fontSize;
  final bool isLoading;

  // Gradient Colors
  final List<Color> gradientColors;

  const StylishButton({
    super.key,
    required this.height,
    required this.width,
    required this.borderColor,
    required this.textColor,
    required this.buttonText,
    required this.onPressed,
    required this.gradientColors,
    this.fontSize,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),

            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            border: Border.all(
              color: borderColor,
              width: 1,
            ),

            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.4),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Text(
              buttonText,
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: fontSize ?? 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}