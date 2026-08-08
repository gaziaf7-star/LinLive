import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_overlay/loading_overlay.dart';


import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../appmenu/views/widgets/game_test.dart';
import '../controllers/record_controller.dart';
import 'calander.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RecordView extends GetView<RecordController> {
  const RecordView({super.key});

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '00:00:00';

    int totalSeconds = int.tryParse(seconds.toString()) ?? 0;
    Duration duration = Duration(seconds: totalSeconds);

    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int secs = duration.inSeconds.remainder(60);

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
  }

  @override
  Widget build(BuildContext context) {
    final recordController = Get.put(RecordController());
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: ('Live Record').appTr,
      ),
      body: Obx(() {
        return LoadingOverlay(
          progressIndicator: SpinKitChasingDots(
            size: 30,
            color: kPrimaryColor,
          ),
          isLoading: recordController.isLoading.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                //-------fast Container --------------
                Column(
                  children: [
                    SizedBox(height: 20,),
                    //------button----------
                    // Align(
                    //   alignment: Alignment.topRight,
                    //   child: Container(
                    //     margin: EdgeInsets.symmetric(
                    //         vertical: kHeight * 0.01,
                    //         horizontal: kWeight * 0.02),
                    //     child: ElevatedButton(
                    //       style: ElevatedButton.styleFrom(
                    //           backgroundColor: Color(0xff8A4CF7),
                    //           shape: RoundedRectangleBorder(
                    //               borderRadius: BorderRadius.circular(5))),
                    //       onPressed: () {},
                    //       child: Text(
                    //         ('Export').appTr,
                    //         style: GoogleFonts.lato(
                    //             color: Colors.white,
                    //             fontWeight: FontWeight.w500,
                    //             fontSize: kHeight * 0.015),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    //---profile--------
                    Obx(() {
                      final userProfile = authController.userProfile.value;
                      final user = userProfile.user;

                      final profileImage = user?.profileImage ?? '';

                      // Only asset_histories frame, entry_histories never use here
                      final framePath =
                          userProfile.assetHistories?.asset?.asset?.toString() ?? '';

                      final agencyId =
                          int.tryParse(user?.agencyId?.toString() ?? '0') ?? 0;

                      final bool hasUserFrame =
                          userProfile.assetHistories != null &&
                              framePath.isNotEmpty &&
                              userProfile.assetHistories?.asset?.type == 'Frame';

                      final bool hasAgencyFrame = !hasUserFrame && agencyId > 0;

                      final baseUrl = kDomainUrl.replaceAll(RegExp(r'/+$'), '');
                      final frameUrl = '$baseUrl/$framePath';

                      print('Asset Histories => ${userProfile.assetHistories}');
                      print('Entry Histories => ${userProfile.entryHistories}');
                      print('Frame Path => $framePath');
                      print('Frame Url => $frameUrl');
                      print('Has User Frame => $hasUserFrame');

                      return Container(
                        height: kHeight * 0.1,
                        width: kHeight * 0.11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: CachedNetworkImage(
                                  imageUrl: ImageHelper.getImageUrl(profileImage),
                                  fit: BoxFit.cover,
                                  height: 80,
                                  width: 80,
                                  placeholder: (c, u) =>
                                  const CircularProgressIndicator(strokeWidth: 2),
                                  errorWidget: (c, u, e) =>
                                  const Icon(Icons.person, size: 50),
                                ),
                              ),
                            ),

                            if (hasUserFrame)
                              SizedBox(
                                height: kHeight * 0.1,
                                width: kHeight * 0.11,
                                child: framePath.toLowerCase().endsWith('.svga')
                                    ? SVGAEasyPlayer(
                                  resUrl: frameUrl,
                                  fit: BoxFit.cover,
                                )
                                    : CachedNetworkImage(
                                  imageUrl: frameUrl,
                                  fit: BoxFit.cover,
                                ),
                              )

                          ],
                        ),
                      );
                    }),
                    SizedBox(
                      height: 15,
                    ),
                    Text(
                      '${authController.userProfile.value.user!.name}',
                      style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: kHeight * 0.018),
                    ),
                    SizedBox(
                      height: 2,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LevelFrame(
                          level: '${authController.userProfile.value.user?.level ?? 0}',
                        ),
                        SizedBox(width: 10,),
                        Text(
                          ('Uid : ${authController.userProfile.value.user?.userId}').appTr,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          constraints: BoxConstraints(),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: authController.userProfile.value.user!.id.toString()));
                            Fluttertoast.showToast(msg: ("User ID copied").appTr);
                          },
                          icon: Icon(Icons.copy, size: 16, color: Colors.black45),
                        ),
                      ],
                    ),

                    //----------fast card ---------------
                    Container(
                      padding: EdgeInsets.symmetric(
                          vertical: kHeight * 0.03,
                          horizontal: kWeight * 0.03),
                      margin: EdgeInsets.symmetric(
                          vertical: kHeight * 0.02,
                          horizontal: kWeight * 0.02),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              kAppColor1.withOpacity(0.4),
                              kAppColor2.withOpacity(0.4),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CastomRecordCard(
                                image:
                                    'assets/icons/download-removebg-preview.png',
                                text: ('Monthly Diamonds').appTr,
                                valueText: recordController
                                    .currentMonthLiveRecord[
                                        'totalMontlyDiamonds']
                                    .toString(),
                              ),

                              CastomRecordCard(
                                image:
                                    'assets/icons/day-removebg-preview.png',
                                text: ('Video Valid Days').appTr,
                                valueText: recordController
                                    .currentMonthLiveRecord[
                                        'totalVideoValidDay']
                                    .toString(),
                              ),
                              CastomRecordCard(
                                image:
                                    'assets/icons/day-removebg-preview.png',
                                text: ('Audio Valid Days').appTr,
                                valueText: recordController
                                    .currentMonthLiveRecord[
                                        'totalAudioValidDay']
                                    .toString(),
                              ),
                              // spacing between items
                            ],
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Divider(
                            color: Color(0xff320dc6).withOpacity(.3),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CastomRecordCard(
                                image:
                                    'assets/icons/time-removebg-preview.png',
                                text: ('Video Valid Time').appTr,
                                valueText: _formatDuration(
                                  recordController.currentMonthLiveRecord[
                                      'totalValidVideoTime'],
                                ),
                              ),
                              CastomRecordCard(
                                image:
                                    'assets/frame/rank-removebg-preview.png',
                                text: ('Audio Valid Time').appTr,
                                valueText: _formatDuration(
                                  recordController.currentMonthLiveRecord[
                                      'totalValidAudioTime'],
                                ),
                              ),
                              CastomRecordCard(
                                image:
                                    'assets/frame/rank-removebg-preview.png',
                                text: ('Host ranks').appTr,
                                valueText: recordController
                                    .currentMonthLiveRecord['hostRank']
                                    .toString(),
                              ),
                              // spacing between items
                            ],
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Divider(
                            color: Color(0xff320dc6).withOpacity(.3),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CastomRecordCard(
                                image:
                                    'assets/icons/commission-removebg-preview.png',
                                text: ('Room Commission').appTr,
                                valueText: ('Your Commission').appTr,
                              ),
                              CastomRecordCard(
                                image:
                                    'assets/icons/commission-removebg-preview.png',
                                text: ('Reword').appTr,
                                valueText:
                                    '${recordController.rewordData['reword_coin']}',
                              ),
                              CastomRecordCard(
                                image:
                                    'assets/icons/commission-removebg-preview.png',
                                text: ('Reword count').appTr,
                                valueText:
                                    '${recordController.rewordData['reword_count']}',
                              ),

                              // spacing between items
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                //------- second Container -------------
                SizedBox(height: kHeight * 0.5, child: DiamondLogPage()),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class CastomRecordCard extends StatelessWidget {
  final String image;
  final String text;
  final String valueText;

  const CastomRecordCard({
    super.key,
    required this.image,
    required this.text,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: kWeight * 0.03,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: GoogleFonts.lato(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: kHeight * 0.014),
            ),
            Text(
              valueText,
              style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: kHeight * 0.016),
            ),
          ],
        ), // Optional text
      ],
    );
  }
}
