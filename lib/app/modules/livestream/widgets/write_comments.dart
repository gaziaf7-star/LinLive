import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/auth/controllers/auth_controller.dart';
import 'package:meetlivepro/app/modules/livestream/controllers/livestream_controller.dart';
import 'package:meetlivepro/app/modules/livestream/socket/websocket_controller.dart';
import 'package:meetlivepro/app/modules/messanger/views/chat_controller.dart';
import 'package:meetlivepro/app/modules/messanger/views/chat_model.dart';
import 'package:meetlivepro/app/modules/messanger/views/chatpage_view.dart';
import 'package:meetlivepro/app/modules/livestream/widgets/entertainment_tools_widget.dart';
import 'package:meetlivepro/app/modules/livestream/widgets/reseableIconButton.dart';
import 'package:meetlivepro/app/services/agora_service.dart';
import 'package:meetlivepro/constants/layout_constant.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../widgets/message_bottom.dart';

import 'gift_bottom_sheet.dart';
import 'live_imogi_bottom_sheet.dart';
import 'live_viewer_list.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class WriteCommentSection extends StatefulWidget {
  static bool Function(Map<String, dynamic> user)? _activeMentionInserter;
  static Map<String, dynamic>? _pendingDirectMentionUser;

  /// Called from live profile bottom sheet @ button.
  ///
  /// This is DIRECT mention insert only. It never opens the mention picker/list,
  /// so when user taps @ from a profile, @Name is written into the active
  /// comment TextField smoothly. If the input is rebuilding while a sheet closes,
  /// the mention is queued and inserted on the next active comment input frame.
  static bool insertMentionToActiveInput(Map<String, dynamic> user) {
    final safeUser = Map<String, dynamic>.from(user);
    final inserter = _activeMentionInserter;

    if (inserter != null) {
      final inserted = inserter(safeUser);
      if (inserted) {
        _pendingDirectMentionUser = null;
        return true;
      }
    }

    _pendingDirectMentionUser = safeUser;
    return false;
  }

  static void _flushPendingMentionAfterFrame() {
    final pending = _pendingDirectMentionUser;
    final inserter = _activeMentionInserter;
    if (pending == null || inserter == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final latestPending = _pendingDirectMentionUser;
      final latestInserter = _activeMentionInserter;
      if (latestPending == null || latestInserter == null) return;

      final inserted = latestInserter(latestPending);
      if (inserted) {
        _pendingDirectMentionUser = null;
      }
    });
  }

  RtcEngine rtcEngine;
  final String streamType;
  final RxMap broadcasterData;

  /// Video LIVE-only controls supplied by PopularLiveView. Keeping these as
  /// callbacks/widgets avoids duplicating Agora filter or PK request logic in
  /// this shared comment bar (which is also used by Audio LIVE).
  final VoidCallback? onVideoFilterTap;
  final Widget? videoPkButton;

  WriteCommentSection({
    required this.rtcEngine,
    required this.streamType,
    required this.broadcasterData,
    this.onVideoFilterTap,
    this.videoPkButton,
  });

  @override
  _WriteCommentSectionState createState() => _WriteCommentSectionState();
}

class _WriteCommentSectionState extends State<WriteCommentSection> {
  final TextEditingController addComments = TextEditingController();
  final FocusNode commentFocusNode = FocusNode();

  final LivestreamController livestreamController = Get.find();
  final WebsocketController websocketController = Get.find();
  final AuthController authController = Get.find();

  late final ChatController _chatController;

  bool isTyping = false;
  bool isSwitched = false;
  bool showAnimatedMessage = false;
  bool _sendingComment = false;
  bool _isCompactCommentSheetOpen = false;
  final Set<int> _callRequestsInFlight = <int>{};

  bool get _canManageCalls =>
      livestreamController.isBroadcaster.value ||
          livestreamController.canModerateLive == true;

  /// Local speaker/remote-audio mute.
  /// Eta shudhu ei device-er jonno kaj korbe:
  /// - mic mute hobe na
  /// - audience/caller ra apnar voice sunte parbe
  /// - apni broad-er karo voice sunben na jokhon speaker off thakbe
  bool _isBroadSpeakerMuted = false;

  Future<void> _toggleBroadSpeakerMute() async {
    final bool nextMuted = !_isBroadSpeakerMuted;

    _safeSetState(() {
      _isBroadSpeakerMuted = nextMuted;
    });

    try {
      await widget.rtcEngine.muteAllRemoteAudioStreams(nextMuted);
      await widget.rtcEngine.adjustPlaybackSignalVolume(nextMuted ? 0 : 100);

      if (!nextMuted) {
        await widget.rtcEngine.setEnableSpeakerphone(true);
        await widget.rtcEngine.setDefaultAudioRouteToSpeakerphone(true);
      }

      debugPrint('🔈 Broad speaker local mute => $nextMuted');
    } catch (e) {
      debugPrint('❌ Broad speaker mute error: $e');
      _safeSetState(() {
        _isBroadSpeakerMuted = !nextMuted;
      });
    }
  }

  bool _callStatusIsActive(dynamic value) {
    final status = _safeText(value).toLowerCase();
    return status == 'accepted' ||
        status == 'joined' ||
        status == 'active' ||
        status == 'live' ||
        status == 'on_seat';
  }

  bool _callWantsVideo(Map<String, dynamic> call) {
    final type = _safeText(call['call_type'] ?? call['type']).toLowerCase();
    return type == 'video' || type == 'popular';
  }

  Map<String, dynamic>? _currentUserVideoCall() {
    final int userId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId <= 0) return null;

