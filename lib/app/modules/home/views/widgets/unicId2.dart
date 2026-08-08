import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/constants.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

class ShimmerUserId1 extends StatefulWidget {
  final dynamic user;
  final double kHeight;
  final double kWeight;

  const ShimmerUserId1({
    super.key,
    required this.user,
    required this.kHeight,
    required this.kWeight,
  });

  @override
  State<ShimmerUserId1> createState() => _ShimmerUserId1State();
}

class _ShimmerUserId1State extends State<ShimmerUserId1>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: widget.kHeight * 0.04,
      width: widget.kWeight * 0.22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/audio_live/unicId-removebg-preview.png',
            height: widget.kHeight * 0.04,
            width: widget.kWeight * 0.22,
            fit: BoxFit.fill,
          ),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: const [
                      Color(0xFFFF8000),
                      Color(0xFFFFF4A3),
                      Color(0xFFFFD700),
                      Color(0xFFFF8000)
                    ],
                    stops: [
                      (_controller.value - 0.35).clamp(0.0, 1.0),
                      (_controller.value - 0.10).clamp(0.0, 1.0),
                      _controller.value.clamp(0.0, 1.0),
                      (_controller.value + 0.25).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                child: Padding(
                  padding:  EdgeInsets.only(left: kWeight*0.045),
                  child: Text(
                    authController.userProfile.value.user!.uniqueId.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: widget.kHeight * 0.016,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF8000),
                      height: 1,
                      shadows: const [
                        Shadow(
                          blurRadius: 5,
                          color: Color(0xFFFFD700),
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          blurRadius: 10,
                          color: Color(0xFFFFC107),
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}