import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/vipcarddesign.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class GotoAudioLiveView extends StatefulWidget {
  const GotoAudioLiveView({super.key});

  @override
  State<GotoAudioLiveView> createState() => _GotoAudioLiveViewState();
}

class _GotoAudioLiveViewState extends State<GotoAudioLiveView> {
  final LivestreamController livestreamController = Get.find();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController announcementController = TextEditingController();

  int selectedMood = 0;
  int selectedTheme = -1;
  int selectedLayout = 0;
  int selectedBackground = 0;
  String announcementText = "";

  final List<List<Color>> themeGradients =  [
    [kAppColor2.withOpacity(.6), kAppColor2.withOpacity(.6), kAppColor1.withOpacity(.6)],
    [Color(0xfff6eee6), Color(0xffd7b98d), Color(0xff7b4a1d)],
    [Color(0xff6b203c), Color(0xff973d8f), Color(0xff2b124c)],
    [Color(0xffa8f5d0), Color(0xff55b97b), Color(0xff135c44)],
  ];

  final List<String> backgroundImages = [
    "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=900",
    "https://images.unsplash.com/photo-1519608487953-e999c86e7455?w=900",
    "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=900",
    "https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=900",
  ];

  @override
  void initState() {
    super.initState();
    livestreamController.seatCount.value = 9;

    // Default title will be current account name. User can still edit it.
    final userName = authController.userProfile.value.user?.name?.toString().trim() ?? '';
    if (userName.isNotEmpty && titleController.text.trim().isEmpty) {
      titleController.text = userName;
    }

    // New live open hole previous picked image/announcement leak korbe na.
    livestreamController.audioImage.value = '';

    /// API theke theme/background list load hobe.
    livestreamController.showTheme();
    livestreamController.showBackground();
  }

  @override
  void dispose() {
    titleController.dispose();
    announcementController.dispose();
    super.dispose();
  }

  int _getThemeId() {
    final list = livestreamController.themeList;
    if (selectedTheme >= 0 && selectedTheme < list.length) {
      final item = list[selectedTheme];
      if (item is Map && item['id'] != null) {
        return int.tryParse(item['id'].toString()) ?? 0;
      }
    }
    return 0;
  }

  int _getBackgroundId() {
    if (selectedBackground == -1) return -1;

    final list = livestreamController.backgroundList;
    if (selectedBackground >= 0 && selectedBackground < list.length) {
      final item = list[selectedBackground];
      if (item is Map && item['id'] != null) {
        return int.tryParse(item['id'].toString()) ?? -1;
      }
    }
    return -1;
  }

  String? _getThemeImageUrl() {
    final list = livestreamController.themeList;
    if (selectedTheme >= 0 && selectedTheme < list.length) {
      final item = list[selectedTheme];
      if (item is Map && item['image'] != null) {
        return ImageHelper.getImageUrl(item['image'].toString());
      }
    }
    return null;
  }

  String? _getBackgroundImageUrl() {
    if (selectedBackground == -1) return null;

    final list = livestreamController.backgroundList;
    if (selectedBackground >= 0 && selectedBackground < list.length) {
      final item = list[selectedBackground];
      if (item is Map && item['image'] != null) {
        return ImageHelper.getImageUrl(item['image'].toString());
      }
    }
    return null;
  }

  String? _getRoomImageUrl() {
    /// Only background tab theke image select korle main room background image show korbe.
    /// Theme tab theke select korle image na, theme color/gradient apply hobe.
    return _getBackgroundImageUrl();
  }

