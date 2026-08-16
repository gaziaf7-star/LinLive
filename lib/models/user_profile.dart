num? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

String? _toStr(dynamic value) {
  if (value == null) return null;

  final text = value.toString();
  if (text == 'null') return null;

  return text;
}

bool? _toBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;

  final text = value.toString().toLowerCase();

  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;

  return null;
}


bool _matchesAccountRole(dynamic value, String expectedRole) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';

  if (normalized.isEmpty ||
      normalized == 'null' ||
      normalized == '0' ||
      normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'inactive' ||
      normalized == 'rejected' ||
      normalized == 'disabled') {
    return false;
  }

  return normalized == expectedRole ||
      normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'active' ||
      normalized == 'approved' ||
      normalized == 'accepted' ||
      normalized == 'enabled';
}

/* =========================================================
   ASSET MODELS
========================================================= */

class Asset {
  num? id;
  String? name;
  String? asset;
  String? price;
  String? type;

  Asset({
    this.id,
    this.name,
    this.asset,
    this.price,
    this.type,
  });

  Asset.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    name = _toStr(json['name']);
    asset = _toStr(json['asset']);
    price = _toStr(json['price']);
    type = _toStr(json['type']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'asset': asset,
      'price': price,
      'type': type,
    };
  }
}

class AssetHistories {
  num? id;
  num? userId;
  num? assetId;
  String? type;
  String? status;
  Asset? asset;

  AssetHistories({
    this.id,
    this.userId,
    this.assetId,
    this.type,
    this.status,
    this.asset,
  });

  AssetHistories.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    userId = _toNum(json['user_id']);
    assetId = _toNum(json['asset_id']);
    type = _toStr(json['type']);
    status = _toStr(json['status']);
    asset = json['asset'] != null ? Asset.fromJson(json['asset']) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'asset_id': assetId,
      'type': type,
      'status': status,
      'asset': asset?.toJson(),
    };
  }
}

class EntryHistories {
  num? id;
  num? userId;
  num? assetId;
  String? type;
  String? status;
  Asset? asset;

  EntryHistories({
    this.id,
    this.userId,
    this.assetId,
    this.type,
    this.status,
    this.asset,
  });

  EntryHistories.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    userId = _toNum(json['user_id']);
    assetId = _toNum(json['asset_id']);
    type = _toStr(json['type']);
    status = _toStr(json['status']);
    asset = json['asset'] != null ? Asset.fromJson(json['asset']) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'asset_id': assetId,
      'type': type,
      'status': status,
      'asset': asset?.toJson(),
    };
  }
}

class VipHistories {
  num? id;
  num? userId;
  num? assetId;
  String? type;
  String? status;
  Asset? asset;

  VipHistories({
    this.id,
    this.userId,
    this.assetId,
    this.type,
    this.status,
    this.asset,
  });

  VipHistories.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    userId = _toNum(json['user_id']);
    assetId = _toNum(json['asset_id']);
    type = _toStr(json['type']);
    status = _toStr(json['status']);
    asset = json['asset'] != null ? Asset.fromJson(json['asset']) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'asset_id': assetId,
      'type': type,
      'status': status,
      'asset': asset?.toJson(),
    };
  }
}

/* =========================================================
   CP DATA MODELS
========================================================= */

class CpGift {
  num? id;
  String? name;
  String? giftImage;
  String? giftImageUrl;
  num? coin;

  CpGift({
    this.id,
    this.name,
    this.giftImage,
    this.giftImageUrl,
    this.coin,
  });

  CpGift.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    name = _toStr(json['name']);
    giftImage = _toStr(json['gift_image']);
    giftImageUrl = _toStr(json['gift_image_url']);
    coin = _toNum(json['coin']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gift_image': giftImage,
      'gift_image_url': giftImageUrl,
      'coin': coin,
    };
  }
}

