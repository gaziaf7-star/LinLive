

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/auth/views/profile_view.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomContainer.dart';
import '../../appmenu/views/appmenu_view.dart';
import '../../appmenu/views/widgets/game_test.dart';
import '../../home/views/widgets/unicId.dart';
import '../../livestream/widgets/audioText.dart';
import '../../livestream/utils/vip_privileges.dart';
import '../../Famaily/view/my_family_api_page.dart';
import '../../messanger/views/chatpage_view.dart';
import '../../myprofile/controllers/myprofile_controller.dart';
import '../../myprofile/views/EditProfile.dart';
import '../../myprofile/views/ProfileConribution.dart';
import '../../myprofile/views/animationUserProfile.dart';
import '../../myprofile/views/myprofile_view.dart';
import '../../myprofile/views/widgets/CpcardPage.dart';
import '../../myprofile/views/widgets/fullGiftReceiverPage.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class userProfileVisit extends StatelessWidget {
  const userProfileVisit({Key? key}) : super(key: key);

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  // ✅ VISIT PROFILE FIX: safe Map converter for API response sections.
  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _userData(Map<String, dynamic> data) {
    final userData = data['User Data'];
    if (userData is Map<String, dynamic>) return userData;
    if (userData is Map) return Map<String, dynamic>.from(userData);
    return {};
  }

  // ✅ AGENCY DATA FIX: API response-er `user_agency` object safe vabe read.
  // Example:
  // user_agency: { user_type, agency_type, host_type, agency_id, host_agency_id, ... }
  Map<String, dynamic> _userAgencyData(Map<String, dynamic> data) {
    final userAgency = data['user_agency'];
    if (userAgency is Map<String, dynamic>) return userAgency;
    if (userAgency is Map) return Map<String, dynamic>.from(userAgency);
    return {};
  }

  // ✅ AGENCY DATA FIX: visual profile data te user_agency priority pabe,
  // but User Data-er missing fields like cover_images, gifts, followers preserve thakbe.
  Map<String, dynamic> _mergeUserWithAgency({
    required Map<String, dynamic> user,
    required Map<String, dynamic> agency,
  }) {
    if (agency.isEmpty) return user;

    final merged = <String, dynamic>{
      ...user,
      ...agency,
    };

    // ✅ PROFILE OWNER DATA FIX:
    // Profile-er visible identity sobsomoy `User Data` theke ashbe.
    // `user_agency` sudhu agency/host/admin related role info provide korbe.
    // Ete user_agency.name (e.g. King Philly) ar profile user-er actual name
    // (e.g. Nilima) ke overwrite korte parbe na.
    for (final key in [
      'id',
      'user_id',
      'unique_id',
      'name',
      'level',
      'level_image',
      'level_image_url',
      'phone',
      'gender',
      'profile_image',
      'profile_image_url',
      'country',
      'cover_images',
      'receive_gift_list',
      'send_gift_list',
      'base_list',
      'followers_list',
      'total_followers',
      'total_following',
      'asset_purchase_history',
    ]) {
      if (user.containsKey(key) && user[key] != null) {
        merged[key] = user[key];
      }
    }

    // User Data-te full URL na thakle agency-r stale profile_image_url remove kori.
    // Tokhon profile_image path theke correct visitor image build hobe.
    if (!user.containsKey('profile_image_url') ||
        _safeText(user['profile_image_url']).isEmpty) {
      merged.remove('profile_image_url');
    }

    return merged;
  }

  String _cleanBaseUrl() {
    String baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');

    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }

    return baseUrl;
  }

  String _fullUrl(dynamic path, {String fallback = ''}) {
    final text = _safeText(path);

    if (text.isEmpty || text == 'No Photo') return fallback;

    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }

    final cleanPath = text.replaceAll(RegExp(r'^/+'), '');
    return '${_cleanBaseUrl()}/$cleanPath';
  }

  String _countryFlag(String? country) {
    final c = (country ?? '').toLowerCase();

    if (c == 'bangladesh') return '🇧🇩';
    if (c == 'india') return '🇮🇳';
    if (c == 'iraq') return '🇮🇶';
    if (c == 'united kingdom') return '🇬🇧';
    if (c == 'andorra') return '🇦🇩';
    if (c == 'pakistan') return '🇵🇰';
    if (c == 'nepal') return '🇳🇵';
    if (c == 'saudi arabia') return '🇸🇦';

    return '🌍';
  }

  String _frameUrl(Map<String, dynamic> user) {
    final history = user['asset_purchase_history'];

    if (history == null || history is! Map) return '';

    final asset = history['asset'];
    if (asset == null || asset is! Map) return '';

    final type = _safeText(asset['type']).toLowerCase();
    final framePath = _safeText(asset['asset']);

    if (type != 'frame' || framePath.isEmpty) return '';

    return _fullUrl(framePath);
  }

  // ===============================================================
  // ✅ VISIT PROFILE VIP TITLE FRAME BESIDE LEVEL
  // Same VIP title frame level-er pashe show hobe.
  // Active VIP na thakle kono fake/default frame show korbe na.
  // ===============================================================
  int _visitorVipSafeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  bool _visitorVipDataBelongsToUser(dynamic vipData, int userId) {
    if (userId <= 0 || vipData is! Map) return false;

    final map = Map<String, dynamic>.from(vipData);
    final int vipUserId = _visitorVipSafeInt(map['user_id']);

    // user_id missing thakle API response-er data current profile-er dhore nibo.
    return vipUserId == 0 || vipUserId == userId;
  }

  DateTime? _visitorVipParseDate(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  bool _visitorVipIsActive(dynamic value) {
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

    final DateTime? expiresAt = _visitorVipParseDate(map['expires_at']);
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> _visitorVipLevel(dynamic vipData) {
    if (!_visitorVipIsActive(vipData)) return <String, dynamic>{};

    final dynamic level = (vipData as Map)['vip_level'];
    if (level is Map<String, dynamic>) return level;
    if (level is Map) return Map<String, dynamic>.from(level);

    return <String, dynamic>{};
  }

  String _visitorCleanVipImage(dynamic value) {
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

  String _visitorActiveVipTitleImage(dynamic vipData) {
    if (!_visitorVipIsActive(vipData)) return '';

    final Map<String, dynamic> level = _visitorVipLevel(vipData);
    final String rawPath = (level['title_image_url'] ??
        level['title_image'] ??
        level['badge_image_url'] ??
        level['badge_image'] ??
        '')
        .toString()
        .trim();

    if (rawPath.isEmpty || rawPath.toLowerCase() == 'null') return '';

    return _visitorCleanVipImage(rawPath);
  }

  dynamic _visitorFindVipCandidate(dynamic value) {
    if (value is List) {
      for (final item in value) {
        final dynamic found = _visitorFindVipCandidate(item);
        if (_visitorVipIsActive(found)) return found;
      }
      return null;
    }

    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    if (_visitorVipIsActive(map)) return map;

    for (final key in [
      'data',
      'vip',
      'vip_data',
      'current_vip',
      'vip_current',
      'active_vip',
      'user_vip',
      'vip_purchase',
      'vip_purchase_history',
      'active_vip_purchase',
      'current_vip_purchase',
    ]) {
      final dynamic found = _visitorFindVipCandidate(map[key]);
      if (_visitorVipIsActive(found)) return found;
    }

    return null;
  }

  dynamic _visitorProfileVipData({
    required Map<String, dynamic> rootData,
    required Map<String, dynamic> profileUser,
  }) {
    for (final source in [rootData, profileUser, _userData(rootData)]) {
      final dynamic found = _visitorFindVipCandidate(source);
      if (_visitorVipIsActive(found)) return found;
    }

    return null;
  }

  Widget _visitorVipTitleImageBadge({
    required Map<String, dynamic> rootData,
    required Map<String, dynamic> profileUser,
  }) {
    if (!VipPrivileges.from(<String, dynamic>{
      ...rootData,
      'user': profileUser,
    }).vipBadge) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final int profileId = _visitorVipSafeInt(profileUser['id']);
      final dynamic apiVipData = _visitorProfileVipData(
        rootData: rootData,
        profileUser: profileUser,
      );

      final Map<String, dynamic>? cachedVip =
      profileId > 0 ? homeController.currentVipForUser(profileId) : null;
      final Map<String, dynamic>? currentVip = homeController.vipCurrentData.value;

      final dynamic vipData = _visitorVipIsActive(apiVipData) &&
          _visitorVipDataBelongsToUser(apiVipData, profileId)
          ? apiVipData
          : cachedVip ??
          (_visitorVipDataBelongsToUser(currentVip, profileId)
              ? currentVip
              : null);

      final String imagePath = _visitorActiveVipTitleImage(vipData);

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

  bool _isMyProfile(Map<String, dynamic> user) {
    final visitorId = _safeText(user['id']);
    final myId = _safeText(authController.userProfile.value.user?.id);
    return visitorId.isNotEmpty && myId.isNotEmpty && visitorId == myId;
  }

  @override
  Widget build(BuildContext context) {
    final MyprofileController myprofileController = Get.put(MyprofileController());

    final Map<String, dynamic> data =
    Map<String, dynamic>.from(Get.arguments ?? {});

    final Map<String, dynamic> user = _userData(data);

    // ✅ AGENCY DATA FIX: agency/host/manager info API-er `user_agency` object theke nibe.
    // Jodi user_agency empty hoy, tahole User Data fallback hobe.
    final Map<String, dynamic> userAgency = _userAgencyData(data);
    final Map<String, dynamic> profileUser = _mergeUserWithAgency(
      user: user,
      agency: userAgency,
    );
    final profileVip = VipPrivileges.from(<String, dynamic>{
      ...data,
      'user': profileUser,
    });

    // ✅ VISIT PROFILE FIX: CP data root API response theke nibe.
    // Example API key: data['cp_data']
    final Map<String, dynamic> cpData = _safeMap(data['cp_data']);

    final String name = _safeText(profileUser['name'], fallback: ('User').appTr);
    final String userId = _safeText(profileUser['user_id'], fallback: '0');
    final String level = _safeText(profileUser['level'], fallback: '0');
    final String gender = _safeText(profileUser['gender'], fallback: ('Male').appTr);
    final String country = _safeText(profileUser['country'], fallback: '');
    // ✅ PROFILE IMAGE OWNER FIX:
    // Visitor-er main profile image always `User Data` theke nibo.
    // `user_agency.profile_image_url` / `profile_image` ekhane use korbo na,
    // nahole agency owner-er image visitor profile-e overwrite hoye jete pare.
    final String profileImage = _fullUrl(
      user['profile_image_url'] ?? user['profile_image'],
      fallback:
      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=F5365C&color=ffffff&bold=true',
    );
    final String frameUrl = _frameUrl(profileUser);

    // ✅ VISIT PROFILE CRASH FIX:
    // API response e `level_image` null hole age ekhane crash korto:
    // profileUser['level_image']['image']
    // Ekhon null-safe map + level_image_url fallback use korbe.
    final Map<String, dynamic> levelImageData =
    _safeMap(profileUser['level_image']);
    final String visitorLevelImage = _safeText(
      levelImageData['image'] ??
          levelImageData['image_url'] ??
          profileUser['level_image_url'],
    );

    final String coverImage = _fullUrl(profileUser['cover_images']);
    final bool hasCover = coverImage.isNotEmpty;

    final List baseList =
    profileUser['base_list'] is List ? profileUser['base_list'] : [];
    final List sendGiftList =
    profileUser['send_gift_list'] is List ? profileUser['send_gift_list'] : [];
    final List receiveGiftList =
    profileUser['receive_gift_list'] is List ? profileUser['receive_gift_list'] : [];

    return SafeArea(
      child: Scaffold(
        backgroundColor: profileVip.effectiveColorfulProfile
            ? const Color(0xFFF6F0FF)
            : Colors.white,
        body: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SizedBox(
                height: Get.height * 0.47,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: hasCover
                          ? CachedNetworkImage(
                        imageUrl: coverImage,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            _defaultCover(),
                      )
                          : _defaultCover(),
                    ),

                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.15),
                              Colors.black.withOpacity(0.45),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 28,
                      left: 20,
                      child: _roundActionButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Get.back(),
                      ),
                    ),

                    Positioned(
                      top: 28,
                      right: 20,
                      child: _roundActionButton(
                        icon: _isMyProfile(user)
                            ? Icons.edit_rounded
                            : Icons.person_add_alt_1_rounded,
                        onTap: () {
                          if (_isMyProfile(user)) {
                            Get.to(() => Editprofile(),
                                transition: Transition.rightToLeft);
                          } else {
                            Fluttertoast.showToast(
                              msg: ("Follow feature coming soon").appTr,
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.black87,
                              textColor: Colors.white,
                              fontSize: 13,
                            );
                          }
                        },
                      ),
                    ),

                    Positioned(
                      top: kHeight*0.04,
                      left: 15,
                      right: 0,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: kHeight*0.05,),
                          // ✅ VISIT PROFILE FIX: visitor user CP thakle duijoner avatar show hobe.
                          _visitorProfileHeaderAvatar(
                            user: profileUser,
                            cpData: cpData,
                            profileImage: profileImage,
                            frameUrl: frameUrl,
                          ),

                          SizedBox(height:  kHeight*0.004),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.5),
                            child: Row(
                              children: [

                                GradientShimmerTextaudio(
                                  text:
                                  name,
                                  fontSize: kHeight * 0.021,
                                  fontWeight:
                                  FontWeight.w500,
                                ),


                                SizedBox(width: kWeight * 0.018),
                                Container(
                                  padding: EdgeInsets.all(kHeight * 0.004),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color:
                                    gender.toString()
                                        .toLowerCase() ==
                                        'female'
                                        ? const Color(0xffff5fb7)
                                        : const Color(0xff31b6ff),
                                  ),
                                  child: Icon(
                                    gender.toString()
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
                                      country
                                  ),
                                  style: TextStyle(fontSize: kHeight * 0.023),
                                ),
                              ],
                            ),
                          ),


                          const SizedBox(height: 11),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(width: kWeight * 0.03),

                              profileUser['unique_id'] == null
                                  ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: kWeight * 0.011,
                                      vertical: kHeight * 0.002,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kAppColor2,
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kAppColor2
                                              .withOpacity(.45),
                                          blurRadius: 10,
                                          offset:
                                          const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      ('ID').appTr,
                                      style: GoogleFonts.poppins(
                                        fontSize:
                                        kHeight * 0.016,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: kWeight * 0.015),

                                  Text(
                                    '${profileUser['user_id'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: kHeight * 0.018,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Color(0xFFFFD700),
                                          offset: Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(width: kWeight * 0.015),

                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text:
                                          '${profileUser['user_id'] ?? ''}',
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.copy,
                                      size: kHeight * 0.019,
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
                                      borderRadius:
                                      BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: kAppColor2
                                              .withOpacity(.45),
                                          blurRadius: 10,
                                          offset:
                                          const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      ('ID').appTr,
                                      style: GoogleFonts.poppins(
                                        fontSize:
                                        kHeight * 0.016,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: kWeight * 0.015),

                                  ShimmerUserId(
                                    user: profileUser,
                                    kHeight: kHeight,
                                    kWeight: kWeight,
                                  ),

                                  SizedBox(width: kWeight * 0.015),

                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text:
                                          '${profileUser['user_id'] ?? ''}',
                                        ),
                                      );
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

                              _visitorSafeLevelFrame(
                                levelImage: visitorLevelImage,
                                level: level,
                              ),

                              _visitorVipTitleImageBadge(
                                rootData: data,
                                profileUser: profileUser,
                              ),
                            ],
                          ),


                          const SizedBox(height: 10),

                          _identityBadgesRow(baseList),

                          SizedBox(height: kHeight*0.02,),

                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: kWeight * 0.018,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _topStatTile(
                                    value: '${sendGiftList.length}',
                                    label: ('Sending').appTr,
                                  ),
                                ),
                                Expanded(
                                  child: _VisitorProfileVisitsStat(
                                    myprofileController: myprofileController,
                                    userId: int.tryParse(
                                      _safeText(
                                        user['id'] ??
                                            profileUser['id'] ??
                                            profileUser['user_id'],
                                      ),
                                    ) ??
                                        0,
                                  ),
                                ),
                                Expanded(
                                  child: _topStatTile(
                                    value:
                                    '${profileUser['total_following'] ?? 0}',
                                    label: ('Following').appTr,
                                  ),
                                ),
                                Expanded(
                                  child: _topStatTile(
                                    value:
                                    '${profileUser['total_followers'] ?? 0}',
                                    label: ('Followers').appTr,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: kHeight * 0.02),
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
                    SizedBox(height: kHeight * 0.01),
                    // ✅ VISIT PROFILE FIX: visitor user-er identity badge show korbe, nijer auth badge na.
                    userTypeBadges(
                      userType: profileUser['user_type'],
                      agencyType: profileUser['agency_type'],
                      reselerType: profileUser['reseler_type'],
                      hostType: profileUser['host_type'],
                      kHeight: kHeight,
                    ),
                    SizedBox(height: kHeight * 0.01),


                    // ✅ TOP CONTRIBUTION FIX: professional animated top gifter card.
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
                    // ✅ TOP GIFTER FIX: visitor user-er id pass kora hocche.
                    // API: auth_user_gift_sender_rank/{userId}
                    _visitorTopContributionCardSection(
                      myprofileController: myprofileController,
                      userId: _safeText(
                        user['id'] ?? profileUser['id'] ?? profileUser['user_id'],
                      ),
                    ),
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
                    // ✅ VISIT PROFILE FIX: host card visitor user-er host_type diye check korbe.
                    (profileUser['host_type']?.toString().trim().toLowerCase() == 'host')
                        ?   // ✅ AGENCY DATA FIX: API-er exact user_agency data show.
                    _visitorAgencyInfoCard(userAgency)
                        : const SizedBox.shrink(),


                    // ✅ VISIT PROFILE FIX: visitor profile CP card API cp_data diye show hobe.
                    // ✅ CP thakle only CP title + CP card show hobe
                    if (_visitorHasActiveCp(cpData)) ...[
                      Row(
                        children: [
                          const SizedBox(width: 12),
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

                      _visitorPremiumCpCardSection(
                        user: user,
                        cpData: cpData,
                      ),

                      SizedBox(height: kHeight * 0.01),
                    ],





                    _VisitorProfileFamilySection(
                      myprofileController: myprofileController,
                      userId: _safeText(
                        user['id'] ?? profileUser['id'] ?? profileUser['user_id'],
                      ),
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

                    // ✅ VISIT PROFILE FIX: visitor user-er receive_gift_list API response theke show korbe.
                    Padding(
                      padding: EdgeInsets.only(left: kHeight * 0.012),
                      child: FutureBuilder(
                        future: myprofileController.showProfileReciverList(userID: '${user['id']}'),
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

                    // SizedBox(height: 0),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     Padding(
                    //       padding: const EdgeInsets.only(left: 12.0),
                    //       child: Text(
                    //         ('Gifts - Sent').appTr,
                    //         style: GoogleFonts.roboto(
                    //           fontSize: kHeight * 0.019,
                    //           color: Colors.black.withOpacity(.8),
                    //           fontWeight: FontWeight.w600,
                    //         ),
                    //       ),
                    //     ),
                    //     IconButton(
                    //       onPressed: () {},
                    //       icon: Icon(Icons.chevron_right),
                    //     ),
                    //   ],
                    // ),

                    SizedBox(height: 15),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(data),
      ),
    );
  }

  Widget _visitorSafeLevelFrame({
    required String levelImage,
    required String level,
  }) {
    final String cleanLevelImage = _safeText(levelImage);
    final String cleanLevel = _safeText(level, fallback: '0');

    if (cleanLevelImage.isEmpty) {
      return Container(
        height: kHeight * 0.028,
        padding: EdgeInsets.symmetric(horizontal: kWeight * 0.018),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD76B),
              Color(0xFFFF8A00),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(.55), width: .8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA000).withOpacity(.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          ('Lv $cleanLevel').appTr,
          maxLines: 1,
          style: GoogleFonts.poppins(
            fontSize: kHeight * 0.012,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    return LevelFrame(
      levelImage: cleanLevelImage,
      level: cleanLevel,
    );
  }

  Widget _defaultCover() {
    return Image.asset(
      'assets/images/profile pic.jpg',
      fit: BoxFit.cover,
    );
  }

  Widget _roundActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: kHeight*0.05,
        width: kHeight*0.05,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF51F55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: kHeight*0.02,
        ),
      ),
    );
  }

  Widget _profileImageWithFrame({
    required String profileImage,
    required String frameUrl,
  }) {
    final bool hasFrame = frameUrl.isNotEmpty;
    final bool isSvgaFrame = frameUrl.toLowerCase().endsWith('.svga');

    return SizedBox(
      height: kHeight*0.15,
      width: kHeight*0.15,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: profileImage,
              height: kHeight*0.1,
              width: kHeight*0.1,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                height: 104,
                width: 104,
                color: Colors.grey.shade300,
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.grey,
                  size: 48,
                ),
              ),
            ),
          ),

          if (hasFrame)
            SizedBox(
              height: kHeight*0.15,
              width: kHeight*0.15,
              child: isSvgaFrame
                  ? SVGAEasyPlayer(
                resUrl: frameUrl,
                fit: BoxFit.cover,
              )
                  : CachedNetworkImage(
                imageUrl: frameUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
  Widget _identityBadgesRow(List baseList) {
    if (baseList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: SizedBox(
        height: kHeight*0.03,
        width: double.infinity,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: baseList.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = baseList[index];
            final imageUrl = _fullUrl(item['image_url'] ?? item['image']);
            final title = _safeText(item['type'], fallback: ('Badge').appTr);

            return Container(

              height: kHeight*0.03,
              constraints: const BoxConstraints(minWidth: 110),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    _textIdentityBadge(title),
              )
                  : _textIdentityBadge(title),
            );
          },
        ),
      ),
    );
  }

  Widget _textIdentityBadge(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD86B),
            Color(0xFFFF4B6E),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _topStatTile({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: kHeight*0.02,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: kHeight*0.014,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: kHeight*0.018,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF2B2B2B),
      ),
    );
  }

  Widget _menuRow({
    required String title,
    required VoidCallback onTap,
    Color arrowColor = const Color(0xFF9E9E9E),
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: kHeight*0.018,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2B2B2B),
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: kHeight*0.02,
            color: arrowColor,
          ),
        ],
      ),
    );
  }

  // ✅ AGENCY CARD DESIGN FIX: user_agency card now matches host agency card design.
  // Source API: user_agency {name, user_id, agency_id, host_agency_id, profile_image_url, profile_image, host_type}
  Widget _visitorAgencyInfoCard(Map<String, dynamic> agency) {
    if (agency.isEmpty) {
      return const SizedBox.shrink();
    }

    final String agencyName = _safeText(agency['name'], fallback: 'Host Account');
    final String userId = _safeText(agency['user_id'], fallback: 'N/A');
    final String agencyId = _safeText(agency['agency_id'], fallback: 'N/A');
    final String hostType = _safeText(agency['host_type'], fallback: ('Host').appTr);
    final String profileImage = _safeText(
      agency['profile_image_url'] ?? agency['profile_image'],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        /// Same responsive size as agency card.
        final double cardHeight = (width * 0.25).clamp(86.0, 105.0).toDouble();
        final double radius = 5;
        final double avatarBox = (cardHeight * 0.82).clamp(70.0, 86.0).toDouble();

        return Container(
          width: double.infinity,
          height: cardHeight,
          margin: EdgeInsets.symmetric(
            horizontal: kWeight * 0.025,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF36310E),
                          Color(0xFF6B5815),
                          Color(0xFF8A7427),
                          Color(0xFF5C4B14),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _VisitorAgencyCardPainter(),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: const Color(0xFFFFDE70).withOpacity(0.32),
                        width: 1,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: (width * 0.032).clamp(10.0, 14.0).toDouble(),
                      vertical: (cardHeight * 0.08).clamp(6.0, 9.0).toDouble(),
                    ),
                    child: Row(
                      children: [
                        _visitorAgencyProfileImage(
                          profileImage: profileImage,
                          size: avatarBox,
                        ),
                        SizedBox(width: (width * 0.03).clamp(9.0, 13.0).toDouble()),
                        Expanded(
                          child: _visitorAgencyInformation(
                            agencyName: agencyName,
                            userId: userId,
                            agencyId: agencyId,
                            hostType: hostType,
                            cardHeight: cardHeight,
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
      },
    );
  }

  Widget _visitorAgencyProfileImage({
    required String profileImage,
    required double size,
  }) {
    final double imageSize = size * 0.62;
    final String imageUrl = _fullUrl(profileImage);

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD45B),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD45B).withOpacity(0.22),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl.isEmpty
                  ? Container(
                color: const Color(0xFF3A3310),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
              )
                  : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Container(
                    color: const Color(0xFF3A3310),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFD45B),
                      ),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return const Icon(
                    Icons.person_rounded,
                    color: Colors.white70,
                    size: 28,
                  );
                },
              ),
            ),
          ),

          /// Same agency frame as reference card.
          SizedBox(
            height: size,
            width: size,
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _visitorAgencyInformation({
    required String agencyName,
    required String userId,
    required String agencyId,
    required String hostType,
    required double cardHeight,
  }) {
    final double titleFont = (cardHeight * 0.13).clamp(12.0, 14.5).toDouble();
    final double smallFont = (cardHeight * 0.105).clamp(10.0, 12.0).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: _visitorAgencyNameRibbon(
                title: agencyName,
                fontSize: titleFont,
              ),
            ),
            const SizedBox(width: 6),
            _visitorAgencyMemberChip(
              text: hostType.toLowerCase() == 'host' ? ('Host').appTr: hostType,
              fontSize: smallFont,
            ),
          ],
        ),
        SizedBox(height: (cardHeight * 0.07).clamp(5.0, 8.0).toDouble()),
        _visitorAgencyRankPill(cardHeight: cardHeight),
        SizedBox(height: (cardHeight * 0.07).clamp(5.0, 8.0).toDouble()),
        Text(
          ('Agency ID:$agencyId  |  UID:$userId').appTr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontSize: smallFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _visitorAgencyNameRibbon({
    required String title,
    required double fontSize,
  }) {
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 6, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7A0D12).withOpacity(0.88),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFFFC94B),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 18,
            width: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD35C),
                  Color(0xFFC56E00),
                ],
              ),
            ),
            child: const Icon(
              Icons.card_membership_rounded,
              size: 12,
              color: Color(0xFF74210B),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFFF1B4),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitorAgencyMemberChip({
    required String text,
    required double fontSize,
  }) {
    final String cleanText = text.trim().isEmpty ? ('Host').appTr: text.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF236577).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cleanText,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _visitorAgencyRankPill({
    required double cardHeight,
  }) {
    return Container(
      height: (cardHeight * 0.22).clamp(20.0, 24.0).toDouble(),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD45B).withOpacity(0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD45B),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            ('No.99+').appTr,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: (cardHeight * 0.105).clamp(10.0, 12.0).toDouble(),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

}




