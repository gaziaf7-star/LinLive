import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CloudinaryService {
  static const String cloudName = 'dg82scsun';
  static const String uploadPreset = 'chat_media';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );

  final RxDouble uploadProgress = 0.0.obs;

  Future<String?> uploadImage(File imageFile) async {
    try {
      print('📤 Uploading image to Cloudinary...');
      uploadProgress.value = 0.0;

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'chat_images',
        ),
      );

      uploadProgress.value = 100.0;
      print('   ✅ Image uploaded: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('   ❌ Image upload error: $e');
      Get.snackbar(
        ('Upload Failed').appTr,
        ('Could not upload image. Please try again.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  Future<String?> uploadVideo(File videoFile) async {
    try {
      print('📤 Uploading video to Cloudinary...');
      uploadProgress.value = 0.0;

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'chat_videos',
        ),
      );

      uploadProgress.value = 100.0;
      print('   ✅ Video uploaded: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('   ❌ Video upload error: $e');
      Get.snackbar(
        ('Upload Failed').appTr,
        ('Could not upload video. Please try again.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  // ✅ NEW: Voice/Audio upload - Cloudinary Video resource type use করে audio এর জন্য
  Future<String?> uploadAudio(File audioFile) async {
    try {
      print('📤 Uploading voice message to Cloudinary...');
      uploadProgress.value = 0.0;

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          audioFile.path,
          resourceType:
          CloudinaryResourceType.Video, // Cloudinary audio = Video type
          folder: 'chat_voices',
        ),
      );

      uploadProgress.value = 100.0;
      print('   ✅ Voice uploaded: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('   ❌ Voice upload error: $e');
      Get.snackbar(
        ('Upload Failed').appTr,
        ('Could not upload voice message. Please try again.').appTr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }
}
