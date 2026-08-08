import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/image_const/image_conost.dart';
import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/CastomText.dart';
import '../../livestream/controllers/livestream_controller.dart';
import '../controllers/home_controller.dart';
import 'all_live_live_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class AudioLiveListView extends GetView<HomeController> {
  const AudioLiveListView({super.key});

  @override
  Widget build(BuildContext context) {
    HomeController controller = Get.put(HomeController());
    Get.put(LivestreamController());
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kAppColor1.withOpacity(.3), kAppColor2],
          ),
        ),
        child: CustomRefreshIndicator(
          onRefresh: () async {
            await homeController.getLivestreamList();
          },
          builder:
              (
                BuildContext context,
                Widget child,
                IndicatorController controller,
              ) {
                return Stack(
                  children: [
                    child, // Your scrollable content
                    // Custom indicator
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          return SizedBox(
                            height:
                                controller.value *
                                80, // adjust height as needed
                            child: Center(
                              child: controller.isIdle
                                  ? const SizedBox()
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: kAppColor,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Transform.scale(
                                        scale: controller.value.clamp(
                                          0.0,
                                          1.0,
                                        ), // grow as you pull
                                        child: Image.asset(
                                          appLogo, // your image path
                                          width: 40,
                                          height: 40,
                                        ),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Obx(() {
              final users = controller.showingLiveStreamList;

              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(kHeight * 0.1),
                    child: Column(
                      children: [
                        SizedBox(height: kHeight * 0.01),
                        Lottie.asset(
                          'assets/flaticons/nYuPvdjcOD.json',
                          height: kHeight * 0.14,
                          width: kHeight * 0.14,
                          fit: BoxFit.cover,
                        ),
                        SizedBox(height: kHeight * 0.01),
                        Castontext(
                          fontWeight: FontWeight.w500,
                          textColor: Colors.black.withOpacity(.6),
                          fontSize: kHeight * 0.012,
                          text: ('No Stream Available').appTr,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (controller.isLoading.value) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: kHeight * 0.23,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(4),
                      ),
                    );
                  },
                );
              }

              final audioUsers = users
                  .where((item) {
                    return item is Map && item['stream_type'] == 'audio';
                  })
                  .toList(growable: false);
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: kHeight * 0.23,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: audioUsers.length,
                  itemBuilder: (context, index) {
                    final item = audioUsers[index];
                    return RepaintBoundary(
                      child: UserProfileCard(
                        key: ValueKey(
                          'audio_live_${item['id'] ?? item['livestream_id'] ?? index}',
                        ),
                        data: item,
                        index: index,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
