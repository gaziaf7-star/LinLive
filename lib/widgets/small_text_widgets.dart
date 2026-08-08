import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class SmallTextStyle extends StatelessWidget {
  final Color color;
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final TextAlign textAlign; // 👈 custom align চাইলে

  const SmallTextStyle({
    super.key,
    required this.color,
    required this.text,
    required this.fontSize,
    this.fontWeight,
    this.textAlign = TextAlign.center, // default center
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text, // ✅ প্রথমে text pass করতে হবে
      textAlign: textAlign, // ✅ এখানে alignment দাও
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color,
      ),
    );
  }
}
