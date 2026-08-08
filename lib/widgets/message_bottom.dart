import 'package:flutter/material.dart';

import '../constants/layout_constant.dart';


import 'package:flutter/material.dart';

import '../constants/layout_constant.dart';

class message_bottom extends StatelessWidget {
  final String image;
  final Color color;
  final Color? color2;
  final VoidCallback? onPress;

  const message_bottom({
    super.key,
    required this.image,
    required this.color,
    this.color2,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPress,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color2 ?? color.withOpacity(0.8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: ShaderMask(
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
          blendMode: BlendMode.srcIn,
          child: Image.asset(
            image,
            height: kHeight * 0.025,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.apps_rounded,
                color: Colors.white,
                size: kHeight * 0.025,
              );
            },
          ),
        ),
      ),
    );
  }
}

class message_bottom1 extends StatelessWidget {
  final String image;
  final Color color;
  final Color? color2;
  final VoidCallback? onPress;

  /// Use a Flutter icon when an asset is missing, transparent or not needed.
  final IconData? icon;
  final Color? iconColor;

  /// Optional ON/OFF indicator used by room-control cards.
  final bool showStatus;
  final bool active;

  const message_bottom1({
    super.key,
    required this.image,
    required this.color,
    this.color2,
    this.onPress,
    this.icon,
    this.iconColor,
    this.showStatus = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final double cardHeight = kHeight * 0.06;
    final double cardWidth = kWeight * 0.22;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPress,
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: cardHeight,
              width: cardWidth,
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 10,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color2 ?? color.withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: icon != null
                  ? Icon(
                icon,
                color: iconColor ?? Colors.white,
                size: kHeight * 0.029,
              )
                  : Image.asset(
                image,
                height: kHeight * 0.033,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.apps_rounded,
                    color: iconColor ?? Colors.white,
                    size: kHeight * 0.027,
                  );
                },
              ),
            ),
            if (showStatus)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  height: kHeight * 0.018,
                  width: kHeight * 0.018,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? const Color(0xff19B96B)
                        : const Color(0xffAAB0BC),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Icon(
                    active ? Icons.check_rounded : Icons.remove_rounded,
                    color: Colors.white,
                    size: kHeight * 0.011,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


