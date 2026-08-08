import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
void showLiveImogiBottomSheet({
  required BuildContext context,
  required int streamId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LiveImogiBottomSheet(streamId: streamId),
  );
}

class LiveImogiBottomSheet extends StatefulWidget {
  final int streamId;

  const LiveImogiBottomSheet({
    super.key,
    required this.streamId,
  });

  @override
  State<LiveImogiBottomSheet> createState() => _LiveImogiBottomSheetState();
}

class _LiveImogiBottomSheetState extends State<LiveImogiBottomSheet> {
  final dynamic controller = Get.find<LivestreamController>();

  /// App process চলাকালীন parsed emoji/category data memory-তে থাকবে।
  /// ফলে bottom sheet দ্বিতীয়বার খুললে API/JSON grouping-এর জন্য অপেক্ষা করতে হবে না।
  static final List<_ImogiCategory> _memoryCategories = <_ImogiCategory>[];

  bool _loading = true;
  bool _sending = false;
  int _selectedIndex = 0;

  final List<_ImogiCategory> _categories = <_ImogiCategory>[];

  @override
  void initState() {
    super.initState();

    /// আগে memory cache থেকে instantly show, তারপর background-এ API refresh।
    _restoreMemoryCategories();
    _loadImogies();
  }

  _ImogiCategory _cloneCategory(_ImogiCategory category) {
    return _ImogiCategory(
      name: category.name,
      icon: category.icon,
      items: category.items
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      priority: category.priority,
    );
  }

