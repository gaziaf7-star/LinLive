import 'package:flutter/material.dart';

class FamilyShimmer extends StatefulWidget {
  const FamilyShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<FamilyShimmer> createState() => _FamilyShimmerState();
}

class _FamilyShimmerState extends State<FamilyShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final width = rect.width;
            final dx = (width * 2) * _controller.value - width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlidingGradientTransform(dx),
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.dx);
  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(dx, 0, 0);
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, required this.height, this.radius = 12, this.margin});
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class FamilyListShimmer extends StatelessWidget {
  const FamilyListShimmer({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return FamilyShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 84,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: const Row(
            children: [
              ShimmerBox(width: 58, height: 58, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBox(width: 145, height: 14, radius: 8),
                    SizedBox(height: 8),
                    ShimmerBox(width: 80, height: 12, radius: 8),
                    SizedBox(height: 8),
                    ShimmerBox(width: 120, height: 10, radius: 8),
                  ],
                ),
              ),
              ShimmerBox(width: 58, height: 34, radius: 9),
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyHomeShimmer extends StatelessWidget {
  const FamilyHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return FamilyShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const ShimmerBox(width: double.infinity, height: 178, radius: 16),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Column(
                children: [
                  ShimmerBox(width: double.infinity, height: 18, radius: 8),
                  SizedBox(height: 12),
                  ShimmerBox(width: double.infinity, height: 14, radius: 8),
                  SizedBox(height: 8),
                  ShimmerBox(width: double.infinity, height: 14, radius: 8),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(5, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: ShimmerBox(width: double.infinity, height: 62, radius: 12))),
          ],
        ),
      ),
    );
  }
}
