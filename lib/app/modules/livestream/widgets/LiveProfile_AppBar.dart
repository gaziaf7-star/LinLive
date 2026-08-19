import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';

class LiveProfile extends StatelessWidget {
  final dynamic data;

  const LiveProfile({
    super.key,
    required this.data,
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

  Map<String, dynamic> _getUserMap(dynamic rawData) {
    final item = _asMap(rawData);

    if (item['user'] is Map) return _asMap(item['user']);
    if (item['User'] is Map) return _asMap(item['User']);
    if (item['viewer'] is Map) return _asMap(item['viewer']);
    if (item['caller'] is Map) return _asMap(item['caller']);
    if (item['profile'] is Map) return _asMap(item['profile']);

    return item;
  }

  dynamic _getUserId(Map<String, dynamic> item, Map<String, dynamic> user) {
    return user['id'] ??
        user['user_id'] ??
        item['viewer_id'] ??
        item['user_id'] ??
        item['caller_id'] ??
        item['id'];
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

  dynamic _firstProfileFrameHistory(Map<String, dynamic> user, Map<String, dynamic> item) {
    // ✅ FIX (top viewer-strip frame/profile sometimes missing): the backend
    // is inconsistent about this field's name — some endpoints/responses
    // (e.g. /livestream/{id}/viewers) return the SINGULAR
    // `asset_purchase_history`, others return the PLURAL
    // `asset_purchase_histories`. Every other profile-frame widget in this
    // app (LiveView_Circle_Container, live_viewers_list, seat_event_handler,
    // etc.) already checks both forms — this widget only checked the plural
    // one, so whenever a viewer's data came from an endpoint using the
    // singular key, their VIP frame/decoration silently failed to render
    // here even though it rendered correctly elsewhere in the same room.
    final candidates = <dynamic>[
      user['frame_purchase_history'],
      user['frame_purchase_histories'],
      user['asset_purchase_history'],
      user['asset_purchase_histories'],
      user['asset_purchase_history2'],
      item['frame_purchase_history'],
      item['frame_purchase_histories'],
      item['asset_purchase_history'],
      item['asset_purchase_histories'],
      item['asset_purchase_history2'],
    ];

    for (final candidate in candidates) {
      final map = _asMap(candidate);
      if (map.isEmpty) continue;
      if (_isEntryCareHistory(map)) continue;

      final path = _frameAssetPath(map);
      if (path.isNotEmpty) return map;
    }

    return null;
  }

  String _frameAssetPath(dynamic history) {
    final frameData = _asMap(history);
    if (frameData.isEmpty) return '';

    final asset = _asMap(frameData['asset']);
    final path = _safeText(
      asset['asset'] ??
          asset['image'] ??
          frameData['asset_path'] ??
          frameData['asset'] ??
          frameData['image'] ??
          frameData['file'] ??
          frameData['url'],
    );

    return path;
  }

  Widget _defaultAvatar() {
    return Image.asset(
      'assets/flaticons/boy.png',
      height: kHeight * 0.04,
      width: kHeight * 0.04,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _asMap(data);
    final user = _getUserMap(data);

    final userId = _getUserId(item, user);
    final profileImage = _safeText(user['profile_image'] ?? user['image'] ?? user['avatar']);

    final frameHistory = _firstProfileFrameHistory(user, item);
    final assetPath = _frameAssetPath(frameHistory);

    return InkWell(
      onTap: () {
        final idText = _safeText(userId);
        if (idText.isNotEmpty) {
          homeController.liveVisitProfile(
            userId: idText,
            seatData: item,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: SizedBox(
            height: kHeight * 0.08,
            width: kHeight * 0.052,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: Get.height * 0.034,
                  width: Get.height * 0.034,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: profileImage.isEmpty
                        ? _defaultAvatar()
                        : CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: ImageHelper.getImageUrl(profileImage),
                      placeholder: (context, url) => _defaultAvatar(),
                      errorWidget: (context, url, error) => _defaultAvatar(),
                    ),
                  ),
                ),

                if (assetPath.isNotEmpty)
                  assetPath.toLowerCase().endsWith('.svga')
                      ? SizedBox(
                    height: kHeight * 0.080,
                    width: kHeight * 0.080,
                    child: SVGAEasyPlayer(
                      resUrl: ImageHelper.getImageUrl(assetPath),
                      fit: BoxFit.contain,
                      loops: null,
                      useCache: true,
                    ),
                  )
                      : CachedNetworkImage(
                    imageUrl: ImageHelper.getImageUrl(assetPath),
                    height: kHeight * 0.080,
                    width: kHeight * 0.080,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox.shrink(),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}