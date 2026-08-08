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
/// Professional Video PK helpers.
///
/// This file is intentionally separated from PopularLiveView so your old live,
/// gift, comment, viewer and seat code stays safe.

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
    return SafeArea(
      top: false,
      child: Container(
        height: Get.height * .72,
        decoration: const BoxDecoration(
          color: Color(0xff120027),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff280052), Color(0xff11001f), Color(0xff001d4c)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ('Select host for Video PK').appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: ('Search host name, ID or level').appTr,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(.55)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(.10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                final lives = _filteredLives(_search.text);
                if (lives.isEmpty) {
                  return Center(
                    child: Text(
                      ('No live host available for PK').appTr,
                      style: TextStyle(color: Colors.white.withOpacity(.75)),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  itemCount: lives.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final live = lives[index];
                    final user = _hostUser(live);
                    final liveId = _toInt(live['id']);
                    final hostId = _toInt(live['user_id'] ?? user['id']);
                    final image = (user['profile_image'] ?? '').toString();
                    final name = (user['name'] ?? ('Host').appTr).toString();
                    final level = (user['level'] ?? '0').toString();
                    final viewers = live['livestream_viewers_count'] ?? live['viewer_count'] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(.10)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white.withOpacity(.18),
                            backgroundImage: image.isEmpty
                                ? null
                                : CachedNetworkImageProvider(ImageHelper.getImageUrl(image)),
                            child: image.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    )),
                                const SizedBox(height: 3),
                                Text(('ID: $hostId  •  Lv.$level  •  Viewers: $viewers').appTr,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.70),
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Obx(() {
                            final loading = liveController.pkRequestLoading.value;
                            return ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () async {
                                await liveController.sendPkRequest(
                                  senderLivestreamId: widget.currentLivestreamId,
                                  receiverLivestreamId: liveId,
                                  senderHostId: widget.currentHostId,
                                  receiverHostId: hostId,
                                  receiverLiveData: live,
                                );
                                if (Get.isBottomSheetOpen == true) Get.back();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pinkAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                              child: loading
                                  ? const SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  :  Text(('PK').appTr),
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
