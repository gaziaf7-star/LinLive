import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../constants/color_constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/livestream_controller.dart';
import '../socket/websocket_controller.dart';
import 'go_to_live_audio.dart';
import 'goto_live_multi.dart';
import 'goto_live_popular.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class GotoLiveTabView extends StatefulWidget {
  const GotoLiveTabView({Key? key}) : super(key: key);

  @override
  State<GotoLiveTabView> createState() => _GotoLiveTabViewState();
}

class _GotoLiveTabViewState extends State<GotoLiveTabView>
    with SingleTickerProviderStateMixin {
  // Removed local Agora engine and preview setup to avoid auto camera activation.

  String liveType = 'public';
  late TabController _tabController;
  TextEditingController textEditingController =
  TextEditingController(text: 'hello');

  AuthController authController = Get.find();
  LivestreamController liveController = Get.isRegistered<LivestreamController>()
      ? Get.find<LivestreamController>()
      : Get.put(LivestreamController());
  WebsocketController controller = Get.find();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Removed initAgora to prevent camera preview at tab load
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white.withOpacity(.1),
        body: Stack(
          children: [
            // Foreground content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      GotoPopularLive(),
                      // GotoMultiLive(),
                      GotoAudioLiveView(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration:  BoxDecoration(
            gradient:  LinearGradient(
              colors: [
                Color(0xff5904d8),
                Color(0xff6d05c1),
                Color(0xff5904d8),

              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: kHeight * 0.015,
                horizontal: kHeight * 0.01,
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient:  LinearGradient(
                    colors: [
                      Color(0xff5904d8),
                      Color(0xff6d05c1),
                      Color(0xff5904d8),

                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 34,
                ),
                dividerColor: Colors.transparent,

                labelColor: Colors.white,
                unselectedLabelColor: Colors.white,

                tabs: [
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.live_tv),
                        Text(
                          ('Popular').appTr,
                          style: GoogleFonts.poppins(
                            fontSize: kHeight * 0.013,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic),
                        Text(
                          ('Audio').appTr,
                          style: GoogleFonts.poppins(
                            fontSize: kHeight * 0.013,
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
}
