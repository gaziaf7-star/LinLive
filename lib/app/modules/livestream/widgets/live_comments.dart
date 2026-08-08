import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/color_constants.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../controllers/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LiveCommentsSection extends StatefulWidget {
  final RxMap broadcasterData;
  final String? streamType;

  const LiveCommentsSection({
    Key? key,
    required this.broadcasterData,
    this.streamType,
  }) : super(key: key);

  @override
  State<LiveCommentsSection> createState() => _LiveCommentsSectionState();
}

class _LiveCommentsSectionState extends State<LiveCommentsSection> {
  final WebsocketController websocketController = Get.find();
  final ScrollController _scrollController = ScrollController();

  /// 0 = All, 1 = Message, 2 = Gift
  final RxInt selectedTab = 0.obs;
  final List<Worker> _workers = <Worker>[];

  /// All activity must stay serial in one timeline:
  /// comment -> join/left -> gift -> comment, exactly as they arrive.
  /// Backend sometimes sends missing/equal timestamps, so we keep a stable
  /// local order for every event key and use it as a safe tie-breaker.
  final Map<String, int> _serialOrderMap = <String, int>{};
  int _serialSeed = 0;

  /// Old floating join/left state kept only for backward compatibility with
  /// helper methods. Join/left is now rendered inside the normal serial list.
  final Set<String> _seenJoinLeftToastKeys = <String>{};
  Map<String, dynamic>? _joinLeftToastItem;

  /// Keeps the comment layer self-contained. The parent audio room no longer
  /// needs to rebuild for every comment/gift event. Workers below increment this
  /// version and only this widget rebuilds.
  int _activityVersion = 0;
  Timer? _activityRefreshTimer;
  bool _pendingActivityScroll = false;

  void _markActivityDirty({bool scroll = true}) {
    if (!mounted) return;
    _pendingActivityScroll = _pendingActivityScroll || scroll;

    // commentsList/giftMessagesList can receive dozens of rows during a rapid
    // Lucky combo. Rebuild this timeline at most once per short frame window.
    if (_activityRefreshTimer?.isActive == true) return;
    _activityRefreshTimer = Timer(const Duration(milliseconds: 120), () {
      _activityRefreshTimer = null;
      if (!mounted) return;
      final bool shouldScroll = _pendingActivityScroll;
      _pendingActivityScroll = false;
      setState(() => _activityVersion++);
      if (shouldScroll) _scrollToBottom();
    });
  }

  final String welcomeText =
      'Welcome to Lin Live.. pornographic, minor, vulgar, violent and other illegal content is strictly prohibited in live broadcast room. We maintain 24 hour supervision and if any violation occurs the account will be banned immediately';

