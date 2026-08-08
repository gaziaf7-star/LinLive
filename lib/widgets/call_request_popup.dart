import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import '../constants/color_constants.dart';
import '../constants/image_helper.dart';
import '../constants/layout_constant.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

class CallRequestPopup extends StatefulWidget {
  final Map<String, dynamic> callData;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const CallRequestPopup({
    super.key,
    required this.callData,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<CallRequestPopup> createState() => _CallRequestPopupState();
}

class _CallRequestPopupState extends State<CallRequestPopup> {
  String? _runningAction;

  Future<void> _runTransition(
    String action,
    Future<void> Function() transition,
  ) async {
    if (_runningAction != null) return;
    setState(() => _runningAction = action);
    try {
      await transition();
    } finally {
      if (mounted) setState(() => _runningAction = null);
    }
  }

  String _framePath(Map<String, dynamic> user) {
    final purchase = user['asset_purchase_history'];
    if (purchase is Map) {
      final asset = purchase['asset'];
      if (asset is Map) {
        return (asset['asset'] ?? asset['file'] ?? asset['url'] ?? '')
            .toString();
      }
      return (purchase['asset_url'] ?? purchase['frame'] ?? '').toString();
    }
    return (user['frame'] ?? widget.callData['frame'] ?? '').toString();
  }

  Widget _placeholder() {
    return Image.asset(
      'assets/audio_live/1136.jpg',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.person, color: Colors.grey.shade500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callerData = widget.callData['caller_data'] is Map
        ? Map<String, dynamic>.from(widget.callData['caller_data'])
        : <String, dynamic>{};
    final rawUser = widget.callData['user'] ?? callerData['user'];
    final user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{};
    final callerId =
        widget.callData['caller_id'] ??
        widget.callData['user_id'] ??
        user['id'] ??
        user['user_id'];
    final userName =
        (user['name'] ??
                widget.callData['name'] ??
                widget.callData['caller_name'] ??
                (callerId == null ? 'Unknown User' : 'User $callerId'))
            .toString();
    final userImage =
        (user['profile_image'] ??
                widget.callData['profile_image'] ??
                widget.callData['caller_image'] ??
                '')
            .toString();
    final displayUid =
        user['user_id'] ?? widget.callData['uid'] ?? callerId ?? 'N/A';
    final framePath = _framePath(user);
    final isAudio =
        widget.callData['call_type']?.toString().toLowerCase() == 'audio';
    final level = user['level'] ?? widget.callData['level'];
    final seatNo =
        widget.callData['seat_no'] ??
        widget.callData['seat'] ??
        callerData['seat_no'];

    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 16,
        shadowColor: Colors.black26,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0xffEEE5EA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            kWeight * 0.06,
            kHeight * 0.025,
            kWeight * 0.06,
            kHeight * 0.025,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(height: kHeight * 0.02),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAudio ? Icons.call : Icons.video_call,
                    color: kPrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ('Incoming Call Request').appTr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: kHeight * 0.02),
              SizedBox(
                width: kWeight * 0.29,
                height: kWeight * 0.29,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: kWeight * 0.22,
                        height: kWeight * 0.22,
                        child: userImage.isEmpty
                            ? _placeholder()
                            : CachedNetworkImage(
                                imageUrl: ImageHelper.getImageUrl(userImage),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _placeholder(),
                                errorWidget: (_, __, ___) => _placeholder(),
                              ),
                      ),
                    ),
                    if (framePath.isNotEmpty)
                      SizedBox.expand(
                        child: framePath.toLowerCase().endsWith('.svga')
                            ? SVGAEasyPlayer(
                                key: ValueKey('call-frame-$framePath'),
                                resUrl: ImageHelper.getImageUrl(framePath),
                                fit: BoxFit.contain,
                                loops: null,
                                useCache: true,
                              )
                            : CachedNetworkImage(
                                key: ValueKey('call-frame-$framePath'),
                                imageUrl: ImageHelper.getImageUrl(framePath),
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const SizedBox.shrink(),
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                      ),
                  ],
                ),
              ),
              Text(
                userName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ('ID: $displayUid').appTr,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _infoChip(
                    isAudio ? ('Audio Call').appTr : ('Video Call').appTr,
                    isAudio ? Icons.mic_rounded : Icons.videocam_rounded,
                  ),
                  if (level != null) _infoChip('Level $level', Icons.star),
                  if (seatNo != null && seatNo.toString() != '0')
                    _infoChip('Seat $seatNo', Icons.event_seat_rounded),
                ],
              ),
              SizedBox(height: kHeight * 0.025),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _runningAction != null
                          ? null
                          : () => _runTransition('reject', widget.onReject),
                      icon: _runningAction == 'reject'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.call_end),
                      label: Text(('Reject').appTr),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade400),
                        minimumSize: Size.fromHeight(kHeight * 0.058),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: kWeight * 0.035),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _runningAction != null
                          ? null
                          : () => _runTransition('accept', widget.onAccept),
                      icon: _runningAction == 'accept'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.call),
                      label: Text(('Accept').appTr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: Size.fromHeight(kHeight * 0.058),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xffFFF6F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffF1DDE3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kPrimaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff4B4045),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