    for (final raw in websocketController.liveCallList) {
      if (raw is! Map) continue;
      final call = Map<String, dynamic>.from(raw);
      final user = call['user'] is Map
          ? Map<String, dynamic>.from(call['user'])
          : <String, dynamic>{};
      final int callUserId = _safeInt(
        call['caller_id'] ?? call['user_id'] ?? user['id'] ?? user['user_id'],
      );
      if (callUserId != userId ||
          !_callStatusIsActive(call['call_status'] ?? call['status']) ||
          !_callWantsVideo(call)) {
        continue;
      }
      return call;
    }
    return null;
  }

  bool _currentUserCanToggleVideo() {
    if (widget.streamType != 'popular') return false;
    if (livestreamController.isBroadcaster.value) return true;
    return _currentUserVideoCall() != null;
  }

  bool _currentUserVideoEnabled() {
    if (livestreamController.isBroadcaster.value) {
      return livestreamController.isVideoEnabled.value;
    }

    final call = _currentUserVideoCall();
    if (call == null) return false;
    final value = call['video_on'] ?? call['is_video_on'];
    if (value == null) return true;
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'enabled';
  }

  // Future<void> _toggleMyVideo() async {
  //   await livestreamController.toggleMyVideoFromAnyButton(
  //     rtcEngine: widget.rtcEngine,
  //   );
  // }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _safeText(dynamic value) => value?.toString().trim() ?? '';

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? fallback;
  }

  String _mentionName(Map<String, dynamic> user) {
    final name = _safeText(
      user['name'] ?? user['full_name'] ?? user['username'],
    );
    if (name.isNotEmpty && name.toLowerCase() != 'null') return name;
    final uid = _safeText(user['user_id'] ?? user['id']);
    return uid.isNotEmpty ? 'User$uid' : ('User').appTr;
  }

  String _mentionToken(Map<String, dynamic> user) {
    final clean = _mentionName(user)
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-.\u0980-\u09FF]'), '')
        .trim();
    return '@${clean.isEmpty ? 'User' : clean}';
  }

  String _mentionImage(Map<String, dynamic> user) {
    return _safeText(user['profile_image'] ?? user['avatar'] ?? user['image']);
  }

  List<Map<String, dynamic>> _liveMentionUsers() {
    final Map<int, Map<String, dynamic>> unique = <int, Map<String, dynamic>>{};

    void addUser(dynamic raw) {
      final item = _asMap(raw);
      if (item.isEmpty) return;

      final nested = _asMap(
        item['user'] ??
            item['viewer'] ??
            item['caller'] ??
            item['profile'] ??
            item['broadcaster'],
      );
      final user = <String, dynamic>{...item, ...nested};
      final id = _safeInt(
        user['id'] ??
            user['user_id'] ??
            item['caller_id'] ??
            item['viewer_id'] ??
            item['broadcaster_id'],
      );
      if (id <= 0) return;

      unique[id] = {...?unique[id], ...user, 'id': id};
    }

    addUser(
      widget.broadcasterData['user'] ?? widget.broadcasterData['broadcaster'],
    );

    for (final raw in websocketController.liveCallList) {
      addUser(raw);
    }

    for (final raw in livestreamController.liveViewerList) {
      addUser(raw);
    }

    unique.remove(authController.userProfile.value.user?.id?.toInt() ?? 0);

    final users = unique.values.toList();
    users.sort(
          (a, b) => _mentionName(
        a,
      ).toLowerCase().compareTo(_mentionName(b).toLowerCase()),
    );
    return users;
  }

  bool _insertMention(Map<String, dynamic> user) {
    final token = _mentionToken(user);
    final text = addComments.text;
    final selection = addComments.selection;
    final int cursor = selection.isValid
        ? (selection.baseOffset.clamp(0, text.length) as int)
        : text.length;

    int replaceStart = cursor;
    while (replaceStart > 0 &&
        text[replaceStart - 1] != ' ' &&
        text[replaceStart - 1] != '\n') {
      replaceStart--;
    }

    final currentWord = text.substring(replaceStart, cursor);
    final bool replaceCurrentAtWord = currentWord.startsWith('@');
    final int start = replaceCurrentAtWord ? replaceStart : cursor;

    final bool needSpaceBefore =
        start > 0 && !RegExp(r'\s$').hasMatch(text.substring(0, start));
    final insertText = '${needSpaceBefore ? ' ' : ''}$token ';
    final newText = text.replaceRange(start, cursor, insertText);
    final newCursor = start + insertText.length;

    addComments.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _safeSetState(() => isTyping = true);

    // Profile sheet close animation er pore keyboard/comment field smooth focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      commentFocusNode.requestFocus();
    });

    return true;
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _syncTypingState() {
    final next =
        commentFocusNode.hasFocus || addComments.text.trim().isNotEmpty;
    if (next == isTyping) return;
    _safeSetState(() {
      isTyping = next;
    });
  }

  void showFlyingMessage(String message) {
    _safeSetState(() {
      showAnimatedMessage = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      _safeSetState(() {
        showAnimatedMessage = false;
      });
    });
  }

  Future<void> _sendCommentFast() async {
    final text = addComments.text.trim();
    final locked = livestreamController.liveCommentLocked.value == true;
    final canModerate = livestreamController.canModerateLive == true;
    debugPrint(
      '[COMMENT][SEND_TAP] text_length=${text.length} locked=$locked '
          'can_moderate=$canModerate sending=$_sendingComment',
    );
    debugPrint('[COMMENT][UI_HANDLER_ENTER]');

    if (locked &&
        !canModerate &&
        !livestreamController.currentVipPrivileges.antiCommentMute) {
      debugPrint('[COMMENT][UI_BLOCKED] reason=locked');
      addComments.clear();
      commentFocusNode.unfocus();
      _safeSetState(() {
        isTyping = false;
      });
      Fluttertoast.showToast(msg: ('Chat is locked').appTr);
      return;
    }

    if (text.isEmpty) {
      debugPrint('[COMMENT][UI_BLOCKED] reason=empty');
      return;
    }
    if (_sendingComment) {
      debugPrint('[COMMENT][UI_BLOCKED] reason=already_sending');
      return;
    }

    _sendingComment = true;

    addComments.clear();
    commentFocusNode.unfocus();
    _safeSetState(() {
      isTyping = false;
    });

    try {
      await livestreamController.tryToAddComment(comment: text);
    } catch (e) {
      debugPrint('❌ Comment send failed: $e');
    } finally {
      _sendingComment = false;
    }
  }

  @override
  void initState() {
    super.initState();

    _chatController = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController());

    commentFocusNode.addListener(_syncTypingState);
    addComments.addListener(_syncTypingState);
    WriteCommentSection._activeMentionInserter = _insertMention;
    WriteCommentSection._flushPendingMentionAfterFrame();
  }

  @override
  void dispose() {
    commentFocusNode.removeListener(_syncTypingState);
    addComments.removeListener(_syncTypingState);
    if (WriteCommentSection._activeMentionInserter == _insertMention) {
      WriteCommentSection._activeMentionInserter = null;
    }
    addComments.dispose();
    commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _closeCompactCommentSheet() async {
    if (!_isCompactCommentSheetOpen) return;

    commentFocusNode.unfocus();

    if (!mounted) return;

    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

    if (navigator.canPop()) {
      await navigator.maybePop();
    }
  }

  Future<void> _sendCommentFromCompactSheet() async {
    final String text = addComments.text.trim();
    final bool locked = livestreamController.liveCommentLocked.value == true;
    final bool canModerate = livestreamController.canModerateLive == true;
    debugPrint(
      '[COMMENT][SEND_TAP] text_length=${text.length} locked=$locked '
          'can_moderate=$canModerate sending=$_sendingComment',
    );
    debugPrint('[COMMENT][UI_HANDLER_ENTER]');

    if (locked &&
        !canModerate &&
        !livestreamController.currentVipPrivileges.antiCommentMute) {
      debugPrint('[COMMENT][UI_BLOCKED] reason=locked');
      addComments.clear();
      commentFocusNode.unfocus();
      Fluttertoast.showToast(msg: ('Chat is locked').appTr);
      return;
    }

    if (_sendingComment) {
      debugPrint('[COMMENT][UI_BLOCKED] reason=already_sending');
      return;
    }

    // Comment na likhe Send button chapleo keyboard + bottom sheet close hobe.
    if (text.isEmpty) {
      debugPrint('[COMMENT][UI_BLOCKED] reason=empty');
      await _closeCompactCommentSheet();
      return;
    }

    // No loading state is shown. The input closes immediately and the comment
    // is sent in the background, so the keyboard interaction feels instant.
    _sendingComment = true;
    addComments.clear();
    commentFocusNode.unfocus();

    // Start the one authoritative send before dismissing the root sheet. The
    // parent input may rebuild during dismissal, but this Future retains the
    // captured text and cannot be skipped by that lifecycle transition.
    final Future<void> sendFuture = livestreamController.tryToAddComment(
      comment: text,
    );

    if (_isCompactCommentSheetOpen && mounted) {
      await _closeCompactCommentSheet();
    }

    try {
      await sendFuture;
    } catch (e) {
      debugPrint('❌ Comment send failed: $e');
      Fluttertoast.showToast(msg: ('Comment could not be sent').appTr);
    } finally {
      _sendingComment = false;
    }
  }

  void _openCompactCommentBottomSheet() {
    if (livestreamController.liveCommentLocked.value == true &&
        livestreamController.canModerateLive != true &&
        !livestreamController.currentVipPrivileges.antiCommentMute) {
      Fluttertoast.showToast(msg: ('Chat is locked').appTr);
      return;
    }

    if (_isCompactCommentSheetOpen) return;
    _isCompactCommentSheetOpen = true;

    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.12),
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            final MediaQueryData mediaQuery = MediaQuery.of(sheetContext);
            final double keyboardHeight = mediaQuery.viewInsets.bottom;
            final bool keyboardVisible = keyboardHeight > 0;

            // Remove the inherited keyboard inset from the sheet first, then
            // add it exactly once below. This keeps the bar attached to the
            // keyboard and prevents the comment UI from jumping too high.
            return MediaQuery.removeViewInsets(
              context: sheetContext,
              removeBottom: true,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      final bool verySmall = width < 340;
                      final bool compact = width < 390;

                      final double horizontalPadding = verySmall ? 6 : 8;
                      final double switchWidth = verySmall ? 60 : 66;
                      final double sendWidth = verySmall
                          ? 40
                          : (compact ? 52 : 60);
                      final double closeWidth = verySmall ? 34 : 36;

                      return Material(
                        color: Colors.transparent,
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            left: keyboardVisible ? 0 : 6,
                            right: keyboardVisible ? 0 : 6,
                            bottom: keyboardVisible
                                ? 0
                                : mediaQuery.padding.bottom,
                          ),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            6,
                            horizontalPadding,
                            6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: keyboardVisible
                                ? const BorderRadius.vertical(
                              top: Radius.circular(18),
                            )
                                : BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xffEEE7EB),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.11),
                                blurRadius: 18,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: switchWidth,
                                child: _buildCompactOnOffSwitch(
                                  sheetSetState,
                                  compact: compact,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF7F4F6),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: const Color(0xffEDE4E9),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: addComments,
                                    focusNode: commentFocusNode,
                                    cursorColor: const Color(0xffF80230),
                                    autofocus: true,
                                    maxLines: 1,
                                    textInputAction: TextInputAction.send,
                                    keyboardAppearance: Brightness.light,
                                    onFieldSubmitted: (_) =>
                                        _sendCommentFromCompactSheet(),
                                    style: GoogleFonts.roboto(
                                      color: const Color(0xff272229),
                                      fontSize: compact ? 12.2 : 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: ('Write a comment...').appTr,
                                      hintStyle: GoogleFonts.roboto(
                                        color: const Color(0xff978C93),
                                        fontSize: compact ? 11.2 : 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: sendWidth,
                                height: 40,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(13),
                                    onTap: _sendCommentFromCompactSheet,
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(13),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xffFD375D),
                                            Color(0xffF80230),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xffF80230,
                                            ).withOpacity(.20),
                                            blurRadius: 9,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),

                                      // Ink widget-এর alignment parameter নেই,
                                      // তাই Center দিয়ে child মাঝখানে রাখা হয়েছে।
                                      child: Center(
                                        child: verySmall
                                            ? const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        )
                                            : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Padding(
                                            padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 5,
                                            ),
                                            child: Text(
                                              ('Send').appTr,
                                              maxLines: 1,
                                              style: GoogleFonts.lato(
                                                color: Colors.white,
                                                fontSize: compact
                                                    ? 11.5
                                                    : 12.5,
                                                fontWeight:
                                                FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: closeWidth,
                                height: 40,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(13),
                                    onTap: _closeCompactCommentSheet,
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF3EEF1),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: const Color(0xffE7DEE3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: Color(0xff6F646B),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _isCompactCommentSheetOpen = false;
      commentFocusNode.unfocus();
      _safeSetState(() {
        isTyping = addComments.text.trim().isNotEmpty;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 70), () {
        if (!mounted || !_isCompactCommentSheetOpen) return;
        commentFocusNode.requestFocus();
      });
    });
  }

  Widget _buildCompactOnOffSwitch(
      StateSetter sheetSetState, {
        required bool compact,
      }) {
    return Container(
      width: double.infinity,
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xffF5F1F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE7DEE3), width: 1),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            alignment: isSwitched
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: compact ? 27 : 30,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSwitched
                      ? const [Color(0xff3EDB8D), Color(0xff13A966)]
                      : const [Color(0xffFD6A7F), Color(0xffF80230)],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    (isSwitched
                        ? const Color(0xff13A966)
                        : const Color(0xffF80230))
                        .withOpacity(.20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () {
                    if (!isSwitched) return;
                    _safeSetState(() => isSwitched = false);
                    sheetSetState(() {});
                  },
                  child: Center(
                    child: Text(
                      ('OFF').appTr,
                      style: TextStyle(
                        color: isSwitched
                            ? const Color(0xff8D8289)
                            : Colors.white,
                        fontSize: compact ? 8.2 : 8.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () {
                    if (isSwitched) return;
                    _safeSetState(() => isSwitched = true);
                    sheetSetState(() {});
                  },
                  child: Center(
                    child: Text(
                      ('ON').appTr,
                      style: TextStyle(
                        color: isSwitched
                            ? Colors.white
                            : const Color(0xff8D8289),
                        fontSize: compact ? 8.2 : 8.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12, // Glass effect
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: 0, left: 10, right: 10, top: 5),
        child: Padding(
          // Video LIVE controls are lifted slightly above the very bottom.
          // Audio LIVE keeps the existing position unchanged.
          padding: EdgeInsets.only(
            bottom: widget.streamType == "popular"
                ? kHeight * 0.022
                : 8.0,
          ),
          child: SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      // color: Colors.grey.withOpacity(0.2),
                    ),
                    child: false
                        ? SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          Container(
                            height: kHeight * 0.04,
                            width: kWeight * 0.18,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Stack(
                              children: [
                                // Moving background highlight
                                AnimatedAlign(
                                  duration: Duration(milliseconds: 300),
                                  alignment: isSwitched
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  child: Container(
                                    height: 50,
                                    width: kWeight * 0.1,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        30,
                                      ),
                                    ),
                                  ),
                                ),
                                // ON/OFF Texts
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            isSwitched = false;
                                          });
                                        },
                                        child: Center(
                                          child: Text(
                                            ('OFF').appTr,
                                            style: TextStyle(
                                              fontSize: kHeight * 0.013,
                                              fontWeight: FontWeight.bold,
                                              color: isSwitched
                                                  ? Colors.red
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            isSwitched = true;
                                          });
                                        },
                                        child: Center(
                                          child: Text(
                                            ('ON').appTr,
                                            style: TextStyle(
                                              fontSize: kHeight * 0.013,
                                              fontWeight: FontWeight.bold,
                                              color: isSwitched
                                                  ? Colors.black
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: TextFormField(
                              cursorColor: kAppColor,
                              controller: addComments,
                              focusNode: commentFocusNode,
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(.7),
                                fontSize: kHeight * 0.014,
                              ),
                              textInputAction: TextInputAction.send,
                              onFieldSubmitted: (_) => _sendCommentFast(),
                              decoration: InputDecoration(
                                hintText: ('Write a comment...').appTr,
                                hintStyle: GoogleFonts.roboto(
                                  color: Colors.black.withOpacity(.6),
                                  fontSize: kHeight * 0.013,
                                ),
                                filled: true,
                                isCollapsed: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: kWeight * 0.05,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        : Align(
                      alignment: Alignment.centerLeft,
                      child: Obx(() {
                        final bool chatLocked =
                            livestreamController
                                .liveCommentLocked
                                .value ==
                                true &&
                                livestreamController.canModerateLive != true &&
                                !livestreamController
                                    .currentVipPrivileges
                                    .antiCommentMute;

                        return IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: chatLocked
                                ? Colors.red.withOpacity(0.38)
                                : Colors.black.withOpacity(0.3),
                          ),
                          onPressed: () {
                            if (chatLocked) {
                              Fluttertoast.showToast(
                                msg: ('Chat is locked').appTr,
                              );
                              return;
                            }
                            _openCompactCommentBottomSheet();
                          },
                          icon: chatLocked
                              ? Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: kHeight * 0.021,
                          )
                              : ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xffFFDF70),
                                  Color(0xffFD375D),
                                  Color(0xffF80230),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcIn,
                            child: Image.asset(
                              'assets/frame/comment_7945005.png',
                              height: kHeight * 0.02,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: false
                      ? GestureDetector(
                    key: ValueKey(1),
                    behavior: HitTestBehavior.opaque,
                    onTap: _sendCommentFast,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 15,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        gradient: LinearGradient(
                          colors: [kAppColor, kAppColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Text(
                        ('Send').appTr,
                        style: GoogleFonts.lato(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: kHeight * 0.015,
                        ),
                      ),
                    ),
                  )
                      : widget.streamType == "popular"
                      ? _buildVideoLiveBottomActions()
                      : Row(
                    key: ValueKey(2),
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      widget.streamType == "popular" ||
                          widget.streamType == "multi"
                          ? Container()
                          : message_bottom(
                        onPress: () async {
                          final livestreamController =
                          Get.find<LivestreamController>();

                          await livestreamController
                              .fetchImogiList();

                          showLiveImogiBottomSheet(
                            context: context,
                            streamId:
                            livestreamController.streamId.value,
                          );
                        },
                        color2: Color(0xffffffff).withOpacity(.2),
                        image: 'assets/newaudio/happy-face.png',
                        color: Color(0xffffffff).withOpacity(.2),
                      ),
                      widget.streamType == "popular" &&
                          widget.onVideoFilterTap != null &&
                          livestreamController.broadcasterId.value ==
                              authController.userProfile.value.user?.id
                          ? Padding(
                        padding: EdgeInsets.only(right: kWeight * 0.006),
                        child: _buildVideoFilterBottomButton(),
                      )
                          : const SizedBox.shrink(),

                      widget.streamType == "popular" && _canManageCalls
                          ? InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => showCallBottomSheet(
                          context,
                          widget.rtcEngine,
                        ),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.10),
                            ),
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                      )
                          : const SizedBox.shrink(),
                      SizedBox(width: kWeight * 0.005),

                      widget.streamType == "popular" &&
                          livestreamController.broadcasterId.value ==
                              authController
                                  .userProfile
                                  .value
                                  .user!
                                  .id
                          ? InkWell(
                        onTap: () {
                          AgoraService().flipCamera();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xffc4f894),
                                Color(0xff1dfa62),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.cameraswitch_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      )
                          : Container(),

                      // widget.streamType == "popular"
                      //     ? Obx(() {
                      //   if (!_currentUserCanToggleVideo()) {
                      //     return const SizedBox.shrink();
                      //   }
                      //   final bool videoOn =
                      //   _currentUserVideoEnabled();
                      //   return Padding(
                      //     padding: EdgeInsets.only(
                      //       left: kWeight * 0.005,
                      //     ),
                      //     child: InkWell(
                      //       borderRadius: BorderRadius.circular(50),
                      //       onTap: _toggleMyVideo,
                      //       child: Container(
                      //         width: 40,
                      //         height: 40,
                      //         decoration: BoxDecoration(
                      //           color: videoOn
                      //               ? Colors.white.withOpacity(.20)
                      //               : const Color(0xffef3f5f),
                      //           shape: BoxShape.circle,
                      //           border: Border.all(
                      //             color: Colors.white.withOpacity(
                      //               .28,
                      //             ),
                      //           ),
                      //         ),
                      //         child: Icon(
                      //           videoOn
                      //               ? Icons.videocam_rounded
                      //               : Icons.videocam_off_rounded,
                      //           size: 20,
                      //           color: Colors.white,
                      //         ),
                      //       ),
                      //     ),
                      //   );
                      // })
                      //     : const SizedBox.shrink(),

                      SizedBox(width: kWeight * 0.0),

                      //------------------- micOff-----------
                      SizedBox(width: kWeight * 0.005),

                      // ✅ Replace your old mute button block with this full fixed block.

                      (widget.broadcasterData?['user']?['id'] != null &&
                          widget.broadcasterData?['user']?['id'] ==
                              authController
                                  .userProfile
                                  .value
                                  .user
                                  ?.id)
                          ? Obx(() {
                        final int userId = authController
                            .userProfile
                            .value
                            .user!
                            .id!
                            .toInt();

                        final hostCallIndex = websocketController
                            .liveCallList
                            .indexWhere((call) {
                          final callerId = call['caller_id'];
                          final callUserId =
                          call['user']?['id'];
                          return callerId.toString() ==
                              userId.toString() ||
                              callUserId.toString() ==
                                  userId.toString();
                        });

                        // ✅ Host mute icon priority:
                        // 1) websocket last known state
                        // 2) local livestreamController.mute
                        // 3) liveCallList audio_on fallback
                        // This prevents host from showing unmute when host is actually muted.
                        final bool hasKnownMute =
                        websocketController.audioMutedUserMap
                            .containsKey(userId);
                        final bool knownMuted = hasKnownMute
                            ? websocketController
                            .audioMutedUserMap[userId] ==
                            true
                            : livestreamController.mute.value ==
                            true;

                        final bool audioOn = knownMuted
                            ? false
                            : (hasKnownMute
                            ? true
                            : (hostCallIndex != -1
                            ? (websocketController
                            .liveCallList[hostCallIndex]['audio_on'] ==
                            1 ||
                            websocketController
                                .liveCallList[hostCallIndex]['audio_on']
                                .toString() ==
                                '1' ||
                            websocketController
                                .liveCallList[hostCallIndex]['is_audio_on'] ==
                                1 ||
                            websocketController
                                .liveCallList[hostCallIndex]['is_audio_on']
                                .toString() ==
                                '1')
                            : true));

                        return message_bottom(
                          onPress: () async {
                            await livestreamController
                                .toggleSpecificUserAudio(
                              userId,
                              rtcEngine: widget.rtcEngine,
                            );
                          },
                          color2: audioOn
                              ? Color(0xffffffff).withOpacity(.2)
                              : Color(0xffffffff).withOpacity(.2),
                          image: audioOn
                              ? 'assets/newaudio/microphone.png'
                              : 'assets/flaticons/mute.png',
                          color: audioOn
                              ? Color(0xffffffff).withOpacity(.2)
                              : Color(0xffffffff).withOpacity(.2),
                        );
                      })
                          : Obx(() {
                        final int userId = authController
                            .userProfile
                            .value
                            .user!
                            .id!
                            .toInt();

                        final myCallIndex = websocketController
                            .liveCallList
                            .indexWhere((call) {
                          final callerId = call['caller_id'];
                          final callUserId =
                          call['user']?['id'];
                          return callerId.toString() ==
                              userId.toString() ||
                              callUserId.toString() ==
                                  userId.toString();
                        });

                        final bool hasKnownMute =
                        websocketController.audioMutedUserMap
                            .containsKey(userId);
                        final bool knownMuted = hasKnownMute
                            ? websocketController
                            .audioMutedUserMap[userId] ==
                            true
                            : livestreamController.mute.value ==
                            true;

                        final bool audioOn = knownMuted
                            ? false
                            : (hasKnownMute
                            ? true
                            : (myCallIndex != -1
                            ? (websocketController
                            .liveCallList[myCallIndex]['audio_on'] ==
                            1 ||
                            websocketController
                                .liveCallList[myCallIndex]['audio_on']
                                .toString() ==
                                '1' ||
                            websocketController
                                .liveCallList[myCallIndex]['is_audio_on'] ==
                                1 ||
                            websocketController
                                .liveCallList[myCallIndex]['is_audio_on']
                                .toString() ==
                                '1')
                            : true));

                        return message_bottom(
                          onPress: () async {
                            // ✅ This updates Agora local mic + backend + liveCallList
                            // so all users can see this audience is muted/unmuted.
                            await livestreamController
                                .toggleMyAudioFromAnyButton(
                              rtcEngine: widget.rtcEngine,
                            );
                          },
                          color2: Color(0xffffffff).withOpacity(.2),
                          color: Color(0xffffffff).withOpacity(.2),
                          image: audioOn
                              ? 'assets/newaudio/microphone.png'
                              : 'assets/flaticons/mute.png',
                        );
                      }),

                      SizedBox(width: kWeight * 0.015),

                      // ✅ Local speaker off/on button.
                      // Mic mute na, shudhu ei device-e broad-er sob remote voice off/on.
                      message_bottom(
                        onPress: _toggleBroadSpeakerMute,
                        color2: _isBroadSpeakerMuted
                            ? Color(0xffffffff).withOpacity(.2)
                            : Color(0xffffffff).withOpacity(.2),
                        color: _isBroadSpeakerMuted
                            ? Color(0xffffffff).withOpacity(.2)
                            : Color(0xffffffff).withOpacity(.2),
                        image: _isBroadSpeakerMuted
                            ? 'assets/frame/sound-off.png'
                            : 'assets/frame/sound.png',
                      ),

                      SizedBox(width: kWeight * 0.008),

                      widget.streamType == "popular" &&
                          widget.videoPkButton != null &&
                          livestreamController.broadcasterId.value ==
                              authController.userProfile.value.user?.id
                          ? Padding(
                        padding: EdgeInsets.only(right: kWeight * 0.006),
                        child: widget.videoPkButton!,
                      )
                          : const SizedBox.shrink(),

                      buildGiftButton(),
                      SizedBox(width: kWeight * 0.01),
                      widget.streamType == "popular" ||
                          widget.streamType == "multi"
                          ? const SizedBox.shrink()
                          : _buildRealtimeMessageButton(),

                      // ReusableIconButton(
                      //   onPressed: () {
                      //     final liveUrl = 'https://linlive.fr/';
                      //     Share.share(
                      //         '🔴 I\'m live now! Watch here: $liveUrl');
                      //   },
                      //   assetImage: 'assets/icons/share.png',
                      //   imageHeight: kHeight * 0.02,
                      //   backgroundColor:
                      //   Color(0xffffffff).withOpacity(.2),
                      // ),

                      // widget.streamType == "popular" &&
                      //     livestreamController.broadcasterId.value ==
                      //         authController
                      //             .userProfile.value.user!.id
                      //     ? SizedBox.shrink()
                      //     : SizedBox(
                      //   width: kWeight * 0.001,
                      // ),

                      ///----------------- giftSent-------------------
                      EntertainmentToolsWidget(
                        rtcEngine: widget.rtcEngine,
                        streamType: widget.streamType,
                        isBroadcaster:
                        livestreamController.isBroadcaster.value,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  bool get _isCurrentVideoHost {
    if (widget.streamType != 'popular') return false;

    final int myId = authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (myId <= 0) return false;

    final int broadcasterId =
        int.tryParse(livestreamController.broadcasterId.value.toString()) ?? 0;

    if (broadcasterId > 0) {
      return broadcasterId == myId;
    }

    final dynamic broadUser = widget.broadcasterData['user'];
    if (broadUser is Map) {
      final int ownerId =
          int.tryParse((broadUser['id'] ?? broadUser['user_id'] ?? 0).toString()) ??
              0;
      if (ownerId > 0) {
        return ownerId == myId;
      }
    }

    return livestreamController.isBroadcaster.value;
  }

  Widget _buildVideoLiveBottomActions() {
    return Row(
      key: const ValueKey('video-live-compact-actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Existing full More menu.
        EntertainmentToolsWidget(
          rtcEngine: widget.rtcEngine,
          streamType: widget.streamType,
          isBroadcaster: livestreamController.isBroadcaster.value,
        ),

        SizedBox(width: kWeight * 0.008),

        // PK beside More.
        if (_isCurrentVideoHost && widget.videoPkButton != null) ...[
          widget.videoPkButton!,
          SizedBox(width: kWeight * 0.008),
        ],

        // Call beside PK.
        if (_canManageCalls) ...[
          _buildCompactVideoCallButton(),
          SizedBox(width: kWeight * 0.008),
        ],

        // Second More. Filter/Camera/Mute/Sound are inside.
        if (_isCurrentVideoHost) _buildVideoQuickMoreButton(),
      ],
    );
  }

  Widget _buildCompactVideoCallButton() {
    return Obx(() {
      final int pending = websocketController.pendingCall.length;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => showCallBottomSheet(
              context,
              widget.rtcEngine,
            ),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(.16),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.call_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          if (pending > 0)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 17,
                  minHeight: 17,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffF80230),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  pending > 9 ? '9+' : '$pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildVideoQuickMoreButton() {
    return InkWell(
      onTap: _openVideoQuickControlsSheet,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.30),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(.16),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }

  bool _hostAudioIsOn() {
    final int userId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId <= 0) return true;

    final bool hasKnownMute =
    websocketController.audioMutedUserMap.containsKey(userId);

    if (hasKnownMute) {
      return websocketController.audioMutedUserMap[userId] != true;
    }

    if (livestreamController.mute.value == true) {
      return false;
    }

    final int hostCallIndex =
    websocketController.liveCallList.indexWhere((call) {
      if (call is! Map) return false;

      final dynamic user = call['user'];
      final dynamic callerId = call['caller_id'];
      final dynamic callUserId = user is Map ? user['id'] : null;

      return callerId.toString() == userId.toString() ||
          callUserId.toString() == userId.toString();
    });

    if (hostCallIndex == -1) return true;

    final dynamic call = websocketController.liveCallList[hostCallIndex];
    if (call is! Map) return true;

    final dynamic raw = call['audio_on'] ?? call['is_audio_on'];
    if (raw == null) return true;
    if (raw is bool) return raw;
    if (raw is num) return raw.toInt() != 0;

    final String value = raw.toString().trim().toLowerCase();
    return value == '1' ||
        value == 'true' ||
        value == 'yes' ||
        value == 'on' ||
        value == 'enabled';
  }

  Future<void> _toggleHostMicFromQuickMore() async {
    if (!_isCurrentVideoHost) return;

    final int userId =
        authController.userProfile.value.user?.id?.toInt() ?? 0;
    if (userId <= 0) return;

    await livestreamController.toggleSpecificUserAudio(
      userId,
      rtcEngine: widget.rtcEngine,
    );
  }

  Future<void> _openVideoFilterFromQuickMore() async {
    if (!_isCurrentVideoHost || widget.onVideoFilterTap == null) return;

    if (Get.isBottomSheetOpen == true) {
      Get.back();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    widget.onVideoFilterTap?.call();
  }

  Future<void> _flipCameraFromQuickMore() async {
    if (!_isCurrentVideoHost) return;

    try {
      await AgoraService().flipCamera();
    } catch (e) {
      debugPrint('Video quick camera switch failed: $e');
    }
  }

  void _openVideoQuickControlsSheet() {
    if (!_isCurrentVideoHost) return;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          return SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                kWeight * 0.035,
                kHeight * 0.012,
                kWeight * 0.035,
                kHeight * 0.018,
              ),
              decoration: BoxDecoration(
                color: const Color(0xff1D1E22),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(.08),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.30),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  SizedBox(height: kHeight * 0.014),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickVideoControlItem(
                          icon: Icons.auto_awesome_rounded,
                          title: ('Filter').appTr,
                          accent: const Color(0xffff5ca8),
                          onTap: _openVideoFilterFromQuickMore,
                        ),
                      ),
                      Expanded(
                        child: _buildQuickVideoControlItem(
                          icon: Icons.cameraswitch_rounded,
                          title: ('Camera').appTr,
                          accent: const Color(0xff5FD5FF),
                          onTap: () async {
                            await _flipCameraFromQuickMore();
                            if (mounted) {
                              sheetSetState(() {});
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: Obx(() {
                          final bool audioOn = _hostAudioIsOn();
                          return _buildQuickVideoControlItem(
                            icon: audioOn
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            title: audioOn
                                ? ('Mute').appTr
                                : ('Unmute').appTr,
                            accent: audioOn
                                ? const Color(0xffFFCA57)
                                : const Color(0xffFF637D),
                            onTap: () async {
                              await _toggleHostMicFromQuickMore();
                              if (mounted) {
                                sheetSetState(() {});
                              }
                            },
                          );
                        }),
                      ),
                      Expanded(
                        child: _buildQuickVideoControlItem(
                          icon: _isBroadSpeakerMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          title: _isBroadSpeakerMuted
                              ? ('Sound On').appTr
                              : ('Sound Off').appTr,
                          accent: _isBroadSpeakerMuted
                              ? const Color(0xffFF637D)
                              : const Color(0xff70E2A3),
                          onTap: () async {
                            await _toggleBroadSpeakerMute();
                            if (mounted) {
                              sheetSetState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.18),
    );
  }

  Widget _buildQuickVideoControlItem({
    required IconData icon,
    required String title,
    required Color accent,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: () {
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: kWeight * 0.006,
          vertical: kHeight * 0.006,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withOpacity(.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withOpacity(.34),
                ),
              ),
              child: Icon(
                icon,
                color: accent,
                size: 22,
              ),
            ),
            SizedBox(height: kHeight * 0.007),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(.94),
                  fontSize: kHeight * 0.0115,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFilterBottomButton() {
    return InkWell(
      onTap: widget.onVideoFilterTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(.10),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFB7E8),
                    Color(0xFFFF4A9D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            Positioned(
              right: 2,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3D77),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeMessageButton() {
    return StreamBuilder<List<Chat>>(
      stream: _chatController.chats,
      builder: (context, snapshot) {
        final chats = snapshot.data ?? const <Chat>[];
        final int totalUnread = _totalUnreadCount(chats);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            message_bottom(
              onPress: _showRecentMessagesBottomSheet,
              color2: const Color(0xffffffff).withOpacity(.2),
              image: 'assets/audio_live/email.png',
              color: const Color(0xffffffff).withOpacity(.2),
            ),
            if (totalUnread > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF80230),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    totalUnread > 99 ? '99+' : '$totalUnread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  int _totalUnreadCount(List<Chat> chats) {
    final String myUserId = _chatController.currentUserId;
    int total = 0;

    for (final chat in chats) {
      total += chat.unreadCounts[myUserId] ?? 0;
    }

    return total;
  }

  void _showRecentMessagesBottomSheet() {
    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.36,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xffFFF9FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 9, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xffD8CBD3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 10, 8),
                child: StreamBuilder<List<Chat>>(
                  stream: _chatController.chats,
                  builder: (context, snapshot) {
                    final chats = snapshot.data ?? const <Chat>[];
                    final totalUnread = _totalUnreadCount(chats);

                    return Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xffF80230), Color(0xffFD375D)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Messages'.appTr,
                            style: GoogleFonts.poppins(
                              color: const Color(0xff201D27),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (totalUnread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffFFE5EC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              totalUnread > 99 ? '99+' : '$totalUnread',
                              style: const TextStyle(
                                color: Color(0xffF80230),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: Get.back,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xff7A6F77),
                            size: 21,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(0xffF0E7EC)),
              Expanded(
                child: StreamBuilder<List<Chat>>(
                  stream: _chatController.chats,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xffF80230),
                          ),
                        ),
                      );
                    }

                    final chats = [...?snapshot.data];
                    final String myUserId = _chatController.currentUserId;

                    chats.sort((a, b) {
                      final aUnread = a.unreadCounts[myUserId] ?? 0;
                      final bUnread = b.unreadCounts[myUserId] ?? 0;

                      if ((aUnread > 0) != (bUnread > 0)) {
                        return aUnread > 0 ? -1 : 1;
                      }

                      return b.lastMessageTime.compareTo(a.lastMessageTime);
                    });

                    if (chats.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mark_chat_unread_outlined,
                              color: Colors.grey.shade300,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No messages yet'.appTr,
                              style: GoogleFonts.poppins(
                                color: const Color(0xff8C8188),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 7, 10, 12),
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 58,
                        color: Color(0xffF1E8ED),
                      ),
                      itemBuilder: (context, index) {
                        return _buildRecentChatTile(
                          chat: chats[index],
                          myUserId: myUserId,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.34),
    );
  }

  Widget _buildRecentChatTile({required Chat chat, required String myUserId}) {
    final String otherUserId = chat.participants.firstWhere(
          (id) => id != myUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    final String name =
    chat.participantNames[otherUserId]?.trim().isNotEmpty == true
        ? chat.participantNames[otherUserId]!.trim()
        : 'Unknown'.appTr;

    final String image = chat.participantImages[otherUserId] ?? '';
    final int unread = chat.unreadCounts[myUserId] ?? 0;
    final bool hasUnread = unread > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _openChatFromBottomSheet(
          chat: chat,
          otherUserId: otherUserId,
          name: name,
          image: image,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xffF80230), Color(0xffFD89A1)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF80230).withOpacity(.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: image.trim().isEmpty
                          ? _recentChatAvatarFallback(name)
                          : CachedNetworkImage(
                        imageUrl: ImageHelper.getImageUrl(image),
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 120),
                        placeholder: (_, __) =>
                            Container(color: const Color(0xffF7E9EF)),
                        errorWidget: (_, __, ___) =>
                            _recentChatAvatarFallback(name),
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -2,
                      bottom: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xff20C463),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xff201D27),
                        fontSize: 12.5,
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chat.lastMessage.trim().isEmpty
                          ? 'Messages'.appTr
                          : chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: hasUnread
                            ? const Color(0xff5A4D55)
                            : const Color(0xff958990),
                        fontSize: 10,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatRecentChatTime(chat.lastMessageTime),
                    style: const TextStyle(
                      color: Color(0xffA0949B),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(height: 5),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffF80230),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentChatAvatarFallback(String name) {
    final String firstLetter = name.trim().isEmpty
        ? 'U'
        : name.trim()[0].toUpperCase();

    return Container(
      color: const Color(0xffFFF0F4),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Color(0xffF80230),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _openChatFromBottomSheet({
    required Chat chat,
    required String otherUserId,
    required String name,
    required String image,
  }) async {
    Get.back();

    await _chatController.markMessagesAsRead(chat.id);

    if (!mounted) return;

    Get.to(
          () => ChatPage(
        receiverId: otherUserId,
        receiverName: name,
        receiverImage: image,
      ),
      transition: Transition.rightToLeftWithFade,
      duration: const Duration(milliseconds: 280),
    );
  }

  String _formatRecentChatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now'.appTr;
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${time.day}/${time.month}';
  }

  Widget buildGiftButton() {
    if (widget.streamType == 'popular') {
      // popular stream
      if (widget.broadcasterData['user']?['id'] ==
          authController.userProfile.value.user!.id) {
        return Container(); // নিজে হলে কিছু দেখাবে না
      } else {
        return gift_bottom_sheet(
          isbrodcaster: widget.broadcasterData,
          liveType: 'popular',
        ); // অন্য কারো হলে
      }
    } else {
      // popular না হলে
      return gift_bottom_sheet(
        isbrodcaster: widget.broadcasterData,
        liveType: 'audio',
      ); // সবসময় দেখাবে
    }
  }

  Future<void> _acceptCallRequest({
    required int userId,
    required StateSetter sheetSetState,
    required bool Function() isSheetActive,
  }) async {
    if (userId <= 0 || _callRequestsInFlight.contains(userId)) return;
    sheetSetState(() => _callRequestsInFlight.add(userId));
    try {
      final accepted = await livestreamController.tryToAcceptCall(
        streamId: livestreamController.streamId.value,
        userId: userId,
      );
      if (!accepted) {
        Fluttertoast.showToast(msg: 'Call could not be accepted'.appTr);
      }
    } catch (error) {
      debugPrint('Call accept failed: $error');
      Fluttertoast.showToast(msg: 'Call could not be accepted'.appTr);
    } finally {
      _callRequestsInFlight.remove(userId);
      if (mounted && isSheetActive()) sheetSetState(() {});
    }
  }

  Future<void> _rejectCallRequest({
    required int userId,
    required StateSetter sheetSetState,
    required bool Function() isSheetActive,
  }) async {
    if (userId <= 0 || _callRequestsInFlight.contains(userId)) return;
    sheetSetState(() => _callRequestsInFlight.add(userId));
    try {
      final rejected = await livestreamController.tryToRejectCall(
        streamId: livestreamController.streamId.value,
        userId: userId,
      );
      if (!rejected) {
        Fluttertoast.showToast(msg: 'Call could not be rejected'.appTr);
      }
    } catch (error) {
      debugPrint('Call reject failed: $error');
      Fluttertoast.showToast(msg: 'Call could not be rejected'.appTr);
    } finally {
      _callRequestsInFlight.remove(userId);
      if (mounted && isSheetActive()) sheetSetState(() {});
    }
  }

  Widget _buildCallList(
      List callList,
      bool isPending, {
        required StateSetter sheetSetState,
        required bool Function() isSheetActive,
      }) {
    final currentUserId = authController.userProfile.value.user?.id?.toInt();
    final visibleCalls = callList
        .where((raw) {
      final call = _asMap(raw);
      final user = _asMap(call['user'] ?? call['caller']);
      final userId = _safeInt(
        call['caller_id'] ?? call['user_id'] ?? user['id'],
      );
      return userId > 0 && userId != currentUserId;
    })
        .toList(growable: false);
    if (visibleCalls.isEmpty) {
      return Center(
        child: Text(
          'No call requests'.appTr,
          style: const TextStyle(
            color: Color(0xff81747C),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
      itemCount: visibleCalls.length,
      itemBuilder: (context, index) {
        final call = _asMap(visibleCalls[index]);
        final user = _asMap(call['user'] ?? call['caller']);
        final userId = _safeInt(
          call['caller_id'] ?? call['user_id'] ?? user['id'],
        );
        final name = _safeText(user['name'] ?? call['name'] ?? 'User');
        final image = _safeText(user['profile_image'] ?? call['profile_image']);
        final callType = _safeText(
          call['call_type'] ?? call['type'] ?? 'audio',
        ).toLowerCase();
        final status = _safeText(
          call['call_status'] ?? call['status'] ?? 'pending',
        );
        final isLoading = _callRequestsInFlight.contains(userId);
        return Card(
          color: const Color(0xffFAF7F9),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xffEEE5EA)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xffEEE5EA),
              backgroundImage: image.isEmpty
                  ? null
                  : CachedNetworkImageProvider(ImageHelper.getImageUrl(image)),
              child: image.isEmpty ? const Icon(Icons.person_rounded) : null,
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'ID: $userId\n${callType == 'video' || callType == 'popular' ? 'Video' : 'Audio'} • $status',
              style: const TextStyle(color: Color(0xff756A70), fontSize: 11),
            ),
            trailing: isLoading
                ? const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
                : isPending
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check, color: Colors.green),
                  tooltip: 'Accept'.appTr,
                  onPressed: userId <= 0
                      ? null
                      : () => _acceptCallRequest(
                    userId: userId,
                    sheetSetState: sheetSetState,
                    isSheetActive: isSheetActive,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  tooltip: 'Reject'.appTr,
                  onPressed: userId <= 0
                      ? null
                      : () => _rejectCallRequest(
                    userId: userId,
                    sheetSetState: sheetSetState,
                    isSheetActive: isSheetActive,
                  ),
                ),
              ],
            )
                : IconButton(
              icon: Icon(Icons.cancel, color: Colors.redAccent),
              onPressed: userId <= 0
                  ? null
                  : () => _rejectCallRequest(
                userId: userId,
                sheetSetState: sheetSetState,
                isSheetActive: isSheetActive,
              ),
            ),
          ),
        );
      },
    );
  }

  void showCallBottomSheet(BuildContext context, RtcEngine _) {
    if (!_canManageCalls) return;
    var isSheetActive = true;
    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
          final availableHeight =
              MediaQuery.sizeOf(sheetContext).height - bottomInset;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              top: false,
              child: DefaultTabController(
                length: 2,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      height: availableHeight * 0.68,
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 10,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 25),
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TabBar(
                                          labelColor: const Color(0xffF80230),
                                          unselectedLabelColor: const Color(
                                            0xff81747C,
                                          ),
                                          indicator: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            color: const Color(0xffFFF0F4),
                                          ),
                                          tabs: [
                                            Tab(text: ('Pending Calls').appTr),
                                            Tab(text: ('Live Calls').appTr),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: Obx(
                                                () => TabBarView(
                                              children: [
                                                _buildCallList(
                                                  websocketController
                                                      .pendingCall,
                                                  true,
                                                  sheetSetState: sheetSetState,
                                                  isSheetActive: () =>
                                                  isSheetActive,
                                                ),
                                                _buildCallList(
                                                  websocketController
                                                      .liveCallList,
                                                  false,
                                                  sheetSetState: sheetSetState,
                                                  isSheetActive: () =>
                                                  isSheetActive,
                                                ),
                                              ],
                                            ),
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
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    ).whenComplete(() => isSheetActive = false);
  }
}