import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/modules/appmenu/views/widgets/imageColor.dart';
import '../../constants/layout_constant.dart';

class castomCard extends StatelessWidget {
  final Color bacgroundColor;
  final VoidCallback? onPress;
  final double? height;
  final double? imageWidth;
  final double? textWidth;
  final EdgeInsetsGeometry? imagePadding;
  final EdgeInsetsGeometry? cardPadding;
  final String text;
  final String image;

  const castomCard({
    super.key,
    required this.bacgroundColor,
    required this.text,
    required this.image,
    this.height,
    this.imageWidth,
    this.textWidth,
    this.imagePadding,
    this.cardPadding,
    this.onPress,
  });

  String _limitText(String value, {int maxLetters = 30}) {
    final clean = value.trim();

    if (clean.length <= maxLetters) {
      return clean;
    }

    return '${clean.substring(0, maxLetters)}..';
  }

  @override
  Widget build(BuildContext context) {
    final String showText = _limitText(text);

    return InkWell(
      onTap: onPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: imagePadding ??
                const EdgeInsets.only(
                  left: 0,
                  right: 0,
                ),
            child: gradientGlowImage(
              image: image,
              height: height ?? kHeight * 0.037,
              width: imageWidth,
              fit: BoxFit.cover,
            ),
          ),

          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFFFE6EC),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFD700),
                  Color(0xFFFF4FA3),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFE6EC),
                ],
                stops: [
                  0.0,
                  0.20,
                  0.42,
                  0.55,
                  0.78,
                  1.0,
                ],
              ).createShader(bounds);
            },
            child: SizedBox(
              width: textWidth,
              child: Text(
                showText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: kHeight * 0.02,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}