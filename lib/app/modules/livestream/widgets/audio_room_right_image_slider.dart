import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../constants/layout_constant.dart';
import 'audioRoomSupport.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

/// Audio room right side small slider.
class AudioRoomRightImageSlider extends StatefulWidget {
  const AudioRoomRightImageSlider({
    super.key,
    required this.livestreamId,
    this.height,
    this.width,
    this.topPadding,
    this.autoSlideDuration = const Duration(seconds: 3),
    this.roomSupportAsset = 'assets/flaticons/room Support.png',
    this.rocketAsset = 'assets/flaticons/Couple.png',
  });

  final int livestreamId;
  final double? height;
  final double? width;
  final double? topPadding;
  final Duration autoSlideDuration;

  /// First slider image
  final String roomSupportAsset;

  /// Second slider image
  final String rocketAsset;

  @override
  State<AudioRoomRightImageSlider> createState() =>
      _AudioRoomRightImageSliderState();
}

class _AudioRoomRightImageSliderState extends State<AudioRoomRightImageSlider> {
  late final PageController _pageController;
  Timer? _timer;
  int _page = 1000;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _page);
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant AudioRoomRightImageSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoSlideDuration != widget.autoSlideDuration) {
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.autoSlideDuration, (_) {
      if (!mounted || !_pageController.hasClients) return;

      _page++;
      _pageController.animateToPage(
        _page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  static const String _cpRankingUrl = 'https://linlive.fr/cp_ranking';

  Future<void> _openItem(int index) async {
    final int realIndex = index % 2;

    if (realIndex == 0) {
      final int safeLiveId = widget.livestreamId;
      if (safeLiveId <= 0) return;
      await RoomSupportWeeklySheet.show(livestreamId: safeLiveId);
      return;
    }

    await _openCpRankingSheet();
  }

  Future<void> _openCpRankingSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Important: if enableDrag is true, the bottom sheet can steal
      // vertical gestures from the WebView and the CP ranking page may not scroll.
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) {
        return const _CpRankingBottomWebViewSheet(
          url: _cpRankingUrl,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.height ?? kHeight * 0.08;
    final double w = widget.width ?? kHeight * 0.07;
    final double top = widget.topPadding ?? kHeight * 0.015;

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: h,
        width: w,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                reverse: false,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => _page = value,
                itemBuilder: (context, index) {
                  final int realIndex = index % 2;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openItem(index),
                    child: realIndex == 0
                        ? _SliderAssetImage(
                      assetPath: widget.roomSupportAsset,
                      fallbackIcon: Icons.emoji_events_rounded,
                    )
                        : _SliderAssetImage(
                      assetPath: widget.rocketAsset,
                      fallbackIcon: Icons.rocket_launch_rounded,
                    ),
                  );
                },
              ),

              Positioned(
                left: 4,
                right: 4,
                bottom: 3,
                child: _TinySliderDots(controller: _pageController),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderAssetImage extends StatelessWidget {
  const _SliderAssetImage({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: double.infinity,
      width: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _SliderFallback(icon: fallbackIcon),
    );
  }
}

class _SliderFallback extends StatelessWidget {
  const _SliderFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xff0a5262),
            Color(0xff0c2435),
            Color(0xff07141d),
          ],
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: kHeight * 0.035,
      ),
    );
  }
}

class _TinySliderDots extends StatelessWidget {
  const _TinySliderDots({required this.controller});

  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        int current = 0;

        if (controller.hasClients && controller.page != null) {
          current = controller.page!.round() % 2;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            final bool active = current == index;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 1.6),
              height: 3.5,
              width: active ? 8 : 3.5,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withOpacity(.42),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CpRankingBottomWebViewSheet extends StatefulWidget {
  final String url;

  const _CpRankingBottomWebViewSheet({required this.url});

  @override
  State<_CpRankingBottomWebViewSheet> createState() =>
      _CpRankingBottomWebViewSheetState();
}

class _CpRankingBottomWebViewSheetState
    extends State<_CpRankingBottomWebViewSheet> {
  late final WebViewController _webViewController;

  bool _isLoading = true;
  String? _errorText;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    debugPrint('CP RANKING WEBVIEW INIT => ${widget.url}');

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            debugPrint('CP ranking page started => $url');
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorText = null;
              _progress = 0;
            });
          },
          onPageFinished: (url) {
            debugPrint('CP ranking page finished => $url');
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            debugPrint(
              'CP ranking web error => '
                  '${error.errorCode} | ${error.errorType} | ${error.description}',
            );

            if (!mounted) return;

            if (error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _errorText = error.description.isNotEmpty
                    ? error.description: ('Failed to load CP ranking').appTr;
              });
            }
          },
          onNavigationRequest: (request) {
            debugPrint('CP ranking navigation => ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _reloadCpRanking() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _progress = 0;
    });

    await _webViewController.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: Get.height * 0.70,
        width: Get.width,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: WebViewWidget(
                  controller: _webViewController,
                  // Let the web page receive vertical drag/touch gestures
                  // so CP ranking can scroll inside the bottom sheet.
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: _LinLiveCpRankingLoading(progress: _progress),
                ),
              if (_errorText != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 46,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ('CP ranking load failed').appTr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorText ?? 'Failed to load CP ranking',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _reloadCpRanking,
                          icon: const Icon(Icons.refresh),
                          label:  Text(('Reload').appTr),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinLiveCpRankingLoading extends StatefulWidget {
  final int progress;

  const _LinLiveCpRankingLoading({required this.progress});

  @override
  State<_LinLiveCpRankingLoading> createState() =>
      _LinLiveCpRankingLoadingState();
}

class _LinLiveCpRankingLoadingState extends State<_LinLiveCpRankingLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: .94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double rawProgress = widget.progress <= 0
        ? .08
        : widget.progress >= 100
        ? 1.0
        : widget.progress / 100;
    final double safeProgress = rawProgress.clamp(.08, 1.0).toDouble();

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 92,
                    width: 92,
                    child: CircularProgressIndicator(
                      value: safeProgress,
                      strokeWidth: 4,
                      color: const Color(0xFFFF3F8E),
                      backgroundColor: const Color(0xFFFFDDEA),
                    ),
                  ),
                  Container(
                    height: 74,
                    width: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3F8E).withOpacity(.18),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Lin\nLive',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF3D1230),
                        fontSize: 17,
                        height: .90,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: .62 + (_controller.value * .38),
                  child: child,
                );
              },
              child: Text(
                ('CP Ranking').appTr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF3D1230),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 132,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: safeProgress,
                  minHeight: 5,
                  color: const Color(0xFFFF3F8E),
                  backgroundColor: const Color(0xFFFFDDEA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
