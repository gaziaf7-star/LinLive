import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';


class PkRequestButton extends StatelessWidget {
  final int currentLivestreamId;
  final int currentHostId;

  const PkRequestButton({
    super.key,
    required this.currentLivestreamId,
    required this.currentHostId,
  });

  @override
  Widget build(BuildContext context) {
    if (currentLivestreamId <= 0 || currentHostId <= 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => showPkHostSelectBottomSheet(
        context: context,
        currentLivestreamId: currentLivestreamId,
        currentHostId: currentHostId,
      ),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xffff4dd8), Color(0xff7a4cff), Color(0xffffc400)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff4dd8).withOpacity(.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 19),
            const SizedBox(width: 4),
            Text(
              ('PK').appTr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showPkHostSelectBottomSheet({
  required BuildContext context,
  required int currentLivestreamId,
  required int currentHostId,
}) {
  Get.bottomSheet(
    PkHostSelectBottomSheet(
      currentLivestreamId: currentLivestreamId,
      currentHostId: currentHostId,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class PkHostSelectBottomSheet extends StatefulWidget {
  final int currentLivestreamId;
  final int currentHostId;

  const PkHostSelectBottomSheet({
    super.key,
    required this.currentLivestreamId,
    required this.currentHostId,
  });

  @override
  State<PkHostSelectBottomSheet> createState() => _PkHostSelectBottomSheetState();
}

class _PkHostSelectBottomSheetState extends State<PkHostSelectBottomSheet> {
  final TextEditingController _search = TextEditingController();
  final LivestreamController liveController = Get.find<LivestreamController>();
  final HomeController homeController = Get.find<HomeController>();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _hostUser(Map<String, dynamic> live) {
    final callers = live['livestream_callers'];
    if (callers is List && callers.isNotEmpty) {
      final first = _asMap(callers.first);
      final user = _asMap(first['user'] ?? first['User']);
      if (user.isNotEmpty) return user;
    }
    return _asMap(live['user'] ?? live['User']);
  }

  bool _isPkEligible(Map<String, dynamic> live) {
    final id = _toInt(live['id']);
    final hostId = _toInt(live['user_id'] ?? _hostUser(live)['id']);
    final type = (live['stream_type'] ?? '').toString().toLowerCase();
    final status = (live['live_status'] ?? live['status'] ?? 'active').toString().toLowerCase();
    final pkStatus = (live['pk_status'] ?? '').toString().toLowerCase();

    return id > 0 &&
        id != widget.currentLivestreamId &&
        hostId > 0 &&
        hostId != widget.currentHostId &&
        type == 'popular' &&
        status != 'ended' &&
        pkStatus != 'running';
  }

  List<Map<String, dynamic>> _filteredLives(String query) {
    final lower = query.trim().toLowerCase();

    return homeController.showingLiveStreamList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isPkEligible)
        .where((live) {
      if (lower.isEmpty) return true;
      final user = _hostUser(live);
      final name = (user['name'] ?? '').toString().toLowerCase();
      final id = (user['id'] ?? live['user_id'] ?? '').toString().toLowerCase();
      final level = (user['level'] ?? '').toString().toLowerCase();
      final title = (live['stream_bte'] ?? '').toString().toLowerCase();
      return name.contains(lower) || id.contains(lower) || level.contains(lower) || title.contains(lower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double availableHeight =
        media.size.height - media.padding.top - media.viewInsets.bottom;

    // Responsive compact height:
    // - smaller than the old 72% sheet
    // - never pushes under the phone navigation area
    // - still leaves enough room for search + host list on small phones
    final double maxAllowed = math.max(300.0, availableHeight - 12.0);
    final double minAllowed = math.min(360.0, maxAllowed);
    final double desiredHeight = media.size.height * 0.56;
    final double sheetHeight =
    desiredHeight.clamp(minAllowed, maxAllowed).toDouble();

    final double horizontalPadding =
    media.size.width < 360 ? 12.0 : 16.0;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(
        bottom: math.max(6.0, media.padding.bottom),
      ),
      child: Container(
        height: sheetHeight,
        margin: EdgeInsets.symmetric(
          horizontal: media.size.width < 340 ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border.all(
            color: const Color(0xffEEE8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.16),
              blurRadius: 26,
              offset: const Offset(0, -7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffD8D0DA),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                10,
                horizontalPadding - 4,
                6,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xffff4dd8),
                          Color(0xff8B5CFF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      ('Select host for Video PK').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xff241E28),
                        fontSize: media.size.width < 360 ? 14.5 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xff746A76),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.poppins(
                    color: const Color(0xff2B2530),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: ('Search host name, ID or level').appTr,
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xffA198A5),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xff8D8391),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xffF7F4F8),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xffECE5EE),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xffA56CFF),
                        width: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                final lives = _filteredLives(_search.text);

                if (lives.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        ('No live host available for PK').appTr,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xff8D8391),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    2,
                    horizontalPadding,
                    math.max(10.0, media.padding.bottom),
                  ),
                  itemCount: lives.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final live = lives[index];
                    final user = _hostUser(live);
                    final liveId = _toInt(live['id']);
                    final hostId = _toInt(live['user_id'] ?? user['id']);
                    final image = (user['profile_image'] ?? '').toString();
                    final name = (user['name'] ?? ('Host').appTr).toString();
                    final level = (user['level'] ?? '0').toString();
                    final viewers = live['livestream_viewers_count'] ??
                        live['viewer_count'] ??
                        0;

                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: media.size.width < 360 ? 9 : 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffFAF8FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xffEEE7F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: media.size.width < 360 ? 42 : 46,
                            height: media.size.width < 360 ? 42 : 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xffE6DCEC),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child: image.isEmpty
                                  ? Container(
                                color: const Color(0xffF0EBF2),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xff9A8FA0),
                                ),
                              )
                                  : CachedNetworkImage(
                                imageUrl:
                                ImageHelper.getImageUrl(image),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xffF0EBF2),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xff9A8FA0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xff2A2430),
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                    media.size.width < 360 ? 12.5 : 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ('ID: $hostId  •  Lv.$level  •  Viewers: $viewers')
                                      .appTr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xff8A808F),
                                    fontSize:
                                    media.size.width < 360 ? 9.8 : 10.8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Obx(() {
                            final loading =
                                liveController.pkRequestLoading.value;

                            return SizedBox(
                              height: 34,
                              child: ElevatedButton(
                                onPressed: loading
                                    ? null
                                    : () async {
                                  await liveController.sendPkRequest(
                                    senderLivestreamId:
                                    widget.currentLivestreamId,
                                    receiverLivestreamId: liveId,
                                    senderHostId: widget.currentHostId,
                                    receiverHostId: hostId,
                                    receiverLiveData: live,
                                  );

                                  if (Get.isBottomSheetOpen == true) {
                                    Get.back();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xffF14FA8),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                    media.size.width < 360 ? 10 : 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: loading
                                    ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : Text(
                                  ('PK').appTr,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class PkBattleOverlay extends StatelessWidget {
  final Map<String, dynamic> currentLiveData;

  const PkBattleOverlay({
    super.key,
    required this.currentLiveData,
  });

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _hostFromLive(Map<String, dynamic> live) {
    final callers = live['livestream_callers'];
    if (callers is List && callers.isNotEmpty) {
      final user = _asMap(_asMap(callers.first)['user'] ?? _asMap(callers.first)['User']);
      if (user.isNotEmpty) return user;
    }
    return _asMap(live['user'] ?? live['User']);
  }

  Widget _hostCard({
    required String label,
    required Map<String, dynamic> live,
    required int score,
    required bool leading,
  }) {
    final user = _hostFromLive(live);
    final name = (user['name'] ?? label).toString();
    final image = (user['profile_image'] ?? '').toString();

    return Expanded(
      child: Container(
        height: Get.height * .31,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: leading ? Colors.amberAccent : Colors.white.withOpacity(.25),
            width: leading ? 2 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              leading ? const Color(0xffffa000).withOpacity(.35) : Colors.white.withOpacity(.13),
              Colors.black.withOpacity(.45),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: image.isEmpty
                  ? Container(color: Colors.black26)
                  : CachedNetworkImage(
                imageUrl: ImageHelper.getImageUrl(image),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.black26),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(.70)],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 3),
                      Text('$score',
                          style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
            if (leading)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(999)),
                  child:  Text(('LEAD').appTr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LivestreamController liveController = Get.find<LivestreamController>();

    return Obx(() {
      if (!liveController.pkIsRunning.value) return const SizedBox.shrink();

      final senderScore = liveController.pkSenderScore.value;
      final receiverScore = liveController.pkReceiverScore.value;
      final total = math.max(1, senderScore + receiverScore);
      final senderFlex = math.max(1, ((senderScore / total) * 1000).round());
      final receiverFlex = math.max(1, 1000 - senderFlex);
      final currentLiveId = _toInt(currentLiveData['id'] ?? currentLiveData['livestream_id']);
      final senderLive = liveController.pkSenderLivestreamId.value == currentLiveId
          ? currentLiveData
          : liveController.pkSenderLiveData;
      final receiverLive = liveController.pkReceiverLivestreamId.value == currentLiveId
          ? currentLiveData
          : liveController.pkReceiverLiveData;

      return Positioned(
        top: Get.height * .115,
        left: 8,
        right: 8,
        child: IgnorePointer(
          ignoring: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.black.withOpacity(.35),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _hostCard(
                          label: ('HOST A').appTr,
                          live: senderLive,
                          score: senderScore,
                          leading: senderScore > receiverScore,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Colors.pinkAccent, Colors.deepPurpleAccent]),
                            boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(.35), blurRadius: 12)],
                          ),
                          child:  Text(('PK').appTr, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        ),
                        _hostCard(
                          label: ('HOST B').appTr,
                          live: receiverLive,
                          score: receiverScore,
                          leading: receiverScore > senderScore,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(flex: senderFlex, child: Container(height: 9, decoration: const BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.horizontal(left: Radius.circular(999))))),
                        Expanded(flex: receiverFlex, child: Container(height: 9, decoration: const BoxDecoration(color: Colors.lightBlueAccent, borderRadius: BorderRadius.horizontal(right: Radius.circular(999))))),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          liveController.pkFormattedRemainingTime,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        if (liveController.isBroadcaster.value)
                          GestureDetector(
                            onTap: () => liveController.endPk(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(999)),
                              child:  Text(('End PK').appTr, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
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
    });
  }
}
