class FamilyParse {
  const FamilyParse._();

  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? fallback;
  }

  static double toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? fallback;
  }

  static String toStr(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  static Map<String, dynamic> toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> toMapList(dynamic value) {
    if (value is List) {
      return value.map((e) => toMap(e)).where((e) => e.isNotEmpty).toList();
    }
    return <Map<String, dynamic>>[];
  }

  static String fullUrl(String? url, String baseUrl) {
    final value = toStr(url);
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (baseUrl.isEmpty) return value;
    if (value.startsWith('/')) return '$baseUrl$value';
    return '$baseUrl/$value';
  }
}

class FamilyModel {
  final int id;
  final String name;
  final String familyCode;
  final String description;
  final String notice;
  final String country;
  final String joinType;
  final int levelNo;
  final double points;
  final double coins;
  final int membersCount;
  final int memberLimit;
  final String logoUrl;
  final String coverUrl;
  final int ownerId;

  /// Ranking API owner object support.
  /// Example: owner.name, owner.profile_image_url, owner.level, owner.country
  final String ownerName;
  final String ownerProfileImageUrl;
  final int ownerLevel;
  final String ownerCountry;

  final String myMemberStatus;
  final String myRole;
  final String myRequestStatus;
  final List<FamilyMemberModel> members;
  final List<FamilyMemberModel> topContributors;
  final List<FamilyAnnouncementModel> announcements;

  const FamilyModel({
    this.id = 0,
    this.name = '',
    this.familyCode = '',
    this.description = '',
    this.notice = '',
    this.country = '',
    this.joinType = 'approval',
    this.levelNo = 1,
    this.points = 0,
    this.coins = 0,
    this.membersCount = 0,
    this.memberLimit = 50,
    this.logoUrl = '',
    this.coverUrl = '',
    this.ownerId = 0,
    this.ownerName = '',
    this.ownerProfileImageUrl = '',
    this.ownerLevel = 0,
    this.ownerCountry = '',
    this.myMemberStatus = '',
    this.myRole = '',
    this.myRequestStatus = '',
    this.members = const [],
    this.topContributors = const [],
    this.announcements = const [],
  });

  factory FamilyModel.fromJson(dynamic json, {String baseUrl = ''}) {
    final m = FamilyParse.toMap(json);
    final level = FamilyParse.toMap(m['level']);
    final stats = FamilyParse.toMap(m['stats']);
    final owner = FamilyParse.toMap(m['owner']);

    final logo = m['logo_url'] ?? m['logo'] ?? m['image'] ?? m['badge_url'];
    final cover = m['cover_url'] ?? m['cover'] ?? m['cover_image'];

    final ownerAvatar = m['owner_profile_image_url'] ??
        m['owner_avatar_url'] ??
        owner['profile_image_url'] ??
        owner['avatar_url'] ??
        owner['profile_image'] ??
        owner['image'];

    return FamilyModel(
      id: FamilyParse.toInt(m['id'] ?? m['family_id']),
      name: FamilyParse.toStr(m['name'] ?? m['family_name']),
      familyCode: FamilyParse.toStr(m['family_code'] ?? m['code'] ?? m['id_code']),
      description: FamilyParse.toStr(m['description']),
      notice: FamilyParse.toStr(m['notice'] ?? m['announcement']),
      country: FamilyParse.toStr(m['country']),
      joinType: FamilyParse.toStr(m['join_type'], fallback: 'approval'),
      levelNo: FamilyParse.toInt(
        m['level_no'] ?? level['level_no'] ?? level['level'] ?? m['level'],
        fallback: 1,
      ),
      points: FamilyParse.toDouble(m['points'] ?? stats['points']),
      coins: FamilyParse.toDouble(m['coins'] ?? stats['coins']),
      membersCount: FamilyParse.toInt(
        m['members_count'] ?? m['member_count'] ?? stats['members_count'],
      ),
      memberLimit: FamilyParse.toInt(
        m['member_limit'] ?? m['members_limit'] ?? m['limit'],
        fallback: 50,
      ),
      logoUrl: FamilyParse.fullUrl(logo?.toString(), baseUrl),
      coverUrl: FamilyParse.fullUrl(cover?.toString(), baseUrl),
      ownerId: FamilyParse.toInt(m['owner_id'] ?? owner['id'] ?? owner['user_id']),
      ownerName: FamilyParse.toStr(
        m['owner_name'] ?? owner['name'],
        fallback: 'Family Owner',
      ),
      ownerProfileImageUrl: FamilyParse.fullUrl(ownerAvatar?.toString(), baseUrl),
      ownerLevel: FamilyParse.toInt(m['owner_level'] ?? owner['level']),
      ownerCountry: FamilyParse.toStr(m['owner_country'] ?? owner['country']),
      myMemberStatus: FamilyParse.toStr(m['my_member_status']),
      myRole: FamilyParse.toStr(m['my_role']),
      myRequestStatus: FamilyParse.toStr(m['my_request_status']),
      members: FamilyParse.toMapList(m['members'])
          .map((e) => FamilyMemberModel.fromJson(e, baseUrl: baseUrl))
          .toList(),
      topContributors: FamilyParse.toMapList(m['top_contributors'] ?? m['contributors'])
          .map((e) => FamilyMemberModel.fromJson(e, baseUrl: baseUrl))
          .toList(),
      announcements: FamilyParse.toMapList(m['announcements'])
          .map((e) => FamilyAnnouncementModel.fromJson(e))
          .toList(),
    );
  }

