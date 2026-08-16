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

  double get _uiScale {
    final double width = MediaQuery.sizeOf(context).width;
    return (width / 360.0).clamp(0.86, 1.12).toDouble();
  }

  double _s(double value) => value * _uiScale;

  void _openWalletDestination() {
    Get.to(() => Reselar());
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double width = media.size.width;
    final double horizontalPadding = _s(14);

    return Scaffold(
      backgroundColor: const Color(0xfff7f7fb),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xffff8a00),
          backgroundColor: Colors.white,
          onRefresh: _handlePullRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: media.padding.bottom + _s(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _walletHeader(),
                SizedBox(height: _s(8)),
                _walletTabs(),
                SizedBox(height: _s(24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _goldBalanceCard(),
                ),
                SizedBox(height: _s(11)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _resellerCard(),
                ),
                SizedBox(height: _s(12)),
                _firstRechargeBanner(),
                SizedBox(height: _s(20)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Text(
                    ('Select Recharge Amount').appTr,
                    style: GoogleFonts.poppins(
                      color: const Color(0xff101014),
                      fontSize: _s(width < 340 ? 15 : 16),
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: _s(12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _coinPackageArea(),
                ),
                SizedBox(height: _s(70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _walletHeader() {
    return SizedBox(
      height: _s(52),
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: _s(12),
            child: InkWell(
              onTap: Get.back,
              borderRadius: BorderRadius.circular(_s(30)),
              child: Padding(
                padding: EdgeInsets.all(_s(8)),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: _s(22),
                  color: const Color(0xff303035),
                ),
              ),
            ),
          ),
          Text(
            ('Wallet').appTr,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: _s(22),
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletTabs() {
    return SizedBox(
      height: _s(42),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _walletTab(
              label: ('Coin').appTr,
              selected: true,
              onTap: null,
            ),
          ),
          Expanded(
            child: _walletTab(
              label: ('Top').appTr,
              selected: false,
              onTap: _openWalletDestination,
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletTab({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.poppins(
              color: selected
                  ? const Color(0xff202024)
                  : const Color(0xff99969c),
              fontSize: _s(15),
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: _s(7)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _s(25),
            height: _s(3),
            decoration: BoxDecoration(
              color: selected ? const Color(0xff161619) : Colors.transparent,
              borderRadius: BorderRadius.circular(_s(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldBalanceCard() {
    return Obx(() {
      final dynamic user = authController.userProfile.value.user;
      final dynamic mainCoins = user?.coins;

      return SizedBox(
        height: _s(110),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Color(0xffff7000),
                      Color(0xffff8a05),
                      Color(0xffffc53e),
                      Color(0xffffed79),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_s(10)),
                ),
                padding: EdgeInsets.fromLTRB(
                  _s(16),
                  _s(14),
                  _s(142),
                  _s(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ('Gold Coins Balance').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: _s(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: _s(5)),
                    Row(
                      children: <Widget>[
                        Container(
                          width: _s(25),
                          height: _s(25),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xffffd968).withOpacity(.55),
                            border: Border.all(
                              color: const Color(0xffffdf79),
                              width: _s(1.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'J',
                            style: GoogleFonts.poppins(
                              color: const Color(0xffff9808),
                              fontSize: _s(16),
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: _s(8)),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: Text(
                              _formatNumber(mainCoins),
                              key: ValueKey<String>(
                                mainCoins?.toString() ?? '0',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: _s(28),
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.receipt_long_outlined,
                          size: _s(15),
                          color: Colors.white,
                        ),
                        SizedBox(width: _s(5)),
                        Expanded(
                          child: Text(
                            ('Recharge record').appTr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: _s(11.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: _s(-3),
              top: _s(-18),
              width: _s(145),
              height: _s(128),
              child: IgnorePointer(
                child: Image.asset(
                  'assets/audio_live/walletcoin.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.topRight,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _resellerCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_s(10)),
      child: InkWell(
        onTap: _openWalletDestination,
        borderRadius: BorderRadius.circular(_s(10)),
        child: Container(
          height: _s(54),
          padding: EdgeInsets.symmetric(horizontal: _s(10)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_s(10)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(.02),
                blurRadius: _s(7),
                offset: Offset(0, _s(2)),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Image.asset(
                'assets/audio_live/bagwallet.png',
                width: _s(42),
                height: _s(42),
                fit: BoxFit.contain,
              ),
              SizedBox(width: _s(10)),
              Expanded(
                child: Text(
                  ('Recommend Coins reseller').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff66666a),
                    fontSize: _s(15),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: _s(6)),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xffc6c6c9),
                size: _s(17),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _firstRechargeBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_s(9)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: SizedBox(
          width: double.infinity,
          height: _s(64),
          child: Image.asset(
            'assets/audio_live/recharge.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
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
        final int crossAxisCount = constraints.maxWidth < _s(300) ? 2 : 3;
        final double ratio = crossAxisCount == 2 ? 0.96 : 0.82;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _packages.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: _s(8),
            mainAxisSpacing: _s(8),
            childAspectRatio: ratio,
          ),
          itemBuilder: (BuildContext context, int index) {
            final GoogleRechargePackage item = _packages[index];
            final ProductDetails? playProduct = _billingService.productFor(
              item.productId,
            );
            final bool isSelected = _selectedProductId == item.productId;
            final String imagePath = _packageImageForIndex(index);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _purchaseBusy
                    ? null
                    : () {
                  setState(() {
                    _selectedProductId = item.productId;
                  });
                  _showPurchaseSheet(item, playProduct);
                },
                borderRadius: BorderRadius.circular(_s(9)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.fromLTRB(
                    _s(5),
                    _s(8),
                    _s(5),
                    _s(7),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfffffaf7),
                    borderRadius: BorderRadius.circular(_s(9)),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xffffc78f)
                          : const Color(0xfffff4ed),
                      width: isSelected ? _s(1.1) : _s(.7),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            imagePath,
                            width: _s(58),
                            height: _s(48),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: _s(3)),
                      Text(
                        _formatNumber(item.coins),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xff101014),
                          fontSize: _s(14.5),
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: _s(8)),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(minHeight: _s(24)),
                        padding: EdgeInsets.symmetric(
                          horizontal: _s(4),
                          vertical: _s(4),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffeebd98),
                          borderRadius: BorderRadius.circular(_s(30)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          playProduct?.price ?? item.fallbackPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: _s(11.5),
                            fontWeight: FontWeight.w400,
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

  String _packageImageForIndex(int index) {
    switch (index % 3) {
      case 1:
        return 'assets/audio_live/walletcoin.png';
      case 2:
        return 'assets/audio_live/walletcoin.png';
      default:
        return 'assets/audio_live/walletcoin.png';
    }
  }

  void _showPurchaseSheet(
      GoogleRechargePackage item,
      ProductDetails? playProduct,
      ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  _s(20),
                  _s(12),
                  _s(20),
                  MediaQuery.of(context).padding.bottom + _s(18),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_s(26)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: _s(44),
                        height: _s(5),
                        decoration: BoxDecoration(
                          color: const Color(0xffdedde1),
                          borderRadius: BorderRadius.circular(_s(20)),
                        ),
                      ),
                    ),
                    SizedBox(height: _s(18)),
                    Text(
                      ('Recharge').appTr,
                      style: GoogleFonts.poppins(
                        fontSize: _s(20),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff111115),
                      ),
                    ),
                    SizedBox(height: _s(5)),
                    Text(
                      '${_formatNumber(item.coins)} ${('coins').appTr} • ${playProduct?.price ?? item.fallbackPrice}',
                      style: GoogleFonts.poppins(
                        fontSize: _s(12.5),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff7a777f),
                      ),
                    ),
                    SizedBox(height: _s(18)),
                    _googlePlayMethodCard(),
                    SizedBox(height: _s(14)),
                    _agreementCard(modalSetState: modalSetState),
                    SizedBox(height: _s(16)),
                    _purchaseButton(),
                    SizedBox(height: _s(12)),
                    _securityNote(),
                  ],
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
        final int count = constraints.maxWidth < _s(300) ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: _s(8),
            mainAxisSpacing: _s(8),
            childAspectRatio: count == 2 ? .96 : .82,
          ),
          itemBuilder: (BuildContext context, int index) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xfffffaf7),
                borderRadius: BorderRadius.circular(_s(9)),
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
      padding: EdgeInsets.all(_s(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(12)),
        border: Border.all(color: const Color(0xffeeeef2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            color: const Color(0xffff8a00),
            size: _s(20),
          ),
          SizedBox(width: _s(8)),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: const Color(0xff615e66),
                fontSize: _s(11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => unawaited(onRetry()),
            child: Text(
              ('Retry').appTr,
              style: TextStyle(
                color: const Color(0xffff8a00),
                fontSize: _s(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googlePlayMethodCard() {
    return Container(
      padding: EdgeInsets.all(_s(12)),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf7),
        borderRadius: BorderRadius.circular(_s(16)),
        border: Border.all(color: const Color(0xffffd5ae)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: _s(42),
            height: _s(42),
            decoration: BoxDecoration(
              color: const Color(0xffffebd9),
              borderRadius: BorderRadius.circular(_s(13)),
            ),
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: const Color(0xffff8500),
              size: _s(25),
            ),
          ),
          SizedBox(width: _s(11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ('Google Play Billing').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff211f24),
                    fontSize: _s(12.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: _s(2)),
                Text(
                  ('Secure payment using your Google Play account').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff89858d),
                    fontSize: _s(10),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_rounded,
            color: const Color(0xff168847),
            size: _s(22),
          ),
        ],
      ),
    );
  }

  Widget _agreementCard({StateSetter? modalSetState}) {
    return Container(
      padding: EdgeInsets.fromLTRB(_s(7), _s(5), _s(9), _s(5)),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf7),
        borderRadius: BorderRadius.circular(_s(14)),
        border: Border.all(color: const Color(0xffeeeef2)),
      ),
      child: Row(
        children: <Widget>[
          Checkbox(
            value: _isChecked,
            activeColor: const Color(0xffff8500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_s(5)),
            ),
            onChanged: _purchaseBusy
                ? null
                : (bool? value) {
              setState(() {
                _isChecked = value ?? false;
              });
              modalSetState?.call(() {});
            },
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  color: const Color(0xff4f4c53),
                  fontSize: _s(10.5),
                  fontWeight: FontWeight.w500,
                ),
                children: <InlineSpan>[
                  TextSpan(text: ('I agree to the ').appTr),
                  TextSpan(
                    text: ('User Recharge Disclaimer Agreement').appTr,
                    style: GoogleFonts.poppins(
                      color: const Color(0xffff8500),
                      fontSize: _s(10.5),
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
          backgroundColor: const Color(0xffff8500),
          disabledBackgroundColor: const Color(0xffffd4aa),
          padding: EdgeInsets.symmetric(vertical: _s(13)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_s(14)),
          ),
        ),
        child: _purchaseBusy
            ? SizedBox(
          width: _s(18),
          height: _s(18),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          ('Pay with Google Play').appTr,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: _s(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _securityNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: _s(1)),
          child: Icon(
            Icons.lock_outline_rounded,
            size: _s(14),
            color: const Color(0xff77747b),
          ),
        ),
        SizedBox(width: _s(6)),
        Expanded(
          child: Text(
            ('Google Play processes the payment. Coins are added only after secure server verification.')
                .appTr,
            style: GoogleFonts.poppins(
              color: const Color(0xff77747b),
              fontSize: _s(10),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
