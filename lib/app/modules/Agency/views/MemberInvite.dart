import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MemberInvite extends StatefulWidget {
  const MemberInvite({super.key});

  @override
  State<MemberInvite> createState() => _MemberInviteState();
}

class _MemberInviteState extends State<MemberInvite>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final int agencyIdFromHome =
          informationcollectionController.currentAgencyId.value;
      final int agencyIdFromVerified = int.tryParse(
        verifiedController.agencySingleData['agency_id']?.toString() ?? '',
      ) ??
          0;
      final int agencyId =
      agencyIdFromHome > 0 ? agencyIdFromHome : agencyIdFromVerified;

      if (agencyId > 0) {
        informationcollectionController.currentAgencyId.value = agencyId;
        informationcollectionController.showRequestAgenctList(
          agencyId: agencyId,
        );
      } else {
        informationcollectionController.showAuthAgencyHome(force: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _mapFrom(dynamic raw) {
    if (raw is Map) {
      return raw.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  String _statusOf(Map<String, dynamic> item) {
    return (item['status'] ?? '').toString().trim();
  }

  bool _isPending(Map<String, dynamic> item) {
    return _statusOf(item).toLowerCase() == 'pending';
  }

  List<Map<String, dynamic>> _memberList() {
    return informationcollectionController.newAgencyRequestList
        .map((e) => _mapFrom(e))
        .where((item) => item.isNotEmpty && !_isPending(item))
        .toList();
  }

  List<Map<String, dynamic>> _applyList() {
    return informationcollectionController.newAgencyRequestList
        .map((e) => _mapFrom(e))
        .where((item) => item.isNotEmpty && _isPending(item))
        .toList();
  }

  String _safeText(dynamic value, {String fallback = 'N/A'}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String _profileImageUrl(Map<String, dynamic> item) {
    final user = _mapFrom(item['user']);
    final directUrl = _safeText(user['profile_image_url'], fallback: '');
    final image = _safeText(user['profile_image'], fallback: '');

    if (directUrl.startsWith('http://') || directUrl.startsWith('https://')) {
      return directUrl;
    }

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }

    if (image.isNotEmpty) {
      final domain = kDomainUrl.endsWith('/')
          ? kDomainUrl.substring(0, kDomainUrl.length - 1)
          : kDomainUrl;
      final cleanImage = image.startsWith('/') ? image.substring(1) : image;
      return '$domain/$cleanImage';
    }

    return 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTD8qrkPg5tffSPQIqlxXcW-czht693ZlfJnHGej1zZUVvStsw638N4108&s';
  }

  String _userName(Map<String, dynamic> item) {
    final user = _mapFrom(item['user']);
    return _safeText(user['name']);
  }

  String _userId(Map<String, dynamic> item) {
    final user = _mapFrom(item['user']);
    return _safeText(user['user_id'] ?? user['id']);
  }

  Widget _avatar(Map<String, dynamic> item) {
    return CachedNetworkImage(
      imageUrl: _profileImageUrl(item),
      imageBuilder: (context, imageProvider) => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
      errorWidget: (context, url, error) => ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Image.network(
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTD8qrkPg5tffSPQIqlxXcW-czht693ZlfJnHGej1zZUVvStsw638N4108&s',
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _deleteButton(Map<String, dynamic> item, {bool compact = false}) {
    final int hostId = informationcollectionController.agencyHostIdFrom(item);

    return Obx(() {
      final bool loading =
          informationcollectionController.deletingHostId.value == hostId;

      return InkWell(
        onTap: loading
            ? null
            : () {
          informationcollectionController.deleteAgencyHost(hostId: hostId);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 5 : 8,
            horizontal: compact ? kWeight * 0.022 : kWeight * 0.04,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D68), Color(0xFFE51B3E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE51B3E).withOpacity(.18),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: loading
              ? SizedBox(
            height: compact ? 13 : 16,
            width: compact ? 13 : 16,
            child: const CircularProgressIndicator(
              strokeWidth: 1.8,
              color: Colors.white,
            ),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: compact ? 14 : 16,
              ),
              const SizedBox(width: 4),
              Text(
                ('Delete').appTr,
                style: GoogleFonts.lato(
                  color: Colors.white,
                  fontSize: compact ? kHeight * 0.013 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        centerTitle: true,
        title:  Text(('Member Request').appTr),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xffff5582),
          labelColor: const Color(0xffff5582),
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs:  [
            Tab(text: ('Agency Number').appTr),
            Tab(text: ('Apply').appTr),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFunTab(),
          _buildApplyTab(),
        ],
      ),
    );
  }

  // Agency Member Tab - Real accepted/active host list with delete option.
  Widget _buildFunTab() {
    return SafeArea(
      child: Obx(() {
        final members = _memberList();

        return Column(
          children: [
            const SizedBox(height: 20),
            _buildSearchField(),
            const SizedBox(height: 20),
            Expanded(
              child: members.isEmpty
                  ? _buildEmptyState(
                title: ('No Member Found').appTr,
                subTitle: 'There are no agency members right now.',
              )
                  : RefreshIndicator(
                onRefresh: () async {
                  final agencyId = informationcollectionController
                      .currentAgencyId.value >
                      0
                      ? informationcollectionController
                      .currentAgencyId.value
                      : int.tryParse(
                    verifiedController
                        .agencySingleData['agency_id']
                        ?.toString() ??
                        '',
                  ) ??
                      0;

                  if (agencyId > 0) {
                    await informationcollectionController
                        .showRequestAgenctList(agencyId: agencyId);
                  } else {
                    await informationcollectionController
                        .showAuthAgencyHome(force: true);
                  }
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (BuildContext context, int index) {
                    final userData = members[index];
                    return _buildFunListItem(userData);
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Apply Tab - Pending member request list with accept/reject/delete option.
  Widget _buildApplyTab() {
    return SafeArea(
      child: Obx(() {
        final applyList = _applyList();

        return Column(
          children: [
            const SizedBox(height: 20),
            _buildSearchField(),
            const SizedBox(height: 20),
            Expanded(
              child: applyList.isEmpty
                  ? _buildEmptyState(
                title: ('No Request Found').appTr,
                subTitle: 'There are no new agency requests right now.',
              )
                  : RefreshIndicator(
                onRefresh: () async {
                  final agencyId = informationcollectionController
                      .currentAgencyId.value >
                      0
                      ? informationcollectionController
                      .currentAgencyId.value
                      : int.tryParse(
                    verifiedController
                        .agencySingleData['agency_id']
                        ?.toString() ??
                        '',
                  ) ??
                      0;

                  if (agencyId > 0) {
                    await informationcollectionController
                        .showRequestAgenctList(agencyId: agencyId);
                  } else {
                    await informationcollectionController
                        .showAuthAgencyHome(force: true);
                  }
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: applyList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final agencyData = applyList[index];
                    return _buildApplyListItem(agencyData);
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Search Field Widget
  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8EAF6), Color(0xFFF3E5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: ('Search members...').appTr,
          hintStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade600,
          ),
          suffixIcon: Icon(
            Icons.close,
            color: Colors.grey.shade600,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(
              color: Color(0xFFE5E2E6),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: const BorderSide(
              color: Color(0xffff5582),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // Agency member list item with fast delete option.
  Widget _buildFunListItem(Map<String, dynamic> userData) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _avatar(userData),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName(userData),
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  ('ID: ${_userId(userData)}').appTr,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.black.withOpacity(.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ('Status: ${_safeText(userData['status'])}').appTr,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(.45),
                  ),
                ),
              ],
            ),
          ),
          _deleteButton(userData),
        ],
      ),
    );
  }

  // Apply List Item - Your existing design + delete option.
  Widget _buildApplyListItem(Map<String, dynamic> agencyData) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[100],
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                _avatar(agencyData),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Castontext(
                        fontSize: Get.height * 0.016,
                        fontWeight: FontWeight.w600,
                        textColor: Colors.black.withOpacity(.6),
                        text: ('ID: ${_userId(agencyData)}').appTr,
                      ),
                      const SizedBox(height: 5),
                      Castontext(
                        fontSize: Get.height * 0.015,
                        fontWeight: FontWeight.w400,
                        textColor: Colors.black.withOpacity(.6),
                        text: ('Name: ${_userName(agencyData)}').appTr,
                      ),
                      const SizedBox(height: 4),
                      Castontext(
                        fontSize: Get.height * 0.014,
                        fontWeight: FontWeight.w400,
                        textColor: Colors.black.withOpacity(.6),
                        text: ('Status: ${_safeText(agencyData['status'])}').appTr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  final hostId =
                  informationcollectionController.agencyHostIdFrom(
                    agencyData,
                  );
                  informationcollectionController.AceptCreate(hostId: hostId);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: kWeight * 0.02,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kAppColor2, kAppColor1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      ('Accept').appTr,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: kHeight * 0.014,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: kHeight * 0.012),
              InkWell(
                onTap: () {
                  final hostId =
                  informationcollectionController.agencyHostIdFrom(
                    agencyData,
                  );
                  informationcollectionController.ARejectCreate(hostId: hostId);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: kWeight * 0.02,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kAppColor2, kAppColor1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      ('Reject').appTr,
                      style: GoogleFonts.lato(
                        color: Colors.white,
                        fontSize: kHeight * 0.014,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: kHeight * 0.012),
              _deleteButton(agencyData, compact: true),
            ],
          ),
        ],
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState({
    String? title,
    String? subTitle,
  }) {
    final String displayTitle =
        title ?? 'No Request Found'.appTr;

    final String displaySubTitle =
        subTitle ??
            'There are no new agency requests right now.'.appTr;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 60,
            color: Colors.grey.withOpacity(0.6),
          ),
          const SizedBox(height: 12),

          Text(
            displayTitle,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            displaySubTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
