import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

import '../app/modules/appmenu/views/widgets/game_test.dart';
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
    final candidates = <dynamic>[

      user['asset_purchase_histories'],
      item['profile_frame_history'],
      item['active_frame'],
      item['asset_purchase_history'],
    ];

    for (final candidate in candidates) {
      final map = _asMap(candidate);
      if (map.isEmpty) continue;
      if (_isEntryCareHistory(map)) continue;
      if (_frameAssetPath(map).isNotEmpty) return map;
    }
    return null;
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
    return Container(
      child: viewerList.isEmpty
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
        itemCount: viewerList.length,
        itemBuilder: (BuildContext context, int viewerIndex) {
          final item = _asMap(viewerList[viewerIndex]);
          final user = _userMap(viewerList[viewerIndex]);
          final id = _userId(item, user);
          final idInt = int.tryParse(id?.toString() ?? '0') ?? 0;
          final name = _safeText(user['name']).isEmpty ? 'User': _safeText(user['name']);
          final level = _safeText(user['level']).isEmpty ? '0' : _safeText(user['level']);
          final frameHistory = _firstProfileFrameHistory(user, item);
          final assetPath = _frameAssetPath(frameHistory);

          return Container(
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
                              SizedBox(height: kHeight * 0.007),
                              Padding(

                                padding: EdgeInsets.only(left: kWeight * 0.047),
                                child: LevelFrame(
                                    level: level),
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
                        text: isFromPk ? ('PK Request').appTr: ('Kick').appTr,
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