class CurrentCp {
  num? id;
  String? requestNo;
  num? senderId;
  num? receiverId;
  num? partnerId;
  num? giftListId;
  num? giftId;
  CpGift? gift;
  String? type;
  num? quantity;
  num? giftCoin;
  num? totalCoin;
  num? coin;
  String? status;
  String? message;
  String? createdAt;
  String? acceptedAt;

  CurrentCp({
    this.id,
    this.requestNo,
    this.senderId,
    this.receiverId,
    this.partnerId,
    this.giftListId,
    this.giftId,
    this.gift,
    this.type,
    this.quantity,
    this.giftCoin,
    this.totalCoin,
    this.coin,
    this.status,
    this.message,
    this.createdAt,
    this.acceptedAt,
  });

  CurrentCp.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    requestNo = _toStr(json['request_no']);
    senderId = _toNum(json['sender_id']);
    receiverId = _toNum(json['receiver_id']);
    partnerId = _toNum(json['partner_id']);
    giftListId = _toNum(json['gift_list_id']);
    giftId = _toNum(json['gift_id']);
    gift = json['gift'] != null ? CpGift.fromJson(json['gift']) : null;
    type = _toStr(json['type']);
    quantity = _toNum(json['quantity']);
    giftCoin = _toNum(json['gift_coin']);
    totalCoin = _toNum(json['total_coin']);
    coin = _toNum(json['coin']);
    status = _toStr(json['status']);
    message = _toStr(json['message']);
    createdAt = _toStr(json['created_at']);
    acceptedAt = _toStr(json['accepted_at']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_no': requestNo,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'partner_id': partnerId,
      'gift_list_id': giftListId,
      'gift_id': giftId,
      'gift': gift?.toJson(),
      'type': type,
      'quantity': quantity,
      'gift_coin': giftCoin,
      'total_coin': totalCoin,
      'coin': coin,
      'status': status,
      'message': message,
      'created_at': createdAt,
      'accepted_at': acceptedAt,
    };
  }
}

class CpUser {
  num? id;
  num? userId;
  String? agencyId;
  String? name;
  String? email;
  String? phone;
  num? level;
  String? gender;
  num? coins;
  String? callRate;
  num? earnedCoins;
  num? giftsCoins;
  String? userType;
  String? country;
  String? profileImage;
  String? profileImageUrl;

  CpUser({
    this.id,
    this.userId,
    this.agencyId,
    this.name,
    this.email,
    this.phone,
    this.level,
    this.gender,
    this.coins,
    this.callRate,
    this.earnedCoins,
    this.giftsCoins,
    this.userType,
    this.country,
    this.profileImage,
    this.profileImageUrl,
  });

  CpUser.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    userId = _toNum(json['user_id']);
    agencyId = _toStr(json['agency_id']);
    name = _toStr(json['name']);
    email = _toStr(json['email']);
    phone = _toStr(json['phone']);
    level = _toNum(json['level']);
    gender = _toStr(json['gender']);
    coins = _toNum(json['coins']);
    callRate = _toStr(json['call_rate']);
    earnedCoins = _toNum(json['earned_coins']);
    giftsCoins = _toNum(json['gifts_coins']);
    userType = _toStr(json['user_type']);
    country = _toStr(json['country']);
    profileImage = _toStr(json['profile_image']);
    profileImageUrl = _toStr(json['profile_image_url']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'agency_id': agencyId,
      'name': name,
      'email': email,
      'phone': phone,
      'level': level,
      'gender': gender,
      'coins': coins,
      'call_rate': callRate,
      'earned_coins': earnedCoins,
      'gifts_coins': giftsCoins,
      'user_type': userType,
      'country': country,
      'profile_image': profileImage,
      'profile_image_url': profileImageUrl,
    };
  }
}

class CpLevel {
  num? id;
  num? levelNo;
  String? title;
  num? requiredCoins;
  num? status;

  CpLevel({
    this.id,
    this.levelNo,
    this.title,
    this.requiredCoins,
    this.status,
  });

