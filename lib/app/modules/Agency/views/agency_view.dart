import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/image_helper.dart';
import '../../informationcollection/controllers/informationcollection_controller.dart';
import '../../memberincome/views/memberincome_view.dart';
import '../../ranking/views/ranking_view.dart';
import 'ActiveMember.dart';
import 'MemberInvite.dart';
import 'createAgency.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
const String _agencyFontFamily = 'Poppins';

class AgencyView extends StatefulWidget {
  const AgencyView({super.key});

  @override
  State<AgencyView> createState() => _AgencyViewState();
}

class _AgencyViewState extends State<AgencyView> with TickerProviderStateMixin {
  late final InformationcollectionController _infoController;
  late final AnimationController _entryController;
  late final AnimationController _floatController;

  int _loadedAgencyId = 0;

  static const Color _bgColor = Color(0xffF7F4FC);

  @override
  void initState() {
    super.initState();

    _infoController = Get.isRegistered<InformationcollectionController>()
        ? Get.find<InformationcollectionController>()
        : Get.put(InformationcollectionController());

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _infoController.showAuthAgencyHome(force: true);
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _mapFrom(dynamic raw) {
    try {
      if (raw is RxMap) {
        return raw.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
        );
      }

      if (raw is Map) {
        return raw.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Map<String, dynamic> get _agencyData {
    final controllerData = _mapFrom(_infoController.agencyData);
    if (controllerData.isNotEmpty) return controllerData;

    final verifiedData = _mapFrom(verifiedController.agencySingleData);
    if (verifiedData.isNotEmpty) return verifiedData;

    return <String, dynamic>{};
  }

  void _syncAgencyRequest(int agencyId) {
    if (agencyId <= 0 || _loadedAgencyId == agencyId) return;

    _loadedAgencyId = agencyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _infoController.showRequestAgenctList(agencyId: agencyId);
    });
  }

  double _sp(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390).clamp(.82, 1.0);
    return (value * scale * .88).clamp(value * .72, value * .96).toDouble();
  }

