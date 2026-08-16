import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/livestream_controller.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../socket/websocket_controller.dart';
class RedPacketLiveOverlay extends StatefulWidget {
  final int livestreamId;

  const RedPacketLiveOverlay({
    super.key,
    required this.livestreamId,
  });

  @override
  State<RedPacketLiveOverlay> createState() => _RedPacketLiveOverlayState();
}

class _RedPacketLiveOverlayState extends State<RedPacketLiveOverlay> {
  final WebsocketController websocketController = Get.find<WebsocketController>();
  final LivestreamController liveController = Get.find<LivestreamController>();

  Timer? _timer;
  Worker? _packetWorker;
  int _remainingSeconds = 0;
  String _activePacketId = '';
  final Set<String> _autoDialogShownIds = <String>{};

  @override
  void initState() {
    super.initState();
    _packetWorker = ever(
      websocketController.currentRedPacket,
          (packet) => _startCountdown(Map<String, dynamic>.from(packet as Map)),
    );

    /// ✅ Global banner click can pass the Lucky Bag through route arguments.
    /// Seed it immediately so the target room does not wait for another API/WS.
    try {
      final args = Get.arguments;
      final routePacket = args is Map ? args['global_lucky_bag_packet'] : null;
      if (routePacket is Map) {
        final seeded = Map<String, dynamic>.from(routePacket);
        if (_isForCurrentStream(seeded)) {
          final fastOpenAfter = _fastestOpenSecondsFromPackets([seeded]);
          seeded['open_after_seconds'] = fastOpenAfter;
          seeded['unlock_after_seconds'] = fastOpenAfter;
          websocketController.currentRedPacket.value = seeded;
          websocketController.redPacketVisible.value = true;
          websocketController.currentRedPacket.refresh();
        }
      }
    } catch (_) {}

    if (websocketController.currentRedPacket.isNotEmpty) {
      final seeded = Map<String, dynamic>.from(websocketController.currentRedPacket);
      if (_isForCurrentStream(seeded)) {
        _startCountdown(seeded);
      }
    }

    /// ✅ If user enters the live room AFTER a Lucky Bag was sent,
    /// fetch active packets so they can still see countdown/open/reward.
    Future.microtask(_loadActiveLuckyBagForRoom);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _packetWorker?.dispose();
    super.dispose();
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }

  bool _isForCurrentStream(Map<String, dynamic> packet) {
    final streamId = _safeInt(packet['livestream_id'] ?? packet['stream_id']);
    return streamId == 0 || streamId == widget.livestreamId;
  }

  int _packetId(Map<String, dynamic> packet) {
    return _safeInt(packet['id'] ?? packet['red_packet_id'] ?? packet['packet_id']);
  }

  bool _samePacket(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = _packetId(a);
    final bId = _packetId(b);
    if (aId > 0 && bId > 0) return aId == bId;
    return false;
  }

  int _fastestOpenSecondsFromPackets(List<Map<String, dynamic>> packets) {
    final candidates = <int>[];
    for (final packet in packets) {
      candidates.addAll([
        _safeInt(packet['unlock_after_seconds']),
        _safeInt(packet['open_after_seconds']),
        _safeInt(packet['unlock_after']),
        _safeInt(packet['open_after']),
      ]);
    }
    final positive = candidates.where((e) => e > 0).toList()..sort();
    return positive.isNotEmpty ? positive.first : 30;
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  int _openAfterSeconds(Map<String, dynamic> packet) {
    /// Backend can send both open_after_seconds=30 and unlock_after_seconds=3.
    /// Use the smallest positive value so the OPEN button matches backend unlock
    /// and does not make users wait until the packet is already gone.
    final candidates = <int>[
      _safeInt(packet['unlock_after_seconds']),
      _safeInt(packet['open_after_seconds']),
      _safeInt(packet['unlock_after']),
      _safeInt(packet['open_after']),
    ].where((e) => e > 0).toList();

    if (candidates.isEmpty) return 30;
    candidates.sort();
    return candidates.first;
  }

  int _createdAtMs(Map<String, dynamic> packet) {
    final fromPacket = _parseDate(packet['created_at'] ?? packet['sent_at']);
    if (fromPacket != null) return fromPacket.millisecondsSinceEpoch;

    final eventMs = _safeInt(packet['event_received_at_ms']);
    if (eventMs > 0) return eventMs;

    return DateTime.now().millisecondsSinceEpoch;
  }

  int _expireAtMs(Map<String, dynamic> packet) {
    final expiresAt = _parseDate(packet['expires_at']);
    if (expiresAt != null) return expiresAt.millisecondsSinceEpoch;

    final expiresIn = _safeInt(packet['expires_in_seconds']);
    if (expiresIn > 0) {
      return DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000);
    }

    final duration = _safeInt(packet['duration_seconds'] ?? packet['expire_seconds']);
    final safeDuration = duration <= 0 ? 120 : duration;
    return _createdAtMs(packet) + safeDuration * 1000;
  }

