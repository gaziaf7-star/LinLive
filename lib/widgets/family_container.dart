import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class familyContainer_1 extends StatelessWidget {
  final Color bordercolor;
  final String fastassetimage;
  final String secondassetimage;
  final String lastassetimage;
  final String text;
  final Color textcolor;
  familyContainer_1({
    required this.bordercolor,
    required this.text,
    required this.textcolor,
    required this.fastassetimage,
    required this.secondassetimage,
    required this.lastassetimage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: bordercolor,
        ),
        color: Color(0x7f69f5c4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 10,
          ),
          InkWell(
            onTap: () {},
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image(
                image: AssetImage(fastassetimage),
                height: 35,
              ),
            ),
          ),
          const SizedBox(
            width: 2,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 2,
              ),
              Text(
                text,
                style: GoogleFonts.philosopher(
                  fontSize: 14,
                  color: textcolor,
                  fontWeight: FontWeight.w300,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image(
                        image: AssetImage(secondassetimage),
                        height: 25,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image(
                        image: AssetImage(lastassetimage),
                        height: 25,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
