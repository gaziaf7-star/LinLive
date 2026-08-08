import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/home/controllers/home_controller.dart';
import 'package:meetlivepro/app/modules/reseller/controllers/reseller_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WithdrawRequestList extends StatefulWidget {
  const WithdrawRequestList({super.key});

  @override
  State<WithdrawRequestList> createState() => _WithdrawRequestListState();
}

class _WithdrawRequestListState extends State<WithdrawRequestList> {
  final HomeController homeController = Get.put(HomeController());

  static const Color kAppColor1 = Color(0xFFF80230);
  static const Color kAppColor2 = Color(0xFFFD375D);
  static const Color kAppbarColor = Color(0xFFF43C5D);

  @override
  void initState() {
    super.initState();
    homeController.showWithdrawRequest();
  }

  Future<void> _confirmAction({
    required String title,
    required String message,
    required Color color,
    required VoidCallback onConfirm,
  }) async {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(.12),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          ('Cancel').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                        onConfirm();
                      },
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withOpacity(.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(.28),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Text(
                          ('Confirm').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeText(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) return fallback;
    final text = value.toString();
    if (text.trim().isEmpty || text == 'null') return fallback;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final double h = Get.height;
    final double w = Get.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(h * 0.068),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kAppColor1,
                kAppColor2,
                kAppbarColor,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    ('Withdraw Requests').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: h * 0.020,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    homeController.showWithdrawRequest();
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (homeController.withdrawRequestLoading.value) {
          return ListView.builder(
            padding: EdgeInsets.all(w * 0.04),
            itemCount: 6,
            itemBuilder: (_, __) => _loadingCard(),
          );
        }

        if (homeController.withdrawRequestList.isEmpty) {
          return RefreshIndicator(
            color: kAppColor2,
            onRefresh: () async {
              await homeController.showWithdrawRequest();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: h * 0.20),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: h * 0.070,
                  color: Colors.black26,
                ),
                SizedBox(height: h * 0.015),
                Text(
                  ('No withdraw request found').appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: h * 0.017,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: kAppColor2,
          onRefresh: () async {
            await homeController.showWithdrawRequest();
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.all(w * 0.04),
            itemCount: homeController.withdrawRequestList.length,
            itemBuilder: (context, index) {
              final item = homeController.withdrawRequestList[index];
              return _withdrawRequestCard(item);
            },
          ),
        );
      }),
    );
  }

  Widget _loadingCard() {
    return Container(
      height: Get.height * 0.17,
      margin: EdgeInsets.only(bottom: Get.height * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }

  Widget _withdrawRequestCard(dynamic item) {
    final int requestId = int.tryParse(item['id'].toString()) ?? 0;

    final String name = _safeText(
      item['user']?['name'] ?? item['sender']?['name'] ?? item['name'],
      fallback: ('Unknown User').appTr,
    );

    final String phone = _safeText(
      item['user']?['phone'] ?? item['sender']?['phone'] ?? item['phone'],
    );

    final String amount = _safeText(item['amount'], fallback: '0');
    final String methodName = _safeText(item['method_name'] ?? item['payment_method']?['method_name']);
    final String account = _safeText(item['method_account'] ?? item['payment_method']?['method_account']);
    final String receivedType = _safeText(item['received_type'], fallback: 'admin');
    final String status = _safeText(item['status'], fallback: ('Pending').appTr);

    return Obx(() {
      final bool acceptLoading =
      homeController.acceptLoadingIds.contains(requestId);
      final bool rejectLoading =
      homeController.rejectLoadingIds.contains(requestId);
      final bool anyLoading = acceptLoading || rejectLoading;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: Get.height * 0.016),
        padding: EdgeInsets.all(Get.width * 0.04),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFFFF3F6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: kAppColor2.withOpacity(.12),
          ),
          boxShadow: [
            BoxShadow(
              color: kAppColor2.withOpacity(.09),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: Get.height * 0.058,
                  width: Get.height * 0.058,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        kAppColor1,
                        kAppColor2,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kAppColor2.withOpacity(.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                SizedBox(width: Get.width * 0.035),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: Get.height * 0.017,
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: Get.height * 0.004),
                      Text(
                        ('Phone: $phone').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: Get.height * 0.0125,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),

            SizedBox(height: Get.height * 0.018),

            Container(
              padding: EdgeInsets.all(Get.width * 0.035),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.black.withOpacity(.04),
                ),
              ),
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.diamond_rounded,
                    title: ('Amount').appTr,
                    value: amount,
                    valueColor: kAppColor2,
                  ),
                  SizedBox(height: Get.height * 0.010),
                  _infoRow(
                    icon: Icons.account_balance_wallet_rounded,
                    title: ('Method').appTr,
                    value: methodName,
                  ),
                  SizedBox(height: Get.height * 0.010),
                  _infoRow(
                    icon: Icons.credit_card_rounded,
                    title: ('Account').appTr,
                    value: account,
                  ),
                  SizedBox(height: Get.height * 0.010),
                  _infoRow(
                    icon: Icons.swap_horiz_rounded,
                    title: ('Received Type').appTr,
                    value: receivedType,
                  ),
                ],
              ),
            ),

            SizedBox(height: Get.height * 0.018),

            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    title: ('Reject').appTr,
                    icon: Icons.close_rounded,
                    color: const Color(0xFFFF3B30),
                    loading: rejectLoading,
                    disable: anyLoading,
                    onTap: () {
                      _confirmAction(
                        title: ('Reject Request?').appTr,
                        message: ('Are you sure you want to reject this withdraw request?').appTr,
                        color: const Color(0xFFFF3B30),
                        onConfirm: () {
                          homeController.showWithdrawRequestReject(
                            ID: requestId,
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(width: Get.width * 0.03),
                Expanded(
                  child: _actionButton(
                    title: ('Accept').appTr,
                    icon: Icons.check_rounded,
                    color: const Color(0xFF00C853),
                    loading: acceptLoading,
                    disable: anyLoading,
                    onTap: () {
                      _confirmAction(
                        title: ('Accept Request?').appTr,
                        message: ('Are you sure you want to approve this withdraw request?').appTr,
                        color: const Color(0xFF00C853),
                        onConfirm: () {
                          homeController.showWithdrawRequestAccept(
                            ID: requestId,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _statusBadge(String status) {
    final bool pending = status.toLowerCase().contains('pending');
    final Color color = pending ? const Color(0xFFFF9800) : kAppColor2;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Get.width * 0.025,
        vertical: Get.height * 0.006,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: Get.height * 0.0115,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    Color valueColor = Colors.black87,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: Get.height * 0.019,
          color: kAppColor2,
        ),
        SizedBox(width: Get.width * 0.025),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: Get.height * 0.0125,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: Get.height * 0.013,
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool loading,
    required bool disable,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: disable ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disable && !loading ? .55 : 1,
        child: Container(
          height: Get.height * 0.048,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withOpacity(.75),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.25),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: loading
              ? SizedBox(
            height: Get.height * 0.020,
            width: Get.height * 0.020,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: Get.height * 0.020,
              ),
              SizedBox(width: Get.width * 0.015),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: Get.height * 0.0145,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}