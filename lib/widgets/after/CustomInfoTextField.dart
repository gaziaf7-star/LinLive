import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/layout_constant.dart';

class CustomInfoTextField extends StatelessWidget {
  final String text;
  final controller;
  final bool readOnly;
  const CustomInfoTextField({
    super.key,
    required this.text,
    this.controller,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        cursorColor: readOnly ? Colors.transparent : Colors.black,
        style: GoogleFonts.lato(
            color: readOnly ? Colors.grey.shade600 : Colors.black,
            fontSize: kHeight * 0.016,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintStyle:
              GoogleFonts.lato(color: Colors.grey, fontWeight: FontWeight.w600),
          contentPadding: EdgeInsets.symmetric(
              horizontal: kHeight * 0.012, vertical: kHeight * 0.014),
          hintText: text,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          filled: true,
          border: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        ),
      ),
    );
  }
}
