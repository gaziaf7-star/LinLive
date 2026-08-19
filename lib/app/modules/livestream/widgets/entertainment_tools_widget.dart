import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/livestream/widgets/reseableIconButton.dart';
import 'package:meetlivepro/constants/constants.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/message_bottom.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../trading/views/trading_view.dart';
import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';
import 'GameBottomSheet.dart';
import 'musicplayerBottomSheet.dart';
import 'red_packet_send_widget.dart';
import 'room_extension_dialog.dart';
import 'live_room_setting_page.dart';
import 'voice_mixer_bottom_sheet.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class EntertainmentToolsWidget extends StatefulWidget {
  final RtcEngine? rtcEngine;
  final String streamType;
  final bool isBroadcaster;

  const EntertainmentToolsWidget({
    super.key,
    this.rtcEngine,
    this.streamType = 'popular',
    required this.isBroadcaster,
  });

  @override
  State<EntertainmentToolsWidget> createState() =>
      _EntertainmentToolsWidgetState();
}

class _EntertainmentToolsWidgetState extends State<EntertainmentToolsWidget> {
  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  int _currentUserId() {
    try {
      return authController.userProfile.value.user?.id?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  int _currentStreamId(LivestreamController controller) {
    try {
      final id = _safeInt(controller.streamId.value);
      if (id > 0) return id;
    } catch (_) {}

    try {
      final ws = Get.find<WebsocketController>();

      final sid = _safeInt(ws.streamID.value);
      if (sid > 0) return sid;

      final activeSid = _safeInt(ws.activeAudioStreamId.value);
      if (activeSid > 0) return activeSid;

      final roomSid = _safeInt(ws.liveRoomUpdateStreamId.value);
      if (roomSid > 0) return roomSid;
    } catch (_) {}

    return 0;
  }

  int _streamIdFromMap(Map<String, dynamic> raw) {
    return _safeInt(
      raw['livestream_id'] ??
          raw['livestreamId'] ??
          raw['stream_id'] ??
          raw['streamId'] ??
          raw['id'],
    );
  }

  int _ownerIdFromMap(Map<String, dynamic> raw) {
    final user = _safeMap(raw['user']);
    final host = _safeMap(raw['host']);
    final broadcaster = _safeMap(raw['broadcaster']);

    return _safeInt(
      raw['host_id'] ??
          raw['broadcaster_id'] ??
          raw['creator_id'] ??
          raw['user_id'] ??
          raw['admin_id'] ??
          user['id'] ??
          host['id'] ??
          broadcaster['id'],
    );
  }

  bool _isAudioRoom() {
    final type = widget.streamType.toLowerCase().trim();
    return type == 'audio' ||
        type == 'live_audio' ||
        type == 'audio_live' ||
        type.contains('audio');
  }

  bool _isPopularRoom() {
    final type = widget.streamType.toLowerCase().trim();
    return type == 'popular' || type == 'video' || type.contains('popular');
  }

  /// ✅ Widget-er isBroadcaster value stale thakte pare.
  /// Tai host permission only current room owner id match korle true hobe.
  bool _isCurrentRoomOwner([LivestreamController? controller]) {
    final c = controller ?? Get.find<LivestreamController>();
    final myId = _currentUserId();
    if (myId <= 0) return false;

    try {
      final dynamic live = c;
      if (live.isCurrentUserCurrentLiveOwner == true) return true;
    } catch (_) {}

    try {
      final broadcasterId = _safeInt(c.broadcasterId.value);
      if (broadcasterId > 0 && broadcasterId == myId) return true;
    } catch (_) {}

    final currentStreamId = _currentStreamId(c);
    final data = _safeMap(c.createStreamData);
    final sources = <Map<String, dynamic>>[
      _safeMap(data['livestreamdata']),
      _safeMap(data['livestream']),
      _safeMap(data['data']),
      data,
    ];

    for (final source in sources) {
      if (source.isEmpty) continue;
      final sourceStreamId = _streamIdFromMap(source);
      if (currentStreamId > 0 &&
          sourceStreamId > 0 &&
          sourceStreamId != currentStreamId) {
        continue;
      }

      final ownerId = _ownerIdFromMap(source);
      if (ownerId > 0) return ownerId == myId;
    }

    return false;
  }

  bool _selfCallRowSaysAdmin({LivestreamController? controller}) {
    final myId = _currentUserId();
    if (myId <= 0) return false;

    try {
      final ws = Get.find<WebsocketController>();
      for (final raw in ws.liveCallList) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final user = _safeMap(row['user']);
        final uid = _safeInt(row['caller_id'] ?? row['user_id'] ?? user['id']);
        if (uid != myId) continue;

        final status = (row['call_status'] ?? row['status'] ?? '')
            .toString()
            .toLowerCase();
        final accepted =
            status.isEmpty ||
                status == 'accepted' ||
                status == 'joined' ||
                status == 'active' ||
                status == 'live';
        if (!accepted) continue;

        return _truthy(
          row['is_guardian'] ??
              row['guardian'] ??
              user['is_guardian'] ??
              user['guardian'],
        );
      }
    } catch (_) {}

    return false;
  }

  /// ✅ Admin permission current room-er local state theke nibe.
  /// Global homeController guardian flag use korbo na, karon eta onno live-e leak hoy.
  bool _isCurrentRoomAdmin([LivestreamController? controller]) {
    final c = controller ?? Get.find<LivestreamController>();
    final myId = _currentUserId();
    if (myId <= 0) return false;

    try {
      if (c.roomGuardianMap.containsKey(myId)) {
        return c.roomGuardianMap[myId] == true;
      }
      if (c.isMyGuardian.value == true) return true;
    } catch (_) {}

    if (_selfCallRowSaysAdmin(controller: c)) return true;

    return false;
  }

  /// ✅ Host tools only current room host OR current room admin.
  /// raw widget.isBroadcaster directly use korle own live theke ber hoyeo onno live-e control leak kore.
  bool get _canUseHostTools {
    try {
      final c = Get.find<LivestreamController>();
      return _isCurrentRoomOwner(c) || _isCurrentRoomAdmin(c);
    } catch (_) {
      return false;
    }
  }

  bool _ensureCanUseHostTools(String actionName) {
    if (_canUseHostTools) return true;
    debugPrint(
      '⛔ Entertainment tool blocked => action=$actionName streamType=${widget.streamType}',
    );
    Fluttertoast.showToast(
      msg: ('Only host or this room admin can do this').appTr,
    );
    return false;
  }

  num? _coinNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return num.tryParse(text);
  }

