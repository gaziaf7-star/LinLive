import 'dart:convert';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/appmenu_view.dart';
import 'package:meetlivepro/app/modules/myprofile/views/widgets/CpcardPage.dart';
import 'package:meetlivepro/app/modules/myprofile/views/widgets/fullGiftReceiverPage.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomContainer.dart';

import '../../../../widgets/buildIconbutton.dart';
import '../../appmenu/views/widgets/Flower.dart';
import '../../appmenu/views/widgets/FlowingList.dart';

import '../../appmenu/views/widgets/game_test.dart';
import '../../home/views/widgets/unicId.dart';
import '../../home/views/widgets/unicId2.dart';
import '../../livestream/widgets/audioText.dart';
import '../../Famaily/view/my_family_api_page.dart';
import '../controllers/myprofile_controller.dart';
import 'EditProfile.dart';
import 'ProfileConribution.dart';
import 'animationUserProfile.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
Future<dynamic>? _profileCpFuture;
dynamic _profileCpDataCache;
Future<dynamic>? _profileFamilyFuture;
String _profileFamilyFutureUserId = '';
int _cpDebugBuildCount = 0;
int _cpDebugApiCount = 0;

// ===============================================================
// ✅ VIP TITLE FRAME BESIDE LEVEL - PROFILE PAGE
// Same system as App Menu: active VIP thakle level-er pashe title frame show hobe.
// Active VIP na thakle kono fake/default frame show korbe na.
// ===============================================================
int _profileAuthUserId() {
  final dynamic rawId = authController.userProfile.value.user?.id;

  if (rawId is num) return rawId.toInt();
  return int.tryParse(rawId?.toString().trim() ?? '') ?? 0;
}

int _profileVipSafeInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

bool _profileVipDataBelongsToUser(dynamic vipData, int userId) {
  if (userId <= 0 || vipData is! Map) return false;

  final map = Map<String, dynamic>.from(vipData);
  return _profileVipSafeInt(map['user_id']) == userId;
}

DateTime? _profileVipParseDate(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;

  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

bool _profileVipIsActive(dynamic value) {
  if (value is! Map) return false;

  final map = Map<String, dynamic>.from(value);
  final String status = (map['status'] ?? '').toString().trim().toLowerCase();
  final dynamic rawActive = map['is_active'];

  final bool isActive = rawActive == true ||
      rawActive == 1 ||
      rawActive?.toString().trim().toLowerCase() == 'true' ||
      status == 'active';

  if (!isActive || map['vip_level'] is! Map) {
    return false;
  }

  final DateTime? expiresAt = _profileVipParseDate(map['expires_at']);
  if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
    return false;
  }

  return true;
}

Map<String, dynamic> _profileVipLevel(dynamic vipData) {
  if (!_profileVipIsActive(vipData)) return <String, dynamic>{};

  final dynamic level = (vipData as Map)['vip_level'];
  if (level is Map<String, dynamic>) return level;
  if (level is Map) return Map<String, dynamic>.from(level);

  return <String, dynamic>{};
}

String _profileCleanVipImage(dynamic value) {
  final String path = value?.toString().trim() ?? '';

  if (path.isEmpty || path.toLowerCase() == 'null') {
    return '';
  }

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  if (path.startsWith('assets/')) {
    return path;
  }

  return ImageHelper.getImageUrl(path);
}

String _profileActiveVipTitleImage(dynamic vipData) {
  if (!_profileVipIsActive(vipData)) return '';

  final Map<String, dynamic> level = _profileVipLevel(vipData);
  final String rawPath = (level['title_image_url'] ??
      level['title_image'] ??
      level['badge_image_url'] ??
      level['badge_image'] ??
      '')
      .toString()
      .trim();

  if (rawPath.isEmpty || rawPath.toLowerCase() == 'null') return '';

  return _profileCleanVipImage(rawPath);
}

Widget _profileCurrentVipTitleImageBadge() {
  return Obx(() {
    final int userId = _profileAuthUserId();

    final Map<String, dynamic>? cachedVip =
    userId > 0 ? homeController.currentVipForUser(userId) : null;

    final Map<String, dynamic>? currentVip = homeController.vipCurrentData.value;

    final Map<String, dynamic>? vipData = cachedVip ??
        (_profileVipDataBelongsToUser(currentVip, userId) ? currentVip : null);

    final String imagePath = _profileActiveVipTitleImage(vipData);

    if (imagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    final double badgeHeight = kHeight * 0.039;
    final double badgeWidth = kWeight * 0.23;

    Widget imageWidget;

    if (imagePath.toLowerCase().endsWith('.svga')) {
      imageWidget = SVGAEasyPlayer(
        resUrl: imagePath,
        fit: BoxFit.contain,
      );
    } else if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      );
    } else {
      imageWidget = Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    }

    return Container(
      height: badgeHeight,
      width: badgeWidth,
      alignment: Alignment.center,
      margin: EdgeInsets.only(left: kWeight * 0.012),
      child: imageWidget,
    );
  });
}

// ===============================================================
// ✅ VIP TITLE FRAME BESIDE LEVEL - END
// ===============================================================

class MyProfileView extends StatelessWidget {
  const MyProfileView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String name = authController.userProfile.value.user!.name ?? '';
    String shortName = name.length > 14 ? '${name.substring(0, 14)}...' : name;
    print(
      'User Profile Data ${authController.userProfile.value.user!.userType}',
    );
    MyprofileController myprofileController = Get.put(MyprofileController());

    final String profileUserId =
        authController.userProfile.value.user?.id?.toString() ?? '';
    if (profileUserId.isNotEmpty &&
        (_profileFamilyFuture == null ||
            _profileFamilyFutureUserId != profileUserId)) {
      _profileFamilyFutureUserId = profileUserId;
      _profileFamilyFuture =
          myprofileController.showProfileFamilyData(userID: profileUserId);
    }

