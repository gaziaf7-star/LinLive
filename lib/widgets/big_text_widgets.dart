import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class LargeTextStyle extends StatelessWidget {
  final Color color;
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;

  const LargeTextStyle({
    super.key,
    required this.color,
    required this.text,
    required this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.lato(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
      ),
    );
  }
}