// ============================================================================
// ✅ PROFILE VISITORS PROFESSIONAL STAT + LIST
// - Header-e total_unique_visitors show kore.
// - Visitors stat click korle professional bottom sheet open hoy.
// - List-e profile image, name, ID, visit_count, visited_at show kore.
// - Pull-to-refresh support ache.
// ============================================================================
class _VisitorProfileVisitsStat extends StatefulWidget {
  final MyprofileController myprofileController;
  final int userId;

  const _VisitorProfileVisitsStat({
    required this.myprofileController,
    required this.userId,
  });

  @override
  State<_VisitorProfileVisitsStat> createState() =>
      _VisitorProfileVisitsStatState();
}

class _VisitorProfileVisitsStatState extends State<_VisitorProfileVisitsStat> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VisitorProfileVisitsStat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _load();
    }
  }

  void _load() {
    if (widget.userId <= 0) return;

    widget.myprofileController.showProfileVisitorList(
      userId: widget.userId,
      force: true,
    );
  }

  void _openVisitorList() {
    if (widget.userId <= 0) return;

    Get.bottomSheet(
      _VisitorProfileVisitorsBottomSheet(
        myprofileController: widget.myprofileController,
        userId: widget.userId,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.45),
    );

    // Sheet open howar sathe latest count/list refresh.
    widget.myprofileController.showProfileVisitorList(
      userId: widget.userId,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool loading =
          widget.myprofileController.isProfileVisitorsLoading.value;
      final int total =
          widget.myprofileController.totalUniqueProfileVisitors.value;

      return InkWell(
        onTap: _openVisitorList,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading && total == 0
                    ? SizedBox(
                  key: const ValueKey('visitor-loading'),
                  height: kHeight * 0.020,
                  width: kHeight * 0.020,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  '$total',
                  key: ValueKey<int>(total),
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.020,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ('Visitors').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: kHeight * 0.0132,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: kWeight * 0.004),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: kHeight * 0.015,
                    color: Colors.white.withOpacity(.82),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _VisitorProfileVisitorsBottomSheet extends StatelessWidget {
  final MyprofileController myprofileController;
  final int userId;

  const _VisitorProfileVisitorsBottomSheet({
    required this.myprofileController,
    required this.userId,
  });

  Future<void> _refresh() {
    return myprofileController.showProfileVisitorList(
      userId: userId,
      force: true,
    ).then((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = MediaQuery.of(context).size.height * .78;

    return SafeArea(
      top: false,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F8FB),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: kHeight * 0.010),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D4DB),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                kWeight * .045,
                kHeight * .016,
                kWeight * .035,
                kHeight * .010,
              ),
              child: Row(
                children: [
                  Container(
                    height: kHeight * .045,
                    width: kHeight * .045,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF4B6E),
                          Color(0xFFFF8A65),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.visibility_rounded,
                      color: Colors.white,
                      size: kHeight * .023,
                    ),
                  ),
                  SizedBox(width: kWeight * .025),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ('Profile Visitors').appTr,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF202028),
                            fontSize: kHeight * .020,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: kHeight * .001),
                        Text(
                          ('People who visited this profile').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8C8C96),
                            fontSize: kHeight * .0115,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Get.back(),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: kHeight * .038,
                      width: kHeight * .038,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEDF2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE0E0E8),
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: const Color(0xFF555560),
                        size: kHeight * .021,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              final int unique =
                  myprofileController.totalUniqueProfileVisitors.value;
              final int visits = myprofileController.totalProfileVisits.value;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: kWeight * .040,
                  vertical: kHeight * .006,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _visitorProfileSummaryCard(
                        icon: Icons.people_alt_rounded,
                        value: '$unique',
                        label: ('Unique Visitors').appTr,
                      ),
                    ),
                    SizedBox(width: kWeight * .025),
                    Expanded(
                      child: _visitorProfileSummaryCard(
                        icon: Icons.remove_red_eye_rounded,
                        value: '$visits',
                        label: ('Total Visits').appTr,
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: kHeight * .006),
            Expanded(
              child: Obx(() {
                final bool loading =
                    myprofileController.isProfileVisitorsLoading.value;
                final String error =
                myprofileController.profileVisitorsError.value.trim();
                final List<Map<String, dynamic>> visitors =
                myprofileController.profileVisitorsList.toList();

                if (loading && visitors.isEmpty) {
                  return Center(
                    child: SizedBox(
                      height: kHeight * .030,
                      width: kHeight * .030,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFFFF4B6E),
                      ),
                    ),
                  );
                }

                if (error.isNotEmpty && visitors.isEmpty) {
                  return _visitorProfileVisitorsMessage(
                    icon: Icons.cloud_off_rounded,
                    title: ('Could not load visitors').appTr,
                    subtitle: error,
                    onRetry: _refresh,
                  );
                }

                if (visitors.isEmpty) {
                  return _visitorProfileVisitorsMessage(
                    icon: Icons.visibility_off_rounded,
                    title: ('No visitors yet').appTr,
                    subtitle: ('Profile visitors will appear here').appTr,
                    onRetry: _refresh,
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFFF4B6E),
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      kWeight * .040,
                      kHeight * .008,
                      kWeight * .040,
                      kHeight * .025,
                    ),
                    itemCount: visitors.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: kHeight * .008),
                    itemBuilder: (context, index) {
                      return _visitorProfileVisitorListTile(
                        visitor: visitors[index],
                        index: index,
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _visitorProfileSummaryCard({
  required IconData icon,
  required String value,
  required String label,
}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * .025,
      vertical: kHeight * .012,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFECECF2),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          height: kHeight * .036,
          width: kHeight * .036,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEF2),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF4B6E),
            size: kHeight * .018,
          ),
        ),
        SizedBox(width: kWeight * .018),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF22222A),
                  fontSize: kHeight * .018,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF8F8F98),
                  fontSize: kHeight * .0105,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _visitorProfileVisitorListTile({
  required Map<String, dynamic> visitor,
  required int index,
}) {
  final String name = _visitorSafeText(
    visitor['name'],
    fallback: ('User').appTr,
  );
  final String id = _visitorSafeText(
    visitor['user_id'] ?? visitor['id'],
    fallback: 'N/A',
  );
  final String image = _visitorFullUrl(
    visitor['profile_image_url'] ?? visitor['profile_image'],
  );
  final int visitCount = _visitorProfileSafeInt(visitor['visit_count']);
  final String visitedAt = _visitorProfileVisitedAt(visitor['visited_at']);

  return Material(
    color: Colors.transparent,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * .025,
        vertical: kHeight * .010,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFECECF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.032),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: kHeight * .052,
                width: kHeight * .052,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD45B),
                      Color(0xFFFF4B6E),
                      Color(0xFF8C5BFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipOval(
                  child: image.isEmpty
                      ? Container(
                    color: const Color(0xFFF0F0F4),
                    child: Icon(
                      Icons.person_rounded,
                      color: const Color(0xFFA0A0AA),
                      size: kHeight * .027,
                    ),
                  )
                      : CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFF0F0F4),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF0F0F4),
                      child: Icon(
                        Icons.person_rounded,
                        color: const Color(0xFFA0A0AA),
                        size: kHeight * .027,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -1,
                child: Container(
                  height: kHeight * .018,
                  width: kHeight * .018,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4B6E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: kHeight * .0085,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: kWeight * .025),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262E),
                    fontSize: kHeight * .0145,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: kHeight * .002),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: kWeight * .012,
                        vertical: kHeight * .0015,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ('ID $id').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF777781),
                          fontSize: kHeight * .0105,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: kWeight * .010),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: id));
                        Fluttertoast.showToast(
                          msg: ('ID copied').appTr,
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.copy_rounded,
                          size: kHeight * .014,
                          color: const Color(0xFF9A9AA4),
                        ),
                      ),
                    ),
                  ],
                ),
                if (visitedAt.isNotEmpty) ...[
                  SizedBox(height: kHeight * .003),
                  Text(
                    visitedAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFAAAAAF),
                      fontSize: kHeight * .0097,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: kWeight * .018),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: kWeight * .018,
              vertical: kHeight * .007,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Text(
                  '$visitCount',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFF4B6E),
                    fontSize: kHeight * .014,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  visitCount == 1 ? ('Visit').appTr : ('Visits').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFB56B7B),
                    fontSize: kHeight * .0088,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _visitorProfileVisitorsMessage({
  required IconData icon,
  required String title,
  required String subtitle,
  required Future<void> Function() onRetry,
}) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * .08,
      vertical: kHeight * .070,
    ),
    children: [
      Center(
        child: Container(
          height: kHeight * .076,
          width: kHeight * .076,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEEF2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF4B6E),
            size: kHeight * .034,
          ),
        ),
      ),
      SizedBox(height: kHeight * .018),
      Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: const Color(0xFF2A2A32),
          fontSize: kHeight * .016,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: kHeight * .006),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: const Color(0xFF93939D),
          fontSize: kHeight * .0115,
          fontWeight: FontWeight.w500,
        ),
      ),
      SizedBox(height: kHeight * .018),
      Center(
        child: OutlinedButton.icon(
          onPressed: () {
            onRetry();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: Text(('Refresh').appTr),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF4B6E),
            side: const BorderSide(
              color: Color(0xFFFFB7C5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    ],
  );
}

int _visitorProfileSafeInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

String _visitorProfileVisitedAt(dynamic value) {
  final String raw = _visitorSafeText(value);
  if (raw.isEmpty) return '';

  final DateTime? date = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (date == null) return raw;

  String two(int number) => number.toString().padLeft(2, '0');

  return '${date.year}-${two(date.month)}-${two(date.day)}  '
      '${two(date.hour)}:${two(date.minute)}';
}


// ============================================================================
// ✅ TOP CONTRIBUTION PROFESSIONAL CARD FIX
// - Shows the user who gifted most at the top.
// - Shows profile image, frame, name, ID, gift coin/count.
// - Right side profiles move smoothly right-to-left inside the card.
// - Uses existing MyprofileController.showProfileContributionList().
// ============================================================================
Widget _visitorTopContributionCardSection({
  required MyprofileController myprofileController,
  required String userId,
}) {
  if (userId.trim().isEmpty || userId.trim() == '0') {
    return const SizedBox.shrink();
  }

  return _VisitorTopContributionCard(
    myprofileController: myprofileController,
    userId: userId,
  );
}

class _VisitorTopContributionCard extends StatefulWidget {
  final MyprofileController myprofileController;
  final String userId;

  const _VisitorTopContributionCard({
    required this.myprofileController,
    required this.userId,
  });

  @override
  State<_VisitorTopContributionCard> createState() =>
      _VisitorTopContributionCardState();
}

class _VisitorTopContributionCardState extends State<_VisitorTopContributionCard> {
  late final Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.myprofileController.showProfileContributionList(
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        final List<dynamic> rawList = widget.myprofileController.profileContributionList;
        final List<Map<String, dynamic>> contributors =
        _visitorNormalizeContributionList(rawList);

        if (snapshot.connectionState == ConnectionState.waiting &&
            contributors.isEmpty) {
          return _visitorTopContributionLoadingCard();
        }

        if (contributors.isEmpty) {
          return const SizedBox.shrink();
        }

        final Map<String, dynamic> topItem = contributors.first;
        final Map<String, dynamic> topSender = _visitorContributionSender(topItem);
        final String topName = _visitorSafeText(
          topSender['name'],
          fallback: ('Top Gifter').appTr,
        );
        final String topId = _visitorSafeText(
          topSender['user_id'] ?? topSender['id'],
          fallback: 'N/A',
        );
        final String topImage = _visitorFullUrl(
          topSender['profile_image_url'] ?? topSender['profile_image'],
        );
        final String topFrame = _visitorContributionFrameUrl(topSender);
        final String topCoins = _visitorCompactNumber(
          _visitorContributionCoins(topItem),
        );
        final String topCount = _visitorSafeText(
          topItem['gift_receive_count'] ??
              topItem['gift_count'] ??
              topItem['count'] ??
              topItem['total_gifts'],
          fallback: '0',
        );

        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Get.to(
              Profileconribution(),
              arguments: {'userId': widget.userId},
              transition: Transition.rightToLeft,
            );
          },
          child: Container(
            width: double.infinity,
            height: (kHeight * 0.128).clamp(102.0, 122.0).toDouble(),
            margin: EdgeInsets.symmetric(
              horizontal: kWeight * 0.030,
              vertical: kHeight * 0.010,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient:  LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A0298),
                  Color(0xFF700287).withOpacity(.6),
                  Color(0xFF4A0298),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4F9A).withOpacity(0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _VisitorTopContributionPainter(),
                    ),
                  ),
                  Positioned(
                    right: -kWeight * 0.10,
                    top: -kHeight * 0.050,
                    child: Container(
                      height: kHeight * 0.17,
                      width: kHeight * 0.17,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(.22),
                            Colors.white.withOpacity(.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: kWeight * 0.035,
                      vertical: kHeight * 0.010,
                    ),
                    child: Row(
                      children: [
                        _visitorTopContributorAvatar(
                          imageUrl: topImage,
                          frameUrl: topFrame,
                        ),
                        SizedBox(width: kWeight * 0.025),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: kWeight * 0.018,
                                      vertical: kHeight * 0.003,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.17),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(.22),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.emoji_events_rounded,
                                          color: const Color(0xFFFFD45B),
                                          size: kHeight * 0.014,
                                        ),
                                        SizedBox(width: kWeight * 0.006),
                                        Text(
                                          ('Top Gifter').appTr,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: kHeight * 0.0105,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: kHeight * 0.006),
                              Text(
                                topName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: kHeight * 0.018,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(.18),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: kHeight * 0.003),
                              Row(
                                children: [
                                  _visitorContributionSmallPill(
                                    icon: Icons.badge_rounded,
                                    text: ('ID $topId').appTr,
                                  ),
                                  SizedBox(width: kWeight * 0.010),
                                  _visitorContributionSmallPill(
                                    icon: Icons.diamond_rounded,
                                    text: topCoins,
                                  ),
                                  if (topCount != '0') ...[
                                    SizedBox(width: kWeight * 0.010),
                                    _visitorContributionSmallPill(
                                      icon: Icons.card_giftcard_rounded,
                                      text: ('x$topCount').appTr,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: kWeight * 0.012),
                        SizedBox(
                          width: kWeight * 0.30,
                          height: double.infinity,
                          child: _VisitorTopContributionMarquee(
                            contributors: contributors,
                          ),
                        ),
                        SizedBox(width: kWeight * 0.004),
                        Container(
                          height: kHeight * 0.032,
                          width: kHeight * 0.032,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.22),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: kHeight * 0.014,
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
      },
    );
  }
}

Widget _visitorTopContributionLoadingCard() {
  return Container(
    width: double.infinity,
    height: (kHeight * 0.128).clamp(102.0, 122.0).toDouble(),
    margin: EdgeInsets.symmetric(
      horizontal: kWeight * 0.030,
      vertical: kHeight * 0.010,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: LinearGradient(
        colors: [
          const Color(0xFF7B1D62).withOpacity(.78),
          const Color(0xFFFF4F9A).withOpacity(.78),
        ],
      ),
    ),
    child: Center(
      child: SizedBox(
        height: kHeight * 0.024,
        width: kHeight * 0.024,
        child: const CircularProgressIndicator(
          strokeWidth: 2.3,
          color: Colors.white,
        ),
      ),
    ),
  );
}

List<Map<String, dynamic>> _visitorNormalizeContributionList(List rawList) {
  final List<Map<String, dynamic>> list = rawList
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => _visitorContributionSender(item).isNotEmpty)
      .toList();

  list.sort((a, b) => _visitorContributionCoins(b)
      .compareTo(_visitorContributionCoins(a)));

  return list;
}

Map<String, dynamic> _visitorContributionSender(Map<String, dynamic> item) {
  final dynamic sender = item['sender'] ??
      item['user'] ??
      item['gifter'] ??
      item['from_user'] ??
      item['top_user'];

  if (sender is Map<String, dynamic>) return sender;
  if (sender is Map) return Map<String, dynamic>.from(sender);
  return <String, dynamic>{};
}

num _visitorContributionCoins(Map<String, dynamic> item) {
  final dynamic raw = item['total_coins'] ??
      item['sender_total_coins'] ??
      item['gift_total_coins'] ??
      item['total_gift_coin'] ??
      item['gift_coin'] ??
      item['coin'] ??
      _visitorContributionSender(item)['gifts_coins'];

  if (raw is num) return raw;
  return num.tryParse(raw?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
}

String _visitorContributionFrameUrl(Map<String, dynamic> sender) {
  final Map<String, dynamic> history =
  _visitorSafeMap(sender['asset_purchase_history']);
  final Map<String, dynamic> asset = _visitorSafeMap(history['asset']);
  final String framePath = _visitorSafeText(asset['asset']);
  final String type = _visitorSafeText(asset['type']).toLowerCase();

  if (framePath.isEmpty) return '';
  if (type.isNotEmpty && type != 'frame') return '';

  return _visitorFullUrl(framePath);
}

String _visitorCompactNumber(num value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
  }
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  }
  return value.toInt().toString();
}