  CpLevel.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    levelNo = _toNum(json['level_no']);
    title = _toStr(json['title']);
    requiredCoins = _toNum(json['required_coins']);
    status = _toNum(json['status']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level_no': levelNo,
      'title': title,
      'required_coins': requiredCoins,
      'status': status,
    };
  }
}

class CpSummary {
  num? totalRequests;
  num? sentRequests;
  num? receivedRequests;
  num? pendingRequests;
  num? acceptedRequests;
  num? rejectedRequests;
  num? cancelledRequests;

  CpSummary({
    this.totalRequests,
    this.sentRequests,
    this.receivedRequests,
    this.pendingRequests,
    this.acceptedRequests,
    this.rejectedRequests,
    this.cancelledRequests,
  });

  CpSummary.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    totalRequests = _toNum(json['total_requests']);
    sentRequests = _toNum(json['sent_requests']);
    receivedRequests = _toNum(json['received_requests']);
    pendingRequests = _toNum(json['pending_requests']);
    acceptedRequests = _toNum(json['accepted_requests']);
    rejectedRequests = _toNum(json['rejected_requests']);
    cancelledRequests = _toNum(json['cancelled_requests']);
  }

  Map<String, dynamic> toJson() {
    return {
      'total_requests': totalRequests,
      'sent_requests': sentRequests,
      'received_requests': receivedRequests,
      'pending_requests': pendingRequests,
      'accepted_requests': acceptedRequests,
      'rejected_requests': rejectedRequests,
      'cancelled_requests': cancelledRequests,
    };
  }
}

class CpData {
  bool? hasCp;
  CurrentCp? currentCp;
  CpUser? cpPartner;
  CpUser? sender;
  CpUser? receiver;

  num? cpTotalCoins;
  CpLevel? cpLevel;
  CpLevel? cpNextLevel;
  num? cpProgressPercent;
  num? cpNeedMoreCoins;

  num? cpDays;
  String? cpSinceDate;
  String? cpSinceFullDate;

  CpSummary? summary;
  num? pendingSentCount;
  num? pendingReceivedCount;

  CpData({
    this.hasCp,
    this.currentCp,
    this.cpPartner,
    this.sender,
    this.receiver,
    this.cpTotalCoins,
    this.cpLevel,
    this.cpNextLevel,
    this.cpProgressPercent,
    this.cpNeedMoreCoins,
    this.cpDays,
    this.cpSinceDate,
    this.cpSinceFullDate,
    this.summary,
    this.pendingSentCount,
    this.pendingReceivedCount,
  });

  CpData.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    hasCp = _toBool(json['has_cp']);
    currentCp = json['current_cp'] != null ? CurrentCp.fromJson(json['current_cp']) : null;
    cpPartner = json['cp_partner'] != null ? CpUser.fromJson(json['cp_partner']) : null;
    sender = json['sender'] != null ? CpUser.fromJson(json['sender']) : null;
    receiver = json['receiver'] != null ? CpUser.fromJson(json['receiver']) : null;

    cpTotalCoins = _toNum(json['cp_total_coins']);
    cpLevel = json['cp_level'] != null ? CpLevel.fromJson(json['cp_level']) : null;
    cpNextLevel = json['cp_next_level'] != null ? CpLevel.fromJson(json['cp_next_level']) : null;
    cpProgressPercent = _toNum(json['cp_progress_percent']);
    cpNeedMoreCoins = _toNum(json['cp_need_more_coins']);

    cpDays = _toNum(json['cp_days']);
    cpSinceDate = _toStr(json['cp_since_date']);
    cpSinceFullDate = _toStr(json['cp_since_full_date']);

