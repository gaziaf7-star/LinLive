import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/image_helper.dart';
import '../../informationcollection/views/informationcollection_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
const Color kAppColor1 = Color(0xFFAC0422);
const Color kAppColor2 = Color(0xFFF81889);
const Color kAppbarColor = Color(0xFFF82897);

class MemberincomeView extends StatefulWidget {
  const MemberincomeView({super.key});

  @override
  State<MemberincomeView> createState() => _MemberincomeViewState();
}

class _MemberincomeViewState extends State<MemberincomeView> {
  bool _isPageLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAgencyHosts();
    });
  }

  Future<void> _loadAgencyHosts() async {
    final agencyId = int.tryParse(
      _safeText(
        _agencyValue('agency_id'),
        '0',
      ),
    );

    if (agencyId == null || agencyId <= 0) return;

    if (mounted) {
      setState(() {
        _isPageLoading = true;
      });
    }

    try {
      await Future.sync(() {
        return informationcollectionController.showAgencyHostList(
          agencyId: agencyId,
        );
      });
    } catch (e) {
      debugPrint('Member income load error: $e');
    }

    if (mounted) {
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  dynamic _agencyValue(String key) {
    try {
      final data = verifiedController.agencySingleData;

      if (data is Map) {
        return data[key];
      }

      return data[key];
    } catch (_) {
      return null;
    }
  }

  List<dynamic> _hostList() {
    try {
      final rawList = informationcollectionController.newAgencyhostList;

      if (rawList is Iterable) {
        return rawList.toList();
      }
    } catch (_) {}

    return <dynamic>[];
  }

  String _safeText(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') return fallback;

    return text;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map(
            (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }

  String? _activeFrameUrl() {
    try {
      final activeAssetIds = homeController.activeFrameData['active_asset_ids'];

      if (activeAssetIds is Map) {
        final asset = activeAssetIds['asset'];

        if (asset is Map && asset['asset'] != null) {
          return "$kDomainUrl/${asset['asset']}";
        }
      }
    } catch (_) {}

    return null;
  }

  String? _hostFrameUrl(Map<String, dynamic> hostData) {
    try {
      final history = hostData['asset_purchase_history'];

      if (history is Map) {
        final asset = history['asset'];

        if (asset is Map && asset['asset'] != null) {
          return ImageHelper.getImageUrl(asset['asset']);
        }
      }
    } catch (_) {}

    return null;
  }

  bool get _isAgencyMember {
    try {
      final agencyId = authController.userProfile.value.user?.agencyId;
      return agencyId != null && agencyId.toString() != '0';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = _hostList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F8),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kAppbarColor, kAppColor2, kAppColor1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          ('Member Income').appTr,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildExportButton(),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: kAppColor2,
            onRefresh: _loadAgencyHosts,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth =
                constraints.maxWidth > 760 ? 760.0 : constraints.maxWidth;

                final horizontalPadding =
                constraints.maxWidth > 420 ? 20.0 : 14.0;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(
                        context: context,
                        totalMembers: hosts.length,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              18,
                              horizontalPadding,
                              8,
                            ),
                            child: _buildTableHeader(context),
                          ),
                        ),
                      ),
                    ),
                    if (hosts.isEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: 14,
                              ),
                              child: _buildEmptyState(),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final hostData = _asMap(hosts[index]);

                            return Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxWidth),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: 5,
                                  ),
                                  child: _buildHostRow(
                                    context: context,
                                    hostData: hostData,
                                    index: index,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: hosts.length,
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 24,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_isPageLoading && hosts.isEmpty)
            Container(
              color: Colors.white.withOpacity(.35),
              child: const Center(
                child: CircularProgressIndicator(
                  color: kAppColor2,
                  strokeWidth: 2.6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () {
          Get.to(
                () => InformationcollectionView(),
            transition: Transition.leftToRight,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.18),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.file_download_outlined,
                color: Colors.white,
                size: 17,
              ),
              const SizedBox(width: 5),
              Text(
                ('Export').appTr,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required BuildContext context,
    required int totalMembers,
  }) {
    final width = MediaQuery.of(context).size.width;
    final avatarSize = width < 360 ? 78.0 : 92.0;

    final agencyName = _safeText(
      _agencyValue('name'),
      ('Agency').appTr,
    );

    final userId = _safeText(
      _agencyValue('user_id'),
      '0',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kAppbarColor, kAppColor2, kAppColor1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          _buildMainAvatar(avatarSize),
          const SizedBox(height: 10),
          Text(
            agencyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: width < 360 ? 17 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            ('ID: $userId').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(.86),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            alignment: WrapAlignment.center,
            children: [
              _buildInfoPill(
                icon: Icons.groups_2_rounded,
                label: ('Members').appTr,
                value: totalMembers.toString(),
              ),
              _buildInfoPill(
                icon: Icons.diamond_rounded,
                label: ('Income').appTr,
                value: ('Report').appTr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainAvatar(double size) {
    String profileUrl = '';

    try {
      final profileImage = authController.userProfile.value.user?.profileImage;
      profileUrl = ImageHelper.getImageUrl(profileImage ?? '');
    } catch (_) {}

    final customFrameUrl = _activeFrameUrl();

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(.95),
                Colors.white.withOpacity(.45),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: profileUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (context, url) => Container(
                color: Colors.white.withOpacity(.25),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.white.withOpacity(.18),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        if (_isAgencyMember)
          IgnorePointer(
            child: SizedBox(
              height: size * 1.20,
              width: size * 1.20,
              child: SVGAEasyPlayer(
                assetsName: agencyFrame,
                fit: BoxFit.cover,
              ),
            ),
          )
        else if (customFrameUrl != null)
          IgnorePointer(
            child: CachedNetworkImage(
              imageUrl: customFrameUrl,
              height: size * 1.20,
              width: size * 1.20,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(.78),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSize = width < 360 ? 11 : 12;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: kAppColor2.withOpacity(.10),
        ),
        boxShadow: [
          BoxShadow(
            color: kAppColor1.withOpacity(.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _headerCell(
            text: ('Host').appTr,
            flex: 5,
            fontSize: kHeight*0.016,
            textAlign: TextAlign.left,
          ),
          _headerCell(
            text: ('Diamonds').appTr,
            flex: 3,
            fontSize: kHeight*0.016,
          ),
          _headerCell(
            text: ('Day').appTr,
            flex: 2,
            fontSize: kHeight*0.016,
          ),
          _headerCell(
            text: ('Time').appTr,
            flex: 2,
            fontSize: kHeight*0.016,
          ),
        ],
      ),
    );
  }

  Widget _headerCell({
    required String text,
    required int flex,
    required double fontSize,
    TextAlign textAlign = TextAlign.center,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: GoogleFonts.poppins(
          color: kAppColor1,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildHostRow({
    required BuildContext context,
    required Map<String, dynamic> hostData,
    required int index,
  }) {
    final width = MediaQuery.of(context).size.width;

    final avatarSize = width < 360 ? 38.0 : 43.0;
    final nameFont = width < 360 ? 12 : 13.2;
    final valueFont = width < 360 ? 10.8 : 12.2;

    final hostName = _safeText(hostData['name'], ('Unknown').appTr);
    final hostId = _safeText(hostData['user_id'], '0');

    final diamonds = _safeText(
      hostData['earned_coins'] ??
          hostData['daily_earned_coins'] ??
          hostData['monthly_earned_coins'],
      '0',
    );

    final day = _safeText(
      hostData['day'] ?? hostData['total_day'],
      '0',
    );

    final time = _safeText(
      hostData['time'] ?? hostData['live_time'],
      '0h0m',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: kAppColor2.withOpacity(.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _buildHostAvatar(
                  hostData: hostData,
                  size: avatarSize,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hostName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color:  Color(0xFF1D1725),
                          fontSize: kHeight*0.016,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        ('ID: $hostId').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF8B8192),
                          fontSize: width < 360 ? 10 : 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _valueCell(
            text: diamonds,
            flex: 3,
            fontSize: valueFont,
            color: kAppColor2,
            fontWeight: FontWeight.w800,
          ),
          _valueCell(
            text: day,
            flex: 2,
            fontSize: valueFont,
          ),
          _valueCell(
            text: time,
            flex: 2,
            fontSize: valueFont,
          ),
        ],
      ),
    );
  }

  Widget _buildHostAvatar({
    required Map<String, dynamic> hostData,
    required double size,
  }) {
    final profileImage = ImageHelper.getImageUrl(hostData['profile_image']);
    final frameUrl = _hostFrameUrl(hostData);

    return SizedBox(
      height: size + 8,
      width: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kAppColor2.withOpacity(.95),
                  kAppColor1.withOpacity(.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: profileImage,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFFFE8F2),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFFFE8F2),
                  child: Icon(
                    Icons.person_rounded,
                    color: kAppColor2.withOpacity(.75),
                    size: size * .52,
                  ),
                ),
              ),
            ),
          ),
          if (frameUrl != null)
            IgnorePointer(
              child: CachedNetworkImage(
                imageUrl: frameUrl,
                width: size + 8,
                height: size + 8,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueCell({
    required String text,
    required int flex,
    required double fontSize,
    Color color = const Color(0xFF2A2430),
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: kAppColor2.withOpacity(.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: kAppColor2.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: kAppColor2,
              size: 27,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ('No member found').appTr,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1D1725),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ('Pull down to refresh member income list.').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF8B8192),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}