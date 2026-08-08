import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../constants/color_constants.dart';
import '../../appmenu/views/appmenu_view.dart';
import '../../home/views/home_view.dart';
import '../../livestream/go_to_live/goto_live_tabbar.dart';
import '../../livestream/controllers/audience_join_controller.dart';
import '../../livestream/controllers/websocket_controller.dart';

import '../../moments/views/moments_view.dart';
import '../../notification/views/notification_view.dart';
import '../../messanger/views/chat_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../services/account_block_service.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../controllers/daily_reword_controller.dart';
import 'daily_reword_diyalog.dart';
const Color kAppColor1 = Color(0xFF190522);
const Color kAppColor2 = Color(0xFF3B072F);
const Color kAppbarColor = Color(0xFF62083E);
const Color kAppbarColor1 = Color(0xFF190522);
const Color kBottomSoftLight = Color(0xFFB86AA2);

class BottomnavView extends StatefulWidget {
  const BottomnavView({super.key});

  @override
  State<BottomnavView> createState() => _BottomnavViewState();
}

class _BottomnavViewState extends State<BottomnavView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Daily reward dialog control:
  // - Same user ke ek dine sudhu ekbar dekhabe.
  // - App close/open ba logout/login korleo same dine abar dekhabe na.
  bool _dailyRewardDialogScheduled = false;
  bool _dailyRewardDialogOpen = false;
  int? _dailyRewardDialogUserId;

  late final ChatController _chatController;
  late final DailyRewardController _dailyRewardController;

  late AnimationController _liveController;
  late AnimationController _borderController;
  late AnimationController _waveController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  final List<Widget> _pages = [
    const HomeView(),
    MomentsView(),
    GotoLiveTabView(),
    NotificationView(),
    AppmenuView(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chatController = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController(), permanent: true);

    _dailyRewardController = Get.isRegistered<DailyRewardController>()
        ? Get.find<DailyRewardController>()
        : Get.put(DailyRewardController(), permanent: true);

    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.055).animate(
      CurvedAnimation(parent: _liveController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.20, end: 0.48).animate(
      CurvedAnimation(parent: _liveController, curve: Curves.easeInOut),
    );

    _checkAndRequestPermissions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRechargeRealtime();
    });
  }

  String _todayLocalKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  String _dailyRewardStorageKey(int userId) {
    return 'daily_reward_dialog_last_shown_user_$userId';
  }

  void _scheduleDailyRewardDialog(int userId) {
    if (userId <= 0) return;

    // User change hole notun user-er jonno abar local check korbe.
    if (_dailyRewardDialogUserId != userId) {
      _dailyRewardDialogUserId = userId;
      _dailyRewardDialogScheduled = false;
    }

    if (_dailyRewardDialogScheduled || _dailyRewardDialogOpen) return;

    _dailyRewardDialogScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showDailyRewardDialogAfterLogin(userId);
    });
  }

  Future<void> _showDailyRewardDialogAfterLogin(int userId) async {
    try {
      final SharedPreferences preferences =
      await SharedPreferences.getInstance();
      final String storageKey = _dailyRewardStorageKey(userId);
      final String today = _todayLocalKey();
      final String? lastShownDate = preferences.getString(storageKey);

      if (lastShownDate == today) return;

      for (int attempt = 0; attempt < 12; attempt++) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 850 : 450),
        );

        if (!mounted || _dailyRewardDialogOpen) return;

        final int currentUserId = Get.isRegistered<AuthController>()
            ? (Get.find<AuthController>()
            .userProfile
            .value
            .user
            ?.id
            ?.toInt() ??
            0)
            : 0;

        if (currentUserId <= 0 || currentUserId != userId) {
          _dailyRewardDialogScheduled = false;
          return;
        }

        if (Get.isDialogOpen ?? false) continue;

        // Always fetch fresh server data immediately before opening the dialog.
        final bool loaded =
        await _dailyRewardController.fetchDailyRewards(force: true);
        if (!mounted) return;

        if (!loaded || !_dailyRewardController.hasData) {
          debugPrint(
            'Daily reward dialog skipped: '
                '${_dailyRewardController.errorMessage.value}',
          );
          _dailyRewardDialogScheduled = false;
          return;
        }

        // Save only after valid API data is available. This keeps broken/empty
        // responses from blocking the dialog for the full day.
        await preferences.setString(storageKey, today);
        if (!mounted) return;

        _dailyRewardDialogOpen = true;
        try {
          await showDailyRewardDialog(
            context: context,
            controller: _dailyRewardController,
            onSignIn: () async {
              final bool claimed =
              await _dailyRewardController.claimToday();
              return claimed;
            },
          );
        } finally {
          _dailyRewardDialogOpen = false;
        }
        return;
      }

      _dailyRewardDialogScheduled = false;
    } catch (error, stackTrace) {
      debugPrint('Daily reward dialog check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _dailyRewardDialogScheduled = false;
    }
  }

  void _ensureRechargeRealtime() {
    if (!Get.isRegistered<WebsocketController>()) return;

    final controller = Get.find<WebsocketController>();
    controller.ensureRechargeRealtimeSubscription();
    controller.resumeRechargePopupAfterForeground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_dailyRewardController.fetchDailyRewards(force: true));
    }

    if (!Get.isRegistered<WebsocketController>()) return;
    final WebsocketController controller = Get.find<WebsocketController>();

    if (state == AppLifecycleState.resumed) {
      controller.resumeUnifiedLiveStreamReconnectAfterForeground();
      controller.ensureRechargeRealtimeSubscription();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      controller.pauseUnifiedLiveStreamReconnectForBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (Get.isRegistered<WebsocketController>()) {
      Get.find<WebsocketController>().disconnectRechargeRealtime();
    }

    _liveController.dispose();
    _borderController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;

    if ((!camera.isGranted || !mic.isGranted) && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) _showPermissionDialog();
    }
  }

  Future<bool> _requestPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    return camera.isGranted && mic.isGranted;
  }

  void _showPermissionDialog() {
    _showCustomDialog(
      icon: FontAwesomeIcons.triangleExclamation,
      iconColor: Colors.orange,
      title: ("Permission Required").appTr,
      message: ("Camera and microphone permissions are required for live streaming.").appTr,
      buttonText: ("Grant Permission").appTr,
      buttonColor: kAppColor,
      onConfirm: () async {
        Navigator.pop(context);
        final granted = await _requestPermissions();
        if (!granted && mounted) _showSettingsDialog();
      },
    );
  }

  void _showSettingsDialog() {
    _showCustomDialog(
      icon: FontAwesomeIcons.gear,
      iconColor: Colors.red,
      title: ("Open Settings").appTr,
      message: ("Please enable camera and microphone permissions from app settings.").appTr,
      buttonText: ("Open Settings").appTr,
      buttonColor: Colors.red,
      onConfirm: () {
        Navigator.pop(context);
        openAppSettings();
      },
    );
  }

  void _showCustomDialog({
    required FaIconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            FaIcon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.roboto(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              ("Cancel").appTr,
              style: GoogleFonts.roboto(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              buttonText,
              style: GoogleFonts.roboto(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final exitApp = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ("Exit app").appTr,
          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          ("Are you sure you want to exit?").appTr,
          style: GoogleFonts.roboto(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:  Text(("No").appTr, style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child:  Text(("Yes").appTr, style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    return exitApp ?? false;
  }

  void _onItemTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
  }


  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = _safeText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  void _openLuckyBagLiveRoom(
      int livestreamId,
      Map<String, dynamic> packet,
      ) {
    if (livestreamId <= 0) {
      Get.snackbar(
        ('Live room not found').appTr,
        ('Please try again later.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final sender = packet['sender'] is Map
        ? Map<String, dynamic>.from(packet['sender'])
        : <String, dynamic>{};

    final int ownerId = _safeInt(
      packet['owner_user_id'] ??
          packet['user_id'] ??
          packet['sender_id'] ??
          sender['id'] ??
          sender['user_id'],
    );

    final String channelName = _firstText([
      packet['room_id'],
      packet['channel_name'],
      packet['agora_channel'],
      packet['agora_channel_name'],
      packet['live_channel'],
      ownerId,
    ]);

    final Map<String, dynamic> liveData = <String, dynamic>{
      ...packet,
      'id': livestreamId,
      'livestream_id': livestreamId,
      'stream_id': livestreamId,
      'room_id': channelName,
      'channel_name': channelName,
      'agora_channel': channelName,
      'agora_channel_name': channelName,
      'owner_user_id': ownerId,
      'user_id': ownerId,
      'stream_type': _safeText(packet['stream_type']).isEmpty
          ? 'audio'
          : _safeText(packet['stream_type']),
      if (sender.isNotEmpty) 'user': sender,
      if (sender.isNotEmpty) 'User': sender,
    };

    if (channelName.isEmpty) {
      Get.snackbar(
        ('Live room data missing').appTr,
        ('Please open the live room from the live list.').appTr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final AudienceJoinController joinController =
    Get.isRegistered<AudienceJoinController>()
        ? Get.find<AudienceJoinController>()
        : Get.put(AudienceJoinController());

    joinController.joinAsAudience(
      channelName: channelName,
      data: liveData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int authenticatedUserId = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>()
          .userProfile
          .value
          .user
          ?.id
          ?.toInt() ??
          0)
          : 0;

      final bool hasAuthenticatedUser = authenticatedUserId > 0;

      final bool forceLogoutRunning =
          Get.isRegistered<AccountBlockService>() &&
              AccountBlockService.to.handlingForceLogout;

      if (hasAuthenticatedUser && !forceLogoutRunning) {
        _scheduleDailyRewardDialog(authenticatedUserId);
      } else {
        // Logout hole next login-e persisted date abar check korbe.
        _dailyRewardDialogScheduled = false;
        _dailyRewardDialogUserId = null;
      }

      // Device/account blocking clears the profile before the route transition
      // finishes. Do not build Home/Chat/Firestore widgets during that frame.
      if (!hasAuthenticatedUser || forceLogoutRunning) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: SizedBox.expand(),
        );
      }

      final bottomPadding = MediaQuery.of(context).padding.bottom;
      final width = MediaQuery.of(context).size.width;

      return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned.fill(
                child: _pages[_selectedIndex],
              ),

            ],
          ),
          bottomNavigationBar: AnimatedBuilder(
            animation: Listenable.merge([
              _liveController,
              _waveController,
            ]),
            builder: (context, _) {
              return Container(
                height: 78 + bottomPadding,

                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Positioned.fill(
                    //   child: CustomPaint(
                    //     painter: _BottomWavePainter(
                    //       progress: _waveController.value,
                    //       glow: _glowAnimation.value,
                    //     ),
                    //   ),
                    // ),

                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              kAppColor1,
                              kAppColor2,
                              kAppbarColor,
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kAppColor1.withOpacity(0.28),
                              blurRadius: 26,
                              spreadRadius: 1,
                              offset: const Offset(0, -2),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 22,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      left: width * 0.08,
                      right: width * 0.08,
                      bottom: bottomPadding + 66,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: width * 0.025,
                      right: width * 0.025,
                      bottom: bottomPadding,
                      height: 68,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAssetNavItem(
                            assetPath: "assets/new/home.png",
                            index: 0,
                            label: ("Home").appTr,
                          ),
                          _buildAssetNavItem(
                            assetPath: "assets/new/youtube.png",
                            index: 1,
                            label: ("Moments").appTr,
                          ),
                          const SizedBox(width: 64),
                          StreamBuilder<int>(
                            stream: Get.find<AuthController>()
                                .userProfile
                                .value
                                .user
                                ?.id ==
                                null
                                ? Stream<int>.value(0)
                                : _chatController.totalUnreadCountStream,
                            initialData: 0,
                            builder: (context, snapshot) {
                              final int count = snapshot.data ?? 0;
                              return _buildAssetNavItem(
                                assetPath: "assets/new/notification.png",
                                index: 3,
                                label: ("Notice").appTr,
                                badge: count > 0
                                    ? (count > 99 ? '99+' : '$count')
                                    : null,
                              );
                            },
                          ),
                          _buildAssetNavItem(
                            assetPath: "assets/new/user.png",
                            index: 4,
                            label: ("Profile").appTr,
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: -22,
                      child: _buildCenterButton(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildCenterButton() {
    final isSelected = _selectedIndex == 2;

    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _liveController,
          _borderController,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: kBottomSoftLight.withOpacity(_glowAnimation.value * 0.38),
                        blurRadius: 35,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                Transform.rotate(
                  angle: _borderController.value * math.pi * 2,
                  child: Container(
                    height: 66,
                    width: 66,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          kAppColor1,
                          kBottomSoftLight,
                          Colors.white,
                          kAppColor2,
                          kAppbarColor,
                          kAppColor1,
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        kAppColor1,
                        kAppColor2,
                        kAppbarColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kBottomSoftLight.withOpacity(_glowAnimation.value),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Container(
                          height: 16,
                          width: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.45),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Image.asset(
                        "assets/new/facetime-button.png",
                        height: 27,
                        width: 27,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),

                if (isSelected)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      height: 5,
                      width: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            kAppColor1,
                            kAppColor2,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kAppColor1.withOpacity(0.55),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetNavItem({
    required String assetPath,
    required int index,
    required String label,
    String? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              top: isSelected ? 3 : 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                height: isSelected ? 46 : 42,
                width: isSelected ? 50 : 44,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [
                      kAppColor1,
                      kAppColor2,
                      kAppbarColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.075),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.35)
                        : Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: kBottomSoftLight.withOpacity(0.22),
                        blurRadius: 14,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    if (!isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 240),
                  scale: isSelected ? 1.10 : 1.0,
                  curve: Curves.easeOutBack,
                  child: isSelected
                      ? Image.asset(
                    assetPath,
                    height: 24,
                    width: 24,
                    fit: BoxFit.contain,
                    color: Colors.white,
                  )
                      : ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.72),
                        kBottomSoftLight.withOpacity(0.76),
                      ],
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Image.asset(
                      assetPath,
                      height: 23,
                      width: 23,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              bottom: isSelected ? 0 : -4,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: isSelected ? 1 : 0,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),

            if (isSelected)
              Positioned(
                bottom: 10,
                child: Container(
                  height: 4,
                  width: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        kAppColor1,
                        kAppColor2,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kBottomSoftLight.withOpacity(0.30),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

            if (badge != null)
              Positioned(
                top: 2,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        kAppColor1,
                        kAppColor2,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: kBottomSoftLight.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
