import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../services/google_play_recharge_service.dart';
import '../../rechage/views/Reselar.dart';
import '../../registersteps/controllers/registersteps_controller.dart';

class CoinTopUp extends StatefulWidget {
  const CoinTopUp({super.key});

  @override
  State<CoinTopUp> createState() => _CoinTopUpState();
}

class _CoinTopUpState extends State<CoinTopUp> with WidgetsBindingObserver {
  static const Duration _balancePollInterval = Duration(seconds: 60);

  late final RegisterstepsController _registerController;
  late final GooglePlayRechargeService _billingService;

  Timer? _balanceTimer;
  bool _isAppInForeground = true;
  bool _isBalanceRefreshing = false;
  bool _isChecked = false;
  bool _billingLoading = true;
  bool _purchaseBusy = false;
  String? _billingError;
  String? _selectedProductId;
  DateTime? _lastBalanceSyncAt;
  List<GoogleRechargePackage> _packages = const <GoogleRechargePackage>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _registerController = Get.isRegistered<RegisterstepsController>()
        ? Get.find<RegisterstepsController>()
        : Get.put(RegisterstepsController());

    _billingService = GooglePlayRechargeService(
      dio: Dio(),
      productsUrl: '$kMainUrl/google-play/products',
      verifyUrl: '$kMainUrl/google-play/verify',
      accessTokenProvider: () async {
        return authController.userProfile.value.token?.toString() ?? '';
      },
      onResult: _handleRechargeResult,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait<void>(<Future<void>>[
        _initializeBilling(),
        _refreshBalance(force: true, showLoader: true),
      ]);
      _startBalancePolling();
    });
  }

  @override
  void dispose() {
    _balanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_billingService.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (_isAppInForeground) {
      unawaited(_refreshBalance(force: true, showLoader: false));
    }
  }

  Future<void> _initializeBilling() async {
    if (mounted) {
      setState(() {
        _billingLoading = true;
        _billingError = null;
      });
    }

    try {
      await _billingService.initialize();
      final List<GoogleRechargePackage> available = _billingService
          .availablePackages
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _packages = available;
        _selectedProductId = available.isEmpty
            ? null
            : available.first.productId;
        _billingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _billingLoading = false;
        _billingError = _cleanError(error);
        _packages = const <GoogleRechargePackage>[];
        _selectedProductId = null;
      });
    }
  }

  Future<void> _reloadBillingProducts() async {
    if (mounted) {
      setState(() {
        _billingLoading = true;
        _billingError = null;
      });
    }

    try {
      await _billingService.reloadProducts();
      final List<GoogleRechargePackage> available = _billingService
          .availablePackages
          .toList(growable: false);

      if (!mounted) return;

      final bool oldSelectionStillAvailable = available.any(
        (GoogleRechargePackage item) => item.productId == _selectedProductId,
      );

      setState(() {
        _packages = available;
        _selectedProductId = oldSelectionStillAvailable
            ? _selectedProductId
            : available.isEmpty
            ? null
            : available.first.productId;
        _billingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _billingLoading = false;
        _billingError = _cleanError(error);
      });
    }
  }

  void _startBalancePolling() {
    _balanceTimer?.cancel();
    _balanceTimer = Timer.periodic(_balancePollInterval, (_) async {
      if (!mounted || !_isAppInForeground) return;

      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      await _refreshBalance(force: false, showLoader: false);
    });
  }

  Future<void> _refreshBalance({
    required bool force,
    required bool showLoader,
  }) async {
    if (_isBalanceRefreshing) return;

    _isBalanceRefreshing = true;
    if (showLoader && mounted) {
      setState(() {});
    }

    try {
      final bool refreshed = await _registerController.refreshAuthUserData(
        force: force,
        minInterval: const Duration(seconds: 8),
        persist: false,
      );

      if (refreshed && mounted) {
        _lastBalanceSyncAt = DateTime.now();
      }
    } finally {
      _isBalanceRefreshing = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handlePullRefresh() async {
    await Future.wait<void>(<Future<void>>[
      _reloadBillingProducts(),
      _refreshBalance(force: true, showLoader: false),
    ]);
  }

  Future<void> _handleRechargeResult(GoogleRechargeResult result) async {
    if (!mounted) return;

    setState(() {
      _purchaseBusy = false;
    });

    if (result.success) {
      await _refreshBalance(force: true, showLoader: false);
      if (!mounted) return;

      final String addedText = result.coinsAdded == null
          ? ''
          : ' +${_formatNumber(result.coinsAdded)}';

      Get.snackbar(
        ('Recharge successful').appTr,
        addedText.isEmpty
            ? result.message.appTr
            : '${result.message.appTr}$addedText ${('coins').appTr}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xff167a45),
        colorText: Colors.white,
        margin: const EdgeInsets.all(14),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    Get.snackbar(
      result.pending ? ('Payment pending').appTr : ('Recharge failed').appTr,
      result.message.appTr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: result.pending
          ? const Color(0xff8a6200)
          : Colors.black87,
      colorText: Colors.white,
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _buySelectedPackage() async {
    if (_purchaseBusy) return;

    if (!_isChecked) {
      _showMessage(
        ('Agreement required').appTr,
        ('Please accept the recharge agreement first.').appTr,
      );
      return;
    }

    final String productId = _selectedProductId?.trim() ?? '';
    if (productId.isEmpty) {
      _showMessage(
        ('Select a package').appTr,
        ('Please select a Google Play coin package.').appTr,
      );
      return;
    }

    setState(() {
      _purchaseBusy = true;
    });

    try {
      await _billingService.buy(productId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _purchaseBusy = false;
      });
      _showMessage(('Unable to start purchase').appTr, _cleanError(error));
    }
  }

  void _showMessage(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      margin: const EdgeInsets.all(14),
    );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
  }

  num _safeNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  String _formatNumber(dynamic value) {
    final num amount = _safeNumber(value);
    final num absolute = amount.abs();

    if (absolute >= 1000000000) {
      return _compactValue(amount / 1000000000, 'B');
    }

    if (absolute >= 1000000) {
      return _compactValue(amount / 1000000, 'M');
    }

    if (absolute >= 1000) {
      return _compactValue(amount / 1000, 'K');
    }

    final bool isWhole = amount == amount.roundToDouble();
    return isWhole
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _compactValue(num value, String suffix) {
    String number;

    if (value.abs() >= 100 || value == value.roundToDouble()) {
      number = value.toStringAsFixed(0);
    } else if (value.abs() >= 10) {
      number = value.toStringAsFixed(1);
    } else {
      number = value.toStringAsFixed(2);
    }

    if (number.contains('.')) {
      number = number.replaceFirst(RegExp(r'\.?0+$'), '');
    }

    return '$number$suffix';
  }

  String _syncLabel() {
    if (_isBalanceRefreshing) return ('Syncing balance...').appTr;
    if (_lastBalanceSyncAt == null) return ('Live balance').appTr;
    return ('Updated just now').appTr;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double width = media.size.width;
    final double topPadding = media.padding.top;
    final double expandedHeight = (width * 0.48).clamp(178.0, 230.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xfff7f5fb),
      body: RefreshIndicator(
        color: kAppColor1,
        backgroundColor: Colors.white,
        onRefresh: _handlePullRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              stretch: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: const Color(0xff4b071d),
              expandedHeight: expandedHeight,
              toolbarHeight: 62,
              automaticallyImplyLeading: false,
              leadingWidth: 62,
              leading: Padding(
                padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                child: InkWell(
                  onTap: Get.back,
                  borderRadius: BorderRadius.circular(30),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              titleSpacing: 4,
              title: Text(
                ('Coin Recharge').appTr,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Get.to(Reselar());
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'TOP',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const <StretchMode>[
                  StretchMode.zoomBackground,
                  StretchMode.fadeTitle,
                ],
                background: _premiumBalanceHeader(
                  topPadding: topPadding,
                  width: width,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                width < 380 ? 14 : 18,
                20,
                width < 380 ? 14 : 18,
                32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _sectionTitle(
                    icon: Icons.diamond_rounded,
                    title: ('Select coin package').appTr,
                    subtitle:
                        ('Price is provided securely by Google Play').appTr,
                  ),
                  const SizedBox(height: 14),
                  _coinPackageArea(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    icon: Icons.verified_user_rounded,
                    title: ('Payment method').appTr,
                    subtitle: ('Digital purchases are processed by Google Play')
                        .appTr,
                  ),
                  const SizedBox(height: 14),
                  _googlePlayMethodCard(),
                  const SizedBox(height: 16),
                  _agreementCard(),
                  const SizedBox(height: 18),
                  _purchaseButton(),
                  const SizedBox(height: 12),
                  _securityNote(),
                  const SizedBox(height: 28),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumBalanceHeader({
    required double topPadding,
    required double width,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xff2d0311),
                Color(0xff65052a),
                Color(0xff9d123f),
              ],
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _PremiumCoinPatternPainter()),
          ),
        ),
        Positioned(
          right: -45,
          top: -30,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  Colors.white.withOpacity(.17),
                  Colors.white.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -55,
          bottom: -75,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  const Color(0xffffadca).withOpacity(.18),
                  const Color(0xffffadca).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            width < 380 ? 18 : 22,
            topPadding + 70,
            width < 380 ? 18 : 22,
            18,
          ),
          child: Obx(() {
            final dynamic user = authController.userProfile.value.user;
            final dynamic mainCoins = user?.coins;
            final dynamic earnedCoins = user?.earnedCoins;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Image.asset(
                      'assets/frame/diamonds.png',
                      fit: BoxFit.contain,
                      height: kHeight * 0.05,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ('Available Coins').appTr,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(.78),
                              fontSize: kHeight * 0.02,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, .18),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                            child: Text(
                              _formatNumber(mainCoins),
                              key: ValueKey<String>(
                                mainCoins?.toString() ?? '0',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: width < 380 ? 28 : 34,
                                height: 1.06,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _headerInfoChip(
                        icon: Icons.savings_rounded,
                        text:
                            '${('Earned').appTr}: ${_formatNumber(earnedCoins)}',
                      ),
                      _headerInfoChip(
                        icon: Icons.sync_rounded,
                        text: _syncLabel(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _headerInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white.withOpacity(.90), size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(.90),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xff8f0c3a), Color(0xff5e0625)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xff7e082f).withOpacity(.18),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: const Color(0xff21151c),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: const Color(0xff83757d),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coinPackageArea() {
    if (_billingLoading) {
      return _packageLoadingGrid();
    }

    if (_billingError != null) {
      return _inlineErrorCard(
        message: _billingError!,
        onRetry: _reloadBillingProducts,
      );
    }

    if (_packages.isEmpty) {
      return _inlineErrorCard(
        message: ('No Google Play coin package is available right now.').appTr,
        onRetry: _reloadBillingProducts,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = constraints.maxWidth < 345
            ? 2
            : constraints.maxWidth > 650
            ? 4
            : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _packages.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: crossAxisCount == 2 ? 1.65 : 1.42,
          ),
          itemBuilder: (BuildContext context, int index) {
            final GoogleRechargePackage item = _packages[index];
            final ProductDetails? playProduct = _billingService.productFor(
              item.productId,
            );
            final bool isSelected = _selectedProductId == item.productId;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _purchaseBusy
                    ? null
                    : () {
                        setState(() {
                          _selectedProductId = item.productId;
                        });
                      },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xff8f0c3a)
                          : const Color(0xffeee7eb),
                      width: isSelected ? 1.6 : 1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xff8f0c3a).withOpacity(.13)
                            : Colors.black.withOpacity(.035),
                        blurRadius: isSelected ? 18 : 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Image.asset(
                                  'assets/frame/diamonds.png',
                                  height: 16,
                                  width: 16,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _formatNumber(item.coins),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xff261820),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              playProduct?.price ?? item.fallbackPrice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xff8f0c3a),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          scale: isSelected ? 1 : 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xff8f0c3a),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _packageLoadingGrid() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = constraints.maxWidth < 345 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: count == 2 ? 1.65 : 1.42,
          ),
          itemBuilder: (BuildContext context, int index) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xffeee9ed),
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _inlineErrorCard({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffeee7eb)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, color: Color(0xff8f0c3a)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: const Color(0xff61545b),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              unawaited(onRetry());
            },
            child: Text(('Retry').appTr),
          ),
        ],
      ),
    );
  }

  Widget _googlePlayMethodCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff8f0c3a), width: 1.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xfff8edf2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xff8f0c3a),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ('Google Play Billing').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff271920),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ('Secure payment using your Google Play account').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff8a7c83),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: Color(0xff168847),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _agreementCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffeee7eb)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Checkbox(
            value: _isChecked,
            activeColor: const Color(0xff8f0c3a),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: _purchaseBusy
                ? null
                : (bool? value) {
                    setState(() {
                      _isChecked = value ?? false;
                    });
                  },
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  color: const Color(0xff4f4248),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                children: <InlineSpan>[
                  TextSpan(text: ('I agree to the ').appTr),
                  TextSpan(
                    text: ('User Recharge Disclaimer Agreement').appTr,
                    style: GoogleFonts.poppins(
                      color: const Color(0xff8f0c3a),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        // Open your recharge agreement route here.
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseButton() {
    final bool enabled =
        !_billingLoading &&
        _billingError == null &&
        _selectedProductId != null &&
        !_purchaseBusy;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? _buySelectedPackage : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xff8f0c3a),
          disabledBackgroundColor: const Color(0xffc8b8bf),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _purchaseBusy
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ('Processing purchase...').appTr,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                ('Pay with Google Play').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _securityNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: Color(0xff766871),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            ('Google Play processes the payment. Coins are added only after secure server verification.')
                .appTr,
            style: GoogleFonts.poppins(
              color: const Color(0xff766871),
              fontSize: 10.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumCoinPatternPainter extends CustomPainter {
  const _PremiumCoinPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    final Paint dotPaint = Paint()
      ..color = Colors.white.withOpacity(.075)
      ..style = PaintingStyle.fill;

    const double gap = 34;
    for (double y = 8; y < size.height; y += gap) {
      for (double x = 8; x < size.width; x += gap) {
        final Path path = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(path, linePaint);
        canvas.drawCircle(Offset(x + 15, y + 15), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
