import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/livestream_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({super.key});

  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  final LivestreamController liveController = Get.find<LivestreamController>();

  static const Color _primary = Color(0xFFF80230);
  static const Color _primary2 = Color(0xFFFD375D);
  static const Color _appbar = Color(0xFFF43C5D);
  static const Color _text = Color(0xFF151923);
  static const Color _subText = Color(0xFF6B7280);
  static const Color _cardBorder = Color(0xFFEDEFF4);
  static const Color _softBg = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    liveController.syncRoomSafetyFromCurrentLiveData(source: 'room_settings_page_init');
  }

  double _sp(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390).clamp(.88, 1.15).toDouble();
    return value * scale;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String? confirmText,
    Color? confirmColor,
    IconData icon = Icons.info_outline_rounded,
  }) async {
    final String resolvedConfirmText =
        confirmText ?? 'Confirm'.appTr;

    final Color resolvedConfirmColor =
        confirmColor ?? _primary;

    final result = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: resolvedConfirmColor.withOpacity(.10),
                ),
                child: Icon(
                  icon,
                  color: resolvedConfirmColor,
                  size: 28,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _subText,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _text,
                        side: const BorderSide(color: _cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                      child: Text(
                        'Cancel'.appTr,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resolvedConfirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                      child: Text(
                        resolvedConfirmText,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    return result == true;
  }

  Future<String?> _showPasswordDialog() async {
    final controllers = List.generate(6, (_) => TextEditingController());
    final focusNodes = List.generate(6, (_) => FocusNode());

    final result = await Get.dialog<String>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [_primary, _primary2]),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(.28),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ('Set Room Password').appTr,
                    style: GoogleFonts.poppins(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ('Enter 6 digit password. Viewers must use this password to join your locked room.').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _subText,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 42,
                        height: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 3.5),
                        decoration: BoxDecoration(
                          color: _softBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: TextField(
                          controller: controllers[index],
                          focusNode: focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: GoogleFonts.poppins(
                            color: _text,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              focusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              focusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(result: null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _text,
                            side: const BorderSide(color: _cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(('Cancel').appTr, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final password = controllers.map((e) => e.text.trim()).join();
                            if (password.length != 6) {
                              HapticFeedback.lightImpact();
                              Fluttertoast.showToast(msg: ('Please enter 6 digit password').appTr);
                              return;
                            }
                            Get.back(result: password);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: Text(('Lock').appTr, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
      barrierDismissible: true,
    );

    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focusNodes) {
      f.dispose();
    }

    return result;
  }

  Future<void> _toggleRoomLock(bool current) async {
    if (liveController.roomSettingsLoading.value) return;

    if (current) {
      final ok = await _confirm(
        title: ('Unlock Room?').appTr,
        message: ('Users will be able to join this room without password.').appTr,
        confirmText: ('Unlock').appTr,
        confirmColor: Colors.green,
        icon: Icons.lock_open_rounded,
      );
      if (!ok) return;
      await liveController.setRoomPasswordLock(lock: false);
      return;
    }

    final password = await _showPasswordDialog();
    if (password == null || password.trim().isEmpty) return;
    await liveController.setRoomPasswordLock(lock: true, roomPassword: password.trim());
  }

  Future<void> _toggleChatLock(bool current) async {
    if (liveController.roomSettingsLoading.value) return;
    final next = !current;
    final ok = await _confirm(
      title: next ? ('Lock Chat?').appTr: ('Unlock Chat?').appTr,
      message: next
          ? 'Viewers and callers will not be able to send comments in this live room.'
          : 'Viewers and callers will be able to send comments again.',
      confirmText: next ? ('Lock').appTr: ('Unlock').appTr,
      confirmColor: next ? _primary : Colors.green,
      icon: next ? Icons.chat_bubble_rounded : Icons.mark_chat_read_rounded,
    );
    if (!ok) return;
    await liveController.setLiveCommentLock(next);
  }

  Future<void> _toggleHiddenRoom(bool current) async {
    if (liveController.roomSettingsLoading.value) return;
    final next = !current;
    final ok = await _confirm(
      title: next ? ('Hide Room?').appTr: ('Show Room?').appTr,
      message: next
          ? 'This room will be hidden from the live list.'
          : 'This room will show again in the live list.',
      confirmText: next ? ('Hide').appTr: ('Show').appTr,
      confirmColor: next ? _primary : Colors.green,
      icon: next ? Icons.visibility_off_rounded : Icons.visibility_rounded,
    );
    if (!ok) return;
    await liveController.setHiddenRoom(next);
  }

  Future<void> _toggleScreenRecord(bool current) async {
    if (liveController.roomSettingsLoading.value) return;
    final next = !current;
    final ok = await _confirm(
      title: next ? ('Block Screen Record?').appTr: ('Allow Screen Record?').appTr,
      message: next
          ? 'Users will not be able to record this room screen.'
          : 'Users will be able to record this room screen again.',
      confirmText: next ? ('Block').appTr: ('Allow').appTr,
      confirmColor: next ? _primary : Colors.green,
      icon: next ? Icons.fiber_manual_record_rounded : Icons.video_camera_back_rounded,
    );
    if (!ok) return;
    await liveController.setScreenRecordBlock(next);
  }

  Future<void> _toggleScreenshot(bool current) async {
    if (liveController.roomSettingsLoading.value) return;
    final next = !current;
    final ok = await _confirm(
      title: next ? ('Block Screenshot?').appTr: ('Allow Screenshot?').appTr,
      message: next
          ? 'Users will not be able to take screenshots in this room.'
          : 'Users will be able to take screenshots again.',
      confirmText: next ? ('Block').appTr: ('Allow').appTr,
      confirmColor: next ? _primary : Colors.green,
      icon: next ? Icons.screenshot_monitor_rounded : Icons.screenshot_rounded,
    );
    if (!ok) return;
    await liveController.setScreenshotBlock(next);
  }

  Future<void> _cleanChat() async {
    if (liveController.roomSettingsLoading.value) return;
    final ok = await _confirm(
      title: ('Clean Chat?').appTr,
      message: ('All current room comments will be removed for everyone.').appTr,
      confirmText: ('Clean').appTr,
      confirmColor: const Color(0xFFFF6B6B),
      icon: Icons.cleaning_services_rounded,
    );
    if (!ok) return;
    await liveController.cleanLiveComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primary2, _appbar],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      ('Room Settings').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: _sp(context, 18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Obx(() {
                    return AnimatedOpacity(
                      opacity: liveController.roomSettingsLoading.value ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const SizedBox(
                        height: 22,
                        width: 48,
                        child: Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          final loading = liveController.roomSettingsLoading.value;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: AbsorbPointer(
              absorbing: loading,
              child: AnimatedOpacity(
                opacity: loading ? .62 : 1,
                duration: const Duration(milliseconds: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerCard(context),
                    const SizedBox(height: 20),
                    _sectionTitle(context, ('Privacy & Room Control').appTr),
                    const SizedBox(height: 10),
                    _settingTile(
                      context: context,
                      icon: Icons.lock_rounded,
                      title: ('Room Lock').appTr,
                      subtitle: liveController.liveRoomLocked.value
                          ? ('Password required to join this room.').appTr: ('Users can join without password.').appTr,
                      value: liveController.liveRoomLocked.value,
                      onTap: () => _toggleRoomLock(liveController.liveRoomLocked.value),
                    ),
                    _settingTile(
                      context: context,
                      icon: Icons.chat_bubble_rounded,
                      title: ('Lock Chat').appTr,
                      subtitle: liveController.liveCommentLocked.value
                          ? ('Comment is locked for viewers/callers.').appTr: ('Viewers/callers can send comments.').appTr,
                      value: liveController.liveCommentLocked.value,
                      onTap: () => _toggleChatLock(liveController.liveCommentLocked.value),
                    ),
                    _settingTile(
                      context: context,
                      icon: Icons.visibility_off_rounded,
                      title: ('Hidden Room').appTr,
                      subtitle: liveController.liveHiddenRoom.value
                          ? ('Room is hidden from live list.').appTr: ('Room is visible in live list.').appTr,
                      value: liveController.liveHiddenRoom.value,
                      onTap: () => _toggleHiddenRoom(liveController.liveHiddenRoom.value),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(context, ('Screen Protection').appTr),
                    const SizedBox(height: 10),
                    _settingTile(
                      context: context,
                      icon: Icons.fiber_manual_record_rounded,
                      title: ('Screen Record').appTr,
                      subtitle: liveController.liveScreenRecordBlocked.value
                          ? ('Screen recording is blocked.').appTr: ('Screen recording is allowed.').appTr,
                      value: liveController.liveScreenRecordBlocked.value,
                      onTap: () => _toggleScreenRecord(liveController.liveScreenRecordBlocked.value),
                    ),
                    _settingTile(
                      context: context,
                      icon: Icons.screenshot_monitor_rounded,
                      title: ('Screenshot').appTr,
                      subtitle: liveController.liveScreenshotBlocked.value
                          ? ('Screenshot is blocked.').appTr: ('Screenshot is allowed.').appTr,
                      value: liveController.liveScreenshotBlocked.value,
                      onTap: () => _toggleScreenshot(liveController.liveScreenshotBlocked.value),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle(context, ('Chat Action').appTr),
                    const SizedBox(height: 10),
                    _actionTile(
                      context: context,
                      icon: Icons.cleaning_services_rounded,
                      title: ('Clean Chat').appTr,
                      subtitle: ('Clear all current live room comments for everyone.').appTr,
                      onTap: _cleanChat,
                    ),
                    const SizedBox(height: 16),
                    _noteCard(context),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [_primary, _primary2]),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(.22),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('Manage Live Room').appTr,
                  style: GoogleFonts.poppins(
                    color: _text,
                    fontSize: _sp(context, 16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ('Lock room, control chat, hide room and manage screen protection smoothly.').appTr,
                  style: GoogleFonts.poppins(
                    color: _subText,
                    fontSize: _sp(context, 12.2),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: _text,
        fontSize: _sp(context, 14.5),
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _settingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: value ? _primary.withOpacity(.25) : _cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.045),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: value ? _primary.withOpacity(.10) : _softBg,
                ),
                child: Icon(icon, color: value ? _primary : _subText, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: _text,
                              fontSize: _sp(context, 14.2),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(value),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _subText,
                        fontSize: _sp(context, 11.5),
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: (_) => onTap(),
                activeColor: Colors.white,
                activeTrackColor: _primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFD7DAE2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: value ? _primary.withOpacity(.10) : Colors.green.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        value ? ('ON').appTr: ('OFF').appTr,
        style: GoogleFonts.poppins(
          color: value ? _primary : Colors.green,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFFF6B6B).withOpacity(.11),
              ),
              child: Icon(icon, color: const Color(0xFFFF4D4D), size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: _text,
                      fontSize: _sp(context, 14.2),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: _subText,
                      fontSize: _sp(context, 11.5),
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: _subText, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _primary.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withOpacity(.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _primary, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              ('Every setting updates with edit API and realtime event. 1 means lock/hide/block, 0 means unlock/show/allow.').appTr,
              style: GoogleFonts.poppins(
                color: _subText,
                fontSize: _sp(context, 11.2),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
