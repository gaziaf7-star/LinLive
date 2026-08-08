import 'package:flutter/material.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ManagerDashboardWebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const ManagerDashboardWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<ManagerDashboardWebViewPage> createState() =>
      _ManagerDashboardWebViewPageState();
}

class _ManagerDashboardWebViewPageState
    extends State<ManagerDashboardWebViewPage> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xffffffff))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _hasError = false;
              _loadingProgress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = 100;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  void _reloadPage() {
    setState(() {
      _hasError = false;
      _loadingProgress = 0;
    });
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
                colors: [
                 kAppColor2,kAppColor1
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              onPressed: _reloadPage,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!_hasError)
              WebViewWidget(controller: _controller)
            else
              _errorView(),

            if (_loadingProgress < 100 && !_hasError)
              LinearProgressIndicator(
                value: _loadingProgress / 100,
                minHeight: 3,
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.url,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _reloadPage,
              icon: const Icon(Icons.refresh_rounded),
              label:  Text(('Try Again').appTr),
            ),
          ],
        ),
      ),
    );
  }
}