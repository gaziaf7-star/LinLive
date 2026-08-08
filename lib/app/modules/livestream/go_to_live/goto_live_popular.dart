import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../services/agora_service.dart';
import '../controllers/agoraTokenController.dart';
import '../controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class GotoPopularLive extends StatefulWidget {
  const GotoPopularLive({super.key});

  @override
  State<GotoPopularLive> createState() => _GotoPopularLiveState();
}

class _GotoPopularLiveState extends State<GotoPopularLive> {
  // String liveType = 'public';
  LivestreamController liveController = Get.find();
  final AgoraService _agoraService = AgoraService();
  bool isEngineReady = false;
  Timer? _beautyApplyDebounce;
  Timer? _colorApplyDebounce;

  TextEditingController textEditingController = TextEditingController(
    text: 'hello',
  );

  Future<void> initAgora() async {
    print('GotoPopularLive: Checking Agora status...');

    // Request permissions only when entering live setup
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      print('Permissions not granted');
      if (mounted) {
        setState(() {
          isEngineReady = false;
        });
      }
      return;
    }

    // Initialize Agora engine via service
    bool success = _agoraService.isInitialized && _agoraService.engine != null;
    if (!success) {
      print(
        'GotoPopularLive: AgoraService not ready, attempting to initialize...',
      );
      success = await _agoraService.initializeEngine();
    }