Widget _visitorTopContributorAvatar({
  required String imageUrl,
  required String frameUrl,
}) {
  final double boxSize = kHeight * 0.088;
  final double imageSize = kHeight * 0.060;

  return SizedBox(
    height: boxSize,
    width: boxSize,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: imageSize,
          width: imageSize,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD45B),
                Color(0xFFFF4F9A),
                Color(0xFF8C3BFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD45B).withOpacity(.32),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: _visitorNetworkCircleImage(
              imageUrl: imageUrl,
              size: imageSize,
            ),
          ),
        ),
        if (frameUrl.trim().isNotEmpty)
          SizedBox(
            height: boxSize,
            width: boxSize,
            child: frameUrl.toLowerCase().endsWith('.svga')
                ? SVGAEasyPlayer(
              resUrl: frameUrl,
              fit: BoxFit.cover,
            )
                : CachedNetworkImage(
              imageUrl: frameUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Positioned(
          right: 0,
          bottom: kHeight * 0.006,
          child: Container(
            padding: EdgeInsets.all(kHeight * 0.004),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD45B), Color(0xFFFF9800)],
              ),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: kHeight * 0.014,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _visitorContributionSmallPill({
  required IconData icon,
  required String text,
}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.012,
      vertical: kHeight * 0.0025,
    ),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.18),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withOpacity(.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: const Color(0xFFFFD45B),
          size: kHeight * 0.012,
        ),
        SizedBox(width: kWeight * 0.005),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(.92),
            fontSize: kHeight * 0.0105,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _VisitorTopContributionMarquee extends StatefulWidget {
  final List<Map<String, dynamic>> contributors;

  const _VisitorTopContributionMarquee({
    required this.contributors,
  });

  @override
  State<_VisitorTopContributionMarquee> createState() =>
      _VisitorTopContributionMarqueeState();
}