    // ✅ VIP WORK: Profile page open hole current user-er active VIP frame load hobe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final int vipUserId = _profileAuthUserId();
      if (vipUserId > 0) {
        homeController.fetchUserCurrentVip(
          userId: vipUserId,
          force: false,
          silent: true,
        );
      }
    });

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              //user cover image  show bottom sheet
              Container(
                height: Get.height * 0.45,
                decoration: BoxDecoration(
                  image:
                  (authController.userProfile.value.user?.coverImages ==
                      null ||
                      authController.userProfile.value.user?.coverImages ==
                          "" ||
                      authController.userProfile.value.user?.coverImages ==
                          "No Photo")
                      ? DecorationImage(
                    image: AssetImage('assets/images/profile pic.jpg'),
                    fit: BoxFit.cover,
                  )
                      : DecorationImage(
                    image: NetworkImage(
                      '$kDomainUrl/${authController.userProfile.value.user!
                          .coverImages}',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () {
                                  Get.back();
                                },
                                child: Container(
                                  margin: EdgeInsets.only(left: 20),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: LinearGradient(
                                      colors: [
                                        kAppColor1,
                                        kAppColor2
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_outlined,
                                    color: Colors.white,
                                    size: kHeight * 0.02,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0, top: 25),
                                child: topIconbutton(
                                  onPressed: () {
                                    Get.to(
                                      Editprofile(),
                                      transition: Transition.rightToLeft,
                                    );
                                  },
                                  icon: const Icon(Icons.edit),
                                  colour: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                    ),
                    Positioned(
                      top: Get.height * 0.075,
                      left: kHeight * 0.02,
                      right: 0,
                      child: _profileHeaderOverlay(
                        myprofileController: myprofileController,
                        shortName: shortName,
                      ),
                    ),
                  ],
                ),
              ),

              //----------------profile -------------------
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(40),
                    topLeft: Radius.circular(40),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: kHeight * 0.018),

                        // ---------------------level identity -------------------
                        Row(
                          children: [
                            SizedBox(width: 12),
                            Text(
                              ('Identity').appTr,
                              style: GoogleFonts.roboto(
                                fontSize: kHeight * 0.019,
                                color: Colors.black.withOpacity(.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        userTypeBadges(
                          userType: authController.userProfile.value.user?.userType,
                          agencyType: authController.userProfile.value.user?.agencyType,
                          reselerType: authController.userProfile.value.user?.reselerType,
                          hostType: authController.userProfile.value.user?.hostType,
                          kHeight: kHeight,
                        ),

                        SizedBox(height: kHeight * 0.015),
                        Row(
                          children: [
                            SizedBox(width: 12),
                            Text(
                              ('Top Gifter').appTr,
                              style: GoogleFonts.roboto(
                                fontSize: kHeight * 0.019,
                                color: Colors.black.withOpacity(.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        _topGifterSection(myprofileController),
                        Row(
                          children: [
                            SizedBox(width: 12),
                            Text(
                              ('Agency').appTr,
                              style: GoogleFonts.roboto(
                                fontSize: kHeight * 0.019,
                                color: Colors.black.withOpacity(.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Obx(() {
                          final String hostType = authController
                              .userProfile
                              .value
                              .user
                              ?.hostType
                              ?.toString()
                              .trim()
                              .toLowerCase() ??
                              '';

                          debugPrint('Profile card hostType => [$hostType]');

                          if (hostType != 'host') {
                            return const SizedBox.shrink();
                          }

                          return const LightSweepContainer2();
                        }),
                        Row(
                          children: [
                            SizedBox(width: 12),
                            Text(
                              ('Cp').appTr,
                              style: GoogleFonts.roboto(
                                fontSize: kHeight * 0.019,
                                color: Colors.black.withOpacity(.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),


                        _profilePremiumCpCardSection(),

                        _profileFamilySection(
                          myprofileController,
                          familyFuture: _profileFamilyFuture,
                        ),

                        Row(
                          children: [
                            SizedBox(width: 12),
                            Text(
                              ('Gifts - Received').appTr,
                              style: GoogleFonts.roboto(
                                fontSize: kHeight * 0.019,
                                color: Colors.black.withOpacity(.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: kHeight * 0.01),
                        Padding(
                          padding: EdgeInsets.only(left: kHeight * 0.012),
                          child: FutureBuilder(
                            future: myprofileController.showProfileReciverList(userID: '${authController.userProfile.value.user?.id}'),
                            builder: (context, snapshot) {
                              final receiverList = myprofileController.profileGiftReceverList;

                              /// ✅ giftsr_data er vitorer sob gifts ek list e ana hocche
                              final List<Map<String, dynamic>> allGiftList = [];

                              for (final receiver in receiverList) {
                                if (receiver is Map) {
                                  final sender = receiver['sender'];
                                  final gifts = receiver['gifts'];

                                  if (gifts is List) {
                                    for (final giftItem in gifts) {
                                      if (giftItem is Map) {
                                        allGiftList.add({
                                          ...Map<String, dynamic>.from(giftItem),
                                          'sender': sender,
                                          'sender_total_coins': receiver['total_coins'],
                                          'gift_receive_count': receiver['gift_receive_count'],
                                        });
                                      }
                                    }
                                  }
                                }
                              }

                              if (snapshot.connectionState == ConnectionState.waiting &&
                                  allGiftList.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (allGiftList.isEmpty) {
                                return const SizedBox();
                              }

                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.022),
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  primary: false,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5, // ✅ row te 5 ta kore
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    mainAxisExtent: kHeight * 0.085,
                                  ),
                                  itemCount: allGiftList.length, // ✅ all nested gifts show hobe
                                  itemBuilder: (context, index) {
                                    final item = allGiftList[index];

                                    final giftData = item['gift'];

                                    final giftImage = giftData != null
                                        ? ImageHelper.getImageUrl(giftData['show_image'])
                                        : null;

                                    final giftCount = item['count'] ?? 0;

                                    return GestureDetector(
                                      onTap: () {},
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0x85D9C0F8),
                                              Color(0xCA8C6AF0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0x85FA8B3C),
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (giftImage != null)
                                                giftImage.toString().endsWith('.svga')
                                                    ? SVGAEasyPlayer(
                                                  resUrl: "$giftImage",
                                                  fit: BoxFit.cover,
                                                )
                                                    : CachedNetworkImage(
                                                  imageUrl: '$giftImage',
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorWidget: (context, url, error) => Icon(
                                                    Icons.error,
                                                    size: kHeight * 0.035,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  Icons.card_giftcard,
                                                  size: kHeight * 0.035,
                                                  color: Colors.white54,
                                                ),

                                              /// ✅ gift count badge
                                              if (giftCount != null && giftCount != 0)
                                                Positioned(
                                                  right: 2,
                                                  bottom: 2,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.55),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      ('x$giftCount').appTr,
                                                      style: GoogleFonts.roboto(
                                                        color: Colors.white,
                                                        fontSize: kHeight * 0.010,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 15),
                      ], //fast row end
                    ),

                  ],
                ),
              ),
              SizedBox(height: kHeight * 0.05),
            ],
          ),
        ),
      ),
    );
  }
}

String _currentProfileUserId() {
  return authController.userProfile.value.user?.id?.toString() ?? '';
}

Widget _profileFamilySection(
    MyprofileController myprofileController, {
      required Future<dynamic>? familyFuture,
    }) {
  return FutureBuilder<dynamic>(
    future: familyFuture,
    builder: (context, snapshot) {
      return Obx(() {
        final family = myprofileController.profileFamilyData.value;
        final isLoading = myprofileController.isProfileFamilyLoading.value;

        if (family == null &&
            (snapshot.connectionState == ConnectionState.waiting || isLoading)) {
          return Padding(
            padding: EdgeInsets.only(top: kHeight * 0.010),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileSectionTitle(('Family').appTr),
                _profileFamilyCardShimmer(),
              ],
            ),
          );
        }

        if (family == null) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(top: kHeight * 0.010),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _profileSectionTitle(('Family').appTr),
              _profileFamilyCard(family),
            ],
          ),
        );
      });
    },
  );
}

Widget _profileSectionTitle(String title) {
  return Row(
    children: [
      const SizedBox(width: 12),
      Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: kHeight * 0.019,
          color: Colors.black.withOpacity(.8),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _profileFamilyCardShimmer() {
  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: Get.width * 0.020,
      vertical: kHeight * 0.006,
    ),
    child: Container(
      height: kHeight * 0.125,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B3043).withOpacity(.72),
            const Color(0xFF16605D).withOpacity(.62),
            const Color(0xFF2BBE9F).withOpacity(.52),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

Widget _profileFamilyCard(Map<String, dynamic> family) {
  final int familyId = _familyInt(family['id']);
  final String name = _familyText(family['name'], fallback: ('Family').appTr);
  final String familyCode = _familyText(
    family['family_code'],
    fallback: familyId > 0 ? '$familyId' : '',
  );
  final String logoUrl = _familyImageUrl(family['logo_url'] ?? family['logo']);
  final int levelNo = _familyInt(family['level_no']);
  final int membersCount = _familyInt(family['members_count']);
  final int memberLimit = _familyInt(family['member_limit']);

  final Map<String, dynamic> badge = _familyMap(family['badge']);
  final String badgeName = _familyText(
    badge['name'],
    fallback: 'Family Badge',
  );
  final int badgeLevel = _familyInt(badge['badge_level']);

  final Map<String, dynamic> userMember = _familyMap(family['user_member']);
  final String role = _familyText(userMember['role'], fallback: 'member');
  final String roleText = role.isEmpty
      ? 'Member': '${role[0].toUpperCase()}${role.length > 1 ? role.substring(1) : ''}';

  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: Get.width * 0.020,
      vertical: kHeight * 0.006,
    ),
    child: InkWell(
      onTap: familyId <= 0
          ? null
          : () {
        Get.to(
              () => MyFamilyApiPage(
            familyId: familyId,
            readOnly: true,
          ),
          transition: Transition.rightToLeft,
        );
      },
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: kHeight * 0.125,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF072B3A),
              Color(0xFF0D5B5B),
              Color(0xFF18A789),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D5B5B).withOpacity(.26),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ProfileFamilyCardPatternPainter(),
              ),
            ),
            Positioned(
              right: -kHeight * 0.030,
              top: -kHeight * 0.045,
              child: Container(
                height: kHeight * 0.160,
                width: kHeight * 0.160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(.070),
                    width: kHeight * 0.020,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(width: kWeight * 0.018),
                _profileFamilyLogo(logoUrl),
                SizedBox(width: kWeight * 0.018),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: kHeight * 0.012,
                      bottom: kHeight * 0.010,
                      right: kWeight * 0.012,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: _familyNameBadge(name),
                            ),
                            SizedBox(width: kWeight * 0.010),
                            _familyRoleBadge(roleText),
                          ],
                        ),
                        SizedBox(height: kHeight * 0.006),
                        Row(
                          children: [
                            _familyRankPill(
                              badgeLevel > 0 ? badgeLevel : (levelNo > 0 ? levelNo : 1),
                            ),
                            SizedBox(width: kWeight * 0.010),
                            Expanded(
                              child: Text(
                                badgeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(.70),
                                  fontSize: kHeight * 0.011,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                ('Family ID:$familyCode').appTr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(.78),
                                  fontSize: kHeight * 0.014,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.groups_rounded,
                              color: Colors.white.withOpacity(.72),
                              size: kHeight * 0.017,
                            ),
                            SizedBox(width: kWeight * 0.010),
                            Text(
                              '$membersCount/$memberLimit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(.78),
                                fontSize: kHeight * 0.014,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: kWeight * 0.010),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white.withOpacity(.60),
                              size: kHeight * 0.013,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _profileFamilyLogo(String logoUrl) {
  final double size = kHeight * 0.096;
  final double imageSize = size * .66;

  return SizedBox(
    height: size,
    width: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: .78,
          child: Container(
            height: size * .74,
            width: size * .74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFE083),
                  Color(0xFF0BD0A2),
                  Color(0xFF0B3043),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
        Container(
          height: imageSize + 8,
          width: imageSize + 8,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B3043),
            border: Border.all(
              color: const Color(0xFFFFE083),
              width: 1.2,
            ),
          ),
          child: ClipOval(
            child: logoUrl.isEmpty
                ? Container(
              color: Colors.white.withOpacity(.12),
              child: Icon(
                Icons.groups_2_rounded,
                color: Colors.white,
                size: imageSize * .55,
              ),
            )
                : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.white.withOpacity(.12),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.white.withOpacity(.12),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: Colors.white,
                  size: imageSize * .55,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: Icon(
            Icons.auto_awesome_rounded,
            color: const Color(0xFFFFE083),
            size: size * .24,
          ),
        ),
        Positioned(
          left: 0,
          bottom: size * .15,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(.85),
            size: size * .18,
          ),
        ),
        Positioned(
          right: 0,
          bottom: size * .15,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(.85),
            size: size * .18,
          ),
        ),
      ],
    ),
  );
}

Widget _familyNameBadge(String name) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.016,
      vertical: kHeight * 0.0035,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFB47419), Color(0xFFFFD05A), Color(0xFF9C5A10)],
      ),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: const Color(0xFFFFF0A6).withOpacity(.75)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.shield_rounded,
          color: const Color(0xFF7B110B),
          size: kHeight * 0.014,
        ),
        SizedBox(width: kWeight * 0.006),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: const Color(0xFF7B110B),
              fontSize: kHeight * 0.012,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _familyRoleBadge(String roleText) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.018,
      vertical: kHeight * 0.004,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFF1E5B7A),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.12),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Text(
      roleText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: kHeight * 0.0105,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );
}