    summary = json['summary'] != null ? CpSummary.fromJson(json['summary']) : null;
    pendingSentCount = _toNum(json['pending_sent_count']);
    pendingReceivedCount = _toNum(json['pending_received_count']);
  }

  Map<String, dynamic> toJson() {
    return {
      'has_cp': hasCp,
      'current_cp': currentCp?.toJson(),
      'cp_partner': cpPartner?.toJson(),
      'sender': sender?.toJson(),
      'receiver': receiver?.toJson(),
      'cp_total_coins': cpTotalCoins,
      'cp_level': cpLevel?.toJson(),
      'cp_next_level': cpNextLevel?.toJson(),
      'cp_progress_percent': cpProgressPercent,
      'cp_need_more_coins': cpNeedMoreCoins,
      'cp_days': cpDays,
      'cp_since_date': cpSinceDate,
      'cp_since_full_date': cpSinceFullDate,
      'summary': summary?.toJson(),
      'pending_sent_count': pendingSentCount,
      'pending_received_count': pendingReceivedCount,
    };
  }
}

/* =========================================================
   USER MODEL
========================================================= */

class User {
  num? id;
  num? userId;
  String? uniqueId;

  String? agencyId;
  String? hostAgencyId;

  String? name;
  String? level;
  String? email;
  String? googleId;
  String? phone;
  String? whatsappNumber;
  String? address;
  String? gender;
  String? dateofbirth;
  String? language;

  String? userType;
  String? permisiononerid;
  String? permisioncountry;
  String? agencyPermisioncountry;
  String? agencyPermisiononerid;

  String? agencyType;
  String? reselerType;
  String? hostType;
  String? hostPosition;
  String? designation;

  bool get isHostAccount => _matchesAccountRole(hostType, 'host');

  bool get isAgencyAccount => _matchesAccountRole(agencyType, 'agency');

  String? balance;
  String? coins;
  String? levelCoins;
  String? staffCoins;
  String? callRate;
  String? earnedCoins;
  String? giftsCoins;

  String? profileImage;
  String? profileImageUrl;
  String? country;
  String? emailVerifiedAt;
  String? coverImages;
  String? profileLocked;
  String? status;
  String? unblockAt;

  String? tags;
  String? isOnline;
  String? callStatus;

  String? refferCode;
  String? refferBy;
  String? otp;

  String? lastActiveAt;
  String? createdAt;
  String? updatedAt;

  num? audioThemeId;
  String? levelImage;

  num? totalFollowers;
  num? totalFollowing;

  AssetHistories? assetHistories;
  EntryHistories? entryHistories;
  VipHistories? vipHistories;
  Map<String, dynamic>? vipPurchaseHistory;

  User({
    this.id,
    this.userId,
    this.uniqueId,
    this.agencyId,
    this.hostAgencyId,
    this.name,
    this.level,
    this.email,
    this.googleId,
    this.phone,
    this.whatsappNumber,
    this.address,
    this.gender,
    this.dateofbirth,
    this.language,
    this.userType,
    this.permisiononerid,
    this.permisioncountry,
    this.agencyPermisioncountry,
    this.agencyPermisiononerid,
    this.agencyType,
    this.reselerType,
    this.hostType,
    this.hostPosition,
    this.designation,
    this.balance,
    this.coins,
    this.levelCoins,
    this.staffCoins,
    this.callRate,
    this.earnedCoins,
    this.giftsCoins,
    this.profileImage,
    this.profileImageUrl,
    this.country,
    this.emailVerifiedAt,
    this.coverImages,
    this.profileLocked,
    this.status,
    this.unblockAt,
    this.tags,
    this.isOnline,
    this.callStatus,
    this.refferCode,
    this.refferBy,
    this.otp,
    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
    this.audioThemeId,
    this.levelImage,
    this.totalFollowers,
    this.totalFollowing,
    this.assetHistories,
    this.entryHistories,
    this.vipHistories,
    this.vipPurchaseHistory,
  });

  User.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    id = _toNum(json['id']);
    userId = _toNum(json['user_id']);
    uniqueId = _toStr(json['unique_id']);

    agencyId = _toStr(json['agency_id']);
    hostAgencyId = _toStr(json['host_agency_id']);

