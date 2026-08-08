class RedPacket {
  int? id;
  int? senderId;
  int? livestreamId;
  String? amount;
  String? message;
  String? status;
  String? expiresAt;
  String? createdAt;
  String? updatedAt;
  User? sender;
  List<RedPacketCollection>? collections;
  int? totalCollections;
  String? remainingAmount;

  RedPacket({
    this.id,
    this.senderId,
    this.livestreamId,
    this.amount,
    this.message,
    this.status,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.sender,
    this.collections,
    this.totalCollections,
    this.remainingAmount,
  });

  RedPacket.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    senderId = json['sender_id'];
    livestreamId = json['livestream_id'];
    amount = json['amount'];
    message = json['message'];
    status = json['status'];
    expiresAt = json['expires_at'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    sender = json['sender'] != null ? User.fromJson(json['sender']) : null;
    if (json['collections'] != null) {
      collections = <RedPacketCollection>[];
      json['collections'].forEach((v) {
        collections!.add(RedPacketCollection.fromJson(v));
      });
    }
    totalCollections = json['total_collections'];
    remainingAmount = json['remaining_amount'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['sender_id'] = senderId;
    data['livestream_id'] = livestreamId;
    data['amount'] = amount;
    data['message'] = message;
    data['status'] = status;
    data['expires_at'] = expiresAt;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (sender != null) {
      data['sender'] = sender!.toJson();
    }
    if (collections != null) {
      data['collections'] = collections!.map((v) => v.toJson()).toList();
    }
    data['total_collections'] = totalCollections;
    data['remaining_amount'] = remainingAmount;
    return data;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.parse(expiresAt!).isBefore(DateTime.now());
  }

  bool get isActive {
    return status == 'active' && !isExpired;
  }

  bool get canCollect {
    return isActive && (remainingAmount != null && double.parse(remainingAmount!) > 0);
  }
}

class RedPacketCollection {
  int? id;
  int? redPacketId;
  int? userId;
  String? amount;
  String? createdAt;
  String? updatedAt;
  User? user;

  RedPacketCollection({
    this.id,
    this.redPacketId,
    this.userId,
    this.amount,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  RedPacketCollection.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    redPacketId = json['red_packet_id'];
    userId = json['user_id'];
    amount = json['amount'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    user = json['user'] != null ? User.fromJson(json['user']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['red_packet_id'] = redPacketId;
    data['user_id'] = userId;
    data['amount'] = amount;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    return data;
  }
}

// User class placeholder - assuming it exists in user_profile.dart
class User {
  int? id;
  String? name;
  String? profileImage;
  String? balance;

  User({this.id, this.name, this.profileImage, this.balance});

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    profileImage = json['profile_image'];
    balance = json['balance'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['profile_image'] = profileImage;
    data['balance'] = balance;
    return data;
  }
}

class RedPacketSendRequest {
  String amount;
  String message;
  int livestreamId;
  int quantity;
  int? durationMinutes;
  bool? isGlobal;

  RedPacketSendRequest({
    required this.amount,
    required this.message,
    required this.livestreamId,
    required this.quantity,
    this.durationMinutes,
    this.isGlobal,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'amount': amount,
      'message': message,
      'livestream_id': livestreamId,
      'quantity': quantity,
    };
    
    if (durationMinutes != null) {
      data['duration_minutes'] = durationMinutes;
    }
    
    if (isGlobal != null) {
      data['is_global'] = isGlobal;
    }
    
    return data;
  }
}

class RedPacketResponse {
  bool success;
  String message;
  RedPacket? data;
  String? error;

  RedPacketResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  RedPacketResponse.fromJson(Map<String, dynamic> json)
      : success = json['success'] ?? false,
        message = json['message'] ?? '' {
    data = json['data'] != null ? RedPacket.fromJson(json['data']) : null;
    error = json['error'];
  }
}
