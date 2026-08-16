import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/image_helper.dart';
import '../../../backpack/controllers/store_controller.dart';
import '../../../../theme/app_theme_controller.dart';
import '../../../../theme/app_theme_model.dart';
import '../../../../theme/widgets/app_theme_background.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class BaseMedalView extends StatefulWidget {
  const BaseMedalView({super.key});

  @override
  State<BaseMedalView> createState() => _BaseMedalViewState();
}

class _BaseMedalViewState extends State<BaseMedalView>
    with WidgetsBindingObserver {
  late final AppThemeController _appThemeController;
  late final StoreController _storeController;

  bool _pageRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appThemeController = Get.isRegistered<AppThemeController>()
        ? Get.find<AppThemeController>()
        : Get.put(AppThemeController(), permanent: true);

    _storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshBases();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBases();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshBases() async {
    if (_pageRefreshRunning) return;

    _pageRefreshRunning = true;
    try {
      await _storeController.getAssetList();
    } catch (_) {
      // Keep previous data visible.
    } finally {
      _pageRefreshRunning = false;
    }
  }

  void _openMedalPreview(dynamic item, int index) {
    Get.bottomSheet(
      _MedalPreviewSheet(item: item, index: index),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.34),
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final AppThemeModel? theme = _appThemeController.theme.value;
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Same theme image system as AppMenuView.
            Positioned.fill(
              child: AppThemeBackground(
                imageUrl: theme?.backgroundImage,
                child: const SizedBox.expand(),
              ),
            ),

            // AppMenu-style soft fade: theme image gradually mixes into white.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.00, 0.18, 0.31, 0.43, 0.58, 1.00],
                      colors: [
                        Colors.transparent,
                        Color(0x18FFFFFF),
                        Color(0x76FFFDF8),
                        Color(0xE8FFFDF8),
                        Color(0xFFFFFDF8),
                        Color(0xFFFFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _MedalHeader(onBack: () => Get.back()),
                  const _AchievementOnlyTab(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ColoredBox(
                      color: Colors.transparent,
                      child: Obx(() {
                        final List<dynamic> bases =
                        List<dynamic>.from(_storeController.baseAssetList);

                        if (bases.isEmpty && _storeController.isLoading.value) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Color(0xFFFFC928),
                              ),
                            ),
                          );
                        }

                        if (bases.isEmpty) {
                          return RefreshIndicator(
                            onRefresh: _refreshBases,
                            color: const Color(0xFFFFC928),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(top: 90),
                              children: <Widget>[
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 54,
                                  color: Colors.black.withOpacity(.20),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'No Achievement Medal'.appTr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF777777),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final int columns = constraints.maxWidth >= 760
                                ? 5
                                : constraints.maxWidth >= 560
                                ? 4
                                : 3;

                            final double horizontalPadding =
                            constraints.maxWidth < 360 ? 10 : 16;

                            return RefreshIndicator(
                              onRefresh: _refreshBases,
                              color: const Color(0xFFFFC928),
                              child: GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: ClampingScrollPhysics(),
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  8,
                                  horizontalPadding,
                                  MediaQuery.paddingOf(context).bottom + 28,
                                ),
                                cacheExtent:
                                MediaQuery.sizeOf(context).height * .85,
                                itemCount: bases.length,
                                gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: .84,
                                ),
                                itemBuilder: (context, index) {
                                  return RepaintBoundary(
                                    child: _BaseMedalCard(
                                      item: bases[index],
                                      index: index,
                                      onTap: () =>
                                          _openMedalPreview(bases[index], index),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MedalHeader extends StatelessWidget {
  const _MedalHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double titleSize = (width * .055).clamp(20.0, 25.0).toDouble();

    return SizedBox(
      height: 62,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onBack,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF161616),
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Medal'.appTr,
            style: GoogleFonts.poppins(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111111),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementOnlyTab extends StatelessWidget {
  const _AchievementOnlyTab();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Achievement'.appTr,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF202020),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC25),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseMedalCard extends StatelessWidget {
  const _BaseMedalCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final dynamic item;
  final int index;
  final VoidCallback onTap;

  Map<String, dynamic> get _map {
    if (item is Map<String, dynamic>) {
      return item as Map<String, dynamic>;
    }
    if (item is Map) {
      return Map<String, dynamic>.from(item as Map);
    }
    return const <String, dynamic>{};
  }

  String get _name {
    final Map<String, dynamic> map = _map;
    final String text = (map['name'] ??
        map['title'] ??
        map['base_name'] ??
        map['badge_name'] ??
        map['level_name'] ??
        'Badge ${index + 1}')
        .toString()
        .trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return 'Badge ${index + 1}';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final resolver = _MedalAssetResolver(_map);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE8D05D),
              width: 1.1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 9, 7, 10),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: _BaseMedalImage(imageUrl: resolver.thumbnailUrl),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3B3B3B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalPreviewSheet extends StatelessWidget {
  const _MedalPreviewSheet({required this.item, required this.index});

  final dynamic item;
  final int index;

  Map<String, dynamic> get _map {
    if (item is Map<String, dynamic>) return item as Map<String, dynamic>;
    if (item is Map) return Map<String, dynamic>.from(item as Map);
    return const <String, dynamic>{};
  }

  String get _name {
    final String text = (_map['name'] ??
        _map['title'] ??
        _map['badge_name'] ??
        'Badge ${index + 1}')
        .toString()
        .trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return 'Badge ${index + 1}';
    }
    return text;
  }

  String get _type {
    final String text = (_map['type'] ?? 'Badge').toString().trim();
    return text.isEmpty ? 'Badge' : text;
  }

  @override
  Widget build(BuildContext context) {
    final resolver = _MedalAssetResolver(_map);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 16 + bottom),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF7D4),
              Color(0xFFFFFBEA),
              Colors.white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.16),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.12),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Medal Preview'.appTr,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: Get.back,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 34,
                      width: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.92),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withOpacity(.05),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1E3A2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.035),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _BaseMedalPreviewImage(imageUrl: resolver.previewUrl),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4C8),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Text(
                _type,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7B5A00),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Thumbnail on list, real SVGA on preview.'.appTr,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7E7E7E),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DisabledActionButton(
                    title: 'Purchase Disabled'.appTr,
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DisabledActionButton(
                    title: 'Send Disabled'.appTr,
                    icon: Icons.send_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledActionButton extends StatelessWidget {
  const _DisabledActionButton({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: .55,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF7D7D7D)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7D7D7D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalAssetResolver {
  const _MedalAssetResolver(this.map);

  final Map<String, dynamic> map;

  String get thumbnailUrl => _resolve(<dynamic>[
    map['show_image_url'],
    map['image_url'],
    map['thumbnail_url'],
    map['base_image_url'],
    map['badge_image_url'],
    map['show_image'],
    map['image'],
    map['thumbnail'],
    map['base_image'],
    map['badge_image'],
    map['asset_url'],
    map['asset'],
  ]);

  String get previewUrl => _resolve(<dynamic>[
    map['asset_url'],
    map['asset'],
    map['base_asset_url'],
    map['badge_asset_url'],
    map['show_image_url'],
    map['show_image'],
    map['image_url'],
    map['image'],
    map['thumbnail_url'],
    map['thumbnail'],
  ]);

  String _resolve(List<dynamic> candidates) {
    for (final dynamic raw in candidates) {
      final String value = raw?.toString().trim() ?? '';
      if (value.isEmpty || value.toLowerCase() == 'null') continue;
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
      if (value.startsWith('assets/')) {
        return value;
      }
      return ImageHelper.getImageUrl(value);
    }
    return '';
  }
}

class _BaseMedalImage extends StatelessWidget {
  const _BaseMedalImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Icon(
        Icons.emoji_events_rounded,
        size: 48,
        color: Color(0xFFD8B72D),
      );
    }

    if (imageUrl.startsWith('assets/')) {
      if (imageUrl.toLowerCase().endsWith('.svga')) {
        return SVGAEasyPlayer(
          resUrl: imageUrl,
          fit: BoxFit.contain,
        );
      }

      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.emoji_events_rounded,
          size: 48,
          color: Color(0xFFD8B72D),
        ),
      );
    }

    if (imageUrl.toLowerCase().endsWith('.svga')) {
      return SVGAEasyPlayer(
        resUrl: imageUrl,
        fit: BoxFit.contain,
      );
    }

    final double logicalWidth = MediaQuery.sizeOf(context).width / 3.2;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheWidth = (logicalWidth * dpr).clamp(150.0, 420.0).round();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      memCacheWidth: cacheWidth,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const Icon(
        Icons.emoji_events_rounded,
        size: 48,
        color: Color(0xFFD8B72D),
      ),
    );
  }
}

class _BaseMedalPreviewImage extends StatelessWidget {
  const _BaseMedalPreviewImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Icon(
        Icons.emoji_events_rounded,
        size: 72,
        color: Color(0xFFD8B72D),
      );
    }

    if (imageUrl.startsWith('assets/')) {
      if (imageUrl.toLowerCase().endsWith('.svga')) {
        return SVGAEasyPlayer(
          resUrl: imageUrl,
          fit: BoxFit.contain,
        );
      }

      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.emoji_events_rounded,
          size: 72,
          color: Color(0xFFD8B72D),
        ),
      );
    }

    if (imageUrl.toLowerCase().endsWith('.svga')) {
      return SVGAEasyPlayer(
        resUrl: imageUrl,
        fit: BoxFit.contain,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      memCacheWidth: 720,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const Icon(
        Icons.emoji_events_rounded,
        size: 72,
        color: Color(0xFFD8B72D),
      ),
    );
  }
}