  int _openRemainingSeconds(Map<String, dynamic> packet) {
    final openAt = _createdAtMs(packet) + _openAfterSeconds(packet) * 1000;
    final left = ((openAt - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left < 0 ? 0 : left;
  }

  int _expireRemainingSeconds(Map<String, dynamic> packet) {
    final left = ((_expireAtMs(packet) - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left < 0 ? 0 : left;
  }

  bool _packetActive(Map<String, dynamic> packet) {
    final status = (packet['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'expired' || status == 'refunded' || status == 'closed' || status == 'completed') {
      return false;
    }
    if (_safeInt(packet['remaining_quantity']) == 0 && packet['remaining_quantity'] != null) {
      return false;
    }
    return _expireRemainingSeconds(packet) > 0;
  }

  Future<void> _loadActiveLuckyBagForRoom() async {
    if (widget.livestreamId <= 0) return;

    try {
      final packets = await liveController.getLivestreamRedPackets(
        livestreamId: widget.livestreamId,
        status: 'active',
        perPage: 20,
      );

      if (!mounted || packets.isEmpty) return;

      final active = packets.firstWhere(
            (packet) => _isForCurrentStream(packet) && _packetActive(packet),
        orElse: () => <String, dynamic>{},
      );

      if (active.isEmpty) return;

      final current = Map<String, dynamic>.from(websocketController.currentRedPacket);
      final bool sameAsSeeded = current.isNotEmpty && _samePacket(current, active);
      final merged = <String, dynamic>{
        if (sameAsSeeded) ...current,
        ...active,
      };

      // If banner/WS packet had unlock_after_seconds=3 but the active-list API
      // later returns open_after_seconds=30, keep the faster value. This is why
      // the packet was entering the room but not showing/opening immediately.
      final int fastOpenAfter = _fastestOpenSecondsFromPackets([
        if (sameAsSeeded) current,
        active,
      ]);
      merged['open_after_seconds'] = fastOpenAfter;
      merged['unlock_after_seconds'] = fastOpenAfter;
      merged['event_received_at_ms'] = sameAsSeeded
          ? (current['event_received_at_ms'] ?? merged['event_received_at_ms'] ?? DateTime.now().millisecondsSinceEpoch)
          : (merged['event_received_at_ms'] ?? DateTime.now().millisecondsSinceEpoch);

      websocketController.currentRedPacket.value = Map<String, dynamic>.from(merged);
      websocketController.redPacketVisible.value = true;
      websocketController.currentRedPacket.refresh();

      _startCountdown(merged);
    } catch (e) {
      debugPrint('❌ load active Lucky Bag failed => $e');
    }
  }

  void _startCountdown(Map<String, dynamic> packet) {
    _timer?.cancel();
    // ✅ FIX: previously just packet['id'].toString() — if the id ends up
    // 0/missing for more than one red packet in a row (the underlying bug
    // fixed in red_packet_event_handler.dart's _normalizeRedPacket),
    // multiple different packets collided on the same "0" key here. Since
    // _autoDialogShownIds (below) tracks which packet id already had its
    // auto-open dialog shown, that collision made every packet AFTER the
    // first one look like "already shown" and silently skip its own
    // auto-open — only reachable afterward through a manual tap on the top
    // card. Combining the id with a per-event timestamp keeps this key
    // unique per actual packet even if the id itself is still wrong; once
    // the id is fixed, this key naturally becomes id-based again in
    // practice since the timestamp differs per send anyway.
    final String rawId = (packet['id'] ?? packet['red_packet_id'] ?? packet['packet_id'] ?? '').toString();
    final String eventStamp =
        (packet['event_received_at_ms'] ??
            packet['created_at'] ??
            packet['open_after_seconds'])
            ?.toString() ??
            '';
    _activePacketId = '${rawId}_$eventStamp';

    if (packet.isEmpty || rawId.isEmpty || !_isForCurrentStream(packet)) {
      if (mounted) setState(() => _remainingSeconds = 0);
      return;
    }

    final int serverUnlockSeconds = _openAfterSeconds(packet);
    packet['open_after_seconds'] = serverUnlockSeconds;
    packet['unlock_after_seconds'] = serverUnlockSeconds;

    void tick() {
      final int expireLeft = _expireRemainingSeconds(packet);
      if (expireLeft <= 0) {
        if (mounted) setState(() => _remainingSeconds = 0);
        _timer?.cancel();
        return;
      }

      final int openLeft = _openRemainingSeconds(packet);
      if (mounted) setState(() => _remainingSeconds = openLeft);

      /// ✅ Dialog appears in the last 5 seconds BEFORE OPEN, not before expiry.
      if (openLeft <= 5 && !_autoDialogShownIds.contains(_activePacketId)) {
        _autoDialogShownIds.add(_activePacketId);
        _openLuckyBagDialog(packet, autoOpen: true);
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _openLuckyBagDialog(Map<String, dynamic> packet, {bool autoOpen = false}) {
    if (Get.isDialogOpen == true && autoOpen) return;
    Get.dialog(
      RedPacketOpenDialog(
        packet: packet,
        initialRemainingSeconds: _remainingSeconds,
      ),
      barrierDismissible: false,
    );
  }

  void _openDetails(Map<String, dynamic> packet) {
    Get.bottomSheet(
      RedPacketDetailsSheet(packet: packet),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!websocketController.redPacketVisible.value ||
          websocketController.currentRedPacket.isEmpty) {
        return const SizedBox.shrink();
      }

      final packet = Map<String, dynamic>.from(websocketController.currentRedPacket);
      if (!_isForCurrentStream(packet)) return const SizedBox.shrink();

      return Positioned(
        left: 8,
        top: MediaQuery.of(context).padding.top + 96,
        child: RedPacketTopCard(
          packet: packet,
          seconds: _remainingSeconds,
          onTap: () {
            if (_remainingSeconds <= 0) {
              _openDetails(packet);
              return;
            }
            _openLuckyBagDialog(packet);
          },
        ),
      );
    });
  }
}

class RedPacketTopCard extends StatelessWidget {
  static const String _audioLuckyBagAsset = 'assets/flaticons/audioredpoket .png';

  final Map<String, dynamic> packet;
  final int seconds;
  final VoidCallback onTap;

  const RedPacketTopCard({
    super.key,
    required this.packet,
    required this.seconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool countdownFinished = seconds <= 0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 62,
              width: 62,
              child: Image.asset(
                _audioLuckyBagAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/frame/redpoket5secoundbackgroundimage .png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const Text(
                    '🧧',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 42),
                  ),
                ),
              ),
            ),

            /// Countdown image-er niche thakbe, but ekto upore tule dewa holo.
            /// Time sesh hole OPEN text show hobe na, sudhu image thakbe.
            if (!countdownFinished)
              Transform.translate(
                // seconds text ekto nicher dike namano holo
                offset: const Offset(0, -2),
                child: Text(
                  ('${seconds}s').appTr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 5,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class RedPacketOpenDialog extends StatefulWidget {
  final Map<String, dynamic> packet;
  final int initialRemainingSeconds;

  const RedPacketOpenDialog({
    super.key,
    required this.packet,
    required this.initialRemainingSeconds,
  });

  @override
  State<RedPacketOpenDialog> createState() => _RedPacketOpenDialogState();
}

class _RedPacketOpenDialogState extends State<RedPacketOpenDialog> {
  static const String _openDialogBgAsset =
      'assets/frame/redpoket5secoundbackgroundimage .png';

  final LivestreamController liveController = Get.find<LivestreamController>();
  final WebsocketController websocketController = Get.find<WebsocketController>();
  Timer? _timer;
  late int _remaining;
  bool _loading = false;

  // ✅ WORKAROUND for a confirmed BACKEND bug: the red_packet_sent websocket
  // broadcast sends id:0 (confirmed via full field dump — every other field
  // is present and correct, only 'id' itself is the literal value 0, sent
  // by the server). _loadActiveLuckyBagForRoom (in the parent overlay)
  // separately fetches the same active packet from the REST list endpoint
  // shortly after, which does carry the real id. This watches for that
  // REST-loaded version to arrive and adopts its id if our own is still 0
  // — a stopgap so Open works while the real fix (server should send the
  // actual id in the websocket event) is pending.
  int? _resolvedPacketId;
  Worker? _idSyncWorker;

  int get _effectivePacketId =>
      _resolvedPacketId ??
          _safeInt(
            widget.packet['id'] ??
                widget.packet['red_packet_id'] ??
                widget.packet['packet_id'],
          );

  void _startIdSyncWorker() {
    if (_effectivePacketId > 0) return; // already have a real id, nothing to fix
    final int myLivestreamId = _safeInt(
      widget.packet['livestream_id'] ?? widget.packet['stream_id'],
    );
    _idSyncWorker = ever(websocketController.currentRedPacket, (dynamic raw) {
      if (!mounted || _effectivePacketId > 0) {
        _idSyncWorker?.dispose();
        return;
      }
      final incoming = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final int incomingLivestreamId = _safeInt(
        incoming['livestream_id'] ?? incoming['stream_id'],
      );
      if (myLivestreamId > 0 && incomingLivestreamId != myLivestreamId) return;
      final int incomingId = _safeInt(
        incoming['id'] ?? incoming['red_packet_id'] ?? incoming['packet_id'],
      );
      if (incomingId > 0) {
        debugPrint(
          '🧧 [RED_PACKET] resolved real id from REST-loaded packet => id=$incomingId (was 0 from websocket event)',
        );
        setState(() => _resolvedPacketId = incomingId);
        _idSyncWorker?.dispose();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _remaining = widget.initialRemainingSeconds < 0 ? 0 : widget.initialRemainingSeconds;
    debugPrint(
      '🧧 [RED_PACKET] dialog opened => packetId=${widget.packet['id'] ?? widget.packet['red_packet_id'] ?? widget.packet['packet_id']} '
          'initialRemainingSeconds=${widget.initialRemainingSeconds} '
          'resolved_remaining=$_remaining',
    );
    // ✅ DEBUG: dump every key in the packet map, one line per field, so the
    // real field name the server uses for the packet's own id can be found
    // directly from logcat — id/red_packet_id/packet_id have all come back
    // empty so far, so whatever field actually holds it must be something
    // else, and this will show it plainly instead of guessing more names.
    debugPrint('🧧 [RED_PACKET] ==== full packet field dump (${widget.packet.length} keys) ====');
    widget.packet.forEach((key, value) {
      debugPrint('🧧 [RED_PACKET] field: $key = $value (${value?.runtimeType})');
    });
    debugPrint('🧧 [RED_PACKET] ==== end packet field dump ====');
    _startIdSyncWorker();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        debugPrint('🧧 [RED_PACKET] countdown reached 0, timer stopped, OPEN should now be tappable');
        _timer?.cancel();
        return;
      }
      if (mounted) setState(() => _remaining--);
      debugPrint('🧧 [RED_PACKET] countdown tick => remaining=$_remaining mounted=$mounted');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idSyncWorker?.dispose();
    super.dispose();
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _senderName() {
    final sender = _map(widget.packet['sender']);
    final name = sender['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'User': name;
  }

  String _senderImage() {
    final sender = _map(widget.packet['sender']);
    final image = sender['profile_image'] ?? sender['image_url'] ?? sender['avatar'] ?? '';
    return ImageHelper.getImageUrl(image?.toString() ?? '');
  }

  int _collectAmount(Map<String, dynamic> data) {
    if (data['already_collected_without_amount'] == true) return -1;
    final redPacket = _map(data['red_packet']);
    final collection = _map(data['collection'] ?? data['my_collection']);
    final values = <dynamic>[
      data['collected_amount'],
      data['amount_collected'],
      data['my_collection_amount'],
      collection['amount_collected'],
      collection['collected_amount'],
      collection['amount'],
      redPacket['my_collection_amount'],
      redPacket['amount_collected'],
      redPacket['collected_amount'],
    ];

    for (final value in values) {
      final amount = _safeInt(value);
      if (amount > 0) return amount;
    }
    return 0;
  }

  Map<String, dynamic> _resultPacket(Map<String, dynamic> data) {
    final redPacket = _map(data['red_packet']);
    final collection = _map(data['collection'] ?? data['my_collection']);
    return <String, dynamic>{
      ...widget.packet,
      if (redPacket.isNotEmpty) ...redPacket,
      if (collection.isNotEmpty) 'my_collection': collection,
    };
  }

  Future<void> _open() async {
    debugPrint(
      '🧧 [RED_PACKET] OPEN tapped => loading=$_loading remaining=$_remaining '
          'effectivePacketId=$_effectivePacketId (raw widget.packet[id]=${widget.packet['id']})',
    );
    if (_loading || _remaining > 0) {
      debugPrint('🧧 [RED_PACKET] OPEN blocked by guard => loading=$_loading remaining=$_remaining');
      return;
    }
    // ✅ CONFIRMED via full field dump: the server's red_packet_sent
    // websocket broadcast itself sends id:0 — a backend bug, not a field-
    // name mismatch (every other field, including red_packet_open_at_ms,
    // expires_in_seconds etc., is present and correct; only 'id' is
    // literally 0). _effectivePacketId includes the REST-resolved-id
    // workaround (see _startIdSyncWorker) so Open still works once that
    // arrives, without waiting on a backend fix.
    final int packetId = _effectivePacketId;
    if (packetId <= 0) {
      debugPrint('🧧 [RED_PACKET] OPEN blocked => invalid packetId=$packetId, still waiting on real id from server/REST');
      Fluttertoast.showToast(
        msg: ('Still loading this Lucky Bag, please try again in a moment.').appTr,
      );
      return;
    }

    // Loading spinner show korbo na. User OPEN text ei dekhbe, API silently run hobe.
    setState(() => _loading = true);
    debugPrint('🧧 [RED_PACKET] calling collectRedPacketData(packetId=$packetId)...');
    final data = await liveController.collectRedPacketData(packetId);
    debugPrint('🧧 [RED_PACKET] collectRedPacketData returned => data=$data');
    if (!mounted) return;
    setState(() => _loading = false);

    // ✅ FIX: previously this just returned silently on failure — the user
    // tapped Open and nothing visibly happened at all, no error, no coin,
    // no explanation. Now a failure is at least shown, and the dialog stays
    // open so the user can retry instead of the packet appearing to vanish.
    if (data == null) {
      debugPrint('🧧 [RED_PACKET] OPEN failed => collectRedPacketData returned null, showing error toast');
      Fluttertoast.showToast(
        msg: ('Unable to open the red packet. Please try again.').appTr,
      );
      return;
    }

    final amount = _collectAmount(data);
    final resultPacket = _resultPacket(data);
    debugPrint('🧧 [RED_PACKET] OPEN success => amount=$amount resultPacket=$resultPacket');

    Get.back();
    Get.dialog(
      RedPacketResultDialog(
        packet: resultPacket,
        amount: amount,
        collectionData: data,
      ),
      barrierDismissible: true,
    );
  }

  Widget _background() {
    return Image.asset(
      _openDialogBgAsset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Color(0xffff3b16),
              Color(0xffed1b00),
              Color(0xffff5c1f),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xffffd95a), width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String image = _senderImage();
    final bool canOpen = _remaining <= 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 312,
            height: 432,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _background()),

                Positioned(
                  top: 28,
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xffffe16a),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      backgroundImage: image.isNotEmpty ? CachedNetworkImageProvider(image) : null,
                      child: image.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                  ),
                ),

                Positioned(
                  top: 102,
                  left: 34,
                  right: 34,
                  child: Text(
                    _senderName(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.merriweather(
                      color: const Color(0xfffff0a8),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                Positioned(
                  top: 136,
                  left: 26,
                  right: 26,
                  child: Text(
                    widget.packet['message']?.toString() ?? ('Sent you a Lucky Bag').appTr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                    ),
                  ),
                ),

                /// White/blank middle area te seconds/OPEN show hobe.
                Positioned(
                  left: 84,
                  right: 84,
                  top: kHeight*0.3,
                  child: GestureDetector(
                    onTap: canOpen ? _open : null,
                    child: Container(
                      height: 104,
                      alignment: Alignment.center,
                      color: Colors.transparent,
                      child: Text(
                        canOpen ? ('OPEN').appTr: '$_remaining',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xffd73300),
                          fontSize: canOpen ? 28 : 45,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 34,
                  child: Text(
                    canOpen
                        ? ('Tap OPEN to get your coins').appTr: ('The Lucky Bag will open in ${_remaining}s').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(.20),
                border: Border.all(color: Colors.white.withOpacity(.7)),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}


class RedPacketResultDialog extends StatelessWidget {
  static const String _resultBgAsset =
      'assets/flaticons/coinrewordluckybag.png';

  final Map<String, dynamic> packet;
  final int amount;
  final Map<String, dynamic> collectionData;

  const RedPacketResultDialog({
    super.key,
    required this.packet,
    required this.amount,
    required this.collectionData,
  });

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _detailsPacket() {
    final redPacket = _map(collectionData['red_packet']);
    final collection = _map(collectionData['collection'] ?? collectionData['my_collection']);
    return <String, dynamic>{
      ...packet,
      if (redPacket.isNotEmpty) ...redPacket,
      if (collection.isNotEmpty) 'my_collection': collection,
    };
  }

  Widget _background() {
    return Image.asset(
      _resultBgAsset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [
              Color(0xffffb739),
              Color(0xffff4516),
              Color(0xffff2f0a),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsPacket = _detailsPacket();
    final bool knownAmount = amount > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 310,
            height: 420,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _background()),

                if (!knownAmount)
                  Positioned(
                    top: 90,
                    left: 28,
                    right: 28,
                    child: Text(
                      ('Already collected').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xff5a1d00),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                Positioned(
                  left: 64,
                  right: 64,
                  top: 165,
                  height: 128,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🪙', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 4),
                      Text(
                        knownAmount ? '$amount' : ('Collected').appTr,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xffe51f00),
                          fontSize: knownAmount ? 28 : 21,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 26,
                  child: GestureDetector(
                    onTap: () {
                      Get.back();
                      Get.bottomSheet(
                        RedPacketDetailsSheet(packet: detailsPacket),
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                      );
                    },
                    child: Text(
                      ('Check the details >').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(.22),
                border: Border.all(color: Colors.white.withOpacity(.7)),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}


class RedPacketDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> packet;

  const RedPacketDetailsSheet({
    super.key,
    required this.packet,
  });

  @override
  State<RedPacketDetailsSheet> createState() => _RedPacketDetailsSheetState();
}

class _RedPacketDetailsSheetState extends State<RedPacketDetailsSheet> {
  final LivestreamController liveController = Get.find<LivestreamController>();
  bool loading = false;
  Map<String, dynamic> packet = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    packet = Map<String, dynamic>.from(widget.packet);
    _loadLatest();
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _collections() {
    final raw = packet['collections'] ?? packet['collectors'] ?? packet['collection_list'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    /// If latest details API does not return the full list yet, show at least
    /// current user's collection from the collect response.
    final mine = _map(packet['my_collection'] ?? packet['collection']);
    if (mine.isNotEmpty) return <Map<String, dynamic>>[mine];

    final bool alreadyMine = packet['already_collected_without_amount'] == true ||
        packet['collected_by_me'] == true ||
        packet['collected_by_me']?.toString() == '1';
    if (alreadyMine) {
      try {
        final dynamic authUser = liveController.authController.userProfile.value.user;
        final userMap = <String, dynamic>{
          'id': liveController.authController.userProfile.value.user?.id,
          'user_id': liveController.authController.userProfile.value.user?.id,
          'name': (authUser as dynamic).name,
          'profile_image': (authUser as dynamic).profileImage,
        };
        return <Map<String, dynamic>>[
          {
            'user': userMap,
            'amount_collected': packet['my_collection_amount'] ??
                packet['collected_amount'] ??
                packet['amount_collected'],
            'created_at': packet['collected_at'] ?? packet['updated_at'] ?? '',
            'already_collected_without_amount': packet['already_collected_without_amount'],
          }
        ];
      } catch (_) {
        return <Map<String, dynamic>>[
          {
            'user': {'name': 'You'},
            'amount_collected': packet['my_collection_amount'] ??
                packet['collected_amount'] ??
                packet['amount_collected'],
            'already_collected_without_amount': packet['already_collected_without_amount'],
          }
        ];
      }
    }

    return <Map<String, dynamic>>[];
  }

  Future<void> _loadLatest() async {
    final int livestreamId = _safeInt(packet['livestream_id'] ?? packet['stream_id'] ?? liveController.streamId.value);
    final int packetId = _safeInt(packet['id'] ?? packet['red_packet_id'] ?? packet['packet_id']);
    if (livestreamId <= 0 || packetId <= 0) return;

    setState(() => loading = true);
    final packets = await liveController.getLivestreamRedPackets(
      livestreamId: livestreamId,
      status: 'all',
      perPage: 20,
    );
    if (!mounted) return;

    final found = packets.firstWhere(
          (e) => _safeInt(e['id'] ?? e['red_packet_id'] ?? e['packet_id']) == packetId,
      orElse: () => packet,
    );

    setState(() {
      final latest = Map<String, dynamic>.from(found);
      packet = <String, dynamic>{
        ...packet,
        ...latest,
        if (packet['my_collection'] != null) 'my_collection': packet['my_collection'],
        if (packet['collection'] != null) 'collection': packet['collection'],
        if (packet['already_collected_without_amount'] == true)
          'already_collected_without_amount': true,
      };
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = _safeInt(packet['amount']);
    final remain = _safeInt(packet['remaining_amount']);
    final quantity = _safeInt(packet['quantity']);
    final remainQty = _safeInt(packet['remaining_quantity']);
    final collected = amount - remain;
    final collectedCount = packet['collected_count'] != null
        ? _safeInt(packet['collected_count'])
        : quantity - remainQty;
    final sender = _map(packet['sender']);
    final collections = _collections();

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * .86,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xffff3d17), Color(0xffff6b1f)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          ('Details').appTr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 28),
                    ],
                  ),
                  const SizedBox(height: 22),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xffffe16a),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: (sender['profile_image'] ?? sender['image_url']) != null
                          ? CachedNetworkImageProvider(ImageHelper.getImageUrl((sender['profile_image'] ?? sender['image_url']).toString()))
                          : null,
                      child: (sender['profile_image'] ?? sender['image_url']) == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    sender['name']?.toString() ?? ('Lucky Bag').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.merriweather(
                      color: const Color(0xfffff0a8),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xfffff7d9),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                ('$collectedCount/$quantity have been received, a total of $collected/$amount coins.').appTr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff565656),
                ),
              ),
            ),
            Expanded(
              child: loading && collections.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : collections.isEmpty
                  ? Center(
                child: Text(
                  ('No one has collected yet').appTr,
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
                  : ListView.separated(
                itemCount: collections.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final item = collections[index];
                  final collector = _map(item['collector'] ?? item['user']);
                  final name = collector['name']?.toString() ?? 'User';
                  final collectorId = (collector['user_id'] ??
                      collector['id'] ??
                      item['collector_id'] ??
                      item['user_id'] ??
                      '')
                      .toString();
                  final image = ImageHelper.getImageUrl(
                    (collector['profile_image'] ?? collector['image_url'] ?? '').toString(),
                  );
                  final coin = _safeInt(item['amount_collected'] ?? item['collected_amount'] ?? item['amount']);
                  final bool unknownCoin = item['already_collected_without_amount'] == true && coin <= 0;
                  final time = (item['created_at'] ?? item['collected_at'] ?? item['time'] ?? '').toString();

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 29,
                      backgroundColor: Colors.blueGrey.shade100,
                      backgroundImage: image.isNotEmpty ? CachedNetworkImageProvider(image) : null,
                      child: image.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : ('U').appTr) : null,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (collectorId.isNotEmpty)
                          Text(
                            ('ID: $collectorId').appTr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff777777),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (time.isNotEmpty)
                          Text(
                            time.length > 16 ? time.substring(0, 16).replaceAll('T', ' ') : time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: Text(
                      unknownCoin ? ('Collected').appTr: '🪙 $coin',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Place this widget in Home/BottomNav root Stack to show global Lucky Bag banner.
/// Example:
/// GlobalRedPacketBanner(onOpenLive: (livestreamId, packet) { /* open live room */ })
class GlobalRedPacketBanner extends StatelessWidget {
  final void Function(int livestreamId, Map<String, dynamic> packet)? onOpenLive;

  const GlobalRedPacketBanner({
    super.key,
    this.onOpenLive,
  });

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final WebsocketController websocketController = Get.find<WebsocketController>();

    return Obx(() {
      if (!websocketController.globalRedPacketVisible.value ||
          websocketController.globalCurrentRedPacket.isEmpty) {
        return const SizedBox.shrink();
      }

      final packet = Map<String, dynamic>.from(websocketController.globalCurrentRedPacket);
      final sender = _map(packet['sender']);
      final livestreamId = _safeInt(packet['livestream_id'] ?? packet['stream_id']);
      final senderName = sender['name']?.toString() ?? 'Someone';

      return Positioned(
        left: 12,
        right: 12,
        top: MediaQuery.of(context).padding.top + 10,
        child: GestureDetector(
          onTap: () {
            if (livestreamId <= 0) {
              Fluttertoast.showToast(msg: ('Live room not found').appTr);
              return;
            }
            if (onOpenLive != null) {
              onOpenLive!(livestreamId, packet);
            } else {
              Fluttertoast.showToast(msg: ('Tap to join Lucky Bag live room').appTr);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xffff3c17), Color(0xffffaa20)],
              ),
              border: Border.all(color: const Color(0xffffe16a), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🧧', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ('$senderName sent a Lucky Bag!').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        ('Tap to join the live room').appTr,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(.90),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      );
    });
  }
}

