import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../ExchangeCoin.dart';
import '../controllers/withdraw_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ExchangeCoinView extends GetView<WithdrawController> {
  const ExchangeCoinView({super.key});

  @override
  Widget build(BuildContext context) {
    final WithdrawController withdrawController = Get.put(WithdrawController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      withdrawController.exchangeSetting();
      withdrawController.exchangeHistory();
    });

    return Scaffold(
      backgroundColor: const Color(0xfff7f4ff),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          ('Exchange Coin').appTr,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xff7C45BC),
                Color(0xffcdaafc),
                Color(0xffade8f0),
              ],
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      body: Obx(
            () => RefreshIndicator(
          onRefresh: () async {
            await withdrawController.exchangeSetting();
            await withdrawController.exchangeHistory();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: kHeight * 0.03),
            child: Column(
              children: [
                _balanceHeader(withdrawController),
                SizedBox(height: kHeight * 0.018),
                _exchangeRateCard(withdrawController, context),
                SizedBox(height: kHeight * 0.018),
                _historySection(withdrawController),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _balanceHeader(WithdrawController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        kWeight * 0.05,
        kHeight * 0.025,
        kWeight * 0.05,
        kHeight * 0.030,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff7C45BC),
            Color(0xffcdaafc),
            Color(0xffade8f0),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ('Account Balance').appTr,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: Colors.white.withOpacity(0.90),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: kHeight * 0.016),
          Row(
            children: [
              Expanded(
                child: _smallBalanceBox(
                  title: ('Receive Coins').appTr,
                  value: controller.currentEarnedCoins.toString(),
                  icon: Icons.savings_rounded,
                ),
              ),
              SizedBox(width: kWeight * 0.030),
              Expanded(
                child: _smallBalanceBox(
                  title: ('Coins').appTr,
                  value: controller.currentCoins.toString(),
                  icon: Icons.monetization_on_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallBalanceBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * 0.030,
        vertical: kHeight * 0.014,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.22),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: kWeight * 0.025),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: kHeight * 0.004),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exchangeRateCard(
      WithdrawController controller,
      BuildContext context,
      ) {
    return Container(
      width: kWeight * 0.92,
      padding: EdgeInsets.all(kWeight * 0.045),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff7C45BC),
                      Color(0xffcdaafc),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.currency_exchange_rounded,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: kWeight * 0.030),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ('Exchange Rate').appTr,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      controller.exchangeRateText,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        color: const Color(0xff7C45BC),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: kHeight * 0.020),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(kWeight * 0.035),
            decoration: BoxDecoration(
              color: const Color(0xfff7f4ff),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffeadfff)),
            ),
            child: Text(
              ('Apni joto Receive Coins exchange korben, rate onujayi Coins paben.').appTr,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: kHeight * 0.025),
          SizedBox(
            width: double.infinity,
            height: kHeight * 0.056,
            child: ElevatedButton(
              onPressed: () => _showExchangeDialog(context, controller),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xff7C45BC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                ('Custom Exchange Amount').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExchangeDialog(
      BuildContext context,
      WithdrawController controller,
      ) {
    controller.updateExchangePreview(controller.exchangeAmount.text);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: kWeight * 0.055),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Obx(
                () => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: kHeight * 0.024),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xff7C45BC),
                          Color(0xffcdaafc),
                          Color(0xffade8f0),
                        ],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.currency_exchange_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        SizedBox(height: kHeight * 0.008),
                        Text(
                          ('Exchange Coins').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          controller.exchangeRateText,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.90),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(kWeight * 0.050),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogBalanceRow(
                          'Available Receive Coins',
                          controller.currentEarnedCoins.toString(),
                        ),
                        SizedBox(height: kHeight * 0.018),
                        Text(
                          ('Enter Receive Coin Amount').appTr,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: kHeight * 0.010),
                        ExchangeTextField(
                          controller: controller.exchangeAmount,
                          onChanged: controller.updateExchangePreview,
                        ),
                        SizedBox(height: kHeight * 0.018),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(kWeight * 0.035),
                          decoration: BoxDecoration(
                            color: const Color(0xfff7f4ff),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xffeadfff),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_circle_down_rounded,
                                color: Color(0xff7C45BC),
                              ),
                              SizedBox(width: kWeight * 0.025),
                              Expanded(
                                child: Text(
                                  ('You will receive').appTr,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                ('${controller.previewReceiveCoins.value} Coins').appTr,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: const Color(0xff7C45BC),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: kHeight * 0.025),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: controller.exchangeLoading.value
                                    ? null
                                    : () {
                                  Get.back();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xff7C45BC),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: kHeight * 0.014,
                                  ),
                                ),
                                child: Text(
                                  ('Cancel').appTr,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: kWeight * 0.030),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: controller.exchangeLoading.value
                                    ? null
                                    : () {
                                  controller.exchangeCoin();
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: const Color(0xff7C45BC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: kHeight * 0.014,
                                  ),
                                ),
                                child: controller.exchangeLoading.value
                                    ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : Text(
                                  ('Exchange').appTr,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dialogBalanceRow(String title, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kWeight * 0.035),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              color: Colors.grey.shade700),
          SizedBox(width: kWeight * 0.025),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection(WithdrawController controller) {
    return Container(
      width: kWeight * 0.92,
      padding: EdgeInsets.all(kWeight * 0.040),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                ('Exchange History').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  controller.exchangeHistory();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xff7C45BC),
                ),
              ),
            ],
          ),
          SizedBox(height: kHeight * 0.006),
          if (controller.exchangeHistoryLoading.value)
            Padding(
              padding: EdgeInsets.symmetric(vertical: kHeight * 0.030),
              child: const CircularProgressIndicator(
                color: Color(0xff7C45BC),
              ),
            )
          else if (controller.exchangeHistoryList.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: kHeight * 0.035),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 45,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: kHeight * 0.010),
                  Text(
                    ('No exchange history found').appTr,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.exchangeHistoryList.length,
              separatorBuilder: (_, __) => Divider(
                height: kHeight * 0.022,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (_, index) {
                final item = controller.exchangeHistoryList[index];

                if (item is! Map) {
                  return const SizedBox.shrink();
                }

                return _historyItem(Map<String, dynamic>.from(item));
              },
            ),
        ],
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> item) {
    final String exchangeAmount = item['exchange_amount']?.toString() ?? '0';
    final String receivedCoins = item['received_coins']?.toString() ?? '0';
    final String status = item['status']?.toString() ?? 'success';
    final String date = item['created_at']?.toString() ?? '';

    return Container(
      padding: EdgeInsets.all(kWeight * 0.025),
      decoration: BoxDecoration(
        color: const Color(0xfffbfaff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffeee6ff)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xff7C45BC).withOpacity(0.12),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Color(0xff7C45BC),
            ),
          ),
          SizedBox(width: kWeight * 0.030),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('$exchangeAmount Receive → $receivedCoins Coins').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: kHeight * 0.004),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * 0.025,
              vertical: kHeight * 0.005,
            ),
            decoration: BoxDecoration(
              color: status == 'success'
                  ? Colors.green.withOpacity(0.12)
                  : Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: status == 'success' ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}