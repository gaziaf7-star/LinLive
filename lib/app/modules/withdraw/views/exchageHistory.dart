import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';
import '../controllers/withdraw_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ExchangeHistoryPage extends GetView<WithdrawController> {
  const ExchangeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final WithdrawController controller = Get.find<WithdrawController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.exchangeHistory();
    });

    return Scaffold(
      backgroundColor: const Color(0xfff7f4ff),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          ('Exchange History').appTr,
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
        actions: [
          IconButton(
            onPressed: () {
              controller.exchangeHistory();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Obx(
            () => RefreshIndicator(
          onRefresh: () async {
            await controller.exchangeHistory();
          },
          child: controller.exchangeHistoryLoading.value
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: kHeight * 0.35),
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff7C45BC),
                ),
              ),
            ],
          )
              : controller.exchangeHistoryList.isEmpty
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * 0.06,
            ),
            children: [
              SizedBox(height: kHeight * 0.25),
              Icon(
                Icons.history_rounded,
                size: 70,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: kHeight * 0.018),
              Text(
                ('No exchange history found').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: kHeight * 0.008),
              Text(
                ('Apnar exchange history ekhane show hobe.').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
              : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(kWeight * 0.045),
            itemCount: controller.exchangeHistoryList.length,
            separatorBuilder: (_, __) =>
                SizedBox(height: kHeight * 0.014),
            itemBuilder: (_, index) {
              final item = controller.exchangeHistoryList[index];

              if (item is! Map) {
                return const SizedBox.shrink();
              }

              return _historyCard(Map<String, dynamic>.from(item));
            },
          ),
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final String exchangeAmount = item['exchange_amount']?.toString() ?? '0';
    final String receivedCoins = item['received_coins']?.toString() ?? '0';
    final String beforeEarned =
        item['before_earned_coins']?.toString() ?? '0';
    final String afterEarned = item['after_earned_coins']?.toString() ?? '0';
    final String beforeCoins = item['before_coins']?.toString() ?? '0';
    final String afterCoins = item['after_coins']?.toString() ?? '0';
    final String status = item['status']?.toString() ?? 'success';
    final String note = item['note']?.toString() ?? '';
    final String date = item['created_at']?.toString() ?? '';

    final bool isSuccess = status.toLowerCase() == 'success';

    return Container(
      padding: EdgeInsets.all(kWeight * 0.040),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffeee6ff)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xff7C45BC).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xff7C45BC),
                  size: 28,
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
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kWeight * 0.028,
                  vertical: kHeight * 0.006,
                ),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: isSuccess ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: kHeight * 0.016),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(kWeight * 0.035),
            decoration: BoxDecoration(
              color: const Color(0xfff7f4ff),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffeadfff)),
            ),
            child: Column(
              children: [
                _infoRow(
                  title: ('Receive Coins').appTr,
                  before: beforeEarned,
                  after: afterEarned,
                ),
                SizedBox(height: kHeight * 0.010),
                _infoRow(
                  title: ('Coins').appTr,
                  before: beforeCoins,
                  after: afterCoins,
                ),
              ],
            ),
          ),

          if (note.isNotEmpty) ...[
            SizedBox(height: kHeight * 0.012),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: kWeight * 0.018),
                Expanded(
                  child: Text(
                    note,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String before,
    required String after,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          before,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: Color(0xff7C45BC),
          ),
        ),
        Text(
          after,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xff7C45BC),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}