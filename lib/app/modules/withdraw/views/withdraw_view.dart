import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/widgets/after/castom%20appbar.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/setheight.dart';
import '../../../../widgets/small_text_widgets.dart';
import '../../registersteps/controllers/registersteps_controller.dart';
import '../controllers/withdraw_controller.dart';
import '../withdraw_account-add.dart';
import 'exchange_coin_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  bool _isRefreshingBalance = true;
  bool _hasFreshBalance = false;

  @override
  void initState() {
    super.initState();

    // Keep the old page behaviour: WithdrawController must be available.
    if (!Get.isRegistered<WithdrawController>()) {
      Get.put(WithdrawController());
    }

    // Page open হওয়ার সঙ্গে সঙ্গে server থেকে latest user/coin data আনবে।
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshBalance();
    });
  }

  Future<void> _refreshBalance() async {
    if (_isRefreshingBalance && _hasFreshBalance) return;

    if (mounted) {
      setState(() {
        _isRefreshingBalance = true;
      });
    }

    bool refreshed = false;

    try {
      refreshed = await registerstepsController.refreshAuthUserData(
        force: true,
        minInterval: Duration.zero,
        persist: true,
      );

      // অন্য page-এর refresh request চললে method false দিতে পারে।
      // অল্প delay দিয়ে একবার retry করলে stale coin দেখানোর ঝুঁকি কমে।
      if (!refreshed) {
        await Future<void>.delayed(const Duration(milliseconds: 300));

        refreshed = await registerstepsController.refreshAuthUserData(
          force: true,
          minInterval: Duration.zero,
          persist: true,
        );
      }
    } catch (error) {
      debugPrint('Host Center balance refresh error: $error');
      refreshed = false;
    }

    if (!mounted) return;

    setState(() {
      _hasFreshBalance = refreshed;
      _isRefreshingBalance = false;
    });
  }

  Widget _buildReceiveBalance() {
    if (_isRefreshingBalance) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          backgroundColor: Colors.white.withOpacity(0.25),
        ),
      );
    }

    if (!_hasFreshBalance) {
      return InkWell(
        onTap: _refreshBalance,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          child: Text(
            'Tap to retry'.appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Auth profile is Rx, so API refresh or exchange-এর পর value auto update হবে।
    return Obx(() {
      final dynamic rawBalance =
          authController.userProfile.value.user?.earnedCoins;

      final String balance =
      rawBalance?.toString().trim().isNotEmpty == true
          ? rawBalance.toString().trim()
          : '0';

      return SmallTextStyle(
        color: Colors.white,
        text: balance,
        fontSize: 18,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: ('Host Center').appTr,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBalance,
        color: kAppColor2,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: kHeight * 0.13,
                    ),

                    ///==========================
                    /// Income Balance Card
                    ///==========================
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: kWeight * 0.04,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: kHeight * 0.045,
                        horizontal: kWeight * 0.025,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            kAppColor2,
                            kAppColor1.withOpacity(.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          /// Receive Coin
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SmallTextStyle(
                                  color: Colors.white,
                                  text: ('Receive').appTr,
                                  fontSize: 15,
                                ),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration:
                                  const Duration(milliseconds: 180),
                                  child: SizedBox(
                                    key: ValueKey<String>(
                                      '$_isRefreshingBalance-$_hasFreshBalance',
                                    ),
                                    height: 28,
                                    child: Center(
                                      child: _buildReceiveBalance(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 1,
                            height: 48,
                            color: Colors.white.withOpacity(0.35),
                          ),

                          /// Dollar Balance
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SmallTextStyle(
                                  color: Colors.white,
                                  text: ('Estimated Earnings ').appTr,
                                  fontSize: 15,
                                ),
                                const SizedBox(height: 6),
                                // Obx(() {
                                //   final withdrawController =
                                //       Get.find<WithdrawController>();
                                //
                                //   if (withdrawController
                                //           .dollarSettingLoading.value &&
                                //       withdrawController
                                //           .dollarConversionSetting.isEmpty) {
                                //     return SmallTextStyle(
                                //       color: Colors.white,
                                //       text: ('Loading...').appTr,
                                //       fontSize: 18,
                                //     );
                                //   }
                                //
                                //   return Column(
                                //     children: [
                                //       SmallTextStyle(
                                //         color: Colors.white,
                                //         text: withdrawController.earnedDollar,
                                //         fontSize: 18,
                                //       ),
                                //       const SizedBox(height: 3),
                                //       Text(
                                //         withdrawController.dollarRateText,
                                //         maxLines: 1,
                                //         overflow: TextOverflow.ellipsis,
                                //         textAlign: TextAlign.center,
                                //         style: GoogleFonts.poppins(
                                //           fontSize: 8.5,
                                //           fontWeight: FontWeight.w500,
                                //           color:
                                //               Colors.white.withOpacity(0.82),
                                //         ),
                                //       ),
                                //     ],
                                //   );
                                // }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SetHeight(heightSet: 0.05),

                    gradientButton(
                      text: ('Payout Request').appTr,
                      onPressed: () {
                        if (_isRefreshingBalance || !_hasFreshBalance) {
                          _refreshBalance();
                          return;
                        }

                        Get.to(
                              () => WithdrawAccount(),
                          transition: Transition.rightToLeft,
                        )?.then((_) => _refreshBalance());
                      },
                    ),

                    SetHeight(heightSet: 0.02),

                    gradientButton(
                      text: 'Exchange'.appTr,
                      onPressed: () {
                        if (_isRefreshingBalance || !_hasFreshBalance) {
                          _refreshBalance();
                          return;
                        }

                        Get.to(
                              () => const ExchangeCoinView(),
                          transition: Transition.rightToLeft,
                        )?.then((_) => _refreshBalance());
                      },
                    ),

                    SetHeight(heightSet: 0.02),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        ('Withdrawal Instructions Anchor withdrawal instructions Background modification')
                            .appTr,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget gradientButton({
  required String text,
  required VoidCallback onPressed,
  double borderRadius = 12,
}) {
  return SizedBox(
    width: kWeight * 0.82,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              kAppColor1,
              kAppColor2,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: const Color(0xffade8f0).withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 24,
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
