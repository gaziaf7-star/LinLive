import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/layout_constant.dart';
import '../controllers/trading_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Tradingsend extends StatelessWidget {
  const Tradingsend({super.key});

  @override
  Widget build(BuildContext context) {
    final TradingController tradingController = Get.put(TradingController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tradingController.showTradingList();
    });

    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => tradingController.showTradingList(),
          child: Obx(() {
            if (tradingController.rechargeHistoryLoading.value &&
                tradingController.tradingListData.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                children: [
                  _summaryShimmer(),
                  const SizedBox(height: 14),
                  ...List.generate(6, (index) => _historyShimmer()),
                ],
              );
            }

            if (tradingController.tradingListData.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: kHeight * 0.22),
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 70,
                    color: Colors.grey.withOpacity(0.55),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ('No recharge history available!').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ('Pull down to refresh').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.black.withOpacity(0.42),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              children: [
                _summaryCard(tradingController),
                const SizedBox(height: 14),
                Text(
                  ('Recharge History').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.018,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff202124),
                  ),
                ),
                const SizedBox(height: 10),
                ...List.generate(
                  tradingController.tradingListData.length,
                      (index) {
                    final item = tradingController.tradingListData[index];

                    return _historyCard(
                      controller: tradingController,
                      item: item,
                      index: index,
                    );
                  },
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _summaryCard(TradingController controller) {
    final totalCount = controller.toInt(
      controller.rechargeSummary['total_recharge_count'],
    );

    final totalAmount = controller.toInt(
      controller.rechargeSummary['total_recharge_amount'],
    );

    final sellerBalance = controller.toInt(
      controller.rechargeSummary['current_seller_balance'],
    );

    return Container(
      padding: EdgeInsets.all(kHeight * 0.017),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
         kAppColor2,kAppColor1
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kAppColor2.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ('Recharge Summary').appTr,
            style: GoogleFonts.poppins(
              fontSize: kHeight * 0.018,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  title: ('Total Count').appTr,
                  value: '$totalCount',
                  icon: Icons.confirmation_number_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryItem(
                  title: ('Total Amount').appTr,
                  value: '$totalAmount',
                  icon: Icons.monetization_on_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sellerBalanceBox(sellerBalance),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kHeight * 0.012,
        vertical: kHeight * 0.012,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: kHeight * 0.025,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.017,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.011,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerBalanceBox(int balance) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kHeight * 0.014,
        vertical: kHeight * 0.012,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: kHeight * 0.026,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            ('Current Seller Balance').appTr,
            style: GoogleFonts.poppins(
              fontSize: kHeight * 0.0125,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.86),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              '$balance',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: kHeight * 0.016,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard({
    required TradingController controller,
    required dynamic item,
    required int index,
  }) {
    final receiver =
    item is Map && item['receiver'] is Map ? item['receiver'] : {};

    final receiverName = controller.safeText(receiver['name']);
    final receiverUserId = controller.safeText(receiver['user_id']);
    final receiverPhone = controller.safeText(receiver['phone']);
    final receiverImage = controller.safeText(receiver['profile_image'], fallback: '');
    final rechargeAmount = controller.toInt(item['recharge_amount']);
    final date = controller.safeText(item['date']);
    final receiverCoins = controller.toInt(receiver['coins']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(kHeight * 0.014),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffEDEEF4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileImage(receiverImage, index),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        receiverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: kHeight * 0.016,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff202124),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        _amountBadge(rechargeAmount),

                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _infoRow(
                  icon: Icons.badge_rounded,
                  text: ('UID: $receiverUserId').appTr,
                ),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.phone_android_rounded,
                  text: ('Phone: $receiverPhone').appTr,
                ),
                const SizedBox(height: 4),
                _infoRow(
                  icon: Icons.access_time_rounded,
                  text: date,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileImage(String imageUrl, int index) {
    return Stack(
      children: [
        Container(
          width: kHeight * 0.058,
          height: kHeight * 0.058,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: kAppColor2.withOpacity(0.35),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultAvatar(),
            )
                : _defaultAvatar(),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kAppColor2,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '${index + 1}',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xffEEE8FF),
      child: const Icon(
        Icons.person_rounded,
        color: kAppColor2,
      ),
    );
  }

  Widget _amountBadge(int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kAppColor2.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '+$amount',
        style: GoogleFonts.poppins(
          fontSize: kHeight * 0.013,
          fontWeight: FontWeight.w700,
          color: kAppColor2,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: kHeight * 0.0155,
          color: Colors.black.withOpacity(0.45),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: kHeight * 0.0118,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.56),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _historyShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(kHeight * 0.014),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Row(
          children: [
            Container(
              width: kHeight * 0.058,
              height: kHeight * 0.058,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}