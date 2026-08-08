import 'package:flutter/material.dart';

import '../../../../constants/layout_constant.dart';

class ReusableIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? assetImage;
  final IconData? icon;
  final double? imageHeight;
  final Color backgroundColor;
  final Color? iconColor;
  final double? iconSize;

  const ReusableIconButton({
    super.key,
    required this.onPressed,
    this.assetImage,
    this.icon,
    this.imageHeight,
    required this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: kWeight * 0.02),
      height: kWeight * 0.09,
      width: kWeight * 0.09,
      child: IconButton(
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        icon: assetImage != null
            ? ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Color(0xFFF8ACC9),
                Color(0xFFF40A24),
              ],
            ).createShader(bounds);
          },
          child: Image.asset(
            assetImage!,
            height: imageHeight ?? 20,
            width: imageHeight ?? 20,
            fit: BoxFit.contain,
          ),
        )
            : ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Color(0xFFF8ACC9),
                Color(0xFFF40A24),
              ],
            ).createShader(bounds);
          },
          child: Icon(
            icon ?? Icons.circle,
            size: iconSize ?? 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}