  /// Spendable account coin balance.
  /// Different API/model versions may expose the same balance using
  /// different field names, so the known names are checked safely.
  num get _currentAccountCoins {
    final dynamic user = authController.userProfile.value.user;
    if (user == null) return 0;

    try {
      final value = _coinNumber(user.levelCoins);
      if (value != null) return value;
    } catch (_) {}

    try {
      final value = _coinNumber(user.levelCoins);
      if (value != null) return value;
    } catch (_) {}

    try {
      final value = _coinNumber(user.levelCoins);
      if (value != null) return value;
    } catch (_) {}

    try {
      final value = _coinNumber(user.levelCoins);
      if (value != null) return value;
    } catch (_) {}

    try {
      final value = _coinNumber(user.levelCoins);
      if (value != null) return value;
    } catch (_) {}

    // Backward-compatible fallback for the currently used user model.
    try {
      final value = _coinNumber(user.levelCoins);
      if (value != null) return value;
    } catch (_) {}

    return 0;
  }

  bool get _hasMinimumCoinBalance => _currentAccountCoins >= 1;

  bool _shouldShowCoinTrading() {
    return _isPopularRoom() && _canUseHostTools;
  }

  bool _shouldShowPocket() {
    return _hasMinimumCoinBalance;
  }

  bool _shouldShowVoiceChange() {
    return (_isAudioRoom() || _isPopularRoom()) && _canUseHostTools;
  }

  bool _shouldShowMusic() {
    return _isAudioRoom() && _canUseHostTools;
  }

  bool _shouldShowYoutube() {
    return _isAudioRoom() && _canUseHostTools;
  }

  bool _shouldShowRoomExtension() {
    return _isAudioRoom() && _canUseHostTools;
  }

