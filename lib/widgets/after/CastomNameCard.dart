import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class castom_game_card extends StatelessWidget {
  final String image;
  final String text;
  final VoidCallback? onPress;
  const castom_game_card({
    super.key,
    required this.image,
    required this.text,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPress,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Color(0xffe87a0b), width: 2)),
            width: 100,
            height: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image(
                image: AssetImage(image),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            text,
            style: GoogleFonts.lato(
                fontSize: 15,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600),
          )
        ],
      ),
    );
  }
}
