import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../controllers/livestream_controller.dart';
import 'entertainment_tools_widget.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MultiWriteCommentSection extends StatefulWidget {
  RtcEngine rtcEngine;

  MultiWriteCommentSection({required this.rtcEngine});

  @override
  _MultiWriteCommentSectionState createState() =>
      _MultiWriteCommentSectionState();
}

class _MultiWriteCommentSectionState extends State<MultiWriteCommentSection> {
  TextEditingController addComments = TextEditingController();
  FocusNode commentFocusNode = FocusNode();

  LivestreamController livestreamController = Get.find();
  bool isTyping = false;
  bool isSwitched = false;
  bool showAnimatedMessage = false;
  final seatUsers = <int, Map<String, dynamic>>{}.obs;
  RtcEngine? engine;

  final availableSeats = <int>[].obs;

  /// ------------------ audio mute ----------------
  void _toggleAudio() async {
    // Toggle mute state using livestreamController.mute.value pattern
    livestreamController.mute.value = !livestreamController.mute.value;

    // Actually mute/unmute the audio using Agora engine
    await engine?.muteLocalAudioStream(livestreamController.mute.value);

    // Find current user's seat and update local state
    int? currentUserSeat = _getCurrentUserSeat();
    if (currentUserSeat != null) {
      setState(() {
        if (seatUsers.containsKey(currentUserSeat)) {
          seatUsers[currentUserSeat]!['audio_on'] =
              !livestreamController.mute.value;
        }
      });
    }
  }

  /// ------------------- video
  bool _getCurrentUserVideoStatus() {
    // Use livestreamController.isVideoEnabled.value for consistency with audio live view system
    return livestreamController.isVideoEnabled.value;
  }

  void _toggleVideo() async {
    // Toggle video state using livestreamController.isVideoEnabled.value pattern
    livestreamController.isVideoEnabled.value =
        !livestreamController.isVideoEnabled.value;

    // Actually enable/disable the video using Agora engine
    await engine?.enableLocalVideo(livestreamController.isVideoEnabled.value);

    print(
        'Video ${livestreamController.isVideoEnabled.value ? "enabled" : "disabled"}');

    // Find current user's seat and update local state
    int? currentUserSeat = _getCurrentUserSeat();
    if (currentUserSeat != null) {
      setState(() {
        if (seatUsers.containsKey(currentUserSeat)) {
          seatUsers[currentUserSeat]!['video_on'] =
              livestreamController.isVideoEnabled.value
                  ? 1
                  : 0; // Convert to 1/0 format
        }
      });
    }
  }