  int _asInt(dynamic value, int fallback) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _openRoomSettingPage(LivestreamController livestreamController) async {
    if (!_ensureCanUseHostTools('room_setting')) return;
    final WebsocketController websocketController =
    Get.find<WebsocketController>();
    final AuthController authController = Get.find<AuthController>();

    // Open Setup immediately. Theme/background APIs are warmed inside the page
    // after its first frame, so network latency never blocks navigation.
    if (Get.isBottomSheetOpen == true) {
      Get.back();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    Get.to(
          () => LiveRoomSettingPage(
        livestreamController: livestreamController,
        websocketController: websocketController,
        authController: authController,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 180),
    );
  }

  Widget _premiumTab(String title, int tabIndex) {
    return Tab(
      child: Builder(
        builder: (context) {
          final TabController? controller = DefaultTabController.maybeOf(
            context,
          );
          final bool selected = controller?.index == tabIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: kWeight * 0.030),
            height: kHeight * 0.034,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? const Color(0xff8d52ef) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: selected
                    ? const Color(0xff8d52ef)
                    : Colors.grey.shade300,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: const Color(0xff8d52ef).withOpacity(.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
                  : [],
            ),
            child: Text(title),
          );
        },
      ),
    );
  }

  Widget _premiumSeatCard({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
            colors: [Color(0xff8d52ef), Color(0xffb46cff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: active ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xff8d52ef) : Colors.grey.shade300,
            width: active ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? const Color(0xff8d52ef).withOpacity(.25)
                  : Colors.black.withOpacity(.04),
              blurRadius: active ? 12 : 6,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.weekend_rounded,
              color: active ? Colors.white : const Color(0xff8d52ef),
              size: kHeight * 0.026,
            ),
            SizedBox(width: kWeight * 0.014),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: active ? Colors.white : Colors.black87,
                fontSize: kHeight * 0.015,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumImageCard({
    required String title,
    required String imageUrl,
    required bool active,
    required IconData fallbackIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: active
                        ? const Color(0xff8d52ef)
                        : Colors.grey.shade300,
                    width: active ? 2.2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: active
                          ? const Color(0xff8d52ef).withOpacity(.22)
                          : Colors.black.withOpacity(.05),
                      blurRadius: active ? 12 : 6,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      if (imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: double.infinity,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              _premiumImagePlaceholder(fallbackIcon),
                          errorWidget: (context, url, error) =>
                              _premiumImagePlaceholder(fallbackIcon),
                        )
                      else
                        _premiumImagePlaceholder(fallbackIcon),

                      if (active)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xff8d52ef).withOpacity(.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),

                      if (active)
                        Positioned(
                          right: 7,
                          top: 7,
                          child: Container(
                            height: kHeight * 0.026,
                            width: kHeight * 0.026,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xff8d52ef), Color(0xffff65c3)],
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: kHeight * 0.015,
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
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: kHeight * 0.0132,
                color: active ? const Color(0xff8d52ef) : Colors.black87,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumImagePlaceholder(IconData icon) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade100,
            Colors.grey.shade200,
            Colors.grey.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.grey.shade400, size: kHeight * 0.038),
      ),
    );
  }

  Widget _premiumLayoutCard({
    required int index,
    required int seatCount,
    required bool active,
    required VoidCallback onTap,
  }) {
    final colors = [
      const Color(0xff047fa8),
      const Color(0xffc88622),
      const Color(0xff14833a),
      const Color(0xff6935bd),
      const Color(0xff11cfd7),
      const Color(0xffd946ef),
    ];

    final color = colors[index % colors.length];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? const Color(0xff8d52ef) : Colors.transparent,
            width: active ? 3 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? const Color(0xff8d52ef).withOpacity(.25)
                  : Colors.black.withOpacity(.08),
              blurRadius: active ? 12 : 6,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: _simpleLayoutPreview(
                seatCount: seatCount,
                layoutIndex: index,
              ),
            ),

            Positioned(
              left: 7,
              bottom: 6,
              child: Text(
                ('Layout ${index + 1}').appTr,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: kHeight * 0.0105,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (active)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  height: kHeight * 0.024,
                  width: kHeight * 0.024,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: const Color(0xff8d52ef),
                    size: kHeight * 0.014,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _simpleLayoutPreview({
    required int seatCount,
    required int layoutIndex,
  }) {
    final int previewCount = seatCount >= 12 ? 12 : 9;

    return LayoutBuilder(
      builder: (context, constraints) {
        List<Offset> points;

        if (layoutIndex % 4 == 0) {
          points = const [
            Offset(.50, .18),
            Offset(.12, .45),
            Offset(.31, .45),
            Offset(.50, .45),
            Offset(.69, .45),
            Offset(.88, .45),
            Offset(.12, .70),
            Offset(.31, .70),
            Offset(.50, .70),
            Offset(.69, .70),
            Offset(.88, .70),
            Offset(.50, .88),
          ];
        } else if (layoutIndex % 4 == 1) {
          points = const [
            Offset(.10, .35),
            Offset(.30, .35),
            Offset(.50, .35),
            Offset(.70, .35),
            Offset(.90, .35),
            Offset(.10, .62),
            Offset(.30, .62),
            Offset(.50, .62),
            Offset(.70, .62),
            Offset(.90, .62),
            Offset(.30, .82),
            Offset(.70, .82),
          ];
        } else if (layoutIndex % 4 == 2) {
          points = const [
            Offset(.50, .42),
            Offset(.18, .18),
            Offset(.18, .40),
            Offset(.18, .62),
            Offset(.18, .82),
            Offset(.82, .18),
            Offset(.82, .40),
            Offset(.82, .62),
            Offset(.82, .82),
            Offset(.36, .76),
            Offset(.50, .76),
            Offset(.64, .76),
          ];
        } else {
          points = const [
            Offset(.50, .50),
            Offset(.50, .18),
            Offset(.72, .27),
            Offset(.84, .50),
            Offset(.72, .73),
            Offset(.50, .84),
            Offset(.28, .73),
            Offset(.16, .50),
            Offset(.28, .27),
            Offset(.38, .12),
            Offset(.62, .12),
            Offset(.50, .88),
          ];
        }

        final displayPoints = points.take(previewCount).toList();
        final double dot = kHeight * 0.009;

        return Stack(
          children: displayPoints.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;

            return Positioned(
              left: (constraints.maxWidth * p.dx) - dot,
              top: (constraints.maxHeight * p.dy) - dot,
              child: Container(
                height: dot * 2,
                width: dot * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == 0
                      ? Colors.white.withOpacity(.95)
                      : Colors.white.withOpacity(.42),
                ),
                child: i == 0
                    ? Icon(
                  Icons.person,
                  color: Colors.grey.shade500,
                  size: dot * 1.25,
                )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _premiumLoadingGrid({required String title, required IconData icon}) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.035),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: kWeight * 0.045,
        mainAxisSpacing: kHeight * 0.016,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Colors.grey.shade400,
                    size: kHeight * 0.038,
                  ),
                ),
              ),
            ),
            SizedBox(height: kHeight * 0.006),
            Container(
              height: kHeight * 0.010,
              width: kWeight * 0.22,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showYoutubeControlDialog(LivestreamController livestreamController) {
    if (!_ensureCanUseHostTools('youtube')) return;
    final TextEditingController linkController = TextEditingController(
      text: livestreamController.liveYoutubeUrl.value,
    );

    Get.dialog(
      AlertDialog(
        title: Text(('YouTube Video').appTr),
        content: TextField(
          controller: linkController,
          decoration: InputDecoration(hintText: ('Paste YouTube link').appTr),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(('Cancel').appTr),
          ),
          TextButton(
            onPressed: () async {
              if (!_ensureCanUseHostTools('youtube_play')) return;
              final url = linkController.text.trim();
              if (url.isEmpty) return;
              Get.back();
              await livestreamController.playOrChangeYoutube(url);
            },
            child: Text(('Play').appTr),
          ),
        ],
      ),
    );
  }

  Future<bool> _showCleanChatConfirmDialog() async {
    final result = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            kWeight * 0.045,
            kHeight * 0.024,
            kWeight * 0.045,
            kHeight * 0.018,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: kHeight * 0.060,
                width: kHeight * 0.060,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xffff7a7a), Color(0xffff3f6b)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffff3f6b).withOpacity(.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  color: Colors.white,
                  size: kHeight * 0.030,
                ),
              ),
              SizedBox(height: kHeight * 0.014),
              Text(
                ('Clean Chat?').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: kHeight * 0.018,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: kHeight * 0.008),
              Text(
                ('All current room comments will be removed for everyone.')
                    .appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: kHeight * 0.013,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: kHeight * 0.020),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: kHeight * 0.014,
                        ),
                      ),
                      child: Text(
                        ('Cancel').appTr,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(width: kWeight * 0.026),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffff3f6b),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: kHeight * 0.014,
                        ),
                      ),
                      child: Text(
                        ('Clean').appTr,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    return result == true;
  }

  Future<void> _cleanChatFromEntertainmentTools(
      LivestreamController livestreamController,
      ) async {
    if (!_ensureCanUseHostTools('clean_chat')) return;

    // First close Entertainment tools bottom sheet, then show confirm dialog.
    if (Get.isBottomSheetOpen == true) {
      Get.back();
      await Future.delayed(const Duration(milliseconds: 120));
    }

    final ok = await _showCleanChatConfirmDialog();
    if (!ok) return;

    await livestreamController.cleanLiveComments();
  }

  Widget _cleanChatToolButton({
    required LivestreamController livestreamController,
  }) {
    return Column(
      children: [
        message_bottom1(
          onPress: () => _cleanChatFromEntertainmentTools(livestreamController),
          color2: const Color(0xffffd9df),
          image: 'assets/audio_live/clean-code.png',
          color: const Color(0xffff3f6b),
        ),
        const SizedBox(height: 7),
        Text(('Clean').appTr, style: _entertainmentToolTextStyle),
      ],
    );
  }

  Future<void> _closeEntertainmentSheetBeforeRoomAction() async {
    if (Get.isBottomSheetOpen == true) {
      Get.back();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<bool> _showRoomControlConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) async {
    final bool? result = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            kWeight * 0.045,
            kHeight * 0.024,
            kWeight * 0.045,
            kHeight * 0.018,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: kHeight * 0.060,
                width: kHeight * 0.060,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: confirmColor.withOpacity(.12),
                  boxShadow: [
                    BoxShadow(
                      color: confirmColor.withOpacity(.20),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: confirmColor, size: kHeight * 0.030),
              ),
              SizedBox(height: kHeight * 0.014),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: kHeight * 0.018,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: kHeight * 0.008),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: kHeight * 0.013,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: kHeight * 0.020),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: kHeight * 0.014,
                        ),
                      ),
                      child: Text(
                        ('Cancel').appTr,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  SizedBox(width: kWeight * 0.026),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: kHeight * 0.014,
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    return result == true;
  }

  Future<String?> _showRoomPasswordDialogFromTools() async {
    // Close any previous focus first. The dialog owns its own controller, so
    // dispose happens only after the dialog route is fully removed.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    return Get.dialog<String>(
      const _RoomPasswordDialog(),
      barrierDismissible: true,
    );
  }

  Future<void> _toggleRoomLockFromMoreOptions(
      LivestreamController livestreamController,
      ) async {
    if (!_ensureCanUseHostTools('room_lock')) return;
    if (livestreamController.roomSettingsLoading.value) return;

    try {
      livestreamController.syncRoomSafetyFromCurrentLiveData(
        source: 'more_options_room_lock',
      );
    } catch (_) {}

    final bool currentlyLocked = livestreamController.liveRoomLocked.value;

    await _closeEntertainmentSheetBeforeRoomAction();

    if (currentlyLocked) {
      final bool ok = await _showRoomControlConfirmDialog(
        title: ('Unlock Room?').appTr,
        message:
        ('Users will be able to join this room without password.').appTr,
        confirmText: ('Unlock').appTr,
        confirmColor: Colors.green,
        icon: Icons.lock_open_rounded,
      );
      if (!ok) return;

      await livestreamController.setRoomPasswordLock(lock: false);
      return;
    }

    final String? password = await _showRoomPasswordDialogFromTools();
    if (password == null || password.trim().isEmpty) return;

    await livestreamController.setRoomPasswordLock(
      lock: true,
      roomPassword: password.trim(),
    );
  }

  Future<void> _toggleChatLockFromMoreOptions(
      LivestreamController livestreamController,
      ) async {
    if (!_ensureCanUseHostTools('chat_lock')) return;
    if (livestreamController.roomSettingsLoading.value) return;

    final bool current = livestreamController.liveCommentLocked.value;
    final bool next = !current;

    await _closeEntertainmentSheetBeforeRoomAction();

    final bool ok = await _showRoomControlConfirmDialog(
      title: next ? ('Lock Chat?').appTr : ('Unlock Chat?').appTr,
      message: next
          ? ('Viewers and callers will not be able to send comments in this live room.')
          .appTr
          : ('Viewers and callers will be able to send comments again.').appTr,
      confirmText: next ? ('Lock').appTr : ('Unlock').appTr,
      confirmColor: next ? const Color(0xffF80230) : Colors.green,
      icon: next ? Icons.chat_bubble_rounded : Icons.mark_chat_read_rounded,
    );
    if (!ok) return;

    await livestreamController.setLiveCommentLock(next);
  }

  Future<void> _toggleHiddenRoomFromMoreOptions(
      LivestreamController livestreamController,
      ) async {
    if (!_ensureCanUseHostTools('hidden_room')) return;
    if (livestreamController.roomSettingsLoading.value) return;

    final bool current = livestreamController.liveHiddenRoom.value;
    final bool next = !current;

    await _closeEntertainmentSheetBeforeRoomAction();

    final bool ok = await _showRoomControlConfirmDialog(
      title: next ? ('Hide Room?').appTr : ('Show Room?').appTr,
      message: next
          ? ('This room will be hidden from the live list.').appTr
          : ('This room will show again in the live list.').appTr,
      confirmText: next ? ('Hide').appTr : ('Show').appTr,
      confirmColor: next ? const Color(0xffF80230) : Colors.green,
      icon: next ? Icons.visibility_off_rounded : Icons.visibility_rounded,
    );
    if (!ok) return;

    await livestreamController.setHiddenRoom(next);
  }

  Future<void> _toggleScreenRecordFromMoreOptions(
      LivestreamController livestreamController,
      ) async {
    if (!_ensureCanUseHostTools('screen_record')) return;
    if (livestreamController.roomSettingsLoading.value) return;

    final bool current = livestreamController.liveScreenRecordBlocked.value;
    final bool next = !current;

    await _closeEntertainmentSheetBeforeRoomAction();

    final bool ok = await _showRoomControlConfirmDialog(
      title: next
          ? ('Block Screen Record?').appTr
          : ('Allow Screen Record?').appTr,
      message: next
          ? ('Users will not be able to record this room screen.').appTr
          : ('Users will be able to record this room screen again.').appTr,
      confirmText: next ? ('Block').appTr : ('Allow').appTr,
      confirmColor: next ? const Color(0xffF80230) : Colors.green,
      icon: next
          ? Icons.fiber_manual_record_rounded
          : Icons.video_camera_back_rounded,
    );
    if (!ok) return;

    await livestreamController.setScreenRecordBlock(next);
  }

  Future<void> _toggleScreenshotFromMoreOptions(
      LivestreamController livestreamController,
      ) async {
    if (!_ensureCanUseHostTools('screenshot')) return;
    if (livestreamController.roomSettingsLoading.value) return;

    final bool current = livestreamController.liveScreenshotBlocked.value;
    final bool next = !current;

    await _closeEntertainmentSheetBeforeRoomAction();

    final bool ok = await _showRoomControlConfirmDialog(
      title: next ? ('Block Screenshot?').appTr : ('Allow Screenshot?').appTr,
      message: next
          ? ('Users will not be able to take screenshots in this room.').appTr
          : ('Users will be able to take screenshots again.').appTr,
      confirmText: next ? ('Block').appTr : ('Allow').appTr,
      confirmColor: next ? const Color(0xffF80230) : Colors.green,
      icon: next ? Icons.screenshot_monitor_rounded : Icons.screenshot_rounded,
    );
    if (!ok) return;

    await livestreamController.setScreenshotBlock(next);
  }

  Widget _roomControlToolButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Uses the exact same component, height and width as
        // Game, Clean, Share, Music and every other tool card.
        message_bottom1(
          onPress: onTap,
          image: '',
          icon: icon,
          iconColor: color,
          showStatus: true,
          active: active,
          color: color.withOpacity(active ? .32 : .22),
          color2: color.withOpacity(active ? .16 : .10),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _entertainmentToolTextStyle,
        ),
      ],
    );
  }

  Future<void> _shareCurrentLiveRoom(
      LivestreamController livestreamController,
      ) async {
    try {
      if (Get.isBottomSheetOpen == true) {
        Get.back();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      const String liveUrl = 'https://linlive.fr/';
      await Share.share('🔴 I\'m live now! Watch here: $liveUrl');
    } catch (e) {
      debugPrint('Live share failed: $e');
      Fluttertoast.showToast(msg: ('Unable to share right now').appTr);
    }
  }

  Widget _shareLiveToolButton({
    required LivestreamController livestreamController,
  }) {
    return Column(
      children: [
        message_bottom1(
          onPress: () => _shareCurrentLiveRoom(livestreamController),
          color2: const Color(0xffdcecff),
          image: 'assets/icons/share.png',
          color: const Color(0xff3f8cff),
        ),
        const SizedBox(height: 7),
        Text(('Share').appTr, style: _entertainmentToolTextStyle),
      ],
    );
  }

  TextStyle get _entertainmentToolTextStyle => GoogleFonts.lato(
    color: Colors.black87,
    fontSize: kHeight * 0.013,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final LivestreamController livestreamController = Get.find();
    final WebsocketController websocketController = Get.find();
    final AuthController authController = Get.find();

    return ReusableIconButton(
      onPressed: () {
        if (_canUseHostTools) {
          try {
            livestreamController.syncRoomSafetyFromCurrentLiveData(
              source: 'more_options_open',
            );
          } catch (_) {}
        }

        Get.bottomSheet(
          Container(
            padding: EdgeInsets.symmetric(
              vertical: kHeight * 0.02,
              horizontal: kWeight * 0.04,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              color: Colors.white,
            ),
            height: kHeight * 0.48,
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ('Entertainment tools').appTr,
                    style: GoogleFonts.lato(
                      fontSize: kHeight * 0.014,
                      color: Colors.black.withOpacity(0.90),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: kHeight * 0.02),

                  /// All tools stay serially aligned.
                  /// Hidden tools do not leave an empty slot; the next tool moves forward.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double horizontalGap = kWeight * 0.018;
                      final double itemWidth =
                          (constraints.maxWidth - (horizontalGap * 3)) / 4;

                      final List<Widget> tools = <Widget>[
                        if (_shouldShowPocket())
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () async {
                                  if (Get.isBottomSheetOpen == true) {
                                    Get.back();
                                    await Future.delayed(
                                      const Duration(milliseconds: 120),
                                    );
                                  }

                                  Get.bottomSheet(
                                    SafeArea(
                                      top: false,
                                      child: RedPacketSendWidget(
                                        streamId:
                                        livestreamController.streamId.value,
                                      ),
                                    ),
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                  );
                                },
                                color2: const Color(0xfffed335),
                                image: 'assets/flaticons/audioredpoket .png',
                                color: const Color(0xffffec84),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Pocket').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),

                        if (_shouldShowCoinTrading())
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () {
                                  Get.to(
                                    TradingView(),
                                    transition: Transition.rightToLeft,
                                  );
                                },
                                color2: const Color(0xfffbcab0),
                                image: 'assets/flaticons/profit.png',
                                color: const Color(0xfff65d0a),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Coin trading').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),
                        if (_shouldShowYoutube())
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () {
                                  Get.back();
                                  Fluttertoast.showToast(
                                    msg: "Comming soon",
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                  );
                                  // _showYoutubeControlDialog(
                                  //   livestreamController,
                                  // );
                                },
                                color2: const Color(0xffffd2d2),
                                image: 'assets/flaticons/youtube.png',
                                color: const Color(0xffff3434),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Youtube').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),
                        if (_shouldShowVoiceChange())
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () async {
                                  if (!_ensureCanUseHostTools('voice_change')) {
                                    return;
                                  }

                                  // Capture the root navigator BEFORE closing the
                                  // Entertainment sheet. Its builder context is
                                  // disposed during the close animation and must
                                  // never be reused for another modal route.
                                  final NavigatorState rootNavigator =
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  );

                                  if (Get.isBottomSheetOpen == true) {
                                    Get.back();
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 220),
                                    );
                                  }

                                  if (!mounted || !rootNavigator.mounted)
                                    return;

                                  await VoiceMixerBottomSheet.show(
                                    rootNavigator.context,
                                    rtcEngine: widget.rtcEngine,
                                  );
                                },
                                // The old voice.png asset was not visible on some
                                // devices. A built-in icon always renders clearly.
                                image: 'assets/audio_live/voice-search.png',
                                // icon: Icons.record_voice_over_rounded,
                                iconColor: const Color(0xff7B3FE4),
                                color: const Color(0xffDCCBFF),
                                color2: const Color(0xffF1EAFE),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Voice cng').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),

                        if (_shouldShowMusic())
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () async {
                                  if (!_ensureCanUseHostTools('music')) return;
                                  Get.back();
                                  await Future.delayed(
                                    const Duration(milliseconds: 140),
                                  );
                                  await LiveMusicPlayerSheet.show(
                                    rtcEngine: widget.rtcEngine,
                                  );
                                },
                                color2: const Color(0xff9de7ff),
                                image: 'assets/frame/sound.png',
                                color: const Color(0xff21d4fd),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Music').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),

                        if (_shouldShowRoomExtension())
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () {
                                  _openRoomSettingPage(livestreamController);
                                },
                                color2: const Color(0xff34d04b),
                                image: 'assets/flaticons/theme.png',
                                color: const Color(0xffa7ec68),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Room Setting').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),

                        if ((_isAudioRoom() || _isPopularRoom()) &&
                            _hasMinimumCoinBalance)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              message_bottom1(
                                onPress: () async {
                                  if (Get.isBottomSheetOpen == true) {
                                    Get.back();
                                    await Future.delayed(
                                      const Duration(milliseconds: 120),
                                    );
                                  }

                                  Get.bottomSheet(
                                    GameBottomSheet(isGame: false),
                                    isScrollControlled: true,
                                  );
                                },
                                color2: const Color(0xffbfffff),
                                image:
                                'assets/audio_live/game-removebg-preview.png',
                                color: const Color(0xffc9f6ff),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                ('Game').appTr,
                                textAlign: TextAlign.center,
                                style: _entertainmentToolTextStyle,
                              ),
                            ],
                          ),

                        // Current-room safety controls.
                        if ((_isAudioRoom() || _isPopularRoom()) &&
                            _canUseHostTools)
                          Obx(
                                () => _roomControlToolButton(
                              title: ('Room Lock').appTr,
                              icon: livestreamController.liveRoomLocked.value
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              color: const Color(0xff8d52ef),
                              active: livestreamController.liveRoomLocked.value,
                              onTap: () => _toggleRoomLockFromMoreOptions(
                                livestreamController,
                              ),
                            ),
                          ),

                        if ((_isAudioRoom() || _isPopularRoom()) &&
                            _canUseHostTools)
                          Obx(
                                () => _roomControlToolButton(
                              title: ('Lock Chat').appTr,
                              icon: livestreamController.liveCommentLocked.value
                                  ? Icons.chat_bubble_rounded
                                  : Icons.mark_chat_read_rounded,
                              color: const Color(0xffF80230),
                              active:
                              livestreamController.liveCommentLocked.value,
                              onTap: () => _toggleChatLockFromMoreOptions(
                                livestreamController,
                              ),
                            ),
                          ),

                        if (_isAudioRoom() && _canUseHostTools)
                          Obx(
                                () => _roomControlToolButton(
                              title: ('Hidden Room').appTr,
                              icon: livestreamController.liveHiddenRoom.value
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: const Color(0xffFF8A00),
                              active: livestreamController.liveHiddenRoom.value,
                              onTap: () => _toggleHiddenRoomFromMoreOptions(
                                livestreamController,
                              ),
                            ),
                          ),

                        if ((_isAudioRoom() || _isPopularRoom()) &&
                            _canUseHostTools)
                          Obx(
                                () => _roomControlToolButton(
                              title: ('Screen Record').appTr,
                              icon:
                              livestreamController
                                  .liveScreenRecordBlocked
                                  .value
                                  ? Icons.fiber_manual_record_rounded
                                  : Icons.video_camera_back_rounded,
                              color: const Color(0xffE83E8C),
                              active: livestreamController
                                  .liveScreenRecordBlocked
                                  .value,
                              onTap: () => _toggleScreenRecordFromMoreOptions(
                                livestreamController,
                              ),
                            ),
                          ),

                        if ((_isAudioRoom() || _isPopularRoom()) &&
                            _canUseHostTools)
                          Obx(
                                () => _roomControlToolButton(
                              title: ('Screenshot').appTr,
                              icon:
                              livestreamController
                                  .liveScreenshotBlocked
                                  .value
                                  ? Icons.screenshot_monitor_rounded
                                  : Icons.screenshot_rounded,
                              color: const Color(0xff147DFF),
                              active: livestreamController
                                  .liveScreenshotBlocked
                                  .value,
                              onTap: () => _toggleScreenshotFromMoreOptions(
                                livestreamController,
                              ),
                            ),
                          ),

                        if ((_isAudioRoom() || _isPopularRoom()) &&
                            _canUseHostTools)
                          _cleanChatToolButton(
                            livestreamController: livestreamController,
                          ),

                        if (_isAudioRoom())
                          _shareLiveToolButton(
                            livestreamController: livestreamController,
                          ),
                      ];

                      return Wrap(
                        alignment: WrapAlignment.start,
                        spacing: horizontalGap,
                        runSpacing: kHeight * 0.024,
                        children: tools
                            .map(
                              (tool) => SizedBox(
                            width: itemWidth,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: tool,
                            ),
                          ),
                        )
                            .toList(),
                      );
                    },
                  ),

                  SizedBox(height: kHeight * 0.05),
                  //---------------------card 2 --------------
                ],
              ),
            ),
          ),
        );
      },
      assetImage: 'assets/frame/menu.png',
      imageHeight: kHeight * 0.025,
      backgroundColor: Color(0xffffffff).withOpacity(.2),
    );
  }

  void _showRoomExtensionDialog() {
    final LivestreamController livestreamController =
    Get.find<LivestreamController>();

    // Get current livestream data - you may need to adjust this based on your app structure
    final currentSeatCount = 4; // Default or get from current livestream
    final livestreamId = livestreamController.streamId.value.toString();

    Get.bottomSheet(
      RoomExtensionDialog(
        currentSeatCount: currentSeatCount,
        livestreamId: livestreamId,
      ),
      isScrollControlled: true,
    );
  }
}

