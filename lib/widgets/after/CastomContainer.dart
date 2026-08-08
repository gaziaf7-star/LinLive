import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/image_helper.dart';
import '../../constants/layout_constant.dart';


class CastomCardtopbar_container extends StatelessWidget {
  final Color fastColor;
  final Color secondColor;
  final String? bgImage;
  final double width;
  final String text;
  const CastomCardtopbar_container({
    super.key,
    this.fastColor = const Color(0xffe3b6ef),
    this.secondColor = const Color(0xfffeedf3),
    required this.text,
    required this.width,
    this.bgImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: Get.height * 0.074,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image:
              DecorationImage(image: AssetImage(bgImage!), fit: BoxFit.cover)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              left: Get.width * 0.054,
              top: 8,
              child: CastomCardProfileImage(
                image:
                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTQ2H6eiz3V2Wnvf73iXTwcgL-vXEvkiwq5TkHorokBLB8q5GusNzd1Y5I&s',
              )),
          Positioned(
              left: Get.width * 0.18,
              top: 8,
              child: CastomCardProfileImage(
                image:
                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTDZTE4mv51-NjfnYRK3IW7Hj--6Wdry0g2iQ&s',
              )),
          Positioned(
              left: Get.width * 0.12,
              top: 2,
              child: CastomCardProfileImage(
                image:
                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRMxhkQE0I56iAAxLQGO8p2QLS-COG7yI2GMQ&s',
              )),
          Positioned(
            top: Get.height * 0.05,
            left: width,
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: CupertinoColors.white,
                fontSize: kHeight * 0.011,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CastomCardProfileImage extends StatelessWidget {
  final String image;
  final VoidCallback? onPressed;
  final DecorationImage? frame;
  const CastomCardProfileImage({
    super.key,
    required this.image,
    this.frame,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: kHeight * 0.05,
            width: kHeight * 0.05,
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              image: frame,
            ),
          ),
          Container(
            height: kHeight * 0.033,
            width: kHeight * 0.033,
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: NetworkImage(ImageHelper.getImageUrl(image)),
                  fit: BoxFit.cover),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
