import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:meetlivepro/app/modules/livestream/controllers/livestream_controller.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
/// BIGO-style YouTube section for live room.

class LiveYoutubePlayerSection extends StatefulWidget {
  const LiveYoutubePlayerSection({
    super.key,
    required this.isBroadcaster,
    required this.liveSeatCount,
    required this.liveController,
    required this.websocketController,
  });

  final bool isBroadcaster;
  final int liveSeatCount;
  final LivestreamController liveController;
  final WebsocketController websocketController;

  @override
  State<LiveYoutubePlayerSection> createState() =>
      _LiveYoutubePlayerSectionState();
}

class _LiveYoutubePlayerSectionState extends State<LiveYoutubePlayerSection> {
  InAppWebViewController? _webViewController;

  String _loadedVideoId = '';
  bool _showWebView = true;
  bool _pageLoaded = false;
  bool _pageFailed = false;

  String get _status => widget.isBroadcaster
      ? widget.liveController.liveYoutubeStatus.value
      : widget.websocketController.liveYoutubeStatus.value;

  String get _videoId => widget.isBroadcaster
      ? widget.liveController.liveYoutubeVideoId.value
      : widget.websocketController.liveYoutubeVideoId.value;

  String get _youtubeUrl => widget.isBroadcaster
      ? widget.liveController.liveYoutubeUrl.value
      : widget.websocketController.liveYoutubeUrl.value;

  bool get _isSupportedLayout =>
      widget.liveSeatCount == 9 || widget.liveSeatCount == 12;

  bool get _shouldShowPlayer {
    final status = _status.trim().toLowerCase();
    final videoId = _videoId.trim();

    return _isSupportedLayout &&
        status.isNotEmpty &&
        status != 'stopped' &&
        videoId.isNotEmpty;
  }

