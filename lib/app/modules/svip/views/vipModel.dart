class VipHelpers {
  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static bool toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value == 1;
    final text = value.toString().toLowerCase().trim();
    if (text == '0' || text == 'false' || text == 'inactive' || text == 'no' || text == 'off') {
      return false;
    }
    return text == '1' ||
        text == 'true' ||
        text == 'active' ||
        text == 'yes' ||
        text == 'on' ||
        fallback;
  }

  static String toStr(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.toLowerCase() == 'null') return fallback;
    return text;
  }

  static String firstStr(
      Map<String, dynamic> map,
      List<String> keys, {
        String fallback = '',
      }) {
    for (final key in keys) {
      final value = toStr(map[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String ext(String url) {
    if (url.trim().isEmpty) return '';
    final clean = Uri.tryParse(url)?.path ?? url;
    final parts = clean.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase().trim();
  }
}

class VipAssetItem {
  final int id;
  final String name;
  final String type;
  final String asset;
  final String assetUrl;
  final String rawPath;
  final String showImage;
  final String showImageUrl;

  VipAssetItem({
    required this.id,
    required this.name,
    required this.type,
    required this.asset,
    required this.assetUrl,
    required this.rawPath,
    this.showImage = '',
    this.showImageUrl = '',
  });

  factory VipAssetItem.fromJson(dynamic value) {
    final map = VipHelpers.asMap(value);
    final url = VipHelpers.firstStr(map, [
      'asset_url',
      'url',
      'full_url',
      'image_url',
      'file_url',
      'assetUrl',
    ]);
    final raw = VipHelpers.firstStr(map, [
      'asset',
      'path',
      'file',
      'image',
      'raw_path',
    ]);
    final showUrl = VipHelpers.firstStr(map, [
      'show_image_url',
      'showImageUrl',
      'preview_url',
      'previewUrl',
      'thumbnail_url',
      'thumb_url',
    ]);
    final showRaw = VipHelpers.firstStr(map, [
      'show_image',
      'showImage',
      'preview',
      'thumbnail',
      'thumb',
    ]);

    return VipAssetItem(
      id: VipHelpers.toInt(map['id']),
      name: VipHelpers.firstStr(map, ['name', 'title'], fallback: 'VIP Asset'),
      type: VipHelpers.firstStr(map, ['type', 'asset_type'], fallback: 'Vip'),
      asset: raw,
      assetUrl: url.isNotEmpty ? url : raw,
      rawPath: raw,
      showImage: showRaw,
      showImageUrl: showUrl.isNotEmpty ? showUrl : showRaw,
    );
  }

  String get previewUrl {
    if (showImageUrl.isNotEmpty) return showImageUrl;
    if (showImage.isNotEmpty) return showImage;
    if (assetUrl.isNotEmpty) return assetUrl;
    return asset;
  }

  String get playUrl => assetUrl.isNotEmpty ? assetUrl : asset;

  String get extension => VipHelpers.ext(playUrl.isNotEmpty ? playUrl : previewUrl);
  String get previewExtension => VipHelpers.ext(previewUrl);

  bool get isSvga => extension == 'svga';
  bool get previewIsSvga => previewExtension == 'svga';
}

class VipPackageItem {
  final int id;
  final int vipId;
  final String mappingKey;
  final int vipLevelNo;
  final int sortOrder;
  final int day;
  final double price;
  final bool status;
  final VipLevel? vipLevel;

  VipPackageItem({
    required this.id,
    required this.vipId,
    required this.mappingKey,
    required this.vipLevelNo,
    required this.sortOrder,
    required this.day,
    required this.price,
    required this.status,
    this.vipLevel,
  });

  factory VipPackageItem.fromJson(
      dynamic value, {
        int fallbackVipId = 0,
        int fallbackVipLevelNo = 0,
      }) {
    final map = VipHelpers.asMap(value);
    final levelMap = map['vip_level'] ?? map['vipVvip'] ?? map['vip_vvip'] ?? map['vip'];
    final id = VipHelpers.toInt(map['package_id'] ?? map['id']);
    final vipId = VipHelpers.toInt(map['vip_id'], fallback: fallbackVipId);
    final mappingKey = VipHelpers.firstStr(
      map,
      ['mapping_key', 'package_mapping_key'],
      fallback: vipId > 0 && id > 0 ? '$vipId:$id' : '',
    );

    return VipPackageItem(
      id: id,
      vipId: vipId,
      mappingKey: mappingKey,
      vipLevelNo: VipHelpers.toInt(
        map['vip_level_no'],
        fallback: fallbackVipLevelNo,
      ),
      sortOrder: VipHelpers.toInt(map['vip_sort_order'] ?? map['sort_order']),
      day: VipHelpers.toInt(map['day']),
      price: VipHelpers.toDouble(map['price']),
      status: VipHelpers.toBool(map['status'], fallback: true),
      vipLevel: levelMap == null ? null : VipLevel.fromJson(levelMap),
    );
  }

  String get priceText {
    if (price == price.roundToDouble()) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }
}

class VipLevel {
  final int id;
  final int levelNo;
  final int sortOrder;
  final String title;
  final String type;
  final int requiredCoins;
  final String description;
  final bool status;
  final String chatBubbleColor;
  final String nameColor;
  final String frameUrl;
  final String badgeImageUrl;
  final String titleImageUrl;
  final String entryBannerImageUrl;
  final String profileCardImageUrl;
  final String nameImageUrl;
  final String chatBubbleImageUrl;
  final String frameShowImageUrl;
  final String badgeImageShowImageUrl;
  final String titleImageShowImageUrl;
  final String entryBannerImageShowImageUrl;
  final String profileCardImageShowImageUrl;
  final String nameImageShowImageUrl;
  final String chatBubbleImageShowImageUrl;
  final Map<String, dynamic> privileges;
  final List<VipAssetItem> selectedAssets;
  final List<VipAssetItem> assets;
  final List<VipPackageItem> packages;
  final Map<String, dynamic> raw;

  VipLevel({
    required this.id,
    required this.levelNo,
    required this.sortOrder,
    required this.title,
    required this.type,
    required this.requiredCoins,
    required this.description,
    required this.status,
    required this.chatBubbleColor,
    required this.nameColor,
    required this.frameUrl,
    required this.badgeImageUrl,
    required this.titleImageUrl,
    required this.entryBannerImageUrl,
    required this.profileCardImageUrl,
    this.nameImageUrl = '',
    this.chatBubbleImageUrl = '',
    this.frameShowImageUrl = '',
    this.badgeImageShowImageUrl = '',
    this.titleImageShowImageUrl = '',
    this.entryBannerImageShowImageUrl = '',
    this.profileCardImageShowImageUrl = '',
    this.nameImageShowImageUrl = '',
    this.chatBubbleImageShowImageUrl = '',
    required this.privileges,
    required this.selectedAssets,
    required this.assets,
    required this.packages,
    this.raw = const <String, dynamic>{},
  });

  factory VipLevel.fromJson(dynamic value) {
    final map = VipHelpers.asMap(value);
    final id = VipHelpers.toInt(map['vip_id'] ?? map['id']);
    final levelNo = VipHelpers.toInt(
      map['vip_level_no'] ?? map['level_no'] ?? map['level'],
      fallback: 1,
    );
    final rawPrivileges = map['privileges'];
    final privilegeMap = rawPrivileges is Map
        ? Map<String, dynamic>.from(rawPrivileges)
        : <String, dynamic>{};

    final selectedList = VipHelpers.asList(map['selected_assets'])
        .map(VipAssetItem.fromJson)
        .toList();
    final assetsList = VipHelpers.asList(map['assets'])
        .map(VipAssetItem.fromJson)
        .toList();
    final packagesList = VipHelpers.asList(map['packages'])
        .map(
          (e) => VipPackageItem.fromJson(
        e,
        fallbackVipId: id,
        fallbackVipLevelNo: levelNo,
      ),
    )
        .where((item) => item.id > 0 && item.vipId > 0 && item.status)
        .toList()
      ..sort((a, b) {
        final orderA = a.sortOrder > 0 ? a.sortOrder : a.day;
        final orderB = b.sortOrder > 0 ? b.sortOrder : b.day;
        return orderA.compareTo(orderB);
      });

    return VipLevel(
      id: id,
      levelNo: levelNo,
      sortOrder: VipHelpers.toInt(map['vip_sort_order'] ?? map['sort_order']),
      title: VipHelpers.firstStr(map, ['title', 'name'], fallback: 'VIP'),
      type: VipHelpers.firstStr(map, ['type', 'vip_type'], fallback: 'vip'),
      requiredCoins: VipHelpers.toInt(map['required_coins'] ?? map['price']),
      description: VipHelpers.toStr(map['description']),
      status: VipHelpers.toBool(map['status'], fallback: true),
      chatBubbleColor: VipHelpers.toStr(
        map['chat_bubble_color'],
        fallback: '#EC4899',
      ),
      nameColor: VipHelpers.toStr(map['name_color'], fallback: '#BE185D'),
      frameUrl: VipHelpers.firstStr(map, ['frame_url', 'frameUrl', 'frame']),
      badgeImageUrl: VipHelpers.firstStr(map, [
        'badge_image_url',
        'badgeImageUrl',
        'badge_url',
        'badge_image',
      ]),
      titleImageUrl: VipHelpers.firstStr(map, [
        'title_image_url',
        'titleImageUrl',
        'title_url',
        'title_image',
      ]),
      entryBannerImageUrl: VipHelpers.firstStr(map, [
        'entry_banner_image_url',
        'entryBannerImageUrl',
        'entry_url',
        'entry_banner_image',
      ]),
      profileCardImageUrl: VipHelpers.firstStr(map, [
        'profile_card_image_url',
        'profileCardImageUrl',
        'profile_card_url',
        'profile_card_image',
      ]),
      nameImageUrl: VipHelpers.firstStr(map, [
        'name_image_url',
        'nameImageUrl',
        'name_url',
        'name_image',
      ]),
      chatBubbleImageUrl: VipHelpers.firstStr(map, [
        'chat_bubble_image_url',
        'chatBubbleImageUrl',
        'chat_bubble_url',
        'chat_bubble_image',
      ]),
      frameShowImageUrl: VipHelpers.firstStr(map, [
        'frame_show_image_url',
        'frameShowImageUrl',
        'frame_show_image',
      ]),
      badgeImageShowImageUrl: VipHelpers.firstStr(map, [
        'badge_image_show_image_url',
        'badgeImageShowImageUrl',
        'badge_image_show_image',
      ]),
      titleImageShowImageUrl: VipHelpers.firstStr(map, [
        'title_image_show_image_url',
        'titleImageShowImageUrl',
        'title_image_show_image',
      ]),
      entryBannerImageShowImageUrl: VipHelpers.firstStr(map, [
        'entry_banner_image_show_image_url',
        'entryBannerImageShowImageUrl',
        'entry_banner_image_show_image',
      ]),
      profileCardImageShowImageUrl: VipHelpers.firstStr(map, [
        'profile_card_image_show_image_url',
        'profileCardImageShowImageUrl',
        'profile_card_image_show_image',
      ]),
      nameImageShowImageUrl: VipHelpers.firstStr(map, [
        'name_image_show_image_url',
        'nameImageShowImageUrl',
        'name_image_show_image',
      ]),
      chatBubbleImageShowImageUrl: VipHelpers.firstStr(map, [
        'chat_bubble_image_show_image_url',
        'chatBubbleImageShowImageUrl',
        'chat_bubble_image_show_image',
      ]),
      privileges: privilegeMap,
      selectedAssets: selectedList,
      assets: assetsList,
      packages: packagesList,
      raw: map,
    );
  }

  String get displayTitle => title.trim().isEmpty ? type.toUpperCase() : title;

  /// True when this level belongs to the SVIP tier rather than the regular
  /// VIP tier. The `/vip/levels` API returns both groups in one flat list,
  /// and it does not always keep `type` unique between them (an SVIP record
  /// can still carry a `vip7`-style type), so the human-readable title is
  /// checked first as the most reliable signal, with `type` as a backup.
  bool get isSvipTier {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedType = type.trim().toLowerCase();
    return normalizedTitle.startsWith('svip') || normalizedType.startsWith('svip');
  }

  String get mainMediaUrl {
    if (framePreviewUrl.isNotEmpty) return framePreviewUrl;
    if (profileCardPreviewUrl.isNotEmpty) return profileCardPreviewUrl;
    if (badgePreviewUrl.isNotEmpty) return badgePreviewUrl;
    if (titlePreviewUrl.isNotEmpty) return titlePreviewUrl;
    if (entryBannerPreviewUrl.isNotEmpty) return entryBannerPreviewUrl;
    if (allAssets.isNotEmpty) return allAssets.first.previewUrl;
    return '';
  }

  String get mainPlayUrl {
    if (frameUrl.isNotEmpty) return frameUrl;
    if (profileCardImageUrl.isNotEmpty) return profileCardImageUrl;
    if (badgeImageUrl.isNotEmpty) return badgeImageUrl;
    if (titleImageUrl.isNotEmpty) return titleImageUrl;
    if (entryBannerImageUrl.isNotEmpty) return entryBannerImageUrl;
    if (allAssets.isNotEmpty) return allAssets.first.playUrl;
    return '';
  }

  String get framePreviewUrl => frameShowImageUrl.isNotEmpty ? frameShowImageUrl : frameUrl;
  String get framePlayUrl => frameUrl.isNotEmpty ? frameUrl : frameShowImageUrl;
  String get badgePreviewUrl => badgeImageShowImageUrl.isNotEmpty ? badgeImageShowImageUrl : badgeImageUrl;
  String get badgePlayUrl => badgeImageUrl.isNotEmpty ? badgeImageUrl : badgeImageShowImageUrl;
  String get titlePreviewUrl => titleImageShowImageUrl.isNotEmpty ? titleImageShowImageUrl : titleImageUrl;
  String get titlePlayUrl => titleImageUrl.isNotEmpty ? titleImageUrl : titleImageShowImageUrl;
  String get entryBannerPreviewUrl => entryBannerImageShowImageUrl.isNotEmpty
      ? entryBannerImageShowImageUrl
      : entryBannerImageUrl;
  String get entryBannerPlayUrl => entryBannerImageUrl.isNotEmpty
      ? entryBannerImageUrl
      : entryBannerImageShowImageUrl;
  String get profileCardPreviewUrl => profileCardImageShowImageUrl.isNotEmpty
      ? profileCardImageShowImageUrl
      : profileCardImageUrl;
  String get profileCardPlayUrl => profileCardImageUrl.isNotEmpty
      ? profileCardImageUrl
      : profileCardImageShowImageUrl;
  String get namePreviewUrl =>
      nameImageShowImageUrl.isNotEmpty ? nameImageShowImageUrl : nameImageUrl;
  String get namePlayUrl =>
      nameImageUrl.isNotEmpty ? nameImageUrl : nameImageShowImageUrl;
  String get chatBubblePreviewUrl => chatBubbleImageShowImageUrl.isNotEmpty
      ? chatBubbleImageShowImageUrl
      : chatBubbleImageUrl;
  String get chatBubblePlayUrl => chatBubbleImageUrl.isNotEmpty
      ? chatBubbleImageUrl
      : chatBubbleImageShowImageUrl;

  List<VipAssetItem> get allAssets {
    final unique = <String, VipAssetItem>{};
    for (final item in [...selectedAssets, ...assets]) {
      unique['${item.id}_${item.previewUrl}_${item.playUrl}'] = item;
    }
    return unique.values.toList();
  }

  bool privilegeEnabled(String key) => VipHelpers.toBool(privileges[key]);
}

class VipSettingSwitchItem {
  final String key;
  final String label;
  final String description;
  final bool value;

  const VipSettingSwitchItem({
    required this.key,
    required this.label,
    required this.description,
    required this.value,
  });

  factory VipSettingSwitchItem.fromJson(
      dynamic value, {
        String fallbackKey = '',
        bool fallbackValue = false,
      }) {
    final map = VipHelpers.asMap(value);
    final key = VipHelpers.firstStr(map, ['key', 'name'], fallback: fallbackKey);
    return VipSettingSwitchItem(
      key: key,
      label: VipHelpers.firstStr(
        map,
        ['label', 'title'],
        fallback: VipSettingsScreenData.defaultLabel(key),
      ),
      description: VipHelpers.firstStr(
        map,
        ['description', 'subtitle', 'text'],
        fallback: VipSettingsScreenData.defaultDescription(key),
      ),
      value: VipHelpers.toBool(map['value'], fallback: fallbackValue),
    );
  }

  VipSettingSwitchItem copyWith({bool? value}) {
    return VipSettingSwitchItem(
      key: key,
      label: label,
      description: description,
      value: value ?? this.value,
    );
  }
}

class VipSettingsScreenData {
  static const supportedFeatureKeys = <String>[
    'hide_visitor_records',
    'hide_online_status',
    'avoid_disturbing',
  ];

  final VipSettingSwitchItem? masterSwitch;
  final List<VipSettingSwitchItem> switches;

  const VipSettingsScreenData({
    this.masterSwitch,
    this.switches = const <VipSettingSwitchItem>[],
  });

  factory VipSettingsScreenData.fromJson(
      dynamic value, {
        Map<String, dynamic> fallbackSettings = const <String, dynamic>{},
        bool fallbackMasterValue = true,
      }) {
    final map = VipHelpers.asMap(value);
    VipSettingSwitchItem? master;
    final rawMaster = map['master_switch'];
    if (rawMaster is Map) {
      master = VipSettingSwitchItem.fromJson(
        rawMaster,
        fallbackKey: 'is_enabled',
        fallbackValue: VipHelpers.toBool(
          fallbackSettings['is_enabled'],
          fallback: fallbackMasterValue,
        ),
      );
    } else if (map.containsKey('master_switch') || fallbackSettings.containsKey('is_enabled')) {
      master = VipSettingSwitchItem(
        key: 'is_enabled',
        label: defaultLabel('is_enabled'),
        description: defaultDescription('is_enabled'),
        value: VipHelpers.toBool(
          fallbackSettings['is_enabled'],
          fallback: fallbackMasterValue,
        ),
      );
    }

    final items = <VipSettingSwitchItem>[];
    final rawSwitches = map['switches'];
    if (rawSwitches is List) {
      for (final item in rawSwitches) {
        final parsed = VipSettingSwitchItem.fromJson(item);
        if (supportedFeatureKeys.contains(parsed.key)) items.add(parsed);
      }
    } else if (rawSwitches is Map) {
      for (final entry in rawSwitches.entries) {
        final itemMap = VipHelpers.asMap(entry.value);
        if (itemMap.isEmpty) {
          items.add(
            VipSettingSwitchItem(
              key: entry.key.toString(),
              label: defaultLabel(entry.key.toString()),
              description: defaultDescription(entry.key.toString()),
              value: VipHelpers.toBool(entry.value),
            ),
          );
        } else {
          items.add(
            VipSettingSwitchItem.fromJson(
              <String, dynamic>{...itemMap, 'key': entry.key.toString()},
            ),
          );
        }
      }
    }

    for (final key in supportedFeatureKeys) {
      if (items.any((item) => item.key == key)) continue;
      if (fallbackSettings.containsKey(key) || items.isEmpty) {
        items.add(
          VipSettingSwitchItem(
            key: key,
            label: defaultLabel(key),
            description: defaultDescription(key),
            value: VipHelpers.toBool(fallbackSettings[key]),
          ),
        );
      }
    }

    items.sort((a, b) {
      final aIndex = supportedFeatureKeys.indexOf(a.key);
      final bIndex = supportedFeatureKeys.indexOf(b.key);
      return aIndex.compareTo(bIndex);
    });

    return VipSettingsScreenData(masterSwitch: master, switches: items);
  }

  static String defaultLabel(String key) {
    switch (key) {
      case 'is_enabled':
        return 'VIP Active';
      case 'hide_visitor_records':
        return 'Hide visitor records';
      case 'hide_online_status':
        return 'Hide Online Status';
      case 'avoid_disturbing':
        return 'Avoid Disturbing';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  static String defaultDescription(String key) {
    switch (key) {
      case 'is_enabled':
        return 'Turn your current VIP privileges on or off without changing the expiry date.';
      case 'hide_visitor_records':
        return 'When you turn on the switch, no visiting records will be left when you visit other people’s profiles.';
      case 'hide_online_status':
        return 'When you enter a room, others will not be able to see you.';
      case 'avoid_disturbing':
        return 'After turning it on, only users I follow can chat with me privately.';
      default:
        return '';
    }
  }

  Map<String, bool> get values {
    final result = <String, bool>{};
    if (masterSwitch != null) result[masterSwitch!.key] = masterSwitch!.value;
    for (final item in switches) {
      result[item.key] = item.value;
    }
    return result;
  }
}

class VipPurchaseInfo {
  final int id;
  final int userId;
  final int vipId;
  final int vipLevelNo;
  final int packageId;
  final String packageMappingKey;
  final String vipType;
  final double price;
  final int day;
  final String status;
  final String startsAt;
  final String expiresAt;
  final int remainingDays;
  final bool isActive;
  final bool isEnabled;
  final bool vipEnabled;
  final List<int> backpackAssetIds;
  final Map<String, dynamic> settings;
  final VipSettingsScreenData settingsScreen;
  final VipLevel? vipLevel;
  final Map<String, dynamic> raw;

  VipPurchaseInfo({
    required this.id,
    required this.userId,
    required this.vipId,
    required this.packageId,
    required this.vipType,
    required this.price,
    required this.day,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.remainingDays,
    required this.isActive,
    this.vipLevelNo = 0,
    this.packageMappingKey = '',
    this.isEnabled = true,
    this.vipEnabled = true,
    this.backpackAssetIds = const <int>[],
    this.settings = const <String, dynamic>{},
    this.settingsScreen = const VipSettingsScreenData(),
    this.vipLevel,
    this.raw = const <String, dynamic>{},
  });

  factory VipPurchaseInfo.fromJson(dynamic value) {
    final map = VipHelpers.asMap(value);
    final levelRaw = map['vip_level'] ?? map['vip'] ?? map['vip_vvip'];
    final settingsMap = VipHelpers.asMap(map['settings']);
    final vipId = VipHelpers.toInt(map['vip_id']);
    final packageId = VipHelpers.toInt(map['package_id']);
    final isActive = VipHelpers.toBool(map['is_active'] ?? map['status']);
    final isEnabled = VipHelpers.toBool(
      map['is_enabled'] ?? settingsMap['is_enabled'],
      fallback: true,
    );
    final backpackAssetIds = VipHelpers.asList(map['backpack_asset_ids'])
        .map(VipHelpers.toInt)
        .where((id) => id > 0)
        .toList();

    return VipPurchaseInfo(
      id: VipHelpers.toInt(map['id']),
      userId: VipHelpers.toInt(map['user_id']),
      vipId: vipId,
      vipLevelNo: VipHelpers.toInt(
        map['vip_level_no'],
        fallback: levelRaw == null
            ? 0
            : VipHelpers.toInt(VipHelpers.asMap(levelRaw)['level_no']),
      ),
      packageId: packageId,
      packageMappingKey: VipHelpers.firstStr(
        map,
        ['package_mapping_key', 'mapping_key'],
        fallback: vipId > 0 && packageId > 0 ? '$vipId:$packageId' : '',
      ),
      vipType: VipHelpers.toStr(map['vip_type'] ?? map['type']),
      price: VipHelpers.toDouble(map['price']),
      day: VipHelpers.toInt(map['day']),
      status: VipHelpers.toStr(map['status']),
      startsAt: VipHelpers.toStr(map['starts_at']),
      expiresAt: VipHelpers.toStr(map['expires_at']),
      remainingDays: VipHelpers.toInt(map['remaining_days']),
      isActive: isActive,
      isEnabled: isEnabled,
      vipEnabled: VipHelpers.toBool(map['vip_enabled'], fallback: isEnabled),
      backpackAssetIds: backpackAssetIds,
      settings: settingsMap,
      settingsScreen: VipSettingsScreenData.fromJson(
        map['settings_screen'],
        fallbackSettings: <String, dynamic>{
          ...settingsMap,
          'is_enabled': isEnabled,
        },
        fallbackMasterValue: isEnabled,
      ),
      vipLevel: levelRaw == null ? null : VipLevel.fromJson(levelRaw),
      raw: map,
    );
  }
}