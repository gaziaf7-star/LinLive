import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class EntryAnimation extends StatefulWidget {
  final dynamic data;

  /// Entry animation sesh hole parent/controller hide korbe.
  final VoidCallback? onFinished;

  const EntryAnimation({
    Key? key,
    required this.data,
    this.onFinished,
  }) : super(key: key);

  @override
  State<EntryAnimation> createState() => _EntryAnimationState();
}

class _EntryAnimationState extends State<EntryAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _fallbackTimer;
  bool _finished = false;

  Map<String, dynamic> get _root => _asMap(widget.data);

  Map<String, dynamic> get _user {
    final root = _root;

    final directUser = _asMap(root['user']);
    if (directUser.isNotEmpty) return directUser;

    final viewerData = _asMap(root['viewer_data']);
    final viewerUser = _asMap(viewerData['user']);
    if (viewerUser.isNotEmpty) return viewerUser;

    final viewer = _asMap(root['viewer']);
    if (viewer.isNotEmpty) return viewer;

    return root;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _safeText(dynamic value) => value?.toString().trim() ?? '';

  Map<String, dynamic> get _entryAsset {
    final user = _user;

    // IMPORTANT:
    // Sudhu entry_histories thekei entry animation nibo.
    // asset_purchase_history use korle profile frame-o entry hisebe show hoy.
    final entryHistory = _asMap(user['entry_histories']);
    final entryAsset = _asMap(entryHistory['asset']);

    if (entryHistory.isEmpty || entryAsset.isEmpty) {
      return <String, dynamic>{};
    }

    final status = _safeText(entryHistory['status']).toLowerCase();
    final assetPath = _safeText(entryAsset['asset']);

    if (assetPath.isEmpty) return <String, dynamic>{};

    // Explicitly inactive/expired entry premium animation hisebe show hobe na.
    if (status.isNotEmpty &&
        status != 'active' &&
        status != 'approved' &&
        status != 'success') {
      return <String, dynamic>{};
    }

    // Extra safety: API vul kore frame type pathaleo entry hisebe show korbo na.
    final assetType = _safeText(
      entryAsset['type'] ??
          entryAsset['asset_type'] ??
          entryAsset['category'] ??
          entryHistory['type'] ??
          entryHistory['asset_type'],
    ).toLowerCase();

    if (assetType.contains('frame')) {
      return <String, dynamic>{};
    }

    return {
      ...entryAsset,
      'asset': assetPath,
      'name': entryAsset['name'] ?? ('Entry').appTr,
      'history_status': entryHistory['status'],
    };
  }

  bool get _hasPremiumEntry => _safeText(_entryAsset['asset']).isNotEmpty;

  String get _entryAssetUrl =>
      ImageHelper.getImageUrl(_safeText(_entryAsset['asset']));

  bool get _isSvgaEntry =>
      _safeText(_entryAsset['asset']).toLowerCase().endsWith('.svga');

  int get _normalEntryMs {
    final root = _root;
    final user = _user;

    final dynamic raw = root['animation_duration_ms'] ??
        root['duration_ms'] ??
        root['duration'] ??
        user['animation_duration_ms'] ??
        user['duration_ms'];

    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed <= 0) return 4500;
    if (parsed < 1200) return 1200;
    if (parsed > 30000) return 30000;
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    _controller = AnimationController(
      duration: Duration(milliseconds: _hasPremiumEntry ? 380 : 450),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: .94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _startFallbackTimer();
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();

    if (!_hasPremiumEntry || !_isSvgaEntry) {
      _fallbackTimer = Timer(Duration(milliseconds: _normalEntryMs), _finish);
      return;
    }

    // SVGA er nijer onFinished use hobe. Callback fail korle safety fallback.
    _fallbackTimer = Timer(const Duration(seconds: 20), _finish);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _fallbackTimer?.cancel();

    if (!mounted) return;

    widget.onFinished?.call();
  }

  @override
  void didUpdateWidget(covariant EntryAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldUser = _extractUserId(oldWidget.data);
    final newUser = _extractUserId(widget.data);

    if (oldUser != newUser) {
      _finished = false;
      _fallbackTimer?.cancel();
      _controller
        ..reset()
        ..forward();
      _startFallbackTimer();
    }
  }

  String _extractUserId(dynamic data) {
    final root = _asMap(data);
    final user = _asMap(root['user']);
    final viewerData = _asMap(root['viewer_data']);
    final viewerUser = _asMap(viewerData['user']);
    return _safeText(user['id'] ??
        viewerUser['id'] ??
        root['viewer_id'] ??
        root['user_id'] ??
        root['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: IgnorePointer(
          ignoring: true,
          child: _hasPremiumEntry ? _premiumFullScreenEntry() : _normalFullScreenEntry(),
        ),
      ),
    );
  }

  Widget _premiumFullScreenEntry() {
    final user = _user;
    final name = _safeText(user['name']).isEmpty ? 'User': _safeText(user['name']);
    final entryName = _safeText(_entryAsset['name']).isEmpty
        ? 'Special Entry'
        : _safeText(_entryAsset['name']);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _isSvgaEntry
              ? SVGAEasyPlayer(
            key: ValueKey(_entryAssetUrl),
            resUrl: _entryAssetUrl,
            fit: BoxFit.contain,
            loops: 0,
            useCache: true,
            onFinished: _finish,
          )
              : CachedNetworkImage(
            imageUrl: _entryAssetUrl,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => _normalFullScreenEntry(),
          ),
        ),

        Positioned(
          left: 14,
          right: 14,
          bottom: kHeight * .18,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: kWeight * .82),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(.62),
                        kAppColor.withOpacity(.82),
                        Colors.black.withOpacity(.20),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(.65),
                      width: .9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kAppColor.withOpacity(.34),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _avatar(user, size: kHeight * .042),
                      SizedBox(width: kWeight * .016),
                      Flexible(
                        child: Text(
                          ('$name entered with $entryName').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: kHeight * .013,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 5),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _normalFullScreenEntry() {
    final user = _user;
    final name = _safeText(user['name']).isEmpty ? 'User': _safeText(user['name']);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: kWeight * .82,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  gradient: LinearGradient(
                    colors: [
                      kAppColor.withOpacity(.96),
                      kAppColor.withOpacity(.48),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(.55),
                    width: .8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kAppColor.withOpacity(.32),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _avatar(user, size: kHeight * .052),
                    SizedBox(width: kWeight * .018),
                    Expanded(
                      child: Text(
                        ('$name entered the room').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: kHeight * .015,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> user, {required double size}) {
    final img = user['profile_image'] ?? user['image'];

    if (img == null || img.toString().isEmpty || img.toString() == 'null') {
      return ClipOval(
        child: Image.asset(
          'assets/images/support_user.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: ImageHelper.getImageUrl(img.toString()),
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorWidget: (_, __, ___) => Image.asset(
          'assets/images/support_user.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
