import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../views/chat_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MessangerController extends GetxController {
  final ImagePicker _picker = ImagePicker();
  final ChatController _chatController = Get.find<ChatController>();

  // Message text
  final messageText = ''.obs;

  // Media paths
  var imagePath = ''.obs;
  var mediaPath = ''.obs;
  var isVideo = false.obs;
  var isVoice = false.obs; // ✅ NEW
  var pickedFilePath = ''.obs;
  final RxDouble uploadProgress = 0.0.obs;

  // Chat data
  String? currentChatId;
  String? currentReceiverId;
  String? currentReceiverName;
  String? currentReceiverImage;

  void setChatData({
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String receiverImage,
  }) {
    currentChatId = chatId;
    currentReceiverId = receiverId;
    currentReceiverName = receiverName;
    currentReceiverImage = receiverImage;
  }

  void setMessageText({required String text}) {
    messageText.value = text.trim();
  }

  void clearMessageText() {
    messageText.value = '';
  }

  // Pick file
  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      pickedFilePath.value = result.files.single.path ?? '';
    } else {
      pickedFilePath.value = '';
    }
  }

  // Camera
  Future<void> openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        imagePath.value = photo.path;
        _showImagePreview(File(photo.path));
      }
    } catch (e) {
      Get.snackbar(
        ('Error').appTr,
        ('Failed to capture photo').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Pick Image
  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        mediaPath.value = image.path;
        isVideo.value = false;
        isVoice.value = false;
        _showImagePreview(File(image.path));
      }
    } catch (e) {
      Get.snackbar(
        ('Error').appTr,
        ('Failed to pick image').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Pick Video
  Future<void> pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 2),
      );

      if (video != null) {
        mediaPath.value = video.path;
        isVideo.value = true;
        isVoice.value = false;
        _showVideoPreview(File(video.path));
      }
    } catch (e) {
      Get.snackbar(
        ('Error').appTr,
        ('Failed to pick video').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showImagePreview(File imageFile) {
    Get.dialog(
      ImagePreviewDialog(
        imageFile: imageFile,
        onSend: (caption) => _sendImage(imageFile, caption),
        onCancel: () {
          imagePath.value = '';
          mediaPath.value = '';
          Get.back();
        },
      ),
      barrierDismissible: false,
    );
  }

  void _showVideoPreview(File videoFile) {
    Get.dialog(
      VideoPreviewDialog(
        videoFile: videoFile,
        onSend: (caption) => _sendVideo(videoFile, caption),
        onCancel: () {
          mediaPath.value = '';
          Get.back();
        },
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _sendImage(File imageFile, String caption) async {
    if (currentChatId == null) return;
    Get.back();
    isVideo.value = false;
    isVoice.value = false;
    uploadProgress.value = 10.0;

    await _chatController.sendImageMessage(
      chatId: currentChatId!,
      receiverId: currentReceiverId!,
      receiverName: currentReceiverName!,
      receiverImage: currentReceiverImage!,
      imageFile: imageFile,
      message: caption,
    );

    uploadProgress.value = 0.0;
    imagePath.value = '';
    mediaPath.value = '';
  }

  Future<void> _sendVideo(File videoFile, String caption) async {
    if (currentChatId == null) return;
    Get.back();
    isVideo.value = true;
    isVoice.value = false;
    uploadProgress.value = 10.0;

    await _chatController.sendVideoMessage(
      chatId: currentChatId!,
      receiverId: currentReceiverId!,
      receiverName: currentReceiverName!,
      receiverImage: currentReceiverImage!,
      videoFile: videoFile,
      message: caption,
    );

    uploadProgress.value = 0.0;
    mediaPath.value = '';
  }
}

// Image Preview Dialog (unchanged)
class ImagePreviewDialog extends StatelessWidget {
  final File imageFile;
  final Function(String) onSend;
  final VoidCallback onCancel;

  const ImagePreviewDialog({
    Key? key,
    required this.imageFile,
    required this.onSend,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController = TextEditingController();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: onCancel,
              ),
            ),
            Container(
              constraints: BoxConstraints(maxHeight: Get.height * 0.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(imageFile, fit: BoxFit.contain),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: captionController,
                style: TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: ('Add a caption...').appTr,
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => onSend(captionController.text.trim()),
              icon: Icon(Icons.send, size: 20),
              label: Text(('Send Photo').appTr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff7c3df6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 5,
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Video Preview Dialog (unchanged)
class VideoPreviewDialog extends StatelessWidget {
  final File videoFile;
  final Function(String) onSend;
  final VoidCallback onCancel;

  const VideoPreviewDialog({
    Key? key,
    required this.videoFile,
    required this.onSend,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController = TextEditingController();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: onCancel,
              ),
            ),
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline,
                      size: 80, color: Colors.white),
                  SizedBox(height: 10),
                  Text(('Video Ready').appTr,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: captionController,
                style: TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: ('Add a caption...').appTr,
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => onSend(captionController.text.trim()),
              icon: Icon(Icons.send, size: 20),
              label: Text(('Send Video').appTr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff7c3df6),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 5,
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