class _VisitorTopContributionMarqueeState
    extends State<_VisitorTopContributionMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contributors.isEmpty) return const SizedBox.shrink();

    final List<Map<String, dynamic>> contributors = widget.contributors.length == 1
        ? [...widget.contributors, ...widget.contributors]
        : widget.contributors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double avatarSize = (kHeight * 0.038).clamp(30.0, 38.0).toDouble();
        final double gap = kWeight * 0.018;
        final double cycleWidth = (avatarSize + gap) * contributors.length;
        final List<Map<String, dynamic>> repeated = [
          ...contributors,
          ...contributors,
        ];

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double dx = width - (_controller.value * (cycleWidth + width));

              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: repeated.map((item) {
                final Map<String, dynamic> sender = _visitorContributionSender(item);
                final String image = _visitorFullUrl(
                  sender['profile_image_url'] ?? sender['profile_image'],
                );
                final String name = _visitorSafeText(sender['name'], fallback: ('User').appTr);

                return Container(
                  margin: EdgeInsets.only(right: gap),
                  height: avatarSize + 16,
                  width: avatarSize,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: avatarSize,
                        width: avatarSize,
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD45B),
                              Color(0xFFFF4F9A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ClipOval(
                          child: _visitorNetworkCircleImage(
                            imageUrl: image,
                            size: avatarSize,
                          ),
                        ),
                      ),
                      SizedBox(height: kHeight * 0.002),
                      Text(
                        name.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(.88),
                          fontSize: kHeight * 0.0088,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _VisitorTopContributionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final Paint shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(.17),
          Colors.transparent,
          Colors.black.withOpacity(.14),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, shinePaint);

    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(.045)
      ..strokeWidth = 1.2;

    for (double x = -size.height; x < size.width * 1.4; x += 24) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }

    final Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFFD45B).withOpacity(.15);

    canvas.drawCircle(
      Offset(size.width * .88, size.height * .20),
      size.height * .55,
      circlePaint,
    );

    final Paint bottomGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, 1.0),
        radius: 1.0,
        colors: [
          const Color(0xFFFFD45B).withOpacity(.18),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bottomGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _VisitorAgencyCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final Paint leftShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(0.32),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, leftShade);

    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.95, -0.9),
        radius: 1.2,
        colors: [
          const Color(0xFFFFE189).withOpacity(0.16),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    final Paint stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1.2;

    for (double x = size.width * 0.35; x < size.width * 1.2; x += 36) {
      canvas.drawLine(
        Offset(x, -10),
        Offset(x - 55, size.height + 12),
        stripePaint,
      );
    }

    final Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFD45B).withOpacity(0.12);

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.16),
      size.height * 0.55,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.86),
      size.height * 0.35,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ============================================================================
