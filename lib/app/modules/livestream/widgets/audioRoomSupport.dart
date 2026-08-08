import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/layout_constant.dart';
import '../controllers/room_support_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class RoomSupportWeeklySheet extends StatefulWidget {
  const RoomSupportWeeklySheet({
    super.key,
    required this.livestreamId,
    required this.controllerTag,
  });

  final int livestreamId;
  final String controllerTag;

  static Future<void> show({required int livestreamId}) async {
    if (livestreamId <= 0) return;

    final String tag = 'room_support_$livestreamId';

    if (Get.isRegistered<RoomSupportController>(tag: tag)) {
      await Get.delete<RoomSupportController>(tag: tag, force: true);
    }

    Get.put<RoomSupportController>(
      RoomSupportController(livestreamId: livestreamId),
      tag: tag,
    );

    try {
      await Get.bottomSheet<void>(
        RoomSupportWeeklySheet(
          livestreamId: livestreamId,
          controllerTag: tag,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(.54),
        enterBottomSheetDuration: const Duration(milliseconds: 220),
        exitBottomSheetDuration: const Duration(milliseconds: 160),
      );
    } finally {
      if (Get.isRegistered<RoomSupportController>(tag: tag)) {
        await Get.delete<RoomSupportController>(tag: tag, force: true);
      }
    }
  }

  @override
  State<RoomSupportWeeklySheet> createState() =>
      _RoomSupportWeeklySheetState();
}

