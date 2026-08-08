import 'dart:io';

import 'package:get/get.dart';

import 'chat_model.dart';
import 'messages/components/firestore_service.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ChatController extends GetxController {
  final RxSet<String> selectedChatIds = <String>{}.obs;
  final RxBool isSelectionMode = false.obs;

  final FirestoreService _firestoreService = Get.put(FirestoreService());
  final RxBool isSending = false.obs;
  final RxBool isUploading = false.obs;

  String get currentUserId => _firestoreService.currentUserId;
  String get currentUserName => _firestoreService.currentUserName;
  String get currentUserImage => _firestoreService.currentUserImage;

  Stream<List<Chat>> get chats {
    return _firestoreService.firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Chat.fromFirestore(d)).toList())
        .handleError((e) {
      print('❌ chats error: $e');
      return <Chat>[];
    });
  }


  /// All chat unread counts combined for the signed-in user.
  /// Firestore snapshots make this update immediately when a message arrives
  /// or when a conversation is marked as read.
  Stream<int> get totalUnreadCountStream {
    return chats
        .map(
          (items) => items.fold<int>(
        0,
            (total, chat) =>
        total + (chat.unreadCounts[currentUserId] ?? 0),
      ),
    )
        .distinct();
  }

  Stream<List<Message>> getMessages(String chatId) =>
      _firestoreService.getMessages(chatId);

  // ─── Text ─────────────────────────────────────────────────────────────────
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
    try {
      isSending.value = true;
      await _firestoreService.sendMessage(
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
    } finally {
      isSending.value = false;
    }
  }

  // ─── Image ────────────────────────────────────────────────────────────────
  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
    required File imageFile,
    String message = '',
  }) async {
    try {
      isSending.value = true;
      isUploading.value = true;
      final url = await _firestoreService.uploadFile(imageFile, 'image');
      if (url != null) {
        await _firestoreService.sendMediaMessage(
          chatId: chatId,
          receiverId: receiverId,
          receiverName: receiverName,
          receiverImage: receiverImage,
          message: message,
          imageUrl: url,
        );
      } else {
        Get.snackbar(('Error').appTr, ('Failed to upload image').appTr);
      }
    } finally {
      isSending.value = false;
      isUploading.value = false;
    }
  }

  // ─── Video ────────────────────────────────────────────────────────────────
  Future<void> sendVideoMessage({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
    required File videoFile,
    String message = '',
  }) async {
    try {
      isSending.value = true;
      isUploading.value = true;
      final url = await _firestoreService.uploadFile(videoFile, 'video');
      if (url != null) {
        await _firestoreService.sendMediaMessage(
          chatId: chatId,
          receiverId: receiverId,
          receiverName: receiverName,
          receiverImage: receiverImage,
          message: message,
          videoUrl: url,
        );
      } else {
        Get.snackbar(('Error').appTr, ('Failed to upload video').appTr);
      }
    } finally {
      isSending.value = false;
      isUploading.value = false;
    }
  }

  // ─── Voice ────────────────────────────────────────────────────────────────
  Future<void> sendVoiceMessage({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
    required File voiceFile,
    int? voiceDuration,
  }) async {
    try {
      isSending.value = true;
      isUploading.value = true;
      final url = await _firestoreService.uploadFile(voiceFile, 'voice');
      if (url != null) {
        await _firestoreService.sendMediaMessage(
          chatId: chatId,
          receiverId: receiverId,
          receiverName: receiverName,
          receiverImage: receiverImage,
          message: '',
          voiceUrl: url,
          voiceDuration: voiceDuration,
        );
      } else {
        Get.snackbar(('Error').appTr, ('Failed to upload voice message').appTr);
      }
    } finally {
      isSending.value = false;
      isUploading.value = false;
    }
  }

  // ─── ✅ Delete For Everyone ────────────────────────────────────────────────
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    await _firestoreService.deleteMessageForEveryone(
      chatId: chatId,
      messageId: messageId,
    );
  }

  // ─── ✅ Delete For Me ─────────────────────────────────────────────────────
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
  }) async {
    await _firestoreService.deleteMessageForMe(
      chatId: chatId,
      messageId: messageId,
    );
  }

  // ─── ✅ React to Message ──────────────────────────────────────────────────
  Future<void> reactToMessage({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    await _firestoreService.reactToMessage(
      chatId: chatId,
      messageId: messageId,
      emoji: emoji,
    );
  }

  // ─── ✅ Remove Reaction ───────────────────────────────────────────────────
  Future<void> removeReaction({
    required String chatId,
    required String messageId,
  }) async {
    await _firestoreService.removeReaction(
      chatId: chatId,
      messageId: messageId,
    );
  }

  Future<void> markMessagesAsRead(String chatId) async =>
      _firestoreService.markMessagesAsRead(chatId);

  String generateChatId(String receiverId) =>
      _firestoreService.generateChatId(receiverId);
}
