import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/layout_constant.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class UserManagePopup extends StatelessWidget {
  final String userId;
  final String userName;
  final String userAvatar;
  final VoidCallback? onSendGifts;
  final VoidCallback? onViewProfile;
  final VoidCallback? onLeaveMic;
  final VoidCallback? onMuteMic;
  final VoidCallback? onKickOut;
  final VoidCallback? onSetAdministrator;
  final VoidCallback? onAddToRoomBlacklist;
  final VoidCallback? onAddToPersonalBlacklist;

  const UserManagePopup({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.onSendGifts,
    this.onViewProfile,
    this.onLeaveMic,
    this.onMuteMic,
    this.onKickOut,
    this.onSetAdministrator,
    this.onAddToRoomBlacklist,
    this.onAddToPersonalBlacklist,
  }) : super(key: key);

  /// 🔹 Call this method to show bottom sheet
  static void show(BuildContext context, UserManagePopup popup) {
    Get.bottomSheet(
      popup,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kHeight * 0.6, // <-- half of screen height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        height: kHeight * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min, // <-- changed from min to max
          children: [
            // Optional: Add a small top drag indicator
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Options in scrollable area
            Column(
              children: [
                _buildOption(
                  icon: Icons.card_giftcard,
                  title: ('Send gifts').appTr,
                  onTap: onSendGifts,
                ),
                _buildOption(
                  icon: Icons.person,
                  title: ('View profile').appTr,
                  onTap: onViewProfile,
                ),
                _buildOption(
                  icon: Icons.mic_off,
                  title: ('Leave the mic').appTr,
                  onTap: onLeaveMic,
                ),
                _buildOption(
                  icon: Icons.volume_off,
                  title: ('Mute Mic').appTr,
                  onTap: onMuteMic,
                ),
                _buildOption(
                  icon: Icons.exit_to_app,
                  title: ('Kick out the room').appTr,
                  onTap: onKickOut,
                ),
                _buildOption(
                  icon: Icons.admin_panel_settings,
                  title: ('Set administrator').appTr,
                  onTap: onSetAdministrator,
                ),
                _buildOption(
                  icon: Icons.block,
                  title: ('Add to the room blacklist').appTr,
                  onTap: onAddToRoomBlacklist,
                ),
                _buildOption(
                  icon: Icons.person_remove,
                  title: ('Add to personal blacklist').appTr,
                  onTap: onAddToPersonalBlacklist,
                ),
              ],
            ),

            // Cancel Button
            Container(
              width: kWeight * 0.8,
              margin: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAppColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: kAppColor),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  ('Cancel').appTr,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Option Tile Builder
  Widget _buildOption({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap ?? () => Get.back(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: 15, vertical: kHeight * 0.015),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3), // Border color
                width: .5, // Border width
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: kHeight * 0.018,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
