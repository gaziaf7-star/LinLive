import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/color_constants.dart';
import '../../constants/layout_constant.dart';

class CustomTextFormField extends StatefulWidget {
  final String text;
  final TextEditingController? controller;
  final IconData? prefix;
  final Color? fillColor;
  final double? height;
  final double? width;
  final bool? obscureText;
  final FocusNode? focusNode;
  final Function(String)? onChanged;
  final String? errorText;

  const CustomTextFormField({
    super.key,
    required this.text,
    this.prefix,
    this.fillColor,
    this.height,
    this.width,
    this.obscureText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.errorText,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  late bool _obscure; // 👈 password hide/show control

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? Get.width * 0.85,
      child: TextFormField(
        textAlign: TextAlign.start,
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: kHeight * 0.016,
          color: Colors.white,
        ),
        obscureText: _obscure,
        cursorColor: const Color(0xfffcfbfd),
        decoration: InputDecoration(
          alignLabelWithHint: true,
          errorMaxLines: 2,
          errorStyle: GoogleFonts.lato(
            color: Colors.red,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          prefixIcon: Icon(
            widget.prefix,
            size: kHeight * 0.021,
            color: const Color(0xff6446fa),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: kHeight * 0.014,
            horizontal: 1,
          ),
          hintText: widget.text,
          suffixIcon: widget.obscureText == true
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      _obscure = !_obscure; // 👈 toggle password
                    });
                  },
                  icon: Icon(
                    _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                    color: Colors.black,
                    size: kHeight * 0.021,
                  ),
                )
              : null,
          hintStyle: GoogleFonts.lato(
            fontWeight: FontWeight.w500,
            fontSize: kHeight * 0.017,
            color: Colors.white,
          ),
          fillColor: widget.fillColor ?? Colors.grey.withOpacity(0.5),
          filled: true,
          errorText: widget.errorText,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: .8),
            borderRadius: BorderRadius.circular(15),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: .8),
            borderRadius: BorderRadius.circular(15),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white, width: .8),
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}
