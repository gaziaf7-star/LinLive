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
import '../../auth/controllers/auth_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class VideoCallView extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;
  final String token;
  final dynamic profile;
  final bool isOutGoingCall;

  const VideoCallView({
    Key? key,
    required this.profile,
    this.isOutGoingCall = false,
    required this.channelName,
    required this.isBroadcaster,
    required this.token,
  }) : super(key: key);

  @override
  State<VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<VideoCallView> {
  final dynamic receiverData = Get.arguments;
  final AuthController authController = Get.find<AuthController>();

  RtcEngine? engine;
  int? _remoteUid;

  bool muted = false;
  bool videoDisabled = false;
  bool isSpeakerOn = true;
  bool isFrontCamera = true;
  bool isJoined = false;
  bool isEngineReady = false;
  bool _isEnding = false;
  bool _engineReleased = false;
  bool _isRemoteVideoMuted = false;

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
      _callingTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!mounted) return;

        if (_remoteUid == null && !_isEnding) {
          Get.snackbar(
            ("No Answer").appTr,
            ("User did not answer the video call").appTr,
            snackPosition: SnackPosition.BOTTOM,
          );
          _endCall();
        }
      });
    }
  }

  Future<void> initializeAgora() async {
    try {
      final status = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (!status[Permission.camera]!.isGranted ||
          !status[Permission.microphone]!.isGranted) {
        throw Exception('Camera/Mic permission denied');
      }

      engine = createAgoraRtcEngine();

      await engine!.initialize(
        RtcEngineContext(appId: appId),
      );

      setupEventHandlers();

      await engine!.enableVideo();
      await engine!.enableAudio();

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

      try {
        await engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 640, height: 360),
            frameRate: 15,
            bitrate: 0,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
      } catch (e) {
        debugPrint('⚠️ video encoder config ignored: $e');
      }

      if (mounted) {
        setState(() {
          isEngineReady = true;
        });
      }

      await engine!.startPreview();

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
      debugPrint('📹 VIDEO CALL JOIN');
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
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e, s) {
      debugPrint("❌ Error initializing Agora video call: $e");
      debugPrint('$s');

      if (mounted) {
        Get.snackbar(
          ("Error").appTr,
          ("Failed to initialize video call").appTr,
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
          debugPrint("🎉 Video joined channel successfully");

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
          debugPrint("👤 Remote user joined video call: $remoteUid");

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
          debugPrint("🚫 Remote user left video call: $remoteUid reason: $reason");

          if (!mounted) return;
          setState(() {
            _remoteUid = null;
          });

          _endCall();
        },
        onRemoteVideoStateChanged: (
            RtcConnection connection,
            int remoteUid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
            ) {
          debugPrint("📹 Remote video state: $state reason: $reason");

          if (!mounted) return;
          setState(() {
            _isRemoteVideoMuted =
                state == RemoteVideoState.remoteVideoStateStopped;
          });
        },
        onRemoteAudioStateChanged: (
            RtcConnection connection,
            int remoteUid,
            RemoteAudioState state,
            RemoteAudioStateReason reason,
            int elapsed,
            ) {
          debugPrint("🎧 Remote audio state: $state reason: $reason");
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora video error: $err, $msg");

          if (mounted) {
            Get.snackbar(
              ("Error").appTr,
              ("Video call error: $msg").appTr,
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

    return lower.startsWith('http://') || lower.startsWith('https://');
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
      await engine?.stopPreview();
    } catch (e) {
      debugPrint('⚠️ stopPreview ignored: $e');
    }

    try {
      await engine?.leaveChannel();
    } catch (e) {
      debugPrint('⚠️ leaveChannel ignored: $e');
    }

    try {
      await engine?.release();
    } catch (e) {
      debugPrint('⚠️ engine release ignored: $e');
    } finally {
      engine = null;
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
      debugPrint("❌ Error ending video call: $e");

      if (mounted) {
        Get.back();
      }
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
              _buildMainVideoView(),
              if (isJoined && isEngineReady && engine != null)
                _buildLocalVideoPreview(),
              _buildTopBar(),
              _buildCallControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainVideoView() {
    if (!isEngineReady || engine == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_remoteUid != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          ),
          if (_isRemoteVideoMuted) _buildMutedAvatarOverlay(),
        ],
      );
    }

    return _buildWaitingView();
  }

  Widget _buildMutedAvatarOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatar(radius: 58),
          const SizedBox(height: 12),
          Text(
            _getCallerName(),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 6),
           Text(
            ('Camera Off').appTr,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatar(radius: 70),
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _remoteUid != null
                ? ("Connected").appTr: widget.isOutGoingCall
                ? ("Video Calling...").appTr: ("Connecting...").appTr,
            style: const TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 40),
          SpinKitRipple(color: kPrimaryColor, size: 80),
        ],
      ),
    );
  }

  Widget _buildLocalVideoPreview() {
    if (engine == null || videoDisabled) {
      return Positioned(
        right: 16,
        top: 75,
        child: Container(
          width: 110,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black87,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.videocam_off, color: Colors.white, size: 38),
          ),
        ),
      );
    }

    return Positioned(
      right: 16,
      top: 75,
      child: Container(
        width: 110,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final String formattedDuration =
        "${_callDuration.inMinutes.toString().padLeft(2, '0')}:"
        "${(_callDuration.inSeconds % 60).toString().padLeft(2, '0')}";

    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topPill(formattedDuration),
          if (_remoteUid != null)
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _getCallerName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildCallControls() {
    return Positioned(
      bottom: 42,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleBtn(
            icon: muted ? Icons.mic_off : Icons.mic,
            color: muted ? Colors.red : Colors.white,
            onTap: _toggleMic,
          ),
          _circleBtn(
            icon: videoDisabled ? Icons.videocam_off : Icons.videocam,
            color: videoDisabled ? Colors.red : Colors.white,
            onTap: _toggleVideo,
          ),
          _circleBtn(
            icon: Icons.call_end,
            color: Colors.white,
            bgColor: Colors.red,
            size: 66,
            onTap: _endCall,
          ),
          _circleBtn(
            icon: Icons.switch_camera,
            color: Colors.white,
            onTap: _switchCamera,
          ),
          _circleBtn(
            icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            color: Colors.white,
            onTap: _toggleSpeaker,
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    Color bgColor = Colors.white24,
    double size = 52,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }

  Widget _buildAvatar({required double radius}) {
    final String imageUrl = _makeImageUrl(_getCallerImage());

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[900],
      backgroundImage:
      _isValidNetworkImage(imageUrl) ? CachedNetworkImageProvider(imageUrl) : null,
      onBackgroundImageError: (_, __) {
        debugPrint('⚠️ Caller image decode failed: $imageUrl');
      },
      child: !_isValidNetworkImage(imageUrl)
          ? Icon(Icons.person, size: radius, color: Colors.white)
          : null,
    );
  }

  Future<void> _toggleMic() async {
    if (!mounted) return;

    setState(() {
      muted = !muted;
    });

    await engine?.muteLocalAudioStream(muted);
  }

  Future<void> _toggleVideo() async {
    if (!mounted) return;

    setState(() {
      videoDisabled = !videoDisabled;
    });

    await engine?.muteLocalVideoStream(videoDisabled);

    if (videoDisabled) {
      try {
        await engine?.stopPreview();
      } catch (_) {}
    } else {
      try {
        await engine?.startPreview();
      } catch (_) {}
    }
  }

  Future<void> _switchCamera() async {
    try {
      await engine?.switchCamera();

      if (!mounted) return;
      setState(() {
        isFrontCamera = !isFrontCamera;
      });
    } catch (e) {
      debugPrint('⚠️ switchCamera ignored: $e');
    }
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
}