import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../constants/constants.dart';



import 'package:meetlivepro/app/localization/app_localizer.dart';
void Lucky77BottomGameView(BuildContext context) {
  final int userId = int.tryParse(
    authController.userProfile.value.user?.id?.toString() ?? '0',
  ) ??
      0;

  if (userId <= 0) {
    Get.snackbar(
      ('Error').appTr,
      ('User ID not found').appTr,
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }

  /*
   IMPORTANT:
   Apnar game URL e /game/{id} er jaygay user id jabe.
   Example:
   http://greedygame.linlive.fr/game/100554?user_id=100554&uid=100554
  */
  final Uri gameUri = Uri.http(
    'lucky77.linlive.fr',
    '/game/$userId',
    {
      'user_id': userId.toString(),
      'uid': userId.toString(),
    },
  );

  final String gameUrl = gameUri.toString();

  debugPrint('KING GAME USER ID => $userId');
  debugPrint('KING GAME URL => $gameUrl');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) {
      return KingGameWebViewSheet(gameUrl: gameUrl);
    },
  );
}

class KingGameWebViewSheet extends StatefulWidget {
  final String gameUrl;

  const KingGameWebViewSheet({
    super.key,
    required this.gameUrl,
  });

  @override
  State<KingGameWebViewSheet> createState() => _KingGameWebViewSheetState();
}

class _KingGameWebViewSheetState extends State<KingGameWebViewSheet> {
  late final WebViewController _webViewController;

  bool _isLoading = true;
  String? _errorText;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    debugPrint('KING GAME WEBVIEW INIT => ${widget.gameUrl}');

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;

            setState(() {
              _progress = progress;
            });
          },
          onPageStarted: (url) {
            debugPrint('King game page started => $url');

            if (!mounted) return;

            setState(() {
              _isLoading = true;
              _errorText = null;
              _progress = 0;
            });
          },
          onPageFinished: (url) {
            debugPrint('King game page finished => $url');

            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _progress = 100;
            });
          },
          onWebResourceError: (error) {
            debugPrint(
              'King game web error => '
                  '${error.errorCode} | ${error.errorType} | ${error.description}',
            );

            if (!mounted) return;

            if (error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _errorText = error.description.isNotEmpty
                    ? error.description
                    : ('Failed to load game').appTr;
              });
            }
          },
          onNavigationRequest: (request) {
            debugPrint('King game navigation => ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.gameUrl));
  }

  Future<void> _reloadGame() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _progress = 0;
    });

    await _webViewController.loadRequest(Uri.parse(widget.gameUrl));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: Get.height * 0.7,
        width: Get.width,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: WebViewWidget(
                      controller: _webViewController,
                    ),
                  ),

                  if (_isLoading)
                    Positioned.fill(
                      child: _LinLiveGameLoading(progress: _progress),
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
                              ('Game load failed').appTr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorText ?? ('Failed to load game').appTr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _reloadGame,
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
          ],
        ),
      ),
    );
  }
}

class _LinLiveGameLoading extends StatefulWidget {
  final int progress;

  const _LinLiveGameLoading({required this.progress});

  @override
  State<_LinLiveGameLoading> createState() => _LinLiveGameLoadingState();
}

class _LinLiveGameLoadingState extends State<_LinLiveGameLoading>
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
    final double safeProgress = (widget.progress <= 0
        ? .08
        : widget.progress >= 100
        ? 1.0
        : widget.progress / 100)
        .clamp(.08, 1.0);

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
                      color: const Color(0xFF7B2CFF),
                      backgroundColor: const Color(0xFFE9DDFF),
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
                          color: const Color(0xFF7B2CFF).withOpacity(.18),
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
                        color: Color(0xFF2A124F),
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
                ('Lin Live').appTr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2A124F),
                  fontSize: 26,
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
                  color: const Color(0xFF7B2CFF),
                  backgroundColor: const Color(0xFFE9DDFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
