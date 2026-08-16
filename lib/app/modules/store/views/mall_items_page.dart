import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../backpack/controllers/store_controller.dart';
import '../../coinshop/views/giftsent_friend.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

/// Ekta single reusable page — Frame, Entry Care, Banner Frame, Lucky Id

class MallItemsPage extends StatefulWidget {
  final String title;
  final String apiType;

  const MallItemsPage({
    super.key,
    required this.title,
    required this.apiType,
  });

  @override
  State<MallItemsPage> createState() => _MallItemsPageState();
}

class _MallItemsPageState extends State<MallItemsPage> {
  late final StoreController storeController;

  /// Age-e filter kora list — build() e r notun kore .where/.map cholbe na,
  /// tai select/tap korle instant feel hobe.
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _errorText;

  Map<String, dynamic>? selectedItem;

  bool get _isEntryType => widget.apiType.toLowerCase().trim() == 'entry care';

  @override
  void initState() {
    super.initState();
    storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());

    if (storeController.assetList.isNotEmpty) {
      // Cache-e already data ache (Mall page theke prefetch হয়ে থাকতে পারে,
      // ba age কোনো category ঘুরে আসা হয়েছে) — instant দেখাও।
      _applyFilter();
      _loading = false;
      _silentRefresh();
    } else {
      _loadFirstTime();
    }
  }

  Future<void> _loadFirstTime() async {
    try {
      await storeController.getAssetList();
      _applyFilter(rebuild: false);
    } catch (e) {
      _errorText = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Background-e chup chap notun data ante — UI block kore na, shimmer o
  /// dekhay na. Shesh hole list update hoy.
  Future<void> _silentRefresh() async {
    try {
      await storeController.getAssetList();
      _applyFilter();
    } catch (_) {
      // Silent fail — user purono cache-i dekhbe, kono error dekhabo na.
    }
  }

  Future<void> refreshAssets() async {
    try {
      await storeController.getAssetList();
      _errorText = null;
    } catch (e) {
      _errorText = e.toString();
    }
    _applyFilter();
  }

  void _applyFilter({bool rebuild = true}) {
    final list = storeController.assetList
        .where((item) => (item['type']?.toString() ?? '') == widget.apiType)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (rebuild && mounted) {
      setState(() => _items = list);
    } else {
      _items = list;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1B1109),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        title: Text(
          widget.title.appTr,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff2A1B10), Color(0xff1B1109)],
          ),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmerGrid();

    if (_errorText != null && _items.isEmpty) {
      return _buildEmptyState(
        title: ('Something went wrong').appTr,
        subtitle: _errorText!,
      );
    }

    if (_items.isEmpty) {
      return _buildEmptyState(
        title: ('No ${widget.title} items found').appTr,
        subtitle: ('New items will appear here.').appTr,
      );
    }

    return RefreshIndicator(
      color: kAppColor2,
      onRefresh: refreshAssets,
      child: _buildGrid(_items),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> list) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: .92,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final selected =
            selectedItem?['id']?.toString() == item['id']?.toString();

        return _MallItemCard(
          item: item,
          selected: selected,
          onTap: () {
            setState(() => selectedItem = item);
            storeController.selectId.value = item['id'].toString();
          },
          onPreviewTap: () => _openAssetPreview(context, item),
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: .92,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xff3A281A),
          highlightColor: const Color(0xff4C3624),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff3A281A),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded,
                color: Colors.white.withOpacity(.5), size: 46),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: Colors.white.withOpacity(.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                setState(() => _loading = true);
                await refreshAssets();
                if (mounted) setState(() => _loading = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAppColor2,
                foregroundColor: Colors.white,
              ),
              child: Text(('Refresh').appTr, style: GoogleFonts.roboto()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final myCoins =
    _formatCoins(authController.userProfile.value.user?.coins);
    final hasSelection = selectedItem != null;
    final purchased =
        selectedItem?['purchased']?.toString().toLowerCase() == 'yes';

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xff120B06),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/coin.png', height: 20, width: 20),
          const SizedBox(width: 6),
          Text(
            myCoins,
            style: GoogleFonts.roboto(
              color: const Color(0xffFFC94A),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: !hasSelection
                ? null
                : () {
              Get.to(GiftSentFriend(), transition: Transition.rightToLeft);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: kAppColor2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            child: Text(
              ('Send').appTr,
              style: GoogleFonts.roboto(
                color: kAppColor2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: !hasSelection
                ? null
                : purchased
                ? null
                : () async {
              await storeController.purchaseAsset(
                purchaseId: selectedItem!['id'].toString(),
              );
              await refreshAssets();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFFC94A),
              foregroundColor: const Color(0xff2A1B10),
              disabledBackgroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            child: Text(
              purchased ? ('Purchased').appTr : ('Purchase').appTr,
              style: GoogleFonts.roboto(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// Play icon tap handler — type onujayi dialog vs full-page select kore.
  void _openAssetPreview(BuildContext context, Map<String, dynamic> item) {
    if (_isEntryType) {
      _showFullPagePreview(context, item);
    } else {
      _showDialogPreview(context, item);
    }
  }

  /// Frame (ba onno type) -> chhoto centered Dialog popup.
  void _showDialogPreview(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.62),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 34),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xff21150B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xffFFC94A).withOpacity(.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 210,
                width: double.infinity,
                child: _AssetPreviewImage(item: item, preferAsset: true),
              ),
              const SizedBox(height: 14),
              Text(
                item['name']?.toString() ?? widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/coin.png', height: 16, width: 16),
                  const SizedBox(width: 5),
                  Text(
                    _formatCoins(item['price']),
                    style: GoogleFonts.roboto(
                      color: const Color(0xffFFC94A),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffFFC94A),
                    foregroundColor: const Color(0xff2A1B10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    ('Close').appTr,
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Entry Care -> full-page immersive preview.
  void _showFullPagePreview(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.55),
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _AssetPreviewImage(
                item: item,
                fit: BoxFit.cover,
                preferAsset: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    item['name']?.toString() ?? widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(.7),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MallItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPreviewTap;

  const _MallItemCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final durationDays = item['duration_days']?.toString() ?? '0';
    final purchased = item['purchased']?.toString().toLowerCase() == 'yes';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff4A3220), Color(0xff2E1E12)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xffFFC94A) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ('$durationDays day').appTr,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onPreviewTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xffFFC94A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Color(0xff2A1B10), size: 15),
                  ),
                ),
              ],
            ),
            Expanded(
              child: GestureDetector(
                onTap: onPreviewTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _AssetPreviewImage(item: item),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/coin.png', height: 16, width: 16),
                const SizedBox(width: 4),
                Text(
                  _formatCoins(item['price']),
                  style: GoogleFonts.roboto(
                    color: const Color(0xffFFC94A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (purchased) ...[
              const SizedBox(height: 4),
              Text(
                ('Owned').appTr,
                style: GoogleFonts.roboto(
                  color: Colors.greenAccent.shade100,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssetPreviewImage extends StatelessWidget {
  final Map<String, dynamic> item;
  final BoxFit fit;

  /// false = grid/card e show_image first (fast static thumbnail)
  /// true  = play/video preview e asset first (SVGA animation)
  final bool preferAsset;

  const _AssetPreviewImage({
    required this.item,
    this.fit = BoxFit.contain,
    this.preferAsset = false,
  });

  @override
  Widget build(BuildContext context) {
    final String showImage = _cleanPath(item['show_image']);
    final String asset = _cleanPath(item['asset']);

    // Grid/card: show_image first -> fast.
    // Play/video preview: asset first -> Frame/Entry SVGA directly play korbe.
    final String rawPath = preferAsset
        ? (asset.isNotEmpty ? asset : showImage)
        : (showImage.isNotEmpty ? showImage : asset);

    if (rawPath.isEmpty) {
      return Icon(
        Icons.image_not_supported_rounded,
        color: Colors.white.withOpacity(.4),
        size: 30,
      );
    }

    final String url = _toFullAssetUrl(rawPath);

    if (rawPath.toLowerCase().endsWith('.svga')) {
      return SizedBox.expand(
        child: RepaintBoundary(
          child: SVGAEasyPlayer(
            key: ValueKey(url),
            resUrl: url,
            fit: fit,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: 300,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: const Color(0xff3A281A),
        highlightColor: const Color(0xff4C3624),
        child: Container(color: const Color(0xff3A281A)),
      ),
      errorWidget: (context, url, error) => Icon(
        Icons.image_not_supported_rounded,
        color: Colors.white.withOpacity(.4),
        size: 30,
      ),
    );
  }

  String _cleanPath(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _toFullAssetUrl(String rawPath) {
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      return rawPath;
    }
    final String base = kDomainUrl.endsWith('/')
        ? kDomainUrl.substring(0, kDomainUrl.length - 1)
        : kDomainUrl;
    final String path = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    return '$base/$path';
  }
}

String _formatCoins(dynamic value) {
  final raw = value?.toString().replaceAll(',', '').trim() ?? '0';
  final number = double.tryParse(raw) ?? 0;

  if (number >= 1000000000) return '${_cleanNumber(number / 1000000000)}B';
  if (number >= 1000000) return '${_cleanNumber(number / 1000000)}M';
  if (number >= 1000) return '${_cleanNumber(number / 1000)}K';
  return number.toStringAsFixed(0);
}

String _cleanNumber(double value) {
  if (value >= 100) return value.toStringAsFixed(0);
  if (value >= 10) return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
}