  String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '').trim()) ?? 0;
  }

  String _formatNumber(dynamic value) {
    final number = _toDouble(value);
    if (number == 0) return '0';
    if (number % 1 == 0) return number.toInt().toString();
    return number.toStringAsFixed(2);
  }

  int get _requestCount {
    try {
      return _infoController.newAgencyRequestList.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = MediaQuery.of(context).padding.top + 58;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: _agencyFontFamily,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(appBarHeight),
          child: _FixedAgencyAppBar(
            height: appBarHeight,
            floatController: _floatController,
          ),
        ),
        body: Obx(() => _buildAgencyHomeBody(context)),
      ),
    );
  }

  Widget _buildAgencyHomeBody(BuildContext context) {
    final rawData = _agencyData;

    if (_infoController.agencyHomeLoading.value && rawData.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xffD70B8F),
          strokeWidth: 2.2,
        ),
      );
    }

    if (rawData.isEmpty) {
      return _AgencyHomeEmptyState(
        message: _infoController.agencyHomeError.value.isNotEmpty
            ? _infoController.agencyHomeError.value
            : 'Agency data not found',
        onRefresh: () => _infoController.showAuthAgencyHome(force: true),
      );
    }

    final data = _mapFrom(rawData['data']).isNotEmpty
        ? _mapFrom(rawData['data'])
        : rawData;

    final agency = _mapFrom(data['agency']).isNotEmpty
        ? _mapFrom(data['agency'])
        : data;

    final authUser = _mapFrom(data['auth_user']);

    final summary = _mapFrom(data['summary']).isNotEmpty
        ? _mapFrom(data['summary'])
        : data;

    final agencyId = _toInt(
      agency['agency_id'] ??
          authUser['user_id'] ??
          data['agency_id'] ??
          agency['id'],
    );
    _syncAgencyRequest(agencyId);

    final status = _text(agency['status'] ?? data['status']).toLowerCase();
    final isPending = status == 'pending';
    final isDeclined = status == 'declined' || status == 'rejected';

    final name = _text(
      agency['name'] ?? authUser['name'] ?? data['name'],
      fallback: 'Not available',
    );

    final agencyImageUrl = _text(
      agency['profile_image_url'] ??
          agency['profile_image'] ??
          authUser['profile_image_url'] ??
          authUser['profile_image'],
    );

    final totalDiamond = summary['total_commission_diamonds'] ??

        summary['total_commission_diamonds'] ??

        0;

    final today = summary['today_diamonds'] ??
        summary['today_commission_diamonds'] ??
        summary['today_commission'] ??
        summary['today'] ??
        0;

    final lastWeek = summary['last_week_diamonds'] ??
        summary['last_week_commission_diamonds'] ??
        summary['last_week_commission'] ??
        summary['last_week'] ??
        0;

    final lastMonth = summary['last_month_diamonds'] ??
        summary['last_month_commission_diamonds'] ??
        summary['last_month_commission'] ??
        summary['last_month'] ??
        0;

    final membersFromList = _infoController.newAgencyhostList.isNotEmpty
        ? _infoController.newAgencyhostList.length
        : 0;

    final members = summary['members'] ??
        summary['member_count'] ??
        summary['total_members'] ??
        data['members'] ??
        data['member_count'] ??
        membersFromList;

    return RefreshIndicator(
      color: const Color(0xffD70B8F),
      onRefresh: () => _infoController.showAuthAgencyHome(force: true),
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          final value = Curves.easeOutCubic.transform(_entryController.value);

          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            children: [
              _AgencyHeader(
                name: name,
                agencyId: agencyId,
                profileImageUrl: agencyImageUrl,
                totalDiamond: _formatNumber(totalDiamond),
                floatController: _floatController,
              ),

              const SizedBox(height: 14),

              _StatsCard(
                today: _formatNumber(today),
                lastWeek: _formatNumber(lastWeek),
                lastMonth: _formatNumber(lastMonth),
                members: _formatNumber(members),
                sp: (v) => _sp(context, v),
              ),

              const SizedBox(height: 20),

              if (isPending)
                _ApplicationStatusCard(
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: Colors.orangeAccent,
                  title: ('Your Application is Under Review').appTr,
                  message:
                  "Please wait while we review your application.\nYou'll be notified once the process is complete.",
                  sp: (v) => _sp(context, v),
                )
              else if (isDeclined)
                _ApplicationStatusCard(
                  icon: Icons.cancel_rounded,
                  iconColor: Colors.redAccent,
                  title: ('Your Application is Rejected').appTr,
                  message: ('Please review your details and reapply again.').appTr,
                  showButton: true,
                  sp: (v) => _sp(context, v),
                )
              else
                _MenuCard(
                  requestCount: _requestCount,
                  sp: (v) => _sp(context, v),
                ),

              if (!isPending && !isDeclined) ...[
                const SizedBox(height: 28),
                _SuccessPill(floatController: _floatController),
              ],

              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}


class _AgencyHomeEmptyState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRefresh;

  const _AgencyHomeEmptyState({
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xffD70B8F),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: MediaQuery.of(context).size.height * .22,
        ),
        children: [
          Container(
            height: 82,
            width: 82,
            decoration: const BoxDecoration(
              color: Color(0xffF2E4FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Color(0xffD70B8F),
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff071032),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                onRefresh();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label:  Text(('Reload').appTr),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffD70B8F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedAgencyAppBar extends StatelessWidget {
  final double height;
  final AnimationController floatController;

  const _FixedAgencyAppBar({
    required this.height,
    required this.floatController,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: floatController,
        builder: (_, __) {
          return CustomPaint(
            painter: _HeaderPatternPainter(floatController.value),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xffF0065F),
                    Color(0xffD70B8F),
                    Color(0xff7D28FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child:  _TopBar(title: ('Agency').appTr),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgencyHeader extends StatelessWidget {
  final String name;
  final int agencyId;
  final String profileImageUrl;
  final String totalDiamond;
  final AnimationController floatController;

  const _AgencyHeader({
    required this.name,
    required this.agencyId,
    required this.profileImageUrl,
    required this.totalDiamond,
    required this.floatController,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final headerHeight = (height * .135).clamp(106.0, 138.0);
    final cardHeight = (height * .21).clamp(160.0, 188.0);
    final side = (width * .042).clamp(16.0, 20.0);

    return SizedBox(
      height: headerHeight + cardHeight - 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: AnimatedBuilder(
              animation: floatController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _HeaderPatternPainter(floatController.value),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xffF0065F),
                          Color(0xffD70B8F),
                          Color(0xff7D28FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: headerHeight - 56,
            left: 0,
            right: 0,
            height: 76,
            child: CustomPaint(
              painter: _WavePainter(),
            ),
          ),
          Positioned(
            top: headerHeight - 34,
            left: side,
            right: side,
            child: _HeroAgencyCard(
              height: cardHeight,
              name: name,
              agencyId: agencyId,
              profileImageUrl: profileImageUrl,
              totalDiamond: totalDiamond,
              floatController: floatController,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Get.back(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontFamily: _agencyFontFamily,
              color: Colors.white,
              fontSize: 23,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: .1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAgencyCard extends StatelessWidget {
  final double height;
  final String name;
  final int agencyId;
  final String profileImageUrl;
  final String totalDiamond;
  final AnimationController floatController;

  const _HeroAgencyCard({
    required this.height,
    required this.name,
    required this.agencyId,
    required this.profileImageUrl,
    required this.totalDiamond,
    required this.floatController,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final logoSize = (width * .29).clamp(96.0, 126.0);
    final nameFont = (width * .055).clamp(20.0, 25.0);
    final diamondFont = (width * .095).clamp(34.0, 46.0);

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: (width * .042).clamp(16.0, 20.0),
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.97),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white.withOpacity(.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9E8EEA).withOpacity(.17),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: CustomPaint(
          painter: _DiamondWatermarkPainter(),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: floatController,
                builder: (_, child) {
                  final dy = math.sin(floatController.value * math.pi) * -4;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: _AgencyProfileArt(
                  size: logoSize,
                  name: name,
                  profileImageUrl: profileImageUrl,
                ),
              ),
              SizedBox(width: (width * .045).clamp(14.0, 20.0)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xff071032),
                        fontSize: nameFont,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffF2E4FA),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 15,
                            color: Color(0xff8B21D6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ('ID: $agencyId').appTr,
                            style: const TextStyle(
                              color: Color(0xff8B21D6),
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 13),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: const Color(0xffE9E8EF),
                    ),
                    const Spacer(),
                     Text(
                      ('Total Diamond').appTr,
                      style: TextStyle(
                        color: Color(0xff686D7E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalDiamond,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xff9D00D7),
                        fontSize: diamondFont,
                        height: .92,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgencyProfileArt extends StatelessWidget {
  final double size;
  final String name;
  final String profileImageUrl;

  const _AgencyProfileArt({
    required this.size,
    required this.name,
    required this.profileImageUrl,
  });

  String? _profileUrl() {
    try {
      final directUrl = profileImageUrl.trim();
      if (directUrl.isNotEmpty && directUrl != 'null') {
        if (directUrl.startsWith('http://') || directUrl.startsWith('https://')) {
          return directUrl;
        }

        final builtUrl = ImageHelper.getImageUrl(directUrl);
        if (builtUrl.trim().isNotEmpty && builtUrl != 'null') return builtUrl;
      }

      final image = authController.userProfile.value.user?.profileImage;
      final url = ImageHelper.getImageUrl(image);
      if (url.trim().isNotEmpty && url != 'null') return url;
    } catch (_) {}
    return null;
  }

  bool _isAgencyMember() {
    try {
      final id = authController.userProfile.value.user?.agencyId;
      if (id == null) return false;
      return id.toString() != '0';
    } catch (_) {
      return false;
    }
  }

  String? _activeFrameUrl() {
    try {
      final frameData = homeController.activeFrameData;
      if (frameData is! Map) return null;

      final activeIds = frameData['active_asset_ids'];
      if (activeIds is! Map) return null;

      final assetBox = activeIds['asset'];
      if (assetBox is! Map) return null;

      final asset = assetBox['asset'];
      if (asset == null) return null;

      final path = asset.toString();
      if (path.trim().isEmpty || path == 'null') return null;

      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }

      return "$kDomainUrl/$path";
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _profileUrl();
    final activeFrameUrl = _activeFrameUrl();

    final cleanName = name.trim();
    final firstLetter =
    cleanName.isNotEmpty ? cleanName.substring(0, 1).toUpperCase() : ('A').appTr;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: size * .82,
            width: size * .82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  const Color(0xffEAF3FF).withOpacity(.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff268BFF).withOpacity(.14),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl == null
                  ? Center(
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    color: const Color(0xff1B62FF),
                    fontSize: size * .26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
                  : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xffEEF4FF),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Text(
                    firstLetter,
                    style: TextStyle(
                      color: const Color(0xff1B62FF),
                      fontSize: size * .26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isAgencyMember())
            SizedBox(
              height: size,
              width: size,
              child: SVGAEasyPlayer(
                assetsName: agencyFrame,
                fit: BoxFit.cover,
              ),
            )
          else if (activeFrameUrl != null)
            CachedNetworkImage(
              imageUrl: activeFrameUrl,
              height: size,
              width: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          Positioned(
            bottom: 2,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size * .13,
                vertical: size * .03,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff1A8DFF),
                    Color(0xff6D40FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff315DFF).withOpacity(.23),
                    blurRadius: 9,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                ('Agency').appTr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * .105,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String today;
  final String lastWeek;
  final String lastMonth;
  final String members;
  final double Function(double) sp;

  const _StatsCard({
    required this.today,
    required this.lastWeek,
    required this.lastMonth,
    required this.members,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(
        horizontal: sp(10),
        vertical: sp(16),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9E8EEA).withOpacity(.12),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.today_rounded,
                  iconColor: const Color(0xff13A85B),
                  bgColor: const Color(0xffE9FFF3),
                  label: ('Today commission').appTr,
                  value: today,
                  sp: sp,
                ),
              ),
              _DividerLine(),
              Expanded(
                child: _StatItem(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xff286BFF),
                  bgColor: const Color(0xffECF1FF),
                  label: ('Last week commission').appTr,
                  value: lastWeek,
                  sp: sp,
                ),
              ),
            ],
          ),
          const _HorizontalDividerLine(),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.calendar_month,
                  iconColor: const Color(0xffEC0A7A),
                  bgColor: const Color(0xffFFE9F5),
                  label: ('Last month commission').appTr,
                  value: lastMonth,
                  sp: sp,
                ),
              ),
              _DividerLine(),
              Expanded(
                child: _StatItem(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xffFF6A1A),
                  bgColor: const Color(0xffFFF0E3),
                  label: ('Total members').appTr,
                  value: members,
                  sp: sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;
  final double Function(double) sp;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: sp(46),
          width: sp(46),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: sp(23),
          ),
        ),
        SizedBox(height: sp(10)),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xff686D7E),
            fontSize: sp(11),
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: sp(7)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xff071032),
            fontSize: sp(26),
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xffE9E8EF),
    );
  }
}

class _HorizontalDividerLine extends StatelessWidget {
  const _HorizontalDividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: const Color(0xffE9E8EF),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final int requestCount;
  final double Function(double) sp;

  const _MenuCard({
    required this.requestCount,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(vertical: sp(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9E8EEA).withOpacity(.12),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.workspace_premium_rounded,
            title: ('My Agency Rank').appTr,
            colors: const [Color(0xff7B40FF), Color(0xffA050FF)],
            badgeCount: 0,
            sp: sp,
            onTap: () => Get.to(
              RankingView(),
              transition: Transition.rightToLeft,
            ),
          ),
          _SoftDivider(),
          _MenuRow(
            icon: Icons.attach_money_rounded,
            title: ('Member Income').appTr,
            colors: const [Color(0xff08C988), Color(0xff20E0A0)],
            badgeCount: 0,
            sp: sp,
            onTap: () => Get.to(
              MemberincomeView(),
              transition: Transition.rightToLeft,
            ),
          ),
          _SoftDivider(),
          _MenuRow(
            icon: Icons.group_add_rounded,
            title: ('Member Request').appTr,
            colors: const [Color(0xff0C83FF), Color(0xff24A5FF)],
            badgeCount: requestCount,
            sp: sp,
            onTap: () => Get.to(
              MemberInvite(),
              transition: Transition.rightToLeft,
            ),
          ),
          _SoftDivider(),
          _MenuRow(
            icon: Icons.event_available_rounded,
            title: ('Member Active Days').appTr,
            colors: const [Color(0xffFF7D20), Color(0xffFF9B35)],
            badgeCount: 0,
            sp: sp,
            onTap: () => Get.to(
              ActiveMember(),
              transition: Transition.rightToLeft,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> colors;
  final int badgeCount;
  final VoidCallback onTap;
  final double Function(double) sp;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.colors,
    required this.badgeCount,
    required this.onTap,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sp(20),
            vertical: sp(12),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: sp(48),
                    width: sp(48),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colors.last.withOpacity(.23),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: sp(25),
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 20,
                          minWidth: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: sp(16)),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xff071032),
                    fontSize: sp(17),
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xff5D6275),
                size: sp(19),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 82, right: 24),
      color: const Color(0xffEFEFF3),
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final bool showButton;
  final double Function(double) sp;

  const _ApplicationStatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.sp,
    this.showButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.symmetric(
        horizontal: sp(18),
        vertical: sp(28),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(.11),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: sp(58),
          ),
          SizedBox(height: sp(13)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sp(18),
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
          ),
          SizedBox(height: sp(8)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sp(12),
              color: const Color(0xff686D7E),
              height: 1.38,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showButton) ...[
            SizedBox(height: sp(22)),
            ElevatedButton.icon(
              onPressed: () => Get.to(Createagency()),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white,
              ),
              label:  Text(
                ('Reapply').appTr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessPill extends StatelessWidget {
  final AnimationController floatController;

  const _SuccessPill({required this.floatController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatController,
      builder: (_, child) {
        final scale = 1 + (math.sin(floatController.value * math.pi) * .018);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xff34D96A),
              Color(0xff13BA55),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff13BA55).withOpacity(.25),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child:  Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 27,
            ),
            SizedBox(width: 11),
            Text(
              ('show list success').appTr,
              style: TextStyle(
                fontFamily: _agencyFontFamily,
                color: Colors.white,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  final double t;

  _HeaderPatternPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withOpacity(.08);

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(.08);

    final shift = math.sin(t * math.pi) * 7;

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * .94, -12 + shift),
        42 + (i * 18),
        ringPaint,
      );
    }

    canvas.drawCircle(
      Offset(size.width * .08, size.height * .18 + shift),
      32,
      glowPaint,
    );

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(.18);

    final startX = size.width * .79;
    final startY = size.height * .45;

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        canvas.drawCircle(
          Offset(startX + col * 13, startY + row * 13),
          2,
          dotPaint,
        );
      }
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(.05);

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .18, size.height * 1.05),
        radius: size.width * .38,
      ),
      math.pi * 1.04,
      math.pi * .42,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderPatternPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffF7F4FC)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 30)
      ..cubicTo(size.width * .16, 3, size.width * .34, 5, size.width * .54, 10)
      ..cubicTo(size.width * .75, 15, size.width * .87, 5, size.width, 30)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withOpacity(.62);

    final line = Path()
      ..moveTo(0, 30)
      ..cubicTo(size.width * .16, 3, size.width * .34, 5, size.width * .54, 10)
      ..cubicTo(size.width * .75, 15, size.width * .87, 5, size.width, 30);

    canvas.drawPath(line, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiamondWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xff9E8EEA).withOpacity(.09);

    final cx = size.width * .84;
    final cy = size.height * .55;
    final w = size.width * .28;
    final h = size.height * .56;

    final top = Offset(cx, cy - h * .5);
    final left = Offset(cx - w * .5, cy - h * .08);
    final right = Offset(cx + w * .5, cy - h * .08);
    final bottom = Offset(cx, cy + h * .5);

    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawLine(top, bottom, paint);
    canvas.drawLine(left, right, paint);
    canvas.drawLine(left, top, paint);
    canvas.drawLine(right, top, paint);

    final sparklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xffB38DFF).withOpacity(.16);

    void sparkle(Offset o, double r) {
      canvas.drawLine(
        Offset(o.dx - r, o.dy),
        Offset(o.dx + r, o.dy),
        sparklePaint,
      );
      canvas.drawLine(
        Offset(o.dx, o.dy - r),
        Offset(o.dx, o.dy + r),
        sparklePaint,
      );
    }

    sparkle(Offset(size.width * .74, size.height * .24), 6);
    sparkle(Offset(size.width * .93, size.height * .30), 4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}