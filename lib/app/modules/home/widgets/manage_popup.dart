import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../constants/image_helper.dart';
import '../../livestream/utils/vip_privileges.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ManagePopup extends StatelessWidget {
  final String userId;
  final dynamic userAllData;
  final String userName;
  final String userAvatar;

  /// For host report.
  /// Pass livestreamId and hostId when opening host profile from live room.
  final int? livestreamId;
  final int? hostId;
  final bool isHostProfile;

  final VoidCallback? onSendGifts;
  final VoidCallback? onViewProfile;
  final VoidCallback? onLeaveMic;
  final VoidCallback? onMuteMic;
  final VoidCallback? onCameraOnOff;
  final VoidCallback? onKickOut;
  final VoidCallback? onSetAdministrator;
  final VoidCallback? onAddToRoomBlacklist;
  final VoidCallback? onAddToPersonalBlacklist;
  final VoidCallback? guardianList;

  const ManagePopup({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.userAllData,
    this.livestreamId,
    this.hostId,
    this.isHostProfile = false,
    this.onSendGifts,
    this.onViewProfile,
    this.onLeaveMic,
    this.onMuteMic,
    this.onKickOut,
    this.onSetAdministrator,
    this.onAddToRoomBlacklist,
    this.onAddToPersonalBlacklist,
    this.onCameraOnOff,
    this.guardianList,
  }) : super(key: key);

  static void show(BuildContext context, ManagePopup popup) {
    Get.bottomSheet(
      popup,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  int get _targetUserId => int.tryParse(userId) ?? 0;

  void _toast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 13,
    );
  }

  void _blockUser() {
    if (VipPrivileges.from(userAllData).antiBlock) {
      _toast(('Protected by VIP privilege').appTr);
      return;
    }
    if (_targetUserId == 0) {
      _toast(('Invalid user').appTr);
      return;
    }

    Get.back();
    Get.dialog(
      _ConfirmDialog(
        icon: Icons.block_rounded,
        title: ('Block user?').appTr,
        message: ('Blocked users will not be able to interact with you normally. You can unblock from Settings > Block List.').appTr,
        confirmText: ('Block').appTr,
        confirmColor: Colors.redAccent,
        onConfirm: () {
          Get.back();
          homeController.userBlock(userId: _targetUserId);
        },
      ),
    );
  }

  int _safeMapInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      final parsed = _safeInt(value);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  int _extractLivestreamIdFromData() {
    final directId = livestreamId ?? 0;
    if (directId > 0) return directId;

    final Map<String, dynamic> userMap = _extractUserMap();
    final int fromUserMap = _safeMapInt(userMap, [
      'livestream_id',
      'live_stream_id',
      'stream_id',
      'live_id',
      'room_id',
      'livestreamId',
      'liveStreamId',
      'streamId',
    ]);
    if (fromUserMap > 0) return fromUserMap;

    if (userAllData is Map) {
      final Map<String, dynamic> root = Map<String, dynamic>.from(userAllData);

      final int fromRoot = _safeMapInt(root, [
        'livestream_id',
        'live_stream_id',
        'stream_id',
        'live_id',
        'room_id',
        'livestreamId',
        'liveStreamId',
        'streamId',
      ]);
      if (fromRoot > 0) return fromRoot;

      final nestedKeys = [
        'livestream',
        'livestreamdata',
        'liveStream',
        'live_stream',
        'live',
        'stream',
        'room',
        'data',
      ];

      for (final key in nestedKeys) {
        final nested = root[key];
        if (nested is Map) {
          final nestedMap = Map<String, dynamic>.from(nested);
          final nestedId = _safeMapInt(nestedMap, [
            'id',
            'livestream_id',
            'live_stream_id',
            'stream_id',
            'live_id',
            'room_id',
            'livestreamId',
            'liveStreamId',
            'streamId',
          ]);
          if (nestedId > 0) return nestedId;
        }
      }
    }

    return 0;
  }

  void _openReportDialog() {
    final int finalLivestreamId = _extractLivestreamIdFromData();
    final int finalHostId = hostId ?? _targetUserId;

    if (finalHostId <= 0) {
      _toast(('Invalid user').appTr);
      return;
    }

    if (finalLivestreamId <= 0) {
      _toast(('Live room information missing. Please re-enter the room and try again.').appTr);
      return;
    }

    Get.back();

    Future.delayed(const Duration(milliseconds: 160), () {
      Get.dialog(
        _ReportHostDialog(
          livestreamId: finalLivestreamId,
          hostId: finalHostId,
          isHostReport: _isTargetHostUser(userId),
        ),
        barrierDismissible: false,
      );
    });
  }


  Map<String, dynamic> _safeMapLocal(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  int _currentUserId() {
    try {
      return authController.userProfile.value.user?.id?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  int _currentStreamId() {
    try {
      return _safeInt(livestreamController.streamId.value);
    } catch (_) {
      return 0;
    }
  }

  int _streamIdFromMapLocal(Map<String, dynamic> raw) {
    return _safeInt(
      raw['livestream_id'] ??
          raw['livestreamId'] ??
          raw['stream_id'] ??
          raw['streamId'] ??
          raw['id'],
    );
  }

  int _ownerIdFromMapLocal(Map<String, dynamic> raw) {
    final user = _safeMapLocal(raw['user']);
    final host = _safeMapLocal(raw['host']);
    final broadcaster = _safeMapLocal(raw['broadcaster']);

    return _safeInt(
      raw['host_id'] ??
          raw['broadcaster_id'] ??
          raw['creator_id'] ??
          raw['user_id'] ??
          raw['admin_id'] ??
          user['id'] ??
          host['id'] ??
          broadcaster['id'],
    );
  }

  /// ✅ Current room owner check. Old isBroadcaster/global host flag use korle onno live-e permission leak kore.
  bool _isCurrentRoomOwner() {
    final myId = _currentUserId();
    if (myId <= 0) return false;

    try {
      final dynamic live = livestreamController;
      if (live.isCurrentUserCurrentLiveOwner == true) return true;
    } catch (_) {}

    try {
      final broadcasterId = _safeInt(livestreamController.broadcasterId.value);
      if (broadcasterId > 0 && broadcasterId == myId) return true;
    } catch (_) {}

    final currentStreamId = _currentStreamId();
    final data = _safeMapLocal(livestreamController.createStreamData);
    final sources = <Map<String, dynamic>>[
      _safeMapLocal(data['livestreamdata']),
      _safeMapLocal(data['livestream']),
      _safeMapLocal(data['data']),
      data,
    ];

    for (final source in sources) {
      if (source.isEmpty) continue;
      final sourceStreamId = _streamIdFromMapLocal(source);
      if (currentStreamId > 0 && sourceStreamId > 0 && sourceStreamId != currentStreamId) {
        continue;
      }

      final ownerId = _ownerIdFromMapLocal(source);
      if (ownerId > 0) return ownerId == myId;
    }

    return false;
  }

  bool _selfCallRowSaysRoomAdmin() {
    final myId = _currentUserId();
    if (myId <= 0) return false;

    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final user = _safeMapLocal(row['user']);
        final uid = _safeInt(row['caller_id'] ?? row['user_id'] ?? user['id']);
        if (uid != myId) continue;

        final status = (row['call_status'] ?? row['status'] ?? '').toString().toLowerCase();
        final accepted = status.isEmpty ||
            status == 'accepted' ||
            status == 'joined' ||
            status == 'active' ||
            status == 'live';
        if (!accepted) continue;

        return _guardianBool(
          row['is_guardian'] ??
              row['guardian'] ??
              user['is_guardian'] ??
              user['guardian'],
        );
      }
    } catch (_) {}

    return false;
  }

  /// ✅ Current room admin check only. homeController.isGuardianPermission use korbo na.
  bool _isCurrentRoomAdmin() {
    final myId = _currentUserId();
    if (myId <= 0) return false;

    try {
      if (livestreamController.roomGuardianMap.containsKey(myId)) {
        return livestreamController.roomGuardianMap[myId] == true;
      }
      if (livestreamController.isMyGuardian.value == true) return true;
    } catch (_) {}

    if (_selfCallRowSaysRoomAdmin()) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    /// ✅ Current room scoped permission only.
    /// isBroadcaster/global guardian value stale thakte pare, tai direct use korbo na.
    final bool isBroadcaster = _isCurrentRoomOwner();
    final bool isCurrentUser =
        userId == authController.userProfile.value.user?.id.toString();

    /// Host = full control.
    /// Room Admin/Guardian = moderation control, but cannot control host and cannot set/remove admin.
    final bool isGuardianUser = _isCurrentRoomAdmin();

    final bool canModerate = isBroadcaster || isGuardianUser;
    final bool targetIsHost = _isTargetHostUser(userId);
    final bool targetIsRoomAdmin = _isTargetRoomAdmin();
    final bool currentUserOnlyRoomAdmin = !isBroadcaster && isGuardianUser;
    final targetVip = VipPrivileges.from(userAllData);

    final bool canMuteTarget =
        canModerate && !isCurrentUser && !targetIsHost && onMuteMic != null;
    final bool canRemoveTargetFromMic =
        canModerate && !isCurrentUser && !targetIsHost && onLeaveMic != null;
    final bool canKickTarget =
        canModerate &&
            !isCurrentUser &&
            !targetIsHost &&
            !(currentUserOnlyRoomAdmin && targetIsRoomAdmin) &&
            !targetVip.antiKickBan &&
            onKickOut != null;
    final bool canRoomBlockTarget = canModerate &&
        !isCurrentUser &&
        !targetIsHost &&
        !targetVip.antiKickBan &&
        onAddToRoomBlacklist != null;

    /// ✅ Only real host can set/remove admin.
    /// Guardian cannot make another admin and cannot remove admin.
    final bool canSetOrRemoveAdmin =
        isBroadcaster && !isCurrentUser && !targetIsHost && onSetAdministrator != null;

    final bool canSelfLiveMic = isCurrentUser && onLeaveMic != null;
    final bool canSelfMute = isCurrentUser && onMuteMic != null;

    final Map<String, dynamic> userMap = _extractUserMap();
    final String profileImage = _resolveImageUrl(
      userAvatar.isNotEmpty
          ? userAvatar
          : userMap['profile_image'] ??
          userMap['avatar'] ??
          userMap['image'] ??
          userMap['photo'],
    );
    final String frameImage = _resolveImageUrl(_extractFrameValue(userMap));
    final String displayId = (userMap['user_id'] ??
        userMap['unique_id'] ??
        userMap['lin_id'] ??
        userId)
        .toString();

    return Container(
      constraints: BoxConstraints(
        maxHeight: kHeight * 0.84,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: 14 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      kAppColor.withOpacity(0.96),
                      kAppColor.withOpacity(0.76),
                      const Color(0xff111827),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kAppColor.withOpacity(0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _profileAvatarWithFrame(
                      profileImage: profileImage,
                      frameImage: frameImage,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.isEmpty ? ('User').appTr: userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.18),
                                    ),
                                  ),
                                  child: Text(
                                    ('ID: $displayId').appTr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.92),
                                    ),
                                  ),
                                ),
                              ),
                              if (targetIsHost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    ('HOST').appTr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              _sectionCard(
                children: [
                  _buildOption(
                    icon: Icons.person_rounded,
                    title: ('View profile').appTr,
                    onTap: onViewProfile,
                  ),
                  if (!isCurrentUser)
                    _buildOption(
                      icon: Icons.block_rounded,
                      title: targetVip.antiBlock
                          ? ('Protected by VIP privilege').appTr
                          : ('Block user').appTr,
                      danger: !targetVip.antiBlock,
                      onTap: targetVip.antiBlock
                          ? () => _toast(
                                ('Protected by VIP privilege').appTr,
                              )
                          : _blockUser,
                    ),
                  if (!isCurrentUser)
                    _buildOption(
                      icon: Icons.report_gmailerrorred_rounded,
                      title: targetIsHost || isHostProfile ? ('Report host').appTr: ('Report user').appTr,
                      danger: true,
                      onTap: _openReportDialog,
                    ),
                ],
              ),

              /// ✅ Own profile options:
              /// Host/guardian/user nijer profile e View profile + Leave mic + Mute pabe.
              if (canSelfLiveMic || canSelfMute) ...[
                const SizedBox(height: 12),
                _sectionCard(
                  children: [
                    if (canSelfLiveMic)
                      _buildOption(
                        icon: Icons.keyboard_voice_rounded,
                        title: ('Leave live mic').appTr,
                        onTap: onLeaveMic,
                      ),
                    if (canSelfMute)
                      _buildOption(
                        icon: Icons.volume_off_rounded,
                        title: ('Mute/Unmute mic').appTr,
                        onTap: onMuteMic,
                      ),
                  ],
                ),
              ],

              /// ✅ Host/Guardian moderation options for other users.
              /// Guardian can moderate viewers, but cannot control host and cannot set admin.
              if (canMuteTarget ||
                  canRemoveTargetFromMic ||
                  canKickTarget ||
                  canSetOrRemoveAdmin ||
                  canRoomBlockTarget) ...[
                const SizedBox(height: 12),
                _sectionCard(
                  children: [
                    if (canMuteTarget)
                      _buildOption(
                        icon: Icons.volume_off_rounded,
                        title: ('Mute/Unmute mic').appTr,
                        onTap: onMuteMic,
                      ),
                    if (canRemoveTargetFromMic)
                      _buildOption(
                        icon: Icons.keyboard_voice_rounded,
                        title: ('Remove from live mic').appTr,
                        onTap: onLeaveMic,
                      ),
                    if (canKickTarget)
                      _buildOption(
                        icon: Icons.exit_to_app_rounded,
                        title: ('Kick out').appTr,
                        onTap: onKickOut,
                      ),
                    if (canSetOrRemoveAdmin)
                      _buildOption(
                        icon: Icons.admin_panel_settings_rounded,
                        title: _isTargetRoomAdmin()
                            ? ('Remove Room Admin').appTr: ('Set Room Admin').appTr,
                        onTap: onSetAdministrator,
                      ),
                    if (canRoomBlockTarget)
                      _buildOption(
                        icon: Icons.meeting_room_rounded,
                        title: ('Room block').appTr,
                        danger: true,
                        onTap: onAddToRoomBlacklist,
                      ),
                  ],
                ),
              ],

              if (currentUserOnlyRoomAdmin && targetIsRoomAdmin && !targetIsHost && !isCurrentUser) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.22),
                    ),
                  ),
                  child: Text(
                    ('Room Admin cannot kick another Room Admin.').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],

              if (canModerate &&
                  !isCurrentUser &&
                  !targetIsHost &&
                  targetVip.antiKickBan) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD76A).withOpacity(.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    ('Protected by VIP privilege').appTr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6A4A00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              if (isGuardianUser && targetIsHost && !isCurrentUser) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.orangeAccent.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    ('Guardian cannot control the host.').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],

              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    ('Cancel').appTr,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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


  bool _guardianBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  bool _isTargetRoomAdmin() {
    final int targetId = int.tryParse(userId) ?? 0;
    if (targetId <= 0) return false;

    try {
      if (livestreamController.roomGuardianMap.containsKey(targetId)) {
        return livestreamController.roomGuardianMap[targetId] == true;
      }
    } catch (_) {}

    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final Map<String, dynamic> user =
        raw['user'] is Map ? Map<String, dynamic>.from(raw['user']) : <String, dynamic>{};
        final int uid = _safeInt(
          raw['caller_id'] ?? raw['user_id'] ?? user['id'] ?? user['user_id'],
        );
        if (uid == targetId) {
          return _guardianBool(
            raw['is_guardian'] ?? raw['guardian'] ?? user['is_guardian'] ?? user['guardian'],
          );
        }
      }
    } catch (_) {}

    final Map<String, dynamic> userMap = _extractUserMap();
    return _guardianBool(
      userMap['is_guardian'] ??
          userMap['guardian'] ??
          homeController.isGuardianData['is_guardian'] ??
          homeController.isGuardianData['value'],
    );
  }


  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _truthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'host' || text == 'broadcaster';
  }

  bool _isTargetHostUser(String targetUserId) {
    final int targetId = _safeInt(targetUserId);
    if (targetId <= 0) return false;

    try {
      final int broadcasterId = livestreamController.broadcasterId.value;
      if (broadcasterId > 0 && broadcasterId == targetId) return true;
    } catch (_) {}

    try {
      for (final raw in websocketController.liveCallList) {
        if (raw is! Map) continue;
        final int callerId = _safeInt(raw['caller_id'] ?? raw['user_id'] ?? raw['user']?['id']);
        if (callerId != targetId) continue;
        if (_truthy(raw['is_broadcaster']) || _truthy(raw['is_host']) || _truthy(raw['host'])) {
          return true;
        }
      }
    } catch (_) {}

    final Map<String, dynamic> userMap = _extractUserMap();
    if (_truthy(userMap['is_broadcaster']) ||
        _truthy(userMap['is_host']) ||
        _truthy(userMap['host']) ||
        userMap['user_type']?.toString().toLowerCase() == 'host') {
      return true;
    }

    return false;
  }

  Map<String, dynamic> _extractUserMap() {
    if (userAllData is Map && userAllData['User Data'] is Map) {
      return Map<String, dynamic>.from(userAllData['User Data']);
    }
    if (userAllData is Map && userAllData['user'] is Map) {
      return Map<String, dynamic>.from(userAllData['user']);
    }
    if (userAllData is Map && userAllData['data'] is Map) {
      return Map<String, dynamic>.from(userAllData['data']);
    }
    if (userAllData is Map) {
      return Map<String, dynamic>.from(userAllData);
    }
    return <String, dynamic>{};
  }

  dynamic _extractFrameValue(Map<String, dynamic> userMap) {
    final dynamic direct = userMap['profile_frame'] ??
        userMap['profileFrame'] ??
        userMap['frame'] ??
        userMap['active_frame'] ??
        userMap['activeFrame'] ??
        userMap['avatar_frame'] ??
        userMap['base_frame'] ??
        userMap['frame_image'] ??
        userMap['frame_url'];

    if (direct != null) return direct;

    if (userAllData is Map) {
      final Map<String, dynamic> root = Map<String, dynamic>.from(userAllData);
      return root['profile_frame'] ??
          root['profileFrame'] ??
          root['frame'] ??
          root['active_frame'] ??
          root['activeFrame'] ??
          root['avatar_frame'] ??
          root['base_frame'] ??
          root['frame_image'] ??
          root['frame_url'];
    }

    return null;
  }

  String _resolveImageUrl(dynamic value) {
    dynamic raw = value;

    if (raw is Map) {
      raw = raw['image'] ??
          raw['image_url'] ??
          raw['frame_image'] ??
          raw['frame_url'] ??
          raw['profile_frame'] ??
          raw['file'] ??
          raw['path'] ??
          raw['url'];
    }

    final String text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';

    return ImageHelper.getImageUrl(text);
  }

  Widget _profileAvatarWithFrame({
    required String profileImage,
    required String frameImage,
  }) {
    return SizedBox(
      height: 72,
      width: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.18),
              border: Border.all(
                color: Colors.white.withOpacity(0.65),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: profileImage.isEmpty
                ? Icon(
              Icons.person_rounded,
              color: Colors.white.withOpacity(0.90),
              size: 34,
            )
                : CachedNetworkImage(
              imageUrl: profileImage,
              fit: BoxFit.cover,
              placeholder: (_, __) => Icon(
                Icons.person_rounded,
                color: Colors.white.withOpacity(0.75),
                size: 32,
              ),
              errorWidget: (_, __, ___) => Icon(
                Icons.person_rounded,
                color: Colors.white.withOpacity(0.75),
                size: 32,
              ),
            ),
          ),
          if (frameImage.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: frameImage,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final Color mainColor = danger ? Colors.redAccent : kAppColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => Get.back(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: mainColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: kHeight * 0.0158,
                    fontWeight: FontWeight.w700,
                    color: danger ? Colors.redAccent : const Color(0xff1F2937),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Colors.black.withOpacity(0.22),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _ReportHostDialog extends StatefulWidget {
  final int livestreamId;
  final int hostId;
  final bool isHostReport;

  const _ReportHostDialog({
    required this.livestreamId,
    required this.hostId,
    this.isHostReport = true,
  });

  @override
  State<_ReportHostDialog> createState() => _ReportHostDialogState();
}

class _ReportHostDialogState extends State<_ReportHostDialog> {
  final TextEditingController descriptionController = TextEditingController();

  String reason = 'abuse';

  final List<Map<String, String>> reasons = [
    {'key': 'abuse', 'label': ('Abusive language').appTr},
    {'key': 'harassment', 'label': ('Harassment or bullying').appTr},
    {'key': 'adult_content', 'label': ('Adult or sexual content').appTr},
    {'key': 'hate_speech', 'label': ('Hate speech').appTr},
    {'key': 'scam', 'label': ('Scam or fraud').appTr},
    {'key': 'other', 'label': ('Other').appTr},
  ];

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final String description = descriptionController.text.trim();

    if (description.length < 5) {
      Fluttertoast.showToast(
        msg: ('Please write a short description').appTr,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
      return;
    }

    homeController.reportHost(
      livestreamId: widget.livestreamId,
      hostId: widget.hostId,
      reason: reason,
      description: description,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Obx(() {
        final bool loading = homeController.reportHostLoading.value;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.report_gmailerrorred_rounded,
                color: Colors.redAccent,
                size: kHeight * 0.052,
              ),
              const SizedBox(height: 10),
              Text(
                widget.isHostReport ? ('Report Host').appTr: ('Report User').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ('Tell us what happened. Our moderation team will review your report.').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: reason,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: ('Reason').appTr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                ),
                items: reasons
                    .map(
                      (item) => DropdownMenuItem<String>(
                    value: item['key'],
                    child: Text(item['label'] ?? ''),
                  ),
                )
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) {
                  if (value == null) return;
                  setState(() => reason = value);
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller: descriptionController,
                enabled: !loading,
                maxLines: 4,
                maxLength: 250,
                decoration: InputDecoration(
                  hintText: ('Describe the issue...').appTr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:  Text(('Cancel').appTr),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        ('Submit').appTr,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: confirmColor, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child:  Text(('Cancel').appTr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