Widget _familyRankPill(int rankNo) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.020,
      vertical: kHeight * 0.004,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF5D4A16), Color(0xFFF7E98B), Color(0xFF9E741D)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(.28), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.emoji_events_rounded,
          color: Colors.white,
          size: kHeight * 0.013,
        ),
        SizedBox(width: kWeight * 0.006),
        Text(
          ('No.$rankNo+ ›').appTr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: kHeight * 0.012,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

Map<String, dynamic> _familyMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _familyText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

int _familyInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

String _familyImageUrl(dynamic value) {
  final text = _familyText(value);
  if (text.isEmpty) return '';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  return _assetFullUrl(text);
}

class _ProfileFamilyCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(.055);

    for (double x = -size.height; x < size.width + size.height; x += 34) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(.060);

    for (double x = 18; x < size.width; x += 42) {
      for (double y = 14; y < size.height; y += 32) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _topGifterSection(MyprofileController myprofileController) {
  final String userId = _currentProfileUserId();

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: Get.width * 0.03),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * 0.030,
        vertical: kHeight * 0.010,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: kAppColor1.withOpacity(.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  height: kHeight * 0.036,
                  width: kHeight * 0.036,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        kAppColor1,
                        kAppColor2,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kAppColor2.withOpacity(.22),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: kHeight * 0.018,
                  ),
                ),
                SizedBox(width: kWeight * 0.020),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ('Top Gifter').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: kHeight * 0.017,
                          color: Colors.black.withOpacity(.84),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: kHeight * 0.002),
                      Obx(() {
                        final int count = myprofileController.profileContributionList.length;
                        return Text(
                          count == 0 ? ('No gifter yet').appTr: ('$count gifters').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.011,
                            color: Colors.black.withOpacity(.45),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: kHeight * 0.058,
            width: Get.width * 0.36,
            child: FutureBuilder(
              future: myprofileController.showProfileContributionList(userId: userId),
              builder: (context, snapshot) {
                return Obx(() {
                  final List topGifters = myprofileController.profileContributionList;

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      topGifters.isEmpty) {
                    return _topGifterLoadingRow();
                  }

                  if (topGifters.isEmpty) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        ('Empty').appTr,
                        style: GoogleFonts.roboto(
                          fontSize: kHeight * 0.012,
                          color: Colors.black.withOpacity(.38),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: topGifters.length > 5 ? 5 : topGifters.length,
                    separatorBuilder: (_, __) => SizedBox(width: kWeight * 0.010),
                    itemBuilder: (context, index) {
                      final dynamic item = topGifters[index];
                      final dynamic sender = _topGifterSender(item);

                      return _topGifterAvatar(
                        sender: sender,
                        index: index,
                        onTap: () {
                          Get.to(
                            Profileconribution(),
                            arguments: {'userId': userId},
                            transition: Transition.rightToLeft,
                          );
                        },
                      );
                    },
                  );
                });
              },
            ),
          ),
          SizedBox(width: kWeight * 0.006),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Get.to(
                Profileconribution(),
                arguments: {'userId': userId},
                transition: Transition.rightToLeft,
              );
            },
            child: Container(
              height: kHeight * 0.034,
              width: kHeight * 0.034,
              decoration: BoxDecoration(
                color: const Color(0xffF6F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(.42),
                size: kHeight * 0.015,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _topGifterLoadingRow() {
  return ListView.separated(
    scrollDirection: Axis.horizontal,
    reverse: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 4,
    separatorBuilder: (_, __) => SizedBox(width: kWeight * 0.010),
    itemBuilder: (context, index) {
      return Container(
        height: kHeight * 0.046,
        width: kHeight * 0.046,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
      );
    },
  );
}

Widget _topGifterAvatar({
  required dynamic sender,
  required int index,
  required VoidCallback onTap,
}) {
  final String profileImage = _topGifterProfileImage(sender);
  final String frameImage = _topGifterFrameImage(sender);

  return Transform.translate(
    offset: Offset(index == 0 ? 0 : -index * 2.0, 0),
    child: CastomCardProfileImage(
      onPressed: onTap,
      frame: _safeDecorationImage(frameImage.isEmpty ? null : frameImage),
      image: profileImage,
    ),
  );
}

dynamic _topGifterSender(dynamic item) {
  if (item is Map && item['sender'] != null) return item['sender'];
  return null;
}

String _topGifterProfileImage(dynamic sender) {
  if (sender is! Map) return '';

  final String image = sender['profile_image']?.toString() ?? '';
  if (image.trim().isEmpty || image == 'null') return '';

  return ImageHelper.getImageUrl(image);
}

String _topGifterFrameImage(dynamic sender) {
  if (sender is! Map) return '';

  final dynamic history = sender['asset_purchase_history'];
  if (history is! Map) return '';

  final dynamic assetData = history['asset'];
  if (assetData is! Map) return '';

  final String asset = assetData['asset']?.toString() ?? '';
  if (asset.trim().isEmpty || asset == 'null') return '';

  return ImageHelper.getImageUrl(asset);
}

Widget _profilePremiumCpCardSection() {
  return Obx(() {
    final dynamic userProfile = authController.userProfile.value;
    final dynamic user = _safeRead(() => userProfile.user);
    final dynamic localCpData = _extractCpDataFromUserProfile(userProfile) ?? _profileCpDataCache;

    if (localCpData != null) {
      return _buildPremiumCpCardFromData(userProfile: userProfile, user: user, cpData: localCpData);
    }

    return FutureBuilder<dynamic>(
      future: _getMyProfileCpFuture(),
      builder: (context, snapshot) {
        final dynamic cpData = _normalizeCpData(snapshot.data) ?? _profileCpDataCache;
        return _buildPremiumCpCardFromData(userProfile: userProfile, user: user, cpData: cpData);
      },
    );
  });
}

Widget _buildPremiumCpCardFromData({
  required dynamic userProfile,
  required dynamic user,
  required dynamic cpData,
}) {
  final dynamic currentCp = _safeRead(() => cpData.currentCp) ??
      _safeRead(() => cpData.current_cp) ??
      _mapValue(cpData, 'current_cp') ??
      _mapValue(cpData, 'currentCp');

  final String cpStatus = (_safeString(
    _safeRead(() => currentCp.status) ?? _mapValue(currentCp, 'status'),
  ) ?? '').toLowerCase().trim();

  final bool cpFlag = _safeBool(
    _safeRead(() => cpData.hasCp) ??
        _safeRead(() => cpData.has_cp) ??
        _mapValue(cpData, 'has_cp') ??
        _mapValue(cpData, 'hasCp'),
  ) ?? false;

  final dynamic cpPartner = _resolveCpPartner(cpData, user);

  final String partnerName = _safeString(
    _safeRead(() => cpPartner.name) ?? _mapValue(cpPartner, 'name'),
  ) ?? '';

  final String partnerImage = _safeString(
    _safeRead(() => cpPartner.profileImageUrl) ??
        _safeRead(() => cpPartner.profileImage) ??
        _safeRead(() => cpPartner.profile_image_url) ??
        _safeRead(() => cpPartner.profile_image) ??
        _mapValue(cpPartner, 'profile_image_url') ??
        _mapValue(cpPartner, 'profileImageUrl') ??
        _mapValue(cpPartner, 'profile_image') ??
        _mapValue(cpPartner, 'profileImage'),
  ) ?? '';

  final bool hasCp = cpPartner != null &&
      partnerName.trim().isNotEmpty &&
      partnerImage.trim().isNotEmpty &&
      (cpFlag || cpStatus == 'accepted' || currentCp != null);

  if (!hasCp) return const SizedBox.shrink();

  final String myName = _safeString(
    _safeRead(() => user.name) ?? _mapValue(user, 'name'),
  ) ?? '';

  final String myImage = _safeString(
    _safeRead(() => user.profileImageUrl) ??
        _safeRead(() => user.profileImage) ??
        _safeRead(() => user.profile_image_url) ??
        _safeRead(() => user.profile_image) ??
        _mapValue(user, 'profile_image_url') ??
        _mapValue(user, 'profileImageUrl') ??
        _mapValue(user, 'profile_image') ??
        _mapValue(user, 'profileImage'),
  ) ?? '';

  final dynamic localCpData = _extractCpDataFromUserProfile(userProfile);
  final dynamic cpLevel = _safeRead(() => cpData.cpLevel) ??
      _safeRead(() => cpData.cp_level) ??
      _mapValue(cpData, 'cp_level') ??
      _mapValue(cpData, 'cpLevel') ??
      _safeRead(() => localCpData.cpLevel) ??
      _safeRead(() => localCpData.cp_level) ??
      _mapValue(localCpData, 'cp_level') ??
      _mapValue(localCpData, 'cpLevel');

  final String levelNo = _idText(
    _safeRead(() => cpLevel.levelNo) ??
        _safeRead(() => cpLevel.level_no) ??
        _mapValue(cpLevel, 'level_no') ??
        _mapValue(cpLevel, 'levelNo') ??
        1,
  );

  final String daysText = _profileCpDaysText(cpData);

  return Padding(
    padding: EdgeInsets.fromLTRB(kHeight * 0.012, kHeight * 0.010, kHeight * 0.012, kHeight * 0.010),
    child: PremiumCpCard(
      myName: myName,
      partnerName: partnerName,
      myImage: _profileImageFullUrl(myImage),
      partnerImage: _profileImageFullUrl(partnerImage),
      levelText: 'Lv.$levelNo',
      totalDays: daysText,
    ),
  );
}

String _profileCpDaysText(dynamic cpData) {
  final dynamic currentCp = _safeRead(() => cpData.currentCp) ??
      _safeRead(() => cpData.current_cp) ??
      _mapValue(cpData, 'current_cp') ??
      _mapValue(cpData, 'currentCp');

  final dynamic directDays = _safeRead(() => cpData.cpDays) ??
      _safeRead(() => cpData.cp_days) ??
      _mapValue(cpData, 'cp_days') ??
      _mapValue(cpData, 'cpDays');

  final String directDaysText = _idText(directDays);
  if (directDaysText.isNotEmpty && directDaysText != 'null') {
    return '${directDaysText}Days';
  }

  final String sinceText = _safeString(
    _safeRead(() => cpData.cpSinceDate) ??
        _safeRead(() => cpData.cp_since_date) ??
        _mapValue(cpData, 'cp_since_date') ??
        _mapValue(cpData, 'cpSinceDate') ??
        _safeRead(() => currentCp.acceptedAt) ??
        _safeRead(() => currentCp.accepted_at) ??
        _mapValue(currentCp, 'accepted_at') ??
        _mapValue(currentCp, 'acceptedAt') ??
        _safeRead(() => currentCp.createdAt) ??
        _safeRead(() => currentCp.created_at) ??
        _mapValue(currentCp, 'created_at') ??
        _mapValue(currentCp, 'createdAt'),
  ) ?? '';

  final DateTime? sinceDate = _parseFlexibleDate(sinceText);
  if (sinceDate == null) return '0Days';

  final DateTime now = DateTime.now();
  final DateTime start = DateTime(sinceDate.year, sinceDate.month, sinceDate.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int days = today.difference(start).inDays + 1;

  return '${days < 0 ? 0 : days}Days';
}

DateTime? _parseFlexibleDate(String value) {
  final String text = value.trim();
  if (text.isEmpty || text == 'null') return null;

  final DateTime? direct = DateTime.tryParse(text);
  if (direct != null) return direct;

  final String normalized = text.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}


Widget _profileHeaderOverlay({
  required MyprofileController myprofileController,
  required String shortName,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Obx(() {
        final dynamic userProfile = authController.userProfile.value;
        final dynamic user = _safeRead(() => userProfile.user);
        final dynamic localCpData = _extractCpDataFromUserProfile(userProfile);

        _printCpProfileDebug(
          userProfile: userProfile,
          user: user,
          localCpData: localCpData,
        );

        if (localCpData != null) {
          return _buildProfileCpAvatar(
            userProfile: userProfile,
            user: user,
            cpData: localCpData,
          );
        }

        return FutureBuilder<dynamic>(
          future: _loadMyProfileCpData(),
          builder: (context, snapshot) {
            final dynamic apiCpData =
                _normalizeCpData(snapshot.data) ?? _profileCpDataCache;

            if (snapshot.hasError) {

            }

            return _buildProfileCpAvatar(
              userProfile: userProfile,
              user: user,
              cpData: apiCpData,
            );
          },
        );
      }),

      Row(
        children: [
          GradientShimmerTextaudio(
            text: shortName,
            fontSize: kHeight * 0.021,
            fontWeight: FontWeight.w500,
          ),
          SizedBox(width: kWeight * 0.018),
          Container(
            padding: EdgeInsets.all(kHeight * 0.004),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: authController.userProfile.value.user?.gender
                  ?.toString()
                  .toLowerCase() ==
                  'female'
                  ? const Color(0xffff5fb7)
                  : const Color(0xff31b6ff),
            ),
            child: Icon(
              authController.userProfile.value.user?.gender
                  ?.toString()
                  .toLowerCase() ==
                  'female'
                  ? Icons.female
                  : Icons.male,
              color: Colors.white,
              size: kHeight * 0.017,
            ),
          ),
          SizedBox(width: kWeight * 0.018),
          Text(
            getCountryFlag(
              authController.userProfile.value.user?.country?.toString(),
            ),
            style: TextStyle(fontSize: kHeight * 0.023),
          ),
        ],
      ),

      SizedBox(height: kHeight * 0.012),

      Row(
        children: [
          authController.userProfile.value.user?.uniqueId == null
              ? Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kWeight * 0.011,
                  vertical: kHeight * 0.002,
                ),
                decoration: BoxDecoration(
                  color: kAppColor2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ('ID').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.014,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: kWeight * 0.012),
              Text(
                '${authController.userProfile.value.user?.userId ?? ''}',
                style: GoogleFonts.poppins(
                  fontSize: kHeight * 0.0145,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: kWeight * 0.012),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                      '${authController.userProfile.value.user?.userId ?? ''}',
                    ),
                  );
                  Fluttertoast.showToast(msg: ('ID copied').appTr);
                },
                child: Icon(
                  Icons.copy,
                  size: kHeight * 0.016,
                  color: Colors.white,
                ),
              ),
            ],
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kWeight * 0.011,
                  vertical: kHeight * 0.002,
                ),
                decoration: BoxDecoration(
                  color: kAppColor2,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: kAppColor2.withOpacity(.45),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  ('ID').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.016,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: kWeight * 0.015),
              ShimmerUserId1(
                user: authController.userProfile.value.user,
                kHeight: kHeight,
                kWeight: kWeight,
              ),
              SizedBox(width: kWeight * 0.015),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                      '${authController.userProfile.value.user?.userId ?? ''}',
                    ),
                  );
                  Fluttertoast.showToast(msg: ('ID copied').appTr);
                },
                child: Icon(
                  Icons.copy,
                  size: kHeight * 0.019,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(width: kWeight * 0.07),
          LevelFrame(
            level: '${authController.userProfile.value.user?.level ?? 0}',
          ),
          _profileCurrentVipTitleImageBadge(),
        ],
      ),

      SizedBox(height: kHeight * 0.02),
      _profileBaseBadgesRow(),
      SizedBox(height: kHeight * 0.01),
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statTile(
            '${myprofileController.profileGiftList.length}',
            ('Sending').appTr,
          ),
          InkWell(
            onTap: () {
              Get.to(
                FollowinfList(),
                transition: Transition.rightToLeft,
              );
            },
            child: _statTile(
              '${authController.userProfile.value.user?.totalFollowing ?? 0}',
              ('Following').appTr,
            ),
          ),
          InkWell(
            onTap: () {
              Get.to(
                Follower(),
                transition: Transition.rightToLeft,
              );
            },
            child: _statTile(
              '${authController.userProfile.value.user?.totalFollowers ?? 0}',
              ('Followers').appTr,
            ),
          ),
        ],
      ),

    ],
  );
}


