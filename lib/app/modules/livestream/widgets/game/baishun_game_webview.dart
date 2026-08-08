import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'baishun_game_controller.dart';

Future<void> showBaishunGameHalfScreen({
  required BuildContext context,
  required BaishunGameSession session,
}) async {
  final double screenHeight = MediaQuery.sizeOf(context).height;
  final double gameHeight = screenHeight * 0.52;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return SizedBox(
        width: double.infinity,
        height: gameHeight,
        child: BaishunGameWebViewPage(
          session: session,
          isBottomSheet: true,
        ),
      );
    },
  );
}

class BaishunGameWebViewPage extends StatefulWidget {
  const BaishunGameWebViewPage({
    super.key,
    required this.session,
    this.isBottomSheet = false,
  });

  final BaishunGameSession session;
  final bool isBottomSheet;

  @override
  State<BaishunGameWebViewPage> createState() =>
      _BaishunGameWebViewPageState();
}

class _BaishunGameWebViewPageState extends State<BaishunGameWebViewPage> {
  static const String _androidBridgeChannel = '_LinLiveBaishunBridge';

  late final WebViewController _webViewController;
  Timer? _loadTimeout;

  bool _isLoading = true;
  bool _isClosing = false;
  int _progress = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _createWebView();
    _startLoadTimeout();
  }

  void _createWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        _androidBridgeChannel,
        onMessageReceived: _handleAndroidBridgeMessage,
      )
      ..addJavaScriptChannel(
        'getConfig',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMethod('getConfig', message.message);
        },
      )
      ..addJavaScriptChannel(
        'destroy',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMethod('destroy', message.message);
        },
      )
      ..addJavaScriptChannel(
        'gameRecharge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMethod('gameRecharge', message.message);
        },
      )
      ..addJavaScriptChannel(
        'gameLoaded',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMethod('gameLoaded', message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
            });
          },
          onPageStarted: (String url) {
            debugPrint('BAISHUN PAGE STARTED => $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorText = null;
                _progress = 0;
              });
            }
            _injectNativeBridgeRepeatedly();
          },
          onPageFinished: (String url) {
            debugPrint('BAISHUN PAGE FINISHED => $url');
            _injectNativeBridgeRepeatedly();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              'BAISHUN WEB ERROR => '
                  '${error.errorCode} | ${error.errorType} | ${error.description}',
            );

            if (!mounted || error.isForMainFrame != true) return;

            _loadTimeout?.cancel();
            setState(() {
              _isLoading = false;
              _errorText = error.description.trim().isNotEmpty
                  ? error.description
                  : ('Failed to load game').appTr;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('BAISHUN NAVIGATION => ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.session.launchUrl));
  }

  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 45), () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _isLoading = false;
        _errorText = ('Game loading timed out. Please reload.').appTr;
      });
    });
  }

  Future<void> _injectNativeBridgeRepeatedly() async {
    const List<Duration> delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 25),
      Duration(milliseconds: 100),
      Duration(milliseconds: 300),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1400),
    ];

    for (final Duration delay in delays) {
      if (delay != Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!mounted || _isClosing) return;
      await _injectNativeBridge();
    }
  }

  Future<void> _injectNativeBridge() async {
    const String script = r'''
(function () {
  try {
    if (window.NativeBridge && window.NativeBridge.__linLiveBaishunBridge === true) {
      return;
    }

    const sendToFlutter = function (method, payload) {
      const normalizedPayload = typeof payload === 'string'
        ? payload
        : JSON.stringify(payload || {});

      window._LinLiveBaishunBridge.postMessage(JSON.stringify({
        method: method,
        payload: normalizedPayload
      }));
    };

    const bridge = window.NativeBridge || {};
    bridge.__linLiveBaishunBridge = true;
    bridge.getConfig = function (payload) {
      sendToFlutter('getConfig', payload);
    };
    bridge.destroy = function (payload) {
      sendToFlutter('destroy', payload);
    };
    bridge.gameRecharge = function (payload) {
      sendToFlutter('gameRecharge', payload);
    };
    bridge.gameLoaded = function (payload) {
      sendToFlutter('gameLoaded', payload);
    };

    window.NativeBridge = bridge;
    window.__LIN_LIVE_BAISHUN_BRIDGE_READY__ = true;
  } catch (error) {
    console.error('LIN LIVE NativeBridge injection failed', error);
  }
})();
''';

    try {
      await _webViewController.runJavaScript(script);
    } catch (error) {
      debugPrint('BAISHUN BRIDGE INJECT ERROR => $error');
    }
  }

  void _handleAndroidBridgeMessage(JavaScriptMessage message) {
    try {
      final dynamic decoded = jsonDecode(message.message);
      if (decoded is! Map<dynamic, dynamic>) return;

      final Map<String, dynamic> payload =
      Map<String, dynamic>.from(decoded);
      final String method = payload['method']?.toString().trim() ?? '';
      final String rawPayload = payload['payload']?.toString() ?? '{}';

      _handleBridgeMethod(method, rawPayload);
    } catch (error, stackTrace) {
      debugPrint('BAISHUN ANDROID BRIDGE MESSAGE ERROR => $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _handleBridgeMethod(String method, String rawPayload) async {
    debugPrint('BAISHUN BRIDGE METHOD => $method | $rawPayload');

    switch (method) {
      case 'getConfig':
        await _sendConfigToGame(rawPayload);
        break;
      case 'gameLoaded':
        _loadTimeout?.cancel();
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorText = null;
          _progress = 100;
        });
        break;
      case 'gameRecharge':
        Get.snackbar(
          ('Recharge Required').appTr,
          ('Your balance is insufficient. Please recharge from LIN LIVE.').appTr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        break;
      case 'destroy':
        await _closeGame();
        break;
      default:
        debugPrint('BAISHUN UNKNOWN BRIDGE METHOD => $method');
    }
  }

  Future<void> _sendConfigToGame(String rawPayload) async {
    final Map<String, dynamic> request = _decodePayload(rawPayload);
    final String callback = request['jsCallback']?.toString().trim() ?? '';

    if (callback.isEmpty) {
      debugPrint('BAISHUN getConfig callback is empty');
      return;
    }

    final RegExp safeCallback = RegExp(
      r'^[A-Za-z_$][A-Za-z0-9_$]*(\.[A-Za-z_$][A-Za-z0-9_$]*)*$',
    );

    if (!safeCallback.hasMatch(callback)) {
      debugPrint('BAISHUN unsafe callback rejected => $callback');
      return;
    }

    // BAISHUN gameMode contract:
    // 2 = half screen / showroom
    // 3 = full screen / game room
    //
    // This page is shown inside the live room as a bottom sheet, so sending
    // gameMode=3 makes some H5 games render their full-screen canvas inside
    // this smaller viewport. The result is cropped/oversized game UI.
    //
    // Keep the backend session config intact, but send the correct mode to H5
    // for the actual WebView presentation.
    final Map<String, dynamic> safeConfig =
    Map<String, dynamic>.from(widget.session.getConfig);

    safeConfig['gameMode'] = widget.isBottomSheet ? '2' : '3';

    final String configJson = jsonEncode(safeConfig);
    final String javascript = '''
try {
  $callback($configJson);
} catch (error) {
  console.error('LIN LIVE getConfig callback failed', error);
}
''';

    try {
      await _webViewController.runJavaScript(javascript);
      debugPrint(
        'BAISHUN CONFIG SENT => mode=${safeConfig['gameMode']} config=$safeConfig',
      );
    } catch (error, stackTrace) {
      debugPrint('BAISHUN CONFIG SEND ERROR => $error');
      debugPrint('$stackTrace');
    }
  }

  Map<String, dynamic> _decodePayload(String rawPayload) {
    dynamic value = rawPayload;

    for (int index = 0; index < 2; index++) {
      if (value is String) {
        final String text = value.trim();
        if (text.isEmpty) return <String, dynamic>{};
        try {
          value = jsonDecode(text);
          continue;
        } catch (_) {
          return <String, dynamic>{};
        }
      }
      break;
    }

    if (value is Map<String, dynamic>) return value;
    if (value is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Future<void> notifyWalletUpdated() async {
    if (widget.session.userId.isEmpty) return;

    final String payload = jsonEncode(<String, dynamic>{
      'userId': widget.session.userId,
    });

    try {
      await _webViewController.runJavaScript('walletUpdate($payload);');
    } catch (error) {
      debugPrint('BAISHUN walletUpdate ERROR => $error');
    }
  }

  Future<void> _reloadGame() async {
    if (!mounted || _isClosing) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _progress = 0;
    });

    _startLoadTimeout();
    await _webViewController.loadRequest(Uri.parse(widget.session.launchUrl));
  }

  Future<void> _closeGame() async {
    if (_isClosing) return;
    _isClosing = true;
    _loadTimeout?.cancel();

    try {
      await _webViewController.runJavaScript('window.stop();');
    } catch (_) {}

    try {
      await _webViewController.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}

    if (mounted) {
      final NavigatorState navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop<void>();
      }
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _isClosing = true;
    _webViewController.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget gameContent = Stack(
      children: <Widget>[
        Positioned.fill(
          child: WebViewWidget(controller: _webViewController),
        ),
        if (_isLoading)
          Positioned.fill(
            child: _BaishunLoadingOverlay(
              progress: _progress,
              gameName: widget.session.game.name,
            ),
          ),
        if (_errorText != null)
          Positioned.fill(
            child: _BaishunErrorOverlay(
              message: _errorText!,
              onReload: _reloadGame,
              onClose: _closeGame,
            ),
          ),

      ],
    );

    final Widget pageBody;

    if (widget.isBottomSheet) {
      pageBody = ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(5),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFE9EBF0),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: gameContent,
          ),
        ),
      );
    } else {
      pageBody = Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: gameContent,
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _closeGame();
        return false;
      },
      child: pageBody,
    );
  }
}

