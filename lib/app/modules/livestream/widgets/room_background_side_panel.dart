import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

Future<void> showRoomBackgroundSidePanel({
  required LivestreamController livestreamController,
  required AuthController authController,
  required int initialBackground,
  required int seatCount,
  required int roomLayout,
  required int roomTheme,
}) async {
  final WebsocketController websocketController =
  Get.find<WebsocketController>();
  final int streamId = livestreamController.streamId.value;
  final int originalBackground = initialBackground;

  final dynamic confirmed = await Get.generalDialog(
    barrierDismissible: true,
    barrierLabel: 'Room Background',
    barrierColor: Colors.black.withOpacity(.18),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: .68,
            heightFactor: 1,
            child: _RoomBackgroundSidePanel(
              livestreamController: livestreamController,
              websocketController: websocketController,
              authController: authController,
              initialBackground: initialBackground,
              seatCount: seatCount,
              roomLayout: roomLayout,
              roomTheme: roomTheme,
            ),
          ),
        ),
      );
    },
  );

  if (confirmed == true) return;

  // Cancel / back / outside tap restores the previous background preview.
  if (streamId > 0) {
    websocketController.liveRoomUpdateStreamId.value = streamId;
  }
  websocketController.liveRoomBackground.value = originalBackground;
  websocketController.liveRoomBackground.refresh();
}
class _RoomBackgroundSidePanel extends StatefulWidget {
  final LivestreamController livestreamController;
  final WebsocketController websocketController;
  final AuthController authController;
  final int initialBackground;
  final int seatCount;
  final int roomLayout;
  final int roomTheme;

  const _RoomBackgroundSidePanel({
    required this.livestreamController,
    required this.websocketController,
    required this.authController,
    required this.initialBackground,
    required this.seatCount,
    required this.roomLayout,
    required this.roomTheme,
  });

  @override
  State<_RoomBackgroundSidePanel> createState() =>
      _RoomBackgroundSidePanelState();
}

class _RoomBackgroundSidePanelState extends State<_RoomBackgroundSidePanel> {
  late int _selectedBackground;

  @override
  void initState() {
    super.initState();
    _selectedBackground = widget.initialBackground;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.livestreamController.backgroundList.isEmpty) {
        widget.livestreamController.showBackground();
      }
    });
  }

  String _imageUrl(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$kDomainUrl/$value';
  }

  int _asInt(dynamic value, int fallback) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _previewBackground(int backgroundId) {
    final int streamId = widget.livestreamController.streamId.value;

    // Local preview only: do NOT call edit API here.
    // We also keep the cache explicitly valid for this current room so even
    // selecting "No Background" (-1) previews correctly.
    if (streamId > 0) {
      widget.websocketController.liveRoomUpdateStreamId.value = streamId;
    }
    widget.websocketController.liveRoomSeatCount.value = widget.seatCount;
    widget.websocketController.liveRoomLayout.value = widget.roomLayout;
    widget.websocketController.liveRoomTheme.value = widget.roomTheme;
    widget.websocketController.liveRoomBackground.value = backgroundId;
    widget.websocketController.liveRoomBackground.refresh();
  }

  Future<void> _confirm() async {
    if (widget.livestreamController.roomEditLoading.value) return;

    await widget.livestreamController.editLiveStreamRoom(
      livestreamId: widget.livestreamController.streamId.value,
      userId: widget.authController.userProfile.value.user?.id?.toInt() ?? 0,
      seatCount: widget.seatCount,
      roomLayout: widget.roomLayout,
      roomTheme: widget.roomTheme,
      roomBackground: _selectedBackground,
    );

    if (mounted) Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xfff7f7f8),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(-8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xffededee), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ('Room Background').appTr,
                      style: GoogleFonts.roboto(
                        color: const Color(0xff161616),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(result: false),
                    icon: const Icon(Icons.close_rounded, color: Color(0xff555555)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final backgrounds = widget.livestreamController.backgroundList
                    .whereType<Map>()
                    .toList();
                final items = <Map>[
                  {'id': -1, 'title': ('No Background').appTr, 'image': null},
                  ...backgrounds,
                ];

                if (backgrounds.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xff222222)),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: .80,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = _asInt(item['id'], -1);
                    final img = _imageUrl(item['image']);
                    final active = _selectedBackground == id;

                    return GestureDetector(
                      onTap: () async {
                        if (img.isNotEmpty) {
                          try {
                            await precacheImage(
                              CachedNetworkImageProvider(img),
                              context,
                            );
                          } catch (_) {}
                        }
                        if (!mounted) return;
                        setState(() => _selectedBackground = id);
                        _previewBackground(id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: active
                                ? const Color(0xff1f1f1f)
                                : const Color(0xffe8e8ea),
                            width: active ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(active ? .10 : .04),
                              blurRadius: active ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: img.isEmpty
                                  ? Container(
                                color: const Color(0xffeeeeef),
                                child: const Icon(
                                  Icons.block_rounded,
                                  color: const Color(0xff777777),
                                  size: 34,
                                ),
                              )
                                  : CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xffeeeeef),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xffeeeeef),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: const Color(0xff999999),
                                  ),
                                ),
                              ),
                            ),
                            if (active)
                              const Positioned(
                                right: 5,
                                top: 5,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xff161616),
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xffededee), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(result: false),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xfff4f4f5),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xffe3e3e5)),
                        ),
                        child: Text(
                          ('Cancel').appTr,
                          style: GoogleFonts.roboto(
                            color: const Color(0xff222222),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() {
                      final loading =
                          widget.livestreamController.roomEditLoading.value;
                      return GestureDetector(
                        onTap: loading ? null : _confirm,
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xff171717),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: loading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            ('Confirm').appTr,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