  ///---------------
  void _leaveSeat() {
    int? currentSeat = _getCurrentUserSeat();
    if (currentSeat == null || currentSeat == 1) {
      return; // Can't leave if broadcaster
    }
// ------------ Video toggle

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          ('Leave Seat').appTr,
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          ('Are you sure you want to leave seat $currentSeat?').appTr,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(('Cancel').appTr, style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement leave seat API call
              // print(
              //     'Leaving seat $currentSeat in channel ${widget.channelName}');
              // Remove user from local state immediately
              setState(() {
                seatUsers.remove(currentSeat);
                availableSeats.add(currentSeat);
                availableSeats.sort();
              });
            },
            child: Text(('Leave').appTr, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --------------------------------  _getCurrentUserAudioStatus----------
  bool _getCurrentUserAudioStatus() {
    // Use livestreamController.mute.value for consistency with audio live view system
    return !livestreamController.mute.value;
  }

  void showFlyingMessage(String message) {
    setState(() {
      showAnimatedMessage = true;
    });

    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        showAnimatedMessage = false;
      });
    });
  }

  int? _getCurrentUserSeat() {
    String currentUserId =
        authController.userProfile.value.user!.id!.toString();
    for (var entry in seatUsers.entries) {
      if (entry.value['user_id'] == currentUserId) {
        return entry.key;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    commentFocusNode.addListener(() {
      setState(() {
        isTyping = commentFocusNode.hasFocus || addComments.text.isNotEmpty;
      });
    });

    addComments.addListener(() {
      setState(() {
        isTyping = commentFocusNode.hasFocus || addComments.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    addComments.dispose();
    commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12, // Glass effect
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 10,
          right: 10,
          top: 5,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
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
                    child: isTyping
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
                                            borderRadius:
                                                BorderRadius.circular(30),
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
                                        fontSize: kHeight * 0.014),
                                    decoration: InputDecoration(
                                      hintText: ('Write a comment...').appTr,
                                      hintStyle: GoogleFonts.roboto(
                                          color: Colors.black.withOpacity(.6),
                                          fontSize: kHeight * 0.013),
                                      filled: true,
                                      isCollapsed: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 11,
                                          horizontal: kWeight * 0.05),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.8)),
                              onPressed: () {
                                setState(() {
                                  isTyping = true;
                                  commentFocusNode.requestFocus();
                                });
                              },
                              icon: ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return const LinearGradient(
                                    colors: [
                                      kAppColor, // Gradient Start (e.g., red-pink)
                                      kAppColor // Gradient End (e.g., orange)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.srcIn,
                                child: Image.asset(
                                  'assets/frame/comment_7945005.png',
                                  height: kHeight * 0.02,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: isTyping
                      ? GestureDetector(
                          key: ValueKey(1), // Unique key to trigger animation
                          onTap: () {
                            setState(() {
                              addComments.clear();
                              isTyping = false;
                              commentFocusNode.unfocus(); // Hide keyboard
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              gradient: LinearGradient(
                                colors: [kAppColor, kAppColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: GestureDetector(
                                onTap: () {
                                  livestreamController.tryToAddComment(
                                      comment: addComments.text);

                                  addComments.clear();
                                  commentFocusNode.unfocus();
                                },
                                child: Text(
                                  ('Send').appTr,
                                  style: GoogleFonts.lato(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: kHeight * 0.015),
                                )),
                          ),
                        )
                      : Row(
                          key: ValueKey(2),
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            buildBottomControls(),
                            EntertainmentToolsWidget(
                              streamType: 'multi',
                              isBroadcaster:
                                  livestreamController.isBroadcaster.value,
                            ),
                            SizedBox(
                              width: 8,
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

  Widget _buildCallList(List callList, bool isPending) {
    return ListView.builder(
      itemCount: callList.length,
      itemBuilder: (context, index) {
        final call = callList[index];
        return call['user']['id'] == authController.userProfile.value.user!.id!
            ? Container()
            : Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(ImageHelper.getImageUrl(
                        '${call['user']['profile_image']}')),
                  ),
                  title: Text(call['user']['name'],
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(('Level: ${call['user']['level']}').appTr,
                      style: TextStyle(color: Colors.grey[700])),
                  trailing: isPending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                livestreamController.tryToAcceptCall(
                                  streamId: livestreamController.streamId.value,
                                  userId: call['user']['id'],
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                livestreamController.tryToRejectCall(
                                  streamId: livestreamController.streamId.value,
                                  userId: call['user']['id'],
                                );
                              },
                            ),
                          ],
                        )
                      : IconButton(
                          icon: Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () {
                            livestreamController.tryToRejectCall(
                              streamId: livestreamController.streamId.value,
                              userId: call['user']['id'],
                            );
                          },
                        ),
                ),
              );
      },
    );
  }

  void showCallBottomSheet(BuildContext context, RtcEngine rtcEngine) {
    Get.bottomSheet(
      DefaultTabController(
        length: 2,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: constraints.maxHeight * 0.5,
              width: constraints.maxWidth * 0.9,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.pinkAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 25),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if (livestreamController.isBroadcaster.value) ...[
                            Expanded(
                              child: Column(
                                children: [
                                  TabBar(
                                    labelColor: Colors.white,
                                    unselectedLabelColor: Colors.white70,
                                    indicator: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.black45.withOpacity(0.3),
                                    ),
                                    tabs:  [
                                      Tab(text: ('Pending Calls').appTr),
                                      Tab(text: ('Live Calls').appTr),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        Obx(() => _buildCallList(
                                            websocketController.pendingCall,
                                            true)),
                                        Obx(() => _buildCallList(
                                            websocketController.liveCallList,
                                            false)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Viewer buttons
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 20),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                livestreamController.tryToCallLivestream(
                                  streamId: livestreamController.streamId.value,
                                  callerId: authController
                                      .userProfile.value.user!.id!
                                      .toInt(),
                                  callType: 'video',
                                );
                                Get.back();
                              },
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/icons/video-call_5535718.png',
                                    height: 30,
                                  ),
                                  const SizedBox(width: 10),
                                   Text(
                                    ('Make a Call').appTr,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xffbf5701),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (websocketController.pendingCall.isNotEmpty ||
                                websocketController.liveCallList.isNotEmpty)
                              const SizedBox(height: 12),
                            if (websocketController.pendingCall.isNotEmpty ||
                                websocketController.liveCallList.isNotEmpty)
                              const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 20),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                await livestreamController.tryToRejectCall(
                                  streamId: livestreamController.streamId.value,
                                  userId: authController
                                      .userProfile.value.user!.id!
                                      .toInt(),
                                );

                                livestreamController.removeBroadcaster(
                                  engine: rtcEngine,
                                );
                                Get.back();
                              },
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/icons/close_463612.png',
                                    height: 30,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    ('Cancel Call').appTr,
                                    style: GoogleFonts.lato(
                                      color: const Color(0xff981701),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget buildBottomControls() {
    return Container(
      height: kHeight * 0.08,
      padding: EdgeInsets.symmetric(horizontal: kWeight * 0.03),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: kWeight * 0.02),

          // Audio toggle - show only if user has joined a seat
          if (_getCurrentUserSeat() != null)
            Obx(() => GestureDetector(
                  onTap: _toggleAudio,
                  child: Container(
                    padding: EdgeInsets.all(kHeight * 0.012),
                    decoration: BoxDecoration(
                      color: _getCurrentUserAudioStatus()
                          ? Colors.green
                          : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getCurrentUserAudioStatus() ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                      size: kHeight * 0.022,
                    ),
                  ),
                )),

          if (_getCurrentUserSeat() != null) SizedBox(width: kWeight * 0.02),

          // Video toggle - show only if user has joined a seat
          if (_getCurrentUserSeat() != null)
            Obx(() => GestureDetector(
                  onTap: _toggleVideo,
                  child: Container(
                    padding: EdgeInsets.all(kHeight * 0.012),
                    decoration: BoxDecoration(
                      color: _getCurrentUserVideoStatus()
                          ? Colors.green
                          : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getCurrentUserVideoStatus()
                          ? Icons.videocam
                          : Icons.videocam_off,
                      color: Colors.white,
                      size: kHeight * 0.022,
                    ),
                  ),
                )),

          // Leave seat button - show only if user has joined a seat (except broadcaster)
          if (_getCurrentUserSeat() != null && _getCurrentUserSeat() != 1)
            Padding(
              padding: EdgeInsets.only(left: kWeight * 0.02),
              child: GestureDetector(
                onTap: _leaveSeat,
                child: Container(
                  padding: EdgeInsets.all(kHeight * 0.012),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.exit_to_app,
                    color: Colors.white,
                    size: kHeight * 0.022,
                  ),
                ),
              ),
            ),

          SizedBox(width: kWeight * 0.02),

          // Gift button
          GestureDetector(
            // onTap: () => _showGiftBottomSheet(null),
            child: Container(
              padding: EdgeInsets.all(kHeight * 0.01),
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard,
                color: Colors.white,
                size: kHeight * 0.02,
              ),
            ),
          ),

          SizedBox(width: kWeight * 0.02),

          // Gift history button
          GestureDetector(
            // onTap: () => _showGiftHistory(),
            child: Container(
              padding: EdgeInsets.all(kHeight * 0.01),
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                color: Colors.white,
                size: kHeight * 0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _infoBadge(IconData icon, String value) {
  return Container(
    height: 15,
    width: 35,
    decoration: const BoxDecoration(
      color: Color(0xff843af4),
      borderRadius: BorderRadius.all(Radius.circular(50)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Icon(icon, size: 11, color: Colors.white),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 7,
          ),
        ),
      ],
    ),
  );
}

Widget _profileImage() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(100),
    child: CachedNetworkImage(
      imageUrl:
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRO_zU_CkIPahftPFxoH-_Ssrk0tTLz0BRkLYea4mE1MtJ3uPa-fwbK7Ppr1_XXtJagCOI',
      height: 50,
      width: 50,
      fit: BoxFit.cover,
    ),
  );
}

Widget _ruleText(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Castontext(
      text: text,
      textColor: Colors.white70,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
  );
}
