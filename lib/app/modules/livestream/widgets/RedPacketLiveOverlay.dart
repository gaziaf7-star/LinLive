import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
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
        seeded['snapshot_received_at_ms'] ??=
            seeded['event_received_at_ms'] ??
                DateTime.now().millisecondsSinceEpoch;
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

  int _snapshotReceivedAtMs(Map<String, dynamic> packet) {
    final int snapshotMs = _safeInt(
      packet['snapshot_received_at_ms'] ??
          packet['api_received_at_ms'] ??
          packet['event_received_at_ms'],
    );

    if (snapshotMs > 0) return snapshotMs;
    return DateTime.now().millisecondsSinceEpoch;
  }

  int _packetDurationSeconds(Map<String, dynamic> packet) {
    final int directDuration = _safeInt(
      packet['duration_seconds'] ??
          packet['expire_seconds'] ??
          packet['lifetime_seconds'],
    );
    if (directDuration > 0) return directDuration;

    // created_at and expires_at can be timezone-less, but their difference is
    // still safe and identical on every device.
    final DateTime? createdAt = _parseDate(
      packet['created_at'] ?? packet['sent_at'],
    );
    final DateTime? expiresAt = _parseDate(packet['expires_at']);

    if (createdAt != null && expiresAt != null) {
      final int seconds = expiresAt.difference(createdAt).inSeconds;
      if (seconds > 0) return seconds;
    }

    final int expiresIn = _safeInt(packet['expires_in_seconds']);
    if (expiresIn > 0) {
      return expiresIn > 120 ? expiresIn : 120;
    }

    return 120;
  }

  int _snapshotElapsedSeconds(Map<String, dynamic> packet) {
    final int expiresIn = _safeInt(packet['expires_in_seconds']);
    if (expiresIn <= 0) return 0;

    final int duration = _packetDurationSeconds(packet);
    return (duration - expiresIn).clamp(0, duration).toInt();
  }

  int _elapsedSinceSnapshotSeconds(Map<String, dynamic> packet) {
    final int elapsedMs =
        DateTime.now().millisecondsSinceEpoch - _snapshotReceivedAtMs(packet);

    if (elapsedMs <= 0) return 0;
    return (elapsedMs / 1000).floor();
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
    final DateTime? fromPacket = _parseDate(
      packet['created_at'] ?? packet['sent_at'],
    );
    if (fromPacket != null) return fromPacket.millisecondsSinceEpoch;

    final int eventMs = _safeInt(packet['event_received_at_ms']);
    if (eventMs > 0) return eventMs;

    return _snapshotReceivedAtMs(packet);
  }

  int _expireAtMs(Map<String, dynamic> packet) {
    final int expiresIn = _safeInt(packet['expires_in_seconds']);
    if (expiresIn > 0) {
      return _snapshotReceivedAtMs(packet) + (expiresIn * 1000);
    }

    final DateTime? expiresAt = _parseDate(packet['expires_at']);
    if (expiresAt != null) return expiresAt.millisecondsSinceEpoch;

    return _createdAtMs(packet) + (_packetDurationSeconds(packet) * 1000);
  }

  int _openRemainingSeconds(Map<String, dynamic> packet) {
    final int explicitRemaining = _safeInt(
      packet['open_remaining_seconds'] ??
          packet['remaining_open_seconds'] ??
          packet['seconds_until_open'] ??
          packet['unlock_in_seconds'],
    );

    if (explicitRemaining > 0) {
      final int left =
          explicitRemaining - _elapsedSinceSnapshotSeconds(packet);
      return left < 0 ? 0 : left;
    }

    final int openAfter = _openAfterSeconds(packet);
    final int elapsedBeforeSnapshot = _snapshotElapsedSeconds(packet);
    final int openLeftAtSnapshot =
    (openAfter - elapsedBeforeSnapshot).clamp(0, openAfter).toInt();
    final int left =
        openLeftAtSnapshot - _elapsedSinceSnapshotSeconds(packet);

    return left < 0 ? 0 : left;
  }

  int _expireRemainingSeconds(Map<String, dynamic> packet) {
    final int expiresIn = _safeInt(packet['expires_in_seconds']);
    if (expiresIn > 0) {
      final int left = expiresIn - _elapsedSinceSnapshotSeconds(packet);
      return left < 0 ? 0 : left;
    }

    final int left =
    ((_expireAtMs(packet) - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil();
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

  bool _canCurrentUserCollect(Map<String, dynamic> packet) {
    if (!_packetActive(packet)) return false;

    final bool alreadyCollected =
        _truthy(packet['collected_by_me']) ||
            _safeInt(packet['my_collection_amount']) > 0;

    if (alreadyCollected) return false;

    if (packet.containsKey('can_collect')) {
      return _truthy(packet['can_collect']);
    }

    return _safeInt(packet['remaining_quantity']) > 0;
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
      final int apiReceivedAtMs = DateTime.now().millisecondsSinceEpoch;

      merged['event_received_at_ms'] = sameAsSeeded
          ? (current['event_received_at_ms'] ??
          merged['event_received_at_ms'] ??
          apiReceivedAtMs)
          : (merged['event_received_at_ms'] ?? apiReceivedAtMs);

      // expires_in_seconds belongs to this fresh API response. Always anchor
      // it to the moment the response reached this device.
      merged['snapshot_received_at_ms'] = apiReceivedAtMs;
      merged['api_received_at_ms'] = apiReceivedAtMs;

      websocketController.currentRedPacket.value =
      Map<String, dynamic>.from(merged);
      websocketController.redPacketVisible.value = true;
      websocketController.currentRedPacket.refresh();

      _startCountdown(merged);
    } catch (e) {
      debugPrint('❌ load active Lucky Bag failed => $e');
    }
  }

  void _startCountdown(Map<String, dynamic> packet) {
    _timer?.cancel();

    packet['snapshot_received_at_ms'] ??=
        packet['api_received_at_ms'] ??
            packet['event_received_at_ms'] ??
            DateTime.now().millisecondsSinceEpoch;

    _activePacketId = (packet['id'] ?? '').toString();

    if (packet.isEmpty || _activePacketId.isEmpty || !_isForCurrentStream(packet)) {
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

      /// Dialog appears in the last 5 seconds BEFORE OPEN.
      ///
      /// Do not mark the packet as shown until the dialog actually opens.
      /// When another GetX dialog is temporarily visible, the next timer tick
      /// retries instead of permanently losing the OPEN dialog.
      if (openLeft <= 5 &&
          !_autoDialogShownIds.contains(_activePacketId)) {
        final bool opened = _openLuckyBagDialog(
          packet,
          autoOpen: true,
        );

        if (opened) {
          _autoDialogShownIds.add(_activePacketId);
        }
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  bool _openLuckyBagDialog(
      Map<String, dynamic> packet, {
        bool autoOpen = false,
      }) {
    if (Get.isDialogOpen == true) {
      return false;
    }

    Get.dialog(
      RedPacketOpenDialog(
        packet: Map<String, dynamic>.from(packet),
        initialRemainingSeconds: _remainingSeconds,
      ),
      barrierDismissible: false,
    );

    return true;
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
              if (_canCurrentUserCollect(packet)) {
                _openLuckyBagDialog(packet);
              } else {
                _openDetails(packet);
              }
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
  Timer? _timer;
  late int _remaining;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    final int serverRemaining = _dialogRemainingFromPacket();
    _remaining = serverRemaining >= 0
        ? serverRemaining
        : (widget.initialRemainingSeconds < 0
        ? 0
        : widget.initialRemainingSeconds);

    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final int next = _dialogRemainingFromPacket();

      if (!mounted) return;

      if (_remaining != next) {
        setState(() => _remaining = next);
      }

      if (next <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _dialogRemainingFromPacket() {
    final int snapshotMs = _safeInt(
      widget.packet['snapshot_received_at_ms'] ??
          widget.packet['api_received_at_ms'] ??
          widget.packet['event_received_at_ms'],
    );

    final int openAfter = _safeInt(
      widget.packet['unlock_after_seconds'] ??
          widget.packet['open_after_seconds'] ??
          widget.packet['unlock_after'] ??
          widget.packet['open_after'],
    );

    final int expiresIn =
    _safeInt(widget.packet['expires_in_seconds']);

    int duration = _safeInt(
      widget.packet['duration_seconds'] ??
          widget.packet['expire_seconds'],
    );

    if (duration <= 0) {
      final String createdText =
          widget.packet['created_at']?.toString().trim() ?? '';
      final String expiresText =
          widget.packet['expires_at']?.toString().trim() ?? '';

      final DateTime? created = DateTime.tryParse(
        createdText.replaceFirst(' ', 'T'),
      );
      final DateTime? expires = DateTime.tryParse(
        expiresText.replaceFirst(' ', 'T'),
      );

      if (created != null && expires != null) {
        duration = expires.difference(created).inSeconds;
      }
    }

    if (duration <= 0) duration = 120;

    final int elapsedBeforeSnapshot = expiresIn > 0
        ? (duration - expiresIn).clamp(0, duration).toInt()
        : 0;

    final int leftAtSnapshot =
    (openAfter - elapsedBeforeSnapshot).clamp(0, openAfter).toInt();

    final int elapsedAfterSnapshot = snapshotMs > 0
        ? ((DateTime.now().millisecondsSinceEpoch - snapshotMs) / 1000)
        .floor()
        .clamp(0, duration)
        .toInt()
        : 0;

    final int calculated = leftAtSnapshot - elapsedAfterSnapshot;
    return calculated < 0 ? 0 : calculated;
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
    if (_loading || _remaining > 0) return;
    final int packetId = _safeInt(widget.packet['id']);
    if (packetId <= 0) return;

    // Loading spinner show korbo na. User OPEN text ei dekhbe, API silently run hobe.
    setState(() => _loading = true);
    final data = await liveController.collectRedPacketData(packetId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (data == null) return;

    final amount = _collectAmount(data);
    final resultPacket = _resultPacket(data);

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
    final int packetId = _safeInt(packet['id']);
    if (livestreamId <= 0 || packetId <= 0) return;

    setState(() => loading = true);
    final packets = await liveController.getLivestreamRedPackets(
      livestreamId: livestreamId,
      status: 'all',
      perPage: 20,
    );
    if (!mounted) return;

    final found = packets.firstWhere(
          (e) => _safeInt(e['id']) == packetId,
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
