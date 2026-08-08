import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantImages;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSender;
  final Map<String, int> unreadCounts;

  Chat({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantImages,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.unreadCounts,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames:
      Map<String, String>.from(data['participantNames'] ?? {}),
      participantImages:
      Map<String, String>.from(data['participantImages'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime:
      (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSender: data['lastMessageSender'] ?? '',
      unreadCounts: _parseUnreadCounts(data),
    );
  }

  static Map<String, int> _parseUnreadCounts(Map<String, dynamic> data) {
    if (data['unreadCounts'] != null) {
      return Map<String, int>.from(data['unreadCounts']);
    }
    final counts = <String, int>{};
    data.forEach((key, value) {
      if (key.startsWith('unreadCount_') && value is int) {
        counts[key.replaceFirst('unreadCount_', '')] = value;
      }
    });
    return counts;
  }
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool read;
  final String? imageUrl;
  final String? videoUrl;
  final String? voiceUrl;
  final int? voiceDuration;

  // ✅ Delete support
  final bool deletedForEveryone; // সবার কাছে delete
  final List<String> deletedForUsers; // শুধু নির্দিষ্ট user এর কাছে delete

  // ✅ Reaction support
  final Map<String, String> reactions; // {userId: emoji}

  // Reply fields
  final String? replyToMessageId;
  final String? replyToMessage;
  final String? replyToSenderId;
  final String? replyToImageUrl;
  final String? replyToVideoUrl;
  final String? replyToVoiceUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.read,
    this.imageUrl,
    this.videoUrl,
    this.voiceUrl,
    this.voiceDuration,
    this.deletedForEveryone = false,
    this.deletedForUsers = const [],
    this.reactions = const {},
    this.replyToMessageId,
    this.replyToMessage,
    this.replyToSenderId,
    this.replyToImageUrl,
    this.replyToVideoUrl,
    this.replyToVoiceUrl,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasVoice => voiceUrl != null && voiceUrl!.isNotEmpty;
  bool get hasMedia => hasImage || hasVideo || hasVoice;
  bool get hasReply => replyToMessageId != null;
  bool get hasReactions => reactions.isNotEmpty;

  // ✅ নির্দিষ্ট user এর জন্য delete হয়েছে কিনা
  bool isDeletedFor(String userId) {
    return deletedForEveryone || deletedForUsers.contains(userId);
  }

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      imageUrl: data['imageUrl'],
      videoUrl: data['videoUrl'],
      voiceUrl: data['voiceUrl'],
      voiceDuration: data['voiceDuration'],
      deletedForEveryone: data['deletedForEveryone'] ?? false,
      deletedForUsers: List<String>.from(data['deletedForUsers'] ?? []),
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      replyToMessageId: data['replyToMessageId'],
      replyToMessage: data['replyToMessage'],
      replyToSenderId: data['replyToSenderId'],
      replyToImageUrl: data['replyToImageUrl'],
      replyToVideoUrl: data['replyToVideoUrl'],
      replyToVoiceUrl: data['replyToVoiceUrl'],
    );
  }
}