// ✅ VISIT PROFILE FAMILY CARD FIX
// - Visitor profile page-e same family card show hobe.
// - API: userFamily(id: userId)
// - Card click korle family-detail page open hobe readOnly mode-e.
// ============================================================================

class _VisitorProfileFamilySection extends StatefulWidget {
  final MyprofileController myprofileController;
  final String userId;

  const _VisitorProfileFamilySection({
    required this.myprofileController,
    required this.userId,
  });

  @override
  State<_VisitorProfileFamilySection> createState() =>
      _VisitorProfileFamilySectionState();
}

class _VisitorProfileFamilySectionState extends State<_VisitorProfileFamilySection> {
  Future<Map<String, dynamic>?>? _future;
  String _loadedUserId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VisitorProfileFamilySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _load();
    }
  }

  void _load() {
    final uid = widget.userId.trim();
    _loadedUserId = uid;
    if (uid.isEmpty || uid == 'null') {
      _future = Future<Map<String, dynamic>?>.value(null);
      return;
    }
    _future = widget.myprofileController.showProfileFamilyData(userID: uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedUserId.isEmpty || _loadedUserId == 'null') {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.only(top: kHeight * 0.010),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _visitorFamilyTitle(('Family').appTr),
                _visitorFamilyCardShimmer(),
              ],
            ),
          );
        }

        final Map<String, dynamic>? family = snapshot.data;
        if (family == null || family.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(top: kHeight * 0.010),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _visitorFamilyTitle(('Family').appTr),
              _visitorFamilyCard(family),
              SizedBox(height: kHeight * 0.006),
            ],
          ),
        );
      },
    );
  }
}

