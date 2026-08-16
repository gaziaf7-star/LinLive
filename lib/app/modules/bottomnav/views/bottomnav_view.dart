import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../livestream/socket/websocket_controller.dart';

import '../../moments/views/moments_view.dart';
import '../../notification/views/notification_view.dart';
import '../../messanger/views/chat_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../services/account_block_service.dart';
import '../../../theme/app_theme_controller.dart';
import '../../../theme/app_theme_model.dart';
import '../../../theme/app_theme_image_cache.dart';
import '../../../theme/widgets/app_theme_background.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../controllers/daily_reword_controller.dart';
import 'daily_reword_diyalog.dart';

const Color kAppColor1 = Color(0xFFFDF8FF);
const Color kAppColor2 = Color(0xFFFDF8FF);
const Color kAppbarColor = Color(0xFFFDF8FF);
const Color kAppbarColor1 = Color(0xFFFDF8FF);
const Color kBottomSoftLight = Color(0xFFB86AA2);

class BottomnavView extends StatefulWidget {
  const BottomnavView({super.key});

  @override
  State<BottomnavView> createState() => _BottomnavViewState();
}

class _BottomnavViewState extends State<BottomnavView>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Daily reward dialog control:
  // - Same user ke ek dine sudhu ekbar dekhabe.
  // - App close/open ba logout/login korleo same dine abar dekhabe na.
  bool _dailyRewardDialogScheduled = false;
  bool _dailyRewardDialogOpen = false;
  int? _dailyRewardDialogUserId;
  Timer? _dailyRewardRetryTimer;

  late final ChatController _chatController;
  late final DailyRewardController _dailyRewardController;
  late final AppThemeController _appThemeController;
  bool _firstThemedFrameLogged = false;

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

    // Registered once, permanently, before runApp in main.dart.
    _appThemeController = Get.find<AppThemeController>();

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
      _dailyRewardRetryTimer?.cancel();
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

  void _queueDailyRewardRetry(
      int userId, {
        Duration delay = const Duration(seconds: 2),
      }) {
    _dailyRewardRetryTimer?.cancel();
    _dailyRewardDialogScheduled = false;

    _dailyRewardRetryTimer = Timer(delay, () {
      if (!mounted || _dailyRewardDialogOpen) return;

      final int currentUserId = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userProfile.value.user?.id?.toInt() ??
          0)
          : 0;

      if (currentUserId == userId && currentUserId > 0) {
        _scheduleDailyRewardDialog(userId);
      }
    });
  }

  Future<void> _showDailyRewardDialogAfterLogin(int userId) async {
    try {
      final SharedPreferences preferences =
      await SharedPreferences.getInstance();
      final String storageKey = _dailyRewardStorageKey(userId);
      final String today = _todayLocalKey();
      final String? lastShownDate = preferences.getString(storageKey);

      // Same user + same local date = ar show korbe na.
      if (lastShownDate == today) {
        _dailyRewardDialogScheduled = true;
        return;
      }

      // Permission / recharge / onno startup dialog thakle wait korbe.
      for (int attempt = 0; attempt < 20; attempt++) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 900 : 500),
        );

        if (!mounted || _dailyRewardDialogOpen) return;

        final int currentUserId = Get.isRegistered<AuthController>()
            ? (Get.find<AuthController>().userProfile.value.user?.id?.toInt() ??
            0)
            : 0;

        if (currentUserId <= 0 || currentUserId != userId) {
          _dailyRewardDialogScheduled = false;
          return;
        }

        final bool anotherDialogOpen = Get.isDialogOpen ?? false;
        final bool anotherBottomSheetOpen = Get.isBottomSheetOpen ?? false;

        if (anotherDialogOpen || anotherBottomSheetOpen) {
          continue;
        }

        // Dialog open korar age fresh server data nibe.
        final bool loaded = await _dailyRewardController.fetchDailyRewards(
          force: true,
        );

        if (!mounted) return;

        if (!loaded || !_dailyRewardController.hasData) {
          debugPrint(
            'Daily reward data not ready: '
                '${_dailyRewardController.errorMessage.value}',
          );

          // Temporary API/network issue hole same day reward permanently miss hobe na.
          _queueDailyRewardRetry(userId, delay: const Duration(seconds: 10));
          return;
        }

        _dailyRewardDialogOpen = true;

        try {
          final dialogFuture = showDailyRewardDialog(
            context: context,
            controller: _dailyRewardController,
            onSignIn: () async {
              final bool claimed = await _dailyRewardController.claimToday();
              return claimed;
            },
          );

          // Dialog successfully invoke howar por-i today mark kori.
          // Tai startup conflict/error hole din-er jonno vul kore block hobe na.
          await Future<void>.delayed(const Duration(milliseconds: 180));
          if (mounted) {
            await preferences.setString(storageKey, today);
          }

          await dialogFuture;
        } finally {
          _dailyRewardDialogOpen = false;
        }

        return;
      }

      // Long permission/other dialog thakleo pore nij theke abar try korbe.
      _queueDailyRewardRetry(userId, delay: const Duration(seconds: 2));
    } catch (error, stackTrace) {
      debugPrint('Daily reward dialog check failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _queueDailyRewardRetry(userId, delay: const Duration(seconds: 8));
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

      final int userId = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userProfile.value.user?.id?.toInt() ??
          0)
          : 0;

      if (userId > 0) {
        _dailyRewardDialogScheduled = false;
        _scheduleDailyRewardDialog(userId);
      }
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
    _dailyRewardRetryTimer?.cancel();

    if (Get.isRegistered<WebsocketController>()) {
      Get.find<WebsocketController>().disconnectRechargeRealtime();
    }

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
      message:
      ("Camera and microphone permissions are required for live streaming.")
          .appTr,
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
      message:
      ("Please enable camera and microphone permissions from app settings.")
          .appTr,
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
            child: Text(("No").appTr, style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: Text(("Yes").appTr, style: TextStyle(color: Colors.green)),
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

  void _openLuckyBagLiveRoom(int livestreamId, Map<String, dynamic> packet) {
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

    joinController.joinAsAudience(channelName: channelName, data: liveData);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int authenticatedUserId = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userProfile.value.user?.id?.toInt() ??
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
        _dailyRewardRetryTimer?.cancel();
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

      final AppThemeModel? appTheme = _appThemeController.theme.value;
      final String? footerUrl = appTheme?.footerImage;
      if (kDebugMode && appTheme != null && !_firstThemedFrameLogged) {
        _firstThemedFrameLogged = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint(
            '[APP_THEME_STARTUP] first_themed_frame='
            '${_appThemeController.startupElapsedMilliseconds}ms',
          );
        });
      }
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      final double footerHeight = 62 + bottomPadding;

      return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: _selectedIndex == 2
              ? _pages[_selectedIndex]
              : AppThemeBackground(
            imageUrl: appTheme?.backgroundImage,
            child: _pages[_selectedIndex],
          ),
          bottomNavigationBar: SizedBox(
            height: footerHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                const ColoredBox(color: Color(0xFF3B072F)),
                if (footerUrl != null)
                  CachedNetworkImage(
                    key: ValueKey<String>(footerUrl),
                    imageUrl: footerUrl,
                    cacheManager: AppThemeImageCache.manager,
                    cacheKey: footerUrl,
                    width: double.infinity,
                    height: footerHeight,
                    fit: BoxFit.fill,
                    alignment: Alignment.center,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, _) => const SizedBox.expand(),
                    errorWidget: (_, url, error) {
                      if (kDebugMode) {
                        debugPrint('Theme footer image failed: $url $error');
                      }
                      return const SizedBox.expand();
                    },
                  ),
                Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildThemeNavItem(
                        assetPath: 'assets/new/home.png',
                        imageUrl: appTheme?.homeIcon,
                        index: 0,
                        label: ('Home').appTr,
                      ),
                      _buildThemeNavItem(
                        assetPath: 'assets/new/youtube.png',
                        imageUrl: appTheme?.momentIcon,
                        index: 1,
                        label: ('Moments').appTr,
                      ),
                      _buildThemeNavItem(
                        assetPath: 'assets/new/facetime-button.png',
                        imageUrl: appTheme?.videoIcon,
                        index: 2,
                        label: ('Video/Audio').appTr,
                        center: true,
                      ),
                      StreamBuilder<int>(
                        stream:
                        Get.find<AuthController>()
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
                          return _buildThemeNavItem(
                            assetPath: 'assets/new/notification.png',
                            imageUrl: appTheme?.messageIcon,
                            index: 3,
                            label: ('Message').appTr,
                            badge: count > 0
                                ? (count > 99 ? '99+' : '$count')
                                : null,
                          );
                        },
                      ),
                      _buildThemeNavItem(
                        assetPath: 'assets/new/user.png',
                        imageUrl: appTheme?.profileIcon,
                        index: 4,
                        label: ('Profile').appTr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildThemeNavItem({
    required String assetPath,
    required String? imageUrl,
    required int index,
    required String label,
    String? badge,
    bool center = false,
  }) {
    final bool isSelected = _selectedIndex == index;

    // Keep normal items compact, but make the selected API image visibly
    // larger and lift it above the footer like professional live apps.
    final double iconSize = center ? 36 : 28;
    final double selectedScale = center ? 1.32 : 1.55;
    final double selectedLift = center ? -0.26 : -0.34;
    final double normalFontSize = center ? 8.5 : 10;
    final double selectedFontSize = center ? 11 : 13;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 54,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                top: center ? 0 : 4,
                left: 0,
                right: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: Offset(0, isSelected ? selectedLift : 0),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    scale: isSelected ? selectedScale : 1,
                    child: Center(
                      child: _themeNavImage(
                        imageUrl: imageUrl,
                        assetPath: assetPath,
                        size: iconSize,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 3,
                left: 2,
                right: 2,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: GoogleFonts.lato(
                    color: isSelected ? const Color(0xFFFFD83D) : Colors.white,
                    fontSize: isSelected ? selectedFontSize : normalFontSize,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 1,
                  right: 8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3B5F), Color(0xFFFF8A4C)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3B5F).withOpacity(0.32),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeNavImage({
    required String? imageUrl,
    required String assetPath,
    required double size,
  }) {
    final fallback = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    if (imageUrl == null) return fallback;
    return CachedNetworkImage(
      key: ValueKey<String>(imageUrl),
      imageUrl: imageUrl,
      cacheManager: AppThemeImageCache.manager,
      cacheKey: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => fallback,
      errorWidget: (_, url, error) {
        if (kDebugMode) {
          debugPrint('Theme navigation image failed: $url $error');
        }
        return fallback;
      },
    );
  }
}
