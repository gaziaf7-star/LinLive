import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/constants.dart';
import '../../../../../constants/image_helper.dart';
import '../../../../../constants/layout_constant.dart';

class FollowLevelFrame extends StatelessWidget {
  final String level;

  /// বাইরে থেকে অন্য level image দিতে চাইলে এটা pass করবেন
  /// Example:
  /// LevelFrame(level: '12', levelImage: user.levelImage)a
  ///
  /// Pass না করলে authController এর levelImage নিবে
  final String? levelImage;

  const FollowLevelFrame({
    super.key,
    required this.level,
    this.levelImage,
  });

  @override
  Widget build(BuildContext context) {
    final String? selectedLevelImage =
    levelImage != null && levelImage!.trim().isNotEmpty
        ? levelImage!.trim()
        : authController.userProfile.value.user?.levelImage;

    return SizedBox(
      height: kHeight * 0.019,
      width: kHeight * 0.040,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _buildLevelBackground(selectedLevelImage),

          Positioned(
            right: kHeight * 0.001,
            child: Text(
              level,
              style: GoogleFonts.roboto(
                fontSize: kHeight * 0.0105,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black45,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBackground(String? image) {
    if (image == null || image.trim().isEmpty) {
      return SizedBox.expand(
        child: SVGAEasyPlayer(
          assetsName: 'assets/svga/Level/level_0_to_9_bg.svga',
          fit: BoxFit.cover,
        ),
      );
    }

    final String cleanImage = image.trim();

    if (cleanImage.startsWith('assets/')) {
      if (cleanImage.toLowerCase().endsWith('.svga')) {
        return SizedBox.expand(
          child: SVGAEasyPlayer(
            assetsName: cleanImage,
            fit: BoxFit.cover,
          ),
        );
      }

      return SizedBox.expand(
        child: Image.asset(
          cleanImage,
          fit: BoxFit.cover,
        ),
      );
    }

    final String imageUrl = cleanImage.startsWith('http')
        ? cleanImage
        : ImageHelper.getImageUrl(cleanImage);

    if (imageUrl.toLowerCase().endsWith('.svga')) {
      return SizedBox.expand(
        child: SVGAEasyPlayer(
          resUrl: imageUrl,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox.expand(
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox.expand(
            child: SVGAEasyPlayer(
              assetsName: 'assets/svga/Level/level_0_to_9_bg.svga',
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}