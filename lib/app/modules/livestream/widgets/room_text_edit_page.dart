import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class RoomTextEditPage extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hint;
  final String helperText;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final bool obscureText;

  const RoomTextEditPage({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.helperText,
    this.maxLength = 100,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscureText = false,
  });

  @override
  State<RoomTextEditPage> createState() => _RoomTextEditPageState();
}

class _RoomTextEditPageState extends State<RoomTextEditPage> {
  late final TextEditingController _controller;
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _obscure = widget.obscureText;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Get.back(result: _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bool multiLine = widget.maxLines > 1;

    return Scaffold(
      backgroundColor: const Color(0xfffafafa),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff202020),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.roboto(
            color: const Color(0xff171717),
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              ('Save').appTr,
              style: GoogleFonts.roboto(
                color: const Color(0xff171717),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 28, 18, 28),
            child: Row(
              crossAxisAlignment:
              multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: widget.obscureText ? 1 : widget.minLines,
                    maxLines: widget.obscureText ? 1 : widget.maxLines,
                    maxLength: widget.maxLength,
                    obscureText: _obscure,
                    textInputAction:
                    multiLine ? TextInputAction.newline : TextInputAction.done,
                    onSubmitted: multiLine ? null : (_) => _save(),
                    style: GoogleFonts.roboto(
                      color: const Color(0xff4b4b4b),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: GoogleFonts.roboto(
                        color: const Color(0xff8a8a8a),
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (widget.obscureText) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xffc9c9c9),
                      size: 22,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _controller.clear(),
                  child: Container(
                    height: 24,
                    width: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xfff1f1f1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xffcccccc),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
            child: Text(
              widget.helperText,
              style: GoogleFonts.roboto(
                color: const Color(0xffcecece),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