  void _restoreMemoryCategories() {
    if (_memoryCategories.isEmpty) return;

    _categories
      ..clear()
      ..addAll(_memoryCategories.map(_cloneCategory));

    _selectedIndex = 0;
    _loading = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheVisibleImogies(0);
    });
  }

  void _saveMemoryCategories() {
    _memoryCategories
      ..clear()
      ..addAll(_categories.map(_cloneCategory));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheVisibleImogies(_selectedIndex);
    });
  }

  Future<void> _precacheUrl(String url) async {
    if (!mounted || url.isEmpty) return;

    try {
      await precacheImage(
        ResizeImage(
          CachedNetworkImageProvider(url),
          width: 128,
          height: 128,
        ),
        context,
      );
    } catch (_) {
      // Broken image must not block the emoji sheet.
    }
  }

  /// Selected tab-এর visible emoji এবং category icons আগে থেকেই image-cache-এ রাখে।
  Future<void> _precacheVisibleImogies(int categoryIndex) async {
    if (!mounted || _categories.isEmpty) return;

    final int safeIndex = categoryIndex.clamp(0, _categories.length - 1).toInt();
    final urls = <String>{};

    for (final category in _categories) {
      if (category.icon.isNotEmpty) urls.add(category.icon);
    }

    final selectedItems = _categories[safeIndex].items.take(24);
    for (final item in selectedItems) {
      final image = _itemImage(item);
      if (image.isNotEmpty) urls.add(image);
    }

    /// Next tab-এর কয়েকটি image-ও আগে load হবে।
    if (safeIndex + 1 < _categories.length) {
      for (final item in _categories[safeIndex + 1].items.take(8)) {
        final image = _itemImage(item);
        if (image.isNotEmpty) urls.add(image);
      }
    }

    await Future.wait(urls.take(36).map(_precacheUrl));
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String _safeImage(dynamic value) {
    final raw = _safeText(value);
    if (raw.isEmpty || raw == 'file:///') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return ImageHelper.getImageUrl(raw);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return <dynamic>[];
  }

  String _categoryNameFromItem(Map<String, dynamic> item) {
    return _safeText(
      item['category'] ??
          item['category_name'] ??
          item['type'] ??
          item['group'] ??
          item['tab'],
      fallback: 'Robot',
    );
  }

  String _itemName(Map<String, dynamic> item) {
    return _safeText(
      item['name'] ?? item['title'] ?? item['imogi_name'] ?? item['emoji_name'],
      fallback: 'Imogi',
    );
  }

  String _itemImage(Map<String, dynamic> item) {
    return _safeImage(
      item['image'] ??
          item['icon'] ??
          item['imogi_image'] ??
          item['emoji_image'] ??
          item['show_image'] ??
          item['url'] ??
          item['file'],
    );
  }

  int _itemId(Map<String, dynamic> item) {
    return int.tryParse(
      (item['id'] ?? item['imogi_id'] ?? item['emoji_id'] ?? 0).toString(),
    ) ??
        0;
  }

  bool _isVip(String name) {
    final key = name.toLowerCase();
    return key.contains('vip') ||
        key.contains('svip') ||
        key.contains('premium') ||
        key.contains('v7') ||
        key.contains('v&v');
  }

  bool _isRoot(String name) {
    final key = name.toLowerCase();
    return key == 'robot' ||
        key == 'root' ||
        key == 'custom' ||
        key == 'default' ||
        key == 'normal' ||
        key == 'all';
  }

  int _priority(String name) {
    final key = name.toLowerCase();

    if (_isRoot(name)) return 0;
    if (key.contains('animal')) return 10;
    if (key.contains('face')) return 20;
    if (key.contains('love')) return 30;
    if (key.contains('funny')) return 40;
    if (_isVip(name)) return 9999;

    return 100;
  }

  void _groupFlatList(List<dynamic> rawList) {
    final grouped = <String, _ImogiCategory>{};

    for (final raw in rawList) {
      final item = _asMap(raw);
      if (item.isEmpty) continue;

      final categoryName = _categoryNameFromItem(item);
      final key = categoryName.toLowerCase();

      grouped.putIfAbsent(
        key,
            () => _ImogiCategory(
          name: categoryName,
          icon: _itemImage(item),
          items: <Map<String, dynamic>>[],
          priority: _priority(categoryName),
        ),
      );

      grouped[key]!.items.add(item);

      if (grouped[key]!.icon.isEmpty) {
        grouped[key]!.icon = _itemImage(item);
      }
    }

    final list = grouped.values.where((cat) => cat.items.isNotEmpty).toList();

    list.sort((a, b) {
      if (a.priority != b.priority) return a.priority.compareTo(b.priority);

      final aSort = int.tryParse(
        (a.items.first['sort_order'] ?? a.items.first['sort'] ?? 999)
            .toString(),
      ) ??
          999;
      final bSort = int.tryParse(
        (b.items.first['sort_order'] ?? b.items.first['sort'] ?? 999)
            .toString(),
      ) ??
          999;

      if (aSort != bSort) return aSort.compareTo(bSort);
      return a.name.compareTo(b.name);
    });

    _categories
      ..clear()
      ..addAll(list);

    if (_selectedIndex >= _categories.length) _selectedIndex = 0;
    _saveMemoryCategories();
  }

  void _groupCategoryList(List<dynamic> rawList) {
    final list = <_ImogiCategory>[];

    for (final raw in rawList) {
      final cat = _asMap(raw);
      if (cat.isEmpty) continue;

      final rawItems = cat['imogies'] ??
          cat['imogi'] ??
          cat['emojis'] ??
          cat['emoji'] ??
          cat['items'] ??
          cat['list'];

      final items = _asList(rawItems)
          .map(_asMap)
          .where((item) => item.isNotEmpty)
          .toList();

      if (items.isEmpty) continue;

      final name = _safeText(
        cat['name'] ?? cat['title'] ?? cat['category'] ?? cat['category_name'],
        fallback: _categoryNameFromItem(items.first),
      );

      final icon = _safeImage(
        cat['image'] ??
            cat['icon'] ??
            cat['category_image'] ??
            items.first['image'] ??
            items.first['icon'] ??
            items.first['imogi_image'] ??
            items.first['emoji_image'],
      );

      list.add(
        _ImogiCategory(
          name: name,
          icon: icon,
          items: items,
          priority: _priority(name),
        ),
      );
    }

    list.sort((a, b) => a.priority.compareTo(b.priority));

    _categories
      ..clear()
      ..addAll(list);

    if (_selectedIndex >= _categories.length) _selectedIndex = 0;
    _saveMemoryCategories();
  }

  dynamic _extractResponseList(dynamic responseData) {
    final root = _asMap(responseData);
    return root['data'] ??
        root['imogies'] ??
        root['emojis'] ??
        root['items'] ??
        root['categories'] ??
        responseData;
  }

  /// Fast open: আগে controller cache থেকে show করবে.
  /// Cache না থাকলে shimmer show করবে.
  Future<void> _loadImogies() async {
    try {
      final cachedList = _readCachedImogiList();

      if (cachedList.isNotEmpty) {
        final cachedFirst = _asMap(cachedList.first);
        final cachedHasNestedItems = cachedFirst.containsKey('imogies') ||
            cachedFirst.containsKey('imogi') ||
            cachedFirst.containsKey('emojis') ||
            cachedFirst.containsKey('emoji') ||
            cachedFirst.containsKey('items') ||
            cachedFirst.containsKey('list');

        if (cachedHasNestedItems) {
          _groupCategoryList(cachedList);
        } else {
          _groupFlatList(cachedList);
        }

        if (mounted) {
          setState(() => _loading = false);
        }
      } else if (_categories.isEmpty) {
        if (mounted) {
          setState(() => _loading = true);
        }
      }

      final dio = controller.dio is Dio ? controller.dio as Dio : Dio();

      /// Your API endpoint: api/imogi_list
      /// kMainUrl usually already contains /api, so final URL becomes:
      /// https://domain.com/api/imogi_list
      final url = '$kMainUrl/imogi_list';

      debugPrint('📤 IMOGI LIST URL => $url');

      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint('📥 IMOGI LIST STATUS => ${response.statusCode}');

      if (!(response.statusCode == 200 || response.statusCode == 201)) {
        if (mounted && _categories.isEmpty) {
          setState(() => _loading = false);
        }
        if (_categories.isEmpty) {
          Fluttertoast.showToast(msg: ('Imogi list load failed').appTr);
        }
        return;
      }

      final source = _extractResponseList(response.data);
      final rawList = _asList(source);

      _saveCacheToController(rawList);

      final first = rawList.isNotEmpty ? _asMap(rawList.first) : {};
      final hasNestedItems = first.containsKey('imogies') ||
          first.containsKey('imogi') ||
          first.containsKey('emojis') ||
          first.containsKey('emoji') ||
          first.containsKey('items') ||
          first.containsKey('list');

      if (hasNestedItems) {
        _groupCategoryList(rawList);
      } else {
        _groupFlatList(rawList);
      }

      if (mounted) {
        setState(() => _loading = false);
      }

      debugPrint('✅ Imogi category tabs => ${_categories.map((e) => e.name).toList()}');
    } catch (e) {
      debugPrint('❌ _loadImogies error: $e');
      if (mounted && _categories.isEmpty) {
        setState(() => _loading = false);
      }
      if (_categories.isEmpty) {
        Fluttertoast.showToast(msg: ('Imogi list load failed').appTr);
      }
    }
  }

  List<dynamic> _readCachedImogiList() {
    try {
      final raw = controller.imogiList;
      if (raw is List && raw.isNotEmpty) return List<dynamic>.from(raw);
      final value = raw?.value;
      if (value is List && value.isNotEmpty) return List<dynamic>.from(value);
    } catch (_) {}

    /// Nested category cache থাকলে flatten না করে original structure রাখি।
    /// এতে category name/icon হারায় না এবং প্রথমবারের tab layout-ও সঠিক থাকে।
    try {
      final raw = controller.imogiCategoryList;
      if (raw is List && raw.isNotEmpty) return List<dynamic>.from(raw);

      final value = raw?.value;
      if (value is List && value.isNotEmpty) return List<dynamic>.from(value);
    } catch (_) {}

    return <dynamic>[];
  }

  void _saveCacheToController(List<dynamic> rawList) {
    if (rawList.isEmpty) return;

    final first = _asMap(rawList.first);
    final hasNestedItems = first.containsKey('imogies') ||
        first.containsKey('imogi') ||
        first.containsKey('emojis') ||
        first.containsKey('emoji') ||
        first.containsKey('items') ||
        first.containsKey('list');

    try {
      if (hasNestedItems) {
        final categoryList = controller.imogiCategoryList;
        if (categoryList != null && categoryList is RxList) {
          categoryList.assignAll(rawList.map(_asMap).toList());
        }
      } else {
        final imogiList = controller.imogiList;
        if (imogiList != null && imogiList is RxList) {
          imogiList.assignAll(rawList.map(_asMap).toList());
        }
      }
    } catch (_) {}
  }

  Future<void> _sendImogi(Map<String, dynamic> item) async {
    if (_sending) return;

    final imogiId = _itemId(item);

    if (imogiId == 0) {
      Fluttertoast.showToast(msg: ('Invalid imogi').appTr);
      return;
    }

    _sending = true;

    try {
      final ok = await controller.sendLiveImogi(
        streamId: widget.streamId,
        imogiId: imogiId,
      );

      if (!mounted) return;

      /// loading UI nai. Success hole direct close.
      if (ok == true) {
        try {
          final ws = Get.find<WebsocketController>();
          final currentUser = controller.authController.userProfile.value.user;
          ws.showLocalImogiAnimation({
            'action_type': 'imogi_sent',
            'livestream_id': widget.streamId,
            'sender_id': currentUser?.id,
            'sender': {
              'id': currentUser?.id,
              'user_id': currentUser?.id,
              'name': currentUser?.name ?? ('User').appTr,
              'level': 0,
              'profile_image': '',
            },
            'imogi_id': imogiId,
            'imogi': item,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('⚠️ local imogi preview skipped: $e');
        }

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('❌ send imogi failed: $e');
      Fluttertoast.showToast(msg: ('Imogi send failed').appTr);
    } finally {
      _sending = false;
    }
  }

  Widget _shimmerBox({
    required double height,
    required double width,
    double radius = 12,
  }) {
    /// Heavy looping animation বাদ দেওয়া হয়েছে, তাই sheet দ্রুত build হয়
    /// এবং low-end phone-এও unnecessary repaint হয় না।
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildShimmerGrid(double width) {
    final crossAxisCount = width < 360 ? 5 : 6;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(top: 4),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .85,
            ),
            itemCount: crossAxisCount * 3,
            itemBuilder: (context, index) {
              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _shimmerBox(
                        height: 34,
                        width: 34,
                        radius: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _shimmerBox(
                    height: 8,
                    width: 34,
                    radius: 6,
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: const Color(0xFFE8EAEE),
        ),
        SizedBox(
          height: 54,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            itemBuilder: (context, index) {
              return Container(
                width: 52,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(9),
                child: _shimmerBox(
                  height: 30,
                  width: 30,
                  radius: 16,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;

    /// Emoji aro choto-choto.
    final crossAxisCount = width < 350
        ? 5
        : width < 430
        ? 6
        : 7;

    final selected = _categories.isEmpty ? null : _categories[_selectedIndex];

    return SafeArea(
      top: false,
      child: Container(
        height: (height * .40).clamp(300.0, 365.0),
        width: double.infinity,
        padding: EdgeInsets.only(
          left: width * .030,
          right: width * .030,
          top: 8,
          bottom: media.padding.bottom > 0 ? 6 : 10,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              width: 38,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.18),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            Expanded(
              child: _loading && _categories.isEmpty
                  ? _buildShimmerGrid(width)
                  : _categories.isEmpty
                  ? Center(
                child: Text(
                  ('No imogi found').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              )
                  : Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(top: 0),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: .82,
                      ),
                      itemCount: selected!.items.length,
                      itemBuilder: (context, index) {
                        final item = selected.items[index];
                        final image = _itemImage(item);
                        final name = _itemName(item);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _sendImogi(item),
                          child: Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: image.isEmpty
                                      ? Icon(
                                    Icons.emoji_emotions_rounded,
                                    color: Colors.black54,
                                    size: 28,
                                  )
                                      : CachedNetworkImage(
                                    imageUrl: image,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 128,
                                    memCacheHeight: 128,
                                    maxWidthDiskCache: 256,
                                    maxHeightDiskCache: 256,
                                    fadeInDuration: Duration.zero,
                                    placeholder:
                                        (_, __) => _shimmerBox(
                                      height: 28,
                                      width: 28,
                                      radius: 16,
                                    ),
                                    errorWidget:
                                        (_, __, ___) => Icon(
                                      Icons
                                          .emoji_emotions_rounded,
                                      color: Colors.black54,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: const Color(0xFFE8EAEE),
                  ),
                  SizedBox(
                    height: 54,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = index == _selectedIndex;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_selectedIndex == index) return;
                            setState(() => _selectedIndex = index);
                            _precacheVisibleImogies(index);
                          },
                          child: AnimatedContainer(
                            duration:
                            const Duration(milliseconds: 160),
                            width: 52,
                            margin: const EdgeInsets.only(right: 7),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF1F3F6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFDDE1E7)
                                    : Colors.transparent,
                              ),
                            ),
                            child: category.icon.isEmpty
                                ? Icon(
                              Icons.emoji_emotions_rounded,
                              color: isSelected
                                  ? const Color(0xFFFF4D91)
                                  : Colors.black54,
                              size: 25,
                            )
                                : CachedNetworkImage(
                              imageUrl: category.icon,
                              fit: BoxFit.contain,
                              memCacheWidth: 96,
                              memCacheHeight: 96,
                              maxWidthDiskCache: 192,
                              maxHeightDiskCache: 192,
                              fadeInDuration: Duration.zero,
                              placeholder: (_, __) =>
                                  _shimmerBox(
                                    height: 25,
                                    width: 25,
                                    radius: 14,
                                  ),
                              errorWidget: (_, __, ___) =>
                                  Icon(
                                    Icons.emoji_emotions_rounded,
                                    color: isSelected
                                        ? const Color(0xFFFF4D91)
                                        : Colors.black54,
                                    size: 25,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImogiCategory {
  final String name;
  String icon;
  final List<Map<String, dynamic>> items;
  final int priority;

  _ImogiCategory({
    required this.name,
    required this.icon,
    required this.items,
    required this.priority,
  });
}
