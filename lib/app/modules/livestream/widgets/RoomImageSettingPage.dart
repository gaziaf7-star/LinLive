import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class RoomImageSettingPage extends StatefulWidget {
  final String currentImageUrl;

  const RoomImageSettingPage({
    super.key,
    required this.currentImageUrl,
  });

  @override
  State<RoomImageSettingPage> createState() => _RoomImageSettingPageState();
}

class _RoomImageSettingPageState extends State<RoomImageSettingPage> {
  File? _pickedImage;

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 72,
      );
      if (image == null) return;
      setState(() => _pickedImage = File(image.path));
    } catch (_) {
      Fluttertoast.showToast(msg: ('Image pick failed').appTr);
    }
  }

  void _save() {
    if (_pickedImage == null) {
      Get.back();
      return;
    }
    Get.back(result: _pickedImage);
  }

  Widget _preview() {
    if (_pickedImage != null) {
      return Image.file(_pickedImage!, fit: BoxFit.cover);
    }

    final url = widget.currentImageUrl.trim();
    if (url.isEmpty) {
      return const Center(
        child: Icon(Icons.person_rounded, size: 72, color: Color(0xff9ea7ad)),
      );
    }

    if (url.startsWith('/')) {
      return Image.file(File(url), fit: BoxFit.cover);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(Icons.person_rounded, size: 72, color: Color(0xff9ea7ad)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff202020),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        title: Text(
          ('Room avatar').appTr,
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: const Color(0xff171717),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              ('Save').appTr,
              style: GoogleFonts.roboto(
                color: const Color(0xff171717),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 180,
                      height: 180,
                      color: const Color(0xffe8edf0),
                      child: _preview(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          title: ('Gallery').appTr,
                          icon: Icons.photo_library_rounded,
                          onTap: () => _pick(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          title: ('Camera').appTr,
                          icon: Icons.photo_camera_rounded,
                          onTap: () => _pick(ImageSource.camera),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              ('If no image is provided, the host profile image will be shown automatically.')
                  .appTr,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: const Color(0xff9a9a9a),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xfff4f4f4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xff555555), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.roboto(
                  color: const Color(0xff333333),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
