import 'package:flutter/material.dart';

/// Imogi now appears on the sender profile/seat center from:
/// - LiveViewCircle_container for audience seats
/// - AudioLiveView broadcaster profile for host seat
///
/// This widget is intentionally lightweight to keep old AudioLiveView import safe
/// without showing duplicate full-screen imogi.
class LiveImogiAnimationOverlay extends StatelessWidget {
  const LiveImogiAnimationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