Widget _visitorFamilyTitle(String title) {
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

Widget _visitorFamilyCardShimmer() {
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
            const Color(0xFF120A2A).withOpacity(.78),
            const Color(0xFF542E84).withOpacity(.70),
            const Color(0xFFB35DFF).withOpacity(.56),
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

Widget _visitorFamilyCard(Map<String, dynamic> family) {
  final int familyId = _visitorFamilyInt(family['id']);
  final String name = _visitorFamilyText(family['name'], fallback: ('Family').appTr);
  final String familyCode = _visitorFamilyText(
    family['family_code'],
    fallback: familyId > 0 ? '$familyId' : '',
  );
  final String logoUrl = _visitorFamilyImageUrl(family['logo_url'] ?? family['logo']);
  final int levelNo = _visitorFamilyInt(family['level_no']);
  final int membersCount = _visitorFamilyInt(family['members_count']);
  final int memberLimit = _visitorFamilyInt(family['member_limit']);

  final Map<String, dynamic> badge = _visitorFamilyMap(family['badge']);
  final String badgeName = _visitorFamilyText(
    badge['name'],
    fallback: 'Family Badge',
  );
  final int badgeLevel = _visitorFamilyInt(badge['badge_level']);

  final Map<String, dynamic> userMember = _visitorFamilyMap(family['user_member']);
  final String role = _visitorFamilyText(userMember['role'], fallback: 'member');
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
              Color(0xFF17082B),
              Color(0xFF4A1F78),
              Color(0xFFA855F7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(.28),
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
                painter: _VisitorFamilyCardPatternPainter(),
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
                    color: Colors.white.withOpacity(.075),
                    width: kHeight * 0.020,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(width: kWeight * 0.018),
                _visitorFamilyLogo(logoUrl),
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
                              child: _visitorFamilyNameBadge(name),
                            ),
                            SizedBox(width: kWeight * 0.010),
                            _visitorFamilyRoleBadge(roleText),
                          ],
                        ),
                        SizedBox(height: kHeight * 0.006),
                        Row(
                          children: [
                            _visitorFamilyRankPill(
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
                                  color: Colors.white.withOpacity(.80),
                                  fontSize: kHeight * 0.014,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.groups_rounded,
                              color: Colors.white.withOpacity(.74),
                              size: kHeight * 0.017,
                            ),
                            SizedBox(width: kWeight * 0.010),
                            Text(
                              '$membersCount/$memberLimit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(.80),
                                fontSize: kHeight * 0.014,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: kWeight * 0.010),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white.withOpacity(.62),
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

Widget _visitorFamilyLogo(String logoUrl) {
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
                  Color(0xFFD946EF),
                  Color(0xFF4A1F78),
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
            color: const Color(0xFF17082B),
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

Widget _visitorFamilyNameBadge(String name) {
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

Widget _visitorFamilyRoleBadge(String roleText) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: kWeight * 0.018,
      vertical: kHeight * 0.004,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFF2F6BFF),
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

Widget _visitorFamilyRankPill(int rankNo) {
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

Map<String, dynamic> _visitorFamilyMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _visitorFamilyText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

int _visitorFamilyInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ?? 0;
}

String _visitorFamilyImageUrl(dynamic value) {
  final text = _visitorFamilyText(value);
  if (text.isEmpty) return '';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  return _visitorFullUrl(text);
}

class _VisitorFamilyCardPatternPainter extends CustomPainter {
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

// ============================================================================
// ✅ VISIT PROFILE API DESIGN FIX HELPERS
// - Visitor profile page now uses API response User Data + cp_data.
// - CP thakle header avatar and CP card both show hobe.
// - Gifts received API response-er receive_gift_list theke show hobe.
// ============================================================================

Map<String, dynamic> _visitorSafeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _visitorSafeText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final String text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

String _visitorCleanBaseUrl() {
  String baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
  if (baseUrl.endsWith('/api')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 4);
  }
  return baseUrl;
}

String _visitorFullUrl(dynamic path, {String fallback = ''}) {
  final String text = _visitorSafeText(path);
  if (text.isEmpty || text == 'No Photo') return fallback;
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  return '${_visitorCleanBaseUrl()}/${text.replaceAll(RegExp(r'^/+'), '')}';
}

String _visitorId(dynamic value) => _visitorSafeText(value);

Map<String, dynamic> _visitorCpPartner({
  required Map<String, dynamic> user,
  required Map<String, dynamic> cpData,
}) {
  final Map<String, dynamic> directPartner = _visitorSafeMap(cpData['cp_partner']);
  if (directPartner.isNotEmpty) return directPartner;

  final Map<String, dynamic> sender = _visitorSafeMap(cpData['sender']);
  final Map<String, dynamic> receiver = _visitorSafeMap(cpData['receiver']);

  final String visitorId = _visitorId(user['id'] ?? user['user_id']);
  final String senderId = _visitorId(sender['id'] ?? sender['user_id']);
  final String receiverId = _visitorId(receiver['id'] ?? receiver['user_id']);

  if (visitorId.isNotEmpty && senderId == visitorId && receiver.isNotEmpty) {
    return receiver;
  }

  if (visitorId.isNotEmpty && receiverId == visitorId && sender.isNotEmpty) {
    return sender;
  }

  if (sender.isNotEmpty) return sender;
  if (receiver.isNotEmpty) return receiver;
  return <String, dynamic>{};
}

bool _visitorHasActiveCp(Map<String, dynamic> cpData) {
  if (cpData.isEmpty) return false;

  final String status = _visitorSafeText(
    _visitorSafeMap(cpData['current_cp'])['status'],
  ).toLowerCase();

  final String hasCpText = _visitorSafeText(cpData['has_cp']).toLowerCase();

  return hasCpText == 'true' ||
      hasCpText == '1' ||
      status == 'accepted' ||
      _visitorSafeMap(cpData['cp_partner']).isNotEmpty;
}

Widget _visitorProfileHeaderAvatar({
  required Map<String, dynamic> user,
  required Map<String, dynamic> cpData,
  required String profileImage,
  required String frameUrl,
}) {
  final bool hasCp = _visitorHasActiveCp(cpData);
  final Map<String, dynamic> partner = _visitorCpPartner(user: user, cpData: cpData);
  final String partnerImage = _visitorFullUrl(
    partner['profile_image_url'] ?? partner['profile_image'],
  );
  final String partnerName = _visitorSafeText(partner['name']);

  if (!hasCp || partnerImage.isEmpty) {
    return _visitorSingleAvatar(
      imageUrl: profileImage,
      frameUrl: frameUrl,
      showFrame: frameUrl.isNotEmpty,
    );
  }

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
          child: _visitorCpAvatarFrame(
            imageUrl: profileImage,
            size: avatarSize,
            frameUrl: frameUrl,
            showFrame: frameUrl.isNotEmpty,
            isPartner: false,
          ),
        ),
        Positioned(
          left: avatarSize * 1.47,
          top: 0,
          child: _visitorCpAvatarFrame(
            imageUrl: partnerImage,
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
        if (partnerName.isNotEmpty)
          Positioned(
            left: kWeight*0.5,
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

Widget _visitorSingleAvatar({
  required String imageUrl,
  required String frameUrl,
  required bool showFrame,
}) {
  return _visitorCpAvatarFrame(
    imageUrl: imageUrl,
    size: kHeight * 0.145,
    frameUrl: frameUrl,
    showFrame: showFrame,
    isPartner: false,
  );
}

Widget _visitorCpAvatarFrame({
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
            child: _visitorNetworkCircleImage(
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

Widget _visitorCpCenterBadge({required double size}) {
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

Widget _visitorNetworkCircleImage({
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
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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

Widget _visitorPremiumCpCardSection({
  required Map<String, dynamic> user,
  required Map<String, dynamic> cpData,
}) {
  if (!_visitorHasActiveCp(cpData)) return const SizedBox.shrink();

  final Map<String, dynamic> partner = _visitorCpPartner(user: user, cpData: cpData);
  final String partnerName = _visitorSafeText(partner['name']);
  final String partnerImage = _visitorFullUrl(
    partner['profile_image_url'] ?? partner['profile_image'],
  );

  if (partnerName.isEmpty || partnerImage.isEmpty) {
    return const SizedBox.shrink();
  }

  final String myName = _visitorSafeText(user['name'], fallback: ('User').appTr);
  final String myImage = _visitorFullUrl(
    user['profile_image_url'] ?? user['profile_image'],
  );

  final Map<String, dynamic> cpLevel = _visitorSafeMap(cpData['cp_level']);
  final String levelNo = _visitorSafeText(cpLevel['level_no'], fallback: '1');
  final String days = _visitorSafeText(cpData['cp_days'], fallback: '0');

  return Padding(
    padding: EdgeInsets.fromLTRB(
      kHeight * 0.012,
      kHeight * 0.010,
      kHeight * 0.012,
      kHeight * 0.010,
    ),
    child: PremiumCpCard(
      myName: myName,
      partnerName: partnerName,
      myImage: myImage,
      partnerImage: partnerImage,
      levelText: 'Lv.$levelNo',
      totalDays: '${days}Days',
    ),
  );
}


Widget _buildBottomBar(Map<String, dynamic> data) {
  final userData = data['User Data'];

  final visitorId = userData?['id']?.toString();
  final myId = authController.userProfile.value.user?.id?.toString();

  /// নিজের profile হলে bottom button দেখাবে না
  if (visitorId == null || myId == null || visitorId == myId) {
    return const SizedBox.shrink();
  }

  return SafeArea(
    child: Container(
      height: kHeight * 0.055,
      margin: EdgeInsets.symmetric(
        vertical: kHeight * 0.01,
        horizontal: kWeight * 0.02,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                Get.to(
                      () => ChatPage(
                    receiverId: '${userData['id']}',
                    receiverName: '${userData['name'] ?? ''}',
                    receiverImage: _visitorFullUrl(
                      userData['profile_image_url'] ?? userData['profile_image'],
                      fallback: _visitorFullUrl(authController.userProfile.value.user?.profileImage),
                    ),
                  ),
                  transition: Transition.rightToLeft,
                );
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF4B6E),
                      Color(0xFFFF6B8A),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4B6E).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ("Hi").appTr,
                        style: TextStyle(
                          fontFamily: "Roboto",
                          fontSize: kHeight * 0.01,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF4B6E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ("Say hello").appTr,
                      style: TextStyle(
                        fontFamily: "Roboto",
                        fontSize: kHeight * 0.014,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: InkWell(
              onTap: () {
                Get.bottomSheet(
                  _buildCallingBottomSheet(data),
                  isScrollControlled: true,
                );
              },
              borderRadius: BorderRadius.circular(50),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF5B6EF5),
                      Color(0xFF7B8FFF),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B6EF5).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ("Calling").appTr,
                      style: TextStyle(
                        fontFamily: "Roboto",
                        fontSize: kHeight * 0.015,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCallingBottomSheet(Map<String, dynamic> data) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: HeaderPainter(),
          child: Container(
            height: kHeight * 0.12,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ("Guest Living").appTr,
                  style: TextStyle(
                    fontFamily: "Roboto",
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child:  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        ("0 Members").appTr,
                        style: TextStyle(
                          fontFamily: "Roboto",
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: kHeight * 0.04),

        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.2),
                    Colors.orange.withOpacity(0.2),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Colors.redAccent,
                      Colors.orange,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic,
                  size: kHeight * 0.03,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: kHeight * 0.015),
            Text(
              ("Start Living with Host").appTr,
              style: TextStyle(
                fontFamily: "Roboto",
                fontSize: kHeight * 0.015,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ("Choose your preferred mode").appTr,
              style: TextStyle(
                fontFamily: "Roboto",
                fontSize: kHeight * 0.013,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),

        SizedBox(height: kHeight * 0.03),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    print(
                        'userId ${authController.userProfile.value.user!.id!.toInt()}');
                    livestreamController.tryToMakeCall(
                      streamType: 'video',
                      userId: authController
                          .userProfile.value.user!.id!
                          .toInt(),
                      receiverData: data,
                    );
                    Get.back();
                  },
                  child: Container(
                    height: 54,
                    margin:
                    const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(27),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF5F6D),
                          Color(0xFFFFC371)
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF5F6D)
                              .withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          ("Video").appTr,
                          style: TextStyle(
                            fontFamily: "Roboto",
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Voice Living Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Get.back();

                    livestreamController.tryToMakeCall(
                      streamType: 'audio',
                      userId: authController
                          .userProfile.value.user!.id!
                          .toInt(),
                      receiverData: data,
                    );
                    Get.back();
                  },
                  child: Container(
                    height: 54,
                    margin:
                    const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(27),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF667EEA),
                          Color(0xFF764BA2)
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF667EEA)
                              .withOpacity(0.4),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          ("Voice").appTr,
                          style: TextStyle(
                            fontFamily: "Roboto",
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: kHeight * 0.04),
      ],
    ),
  );
}
