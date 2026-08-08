import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../../../widgets/tasksLiveView.dart';
import '../../../services/agora_service.dart';
import '../../ranking/views/allrank.dart';
import '../controllers/livestream_action_controller.dart';
import '../controllers/livestream_controller.dart';
import '../controllers/websocket_controller.dart';
import '../widgets/LiveProfile_AppBar.dart';
import '../widgets/entry_animation.dart';
import '../widgets/live_comments.dart';
import '../widgets/live_viewer_list.dart';
import '../widgets/red_packet_animation.dart';
import '../widgets/write_comments.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class MultiLiveView extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;
  final int? seatCount;
  final String token;

  const MultiLiveView({
    super.key,
    required this.channelName,
    this.seatCount,
    required this.isBroadcaster,
    required this.token,
  });

  @override
  State<MultiLiveView> createState() => _MultiLiveViewState();
}

class _MultiLiveViewState extends State<MultiLiveView> {
  LivestreamController liveController = Get.find();
  LiveStreamActionController actionController = Get.put(
    LiveStreamActionController(),
  );
  WebsocketController websocketController = Get.find();

  final AgoraService _agoraService = AgoraService();

  final streamData = Get.arguments;

  final streamInfo = {}.obs;
  final broadcasterData = {}.obs;
  String? _currentToken;

  // final activeCallers = [].obs;

  final addComments = TextEditingController();

  // ✅ BATTERY OPTIMIZATION & SAFETY: schedule UI updates after current frame
  Timer? _uiUpdateTimer;

  void _scheduleUIUpdate() {
    if (!mounted) return;
    if (_uiUpdateTimer?.isActive == true) return;

    // Debounce rapid events and ensure setState is not called during build
    _uiUpdateTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
  }

  void setLiveStreamDataAsBroadcaster() {
    if (streamData != null) {
      streamInfo.value = streamData['livestreamdata'] ?? {};
      broadcasterData.value = streamData['broadcaster_call_data'] ?? {};

      if (broadcasterData.isNotEmpty && broadcasterData['user'] != null) {
        liveController.broadcasterId.value = broadcasterData['user']['id'];
      }
      liveController.lastPingUpdate(id: streamInfo['id']);
      // Timer start করি broadcaster এর জন্য
      if (!liveController.isLive.value) {
        String? createdAt =
            streamData['livestreamdata']?['created_at'] ??
            broadcasterData['created_at'];
        if (createdAt != null) {
          liveController.startLive(createdAt);
        } else {
          liveController.startLive(DateTime.now().toIso8601String());
        }
      }
    } else {
      streamInfo.value = {};
      broadcasterData.value = {};
      print('Warning: streamData is null in setLiveStreamDataAsBroadcaster');
    }
  }

  void setLiveStreamDataAsAudience() async {
    // print('stream data $streamData');
    // // Ensure call list is populated for first-time audience members
    await liveController.tryToGetCallList(streamId: streamData['id']);
    // Check if livestream_callers exists and is not empty
    if (streamData != null &&
        streamData['livestream_callers'] != null &&
        streamData['livestream_callers'].isNotEmpty) {
      broadcasterData.value = streamData['livestream_callers'][0];
      liveController.broadcasterId.value = broadcasterData['user']['id'];
      print(
        'this is broadcaster data ${streamData['livestream_callers'][0]['user']['name']}',
      );
    } else {
      // Fallback: try to get broadcaster data from other sources
      broadcasterData.value = streamData['broadcaster_call_data'] ?? {};
      if (broadcasterData.value.isNotEmpty &&
          broadcasterData.value['user'] != null) {
        liveController.broadcasterId.value = broadcasterData['user']['id'];
      }
      print('Using fallback broadcaster data');
    }

    // Set streamInfo with proper fallback
    if (streamData != null) {
      streamInfo.value = streamData;
    } else {
      streamInfo.value = {};
      print('Warning: streamData is null in setLiveStreamDataAsAudience');
    }

    // Set the stream ID in WebSocket controller and fetch initial gift total
    if (streamData != null && streamData['id'] != null) {
      websocketController.streamID.value = streamData['id'];
      websocketController.fetchInitialGiftTotal();
    }

    // Timer start করি audience এর জন্য
    if (!liveController.isLive.value) {
      String? createdAt =
          streamData['created_at'] ?? broadcasterData['created_at'];
      if (createdAt != null) {
        liveController.startLive(createdAt);
      } else {
        liveController.startLive(DateTime.now().toIso8601String());
      }
    }
  }

  Future<void> prepareForLive() async {
    // 🔹 Ensure Agora service is initialized
    if (!_agoraService.isInitialized || _agoraService.engine == null) {
      print("AgoraService not ready, attempting to initialize...");
      bool initialized = await _agoraService.initializeEngine();
      if (!initialized) {
        print("Failed to initialize Agora engine");
        return;
      }
    }

    final engine = _agoraService.engine;
    if (engine == null) {
      print("Engine is null after initialization");
      return;
    }

    print("⚙️ Configuring Agora for low-heat performance...");

    // 🔹 1. Set channel profile
    await engine.setChannelProfile(
      ChannelProfileType.channelProfileLiveBroadcasting,
    );

    // 🔹 2. Enable video (with hardware acceleration if available)
    await engine.enableVideo();
    await engine.setParameters('{"che.video.hardware_encoding": true}');
    await engine.setParameters(
      '{"che.video.lowBitRateStreamParameter": {"width": 320, "height": 180, "frameRate": 15, "bitrate": 140}}',
    );

    // 🔹 3. Video Encoder Configuration (optimized)
    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(
          width: 480,
          height: 270,
        ), // 360p বা 480p রাখুন
        frameRate: 15, // Low FPS
        bitrate: 500, // Low bitrate
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );

    // 🔹 4. Dynamic bitrate and frame rate for thermal management
    await engine.setParameters('{"che.video.enableAdaptiveBitrate": true}');
    await engine.setParameters('{"rtc.video.dynamic_switch": true}');

    // 🔹 5. Battery optimizer custom config (if any)
    try {} catch (e) {
      print("⚠️ Battery optimizer not available: $e");
    }

    // 🔹 6. Enable low latency mode for less processing
    await engine.setParameters('{"rtc.low_latency_mode": true}');

    // 🔹 7. Set role-specific configurations
    if (widget.isBroadcaster) {
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableLocalVideo(true);
      await engine.muteLocalAudioStream(false);
    } else {
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.enableLocalVideo(false);
      await engine.muteLocalAudioStream(true);
    }

    // 🔹 8. Event handlers (optimized with debounced UI updates)
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          print("🎉 Joined channel successfully");
          _scheduleUIUpdate();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          print("👤 Remote user joined: $remoteUid");
          _scheduleUIUpdate();
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              if (!_agoraService.isCurrentEngineInstance(engine)) return;
              print("🚫 Remote user left: $remoteUid");
              _scheduleUIUpdate();
            },
        // 🔥 Correct onError handler
        onError: (ErrorCodeType err, String msg) {
          if (!_agoraService.isCurrentEngineInstance(engine)) return;
          print("⚠️ Agora Error: $err | Message: $msg");
          if (widget.isBroadcaster) {
            livestreamController.agoraTokenGenerateError();
          }
        },
      ),
    );

    // 🔹 9. Join the channel
    final userId = authController.userProfile.value.user!.id!.toInt();
    await _agoraService.joinChannelWithOptions(
      token: widget.token,
      channelId: widget.channelName,
      uid: userId,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: widget.isBroadcaster
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
      ),
    );

    // 🔹 10. Schedule a UI update
    _scheduleUIUpdate();

    // 🔹 11. (Extra) Lower device heating by disabling unused video renderers
    await engine.setParameters('{"che.video.disable_render": false}');
    print("✅ Agora ready with low-heat optimizations");
  }

  // ------------------------- timer ---------------

  @override
  void initState() {
    // Enable wake lock to keep screen on during live streaming

    print('Sagor seat test data ${liveController.seatCount.value}');
    WakelockPlus.enable();
    _currentToken = widget.token;
    String? createdAt;

    // প্রথমে createData থেকে check করি
    createdAt = liveController.createData['viewer']?['created_at'];

    // যদি createData থেকে না পাই, তাহলে arguments থেকে check করি
    if (createdAt == null && Get.arguments != null) {
      createdAt = Get.arguments['created_at'];
    }

    // যদি এখনো না পাই, তাহলে current time use করি
    if (createdAt != null) {
      liveController.startLive(createdAt);
    } else {
      // Fallback: current time দিয়ে timer start করি
      liveController.startLive(DateTime.now().toIso8601String());
    }
    if (widget.isBroadcaster) {
      websocketController.broadcasterWebsocket.sink.close();
    }
    prepareForLive();
    if (widget.isBroadcaster) {
      liveController.isBroadcaster.value = true;
      setLiveStreamDataAsBroadcaster();
    } else {
      setLiveStreamDataAsAudience();
    }
    // Setup red packet callbacks
    _setupRedPacketCallbacks();

    super.initState();
  }

  @override
  void dispose() {
    // ✅ BATTERY OPTIMIZATION: Cancel UI update timer to prevent memory leaks
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;

    // Disable wake lock to restore normal screen behavior
    WakelockPlus.disable();
    websocketController.liveCallList.clear();
    websocketController.pendingCall.clear();
    liveController.liveViewerList.clear();
    liveController.stopPingUpdate();
    liveController.stopLivePresenceHeartbeat();
    liveController.stopLive();
    liveController.isBroadcaster.value = false;
    if (!widget.isBroadcaster) {
      liveController.tryToRemoveViewer(
        streamId: streamInfo['id'],
        viewerId: authController.userProfile.value.user!.id!.toInt(),
      );
    }

    // Clear red packet callbacks
    websocketController.clearRedPacketCallbacks();

    liveController.hasJoinedCall.value =
        false; // Set join status to false when leaving
    _agoraService.leaveChannel();

    super.dispose();
  }

  void _setupRedPacketCallbacks() {
    websocketController.setRedPacketCallbacks(
      onReceived: (redPacketData) {
        print('🧧 Red packet received in PopularLiveView: $redPacketData');
        // Red packet animation will be shown automatically via Obx
      },
      onCollected: (collectionData) {
        print('🧧 Red packet collected in PopularLiveView: $collectionData');
        // Update balance or show success message
        Get.snackbar(
          ('🧧 Red Packet Collected!').appTr,
          ('You received ${collectionData["amount"]} coins').appTr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      },
    );
  }

  //for live stream end
  @override
  Widget build(BuildContext context) {
    // ✅ KEEP SYSTEM UI: Keep bottom navigation visible, UI starts above it
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return WillPopScope(
      onWillPop: () async {
        if (widget.isBroadcaster) {
          // Broadcaster হলে popup দেখাবো
          bool exitApp = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15), // corner radius
              ),
              title: Text(
                ("End Live").appTr,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                ("Are you sure you want to exit?").appTr,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // stay
                  child: Text(
                    ("No").appTr,
                    style: GoogleFonts.roboto(fontSize: 14, color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (widget.isBroadcaster) {
                      await liveController.tryToRemoveLivestream(
                        streamId: streamInfo['id'],
                      );
                    }
                    await _agoraService.leaveChannel(); // Dialog close
                  },
                  child: Text(
                    ("Yes").appTr,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          );

          return exitApp; // true/false based on popup
        } else {
          // Broadcaster না হলে normal back behavior
          return true;
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: true,
          child: broadcasterData.isEmpty
              ? Stack(
                  children: [
                    SpinKitChasingDots(size: 40, color: kPrimaryColor),
                    Image.asset(
                      'assets/audio_live/1136.jpg',
                      fit: BoxFit.cover,
                      height: kHeight,
                      width: kWeight,
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/images/backgroundimagewalparer.jpg',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      //
                      _broadcastView(),

                      broadcasterData == null && broadcasterData['user'] == null
                          ? Container()
                          : Column(
                              children: [
                                SizedBox(height: kHeight * 0.05),
                                //Live view Part one start
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      //fast row start
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // ==== Left fixed Stack ====
                                          Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              // Main Container (Background + Info + Follow Button)
                                              Container(
                                                padding: EdgeInsets.only(
                                                  right: Get.width * 0.015,
                                                ),
                                                margin: EdgeInsets.only(
                                                  left: Get.width * 0.07,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.2,
                                                  ),
                                                  color: const Color(
                                                    0x47381b1b,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: Get.width * 0.07,
                                                    ), // profile এর জায়গা
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        broadcasterData['user'] !=
                                                                null
                                                            ? Text(
                                                                (() {
                                                                  final name =
                                                                      broadcasterData['user']['name'] ??
                                                                      '';
                                                                  // ৬ অক্ষরের বেশি হলে শেষে ... দেখাবে
                                                                  return name.length >
                                                                          10
                                                                      ? '${name.substring(0, 10)}...'
                                                                      : name;
                                                                })(),
                                                                style: GoogleFonts.poppins(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      (Get.height *
                                                                              0.011)
                                                                          .clamp(
                                                                            9.0,
                                                                            11.0,
                                                                          ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              )
                                                            : const SizedBox(),
                                                        (broadcasterData['user']?['user_id'] !=
                                                                null)
                                                            ? Text(
                                                                ('Uid : ${broadcasterData['user']['user_id']}')
                                                                    .appTr,
                                                                style: GoogleFonts.poppins(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      (Get.height *
                                                                              0.012)
                                                                          .clamp(
                                                                            9.0,
                                                                            14.0,
                                                                          ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              )
                                                            : const SizedBox(),
                                                      ],
                                                    ),
                                                    SizedBox(
                                                      width: Get.width * 0.015,
                                                    ),
                                                    Obx(() {
                                                      if (broadcasterData?['user']?['id'] ==
                                                          authController
                                                              .userProfile
                                                              .value
                                                              .user
                                                              ?.id) {
                                                        return const SizedBox();
                                                      }

                                                      return AnimatedSwitcher(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 300,
                                                            ),
                                                        child:
                                                            momentsController
                                                                .isFollowing1
                                                                .value
                                                            ? Container()
                                                            : InkWell(
                                                                key:
                                                                    const ValueKey(
                                                                      'follow',
                                                                    ),
                                                                onTap: () {
                                                                  momentsController
                                                                      .followCreate(
                                                                        userId:
                                                                            '${broadcasterData['user']?['id']}',
                                                                      );
                                                                },
                                                                child: Container(
                                                                  padding: EdgeInsets.symmetric(
                                                                    vertical:
                                                                        Get.height *
                                                                        0.007,
                                                                    horizontal:
                                                                        Get.width *
                                                                        0.03,
                                                                  ),
                                                                  decoration: BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          30,
                                                                        ),
                                                                    gradient: const LinearGradient(
                                                                      colors: [
                                                                        Color(
                                                                          0xff8A4CF7,
                                                                        ),
                                                                        Color(
                                                                          0xffB460F0,
                                                                        ),
                                                                      ],
                                                                      begin: Alignment
                                                                          .topCenter,
                                                                      end: Alignment
                                                                          .bottomCenter,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    ('Follow')
                                                                        .appTr,
                                                                    style: GoogleFonts.lato(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          (Get.height *
                                                                                  0.011)
                                                                              .clamp(
                                                                                9.0,
                                                                                14.0,
                                                                              ),
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                      );
                                                    }),
                                                  ],
                                                ),
                                              ),

                                              // Profile + Fame Overlay
                                              Positioned(
                                                left: 5,
                                                top: -Get.height * 0.009,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    homeController.liveVisitProfile(
                                                      userId:
                                                          '${broadcasterData['user']['id']}',
                                                      seatData:
                                                          websocketController
                                                              .liveCallList[0],
                                                    );
                                                  },
                                                  child: Obx(() {
                                                    double size =
                                                        Get.height * 0.055;
                                                    final user =
                                                        broadcasterData['user'];

                                                    return SizedBox(
                                                      height: size,
                                                      width: size,
                                                      child: Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          // Profile Image
                                                          ClipOval(
                                                            child: CachedNetworkImage(
                                                              imageUrl:
                                                                  ImageHelper.getImageUrl(
                                                                    "${user['profile_image']}",
                                                                  ),
                                                              fit: BoxFit.cover,
                                                              height:
                                                                  size * 0.7,
                                                              width: size * 0.7,
                                                            ),
                                                          ),

                                                          // Frame condition
                                                          if (user['agency_id'] !=
                                                              0) ...[
                                                            // show agency frame
                                                            Positioned.fill(
                                                              child: SVGAEasyPlayer(
                                                                assetsName:
                                                                    agencyFrame,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                            ),
                                                          ] else if (user['asset_purchase_history'] !=
                                                              null) ...[
                                                            // show asset frame only if agency_id == 0
                                                            Positioned.fill(
                                                              child: Image.network(
                                                                "$kDomainUrl/${user['asset_purchase_history']['asset']['asset']}",
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // ==== Right viewers + close ==== (Flexible so it won’t overflow)
                                          Flexible(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                SizedBox(
                                                  width: Get.width * 0.22,
                                                  height: Get.height * 0.04,
                                                  child: Obx(() {
                                                    // Filter list একবারেই বের করো
                                                    final filteredList =
                                                        livestreamController
                                                            .liveViewerList
                                                            .where(
                                                              (viewer) =>
                                                                  viewer['user']['id'] !=
                                                                  broadcasterData['user']['id'],
                                                            )
                                                            .toList();

                                                    if (filteredList.isEmpty) {
                                                      return const SizedBox(); // কিছু না দেখানোর জন্য (empty state)
                                                    }

                                                    return ListView.builder(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      itemCount:
                                                          filteredList.length,
                                                      itemBuilder:
                                                          (context, index) {
                                                            final data =
                                                                filteredList[index];
                                                            return LiveProfile(
                                                              data: data,
                                                            );
                                                          },
                                                    );
                                                  }),
                                                ),

                                                ///------------- viewer list show
                                                InkWell(
                                                  onTap: () {
                                                    /// *********** All Viewer List Bottom sheet ***********
                                                    final filteredList =
                                                        livestreamController
                                                            .liveViewerList
                                                            .where(
                                                              (viewer) =>
                                                                  viewer['user']['id'] !=
                                                                  broadcasterData['user']['id'],
                                                            )
                                                            .toList();

                                                    Get.bottomSheet(
                                                      LiveViewerList(
                                                        filteredList:
                                                            filteredList,
                                                      ),
                                                      isScrollControlled: true,
                                                    );
                                                  },
                                                  child: Container(
                                                    margin: EdgeInsets.only(
                                                      left: Get.width * 0.01,
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            100,
                                                          ),
                                                      child: Container(
                                                        height:
                                                            Get.height * 0.035,
                                                        width:
                                                            Get.height * 0.035,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: kAppColor
                                                                  .withOpacity(
                                                                    .6,
                                                                  ),
                                                            ),
                                                        child: Center(
                                                          child: Obx(() {
                                                            final filteredCount =
                                                                livestreamController
                                                                    .liveViewerList
                                                                    .where(
                                                                      (
                                                                        viewer,
                                                                      ) =>
                                                                          viewer['user']['id'] !=
                                                                          broadcasterData['user']['id'],
                                                                    )
                                                                    .length;
                                                            return Text(
                                                              '$filteredCount+',
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            );
                                                          }),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                (broadcasterData != null &&
                                                        widget.isBroadcaster)
                                                    ? GestureDetector(
                                                        onTap: () async {
                                                          // Show confirmation dialog for broadcaster
                                                          final shouldEnd = await Get.dialog<bool>(
                                                            AlertDialog(
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      0,
                                                                    ), // ✅ কম border radius
                                                              ),
                                                              backgroundColor:
                                                                  Colors.white,
                                                              title: Text(
                                                                ('End Live Stream')
                                                                    .appTr,
                                                                style: GoogleFonts.roboto(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                              content: Text(
                                                                ('Are you sure you want to end this live stream? All viewers will be disconnected.')
                                                                    .appTr,
                                                                style: GoogleFonts.roboto(
                                                                  fontSize: 14,
                                                                  color: Colors
                                                                      .black54,
                                                                ),
                                                              ),
                                                              actionsPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 8,
                                                                  ),
                                                              actions: [
                                                                TextButton(
                                                                  style: TextButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .grey
                                                                            .shade200,
                                                                    // ✅ Cancel এর ব্যাকগ্রাউন্ড
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () =>
                                                                      Get.back(
                                                                        result:
                                                                            false,
                                                                      ),
                                                                  child: Text(
                                                                    ('Cancel')
                                                                        .appTr,
                                                                    style: GoogleFonts.roboto(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: Colors
                                                                          .black87,
                                                                    ),
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  style: TextButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .redAccent,
                                                                    // ✅ End Stream এর রঙ
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () async {
                                                                    if (widget
                                                                        .isBroadcaster) {
                                                                      await liveController.tryToRemoveLivestream(
                                                                        streamId:
                                                                            streamInfo['id'],
                                                                      );
                                                                    }
                                                                    await _agoraService
                                                                        .leaveChannel(); // Dialog close
                                                                  },
                                                                  child: Text(
                                                                    ('End Stream')
                                                                        .appTr,
                                                                    style: GoogleFonts.roboto(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );

                                                          if (shouldEnd ==
                                                              true) {
                                                            // created_at থেকে startTime নেওয়া, null হলে এখনকার সময় ব্যবহার
                                                            final DateTime
                                                            startDateTime =
                                                                broadcasterData['created_at'] !=
                                                                    null
                                                                ? DateTime.parse(
                                                                    broadcasterData['created_at'],
                                                                  )
                                                                : DateTime.now();

                                                            print(
                                                              'stream data $streamInfo',
                                                            );

                                                            // End the stream properly
                                                            await livestreamController
                                                                .liveEndTimeCase(
                                                                  streamId:
                                                                      broadcasterData['livestream_id'],
                                                                  startTime:
                                                                      startDateTime,
                                                                );

                                                            await _agoraService
                                                                .leaveChannel();
                                                          }
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            color: kAppColor,
                                                          ),
                                                          margin:
                                                              EdgeInsets.only(
                                                                right: 2,
                                                                left: 2,
                                                              ),
                                                          height:
                                                              Get.height *
                                                              0.035,
                                                          width:
                                                              Get.height *
                                                              0.035,
                                                          child: Icon(
                                                            Icons.close_rounded,
                                                            color: Colors.white,
                                                            size:
                                                                Get.height *
                                                                0.02,
                                                          ),
                                                        ),
                                                      )
                                                    : IconButton(
                                                        style: IconButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.grey[100],
                                                          padding:
                                                              EdgeInsets.all(4),
                                                          // ভিতরের space ছোট করা
                                                          minimumSize: Size(
                                                            28,
                                                            28,
                                                          ), // button এর overall size ছোট করা
                                                        ),
                                                        onPressed: () {
                                                          Get.back();
                                                        },
                                                        icon: Icon(
                                                          Icons.close,
                                                          color: kAppColor,
                                                          size:
                                                              18, // icon টার সাইজ ছোট
                                                        ),
                                                      ),
                                                // Nothing will be shown if broadcasterData is null
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: kHeight * 0.006),

                                      ///---------- timer -------------
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                          top: 5,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Get.to(
                                                  Allrank(),
                                                  transition:
                                                      Transition.rightToLeft,
                                                );
                                              },
                                              child: Obx(() {
                                                return TaskLiveProfile(
                                                  text: (() {
                                                    // যদি broadcasterData বা broadcasterData['user'] null হয়, তাহলে 0 ধরা হবে
                                                    int coins =
                                                        int.tryParse(
                                                          (websocketController
                                                              .liveCallList[0]['user']['earned_coins']
                                                              .toString()),
                                                        ) ??
                                                        0;

                                                    if (coins >= 1000000) {
                                                      double value =
                                                          coins / 1000000;
                                                      return value % 1 == 0
                                                          ? '${value.toInt()}M'
                                                          : '${value.toStringAsFixed(1)}M';
                                                    } else if (coins >= 1000) {
                                                      double value =
                                                          coins / 1000;
                                                      return value % 1 == 0
                                                          ? '${value.toInt()}k'
                                                          : '${value.toStringAsFixed(1)}k';
                                                    } else {
                                                      return coins.toString();
                                                    }
                                                  })(),
                                                  seccondtext: 'Receive: ',
                                                );
                                              }),
                                            ),
                                            broadcasterData?['user']?['id'] ==
                                                    authController
                                                        .userProfile
                                                        .value
                                                        .user!
                                                        .id
                                                ? Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              kWeight * 0.03,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      color: Colors.black
                                                          .withOpacity(0.2),
                                                    ),
                                                    child: Obx(
                                                      () => Castontext(
                                                        fontSize:
                                                            kHeight * 0.015,
                                                        textColor:
                                                            liveController
                                                                .isLive
                                                                .value
                                                            ? const Color(
                                                                0xff00ff00,
                                                              ) // Live active = green
                                                            : const Color(
                                                                0xff808080,
                                                              ), // Inactive = gray
                                                        text: liveController
                                                            .formattedTime,
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                            GestureDetector(
                                              onTap: () {
                                                // Get.to(RankingView(),
                                                //     transition: Transition.rightToLeft);
                                              },
                                              child: Container(
                                                margin: EdgeInsets.only(
                                                  left: 5,
                                                  right: 10,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: kAppColor.withOpacity(
                                                    0.8,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      ('Current:').appTr,
                                                      style: GoogleFonts.roboto(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        fontSize:
                                                            kHeight * 0.012,
                                                      ),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Obx(() {
                                                      if (websocketController
                                                          .liveCallList
                                                          .isEmpty) {
                                                        print(
                                                          "⚠️ No coins found — list is empty",
                                                        );
                                                        return const Text('0');
                                                      }

                                                      int coins =
                                                          int.tryParse(
                                                            websocketController
                                                                .liveCallList[0]['earn_coins']
                                                                .toString(),
                                                          ) ??
                                                          0;
                                                      String displayText;
                                                      if (coins >= 1000000) {
                                                        double value =
                                                            coins / 1000000;
                                                        displayText =
                                                            value % 1 == 0
                                                            ? '${value.toInt()}M'
                                                            : '${value.toStringAsFixed(1)}M';
                                                      } else if (coins >=
                                                          1000) {
                                                        double value =
                                                            coins / 1000;
                                                        displayText =
                                                            value % 1 == 0
                                                            ? '${value.toInt()}k'
                                                            : '${value.toStringAsFixed(1)}k';
                                                      } else {
                                                        displayText = coins
                                                            .toString();
                                                      }

                                                      // 🔹 UI return
                                                      return Text(
                                                        displayText,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize:
                                                              kHeight * 0.014,
                                                        ),
                                                      );
                                                    }),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      ///----- noble part ----------
                                      InkWell(
                                        onTap: () {},
                                        child: Container(
                                          width: kWeight * 0.25,
                                          margin: EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 10,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 3,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xff8c61e1),
                                                Color(0xff5815dc),
                                              ],
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Image(
                                                image: AssetImage(
                                                  'assets/flaticons/crown.png',
                                                ),
                                                height: kHeight * 0.03,
                                              ),
                                              Text(
                                                (' Noble').appTr,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  fontSize: kWeight * 0.029,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8.0,
                                      right: 9,
                                    ),
                                    child: Row(
                                      children: [
                                        LiveCommentsSection(
                                          broadcasterData: broadcasterData,
                                          streamType: 'audio',
                                        ),
                                        ////container  text end
                                        SizedBox(width: kWeight * 0.02),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(height: kHeight * 0.055),
                              ],
                            ),
                      Obx(() {
                        final newUser = websocketController.newJoinedUserData;

                        // প্রিন্ট করে দেখুন
                        print("New Joined User Data: $newUser");

                        // যদি নতুন ইউজার ব্রডকাস্টার না হয়
                        if (websocketController.newViewersJoinded.value) {
                          return Positioned(
                            left: 12,
                            top: Get.height * 0.5,
                            child: SizedBox(
                              width: Get.width * 0.9,
                              child: EntryAnimation(data: newUser),
                            ),
                          );
                        } else {
                          // ব্রডকাস্টার বা অন্য শর্তে কিছু দেখাবেন না
                          return Container();
                        }
                      }),

                      // Red Packet Animation
                      Obx(
                        () =>
                            websocketController.redPacketVisible.value &&
                                websocketController
                                    .currentRedPacket
                                    .value
                                    .isNotEmpty
                            ? Positioned.fill(
                                child: RedPacketAnimation(
                                  isVisible: websocketController
                                      .redPacketVisible
                                      .value,
                                  onTap: () async {
                                    // Collect red packet
                                    final redPacket = websocketController
                                        .currentRedPacket
                                        .value;
                                    if (redPacket.isNotEmpty) {
                                      await liveController.collectRedPacket(
                                        redPacket['id'],
                                      );
                                      websocketController.hideRedPacket();
                                    }
                                  },
                                ),
                              )
                            : Container(),
                      ),

                      _agoraService.engine == null
                          ? const Center(
                              child: CircularProgressIndicator(),
                            ) // Show loading
                          : Container(),

                      ///------------- bottom part -------
                      _agoraService.engine != null
                          ? Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: kWeight * 0.0,
                                ),
                                child: Row(
                                  children: [
                                    // WriteCommentSection takes most of the space
                                    Expanded(
                                      child: WriteCommentSection(
                                        rtcEngine: _agoraService.engine!,
                                        streamType: 'popular',
                                        broadcasterData: broadcasterData,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              color: Colors
                                  .transparent, // Optional: blank red bar if engine null
                              height: 60, // adjust height if needed
                            ),

                      Obx(
                        () => livestreamController.showMiniScene.value
                            ? Positioned(
                                top: 60,
                                right: 10,
                                child: AnimatedOpacity(
                                  opacity:
                                      livestreamController.showMiniScene.value
                                      ? 1
                                      : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    width: Get.width * 0.5,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ("🎁 Mini Scene").appTr,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          ("This is a small overlay above live.")
                                              .appTr,
                                        ),
                                        const SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: () {
                                            livestreamController
                                                    .showMiniScene
                                                    .value =
                                                false;
                                          },
                                          child: Text(("Close").appTr),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      //Live view bottom part end
                    ],
                  ),
                ),
        ),

        // body parameter শেষ
      ),
    );
  }

  bool muted = false, videoDisabled = false, loudSpeaker = false;

  Widget _broadcastView() {
    if (_agoraService.engine == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Obx(() {
      final views = _getRenderViews(
        listActive: websocketController.liveCallList,
      );

      if (views.isEmpty) {
        return Center(child: Text(("Waiting for remote user...").appTr));
      }

      final mainView = views[0];

      websocketController.liveCallList
          .asMap()
          .entries
          .where((e) => e.key > 0 && e.key <= 4 && e.key < views.length)
          .map((e) {
            final index = e.key;
            final broadcaster = e.value;

            return GestureDetector(
              onTap: () {
                homeController.liveVisitProfile(
                  userId: '${broadcaster['user']['id']}',
                  seatData: broadcaster,
                );
              },
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: Get.width * 0.25,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAppColor, width: .4),
                  color: Colors.black.withOpacity(0.6),
                ),
                child: Column(
                  children: [
                    // ভিডিও ভিউ অংশ
                    Container(
                      height: Get.height * 0.1,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: broadcaster['video_on'] == 0
                            ? Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    100,
                                  ), // full round shape
                                  child: CachedNetworkImage(
                                    imageUrl: ImageHelper.getImageUrl(
                                      broadcaster['user']['profile_image'],
                                    ),
                                    height:
                                        Get.height *
                                        0.07, // equal height & width
                                    width: Get.height * 0.07,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : views[index],
                      ),
                    ),

                    // নাম ও লেভেল অংশ
                    broadcaster['video_on'] == 0
                        ? Center(
                            child: Text(
                              broadcaster['user']['name'].length > 10
                                  ? '${broadcaster['user']['name'].substring(0, 10)}...'
                                  : broadcaster['user']['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: kHeight * 0.009,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kAppColor,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 9,
                                  backgroundImage: NetworkImage(
                                    ImageHelper.getImageUrl(
                                      '${broadcaster['user']['profile_image']}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        broadcaster['user']['name'].length > 10
                                            ? '${broadcaster['user']['name'].substring(0, 10)}...'
                                            : broadcaster['user']['name'],
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: kHeight * 0.009,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
          })
          .toList();

      return websocketController.isPkRunning.value
          ? Stack(
              children: [
                // 🎥 Main broadcaster view
                Positioned(
                  top: kHeight * 0.2,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: kHeight * 0.4,
                    child: Row(
                      children: [
                        Expanded(child: views[0]),
                        Expanded(child: views[1]),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: _buildSeatLayout(
                context,
                views,
                websocketController.liveCallList,
                liveController.seatCount.value,
                mainView,
              ),
            );
    });
  }

  /// Helper function to get list of native views

  Widget _seatBoxView(
    List<Widget> views,
    List<dynamic> liveCallList,
    int index,
  ) {
    // Find the call entry occupying this exact seat number
    Map<String, dynamic>? seatEntry;
    for (final call in liveCallList) {
      final seatNo = call['seat_no'];
      if (seatNo != null && seatNo.toString() == index.toString()) {
        seatEntry = Map<String, dynamic>.from(call);
        break;
      }
    }

    // If seat is empty, allow audience to tap to join
    if (seatEntry == null) {
      return InkWell(
        onTap: () => _attemptJoinSeat(index),
        child: Center(
          child: Icon(
            Icons.event_seat,
            size: kHeight * 0.024,
            color: Colors.white,
          ),
        ),
      );
    }

    // Seat occupied: render the correct video for the user assigned to this seat
    final int uid =
        int.tryParse(
          '${seatEntry['user']?['id'] ?? seatEntry['caller_id'] ?? 0}',
        ) ??
        0;
    final bool isLocalUser =
        uid == (authController.userProfile.value.user?.id ?? -1);
    final bool videoOn = (seatEntry['video_on']?.toString() == '1');

    if (videoOn) {
      final Widget videoView = isLocalUser
          ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          : AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            );

      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: SizedBox.expand(child: videoView),
      );
    }

    // Occupied but video is off – show a non-clickable placeholder
    return Center(
      child: Icon(Icons.event_seat, size: kHeight * 0.024, color: Colors.white),
    );
  }

  /// Builds the non-PK layout according to seatCount similar to goto_live_multi
  Widget _buildSeatLayout(
    BuildContext context,
    List<Widget> views,
    List<dynamic> liveCallList,
    int seatCount,
    Widget mainView,
  ) {
    switch (seatCount) {
      case 6:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          height: kHeight * .38,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              // Left column: main view on top, two seats below
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(0),
                        ),
                        child: Container(
                          color: Colors.black54,
                          child: SizedBox.expand(child: mainView),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: 1,
                                  color: Colors.white,
                                ),
                              ),
                              child: _seatBoxView(views, liveCallList, 1),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: _seatBoxView(views, liveCallList, 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right column: three vertical seats
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.white),
                        ),
                        child: _seatBoxView(views, liveCallList, 3),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 1),
                            right: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 4),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.white),
                        ),
                        child: _seatBoxView(views, liveCallList, 5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 9:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          height: kHeight * .38,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              // Column 1
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(width: 1, color: Colors.white54),
                          ),
                          child: SizedBox.expand(child: mainView),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 1),
                            right: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 1),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.white),
                        ),
                        child: _seatBoxView(views, liveCallList, 2),
                      ),
                    ),
                  ],
                ),
              ),
              // Column 2
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 1),
                            bottom: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 3),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 1),
                            right: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 4),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 1),
                            bottom: BorderSide(color: Colors.white, width: 1),
                            right: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 5),
                      ),
                    ),
                  ],
                ),
              ),
              // Column 3
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.white),
                        ),
                        child: _seatBoxView(views, liveCallList, 6),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.white, width: 1),
                            bottom: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 7),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.white, width: 1),
                            bottom: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 15:
        // 3 columns x 5 rows grid; mainView occupies top-left, others fill sequentially
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          height: kHeight * .42,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(width: 1, color: Colors.white54),
                          ),
                          child: SizedBox.expand(child: mainView),
                        ),
                      ),
                    ),
                    for (int i = 1; i <= 4; i++)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(width: 1, color: Colors.white),
                          ),
                          child: _seatBoxView(views, liveCallList, i),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 5; i <= 9; i++)
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.white, width: 1),
                              right: BorderSide(color: Colors.white, width: 1),
                              bottom: BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: _seatBoxView(views, liveCallList, i),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 10; i <= 14; i++)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(width: 1, color: Colors.white),
                          ),
                          child: _seatBoxView(views, liveCallList, i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 4:
      default:
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          height: kHeight * .38,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Main broadcaster view
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: Container(
                    color: Colors.black54,
                    child: SizedBox.expand(child: mainView),
                  ),
                ),
              ),
              // Right: 3 equal boxes
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.white),
                        ),
                        child: _seatBoxView(views, liveCallList, 1),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.white, width: 1),
                            right: BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: _seatBoxView(views, liveCallList, 2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.white),
                        ),
                        child: _seatBoxView(views, liveCallList, 3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  List<Widget> _getRenderViews({required List<dynamic> listActive}) {
    final List<StatefulWidget> list = [];
    final List activeCallersData = [];

    for (var activeCallData in listActive) {
      int uid = int.parse(activeCallData['user']['id'].toString());

      if (uid.toString() == widget.channelName) {
        if (widget.isBroadcaster) {
          activeCallersData.insert(0, activeCallData);
          list.insert(
            0,
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: 0), // Local broadcaster always uid: 0
              ),
            ),
          );
        } else {
          activeCallersData.insert(0, activeCallData);
          list.insert(
            0,
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            ),
          );
        }
      } else {
        if (uid == authController.userProfile.value.user!.id!) {
          _agoraService.engine!.setClientRole(
            role: ClientRoleType.clientRoleBroadcaster,
          );
          // Do not force-enable video/audio here to avoid background camera start.
          activeCallersData.add(activeCallData);
          list.add(
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: 0),
              ),
            ),
          );
        } else {
          activeCallersData.add(activeCallData);
          list.add(
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _agoraService.engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            ),
          );
        }
      }
    }

    return list;
  }

  Future giftBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xff16261c),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // **Premium Banner**
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff24a177),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(Icons.close, color: Colors.red),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // **Title**
            Text(
              ("Choose Your Gift 🎁").appTr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),

            // **Gift GridView**
            Obx(() {
              return livestreamController.giftList.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        ("No gifts available 😔").appTr,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisExtent: 120,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: livestreamController.giftList.length,
                        itemBuilder: (context, index) {
                          final gift = livestreamController.giftList[index];
                          bool isSelected =
                              livestreamController.selectedGiftId.value ==
                              gift['id'];
                          return GestureDetector(
                            onTap: () {
                              livestreamController.selectedGiftId.value =
                                  gift['id'];
                              setState(() {});
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(0xff16261c)
                                    : Color(0xff16261c),
                                border: Border.all(
                                  color: isSelected
                                      ? Color(0xff24a177)
                                      : Color(0xff16261c),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // **Gift Image**
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      "$kDomainUrl/${gift['gift_image']}",
                                      height: 50,
                                      width: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(height: 8),

                                  // **Gift Name**
                                  Text(
                                    gift['name'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),

                                  // **Gift Coin Price**
                                  Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image(
                                          image: AssetImage(
                                            'assets/icons/coin.png',
                                          ),
                                          height: 10,
                                        ),
                                        SizedBox(width: 7),
                                        Text(
                                          "${gift['coin']}  ",
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
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
                    );
            }),

            SizedBox(height: 16),

            Obx(() {
              return livestreamController.selectedGiftId.value != 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            livestreamController.tryToSendGift(
                              receiverId:
                                  livestreamController.broadcasterId.value,
                              giftId: livestreamController.selectedGiftId.value,
                              giftPrice:
                                  int.tryParse(
                                    authController.userProfile.value.user!.coins
                                        .toString(),
                                  ) ??
                                  0,
                            );

                            Get.back();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: 1,
                              horizontal: 10,
                            ),
                            backgroundColor: Colors.greenAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Text(
                              ("Send").appTr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox();
            }),
          ],
        ),
      ),
    );
  }
}

