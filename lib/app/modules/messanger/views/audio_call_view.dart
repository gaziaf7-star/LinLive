import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class AudioCallView extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;
  final String token;
  final dynamic profile;
  final bool isOutGoingCall;

  const AudioCallView({
    Key? key,
    required this.profile,
    this.isOutGoingCall = false,
    required this.channelName,
    required this.isBroadcaster,
    required this.token,
  }) : super(key: key);

  @override
  State<AudioCallView> createState() => _AudioCallViewState();
}

class _AudioCallViewState extends State<AudioCallView> {
  final dynamic receiverData = Get.arguments;

  RtcEngine? engine;
  int? _remoteUid;

  bool muted = false;
  bool isSpeakerOn = true;
  bool isJoined = false;
  bool _isEnding = false;
  bool _engineReleased = false;

  Duration _callDuration = Duration.zero;
  Timer? _callTimer;
  Timer? _callingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    initializeAgora();
    _startCallTimer();
    _startCallingTimeout();
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callDuration += const Duration(seconds: 1);
      });
    });
  }

  void _startCallingTimeout() {
    _callingTimeoutTimer?.cancel();

    if (widget.isOutGoingCall) {
      _callingTimeoutTimer = Timer(const Duration(seconds: 40), () {
        if (!mounted) return;

        if (_remoteUid == null && !_isEnding) {
          Get.snackbar(
            ("No Answer").appTr,
            ("User did not answer the call").appTr,
            snackPosition: SnackPosition.BOTTOM,
          );
          _endCall();
        }
      });
    }
  }

  Future<void> initializeAgora() async {
    try {
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }

      engine = createAgoraRtcEngine();

      await engine!.initialize(
        RtcEngineContext(appId: appId),
      );

      await engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      await engine!.enableAudio();

      /// ✅ IMPORTANT FIX:
      /// Agora কিছু device এ setEnableSpeakerphone true দিলে -3 error দেয়।
      /// তাই speaker route error ignore করা হচ্ছে, call close হবে না।
      try {
        await engine!.setDefaultAudioRouteToSpeakerphone(true);
      } catch (e) {
        debugPrint('⚠️ setDefaultAudioRouteToSpeakerphone ignored: $e');
      }

      try {
        await engine!.setEnableSpeakerphone(true);
      } catch (e) {
        debugPrint('⚠️ setEnableSpeakerphone ignored: $e');
      }

      await engine!.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );

      setupEventHandlers();

      final int userId =
          authController.userProfile.value.user?.id?.toInt() ?? 0;

      if (userId == 0) {
        throw Exception('User id empty');
      }

      if (widget.token.trim().isEmpty) {
        throw Exception(('Agora token empty').appTr);
      }

      if (widget.channelName.trim().isEmpty) {
        throw Exception('Agora channel name empty');
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🎧 AUDIO CALL JOIN');
      debugPrint('👤 uid: $userId');
      debugPrint('📡 channel: ${widget.channelName}');
      debugPrint('📞 outgoing: ${widget.isOutGoingCall}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      await engine!.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: userId,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e, s) {
      debugPrint("❌ Error initializing Agora audio call: $e");
      debugPrint('$s');

      if (mounted) {
        Get.snackbar(
          ("Error").appTr,
          ("Failed to initialize audio call").appTr,
          snackPosition: SnackPosition.BOTTOM,
        );

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _endCall();
        });
      }
    }
  }

  void setupEventHandlers() {
    engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("🎉 Audio joined channel successfully");

          if (!mounted) return;
          setState(() {
            isJoined = true;
          });
        },
        onUserJoined: (
            RtcConnection connection,
            int remoteUid,
            int elapsed,
            ) {
          debugPrint("👤 Remote user joined audio call: $remoteUid");

          _callingTimeoutTimer?.cancel();

          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
            ) {
          debugPrint("🚫 Remote user left audio call: $remoteUid reason: $reason");

          if (!mounted) return;
          setState(() {
            _remoteUid = null;
          });

          _endCall();
        },
        onRemoteAudioStateChanged: (
            RtcConnection connection,
            int remoteUid,
            RemoteAudioState state,
            RemoteAudioStateReason reason,
            int elapsed,
            ) {
          debugPrint("🎧 Remote audio state changed: $state reason: $reason");
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora audio error: $err, $msg");

          if (mounted) {
            Get.snackbar(
              ("Error").appTr,
              ("Audio call error: $msg").appTr,
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        },
      ),
    );
  }

  String _getCallerName() {
    try {
      if (receiverData == null) return ('User').appTr;

      if (receiverData is Map) {
        if (_notEmpty(receiverData['peeredUserName'])) {
          return receiverData['peeredUserName'].toString();
        }

        if (_notEmpty(receiverData['caller_name'])) {
          return receiverData['caller_name'].toString();
        }

        if (_notEmpty(receiverData['name'])) {
          return receiverData['name'].toString();
        }

        if (receiverData['User Data'] != null &&
            receiverData['User Data'] is Map) {
          final userData = receiverData['User Data'];

          if (_notEmpty(userData['name'])) {
            return userData['name'].toString();
          }
        }

        if (receiverData['user_agency'] != null &&
            receiverData['user_agency'] is Map) {
          final userAgency = receiverData['user_agency'];

          if (_notEmpty(userAgency['name'])) {
            return userAgency['name'].toString();
          }
        }
      }
    } catch (_) {}

    return ('User').appTr;
  }

  String _getCallerImage() {
    try {
      if (receiverData == null) return '';

      if (receiverData is Map) {
        if (_notEmpty(receiverData['profile_image'])) {
          return receiverData['profile_image'].toString();
        }

        if (_notEmpty(receiverData['caller_image'])) {
          return receiverData['caller_image'].toString();
        }

        if (receiverData['User Data'] != null &&
            receiverData['User Data'] is Map) {
          final userData = receiverData['User Data'];

          if (_notEmpty(userData['profile_image'])) {
            return userData['profile_image'].toString();
          }
        }

        if (receiverData['user_agency'] != null &&
            receiverData['user_agency'] is Map) {
          final userAgency = receiverData['user_agency'];

          if (_notEmpty(userAgency['profile_image'])) {
            return userAgency['profile_image'].toString();
          }
        }
      }
    } catch (_) {}

    return '';
  }

  bool _notEmpty(dynamic value) {
    if (value == null) return false;

    final text = value.toString().trim();

    return text.isNotEmpty &&
        text.toLowerCase() != 'null' &&
        text != 'No Photo';
  }

  String _makeImageUrl(String image) {
    final clean = image.trim();

    if (clean.isEmpty ||
        clean.toLowerCase() == 'null' ||
        clean == 'No Photo') {
      return '';
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    return '$kDomainUrl/$clean';
  }

  bool _isValidNetworkImage(String url) {
    if (url.trim().isEmpty) return false;

    final lower = url.toLowerCase();

    if (!(lower.startsWith('http://') || lower.startsWith('https://'))) {
      return false;
    }

    /// Flutter image decoder png/jpg/webp/gif ভালো handle করে।
    /// Unknown/broken image হলে avatar fallback show হবে।
    return true;
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callingTimeoutTimer?.cancel();
    _destroyEngine();
    super.dispose();
  }

  Future<void> _destroyEngine() async {
    if (_engineReleased) return;
    _engineReleased = true;

    try {
      await engine?.leaveChannel();
    } catch (e) {
      debugPrint('⚠️ Audio leaveChannel ignored: $e');
    }

    try {
      await engine?.release();
    } catch (e) {
      debugPrint('⚠️ Audio engine release ignored: $e');
    } finally {
      engine = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              _buildMainView(),
              _buildCallControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    final String imageUrl = _makeImageUrl(_getCallerImage());

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 80,
            backgroundColor: Colors.grey[900],
            backgroundImage: _isValidNetworkImage(imageUrl)
                ? CachedNetworkImageProvider(imageUrl)
                : null,
            onBackgroundImageError: (_, __) {
              debugPrint('⚠️ Caller image decode failed: $imageUrl');
            },
            child: !_isValidNetworkImage(imageUrl)
                ? const Icon(
              Icons.person,
              color: Colors.white,
              size: 70,
            )
                : null,
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _getCallerName(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _remoteUid != null
                ? ("Connected").appTr: widget.isOutGoingCall
                ? ("Calling...").appTr: ("Connecting...").appTr,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "${_callDuration.inMinutes.toString().padLeft(2, '0')}:"
                "${(_callDuration.inSeconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),

          if (_remoteUid == null) ...[
            const SizedBox(height: 20),
            SpinKitChasingDots(
              size: 40,
              color: kPrimaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: muted ? Icons.mic_off : Icons.mic,
            color: muted ? Colors.red : Colors.white,
            onPressed: _toggleMicrophone,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.white,
            bgColor: Colors.red,
            isLarge: true,
            onPressed: _endCall,
          ),
          _buildControlButton(
            icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            color: Colors.white,
            onPressed: _toggleSpeaker,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    Color bgColor = Colors.black54,
    bool isLarge = false,
  }) {
    return Container(
      width: isLarge ? 64 : 52,
      height: isLarge ? 64 : 52,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: isLarge ? 30 : 24,
          color: color,
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _toggleMicrophone() {
    if (!mounted) return;

    setState(() {
      muted = !muted;
    });

    engine?.muteLocalAudioStream(muted);
  }

  Future<void> _toggleSpeaker() async {
    if (!mounted) return;

    final next = !isSpeakerOn;

    setState(() {
      isSpeakerOn = next;
    });

    try {
      await engine?.setEnableSpeakerphone(next);
    } catch (e) {
      debugPrint('⚠️ setEnableSpeakerphone toggle ignored: $e');
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;

    try {
      _callTimer?.cancel();
      _callingTimeoutTimer?.cancel();

      await _destroyEngine();

      if (mounted) {
        Get.back();
      }
    } catch (e) {
      debugPrint("❌ Error ending audio call: $e");

      if (mounted) {
        Get.back();
      }
    }
  }
}