  bool _shouldPlay(String status) {
    final value = status.trim().toLowerCase();
    return value == 'playing' || value == 'resumed' || value == 'changed';
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = _status.trim().toLowerCase();
      final videoId = _videoId.trim();

      if (!_shouldShowPlayer) {
        _resetLocalState();
        return const SizedBox.shrink();
      }

      final bool isPaused = status == 'paused';
      final bool canPlay = _shouldPlay(status);

      if (_loadedVideoId != videoId) {
        _loadedVideoId = videoId;
        _showWebView = true;
        _pageLoaded = false;
        _pageFailed = false;
        _webViewController = null;
      }

      final media = MediaQuery.of(context);
      final double playerHeight = widget.liveSeatCount == 12
          ? media.size.height * 0.255
          : media.size.height * 0.265;

      return Container(
        width: double.infinity,
        height: playerHeight,
        margin: EdgeInsets.only(
          left: media.size.width * 0.03,
          right: media.size.width * 0.03,
          bottom: media.size.height * 0.006,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: isPaused || !_showWebView
                  ? _thumbnailCover(
                videoId: videoId,
                paused: isPaused,
                canPlay: canPlay,
              )
                  : _directYoutubeEmbed(videoId: videoId, autoPlay: canPlay),
            ),

            if (!_pageLoaded && !_pageFailed && !isPaused && _showWebView)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),

            if (!isPaused && _showWebView)
              Positioned(
                top: 7,
                left: 7,
                child: _tinyBadge('YouTube Live'),
              ),

            if (_pageFailed)
              Positioned.fill(
                child: _failedCover(videoId),
              ),

            Positioned(
              top: 7,
              right: 7,
              child: _openYoutubeButton(videoId),
            ),

            if (widget.isBroadcaster)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _hostControlBar(status),
              ),
          ],
        ),
      );
    });
  }

  Widget _directYoutubeEmbed({
    required String videoId,
    required bool autoPlay,
  }) {
    return InAppWebView(
      key: ValueKey('bigo-direct-youtube-$videoId-${autoPlay ? 1 : 0}'),
      initialUrlRequest: URLRequest(url: WebUri(_embedUrl(videoId, autoPlay))),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        iframeAllowFullscreen: true,
        transparentBackground: false,
        disableContextMenu: true,
        supportZoom: false,
        builtInZoomControls: false,
        displayZoomControls: false,
        useShouldOverrideUrlLoading: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStart: (_, __) {
        if (!mounted) return;
        setState(() {
          _pageLoaded = false;
          _pageFailed = false;
        });
      },
      onLoadStop: (controller, _) async {
        _webViewController = controller;
        if (!mounted) return;
        setState(() {
          _pageLoaded = true;
          _pageFailed = false;
        });
      },
      onReceivedError: (_, __, error) {
        debugPrint('LiveYouTube direct WebView error: ${error.description}');
        if (!mounted) return;
        setState(() {
          _pageLoaded = true;
          _pageFailed = true;
        });
      },
      onReceivedHttpError: (_, __, response) {
        debugPrint('LiveYouTube direct HTTP error: ${response.statusCode}');
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.ALLOW;

        final host = uri.host.toLowerCase();
        final isYoutube = host.contains('youtube.com') ||
            host.contains('youtube-nocookie.com') ||
            host.contains('ytimg.com') ||
            host.contains('googlevideo.com') ||
            host.contains('google.com') ||
            host.contains('gstatic.com');

        if (isYoutube) return NavigationActionPolicy.ALLOW;

        return NavigationActionPolicy.CANCEL;
      },
      onConsoleMessage: (_, consoleMessage) {
        final msg = consoleMessage.message;
        if (msg.contains('playVideo is not defined') ||
            msg.contains('liveYoutubeError')) {
          debugPrint('LiveYouTube old JS still exists somewhere: $msg');
        } else {
          debugPrint('LiveYouTube direct WebView: $msg');
        }
      },
    );
  }

  Widget _thumbnailCover({
    required String videoId,
    required bool paused,
    required bool canPlay,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _thumbnailUrl(videoId),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
        ),
        Container(color: Colors.black.withOpacity(.45)),
        Center(
          child: InkWell(
            onTap: paused || !canPlay
                ? null
                : () {
              setState(() {
                _showWebView = true;
                _pageLoaded = false;
                _pageFailed = false;
              });
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(.65),
                border: Border.all(color: Colors.white.withOpacity(.3)),
              ),
              child: Icon(
                paused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: widget.isBroadcaster ? 52 : 14,
          child: Text(
            paused
                ? ('YouTube paused by host').appTr: ('Tap play if the video does not start automatically').appTr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _failedCover(String videoId) {
    return Container(
      color: Colors.black.withOpacity(.88),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ondemand_video_rounded, color: Colors.white, size: 34),
            const SizedBox(height: 8),
             Text(
              ('This video cannot play inside the app WebView.').appTr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _openInYoutube(videoId),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label:  Text(('Open YouTube').appTr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tinyBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _openYoutubeButton(String videoId) {
    return InkWell(
      onTap: () => _openInYoutube(videoId),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child:  Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              ('Open').appTr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostControlBar(String status) {
    final bool paused = status == 'paused';

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.52),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _smallButton(
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              onTap: () async {
                if (paused) {
                  setState(() {
                    _showWebView = true;
                    _pageLoaded = false;
                    _pageFailed = false;
                  });
                  await widget.liveController.resumeYoutube();
                } else {
                  setState(() {
                    _showWebView = false;
                    _pageLoaded = true;
                    _pageFailed = false;
                  });
                  await _webViewController?.loadUrl(
                    urlRequest: URLRequest(url: WebUri('about:blank')),
                  );
                  await widget.liveController.pauseYoutube();
                }
              },
            ),
            _smallButton(
              icon: Icons.link_rounded,
              onTap: _showYoutubeLinkDialog,
            ),
            _smallButton(
              icon: Icons.refresh_rounded,
              onTap: () async {
                final id = _videoId.trim();
                if (id.isEmpty) return;
                setState(() {
                  _showWebView = true;
                  _pageLoaded = false;
                  _pageFailed = false;
                });
                await _webViewController?.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(_embedUrl(id, true, forceReload: true)),
                  ),
                );
              },
            ),
            _smallButton(
              icon: Icons.close_rounded,
              color: Colors.redAccent,
              onTap: () async {
                await _webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri('about:blank')),
                );
                await widget.liveController.stopYoutube();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 28,
        width: 32,
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  void _showYoutubeLinkDialog() {
    final controller = TextEditingController(
      text: widget.liveController.liveYoutubeUrl.value,
    );

    Get.dialog(
      AlertDialog(
        title:  Text(('Play YouTube').appTr),
        content: TextField(
          controller: controller,
          decoration:  InputDecoration(hintText: ('Paste YouTube link here').appTr),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:  Text(('Cancel').appTr),
          ),
          Obx(() {
            final loading = widget.liveController.youtubeLoading.value;
            return TextButton(
              onPressed: loading
                  ? null
                  : () async {
                final url = controller.text.trim();
                if (url.isEmpty) {
                  Fluttertoast.showToast(msg: ('Paste YouTube link').appTr);
                  return;
                }
                Get.back();
                setState(() {
                  _showWebView = true;
                  _pageLoaded = false;
                  _pageFailed = false;
                });
                await widget.liveController.playOrChangeYoutube(url);
              },
              child: Text(loading ? ('Loading...').appTr: ('Play').appTr),
            );
          }),
        ],
      ),
    );
  }

  void _resetLocalState() {
    _webViewController = null;
    _loadedVideoId = '';
    _showWebView = true;
    _pageLoaded = false;
    _pageFailed = false;
  }

  String _embedUrl(String videoId, bool autoPlay, {bool forceReload = false}) {
    final cacheBust = forceReload ? DateTime.now().millisecondsSinceEpoch : 0;

    return Uri.https(
      'www.youtube.com',
      '/embed/$videoId',
      {
        'autoplay': autoPlay ? '1' : '0',
        // Muted autoplay is much more reliable in Android WebView.
        'mute': autoPlay ? '1' : '0',
        'playsinline': '1',
        'controls': '1',
        'rel': '0',
        'modestbranding': '1',
        'fs': '0',
        'iv_load_policy': '3',
        // Keep JS API off. This is the main fix.
        'enablejsapi': '0',
        'origin': 'https://www.youtube.com',
        'widget_referrer': 'https://www.youtube.com',
        if (cacheBust != 0) 'v': '$cacheBust',
      },
    ).toString();
  }

  String _thumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  Future<void> _openInYoutube(String videoId) async {
    final url = _youtubeUrl.trim().isNotEmpty
        ? _youtubeUrl.trim()
        : 'https://www.youtube.com/watch?v=$videoId';

    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened) {
      Fluttertoast.showToast(msg: ('Could not open YouTube').appTr);
    }
  }
}
