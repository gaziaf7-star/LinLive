import 'dart:collection';

import 'package:get/get.dart';

enum GlobalLiveBannerType {
  luckyBag,
  luckyWin,
  rocket,
}

class GlobalLiveBannerItem {
  const GlobalLiveBannerItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.displaySeconds,
  });

  final String id;
  final GlobalLiveBannerType type;
  final Map<String, dynamic> payload;
  final int displaySeconds;
}

/// One app-wide FIFO queue for Lucky Bag, Lucky Win and Rocket banners.
///
/// Rules:
/// - At most two banners are visible at the same time.
/// - The same banner type is shown one-by-one, never twice in two slots.
/// - Waiting time never consumes a banner's display duration.
/// - A dismissed/completed banner promotes the next eligible queued item.
class GlobalLiveBannerQueueController extends GetxController {
  static const int maxVisibleBanners = 2;

  final RxList<GlobalLiveBannerItem> visibleBanners =
      <GlobalLiveBannerItem>[].obs;

  final Queue<GlobalLiveBannerItem> _pending =
  Queue<GlobalLiveBannerItem>();
  final LinkedHashSet<String> _seenIds = LinkedHashSet<String>();

  bool hasSeen(String id) => _seenIds.contains(id);

  int get pendingCount => _pending.length;

  bool isVisible(String id) =>
      visibleBanners.any((GlobalLiveBannerItem item) => item.id == id);

  void enqueue({
    required String id,
    required GlobalLiveBannerType type,
    required Map<String, dynamic> payload,
    int displaySeconds = 5,
  }) {
    final String normalizedId = id.trim();
    if (normalizedId.isEmpty || _seenIds.contains(normalizedId)) return;

    _remember(normalizedId);

    final GlobalLiveBannerItem item = GlobalLiveBannerItem(
      id: normalizedId,
      type: type,
      payload: Map<String, dynamic>.from(payload),
      displaySeconds: displaySeconds.clamp(3, 15).toInt(),
    );

    if (_canShowNow(item)) {
      visibleBanners.add(item);
      return;
    }

    _pending.addLast(item);
  }

  GlobalLiveBannerItem? activeItem(GlobalLiveBannerType type) {
    for (final GlobalLiveBannerItem item in visibleBanners) {
      if (item.type == type) return item;
    }
    return null;
  }

  int slotOf(String id) {
    return visibleBanners.indexWhere(
          (GlobalLiveBannerItem item) => item.id == id,
    );
  }

  void finish(String id) {
    final int oldLength = visibleBanners.length;
    visibleBanners.removeWhere(
          (GlobalLiveBannerItem item) => item.id == id,
    );

    if (visibleBanners.length != oldLength) {
      _promotePending();
    }
  }

  void clearAll() {
    visibleBanners.clear();
    _pending.clear();
    _seenIds.clear();
  }

  bool _canShowNow(GlobalLiveBannerItem item) {
    if (visibleBanners.length >= maxVisibleBanners) return false;
    return !visibleBanners.any(
          (GlobalLiveBannerItem active) => active.type == item.type,
    );
  }

  void _promotePending() {
    while (visibleBanners.length < maxVisibleBanners && _pending.isNotEmpty) {
      final int candidates = _pending.length;
      GlobalLiveBannerItem? selected;

      for (int index = 0; index < candidates; index++) {
        final GlobalLiveBannerItem candidate = _pending.removeFirst();
        if (_canShowNow(candidate)) {
          selected = candidate;
          break;
        }
        _pending.addLast(candidate);
      }

      if (selected == null) break;
      visibleBanners.add(selected);
    }
  }

  void _remember(String id) {
    _seenIds.add(id);
    while (_seenIds.length > 500) {
      _seenIds.remove(_seenIds.first);
    }
  }
}

GlobalLiveBannerQueueController globalLiveBannerQueue() {
  if (Get.isRegistered<GlobalLiveBannerQueueController>()) {
    return Get.find<GlobalLiveBannerQueueController>();
  }

  return Get.put<GlobalLiveBannerQueueController>(
    GlobalLiveBannerQueueController(),
    permanent: true,
  );
}
