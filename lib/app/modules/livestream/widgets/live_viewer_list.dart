import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/live_viewers_list.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveViewerList extends StatelessWidget {
  const LiveViewerList({
    super.key,
    required this.filteredList,
    this.isFromPk = false, // ✅ default value false
  });

  final bool isFromPk; // ✅ final রাখা ঠিক আছে
  final List filteredList;


  int _viewerUserId(dynamic viewer) {
    if (viewer is! Map) return 0;
    final user = viewer['user'] is Map ? Map<String, dynamic>.from(viewer['user']) : <String, dynamic>{};
    return int.tryParse((viewer['viewer_id'] ?? viewer['user_id'] ?? viewer['caller_id'] ?? user['id'] ?? user['user_id']).toString()) ?? 0;
  }

  bool _viewerActive(dynamic viewer) {
    if (viewer is! Map) return false;
    final activeRaw = viewer['is_active'];
    final active = activeRaw == null || activeRaw == true || activeRaw == 1 || activeRaw.toString() == '1' || activeRaw.toString().toLowerCase() == 'true';
    return active && _viewerUserId(viewer) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final safeFilteredList = filteredList.where(_viewerActive).toList();

    return Container(
      height: kHeight * 0.6,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          SizedBox(height: kHeight * 0.01),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kWeight * 0.02),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Center(
                  child: Castontext(
                    fontSize: kHeight * 0.023,
                    fontWeight: FontWeight.w600,
                    textColor: Colors.black.withOpacity(.7),
                    text: ('All Viewer List').appTr,
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close, color: kAppColor, size: 18),
                ),
              ],
            ),
          ),
          SizedBox(height: kHeight * 0.004),

          /// 🔹 যদি Viewer না থাকে, তাহলে Center করে Empty Message দেখাও
          Expanded(
            child: safeFilteredList.isEmpty
                ? Center(
              child: Text(
                ('No viewers yet 👀').appTr,
                style: GoogleFonts.roboto(
                  fontSize: kHeight * 0.016,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                ),
              ),
            )
                : LiveViewersList(

              viewerList: safeFilteredList,
              isBroadcaster: livestreamController.isBroadcaster.value,
              isFromPk: isFromPk,
              onKickUser: (userId) {
                livestreamController.kickOutUser(userId);
              },
            ),
          ),
        ],
      ),
    );
  }
}
