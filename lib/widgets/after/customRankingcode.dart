import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/layout_constant.dart';

class CastonRankingcard extends StatelessWidget {
  final Color fastColor;
  final Color secondColor;
  final Color bottomColor;

  final String name;
  final String coin;
  final String profileImage;
  final String rankText;

  final DecorationImage? frame;

  /// ✅ Background image path
  final String backgroundImage;

  final double height;
  final double width;
  final double? pwidth;

  final Color? topBorderColor;
  final Color? sideBorderColor;

  const CastonRankingcard({
    super.key,
    required this.fastColor,
    required this.secondColor,
    required this.bottomColor,
    required this.height,
    required this.width,
    required this.rankText,
    required this.name,
    required this.coin,
    required this.profileImage,
    required this.backgroundImage,
    this.frame,
    this.pwidth,
    this.topBorderColor,
    this.sideBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(backgroundImage),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: frame,
                ),
                child: CircleAvatar(
                  radius: kHeight * 0.035,
                  backgroundColor: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: CachedNetworkImage(
                      imageUrl: profileImage,
                      fit: BoxFit.cover,
                      height: kHeight * 0.045,
                      width: kHeight * 0.045,
                      placeholder: (context, url) => const SizedBox(),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: kHeight * 0.016,
                  ),
                ),
              ),

              Text(
                coin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: kHeight * 0.015,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}