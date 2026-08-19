import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/layout_constant.dart';
import '../../../services/agora_service.dart';
import '../controllers/agoraTokenController.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/livestream_controller.dart';
import '../videofilter/professional_video_effects_sheet.dart';
import '../videofilter/video_effect_models.dart';
import '../videofilter/video_effects_controller.dart';
import 'go_to_live_audio.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class GotoPopularLive extends StatefulWidget {
  final VoidCallback? onClose;

  const GotoPopularLive({
    super.key,
    this.onClose,
  });

  @override
  State<GotoPopularLive> createState() => _GotoPopularLiveState();
}

class _GotoPopularLiveState extends State<GotoPopularLive> {
  // String liveType = 'public';
  LivestreamController liveController = Get.find();
  final AuthController authController = Get.find<AuthController>();
  final AgoraService _agoraService = AgoraService();
  late final VideoEffectsController _videoEffectsController;
  bool isEngineReady = false;

  TextEditingController textEditingController = TextEditingController(
    text: 'hello',
  );

  // ✅ Announcement field — same pattern/widget as go_to_live_audio.dart's
  // AnnouncementBottomSheet, so Video Live has the same optional
  // announcement capability Audio Live already has.
  String announcementText = '';
  final TextEditingController announcementController = TextEditingController();

  void _openAnnouncementSheet() {
    announcementController.text = announcementText;

    Get.bottomSheet(
      AnnouncementBottomSheet(
        controller: announcementController,
        onSave: (value) {
          setState(() => announcementText = value);
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> initAgora() async {
    debugPrint('GotoPopularLive: fast camera startup...');

    try {
      // Do not open permission dialogs again when the user already granted them.
      PermissionStatus cameraStatus = await Permission.camera.status;
      PermissionStatus micStatus = await Permission.microphone.status;

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        final statuses = await <Permission>[
          Permission.camera,
          Permission.microphone,
        ].request();
        cameraStatus = statuses[Permission.camera] ?? cameraStatus;
        micStatus = statuses[Permission.microphone] ?? micStatus;
      }

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        debugPrint('GotoPopularLive: camera/mic permission not granted');
        if (mounted) {
          setState(() => isEngineReady = false);
        }
        return;
      }

      // Critical path: engine -> local camera -> preview.
      // Beauty/filter/denoise are intentionally applied AFTER preview becomes
      // visible, so the first camera frame is not blocked by effect setup.
      final bool success = await _agoraService.prepareVideoPreviewFast();

      if (!mounted) return;
      setState(() => isEngineReady = success);

      if (!success) {
        debugPrint('GotoPopularLive: failed to initialize Agora preview');
        return;
      }

      // Non-blocking post-preview configuration.
      unawaited(_agoraService.configureVideoQualityAfterPreview());
      unawaited(
        _agoraService.applyProfessionalVideoLook(
          lightening: .48,
          smoothness: .48,
          redness: .18,
          sharpness: .42,
          colorStrength: .22,
          skinProtect: .48,
          filter: AgoraLutFilter.natural,
          filterStrength: .24,
          lowLight: true,
          denoise: true,
        ),
      );

      debugPrint('GotoPopularLive: CAMERA_VISIBLE_FAST');
    } catch (error, stackTrace) {
      debugPrint('GotoPopularLive fast init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => isEngineReady = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _videoEffectsController = VideoEffectsController(
      agoraService: _agoraService,
    );
    initAgora();
  }

  @override
  void dispose() {
    announcementController.dispose();
    _videoEffectsController.dispose();
    if (liveController.minimizedVideoLiveSession.isEmpty) {
      _agoraService.leaveChannel();
    } else {
      debugPrint(
        'GotoPopularLive dispose kept Agora channel for minimized video live',
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AgoraTokenController agoraTokenController =
    Get.find<AgoraTokenController>();
    final h = kHeight;
    final w = kWeight;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: isEngineReady && _agoraService.engine != null
                ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: const VideoCanvas(
                  uid: 0,
                  renderMode: RenderModeType.renderModeHidden,
                  mirrorMode:
                  VideoMirrorModeType.videoMirrorModeEnabled,
                ),
              ),
            )
                : Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),

                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(.10),
                      Colors.transparent,
                      Colors.black.withOpacity(.34),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, .56, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    w * .035,
                    h * .006,
                    w * .025,
                    0,
                  ),
                  child: Row(
                    children: [
                      _roundTopButton(
                        icon: Icons.lock_outline_rounded,
                        onTap: _openRoomAccessDialog,
                      ),
                      const Spacer(),
                      _roundTopButton(
                        icon: Icons.close_rounded,
                        iconSize: h * .032,
                        onTap: () {
                          final close = widget.onClose;
                          if (close != null) {
                            close();
                          } else {
                            Get.back();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: h * .02),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * .045),
                  child: _buildVideoSetupCard(),
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * .035),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSetupTool(
                        icon: Icons.cameraswitch_rounded,
                        label: ('Flip').appTr,
                        onTap: () => _agoraService.flipCamera(),
                      ),
                      _buildSetupTool(
                        icon: Icons.face_retouching_natural_rounded,
                        label: ('Beauty').appTr,
                        onTap: () => _openEffects(VideoEffectsSection.beauty),
                      ),
                      _buildSetupTool(
                        icon: Icons.auto_awesome_rounded,
                        label: ('Magic').appTr,
                        onTap: () => _openEffects(VideoEffectsSection.presets),
                      ),
                      _buildSetupTool(
                        icon: Icons.school_outlined,
                        label: ('Academy').appTr,
                        onTap: () {},
                      ),
                      _buildSetupTool(
                        icon: Icons.expand_less_rounded,
                        label: ('Expand').appTr,
                        onTap: _openRoomAccessDialog,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: h * .026),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * .115),
                  child: Obx(() {
                    final bool loading =
                        liveController.isCreatingLive.value ||
                            agoraTokenController.tokenIsLoading.value;

                    return InkWell(
                      onTap: loading
                          ? null
                          : () async {
                        FocusScope.of(context).unfocus();
                        await liveController.tryToCreateLivestream(
                          streamTitle: textEditingController.text,
                          streamType: 'popular',
                          userId: authController
                              .userProfile.value.user!.id!
                              .toInt(),
                          anousment: announcementText.trim(),
                        );
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: h * .062,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: LinearGradient(
                            colors: loading
                                ? const [
                              Color(0xFF79D4D8),
                              Color(0xFF65C7E7),
                            ]
                                : const [
                              Color(0xFF16DED8),
                              Color(0xFF49C8F4),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22D9E4).withOpacity(.28),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: loading
                              ? const SizedBox(
                            key: ValueKey('video-create-loading'),
                            height: 23,
                            width: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            ('Go LIVE').appTr,
                            key: const ValueKey('video-go-live'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: h * .020,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: h * .095),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundTopButton({
    required IconData icon,
    required VoidCallback onTap,
    double? iconSize,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: kHeight * .045,
        width: kHeight * .045,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(.12),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize ?? kHeight * .021,
        ),
      ),
    );
  }

  Widget _buildVideoSetupCard() {
    final h = kHeight;
    final w = kWeight;

    return Container(
      padding: EdgeInsets.all(w * .024),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => liveController.kycNidShow(),
                borderRadius: BorderRadius.circular(14),
                child: Obx(() {
                  final String localCover =
                  liveController.videoImage.value.trim();

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: localCover.isEmpty
                        ? Image.asset(
                      appLogo,
                      width: h * .080,
                      height: h * .080,
                      fit: BoxFit.cover,
                    )
                        : Image.file(
                      File(localCover),
                      width: h * .080,
                      height: h * .080,
                      fit: BoxFit.cover,
                    ),
                  );
                }),
              ),
              SizedBox(width: w * .025),
              Expanded(
                child: TextField(
                  controller: textEditingController,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: h * .020,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: ('Add a title to chat').appTr,
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(.72),
                      fontSize: h * .019,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: h * .026,
            color: Colors.white.withOpacity(.12),
          ),
          Row(
            children: [
              Expanded(child: _tagPill('#', ('Singing').appTr)),
              SizedBox(width: w * .014),
              Expanded(child: _tagPill('#', ('DJ').appTr)),
              SizedBox(width: w * .014),
              Expanded(child: _tagPill('#', ('Charmer').appTr)),
              SizedBox(width: w * .014),
              InkWell(
                onTap: _openAnnouncementSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: h * .042,
                  width: h * .042,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    announcementText.trim().isEmpty
                        ? Icons.keyboard_arrow_down_rounded
                        : CupertinoIcons.speaker_2_fill,
                    color: Colors.white,
                    size: h * .020,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tagPill(String prefix, String label) {
    return Container(
      height: kHeight * .042,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.17),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(.07),
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prefix,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight * .018,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight * .0135,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: kHeight * .016,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: kWeight * .17,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: kHeight * .034,
            ),
            SizedBox(height: kHeight * .007),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: kHeight * .014,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoomAccessDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Container(
          width: Get.width * .86,
          padding: const EdgeInsets.all(18),
          child: Obx(() {
            final isPasswordMode =
                liveController.selectedType.value ==
                    'Please set room password';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('Live Room Settings').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomDropdown(
                    closedHeaderPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    hintText: ('Select room type').appTr,
                    items: liveController.nationalIdentity,
                    initialItem: liveController.nationalIdentity[0],
                    canCloseOutsideBounds: true,
                    decoration: CustomDropdownDecoration(
                      prefixIcon: Icon(
                        isPasswordMode
                            ? Icons.lock_outline_rounded
                            : Icons.card_giftcard_rounded,
                        color: const Color(0xFF8352F4),
                      ),
                      closedSuffixIcon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black87,
                      ),
                      headerStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      closedFillColor: const Color(0xFFF3EEFF),
                      listItemStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      closedBorderRadius: BorderRadius.circular(12),
                      expandedFillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      liveController.selectedType.value = value!;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  obscureText: isPasswordMode,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: isPasswordMode
                        ? ('Enter your password').appTr
                        : ('Enter gift').appTr,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF7F7F9),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: isPasswordMode
                        ? const Icon(
                      Icons.visibility_off_outlined,
                      color: Color(0xFF8352F4),
                      size: 19,
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8352F4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      ('Confirm').appTr,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _openEffects(VideoEffectsSection section) {
    showProfessionalVideoEffectsSheet(
      context,
      initialSection: section,
      controller: _videoEffectsController,
    );
  }
}
