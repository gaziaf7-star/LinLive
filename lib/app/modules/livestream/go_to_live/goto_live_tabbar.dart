import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/agora_service.dart';
import 'go_to_live_audio.dart';
import 'goto_live_popular.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class GotoLiveTabView extends StatefulWidget {
  final VoidCallback? onClose;

  const GotoLiveTabView({
    super.key,
    this.onClose,
  });

  @override
  State<GotoLiveTabView> createState() => _GotoLiveTabViewState();
}

class _GotoLiveTabViewState extends State<GotoLiveTabView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final AgoraService _agoraService = AgoraService();

  DateTime _lastTabTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastAppliedMediaTab = -1;

  @override
  void initState() {
    super.initState();

    // Only 2 modes:
    // 0 = Video LIVE
    // 1 = Audio LIVE
    _tabController = TabController(
      length: 2,
      initialIndex: 0,
      vsync: this,
    );

    _tabController.addListener(_handleTabChanged);

    // Warm only the Agora video engine. This does not start the camera or
    // request permission; GotoPopularLive starts capture explicitly.
    // Doing the engine work here overlaps it with the page transition and
    // makes the visible camera start noticeably faster.
    unawaited(_agoraService.initializeEngine());
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    _applyMediaModeForTab(_tabController.index);
  }

  Future<void> _applyMediaModeForTab(int index) async {
    if (_lastAppliedMediaTab == index) return;

    final engine = _agoraService.engine;

    // The singleton may exist while initialize() is still running. Do not send
    // camera commands until the service reports a ready engine.
    if (engine == null || !_agoraService.isInitialized) {
      _lastAppliedMediaTab = -1;
      return;
    }

    try {
      if (index == 1) {
        // AUDIO LIVE: camera/preview completely off.
        await _agoraService.muteLocalVideoSafe(true);
        await _agoraService.enableLocalVideoSafe(false);
        await _agoraService.stopPreview();
      } else {
        // VIDEO LIVE: only start capture after user has granted permission.
        // GotoPopularLive owns permission handling, so we only prepare here
        // when the engine is already available.
        await engine.enableVideo();
      }

      _lastAppliedMediaTab = index;
    } catch (e) {
      debugPrint('Live create media tab switch failed safely: $e');
    }
  }

  void _onTabTap(int index) {
    if (_tabController.index == index && !_tabController.indexIsChanging) {
      return;
    }

    final now = DateTime.now();

    // Prevent very fast repeated tapping.
    if (now.difference(_lastTabTapTime).inMilliseconds < 220) {
      return;
    }

    _lastTabTapTime = now;

    _applyMediaModeForTab(index);

    _tabController.animateTo(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                // Video LIVE
                GotoPopularLive(onClose: widget.onClose),

                // Audio LIVE
                GotoAudioLiveView(onClose: widget.onClose),
              ],
            ),
          ),

          // Bottom mode selector.
          // Only LIVE + Audio LIVE.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: 72,
                padding: const EdgeInsets.only(
                  left: 34,
                  right: 34,
                  top: 8,
                  bottom: 8,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0x4D000000),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: AnimatedBuilder(
                  animation: _tabController.animation ?? _tabController,
                  builder: (context, child) {
                    final animationValue =
                        _tabController.animation?.value ??
                            _tabController.index.toDouble();

                    final int current = animationValue.round().clamp(0, 1).toInt();

                    return Row(
                      children: [
                        Expanded(
                          child: _buildTabItem(
                            title: ('LIVE').appTr,
                            selected: current == 0,
                            onTap: () => _onTabTap(0),
                          ),
                        ),
                        Expanded(
                          child: _buildTabItem(
                            title: ('Audio LIVE').appTr,
                            selected: current == 1,
                            onTap: () => _onTabTap(1),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: GoogleFonts.poppins(
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(.72),
              fontSize: selected ? 18 : 15,
              fontWeight:
              selected ? FontWeight.w700 : FontWeight.w400,
              height: 1.1,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 7,
            width: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? Colors.white
                  : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
