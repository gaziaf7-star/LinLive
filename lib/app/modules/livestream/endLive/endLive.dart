import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/after/castomLiveend.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import '../../bottomnav/views/bottomnav_view.dart'
    hide kAppColor1, kAppColor2;

class Endlive extends StatelessWidget {
  const Endlive({super.key});

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final String result = value?.toString().trim() ?? '';
    if (result.isEmpty || result.toLowerCase() == 'null') {
      return fallback;
    }
    return result;
  }

  String formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final duration = Duration(seconds: safeSeconds);

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return '${twoDigits(duration.inHours)}:'
        '${twoDigits(duration.inMinutes.remainder(60))}:'
        '${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = _asMap(Get.arguments);

    final Map<String, dynamic> livestreamData = _asMap(
      data['livestream_data'] ??
          data['livestream'] ??
          data['data'],
    );

    final Map<String, dynamic> endLiveData = _asMap(
      data['end_live_data'] ??
          data['end_data'],
    );

    final Map<String, dynamic> user = _asMap(
      livestreamData['user'] ??
          livestreamData['User'] ??
          data['user'],
    );

    final Map<String, dynamic> purchaseHistory = _asMap(
      user['asset_purchase_history'],
    );
    final Map<String, dynamic> frameAsset = _asMap(
      purchaseHistory['asset'],
    );

    final String hostName = _text(
      user['name'] ??
          livestreamData['host_name'] ??
          data['host_name'],
      fallback: ('Host').appTr,
    );

    final String profileImage = _text(
      user['profile_image'] ??
          user['avatar'] ??
          livestreamData['profile_image'],
    );

    final String framePath = _text(
      frameAsset['asset'] ??
          frameAsset['image'] ??
          frameAsset['file'],
    );

    final int giftAmount = _toInt(
      endLiveData['gift_amount'] ??
          data['gift_amount'] ??
          livestreamData['gifts_coins'] ??
          livestreamData['total_gift_coins'],
    );

    final int newFollowers = _toInt(
      data['new_followers'] ??
          endLiveData['new_followers'],
    );

    final int liveDurationSeconds = _toInt(
      livestreamData['live_duration_seconds'] ??
          endLiveData['live_duration_seconds'] ??
          data['live_duration_seconds'],
    );

    final int audienceCount = _toInt(
      endLiveData['audience'] ??
          endLiveData['viewer_count'] ??
          data['audience'] ??
          data['viewer_count'],
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kAppColor1, kAppColor2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          ('End Live').appTr,
          style: GoogleFonts.lato(
            fontSize: kHeight * 0.022,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: kHeight * 0.03),
          child: Column(
            children: [
              SizedBox(height: kHeight * 0.055),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: kWeight * 0.9,
                      padding: EdgeInsets.symmetric(
                        vertical: kHeight * 0.05,
                      ),
                      margin: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: kWeight * 0.03,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kAppColor2, kAppColor1],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 50),
                          Castontext(
                            textColor: Colors.white,
                            text: hostName,
                            fontSize: 20,
                          ),
                          Castontext(
                            textColor: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            text: 'Live ended',
                          ),
                          SizedBox(height: kHeight * 0.03),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                            children: [
                              CastomLivecatagory(
                                text: 'Receive Coin',
                                text1: '$giftAmount',
                                image: 'assets/images/dollar.png',
                              ),
                              CastomLivecatagory(
                                text: 'New follower',
                                text1: '$newFollowers',
                                image: 'assets/flaticons/user.png',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -40,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: kHeight * 0.12,
                        width: kHeight * 0.12,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: CircleAvatar(
                                radius: kHeight * 0.035,
                                backgroundColor: Colors.white,
                                child: profileImage.isEmpty
                                    ? Icon(
                                  Icons.person,
                                  size: kHeight * 0.07,
                                )
                                    : CachedNetworkImage(
                                  imageUrl:
                                  ImageHelper.getImageUrl(
                                    profileImage,
                                  ),
                                  height: kHeight * 0.09,
                                  width: kHeight * 0.09,
                                  fit: BoxFit.cover,
                                  errorWidget:
                                      (context, url, error) =>
                                      Icon(
                                        Icons.person,
                                        size: kHeight * 0.07,
                                      ),
                                  placeholder: (context, url) =>
                                      SizedBox(
                                        height: kHeight * 0.09,
                                        width: kHeight * 0.09,
                                        child: const Center(
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            if (framePath.isNotEmpty)
                              framePath
                                  .toLowerCase()
                                  .endsWith('.svga')
                                  ? SizedBox(
                                height: kHeight * 0.12,
                                width: kHeight * 0.12,
                                child: SVGAEasyPlayer(
                                  resUrl:
                                  '$kDomainUrl/$framePath',
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : CachedNetworkImage(
                                imageUrl:
                                '$kDomainUrl/$framePath',
                                height: kHeight * 0.12,
                                width: kHeight * 0.12,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) =>
                                const SizedBox.shrink(),
                                errorWidget:
                                    (context, url, error) =>
                                const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: kHeight * 0.02,
                  horizontal: kWeight * 0.05,
                ),
                margin: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: kWeight * 0.05,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kAppColor2, kAppColor1],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Castontext(
                            text: 'Live Duration',
                            textColor:
                            Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: kHeight * 0.015,
                          ),
                          SizedBox(height: kHeight * 0.01),
                          Castontext(
                            text: formatDuration(
                              liveDurationSeconds,
                            ),
                            textColor: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: kHeight * 0.02,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: kHeight * 0.15,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                      margin: EdgeInsets.symmetric(
                        horizontal: kWeight * 0.04,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Castontext(
                            text: 'Audiences',
                            textColor:
                            Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: kHeight * 0.015,
                          ),
                          SizedBox(height: kHeight * 0.01),
                          Castontext(
                            text: '$audienceCount',
                            textColor: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: kHeight * 0.02,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: kHeight * 0.05),
              SizedBox(
                width: kWeight * 0.85,
                height: kHeight * 0.06,
                child: ElevatedButton(
                  onPressed: () {
                    Get.offAll(
                          () => BottomnavView(),
                      transition: Transition.rightToLeft,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kAppColor2, kAppColor1],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      child: Text(
                        ('Confirm').appTr,
                        style: GoogleFonts.lato(
                          color: Colors.white,
                          fontSize: kHeight * 0.017,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
