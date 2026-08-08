import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../constants/spinkit.dart';
import '../controllers/store_controller.dart';
import 'backPackGiftsent.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class Backpackstore extends StatefulWidget {
  const Backpackstore({super.key});

  @override
  State<Backpackstore> createState() => _BackpackstoreState();
}

class _BackpackstoreState extends State<Backpackstore> {
  late final StoreController storeController;
  late Future<dynamic> _loadFuture;

  int _selectedTabIndex = 0;
  int _selectedVipSubTabIndex = 0;

  // Keeps the tapped asset visually active immediately while the API request
  // and backpack refresh are running. The key is frame/entry/vip.
  final Map<String, String> _pendingActiveAssetByType = <String, String>{};

  final List<_BackpackTab> _tabs = [
    _BackpackTab(title: ('VIP').appTr, key: 'vip'),
    _BackpackTab(title: ('Frame').appTr, key: 'frame'),
    _BackpackTab(title: ('Entry').appTr, key: 'entry'),
  ];

  final List<_BackpackTab> _vipSubTabs = [
    _BackpackTab(title: ('VIP Base').appTr, key: 'base'),
    _BackpackTab(title: ('VIP Assets').appTr, key: 'assets'),
  ];

  @override
  void initState() {
    super.initState();
    storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());
    _loadFuture = storeController.showBackPackList();
  }

  Future<void> _refreshBackpack() async {
    final future = storeController.showBackPackList();
    setState(() => _loadFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return LoadingOverlay(
        isLoading: storeController.isLoading.value,
        progressIndicator: kLoadingIndicator(),
        child: Container(
          color: const Color(0xffF4F5F9),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildMainTabs(),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<dynamic>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        storeController.backpackList.isEmpty &&
                        storeController.vipBaseItems.isEmpty) {
                      return _buildLoadingGrid();
                    }

                    if (snapshot.hasError &&
                        storeController.backpackList.isEmpty &&
                        storeController.vipBaseItems.isEmpty) {
                      return _buildErrorState();
                    }

                    return _buildSelectedTabBody();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSelectedTabBody() {
    final selectedTab = _tabs[_selectedTabIndex];

    if (selectedTab.key == 'vip') {
      return Column(
        children: [
          _buildVipSubTabs(),
          const SizedBox(height: 10),
          if (_selectedVipSubTabIndex == 0) ...[
            _buildVipMasterCard(),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _buildItemsGrid(
              items: _selectedVipSubTabIndex == 0
                  ? List<dynamic>.from(storeController.vipBaseItems)
                  : _filteredHistoryItems('vip'),
              emptyTitle: _selectedVipSubTabIndex == 0
                  ? ('VIP Base').appTr
                  : ('VIP Assets').appTr,
            ),
          ),
        ],
      );
    }

    return _buildItemsGrid(
      items: _filteredHistoryItems(selectedTab.key),
      emptyTitle: selectedTab.title,
    );
  }

  Widget _buildMainTabs() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final selected = _selectedTabIndex == index;
          final count = _mainTabCount(tab.key);

          return GestureDetector(
            onTap: () {
              if (_selectedTabIndex == index) return;
              setState(() {
                _selectedTabIndex = index;
                if (tab.key != 'vip') _selectedVipSubTabIndex = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: selected
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff793be6),
                    Color(0xff4700f5),
                  ],
                )
                    : null,
                color: selected ? null : Colors.white,
                border: Border.all(
                  color: selected
                      ? const Color(0xff793be6)
                      : const Color(0xffE3E5EE),
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: const Color(0xff793be6).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.title,
                    style: GoogleFonts.lato(
                      color:
                      selected ? Colors.white : const Color(0xff313247),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 7),
                  _CountBadge(count: count, selected: selected),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVipSubTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffEAE7F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(_vipSubTabs.length, (index) {
          final tab = _vipSubTabs[index];
          final selected = _selectedVipSubTabIndex == index;
          final count = index == 0
              ? storeController.vipBaseItems.length
              : _filteredHistoryItems('vip').length;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedVipSubTabIndex == index) return;
                setState(() => _selectedVipSubTabIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tab.title,
                      style: GoogleFonts.lato(
                        color: selected
                            ? const Color(0xff5C20D7)
                            : const Color(0xff696A79),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: GoogleFonts.lato(
                        color: selected
                            ? const Color(0xff5C20D7)
                            : const Color(0xff8A8B98),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVipMasterCard() {
    if (!storeController.hasCurrentVip) {
      return const SizedBox.shrink();
    }

    final enabled = storeController.currentVipEnabled;
    final saving = storeController.isVipBaseSaving('is_enabled');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xff261049),
            Color(0xff5D24B8),
            Color(0xff7A3FE7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff5D24B8).withOpacity(.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.14),
              border: Border.all(color: Colors.white.withOpacity(.25)),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xffffdd71),
              size: 27,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeController.currentVipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? ('All VIP base items are active').appTr
                      : ('All VIP base items are inactive').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: Colors.white.withOpacity(.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (storeController.currentVipExpiresAt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${('Expires').appTr}: ${storeController.currentVipExpiresAt}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      color: Colors.white.withOpacity(.62),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (saving)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Switch.adaptive(
              value: enabled,
              activeColor: const Color(0xffffdd71),
              onChanged: storeController.hasCurrentVip
                  ? storeController.toggleVipMembership
                  : null,
            ),
        ],
      ),
    );
  }

  String _effectiveActiveAssetId(String typeKey) {
    if (_pendingActiveAssetByType.containsKey(typeKey)) {
      return _pendingActiveAssetByType[typeKey] ?? '';
    }
    return _serverActiveAssetIdForType(typeKey);
  }

  String _serverActiveAssetIdForType(String typeKey) {
    final histories = storeController.backpackList;

    // First priority: a row explicitly marked as equipped/selected.
    for (final rawItem in histories) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      if (_getTypeKey(item) != typeKey) continue;

      final assetId = _itemAssetId(item);
      if (assetId.isEmpty) continue;

      if (_hasTrueFlag(item, const [
        'is_equipped',
        'equipped',
        'is_selected',
        'selected',
        'is_active_asset',
        'active_asset',
        'is_current_asset',
      ])) {
        return assetId;
      }
    }

    // Second priority: active/equipped asset IDs returned beside any row.
    final candidateIds = <String>{};

    for (final rawItem in histories) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final user = _mapOf(item['user']);

      _collectAssetIdCandidates(candidateIds, item, typeKey);
      _collectAssetIdCandidates(candidateIds, user, typeKey);

      final activePurchase = _mapOf(
        user['asset_purchase_history'] ??
            user['active_asset_purchase_history'] ??
            user['equipped_asset'] ??
            item['active_asset_purchase_history'],
      );

      final nestedId = _cleanString(
        activePurchase['asset_id'] ??
            activePurchase['id'],
      );
      if (nestedId.isNotEmpty) candidateIds.add(nestedId);
    }

    for (final candidateId in candidateIds) {
      final matchingItem = _findBackpackItemByAssetId(candidateId);
      if (matchingItem != null && _getTypeKey(matchingItem) == typeKey) {
        return candidateId;
      }
    }

    // Do not use item.status here. In this API, "Active" means the purchase is
    // valid, not that the frame/entry is currently equipped.
    return '';
  }

  Map<String, dynamic>? _findBackpackItemByAssetId(String assetId) {
    for (final rawItem in storeController.backpackList) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      if (_itemAssetId(item) == assetId) return item;
    }
    return null;
  }

  void _showPendingSelection(String typeKey, String assetId) {
    if (!mounted) return;
    setState(() {
      _pendingActiveAssetByType[typeKey] = assetId;
    });
  }

  void _clearPendingSelection(String typeKey) {
    if (!mounted) return;
    setState(() {
      _pendingActiveAssetByType.remove(typeKey);
    });
  }

  Widget _buildItemsGrid({
    required List<dynamic> items,
    required String emptyTitle,
  }) {
    if (items.isEmpty) {
      return _buildEmptyState(emptyTitle);
    }

    return RefreshIndicator(
      onRefresh: _refreshBackpack,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(
          left: 2,
          right: 2,
          top: 2,
          bottom: 20,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.74,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final rawItem = items[index];
          final itemMap = rawItem is Map
              ? Map<String, dynamic>.from(rawItem)
              : <String, dynamic>{};
          final isVipBase = _asBool(itemMap['is_vip_base']);
          final typeKey = isVipBase ? 'vip_base' : _getTypeKey(itemMap);

          return _BackpackCard(
            item: rawItem,
            storeController: storeController,
            activeAssetId: isVipBase
                ? ''
                : _effectiveActiveAssetId(typeKey),
            onPendingSelection: _showPendingSelection,
            onSelectionFinished: _clearPendingSelection,
          );
        },
      ),
    );
  }

  int _mainTabCount(String key) {
    if (key == 'vip') {
      return storeController.vipBaseItems.length +
          _filteredHistoryItems('vip').length;
    }
    return _filteredHistoryItems(key).length;
  }

  List<dynamic> _filteredHistoryItems(String tabKey) {
    return storeController.backpackList.where((item) {
      if (item is! Map) return false;
      final map = Map<String, dynamic>.from(item);
      return _getTypeKey(map) == tabKey;
    }).toList();
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _refreshBackpack,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: kHeight * 0.22),
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              ('Failed to load backpack list').appTr,
              style: GoogleFonts.lato(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              ('Pull down to refresh').appTr,
              style: GoogleFonts.lato(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String tabTitle) {
    return RefreshIndicator(
      onRefresh: _refreshBackpack,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: kHeight * 0.18),
          const Icon(
            Icons.inventory_2_outlined,
            size: 52,
            color: Colors.black26,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              ('No $tabTitle item found').appTr,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                color: Colors.black54,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackpackCard extends StatelessWidget {
  const _BackpackCard({
    required this.item,
    required this.storeController,
    required this.activeAssetId,
    required this.onPendingSelection,
    required this.onSelectionFinished,
  });

  final dynamic item;
  final StoreController storeController;
  final String activeAssetId;
  final void Function(String typeKey, String assetId) onPendingSelection;
  final void Function(String typeKey) onSelectionFinished;

  Map<String, dynamic> get _itemMap {
    if (item is Map<String, dynamic>) return item as Map<String, dynamic>;
    if (item is Map) return Map<String, dynamic>.from(item as Map);
    return <String, dynamic>{};
  }

  bool get _isVipBase => _asBool(_itemMap['is_vip_base']);

  Map<String, dynamic> get _assetMap {
    if (_isVipBase) return _itemMap;
    return _getAssetMap(_itemMap);
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetMap;
    final assetId = _cleanString(
      _itemMap['asset_id'] ?? asset['id'],
    );
    final assetPath = _cleanString(asset['asset']);
    final showImagePath = _cleanString(
      asset['show_image_url'] ??
          asset['showImageUrl'] ??
          asset['show_image'],
    );
    final name = _cleanString(asset['name']).isEmpty
        ? 'Backpack Item'
        : _cleanString(asset['name']);
    final price = _cleanString(asset['price']).isEmpty
        ? '0'
        : _cleanString(asset['price']);
    final durationDays = _cleanString(asset['duration_days']).isEmpty
        ? '-'
        : _cleanString(asset['duration_days']);
    final featureKey = _cleanString(_itemMap['feature_key']);
    final typeKey = _isVipBase ? 'vip_base' : _getTypeKey(_itemMap);

    final isActive = _isVipBase
        ? storeController.vipBaseItemEnabled(featureKey)
        : assetId.isNotEmpty && activeAssetId == assetId;

    final isVipManaged = _asBool(_itemMap['is_vip_managed']);
    final canSend = !_isVipBase && !isVipManaged && assetId.isNotEmpty;
    final canActivate = _isVipBase ||
        _asBool(_itemMap['can_activate'], fallback: true);
    final isSaving = _isVipBase &&
        storeController.isVipBaseSaving(featureKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: _isVipBase
            ? Border.all(
          color: const Color(0xff793be6).withOpacity(.28),
        )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _isVipBase
                            ? const [
                          Color(0xffF2E8FF),
                          Color(0xffC9A8FF),
                        ]
                            : const [
                          Color(0xffade8f0),
                          Color(0xffcdaafc),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      color: const Color(0xff25263A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 42,
                      left: 10,
                      right: 10,
                    ),
                    child: GestureDetector(
                      onTap: assetPath.isEmpty && showImagePath.isEmpty
                          ? null
                          : () => _openAssetPreviewDialog(
                        name: name,
                        assetPath: assetPath,
                        showImagePath: showImagePath,
                      ),
                      child: _BackpackAssetPreview(
                        assetPath: assetPath,
                        showImagePath: showImagePath,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xff1FA76F)
                          : const Color(0xff7D7E8A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isVipBase
                          ? (isActive ? ('Active').appTr : ('Inactive').appTr)
                          : ('$durationDays Days').appTr,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      if (canSend) ...[
                        Expanded(
                          child: _SmallActionButton(
                            title: ('Sending').appTr,
                            color: const Color(0xff2fb599),
                            onTap: () {
                              storeController.backPackAssetId.value = assetId;
                              _openSendBottomSheet(
                                item: _itemMap,
                                storeController: storeController,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _SmallActionButton(
                          title: isSaving
                              ? ''
                              : isActive
                              ? ('Deactivate').appTr
                              : ('Activate').appTr,
                          color: isActive
                              ? const Color(0xffE15B64)
                              : const Color(0xff4700f5),
                          loading: isSaving,
                          onTap: () async {
                            if (!canActivate) {
                              Fluttertoast.showToast(
                                msg: ('This item cannot be activated').appTr,
                              );
                              return;
                            }

                            if (_isVipBase) {
                              await storeController.toggleVipBaseItem(
                                featureKey: featureKey,
                                value: !isActive,
                              );
                              return;
                            }

                            if (assetId.isEmpty) return;

                            // Update the UI immediately. Empty means no selected
                            // item in this category while deactivating.
                            onPendingSelection(
                              typeKey,
                              isActive ? '' : assetId,
                            );

                            try {
                              if (isActive) {
                                await storeController.deActiveBackPackPost(
                                  backPackId: assetId,
                                );
                              } else {
                                await storeController.activeBackPackPost(
                                  backPackId: assetId,
                                );
                              }
                            } finally {
                              // Controller refreshes the backpack after success.
                              // Removing the temporary value makes the card use
                              // the fresh server-selected asset ID.
                              onSelectionFinished(typeKey);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _isVipBase
                ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 17,
                  color: Color(0xff793be6),
                ),
                const SizedBox(width: 4),
                Text(
                  storeController.currentVipTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: const Color(0xff793be6),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/coin.png',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xff793be6),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackpackAssetPreview extends StatelessWidget {
  const _BackpackAssetPreview({
    required this.assetPath,
    this.showImagePath = '',
    this.large = false,
  });

  final String assetPath;
  final String showImagePath;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final previewPath = showImagePath.isNotEmpty ? showImagePath : assetPath;

    if (previewPath.isEmpty) {
      return const Icon(
        Icons.image_not_supported_outlined,
        size: 44,
        color: Colors.white70,
      );
    }

    final size = large ? kHeight * 0.24 : kHeight * 0.105;
    final previewIsSvga = _fileExtension(previewPath) == 'svga';

    if (previewIsSvga) {
      return SizedBox(
        height: size,
        width: size,
        child: SVGAEasyPlayer(
          resUrl: _buildAssetUrl(previewPath),
          fit: BoxFit.contain,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: _buildAssetUrl(previewPath),
      height: size,
      width: size,
      fit: BoxFit.contain,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.35),
        highlightColor: Colors.white.withOpacity(0.75),
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      errorWidget: (context, url, error) => const Icon(
        Icons.broken_image_outlined,
        size: 44,
        color: Colors.white,
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.title,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w700,
            fontSize: kHeight * 0.0105,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.selected,
  });

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withOpacity(0.20)
            : const Color(0xffF0EEFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.lato(
          color: selected ? Colors.white : const Color(0xff793be6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

void _openAssetPreviewDialog({
  required String name,
  required String assetPath,
  required String showImagePath,
}) {
  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff2C1552),
              Color(0xff5B28A7),
              Color(0xff1D0E37),
            ],
          ),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: kHeight * .32,
              width: double.infinity,
              child: _BackpackAssetPreview(
                assetPath: assetPath,
                showImagePath: _fileExtension(assetPath) == 'svga'
                    ? ''
                    : showImagePath,
                large: true,
              ),
            ),
          ],
        ),
      ),
    ),
    barrierColor: Colors.black.withOpacity(.72),
  );
}

void _openSendBottomSheet({
  required Map<String, dynamic> item,
  required StoreController storeController,
}) {
  final asset = _getAssetMap(item);
  final assetPath = _cleanString(asset['asset']);
  final showImagePath = _cleanString(asset['show_image']);
  final price = _cleanString(asset['price']).isEmpty
      ? '0'
      : _cleanString(asset['price']);
  final name = _cleanString(asset['name']).isEmpty
      ? 'Backpack Item'
      : _cleanString(asset['name']);

  Get.bottomSheet(
    Container(
      height: kHeight * 0.43,
      padding: EdgeInsets.symmetric(
        vertical: kHeight * 0.02,
        horizontal: kWeight * 0.04,
      ),
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          SizedBox(height: kHeight * 0.015),
          Row(
            children: [
              Container(
                height: kHeight * 0.105,
                width: kHeight * 0.105,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xffade8f0),
                      Color(0xffcdaafc),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _BackpackAssetPreview(
                  assetPath: assetPath,
                  showImagePath: showImagePath,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/coin.png',
                          width: 18,
                          height: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          price,
                          style: GoogleFonts.poppins(
                            color: const Color(0xff793be6),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: kHeight * 0.018),
          const Divider(color: Colors.black12),
          SizedBox(height: kHeight * 0.01),
          Text(
            ('Select gift object').appTr,
            style: GoogleFonts.lato(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: kHeight * 0.015),
          GestureDetector(
            onTap: () {
              Get.to(
                Backpackgiftsent(),
                transition: Transition.rightToLeft,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xff793be6).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xff793be6).withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ('Send').appTr,
                    style: GoogleFonts.lato(
                      color: const Color(0xff25263A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ('Choose').appTr,
                    style: GoogleFonts.lato(
                      color: const Color(0xff1d5bf4),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/coin.png',
                    width: 22,
                    height: 22,
                  ),
                  Text(
                    ' ${_walletCoinText()}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xff793be6),
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 7,
                    horizontal: 20,
                  ),
                  minimumSize: const Size(0, 35),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(0xff793be6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () {},
                child: Text(
                  ('Send').appTr,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

class _BackpackTab {
  const _BackpackTab({
    required this.title,
    required this.key,
  });

  final String title;
  final String key;
}

Map<String, dynamic> _getAssetMap(Map<String, dynamic> item) {
  final asset = item['asset'];
  if (asset is Map<String, dynamic>) return asset;
  if (asset is Map) return Map<String, dynamic>.from(asset);
  return <String, dynamic>{};
}

String _getTypeKey(Map<String, dynamic> item) {
  final asset = _getAssetMap(item);
  final assetType = _cleanString(asset['type']).toLowerCase();
  final assetName = _cleanString(asset['name']).toLowerCase();
  final itemType = _cleanString(item['type']).toLowerCase();
  final combined = '$assetType $assetName $itemType';

  // VIP-managed assets often return asset.type = "Vip". Therefore the name
  // must be inspected before the generic VIP rule.
  if (combined.contains('frame') || combined.contains('fream')) {
    return 'frame';
  }

  if (combined.contains('entry') ||
      combined.contains('antri') ||
      combined.contains('entrance') ||
      combined.contains('banner') ||
      combined.contains(' car')) {
    return 'entry';
  }

  if (combined.contains('vip') ||
      combined.contains('svip') ||
      combined.contains('vvip') ||
      _asBool(item['is_vip_asset']) ||
      _asBool(item['is_vip_managed'])) {
    return 'vip';
  }

  return 'other';
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _itemAssetId(Map<String, dynamic> item) {
  final asset = _getAssetMap(item);
  return _cleanString(
    item['asset_id'] ??
        asset['id'],
  );
}

bool _hasTrueFlag(
    Map<String, dynamic> map,
    List<String> keys,
    ) {
  for (final key in keys) {
    if (map.containsKey(key) && _asBool(map[key])) return true;
  }
  return false;
}

void _collectAssetIdCandidates(
    Set<String> output,
    Map<String, dynamic> map,
    String typeKey,
    ) {
  if (map.isEmpty) return;

  final genericKeys = <String>[
    'active_asset_id',
    'current_asset_id',
    'selected_asset_id',
    'equipped_asset_id',
  ];

  final typedKeys = switch (typeKey) {
    'frame' => <String>[
      'active_frame_id',
      'current_frame_id',
      'selected_frame_id',
      'equipped_frame_id',
      'frame_asset_id',
    ],
    'entry' => <String>[
      'active_entry_id',
      'current_entry_id',
      'selected_entry_id',
      'equipped_entry_id',
      'entry_asset_id',
    ],
    'vip' => <String>[
      'active_vip_asset_id',
      'current_vip_asset_id',
      'selected_vip_asset_id',
    ],
    _ => <String>[],
  };

  for (final key in <String>[...typedKeys, ...genericKeys]) {
    final id = _cleanString(map[key]);
    if (id.isNotEmpty) output.add(id);
  }
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value == 1;

  final text = _cleanString(value).toLowerCase();
  if (const {'1', 'true', 'active', 'on', 'yes'}.contains(text)) return true;
  if (const {'0', 'false', 'inactive', 'off', 'no'}.contains(text)) {
    return false;
  }
  return fallback;
}

String _cleanString(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.toLowerCase() == 'null') return '';
  return text;
}

String _fileExtension(String value) {
  final clean = Uri.tryParse(value)?.path ?? value;
  final parts = clean.split('.');
  if (parts.length < 2) return '';
  return parts.last.toLowerCase();
}

String _buildAssetUrl(String path) {
  final cleanPath = path.trim();
  if (cleanPath.startsWith('http://') ||
      cleanPath.startsWith('https://')) {
    return cleanPath;
  }

  final base = kDomainUrl.endsWith('/')
      ? kDomainUrl.substring(0, kDomainUrl.length - 1)
      : kDomainUrl;
  final itemPath =
  cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;

  return '$base/$itemPath';
}

String _walletCoinText() {
  try {
    return '${authController.userProfile.value.user?.coins ?? 0}';
  } catch (_) {
    return '0';
  }
}
