import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CastomUserProfiledevider extends StatelessWidget {
  const CastomUserProfiledevider({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Divider(
        color: Color(0xfff3f3f5),
      ),
    );
  }
}

class CastomUserProfileotherOption extends StatelessWidget {
  final String text;
  const CastomUserProfileotherOption({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      decoration: BoxDecoration(),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            color: Colors.black, fontSize: 20, fontWeight: FontWeight.w300),
      ),
    );
  }
}
