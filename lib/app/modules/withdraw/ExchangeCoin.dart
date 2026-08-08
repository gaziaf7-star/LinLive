import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class ExchangeTextField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String)? onChanged;

  const ExchangeTextField({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: ('Enter receive coin amount').appTr,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.grey,
        ),
        prefixIcon: const Icon(
          Icons.savings_rounded,
          color: Color(0xff7C45BC),
        ),
        filled: true,
        fillColor: const Color(0xfff7f4ff),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffeadfff)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xff7C45BC),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}