class _BaishunLoadingOverlay extends StatelessWidget {
  const _BaishunLoadingOverlay({
    required this.progress,
    required this.gameName,
  });

  final int progress;
  final String gameName;

  @override
  Widget build(BuildContext context) {
    final double value = progress <= 0
        ? 0.04
        : (progress / 100).clamp(0.04, 1.0).toDouble();

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE0D7FF),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF7B61FF).withOpacity(0.10),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: Color(0xFF6C4DFF),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  gameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF202124),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ('Loading game...').appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF8A8D95),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double trackWidth = constraints.maxWidth;
                    return Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0F4),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        width: trackWidth * value,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Color(0xFF6C4DFF),
                              Color(0xFF9B73FF),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 11),
                Row(
                  children: <Widget>[
                    Text(
                      ('Preparing game').appTr,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9A9DA5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F1FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$progress%',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF6C4DFF),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BaishunErrorOverlay extends StatelessWidget {
  const _BaishunErrorOverlay({
    required this.message,
    required this.onReload,
    required this.onClose,
  });

  final String message;
  final Future<void> Function() onReload;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 54,
              ),
              const SizedBox(height: 14),
              Text(
                ('Game load failed').appTr,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF202124),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF7A7D85),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF34363B),
                      side: const BorderSide(color: Color(0xFFDADDE3)),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(('Close').appTr),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(('Reload').appTr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