  int get _currentStreamId {
    final value = websocketController.streamID.value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _announcementForCurrentRoom() {
    final wsAnnouncement = websocketController.liveRoomAnnouncement.value
        .trim();
    if (wsAnnouncement.isNotEmpty) return wsAnnouncement;

    final b = _asMap(widget.broadcasterData);
    final candidates = [
      b['announcement'],
      b['anousment'],
      b['stream_title'],
      b['livestream'] is Map ? b['livestream']['announcement'] : null,
      b['livestream'] is Map ? b['livestream']['anousment'] : null,
      b['livestreamdata'] is Map ? b['livestreamdata']['announcement'] : null,
      b['livestreamdata'] is Map ? b['livestreamdata']['anousment'] : null,
    ];

    for (final value in candidates) {
      final text = _safeText(value);
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  Map<String, dynamic>? _pinnedAnnouncementItem() {
    final sid = _currentStreamId;
    if (sid == 0) return null;

    final customText = _announcementForCurrentRoom();

    /// ✅ Only one pinned notice will show:
    /// - custom announcement thakle sudhu custom announcement
    /// - custom announcement na thakle sudhu default welcome
    final bool hasCustomAnnouncement = customText.trim().isNotEmpty;
    final text = hasCustomAnnouncement ? customText.trim() : welcomeText;

    if (text.trim().isEmpty) return null;

    return {
      'type': 'system',
      'system_type': hasCustomAnnouncement ? 'announcement' : 'welcome',
      'comment_key': hasCustomAnnouncement
          ? 'announcement_$sid'
          : 'welcome_$sid',
      'livestream_id': sid,
      'user': {
        'id': 0,
        'name': hasCustomAnnouncement ? 'Announcement': 'System',
        'level': 0,
        'profile_image': null,
        'is_online': true,
      },
      'comment': text,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  bool _isAnnouncement(Map item) {
    return _safeText(item['system_type']).toLowerCase() == 'announcement' ||
        _safeText(item['comment_key']).startsWith('announcement_');
  }

  bool _isWelcomeItem(Map item) {
    return _safeText(item['system_type']).toLowerCase() == 'welcome' ||
        _safeText(item['comment_key']).startsWith('welcome_') ||
        _safeText(item['comment']) == welcomeText;
  }

  void _removePinnedNoticesFromScrollableList() {
    /*
    |--------------------------------------------------------------------------
    | IMPORTANT: never mutate commentsList from its own GetX worker
    |--------------------------------------------------------------------------
    | _itemsForTab() already filters announcement/welcome items for rendering.
    | Mutating the same RxList inside ever(commentsList, ...) recursively triggers
    | the worker and caused the observed Stack Overflow during viewer_left events.
    |--------------------------------------------------------------------------
    */
    return;
  }

  void _ensureAnnouncementForCurrentStream() {
    // Announcement/default welcome will be rendered as one pinned/fixed card.
    // Do not keep them inside commentsList, otherwise two notices show.
    _removePinnedNoticesFromScrollableList();
  }

  @override
  void initState() {
    super.initState();

    _ensureWelcomeForCurrentStream();
    _ensureAnnouncementForCurrentStream();
    _markExistingJoinLeftAsSeen();
    _primeSerialOrder();

    _workers.add(
      ever(websocketController.commentsList, (_) {
        // Read-only reaction. Never edit commentsList from this worker.
        _syncSerialOrderFromList(websocketController.commentsList);
        _showLatestJoinLeftToastIfNeeded();
        _markActivityDirty();
      }),
    );

    _workers.add(
      ever(websocketController.giftMessagesList, (_) {
        _syncSerialOrderFromList(websocketController.giftMessagesList);
        _markActivityDirty();
      }),
    );

    _workers.add(
      ever(selectedTab, (_) {
        _markActivityDirty();
      }),
    );

    _workers.add(
      ever(websocketController.liveRoomAnnouncement, (_) {
        // Pinned announcement is computed directly in build().
        _markActivityDirty(scroll: false);
      }),
    );

    _workers.add(
      everAll([
        websocketController.streamID,
        livestreamController.currentPkId,
        livestreamController.pkSenderLivestreamId,
        livestreamController.pkReceiverLivestreamId,
        livestreamController.pkModeActive,
      ], (_) {
        // Room/PK change only updates derived UI; source lists stay untouched.
        _clearOldEntryOnRoomChange();
        _markActivityDirty();
      }),
    );
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    _activityRefreshTimer?.cancel();
    _activityRefreshTimer = null;
    _scrollController.dispose();
    super.dispose();
  }

  void _clearOldEntryOnRoomChange() {
    /// Room change hole ager room-er floating entry thakbe na.
    /// Same room-e auto hide hobe na.
    final item = _joinLeftToastItem;
    if (item == null) return;

    if (!_isForCurrentStream(item)) {
      if (!mounted) return;
      setState(() => _joinLeftToastItem = null);
    }
  }

  void _ensureWelcomeForCurrentStream() {
    /// Default welcome আর custom announcement দুইটা একসাথে show হবে না।
    /// Welcome/Announcement now only render from _pinnedAnnouncementItem().
    _removePinnedNoticesFromScrollableList();
  }

  void _markExistingJoinLeftAsSeen() {
    for (final raw in websocketController.commentsList) {
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);

      if (!_isForCurrentStream(item) || !_isJoinLeft(item)) continue;

      _seenJoinLeftToastKeys.add(_dedupeKey(item));
    }
  }

  void _showLatestJoinLeftToastIfNeeded() {
    // Join/left now show serially inside the comment list, not as floating banner.
    return;
  }

  void _primeSerialOrder() {
    _syncSerialOrderFromList(websocketController.commentsList);
    _syncSerialOrderFromList(websocketController.giftMessagesList);
  }

  void _syncSerialOrderFromList(Iterable<dynamic> rawList) {
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (!_isForCurrentStream(item)) continue;
      if (_isAnnouncement(item) || _isWelcomeItem(item)) continue;
      _rememberSerialOrder(item);
    }
  }

  String _rawSerialKey(Map item) {
    final normalized = _isGift(item) ? _normalizeGiftItem(Map<String, dynamic>.from(item)) : item;
    final user = _asMap(
      normalized['user'] ??
          normalized['sender'] ??
          normalized['viewer'] ??
          normalized['caller'] ??
          normalized['joined_user'] ??
          normalized['join_user'],
    );
    final receiver = _asMap(normalized['receiver']);
    final gift = _asMap(normalized['gift']);

    final stream = _safeText(
      normalized['livestream_id'] ??
          normalized['stream_id'] ??
          normalized['live_stream_id'] ??
          normalized['room_id'],
    );
    final actionType = _safeText(normalized['action_type']);
    final action = _safeText(normalized['action']);
    final type = _safeText(normalized['type']);
    final eventId = _safeText(
      normalized['event_id'] ??
          normalized['comment_key'] ??
          normalized['message_id'] ??
          normalized['id'],
    );

    final userId = _safeText(
      user['id'] ??
          user['user_id'] ??
          normalized['user_id'] ??
          normalized['viewer_id'] ??
          normalized['caller_id'] ??
          normalized['sender_id'],
    );

    final comment = _safeText(normalized['comment']);
    final timestamp = _safeText(
      normalized['timestamp'] ??
          normalized['created_at'] ??
          normalized['updated_at'] ??
          normalized['sent_at'] ??
          normalized['time'],
    );

    if (eventId.isNotEmpty) {
      return '$stream|$type|$actionType|$action|$eventId';
    }

    if (_isGift(normalized)) {
      return '$stream|gift|$userId|${receiver['id']}|${gift['id']}|$timestamp';
    }

    if (_isJoinLeft(normalized)) {
      return '$stream|join_left|$actionType|$action|$userId|$timestamp';
    }

    return '$stream|message|$userId|$comment|$timestamp';
  }

  void _rememberSerialOrder(Map item) {
    final key = _rawSerialKey(item);
    if (key.trim().isEmpty) return;
    _serialOrderMap.putIfAbsent(key, () => ++_serialSeed);
  }

  int _serialOrderOf(Map item) {
    _rememberSerialOrder(item);
    return _serialOrderMap[_rawSerialKey(item)] ?? 0;
  }

  DateTime? _parseEventDate(dynamic value) {
    final raw = _safeText(value);
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  int _eventSortMs(Map item) {
    final date = _parseEventDate(
      item['timestamp'] ??
          item['created_at'] ??
          item['updated_at'] ??
          item['sent_at'] ??
          item['time'],
    );

    if (date != null) return date.millisecondsSinceEpoch;

    /// Missing timestamp hole local arrival order diye serial thakbe.
    /// Large base use korchi jate real server timestamps always first thake.
    return 4102444800000 + _serialOrderOf(item);
  }

  int _compareSerialItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    final timeCompare = _eventSortMs(a).compareTo(_eventSortMs(b));
    if (timeCompare != 0) return timeCompare;
    return _serialOrderOf(a).compareTo(_serialOrderOf(b));
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted || !_scrollController.hasClients) return;

      final max = _scrollController.position.maxScrollExtent;

      if (max <= 0) return;

      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _safeText(dynamic value) => value?.toString().trim() ?? '';


  Future<void> _copyCommentText(String text) async {
    final String cleanText = text.trim();

    if (cleanText.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: cleanText),
    );

    if (!mounted) return;

    Fluttertoast.cancel();

    await Fluttertoast.showToast(
      msg: ('Comment copied').appTr,
    );
  }



  String _normalizeMentionKey(dynamic value) {
    return _safeText(value)
        .replaceAll('@', '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  List<Map<String, dynamic>> _allMentionableUsers(Map<String, dynamic> item) {
    final Map<int, Map<String, dynamic>> unique = <int, Map<String, dynamic>>{};

    void addUser(dynamic raw) {
      final map = _asMap(raw);
      if (map.isEmpty) return;
      final nested = _asMap(
        map['user'] ?? map['viewer'] ?? map['caller'] ?? map['profile'] ?? map['broadcaster'],
      );
      final user = <String, dynamic>{...map, ...nested};
      final id = _toInt(
        user['id'] ??
            user['user_id'] ??
            map['caller_id'] ??
            map['viewer_id'] ??
            map['broadcaster_id'],
      );
      if (id <= 0) return;
      unique[id] = {...?unique[id], ...user, 'id': id};
    }

    addUser(widget.broadcasterData['user'] ?? widget.broadcasterData['broadcaster']);
    addUser(item['user'] ?? item['sender'] ?? item['viewer'] ?? item['caller']);

    for (final raw in websocketController.liveCallList) {
      addUser(raw);
    }
    for (final raw in livestreamController.liveViewerList) {
      addUser(raw);
    }

    return unique.values.toList();
  }

  Map<String, dynamic>? _resolveMentionUser(String mention, Map<String, dynamic> item) {
    final key = _normalizeMentionKey(mention);
    if (key.isEmpty) return null;

    for (final user in _allMentionableUsers(item)) {
      final names = <String>[
        _safeText(user['name']),
        _safeText(user['full_name']),
        _safeText(user['username']),
        _safeText(user['user_id']),
        _safeText(user['id']),
      ].where((e) => e.isNotEmpty).toList();

      for (final name in names) {
        if (_normalizeMentionKey(name) == key) return user;
      }
    }
    return null;
  }

  void _openMentionProfile(Map<String, dynamic> user) {
    final userId = _safeText(user['id'] ?? user['user_id']);
    if (userId.isEmpty) return;
    homeController.liveVisitProfile(userId: userId, seatData: user);
  }

  Widget _professionalCommentText({
    required String comment,
    required Map<String, dynamic> item,
  }) {
    final baseStyle = GoogleFonts.roboto(
      fontSize: kHeight * .017,
      color: Colors.white,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );

    final mentionRegex = RegExp(r'@[^\s@]+');
    final spans = <InlineSpan>[];
    int last = 0;

    for (final match in mentionRegex.allMatches(comment)) {
      if (match.start > last) {
        spans.add(TextSpan(text: comment.substring(last, match.start), style: baseStyle));
      }

      final mentionText = comment.substring(match.start, match.end);
      final mentionedUser = _resolveMentionUser(mentionText, item);

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: mentionedUser == null ? null : () => _openMentionProfile(mentionedUser),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: kAppColor.withOpacity(.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAppColor.withOpacity(.42), width: .55),
              ),
              child: Text(
                mentionText,
                style: GoogleFonts.roboto(
                  fontSize: kHeight * .0162,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      );
      last = match.end;
    }

    if (last < comment.length) {
      spans.add(TextSpan(text: comment.substring(last), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans.isEmpty ? [TextSpan(text: comment, style: baseStyle)] : spans),
      softWrap: true,
    );
  }

  double get _commentCardWidth => kWeight * .72;

  BoxConstraints get _sameCommentCardConstraints =>
      BoxConstraints(minWidth: _commentCardWidth, maxWidth: _commentCardWidth);

  bool _giftValueOk(dynamic value) {
    if (value == null) return false;

    final v = value.toString().trim();

    return v.isNotEmpty && v.toLowerCase() != 'null' && v != '0';
  }

  dynamic _firstOk(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (_giftValueOk(value) || value is Map || value is List) return value;
    }

    return null;
  }

  Map<String, dynamic> _mergeGoodMaps(List<Map<String, dynamic>> maps) {
    final merged = <String, dynamic>{};

    for (final map in maps) {
      map.forEach((key, value) {
        if (_giftValueOk(value) || value is Map || value is List) {
          merged[key.toString()] = value;
        }
      });
    }

    return merged;
  }

  Map<String, dynamic> _userFromAuthOrCache(dynamic userId) {
    final uid = _toInt(userId);

    if (uid <= 0) return <String, dynamic>{};

    try {
      final currentUser = authController.userProfile.value.user;

      if (currentUser != null && _toInt(currentUser.id) == uid) {
        return {
          'id': currentUser.id,
          'user_id': currentUser.userId,
          'name': currentUser.name,
          'level': currentUser.level,
          'profile_image': currentUser.profileImage,
          'level_image': currentUser.levelImage,
        };
      }
    } catch (_) {}

    try {
      for (final raw in websocketController.liveCallList) {
        final item = _asMap(raw);
        final user = _asMap(item['user'] ?? item['caller'] ?? item['viewer']);

        final id = _toInt(
          user['id'] ??
              user['user_id'] ??
              item['caller_id'] ??
              item['user_id'] ??
              item['viewer_id'] ??
              item['id'],
        );

        if (id == uid) return _mergeGoodMaps([item, user]);
      }
    } catch (_) {}

    try {
      for (final raw in livestreamController.liveViewerList) {
        final item = _asMap(raw);
        final user = _asMap(
          item['user'] ?? item['viewer'] ?? item['viewer_data'],
        );

        final id = _toInt(
          user['id'] ??
              user['user_id'] ??
              item['viewer_id'] ??
              item['user_id'] ??
              item['caller_id'] ??
              item['id'],
        );

        if (id == uid) return _mergeGoodMaps([item, user]);
      }
    } catch (_) {}

    final host = _asMap(
      widget.broadcasterData['user'] ?? widget.broadcasterData['broadcaster'],
    );

    final hostId = _toInt(
      host['id'] ?? host['user_id'] ?? widget.broadcasterData['user_id'],
    );

    if (hostId == uid) return host;

    return <String, dynamic>{};
  }

  Map<String, dynamic> _userFromCommentItem(Map<String, dynamic> item) {
    final directUser = _asMap(
      item['user'] ??
          item['viewer'] ??
          item['sender'] ??
          item['caller'] ??
          item['joined_user'] ??
          item['join_user'] ??
          item['data'],
    );

    final dynamic id = directUser['id'] ??
        directUser['user_id'] ??
        item['user_id'] ??
        item['viewer_id'] ??
        item['sender_id'] ??
        item['caller_id'];

    final cached = _userFromAuthOrCache(id);

    return _mergeGoodMaps([cached, directUser]);
  }

  String _cleanMediaPath(dynamic value) {
    final text = _safeText(value);

    if (text.isEmpty || text.toLowerCase() == 'null') return '';

    return text;
  }

  String _levelImagePathOf(Map<String, dynamic> user) {
    return _cleanMediaPath(
      user['level_image'] ??
          user['levelImage'] ??
          user['level_image_url'] ??
          user['levelImageUrl'] ??
          user['level_badge'] ??
          user['levelBadge'],
    );
  }

  String _profileFramePathOf(Map<String, dynamic> user) {
    final directPath = _cleanMediaPath(
      user['profile_frame'] ??
          user['profileFrame'] ??
          user['frame'] ??
          user['frame_image'] ??
          user['frameImage'] ??
          user['avatar_frame'] ??
          user['avatarFrame'] ??
          user['entry_frame'] ??
          user['entryFrame'],
    );

    if (directPath.isNotEmpty) return directPath;

    final history = _asMap(
      user['asset_purchase_histories'] ??
          user['activeFrame'],
    );

    if (history.isEmpty) return '';

    final status = _safeText(history['status']).toLowerCase();

    if (status.isNotEmpty && status != 'active') return '';

    final asset = _asMap(history['asset'] ?? history['asset_data']);

    final framePath = _cleanMediaPath(
      asset['asset'] ??
          asset['image'] ??
          asset['file'] ??
          asset['path'] ??
          asset['url'] ??
          history['asset'] ??
          history['image'] ??
          history['file'] ??
          history['path'] ??
          history['url'],
    );

    return framePath;
  }

  bool _isSvgaPath(String path) => path.toLowerCase().endsWith('.svga');

  Widget _networkImageOrSvga({
    required String path,
    required double height,
    required double width,
    required BoxFit fit,
    Widget? fallback,
  }) {
    final cleanPath = _cleanMediaPath(path);

    if (cleanPath.isEmpty) {
      return fallback ?? const SizedBox.shrink();
    }

    final url = ImageHelper.getImageUrl(cleanPath);

    if (_isSvgaPath(cleanPath)) {
      return SVGAEasyPlayer(
        resUrl: url,
        fit: fit,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, value) => const SizedBox.shrink(),
      errorWidget: (context, value, error) => fallback ?? const SizedBox.shrink(),
    );
  }

  bool get _isPkRunningForComments {
    try {
      final int currentPkId = _toInt(livestreamController.currentPkId.value);
      final int pkSenderStreamId = _toInt(
        livestreamController.pkSenderLivestreamId.value,
      );
      final int pkReceiverStreamId = _toInt(
        livestreamController.pkReceiverLivestreamId.value,
      );

      return livestreamController.pkModeActive.value == true ||
          currentPkId > 0 ||
          pkSenderStreamId > 0 ||
          pkReceiverStreamId > 0;
    } catch (_) {
      return false;
    }
  }

  int get _currentPkIdForComments {
    try {
      return _toInt(livestreamController.currentPkId.value);
    } catch (_) {
      return 0;
    }
  }

  Set<int> get _pkStreamIdsForComments {
    final ids = <int>{};

    try {
      final int current = _toInt(livestreamController.streamId.value);
      final int sender = _toInt(
        livestreamController.pkSenderLivestreamId.value,
      );
      final int receiver = _toInt(
        livestreamController.pkReceiverLivestreamId.value,
      );

      if (current > 0) ids.add(current);
      if (sender > 0) ids.add(sender);
      if (receiver > 0) ids.add(receiver);
    } catch (_) {}

    final int wsStream = _currentStreamId;

    if (wsStream > 0) ids.add(wsStream);

    return ids;
  }

  Set<int> _itemStreamIds(Map item) {
    final ids = <int>{};

    for (final key in [
      'livestream_id',
      'stream_id',
      'live_stream_id',
      'room_id',
      'sender_livestream_id',
      'receiver_livestream_id',
      'opponent_livestream_id',
    ]) {
      final id = _toInt(item[key]);

      if (id > 0) ids.add(id);
    }

    return ids;
  }

  bool _isForCurrentStream(Map item) {
    if (item['comment'] == welcomeText && item['comment_key'] == null) {
      /// Old welcome message from previous version had livestream_id 100.
      /// Do not show it in new rooms, otherwise old audio comments mix in video.
      return false;
    }

    final sid = _currentStreamId;
    final itemStreamId =
        item['livestream_id'] ??
            item['stream_id'] ??
            item['live_stream_id'] ??
            item['room_id'];

    /// Only current welcome can pass without stream id.
    if (itemStreamId == null) {
      return item['comment_key'] == 'welcome_$sid';
    }

    final int eventStreamId = _toInt(itemStreamId);

    /// Normal live: only current stream will show.
    if (sid > 0 && eventStreamId == sid) {
      return true;
    }

    /// PK live: both livestream rooms must show in the same comment box.
    final bool pkRunning = _isPkRunningForComments;

    if (!pkRunning) {
      return sid == 0;
    }

    final pkStreams = _pkStreamIdsForComments;
    final itemStreams = _itemStreamIds(item);

    if (itemStreams.any(pkStreams.contains)) {
      return true;
    }

    /// If backend sends pk_id but not both stream ids, still allow the current PK.
    final int itemPkId = _toInt(item['pk_id']);
    final int currentPkId = _currentPkIdForComments;

    if (itemPkId > 0 && currentPkId > 0 && itemPkId == currentPkId) {
      return true;
    }

    return false;
  }

  bool _isJoinLeft(Map item) {
    final comment = _safeText(item['comment']).toLowerCase();
    final systemType = _safeText(item['system_type']).toLowerCase();
    final actionType = _safeText(item['action_type']).toLowerCase();
    final action = _safeText(item['action']).toLowerCase();

    return comment == 'has joined the stream' ||
        comment == 'left the room' ||
        systemType == 'viewer_join' ||
        systemType == 'viewer_joined' ||
        systemType == 'viewer_left' ||
        systemType == 'viewer_leave' ||
        actionType == 'viewer_joined' ||
        actionType == 'viewer_left' ||
        action == 'viewer_add' ||
        action == 'viewer_remove';
  }

  bool _isValidUser(dynamic user) {
    if (user is! Map) return false;

    final name = _safeText(user['name']);

    return name.isNotEmpty && name.toLowerCase() != 'null';
  }

  bool _isGift(Map item) {
    final type = _safeText(item['type']).toLowerCase();
    final actionType = _safeText(item['action_type']).toLowerCase();

    return type == 'gift' ||
        type == 'lucky_gift' ||
        type == 'lucky_gift_card' ||
        actionType == 'gift_sent' ||
        actionType == 'multi_live_gift_sent' ||
        actionType == 'pk_gift_sent' ||
        actionType == 'pk_gift_received' ||
        actionType == 'lucky_gift_result' ||
        item['is_lucky_gift'] == true ||
        item['gift'] != null ||
        item['gifter'] != null;
  }


  bool _timelineTruthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value.toInt() == 1;
    final String text = _safeText(value).toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'win' ||
        text == 'winner';
  }

  bool _isLuckyTimelineGift(Map<String, dynamic> item) {
    final Map<String, dynamic> merged = <String, dynamic>{
      ..._asMap(item['data']),
      ..._asMap(item['gift_data']),
      ...item,
    };
    final Map<String, dynamic> gift = _asMap(
      merged['gift'] ?? merged['gift_info'] ?? merged['asset'],
    );

    final String action = _safeText(
      merged['action_type'] ?? merged['type'],
    ).toLowerCase();
    final String category = _safeText(
      gift['category'] ??
          gift['gift_category'] ??
          gift['gift_type'] ??
          merged['gift_category'] ??
          merged['gift_type'],
    ).toLowerCase();
    final String name = _safeText(
      gift['name'] ?? gift['gift_name'] ?? merged['gift_name'],
    ).toLowerCase();

    return action.contains('lucky') ||
        category.contains('lucky') ||
        name.contains('lucky') ||
        _timelineTruthy(merged['is_lucky_gift']) ||
        _timelineTruthy(gift['is_lucky_gift']) ||
        _timelineTruthy(gift['is_lucky']) ||
        merged['lucky_result'] is Map ||
        merged['lucky_results'] is List;
  }

  int _timelineWinAmount(Map<String, dynamic> item) {
    final Map<String, dynamic> merged = <String, dynamic>{
      ..._asMap(item['data']),
      ..._asMap(item['gift_data']),
      ...item,
    };
    final Map<String, dynamic> result = _asMap(merged['lucky_result']);
    return _toInt(
      merged['win_amount'] ??
          merged['back_coin'] ??
          merged['win_coin'] ??
          merged['bonus_coin'] ??
          result['win_amount'] ??
          result['back_coin'] ??
          result['win_coin'] ??
          result['bonus_coin'],
    );
  }

  bool _shouldShowGiftTimelineItem(Map<String, dynamic> item) {
    if (!_isGift(item)) return false;
    if (!_isLuckyTimelineGift(item)) return true;

    final Map<String, dynamic> result = _asMap(item['lucky_result']);
    final int winAmount = _timelineWinAmount(item);
    final bool isWin = _timelineTruthy(item['is_win']) ||
        _timelineTruthy(result['is_win']) ||
        winAmount > 0;

    // Lucky send/loss rows stay out of comments. Only a real confirmed win is
    // visible. This also protects the UI if an older backend still sends every
    // Lucky tap into commentsList or giftMessagesList.
    return isWin && winAmount > 0;
  }

  Map<String, dynamic> _normalizeGiftItem(Map<String, dynamic> item) {
    /// Keep root + nested data together. Some events have full sender at root,
    /// while gift fields arrive inside data/gift_data.
    final normalized = <String, dynamic>{
      ..._asMap(item['data']),
      ..._asMap(item['gift_data']),
      ..._asMap(item['gift_info']),
      ...item,
    };

    Map<String, dynamic> normalizeUser({
      required String role,
      required dynamic fallbackId,
    }) {
      final direct = _asMap(
        _firstOk(
          normalized,
          role == 'sender'
              ? ['sender', 'gifter', 'from_user', 'user']
              : [
            'receiver',
            'receiver_user',
            'to_user',
            'host',
            'broadcaster',
            'livestream_user',
          ],
        ),
      );

      final id =
          direct['id'] ??
              direct['user_id'] ??
              fallbackId ??
              _firstOk(
                normalized,
                role == 'sender'
                    ? ['sender_id', 'gifter_id', 'user_id']
                    : ['receiver_id', 'to_user_id', 'host_id', 'broadcaster_id'],
              );

      final cached = _userFromAuthOrCache(id);

      return _mergeGoodMaps([
        cached,
        direct,
        {
          'id': id,
          'user_id': direct['user_id'] ?? id,
          'name': _firstOk(
            normalized,
            role == 'sender'
                ? ['sender_name', 'gifter_name', 'user_name', 'name']
                : [
              'receiver_name',
              'to_user_name',
              'host_name',
              'broadcaster_name',
            ],
          ),
          'level': _firstOk(
            normalized,
            role == 'sender'
                ? ['sender_level', 'gifter_level', 'level']
                : [
              'receiver_level',
              'to_user_level',
              'host_level',
              'broadcaster_level',
            ],
          ),
          'profile_image': _firstOk(
            normalized,
            role == 'sender'
                ? [
              'sender_profile_image',
              'gifter_profile_image',
              'profile_image',
              'avatar',
            ]
                : [
              'receiver_profile_image',
              'to_user_profile_image',
              'host_profile_image',
              'broadcaster_profile_image',
            ],
          ),
          'level_image': _firstOk(
            normalized,
            role == 'sender'
                ? [
              'sender_level_image',
              'gifter_level_image',
              'level_image',
              'levelImage',
            ]
                : [
              'receiver_level_image',
              'to_user_level_image',
              'host_level_image',
              'broadcaster_level_image',
            ],
          ),
          'asset_purchase_history': _firstOk(
            normalized,
            role == 'sender'
                ? [
              'sender_asset_purchase_history',
              'gifter_asset_purchase_history',
              'asset_purchase_history',
              'assetPurchaseHistory',
            ]
                : [
              'receiver_asset_purchase_history',
              'to_user_asset_purchase_history',
              'host_asset_purchase_history',
              'broadcaster_asset_purchase_history',
            ],
          ),
        },
      ]);
    }

    final senderId =
        _firstOk(normalized, ['sender_id', 'gifter_id', 'user_id']) ??
            _asMap(
              normalized['sender'] ?? normalized['gifter'] ?? normalized['user'],
            )['id'];

    final receiverId =
        _firstOk(normalized, [
          'receiver_id',
          'to_user_id',
          'host_id',
          'broadcaster_id',
        ]) ??
            _asMap(
              normalized['receiver'] ??
                  normalized['receiver_user'] ??
                  normalized['to_user'] ??
                  normalized['host'] ??
                  normalized['broadcaster'],
            )['id'];

    final sender = normalizeUser(role: 'sender', fallbackId: senderId);
    var receiver = normalizeUser(role: 'receiver', fallbackId: receiverId);

    if ((_toInt(receiver['id'] ?? receiver['user_id']) <= 0 ||
        !_giftValueOk(receiver['profile_image'])) &&
        _toInt(receiverId) > 0 &&
        _toInt(receiverId) == _toInt(sender['id'] ?? sender['user_id'])) {
      receiver = Map<String, dynamic>.from(sender);
    }

    final directGift = _asMap(
      _firstOk(normalized, ['gift', 'gift_data', 'gift_info', 'asset']),
    );

    final gift = _mergeGoodMaps([
      directGift,
      {
        'id':
        directGift['id'] ??
            _firstOk(normalized, ['gift_id', 'asset_id', 'id']),
        'name':
        directGift['name'] ??
            _firstOk(normalized, ['gift_name', 'asset_name', 'name']),
        'image':
        directGift['image'] ??
            directGift['gift_image'] ??
            directGift['show_image'] ??
            _firstOk(normalized, [
              'gift_image',
              'image',
              'show_image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'gift_image':
        directGift['gift_image'] ??
            directGift['image'] ??
            _firstOk(normalized, [
              'gift_image',
              'image',
              'show_image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'show_image':
        directGift['show_image'] ??
            directGift['image'] ??
            _firstOk(normalized, [
              'show_image',
              'gift_image',
              'image',
              'thumbnail',
              'icon',
              'svga',
            ]),
        'coin':
        directGift['coin'] ??
            directGift['coins'] ??
            _firstOk(normalized, ['gift_coin', 'coin', 'coins', 'total_coins']),
      },
    ]);

    normalized['type'] = normalized['type'] ?? 'gift';
    normalized['sender'] = sender;
    normalized['user'] = sender;
    normalized['receiver'] = receiver;
    normalized['gift'] = gift;
    normalized['livestream_id'] =
        normalized['livestream_id'] ?? normalized['stream_id'];
    normalized['timestamp'] =
        normalized['timestamp'] ??
            normalized['created_at'] ??
            normalized['updated_at'] ??
            normalized['sent_at'] ??
            normalized['time'];
    normalized['event_id'] =
        normalized['event_id'] ??
            normalized['id'] ??
            '${normalized['livestream_id']}_${sender['id']}_${receiver['id']}_${gift['id']}_${normalized['timestamp']}';

    return normalized;
  }

  bool _isRealMessage(Map item) {
    if (_isGift(item)) return false;
    if (_isJoinLeft(item)) return false;
    if (item['comment'] == welcomeText) return false;

    final comment = _safeText(item['comment']);

    return comment.isNotEmpty;
  }

  DateTime _timeOf(Map item) {
    return DateTime.fromMillisecondsSinceEpoch(_eventSortMs(item));
  }

  String _dedupeKey(Map<String, dynamic> item) {
    final normalized = _isGift(item) ? _normalizeGiftItem(item) : item;

    final type = _safeText(normalized['type']);
    final systemType = _safeText(normalized['system_type']);
    final actionType = _safeText(normalized['action_type']);
    final action = _safeText(normalized['action']);
    final user = _asMap(
      normalized['user'] ?? normalized['sender'] ?? normalized['viewer'],
    );
    final gift = _asMap(normalized['gift']);
    final receiver = _asMap(normalized['receiver']);
    final userId = _safeText(
      user['id'] ??
          user['user_id'] ??
          normalized['user_id'] ??
          normalized['viewer_id'],
    );
    final comment = _safeText(normalized['comment']);
    final eventId = _safeText(
      normalized['event_id'] ?? normalized['comment_key'],
    );
    final stream = _safeText(
      normalized['livestream_id'] ?? normalized['stream_id'],
    );

    if (_isGift(normalized)) {
      if (eventId.isNotEmpty) return '$stream|gift|$eventId';

      return '$stream|gift|$userId|${receiver['id']}|${gift['id']}|${normalized['timestamp']}';
    }

    if (_isJoinLeft(normalized)) {
      /// Backend can send viewer_joined + live_comment + system event together.
      /// Same user/action inside 2.5 seconds will show only one item, but later
      /// leave -> rejoin will still show again because timestamp bucket changes.
      final time = _timeOf(normalized);

      final bucket = time.millisecondsSinceEpoch <= 0
          ? 0
          : time.millisecondsSinceEpoch ~/ 2500;

      final isLeft =
          comment.toLowerCase().contains('left') ||
              systemType.toLowerCase().contains('left') ||
              action.toLowerCase().contains('remove') ||
              actionType.toLowerCase().contains('left');

      return '$stream|join_left|${isLeft ? 'left' : 'join'}|$userId|$bucket';
    }

    if (eventId.isNotEmpty) return '$stream|$type|$systemType|$eventId';

    return '$stream|msg|$userId|$comment|${normalized['timestamp']}';
  }

  List<Map<String, dynamic>> _dedupe(List<Map<String, dynamic>> input) {
    final seen = <String>{};
    final output = <Map<String, dynamic>>[];

    for (final item in input) {
      final key = _dedupeKey(item);

      if (seen.contains(key)) continue;

      seen.add(key);
      output.add(item);
    }

    return output;
  }

  List<Map<String, dynamic>> _itemsForTab() {
    final comments = websocketController.commentsList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where(_isForCurrentStream)
        .where((item) => !_isAnnouncement(item) && !_isWelcomeItem(item))
        .where((item) {
      /// Join/left, normal comments, and welcome must stay in serial list.
      /// Only invalid join payloads are removed.
      if (_isJoinLeft(item) && !_isValidUser(_userFromCommentItem(item))) {
        return false;
      }
      return true;
    })
        .toList();

    /// Some normal gift events arrive in commentsList instead of giftMessagesList,
    /// especially older backend payloads with action_type=gift_sent. Normalize both.
    final giftFromComments = comments
        .where(_isGift)
        .map(_normalizeGiftItem)
        .where(_shouldShowGiftTimelineItem)
        .toList();

    /// Comments list should keep join/left in All tab, but remove gift payloads
    /// because gifts are normalized separately from both sources.
    final serialComments = comments.where((item) => !_isGift(item)).toList();

    final gifts = <Map<String, dynamic>>[
      ...giftFromComments,
      ...websocketController.giftMessagesList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(_isForCurrentStream)
          .where(_isGift)
          .map(_normalizeGiftItem)
          .where(_shouldShowGiftTimelineItem),
    ];

    if (selectedTab.value == 1) {
      final messages = _dedupe(serialComments.where(_isRealMessage).toList());
      for (final item in messages) {
        _rememberSerialOrder(item);
      }
      messages.sort(_compareSerialItems);
      return messages;
    }

    if (selectedTab.value == 2) {
      final onlyGifts = _dedupe(gifts);
      for (final item in onlyGifts) {
        _rememberSerialOrder(item);
      }
      onlyGifts.sort(_compareSerialItems);
      return onlyGifts;
    }

    /// All tab serial order:
    /// welcome/comment/join-left/gift/lucky gift -> one by one by timestamp.
    final all = _dedupe(<Map<String, dynamic>>[...serialComments, ...gifts]);
    for (final item in all) {
      _rememberSerialOrder(item);
    }

    all.sort(_compareSerialItems);

    return all;
  }

  @override
  Widget build(BuildContext context) {
    // Read this local version so worker-driven updates rebuild only this
    // LiveCommentsSection, not the whole audio room page.
    _activityVersion;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tabHeader(),
          SizedBox(height: kHeight * 0.006),
          Expanded(child: _commentListBody()),
        ],
      ),
    );
  }

  Widget _commentListBody() {
    final items = _itemsForTab();
    final pinnedAnnouncement = selectedTab.value == 2
        ? null
        : _pinnedAnnouncementItem();

    return Padding(
      padding: const EdgeInsets.only(left: 7.0),
      child: Column(
        children: [
          if (pinnedAnnouncement != null) _announcementItem(pinnedAnnouncement),
          Expanded(
            child: items.isEmpty
                ? Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: kWeight * .02,
                  top: 8,
                ),
                child: Text(
                  selectedTab.value == 2
                      ? ('No gifts yet').appTr: selectedTab.value == 1
                      ? ('No messages yet').appTr: ('No activity yet').appTr,
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: kHeight * .012,
                  ),
                ),
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.zero,
              controller: _scrollController,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                if (_isGift(item)) return _giftItem(item);
                if (item['comment'] == welcomeText) return _welcomeItem(item);
                if (_isJoinLeft(item)) return _joinLeftItem(item);

                return _messageItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Obx(
            () => Padding(
          padding: EdgeInsets.only(left: kWeight * 0.02),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tabButton(('All').appTr, 0),
              SizedBox(width: kWeight * .035),
              _tabButton(('Message').appTr, 1),
              SizedBox(width: kWeight * .035),
              _tabButton(('Gift').appTr, 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String title, int index) {
    final active = selectedTab.value == index;

    return GestureDetector(
      onTap: () {
        selectedTab.value = index;
        _scrollToBottom();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              color: active ? Colors.white : Colors.white70,
              fontSize: kHeight * .015,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2,
            width: active ? kWeight * .045 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinLeftItem(Map<String, dynamic> item) {
    final user = _userFromCommentItem(item);

    if (!_isValidUser(user)) return const SizedBox.shrink();

    final comment = _safeText(item['comment']).toLowerCase();
    final systemType = _safeText(item['system_type']).toLowerCase();
    final actionType = _safeText(item['action_type']).toLowerCase();
    final action = _safeText(item['action']).toLowerCase();

    final bool isLeft =
        comment.contains('left') ||
            systemType.contains('left') ||
            systemType.contains('leave') ||
            actionType.contains('left') ||
            action.contains('remove');

    final String name = _safeText(user['name']).isEmpty
        ? 'User': _safeText(user['name']);

    final Color accent = isLeft
        ? const Color(0xffff6b6b)
        : const Color(0xff45f39b);
    final Color accentTwo = isLeft
        ? const Color(0xffffb15c)
        : const Color(0xff32d7ff);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: _sameCommentCardConstraints,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7, right: 6),
          child: FadeInUp(
            duration: const Duration(milliseconds: 260),
            from: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(.54),
                    accent.withOpacity(.22),
                    Colors.black.withOpacity(.28),
                  ],
                ),
                border: Border.all(
                  color: accent.withOpacity(.62),
                  width: .8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _avatar(user, size: kHeight * .034),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          height: kHeight * .015,
                          width: kHeight * .015,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [accent, accentTwo],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(.88),
                              width: .8,
                            ),
                          ),
                          child: Icon(
                            isLeft
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            color: Colors.white,
                            size: kHeight * .0095,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: kWeight * .02),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: kHeight * .0128,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            SizedBox(width: kWeight * .012),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: accent.withOpacity(.22),
                                border: Border.all(
                                  color: accent.withOpacity(.55),
                                  width: .6,
                                ),
                              ),
                              child: Text(
                                isLeft ? ('LEFT').appTr: ('JOINED').appTr,
                                maxLines: 1,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: kHeight * .0086,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .35,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isLeft
                              ? ('left the live room').appTr: ('entered the live room').appTr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: Colors.white.withOpacity(.78),
                            fontSize: kHeight * .0105,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _announcementItem(Map<String, dynamic> item) {
    final comment = _safeText(item['comment']);
    if (comment.isEmpty) return const SizedBox.shrink();

    /// Same width + same left position as normal comments.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: _sameCommentCardConstraints,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7, right: 6),
          child: FadeIn(
            duration: const Duration(milliseconds: 350),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: kAppColor1.withOpacity(.95),
                  width: .75,
                ),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withOpacity(.38),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: kHeight * .016,
                  ),
                  SizedBox(width: kWeight * .018),
                  Expanded(
                    child: Text(
                      comment,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: GoogleFonts.roboto(
                        fontSize: kHeight * .0114,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeItem(Map<String, dynamic> item) {
    if (widget.broadcasterData['user']?['id'] ==
        authController.userProfile.value.user!.id) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: FadeIn(
        duration: const Duration(milliseconds: 350),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: _sameCommentCardConstraints,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: kAppColor, width: 1.4),
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withOpacity(.35),
              ),
              child: Text(
                item['comment'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: GoogleFonts.roboto(
                  fontSize: kHeight * .011,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageItem(Map<String, dynamic> item) {
    final user = _userFromCommentItem(item);

    if (!_isValidUser(user)) return const SizedBox.shrink();

    final comment = _safeText(item['comment']);

    if (comment.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: _sameCommentCardConstraints,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7, right: 6),
          child: FadeIn(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(.55),
                  width: .75,
                ),
                color: Colors.black.withOpacity(.18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(user, size: kHeight * .038),
                  SizedBox(width: kWeight * .018),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _nameLevelRow(user),
                        const SizedBox(height: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => _copyCommentText(comment),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: _professionalCommentText(
                              comment: comment,
                              item: item,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _giftItem(Map<String, dynamic> item) {
    final normalizedItem = _normalizeGiftItem(item);

    final sender = _asMap(normalizedItem['sender']);
    final receiver = _asMap(normalizedItem['receiver']);
    final gift = _asMap(normalizedItem['gift']);

    if (!_isValidUser(sender)) return const SizedBox.shrink();

    final String giftName = (gift['name'] ?? item['gift_name'] ?? ('Gift').appTr)
        .toString();

    final String receiverName =
    (receiver['name'] ?? item['receiver_name'] ?? ('User').appTr).toString();

    final String itemType = _safeText(normalizedItem['type']).toLowerCase();

    final bool isLucky =
        normalizedItem['is_lucky_gift'] == true ||
            itemType == 'lucky_gift' ||
            itemType == 'lucky_gift_card';

    if (isLucky) {
      final double rawMultiplier =
          double.tryParse(
            '${normalizedItem['multiplier'] ?? normalizedItem['gun'] ?? normalizedItem['x'] ?? 0}',
          ) ??
              0;

      // gift_sent event-e lucky result ekhono na ashle multiplier 0 thake.
      // Ei incomplete event-er jonno 0 gun / empty Lucky card dekhabo na.
      // Backend theke valid lucky_result/lucky_results aslei card render hobe.
      if (rawMultiplier <= 0) {
        return const SizedBox.shrink();
      }

      final double multiplier = rawMultiplier;

      final int winAmount =
          int.tryParse(
            '${normalizedItem['win_amount'] ?? normalizedItem['back_coin'] ?? normalizedItem['win_coin'] ?? 0}',
          ) ??
              0;

      final bool isBig =
          normalizedItem['is_big_win'] == true ||
              normalizedItem['is_jackpot'] == true ||
              multiplier >= 100;

      String coinText() {
        if (winAmount >= 1000000) {
          return '${(winAmount / 1000000).toStringAsFixed(1)}M';
        }

        if (winAmount >= 1000) {
          return '${(winAmount / 1000).toStringAsFixed(1)}K';
        }

        return '$winAmount';
      }

      String luckyCoinBadgeText() {
        return winAmount > 0 ? coinText() : '0';
      }

      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: _sameCommentCardConstraints,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 6),
            child: FadeInLeft(
              duration: const Duration(milliseconds: 320),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isBig
                        ? [
                      const Color(0xff2a1468).withOpacity(.96),
                      const Color(0xff7736ff).withOpacity(.96),
                      const Color(0xffffb938).withOpacity(.96),
                    ]
                        : [
                      const Color(0xff075f43).withOpacity(.96),
                      const Color(0xff10bc70).withOpacity(.96),
                      const Color(0xff1ddd89).withOpacity(.96),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(.70),
                    width: .9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      (isBig
                          ? const Color(0xff8e47ff)
                          : const Color(0xff16ce7d))
                          .withOpacity(.28),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _avatar(sender, size: kHeight * .041),
                    SizedBox(width: kWeight * .018),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _nameLevelRow(sender)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.35),
                                    width: .6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/diamond-removebg-preview.png',
                                      height: kHeight * .0155,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(
                                            Icons.monetization_on_rounded,
                                            color: const Color(0xfffff08a),
                                            size: kHeight * .0155,
                                          ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      luckyCoinBadgeText(),
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xfffff08a),
                                        fontSize: kHeight * .015,
                                        fontWeight: FontWeight.w900,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  winAmount > 0
                                      ? ('Won +${coinText()} coins').appTr: ('Better luck next time').appTr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    fontSize: kHeight * .012,
                                    color: Colors.white.withOpacity(.96),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: kWeight * .014),
                              _giftIcon(gift),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Normal gift one-line design:
    /// sender profile -> Send to -> receiver profile -> gift icon/name.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: _sameCommentCardConstraints,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7, right: 6),
          child: FadeIn(
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(.26),
                    Colors.deepPurple.withOpacity(.4),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatar(sender, size: kHeight * .036),
                  SizedBox(width: kWeight * .010),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: kWeight * .008),
                    child: Text(
                      ('Send to').appTr,
                      maxLines: 1,
                      style: GoogleFonts.roboto(
                        fontSize: kHeight * .012,
                        color: Colors.white.withOpacity(.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: kWeight * .008),
                  _avatar(receiver, size: kHeight * .032),
                  SizedBox(width: kWeight * .008),
                  Expanded(
                    flex: 22,
                    child: Text(
                      receiverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: kHeight * .0108,
                        color: Colors.white.withOpacity(.96),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: kWeight * .008),
                  _giftIcon(gift),
                  SizedBox(width: kWeight * .006),
                  Expanded(
                    flex: 20,
                    child: Text(
                      giftName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: kHeight * .0108,
                        color: const Color(0xffffdf6d),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> user, {required double size}) {
    final img = _cleanMediaPath(user['profile_image'] ?? user['avatar']);
    final framePath = _profileFramePathOf(user);
    final bool hasUserFrame = framePath.isNotEmpty;
    final double boxSize = hasUserFrame ? size * 1.85 : size;
    final double frameSize = hasUserFrame ? size * 1.85 : size;

    return InkWell(
      onTap: () {
        final userId = _safeText(user['id'] ?? user['user_id']);

        if (userId.isNotEmpty) {
          homeController.liveVisitProfile(userId: userId, seatData: user);
        }
      },
      child: SizedBox(
        height: kHeight*0.04,
        width:kHeight*0.04,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              height: size,
              width: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: img.isEmpty
                    ? Image.asset(
                  'assets/images/support_user.png',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                )
                    : CachedNetworkImage(
                  imageUrl: ImageHelper.getImageUrl(img),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholderFadeInDuration: Duration.zero,
                  placeholder: (context, value) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/images/support_user.png',
                    width: kHeight*0.08,
                    height: kHeight*0.08,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            if (hasUserFrame)
              SizedBox(
                height: kHeight*0.05,
                width: kHeight*0.05,
                child: _networkImageOrSvga(
                  path: framePath,
                  height: frameSize,
                  width: frameSize,
                  fit: BoxFit.cover,
                  fallback: const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _levelBadge(Map<String, dynamic> user) {
    final level = (user['level'] ?? 0).toString();
    final levelImagePath = _levelImagePathOf(user);
    final double badgeHeight = kHeight * 0.027;
    final double badgeWidth = kHeight * 0.047;

    return SizedBox(
      height: kHeight*0.022,
      width: kWeight*0.2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          levelImagePath.isEmpty
              ? SVGAEasyPlayer(
            assetsName: 'assets/svga/Level/level_0_to_9_bg.svga',
            fit: BoxFit.cover,
          )
              : SizedBox(
            height: kHeight * 0.06,
            width: kHeight * 0.06,
            child: _networkImageOrSvga(
              path: levelImagePath,
              height: kHeight * 0.06,
              width: kHeight * 0.06,
              fit: BoxFit.cover,
              fallback: SVGAEasyPlayer(
                assetsName: 'assets/svga/Level/level_0_to_9_bg.svga',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            right: kHeight * 0.02,
            child: Text(
              level,
              style: GoogleFonts.roboto(
                fontSize: kHeight * 0.013,
                fontWeight: FontWeight.bold,
                color: Color(0xfffbcaab),
                shadows: const [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black45,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameLevelRow(Map<String, dynamic> user) {
    final name = (user['name'] ?? ('User').appTr).toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ShaderMask(
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xfffff3a3),
                  Color(0xffffc400),
                  Color(0xffff6a00),
                  Color(0xffff2d55),
                ],
              ).createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              );
            },
            blendMode: BlendMode.srcIn,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: kHeight * .019,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(width: kWeight * .010),
        _levelBadge(user),
      ],
    );
  }

  Widget _giftIcon(Map<String, dynamic> gift) {
    final raw =
        gift['show_image'] ??
            gift['image'] ??
            gift['gift_image'] ??
            gift['icon'] ??
            gift['svga'] ??
            gift['gift_svga'];

    if (raw == null || raw.toString().isEmpty || raw.toString() == 'null') {
      return Icon(
        Icons.card_giftcard,
        color: Colors.amber,
        size: kHeight * .028,
      );
    }

    final rawText = raw.toString();
    final url = ImageHelper.getImageUrl(rawText);

    /// Flutter Image/CachedNetworkImage cannot decode .svga as a bitmap.
    /// Show a clean gift icon here; full SVGA animation is handled elsewhere.
    if (rawText.toLowerCase().endsWith('.svga')) {
      return Icon(
        Icons.card_giftcard,
        color: Colors.amber,
        size: kHeight * .030,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: kHeight * .032,
      width: kHeight * .032,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) =>
          Icon(Icons.card_giftcard, color: Colors.amber, size: kHeight * .028),
    );
  }
}
