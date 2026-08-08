import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/setheight.dart';
import '../../backpack/controllers/store_controller.dart';
import '../../store/controllers/store1_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class GiftFollowerList extends StatefulWidget {
  const GiftFollowerList({super.key});

  @override
  State<GiftFollowerList> createState() => _GiftFollowerListState();
}

class _GiftFollowerListState extends State<GiftFollowerList> {
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
      store1controller.showFollowerList();
    });
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  String _fullImageUrl(dynamic path) {
    final imagePath = _safeText(path);
    if (imagePath.isEmpty) return '';

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    return ImageHelper.getImageUrl(imagePath);
  }

  Map<String, dynamic>? _activeFrameAsset(Map<String, dynamic> user) {
    final history = user['asset_purchase_history'];

    if (history == null || history is! Map) return null;

    final historyMap = Map<String, dynamic>.from(history);

    final status = _safeText(historyMap['status']).toLowerCase();
    if (status.isNotEmpty && status != 'active') return null;

    final asset = historyMap['asset'];
    if (asset == null || asset is! Map) return null;

    final assetMap = Map<String, dynamic>.from(asset);
    final assetPath = _safeText(assetMap['asset']);

    if (assetPath.isEmpty) return null;

    return assetMap;
  }

  Widget _profileFrame(Map<String, dynamic> user) {
    final asset = _activeFrameAsset(user);

    if (asset == null) {
      return const SizedBox.shrink();
    }

    final frameUrl = _fullImageUrl(asset['asset']);

    if (frameUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isSvga = frameUrl.toLowerCase().endsWith('.svga');

    return SizedBox(
      height: kHeight * 0.15,
      width: kHeight * 0.15,
      child: isSvga
          ? SVGAEasyPlayer(
        resUrl: frameUrl,
        fit: BoxFit.cover,
      )
          : CachedNetworkImage(
        imageUrl: frameUrl,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (c, u) => const SizedBox.shrink(),
        errorWidget: (c, u, e) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        child: Column(
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
                  store1controller.searchByUserId(value);
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
                if (store1controller.isLoading.value) {
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 20),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return _premiumShimmerCard();
                    },
                  );
                }

                if (store1controller.filteredFollowerList.isEmpty) {
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
                          ("No followers found").appTr,
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
                  itemCount: store1controller.filteredFollowerList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final follower = store1controller.filteredFollowerList[index];

                    final Map<String, dynamic> user =
                    Map<String, dynamic>.from(follower['user'] ?? {});

                    final String userId = _safeText(user['user_id']);
                    final String name =
                    _safeText(user['name'], fallback: ('Unknown User').appTr);
                    final String level = _safeText(user['level'], fallback: '0');
                    final String country =
                    _safeText(user['country'], fallback: ('Unknown').appTr);
                    final String gender =
                    _safeText(user['gender'], fallback: ('User').appTr);
                    final String totalFollowers =
                    _safeText(user['total_followers'], fallback: '0');

                    return _premiumUserCard(
                      user: user,
                      userId: userId,
                      name: name,
                      level: level,
                      country: country,
                      gender: gender,
                      totalFollowers: totalFollowers,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumUserCard({
    required Map<String, dynamic> user,
    required String userId,
    required String name,
    required String level,
    required String country,
    required String gender,
    required String totalFollowers,
  }) {
    final String profileUrl = _fullImageUrl(user['profile_image']);

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
              SizedBox(
                height: kHeight * 0.13,
                width: kHeight * 0.13,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: kHeight * 0.085,
                      width: kHeight * 0.085,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: profileUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholderFadeInDuration: Duration.zero,
                          placeholder: (c, u) => const SizedBox.shrink(),
                          errorWidget: (c, u, e) => const Icon(
                            Icons.person,
                            size: 34,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    // Profile Frame Show Here
                    _profileFrame(user),
                  ],
                ),
              ),

              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                  name,
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
                      text: totalFollowers,
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
                      kAppColor2,
                      kAppColor1
                    ]
                        : [
                      kAppColor2.withOpacity(.5),
                      kAppColor1.withOpacity(.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isSending
                          ? Colors.grey.withOpacity(0.22)
                          : const Color(0xFFFF9800).withOpacity(0.30),
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
                    const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ("Send").appTr,
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