    name = _toStr(json['name']);
    level = _toStr(json['level']);
    email = _toStr(json['email']);
    googleId = _toStr(json['google_id']);
    phone = _toStr(json['phone']);
    whatsappNumber = _toStr(json['whatsapp_number']);
    address = _toStr(json['address']);
    gender = _toStr(json['gender']);
    dateofbirth = _toStr(json['dateofbirth']);
    language = _toStr(json['language']);

    userType = _toStr(json['user_type']);
    permisiononerid = _toStr(json['permisiononerid']);
    permisioncountry = _toStr(json['permisioncountry']);
    agencyPermisioncountry = _toStr(json['agency_permisioncountry']);
    agencyPermisiononerid = _toStr(json['agency_permisiononerid']);

    agencyType = _toStr(json['agency_type']);
    reselerType = _toStr(json['reseler_type']);
    hostType = _toStr(json['host_type']);
    hostPosition = _toStr(json['host_position']);
    designation = _toStr(json['designation']);

    balance = _toStr(json['balance']);
    coins = _toStr(json['coins']);
    levelCoins = _toStr(json['level_coins']);
    staffCoins = _toStr(json['staff_coins']);
    callRate = _toStr(json['call_rate']);
    earnedCoins = _toStr(json['earned_coins']);
    giftsCoins = _toStr(json['gifts_coins']);

    profileImage = _toStr(json['profile_image']);
    profileImageUrl = _toStr(json['profile_image_url']);
    country = _toStr(json['country']);
    emailVerifiedAt = _toStr(json['email_verified_at']);
    coverImages = _toStr(json['cover_images']);
    profileLocked = _toStr(json['profile_locked']);
    status = _toStr(json['status']);
    unblockAt = _toStr(json['unblock_at']);

    tags = _toStr(json['tags']);
    isOnline = _toStr(json['is_online']);
    callStatus = _toStr(json['call_status']);

    refferCode = _toStr(json['reffer_code']);
    refferBy = _toStr(json['reffer_by']);
    otp = _toStr(json['otp']);

    lastActiveAt = _toStr(json['last_active_at']);
    createdAt = _toStr(json['created_at']);
    updatedAt = _toStr(json['updated_at']);

    audioThemeId = _toNum(json['audio_theme_id']);
    levelImage = _toStr(json['level_image']);

    totalFollowers = _toNum(json['total_followers']);
    totalFollowing = _toNum(json['total_following']);

    assetHistories = json['asset_histories'] != null
        ? AssetHistories.fromJson(json['asset_histories'])
        : null;

    entryHistories = json['entry_histories'] != null
        ? EntryHistories.fromJson(json['entry_histories'])
        : null;

    vipHistories = json['vip_histories'] != null
        ? VipHistories.fromJson(json['vip_histories'])
        : null;

    final rawVipPurchaseHistory = json['vip_purchase_history'];
    vipPurchaseHistory = rawVipPurchaseHistory is Map
        ? Map<String, dynamic>.from(rawVipPurchaseHistory)
        : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'unique_id': uniqueId,
      'agency_id': agencyId,
      'host_agency_id': hostAgencyId,
      'name': name,
      'level': level,
      'email': email,
      'google_id': googleId,
      'phone': phone,
      'whatsapp_number': whatsappNumber,
      'address': address,
      'gender': gender,
      'dateofbirth': dateofbirth,
      'language': language,
      'user_type': userType,
      'permisiononerid': permisiononerid,
      'permisioncountry': permisioncountry,
      'agency_permisioncountry': agencyPermisioncountry,
      'agency_permisiononerid': agencyPermisiononerid,
      'agency_type': agencyType,
      'reseler_type': reselerType,
      'host_type': hostType,
      'host_position': hostPosition,
      'designation': designation,
      'balance': balance,
      'coins': coins,
      'level_coins': levelCoins,
      'staff_coins': staffCoins,
      'call_rate': callRate,
      'earned_coins': earnedCoins,
      'gifts_coins': giftsCoins,
      'profile_image': profileImage,
      'profile_image_url': profileImageUrl,
      'country': country,
      'email_verified_at': emailVerifiedAt,
      'cover_images': coverImages,
      'profile_locked': profileLocked,
      'status': status,
      'unblock_at': unblockAt,
      'tags': tags,
      'is_online': isOnline,
      'call_status': callStatus,
      'reffer_code': refferCode,
      'reffer_by': refferBy,
      'otp': otp,
      'last_active_at': lastActiveAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'audio_theme_id': audioThemeId,
      'level_image': levelImage,
      'total_followers': totalFollowers,
      'total_following': totalFollowing,
      'asset_histories': assetHistories?.toJson(),
      'entry_histories': entryHistories?.toJson(),
      'vip_histories': vipHistories?.toJson(),
      'vip_purchase_history': vipPurchaseHistory,
    };
  }
}

