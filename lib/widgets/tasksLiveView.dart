import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


import '../constants/color_constants.dart';
import '../constants/layout_constant.dart';
import 'after/CastomText.dart';

class TaskLiveProfile extends StatelessWidget {
  final String text;
  final String seccondtext;
  const TaskLiveProfile({
    super.key,
    required this.text,
    required this.seccondtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 8),
        padding: EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(colors: [
            Color(0xff0c0c0c).withOpacity(.4),
            Color(0xff0c0c0c).withOpacity(.4),
          ])
        ),
        child: Row(
          children: [
            Castontext(
                fontSize: kHeight * 0.012,
                fontWeight: FontWeight.w500,
                textColor: Colors.white.withOpacity(.8),
                text: seccondtext),
            Padding(
              padding: const EdgeInsets.only(left: 2.0, right: 2.0),
              child: Text(
                text,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: kHeight * 0.014,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ));
  }
}
