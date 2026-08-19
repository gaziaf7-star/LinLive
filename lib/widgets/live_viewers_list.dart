import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

import '../app/modules/appmenu/views/widgets/game_test.dart';
import '../app/modules/livestream/utils/vip_privileges.dart';
import '../constants/color_constants.dart';
import '../constants/constants.dart';
import '../constants/image_helper.dart';
import '../constants/layout_constant.dart';
import 'after/CastomText.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveViewersList extends StatelessWidget {
  final List<dynamic> viewerList;
  final bool isBroadcaster;
  final bool isFromPk;
  final Function(int)? onKickUser;

  const LiveViewersList({
    super.key,
    required this.viewerList,
    required this.isBroadcaster,
    this.onKickUser,
    required this.isFromPk,
  });

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  String _safeLower(dynamic value) => _safeText(value).toLowerCase();

  Map<String, dynamic> _userMap(dynamic viewer) {
    final item = _asMap(viewer);
    if (item['user'] is Map) return _asMap(item['user']);
    if (item['viewer'] is Map) return _asMap(item['viewer']);
    if (item['caller'] is Map) return _asMap(item['caller']);
    return item;
  }

  dynamic _userId(Map<String, dynamic> item, Map<String, dynamic> user) {
    return user['id'] ?? user['user_id'] ?? item['viewer_id'] ?? item['user_id'] ?? item['caller_id'] ?? item['id'];
  }

  bool _isEntryCareHistory(dynamic history) {
    final frameData = _asMap(history);
    if (frameData.isEmpty) return false;

    final asset = _asMap(frameData['asset']);
    final assetType = _safeLower(asset['type'] ?? frameData['asset_type']);
    final historyType = _safeLower(frameData['type'] ?? frameData['history_type']);
    final assetName = _safeLower(asset['name'] ?? frameData['name']);

    return assetType == 'entry care' ||
        historyType == 'entry care' ||
        assetType.contains('entry') ||
        historyType.contains('entry') ||
        assetName.contains('entry');
  }

  String _frameAssetPath(dynamic history) {
    final frameData = _asMap(history);
    if (frameData.isEmpty) return '';

    final asset = _asMap(frameData['asset']);
    return _safeText(asset['asset'] ?? asset['image'] ?? frameData['asset_path'] ?? frameData['image'] ?? frameData['file'] ?? frameData['url']);
  }

  dynamic _firstProfileFrameHistory(Map<String, dynamic> user, Map<String, dynamic> item) {
    // ✅ FIX (bottom-sheet "All Viewer List" frame not showing): the backend
    // sends this field as singular `asset_purchase_history` nested inside
    // `user` (see /viewerlist/{id}). This was only checking the PLURAL form
    // on `user`, and the singular form on the wrong object (`item`, the raw
    // viewer row, not `user`) — so it could never find the frame for the
    // shape this API actually returns. Checking both forms on `user` (and
    // `item` as a fallback for other endpoints) matches every other
    // frame-lookup in the app.
    final candidates = <dynamic>[
      user['asset_purchase_history'],
      user['asset_purchase_histories'],
      user['frame_purchase_history'],
      user['frame_purchase_histories'],
      item['profile_frame_history'],
      item['active_frame'],
      item['asset_purchase_history'],
      item['asset_purchase_histories'],
    ];

    for (final candidate in candidates) {
      final map = _asMap(candidate);
      if (map.isEmpty) continue;
      if (_isEntryCareHistory(map)) continue;
      if (_frameAssetPath(map).isNotEmpty) return map;
    }
    return null;
  }

  // ✅ NEW: same level_image fallback-key pattern used elsewhere in the app
  // (live_comments.dart, LiveProfile_AppBar.dart) so the level badge below
  // shows each viewer's OWN level image instead of always falling back to
  // the logged-in user's.
  String _levelImagePath(Map<String, dynamic> user, Map<String, dynamic> item) {
    return _safeText(
      user['level_image'] ??
          user['levelImage'] ??
          user['level_image_url'] ??
          user['levelImageUrl'] ??
          item['level_image'] ??
          item['levelImage'],
    );
  }

  Widget _avatar(Map<String, dynamic> user) {
    final profileImage = _safeText(user['profile_image'] ?? user['image'] ?? user['avatar']);
    final String normalizedUrl =
    profileImage.isEmpty ? '' : ImageHelper.getImageUrl(profileImage);
    final int decodeSize = (kHeight * 0.11).round().clamp(96, 240);
    final String stableUserId = _safeText(user['id'] ?? user['user_id']);

    Widget fallback() => Image.asset(
      'assets/audio_live/linemptyimage.PNG',
      key: ValueKey<String>('viewer-placeholder-$stableUserId'),
      height: kHeight * 0.055,
      width: kHeight * 0.055,
      fit: BoxFit.cover,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: normalizedUrl.isEmpty
          ? fallback()
          : CachedNetworkImage(
        key: ValueKey<String>(
          'viewer-profile-$stableUserId-$normalizedUrl',
        ),
        fit: BoxFit.cover,
        imageUrl: normalizedUrl,
        cacheKey: normalizedUrl,
        memCacheWidth: decodeSize,
        memCacheHeight: decodeSize,
        maxWidthDiskCache: 320,
        maxHeightDiskCache: 320,
        placeholder: (_, __) => fallback(),
        errorWidget: (_, __, ___) => fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleViewerList = viewerList.where((viewer) {
      final vip = VipPrivileges.from(viewer);
      return !vip.invisible || isBroadcaster;
    }).toList(growable: false);
    return Container(
      child: visibleViewerList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: kHeight * 0.08,
              color: Colors.grey.withOpacity(0.6),
            ),
            SizedBox(height: kHeight * 0.02),
            Text(
              ('No viewers yet').appTr,
              style: TextStyle(
                fontSize: kHeight * 0.018,
                color: Colors.grey.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: visibleViewerList.length,
        itemBuilder: (BuildContext context, int viewerIndex) {
          final item = _asMap(visibleViewerList[viewerIndex]);
          final user = _userMap(visibleViewerList[viewerIndex]);
          final vip = VipPrivileges.from(item);
          final id = _userId(item, user);
          final idInt = int.tryParse(id?.toString() ?? '0') ?? 0;
          final name = _safeText(user['name']).isEmpty ? 'User': _safeText(user['name']);
          final level = _safeText(user['level']).isEmpty ? '0' : _safeText(user['level']);
          final frameHistory = _firstProfileFrameHistory(user, item);
          final assetPath = _frameAssetPath(frameHistory);
          final levelImagePath = _levelImagePath(user, item);

          return Container(
            key: ValueKey<String>('viewer_row_${idInt}_$viewerIndex'),
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: kWeight * 0.015),
            padding: EdgeInsets.symmetric(vertical: 5, horizontal: kWeight * 0.02),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (idInt > 0) {
                        homeController.liveVisitProfile(
                          userId: '$idInt',
                          seatData: item,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          height: kHeight * 0.065,
                          width: kHeight * 0.065,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: Get.height * 0.055,
                                width: Get.height * 0.055,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: _avatar(user),
                              ),
                              if (assetPath.isNotEmpty)
                                assetPath.toLowerCase().endsWith('.svga')
                                    ? SizedBox(
                                  height: kHeight * 0.085,
                                  width: kHeight * 0.085,
                                  child: SVGAEasyPlayer(
                                    resUrl: ImageHelper.getImageUrl(assetPath),
                                    fit: BoxFit.cover,
                                    loops: null,
                                    useCache: true,
                                  ),
                                )
                                    : CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(assetPath),
                                  height: kHeight * 0.085,
                                  width: kHeight * 0.085,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const SizedBox.shrink(),
                                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: kWeight * 0.023),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Castontext(
                                fontWeight: FontWeight.w600,
                                fontSize: kHeight * 0.02,
                                textColor: Colors.black.withOpacity(.7),
                                text: name,
                              ),
                              if (vip.vipBadge)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD76A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    vip.vipType.isEmpty
                                        ? 'VIP'
                                        : vip.vipType.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF3A245C),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              SizedBox(height: kHeight * 0.007),
                              Padding(

                                padding: EdgeInsets.only(left: kWeight * 0.047),
                                child: LevelFrame(
                                    key: ValueKey<String>(
                                      'level_frame_${idInt}_$levelImagePath',
                                    ),
                                    level: level,
                                    // ✅ FIX: was omitted, so LevelFrame's
                                    // own default silently fell back to the
                                    // *logged-in* user's level image for
                                    // every row here instead of each
                                    // viewer's own.
                                    levelImage: levelImagePath,
                                    // ✅ FIX (root cause of "everyone shows
                                    // the same image"): this list shows
                                    // OTHER users. Without this flag,
                                    // LevelFrame fell back to the CURRENTLY
                                    // LOGGED-IN user's own level image for
                                    // every row that had no level_image of
                                    // its own (i.e. most rows) — so every
                                    // such row showed the viewer's own
                                    // badge instead of the neutral default.
                                    useCurrentUserFallback: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isBroadcaster && onKickUser != null && idInt > 0)
                  GestureDetector(
                    onTap: () {
                      if (!isFromPk && vip.antiKickBan) {
                        Fluttertoast.showToast(
                          msg: ('Protected by VIP privilege').appTr,
                        );
                        return;
                      }
                      if (isFromPk) {
                        livestreamController.tryToCallLivestream(
                          streamId: livestreamController.streamId.value,
                          callerId: idInt,
                          callType: 'pk',
                        );
                      } else {
                        onKickUser!(idInt);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: kHeight * 0.007, horizontal: kWeight * 0.05),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [kAppColor.withOpacity(.7), kAppColor],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                      ),
                      child: Castontext(
                        fontWeight: FontWeight.w500,
                        fontSize: kHeight * 0.016,
                        textColor: Colors.white.withOpacity(.8),
                        text: isFromPk
                            ? ('PK Request').appTr
                            : vip.antiKickBan
                            ? ('Protected').appTr
                            : ('Kick').appTr,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}