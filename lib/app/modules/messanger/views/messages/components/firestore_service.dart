import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../services/cloud_services.dart';

import '../../../../auth/controllers/auth_controller.dart';
import '../../chat_model.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AuthController _authController = Get.find<AuthController>();

  FirebaseFirestore get firestore => _firestore;
  RxDouble get uploadProgress => _cloudinaryService.uploadProgress;

  String get currentUserId =>
      _authController.userProfile.value.user!.id.toString();
  String get currentUserName =>
      _authController.userProfile.value.user!.name ?? ('You').appTr;
  String get currentUserImage =>
      _authController.userProfile.value.user!.profileImage ?? '';

  Stream<List<Chat>> getChats() => _firestore
      .collection('chats')
      .where('participants', arrayContains: currentUserId)
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Chat.fromFirestore).toList());

  Stream<List<Message>> getMessages(String chatId) => _firestore
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((s) => s.docs.map(Message.fromFirestore).toList());

  // ─── Upload ───────────────────────────────────────────────────────────────
  Future<String?> uploadFile(File file, String fileType) async {
    if (fileType == 'image') return await _cloudinaryService.uploadImage(file);
    if (fileType == 'video') return await _cloudinaryService.uploadVideo(file);
    if (fileType == 'voice') return await _cloudinaryService.uploadAudio(file);
    return null;
  }

  // ─── Send Text ────────────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
    required String message,
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderId,
    String? replyToImageUrl,
    String? replyToVideoUrl,
  }) async {
    await _sendInternal(
      chatId: chatId,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverImage: receiverImage,
      message: message,
      replyToMessageId: replyToMessageId,
      replyToMessage: replyToMessage,
      replyToSenderId: replyToSenderId,
      replyToImageUrl: replyToImageUrl,
      replyToVideoUrl: replyToVideoUrl,
    );
  }

  // ─── Send Media ───────────────────────────────────────────────────────────
  Future<void> sendMediaMessage({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
    String message = '',
    String? imageUrl,
    String? videoUrl,
    String? voiceUrl,
    int? voiceDuration,
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderId,
    String? replyToImageUrl,
    String? replyToVideoUrl,
    String? replyToVoiceUrl,
  }) async {
    await _sendInternal(
      chatId: chatId,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverImage: receiverImage,
      message: message,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      voiceUrl: voiceUrl,
      voiceDuration: voiceDuration,
      replyToMessageId: replyToMessageId,
      replyToMessage: replyToMessage,
      replyToSenderId: replyToSenderId,
      replyToImageUrl: replyToImageUrl,
      replyToVideoUrl: replyToVideoUrl,
      replyToVoiceUrl: replyToVoiceUrl,
    );
  }

  Future<void> _sendInternal({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
    required String message,
    String? imageUrl,
    String? videoUrl,
    String? voiceUrl,
    int? voiceDuration,
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderId,
    String? replyToImageUrl,
    String? replyToVideoUrl,
    String? replyToVoiceUrl,
  }) async {
    const maxRetries = 3;
    int attempt = 0;

    while (true) {
      try {
        String preview = message;
        if (imageUrl != null) preview = message.isEmpty ? '📷 Photo': message;
        if (videoUrl != null) preview = message.isEmpty ? '🎥 Video': message;
        if (voiceUrl != null) preview = '🎤 Voice message';

        final chatDoc = await _firestore.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
          await _firestore.collection('chats').doc(chatId).set({
            'participants': [currentUserId, receiverId],
            'participantNames': {
              currentUserId: currentUserName,
              receiverId: receiverName
            },
            'participantImages': {
              currentUserId: currentUserImage,
              receiverId: receiverImage
            },
            'lastMessage': preview,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSender': currentUserId,
            'unreadCounts': {currentUserId: 0, receiverId: 1},
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = chatDoc.data() as Map<String, dynamic>;
          final counts = Map<String, int>.from(data['unreadCounts'] ?? {});
          counts[receiverId] = (counts[receiverId] ?? 0) + 1;
          counts[currentUserId] = counts[currentUserId] ?? 0;
          await _firestore.collection('chats').doc(chatId).update({
            'lastMessage': preview,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSender': currentUserId,
            'unreadCounts': counts,
          });
        }

        final msgData = <String, dynamic>{
          'senderId': currentUserId,
          'receiverId': receiverId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'deletedForEveryone': false,
          'deletedForUsers': [],
          'reactions': {},
        };

        if (imageUrl != null) msgData['imageUrl'] = imageUrl;
        if (videoUrl != null) msgData['videoUrl'] = videoUrl;
        if (voiceUrl != null) {
          msgData['voiceUrl'] = voiceUrl;
          if (voiceDuration != null) msgData['voiceDuration'] = voiceDuration;
        }
        if (replyToMessageId != null) {
          msgData['replyToMessageId'] = replyToMessageId;
          msgData['replyToMessage'] = replyToMessage ?? '';
          msgData['replyToSenderId'] = replyToSenderId ?? '';
          if (replyToImageUrl != null) msgData['replyToImageUrl'] = replyToImageUrl;
          if (replyToVideoUrl != null) msgData['replyToVideoUrl'] = replyToVideoUrl;
          if (replyToVoiceUrl != null) msgData['replyToVoiceUrl'] = replyToVoiceUrl;
        }

        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add(msgData);

        return; // ✅ success

      } catch (e) {
        attempt++;

        final isUnavailable = e.toString().contains('unavailable') ||
            e.toString().contains('UNAVAILABLE');

        if (isUnavailable && attempt < maxRetries) {
          final waitSeconds = attempt * 2;
          print('⚠️ Retry $attempt/$maxRetries — waiting ${waitSeconds}s...');
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }

        print('❌ send error (attempt $attempt): $e');
        Get.snackbar(
          ('Error').appTr,
          isUnavailable
              ? ('Network error. Please check your connection.').appTr: ('Message send failed').appTr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        rethrow;
      }
    }
  }

  // ─── ✅ Delete For Everyone ────────────────────────────────────────────────
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedForEveryone': true,
        'message': '',
        'imageUrl': FieldValue.delete(),
        'videoUrl': FieldValue.delete(),
        'voiceUrl': FieldValue.delete(),
      });
    } catch (e) {
      print('❌ deleteForEveryone error: $e');
    }
  }

  // ─── ✅ Delete For Me ─────────────────────────────────────────────────────
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedForUsers': FieldValue.arrayUnion([currentUserId]),
      });
    } catch (e) {
      print('❌ deleteForMe error: $e');
    }
  }

  // ─── ✅ React ─────────────────────────────────────────────────────────────
  Future<void> reactToMessage({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$currentUserId': emoji});
    } catch (e) {
      print('❌ react error: $e');
    }
  }

  // ─── ✅ Remove Reaction ───────────────────────────────────────────────────
  Future<void> removeReaction({
    required String chatId,
    required String messageId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$currentUserId': FieldValue.delete()});
    } catch (e) {
      print('❌ removeReaction error: $e');
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final unread = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false)
          .get();
      if (unread.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({'unreadCounts.$currentUserId': 0});
    } catch (e) {
      print('❌ markRead error: $e');
    }
  }

  String generateChatId(String receiverId) {
    return currentUserId.hashCode <= receiverId.hashCode
        ? '$currentUserId-$receiverId'
        : '$receiverId-$currentUserId';
  }
}
