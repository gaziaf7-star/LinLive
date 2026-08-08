import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../constants/constants.dart';



import 'package:meetlivepro/app/localization/app_localizer.dart';
void RolleteBottomGameView(BuildContext context) {
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
    'roulette.linlive.fr',
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
    return Container(
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
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: .96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: .72, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progressValue = (widget.progress <= 0 ? 8 : widget.progress)
        .clamp(0, 100)
        .toDouble() / 100;

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 84,
              width: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 82,
                    width: 82,
                    child: CircularProgressIndicator(
                      value: widget.progress > 0 && widget.progress < 100
                          ? progressValue
                          : null,
                      strokeWidth: 4.2,
                      backgroundColor: const Color(0xFFE9ECF5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF7B2CFF),
                      ),
                    ),
                  ),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        height: 62,
                        width: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF7B2CFF),
                              Color(0xFFFF2D75),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2CFF).withOpacity(.22),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'L',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  ('Lin Live').appTr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF161A2D),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 118,
              height: 5,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progressValue.clamp(.10, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7B2CFF),
                          Color(0xFFFF2D75),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

