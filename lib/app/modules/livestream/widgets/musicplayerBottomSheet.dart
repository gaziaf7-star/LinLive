import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/livestream_controller.dart';

/// Full-screen host music library. Playback remains owned by the existing
/// LiveMusicController and the already-joined Agora engine.
class LiveMusicPlayerSheet extends StatefulWidget {
  const LiveMusicPlayerSheet({super.key, required this.rtcEngine, this.initialPlaylist = false});

  final RtcEngine? rtcEngine;
  final bool initialPlaylist;

  static Future<void> show({required RtcEngine? rtcEngine, bool showPlaylist = false}) async {
    final controller = Get.find<LivestreamController>();
    if (controller.isMusicPlayerSheetOpen.value) return;
    controller.isMusicPlayerSheetOpen.value = true;
    try {
      await Get.to<void>(
        () => LiveMusicPlayerSheet(rtcEngine: rtcEngine, initialPlaylist: showPlaylist),
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 220),
      );
    } finally {
      controller.isMusicPlayerSheetOpen.value = false;
    }
  }

  @override
  State<LiveMusicPlayerSheet> createState() => _LiveMusicPlayerSheetState();
}

class _LiveMusicPlayerSheetState extends State<LiveMusicPlayerSheet> {
  final LivestreamController controller = Get.find<LivestreamController>();
  late int tab = widget.initialPlaylist ? 1 : 0;

  @override
  void initState() {
    super.initState();
    if (tab == 0) controller.liveMusicController.loadLocalMusics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 21), onPressed: Get.back),
        titleSpacing: 0,
        title: Row(children: [_tab('Local', 0), _tab('Play List', 1)]),
      ),
      body: Obx(() {
        final hasTrack = controller.selectedMusicPath.value.isNotEmpty;
        return Column(children: [
          Expanded(child: tab == 0 ? _localList() : _playlist()),
          if (hasTrack) _bottomPlayer(),
        ]);
      }),
    );
  }

  Widget _tab(String label, int index) => InkWell(
        onTap: () {
          setState(() => tab = index);
          if (index == 0) controller.liveMusicController.loadLocalMusics();
        },
        child: Container(
          margin: const EdgeInsets.only(right: 34),
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == index ? const Color(0xFFFFC400) : Colors.transparent, width: 3))),
          child: Text(label, style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: tab == index ? FontWeight.w700 : FontWeight.w500)),
        ),
      );

  Widget _localList() {
    final music = controller.liveMusicController;
    if (music.localMusicLoading.value) return const Center(child: CircularProgressIndicator(color: Color(0xFFFFC400)));
    if (music.localMusicPermissionDenied.value) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.library_music_outlined, size: 52, color: Colors.black38),
        const SizedBox(height: 12),
        const Text('Allow audio access to show music on this phone'),
        TextButton(onPressed: () => music.loadLocalMusics(force: true), child: const Text('Try again')),
      ]));
    }
    return RefreshIndicator(
      color: const Color(0xFFFFC400),
      onRefresh: () => music.loadLocalMusics(force: true),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: controller.selectedMusicPath.value.isEmpty ? 12 : 4),
        itemCount: music.localMusics.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) return Padding(padding: const EdgeInsets.fromLTRB(18, 15, 18, 10), child: Text('${music.localMusics.length} songs', style: const TextStyle(color: Colors.black54, fontSize: 13)));
          return _songRow(music.localMusics[index - 1], index - 1, false);
        },
      ),
    );
  }

  Widget _playlist() {
    final songs = controller.liveMusicController.musicPlaylist;
    if (songs.isEmpty) return const Center(child: Text('No songs selected', style: TextStyle(color: Colors.black45)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: songs.length,
      itemBuilder: (_, index) => _songRow(songs[index], index, true),
    );
  }

  Widget _songRow(Map<String, dynamic> song, int index, bool playlist) {
    final path = (song['path'] ?? '').toString();
    final selected = path == controller.selectedMusicPath.value;
    final title = (song['title'] ?? song['name'] ?? 'Unknown Music').toString();
    var artist = (song['artist'] ?? '').toString().trim();
    if (artist.isEmpty || artist == '<unknown>') artist = '<unknown>';
    final duration = int.tryParse('${song['duration'] ?? 0}') ?? 0;
    return InkWell(
      onTap: () => playlist
          ? controller.liveMusicController.playPlaylistMusic(rtcEngine: widget.rtcEngine, index: index)
          : controller.liveMusicController.selectLocalMusic(rtcEngine: widget.rtcEngine, music: song),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F1F1)))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: selected ? const Color(0xFFB88600) : Colors.black, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 4),
            Text(duration > 0 ? '$artist  •  ${controller.formatMusicTime(duration)}' : artist, style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ])),
          const SizedBox(width: 12),
          Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFFFC400), shape: BoxShape.circle), child: Icon(selected && controller.liveMusicStatus.value != 'paused' ? Icons.graphic_eq : Icons.play_arrow_rounded, color: Colors.black, size: 25)),
        ]),
      ),
    );
  }

  Widget _bottomPlayer() {
    final paused = controller.liveMusicStatus.value == 'paused';
    final duration = controller.musicDurationMs.value;
    final position = controller.musicPositionMs.value
        .clamp(0, math.max(duration, 0))
        .toInt();
    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFF111111),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
        child: Row(children: [
          _yellowButton(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, () => paused ? controller.resumeLiveMusic(rtcEngine: widget.rtcEngine) : controller.pauseLiveMusic(rtcEngine: widget.rtcEngine), 52),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(controller.liveMusicName.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), activeTrackColor: const Color(0xFFFFC400), inactiveTrackColor: Colors.white30, thumbColor: const Color(0xFFFFC400), overlayShape: SliderComponentShape.noOverlay), child: Slider(value: duration > 0 ? position.toDouble() : 0, max: duration > 0 ? duration.toDouble() : 1, onChanged: duration > 0 ? (v) => controller.musicPositionMs.value = v.round() : null, onChangeEnd: duration > 0 ? (v) => controller.seekLiveMusic(rtcEngine: widget.rtcEngine, positionMs: v.round()) : null)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(controller.formatMusicTime(position), style: _time), Text(duration > 0 ? controller.formatMusicTime(duration) : '--:--', style: _time)]),
          ])),
          IconButton(onPressed: () => controller.liveMusicController.playPreviousLiveMusic(rtcEngine: widget.rtcEngine), icon: const Icon(Icons.skip_previous_rounded, color: Colors.white)),
          IconButton(onPressed: () => controller.liveMusicController.playNextLiveMusic(rtcEngine: widget.rtcEngine), icon: const Icon(Icons.skip_next_rounded, color: Colors.white)),
          IconButton(onPressed: () => setState(() => tab = 1), icon: const Icon(Icons.queue_music_rounded, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _yellowButton(IconData icon, VoidCallback onTap, double size) => InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: size, height: size, decoration: const BoxDecoration(color: Color(0xFFFFC400), shape: BoxShape.circle), child: Icon(icon, color: Colors.black, size: 31)));
  TextStyle get _time => const TextStyle(color: Colors.white54, fontSize: 10);
}
