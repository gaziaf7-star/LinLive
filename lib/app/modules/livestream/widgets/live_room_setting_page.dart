import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../apis/api_endpoints.dart';

import '../../auth/controllers/auth_controller.dart';
import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';
import 'RoomImageSettingPage.dart';
import 'room_background_side_panel.dart';

import 'room_layout_setting_page.dart';
import 'room_seat_setting_page.dart';
import 'room_text_edit_page.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class LiveRoomSettingPage extends StatefulWidget {
  final LivestreamController livestreamController;
  final WebsocketController websocketController;
  final AuthController authController;

  const LiveRoomSettingPage({
    super.key,
    required this.livestreamController,
    required this.websocketController,
    required this.authController,
  });

  @override
  State<LiveRoomSettingPage> createState() => _LiveRoomSettingPageState();
}

class _LiveRoomSettingPageState extends State<LiveRoomSettingPage> {
  late int selectedSeatCount;
  late int selectedLayout;
  late int selectedTheme;
  late int selectedBackground;

  final TextEditingController roomNameController = TextEditingController();
  final TextEditingController announcementController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  File? pickedRoomImage;

  final List<int> seatOptions = const [9, 12, 15, 20];

  @override
  void initState() {
    super.initState();

    final live = _currentLiveData();
    final bool useWsRoomCache = _websocketRoomCacheBelongsToThisRoom;

    selectedSeatCount =
    useWsRoomCache && widget.websocketController.liveRoomSeatCount.value > 0
        ? widget.websocketController.liveRoomSeatCount.value
        : _asInt(
      live['seat_count'],
      widget.livestreamController.seatCount.value,
    );
    selectedLayout = useWsRoomCache
        ? widget.websocketController.liveRoomLayout.value
        : _asInt(live['room_layout'], 0);
    selectedTheme = useWsRoomCache
        ? widget.websocketController.liveRoomTheme.value
        : _asInt(live['room_theme'], 0);
    selectedBackground = useWsRoomCache
        ? widget.websocketController.liveRoomBackground.value
        : _asInt(live['room_background'], -1);

    roomNameController.text = _firstText([
      useWsRoomCache ? widget.websocketController.liveRoomTitle.value : '',
      live['stream_bte'],
      live['title'],
    ], fallback: 'Live Room');

    announcementController.text = _firstText([
      useWsRoomCache
          ? widget.websocketController.liveRoomAnnouncement.value
          : '',
      live['announcement'],
      live['anousment'],
      live['stream_title'],
    ]);

    passwordController.text = _firstText([
      useWsRoomCache ? widget.websocketController.liveRoomPassword.value : '',
      live['room_password'],
      live['stream_password'],
      live['password'],
    ]);

    /// Fast page open: background/theme list load background-e korbo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.livestreamController.showBackground();
      widget.livestreamController.showTheme();
    });
  }

  @override
  void dispose() {
    roomNameController.dispose();
    announcementController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _currentLiveData() {
    final data = widget.livestreamController.createStreamData;
    Map<String, dynamic> live = <String, dynamic>{};
    if (data['livestreamdata'] is Map) {
      live = Map<String, dynamic>.from(data['livestreamdata']);
    } else if (data['livestream'] is Map) {
      live = Map<String, dynamic>.from(data['livestream']);
    }

    final currentStreamId = widget.livestreamController.streamId.value;
    final liveId =
        int.tryParse((live['id'] ?? live['livestream_id'] ?? '0').toString()) ??
            0;

    if (currentStreamId > 0 && liveId > 0 && liveId != currentStreamId) {
      return <String, dynamic>{};
    }

    return live;
  }

  bool get _websocketRoomCacheBelongsToThisRoom {
    final currentStreamId = widget.livestreamController.streamId.value;
    return currentStreamId > 0 &&
        widget.websocketController.liveRoomUpdateStreamId.value ==
            currentStreamId;
  }

  String _firstText(List<dynamic> values, {String fallback = ''}) {
    for (final raw in values) {
      final text = raw?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  int _asInt(dynamic value, int fallback) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _maxLayoutForSeats(int seats) {
    if (seats == 9) return 3;
    if (seats == 12) return 4;
    return 0;
  }

  String _imageUrl(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$kDomainUrl/$value';
  }

  String get _currentStreamImageUrl {
    if (pickedRoomImage != null) return pickedRoomImage!.path;
    final live = _currentLiveData();
    final bool useWsRoomCache = _websocketRoomCacheBelongsToThisRoom;
    final streamImage = _firstText([
      useWsRoomCache
          ? widget.websocketController.liveRoomStreamImage.value
          : '',
      live['stream_image'],
      live['image'],
      live['cover_image'],
      live['thumbnail'],
    ]);
    if (streamImage.isNotEmpty) return _imageUrl(streamImage);

    final user = widget.authController.userProfile.value.user;
    final profile = user?.profileImage?.toString().trim() ?? '';
    return profile.isEmpty ? '' : _imageUrl(profile);
  }

  Future<void> _saveRoom({bool closeKeyboard = true}) async {
    if (closeKeyboard) FocusScope.of(context).unfocus();

    selectedLayout = selectedLayout
        .clamp(0, _maxLayoutForSeats(selectedSeatCount))
        .toInt();

    await widget.livestreamController.editLiveStreamRoom(
      livestreamId: widget.livestreamController.streamId.value,
      userId: widget.authController.userProfile.value.user?.id?.toInt() ?? 0,
      seatCount: selectedSeatCount,
      roomLayout: selectedLayout,
      roomTheme: selectedTheme,
      roomBackground: selectedBackground,
      streamTitle: roomNameController.text.trim().isEmpty
          ? 'Live Room'
          : roomNameController.text.trim(),
      streamAnnouncement: announcementController.text.trim(),
      streamImageFile: pickedRoomImage,
      roomPassword: passwordController.text.trim(),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openRoomAvatarPage() async {
    final result = await Get.to<File?>(
          () => RoomImageSettingPage(currentImageUrl: _currentStreamImageUrl),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );

    if (result == null) return;
    setState(() => pickedRoomImage = result);
    await _saveRoom(closeKeyboard: false);
  }

  Future<void> _openRoomNamePage() async {
    final result = await Get.to<String>(
          () => RoomTextEditPage(
        title: ('Edit room name').appTr,
        initialValue: roomNameController.text,
        hint: ('Please set the room name').appTr,
        helperText:
        ('2-30 characters, which can be composed of Chinese and English, numbers, emoji expressions')
            .appTr,
        maxLength: 30,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );

    if (result == null) return;
    roomNameController.text = result;
    setState(() {});
    await _saveRoom(closeKeyboard: false);
  }

  Future<void> _openRoomPasswordPage() async {
    final result = await Get.to<String>(
          () => RoomTextEditPage(
        title: ('Edit room password').appTr,
        initialValue: passwordController.text,
        hint: ('Please set the room password').appTr,
        helperText: ('Leave empty if you do not want a password').appTr,
        maxLength: 30,
        obscureText: true,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );

    if (result == null) return;
    passwordController.text = result;
    setState(() {});
    await _saveRoom(closeKeyboard: false);
  }

  Future<void> _openRoomNoticePage() async {
    final result = await Get.to<String>(
          () => RoomTextEditPage(
        title: ('Edit room notice').appTr,
        initialValue: announcementController.text,
        hint: ('Please set the room notice').appTr,
        helperText: ('The notice will be shown in live comments').appTr,
        maxLength: 120,
        minLines: 3,
        maxLines: 5,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );

    if (result == null) return;
    announcementController.text = result;
    setState(() {});
    await _saveRoom(closeKeyboard: false);
  }

  Future<void> _openSeatSettingPage() async {
    final result = await Get.to<RoomSeatSettingResult>(
          () => RoomSeatSettingPage(
        seatOptions: seatOptions,
        initialSeatCount: selectedSeatCount,
        initialLayout: selectedLayout,
      ),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 220),
    );

    if (result == null) return;
    setState(() {
      selectedSeatCount = result.seatCount;
      selectedLayout = result.roomLayout
          .clamp(0, _maxLayoutForSeats(result.seatCount))
          .toInt();
    });
    await _saveRoom(closeKeyboard: false);
  }

  Future<void> _openLayoutSettingPage() async {
    final layoutCount = _maxLayoutForSeats(selectedSeatCount) + 1;
    final result = await Get.to<int>(
          () => RoomLayoutSettingPage(
        seatCount: selectedSeatCount,
        initialLayout: selectedLayout,
        layoutCount: layoutCount,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 220),
    );

    if (result == null) return;
    setState(() => selectedLayout = result.clamp(0, layoutCount - 1).toInt());
    await _saveRoom(closeKeyboard: false);
  }

  Future<void> _openBackgroundSetting() async {
    // Capture values before closing this setup page. The picker must appear
    // on top of the real AudioLiveView so the host can preview backgrounds.
    final livestreamController = widget.livestreamController;
    final authController = widget.authController;
    final int initialBackground = selectedBackground;
    final int seatCount = selectedSeatCount;
    final int roomLayout = selectedLayout;
    final int roomTheme = selectedTheme;

    // Close Set up first; AudioLiveView becomes visible underneath.
    Get.back();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    await showRoomBackgroundSidePanel(
      livestreamController: livestreamController,
      authController: authController,
      initialBackground: initialBackground,
      seatCount: seatCount,
      roomLayout: roomLayout,
      roomTheme: roomTheme,
    );
  }

  String get _backgroundName {
    if (selectedBackground == -1) return ('Default').appTr;

    for (final raw in widget.livestreamController.backgroundList) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (_asInt(map['id'], -999) == selectedBackground) {
        final name = (map['name'] ?? map['title'] ?? '').toString().trim();
        return name.isEmpty ? ('Selected').appTr : name;
      }
    }

    return ('Selected').appTr;
  }

  String get _passwordPreview {
    final password = passwordController.text.trim();
    if (password.isEmpty) return '';
    return '•' * password.length.clamp(4, 10);
  }

  String get _roomInitial {
    final source = roomNameController.text.trim().isNotEmpty
        ? roomNameController.text.trim()
        : 'R';
    return source.substring(0, 1).toUpperCase();
  }

  double _uiScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 390.0).clamp(0.88, 1.05);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF6F7F9),
        foregroundColor: const Color(0xFF222222),
        centerTitle: true,
        toolbarHeight: 66 * scale,
        leadingWidth: 56 * scale,
        leading: IconButton(
          splashRadius: 22 * scale,
          padding: EdgeInsets.zero,
          onPressed: () => Get.back(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 22 * scale,
            color: const Color(0xFF222222),
          ),
        ),
        title: Text(
          ('Set up').appTr,
          style: GoogleFonts.roboto(
            color: const Color(0xFF171717),
            fontSize: 21 * scale,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Obx(() {
              return widget.livestreamController.roomEditLoading.value
                  ? const LinearProgressIndicator(minHeight: 2)
                  : const SizedBox(height: 2);
            }),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  14 * scale,
                  14 * scale,
                  14 * scale,
                  26 * scale,
                ),
                children: [
                  // Main room setup group.
                  _settingsGroup(
                    context,
                    children: [
                      _avatarTile(context),
                      _optionTile(
                        context,
                        title: ('Room Name').appTr,
                        value: roomNameController.text.trim(),
                        onTap: _openRoomNamePage,
                      ),
                      _optionTile(
                        context,
                        title: ('Room Password').appTr,
                        value: _passwordPreview,
                        onTap: _openRoomPasswordPage,
                      ),
                      _optionTile(
                        context,
                        title: ('Room Background').appTr,
                        value: _backgroundName,
                        onTap: _openBackgroundSetting,
                      ),
                      _optionTile(
                        context,
                        title: ('Room notice').appTr,
                        value: announcementController.text.trim(),
                        onTap: _openRoomNoticePage,
                        valueMaxLines: 2,
                      ),
                    ],
                  ),

                  SizedBox(height: 18 * scale),

                  // Keep every existing option/function from the old page.
                  _settingsGroup(
                    context,
                    children: [
                      _optionTile(
                        context,
                        title: ('Number of mics').appTr,
                        value: '$selectedSeatCount',
                        onTap: _openSeatSettingPage,
                      ),
                      _optionTile(
                        context,
                        title: ('Room Layout').appTr,
                        value: 'Layout ${selectedLayout + 1}',
                        onTap: _openLayoutSettingPage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsGroup(
      BuildContext context, {
        required List<Widget> children,
      }) {
    final scale = _uiScale(context);

    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) SizedBox(height: 2 * scale),
        ],
      ],
    );
  }

  Widget _avatarTile(BuildContext context) {
    final scale = _uiScale(context);
    final url = _currentStreamImageUrl;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(14 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openRoomAvatarPage,
        child: Container(
          height: 72 * scale,
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFF0F1F3),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(14 * scale),
          ),
          padding: EdgeInsets.symmetric(horizontal: 15 * scale),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ('Room avatar').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF2F3135),
                    fontSize: 16.5 * scale,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(
                width: 150 * scale,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _avatarPreview(context, url),
                    SizedBox(width: 12 * scale),
                    SizedBox(
                      width: 24 * scale,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFFC8CBD0),
                        size: 24 * scale,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPreview(BuildContext context, String url) {
    final scale = _uiScale(context);
    Widget child;

    if (url.isEmpty) {
      child = Container(
        color: const Color(0xFF879EAB),
        alignment: Alignment.center,
        child: Text(
          _roomInitial,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 25 * scale,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      );
    } else if (url.startsWith('/')) {
      child = Image.file(
        File(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: const Color(0xFFF0F0F0),
        ),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFF879EAB),
          alignment: Alignment.center,
          child: Text(
            _roomInitial,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 25 * scale,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(9 * scale),
      child: SizedBox(
        height: 48 * scale,
        width: 48 * scale,
        child: child,
      ),
    );
  }

  Widget _optionTile(
      BuildContext context, {
        required String title,
        required String value,
        required VoidCallback onTap,
        int valueMaxLines = 2,
      }) {
    final scale = _uiScale(context);
    final bool hasValue = value.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(14 * scale),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 68 * scale),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFF0F1F3),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(14 * scale),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 15 * scale,
            vertical: 10 * scale,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF2F3135),
                    fontSize: 16.5 * scale,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              SizedBox(
                width: 150 * scale,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasValue)
                      Expanded(
                        child: Text(
                          value,
                          maxLines: valueMaxLines,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.roboto(
                            color: const Color(0xFF9A9DA3),
                            fontSize: 14.5 * scale,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    SizedBox(width: 10 * scale),
                    SizedBox(
                      width: 24 * scale,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFFC8CBD0),
                        size: 24 * scale,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}