Future<void> _attemptJoinSeat(int seatNo) async {
  // Only audience can attempt to join seats
  if (livestreamController.isBroadcaster.value) return;

  // Check if user is already on a seat
  final userId = authController.userProfile.value.user?.id?.toInt() ?? 0;
  final alreadyOnSeat = websocketController.liveCallList.any((call) {
    final callUserId =
        call['user']?['id']?.toInt() ?? call['caller_id']?.toInt() ?? -1;
    return callUserId == userId;
  });

  if (alreadyOnSeat) {
    Get.snackbar(
      ('Info').appTr,
      ('You are already on a mic seat.').appTr,
      backgroundColor: Colors.black54,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }

  // Check available seats before joining
  final availableSeats = await livestreamController.getAvailableSeats(
    livestreamController.streamId.value,
  );

  final isSeatAvailable =
      availableSeats != null &&
      availableSeats['available_seats'] != null &&
      (availableSeats['available_seats'] as List)
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .contains(seatNo);

  if (!isSeatAvailable) {
    Get.snackbar(
      ('Seat Busy').appTr,
      ('Selected seat is not available right now.').appTr,
      backgroundColor: Colors.black54,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }

  // Proceed with joining the seat
  await livestreamController.tryToCallLivestream(
    streamId: livestreamController.streamId.value,
    callerId: userId,
    callType: 'video',
    seatNO: seatNo,
  );
}
