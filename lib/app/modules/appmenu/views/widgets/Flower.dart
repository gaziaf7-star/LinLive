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

class Follower extends StatefulWidget {
  const Follower({super.key});

  @override
  State<Follower> createState() => _FollowerState();
}

class _FollowerState extends State<Follower> {
  late final Store1Controller controller;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<Store1Controller>()
        ? Get.find<Store1Controller>()
        : Get.put(Store1Controller());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshFollowPages(silent: true);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  int _currentUserId() {
    final dynamic raw = authController.userProfile.value.user?.id;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
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

  Future<void> _refresh() async {
    await controller.refreshFollowPages(silent: true);
  }

  void _openVisitProfile(int userId) {
    if (userId <= 0) return;
    homeController.visitProfile(userId: userId.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: ('Follower').appTr),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              _topSummary(),
              _searchBox(),
              Expanded(
                child: Obx(() {
                  final loading = controller.isLoading.value &&
                      controller.filteredFollowerList.isEmpty;
                  final list = controller.filteredFollowerList;

                  if (loading) return _loadingList();

                  if (list.isEmpty) {
                    return _emptyState(
                      title: ('No followers yet').appTr,
                      subtitle: ('Pull down to refresh follower list.').appTr,
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
                        final user = controller.followerUser(item);
                        final userId = controller.userIdFromUserMap(user);
                        final isMe = userId > 0 && userId == _currentUserId();

                        return _userCard(
                          user: user,
                          item: item,
                          userId: userId,
                          isMe: isMe,
                          removeFromFollowingList: false,
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
      final total = controller.totalFollowerCount.value > 0
          ? controller.totalFollowerCount.value
          : controller.followerList.length;

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
              child: const Icon(Icons.people_alt_rounded, color: Color(0xff7b2cff)),
            ),
            SizedBox(width: kWeight * .030),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ('$total Followers').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: kHeight * .020,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    ('Follow back instantly and keep your list updated.').appTr,
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
      padding: EdgeInsets.fromLTRB(
        kWeight * .04,
        0,
        kWeight * .04,
        kHeight * .012,
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          controller.searchByUserId(value);
          setState(() {});
        },
        style: GoogleFonts.poppins(fontSize: kHeight * .0135),
        decoration: InputDecoration(
          hintText: ('Search by name or ID').appTr,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Obx(() {
            return controller.isLoading.value
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
                controller.searchByUserId('');
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
    required Map<String, dynamic> user,
    required dynamic item,
    required int userId,
    required bool isMe,
    required bool removeFromFollowingList,
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
            child: _avatar(image),
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
                    children: [
                      SizedBox(width: kWeight * .012),
                      Text(
                        _countryFlag(country),
                        style: TextStyle(fontSize: kHeight * .018),
                      ),
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
          if (!isMe)
            Obx(() {
              final loading = controller.followActionLoadingIds.contains(userId);
              final following = controller.isUserFollowing(userId, item: item);
              return _followButton(
                loading: loading,
                following: following,
                onTap: loading
                    ? null
                    : () => controller.toggleFollowUser(
                  userId: userId,
                  currentlyFollowing: following,
                  removeFromFollowingList: false,
                  userData: user,
                ),
              );
            })
          else
            _selfBadge(),
        ],
      ),
    );
  }

  Widget _avatar(String image) {
    return Container(
      height: kHeight * .064,
      width: kHeight * .064,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xff8b5cf6), Color(0xffec4899)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff8b5cf6).withOpacity(.22),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
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
    );
  }

  Widget _followButton({
    required bool loading,
    required bool following,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * .035,
          vertical: kHeight * .009,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: following
              ? null
              : const LinearGradient(colors: [Color(0xff9d67fd), Color(0xffc87efd)]),
          color: following ? const Color(0xfff1ecff) : null,
          border: Border.all(color: following ? const Color(0xff9d67fd) : Colors.transparent),
        ),
        child: loading
            ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(
          following ? 'Following': ('Follow').appTr,
          style: GoogleFonts.poppins(
            fontSize: kHeight * .0118,
            fontWeight: FontWeight.w800,
            color: following ? const Color(0xff7b2cff) : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _selfBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: kWeight * .032, vertical: kHeight * .008),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        ('You').appTr,
        style: GoogleFonts.poppins(
          color: Colors.grey.shade700,
          fontSize: kHeight * .0115,
          fontWeight: FontWeight.w800,
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
          Icon(Icons.people_outline_rounded, size: kHeight * .070, color: Colors.grey.shade400),
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