class _RoomPasswordDialog extends StatefulWidget {
  const _RoomPasswordDialog();

  @override
  State<_RoomPasswordDialog> createState() => _RoomPasswordDialogState();
}

class _RoomPasswordDialogState extends State<_RoomPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _close([String? result]) {
    _passwordFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(result);
  }

  void _submit() {
    final String password = _passwordController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(password)) {
      Fluttertoast.showToast(msg: ('Please enter 6 digit password').appTr);
      return;
    }
    _close(password);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double availableHeight =
        media.size.height - media.viewInsets.bottom - 48;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight.clamp(260.0, media.size.height).toDouble(),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              kWeight * 0.045,
              kHeight * 0.024,
              kWeight * 0.045,
              kHeight * 0.018,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: kHeight * 0.060,
                  width: kHeight * 0.060,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xff8d52ef), Color(0xffff65c3)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff8d52ef).withOpacity(.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: kHeight * 0.029,
                  ),
                ),
                SizedBox(height: kHeight * 0.014),
                Text(
                  ('Set Room Password').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: kHeight * 0.018,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: kHeight * 0.008),
                Text(
                  ('Enter 6 digit password. Viewers must use this password to join your locked room.')
                      .appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: kHeight * 0.0125,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: kHeight * 0.018),
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: kHeight * 0.020,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    filled: true,
                    fillColor: const Color(0xfff7f4ff),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: kWeight * 0.04,
                      vertical: kHeight * 0.014,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xff8d52ef),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: kHeight * 0.018),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _close(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: kHeight * 0.014,
                          ),
                        ),
                        child: Text(
                          ('Cancel').appTr,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: kWeight * 0.026),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff8d52ef),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: kHeight * 0.014,
                          ),
                        ),
                        child: Text(
                          ('Lock').appTr,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}
