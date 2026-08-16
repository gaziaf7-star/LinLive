/// Normalized, room-safe view of the VIP data returned with a user.
///
/// Privileges are never inferred from a VIP/SVIP level. Every capability is
/// read from the backend boolean flags and defaults to false.
class VipPrivileges {
  const VipPrivileges({
    this.hasActiveVip = false,
    this.vipId = 0,
    this.antiCommentMute = false,
    this.antiKickBan = false,
    this.antiBlock = false,
    this.invisible = false,
    this.vipGift = false,
    this.vipEmoji = false,
    this.gifProfilePic = false,
    this.vipSet = false,
    this.entryBanner = false,
    this.colorfulChat = false,
    this.colorfulProfile = false,
    this.vipBadge = false,
    this.colorfulProfileEnabled = true,
    this.vipTitle = '',
    this.vipType = '',
    this.vipFrame = '',
  });

  final bool hasActiveVip;
  final int vipId;
  final bool antiCommentMute;
  final bool antiKickBan;
  final bool antiBlock;
  final bool invisible;
  final bool vipGift;
  final bool vipEmoji;
  final bool gifProfilePic;
  final bool vipSet;
  final bool entryBanner;
  final bool colorfulChat;
  final bool colorfulProfile;
  final bool vipBadge;
  final bool colorfulProfileEnabled;
  final String vipTitle;
  final String vipType;
  final String vipFrame;

  bool get effectiveColorfulProfile =>
      hasActiveVip && colorfulProfile && colorfulProfileEnabled;
  bool get hasVip => hasActiveVip;
  bool get canUseVipGift => vipGift;
  bool get canUseVipEmoji => vipEmoji;
  bool get hasEntryBanner => entryBanner;
  bool get hasColorfulChat => colorfulChat;
  bool get hasColorfulProfile => colorfulProfile;
  bool get hasVipBadge => vipBadge;
  bool get hasGifProfilePic => gifProfilePic;
  bool get hasVipSet => vipSet;
  bool get hasAntiCommentMute => antiCommentMute;
  bool get hasAntiKickBan => antiKickBan;
  bool get hasAntiBlock => antiBlock;
  bool get isInvisible => invisible;

  static const VipPrivileges none = VipPrivileges();

  factory VipPrivileges.from(dynamic source) {
    final root = _map(source);
    if (root.isEmpty) return none;

    final user = _firstMap(<dynamic>[
      root['user'],
      root['sender'],
      root['viewer'],
      root['caller'],
      root['target_user'],
      root['viewer_data'],
      root,
    ]);
    final nestedUser = _firstMap(<dynamic>[
      user['user'],
      user['sender'],
      user['viewer'],
      user['caller'],
      user,
    ]);

    final history = _firstMap(<dynamic>[
      nestedUser['vip_purchase_history'],
      nestedUser['vipPurchaseHistory'],
      user['vip_purchase_history'],
      user['vipPurchaseHistory'],
      root['vip_purchase_history'],
      root['vipPurchaseHistory'],
      root['active_vip'],
      root['activeVip'],
    ]);
    final package = _firstMap(<dynamic>[
      history['package'],
      history['vip_package'],
      nestedUser['vip_package'],
      root['vip_package'],
    ]);
    final vip = _firstMap(<dynamic>[
      package['vip_vvip'],
      package['vipVvip'],
      package['vip'],
      history['vip_vvip'],
      history['vipVvip'],
      nestedUser['vip_vvip'],
      root['vip_vvip'],
    ]);
    final privilegeMap = _firstMap(<dynamic>[
      vip['privileges'],
      package['privileges'],
      history['privileges'],
      nestedUser['vip_privileges'],
      nestedUser['privileges'],
      root['vip_privileges'],
      root['privileges'],
    ]);
    if (history.isEmpty &&
        package.isEmpty &&
        vip.isEmpty &&
        privilegeMap.isEmpty) {
      return none;
    }

    final bool active = _activeVip(
      history: history,
      package: package,
      vip: vip,
      root: root,
      hasPrivilegePayload: privilegeMap.isNotEmpty,
    );
    if (!active) return none;

    final settings = _firstMap(<dynamic>[
      history['user_settings'],
      history['userSettings'],
      nestedUser['vip_user_settings'],
      nestedUser['user_settings'],
      root['vip_user_settings'],
    ]);

    bool packageFlag(String key) => _bool(privilegeMap[key]);
    bool effectiveFlag(String key) => packageFlag(key) && _bool(settings[key]);

    return VipPrivileges(
      hasActiveVip: true,
      vipId: _int(vip['id'] ?? vip['vip_id'] ?? package['vip_id']),
      antiCommentMute: packageFlag('anti_comment_mute'),
      antiKickBan: packageFlag('anti_kick_ban'),
      antiBlock: packageFlag('anti_block'),
      invisible: packageFlag('invisible'),
      vipGift: effectiveFlag('vip_gift'),
      vipEmoji: effectiveFlag('vip_emoji'),
      gifProfilePic: packageFlag('gif_profile_pic'),
      vipSet: effectiveFlag('vip_set'),
      entryBanner: effectiveFlag('entry_banner'),
      colorfulChat: effectiveFlag('colorful_chat'),
      colorfulProfile: effectiveFlag('colorful_profile'),
      vipBadge: packageFlag('vip_badge'),
      colorfulProfileEnabled: effectiveFlag('colorful_profile'),
      vipTitle: _text(vip['title'] ?? package['title'] ?? history['vip_type']),
      vipType: _text(vip['type'] ?? history['vip_type']),
      vipFrame: _text(vip['frame'] ?? vip['frame_url']),
    );
  }

  static bool _activeVip({
    required Map<String, dynamic> history,
    required Map<String, dynamic> package,
    required Map<String, dynamic> vip,
    required Map<String, dynamic> root,
    required bool hasPrivilegePayload,
  }) {
    final explicit = _first(<dynamic>[
      history['is_active'],
      history['active'],
      root['has_active_vip'],
      root['vip_active'],
      package['is_active'],
    ]);
    if (explicit != null) return _bool(explicit);

    final status = _text(
      history['status'] ?? package['status'] ?? vip['status'],
    ).toLowerCase();
    if (<String>{
      '0',
      'false',
      'expired',
      'inactive',
      'cancelled',
      'canceled',
      'disabled',
    }.contains(status)) {
      return false;
    }

    final expiryText = _text(
      history['expires_at'] ??
          history['expire_at'] ??
          history['expired_at'] ??
          history['end_date'] ??
          history['expiry_date'] ??
          root['vip_expires_at'],
    );
    if (expiryText.isNotEmpty) {
      final expiry = DateTime.tryParse(expiryText);
      if (expiry != null && !expiry.isAfter(DateTime.now())) return false;
    }

    // A singular vip_purchase_history/compact privilege object is the current
    // backend relation. Explicit inactive/expired markers above always win.
    return history.isNotEmpty ||
        package.isNotEmpty ||
        vip.isNotEmpty ||
        hasPrivilegePayload;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _firstMap(Iterable<dynamic> values) {
    for (final value in values) {
      final map = _map(value);
      if (map.isNotEmpty) return map;
    }
    return <String, dynamic>{};
  }

  static dynamic _first(Iterable<dynamic> values) {
    for (final value in values) {
      if (value != null && _text(value).toLowerCase() != 'null') return value;
    }
    return null;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = _text(value).toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_text(value)) ?? 0;
  }

  static String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }
}
