import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AnimatedProgressBar extends StatefulWidget {
  final AnimatedProgressBarController controller;

  const AnimatedProgressBar({Key? key, required this.controller})
      : super(key: key);

  @override
  _AnimatedProgressBarState createState() => _AnimatedProgressBarState();
}

class AnimatedProgressBarController {
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double barWidth = MediaQuery.of(context).size.width - 30;

    return Obx(() {
      // double percent = widget.controller.percent;
      // int teamA = widget.controller.teamALikes.value;
      // int teamB = widget.controller.teamBLikes.value;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Premium Background Shadow
          Container(
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.yellow.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
          ),

          // Progress Bar + Dynamic Lighting
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.4),
                      Colors.yellow.withOpacity(0.6),
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                    begin: Alignment(-1.0 + 2.0 * _glowController.value, 0),
                    end: Alignment(1.0 + 2.0 * _glowController.value, 0),
                  ).createShader(bounds);
                },
                blendMode: BlendMode.plus,
                child: LinearPercentIndicator(
                  animation: true,
                  animateFromLastPercent: true,
                  animationDuration: 1000,
                  lineHeight: 28.0,
                  // percent: percent,
                  barRadius: const Radius.circular(20),
                  backgroundColor: Colors.pink,
                  linearGradient: const LinearGradient(
                    colors: [Colors.indigoAccent, Colors.cyanAccent],
                  ),
                  center: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.thumb_up,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 5),
                            Text(
                              ("A").appTr,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              ("B").appTr,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.thumb_up,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Glow Shimmer (moving dot)
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Positioned(
                // left: (barWidth * percent) - 6,
                left: 6,
                top: -2,
                child: Opacity(
                  opacity: 0.5 + (0.5 * _glowController.value),
                  child: Container(
                    width: 14,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.9),
                          Colors.yellow.withOpacity(0.6),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Left Spark
          Positioned(
            left: -6,
            top: -2,
            child: Container(
              width: 12,
              height: 32,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.6), Colors.transparent],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // Right Spark
          Positioned(
            right: -6,
            top: -2,
            child: Container(
              width: 12,
              height: 32,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.3), Colors.transparent],
                  radius: 0.8,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
