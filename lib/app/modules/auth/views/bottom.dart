

import 'package:flutter/cupertino.dart';

import '../../../../constants/color_constants.dart';
import 'package:flutter/material.dart';

class LightingButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const LightingButton({super.key, required this.text, required this.onTap});

  @override
  State<LightingButton> createState() => _LightingButtonState();
}

class _LightingButtonState extends State<LightingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [
                    Colors.purpleAccent,
                    Colors.blueAccent,
                    Colors.cyanAccent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(_animation.value),
                    blurRadius: 25,
                    spreadRadius: 3,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Text(
                widget.text,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BNBCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Color(0xffffffff) // আপনার থিম কালার
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.moveTo(0, 0); // শুরুতে একদম কোণ থেকে শুরু হবে (কোনো রেডিয়াস নেই)

    // বাম দিকের সোজা লাইন থেকে সেন্টার বাটন বা নচ (Notch) পর্যন্ত
    path.lineTo(size.width * 0.35, 0);

    // মাঝখানের কার্ভ (যেখানে ভিডিও আইকনটি আছে)
    path.quadraticBezierTo(size.width * 0.40, 0, size.width * 0.40, 20);
    path.arcToPoint(
      Offset(size.width * 0.60, 20),
      radius: const Radius.circular(20.0),
      clockwise: false,
    );
    path.quadraticBezierTo(size.width * 0.60, 0, size.width * 0.65, 0);

    // ডান দিকের একদম শেষ কোণ পর্যন্ত সোজা লাইন
    path.lineTo(size.width, 0);

    // নিচের অংশগুলো সোজা রাখা হয়েছে
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // শ্যাডো বা হালকা গভীরতা দেওয়ার জন্য (ঐচ্ছিক)
    canvas.drawShadow(path, Colors.black, 5, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