Widget _buildProfileCpAvatar({
  required dynamic userProfile,
  required dynamic user,
  required dynamic cpData,
}) {
  final String profileImage = _safeString(
    _safeRead(() => user.profileImage) ??
        _safeRead(() => user.profile_image) ??
        _mapValue(user, 'profile_image') ??
        _mapValue(user, 'profileImage'),
  ) ??
      '';

  final dynamic cpPartner = _resolveCpPartner(cpData, user);

  final String partnerImage = _safeString(
    _safeRead(() => cpPartner.profileImageUrl) ??
        _safeRead(() => cpPartner.profileImage) ??
        _safeRead(() => cpPartner.profile_image_url) ??
        _safeRead(() => cpPartner.profile_image) ??
        _mapValue(cpPartner, 'profile_image_url') ??
        _mapValue(cpPartner, 'profileImageUrl') ??
        _mapValue(cpPartner, 'profile_image') ??
        _mapValue(cpPartner, 'profileImage'),
  ) ??
      '';

  final String partnerName = _safeString(
    _safeRead(() => cpPartner.name) ?? _mapValue(cpPartner, 'name'),
  ) ??
      '';

  final bool cpFlag =
      _safeBool(_safeRead(() => cpData.hasCp) ??
          _safeRead(() => cpData.has_cp) ??
          _mapValue(cpData, 'has_cp') ??
          _mapValue(cpData, 'hasCp')) ??
          false;

  final dynamic currentCp = _safeRead(() => cpData.currentCp) ??
      _safeRead(() => cpData.current_cp) ??
      _mapValue(cpData, 'current_cp') ??
      _mapValue(cpData, 'currentCp');

  final String cpStatus = (_safeString(
    _safeRead(() => currentCp.status) ?? _mapValue(currentCp, 'status'),
  ) ??
      '')
      .toLowerCase()
      .trim();

  final bool hasCp = cpPartner != null &&
      partnerImage.trim().isNotEmpty &&
      (cpFlag || cpStatus == 'accepted' || currentCp != null);

  final dynamic assetHistories = _safeRead(() => userProfile.assetHistories) ??
      _safeRead(() => userProfile.asset_histories) ??
      _safeRead(() => user.assetHistories) ??
      _safeRead(() => user.asset_histories) ??
      _mapValue(userProfile, 'asset_histories') ??
      _mapValue(user, 'asset_histories');

  final dynamic asset =
      _safeRead(() => assetHistories.asset) ?? _mapValue(assetHistories, 'asset');

  final String framePath = _safeString(
    _safeRead(() => asset.asset) ?? _mapValue(asset, 'asset'),
  ) ??
      '';

  final String frameType = _safeString(
    _safeRead(() => asset.type) ?? _mapValue(asset, 'type'),
  ) ??
      '';

  final bool hasUserFrame = assetHistories != null &&
      framePath.isNotEmpty &&
      frameType.toLowerCase().trim() == 'frame';

  final String frameUrl = _assetFullUrl(framePath);



  if (hasCp) {
    return _cpCoupleProfileHeader(
      profileImage: profileImage,
      partnerImage: partnerImage,
      partnerName: partnerName,
      frameUrl: frameUrl,
      hasUserFrame: hasUserFrame,
    );
  }

  return _singleProfileAvatar(
    profileImage: profileImage,
    frameUrl: frameUrl,
    hasUserFrame: hasUserFrame,
  );
}

