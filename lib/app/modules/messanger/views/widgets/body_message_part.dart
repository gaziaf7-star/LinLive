import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'friend_message.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class body_message_part extends StatelessWidget {
  const body_message_part({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 10,
        ),
        Center(
          child: Text(
            ('1 FEB 2024 AT 12:30 AM').appTr,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10),
          ),
        ),
        SizedBox(
          height: 10,
        ),
        friend_message(),
        SizedBox(
          height: 10,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(.2),
            ),
            child: Text(
              ('my name is alamin , \nMy father nam is abul gazi ').appTr,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}
