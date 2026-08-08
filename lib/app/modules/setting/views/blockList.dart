import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castom appbar.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class BlockListPage extends StatefulWidget {
  const BlockListPage({super.key});

  @override
  State<BlockListPage> createState() => _BlockListPageState();
}

class _BlockListPageState extends State<BlockListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => homeController.getBlockedUserList());
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _normalizeBlockedUser(dynamic item) {
    if (item is! Map) return <String, dynamic>{};

    final Map<String, dynamic> root = Map<String, dynamic>.from(item);

    final dynamic blockedRaw =
        root['blocked_user'] ?? root['user'] ?? root['blocked'];

    Map<String, dynamic> user = <String, dynamic>{};

    if (blockedRaw is Map) {
      user = Map<String, dynamic>.from(blockedRaw);
    } else {
      user = Map<String, dynamic>.from(root);
    }

    /// Keep root block data for fallback
    user['__block_row_id'] = root['id'];
    user['__blocker_id'] = root['blocker_id'];
    user['__blocked_id'] = root['blocked_id'];

    return user;
  }

  String _safeText(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  String _userAvatar(Map<String, dynamic> user) {
    final raw = user['image_url'] ??
        user['profile_image'] ??
        user['profileImage'] ??
        user['avatar'] ??
        user['image'] ??
        user['photo'];

    final text = raw?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return ImageHelper.getImageUrl(text);
  }

  int _blockedUserId(Map<String, dynamic> user) {
    return _safeInt(
      user['id'] ??
          user['user_id'] ??
          user['blocked_id'] ??
          user['__blocked_id'],
    );
  }

  String _displayUserId(Map<String, dynamic> user) {
    final id = user['unique_id'] ??
        user['user_id'] ??
        user['id'] ??
        user['__blocked_id'];

    final text = id?.toString().trim() ?? '';

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xfff6f3fb),
      appBar: CustomAppBar(title: ('Block List').appTr),
      body: Obx(() {
        if (homeController.blockListLoading.value &&
            homeController.blockedUserList.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (homeController.blockedUserList.isEmpty) {
          return _emptyView();
        }

        return RefreshIndicator(
          onRefresh: () => homeController.getBlockedUserList(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: homeController.blockedUserList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dynamic item = homeController.blockedUserList[index];
              final Map<String, dynamic> user = _normalizeBlockedUser(item);

              final int userId = _blockedUserId(user);

              final String name = _safeText(
                user['name'] ?? user['full_name'] ?? user['username'],
                ('Unknown User').appTr,
              );

              final String displayId = _displayUserId(user);
              final String avatar = _userAvatar(user);

              final bool isLoading =
              homeController.unblockLoadingIds.contains(userId);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    radius: height * 0.033,
                    backgroundColor: Colors.grey.shade200,
                    child: ClipOval(
                      child: avatar.isEmpty
                          ? Icon(
                        Icons.person,
                        color: Colors.grey.shade600,
                        size: height * 0.034,
                      )
                          : CachedNetworkImage(
                        imageUrl: avatar,
                        height: height * 0.066,
                        width: height * 0.066,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person,
                          color: Colors.grey.shade600,
                          size: height * 0.034,
                        ),
                        placeholder: (_, __) =>
                        const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      displayId.isEmpty ? ('Blocked').appTr: ('ID: $displayId • Blocked').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: userId == 0 || isLoading
                        ? null
                        : () {
                      homeController.userUnBlock(userId: userId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAppColor,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? SizedBox(
                      height: height * 0.018,
                      width: height * 0.018,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Castontext(
                      fontWeight: FontWeight.w500,
                      textColor: Colors.white,
                      fontSize: height * 0.0125,
                      text: ('Unblock').appTr,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _emptyView() {
    return RefreshIndicator(
      onRefresh: () => homeController.getBlockedUserList(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: kHeight * 0.20),
          Icon(
            Icons.block_rounded,
            size: kHeight * 0.075,
            color: Colors.grey,
          ),
          const SizedBox(height: 14),
          Text(
            ('No blocked users').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ('Users you block will appear here.').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}