Widget _cpCoupleProfileHeader({
  required String profileImage,
  required String partnerImage,
  required String partnerName,
  required String frameUrl,
  required bool hasUserFrame,
}) {
  final double avatarSize = kHeight * 0.145;
  final double totalWidth = avatarSize * 1.95;

  return SizedBox(
    height: avatarSize * 1.10,
    width: totalWidth,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: _cpAvatarFrame(
            imageUrl: _profileImageFullUrl(profileImage),
            size: avatarSize,
            frameUrl: frameUrl,
            showFrame: hasUserFrame,
            isPartner: false,
          ),
        ),
        Positioned(
          left: avatarSize * 1.4,
          top: 0,
          child: _cpAvatarFrame(
            imageUrl: _profileImageFullUrl(partnerImage),
            size: avatarSize,
            frameUrl: '',
            showFrame: false,
            isPartner: true,
          ),
        ),
        Positioned(
          left: avatarSize * 0.83,
          top: avatarSize * 0.26,
          child: SizedBox(
            height: kHeight*0.12,
            width: kHeight*0.12,
            child: SVGAEasyPlayer(
              assetsName: 'assets/svga/Level/cp_info_bg (1).svga',
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (partnerName.trim().isNotEmpty)
          Positioned(
            left:kWeight*0.6,
            bottom: 0,
            child: Container(
              constraints: BoxConstraints(maxWidth: avatarSize * 0.95),
              padding: EdgeInsets.symmetric(
                horizontal: kWeight * 0.015,
                vertical: kHeight * 0.003,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: const Color(0xffff4fa3),
                    size: kHeight * 0.014,
                  ),
                  SizedBox(width: kWeight * 0.006),
                  Flexible(
                    child: Text(
                      partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: kHeight * 0.0115,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _singleProfileAvatar({
  required String profileImage,
  required String frameUrl,
  required bool hasUserFrame,
}) {
  return _cpAvatarFrame(
    imageUrl: _profileImageFullUrl(profileImage),
    size: kHeight * 0.145,
    frameUrl: frameUrl,
    showFrame: hasUserFrame,
    isPartner: false,
  );
}

Widget _cpAvatarFrame({
  required String imageUrl,
  required double size,
  required String frameUrl,
  required bool showFrame,
  required bool isPartner,
}) {
  final double imageSize = size * 0.68;

  return SizedBox(
    height: size,
    width: size,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: imageSize,
          width: imageSize,
          padding: EdgeInsets.all(size * 0.035),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isPartner
                  ? const [
                Color(0xfffff176),
                Color(0xffff9f1c),
                Color(0xffff4fa3),
              ]
                  : const [
                Colors.white,
                Color(0xffffd54f),
                Color(0xffff8a00),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.22),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: _networkCircleImage(
              imageUrl: imageUrl,
              size: imageSize,
            ),
          ),
        ),

        if (showFrame && frameUrl.trim().isNotEmpty)
          SizedBox(
            height: size * 1.08,
            width: size * 1.08,
            child: frameUrl.toLowerCase().endsWith('.svga')
                ? SVGAEasyPlayer(
              resUrl: frameUrl,
              fit: BoxFit.cover,
            )
                : CachedNetworkImage(
              imageUrl: frameUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),

        if (isPartner)
          Positioned(
            top: size * 0.13,
            right: size * 0.18,
            child: Container(
              padding: EdgeInsets.all(size * 0.035),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xfffff176), Color(0xffff9800)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: const Color(0xffff2f86),
                size: size * 0.115,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _cpCenterBadge({required double size}) {
  return Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [
          Color(0xffffe6f3),
          Color(0xffff5fb7),
          Color(0xffffd54f),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xffff4fa3).withOpacity(.55),
          blurRadius: 14,
          spreadRadius: 1,
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: size * 0.58,
        ),
        Positioned(
          bottom: size * 0.16,
          child: Text(
            ('CP').appTr,
            style: GoogleFonts.poppins(
              color: const Color(0xffc2176b),
              fontSize: size * 0.18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _networkCircleImage({
  required String imageUrl,
  required double size,
}) {
  if (imageUrl.trim().isEmpty || imageUrl.trim() == 'null') {
    return Container(
      color: Colors.white.withOpacity(.20),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: BoxFit.cover,
    height: size,
    width: size,
    placeholder: (context, url) => Container(
      color: Colors.white.withOpacity(.15),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      color: Colors.white.withOpacity(.20),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.55,
      ),
    ),
  );
}


DecorationImage? _safeDecorationImage(String? imageUrl) {
  final url = (imageUrl ?? '').trim();

  if (url.isEmpty || url == 'null') return null;

  // SVGA file ke NetworkImage/DecorationImage diye load korle
  // Invalid image data crash hoy. Tai frame slot-e SVGA skip kora holo.
  if (url.toLowerCase().endsWith('.svga')) return null;

  return DecorationImage(
    image: NetworkImage(url),
    fit: BoxFit.cover,
  );
}

String _profileImageFullUrl(String path) {
  final text = path.trim();
  if (text.isEmpty || text == 'null') return '';

  if (text.startsWith('http://') || text.startsWith('https://')) {
    return text;
  }

  return _assetFullUrl(text);
}


void _printCpProfileDebug({
  required dynamic userProfile,
  required dynamic user,
  required dynamic localCpData,
}) {
  // build bar bar hoy, tai debug print limit rakhlam.
  if (_cpDebugBuildCount >= 30) return;
  _cpDebugBuildCount++;

  final dynamic userProfileJson = _safeRead(() => userProfile.toJson());
  final dynamic cpFromJson = _normalizeCpData(userProfileJson);
  final String token = _extractAuthToken();

}

String _shortJson(dynamic value, {int max = 3500}) {
  if (value == null) return 'null';

  String text;
  try {
    text = const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    text = value.toString();
  }

  if (text.length <= max) return text;
  return '${text.substring(0, max)}... [trimmed ${text.length - max} chars]';
}

String _tokenPreview(String token) {
  final text = token.trim();
  if (text.isEmpty) return 'EMPTY';
  if (text.length <= 16) return text;
  return '${text.substring(0, 8)}...${text.substring(text.length - 6)}';
}

String _currentUserIdText() {
  final dynamic profile = _safeRead(() => authController.userProfile.value);
  final dynamic user = _safeRead(() => profile.user);

  return _idText(
    _safeRead(() => user.userId) ??
        _safeRead(() => user.user_id) ??
        _safeRead(() => user.id) ??
        _mapValue(user, 'user_id') ??
        _mapValue(user, 'id'),
  );
}

Future<dynamic> _getMyProfileCpFuture() {
  _profileCpFuture ??= _loadMyProfileCpData();
  return _profileCpFuture!;
}

Future<dynamic> _loadMyProfileCpData() async {
  final String token = _extractAuthToken();
  final String userId = _currentUserIdText();

  _cpDebugApiCount++;

  if (token.isEmpty) {
    return null;
  }

  final String baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');

  final List<String> urls = [
    '$baseUrl/api/auth_cp_request_list',
    '$baseUrl/auth_cp_request_list',
    '$baseUrl/api/auth-cp-request-list',
    '$baseUrl/api/cp/auth-request-list',
    if (userId.isNotEmpty) '$baseUrl/api/auth_cp_request_list/$userId',
    if (userId.isNotEmpty) '$baseUrl/auth_cp_request_list/$userId',
  ];

  for (final url in urls) {
    try {
      debugPrint('---------------- CP API CALL ----------------');
      debugPrint('CP API URL => $url');

      final response = await GetConnect().get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': token.toLowerCase().startsWith('bearer ')
              ? token
              : 'Bearer $token',
        },
      );

      final dynamic body = response.body;
      final String? bodyString = response.bodyString;

      final dynamic normalized =
          _normalizeCpData(body) ?? _normalizeCpData(bodyString);


      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          normalized != null) {
        _profileCpDataCache = normalized;
        return normalized;
      }
    } catch (error, stack) {

    }
  }

  return null;
}

String _extractAuthToken() {
  final dynamic auth = authController;
  final dynamic profile = _safeRead(() => auth.userProfile.value);

  final List<dynamic> values = [
    _safeRead(() => profile.token),
    _safeRead(() => auth.token.value),
    _safeRead(() => auth.userToken.value),
    _safeRead(() => auth.apiToken.value),
    _safeRead(() => auth.token),
    _safeRead(() => auth.userToken),
    _safeRead(() => auth.apiToken),
  ];

  for (final value in values) {
    final String? token = _safeString(value);
    if (token != null && token.trim().isNotEmpty && token != 'null') {
      return token.trim();
    }
  }

  return '';
}

dynamic _extractCpDataFromUserProfile(dynamic userProfile) {
  final dynamic direct = _safeRead(() => userProfile.cpData) ??
      _safeRead(() => userProfile.cp_data) ??
      _mapValue(userProfile, 'cp_data') ??
      _mapValue(userProfile, 'cpData');

  final dynamic normalizedDirect = _normalizeCpData(direct);
  if (normalizedDirect != null) return normalizedDirect;

  final dynamic json = _safeRead(() => userProfile.toJson());
  return _normalizeCpData(json);
}

dynamic _normalizeCpData(dynamic raw) {
  if (raw == null) return null;

  dynamic data = raw;

  if (data is String) {
    final String text = data.trim();
    if (text.isEmpty || text == 'null') return null;

    try {
      data = jsonDecode(text);
    } catch (error) {
      debugPrint('CP normalize string jsonDecode failed => $error');
      return null;
    }
  }

  if (data is List) {
    return _normalizeCpDataFromList(data);
  }

  if (data is! Map) return null;

  final Map<dynamic, dynamic> map = data;

  // Common API root keys.
  final List<String> directKeys = [
    'cp_data',
    'cpData',
    'data',
    'result',
    'response',
    'payload',
    'current_cp_data',
    'currentCpData',
  ];

  for (final key in directKeys) {
    final dynamic value = map[key];
    if (value == null) continue;

    final dynamic normalized = _normalizeCpData(value);
    if (normalized != null) return normalized;
  }

  // Some APIs return requests list instead of cp_data object.
  final List<String> listKeys = [
    'requests',
    'request_list',
    'cp_requests',
    'cp_request_list',
    'sent_requests',
    'received_requests',
    'accepted_requests',
    'pending_requests',
    'list',
    'items',
  ];

  for (final key in listKeys) {
    final dynamic value = map[key];
    if (value is List) {
      final dynamic normalized = _normalizeCpDataFromList(value);
      if (normalized != null) return normalized;
    }
  }

  // Direct CP data object.
  if (map.containsKey('has_cp') ||
      map.containsKey('hasCp') ||
      map.containsKey('current_cp') ||
      map.containsKey('currentCp') ||
      map.containsKey('cp_partner') ||
      map.containsKey('cpPartner')) {
    return map;
  }

  // Direct single CP request object.
  final dynamic requestMap = _buildCpDataFromRequest(map);
  if (requestMap != null) return requestMap;

  // Last fallback: object has sender/receiver but no wrapper.
  if (map.containsKey('sender') || map.containsKey('receiver')) {
    return map;
  }

  return null;
}

dynamic _normalizeCpDataFromList(List list) {
  if (list.isEmpty) return null;

  dynamic firstValid;
  dynamic accepted;

  for (final item in list) {
    final dynamic cpData = _normalizeCpData(item);
    if (cpData == null) continue;

    firstValid ??= cpData;

    final dynamic currentCp = _safeRead(() => cpData.currentCp) ??
        _safeRead(() => cpData.current_cp) ??
        _mapValue(cpData, 'current_cp') ??
        _mapValue(cpData, 'currentCp') ??
        cpData;

    final String status = (_safeString(
      _safeRead(() => currentCp.status) ?? _mapValue(currentCp, 'status'),
    ) ??
        '').toLowerCase().trim();

    if (status == 'accepted') {
      accepted = cpData;
      break;
    }
  }

  return accepted ?? firstValid;
}

dynamic _buildCpDataFromRequest(dynamic raw) {
  if (raw == null || raw is! Map) return null;

  final Map<dynamic, dynamic> request = raw;

  final bool looksLikeRequest = request.containsKey('sender_id') ||
      request.containsKey('receiver_id') ||
      request.containsKey('partner_id') ||
      request.containsKey('gift_id') ||
      request.containsKey('gift_list_id') ||
      request.containsKey('request_no') ||
      request.containsKey('status');

  if (!looksLikeRequest) return null;

  final String status = (_safeString(request['status']) ?? '').toLowerCase().trim();

  final dynamic sender = request['sender'] ??
      request['from_user'] ??
      request['sender_user'] ??
      request['request_sender'];

  final dynamic receiver = request['receiver'] ??
      request['to_user'] ??
      request['receiver_user'] ??
      request['request_receiver'];

  final dynamic partner = request['cp_partner'] ??
      request['cpPartner'] ??
      request['partner'] ??
      request['partner_user'];

  return <String, dynamic>{
    'has_cp': status == 'accepted' || partner != null || sender != null || receiver != null,
    'current_cp': request,
    'cp_partner': partner,
    'sender': sender,
    'receiver': receiver,
    'cp_total_coins': request['total_coin'] ?? request['coin'] ?? request['gift_coin'],
    'cp_days': request['cp_days'],
    'cp_since_date': request['cp_since_date'],
    'cp_since_full_date': request['cp_since_full_date'],
  };
}

dynamic _resolveCpPartner(dynamic cpData, dynamic user) {
  if (cpData == null) return null;

  final dynamic directPartner = _safeRead(() => cpData.cpPartner) ??
      _safeRead(() => cpData.cp_partner) ??
      _mapValue(cpData, 'cp_partner') ??
      _mapValue(cpData, 'cpPartner');

  if (directPartner != null) return directPartner;

  final dynamic currentCp = _safeRead(() => cpData.currentCp) ??
      _safeRead(() => cpData.current_cp) ??
      _mapValue(cpData, 'current_cp') ??
      _mapValue(cpData, 'currentCp');

  final dynamic currentPartner = _safeRead(() => currentCp.cpPartner) ??
      _safeRead(() => currentCp.cp_partner) ??
      _safeRead(() => currentCp.partner) ??
      _safeRead(() => currentCp.partnerUser) ??
      _safeRead(() => currentCp.partner_user) ??
      _mapValue(currentCp, 'cp_partner') ??
      _mapValue(currentCp, 'cpPartner') ??
      _mapValue(currentCp, 'partner') ??
      _mapValue(currentCp, 'partner_user') ??
      _mapValue(currentCp, 'partnerUser');

  if (currentPartner != null) return currentPartner;

  final dynamic sender = _safeRead(() => cpData.sender) ??
      _safeRead(() => currentCp.sender) ??
      _safeRead(() => currentCp.senderUser) ??
      _safeRead(() => currentCp.sender_user) ??
      _mapValue(cpData, 'sender') ??
      _mapValue(currentCp, 'sender') ??
      _mapValue(currentCp, 'sender_user') ??
      _mapValue(currentCp, 'senderUser');

  final dynamic receiver = _safeRead(() => cpData.receiver) ??
      _safeRead(() => currentCp.receiver) ??
      _safeRead(() => currentCp.receiverUser) ??
      _safeRead(() => currentCp.receiver_user) ??
      _mapValue(cpData, 'receiver') ??
      _mapValue(currentCp, 'receiver') ??
      _mapValue(currentCp, 'receiver_user') ??
      _mapValue(currentCp, 'receiverUser');

  final String myId = _idText(
    _safeRead(() => user.userId) ??
        _safeRead(() => user.user_id) ??
        _safeRead(() => user.id) ??
        _mapValue(user, 'user_id') ??
        _mapValue(user, 'id'),
  );

  final String senderId = _idText(
    _safeRead(() => sender.userId) ??
        _safeRead(() => sender.user_id) ??
        _safeRead(() => sender.id) ??
        _mapValue(sender, 'user_id') ??
        _mapValue(sender, 'id'),
  );

  final String receiverId = _idText(
    _safeRead(() => receiver.userId) ??
        _safeRead(() => receiver.user_id) ??
        _safeRead(() => receiver.id) ??
        _mapValue(receiver, 'user_id') ??
        _mapValue(receiver, 'id'),
  );

  if (myId.isNotEmpty && senderId == myId && receiver != null) return receiver;
  if (myId.isNotEmpty && receiverId == myId && sender != null) return sender;

  return sender ?? receiver;
}

String _idText(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _assetFullUrl(String path) {
  final text = path.trim();
  if (text.isEmpty || text == 'null') return '';

  if (text.startsWith('http://') || text.startsWith('https://')) {
    return text;
  }

  final baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
  final cleanPath = text.replaceAll(RegExp(r'^/+'), '');
  return '$baseUrl/$cleanPath';
}

dynamic _mapValue(dynamic source, String key) {
  if (source is Map) return source[key];
  return null;
}

T? _safeRead<T>(T Function() read) {
  try {
    return read();
  } catch (_) {
    return null;
  }
}

String? _safeString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  if (text == 'null') return null;
  return text;
}

bool? _safeBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;

  final text = value.toString().toLowerCase().trim();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;

  return null;
}

Widget _statTile(String value, String label) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: kHeight * 0.015),
    child: Column(
      children: [
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: kHeight * 0.023,
            fontWeight: FontWeight.bold,
            color: kAppColor2,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: kHeight * 0.014,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}



Widget userTypeBadges({
  required String? userType,
  required String? agencyType,
  required String? reselerType,
  required String? hostType,
  required double kHeight,
}) {
  final Set<String> roles = {};

  void addRole(dynamic value) {
    final text = value?.toString().toLowerCase().trim() ?? '';

    if (text.isEmpty || text == 'null' || text == '0') return;

    final parts = text
        .split(RegExp(r'[,| ]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    roles.addAll(parts);
  }

  addRole(userType);
  addRole(agencyType);
  addRole(reselerType);
  addRole(hostType);

  final Map<String, List<String>> roleImages = {
    'host': [
      'assets/Pk/Host__1_-removebg-preview.png',
    ],

    'reseller': [
      'assets/Pk/reseller__1_-removebg-preview.png',
    ],
    'reseler': [
      'assets/Pk/reseller__1_-removebg-preview.png',
    ],

    'agency': [
      'assets/Pk/agent__2___1_-removebg-preview.png',
    ],
    'agent': [
      'assets/Pk/agent__2___1_-removebg-preview.png',
    ],

    // Manager er jonno 2ta fallback path rakha holo
    'manager': [
      'assets/audio_live/man.png',
      'assets/audio_live/man.png',
    ],

    'country_manager': [
      'assets/Pk/manager-removebg-preview.png',
      'assets/audio_live/man.png',
    ],

    'super_admin': [
      'assets/Pk/superadmin.png',
      'assets/Pk/superadmin.png',
    ],

    'bd_admin': [
      'assets/Pk/bdDmin.png',
      'assets/Pk/bdDmin.png',
    ],

    'admin': [
      'assets/Pk/manager-removebg-preview.png',
      'assets/audio_live/man.png',
    ],
  };

  final List<String> order = [
    'host',
    'reseller',
    'reseler',
    'agency',
    'agent',
    'manager',
    'country_manager',
    'super_admin',
    'bd_admin',
    'admin',
  ];

  final Set<String> addedGroup = {};

  final badges = <Widget>[];

  for (final role in order) {
    final bool matched = roles.contains(role) && roleImages.containsKey(role);

    debugPrint(
      'Badge check => role: $role | contains: ${roles.contains(role)} | matched: $matched',
    );

    if (!matched) continue;

    // Duplicate reseller/reseler badge stop
    if ((role == 'reseller' || role == 'reseler') &&
        addedGroup.contains('reseller_group')) {
      continue;
    }

    // Duplicate agency/agent badge stop
    if ((role == 'agency' || role == 'agent') &&
        addedGroup.contains('agency_group')) {
      continue;
    }

    // Duplicate manager/admin type badge stop
    if ((role == 'manager' ||
        role == 'country_manager' ||
        role == 'super_admin' ||
        role == 'bd_admin' ||
        role == 'admin') &&
        addedGroup.contains('manager_group')) {
      continue;
    }

    if (role == 'reseller' || role == 'reseler') {
      addedGroup.add('reseller_group');
    } else if (role == 'agency' || role == 'agent') {
      addedGroup.add('agency_group');
    } else if (role == 'manager' ||
        role == 'country_manager' ||
        role == 'super_admin' ||
        role == 'bd_admin' ||
        role == 'admin') {
      addedGroup.add('manager_group');
    } else {
      addedGroup.add(role);
    }

    debugPrint('✅ Showing badge => $role | images => ${roleImages[role]}');

    badges.add(
      Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.45),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: _BadgeImageWithFallback(
          images: roleImages[role]!,
          height: kHeight * 0.045,
          role: role,
        ),
      ),
    );
  }

  debugPrint('Total badges showing => ${badges.length}');

  if (badges.isEmpty) {
    debugPrint('⚠️ No badge found for roles => $roles');
    return const SizedBox.shrink();
  }

  return Align(
    alignment: Alignment.topLeft,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: badges,
      ),
    ),
  );
}

class _BadgeImageWithFallback extends StatefulWidget {
  final List<String> images;
  final double height;
  final String role;

  const _BadgeImageWithFallback({
    required this.images,
    required this.height,
    required this.role,
  });

  @override
  State<_BadgeImageWithFallback> createState() =>
      _BadgeImageWithFallbackState();
}

class _BadgeImageWithFallbackState extends State<_BadgeImageWithFallback> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty || index >= widget.images.length) {
      debugPrint('❌ All badge images failed => ${widget.role}');
      return const SizedBox.shrink();
    }

    final imagePath = widget.images[index];

    return Image.asset(
      imagePath,
      height: widget.height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, error) {
        debugPrint(
          '❌ Badge image load failed => ${widget.role} | path: $imagePath | error: $error',
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && index < widget.images.length - 1) {
            setState(() {
              index++;
            });
          }
        });

        return const SizedBox.shrink();
      },
    );
  }
}

Widget _profileBaseBadgesRow() {
  return Obx(() {
    final bases = homeController.profileBaseList;

    if (bases.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: kHeight * 0.032,
      width: double.infinity,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: bases.length,
        separatorBuilder: (_, __) => SizedBox(width: kWeight * 0.006),
        itemBuilder: (context, index) {
          final item = bases[index];
          return _baseBadgeItem(item);
        },
      ),
    );
  });
}

Widget _baseBadgeItem(dynamic item) {
  String imageUrl = '';

  if (item is Map) {
    imageUrl = item['image_url']?.toString() ?? '';

    if (imageUrl.isEmpty) {
      final imagePath = item['image']?.toString() ?? '';
      if (imagePath.isNotEmpty) {
        final cleanDomain = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
        final cleanPath = imagePath.replaceAll(RegExp(r'^/+'), '');
        imageUrl = '$cleanDomain/$cleanPath';
      }
    }
  }

  if (imageUrl.isEmpty) {
    return const SizedBox.shrink();
  }

  final lowerUrl = imageUrl.toLowerCase().trim();

  return Container(
    width: kWeight * 0.225,
    height: kHeight * 0.050,
    alignment: Alignment.center,
    child: lowerUrl.endsWith('.svga')
        ? SVGAEasyPlayer(
      resUrl: imageUrl,
      fit: BoxFit.contain,
    )
        : CachedNetworkImage(
      imageUrl: imageUrl,
      width: kWeight * 0.215,
      height: kHeight * 0.040,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      memCacheWidth: 300,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    ),
  );
}

