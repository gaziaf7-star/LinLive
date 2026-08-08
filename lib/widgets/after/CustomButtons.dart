import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

class CustomButtons extends StatelessWidget {
  final String text;
  final String image;
  final Color? backgroundColor;

  /// Button-এর ভিতরের gradient
  final Gradient? gradient;

  /// Neon border gradient
  final Gradient? borderGradient;

  final VoidCallback? onTap;
  final double? height;
  final bool isLoading;
  final bool showArrow;
  final double borderWidth;
  final Color textColor;
  final Color arrowColor;
  final EdgeInsetsGeometry margin;

  const CustomButtons({
    super.key,
    required this.text,
    required this.image,
    required this.onTap,
    this.backgroundColor,
    this.gradient,
    this.borderGradient,
    this.height,
    this.isLoading = false,
    this.showArrow = true,
    this.borderWidth = 3,
    this.textColor = Colors.white,
    this.arrowColor = const Color(0xffb89aff),
    this.margin = const EdgeInsets.symmetric(
      horizontal: 2,
      vertical: 7,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);

    final double buttonHeight =
        height ?? (screenSize.height * 0.068).clamp(58.0, 70.0).toDouble();

    final double fontSize =
    (screenSize.height * 0.021).clamp(16.0, 21.0).toDouble();

    final BorderRadius outerRadius = BorderRadius.circular(45);

    final BorderRadius innerRadius = BorderRadius.circular(
      45 - borderWidth,
    );

    final Gradient effectiveBorderGradient =
        borderGradient ??
            const LinearGradient(
              colors: [
                Color(0xffff5ee7),
                Color(0xffbc40ff),
                Color(0xff626dff),
                Color(0xff40b7ff),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            );

    final Gradient effectiveInnerGradient =
        gradient ??
            const LinearGradient(
              colors: [
                Color(0xff25004f),
                Color(0xff150044),
                Color(0xff08083f),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kWeight*0.03),
      child: Container(
        width: double.infinity,
        height: kHeight*0.067,
        decoration: BoxDecoration(
          gradient: effectiveBorderGradient,
          borderRadius: outerRadius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff43df).withOpacity(0.42),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: const Color(0xff397dff).withOpacity(0.42),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        padding: EdgeInsets.all(borderWidth),
        child: Material(
          color: Colors.transparent,
          borderRadius: innerRadius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: backgroundColor,
              gradient: backgroundColor == null
                  ? effectiveInnerGradient
                  : null,
              borderRadius: innerRadius,
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: isLoading ? null : onTap,
              borderRadius: innerRadius,
              splashColor: Colors.white.withOpacity(0.12),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    // Left icon area
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isLoading
                              ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                              : Image.asset(
                            image,
                            key: const ValueKey('icon'),
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Center text
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Right arrow area
                    SizedBox(
                      width: 45,
                      child: Center(
                        child: showArrow
                            ? Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: arrowColor,
                          size: 25,
                        )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}