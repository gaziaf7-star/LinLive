import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../modules/auth/controllers/auth_controller.dart';
import '../modules/messanger/views/chat_model.dart';
import 'cloud_services.dart';
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AuthController _authController = Get.find<AuthController>();

  FirebaseFirestore get firestore => _firestore;
  RxDouble get uploadProgress => _cloudinaryService.uploadProgress;

  /// The authenticated profile is cleared before navigation when an account or
  /// device is blocked. Every chat getter must therefore remain null-safe during
  /// the small route-transition window.
  bool get hasAuthenticatedUser {
    final user = _authController.userProfile.value.user;
    final id = user?.id;
    if (id == null) return false;
    final text = id.toString().trim();
    return text.isNotEmpty && text != '0' && text.toLowerCase() != 'null';
  }

  String get currentUserId {
    final user = _authController.userProfile.value.user;
    final id = user?.id?.toString().trim() ?? '';
    if (id.isEmpty || id == '0' || id.toLowerCase() == 'null') return '';
    return id;
  }

  String get currentUserName {
    final name =
        _authController.userProfile.value.user?.name?.toString().trim() ?? '';
    return name.isEmpty ? ('You').appTr : name;
  }

  String get currentUserImage {
    return _authController.userProfile.value.user?.profileImage
        ?.toString()
        .trim() ??
        '';
  }

  Stream<List<Chat>> getChats() {
    final String userId = currentUserId;
    if (userId.isEmpty) {
      return Stream<List<Chat>>.value(const <Chat>[]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Chat.fromFirestore).toList());
  }

  Stream<List<Message>> getMessages(String chatId) {
    if (!hasAuthenticatedUser || chatId.trim().isEmpty) {
      return Stream<List<Message>>.value(const <Message>[]);
    }

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((s) => s.docs.map(Message.fromFirestore).toList());
  }

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
    final String senderId = currentUserId;
    if (senderId.isEmpty) {
      throw StateError(
        'Authenticated user is unavailable. The session may have ended.',
      );
    }

    const int maxRetries = 3;
    int attempt = 0;

    final chatRef = _firestore.collection('chats').doc(chatId);

    // Keep the same message ID during retries. If Firestore committed the first
    // request but the client lost the response, the transaction will see this
    // document and will not increase unread count twice.
    final messageRef = chatRef.collection('messages').doc();

    while (true) {
      try {
        String preview = message.trim();
        if (imageUrl != null) {
          preview = preview.isEmpty ? '📷 Photo' : preview;
        }
        if (videoUrl != null) {
          preview = preview.isEmpty ? '🎥 Video' : preview;
        }
        if (voiceUrl != null) {
          preview = preview.isEmpty ? '🎤 Voice message' : preview;
        }

        final msgData = <String, dynamic>{
          'senderId': senderId,
          'receiverId': receiverId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'deletedForEveryone': false,
          'deletedForUsers': <String>[],
          'reactions': <String, String>{},
        };

        if (imageUrl != null) msgData['imageUrl'] = imageUrl;
        if (videoUrl != null) msgData['videoUrl'] = videoUrl;
        if (voiceUrl != null) {
          msgData['voiceUrl'] = voiceUrl;
          if (voiceDuration != null) {
            msgData['voiceDuration'] = voiceDuration;
          }
        }

        if (replyToMessageId != null) {
          msgData['replyToMessageId'] = replyToMessageId;
          msgData['replyToMessage'] = replyToMessage ?? '';
          msgData['replyToSenderId'] = replyToSenderId ?? '';
          if (replyToImageUrl != null) {
            msgData['replyToImageUrl'] = replyToImageUrl;
          }
          if (replyToVideoUrl != null) {
            msgData['replyToVideoUrl'] = replyToVideoUrl;
          }
          if (replyToVoiceUrl != null) {
            msgData['replyToVoiceUrl'] = replyToVoiceUrl;
          }
        }

        await _firestore.runTransaction((transaction) async {
          final chatSnapshot = await transaction.get(chatRef);
          final existingMessage = await transaction.get(messageRef);

          if (existingMessage.exists) {
            return;
          }

          if (!chatSnapshot.exists) {
            transaction.set(chatRef, {
              'participants': [senderId, receiverId],
              'participantNames': {
                senderId: currentUserName,
                receiverId: receiverName,
              },
              'participantImages': {
                senderId: currentUserImage,
                receiverId: receiverImage,
              },
              'lastMessage': preview,
              'lastMessageTime': FieldValue.serverTimestamp(),
              'lastMessageSender': senderId,
              'unreadCounts': {
                senderId: 0,
                receiverId: 1,
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            transaction.update(chatRef, {
              'lastMessage': preview,
              'lastMessageTime': FieldValue.serverTimestamp(),
              'lastMessageSender': senderId,
              'unreadCounts.$receiverId': FieldValue.increment(1),
            });
          }

          transaction.set(messageRef, msgData);
        });

        return;
      } catch (e) {
        attempt++;

        final bool isUnavailable =
            e.toString().contains('unavailable') ||
                e.toString().contains('UNAVAILABLE');

        if (isUnavailable && attempt < maxRetries) {
          final int waitSeconds = attempt * 2;
          print(
            '⚠️ Retry $attempt/$maxRetries — waiting ${waitSeconds}s...',
          );
          await Future<void>.delayed(Duration(seconds: waitSeconds));
          continue;
        }

        print('❌ send error (attempt $attempt): $e');
        Get.snackbar(
          'Error'.appTr,
          isUnavailable
              ? 'Network error. Please check your connection.'.appTr
              : 'Message send failed'.appTr,
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
    if (!hasAuthenticatedUser) return;
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
    final String userId = currentUserId;
    if (userId.isEmpty) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedForUsers': FieldValue.arrayUnion([userId]),
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
    final String userId = currentUserId;
    if (userId.isEmpty) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': emoji});
    } catch (e) {
      print('❌ react error: $e');
    }
  }

  // ─── ✅ Remove Reaction ───────────────────────────────────────────────────
  Future<void> removeReaction({
    required String chatId,
    required String messageId,
  }) async {
    final String userId = currentUserId;
    if (userId.isEmpty) return;
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': FieldValue.delete()});
    } catch (e) {
      print('❌ removeReaction error: $e');
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final String userId = currentUserId;
    if (userId.isEmpty || chatId.trim().isEmpty) return;

    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final unread = await chatRef
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Subtract only the messages marked by this call. If a new message arrives
      // at the same time, Firestore retries the transaction and keeps that new
      // unread message in the badge count.
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(chatRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>? ??
            <String, dynamic>{};
        final counts = Map<String, dynamic>.from(
          data['unreadCounts'] as Map? ?? <String, dynamic>{},
        );
        final dynamic rawCurrent = counts[userId];
        final int currentCount = rawCurrent is num
            ? rawCurrent.toInt()
            : int.tryParse(rawCurrent?.toString() ?? '') ?? 0;
        final int nextCount = currentCount - unread.docs.length;

        transaction.update(chatRef, {
          'unreadCounts.$userId': nextCount < 0 ? 0 : nextCount,
        });
      });
    } catch (e) {
      print('❌ markRead error: $e');
    }
  }

  String generateChatId(String receiverId) {
    final String userId = currentUserId;
    if (userId.isEmpty || receiverId.trim().isEmpty) return '';

    return userId.hashCode <= receiverId.hashCode
        ? '$userId-$receiverId'
        : '$receiverId-$userId';
  }
}