  bool get isMember => myMemberStatus == 'accepted' || myRole.isNotEmpty;
  bool get canRequest =>
      myRequestStatus.isEmpty ||
          myRequestStatus == 'rejected' ||
          myRequestStatus == 'cancelled';
  bool get isPending => myRequestStatus == 'pending';
  String get memberText => '$membersCount/$memberLimit';
}

class FamilyMemberModel {
  final int id;
  final int userId;
  final String name;
  final String role;
  final double points;
  final double coins;
  final String avatarUrl;
  final String joinedAt;

  const FamilyMemberModel({
    this.id = 0,
    this.userId = 0,
    this.name = '',
    this.role = 'member',
    this.points = 0,
    this.coins = 0,
    this.avatarUrl = '',
    this.joinedAt = '',
  });

  factory FamilyMemberModel.fromJson(dynamic json, {String baseUrl = ''}) {
    final m = FamilyParse.toMap(json);
    final user = FamilyParse.toMap(m['user']);
    final profile = FamilyParse.toMap(m['profile']);
    final pivot = FamilyParse.toMap(m['pivot'] ?? m['membership']);
    final avatar = m['avatar_url'] ??
        m['profile_image_url'] ??
        m['profile_image'] ??
        user['profile_image_url'] ??
        user['avatar_url'] ??
        user['profile_image'] ??
        user['image'] ??
        profile['image'];

    return FamilyMemberModel(
      id: FamilyParse.toInt(
        m['member_id'] ?? m['family_member_id'] ?? m['pivot_id'] ?? pivot['id'] ?? m['id'],
      ),
      userId: FamilyParse.toInt(
        m['user_id'] ?? m['userId'] ?? user['id'] ?? user['user_id'] ?? pivot['user_id'],
      ),
      name: FamilyParse.toStr(
        m['name'] ?? user['name'] ?? profile['name'],
        fallback: 'Unknown User',
      ),
      role: FamilyParse.toStr(m['role'] ?? pivot['role'], fallback: 'member').toLowerCase(),
      points: FamilyParse.toDouble(m['points'] ?? m['family_points']),
      coins: FamilyParse.toDouble(m['coins'] ?? m['contribution_coins']),
      avatarUrl: FamilyParse.fullUrl(avatar?.toString(), baseUrl),
      joinedAt: FamilyParse.toStr(m['joined_at'] ?? m['created_at']),
    );
  }
}

class FamilyRequestModel {
  final int id;
  final int familyId;
  final int userId;
  final String status;
  final String message;
  final String userName;
  final String userAvatarUrl;
  final String createdAt;

  const FamilyRequestModel({
    this.id = 0,
    this.familyId = 0,
    this.userId = 0,
    this.status = '',
    this.message = '',
    this.userName = '',
    this.userAvatarUrl = '',
    this.createdAt = '',
  });