/* =========================================================
   MAIN LOGIN / USER PROFILE RESPONSE MODEL
========================================================= */

class DeviceSession {
  num? deviceId;
  String? deviceUuid;
  bool? isBlocked;
  String? channel;
  String? privateChannel;
  String? event;
  num? loginId;

  DeviceSession({
    this.deviceId,
    this.deviceUuid,
    this.isBlocked,
    this.channel,
    this.privateChannel,
    this.event,
    this.loginId,
  });

  DeviceSession.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    deviceId = _toNum(json['device_id']);
    deviceUuid = _toStr(json['device_uuid']);
    isBlocked = _toBool(json['is_blocked']);
    channel = _toStr(json['channel']);
    privateChannel = _toStr(json['private_channel']);
    event = _toStr(json['event']);
    loginId = _toNum(json['login_id']);
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_uuid': deviceUuid,
      'is_blocked': isBlocked,
      'channel': channel,
      'private_channel': privateChannel,
      'event': event,
      'login_id': loginId,
    };
  }
}

class UserProfile {
  bool? success;
  String? message;
  String? token;

  CpData? cpData;
  User? user;

  num? totalFollowers;
  num? totalFollowing;

  AssetHistories? assetHistories;
  EntryHistories? entryHistories;
  VipHistories? vipHistories;
  DeviceSession? deviceSession;

  UserProfile({
    this.success,
    this.message,
    this.token,
    this.cpData,
    this.user,
    this.totalFollowers,
    this.totalFollowing,
    this.assetHistories,
    this.entryHistories,
    this.vipHistories,
    this.deviceSession,
  });

  UserProfile.fromJson(dynamic json) {
    if (json == null || json is! Map) return;

    success = _toBool(json['success']);
    message = _toStr(json['message']);
    token = _toStr(json['token']);
    deviceSession = json['device_session'] != null
        ? DeviceSession.fromJson(json['device_session'])
        : null;

    cpData = json['cp_data'] != null ? CpData.fromJson(json['cp_data']) : null;
    user = json['user'] != null ? User.fromJson(json['user']) : null;

    totalFollowers = _toNum(json['total_followers']) ?? user?.totalFollowers;
    totalFollowing = _toNum(json['total_following']) ?? user?.totalFollowing;

    assetHistories = json['asset_histories'] != null
        ? AssetHistories.fromJson(json['asset_histories'])
        : user?.assetHistories;

    entryHistories = json['entry_histories'] != null
        ? EntryHistories.fromJson(json['entry_histories'])
        : user?.entryHistories;

    vipHistories = json['vip_histories'] != null
        ? VipHistories.fromJson(json['vip_histories'])
        : user?.vipHistories;

    user?.totalFollowers = totalFollowers;
    user?.totalFollowing = totalFollowing;
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'token': token,
      'cp_data': cpData?.toJson(),
      'user': user?.toJson(),
      'total_followers': totalFollowers,
      'total_following': totalFollowing,
      'asset_histories': assetHistories?.toJson(),
      'entry_histories': entryHistories?.toJson(),
      'vip_histories': vipHistories?.toJson(),
      'device_session': deviceSession?.toJson(),
    };
  }
}