class _RoomSupportWeeklySheetState extends State<RoomSupportWeeklySheet>
    with SingleTickerProviderStateMixin {
  static const String _backgroundAsset =
      'assets/audio_live/roomsupportbg.png';
  static const String _walletAsset =
      'assets/audio_live/roomSupprtWallet.png';
  static const String _giftAsset =
      'assets/audio_live/roomSupportGift.png';

  late final TabController _tabController;

  RoomSupportController get controller =>
      Get.find<RoomSupportController>(tag: widget.controllerTag);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: kHeight * .94,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xff043f36),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _background()),
              Column(
                children: <Widget>[
                  _topHandle(),
                  _topNavigation(),
                  Expanded(
                    child: Obx(() {
                      if (controller.loading.value && controller.data.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xffffd95c),
                          ),
                        );
                      }

                      if (controller.error.value.isNotEmpty &&
                          controller.data.isEmpty) {
                        return _errorView();
                      }

                      return TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: <Widget>[
                          _roomSupportTab(),
                          _rankingTab(),
                        ],
                      );
                    }),
                  ),
                ],
              ),
              Obx(() {
                if (!controller.silentLoading.value ||
                    controller.data.isEmpty) {
                  return const SizedBox.shrink();
                }
                return const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xffffd95c),
                    backgroundColor: Colors.transparent,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _background() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          _backgroundAsset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xff07554d),
                    Color(0xff06463c),
                    Color(0xff022d28),
                  ],
                ),
              ),
            );
          },
        ),
        Container(color: const Color(0xff003d35).withOpacity(.52)),
      ],
    );
  }

  Widget _topHandle() {
    return Padding(
      padding: EdgeInsets.only(top: kHeight * .010),
      child: Container(
        width: 46,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.36),
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }

  Widget _topNavigation() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 390;
        final double navHeight = compact ? kHeight * .070 : kHeight * .078;

        return SizedBox(
          height: navHeight,
          child: Row(
            children: <Widget>[
              SizedBox(width: compact ? kWeight * .016 : kWeight * .026),
              _roundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Get.back(),
              ),
              SizedBox(width: compact ? kWeight * .014 : kWeight * .022),
              Expanded(
                child: Container(
                  height: compact ? kHeight * .050 : kHeight * .056,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xff063f3b).withOpacity(.96),
                        const Color(0xff022e2b).withOpacity(.96),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xffffd96a).withOpacity(.26),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(.30),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                      BoxShadow(
                        color: const Color(0xff2ee4cf).withOpacity(.09),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() {}),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.zero,
                    splashBorderRadius: BorderRadius.circular(999),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xff9affee),
                          Color(0xff42dbc7),
                          Color(0xff18a897),
                        ],
                      ),
                      border: Border.all(color: Colors.white70),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xff35dec8).withOpacity(.40),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(.30),
                          blurRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    labelColor: const Color(0xff063f38),
                    unselectedLabelColor: Colors.white60,
                    tabs: <Widget>[
                      _responsiveTabLabel(
                        icon: Icons.support_agent_rounded,
                        text: ('Room Support').appTr,
                        compact: compact,
                      ),
                      _responsiveTabLabel(
                        icon: Icons.emoji_events_rounded,
                        text: ('Ranking').appTr,
                        compact: compact,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: compact ? kWeight * .016 : kWeight * .026),
            ],
          ),
        );
      },
    );
  }

  Widget _responsiveTabLabel({
    required IconData icon,
    required String text,
    required bool compact,
  }) {
    return Tab(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: compact ? 16 : 18),
              SizedBox(width: compact ? 5 : 7),
              Text(
                text,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: kHeight * .048,
          height: kHeight * .048,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(.14),
            border: Border.all(color: Colors.white.withOpacity(.34)),
          ),
          child: Icon(icon, color: Colors.white, size: kHeight * .030),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(kHeight * .025),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              color: const Color(0xffffd95c),
              size: kHeight * .052,
            ),
            SizedBox(height: kHeight * .012),
            Text(
              controller.error.value,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight * .015,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: kHeight * .016),
            ElevatedButton.icon(
              onPressed: controller.load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(('Retry').appTr),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffffd95c),
                foregroundColor: const Color(0xff064238),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomSupportTab() {
    return RefreshIndicator(
      onRefresh: controller.load,
      color: const Color(0xff06735f),
      backgroundColor: const Color(0xffffe6a5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          kWeight * .024,
          kHeight * .004,
          kWeight * .024,
          kHeight * .030,
        ),
        child: Column(
          children: <Widget>[
            _countdownAndPartnerSection(),
            SizedBox(height: kHeight * .014),
            _currentProgressCard(),
            SizedBox(height: kHeight * .014),
            _targetRewardTable(),
            SizedBox(height: kHeight * .014),
            _rulesSection(),
            SizedBox(height: kHeight * .014),
            _weeklySalarySection(),
            SizedBox(height: kHeight * .014),
            _rewardHistorySection(),
            SizedBox(height: kHeight * .012),
            _partnerPoolNote(),
          ],
        ),
      ),
    );
  }

  Widget _countdownAndPartnerSection() {
    final List<Map<String, dynamic>> partners = controller.partners;
    final bool showAddCard =
        controller.canManagePartners && partners.length < RoomSupportController.maxPartners;
    final int itemCount = partners.length + (showAddCard ? 1 : 0);

    return _outlinedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * .028,
              vertical: kHeight * .010,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xffffe7a1),
                  Color(0xffffc94c),
                  Color(0xffffe7a1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(.28),
                  blurRadius: 9,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: const Color(0xffffd95c).withOpacity(.18),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  color: const Color(0xff07574b),
                  size: kHeight * .024,
                ),
                SizedBox(width: kWeight * .014),
                Text(
                  ('COUNTDOWN').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff07574b),
                    fontSize: kHeight * .017,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Obx(() {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: kWeight * .024,
                      vertical: kHeight * .006,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffff5a12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      controller.countdownText,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: kHeight * .015,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: kHeight * .010),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kWeight * .010),
            child: Text(
              'Room Partners for the previous week can be added from Monday 00:00 to Tuesday 24:00 (UTC +5:30), and rewards are sent every Monday.',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(.90),
                fontSize: kHeight * .0123,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: kHeight * .012),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  ('Room Partners').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xffffe578),
                    fontSize: kHeight * .0155,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${partners.length}/${RoomSupportController.maxPartners}',
                style: GoogleFonts.poppins(
                  color: const Color(0xffffe578),
                  fontSize: kHeight * .014,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: kHeight * .008),
          if (itemCount == 0)
            _emptyPartnerMessage()
          else
            SizedBox(
              height: kHeight * .128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: itemCount,
                separatorBuilder: (_, __) => SizedBox(width: kWeight * .018),
                itemBuilder: (BuildContext context, int index) {
                  if (index < partners.length) {
                    return _partnerSlot(partners[index], index: index);
                  }
                  return _addPartnerSlot();
                },
              ),
            ),
          if (!controller.canManagePartners) ...<Widget>[
            SizedBox(height: kHeight * .008),
            Row(
              children: <Widget>[
                Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white54,
                  size: kHeight * .016,
                ),
                SizedBox(width: kWeight * .010),
                Expanded(
                  child: Text(
                    'Only the host or this room admin can add and remove partners.',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: kHeight * .0108,
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

  Widget _emptyPartnerMessage() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: kHeight * .018),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Text(
        ('No partner added yet').appTr,
        style: GoogleFonts.poppins(
          color: Colors.white60,
          fontSize: kHeight * .013,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _partnerSlot(Map<String, dynamic> item, {required int index}) {
    final String name = controller.partnerName(item);
    final String image = controller.partnerImage(item);
    final int supportPartnerId = controller.supportPartnerIdOf(item);

    return Container(
      width: kWeight * .235,
      padding: EdgeInsets.fromLTRB(
        kWeight * .014,
        kHeight * .010,
        kWeight * .014,
        kHeight * .008,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xff0d7d6f),
            Color(0xff07594f),
            Color(0xff033f39),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffffd96a).withOpacity(.58),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xff2ee4cf).withOpacity(.10),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _avatar(image, size: kHeight * .058),
              SizedBox(height: kHeight * .006),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: kHeight * .0118,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'ID: ${controller.partnerPublicId(item)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: kHeight * .0092,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              height: kHeight * .020,
              width: kHeight * .020,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xffffd95c),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                  color: const Color(0xff06443c),
                  fontSize: kHeight * .0095,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (controller.canManagePartners)
            Positioned(
              right: -4,
              top: -4,
              child: Obx(() {
                final bool removing = controller.partnerActionLoading.value &&
                    controller.removingSupportPartnerId.value > 0 &&
                    controller.removingSupportPartnerId.value == supportPartnerId;
                return InkWell(
                  onTap: controller.partnerActionLoading.value
                      ? null
                      : () => _confirmRemovePartner(item),
                  customBorder: const CircleBorder(),
                  child: Container(
                    height: kHeight * .027,
                    width: kHeight * .027,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(.50)),
                    ),
                    child: removing
                        ? SizedBox(
                      height: kHeight * .012,
                      width: kHeight * .012,
                      child: const CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: kHeight * .016,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _addPartnerSlot() {
    return Obx(() {
      final bool enabled = controller.canAddPartner;
      final String label = controller.partnerLimitReached
          ? 'Full'
          : controller.backendPartnerWindowOpen
          ? 'Add'
          : 'Closed';

      return Opacity(
        opacity: enabled ? 1 : .56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? _openAddPartnerDialog : null,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: kWeight * .205,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xff118d7d).withOpacity(.90),
                    const Color(0xff07594f).withOpacity(.88),
                    const Color(0xff033f39).withOpacity(.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xffffd96a).withOpacity(.56),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(.26),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xffffd95c).withOpacity(.08),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    height: kHeight * .058,
                    width: kHeight * .058,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xff21b7a4),
                          Color(0xff0c8173),
                          Color(0xff055d54),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(.66)),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(.32),
                          blurRadius: 7,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: const Color(0xff2ee4cf).withOpacity(.24),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: controller.partnerActionLoading.value
                        ? Padding(
                      padding: EdgeInsets.all(kHeight * .018),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      Icons.add_rounded,
                      color: const Color(0xffffdd72),
                      size: kHeight * .038,
                    ),
                  ),
                  SizedBox(height: kHeight * .006),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: const Color(0xffffdd72),
                      fontSize: kHeight * .013,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _openAddPartnerDialog() async {
    if (!controller.canAddPartner || !mounted) return;

    final String? rawValue = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return const _AddRoomPartnerDialog();
      },
    );

    if (!mounted || rawValue == null) return;

    final int partnerId = int.tryParse(rawValue.trim()) ?? 0;
    final RoomSupportActionResult result =
    await controller.addPartner(partnerId);

    if (!mounted) return;
    _showActionResult(result);
  }

  Future<void> _confirmRemovePartner(Map<String, dynamic> item) async {
    final String name = controller.partnerName(item);
    final bool? confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(('Remove Partner').appTr),
        content: Text('Remove $name from this week Room Support partners?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(('Cancel').appTr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              ('Remove').appTr,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final RoomSupportActionResult result =
    await controller.removePartner(item);
    _showActionResult(result);
  }

  void _showActionResult(RoomSupportActionResult result) {
    Get.snackbar(
      result.success ? ('Success').appTr : ('Failed').appTr,
      result.message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor:
      result.success ? const Color(0xff08775e) : Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }

  Widget _currentProgressCard() {
    final Map<String, dynamic> current = controller.current;
    final Map<String, dynamic> currentLevel = controller.map(current['current_level']);
    final int level = currentLevel.isNotEmpty
        ? controller.safeInt(currentLevel['level_no'])
        : controller.safeInt(current['current_level']);
    final int visitors = controller.safeInt(
      current['room_visitors'] ?? current['visitors'],
    );
    final int roomCoins = controller.safeInt(current['room_coins']);
    final int reward = controller.safeInt(
      controller.rewardPreview['total_reward'] ??
          controller.rewardPreview['owner_reward'],
    );

    return _outlinedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('MY ROOM PROGRESS'),
          SizedBox(height: kHeight * .012),
          Row(
            children: <Widget>[
              _metricCard('Level', '$level', Icons.workspace_premium_rounded),
              SizedBox(width: kWeight * .014),
              _metricCard('Visitors', '$visitors', Icons.groups_rounded),
              SizedBox(width: kWeight * .014),
              _metricCard('Room Coins', _formatCoins(roomCoins), Icons.monetization_on_rounded),
              SizedBox(width: kWeight * .014),
              _metricCard('Reward', _formatCoins(reward), Icons.card_giftcard_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * .010,
          vertical: kHeight * .012,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: const Color(0xffffd95c), size: kHeight * .022),
            SizedBox(height: kHeight * .005),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight * .012,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: kHeight * .0089,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetRewardTable() {
    final List<Map<String, dynamic>> rows = controller.targetLevels;
    final Map<String, int> totals = controller.targetGrandTotal;

    return _outlinedPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.symmetric(vertical: kHeight * .010),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xffffe5a0),
                  Color(0xffffc94c),
                  Color(0xffffe5a0),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                'TARGET & REWARD TABLE (LEVEL 1 TO 10)',
                style: GoogleFonts.poppins(
                  color: const Color(0xff084a41),
                  fontSize: kHeight * .014,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: kWeight * 2.16,
              child: Column(
                children: <Widget>[
                  _targetTableRow(
                    <String>[
                      'Level',
                      'Room\nVisitors',
                      'Room Coin\nTarget',
                      'Total Reward\n(15%)',
                      'Owner Reward\n(10%)',
                      'Partner Pool\n(5%)',
                      'Number of\nPartners',
                      'Reward Per\nPartner',
                    ],
                    header: true,
                  ),
                  ...rows.map((Map<String, dynamic> row) {
                    return _targetTableRow(<String>[
                      '${row['level_no']}',
                      '${row['room_visitors']}',
                      _formatFullNumber(row['room_coin_target']),
                      _formatFullNumber(row['total_reward']),
                      _formatFullNumber(row['owner_reward']),
                      _formatFullNumber(row['partner_pool']),
                      '${row['number_of_partners']}',
                      _formatFullNumber(row['reward_per_partner']),
                    ]);
                  }),
                  _targetTableRow(
                    <String>[
                      'GRAND TOTAL',
                      '${totals['visitors']}',
                      _formatFullNumber(totals['room_coins']),
                      _formatFullNumber(totals['total_reward']),
                      _formatFullNumber(totals['owner_reward']),
                      _formatFullNumber(totals['partner_pool']),
                      '${totals['partners']}',
                      _formatFullNumber(totals['reward_per_partner']),
                    ],
                    total: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetTableRow(
      List<String> items, {
        bool header = false,
        bool total = false,
      }) {
    const List<IconData> headerIcons = <IconData>[
      Icons.workspace_premium_rounded,
      Icons.groups_rounded,
      Icons.monetization_on_rounded,
      Icons.card_giftcard_rounded,
      Icons.military_tech_rounded,
      Icons.diversity_3_rounded,
      Icons.group_add_rounded,
      Icons.emoji_events_rounded,
    ];

    return Container(
      height: header ? kHeight * .092 : kHeight * .054,
      decoration: BoxDecoration(
        gradient: total
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xfffff0b0),
            Color(0xffffc749),
            Color(0xffe5a928),
          ],
        )
            : header
            ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xff0b7467).withOpacity(.96),
            const Color(0xff064e46).withOpacity(.96),
          ],
        )
            : null,
        boxShadow: total
            ? <BoxShadow>[
          BoxShadow(
            color: const Color(0xffffcf55).withOpacity(.24),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ]
            : null,
        border: Border(
          bottom: BorderSide(
            color: total
                ? const Color(0xff8b6415)
                : Colors.white.withOpacity(.16),
          ),
        ),
      ),
      child: Row(
        children: List<Widget>.generate(items.length, (int index) {
          return Expanded(
            flex: index == 0 ? 8 : index == 1 ? 10 : 14,
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: kWeight * .006),
              decoration: BoxDecoration(
                border: Border(
                  right: index == items.length - 1
                      ? BorderSide.none
                      : BorderSide(
                    color: total
                        ? const Color(0xffa5791e)
                        : Colors.white.withOpacity(.15),
                  ),
                ),
              ),
              child: header
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _premium3DIcon(
                    headerIcons[index],
                    size: kHeight * .027,
                    iconSize: kHeight * .015,
                  ),
                  SizedBox(height: kHeight * .004),
                  Text(
                    items[index],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xffffe27c),
                      fontSize: kHeight * .0098,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                ],
              )
                  : index == 0 && !total
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: const Color(0xffffd95c),
                    size: kHeight * .014,
                  ),
                  SizedBox(width: kWeight * .005),
                  Text(
                    items[index],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: kHeight * .0109,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              )
                  : Text(
                items[index],
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: total
                      ? const Color(0xff084a41)
                      : (index >= 3 && index <= 5)
                      ? const Color(0xffffdd6c)
                      : Colors.white,
                  fontSize:
                  total ? kHeight * .0107 : kHeight * .0109,
                  fontWeight:
                  total ? FontWeight.w900 : FontWeight.w600,
                  height: 1.14,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _premium3DIcon(
      IconData icon, {
        required double size,
        required double iconSize,
      }) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xfffff3b0),
            Color(0xffffcf4f),
            Color(0xffd89614),
          ],
        ),
        border: Border.all(color: Colors.white70, width: .7),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.34),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xffffdc69).withOpacity(.35),
            blurRadius: 7,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xff0a5a4f), size: iconSize),
    );
  }

  Widget _rulesSection() {
    final List<String> rules = controller.displayRules;

    return _outlinedPanel(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _goldLine()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kWeight * .022),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _premium3DIcon(
                      Icons.gavel_rounded,
                      size: kHeight * .036,
                      iconSize: kHeight * .020,
                    ),
                    SizedBox(width: kWeight * .014),
                    Text(
                      ('RULES').appTr,
                      style: GoogleFonts.poppins(
                        color: const Color(0xffffd95c),
                        fontSize: kHeight * .020,
                        fontWeight: FontWeight.w900,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black.withOpacity(.45),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _goldLine()),
            ],
          ),
          SizedBox(height: kHeight * .016),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool twoColumns = constraints.maxWidth >= 640;
              final double spacing = kWeight * .018;
              final double cardWidth = twoColumns
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: kHeight * .012,
                children: rules.asMap().entries.map(
                      (MapEntry<int, String> entry) {
                    return SizedBox(
                      width: cardWidth,
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: twoColumns ? kHeight * .100 : 0,
                        ),
                        padding: EdgeInsets.all(kHeight * .012),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              const Color(0xff0b7264).withOpacity(.94),
                              const Color(0xff064c45).withOpacity(.96),
                              const Color(0xff033b35).withOpacity(.98),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xffffd95c).withOpacity(.24),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(.22),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: const Color(0xff25d5bd).withOpacity(.07),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              height: kHeight * .034,
                              width: kHeight * .034,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    Color(0xffffee9f),
                                    Color(0xffffc83f),
                                    Color(0xffd89012),
                                  ],
                                ),
                                border: Border.all(color: Colors.white70),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.32),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xff07544a),
                                  fontSize: kHeight * .011,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            SizedBox(width: kWeight * .016),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(.93),
                                  fontSize: kHeight * .0121,
                                  fontWeight: FontWeight.w500,
                                  height: 1.38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _weeklySalarySection() {
    return _outlinedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: _premium3DIcon(
              Icons.payments_rounded,
              size: kHeight * .040,
              iconSize: kHeight * .022,
            ),
          ),
          SizedBox(height: kHeight * .010),
          Text(
            'WEEKLY SALARY (PAYOUT) SYSTEM',
            textAlign: TextAlign.center,
            softWrap: true,
            style: GoogleFonts.poppins(
              color: const Color(0xffffd95c),
              fontSize: kHeight * .018,
              fontWeight: FontWeight.w900,
              height: 1.18,
              shadows: <Shadow>[
                Shadow(
                  color: Colors.black.withOpacity(.46),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: kHeight * .016),

          // Full mobile width layout:
          // payout card upore, important note card niche.
          // Card-er vitoreo image ebong text upor-niche thakbe.
          _weeklyPayoutCard(),
          SizedBox(height: kHeight * .014),
          _weeklyImportantNoteCard(),
        ],
      ),
    );
  }

  Widget _weeklyPayoutCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .028,
        vertical: kHeight * .018,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xff0b6d61).withOpacity(.97),
            const Color(0xff054941).withOpacity(.98),
            const Color(0xff03352f),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.13)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            height: kHeight * .160,
            child: _walletCoinArtwork(),
          ),
          SizedBox(height: kHeight * .014),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.transparent,
                  const Color(0xffffd95c).withOpacity(.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: kHeight * .014),
          _salaryPointsColumn(),
        ],
      ),
    );
  }

  Widget _weeklyImportantNoteCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .028,
        vertical: kHeight * .018,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xff0c7567),
            Color(0xff07564d),
            Color(0xff043e38),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffffd95c).withOpacity(.62),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xffffd95c).withOpacity(.10),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.campaign_rounded,
                color: const Color(0xffffe579),
                size: kHeight * .032,
              ),
              SizedBox(width: kWeight * .014),
              Expanded(
                child: Text(
                  'IMPORTANT NOTE',
                  softWrap: true,
                  style: GoogleFonts.poppins(
                    color: const Color(0xffffd95c),
                    fontSize: kHeight * .015,
                    fontWeight: FontWeight.w900,
                    height: 1.20,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: kHeight * .010),
          Text(
            'Make sure to add your Room Partners on time to be eligible for rewards.',
            softWrap: true,
            textWidthBasis: TextWidthBasis.parent,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: kHeight * .0122,
              fontWeight: FontWeight.w500,
              height: 1.42,
            ),
          ),
          SizedBox(height: kHeight * .014),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.transparent,
                  const Color(0xffffd95c).withOpacity(.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: kHeight * .012),
          SizedBox(
            width: double.infinity,
            height: kHeight * .145,
            child: _giftRewardArtwork(),
          ),
        ],
      ),
    );
  }

  Widget _salaryPointsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _salaryPoint(
          Icons.calendar_month_rounded,
          'Every Monday',
          'Rewards are calculated and sent to eligible wallets.',
        ),
        _salaryPoint(
          Icons.check_circle_outline_rounded,
          'Automatic Payout',
          'The highest achieved level is paid automatically.',
        ),
        _salaryPoint(
          Icons.verified_user_outlined,
          'Secure & Fair',
          'All rewards are calculated and delivered safely.',
        ),
      ],
    );
  }

  Widget _walletCoinArtwork() {
    return RepaintBoundary(
      child: Image.asset(
        _walletAsset,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xffffd95c),
              size: 58,
            ),
          );
        },
      ),
    );
  }

  Widget _coinStack(double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(4, (int index) {
        return Transform.translate(
          offset: Offset(0, index == 0 ? 0 : -size * .18),
          child: Container(
            width: size,
            height: size * .34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xffffef8d),
                  Color(0xffffc42f),
                  Color(0xffcc8510),
                ],
              ),
              border: Border.all(color: const Color(0xfffff1a7), width: .7),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _giftRewardArtwork() {
    return RepaintBoundary(
      child: Image.asset(
        _giftAsset,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xffffd95c),
              size: 58,
            ),
          );
        },
      ),
    );
  }

  Widget _salaryPoint(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: kHeight * .012),
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .018,
        vertical: kHeight * .011,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                color: const Color(0xffffd95c),
                size: kHeight * .023,
              ),
              SizedBox(width: kWeight * .014),
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  style: GoogleFonts.poppins(
                    color: const Color(0xffffd95c),
                    fontSize: kHeight * .0128,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: kHeight * .006),
          Text(
            description,
            softWrap: true,
            textWidthBasis: TextWidthBasis.parent,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: kHeight * .0104,
              fontWeight: FontWeight.w500,
              height: 1.38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardHistorySection() {
    final List<Map<String, dynamic>> rewards = controller.rewards;
    if (rewards.isEmpty) return const SizedBox.shrink();

    return _outlinedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionTitle('REWARD HISTORY'),
          SizedBox(height: kHeight * .010),
          ...rewards.take(8).map((Map<String, dynamic> row) {
            final Map<String, dynamic> user = controller.map(
              row['user'] ?? row['partner'] ?? row['owner'],
            );
            final String name = controller.firstText(<dynamic>[
              user['name'],
              row['name'],
              row['title'],
            ], fallback: 'User');
            final int coins = controller.safeInt(
              row['coins'] ??
                  row['amount'] ??
                  row['reward_amount'] ??
                  row['partner_reward'],
            );

            return Container(
              margin: EdgeInsets.only(bottom: kHeight * .008),
              padding: EdgeInsets.symmetric(
                horizontal: kWeight * .018,
                vertical: kHeight * .009,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xffffd95c),
                  ),
                  SizedBox(width: kWeight * .016),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: kHeight * .012,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatFullNumber(coins),
                    style: GoogleFonts.poppins(
                      color: const Color(0xffffd95c),
                      fontSize: kHeight * .012,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _partnerPoolNote() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .026,
        vertical: kHeight * .010,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xffffd95c).withOpacity(.40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.info_rounded,
            color: const Color(0xffffd95c),
            size: kHeight * .020,
          ),
          SizedBox(width: kWeight * .012),
          Flexible(
            child: Text(
              'Partner Pool (5%) is distributed equally among all partners for each level.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xffffe89b),
                fontSize: kHeight * .0107,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingTab() {
    final List<Map<String, dynamic>> rankings = controller.rankingItems;

    return RefreshIndicator(
      onRefresh: controller.load,
      color: const Color(0xff06735f),
      backgroundColor: const Color(0xffffe6a5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          kWeight * .028,
          kHeight * .006,
          kWeight * .028,
          kHeight * .025,
        ),
        child: Column(
          children: <Widget>[
            _rankingInfoBar(),
            SizedBox(height: kHeight * .014),
            _rankingPeriodTabs(),
            SizedBox(height: kHeight * .014),
            if (rankings.isEmpty)
              _emptyRanking()
            else
              ...rankings.take(50).toList().asMap().entries.map(
                    (MapEntry<int, Map<String, dynamic>> entry) =>
                    _rankingCard(entry.key + 1, entry.value),
              ),
            SizedBox(height: kHeight * .016),
            _myRankCard(),
          ],
        ),
      ),
    );
  }

  Widget _rankingInfoBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .024,
        vertical: kHeight * .012,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff0b7163).withOpacity(.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.volume_up_rounded,
            color: const Color(0xffffd95c),
            size: kHeight * .022,
          ),
          SizedBox(width: kWeight * .014),
          Expanded(
            child: Text(
              'Room points = Room Coins + Room Visitors × 1000',
              style: GoogleFonts.poppins(
                color: const Color(0xffffe88d),
                fontSize: kHeight * .012,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingPeriodTabs() {
    final List<String> tabs = <String>[
      ('Daily').appTr,
      ('Weekly').appTr,
      ('Monthly').appTr,
    ];

    return Obx(() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List<Widget>.generate(tabs.length, (int index) {
          final bool selected = controller.rankingPeriodIndex.value == index;
          return GestureDetector(
            onTap: () => controller.rankingPeriodIndex.value = index,
            child: Column(
              children: <Widget>[
                Text(
                  tabs[index],
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : Colors.white54,
                    fontSize: kHeight * .015,
                    fontWeight:
                    selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                SizedBox(height: kHeight * .005),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 4,
                  width: selected ? 34 : 0,
                  decoration: BoxDecoration(
                    color: const Color(0xffffd95c),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ],
            ),
          );
        }),
      );
    });
  }

  Widget _rankingCard(int rank, Map<String, dynamic> row) {
    final Map<String, dynamic> user = controller.map(
      row['user'] ?? row['partner'] ?? row['owner'],
    );
    final String name = controller.firstText(<dynamic>[
      user['name'],
      row['name'],
      row['title'],
    ], fallback: 'User');
    final String image = controller.firstText(<dynamic>[
      user['profile_image'],
      user['avatar'],
      row['profile_image'],
    ]);
    final int points = controller.safeInt(
      row['points'] ??
          row['room_points'] ??
          row['coins'] ??
          row['amount'] ??
          row['reward_amount'],
    );

    final List<Color> colors = rank == 1
        ? const <Color>[Color(0xffffc927), Color(0xffb87600)]
        : rank == 2
        ? const <Color>[Color(0xffa7b3c8), Color(0xff586881)]
        : rank == 3
        ? const <Color>[Color(0xffbb7b4f), Color(0xff72442d)]
        : const <Color>[Color(0xff0b7768), Color(0xff07564c)];

    return Container(
      height: kHeight * .078,
      margin: EdgeInsets.only(bottom: kHeight * .010),
      padding: EdgeInsets.symmetric(horizontal: kWeight * .024),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: kWeight * .070,
            child: Text(
              rank <= 3 ? '🏆' : '$rank',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: rank <= 3 ? kHeight * .022 : kHeight * .017,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: kWeight * .014),
          _avatar(image, size: kHeight * .050),
          SizedBox(width: kWeight * .020),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: kHeight * .013,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (controller.rankingUserId(row).isNotEmpty)
                  Text(
                    'ID: ${controller.rankingUserId(row)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: kHeight * .0095,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatCoins(points),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: kHeight * .013,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: kWeight * .008),
          Text('🪙', style: TextStyle(fontSize: kHeight * .017)),
        ],
      ),
    );
  }

  Widget _emptyRanking() {
    return _outlinedPanel(
      child: Column(
        children: <Widget>[
          Icon(
            Icons.emoji_events_rounded,
            color: const Color(0xffffd95c),
            size: kHeight * .050,
          ),
          SizedBox(height: kHeight * .010),
          Text(
            ('No ranking data yet').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: kHeight * .014,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _myRankCard() {
    final Map<String, dynamic> current = controller.current;
    final Map<String, dynamic> authUser = controller.authUserMap();
    final Map<String, dynamic> apiUser = controller.map(
      current['user'] ??
          current['owner'] ??
          current['profile'] ??
          controller.data['my_user'] ??
          controller.data['owner'],
    );

    final int rank = controller.safeInt(
      current['rank'] ?? current['my_rank'] ?? current['position'],
      fallback: 0,
    );
    final int points = controller.safeInt(
      current['room_points'] ??
          current['total_coins'] ??
          current['room_coins'],
    );
    final String name = controller.firstText(<dynamic>[
      apiUser['name'],
      current['name'],
      authUser['name'],
    ], fallback: 'My Rank');
    final String image = controller.firstText(<dynamic>[
      apiUser['profile_image'],
      apiUser['avatar'],
      current['profile_image'],
      authUser['profile_image'],
    ]);

    return Container(
      height: kHeight * .086,
      padding: EdgeInsets.symmetric(horizontal: kWeight * .026),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xff16b994), Color(0xff08745f)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffffd95c).withOpacity(.58)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            rank > 0 ? '#$rank' : '—',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: kHeight * .019,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: kWeight * .024),
          _avatar(image, size: kHeight * .052),
          SizedBox(width: kWeight * .020),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: kHeight * .014,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _formatCoins(points),
            style: GoogleFonts.poppins(
              color: const Color(0xffffe586),
              fontSize: kHeight * .014,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedPanel({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(kHeight * .014),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xff087064).withOpacity(.94),
            const Color(0xff054c44).withOpacity(.96),
            const Color(0xff023a34).withOpacity(.98),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xffffd95c).withOpacity(.42),
          width: 1.05,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: const Color(0xff2ee4cf).withOpacity(.08),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xffffd95c).withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: const Color(0xffffd95c),
        fontSize: kHeight * .015,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _goldLine() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.transparent,
            const Color(0xffffd95c).withOpacity(.85),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String rawUrl, {required double size}) {
    final String source = rawUrl.trim();
    final String url = source.isEmpty
        ? ''
        : source.startsWith('http')
        ? source
        : '$kDomainUrl/$source';

    return ClipOval(
      child: Container(
        height: size,
        width: size,
        color: Colors.white.withOpacity(.14),
        child: url.isEmpty
            ? Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: size * .56,
        )
            : Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: size * .56,
            );
          },
        ),
      ),
    );
  }

  String _formatCoins(dynamic raw) {
    final int value = controller.safeInt(raw);
    if (value >= 1000000000) {
      final double number = value / 1000000000;
      return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      final double number = value / 1000000;
      return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final double number = value / 1000;
      return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}K';
    }
    return value.toString();
  }

  String _formatFullNumber(dynamic raw) {
    final int value = controller.safeInt(raw);
    final String text = value.toString();
    final StringBuffer output = StringBuffer();

    for (int index = 0; index < text.length; index++) {
      final int remaining = text.length - index;
      output.write(text[index]);
      if (remaining > 1 && remaining % 3 == 1) output.write(',');
    }

    return output.toString();
  }
}

class _AddRoomPartnerDialog extends StatefulWidget {
  const _AddRoomPartnerDialog();

  @override
  State<_AddRoomPartnerDialog> createState() =>
      _AddRoomPartnerDialogState();
}

class _AddRoomPartnerDialogState extends State<_AddRoomPartnerDialog> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_closing) return;

    final String value = _textController.text.trim();
    if (value.isEmpty || int.tryParse(value) == null || int.parse(value) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Partner ID')),
      );
      return;
    }

    _closing = true;
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    // Let the keyboard/InputDecorator finish one frame before the dialog route
    // is removed. This prevents Flutter's `_dependents.isEmpty` / wrong build
    // scope assertion on MIUI and other Android devices.
    await Future<void>.delayed(const Duration(milliseconds: 90));

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop<String>(value);
  }

  Future<void> _cancel() async {
    if (_closing) return;
    _closing = true;
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop<String>();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets keyboardInsets = MediaQuery.viewInsetsOf(context);

    return PopScope(
      canPop: !_closing,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          22 + keyboardInsets.bottom,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 430,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xff0b7567),
                      Color(0xff075247),
                      Color(0xff033c35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xffffd95c).withOpacity(.62),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(.42),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: const Color(0xff2ee4cf).withOpacity(.14),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xfffff1a0),
                            Color(0xffffc83f),
                            Color(0xffd88e10),
                          ],
                        ),
                        border: Border.all(color: Colors.white70),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withOpacity(.34),
                            blurRadius: 9,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xff075247),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ('Add Room Partner').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xffffe99a),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the database user ID of the partner.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: ('Partner ID').appTr,
                        hintText: ('Enter user ID').appTr,
                        labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        hintStyle: GoogleFonts.poppins(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.badge_rounded,
                          color: Color(0xffffd95c),
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(.18),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(.18),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xffffd95c),
                            width: 1.3,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _closing ? null : _cancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(.30),
                              ),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(('Cancel').appTr),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _closing ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffffd95c),
                              foregroundColor: const Color(0xff06443c),
                              minimumSize: const Size.fromHeight(46),
                              elevation: 8,
                              shadowColor: Colors.black54,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              ('Add Partner').appTr,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w900,
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
          ),
        ),
      ),
    );
  }
}

