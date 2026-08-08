import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ProfileContributionList extends StatelessWidget {
  final bool isMonthlyMode;
  final String filterKey;
  final Future<void> Function() onRefresh;

  const ProfileContributionList({
    super.key,
    required this.isMonthlyMode,
    required this.filterKey,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final list = myprofileController.profileContributionList;

    return Obx(() {
      final contributions = myprofileController.profileContributionList;
      final selfData = _findSelfData(contributions);

      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: onRefresh,
            color: kAppColor1,
            child: contributions.isEmpty
                ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * .22),
                Icon(
                  Icons.emoji_events_outlined,
                  size: 70,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    ('No Top Gifter Found').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade700,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    ('No ranking data available for this filter.').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            )
                : ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 98),
              itemCount: contributions.length,
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(contributions[index]);
                return _rankingRow(context, item, index);
              },
            ),
          ),
          _bottomSelfCard(context, selfData),
        ],
      );
    });
  }

  Map<String, dynamic>? _findSelfData(List<dynamic> contributions) {
    final currentId = authController.userProfile.value.user?.id?.toString();
    if (currentId == null) return null;

    for (int i = 0; i < contributions.length; i++) {
      final item = Map<String, dynamic>.from(contributions[i]);
      final sender = Map<String, dynamic>.from(item['sender'] ?? {});
      if (sender['id']?.toString() == currentId || item['sender_id']?.toString() == currentId) {
        item['__rank__'] = i + 1;
        return item;
      }
    }
    return null;
  }

  Widget _rankingRow(BuildContext context, Map<String, dynamic> item, int index) {
    final sender = Map<String, dynamic>.from(item['sender'] ?? {});
    final rank = index + 1;
    final bgColor = _rankBackground(rank);
    final rankColor = _rankColor(rank);
    final profileImage = sender['profile_image']?.toString() ?? '';
    final name = sender['name']?.toString() ?? ('Unknown User').appTr;
    final totalCoin = _toInt(item['total_coin']);
    final expValue = _toInt(sender['gifts_coins']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: .7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: rankColor,
                fontSize: rank <= 3 ? 22 : 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _avatarWithFrame(item, rank: rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff21243A),
                    fontSize: rank <= 3 ? 16 : 15,
                    fontWeight: rank <= 3 ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 14,
                  runSpacing: 2,
                  children: [
                    Text(
                      ('Lit Gifts:${_formatCompact(totalCoin)}').appTr,
                      style: GoogleFonts.poppins(
                        color: rank <= 3
                            ? const Color(0xff7E4F17)
                            : const Color(0xff8A8FA3),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ('Exp:${_formatCompact(expValue)}').appTr,
                      style: GoogleFonts.poppins(
                        color: rank <= 3
                            ? const Color(0xff7E4F17)
                            : const Color(0xff8A8FA3),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarWithFrame(Map<String, dynamic> contributor, {required int rank}) {
    final sender = Map<String, dynamic>.from(contributor['sender'] ?? {});
    final assetHistory = sender['asset_purchase_history'];
    final assetPath = assetHistory?['asset']?['asset']?.toString();
    final frameUrl = (assetPath != null && assetPath.isNotEmpty)
        ? ImageHelper.getImageUrl(assetPath)
        : null;
    final profileUrl = ImageHelper.getImageUrl(sender['profile_image']?.toString() ?? '');

    final ringColor = rank == 1
        ? const Color(0xffF3C63A)
        : rank == 2
        ? const Color(0xffA2C8FF)
        : rank == 3
        ? const Color(0xffF7C9A4)
        : Colors.white;

    return SizedBox(
      height: 66,
      width: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (frameUrl != null && frameUrl.toLowerCase().endsWith('.svga'))
            Positioned.fill(
              child: SVGAEasyPlayer(
                resUrl: frameUrl,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: rank <= 3 ? 2.2 : 1.6),
                image: frameUrl != null && frameUrl.isNotEmpty && !frameUrl.toLowerCase().endsWith('.svga')
                    ? DecorationImage(image: NetworkImage(frameUrl), fit: BoxFit.cover)
                    : null,
              ),
            ),
          Container(
            height: 49,
            width: 49,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 1.8),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: profileUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.person),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomSelfCard(BuildContext context, Map<String, dynamic>? selfData) {
    final authUser = authController.userProfile.value.user;
    final sender = selfData != null ? Map<String, dynamic>.from(selfData['sender'] ?? {}) : <String, dynamic>{};
    final rankText = selfData != null ? '${selfData['__rank__']}' : '-';
    final totalCoin = selfData != null ? _formatCompact(_toInt(selfData['total_coin'])) : '0';
    final expValue = selfData != null ? _formatCompact(_toInt(sender['gifts_coins'])) : '0';
    final name = sender['name']?.toString() ?? authUser?.name?.toString() ?? ('Unknown').appTr;
    final profile = sender['profile_image']?.toString() ?? authUser?.profileImage?.toString() ?? '';

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: const Color(0xffEEF3FB),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: const BoxDecoration(
                color: Color(0xff91A8B6),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: profile.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(profile),
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => _nameFallback(name),
                )
                    : _nameFallback(name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xff1F2430),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ('Lit Gifts:$totalCoin    Exp:$expValue').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xff81879A),
                      fontSize: 12.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ('Ranking').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff8C90A3),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rankText,
                  style: GoogleFonts.poppins(
                    color: const Color(0xff10141F),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameFallback(String name) {
    final first = name.isNotEmpty ? name[0].toUpperCase() : ('U').appTr;
    return Center(
      child: Text(
        first,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _rankBackground(int rank) {
    if (rank == 1) return const Color(0xffF4FBD8);
    if (rank == 2) return const Color(0xffEEF4FF);
    if (rank == 3) return const Color(0xffFFF1E8);
    return Colors.white;
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xffF09A1B);
    if (rank == 2) return const Color(0xff7FA8D8);
    if (rank == 3) return const Color(0xffD59464);
    return const Color(0xffB9BDC9);
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatCompact(dynamic value) {
    final number = _toInt(value);
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed((number / 1000000000) >= 10 ? 0 : 1)}B';
    }
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed((number / 1000000) >= 10 ? 0 : 1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed((number / 1000) >= 10 ? 0 : 1)}K';
    }
    return number.toString();
  }
}
