import 'package:flutter/widgets.dart';

/// Shared responsive distance below the status-bar SafeArea for top banners.
double globalBannerTopOffset(BuildContext context) {
  final height = MediaQuery.sizeOf(context).height;
  return (height * 0.025).clamp(18.0, 24.0).toDouble();
}

double globalLuckyBannerTopOffset(BuildContext context) =>
    globalBannerTopOffset(context) + 10.0;

double globalLuckyVisibleBannerHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height * 0.117;

double globalBigGiftBannerHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 370 ? 116.0 : 124.0;

// Compatibility for banner types whose existing size is intentionally
// unchanged by the Lucky Win-only height adjustment.
double globalLuckyBannerHeight(BuildContext context) =>
    globalBigGiftBannerHeight(context);

double globalBigGiftBannerWidth(double availableWidth) {
  final compact = availableWidth < 370;
  return (availableWidth * (compact ? .96 : .93)).clamp(300.0, 610.0);
}

double globalBannerSlotOffset(BuildContext context, int slot) {
  if (slot <= 0) return 0;
  return slot * (globalBigGiftBannerHeight(context) + 20.0);
}
