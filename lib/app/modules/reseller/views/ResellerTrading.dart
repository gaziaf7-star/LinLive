import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/layout_constant.dart';
import '../../home/controllers/home_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WithdrawRequestList extends StatefulWidget {
  const WithdrawRequestList({super.key});

  @override
  State<WithdrawRequestList> createState() => _WithdrawRequestListState();
}

class _WithdrawRequestListState extends State<WithdrawRequestList>
    with SingleTickerProviderStateMixin {
  final HomeController homeController = Get.put(HomeController());

  late final TabController _tabController;

  static const Color kAppColor1 = Color(0xFFF80230);
  static const Color kAppColor2 = Color(0xFFFD375D);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeController.refreshWithdrawAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _safeText(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _normalizeStatus(dynamic value) {
    final status = value?.toString().toLowerCase().trim() ?? '';

    if (status == 'accept' ||
        status == 'accepted' ||
        status == 'approve' ||
        status == 'approved') {
      return 'Accepted';
    }

    if (status == 'reject' ||
        status == 'rejected' ||
        status == 'decline' ||
        status == 'declined') {
      return 'Rejected';
    }

    return ('Pending').appTr;
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();

    if (lower == 'accepted') return Colors.green;
    if (lower == 'rejected') return Colors.red;
    return Colors.orange;
  }

  Future<void> _confirmDialog({
    required String title,
    required String message,
    required Color color,
    required VoidCallback onConfirm,
  }) async {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: Get.width * 0.07),
        child: Container(
          padding: EdgeInsets.all(Get.width * 0.05),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.20),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: Get.height * 0.065,
                width: Get.height * 0.065,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(.70),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.35),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              SizedBox(height: Get.height * 0.018),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: Get.height * 0.020,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: Get.height * 0.008),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: Get.height * 0.014,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              SizedBox(height: Get.height * 0.025),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        height: Get.height * 0.052,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          ('Cancel').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontSize: Get.height * 0.0145,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Get.width * 0.03),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                        onConfirm();
                      },
                      child: Container(
                        height: Get.height * 0.052,
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
                              color: color.withOpacity(.30),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Text(
                          ('Confirm').appTr,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: Get.height * 0.0145,
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

  @override
  Widget build(BuildContext context) {
    final double h = Get.height;
    final double w = Get.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.fromLTRB(w * 0.04, h * 0.012, w * 0.04, 0),
              padding: EdgeInsets.all(w * 0.012),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.045),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      kAppColor1,
                      kAppColor2,
                    ],
                  ),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                labelStyle: GoogleFonts.poppins(
                  fontSize: h * 0.0135,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: h * 0.0135,
                  fontWeight: FontWeight.w600,
                ),
                tabs:  [
                  Tab(text: ('Withdraw Request').appTr),
                  Tab(text: ('Withdraw History').appTr),
                ],
              ),
            ),
            SizedBox(height: h * 0.012),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _requestTab(),
                  _historyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestTab() {
    return Obx(() {
      if (homeController.withdrawRequestLoading.value) {
        return _loadingList();
      }

      if (homeController.withdrawRequestList.isEmpty) {
        return _emptyView(
          icon: Icons.account_balance_wallet_outlined,
          title: ('No withdraw request found').appTr,
          subtitle: ('Pull down to refresh request list').appTr,
          onRefresh: homeController.showWithdrawRequest,
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
          padding: EdgeInsets.all(Get.width * 0.04),
          itemCount: homeController.withdrawRequestList.length,
          itemBuilder: (context, index) {
            final item = homeController.withdrawRequestList[index];
            return _withdrawCard(
              item: item,
              showActionButtons: true,
            );
          },
        ),
      );
    });
  }

  Widget _historyTab() {
    return Obx(() {
      if (homeController.withdrawHistoryLoading.value) {
        return _loadingList();
      }

      if (homeController.withdrawHistoryList.isEmpty) {
        return _emptyView(
          icon: Icons.history_rounded,
          title: ('No withdraw history found').appTr,
          subtitle: ('Accepted and rejected requests will show here').appTr,
          onRefresh: homeController.showWithdrawHistory,
        );
      }

      return RefreshIndicator(
        color: kAppColor2,
        onRefresh: () async {
          await homeController.showWithdrawHistory();
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.all(Get.width * 0.04),
          itemCount: homeController.withdrawHistoryList.length,
          itemBuilder: (context, index) {
            final item = homeController.withdrawHistoryList[index];
            return _withdrawCard(
              item: item,
              showActionButtons: false,
            );
          },
        ),
      );
    });
  }

  Widget _loadingList() {
    return ListView.builder(
      padding: EdgeInsets.all(Get.width * 0.04),
      itemCount: 6,
      itemBuilder: (context, index) => _loadingCard(),
    );
  }

  Widget _emptyView({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      color: kAppColor2,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: Get.height * 0.22),
          Icon(
            icon,
            size: Get.height * 0.075,
            color: Colors.black26,
          ),
          SizedBox(height: Get.height * 0.015),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: Get.height * 0.017,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Get.height * 0.006),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: Get.height * 0.0125,
              color: Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: Get.height * 0.22,
        margin: EdgeInsets.only(bottom: Get.height * 0.016),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _withdrawCard({
    required dynamic item,
    required bool showActionButtons,
  }) {
    final itemMap = _safeMap(item);
    final int requestId = _safeInt(itemMap['id']);

    final Map<String, dynamic> user = _safeMap(itemMap['user']);

    final String name = _safeText(user['name'], fallback: ('Unknown').appTr);
    final String phone = _safeText(user['phone']);
    final String profileImage = _safeText(user['profile_image'], fallback: '');

    final int coins = _safeInt(user['coins']);
    final String method = _safeText(
      itemMap['method'] ?? itemMap['method_name'] ?? itemMap['withdraw_method'],
    );
    final String number = _safeText(
      itemMap['number'] ??
          itemMap['method_account'] ??
          itemMap['account_number'],
    );
    final String receivedType = _safeText(itemMap['received_type']);
    final String status = _normalizeStatus(
      itemMap['action_status'] ?? itemMap['status'],
    );
    final String createdAt = _safeText(
      itemMap['date'] ?? itemMap['created_at'] ?? itemMap['updated_at'],
    );
    final int amount = _safeInt(
      itemMap['amount'] ??
          itemMap['withdraw_amount'] ??
          itemMap['recharge_amount'] ??
          itemMap['coins'],
    );

    final Color statusColor = _statusColor(status);

    return Obx(() {
      final bool acceptLoading = homeController.acceptLoadingIds.contains(requestId);
      final bool rejectLoading = homeController.rejectLoadingIds.contains(requestId);
      final bool anyLoading = acceptLoading || rejectLoading;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: Get.height * 0.018),
        padding: EdgeInsets.all(Get.width * 0.04),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(showActionButtons ? 0.06 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
          border: Border.all(
            color: showActionButtons
                ? kAppColor2.withOpacity(.12)
                : statusColor.withOpacity(.22),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _profileAvatar(profileImage),
                SizedBox(width: Get.width * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: Get.height * 0.018,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: Get.height * 0.003),
                      Text(
                        ('Phone: $phone').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: Get.height * 0.0128,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: Get.height * 0.003),
                      Text(
                        ('Balance: $coins').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: Get.height * 0.0128,
                          fontWeight: FontWeight.w700,
                          color: kAppColor2,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),

            SizedBox(height: Get.height * 0.015),
            Divider(color: Colors.grey.shade200),
            SizedBox(height: Get.height * 0.012),

            Row(
              children: [
                Expanded(
                  child: _infoBox(
                    title: ('Amount').appTr,
                    value: amount > 0 ? '$amount' : 'N/A',
                    icon: Icons.monetization_on_rounded,
                  ),
                ),
                SizedBox(width: Get.width * 0.025),
                Expanded(
                  child: _infoBox(
                    title: ('Type').appTr,
                    value: receivedType,
                    icon: Icons.category_rounded,
                  ),
                ),
              ],
            ),

            SizedBox(height: Get.height * 0.010),

            Row(
              children: [
                Expanded(
                  child: _infoBox(
                    title: ('Method').appTr,
                    value: method,
                    icon: Icons.account_balance_rounded,
                  ),
                ),
                SizedBox(width: Get.width * 0.025),
                Expanded(
                  child: _infoBox(
                    title: ('Number').appTr,
                    value: number,
                    icon: Icons.numbers_rounded,
                  ),
                ),
              ],
            ),

            SizedBox(height: Get.height * 0.010),

            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: Get.height * 0.016,
                  color: Colors.black38,
                ),
                SizedBox(width: Get.width * 0.014),
                Expanded(
                  child: Text(
                    createdAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: Get.height * 0.012,
                      fontWeight: FontWeight.w500,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),

            if (showActionButtons) ...[
              SizedBox(height: Get.height * 0.016),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: rejectLoading
                          ? SizedBox(
                        height: Get.height * 0.018,
                        width: Get.height * 0.018,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.close_rounded),
                      label: Text(
                        ('Reject').appTr,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: anyLoading
                          ? null
                          : () {
                        _confirmDialog(
                          title: ('Reject Request?').appTr,
                          message: ('Are you sure you want to reject this withdraw request?').appTr,
                          color: Colors.red,
                          onConfirm: () {
                            homeController.showWithdrawRequestReject(
                              ID: requestId,
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: Get.height * 0.014,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Get.width * 0.03),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: acceptLoading
                          ? SizedBox(
                        height: Get.height * 0.018,
                        width: Get.height * 0.018,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        ('Accept').appTr,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: anyLoading
                          ? null
                          : () {
                        _confirmDialog(
                          title: ('Accept Request?').appTr,
                          message: ('Are you sure you want to accept this withdraw request?').appTr,
                          color: Colors.green,
                          onConfirm: () {
                            homeController.showWithdrawRequestAccept(
                              ID: requestId,
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: Get.height * 0.014,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _profileAvatar(String imageUrl) {
    return Container(
      height: Get.height * 0.070,
      width: Get.height * 0.070,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: kAppColor2.withOpacity(.25),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _avatarFallback(),
          errorWidget: (_, __, ___) => _avatarFallback(),
        )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person_rounded,
        color: kAppColor2,
        size: Get.height * 0.034,
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Get.width * 0.030,
        vertical: Get.height * 0.0055,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: Get.height * 0.0118,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Get.width * 0.030,
        vertical: Get.height * 0.010,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: Get.height * 0.020,
            color: kAppColor2,
          ),
          SizedBox(width: Get.width * 0.018),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: Get.height * 0.0108,
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                  ),
                ),
                SizedBox(height: Get.height * 0.002),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: Get.height * 0.013,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}