    // Explicitly start preview only on this screen
    if (success && _agoraService.engine != null) {
      // Set higher video resolution ONLY for this screen
      await _agoraService.engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 540, height: 960),
          frameRate: 15,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeAdaptive,
          degradationPreference: DegradationPreference.maintainBalanced,
        ),
      );
      debugPrint('VIDEO_ENCODER_BALANCED');
      try {
        await _agoraService.engine!.setParameters(
          '{"che.video.hardware_encoding": true,'
              '"che.video.enableAdaptiveBitrate": true,'
              '"rtc.video.dynamic_switch": true}',
        );
        await _agoraService.engine!.enableVideo();
        await _agoraService.engine!.enableLocalVideo(true);
        await _agoraService.engine!.muteLocalVideoStream(false);
      } catch (e) {
        debugPrint('CAMERA_BALANCED_SETUP_SKIPPED => $e');
      }

      // Fast low-light + moderate natural beauty keeps faces visible without
      // stacking heavy effects. The same encoder profile is reused in live view,
      // avoiding the old preview-to-live camera restart and dark/soft image.
      await _agoraService.applyNaturalLowLightEnhancement();
      await _agoraService.setBeautyCustom(
        contrast: LighteningContrastLevel.lighteningContrastNormal,
        lightening: 0.48,
        smoothness: 0.48,
        redness: 0.20,
        sharpness: 0.42,
      );
      await _agoraService.setColorEnhance(
        strength: 0.22,
        skinProtect: 0.42,
      );

      // Start local preview with the above configuration
      await _agoraService.startPreview();
    }

    if (mounted) {
      setState(() {
        isEngineReady = success;
      });
    }

    if (success) {
      print('GotoPopularLive: Agora is ready');
    } else {
      print('GotoPopularLive: Failed to initialize Agora');
    }
  }

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  @override
  void dispose() {
    _beautyApplyDebounce?.cancel();
    _beautyApplyDebounce = null;
    _colorApplyDebounce?.cancel();
    _colorApplyDebounce = null;
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
    AgoraTokenController agoraTokenController = Get.find();
    return Scaffold(
      backgroundColor: Colors.transparent, // Camera pure full screen dekhabe
      body: Stack(
        children: [
          // === FULL SCREEN CAMERA BACKGROUND ===
          Positioned.fill(
            child: isEngineReady && _agoraService.engine != null
                ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: const VideoCanvas(
                  uid: 0,
                  renderMode: RenderModeType.renderModeHidden,
                  mirrorMode: VideoMirrorModeType.videoMirrorModeEnabled,
                ),
              ),
            )
                : Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      ('Initializing camera...').appTr,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // === UI OVERLAY ===
          SafeArea(
            child: Column(
              children: [
                // ==== Top bar ====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Get.dialog(
                          Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Container(
                              width: Get.width * 0.85,
                              padding: const EdgeInsets.all(16),
                              child: Obx(() {
                                final isPasswordMode =
                                    liveController.selectedType.value ==
                                        "Please set room password";

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Dropdown
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Color(0xffb5a7fe),
                                        ),
                                        color: const Color(0xffb5a7fe),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: CustomDropdown(
                                        closedHeaderPadding:
                                        const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 10,
                                        ),
                                        hintText:
                                        ('Select National ID Type').appTr,
                                        items: liveController.nationalIdentity,
                                        initialItem:
                                        liveController.nationalIdentity[0],
                                        canCloseOutsideBounds: true,
                                        decoration: CustomDropdownDecoration(
                                          prefixIcon: isPasswordMode
                                              ? Icon(
                                            Icons.password_outlined,
                                            color: Color(0xff933efa),
                                          )
                                              : Image.asset(
                                            'assets/audio_live/gift.png',
                                            height: 20,
                                            width: 20,
                                          ),
                                          closedSuffixIcon: const Icon(
                                            Icons.arrow_drop_down_outlined,
                                            color: Colors.black87,
                                          ),
                                          headerStyle: GoogleFonts.lato(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                          closedFillColor: const Color(
                                            0xffb5a7fe,
                                          ),
                                          listItemStyle: GoogleFonts.lato(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
                                          hintStyle: GoogleFonts.lato(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
                                          ),
                                          closedBorderRadius:
                                          BorderRadius.circular(8),
                                          expandedFillColor: Colors.white,
                                        ),
                                        onChanged: (value) {
                                          liveController.selectedType.value =
                                          value!;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Input Field
                                    TextField(
                                      obscureText: isPasswordMode,
                                      style: const TextStyle(
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: isPasswordMode
                                            ? 'Enter your password'
                                            : 'Enter gift ',
                                        hintStyle: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 12,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.black38,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xff8b42fa),
                                          ),
                                        ),
                                        suffixIcon: isPasswordMode
                                            ? const FaIcon(
                                          FontAwesomeIcons.eyeSlash,
                                          color: Color(0xff8b42fa),
                                          size: 14,
                                        )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Confirm Button
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: TextButton(
                                        onPressed: () {
                                          Get.back();
                                        },
                                        child: Text(
                                          ("Confirm").appTr,
                                          style: TextStyle(
                                            color: Color(0xff8b42fa),
                                            fontWeight: FontWeight.bold,
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
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Castontext(
                          fontSize: kHeight * 0.017,
                          fontWeight: FontWeight.w600,
                          textColor: Colors.white,
                          text: 'password',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Get.back();
                        },
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                // ==== Middle scrollable area ====
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Cover photo + textfield
                        Stack(
                          children: [
                            InkWell(
                              onTap: () {
                                liveController.kycNidShow();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  vertical: kHeight * 0.01,
                                  horizontal: kWeight * 0.02,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                height: kHeight * 0.13,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.black38,
                                ),
                                child: Row(
                                  children: [
                                    liveController.videoImage.isEmpty
                                        ? Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xff2c0375),
                                            Color(0xff41026e),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white
                                                .withOpacity(0.2),
                                            spreadRadius: 2,
                                            blurRadius: 10,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        child: Image.asset(
                                          appLogo,
                                          width: kHeight * 0.1,
                                          height: kHeight * 0.1,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                        : Obx(
                                          () => Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        width: kWeight * 0.21,
                                        child: ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          child: Image.file(
                                            File(
                                              liveController
                                                  .videoImage
                                                  .value,
                                            ),
                                            height: kHeight * 0.094,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: kWeight * 0.02),
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 35,
                                          width: 200,
                                          child: TextField(
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            controller: textEditingController,
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText:
                                              ('Write a live title').appTr,
                                              hintStyle: GoogleFonts.lato(
                                                fontSize: kHeight * 0.015,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Positioned(
                            //   left: kWeight * 0.058,
                            //   top: kHeight * 0.098,
                            //   child: Container(
                            //     padding: EdgeInsets.symmetric(
                            //         vertical: 3, horizontal: kWeight * 0.022),
                            //     decoration: BoxDecoration(
                            //       borderRadius: const BorderRadius.only(
                            //         bottomLeft: Radius.circular(10),
                            //         bottomRight: Radius.circular(10),
                            //       ),
                            //       color:
                            //           const Color(0xff704bfa).withOpacity(0.3),
                            //     ),
                            //     child: Castontext(
                            //       textColor: Colors.white,
                            //       fontWeight: FontWeight.w500,
                            //       fontSize: kHeight * 0.014,
                            //       text: 'Cover photo',
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ==== Bottom fixed buttons ====
                Padding(
                  padding: EdgeInsets.only(bottom: kHeight * 0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      InkWell(
                        onTap: () {
                          _openFilterSheet();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xfff93776),
                                Color(0xff7f23e8),
                                Color(0xff218afb),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/download__26_-removebg-preview.png',
                            height: 35,
                            color: Colors.white,
                            width: 35,
                          ),
                        ),
                      ),
                      Obx(() {
                        final bool loading =
                            liveController.isCreatingLive.value ||
                                agoraTokenController.tokenIsLoading.value;
                        return InkWell(
                          onTap: loading
                              ? null
                              : () async {
                            await liveController.tryToCreateLivestream(
                              streamTitle: textEditingController.text,
                              streamType: 'popular',
                              userId: authController
                                  .userProfile
                                  .value
                                  .user!
                                  .id!
                                  .toInt(),
                              anousment: 'ss',
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            height: kHeight * 0.056,
                            width: kWeight * 0.56,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: loading
                                    ? const [
                                  Color(0xffC9A3AD),
                                  Color(0xffB78C98),
                                ]
                                    : const [
                                  Color(0xffF80230),
                                  Color(0xffFF4770),
                                ],
                              ),
                              boxShadow: loading
                                  ? null
                                  : const [
                                BoxShadow(
                                  color: Color(0x45F80230),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (loading)
                                  const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.videocam_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                const SizedBox(width: 9),
                                Text(
                                  loading
                                      ? ('Creating Live...').appTr
                                      : ('Go Live').appTr,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: kHeight * 0.016,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      InkWell(
                        onTap: () {
                          AgoraService().flipCamera();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xfff93776),
                                Color(0xff7f23e8),
                                Color(0xff218afb),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Image.asset(
                            'assets/audio_live/wireless.png',
                            height: kHeight * 0.04,
                            color: Colors.white,
                            width: kHeight * 0.04,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyBeautyPreset({
    required LighteningContrastLevel contrast,
    required double lightening,
    required double smoothness,
    required double redness,
    required double sharpness,
    double colorStrength = 0.0,
    double skinProtect = 0.40,
  }) async {
    _beautyApplyDebounce?.cancel();
    _colorApplyDebounce?.cancel();

    await _agoraService.disableAllVideoEffects();
    await _agoraService.setBeautyCustom(
      contrast: contrast,
      lightening: lightening,
      smoothness: smoothness,
      redness: redness,
      sharpness: sharpness,
    );
    if (colorStrength > 0) {
      await _agoraService.setColorEnhance(
        strength: colorStrength,
        skinProtect: skinProtect,
      );
    }
  }

  void _scheduleBeautyApply({
    required LighteningContrastLevel contrast,
    required double lightening,
    required double smoothness,
    required double redness,
    required double sharpness,
  }) {
    _beautyApplyDebounce?.cancel();
    _beautyApplyDebounce = Timer(const Duration(milliseconds: 90), () {
      _agoraService.setBeautyCustom(
        contrast: contrast,
        lightening: lightening,
        smoothness: smoothness,
        redness: redness,
        sharpness: sharpness,
      );
    });
  }

  void _scheduleColorApply({
    required double strength,
    required double skinProtect,
  }) {
    _colorApplyDebounce?.cancel();
    _colorApplyDebounce = Timer(const Duration(milliseconds: 90), () {
      _agoraService.setColorEnhance(
        strength: strength,
        skinProtect: skinProtect,
      );
    });
  }

  // ================= FILTER BOTTOM SHEET =================
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.black.withOpacity(0.5),
      builder: (ctx) {
        // Tuning values (0.0 - 1.0)
        // HD-oriented baseline values
        double colorStrength = 0.4;
        double skinProtect = 0.3;
        double lightening = 0.55; // brighter look
        double smoothness = 0.60; // smoother skin
        double redness = 0.25; // natural warmth
        double sharpness = 0.60; // crisper details
        String activePreset = 'Natural';
        LighteningContrastLevel contrast =
            LighteningContrastLevel.lighteningContrastHigh; // punchy contrast
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) {
              return DefaultTabController(
                length: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  height: kHeight * 0.48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ('Beauty & Filters').appTr,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TabBar(
                          indicatorColor: Colors.transparent,
                          dividerColor: Colors.transparent,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: const Color(0xFF6A5AE0).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          tabs: [
                            Tab(
                              icon: Icon(Icons.auto_awesome),
                              text: ('Presets').appTr,
                            ),
                            Tab(icon: Icon(Icons.tune), text: ('Beauty').appTr),
                            Tab(
                              icon: Icon(Icons.color_lens),
                              text: ('Color').appTr,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Presets tab
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _presetChip(
                                      ('Custom').appTr,
                                      selected: activePreset == 'Custom',
                                      onTap: () async {
                                        setState(() => activePreset = 'Custom');
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                    _presetChip(
                                      'None (HD)',
                                      selected: activePreset == 'None',
                                      onTap: () async {
                                        setState(() => activePreset = 'None');
                                        // Ensure HD encoder with no visual filters
                                        try {
                                          if (_agoraService.engine != null) {
                                            await _agoraService.engine!
                                                .setVideoEncoderConfiguration(
                                              const VideoEncoderConfiguration(
                                                dimensions: VideoDimensions(
                                                  width: 540,
                                                  height: 960,
                                                ),
                                                frameRate: 15,
                                                bitrate: 0,
                                                orientationMode: OrientationMode
                                                    .orientationModeAdaptive,
                                                degradationPreference:
                                                DegradationPreference
                                                    .maintainBalanced,
                                              ),
                                            );
                                          }
                                        } catch (_) {}

                                        await _agoraService
                                            .disableAllVideoEffects();
                                      },
                                    ),
                                    _presetChip(
                                      'Natural',
                                      selected: activePreset == 'Natural',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Natural';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.55;
                                          smoothness = 0.60;
                                          redness = 0.25;
                                          sharpness = 0.50;
                                        });
                                        await _agoraService
                                            .disableAllVideoEffects();
                                        await _agoraService.setBeautyNatural();
                                      },
                                    ),
                                    _presetChip(
                                      'Smooth',
                                      selected: activePreset == 'Smooth',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Smooth';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.55;
                                          smoothness = 0.75;
                                          redness = 0.22;
                                          sharpness = 0.40;
                                        });
                                        await _agoraService
                                            .disableAllVideoEffects();
                                        await _agoraService.setBeautySmooth();
                                      },
                                    ),
                                    _presetChip(
                                      'Glossy',
                                      selected: activePreset == 'Glossy',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Glossy';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.65;
                                          smoothness = 0.65;
                                          redness = 0.30;
                                          sharpness = 0.55;
                                        });
                                        await _agoraService
                                            .disableAllVideoEffects();
                                        await _agoraService.setBeautyGlossy();
                                      },
                                    ),
                                    _presetChip(
                                      'Rosy',
                                      selected: activePreset == 'Rosy',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Rosy';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.55;
                                          smoothness = 0.60;
                                          redness = 0.55;
                                          sharpness = 0.45;
                                        });
                                        await _agoraService
                                            .disableAllVideoEffects();
                                        await _agoraService.setBeautyRosy();
                                      },
                                    ),
                                    _presetChip(
                                      'HD',
                                      selected: activePreset == 'HD',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'HD';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.60;
                                          smoothness = 0.65;
                                          redness = 0.25;
                                          sharpness = 0.70;
                                        });
                                        // Keep encoder HD while applying HD beauty
                                        try {
                                          if (_agoraService.engine != null) {
                                            await _agoraService.engine!
                                                .setVideoEncoderConfiguration(
                                              const VideoEncoderConfiguration(
                                                dimensions: VideoDimensions(
                                                  width: 540,
                                                  height: 960,
                                                ),
                                                frameRate: 15,
                                                bitrate: 0,
                                                orientationMode: OrientationMode
                                                    .orientationModeAdaptive,
                                                degradationPreference:
                                                DegradationPreference
                                                    .maintainBalanced,
                                              ),
                                            );
                                          }
                                        } catch (_) {}
                                        await _agoraService
                                            .disableAllVideoEffects();
                                        await _agoraService.setBeautyHD();
                                      },
                                    ),
                                    _presetChip(
                                      'Blemish',
                                      selected: activePreset == 'Blemish',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Blemish';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastNormal;
                                          lightening = 0.50;
                                          smoothness = 0.80;
                                          redness = 0.22;
                                          sharpness = 0.35;
                                        });
                                        await _agoraService
                                            .disableAllVideoEffects();
                                        await _agoraService.setBeautyBlemish();
                                      },
                                    ),
                                    _presetChip(
                                      'Bright',
                                      selected: activePreset == 'Bright',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Bright';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastNormal;
                                          lightening = 0.72;
                                          smoothness = 0.50;
                                          redness = 0.20;
                                          sharpness = 0.48;
                                          colorStrength = 0.20;
                                          skinProtect = 0.48;
                                        });
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                    _presetChip(
                                      'Clear',
                                      selected: activePreset == 'Clear',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Clear';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.48;
                                          smoothness = 0.36;
                                          redness = 0.16;
                                          sharpness = 0.82;
                                          colorStrength = 0.34;
                                          skinProtect = 0.45;
                                        });
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                    _presetChip(
                                      'Soft',
                                      selected: activePreset == 'Soft',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Soft';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastLow;
                                          lightening = 0.56;
                                          smoothness = 0.76;
                                          redness = 0.20;
                                          sharpness = 0.28;
                                          colorStrength = 0.15;
                                          skinProtect = 0.55;
                                        });
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                    _presetChip(
                                      'Warm',
                                      selected: activePreset == 'Warm',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Warm';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastNormal;
                                          lightening = 0.56;
                                          smoothness = 0.56;
                                          redness = 0.42;
                                          sharpness = 0.44;
                                          colorStrength = 0.30;
                                          skinProtect = 0.45;
                                        });
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                    _presetChip(
                                      'Fresh',
                                      selected: activePreset == 'Fresh',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Fresh';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.60;
                                          smoothness = 0.44;
                                          redness = 0.12;
                                          sharpness = 0.62;
                                          colorStrength = 0.40;
                                          skinProtect = 0.50;
                                        });
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                    _presetChip(
                                      'Studio',
                                      selected: activePreset == 'Studio',
                                      onTap: () async {
                                        setState(() {
                                          activePreset = 'Studio';
                                          contrast = LighteningContrastLevel
                                              .lighteningContrastHigh;
                                          lightening = 0.66;
                                          smoothness = 0.60;
                                          redness = 0.26;
                                          sharpness = 0.64;
                                          colorStrength = 0.44;
                                          skinProtect = 0.50;
                                        });
                                        await _applyBeautyPreset(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                          colorStrength: colorStrength,
                                          skinProtect: skinProtect,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Beauty tuning tab
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ('Contrast').appTr,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        _presetChip(
                                          'Low',
                                          selected:
                                          contrast ==
                                              LighteningContrastLevel
                                                  .lighteningContrastLow,
                                          onTap: () {
                                            setState(
                                                  () => contrast =
                                                  LighteningContrastLevel
                                                      .lighteningContrastLow,
                                            );
                                            _scheduleBeautyApply(
                                              contrast: contrast,
                                              lightening: lightening,
                                              smoothness: smoothness,
                                              redness: redness,
                                              sharpness: sharpness,
                                            );
                                          },
                                        ),
                                        _presetChip(
                                          'Normal',
                                          selected:
                                          contrast ==
                                              LighteningContrastLevel
                                                  .lighteningContrastNormal,
                                          onTap: () {
                                            setState(
                                                  () => contrast =
                                                  LighteningContrastLevel
                                                      .lighteningContrastNormal,
                                            );
                                            _scheduleBeautyApply(
                                              contrast: contrast,
                                              lightening: lightening,
                                              smoothness: smoothness,
                                              redness: redness,
                                              sharpness: sharpness,
                                            );
                                          },
                                        ),
                                        _presetChip(
                                          'High',
                                          selected:
                                          contrast ==
                                              LighteningContrastLevel
                                                  .lighteningContrastHigh,
                                          onTap: () {
                                            setState(
                                                  () => contrast =
                                                  LighteningContrastLevel
                                                      .lighteningContrastHigh,
                                            );
                                            _scheduleBeautyApply(
                                              contrast: contrast,
                                              lightening: lightening,
                                              smoothness: smoothness,
                                              redness: redness,
                                              sharpness: sharpness,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _sliderRow(
                                      label: ('Lightening').appTr,
                                      value: lightening,
                                      onChanged: (v) {
                                        setState(() {
                                          lightening = v;
                                          activePreset = 'Custom';
                                        });
                                        _scheduleBeautyApply(
                                          contrast: contrast,
                                          lightening: v,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: sharpness,
                                        );
                                      },
                                    ),
                                    _sliderRow(
                                      label: ('Smoothness').appTr,
                                      value: smoothness,
                                      onChanged: (v) {
                                        setState(() {
                                          smoothness = v;
                                          activePreset = 'Custom';
                                        });
                                        _scheduleBeautyApply(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: v,
                                          redness: redness,
                                          sharpness: sharpness,
                                        );
                                      },
                                    ),
                                    _sliderRow(
                                      label: ('Redness').appTr,
                                      value: redness,
                                      onChanged: (v) {
                                        setState(() {
                                          redness = v;
                                          activePreset = 'Custom';
                                        });
                                        _scheduleBeautyApply(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: v,
                                          sharpness: sharpness,
                                        );
                                      },
                                    ),
                                    _sliderRow(
                                      label: ('Sharpness').appTr,
                                      value: sharpness,
                                      onChanged: (v) {
                                        setState(() {
                                          sharpness = v;
                                          activePreset = 'Custom';
                                        });
                                        _scheduleBeautyApply(
                                          contrast: contrast,
                                          lightening: lightening,
                                          smoothness: smoothness,
                                          redness: redness,
                                          sharpness: v,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Color enhance tab
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ('Color Enhance').appTr,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ('Strength').appTr,
                                                style: GoogleFonts.roboto(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              Slider(
                                                value: colorStrength,
                                                min: 0,
                                                max: 1,
                                                onChanged: (v) {
                                                  setState(
                                                        () => colorStrength = v,
                                                  );
                                                  _scheduleColorApply(
                                                    strength: v,
                                                    skinProtect: skinProtect,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ('Skin Protect').appTr,
                                                style: GoogleFonts.roboto(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              Slider(
                                                value: skinProtect,
                                                min: 0,
                                                max: 1,
                                                onChanged: (v) {
                                                  setState(
                                                        () => skinProtect = v,
                                                  );
                                                  _scheduleColorApply(
                                                    strength: colorStrength,
                                                    skinProtect: v,
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF6A5AE0,
                                              ),
                                            ),
                                            onPressed: () async {
                                              await _agoraService
                                                  .disableAllVideoEffects();
                                              if (mounted)
                                                Navigator.of(context).pop();
                                            },
                                            child: Text(('Reset All').appTr),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _presetChip(
      String label, {
        required bool selected,
        required VoidCallback onTap,
      }) {
    final bg = selected ? const Color(0xFF6A5AE0) : Colors.white10;
    final borderColor = selected ? const Color(0xFF6A5AE0) : Colors.white24;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: selected
              ? [
            BoxShadow(
              color: const Color(0xFF6A5AE0).withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.roboto(color: Colors.white70)),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