  void _openSeatBottomSheet() {
    Get.bottomSheet(
      SeatCountBottomSheet(
        selectedSeat: livestreamController.seatCount.value,
        onSelect: (seat) {
          setState(() {
            livestreamController.seatCount.value = seat;

            /// 9 seat default = top owner + 4 + 4.
            /// 12 seat default = top 2 + 5 + 5.
            /// Other seat sets keep their safe default style.
            if (seat == 9) {
              selectedLayout = 0;
            } else if (seat == 12) {
              selectedLayout = 4;
            } else {
              selectedLayout = 0;
            }
          });
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

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

  void _openThemeSheet() {
    Get.bottomSheet(
      Obx(() {
        return RoomThemeBottomSheet(
          seatCount: livestreamController.seatCount.value,
          selectedTheme: selectedTheme,
          selectedLayout: selectedLayout,
          selectedBackground: selectedBackground,
          themeList: livestreamController.themeList,
          backgroundList: livestreamController.backgroundList,
          backgroundImages: backgroundImages,
          onThemeSelect: (index) {
            setState(() {
              selectedTheme = index;

              /// Theme select korle API theme image main background-e show hobe na.
              /// Theme color/gradient apply hobe.
              selectedBackground = -1;
            });
          },
          onLayoutSelect: (index) {
            setState(() => selectedLayout = index);
          },
          onBackgroundSelect: (index) {
            setState(() {
              selectedBackground = index;
              /// Background image is the real room background; theme must not override it.
              selectedTheme = -1;
            });
          },
        );
      }),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }



  Future<bool> _ensureMicrophonePermissionBeforeCreate() async {
    try {
      PermissionStatus status = await Permission.microphone.status;

      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        return true;
      }

      Fluttertoast.showToast(
        msg: ('Please allow microphone permission for audio live').appTr,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: kHeight * 0.012,
      );

      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Microphone permission check failed: $e');
      return true;
    }
  }

  /// Use this on your custom icon onTap:
  /// InkWell(onTap: _createDefaultNineSeatBackgroundLive, ...)
  /// It creates an audio live with 9 seats + first background image, without theme overriding background.
  Future<void> createDefaultNineSeatBackgroundLive() async {
    FocusScope.of(context).unfocus();

    final bool micReady = await _ensureMicrophonePermissionBeforeCreate();
    if (!micReady) return;

    final user = authController.userProfile.value.user;
    final String title = titleController.text.trim().isEmpty
        ? (user?.name?.toString().trim().isNotEmpty == true ? user!.name.toString() : 'Live Room')
        : titleController.text.trim();

    setState(() {
      livestreamController.seatCount.value = 9;
      selectedLayout = 0;
      selectedTheme = -1;
      selectedBackground = 0;
    });

    livestreamController.mute.value = false;

    // GotoAudioLiveView theke call korar somoy:
    await livestreamController.tryToCreateLivestream(
      streamTitle: title,
      streamType: 'audio',
      userId: authController.userProfile.value.user!.id!.toInt(),

      seatCountValue: livestreamController.seatCount.value,
      roomLayout: selectedLayout,
      roomTheme: _getThemeId(),
      roomBackground: _getBackgroundId(),
      anousment: announcementText.trim(),
      streamImageFile: livestreamController.audioImage.value.trim().isEmpty
          ? null
          : File(livestreamController.audioImage.value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = kHeight;
    final w = kWeight;

    final roomImageUrl = _getRoomImageUrl();
    final safeThemeIndex = themeGradients.isEmpty
        ? 0
        : selectedTheme.clamp(0, 999999).toInt() % themeGradients.length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: themeGradients[safeThemeIndex].last,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: h,
        width: w,
        decoration: BoxDecoration(
          gradient: roomImageUrl == null
              ? LinearGradient(
            colors: themeGradients[safeThemeIndex],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
              : null,
          image: roomImageUrl == null
              ? null
              : DecorationImage(
            image: CachedNetworkImageProvider(roomImageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(.18),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: h * 0.014),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.045),
                child: _TopLiveInfoCard(
                  titleController: titleController,
                  announcementText: announcementText,
                  onAnnouncementTap: _openAnnouncementSheet,
                  livestreamController: livestreamController,
                  selectedMood: selectedMood,
                  onMoodSelect: (index) {
                    setState(() => selectedMood = index);
                  },
                ),
              ),

              SizedBox(height: h * 0.06),

              Obx(() {
                return _SeatArea(
                  seatCount: livestreamController.seatCount.value,
                  layoutType: selectedLayout,
                  onSeatTap: _openSeatBottomSheet,
                );
              }),

              SizedBox(height: h * 0.01),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.08),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BottomMenuItem(
                      icon: Icons.event_seat,
                      title: ("Seats").appTr,
                      onTap: _openSeatBottomSheet,
                    ),
                    _BottomMenuItem(
                      icon: Icons.card_giftcard,
                      title: ("Theme").appTr,
                      onTap: _openThemeSheet,
                    ),

                  ],
                ),
              ),

              SizedBox(height: h * 0.02),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.045),
                child: GestureDetector(
                  onTap: () async {
                    if (kDebugMode) {
                      debugPrint(
                        'create_tap=${DateTime.now().microsecondsSinceEpoch}',
                      );
                    }
                    FocusScope.of(context).unfocus();

                    final user = authController.userProfile.value.user;
                    final String liveTitle = titleController.text.trim().isEmpty
                        ? (user?.name?.toString().trim().isNotEmpty == true
                        ? user!.name.toString().trim()
                        : 'Live Room')
                        : titleController.text.trim();

                    final bool micReady = await _ensureMicrophonePermissionBeforeCreate();
                    if (!micReady) return;

                    livestreamController.mute.value = false;

                    // GotoAudioLiveView theke call korar somoy:
                    if (livestreamController.isCreatingLive.value) return;

                    await livestreamController.tryToCreateLivestream(
                      streamTitle: liveTitle,
                      anousment: announcementText.trim(),
                      streamType: 'audio',
                      userId: authController.userProfile.value.user!.id!.toInt(),

                      seatCountValue: livestreamController.seatCount.value,
                      roomLayout: selectedLayout,
                      roomTheme: _getBackgroundId() >= 0 ? 0 : _getThemeId(),
                      roomBackground: _getBackgroundId(),
                      streamImageFile: livestreamController.audioImage.value.trim().isEmpty
                          ? null
                          : File(livestreamController.audioImage.value.trim()),
                    );
                  },
                  child: Container(
                    height: h * 0.050,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(.7)),
                      gradient: const LinearGradient(
                        colors: [kAppColor2, kAppColor1],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Obx(() {
                      final loading = livestreamController.isCreatingLive.value;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: loading
                            ? const SizedBox(
                          key: ValueKey('live-loading'),
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          ("Go Live").appTr,
                          key: const ValueKey('go-live-text'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: h * 0.016,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              SizedBox(height: h * 0.016),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================= SEAT AREA =================

class _SeatArea extends StatelessWidget {
  final int seatCount;
  final int layoutType;
  final VoidCallback onSeatTap;

  const _SeatArea({
    required this.seatCount,
    required this.layoutType,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = kHeight;
    final w = kWeight;

    final profileUrl = ImageHelper.getImageUrl(
      authController.userProfile.value.user?.profileImage,
    );

    /// Layout change only for 9 and 12 seats.
    /// 15/20 and other default sets will stay exactly default style.
    final appliedLayout = seatCount == 9
        ? layoutType.clamp(0, 3).toInt()
        : seatCount == 12
        ? layoutType.clamp(0, 4).toInt()
        : 0;

    final seatSize = seatCount == 9
        ? h * 0.050
        : seatCount == 12
        ? h * 0.045
        : seatCount == 15
        ? h * 0.047
        : h * 0.043;

    return SizedBox(
      height: h * 0.35,
      width: double.infinity,
      child: Padding(
        /// 20px left/right gap, so 9/12/15/20 seats get more width
        /// and stay nicely centered on the page.
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey('$seatCount-$appliedLayout'),
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (seatCount == 9) ...[
                _layout9(h, appliedLayout, seatSize, profileUrl),
              ] else if (seatCount == 12) ...[
                _layout12(h, appliedLayout, seatSize, profileUrl),
              ] else if (seatCount == 15) ...[
                _layout15(h, seatSize, profileUrl),
              ] else if (seatCount == 20) ...[
                _layout20(h, seatSize, profileUrl),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerAvatar(String url, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: size / 2.25,
        backgroundImage: CachedNetworkImageProvider(url),
      ),
    );
  }

  Widget _seat(double size) {
    return _SeatCircle(
      size: size,
      onTap: onSeatTap,
    );
  }

  Widget _seatRow(int count, double size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(count, (_) => _seat(size)),
    );
  }

  Widget _layout9(
      double h,
      int layout,
      double size,
      String profileUrl,
      ) {
    final positions = _seatPositions(count: 9, layout: layout);

    return _PatternSeatStack(
      height: h * 0.320,
      seatSize: size,
      positions: positions,
      ownerBuilder: () => _ownerAvatar(profileUrl, size),
      seatBuilder: () => _seat(size),
    );
  }

  Widget _layout12(
      double h,
      int layout,
      double size,
      String profileUrl,
      ) {
    final positions = _seatPositions(count: 12, layout: layout);

    return _PatternSeatStack(
      height: h * 0.330,
      seatSize: size,
      positions: positions,
      ownerBuilder: () => _ownerAvatar(profileUrl, size),
      seatBuilder: () => _seat(size),
    );
  }

  Widget _layout15(
      double h,
      double size,
      String profileUrl,
      ) {
    final positions = _seatPositions(count: 15, layout: 0);

    return _PatternSeatStack(
      height: h * 0.300,
      seatSize: size,
      positions: positions,
      ownerBuilder: () => _ownerAvatar(profileUrl, size),
      seatBuilder: () => _seat(size),
    );
  }

  Widget _layout20(
      double h,
      double size,
      String profileUrl,
      ) {
    final positions = _seatPositions(count: 20, layout: 0);

    return _PatternSeatStack(
      height: h * 0.335,
      seatSize: size,
      positions: positions,
      ownerBuilder: () => _ownerAvatar(profileUrl, size),
      seatBuilder: () => _seat(size),
    );
  }

  List<_SeatPoint> _seatPositions({
    required int count,
    required int layout,
  }) {
    /// ================= 9 SEAT LAYOUTS =================
    /// Layout 0/default: top owner 1, below 4 + 4.
    if (count == 9 && layout == 0) {
      return const [
        _SeatPoint(.50, .17, true),
        _SeatPoint(.20, .46, false),
        _SeatPoint(.40, .46, false),
        _SeatPoint(.60, .46, false),
        _SeatPoint(.80, .46, false),
        _SeatPoint(.20, .72, false),
        _SeatPoint(.40, .72, false),
        _SeatPoint(.60, .72, false),
        _SeatPoint(.80, .72, false),
      ];
    }

    /// Layout 1: first line 5 seats, second line 4 seats.
    /// Owner profile is the first item of the first line.
    if (count == 9 && layout == 1) {
      return const [
        _SeatPoint(.10, .28, true),
        _SeatPoint(.30, .28, false),
        _SeatPoint(.50, .28, false),
        _SeatPoint(.70, .28, false),
        _SeatPoint(.90, .28, false),
        _SeatPoint(.20, .56, false),
        _SeatPoint(.40, .56, false),
        _SeatPoint(.60, .56, false),
        _SeatPoint(.80, .56, false),
      ];
    }

    /// Layout 2: left side 3, right side 3, bottom 2, middle owner 1.
    if (count == 9 && layout == 2) {
      return const [
        _SeatPoint(.50, .41, true),
        _SeatPoint(.18, .18, false),
        _SeatPoint(.18, .40, false),
        _SeatPoint(.18, .62, false),
        _SeatPoint(.82, .18, false),
        _SeatPoint(.82, .40, false),
        _SeatPoint(.82, .62, false),
        _SeatPoint(.38, .62, false),
        _SeatPoint(.62, .62, false),
      ];
    }

    /// Layout 3: round layout, 8 seats around and owner in center.
    if (count == 9 && layout == 3) {
      return const [
        _SeatPoint(.50, .51, true),
        _SeatPoint(.50, .18, false),
        _SeatPoint(.72, .27, false),
        _SeatPoint(.82, .50, false),
        _SeatPoint(.72, .73, false),
        _SeatPoint(.50, .82, false),
        _SeatPoint(.28, .73, false),
        _SeatPoint(.18, .50, false),
        _SeatPoint(.28, .27, false),
      ];
    }

    /// ================= 12 SEAT LAYOUTS =================
    /// 12 layout 1 / blue: top owner 1, then 6 seats, then 5 seats.
    if (count == 12 && layout == 0) {
      return const [
        _SeatPoint(.50, .16, true),
        _SeatPoint(.08, .42, false),
        _SeatPoint(.24, .42, false),
        _SeatPoint(.40, .42, false),
        _SeatPoint(.56, .42, false),
        _SeatPoint(.72, .42, false),
        _SeatPoint(.88, .42, false),
        _SeatPoint(.12, .68, false),
        _SeatPoint(.31, .68, false),
        _SeatPoint(.50, .68, false),
        _SeatPoint(.69, .68, false),
        _SeatPoint(.88, .68, false),
      ];
    }

    /// 12 layout 2 / orange: 6 seats on top row and 6 seats on bottom row.
    if (count == 12 && layout == 1) {
      return const [
        _SeatPoint(.08, .34, true),
        _SeatPoint(.24, .34, false),
        _SeatPoint(.40, .34, false),
        _SeatPoint(.56, .34, false),
        _SeatPoint(.72, .34, false),
        _SeatPoint(.88, .34, false),
        _SeatPoint(.08, .61, false),
        _SeatPoint(.24, .61, false),
        _SeatPoint(.40, .61, false),
        _SeatPoint(.56, .61, false),
        _SeatPoint(.72, .61, false),
        _SeatPoint(.88, .61, false),
      ];
    }

    /// 12 layout 3 / green: left 4, right 4, bottom 3 and center 1.
    if (count == 12 && layout == 2) {
      return const [
        _SeatPoint(.50, .38, true),
        _SeatPoint(.18, .12, false),
        _SeatPoint(.18, .32, false),
        _SeatPoint(.18, .54, false),
        _SeatPoint(.18, .76, false),
        _SeatPoint(.82, .12, false),
        _SeatPoint(.82, .32, false),
        _SeatPoint(.82, .54, false),
        _SeatPoint(.82, .76, false),
        _SeatPoint(.35, .76, false),
        _SeatPoint(.50, .76, false),
        _SeatPoint(.65, .76, false),
      ];
    }

    /// 12 layout 4 / purple: round style with 10 outer seats and 2 middle seats.
    if (count == 12 && layout == 3) {
      return const [
        _SeatPoint(.40, .50, true),
        _SeatPoint(.60, .50, false),
        _SeatPoint(.38, .18, false),
        _SeatPoint(.62, .18, false),
        _SeatPoint(.18, .32, false),
        _SeatPoint(.82, .32, false),
        _SeatPoint(.12, .52, false),
        _SeatPoint(.88, .52, false),
        _SeatPoint(.18, .72, false),
        _SeatPoint(.82, .72, false),
        _SeatPoint(.38, .86, false),
        _SeatPoint(.62, .86, false),
      ];
    }

    /// 12 layout 5 / cyan: top 2, then 5, then 5.
    /// This is also used as the default 12-seat layout.
    if (count == 12 && layout == 4) {
      return const [
        _SeatPoint(.42, .16, true),
        _SeatPoint(.58, .16, false),
        _SeatPoint(.12, .43, false),
        _SeatPoint(.31, .43, false),
        _SeatPoint(.50, .43, false),
        _SeatPoint(.69, .43, false),
        _SeatPoint(.88, .43, false),
        _SeatPoint(.12, .68, false),
        _SeatPoint(.31, .68, false),
        _SeatPoint(.50, .68, false),
        _SeatPoint(.69, .68, false),
        _SeatPoint(.88, .68, false),
      ];
    }

    /// ================= 15 SEAT DEFAULT LAYOUT =================
    /// Big and centered: first line owner + 4 seats, then 5 + 5.
    if (count == 15) {
      return const [
        _SeatPoint(.10, .18, true),
        _SeatPoint(.30, .18, false),
        _SeatPoint(.50, .18, false),
        _SeatPoint(.70, .18, false),
        _SeatPoint(.90, .18, false),

        _SeatPoint(.10, .48, false),
        _SeatPoint(.30, .48, false),
        _SeatPoint(.50, .48, false),
        _SeatPoint(.70, .48, false),
        _SeatPoint(.90, .48, false),

        _SeatPoint(.10, .76, false),
        _SeatPoint(.30, .76, false),
        _SeatPoint(.50, .76, false),
        _SeatPoint(.70, .76, false),
        _SeatPoint(.90, .76, false),
      ];
    }

    /// ================= 20 SEAT DEFAULT LAYOUT =================
    /// Big and centered: owner + 4 seats, then 5 + 5 + 5.
    if (count == 20) {
      return const [
        _SeatPoint(.10, .13, true),
        _SeatPoint(.30, .13, false),
        _SeatPoint(.50, .13, false),
        _SeatPoint(.70, .13, false),
        _SeatPoint(.90, .13, false),

        _SeatPoint(.10, .39, false),
        _SeatPoint(.30, .39, false),
        _SeatPoint(.50, .39, false),
        _SeatPoint(.70, .39, false),
        _SeatPoint(.90, .39, false),

        _SeatPoint(.10, .64, false),
        _SeatPoint(.30, .64, false),
        _SeatPoint(.50, .64, false),
        _SeatPoint(.70, .64, false),
        _SeatPoint(.90, .64, false),

        _SeatPoint(.10, .89, false),
        _SeatPoint(.30, .89, false),
        _SeatPoint(.50, .89, false),
        _SeatPoint(.70, .89, false),
        _SeatPoint(.90, .89, false),
      ];
    }

    return const [];
  }
}

class _SeatPoint {
  final double x;
  final double y;
  final bool owner;

  const _SeatPoint(this.x, this.y, this.owner);
}

class _PatternSeatStack extends StatelessWidget {
  final double height;
  final double seatSize;
  final List<_SeatPoint> positions;
  final Widget Function() ownerBuilder;
  final Widget Function() seatBuilder;

  const _PatternSeatStack({
    required this.height,
    required this.seatSize,
    required this.positions,
    required this.ownerBuilder,
    required this.seatBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: positions.map((point) {
              return Positioned(
                left: (constraints.maxWidth * point.x) - seatSize / 2,
                top: (constraints.maxHeight * point.y) - seatSize / 2,
                child: point.owner ? ownerBuilder() : seatBuilder(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SeatCircle extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _SeatCircle({
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(.20),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          Icons.weekend_rounded,
          color: Colors.white,
          size: size * 0.62,
        ),
      ),
    );
  }
}


/// ================= TOP CARD =================

class _TopLiveInfoCard extends StatelessWidget {
  final TextEditingController titleController;
  final String announcementText;
  final VoidCallback onAnnouncementTap;
  final LivestreamController livestreamController;
  final int selectedMood;
  final ValueChanged<int> onMoodSelect;

  const _TopLiveInfoCard({
    required this.titleController,
    required this.announcementText,
    required this.onAnnouncementTap,
    required this.livestreamController,
    required this.selectedMood,
    required this.onMoodSelect,
  });

  @override
  Widget build(BuildContext context) {
    final h = kHeight;
    final w = kWeight;

    final moods = [
      {"title": "Chat", "icon": Icons.chat_bubble, "color": const Color(0xff22d5e6)},
      {"title": "Dating", "icon": Icons.whatshot, "color": const Color(0xffff4b3e)},
      {"title": "Games", "icon": Icons.videogame_asset, "color": const Color(0xff2b2d42)},
      {"title": "Interests", "icon": Icons.interests, "color": const Color(0xffffc928)},
      {"title": "Emotional", "icon": Icons.favorite, "color": const Color(0xffff1fb8)},
    ];

    return Container(
      height: h * 0.145,
      padding: EdgeInsets.all(w * 0.025),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => livestreamController.audioimagePicker(),
                child: Obx(() {
                  final localImg = livestreamController.audioImage.value;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: localImg.isEmpty
                        ? CachedNetworkImage(
                      imageUrl: ImageHelper.getImageUrl(
                        authController.userProfile.value.user?.profileImage,
                      ),
                      height: h * 0.09,
                      width: h * 0.09,
                      fit: BoxFit.cover,
                    )
                        : Image.file(
                      File(localImg),
                      height: h * 0.067,
                      width: h * 0.067,
                      fit: BoxFit.cover,
                    ),
                  );
                }),
              ),
              SizedBox(width: w * 0.025),
              Expanded(
                child: Column(
                  children: [
                    _InputLine(
                      controller: titleController,
                      hint: "Add a title",
                    ),
                    SizedBox(height: h * 0.006),
                    GestureDetector(
                      onTap: onAnnouncementTap,
                      child: Container(
                        height: h * 0.030,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.speaker_2_fill,
                              color: Colors.white,
                              size: h * 0.015,
                            ),
                            SizedBox(width: h * 0.006),
                            Expanded(
                              child: Text(
                                announcementText.trim().isEmpty
                                    ? ("Announcement (optional)").appTr: announcementText.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(.78),
                                  fontSize: h * 0.0115,
                                  fontStyle: announcementText.trim().isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
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

        ],
      ),
    );
  }
}

class _InputLine extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _InputLine({
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final h = kHeight;

    return SizedBox(
      height: h * 0.030,
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: h * 0.017,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withOpacity(.65),
            fontSize: h * 0.018,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool active;

  const _CategoryItem({
    required this.icon,
    required this.title,
    required this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = kHeight;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: h * 0.027,
          width: h * 0.045,
          decoration: BoxDecoration(
            color: active ? color : Colors.white.withOpacity(.14),
            borderRadius: BorderRadius.circular(4),
            border: active ? Border.all(color: Colors.white, width: .7) : null,
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : color,
            size: h * 0.015,
          ),
        ),
        SizedBox(height: h * 0.002),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: h * 0.0068,
          ),
        ),
      ],
    );
  }
}

/// ================= ROOM THEME SHEET =================

class RoomThemeBottomSheet extends StatefulWidget {
  final int seatCount;
  final int selectedTheme;
  final int selectedLayout;
  final int selectedBackground;
  final List<dynamic> themeList;
  final List<dynamic> backgroundList;
  final List<String> backgroundImages;
  final ValueChanged<int> onThemeSelect;
  final ValueChanged<int> onLayoutSelect;
  final ValueChanged<int> onBackgroundSelect;

  const RoomThemeBottomSheet({
    super.key,
    required this.seatCount,
    required this.selectedTheme,
    required this.selectedLayout,
    required this.selectedBackground,
    required this.themeList,
    required this.backgroundList,
    required this.backgroundImages,
    required this.onThemeSelect,
    required this.onLayoutSelect,
    required this.onBackgroundSelect,
  });

  @override
  State<RoomThemeBottomSheet> createState() => _RoomThemeBottomSheetState();
}

class _RoomThemeBottomSheetState extends State<RoomThemeBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final tabs = [
    "Theme",
    "Layout",
    "Background",
  ];

  late int localTheme;
  late int localLayout;
  late int localBackground;

  @override
  void initState() {
    super.initState();
    localTheme = widget.selectedTheme;
    localLayout = widget.selectedLayout;
    localBackground = widget.selectedBackground;
    tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = kHeight;
    final w = kWeight;

    return Container(
      height: h * 0.56,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          SizedBox(height: h * 0.012),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.035),
            child: Row(
              children: [
                SizedBox(width: w * 0.08),
                Expanded(
                  child: Center(
                    child: Text(
                      ("Room Theme").appTr,
                      style: GoogleFonts.poppins(
                        fontSize: h * 0.018,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.black),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade300),
          SizedBox(
            height: h * 0.043,
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              labelPadding: EdgeInsets.symmetric(horizontal: w * 0.008),
              tabAlignment: TabAlignment.start,
              tabs: tabs.map((e) {
                return Tab(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.030),
                    height: h * 0.034,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(e),
                  ),
                );
              }).toList(),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey.shade400,
              labelStyle: GoogleFonts.poppins(fontSize: h * 0.013),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: h * 0.013),
            ),
          ),
          SizedBox(height: h * 0.012),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                ThemeTabView(
                  selectedIndex: localTheme,
                  themeList: widget.themeList,
                  onSelect: (index) {
                    setState(() {
                      localTheme = index;

                      /// Theme select korle background image off hobe,
                      /// so main page-e theme gradient/color show korbe.
                      localBackground = -1;
                    });
                    widget.onThemeSelect(index);
                  },
                ),
                LayoutTabView(
                  seatCount: widget.seatCount,
                  selectedIndex: localLayout,
                  onSelect: (index) {
                    setState(() => localLayout = index);
                    widget.onLayoutSelect(index);
                  },
                ),
                BackgroundTabView(
                  selectedIndex: localBackground,
                  backgroundList: widget.backgroundList,
                  images: widget.backgroundImages,
                  onSelect: (index) {
                    setState(() => localBackground = index);
                    widget.onBackgroundSelect(index);
                  },
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= THEME TAB =================

class ThemeTabView extends StatelessWidget {
  final int selectedIndex;
  final List<dynamic> themeList;
  final ValueChanged<int> onSelect;

  const ThemeTabView({
    super.key,
    required this.selectedIndex,
    required this.themeList,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final defaultItems = [
      {
        "id": 0,
        "name": "Default",
        "image": "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=500",
      },
      {
        "id": 0,
        "name": "Olympic Games",
        "image": "https://images.unsplash.com/photo-1519608487953-e999c86e7455?w=500",
      },
      {
        "id": 0,
        "name": "Mysterious",
        "image": "https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=500",
      },
      {
        "id": 0,
        "name": "Harmony",
        "image": "https://images.unsplash.com/photo-1448375240586-882707db888b?w=500",
      },
    ];

    final items = themeList.isNotEmpty ? themeList : defaultItems;

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.035),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: kWeight * 0.045,
        mainAxisSpacing: kHeight * 0.016,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final active = selectedIndex == index;
        final item = items[index];

        final name = item is Map
            ? (item['name'] ?? 'Theme').toString()
            : 'Theme';

        final rawImage = item is Map ? (item['image'] ?? '').toString() : '';
        final imageUrl = rawImage.startsWith('http')
            ? rawImage
            : ImageHelper.getImageUrl(rawImage);

        return GestureDetector(
          onTap: () => onSelect(index),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: active
                        ? Border.all(color: const Color(0xff8d52ef), width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const CupertinoActivityIndicator(),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        if (active)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: CircleAvatar(
                              radius: kHeight * 0.012,
                              backgroundColor: const Color(0xff8d52ef),
                              child: Icon(
                                Icons.check,
                                size: kHeight * 0.014,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: kHeight * 0.006),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: kHeight * 0.014,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ================= LAYOUT TAB =================

class LayoutTabView extends StatelessWidget {
  final int seatCount;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const LayoutTabView({
    super.key,
    required this.seatCount,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xff047fa8),
      const Color(0xffc88622),
      const Color(0xff14833a),
      const Color(0xff6935bd),
      const Color(0xff11cfd7),
    ];

    /// Layout only for 9 and 12 seats.
    /// 9 seat = 4 layouts, 12 seat = 5 layouts.
    final itemCount = seatCount == 9
        ? 4
        : seatCount == 12
        ? 5
        : 0;

    if (itemCount == 0) {
      return Center(
        child: Text(
          ('Layout only available for 9 seat and 12 seat').appTr,
          style: GoogleFonts.poppins(
            fontSize: kHeight * 0.014,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.035),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: kWeight * 0.035,
        mainAxisSpacing: kHeight * 0.018,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final active = selectedIndex == index;

        return GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(4),
              border: active
                  ? Border.all(color: const Color(0xff8d52ef), width: 3)
                  : null,
            ),
            child: Stack(
              children: [
                Center(child: _LayoutPreview(seatCount: seatCount, type: index)),
                if (active)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: kHeight * 0.012,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.check,
                        size: kHeight * 0.014,
                        color: const Color(0xff8d52ef),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LayoutPreview extends StatelessWidget {
  final int seatCount;
  final int type;

  const _LayoutPreview({
    required this.seatCount,
    required this.type,
  });

  Widget _miniSeat({bool owner = false}) {
    return CircleAvatar(
      radius: kHeight * 0.008,
      backgroundColor:
      owner ? Colors.white.withOpacity(.90) : Colors.white.withOpacity(.35),
      child: Icon(
        owner ? Icons.person : Icons.weekend_rounded,
        color: owner ? Colors.grey.shade500 : Colors.white.withOpacity(.72),
        size: kHeight * 0.010,
      ),
    );
  }

  List<_PreviewPoint> _positions9(int type) {
    switch (type) {
    /// 9 layout 1/default: top owner 1, below 4 + 4.
      case 0:
        return const [
          _PreviewPoint(.50, .22, true),
          _PreviewPoint(.20, .50, false),
          _PreviewPoint(.40, .50, false),
          _PreviewPoint(.60, .50, false),
          _PreviewPoint(.80, .50, false),
          _PreviewPoint(.20, .72, false),
          _PreviewPoint(.40, .72, false),
          _PreviewPoint(.60, .72, false),
          _PreviewPoint(.80, .72, false),
        ];

    /// 9 layout 2: first row 5, second row 4. Owner is first profile.
      case 1:
        return const [
          _PreviewPoint(.10, .35, true),
          _PreviewPoint(.30, .35, false),
          _PreviewPoint(.50, .35, false),
          _PreviewPoint(.70, .35, false),
          _PreviewPoint(.90, .35, false),
          _PreviewPoint(.20, .62, false),
          _PreviewPoint(.40, .62, false),
          _PreviewPoint(.60, .62, false),
          _PreviewPoint(.80, .62, false),
        ];

    /// 9 layout 3: left/right side 3 + 3, bottom 2, middle owner.
      case 2:
        return const [
          _PreviewPoint(.50, .45, true),
          _PreviewPoint(.18, .22, false),
          _PreviewPoint(.18, .43, false),
          _PreviewPoint(.18, .64, false),
          _PreviewPoint(.82, .22, false),
          _PreviewPoint(.82, .43, false),
          _PreviewPoint(.82, .64, false),
          _PreviewPoint(.38, .64, false),
          _PreviewPoint(.62, .64, false),
        ];

    /// 9 layout 4: round 8 seats and owner in middle.
      default:
        return const [
          _PreviewPoint(.50, .51, true),
          _PreviewPoint(.50, .20, false),
          _PreviewPoint(.72, .30, false),
          _PreviewPoint(.82, .52, false),
          _PreviewPoint(.72, .74, false),
          _PreviewPoint(.50, .83, false),
          _PreviewPoint(.28, .74, false),
          _PreviewPoint(.18, .52, false),
          _PreviewPoint(.28, .30, false),
        ];
    }
  }

  List<_PreviewPoint> _positions12(int type) {
    switch (type) {
    /// blue: top 1, then 6, then 5
      case 0:
        return const [
          _PreviewPoint(.50, .16, true),
          _PreviewPoint(.08, .42, false),
          _PreviewPoint(.24, .42, false),
          _PreviewPoint(.40, .42, false),
          _PreviewPoint(.56, .42, false),
          _PreviewPoint(.72, .42, false),
          _PreviewPoint(.88, .42, false),
          _PreviewPoint(.12, .68, false),
          _PreviewPoint(.31, .68, false),
          _PreviewPoint(.50, .68, false),
          _PreviewPoint(.69, .68, false),
          _PreviewPoint(.88, .68, false),
        ];

    /// orange: 6 + 6 rows
      case 1:
        return const [
          _PreviewPoint(.08, .34, true),
          _PreviewPoint(.24, .34, false),
          _PreviewPoint(.40, .34, false),
          _PreviewPoint(.56, .34, false),
          _PreviewPoint(.72, .34, false),
          _PreviewPoint(.88, .34, false),
          _PreviewPoint(.08, .61, false),
          _PreviewPoint(.24, .61, false),
          _PreviewPoint(.40, .61, false),
          _PreviewPoint(.56, .61, false),
          _PreviewPoint(.72, .61, false),
          _PreviewPoint(.88, .61, false),
        ];

    /// green: left 4 + right 4 + bottom 3 + center 1
      case 2:
        return const [
          _PreviewPoint(.50, .38, true),
          _PreviewPoint(.18, .12, false),
          _PreviewPoint(.18, .32, false),
          _PreviewPoint(.18, .54, false),
          _PreviewPoint(.18, .76, false),
          _PreviewPoint(.82, .12, false),
          _PreviewPoint(.82, .32, false),
          _PreviewPoint(.82, .54, false),
          _PreviewPoint(.82, .76, false),
          _PreviewPoint(.35, .76, false),
          _PreviewPoint(.50, .76, false),
          _PreviewPoint(.65, .76, false),
        ];

    /// purple: round with 2 middle seats
      case 3:
        return const [
          _PreviewPoint(.40, .50, true),
          _PreviewPoint(.60, .50, false),
          _PreviewPoint(.38, .18, false),
          _PreviewPoint(.62, .18, false),
          _PreviewPoint(.18, .32, false),
          _PreviewPoint(.82, .32, false),
          _PreviewPoint(.12, .52, false),
          _PreviewPoint(.88, .52, false),
          _PreviewPoint(.18, .72, false),
          _PreviewPoint(.82, .72, false),
          _PreviewPoint(.38, .86, false),
          _PreviewPoint(.62, .86, false),
        ];

    /// cyan: top 2, then 5, then 5
      default:
        return const [
          _PreviewPoint(.42, .16, true),
          _PreviewPoint(.58, .16, false),
          _PreviewPoint(.12, .43, false),
          _PreviewPoint(.31, .43, false),
          _PreviewPoint(.50, .43, false),
          _PreviewPoint(.69, .43, false),
          _PreviewPoint(.88, .43, false),
          _PreviewPoint(.12, .68, false),
          _PreviewPoint(.31, .68, false),
          _PreviewPoint(.50, .68, false),
          _PreviewPoint(.69, .68, false),
          _PreviewPoint(.88, .68, false),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final positions = seatCount == 9 ? _positions9(type) : _positions12(type);
        final mini = kHeight * 0.008;

        return Stack(
          clipBehavior: Clip.none,
          children: positions.map((p) {
            return Positioned(
              left: (constraints.maxWidth * p.x) - mini,
              top: (constraints.maxHeight * p.y) - mini,
              child: _miniSeat(owner: p.owner),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PreviewPoint {
  final double x;
  final double y;
  final bool owner;

  const _PreviewPoint(this.x, this.y, this.owner);
}


class BackgroundTabView extends StatelessWidget {
  final int selectedIndex;
  final List<dynamic> backgroundList;
  final List<String> images;
  final ValueChanged<int> onSelect;

  const BackgroundTabView({
    super.key,
    required this.selectedIndex,
    required this.backgroundList,
    required this.images,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final defaultItems = images
        .map((e) => {
      "id": 0,
      "name": "Background",
      "image": e,
    })
        .toList();

    final items = backgroundList.isNotEmpty ? backgroundList : defaultItems;

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.035),
      itemCount: items.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: kWeight * 0.045,
        mainAxisSpacing: kHeight * 0.016,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          final active = selectedIndex == -1;

          return GestureDetector(
            onTap: () => onSelect(-1),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: active
                            ? const Color(0xff8d52ef)
                            : Colors.grey.shade300,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.block,
                            size: kHeight * 0.038,
                            color: active
                                ? const Color(0xff8d52ef)
                                : Colors.grey,
                          ),
                        ),
                        if (active)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: CircleAvatar(
                              radius: kHeight * 0.012,
                              backgroundColor: const Color(0xff8d52ef),
                              child: Icon(
                                Icons.check,
                                size: kHeight * 0.014,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: kHeight * 0.006),
                Text(
                  ("No Background").appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.014,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          );
        }

        final bgIndex = index - 1;
        final active = selectedIndex == bgIndex;
        final item = items[bgIndex];

        final name = item is Map
            ? (item['name'] ?? ('Background').appTr).toString()
            : ('Background').appTr;

        final rawImage = item is Map ? (item['image'] ?? '').toString() : '';
        final imageUrl = rawImage.startsWith('http')
            ? rawImage
            : ImageHelper.getImageUrl(rawImage);

        return GestureDetector(
          onTap: () => onSelect(bgIndex),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: active
                        ? Border.all(color: const Color(0xff8d52ef), width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: double.infinity,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const CupertinoActivityIndicator(),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        if (active)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: CircleAvatar(
                              radius: kHeight * 0.012,
                              backgroundColor: const Color(0xff8d52ef),
                              child: Icon(
                                Icons.check,
                                size: kHeight * 0.014,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: kHeight * 0.006),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: kHeight * 0.014,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ================= OTHER TABS =================

class MicDecorTabView extends StatelessWidget {
  const MicDecorTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return _SquareItemGrid(
      count: 3,
      builder: (index) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff23d4df), Color(0xff087195)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: CircleAvatar(
            radius: kHeight * 0.028,
            backgroundColor: Colors.white.withOpacity(.35),
            child: Icon(Icons.add, color: Colors.white, size: kHeight * 0.030),
          ),
        ),
      ),
    );
  }
}

class VoiceWavesTabView extends StatelessWidget {
  const VoiceWavesTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.amber, Colors.deepPurple, Colors.greenAccent];

    return _SquareItemGrid(
      count: 3,
      builder: (index) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff23d4df), Color(0xff087195)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Container(
            height: kHeight * 0.055,
            width: kHeight * 0.055,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors[index], width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors[index].withOpacity(.45),
                  blurRadius: 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PartnerSendTabView extends StatelessWidget {
  const PartnerSendTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return _SquareItemGrid(
      count: 3,
      builder: (index) {
        final icons = [
          CupertinoIcons.nosign,
          Icons.favorite_border,
          Icons.handshake,
        ];

        return Container(
          decoration: BoxDecoration(
            color: index == 0 ? Colors.blueGrey.shade200 : null,
            gradient: index == 0
                ? null
                : const LinearGradient(
              colors: [Color(0xff23d4df), Color(0xff22ce7f)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(
              icons[index],
              size: kHeight * 0.038,
              color: index == 0 ? Colors.black : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _SquareItemGrid extends StatelessWidget {
  final int count;
  final Widget Function(int index) builder;

  const _SquareItemGrid({
    required this.count,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.035),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: kWeight * 0.035,
        mainAxisSpacing: kHeight * 0.018,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) => builder(index),
    );
  }
}

/// ================= ANNOUNCEMENT SHEET =================

class AnnouncementBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSave;

  const AnnouncementBottomSheet({
    super.key,
    required this.controller,
    required this.onSave,
  });

  @override
  State<AnnouncementBottomSheet> createState() =>
      _AnnouncementBottomSheetState();
}

class _AnnouncementBottomSheetState extends State<AnnouncementBottomSheet> {
  bool stickyOnTop = false;

  @override
  Widget build(BuildContext context) {
    final h = kHeight;
    final w = kWeight;

    return Container(
      height: h * 0.62,
      padding: EdgeInsets.only(
        left: w * 0.025,
        right: w * 0.025,
        bottom: MediaQuery.of(context).viewInsets.bottom + h * 0.015,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(height: h * 0.010),
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    ("Cancel").appTr,
                    style: GoogleFonts.poppins(fontSize: h * 0.012),
                  ),
                ),
                const Spacer(),
                Text(
                  ("Announcement").appTr,
                  style: GoogleFonts.poppins(
                    fontSize: h * 0.014,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    widget.onSave(widget.controller.text.trim());
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    ("Save").appTr,
                    style: GoogleFonts.poppins(
                      fontSize: h * 0.012,
                      color: const Color(0xff25c76a),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: h * 0.020),
            Container(
              height: h * 0.22,
              width: double.infinity,
              padding: EdgeInsets.all(w * 0.045),
              decoration: BoxDecoration(
                color: const Color(0xfff5f5f7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: widget.controller,
                maxLength: 1000,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  counterText: "",
                  border: InputBorder.none,
                  hintText:
                  ("Enter Announcement to help audience learn more\nabout your room").appTr,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: h * 0.013,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ("Sticky on top").appTr,
                style: GoogleFonts.poppins(
                  fontSize: h * 0.024,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: h * 0.014),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ("After setting the announcement will be place on top of the\nchat area Example >").appTr,
                    style: GoogleFonts.poppins(
                      fontSize: h * 0.011,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                Switch(
                  value: stickyOnTop,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.black,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.black,
                  onChanged: (value) {
                    setState(() => stickyOnTop = value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= SEAT SHEET =================

class SeatCountBottomSheet extends StatelessWidget {
  final int selectedSeat;
  final ValueChanged<int> onSelect;

  const SeatCountBottomSheet({
    super.key,
    required this.selectedSeat,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final h = kHeight;
    final w = kWeight;

    final seats = [
      {"seat": 9, "color": const Color(0xff064c62)},
      {"seat": 12, "color": const Color(0xff7130c9)},
      {"seat": 15, "color": const Color(0xff10a64d)},
      {"seat": 20, "color": const Color(0xff16cfe0)},
    ];

    return Container(
      height: h * 0.26,
      padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: h * 0.012),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              Text(
                ("Number of seats").appTr,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: h * 0.014,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.chevron_right, color: Colors.black),
              ),
            ],
          ),
          SizedBox(height: h * 0.018),
          Expanded(
            child: GridView.builder(
              itemCount: seats.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: h * 0.012,
                crossAxisSpacing: w * 0.04,
                childAspectRatio: 3.3,
              ),
              itemBuilder: (context, index) {
                final item = seats[index];
                final seat = item["seat"] as int;
                final color = item["color"] as Color;

                return GestureDetector(
                  onTap: () {
                    onSelect(seat);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: selectedSeat == seat
                          ? Border.all(color: Colors.black, width: 1.2)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.weekend_rounded,
                            color: Colors.white, size: h * 0.026),
                        SizedBox(width: w * 0.015),
                        Text(
                          ("$seat seat").appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: h * 0.016,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= BOTTOM MENU =================

class _BottomMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _BottomMenuItem({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = kHeight;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: h * 0.025),
          SizedBox(height: h * 0.004),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: h * 0.015,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
