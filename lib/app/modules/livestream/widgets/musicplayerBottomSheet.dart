import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveMusicPlayerSheet extends StatefulWidget {
  final RtcEngine? rtcEngine;

  const LiveMusicPlayerSheet({super.key, required this.rtcEngine});

  static Future<void> show({required RtcEngine? rtcEngine}) async {
    final LivestreamController controller =
    Get.find<LivestreamController>();

    // Prevent two music sheets from opening at the same time.
    if (controller.isMusicPlayerSheetOpen.value) return;

    controller.isMusicPlayerSheetOpen.value = true;

    try {
      await Get.bottomSheet<void>(
        LiveMusicPlayerSheet(rtcEngine: rtcEngine),
        isScrollControlled: true,
        ignoreSafeArea: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(.68),
        enterBottomSheetDuration: const Duration(milliseconds: 320),
        exitBottomSheetDuration: const Duration(milliseconds: 220),
      );
    } finally {
      // Works for close button, back button and swipe-down close.
      controller.isMusicPlayerSheetOpen.value = false;
    }
  }

  @override
  State<LiveMusicPlayerSheet> createState() => _LiveMusicPlayerSheetState();
}

class _LiveMusicPlayerSheetState extends State<LiveMusicPlayerSheet>
    with SingleTickerProviderStateMixin {
  final LivestreamController controller = Get.find<LivestreamController>();
  late final AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
  }

  @override
  void dispose() {
    _discController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: height * .88),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final status = controller.liveMusicStatus.value;
          final hasMusic = controller.liveMusicName.value.trim().isNotEmpty &&
              status != 'stopped';
          final paused = status == 'paused';
          if (!hasMusic || paused) {
            if (_discController.isAnimating) {
              _discController.stop(canceled: false);
            }
          } else if (!_discController.isAnimating) {
            _discController.repeat();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _header(hasMusic),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    children: [
                      _artwork(hasMusic, paused),
                      const SizedBox(height: 18),
                      Text(
                        hasMusic ? controller.liveMusicName.value : ('No music selected').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasMusic
                            ? (paused ? ('Paused in live room').appTr: ('Playing for everyone').appTr)
                            : ('Choose an audio file from your device').appTr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.58),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _progress(hasMusic),
                      const SizedBox(height: 10),
                      _mainControls(hasMusic, paused),
                      const SizedBox(height: 18),
                      _volumeCard(),
                      const SizedBox(height: 18),
                      _actionButtons(hasMusic),
                      if (controller.recentLiveMusics.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _recentSection(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _header(bool hasMusic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF80230), Color(0xFF8D52EF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
           Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(('Live Music Studio').appTr,
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text(('Professional room audio control').appTr,
                    style: TextStyle(color: Color(0xFF8F9AB5), fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _artwork(bool hasMusic, bool paused) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFFF80230).withOpacity(.25), blurRadius: 45, spreadRadius: 6),
              BoxShadow(color: const Color(0xFF21D4FD).withOpacity(.15), blurRadius: 55, spreadRadius: 4),
            ],
          ),
        ),
        RotationTransition(
          turns: _discController,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [Color(0xFF131B31), Color(0xFF39415A), Color(0xFF111827), Color(0xFF131B31)],
              ),
              border: Border.all(color: Colors.white.withOpacity(.18), width: 2),
            ),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFF80230), Color(0xFF8D52EF)]),
                ),
                child: Icon(
                  hasMusic ? (paused ? Icons.pause_rounded : Icons.music_note_rounded) : Icons.library_music_rounded,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _progress(bool hasMusic) {
    final duration = controller.musicDurationMs.value;
    final position = controller.musicPositionMs.value
        .clamp(0, math.max(duration, 0))
        .toInt();
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
            activeTrackColor: const Color(0xFFF80230),
            inactiveTrackColor: Colors.white.withOpacity(.12),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFFF80230).withOpacity(.18),
          ),
          child: Slider(
            value: duration > 0 ? position.toDouble() : 0,
            max: duration > 0 ? duration.toDouble() : 1,
            onChanged: hasMusic && duration > 0
                ? (value) => controller.musicPositionMs.value = value.round()
                : null,
            onChangeEnd: hasMusic && duration > 0
                ? (value) => controller.seekLiveMusic(
              rtcEngine: widget.rtcEngine,
              positionMs: value.round(),
            )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(controller.formatMusicTime(position), style: _timeStyle),
              Text(duration > 0 ? controller.formatMusicTime(duration) : '--:--', style: _timeStyle),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle get _timeStyle => TextStyle(color: Colors.white.withOpacity(.48), fontSize: 11, fontWeight: FontWeight.w600);

  Widget _mainControls(bool hasMusic, bool paused) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundButton(
          icon: controller.musicRepeat.value ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          small: true,
          active: controller.musicRepeat.value,
          onTap: hasMusic
              ? () => controller.toggleLiveMusicRepeat(rtcEngine: widget.rtcEngine)
              : null,
        ),
        const SizedBox(width: 22),
        _roundButton(
          icon: Icons.replay_10_rounded,
          onTap: hasMusic
              ? () => controller.seekLiveMusic(
            rtcEngine: widget.rtcEngine,
            positionMs: controller.musicPositionMs.value - 10000,
          )
              : null,
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: !hasMusic
              ? () => controller.pickAndPlayLiveMusic(rtcEngine: widget.rtcEngine)
              : () => paused
              ? controller.resumeLiveMusic(rtcEngine: widget.rtcEngine)
              : controller.pauseLiveMusic(rtcEngine: widget.rtcEngine),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFF80230), Color(0xFFFF5274)]),
              boxShadow: [BoxShadow(color: const Color(0xFFF80230).withOpacity(.42), blurRadius: 24, spreadRadius: 2)],
            ),
            child: controller.musicLoading.value
                ? const Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(!hasMusic || paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(width: 14),
        _roundButton(
          icon: Icons.forward_10_rounded,
          onTap: hasMusic
              ? () => controller.seekLiveMusic(
            rtcEngine: widget.rtcEngine,
            positionMs: controller.musicPositionMs.value + 10000,
          )
              : null,
        ),
        const SizedBox(width: 22),
        _roundButton(
          icon: Icons.queue_music_rounded,
          small: true,
          onTap: () => controller.pickAndPlayLiveMusic(rtcEngine: widget.rtcEngine),
        ),
      ],
    );
  }

  Widget _roundButton({required IconData icon, VoidCallback? onTap, bool small = false, bool active = false}) {
    final size = small ? 38.0 : 46.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFFF80230).withOpacity(.18) : Colors.white.withOpacity(.07),
          border: Border.all(color: active ? const Color(0xFFF80230).withOpacity(.55) : Colors.white.withOpacity(.10)),
        ),
        child: Icon(icon, color: onTap == null ? Colors.white24 : (active ? const Color(0xFFFF6B87) : Colors.white), size: small ? 20 : 24),
      ),
    );
  }

  Widget _volumeCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_up_rounded, color: Color(0xFF21D4FD), size: 23),
          const SizedBox(width: 10),
           Text(('Music volume').appTr, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: const Color(0xFF21D4FD),
                inactiveTrackColor: Colors.white.withOpacity(.10),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: controller.musicVolume.value.toDouble(),
                min: 0,
                max: 100,
                onChanged: (value) {
                  controller.musicVolume.value = value.round();
                  controller.setLiveMusicVolume(rtcEngine: widget.rtcEngine, volume: value.round());
                },
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text('${controller.musicVolume.value}%', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(bool hasMusic) {
    return Row(
      children: [
        Expanded(
          child: _wideButton(
            icon: hasMusic ? Icons.swap_horiz_rounded : Icons.add_rounded,
            label: hasMusic ? 'Change music' : 'Choose music',
            primary: true,
            onTap: () => controller.pickAndPlayLiveMusic(rtcEngine: widget.rtcEngine),
          ),
        ),
        if (hasMusic) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _wideButton(
              icon: Icons.stop_rounded,
              label: ('Stop').appTr,
              onTap: () => controller.stopLiveMusic(rtcEngine: widget.rtcEngine),
            ),
          ),
        ],
      ],
    );
  }

  Widget _wideButton({required IconData icon, required String label, required VoidCallback onTap, bool primary = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            gradient: primary ? const LinearGradient(colors: [Color(0xFFF80230), Color(0xFF8D52EF)]) : null,
            color: primary ? null : Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(15),
            border: primary ? null : Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))],
          ),
        ),
      ),
    );
  }

  Widget _recentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
          children: [
            Icon(Icons.history_rounded, color: Color(0xFF8F9AB5), size: 18),
            SizedBox(width: 7),
            Text(('Recently played').appTr, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        ...controller.recentLiveMusics.take(5).map((music) {
          final selected = music['path'] == controller.selectedMusicPath.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.playRecentLiveMusic(rtcEngine: widget.rtcEngine, music: music),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF80230).withOpacity(.11) : Colors.white.withOpacity(.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? const Color(0xFFF80230).withOpacity(.35) : Colors.white.withOpacity(.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(11)),
                        child: Icon(selected ? Icons.graphic_eq_rounded : Icons.music_note_rounded, color: selected ? const Color(0xFFFF6B87) : Colors.white70, size: 20),
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Text(music['name'] ?? ('Music').appTr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                      const Icon(Icons.play_arrow_rounded, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
