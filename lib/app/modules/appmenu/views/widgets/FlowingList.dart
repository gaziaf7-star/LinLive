import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/constants.dart';
import '../../../../../constants/image_helper.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../../../widgets/after/castom appbar.dart';
import '../../../store/controllers/store1_controller.dart';
import 'game_test.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class FollowinfList extends StatefulWidget {
  const FollowinfList({super.key});

  @override
  State<FollowinfList> createState() => _FollowinfListState();
}

class _FollowinfListState extends State<FollowinfList> {
  late final Store1Controller controller;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<Store1Controller>()
        ? Get.find<Store1Controller>()
        : Get.put(Store1Controller());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.showFollowingList(silent: true);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _countryFlag(String country) {
    final text = country.trim().toLowerCase();
    if (text == 'bangladesh' || text == 'bd') return '🇧🇩';
    if (text == 'india' || text == 'in') return '🇮🇳';
    if (text == 'pakistan' || text == 'pk') return '🇵🇰';
    if (text == 'saudi arabia' || text == 'saudi' || text == 'sa') return '🇸🇦';
    if (text == 'united arab emirates' || text == 'uae' || text == 'ae') return '🇦🇪';
    return '🌐';
  }

  Future<void> _refresh() => controller.showFollowingList(silent: true);

  void _openVisitProfile(int userId) {
    if (userId <= 0) return;
    homeController.visitProfile(userId: userId.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: ('Following').appTr),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              _topSummary(),
              _searchBox(),
              Expanded(
                child: Obx(() {
                  final loading = controller.isFollowingLoading.value &&
                      controller.filteredFollowingList.isEmpty;
                  final list = controller.filteredFollowingList;

                  if (loading) return _loadingList();

                  if (list.isEmpty) {
                    return _emptyState(
                      title: ('No following yet').appTr,
                      subtitle: ('People you follow will appear here.').appTr,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        kWeight * .035,
                        kHeight * .010,
                        kWeight * .035,
                        kHeight * .030,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final user = controller.followingUser(item);
                        final userId = controller.userIdFromUserMap(user);

                        return _userCard(
                          item: item,
                          user: user,
                          userId: userId,
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topSummary() {
    return Obx(() {
      final total = controller.totalFollowingCount.value > 0
          ? controller.totalFollowingCount.value
          : controller.followingList.length;

      return Padding(
        padding: EdgeInsets.fromLTRB(
          kWeight * .04,
          kHeight * .012,
          kWeight * .04,
          kHeight * .010,
        ),
        child: Row(
          children: [
            Container(
              height: kHeight * .052,
              width: kHeight * .052,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xfff4efff),
                border: Border.all(color: const Color(0xffe9ddff)),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xff7b2cff)),
            ),
            SizedBox(width: kWeight * .030),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ('$total Following').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: kHeight * .020,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    ('Unfollow instantly and the list updates without reload.').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: kHeight * .012,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _searchBox() {
    return Padding(
      padding: EdgeInsets.fromLTRB(kWeight * .04, 0, kWeight * .04, kHeight * .012),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          controller.searchByFollowing(value);
          setState(() {});
        },
        style: GoogleFonts.poppins(fontSize: kHeight * .0135),
        decoration: InputDecoration(
          hintText: ('Search by name or ID').appTr,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Obx(() {
            return controller.isFollowingLoading.value
                ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : (searchController.text.trim().isEmpty
                ? const SizedBox.shrink()
                : IconButton(
              onPressed: () {
                searchController.clear();
                controller.searchByFollowing('');
                setState(() {});
              },
              icon: const Icon(Icons.close_rounded),
            ));
          }),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: kHeight * .015),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _userCard({
    required dynamic item,
    required Map<String, dynamic> user,
    required int userId,
  }) {
    final image = controller.userImage(user);
    final name = controller.userName(user);
    final country = controller.userCountry(user);
    final uid = (user['user_id'] ?? user['unique_id'] ?? userId).toString();

    return Container(
      margin: EdgeInsets.only(bottom: kHeight * .012),
      padding: EdgeInsets.all(kHeight * .012),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffede9fe)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openVisitProfile(userId),
            child: _avatar(image, item),
          ),
          SizedBox(width: kWeight * .030),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openVisitProfile(userId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: kHeight * .0155,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: kHeight * .004),
                  Row(
                    children: [                    Text(_countryFlag(country), style: TextStyle(fontSize: kHeight * .018)),
                      SizedBox(width: kWeight * .012),
                      Flexible(
                        child: Text(
                          ('ID $uid').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                            fontSize: kHeight * .011,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Obx(() {
            final loading = controller.followActionLoadingIds.contains(userId);
            return _unfollowButton(
              loading: loading,
              onTap: loading
                  ? null
                  : () => controller.unfollowUserFast(
                userId: userId,
                removeFromFollowingList: true,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _avatar(String image, dynamic item) {
    final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    final user = controller.followingUser(item);
    final asset = user['asset_purchase_history'] ?? map['asset_purchase_history'];
    String frame = '';
    if (asset is Map) {
      final assetMap = Map<String, dynamic>.from(asset);
      final nestedAsset = assetMap['asset'];
      if (nestedAsset is Map) {
        frame = (nestedAsset['asset'] ?? '').toString();
      } else {
        frame = (assetMap['asset'] ?? '').toString();
      }
    }

    return SizedBox(
      height: kHeight * .070,
      width: kHeight * .070,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: kHeight * .064,
            width: kHeight * .064,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xff8b5cf6), Color(0xffec4899)]),
            ),
            padding: const EdgeInsets.all(2.2),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: ImageHelper.getImageUrl(image),
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xffeee8ff)),
                errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
          if (frame.trim().isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: ImageHelper.getImageUrl(frame),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _unfollowButton({required bool loading, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: kWeight * .034, vertical: kHeight * .009),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: const Color(0xffffeef2),
          border: Border.all(color: const Color(0xffff6b8a).withOpacity(.45)),
        ),
        child: loading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(
          ('Unfollow').appTr,
          style: GoogleFonts.poppins(
            color: const Color(0xffff3f6b),
            fontSize: kHeight * .0118,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _loadingList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(kWeight * .035, kHeight * .010, kWeight * .035, 0),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        height: kHeight * .088,
        margin: EdgeInsets.only(bottom: kHeight * .012),
        decoration: BoxDecoration(
          color: const Color(0xfff7f4ff),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: kHeight * .16),
          Icon(Icons.person_add_disabled_rounded, size: kHeight * .070, color: Colors.grey.shade400),
          SizedBox(height: kHeight * .014),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: kHeight * .017),
          ),
          SizedBox(height: kHeight * .006),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: kHeight * .013),
          ),
        ],
      ),
    );
  }
}
