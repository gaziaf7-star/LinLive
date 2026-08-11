import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../appmenu/views/widgets/Flower.dart';
import '../../appmenu/views/widgets/FlowingList.dart';
import '../../messanger/views/chat_controller.dart';
import '../../messanger/views/messanger_view.dart';
import '../controllers/notification_controller.dart';
import 'notificationCard.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(NotificationController());

    final ChatController chatController =
    Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController(), permanent: true);

    final double w = MediaQuery.of(context).size.width;
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: h * 0.065,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF3B072F),
                Color(0xFF3B072F),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Text(
          'Message'.appTr,
          style: GoogleFonts.lato(
            fontSize: w * 0.048,
            fontWeight: FontWeight.w800,
            color: const Color(0xfffbfafa),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: h * 0.025),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.065),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder<int>(
                  stream: chatController.totalUnreadCountStream,
                  initialData: 0,
                  builder: (context, snapshot) {
                    return InkWell(
                      onTap: () {
                        Get.to(
                          MessengerView(),
                          transition: Transition.fade,
                        );
                      },
                      child: _topIcon(
                        w: w,
                        title: 'Messages'.appTr,
                        icon: Icons.chat_bubble_outline,
                        colors: const [
                          Color(0xff1AD8D2),
                          Color(0xff2D9BF3),
                        ],
                        badgeCount: snapshot.data ?? 0,
                      ),
                    );
                  },
                ),
                InkWell(
                  onTap: () {
                    Get.to(
                      FollowinfList(),
                      transition: Transition.fade,
                    );
                  },
                  child: _topIcon(
                    w: w,
                    title: 'Following'.appTr,
                    icon: Icons.favorite_border,
                    showPlus: true,
                    colors: const [
                      Color(0xffFFD64D),
                      Color(0xffFF842D),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    Get.to(
                      Follower(),
                      transition: Transition.rightToLeft,
                    );
                  },
                  child: _topIcon(
                    w: w,
                    title: 'Follow'.appTr,
                    icon: Icons.star_border,
                    colors: const [
                      Color(0xffB84CFF),
                      Color(0xff25C8FF),
                    ],
                  ),
                ),
                SizedBox(width: kWeight * 0.08),
              ],
            ),
          ),
          SizedBox(height: h * 0.032),
          Container(
            height: h * 0.018,
            color: const Color(0xffF5F5F5),
          ),
          Expanded(
            child: NotificationCardView(),
          ),
        ],
      ),
    );
  }

  Widget _topIcon({
    required double w,
    required String title,
    required IconData icon,
    required List<Color> colors,
    bool showPlus = false,
    int badgeCount = 0,
  }) {
    final double circleSize = w * 0.112;

    return Column(
      children: [
        SizedBox(
          height: circleSize + 4,
          width: circleSize + 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        icon,
                        color: Colors.white,
                        size: w * 0.05,
                      ),
                      if (showPlus)
                        Positioned(
                          right: circleSize * 0.24,
                          bottom: circleSize * 0.27,
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: w * 0.025,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -3,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 20,
                      minWidth: 20,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xffF80230),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: w * 0.018),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: kHeight * 0.015,
            fontWeight: FontWeight.w500,
            color: const Color(0xff434343),
          ),
        ),
      ],
    );
  }
}
