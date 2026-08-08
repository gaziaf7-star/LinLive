import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Small helper widgets for audio room performance.
///
/// Keep expensive/live layers isolated so a small Rx update does not force the
/// whole AudioLiveView page to rebuild/repaint.
class AudioRoomReactiveBackground extends StatelessWidget {
  final Decoration Function()? decorationBuilder;
  final Widget Function()? childBuilder;

  const AudioRoomReactiveBackground({
    super.key,
    this.decorationBuilder,
    this.childBuilder,
  }) : assert(decorationBuilder != null || childBuilder != null);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Positioned.fill(
        child: RepaintBoundary(
          child:
              childBuilder?.call() ??
              DecoratedBox(decoration: decorationBuilder!.call()),
        ),
      ),
    );
  }
}

class AudioRoomLayerBoundary extends StatelessWidget {
  final Widget child;

  const AudioRoomLayerBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

class AudioRoomPositionedLayerBoundary extends StatelessWidget {
  final Widget child;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  const AudioRoomPositionedLayerBoundary({
    super.key,
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: RepaintBoundary(child: child),
    );
  }
}
