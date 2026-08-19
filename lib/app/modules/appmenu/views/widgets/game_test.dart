import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/constants.dart';
import '../../../../../constants/image_helper.dart';
import '../../../../../constants/layout_constant.dart';

class LevelFrame extends StatelessWidget {
  final String level;

  /// বাইরে থেকে অন্য level image দিতে চাইলে এটা pass করবেন
  /// Example:
  /// LevelFrame(level: '12', levelImage: user.levelImage)
  ///
  /// Pass না করলে, ar useCurrentUserFallback true thakle (default),
  /// authController এর levelImage নিবে — এটা শুধুমাত্র "নিজের" profile/self
  /// display context-এর জন্য ঠিক (jekhane level ta always logged-in user er-i).
  final String? levelImage;

  /// ✅ FIX: lists that render OTHER people's rows (viewer list, seat grid,
  /// etc.) must pass `useCurrentUserFallback: false`. Otherwise, whenever a
  /// particular row has no level_image of its own (very common — most users
  /// are level 0 with no custom image), this widget silently fell back to
  /// the CURRENTLY LOGGED-IN user's own level image — so every such row
  /// showed the viewing user's own badge instead of a neutral default,
  /// making it look like "everyone shows the same [my] image".
  /// Defaults to true so any existing self-display call site keeps working
  /// unchanged.
  final bool useCurrentUserFallback;

  const LevelFrame({
    super.key,
    required this.level,
    this.levelImage,
    this.useCurrentUserFallback = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasExplicitImage =
        levelImage != null && levelImage!.trim().isNotEmpty;
    final String? selectedLevelImage = hasExplicitImage
        ? levelImage!.trim()
        : (useCurrentUserFallback
        ? authController.userProfile.value.user?.levelImage
        : null);

    return SizedBox(
      height: kHeight * 0.027,
      width: kHeight * 0.047,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _buildLevelBackground(selectedLevelImage),

          Positioned(
            right: -kHeight * 0.006,
            child: Text(
              level,
              style: GoogleFonts.roboto(
                fontSize: kHeight * 0.015,
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
    // ✅ FIX ("level image showing the same for everyone" in lists like
    // the All Viewer List bottom sheet): SVGAEasyPlayer/Image.network are
    // stateful widgets that load/cache their content in State. Without a
    // key tied to the actual image being shown, Flutter's default
    // ListView.builder reconciliation can reuse the Element (and its
    // already-loaded State) at a given list position for a *different*
    // row's data, so the visual can lag behind or repeat a previous row's
    // image. Keying every branch by the resolved path/asset forces a fresh
    // widget identity — and therefore a fresh load — whenever the actual
    // image differs, regardless of where it sits in a list.
    if (image == null || image.trim().isEmpty) {
      return SVGAEasyPlayer(
        key: const ValueKey<String>('level_bg_default'),
        assetsName: 'assets/svga/Level/level_0_to_9_bg.svga',
        fit: BoxFit.cover,
      );
    }

    final String cleanImage = image.trim();

    if (cleanImage.startsWith('assets/')) {
      if (cleanImage.toLowerCase().endsWith('.svga')) {
        return SVGAEasyPlayer(
          key: ValueKey<String>('level_bg_asset_$cleanImage'),
          assetsName: cleanImage,
          fit: BoxFit.cover,
        );
      }

      return Image.asset(
        cleanImage,
        key: ValueKey<String>('level_bg_asset_img_$cleanImage'),
        fit: BoxFit.cover,
      );
    }

    final String imageUrl = cleanImage.startsWith('http')
        ? cleanImage
        : ImageHelper.getImageUrl(cleanImage);

    if (imageUrl.toLowerCase().endsWith('.svga')) {
      return SizedBox(
        height: kHeight * 0.12,
        width: kHeight * 0.12,
        child: SVGAEasyPlayer(
          key: ValueKey<String>('level_bg_net_$imageUrl'),
          resUrl: imageUrl,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      height: kHeight * 0.12,
      width: kHeight * 0.12,
      child: Image.network(
        imageUrl,
        key: ValueKey<String>('level_bg_net_img_$imageUrl'),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return SVGAEasyPlayer(
            key: const ValueKey<String>('level_bg_default_fallback'),
            assetsName: 'assets/svga/Level/level_0_to_9_bg.svga',
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}