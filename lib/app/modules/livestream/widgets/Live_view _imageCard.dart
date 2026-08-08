import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveViewsecond_Image extends StatelessWidget {
  final String image;
  const LiveViewsecond_Image({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: kHeight * 0.007, horizontal: kWeight * 0.01),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.black.withOpacity(0.3)),
      child: Column(
        children: [
          Image(
            image: AssetImage(image),
            height: kHeight * 0.025,
          ),
          Text(
            ('Join Call').appTr,
            style: GoogleFonts.lato(
                color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
