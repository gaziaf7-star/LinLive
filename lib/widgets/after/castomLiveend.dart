import 'package:flutter/material.dart';

import '../../constants/layout_constant.dart';
import 'CastomText.dart';

class CastomLivecatagory extends StatelessWidget {
  final String text;
  final String text1;
  final String image;
  const CastomLivecatagory({
    super.key,
    required this.text,
    required this.text1,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: kWeight * 0.03),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Icon Container with gradient circle
          Container(
            padding: EdgeInsets.all(kWeight * 0.015),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xff8A4CF7),
                  Color(0xffB460F0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              image,
              height: kHeight * 0.025,
              color: Colors.white,
            ),
          ),
          SizedBox(width: kWeight * 0.025),
          // Texts
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Castontext(
                textColor: Colors.white,
                text: text,
              ),
              SizedBox(height: 2),
              Castontext(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                textColor: Color(0xfffdfdfd),
                text: text1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