  factory FamilyRequestModel.fromJson(dynamic json, {String baseUrl = ''}) {
    final m = FamilyParse.toMap(json);
    final user = FamilyParse.toMap(m['user']);
    final avatar = m['user_avatar_url'] ??
        user['profile_image_url'] ??
        user['avatar_url'] ??
        user['profile_image'] ??
        user['image'];

    return FamilyRequestModel(
      id: FamilyParse.toInt(m['id'] ?? m['request_id']),
      familyId: FamilyParse.toInt(m['family_id']),
      userId: FamilyParse.toInt(m['user_id'] ?? user['id']),
      status: FamilyParse.toStr(m['status']),
      message: FamilyParse.toStr(m['message']),
      userName: FamilyParse.toStr(
        m['user_name'] ?? user['name'],
        fallback: 'Unknown User',
      ),
      userAvatarUrl: FamilyParse.fullUrl(avatar?.toString(), baseUrl),
      createdAt: FamilyParse.toStr(m['created_at']),
    );
  }
}

class FamilyAnnouncementModel {
  final int id;
  final String title;
  final String message;
  final String createdAt;

  const FamilyAnnouncementModel({
    this.id = 0,
    this.title = '',
    this.message = '',
    this.createdAt = '',
  });

  factory FamilyAnnouncementModel.fromJson(dynamic json) {
    final m = FamilyParse.toMap(json);
    return FamilyAnnouncementModel(
      id: FamilyParse.toInt(m['id']),
      title: FamilyParse.toStr(m['title'], fallback: 'Announcement'),
      message: FamilyParse.toStr(m['message'] ?? m['body'] ?? m['notice']),
      createdAt: FamilyParse.toStr(m['created_at']),
    );
  }
}

class FamilyLevelModel {
  final int id;
  final int levelNo;
  final double requiredPoints;
  final String name;
  final String badgeUrl;

  const FamilyLevelModel({
    this.id = 0,
    this.levelNo = 1,
    this.requiredPoints = 0,
    this.name = '',
    this.badgeUrl = '',
  });

  factory FamilyLevelModel.fromJson(dynamic json, {String baseUrl = ''}) {
    final m = FamilyParse.toMap(json);
    final badge = m['badge_url'] ?? m['image'] ?? m['icon'];
    return FamilyLevelModel(
      id: FamilyParse.toInt(m['id']),
      levelNo: FamilyParse.toInt(m['level_no'] ?? m['level'], fallback: 1),
      requiredPoints: FamilyParse.toDouble(m['required_points'] ?? m['points']),
      name: FamilyParse.toStr(m['name'] ?? m['title']),
      badgeUrl: FamilyParse.fullUrl(badge?.toString(), baseUrl),
    );
  }
}

class FamilyBadgeModel {
  final int id;
  final String name;
  final String imageUrl;
  final int levelNo;

  const FamilyBadgeModel({
    this.id = 0,
    this.name = '',
    this.imageUrl = '',
    this.levelNo = 0,
  });

  factory FamilyBadgeModel.fromJson(dynamic json, {String baseUrl = ''}) {
    final m = FamilyParse.toMap(json);
    final image = m['image_url'] ?? m['image'] ?? m['badge_url'];
    return FamilyBadgeModel(
      id: FamilyParse.toInt(m['id']),
      name: FamilyParse.toStr(m['name'] ?? m['title']),
      imageUrl: FamilyParse.fullUrl(image?.toString(), baseUrl),
      levelNo: FamilyParse.toInt(m['level_no'] ?? m['level']),
    );
  }
}

class FamilyCoinLogModel {
  final int id;
  final double points;
  final double coins;
  final String actionType;
  final String note;
  final String userName;
  final String createdAt;

  const FamilyCoinLogModel({
    this.id = 0,
    this.points = 0,
    this.coins = 0,
    this.actionType = '',
    this.note = '',
    this.userName = '',
    this.createdAt = '',
  });

  factory FamilyCoinLogModel.fromJson(dynamic json) {
    final m = FamilyParse.toMap(json);
    final user = FamilyParse.toMap(m['user']);
    return FamilyCoinLogModel(
      id: FamilyParse.toInt(m['id']),
      points: FamilyParse.toDouble(m['points']),
      coins: FamilyParse.toDouble(m['coins']),
      actionType: FamilyParse.toStr(m['action_type']),
      note: FamilyParse.toStr(m['note']),
      userName: FamilyParse.toStr(m['user_name'] ?? user['name']),
      createdAt: FamilyParse.toStr(m['created_at']),
    );
  }
}

String familyCompactNumber(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 2)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
