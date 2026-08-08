class CpInviteUser {
  final int id;
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String profileImage;

  CpInviteUser({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImage,
  });

  factory CpInviteUser.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpInviteUser(
      id: _toInt(map['id']),
      userId: _toInt(map['user_id']),
      name: _toStr(map['name']),
      email: _toStr(map['email']),
      phone: _toStr(map['phone']),
      profileImage: _toStr(map['profile_image']),
    );
  }
}

class CpInviteGift {
  final int id;
  final String name;
  final String image;
  final int coin;

  CpInviteGift({
    required this.id,
    required this.name,
    required this.image,
    required this.coin,
  });

  factory CpInviteGift.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpInviteGift(
      id: _toInt(map['id']),
      name: _toStr(map['name']),
      image: _toStr(map['image']),
      coin: _toInt(map['coin']),
    );
  }
}

class CpInviteRequest {
  final int id;
  final String requestNo;
  final String direction;
  final bool isSender;
  final bool isReceiver;

  final int senderId;
  final int receiverId;

  final CpInviteUser sender;
  final CpInviteUser receiver;
  final CpInviteGift? gift;

  final int giftListId;
  final String type;
  final int quantity;
  final int coin;
  final String message;

  final String status;
  final String statusText;

  final bool canAccept;
  final bool canReject;
  final bool canCancel;

  final String createdAt;
  final String createdDate;
  final String createdTime;
  final String? acceptedAt;
  final String? cancelledAt;

  CpInviteRequest({
    required this.id,
    required this.requestNo,
    required this.direction,
    required this.isSender,
    required this.isReceiver,
    required this.senderId,
    required this.receiverId,
    required this.sender,
    required this.receiver,
    required this.gift,
    required this.giftListId,
    required this.type,
    required this.quantity,
    required this.coin,
    required this.message,
    required this.status,
    required this.statusText,
    required this.canAccept,
    required this.canReject,
    required this.canCancel,
    required this.createdAt,
    required this.createdDate,
    required this.createdTime,
    required this.acceptedAt,
    required this.cancelledAt,
  });

  factory CpInviteRequest.fromJson(dynamic json) {
    final map = _asMap(json);

    return CpInviteRequest(
      id: _toInt(map['id']),
      requestNo: _toStr(map['request_no']),
      direction: _toStr(map['direction']),
      isSender: _toBool(map['is_sender']),
      isReceiver: _toBool(map['is_receiver']),
      senderId: _toInt(map['sender_id']),
      receiverId: _toInt(map['receiver_id']),
      sender: CpInviteUser.fromJson(map['sender']),
      receiver: CpInviteUser.fromJson(map['receiver']),
      gift: map['gift'] == null ? null : CpInviteGift.fromJson(map['gift']),
      giftListId: _toInt(map['gift_list_id']),
      type: _toStr(map['type']),
      quantity: _toInt(map['quantity']),
      coin: _toInt(map['coin']),
      message: _toStr(map['message']),
      status: _toStr(map['status']),
      statusText: _toStr(map['status_text']),
      canAccept: _toBool(map['can_accept']),
      canReject: _toBool(map['can_reject']),
      canCancel: _toBool(map['can_cancel']),
      createdAt: _toStr(map['created_at']),
      createdDate: _toStr(map['created_date']),
      createdTime: _toStr(map['created_time']),
      acceptedAt: map['accepted_at']?.toString(),
      cancelledAt: map['cancelled_at']?.toString(),
    );
  }

  CpInviteUser get partnerUser {
    if (isReceiver) return sender;
    return receiver;
  }

  CpInviteUser get mySideUser {
    if (isReceiver) return receiver;
    return sender;
  }

  bool get isPending => status.toLowerCase() == 'pending';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

String _toStr(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

bool _toBool(dynamic value) {
  if (value == true) return true;
  if (value == false) return false;
  if (value == 1) return true;
  if (value == 0) return false;

  final text = value.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}