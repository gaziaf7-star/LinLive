import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/color_constants.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../apis/api_endpoints.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../../../widgets/setheight.dart';
import '../../../backpack/controllers/store_controller.dart';
import '../../controllers/store1_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class GiftFollowinglist extends StatefulWidget {
  const GiftFollowinglist({super.key});

  @override
  State<GiftFollowinglist> createState() => _GiftFollowinglistState();
}

class _GiftFollowinglistState extends State<GiftFollowinglist> {
  late final Store1Controller store1controller;
  late final StoreController storeController;

  @override
  void initState() {
    super.initState();

    store1controller = Get.isRegistered<Store1Controller>()
        ? Get.find<Store1Controller>()
        : Get.put(Store1Controller());

    storeController = Get.isRegistered<StoreController>()
        ? Get.find<StoreController>()
        : Get.put(StoreController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      store1controller.showFollowingList();
    });
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String _baseUrlWithoutApi() {
    String baseUrl = kMainUrl.trim();

    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }

    return baseUrl;
  }

  String _fullImageUrl(dynamic path) {
    String imagePath = _safeText(path);

    if (imagePath.isEmpty) return '';

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    if (imagePath.startsWith('/')) {
      imagePath = imagePath.substring(1);
    }

    return '${_baseUrlWithoutApi()}/$imagePath';
  }

  Map<String, dynamic>? _activeFrameAsset(Map<String, dynamic> followingUser) {
    final history = followingUser['asset_purchase_history'];

    if (history == null || history is! Map) {
      return null;
    }

    final historyMap = Map<String, dynamic>.from(history);

    final status = _safeText(historyMap['status']).toLowerCase();
    if (status.isNotEmpty && status != 'active') {
      return null;
    }

    final asset = historyMap['asset'];

    if (asset == null || asset is! Map) {
      return null;
    }

    final assetMap = Map<String, dynamic>.from(asset);
    final assetPath = _safeText(assetMap['asset']);

    if (assetPath.isEmpty) {
      return null;
    }

    return assetMap;
  }

  Widget _profileWithFrame(Map<String, dynamic> followingUser) {
    final String userName = _safeText(
      followingUser['name'],
      fallback: ('User').appTr,
    );

    final String profileImage = _fullImageUrl(
      followingUser['profile_image'],
    );

    return SizedBox(
      height: 74,
      width: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: profileImage.isNotEmpty
                  ? profileImage
                  : 'https://ui-avatars.com/api/?name=$userName',
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.account_circle,
                size: 48,
                color: Colors.grey,
              ),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),

          // Active Frame / SVGA frame
          _frameWidget(followingUser),
        ],
      ),
    );
  }

  Widget _frameWidget(Map<String, dynamic> followingUser) {
    final asset = _activeFrameAsset(followingUser);

    if (asset == null) {
      return const SizedBox.shrink();
    }

    final String frameUrl = _fullImageUrl(asset['asset']);

    if (frameUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isSvga = frameUrl.toLowerCase().endsWith('.svga');

    return SizedBox(
      height: 74,
      width: 74,
      child: isSvga
          ? SVGAEasyPlayer(
        key: ValueKey(frameUrl),
        resUrl: frameUrl,
        fit: BoxFit.cover,
      )
          : CachedNetworkImage(
        imageUrl: frameUrl,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: Column(
        children: [
          SetHeight(heightSet: 0.02),

          Container(
            margin: EdgeInsets.symmetric(horizontal: kWeight * 0.04),
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextFormField(
              onChanged: (value) {
                store1controller.searchByFollowing(value);
              },
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF222222),
              ),
              decoration: InputDecoration(
                hintText: ("Search by User ID...").appTr,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[600],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          SetHeight(heightSet: 0.012),

          Expanded(
            child: Obx(() {
              if (store1controller.isFollowingLoading.value) {
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return _premiumShimmerCard();
                  },
                );
              }

              if (store1controller.filteredFollowingList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 92,
                        width: 92,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        ("No following found").appTr,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ("Try searching with another user ID").appTr,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 6, bottom: 20),
                itemCount: store1controller.filteredFollowingList.length,
                itemBuilder: (BuildContext context, int index) {
                  final follower =
                  store1controller.filteredFollowingList[index];

                  final followingRaw = follower['following'];

                  if (followingRaw == null || followingRaw is! Map) {
                    return const SizedBox.shrink();
                  }

                  final Map<String, dynamic> followingUser =
                  Map<String, dynamic>.from(followingRaw);

                  final String userName = _safeText(
                    followingUser['name'],
                    fallback: ('User').appTr,
                  );

                  final String userId = _safeText(
                    followingUser['user_id'],
                    fallback: 'N/A',
                  );

                  final String level = _safeText(
                    followingUser['level'],
                    fallback: '0',
                  );

                  final String country = _safeText(
                    followingUser['country'],
                    fallback: ('Unknown').appTr,
                  );

                  final String gender = _safeText(
                    followingUser['gender'],
                    fallback: ('User').appTr,
                  );

                  final String followers = _safeText(
                    followingUser['total_followers'],
                    fallback: '0',
                  );

                  final String isOnline = _safeText(
                    followingUser['is_online'],
                    fallback: 'false',
                  );

                  return _followingCard(
                    followingUser: followingUser,
                    userName: userName,
                    userId: userId,
                    level: level,
                    country: country,
                    gender: gender,
                    followers: followers,
                    isOnline: isOnline,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _followingCard({
    required Map<String, dynamic> followingUser,
    required String userName,
    required String userId,
    required String level,
    required String country,
    required String gender,
    required String followers,
    required String isOnline,
  }) {
    final bool online = isOnline.toLowerCase() == 'true';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _profileWithFrame(followingUser),

              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    ("Lv $level").appTr,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E1E1E),
                  ),
                ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    Icon(
                      Icons.badge_rounded,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        ("UID: $userId").appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _miniBadge(
                      icon: Icons.public_rounded,
                      text: country,
                    ),
                    _miniBadge(
                      icon: gender.toLowerCase() == "female"
                          ? Icons.female_rounded
                          : Icons.male_rounded,
                      text: gender,
                    ),
                    _miniBadge(
                      icon: Icons.people_alt_rounded,
                      text: followers,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Obx(() {
            final bool isSending =
                storeController.sendingUserId.value == userId;

            return GestureDetector(
              onTap: isSending
                  ? null
                  : () {
                storeController.sendingAsset(userId: userId);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 42,
                width: 86,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSending
                        ? [
                      const Color(0xFFBDBDBD),
                      const Color(0xFF9E9E9E),
                    ]
                        : online
                        ? [
                      const Color(0xFF4CAF50),
                      const Color(0xFF2E7D32),
                    ]
                        : [
                      kAppColor,
                      kAppColor2,

                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isSending
                          ? Colors.grey.withOpacity(0.22)
                          : online
                          ? Colors.green.withOpacity(0.28)
                          :kAppColor.withOpacity(0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: isSending
                    ? const SizedBox(
                  height: 19,
                  width: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      online
                          ? Icons.circle_rounded
                          : Icons.send_rounded,
                      color: Colors.white,
                      size: online ? 11 : 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      online ? ("Online").appTr: ("Send").appTr,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEFEFEF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              height: 62,
              width: 62,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 140,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        height: 18,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 18,
                        width: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 42,
              width: 86,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}