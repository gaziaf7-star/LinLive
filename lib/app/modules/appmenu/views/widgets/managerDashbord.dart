import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/constants/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../apis/api_endpoints.dart';

class ManagerDashboardWebViewPage extends StatefulWidget {
  final String title;
  final String? url;
  final String? target;
  final String? token;

  const ManagerDashboardWebViewPage({
    super.key,
    required this.title,
    this.url,
    this.target,
    this.token,
  });

  @override
  State<ManagerDashboardWebViewPage> createState() =>
      _ManagerDashboardWebViewPageState();
}

class _ManagerDashboardWebViewPageState
    extends State<ManagerDashboardWebViewPage> {
  late final WebViewController _controller;

  void _log(String message) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('[MANAGER_WEBVIEW] $message');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  final ValueNotifier<int> _loadingProgress = ValueNotifier<int>(0);
  final ValueNotifier<bool> _showFirstLoader = ValueNotifier<bool>(true);

  bool _hasLoadedOnce = false;
  bool _hasMainFrameError = false;
  String _mainFrameErrorMessage = '';
  String _currentMainUrl = '';
  bool _errorSnackVisible = false;
  bool _isFetchingSignedUrl = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..enableZoom(false)
      ..setOverScrollMode(WebViewOverScrollMode.never)
      ..setHorizontalScrollBarEnabled(false)
      ..setVerticalScrollBarEnabled(true)
      ..setOnJavaScriptConfirmDialog(_showJavaScriptConfirm)
      ..setOnJavaScriptAlertDialog(_showJavaScriptAlert)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: _onProgress,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onWebResourceError: _onWebResourceError,
          onNavigationRequest: (NavigationRequest request) {
            _log(
              'NAVIGATION REQUEST\n'
                  'URL: ${request.url}\n'
                  'Main frame: ${request.isMainFrame}',
            );
            return NavigationDecision.navigate;
          },
        ),
      );

    _initLoad();
  }

  void _initLoad() {
    _log(
      'INIT LOAD\n'
          'Title: ${widget.title}\n'
          'Target: ${widget.target ?? ''}\n'
          'Passed URL: ${widget.url ?? ''}\n'
          'Token supplied: ${widget.token != null && widget.token!.trim().isNotEmpty}',
    );

    // If a valid pre-signed URL was passed directly, load it immediately
    final String? directUrl = widget.url;
    if (directUrl != null &&
        directUrl.trim().isNotEmpty &&
        directUrl.contains('signature=')) {
      _currentMainUrl = directUrl.trim();
      _log('DIRECT SIGNED URL LOAD\nURL: $_currentMainUrl');
      _controller.loadRequest(Uri.parse(directUrl.trim()));
      return;
    }

    // Otherwise, fetch the secure signed URL from API
    _fetchSignedUrlAndLoad();
  }

  String _resolveBaseUrl() {
    String base = kDomainUrl.trim();

    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }

    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    _log('RESOLVED BASE URL: $base');
    return base;
  }

  String _resolveAuthToken() {
    if (widget.token != null && widget.token!.trim().isNotEmpty) {
      final String token = widget.token!.trim();
      _log('AUTH TOKEN SOURCE: widget.token | length=${token.length}');
      return token;
    }

    try {
      final dynamic ac = authController;
      final dynamic tokenVal = ac.token?.value ?? ac.token;
      if (tokenVal != null && tokenVal.toString().trim().isNotEmpty) {
        final String token = tokenVal.toString().trim();
        _log('AUTH TOKEN SOURCE: authController.token | length=${token.length}');
        return token;
      }
    } catch (e, st) {
      _log('AUTH TOKEN authController.token ERROR: $e\n$st');
    }

    try {
      final dynamic profile = authController.userProfile.value;
      final dynamic tokenVal = profile?.token ?? profile?.user?.token;
      if (tokenVal != null && tokenVal.toString().trim().isNotEmpty) {
        final String token = tokenVal.toString().trim();
        _log('AUTH TOKEN SOURCE: userProfile | length=${token.length}');
        return token;
      }
    } catch (e, st) {
      _log('AUTH TOKEN userProfile ERROR: $e\n$st');
    }

    _log('AUTH TOKEN NOT FOUND');
    return '';
  }

  Future<void> _fetchSignedUrlAndLoad() async {
    if (_isFetchingSignedUrl) return;

    setState(() {
      _isFetchingSignedUrl = true;
      _hasMainFrameError = false;
      _mainFrameErrorMessage = '';
    });
    _showFirstLoader.value = true;
    _loadingProgress.value = 10;

    final String baseUrl = _resolveBaseUrl();
    final String token = _resolveAuthToken();

    _log(
      'FETCH SIGNED URL START\n'
          'Base URL: $baseUrl\n'
          'Token available: ${token.isNotEmpty}\n'
          'Token length: ${token.length}',
    );

    // Determine target parameter
    String targetParam = (widget.target ?? '').trim();
    if (targetParam.isEmpty && widget.url != null && widget.url!.isNotEmpty) {
      // Extract target from raw url path if needed (e.g. https://domain.com/manager_dashboard/123)
      final Uri? parsed = Uri.tryParse(widget.url!);
      if (parsed != null && parsed.pathSegments.isNotEmpty) {
        targetParam = parsed.pathSegments.first;
      }
    }

    _log('RESOLVED TARGET: "$targetParam"');

    try {
      final Uri apiUrl = Uri.parse('$baseUrl/api/manager/webview-url').replace(
        queryParameters: {
          if (targetParam.isNotEmpty) 'target': targetParam,
          'expires_in': '60',
        },
      );

      _log('SIGNED URL API REQUEST\nGET: $apiUrl');

      final http.Response response = await http.get(
        apiUrl,
        headers: {
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      _log(
        'SIGNED URL API RESPONSE\n'
            'Status: ${response.statusCode}\n'
            'Request URL: $apiUrl\n'
            'Body: ${response.body}',
      );

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['status'] == true &&
          decoded['data']?['url'] != null) {
        final String signedUrl = decoded['data']['url'].toString();
        _currentMainUrl = signedUrl;
        _isFetchingSignedUrl = false;

        _log(
          'SIGNED URL SUCCESS\n'
              'Signed URL: $signedUrl\n'
              'Loading into WebView...',
        );

        _controller.loadRequest(Uri.parse(signedUrl));
        return;
      }

      final String message = decoded is Map && decoded['message'] != null
          ? decoded['message'].toString()
          : ('Access denied or invalid permissions').appTr;

      _log(
        'SIGNED URL API FAILED\n'
            'Status: ${response.statusCode}\n'
            'Message: $message\n'
            'Body: ${response.body}',
      );

      if (!mounted) return;
      setState(() {
        _isFetchingSignedUrl = false;
        _hasMainFrameError = true;
        _mainFrameErrorMessage = message;
      });
      _showFirstLoader.value = false;
      _loadingProgress.value = 0;
    } catch (e, st) {
      _log(
        'SIGNED URL REQUEST EXCEPTION\n'
            'Error: $e\n'
            'StackTrace: $st',
      );

      if (!mounted) return;
      setState(() {
        _isFetchingSignedUrl = false;
        _hasMainFrameError = true;
        _mainFrameErrorMessage = ('Network error: unable to reach server').appTr;
      });
      _showFirstLoader.value = false;
      _loadingProgress.value = 0;
    }
  }

  @override
  void dispose() {
    _loadingProgress.dispose();
    _showFirstLoader.dispose();
    super.dispose();
  }

  void _onProgress(int progress) {
    final int old = _loadingProgress.value;

    if (progress == 0 ||
        progress == 25 ||
        progress == 50 ||
        progress == 75 ||
        progress == 100) {
      _log('WEBVIEW PROGRESS: $progress% | URL: $_currentMainUrl');
    }

    if (progress == 0 ||
        progress == 100 ||
        (progress - old).abs() >= 4) {
      _loadingProgress.value = progress.clamp(0, 100).toInt();
    }
  }

  void _onPageStarted(String url) {
    _log('WEBVIEW PAGE STARTED\nURL: $url');
    _currentMainUrl = url;
    _loadingProgress.value = 0;

    if (!_hasLoadedOnce) {
      _showFirstLoader.value = true;
    }

    if (_hasMainFrameError && mounted) {
      setState(() {
        _hasMainFrameError = false;
        _mainFrameErrorMessage = '';
      });
    }
  }

  void _onPageFinished(String url) {
    _log('WEBVIEW PAGE FINISHED\nURL: $url');
    _currentMainUrl = url;
    _loadingProgress.value = 100;
    _showFirstLoader.value = false;
    _hasLoadedOnce = true;

    Future<void>.delayed(const Duration(milliseconds: 40), () async {
      if (!mounted) return;
      await _applyWebViewPerformanceFixes();
    });
  }

  void _onWebResourceError(WebResourceError error) {
    _log(
      'WEBVIEW RESOURCE ERROR\n'
          'Error code: ${error.errorCode}\n'
          'Description: ${error.description}\n'
          'Error type: ${error.errorType}\n'
          'URL: ${error.url}\n'
          'Main frame: ${error.isForMainFrame}\n'
          'Current main URL: $_currentMainUrl',
    );

    final bool definitelyMainFrame = error.isForMainFrame == true;
    final bool unknownButCurrentMainFrame =
        error.isForMainFrame == null &&
            error.url != null &&
            error.url == _currentMainUrl;

    if (!definitelyMainFrame && !unknownButCurrentMainFrame) {
      return;
    }

    _loadingProgress.value = 100;
    _showFirstLoader.value = false;

    final String message = error.description.trim().isEmpty
        ? ('Unable to load page').appTr
        : error.description.trim();

    if (!_hasLoadedOnce) {
      if (!mounted) return;
      setState(() {
        _hasMainFrameError = true;
        _mainFrameErrorMessage = message;
      });
      return;
    }

    _showNonBlockingError(message);
  }

  Future<bool> _showJavaScriptConfirm(
      JavaScriptConfirmDialogRequest request,
      ) async {
    if (!mounted) return false;

    final String message = request.message.trim().isEmpty
        ? ('Are you sure?').appTr
        : request.message.trim();

    _log('JAVASCRIPT CONFIRM\nMessage: $message');
    final String lower = message.toLowerCase();

    final bool destructive = lower.contains('decline') ||
        lower.contains('reject') ||
        lower.contains('delete') ||
        lower.contains('remove');
    final bool acceptAction = lower.contains('accept') ||
        lower.contains('approve') ||
        lower.contains('assign') ||
        lower.contains('give');

    final String actionLabel = destructive
        ? ('Decline').appTr
        : acceptAction
        ? ('Confirm').appTr
        : ('OK').appTr;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFF3E5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  destructive
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user_rounded,
                  color: destructive ? Colors.red : kAppColor1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ('Confirm Action').appTr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: Color(0xFF55565A),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                ('Cancel').appTr,
                style: const TextStyle(
                  color: Color(0xFF66676B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? Colors.red : kAppColor1,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showJavaScriptAlert(
      JavaScriptAlertDialogRequest request,
      ) async {
    if (!mounted) return;

    _log('JAVASCRIPT ALERT\nMessage: ${request.message}');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            ('Notice').appTr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            request.message,
            style: const TextStyle(fontSize: 14.5, height: 1.45),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kAppColor1,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(('OK').appTr),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyWebViewPerformanceFixes() async {
    const String script = r'''
(function () {
  try {
    var oldStyle = document.getElementById('linlive-app-webview-fast-style');
    if (!oldStyle) {
      var style = document.createElement('style');
      style.id = 'linlive-app-webview-fast-style';
      style.textContent = `
        html, body {
          scroll-behavior: auto !important;
          overscroll-behavior-y: contain !important;
          -webkit-overflow-scrolling: touch;
        }
        * {
          -webkit-tap-highlight-color: transparent;
        }
      `;
      document.head && document.head.appendChild(style);
    }

    document.querySelectorAll('a[target="_blank"]').forEach(function (a) {
      a.setAttribute('target', '_self');
    });
    document.querySelectorAll('form[target="_blank"]').forEach(function (f) {
      f.setAttribute('target', '_self');
    });

    if (!window.__linliveOpenPatched) {
      window.__linliveOpenPatched = true;
      window.open = function (url) {
        if (url) window.location.href = url;
        return window;
      };
    }

    document.querySelectorAll('img').forEach(function (img) {
      if (!img.hasAttribute('decoding')) img.setAttribute('decoding', 'async');
      if (!img.hasAttribute('loading')) img.setAttribute('loading', 'lazy');
    });
  } catch (e) {}
})();
''';

    try {
      await _controller.runJavaScript(script);
      _log('WEBVIEW PERFORMANCE SCRIPT APPLIED');
    } catch (e, st) {
      _log(
        'WEBVIEW PERFORMANCE SCRIPT ERROR\n'
            'Error: $e\n'
            'StackTrace: $st',
      );
    }
  }

  void _showNonBlockingError(String message) {
    _log('NON-BLOCKING ERROR: $message');
    if (!mounted || _errorSnackVisible) return;

    _errorSnackVisible = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: ('Retry').appTr,
          onPressed: _reloadPage,
        ),
      ),
    )
        .closed
        .whenComplete(() {
      _errorSnackVisible = false;
    });
  }

  Future<bool> _onWillPop() async {
    final bool canGoBack = await _controller.canGoBack();
    _log('BACK PRESSED | WebView canGoBack: $canGoBack');

    if (canGoBack) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  void _reloadPage() {
    _log(
      'RELOAD REQUESTED\n'
          'Current URL: $_currentMainUrl\n'
          'Has main-frame error: $_hasMainFrameError',
    );

    if (_currentMainUrl.isEmpty || _hasMainFrameError) {
      _fetchSignedUrlAndLoad();
      return;
    }

    _loadingProgress.value = 0;
    if (!_hasLoadedOnce) {
      _showFirstLoader.value = true;
    }

    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [kAppColor2, kAppColor1],
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: ('Refresh').appTr,
              onPressed: _reloadPage,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: _controller),

              if (_hasMainFrameError && !_hasLoadedOnce)
                _errorView(),

              ValueListenableBuilder<bool>(
                valueListenable: _showFirstLoader,
                builder: (context, show, _) {
                  if (!show || _hasMainFrameError) {
                    return const SizedBox.shrink();
                  }
                  return _firstLoadView();
                },
              ),

              Align(
                alignment: Alignment.topCenter,
                child: ValueListenableBuilder<int>(
                  valueListenable: _loadingProgress,
                  builder: (context, progress, _) {
                    if (progress <= 0 || progress >= 100 || _hasMainFrameError) {
                      return const SizedBox.shrink();
                    }
                    return LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _firstLoadView() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFF8ECFA),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: kAppColor1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ('Loading dashboard...').appTr,
              style: const TextStyle(
                color: Color(0xFF333438),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ('Please wait a moment').appTr,
              style: const TextStyle(
                color: Color(0xFF909198),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 58,
                color: Colors.grey,
              ),
              const SizedBox(height: 14),
              Text(
                ('Page load kora jacche na').appTr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_mainFrameErrorMessage.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  _mainFrameErrorMessage,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _reloadPage,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(('Try Again').appTr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
